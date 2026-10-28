//
//  GroupSharingService.swift
//  Later 再度
//
//  グループ作成時のCKShare発行(合言葉→共有URLの解決含む)と、
//  参加コード経由でのShare受け入れを担当する。招待リンクを直接タップして
//  受け取ったCKShare.Metadataの受け入れにも同じacceptShare(metadata:)を使う。

import CloudKit
import Foundation
import SwiftData
import os

private let logger = GroupSyncLogger.shared

/// グループの人数・所属数に関するシステム上限。CKShareの参加人数やSwiftData上の
/// 所属グループ数はサーバー側で強制されないため、参加/作成の入口(GroupSharingService)で
/// 明示的にバリデーションする。
enum GroupMembershipPolicy {
    /// 1グループあたりの最大人数(ホストを含む)。9人目の参加は拒否する。
    /// 「4人以上」は作成直後には満たせないため、案内の文言だけにして強制しない。
    static let maxMembersPerGroup = 8
    /// グループごとに決められる人数の上限の範囲
    static let memberLimitRange = 4...8
    /// 1人が参加・作成できる最大グループ数。個人用スペース「ME」は数えない
    /// (全ユーザーが自動的に持つものであり、「参加・作成した」グループではないため)。
    static let maxGroupsPerUser = 10
}

/// GroupSharingService内部だけで使う、「画像アップロードでquotaExceededを検知したので
/// 画像を除いて再試行してほしい」という一時的な内部シグナル。GroupSharingError(呼び出し側
/// にも公開する正式なエラー型)とは別にしているのは、この状態はcreateGroup内で必ず
/// 再試行によって解消される(呼び出し側に直接届くことはない)一時的なものだから。
private struct QuotaExceededDuringImageUpload: Error {}

enum GroupSharingError: LocalizedError {
    case notSignedIn
    case shareURLMissing
    /// このグループは既にGroupMembershipPolicy.maxMembersPerGroupに達しており、
    /// これ以上の参加を受け付けられない。
    case groupFull
    /// 自分が既にGroupMembershipPolicy.maxGroupsPerUser個のグループに
    /// 参加・作成済みで、これ以上参加・作成できない。
    case tooManyGroups
    /// underlyingがあれば、iCloud未ログイン・期限切れ・既に受諾済みなど、実際のCKErrorの
    /// 説明を画面のメッセージにそのまま含める(招待リンクの受諾失敗時に原因を
    /// 特定できるよう、コンソールだけでなくUIにも反映するため)。
    case acceptFailed(underlying: Error? = nil)
    /// フェーズ1: グループ専用のCKRecordZone自体の作成/保存が失敗した場合。
    /// この時点で失敗している場合、後続のgroupRecord/hostProfileRecord/shareは
    /// そもそも保存先のゾーンが存在しないため、絶対に保存を試みない。
    case zoneCreationFailed(underlying: Error)
    /// グループ本体(groupRecord)のCloudKit保存自体が失敗した場合。共有リンクの問題とは
    /// 切り分けて呼び出し側に伝えるための専用ケース。
    /// detailは、atomicバッチの「巻き添え」ではない本当の原因レコード(underlyingとは別の
    /// レコードのことがある)のCKErrorコード・説明。TestFlight実機などXcodeコンソールを
    /// 見られない環境でも原因を特定できるよう、画面表示用メッセージに含める。
    case groupCreationFailed(underlying: Error, detail: String? = nil)
    /// グループ本体は保存できたが、CKShareの保存/URL取得だけが失敗した場合。
    case shareCreationFailed(underlying: Error, detail: String? = nil)
    /// グループ削除(ホスト時はゾーンごと削除、メンバー時は共有からの離脱)が失敗した場合。
    case deleteFailed(underlying: Error)
    /// グループアイコン/ホストのアバター画像のアップロードでCKError.quotaExceeded
    /// (iCloudの空き容量不足)を検知した場合。groupCreatedWithoutImagesがtrueなら、
    /// 画像を除いて再試行した結果グループ自体(名前・共有リンク含む)は作成できている
    /// (呼び出し側は、この場合グループを削除したりエラー画面のまま止めたりしないこと)。
    case quotaExceeded(groupCreatedWithoutImages: Bool)

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "iCloudアカウントの情報を取得できませんでした"
        case .shareURLMissing: return "共有リンクの取得に失敗しました"
        case .groupFull: return "このグループは満員です(最大\(GroupMembershipPolicy.maxMembersPerGroup)人までのため、これ以上参加できません)"
        case .tooManyGroups: return "参加・作成できるグループ数の上限(\(GroupMembershipPolicy.maxGroupsPerUser)グループ)に達しています"
        case .acceptFailed(let underlying):
            guard let underlying else { return "グループへの参加に失敗しました" }
            return "グループへの参加に失敗しました(\(underlying.localizedDescription))"
        case .zoneCreationFailed(let underlying): return "グループ領域の作成に失敗しました(\(underlying.localizedDescription))"
        case .groupCreationFailed(let underlying, let detail):
            return Self.describe("グループの作成に失敗しました", underlying: underlying, detail: detail)
        case .shareCreationFailed(let underlying, let detail):
            return Self.describe("共有リンクの作成に失敗しました", underlying: underlying, detail: detail)
        case .deleteFailed(let underlying):
            return "グループの削除に失敗しました(\(underlying.localizedDescription))"
        case .quotaExceeded(let groupCreatedWithoutImages):
            let base = "iCloudの容量が不足しているため、画像を保存できません。設定アプリのiCloudストレージ管理から空き容量を確認するか、容量を追加してください。"
            guard groupCreatedWithoutImages else { return base }
            return base + "グループ自体は画像なしで作成されました。空き容量を確保できたら、グループの設定から画像を設定し直してください。"
        }
    }

    private static func describe(_ base: String, underlying: Error, detail: String?) -> String {
        guard let detail else { return "\(base)(\(underlying.localizedDescription))" }
        return "\(base)(\(underlying.localizedDescription)) — 真因: \(detail)"
    }
}

extension Error {
    /// CKErrorの場合はコード番号・userInfoまで含めた詳細をXcodeのデバッグコンソールへ
    /// 出力し、画面表示用にコード番号付きの文言を返す。実機特有のCloudKit障害切り分け用に
    /// GroupDetailView/CircleCreateGroupViewの両方から共通で使う。
    /// partialFailure系のCKError(トップレベルのcode 2、あるいはatomicバッチの巻き添えで
    /// 個々のレコード結果に載ってくるcode 22など)はuserInfo[CKPartialErrorsByItemIDKey]に
    /// レコード単位のサブエラーを持つことがあるため、それも展開してログに出す。
    func loggedDescription(context: String) -> String {
        if let ckError = self as? CKError {
            var details = """
            \(context): CKError
              code = \(ckError.code.rawValue) (\(ckError.code))
              localizedDescription = \(ckError.localizedDescription)
              userInfo = \(ckError.userInfo)
              retryAfterSeconds = \(String(describing: ckError.retryAfterSeconds))
            """
            if let partialErrors = ckError.partialErrorsByItemID, !partialErrors.isEmpty {
                details += "\n  partialErrorsByItemID:"
                for (itemID, subError) in partialErrors {
                    if let subCKError = subError as? CKError {
                        details += "\n    - \(itemID): code = \(subCKError.code.rawValue) (\(subCKError.code)), localizedDescription = \(subCKError.localizedDescription), userInfo = \(subCKError.userInfo)"
                    } else {
                        details += "\n    - \(itemID): \(subError)"
                    }
                }
            }
            // os.Loggerは既定で変数の補間内容を"<private>"に伏せてしまい、TestFlightで
            // 原因調査ができなくなるため、privacy: .publicを明示する。
            logger.error("\(details, privacy: .public)")
            return "\(context)に失敗しました(CKError \(ckError.code.rawValue): \(ckError.localizedDescription))"
        } else {
            logger.error("\(context, privacy: .public): failed with non-CKError: \(String(describing: self), privacy: .public)")
            return localizedDescription
        }
    }

    /// CKPartialErrorsByItemIDKeyを直接userInfoから取り出し、レコード単位のサブエラーを
    /// 「❌ [CloudKit Item Error] <itemID>: <description>」の形式でログへ出す。
    /// loggedDescription(context:)内の型付きAPI(CKError.partialErrorsByItemID)による
    /// ダンプと内容は重複するが、atomicバッチ失敗(code 22)発生時に真因のレコードだけを
    /// 一目で拾えるよう、専用のシンプルな出力形式として分けて残す。
    func logPartialItemErrors() {
        guard let ckError = self as? CKError, ckError.code == .batchRequestFailed else { return }
        guard let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [NSObject: NSError] else { return }
        for (itemID, itemError) in partialErrors {
            print("❌ [CloudKit Item Error] \(itemID): \(itemError.localizedDescription)")
        }
    }

    /// トップレベル、またはpartialErrorsByItemID内に埋もれたCKError.quotaExceeded
    /// (コード25、iCloudの空き容量不足)を検知する。atomicバッチでは本当の原因が
    /// 「巻き添え」のCKError 22(batchRequestFailed)の下に隠れていることがあるため、
    /// 両方を確認する。
    var asQuotaExceededCKError: CKError? {
        guard let ckError = self as? CKError else { return nil }
        if ckError.code == .quotaExceeded { return ckError }
        if let partialErrors = ckError.partialErrorsByItemID {
            for (_, subError) in partialErrors {
                if let subCKError = subError as? CKError, subCKError.code == .quotaExceeded {
                    return subCKError
                }
            }
        }
        return nil
    }

    /// modifyRecords呼び出し自体がthrowした場合(saveResultsではなく、操作全体の失敗として
    /// 届く場合)に使う。partialErrorsByItemIDの中から、.batchRequestFailed以外の(=巻き添え
    /// ではない)固有コードを持つサブエラーを1件だけ拾って人間可読な文字列にする。
    var rootCausePartialErrorDetail: String? {
        guard let ckError = self as? CKError, let partialErrors = ckError.partialErrorsByItemID else { return nil }
        for (itemID, subError) in partialErrors {
            guard let subCKError = subError as? CKError, subCKError.code != .batchRequestFailed else { continue }
            return "\(itemID): CKError \(subCKError.code.rawValue)(\(subCKError.code)) \(subCKError.localizedDescription)"
        }
        return nil
    }
}

@MainActor
final class GroupSharingService {
    private let container: CKContainer
    private let modelContext: ModelContext
    private let cloudKitManager: CloudKitManager

    init(container: CKContainer, modelContext: ModelContext, cloudKitManager: CloudKitManager) {
        self.container = container
        self.modelContext = modelContext
        self.cloudKitManager = cloudKitManager
    }

    /// 新規グループのゾーン+CKShareを作成し、合言葉(inviteCode)をPublic DBへ公開する。
    /// hostProfileは作成者自身のUserProfile。
    ///
    /// 画像(グループアイコン/ホストのアバター)のアップロードでCKError.quotaExceeded
    /// (iCloudの空き容量不足)が検知された場合、画像を除いて自動的に1回だけ再試行する
    /// (グループの名前・共有リンクといったテキスト情報まで道連れで失敗させないため)。
    /// 再試行が成功した場合はGroupSharingError.quotaExceeded(groupCreatedWithoutImages: true)を
    /// throwする。この場合、グループ自体は既にCloudKit上にもローカルにも作成済みなので、
    /// 呼び出し側はこれを「失敗」として扱ってグループを削除してはならない
    /// (エラーメッセージの表示 + 画像なしでの成功、の両方を兼ねたケース)。
    func createGroup(_ group: LaterGroup, hostProfile: UserProfile) async throws {
        guard let ownerName = cloudKitManager.currentUserRecordName else {
            throw GroupSharingError.notSignedIn
        }

        // フェーズ1: グループ専用のCKRecordZoneをサーバー上に確実に作成する。
        // ここが完了(saveがawaitから正常returnする)するまでは、そのゾーンを
        // 参照するレコード(groupRecord/hostProfileRecord/share)を一切構築・保存しない。
        // ゾーンが存在しない状態でレコード保存を試みると、CKErrorが「巻き添え」で
        // atomicバッチ全体に対する code 22 (batchRequestFailed)として現れ、
        // 本当の原因(ゾーン未作成)がレコード単位のエラーに埋もれて見えなくなるため、
        // 意図的に保存を2段階に分離している。
        let zoneID = group.zoneID(ownerName: ownerName)
        let zone = CKRecordZone(zoneID: zoneID)
        do {
            let savedZone = try await container.privateCloudDatabase.save(zone)
            print("[GroupSync] ゾーン作成に成功: \(savedZone.zoneID)")
        } catch {
            _ = error.loggedDescription(context: "[GroupSync] ゾーン作成に失敗: \(zoneID)")
            error.logPartialItemErrors()
            throw GroupSharingError.zoneCreationFailed(underlying: error)
        }

        // フェーズ2: ゾーンの存在がサーバー側で確定した後にのみ、グループ本体・
        // ホストプロフィール・CKShareのレコードを構築して保存する。まずは画像を
        // 含めて試み、CKError.quotaExceededを検知した場合のみ画像を除いて再試行する。
        do {
            try await saveGroupRecords(group, hostProfile: hostProfile, ownerName: ownerName, zoneID: zoneID, includeImages: true)
        } catch is QuotaExceededDuringImageUpload {
            print("[GroupSync] createGroup: CKError.quotaExceeded(画像アップロード)を検知。画像を除いて再試行します")
            do {
                try await saveGroupRecords(group, hostProfile: hostProfile, ownerName: ownerName, zoneID: zoneID, includeImages: false)
            } catch is QuotaExceededDuringImageUpload {
                // 画像を除いても容量超過になることは無いはずだが、念のため区別せず扱う。
                throw GroupSharingError.quotaExceeded(groupCreatedWithoutImages: false)
            }
            // 画像を除いた再試行が成功 = グループ自体(名前・共有リンク含む)は作成できている。
            throw GroupSharingError.quotaExceeded(groupCreatedWithoutImages: true)
        }
    }

    /// グループ本体・ホストプロフィール・CKShareの3件を保存する。
    ///
    /// 【重要】CKShareを新規作成する場合、そのrootRecordは同じ保存操作
    /// (同じmodifyRecords呼び出し)の中で一緒に保存しなければならない
    /// (CKShareをrootRecordと別の操作で保存すると
    /// 「An added share is being saved without its rootRecord being saved
    /// in the same operation.」というエラーになる、実機で確認済みのCloudKit側の制約)。
    /// そのため、groupRecord/hostProfileRecord/shareの3件は必ず同じ
    /// modifyRecords呼び出しで保存すること(フェーズを分けない)。
    ///
    /// includeImages=falseの場合、グループアイコン/ホストのアバターはCKAssetとして
    /// 含めない(createGroupが容量超過検知後の再試行として呼ぶ)。
    private func saveGroupRecords(
        _ group: LaterGroup,
        hostProfile: UserProfile,
        ownerName: String,
        zoneID: CKRecordZone.ID,
        includeImages: Bool
    ) async throws {
        let groupRecord = group.toCKRecord(existing: nil, ownerName: ownerName, includeIcon: includeImages)
        let share = CKShare(rootRecord: groupRecord)
        share.publicPermission = .readWrite
        share[CKShare.SystemFieldKey.title] = group.name as CKRecordValue

        let hostRecordName = "profile_\(hostProfile.id.uuidString)_\(group.id.uuidString)"
        hostProfile.ckRecordName = hostRecordName
        hostProfile.cloudKitUserRecordName = ownerName
        let hostProfileRecord = hostProfile.toCKRecord(existing: nil, zoneID: zoneID, groupRecordID: groupRecord.recordID, includeAvatar: includeImages)

        let saveResults: [CKRecord.ID: Result<CKRecord, Error>]
        do {
            (saveResults, _) = try await container.privateCloudDatabase.modifyRecords(
                saving: [groupRecord, hostProfileRecord, share],
                deleting: []
            )
        } catch {
            // atomicバッチ全体が(個々のsaveResultsではなく)呼び出し自体としてthrowした場合。
            // ここでも同じ形式でuserInfo[CKPartialErrorsByItemIDKey]を展開し、
            // どのレコードが真因だったかをログへ残す。
            _ = error.loggedDescription(context: "CircleCreateGroupView.createGroup modifyRecords")
            error.logPartialItemErrors()
            if includeImages, error.asQuotaExceededCKError != nil {
                throw QuotaExceededDuringImageUpload()
            }
            throw GroupSharingError.groupCreationFailed(underlying: error, detail: error.rootCausePartialErrorDetail)
        }

        // atomically: true(デフォルト)のバッチでは、3レコードのうち本当の原因になった
        // レコードだけが固有のサブエラーを持ち、無関係だった残りのレコードは軒並み
        // CKError 22 (batchRequestFailed) を受け取る「巻き添え」になる。groupRecordの
        // 結果だけを見て早期returnすると、真因が別レコードにあった場合に特定できなくなる
        // ため、分岐する前に3件すべてをログへ出力しておく。
        let recordLabels: [CKRecord.ID: String] = [
            groupRecord.recordID: "groupRecord(\(AppRecordType.laterGroup))",
            hostProfileRecord.recordID: "hostProfileRecord(\(AppRecordType.userProfile))",
            share.recordID: "share(CKShare)",
        ]
        var quotaExceededDetected = false
        for (recordID, result) in saveResults {
            let label = recordLabels[recordID] ?? recordID.recordName
            switch result {
            case .success:
                print("[GroupSync] createGroup saveResults[\(label), zone=\(recordID.zoneID.zoneName)]: success")
            case .failure(let error):
                _ = error.loggedDescription(context: "[GroupSync] createGroup saveResults[\(label), zone=\(recordID.zoneID.zoneName)]")
                error.logPartialItemErrors()
                if error.asQuotaExceededCKError != nil {
                    quotaExceededDetected = true
                }
            }
        }

        if includeImages, quotaExceededDetected {
            throw QuotaExceededDuringImageUpload()
        }

        // 3件のうち、.batchRequestFailed(22)以外の固有コードを持つレコードこそが
        // 「巻き添え」ではない本当の原因。groupRecord自身の結果だけを見ると、
        // groupRecordがただの巻き添えで実際はhostProfileRecord/shareが原因、という
        // ケースを取り違えるため、分岐前に横断して探しておく。TestFlightなど
        // Xcodeコンソールを見られない環境でも原因を特定できるよう、この結果を
        // 画面表示用メッセージ(detail)にそのまま含める。
        let rootCause = rootCauseDetail(from: saveResults, labels: recordLabels)

        // グループ本体の保存結果を、共有リンク(share)の結果とは独立に確認する。
        // これにより「グループ作成自体が失敗した」のか「グループは保存できたが
        // 共有リンクだけ失敗した」のかを呼び出し側で切り分けられる。
        if case .failure(let groupError) = saveResults[groupRecord.recordID] {
            throw GroupSharingError.groupCreationFailed(underlying: groupError, detail: rootCause)
        }

        // ホストプロフィールの保存結果も明示的に確認する。atomicバッチ(デフォルト)では
        // 理論上groupRecord/shareと運命を共にするはずだが、ここを確認していなかったために
        // 万一失敗していても検知できず、後から参加したメンバー全員がホストを
        // 永久に認識できなくなる(=データが存在しないので、受信側をいくら直しても直らない)
        // という不具合につながっていた。
        if case .failure(let profileError) = saveResults[hostProfileRecord.recordID] {
            throw GroupSharingError.groupCreationFailed(underlying: profileError, detail: rootCause)
        }

        guard case .success(let savedShareRecord) = saveResults[share.recordID] else {
            if case .failure(let shareError) = saveResults[share.recordID] {
                throw GroupSharingError.shareCreationFailed(underlying: shareError, detail: rootCause)
            }
            throw GroupSharingError.shareURLMissing
        }
        guard let savedShare = savedShareRecord as? CKShare, let shareURL = savedShare.url else {
            throw GroupSharingError.shareURLMissing
        }

        // 招待リンクをタップした際にアプリへ直接ルーティングされない問題の切り分け用。
        // CKSharingSupported/entitlements側の設定と、実際に発行されたURLの形式・
        // publicPermission・zoneIDを突き合わせられるようにログへ残す。
        print("""
        GroupSharingService.createGroup: share created
          url = \(shareURL.absoluteString)
          publicPermission = \(savedShare.publicPermission.rawValue)
          recordID = \(savedShare.recordID)
          zoneID = \(zoneID)
          containerIdentifier = \(container.containerIdentifier ?? "nil")
          includeImages = \(includeImages)
        """)

        group.ownerCloudKitUserRecordName = ownerName
        group.ckRecordName = groupRecord.recordID.recordName
        group.ckZoneName = zoneID.zoneName
        group.ckZoneOwnerName = zoneID.ownerName
        group.ckShareURL = shareURL.absoluteString

        hostProfile.ckZoneName = zoneID.zoneName
        hostProfile.ckZoneOwnerName = zoneID.ownerName

        try modelContext.save()
    }

    /// saveResultsの中から、.batchRequestFailed(22)以外の固有コードを持つ(=巻き添えでない)
    /// 本当の原因レコードを1件だけ拾って人間可読な文字列にする。全レコードがbatchRequestFailed
    /// だった場合(真因のレコード自体もこのバッチのAPI経由では固有コードを返さなかった場合)はnil。
    private func rootCauseDetail(
        from saveResults: [CKRecord.ID: Result<CKRecord, Error>],
        labels: [CKRecord.ID: String]
    ) -> String? {
        for (recordID, result) in saveResults {
            guard case .failure(let error) = result, let ckError = error as? CKError, ckError.code != .batchRequestFailed else { continue }
            let label = labels[recordID] ?? recordID.recordName
            return "\(label): CKError \(ckError.code.rawValue)(\(ckError.code)) \(ckError.localizedDescription)"
        }
        return nil
    }

    /// 招待リンクのURL文字列(later://join?shareUrl=...から取り出したCKShare URLなど)から
    /// CKShare.Metadataを解決する。リンクを直接タップした場合(AppDelegate経由)は既に
    /// Metadataが得られるためこのメソッドは使わない — URL文字列だけを持っている場合に使う。
    func resolveShareMetadata(shareURLString: String) async throws -> CKShare.Metadata {
        guard let shareURL = URL(string: shareURLString) else {
            throw GroupSharingError.shareURLMissing
        }
        let metadatas = try await container.shareMetadatas(for: [shareURL])
        guard case .success(let metadata) = metadatas[shareURL] else {
            if case .failure(let error) = metadatas[shareURL] {
                throw GroupSharingError.acceptFailed(underlying: error)
            }
            throw GroupSharingError.acceptFailed()
        }
        return metadata
    }

    /// group.ckShareURLはCKRecordに同期されないローカルキャッシュのため、ホストが
    /// 別端末で開いた場合などは空になっている。その場合はPrivate DBのルートレコードから
    /// 既存のCKShareを辿って取り直す(ホスト=このゾーンのオーナーの端末でのみ成功する)。
    /// ホスト・非ホストどちらの端末から呼んでも動くよう、実際のゾーン所有者かどうかで
    /// 参照するデータベースを切り替える(leaveGroupと同じ理由: アプリ内の「現在ホスト役か」
    /// (ownerCloudKitUserRecordName基準のisHost)はホスト引き継ぎで変わり得るが、
    /// CloudKit上の実際のゾーン所有者(zoneID.ownerName)は不変で、これを基準にしないと
    /// 誤ったDBへアクセスして"Only shared zones can be accessed in the shared DB"等の
    /// エラーになる。取得できたURLはgroup.ckShareURLへローカルキャッシュするため、
    /// 次回以降は非ホストの端末でも再フェッチ無しで使える。
    func fetchOrCreateShareURL(for group: LaterGroup) async throws -> URL {
        if let cached = group.ckShareURL, let url = URL(string: cached) {
            return url
        }

        guard let recordID = group.cachedRecordID else {
            throw GroupSharingError.shareURLMissing
        }

        let isActualZoneOwner = recordID.zoneID.ownerName == cloudKitManager.currentUserRecordName
        let database = isActualZoneOwner ? container.privateCloudDatabase : container.sharedCloudDatabase

        let record = try await database.record(for: recordID)
        guard let shareReference = record.share else {
            throw GroupSharingError.shareURLMissing
        }

        let shareRecord = try await database.record(for: shareReference.recordID)
        guard let share = shareRecord as? CKShare, let url = share.url else {
            throw GroupSharingError.shareURLMissing
        }

        group.ckShareURL = url.absoluteString
        try? modelContext.save()
        return url
    }

    /// 招待リンクを直接タップして受け取ったCKShare.Metadataを受け入れる。
    /// AppDelegate/SceneDelegateのuserDidAcceptCloudKitShareWithからShareInviteInbox経由で
    /// 呼ばれる。CKAcceptSharesOperationを直接使い、コンテナID・共有元・結果を
    /// [GroupSync]プレフィックス付きでログへ残す(招待リンクのルーティング問題の切り分け用)。
    func acceptShare(metadata: CKShare.Metadata) async throws {
        // システム上限のチェック。CKAcceptSharesOperationを呼ぶ前に確認することで、
        // 上限超過時はCloudKit側の共有状態(参加者リスト)に一切触れずに拒否できる。
        // 呼び出し側(RootView.handleGroupJoinLink)には「既に参加済みなら受諾処理を
        // 再実行しない」既存のガードがあるため、ここに到達する時点で新規参加である
        // ことが前提。ただしCKShare直接タップ経由(ShareInviteInbox)はその既存ガードを
        // 通らないため、既存メンバーの再受諾では以下の判定が誤って発火しないよう、
        // 「参加人数」はメンバー追加前の値、「所属グループ数」も追加前の値で判定する
        // (どちらも自分が既にカウントされている場合は上限に余裕がある状態のまま)。
        if let currentUser = UserProfile.current(from: (try? modelContext.fetch(FetchDescriptor<UserProfile>())) ?? []) {
            let joinedGroupCount = currentUser.groups.filter { !$0.isPersonalSpace }.count
            guard joinedGroupCount < GroupMembershipPolicy.maxGroupsPerUser else {
                print("[GroupSync] acceptShare中断: 所属グループ数の上限(\(GroupMembershipPolicy.maxGroupsPerUser))に到達済み")
                throw GroupSharingError.tooManyGroups
            }
        }
        guard metadata.share.participants.count < GroupMembershipPolicy.maxMembersPerGroup else {
            print("[GroupSync] acceptShare中断: グループの人数上限(\(GroupMembershipPolicy.maxMembersPerGroup))に到達済み")
            throw GroupSharingError.groupFull
        }

        let ownerName = metadata.ownerIdentity.nameComponents?.formatted()
            ?? metadata.ownerIdentity.userRecordID?.recordName
            ?? "unknown"
        print("[GroupSync] Accept Share started for URL: \(metadata.share.url?.absoluteString ?? "unknown")")
        print("""
        [GroupSync] acceptShare開始
          containerIdentifier = \(metadata.containerIdentifier)
          owner = \(ownerName)
          rootRecordID = \(String(describing: metadata.hierarchicalRootRecordID))
          share.url = \(metadata.share.url?.absoluteString ?? "nil")
        """)

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
                operation.qualityOfService = .userInitiated

                operation.perShareResultBlock = { shareMetadata, result in
                    switch result {
                    case .success(let share):
                        print("[GroupSync] perShareResult success: shareRecordID = \(share.recordID), zoneID = \(share.recordID.zoneID)")
                    case .failure(let error):
                        _ = error.loggedDescription(context: "[GroupSync] perShareResult failure")
                    }
                }

                operation.acceptSharesResultBlock = { result in
                    switch result {
                    case .success:
                        print("[GroupSync] CKAcceptSharesOperation 全体success")
                        continuation.resume()
                    case .failure(let error):
                        _ = error.loggedDescription(context: "[GroupSync] CKAcceptSharesOperation 全体failure")
                        continuation.resume(throwing: error)
                    }
                }

                container.add(operation)
            }
        } catch {
            throw GroupSharingError.acceptFailed(underlying: error)
        }
        print("[GroupSync] Successfully joined shared zone. RecordID: \(String(describing: metadata.hierarchicalRootRecordID))")

        // CKSyncEngine.fetchChanges()(fetchSharedChangesNow)はイベント駆動・内部キュー経由の
        // うえ、検索/インデックスベースの経路を通ることがあり、受諾直後の呼び出しでは
        // サーバー側の伝播タイミング次第でまだ拾えないことがある。ここでは3段構えで、
        // 「acceptShareがreturnする時点で必ずローカルにグループが存在する」状態を保証する。
        if let rootRecordID = metadata.hierarchicalRootRecordID {
            // 1. rootRecordIDをピンポイントで直接フェッチする(record(for:)はID指定の
            //    直接取得のため、検索インデックスの更新を待たず即座に返る)。
            do {
                print("[GroupSync] rootRecordの直接フェッチ開始: \(rootRecordID)")
                let rootRecord = try await container.sharedCloudDatabase.record(for: rootRecordID)
                await cloudKitManager.applyRecordImmediately(rootRecord)
                print("[GroupSync] rootRecordの直接フェッチ成功")
            } catch {
                _ = error.loggedDescription(context: "[GroupSync] rootRecordの直接フェッチ失敗")
            }

            // 2. 同じゾーンの残り(メンバープロフィール・写真など)もあわせて反映しておく。
            print("[GroupSync] 対象ゾーンの即時フェッチ開始: \(rootRecordID.zoneID)")
            await cloudKitManager.fetchAndApplyZoneImmediately(zoneID: rootRecordID.zoneID)
            print("[GroupSync] 対象ゾーンの即時フェッチ完了")

            // 3. 1・2のいずれでもまだローカルに反映されていない場合の最終手段として、
            //    metadataから分かる範囲(共有タイトル)だけでグループを仮作成し、
            //    タイムアウトアラートを出さずに済むようにする(実データは後続の同期で
            //    上書きされる。ensurePlaceholderGroup自身が「既に存在すれば何もしない」
            //    ガードを持つため、1・2で既に反映済みならここは実質no-op)。
            await cloudKitManager.ensurePlaceholderGroup(rootRecordID: rootRecordID, metadata: metadata)
        }

        print("[GroupSync] fetchSharedChangesNow呼び出し開始")
        await cloudKitManager.fetchSharedChangesNow()

        print("[GroupSync] acceptShare完了")
    }

    /// 参加後、自分自身のUserProfileをこのグループの共有ゾーンにもアップロードする。
    /// (accept直後はまだローカルにgroup/zone情報が無いため、ローカル反映を待ってから呼ぶ)
    /// markForUploadはCKSyncEngineのキューにローカルで積むだけで送信は保証しないため、
    /// ここで必ずsendPendingChangesNow()まで行う。以前は呼び出し側(合言葉参加/QR参加の
    /// CircleManagementView)がこれを呼び忘れており、「参加しました」の表示直後にアプリを
    /// 閉じると自分のプロフィールが永久にサーバーへ届かないことがあった。
    ///
    /// group.myProfileCKRecordChangeTagが既にある(=「このグループ」への送信成功が確認済み、
    /// CloudKitManager.markSynced参照)場合は何もしない。呼び出し元
    /// (GroupDetailView/GroupHomeDetailView.ensureOwnMembershipIsSynced)は
    /// 画面表示中3秒おきに無条件でこれを呼んでいたため、ガードが無いと
    /// 「送るたびにchangeTagが更新されないので毎回サーバーには新規挿入に見える→
    /// 直前の送信成功分と衝突→競合リカバリで復旧→3秒後にまた送る」を無限に
    /// 繰り返してしまっていた。
    ///
    /// このタグは(UserProfile側ではなく)グループ自身に持たせている。UserProfileは
    /// ユーザーごとに1つのローカルオブジェクトである一方、複数グループに参加すると
    /// グループごとに別々のCKRecordを送信する必要があるため、UserProfile側の
    /// 単一フィールドで管理すると「別グループへの送信成功」が「このグループへの
    /// 送信済み」と誤判定され、新しく参加したグループにはプロフィールが一度も
    /// 送信されなくなる(詳細はLaterGroup.myProfileCKRecordChangeTagのコメント参照)。
    ///
    /// group.myProfileCKRecordChangeTagがnilのまま(=このグループへの到達が一度も
    /// 確認できていない、新規参加したグループを含む)場合は、過去のビルドで初回
    /// アップロードだけが検知されずに欠落したケースの自己修復のため、これまで通り
    /// 毎回送信を試みる。プロフィールの実際の編集(名前/bio等)はProfileView側が
    /// cloudKitManager.markForUpload(userProfile:in:)を直接呼ぶ別経路のため、
    /// このガードの影響を受けない。
    func uploadOwnProfile(_ profile: UserProfile, to group: LaterGroup) async {
        guard group.myProfileCKRecordChangeTag == nil else {
            print("[GroupSync] uploadOwnProfile: 既に同期済みのため再送をスキップ (group=\(group.name))")
            return
        }
        cloudKitManager.markForUpload(userProfile: profile, in: group)
        await cloudKitManager.sendPendingChangesNow()
        print("[GroupSync] Uploaded own profile and forced send for group \(group.name)")
    }

    private static func inviteRecordName(joinCode: String) -> String {
        "invite_\(joinCode)"
    }

    /// グループから脱退する。CloudKitのCKRecordZoneはオーナー(作成者)のiCloudアカウントから
    /// 動かせないため、ホストが脱退しても他に残るメンバーがいれば「アプリ内のホスト権限」
    /// (招待リンク発行・ホストバッジ)だけを自動的に他の1人へ引き継ぎ、ゾーン自体は
    /// 元ホストのアカウントに残したまま(他メンバーは引き続きShared DB経由でアクセスできる)
    /// 脱退処理を行う。残るメンバーが誰もいない(最後の1人が脱退する)場合のみ、
    /// グループを丸ごと削除する。
    /// ローカルのLaterGroup(SwiftData)は呼び出し側で削除すること
    /// (photosはdeleteRule: .cascadeのため自動的に一緒に消える)。
    func leaveGroup(_ group: LaterGroup, currentUser: UserProfile, isHost: Bool) async throws {
        let remainingMembers = group.members.filter { $0.id != currentUser.id }

        // 残るメンバーがいる場合、ホスト権限を先に引き継いでおく(このあと自分の
        // プロフィールレコードを削除しても、グループ本体レコードには影響しないため
        // 順序は問わないが、失敗時にホスト不在のまま残らないよう先に行う)。
        if isHost, let newHost = remainingMembers.first {
            group.host = newHost
            group.ownerCloudKitUserRecordName = newHost.cloudKitUserRecordName
        }

        guard let zoneID = group.cachedZoneID else {
            // ゾーン情報がローカルに無い(CloudKitへ一度も同期されていない)場合は、
            // サーバー側で消す/更新すべきものが無いのでローカル処理だけで完了とみなす。
            return
        }

        // isHost(アプリ内の「現在ホスト役を持っているか」、ownerCloudKitUserRecordName基準)は
        // 脱退のたびに次のメンバーへ引き継がれるが、CloudKitのゾーン所有権自体は
        // ゾーンを最初に作成したユーザーに物理的に固定されたまま変わらない
        // (zoneID.ownerNameが不変の実際の所有者)。isHostを使ってPrivate/Shared DBの
        // どちらにアクセスするかを決めていると、ホスト引き継ぎ後の新ホストが
        // 「アプリ上はホストだが実際のゾーン所有者ではない」状態になり、
        // 誤ったDBへアクセスして"Only shared zones can be accessed in the shared DB"
        // 等のエラーで脱退そのものが失敗する不具合があった。実際のゾーン所有者かどうかは
        // zoneID.ownerNameとCloudKitManager.currentUserRecordNameを直接比較して判定する
        // (こちらはローカルのUserProfileの重複等の影響を受けない、常に正しい値)。
        let isActualZoneOwner = zoneID.ownerName == cloudKitManager.currentUserRecordName

        do {
            if isActualZoneOwner && remainingMembers.isEmpty {
                // 最後の1人としての脱退 = グループごと削除。ゾーンが既に(何らかの理由で)
                // 存在しない場合は、削除すべきものが既に無いというだけなので脱退自体は
                // 成功として扱う(下のcatchで.zoneNotFoundを許容している)。
                _ = try await container.privateCloudDatabase.modifyRecordZones(saving: [], deleting: [zoneID])
                if !group.inviteCode.isEmpty {
                    let recordID = CKRecord.ID(recordName: Self.inviteRecordName(joinCode: group.inviteCode))
                    _ = try? await container.publicCloudDatabase.deleteRecord(withID: recordID)
                }
                return
            }

            // 自分のプロフィールレコードだけを削除して、他メンバーへ脱退を伝える
            // (CloudKitManager.applyDeletionがAppRecordType.userProfileの削除を検知して
            // 各メンバーのローカルのgroup.membersから外す)。実際のゾーン所有者は自分の
            // Private DB、それ以外(アプリ上はホストでも実ゾーン所有者ではない場合を含む)は
            // 自分のShared DBから削除する。
            // currentUser.cachedRecordID(UserProfile側の単一フィールド由来)は使わない:
            // UserProfileは複数グループにまたがる単一のローカルオブジェクトのため、
            // このフィールドは「最後に見た1つのグループ」の値しか保持できず、
            // 脱退しようとしている「この」グループの値とは限らない
            // (uploadOwnProfile/markForUploadと同じ理由。誤った/存在しないレコードを
            // 削除しようとして失敗する、または無関係なグループのレコードを消してしまう
            // おそれがあった)。recordNameは決定論的に組み立てられるため、このグループの
            // zoneIDと組み合わせて直接計算する。
            let profileRecordID = CKRecord.ID(recordName: "profile_\(currentUser.id.uuidString)_\(group.id.uuidString)", zoneID: zoneID)
            let database = isActualZoneOwner ? container.privateCloudDatabase : container.sharedCloudDatabase
            _ = try await database.deleteRecord(withID: profileRecordID)

            // ホストを引き継いだ場合は、更新後のownerCloudKitUserRecordNameを
            // 他メンバーにも反映させるため、グループ本体レコードも再アップロードする。
            if isHost {
                cloudKitManager.markForUpload(group: group)
            }
        } catch let ckError as CKError where ckError.code == .zoneNotFound || ckError.code == .unknownItem {
            // ゾーンやレコードがサーバー側に既に存在しない(例えばホストが先にグループごと
            // 削除していた等)場合は、削除すべきものが既に無いだけなので、脱退自体は
            // 成功として扱ってよい。ここでエラーにしてしまうと、ユーザーが脱退したくても
            // 一切脱退できなくなってしまう(「グループから脱退できない」不具合の原因だった)。
            print("[GroupSync] leaveGroup: サーバー側に対象が既に存在しないため削除をスキップし、脱退を続行します: \(ckError)")
        } catch {
            _ = error.loggedDescription(context: "GroupSharingService.leaveGroup(isHost: \(isHost))")
            error.logPartialItemErrors()
            throw GroupSharingError.deleteFailed(underlying: error)
        }
    }
}
