//
//  CloudKitManager.swift
//  Later 再度
//
//  CKSyncEngineを2系統(Private DB / Shared DB)保持し、SwiftDataとの
//  相互反映を行う。オーナーとして作ったグループはPrivate DB、招待されて
//  参加したグループはShared DBに属するため、両方を監視する必要がある。

import CloudKit
import Foundation
import SwiftData
import os

@MainActor
final class CloudKitManager: NSObject {
    static let containerIdentifier = "iCloud.jp.shotoku.later"

    /// AppDelegate(UIKit側のリモート通知コールバック)からアクセスするための参照。
    static weak var current: CloudKitManager?

    let container: CKContainer
    private let modelContext: ModelContext

    private(set) var currentUserRecordName: String?

    private var privateEngine: CKSyncEngine?
    private var sharedEngine: CKSyncEngine?

    /// サーバーとの競合(CKError.serverRecordChanged、コード14/2004「record to insert
    /// already exists」等)が検知されたrecordIDについて、サーバー側の最新レコード
    /// (CKError.serverRecord、正しいrecordChangeTagを持つ)を一時的に保持する。
    /// buildRecord(for:)がこれを見つけた場合、ゼロから新規レコードを作る代わりに
    /// このレコードへフィールドを上書きして再送することで、「新規挿入」ではなく
    /// 「更新」としてサーバーに送れるようにする。再インストール等でローカルの
    /// ckRecordChangeTagとCKSyncEngineの同期状態を両方失った場合、ローカルは
    /// レコードが既に存在することを知らずに新規挿入として送ってしまい、
    /// サーバー側に同名レコードが残っていると競合エラーになる
    /// (このプロパティはその1回限りの取り違えを次の再送で正すためのもの)。
    private var conflictServerRecords: [CKRecord.ID: CKRecord] = [:]

    /// 一時的なエラー(ネットワーク不調等)でのリトライ回数をrecordIDごとに記録する。
    /// 1回目の失敗時は即時リトライ、2回目以降はretryDelays(30秒→2分→10分)の間隔を
    /// 空けて再試行し、それでも失敗し続ける場合はこの即時系の仕組みでの再試行を諦め、
    /// resendOwnUnlockedPhotosIfNeeded()(フォアグラウンド復帰時・画面ポーリング時の
    /// 定期的な再送保険)に委ねる。保存成功時にクリアする。
    private var retryAttemptCounts: [CKRecord.ID: Int] = [:]
    private static let retryDelays: [TimeInterval] = [30, 120, 600]

    /// resendOwnUnlockedPhotosIfNeeded()を最後に実際に実行した時刻。フォアグラウンド復帰時
    /// だけでなく画面の3秒ポーリングからも呼ばれるようになったため、無駄な連続実行を
    /// 防ぐために最低間隔を設ける。
    private var lastResendSweepDate: Date?
    private static let resendSweepMinInterval: TimeInterval = 60
    /// #Predicateでの絞り込みが万一SQLiteレベルで効いていなかった場合でも、1回の
    /// スイープで処理する件数の上限を頭打ちにしておく安全策。理論上一度に再送が
    /// 必要になる件数はごく少数のはずなので、この上限に達すること自体が異常な
    /// 兆候(絞り込みが効いていない等)の手がかりになる。
    private static let resendSweepFetchLimit = 200

    /// migrateChekiGradingForOwnPhotos()の多重実行(プロセス内での再入)防止用。
    /// 既に焼き込み済みの写真を対象から除外する冪等性自体はLaterPhoto.isColorGraded
    /// フラグが保証するが、それとは別に「今まさに処理中のバッチ」が重複して
    /// 起動しないようにするための軽量なガード。
    private var isMigratingChekiGrading = false

    /// CKSyncEngineからの変更通知(apply(record:)経由)、または既知のローカル操作
    /// (自分の投稿直後等)によって「再評価が必要かもしれない」とマークされたグループの
    /// ID集合。evaluateGroupUnlockConditions()はこの集合に含まれるグループだけを処理し、
    /// 処理し終えたらクリアする(グループ数に比例して3秒ポーリングが重くなる問題への対応。
    /// 変化の無いグループは毎回re-evaluateしない)。
    ///
    /// resendOwnUnlockedPhotosIfNeeded()は、この集合を消費すると早い者勝ちで空になって
    /// しまいevaluateGroupUnlockConditions()と互いに飢餓状態になるため、独立した
    /// 「前回の処理以降に何か変化があったか」の真偽値(hasPendingChangeForResendSweep)を
    /// 別途持つ。どちらも同じmarkGroupDirty(_:)からまとめて更新される、同じ
    /// 「変化があった」イベントの独立した購読者という位置づけ。
    private var dirtyGroupIDs: Set<UUID> = []
    private var hasCompletedInitialGroupEvaluation = false
    private var hasPendingChangeForResendSweep = false

    /// 1件のCKRecordの反映(apply(record:)経由)、またはローカルでの既知の変更
    /// (PostTargetGroupSelectionView.submitPost等)によって、このグループに関係する
    /// 状態が変わった可能性があることを記録する。実際に変化があった場合の反映が
    /// 遅れることのないよう、CKSyncEngineの変更通知およびローカルの直接操作の
    /// どちらからも確実に呼ぶこと。
    func markGroupDirty(_ groupID: UUID?) {
        guard let groupID else { return }
        dirtyGroupIDs.insert(groupID)
        hasPendingChangeForResendSweep = true
    }

    private static let privateStateFileName = "ck_sync_state_private.json"
    private static let sharedStateFileName = "ck_sync_state_shared.json"
    private static let privateSubscriptionID = "later2-private-db-subscription"
    private static let sharedSubscriptionID = "later2-shared-db-subscription"

    init(modelContext: ModelContext) {
        self.container = CKContainer(identifier: Self.containerIdentifier)
        self.modelContext = modelContext
        super.init()
    }

    /// サインイン後に一度だけ呼ぶ。CKSyncEngineの起動と自動同期の開始を行う。
    func start() async {
        do {
            currentUserRecordName = try await container.userRecordID().recordName
        } catch {
            print("CloudKitManager: failed to fetch userRecordID: \(error)")
        }

        // 自分のUserProfile.cloudKitUserRecordNameをできるだけ早く(サインイン直後に)
        // 確定させておく。以前はグループを作成/参加するまでこのフィールドがnilのままで、
        // その状態でUserDirectory(Public DB)へpublishされると、相手側が本当のiCloud
        // 識別子を解決できない「プロフィール未同期」状態になっていた。
        if let currentUserRecordName, let user = UserProfile.current(from: (try? modelContext.fetch(FetchDescriptor<UserProfile>())) ?? []) {
            if user.cloudKitUserRecordName != currentUserRecordName {
                user.cloudKitUserRecordName = currentUserRecordName
                try? modelContext.save()
            }
            await UserDirectoryService.publish(user)
        }

        if let currentUserRecordName {
            await PhotoNotificationService.setupNotificationSubscriptions(for: currentUserRecordName, container: container)
        }

        // 起動のたびに一度、既存の壊れたデータ(同一人物の重複UserProfileが
        // group.membersに混入している状態)を解消する。addMember(_:)/isMember(_:)側の
        // 修正は「これから新たに重複が発生すること」は防ぐが、過去に既に重複してしまった
        // データはこの端末のローカルストアに残ったままのため、別途マイグレーションが必要。
        deduplicateGroupMembers()

        var privateConfig = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: Self.loadState(fileName: Self.privateStateFileName),
            delegate: self
        )
        privateConfig.subscriptionID = Self.privateSubscriptionID
        privateEngine = CKSyncEngine(privateConfig)

        var sharedConfig = CKSyncEngine.Configuration(
            database: container.sharedCloudDatabase,
            stateSerialization: Self.loadState(fileName: Self.sharedStateFileName),
            delegate: self
        )
        sharedConfig.subscriptionID = Self.sharedSubscriptionID
        sharedEngine = CKSyncEngine(sharedConfig)

        Self.current = self

        // 「解禁時に一度だけチェキ加工を焼き込む」仕組みの導入前から既に解禁済みだった
        // 自分の写真を遡って焼き込む。件数次第で時間がかかり得るため、start()自体を
        // 待たせないよう独立したTaskとして起動する(deduplicateGroupMembers()と違い
        // Core Image処理を伴うため、CKSyncEngineの初期化完了を待たせたくない)。
        Task { [weak self] in
            await self?.migrateChekiGradingForOwnPhotos()
        }
    }

    /// グループ参加直後など、すぐにShared DBの内容を反映させたい場合に呼ぶ。
    func fetchSharedChangesNow() async {
        try? await sharedEngine?.fetchChanges()
    }

    /// fetchSharedChangesNow()のPrivate DB版。自分がホストのグループで他メンバーの
    /// 更新(新規参加のプロフィール、撮影された写真等)をすぐに反映させたい場合に呼ぶ。
    func fetchPrivateChangesNow() async {
        try? await privateEngine?.fetchChanges()
    }

    /// markForUpload等でキューに入れた保留中のローカル変更を、CKSyncEngine自身の
    /// スケジューリングを待たずに即座に送信する。グループ参加直後、自分のプロフィール
    /// レコードをできるだけ早く他メンバーへ見せたい場合などに呼ぶ。
    func sendPendingChangesNow() async {
        try? await privateEngine?.sendChanges()
        try? await sharedEngine?.sendChanges()
    }

    /// CKShare受諾の直後など、CKSyncEngineの通常の変更検知(イベント駆動・内部キュー経由)を
    /// 待たずに、指定ゾーンの現在の全レコードを直接フェッチしてローカルへ即座に反映する。
    /// fetchSharedChangesNow()(=sharedEngine.fetchChanges())はサーバー側の伝播タイミング
    /// によっては受諾直後にはまだそのゾーンを拾えないことがあるため、CKShare受諾で
    /// 判明済みのzoneIDを名指しでCKFetchRecordZoneChangesOperationに渡し、
    /// 同期エンジンの状態(変更トークン等)とは独立に一度だけ取得する。
    func fetchAndApplyZoneImmediately(zoneID: CKRecordZone.ID) async {
        print("[GroupSync] fetchAndApplyZoneImmediately開始: zoneID=\(zoneID)")
        let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: config]
        )
        operation.qualityOfService = .userInitiated

        var fetchedRecords: [CKRecord] = []
        operation.recordWasChangedBlock = { _, result in
            if case .success(let record) = result {
                fetchedRecords.append(record)
            }
        }

        // ゾーンの所有者が自分自身(=ホストとして作ったグループ)ならPrivate DB、
        // そうでなければ(=招待されて参加したグループ)Shared DBを見る必要がある。
        // 以前はShared DBに決め打ちしていたため、ホスト自身がこれを呼んでも
        // 自分のPrivate DBにあるゾーンは見つからず何も反映されなかった
        // (GroupSharingService.swiftの既存パターンに合わせる)。
        let database = zoneID.ownerName == currentUserRecordName
            ? container.privateCloudDatabase
            : container.sharedCloudDatabase

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            operation.fetchRecordZoneChangesResultBlock = { result in
                if case .failure(let error) = result {
                    _ = error.loggedDescription(context: "CloudKitManager.fetchAndApplyZoneImmediately(zoneID: \(zoneID))")
                }
                continuation.resume()
            }
            database.add(operation)
        }

        guard !fetchedRecords.isEmpty else {
            print("[GroupSync] fetchAndApplyZoneImmediately完了: 0件(サーバー側にまだ何も反映されていないか、既に最新)")
            return
        }
        // applyFetchedChangesと同じ理由でLaterGroupを先に適用する。
        let orderedRecords = fetchedRecords.sorted { lhs, rhs in
            let lhsIsGroup = lhs.recordType == AppRecordType.laterGroup
            let rhsIsGroup = rhs.recordType == AppRecordType.laterGroup
            return lhsIsGroup && !rhsIsGroup
        }
        // applyFetchedChangesの内訳ログと同じ形式。fetchAndApplyZoneImmediately経由
        // (GroupDetailView/GroupHomeDetailViewの3秒ポーリング)でも、実際にどのレコード
        // タイプが何件取得できているかをここで可視化する。
        var typeCounts: [String: Int] = [:]
        for record in orderedRecords {
            typeCounts[record.recordType, default: 0] += 1
        }
        let breakdown = typeCounts.map { "\($0.key) x\($0.value)" }.joined(separator: ", ")
        print("[GroupSync] fetchAndApplyZoneImmediately内訳: \(breakdown)")

        for record in orderedRecords {
            if record.recordType == AppRecordType.userProfile {
                print("[GroupSync] fetchAndApplyZoneImmediately: UserProfile受信 recordName=\(record.recordID.recordName), group参照=\(String(describing: record["group"]))")
            }
            apply(record: record)
        }
        try? modelContext.save()
        await evaluateGroupUnlockConditions()
        print("[GroupSync] fetchAndApplyZoneImmediately完了: \(fetchedRecords.count)件取得・適用")
        if let group = fetchOne(LaterGroup.self, { $0.cachedZoneID == zoneID }) {
            print("[GroupSync] メンバー確認: グループ\(group.name)は現在\(group.members.count)人 [\(group.members.map(\.name).joined(separator: ", "))]")
        }
    }

    /// 1件のCKRecordを直接ローカルへ反映する。CKShare受諾直後、metadataから判明済みの
    /// rootRecordIDをsharedCloudDatabase.record(for:)でピンポイント取得した結果を
    /// 即座に反映する用途(ゾーン全体のfetch/検索インデックスの更新を待たない、
    /// 最速でグループ本体だけを画面に出すための経路)。
    func applyRecordImmediately(_ record: CKRecord) async {
        apply(record: record)
        try? modelContext.save()
    }

    /// CKShare受諾直後、rootRecordの直接フェッチ・ゾーン全体のフェッチのいずれにも
    /// (まだ)成功しなかった場合の最終フォールバック。CKShare.Metadataから分かる範囲
    /// (共有タイトル=グループ名、rootRecordIDのUUID)だけでローカルにグループを仮作成し、
    /// タイムアウトアラートを出さずに画面へ即座に反映できるようにする。
    /// 実データは後続の同期(次回のfetchSharedChangesNow/CKSyncEngineの通常フロー)で
    /// upsertGroup(from:)が同じckRecordNameを見つけ次第、この仮グループへ上書きされる
    /// (二重に作られることはない)。
    func ensurePlaceholderGroup(rootRecordID: CKRecord.ID, metadata: CKShare.Metadata) async {
        let recordName = rootRecordID.recordName
        guard fetchOne(LaterGroup.self, { $0.ckRecordName == recordName }) == nil else { return }
        guard let id = UUID(uuidString: recordName) else { return }

        let name = (metadata.share[CKShare.SystemFieldKey.title] as? String) ?? "グループ"
        let placeholder = LaterGroup(name: name)
        placeholder.id = id
        placeholder.ckRecordName = recordName
        placeholder.ckZoneName = rootRecordID.zoneID.zoneName
        placeholder.ckZoneOwnerName = rootRecordID.zoneID.ownerName
        modelContext.insert(placeholder)
        try? modelContext.save()
        print("CloudKitManager.ensurePlaceholderGroup: プレースホルダーを作成 (\(name))")
    }

    /// CKSubscriptionからのリモート通知(プッシュ)を受けて呼ばれる。
    func handleRemoteNotification() async {
        try? await privateEngine?.fetchChanges()
        try? await sharedEngine?.fetchChanges()
    }

    /// 自分が撮影した写真のうち、既にisUnlocked=trueになっている直近数日分を、
    /// 念のため無条件で再送キューへ積み直す。evaluateGroupUnlockConditions()は
    /// 「isUnlockedがfalse→trueに変わったその瞬間」にしかmarkForUploadを呼ばないため、
    /// その一度きりの送信が(競合以外の理由で)失敗すると、以降誰も再送を試みず、
    /// 画像(CKAsset)だけが他メンバーへ永久に届かなくなる不具合があった
    /// (isUnlockedはisUnlocked自体を持たない受信側でも各自の判定で独立にtrueへ
    /// 変わるため、「相手のisUnlockedがtrueに見える」ことと「画像が実際に届いている」
    /// ことは別の事象になり得る)。
    ///
    /// 以前はアプリがフォアグラウンドに戻るたびにしか呼ばれず、撮影者本人が一度も
    /// アプリを開き直さないと永久に再送されない問題があったため、現在は各画面の
    /// 3秒ポーリング(GroupHomeDetailView等)からも毎回呼んでよい設計にしている。
    /// その代わり、実際のスイープ処理(SwiftData全件フェッチ+enqueue)は
    /// resendSweepMinInterval(60秒)に1回だけに間引く。CKSyncEngine自体は
    /// 既に最新のレコードに対する再送を安全に無視するため、この間引きは
    /// 「無駄なCPU/フェッチを減らすため」だけの最適化であり、間引かなくても実害はない。
    func resendOwnUnlockedPhotosIfNeeded() async {
        guard let currentUserRecordName else { return }
        let isFirstRun = lastResendSweepDate == nil
        if let lastResendSweepDate, Date().timeIntervalSince(lastResendSweepDate) < Self.resendSweepMinInterval {
            return
        }
        // dirtyGroupIDsとは独立した「前回のスイープ以降に何か変化があったか」だけを見る
        // (evaluateGroupUnlockConditionsが同じイベント発のdirtyGroupIDsを消費・クリア
        // してしまうため、共有すると60秒間隔のこちらが常に空振りになる)。初回は
        // 取りこぼしを防ぐため無条件で実行する。
        guard isFirstRun || hasPendingChangeForResendSweep else {
            print("[GroupSync] 画像再送保険: 変化なしのためスキップ")
            return
        }
        hasPendingChangeForResendSweep = false
        lastResendSweepDate = Date()

        guard let cutoff = Calendar.current.date(byAdding: .day, value: -2, to: Date()) else { return }

        // 以前は全LaterPhotoをfetchしてからコード側で(isUnlocked/自分が撮影者か/
        // captureDate)をフィルタしており、端末に溜まった写真の総数(グループ数が
        // 増えるほど増加する)に比例して所要時間が伸びていた。#PredicateでDB側に
        // 絞り込み条件を渡すことで、「解禁済み・自分が撮影者・画像まだ未アップロード・
        // 直近2日以内」に一致する行だけを取得する(判定条件自体は変更していない)。
        // さらに、絞り込みが万一SQLiteレベルで効いていなかった場合の安全策として
        // fetchLimitを設け、古いものを優先するsortDescriptorと組み合わせる。
        let recordName = currentUserRecordName
        let fetchToken = PerformanceSignpost.begin("CloudKitManager.fetchAllPhotos(resendSweep)")
        var descriptor = FetchDescriptor<LaterPhoto>(
            predicate: #Predicate<LaterPhoto> { photo in
                photo.isUnlocked
                    && !photo.isImageUploaded
                    && photo.authorCloudKitUserRecordName == recordName
                    && photo.captureDate >= cutoff
            },
            sortBy: [SortDescriptor(\.captureDate, order: .forward)]
        )
        descriptor.fetchLimit = Self.resendSweepFetchLimit
        guard let candidatePhotos = try? modelContext.fetch(descriptor) else {
            PerformanceSignpost.end("CloudKitManager.fetchAllPhotos(resendSweep)", fetchToken, detail: "失敗")
            return
        }
        PerformanceSignpost.end("CloudKitManager.fetchAllPhotos(resendSweep)", fetchToken, detail: "件数=\(candidatePhotos.count)")
        if candidatePhotos.count == Self.resendSweepFetchLimit {
            print("[GroupSync] 画像再送保険: fetchLimit(\(Self.resendSweepFetchLimit))に到達。絞り込みが効いていない可能性、または想定より対象が多い状態です。古いものから処理し、残りは次回以降のスイープで処理します")
        }

        var candidates: [(photo: LaterPhoto, group: LaterGroup)] = []
        for photo in candidatePhotos {
            guard let groupID = photo.groupID, let group = fetchOne(LaterGroup.self, { $0.id == groupID }) else { continue }
            candidates.append((photo, group))
        }

        print("[GroupSync] 画像再送保険: 対象\(candidates.count)件")
        guard !candidates.isEmpty else { return }

        for (photo, group) in candidates {
            await markForUpload(photo: photo, in: group)
        }
        await sendPendingChangesNow()
        // 各recordの実際の成功/失敗は、この後CKSyncEngineDelegate.handleEvent(.sentRecordZoneChanges)
        // 側で「画像再送信 recordName=..., 成功/失敗」として個別にログされる(既存の仕組み)。
    }

    // MARK: - ローカル変更のアップロード登録

    /// UserProfileはユーザーごとに1つのローカルオブジェクトだが、複数グループに参加すると
    /// グループごとに別々のCKRecord(recordNameが異なる)を送信する必要がある。
    /// 以前はここで`userProfile.ckZoneName`/`ckZoneOwnerName`/`ckRecordName`を
    /// (最初にnilの時だけ設定する形で)直接書き換えていたため、2つ目以降のグループでは
    /// 既に別グループの値で埋まっているこれらのフィールドが更新されず、送信先が
    /// 最初に参加したグループのゾーン/レコードのまま固定されてしまっていた。
    /// ここでは`userProfile`側のフィールドには一切触れず、`group`から都度
    /// (このグループ用の)recordName/zoneを計算して直接enqueueする
    /// (buildRecord(for:)側もrecordNameのプロフィールID・グループIDを都度パースして
    /// 解決するため、userProfile.ckRecordName等の値には依存しない)。
    func markForUpload(userProfile: UserProfile, in group: LaterGroup) {
        guard let zoneName = group.ckZoneName, let zoneOwnerName = group.ckZoneOwnerName else { return }
        let recordName = "profile_\(userProfile.id.uuidString)_\(group.id.uuidString)"
        enqueueSave(zoneOwnerName: zoneOwnerName, recordName: recordName, zoneName: zoneName)
    }

    func markForUpload(group: LaterGroup) {
        guard let zoneOwnerName = group.ckZoneOwnerName, let zoneName = group.ckZoneName, let recordName = group.ckRecordName else { return }
        try? modelContext.save()
        enqueueSave(zoneOwnerName: zoneOwnerName, recordName: recordName, zoneName: zoneName)
    }

    /// 写真のCKレコードをアップロードキューへ積む。以前はグループ自身の
    /// ckZoneName/ckZoneOwnerNameがこの端末でnilのまま(=group.cachedZoneIDがnil)だと、
    /// inheritZone→enqueueSaveが無言でreturnし、「対象件数」には数えられるのに
    /// 実際には一切送信されないというサイレント失敗になっていた
    /// (一部グループでのみ画像が「読み込み中」のまま止まる不具合の根本原因)。
    /// ここでは諦める前にresyncGroupZoneInfoIfNeeded(_:)でグループのゾーン情報の
    /// 復旧を試み、成功すれば同じ処理をそのまま続行する。
    func markForUpload(photo: LaterPhoto, in group: LaterGroup) async {
        let photoLabel = photo.ckRecordName ?? photo.id.uuidString
        if group.cachedZoneID == nil {
            GroupSyncLogger.shared.warning("[GroupSync] markForUpload(photo): groupID=\(group.id, privacy: .public)のゾーン情報が未確定のため再同期を試みます recordName=\(photoLabel, privacy: .public)")
            let resynced = await resyncGroupZoneInfoIfNeeded(group)
            GroupSyncLogger.shared.notice("[GroupSync] markForUpload(photo): 再同期\(resynced ? "成功" : "失敗", privacy: .public) groupID=\(group.id, privacy: .public), recordName=\(photoLabel, privacy: .public)")
        }
        inheritZone(zoneName: &photo.ckZoneName, zoneOwnerName: &photo.ckZoneOwnerName, from: group)
        if photo.ckRecordName == nil {
            photo.ckRecordName = photo.id.uuidString
        }
        try? modelContext.save()
        GroupSyncLogger.shared.debug("[GroupSync] markForUpload(photo): groupID=\(group.id, privacy: .public), recordName=\(photo.ckRecordName ?? "nil", privacy: .public), zoneName=\(photo.ckZoneName ?? "nil", privacy: .public), zoneOwnerName=\(photo.ckZoneOwnerName ?? "nil", privacy: .public)")
        enqueueSave(zoneOwnerName: photo.ckZoneOwnerName, recordName: photo.ckRecordName, zoneName: photo.ckZoneName)
    }

    func markForUpload(vote: PhotoVote, in group: LaterGroup) {
        inheritZone(zoneName: &vote.ckZoneName, zoneOwnerName: &vote.ckZoneOwnerName, from: group)
        if vote.ckRecordName == nil, let photoID = vote.photoID, let voterName = vote.voterCloudKitUserRecordName {
            vote.ckRecordName = PhotoVote.deterministicRecordName(roundNumber: vote.roundNumber, photoID: photoID, voterCloudKitUserRecordName: voterName)
        }
        try? modelContext.save()
        enqueueSave(zoneOwnerName: vote.ckZoneOwnerName, recordName: vote.ckRecordName, zoneName: vote.ckZoneName)
    }

    func markForDelete(vote: PhotoVote) {
        guard let recordName = vote.ckRecordName, let zoneName = vote.ckZoneName, let ownerName = vote.ckZoneOwnerName else { return }
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        engine(forZoneOwnerName: ownerName)?.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID)])
    }

    /// 保持期間(PhotoRetentionPolicy)を過ぎてローカルから削除する写真をCloudKit側にも
    /// 伝える。ここでCKレコードの削除を送らないと、ローカルでdeleteしても次回の
    /// fetchChangesでサーバー側にまだ残っているレコードが再取得され、削除が
    /// 元に戻ってしまう。
    func markForDelete(photo: LaterPhoto) {
        guard let recordName = photo.ckRecordName, let zoneName = photo.ckZoneName, let ownerName = photo.ckZoneOwnerName else { return }
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        engine(forZoneOwnerName: ownerName)?.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID)])
    }

    /// markForUpload(photo:in:)と同じ流れ。動画本体は既にLaterVideo.toCKRecord側で
    /// isUnlocked&&localFilePathが残っている場合だけ添付される(未解禁の間はメタデータのみ)。
    func markForUpload(video: LaterVideo, in group: LaterGroup) async {
        let videoLabel = video.ckRecordName ?? video.id.uuidString
        if group.cachedZoneID == nil {
            GroupSyncLogger.shared.warning("[GroupSync] markForUpload(video): groupID=\(group.id, privacy: .public)のゾーン情報が未確定のため再同期を試みます recordName=\(videoLabel, privacy: .public)")
            _ = await resyncGroupZoneInfoIfNeeded(group)
        }
        inheritZone(zoneName: &video.ckZoneName, zoneOwnerName: &video.ckZoneOwnerName, from: group)
        if video.ckRecordName == nil {
            video.ckRecordName = video.id.uuidString
        }
        try? modelContext.save()
        enqueueSave(zoneOwnerName: video.ckZoneOwnerName, recordName: video.ckRecordName, zoneName: video.ckZoneName)
    }

    func markForDelete(video: LaterVideo) {
        guard let recordName = video.ckRecordName, let zoneName = video.ckZoneName, let ownerName = video.ckZoneOwnerName else { return }
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        engine(forZoneOwnerName: ownerName)?.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID)])
    }

    /// タップ時にだけ動画本体(CKAsset)を都度フェッチする。一覧表示・同期時には一切
    /// 呼ばれない(サムネイルのみで表示するため)。取得したCKAssetのfileURLはシステムの
    /// 一時領域にあり短命なため、呼び出し側が安全に使える専用の一時ファイルへコピーして返す
    /// (再生後の削除は呼び出し側の責務)。
    func fetchVideoAsset(for video: LaterVideo) async throws -> URL {
        guard let recordID = video.cachedRecordID else {
            throw NSError(domain: "LaterVideo", code: 1, userInfo: [NSLocalizedDescriptionKey: "動画のレコード情報がまだ確定していません"])
        }
        let database = recordID.zoneID.ownerName == currentUserRecordName
            ? container.privateCloudDatabase
            : container.sharedCloudDatabase

        let record = try await database.record(for: recordID)
        guard let asset = record["video"] as? CKAsset, let fileURL = asset.fileURL else {
            throw NSError(domain: "LaterVideo", code: 2, userInfo: [NSLocalizedDescriptionKey: "動画データがまだ届いていません。しばらくしてからもう一度お試しください。"])
        }
        let localCopyURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
        try FileManager.default.copyItem(at: fileURL, to: localCopyURL)
        return localCopyURL
    }

    private func inheritZone(zoneName: inout String?, zoneOwnerName: inout String?, from group: LaterGroup) {
        if zoneName == nil { zoneName = group.ckZoneName }
        if zoneOwnerName == nil { zoneOwnerName = group.ckZoneOwnerName }
        if zoneName == nil || zoneOwnerName == nil {
            GroupSyncLogger.shared.warning("[GroupSync] inheritZone: グループ自身のゾーン情報も未確定 groupID=\(group.id, privacy: .public), group.ckZoneName=\(group.ckZoneName ?? "nil", privacy: .public), group.ckZoneOwnerName=\(group.ckZoneOwnerName ?? "nil", privacy: .public)")
        }
    }

    /// 以前はzoneOwnerName/recordName/zoneNameのいずれかがnilの場合、ログもエラーも
    /// 出さずにここで無言でreturnしていた。再送保険の「対象N件」ログと実際の送信件数が
    /// 食い違う原因を追えるよう、中断した事実を必ず記録する。
    private func enqueueSave(zoneOwnerName: String?, recordName: String?, zoneName: String?) {
        guard let zoneOwnerName, let recordName, let zoneName else {
            GroupSyncLogger.shared.error("[GroupSync] enqueueSave中断: ゾーン情報が未確定のため送信をスキップ recordName=\(recordName ?? "nil", privacy: .public), zoneName=\(zoneName ?? "nil", privacy: .public), zoneOwnerName=\(zoneOwnerName ?? "nil", privacy: .public)")
            return
        }
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: zoneOwnerName)
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        GroupSyncLogger.shared.debug("[GroupSync] enqueueSave: recordName=\(recordID.recordName, privacy: .public), zone=\(zoneID.zoneName, privacy: .public)")
        engine(forZoneOwnerName: zoneOwnerName)?.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
    }

    /// group.cachedZoneID(ckZoneName/ckZoneOwnerName)がこの端末でnilのままだと、
    /// markForUpload→inheritZone→enqueueSaveが無言で失敗し続ける
    /// (一部グループでのみ画像の再送保険が効かない根本原因)。ここでは諦める前に、
    /// グループ自身のCKRecordをCloudKitへ明示的に問い合わせて復旧を試みる。
    ///
    /// ckZoneName/ckZoneOwnerNameの両方が失われていても、グループ作成時の命名規則
    /// (CloudKitZoneNaming.groupZoneName)とownerCloudKitUserRecordName(アプリ側で
    /// 別途保持しているホスト情報)から最も可能性の高いzoneID/recordIDを推測し、
    /// 直接1件フェッチする。推測が外れていれば単に取得失敗(.unknownItem等)になるだけで
    /// 副作用は無く、成功すればapply(record:)が本物のレコードから正しい
    /// ckZoneName/ckZoneOwnerNameを上書きしてくれる。
    @discardableResult
    func resyncGroupZoneInfoIfNeeded(_ group: LaterGroup) async -> Bool {
        if group.cachedZoneID != nil { return true }
        guard let currentUserRecordName else { return false }

        let guessedOwnerName = group.ckZoneOwnerName ?? group.ownerCloudKitUserRecordName ?? currentUserRecordName
        let guessedZoneName = group.ckZoneName ?? CloudKitZoneNaming.groupZoneName(groupID: group.id)
        let zoneID = CKRecordZone.ID(zoneName: guessedZoneName, ownerName: guessedOwnerName)
        let recordID = CKRecord.ID(recordName: group.ckRecordName ?? group.id.uuidString, zoneID: zoneID)
        let database = guessedOwnerName == currentUserRecordName
            ? container.privateCloudDatabase
            : container.sharedCloudDatabase

        GroupSyncLogger.shared.notice("[GroupSync] resyncGroupZoneInfo開始: groupID=\(group.id, privacy: .public), 推測zoneID=\(zoneID.zoneName, privacy: .public)/\(zoneID.ownerName, privacy: .public)")
        do {
            let record = try await database.record(for: recordID)
            apply(record: record)
            try? modelContext.save()
            let success = group.cachedZoneID != nil
            GroupSyncLogger.shared.notice("[GroupSync] resyncGroupZoneInfo\(success ? "成功" : "失敗(適用後もゾーン未確定)", privacy: .public): groupID=\(group.id, privacy: .public)")
            return success
        } catch {
            _ = error.loggedDescription(context: "CloudKitManager.resyncGroupZoneInfoIfNeeded(groupID: \(group.id))")
            return false
        }
    }

    private func engine(forZoneOwnerName ownerName: String?) -> CKSyncEngine? {
        if let ownerName, let currentUserRecordName, ownerName != currentUserRecordName {
            return sharedEngine
        }
        return privateEngine
    }

    // MARK: - State persistence

    private static func stateFileURL(fileName: String) -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(fileName)
    }

    private static func loadState(fileName: String) -> CKSyncEngine.State.Serialization? {
        let url = stateFileURL(fileName: fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private func saveState(_ serialization: CKSyncEngine.State.Serialization, isPrivate: Bool) {
        let fileName = isPrivate ? Self.privateStateFileName : Self.sharedStateFileName
        let url = Self.stateFileURL(fileName: fileName)
        guard let data = try? JSONEncoder().encode(serialization) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url)
    }

    // MARK: - Fetch: サーバーからの受信をローカルへ反映

    private func applyFetchedChanges(_ event: CKSyncEngine.Event.FetchedRecordZoneChanges) async {
        // LaterGroupを他のレコード種別より先に適用する。UserProfile/LaterPhoto/PhotoVoteは
        // groupフィールド(参照)で紐づくLaterGroupがローカルに無いと黙って破棄され、
        // CKSyncEngineの変更トークンは進んでしまうため再取得もされない。同一バッチ内で
        // LaterGroupより先にUserProfile等が来る順序だとメンバーが消えてしまう不具合があった。
        let orderedModifications = event.modifications.sorted { lhs, rhs in
            let lhsIsGroup = lhs.record.recordType == AppRecordType.laterGroup
            let rhsIsGroup = rhs.record.recordType == AppRecordType.laterGroup
            return lhsIsGroup && !rhsIsGroup
        }
        var typeCounts: [String: Int] = [:]
        for modification in orderedModifications {
            typeCounts[modification.record.recordType, default: 0] += 1
            apply(record: modification.record)
        }
        if !orderedModifications.isEmpty {
            let breakdown = typeCounts.map { "\($0.key) x\($0.value)" }.joined(separator: ", ")
            print("[GroupSync] applyFetchedChanges: \(orderedModifications.count)件適用(内訳: \(breakdown))")
        }
        for deletion in event.deletions {
            applyDeletion(recordID: deletion.recordID, recordType: deletion.recordType)
        }
        try? modelContext.save()
        await evaluateGroupUnlockConditions()
    }

    /// グループごとに早期解禁の条件(今日中・全員撮影済み・目標枚数到達)を判定し、
    /// 揃っていれば当日のLaterPhotoをローカルで解禁状態にする。自分が撮影した写真については
    /// 画像入りで再送する(他人の写真の実データはこの端末に存在しないため再送できない —
    /// その人自身の端末が、同じ判定を独立に行って自分の写真を送信する)。
    /// リモート通知によるfetch後、および自分の撮影直後の両方から呼ばれる。
    ///
    /// 2026/9〜: 「撮影完了」条件に加えて「翌朝9:00(GroupUnlockPolicy.
    /// nextUnlockThreshold)に到達しているか」もANDで満たす必要がある。このメソッドは
    /// CloudKitの変更を検知した時(dirtyGroupIDs)だけ動くため、時計が9:00を過ぎた
    /// だけのタイミングでは呼ばれない。その穴は evaluateLocallyPendingTimeGatedUnlocks()
    /// (dirty判定を経由しないローカル専用の再チェック、3秒ポーリング等から呼ぶ)で埋める。
    func evaluateGroupUnlockConditions() async {
        guard let groups = try? modelContext.fetch(FetchDescriptor<LaterGroup>()) else { return }

        // dirtyGroupIDsに含まれるグループだけを処理する(グループ数に比例して3秒
        // ポーリングが重くなる問題への対応)。初回(起動後まだ一度も通していない)は
        // 取りこぼしを防ぐため安全側に倒して全グループを対象にする。
        let targetGroups: [LaterGroup]
        if hasCompletedInitialGroupEvaluation {
            let dirty = dirtyGroupIDs
            dirtyGroupIDs.removeAll()
            guard !dirty.isEmpty else {
                print("[GroupSync] evaluateGroupUnlockConditions: 変化なしのためスキップ(全\(groups.count)件中0件処理)")
                return
            }
            targetGroups = groups.filter { dirty.contains($0.id) }
            print("[GroupSync] evaluateGroupUnlockConditions: 対象\(targetGroups.count)件処理(全\(groups.count)件中、スキップ\(groups.count - targetGroups.count)件)")
        } else {
            hasCompletedInitialGroupEvaluation = true
            dirtyGroupIDs.removeAll()
            targetGroups = groups
            print("[GroupSync] evaluateGroupUnlockConditions: 初回のため全\(groups.count)件を評価")
        }

        await runUnlockEvaluation(for: targetGroups)
    }

    /// dirtyGroupIDsを経由せず、ローカルのSwiftDataだけを見て「撮影条件は揃っているが
    /// 9:00の時刻ゲートで待たされている」写真/動画を再チェックする。CloudKitフェッチは
    /// 発生させない(ネットワークアクセス無し)ため、既存の3秒ポーリングloopや
    /// アプリのフォアグラウンド復帰時に軽量に呼んでよい。
    func evaluateLocallyPendingTimeGatedUnlocks() async {
        guard let groups = try? modelContext.fetch(FetchDescriptor<LaterGroup>()) else { return }
        await runUnlockEvaluation(for: groups)
    }

    /// evaluateGroupUnlockConditions/evaluateLocallyPendingTimeGatedUnlocksが共有する
    /// 実処理本体。
    private func runUnlockEvaluation(for targetGroups: [LaterGroup]) async {
        guard !targetGroups.isEmpty else { return }

        let now = Date()
        var didChange = false
        var recordNamesNeedingResend: [String] = []

        // 時間帯制限の撤廃に伴い、「現在進行中サイクルの写真/動画」は暦日や解禁時刻からの
        // 計算ではなく、単純に「まだ解禁されていない(isUnlocked==false)もの」に一致する
        // (解禁と同時に必ずisUnlockedがtrueになるため、これより過去に取りこぼしが
        // 残ることはない)。以前はグループ数×全写真数に比例する計算量を避けるため
        // 直近1日分をまとめて取得していたが、この述語ならデータ量そのものが
        // 「未解禁分」だけに絞られるため、より直接的に軽量になる。
        let unlockedPhotosPredicate = #Predicate<LaterPhoto> { !$0.isUnlocked }
        guard let recentPhotos = try? modelContext.fetch(FetchDescriptor<LaterPhoto>(predicate: unlockedPhotosPredicate)) else { return }
        var recentPhotosByGroupID: [UUID: [LaterPhoto]] = [:]
        for photo in recentPhotos {
            guard let groupID = photo.groupID else { continue }
            recentPhotosByGroupID[groupID, default: []].append(photo)
        }

        // 動画も写真と同じ枚数カウント対象にする(仕様変更)。
        let unlockedVideosPredicate = #Predicate<LaterVideo> { !$0.isUnlocked }
        let recentVideos = (try? modelContext.fetch(FetchDescriptor<LaterVideo>(predicate: unlockedVideosPredicate))) ?? []
        var recentVideosByGroupID: [UUID: [LaterVideo]] = [:]
        for video in recentVideos {
            guard let groupID = video.groupID else { continue }
            recentVideosByGroupID[groupID, default: []].append(video)
        }
        var videoRecordNamesNeedingResend: [String] = []

        for group in targetGroups {
            let groupID = group.id
            let boundary = group.lastUnlockAt ?? group.creationDate
            let currentCyclePhotos = (recentPhotosByGroupID[groupID] ?? []).filter { $0.captureDate > boundary }
            let currentCycleVideos = (recentVideosByGroupID[groupID] ?? []).filter { $0.captureDate > boundary }
            guard !currentCyclePhotos.isEmpty || !currentCycleVideos.isEmpty else { continue }

            let shotConditionMet: Bool
            if group.isPersonalSpace {
                // MEには「全員達成」という概念が無いため、ユーザー自身が設定した当日の
                // 目標枚数(personalDailyTargetCount)以上撮っていれば解禁する
                // (GroupUnlockPolicy.shouldUnlockは使わない)。
                shotConditionMet = GroupUnlockPolicy.shouldUnlockPersonalSpace(
                    shotCount: currentCyclePhotos.count + currentCycleVideos.count,
                    targetCount: group.personalDailyTargetCount
                )
            } else {
                let memberIDs = Set(group.deduplicatedMemberIDs)
                var countsByAuthor: [UUID: Int] = [:]
                for photo in currentCyclePhotos {
                    guard let authorID = photo.owner?.id else { continue }
                    countsByAuthor[authorID, default: 0] += 1
                }
                for video in currentCycleVideos {
                    guard let authorID = video.owner?.id else { continue }
                    countsByAuthor[authorID, default: 0] += 1
                }
                shotConditionMet = GroupUnlockPolicy.shouldUnlock(
                    memberIDs: memberIDs,
                    currentCyclePhotoCountsByAuthor: countsByAuthor
                )
            }

            guard shotConditionMet else { continue }

            // 解禁が起きた瞬間の識別子。壁時計時刻(Date())を使うと、各メンバーの端末が
            // 独立に判定・書き込みを行うため端末ごとにわずかに異なる値になり、
            // LaterGroup.lastUnlockAtとLaterPhoto.unlockDateが端末間で一致しなくなる
            // (LaterGroup.mostRecentCyclePhotosのunlockDate一致判定が壊れる)。
            // 代わりに「このサイクルに属する写真/動画が撮影時に既に確定させている
            // unlockDate(翌朝9:00)」という、既に全メンバー間で同期済みのデータだけから
            // 決まる値を使うことで、どの端末で計算しても同じ結果になるようにする。
            // 異なる日に撮影したメンバーが混在する場合は、もっとも遅い9:00まで全体が待つ。
            let unlockInstant = (currentCyclePhotos.map(\.unlockDate) + currentCycleVideos.map(\.unlockDate)).max() ?? now

            // 時刻ゲート: 撮影条件が揃っていても、翌朝9:00に到達していなければ
            // まだ解禁しない(全員撮影完了済み・時刻待ちの状態はGroupStatusPresenter.
            // GroupDailyState.waitingForUnlockTimeがUI側で表現する)。
            guard GroupUnlockPolicy.isUnlockTimeReached(unlockAt: unlockInstant, now: now) else { continue }

            group.lastUnlockAt = unlockInstant
            markForUpload(group: group)

            for photo in currentCyclePhotos where !photo.isUnlocked {
                photo.unlockDate = unlockInstant
                if photo.authorCloudKitUserRecordName == currentUserRecordName {
                    // 解禁確定の直前に一度だけチェキ加工(FilmEmulation)を焼き込み、
                    // imageData自体を最終結果にする。以降、他メンバーはCKAsset経由で
                    // 受け取ったバイト列をそのまま表示すればよくなる(表示側の
                    // 再加工・乱数シードの不整合が構造的に無くなる)。焼き込みが
                    // 終わるまではisUnlockedをtrueにしない(既存の「現像中」表示が
                    // そのままプレースホルダーとして機能し、未加工の一瞬が
                    // 画面に出ることを避ける)。
                    await ChekiColorGrade.bakeIntoImageData(photo)
                    photo.isUnlocked = true
                    didChange = true
                    await markForUpload(photo: photo, in: group)
                    recordNamesNeedingResend.append(photo.ckRecordName ?? photo.id.uuidString)
                } else {
                    // 他メンバーの写真は自分の端末に実データが無いため焼き込めない。
                    // 加工済みバイト列は、撮影者本人の端末が焼き込んだ結果をCKAsset経由で
                    // 受信するのを待つ(このisUnlockedの反転自体は解禁ポリシーの判定結果を
                    // 各メンバーが独立にローカル反映しているだけで、画像本体とは別)。
                    photo.isUnlocked = true
                    didChange = true
                }
            }

            for video in currentCycleVideos where !video.isUnlocked {
                // 写真の「現像中」演出(ChekiColorGrade.bakeIntoImageData)は動画には
                // 適用しない。isUnlockedを反転させるだけで、動画本体の加工は撮影直後の
                // FilmEmulationVideoExporterで既に完了済み。
                video.unlockDate = unlockInstant
                video.isUnlocked = true
                didChange = true
                if video.authorCloudKitUserRecordName == currentUserRecordName {
                    await markForUpload(video: video, in: group)
                    videoRecordNamesNeedingResend.append(video.ckRecordName ?? video.id.uuidString)
                }
            }
        }

        if didChange {
            try? modelContext.save()
        }

        if !videoRecordNamesNeedingResend.isEmpty {
            DispatchQueue.main.async { [weak self] in
                Task { @MainActor in
                    await self?.sendPendingChangesNow()
                }
            }
        }

        guard !recordNamesNeedingResend.isEmpty else { return }

        // markForUploadでキューへ積むだけでは、次に何か別の操作がsendChanges()を呼ぶまで
        // 実際の送信(=画像本体CKAssetの再送信)が遅延する。ただし、この関数は
        // CKSyncEngineDelegate.handleEvent(.fetchedRecordZoneChanges)からapplyFetchedChanges
        // 経由で呼ばれることがあり、その場合はCKSyncEngine内部のデリゲートコールバック
        // 呼び出しの真っ最中にある。ここで直接sendPendingChangesNow()をawaitすると、
        // デリゲートコールバック内からsendChanges()を再帰的に呼び出すことになり、
        // CKSyncEngineの「デリゲートコールバック中の再帰呼び出しは保証できない」安全装置に
        // 触れてcaulk::mach::semaphoreのデッドロックでクラッシュする
        // (CKSyncEngine.___CKSyncEngine_cannot_guarantee_serial_delegate_callbacks_if_you_recurse___)。
        // DispatchQueue.main.asyncでイベントループの次のサイクルまで確実に逃がしてから
        // Taskを起動する(このメソッドの他の呼び出し元(fetchAndApplyZoneImmediately等)は
        // 元々デリゲートコールバックの外なので、この遅延を挟んでも実害はない)。
        for recordName in recordNamesNeedingResend {
            print("[GroupSync] 画像再送信 recordName=\(recordName), 送信要求(次サイクルへ委譲)")
        }
        DispatchQueue.main.async { [weak self] in
            Task { @MainActor in
                await self?.sendPendingChangesNow()
            }
        }
    }

    /// 既に重複してしまっている(同一cloudKitUserRecordNameを持つ複数のUserProfileが
    /// 同じgroup.membersに入っている)壊れたデータのマイグレーション。addMember(_:)/
    /// isMember(_:)の修正は「これから新たに重複が発生すること」を防ぐだけで、
    /// 過去に既に重複してしまったローカルデータまでは直さないため、別途一度だけ解消する。
    ///
    /// 各グループについて、cloudKitUserRecordNameが同じメンバーが複数いれば、
    /// そのグループ内での撮影実績(LaterPhoto.owner)が多い方を残し、残りをmembersから
    /// 取り除く(同数ならより多くのグループ写真情報を保持している=同期が進んでいる方を優先)。
    /// UserProfileオブジェクト自体は削除しない(他のグループのメンバーや過去の写真の
    /// ownerとして引き続き参照されている可能性があるため、membersからの除去のみ行う)。
    func deduplicateGroupMembers() {
        guard let groups = try? modelContext.fetch(FetchDescriptor<LaterGroup>()) else { return }
        guard let allPhotos = try? modelContext.fetch(FetchDescriptor<LaterPhoto>()) else { return }
        var didChange = false

        for group in groups {
            var keeperByKey: [String: UserProfile] = [:]
            var duplicatesToRemove: [UserProfile] = []

            for member in group.members {
                guard let key = member.cloudKitUserRecordName, !key.isEmpty else { continue }
                guard let existingKeeper = keeperByKey[key] else {
                    keeperByKey[key] = member
                    continue
                }
                let existingPhotoCount = allPhotos.filter { $0.groupID == group.id && $0.owner?.id == existingKeeper.id }.count
                let candidatePhotoCount = allPhotos.filter { $0.groupID == group.id && $0.owner?.id == member.id }.count
                if candidatePhotoCount > existingPhotoCount {
                    duplicatesToRemove.append(existingKeeper)
                    keeperByKey[key] = member
                } else {
                    duplicatesToRemove.append(member)
                }
            }

            for duplicate in duplicatesToRemove {
                if group.removeMember(userID: duplicate.id) {
                    didChange = true
                    print("[GroupSync] deduplicateGroupMembers: グループ\(group.name)から重複メンバー\(duplicate.name)(id=\(duplicate.id))を除去")
                }
            }
        }

        if didChange {
            try? modelContext.save()
        }
    }

    /// 「解禁時に一度だけチェキ加工(FilmEmulation)を焼き込む」仕組みの導入前から
    /// 既に解禁済みだった、自分が撮影した写真を遡って焼き込むマイグレーション。
    ///
    /// 対象は isUnlocked == true && isColorGraded == false && 自分が撮影した写真のみ。
    /// 他メンバーが撮影した写真は対象にしない: 焼き込みにはその写真の実データ
    /// (imageData)が必要だが、自分の端末にある他人の写真のimageDataはCloudKit経由で
    /// 受信したものであり、ここで独自に焼き込むと(1)乱数シードが端末ごとに異なるため
    /// 見た目が撮影者本人の焼き込み結果と食い違う、(2)撮影者本人が後で自分の端末で
    /// 焼き込んだ結果を送ってきた際、二重に加工が重なる、という問題が起きる。
    /// 「1つの写真につき、焼き込みは撮影者本人の端末で1回だけ」という原則を
    /// isUnlockedの通常の解禁フロー(evaluateGroupUnlockConditions/autoUnlockPhotos)と
    /// 揃えている。
    ///
    /// isColorGradedフラグにより、既に焼き込み済みの写真は対象から自然に除外されるため、
    /// deduplicateGroupMembers()と同じ方針で起動のたびに呼んでよい
    /// (2回目以降は対象0件の軽い処理で終わる)。
    func migrateChekiGradingForOwnPhotos() async {
        guard !isMigratingChekiGrading else { return }
        guard let currentUserRecordName else { return }
        // World Later等でLaterPhotoの総数が増えても、この対象(自分が撮影した未焼き込み分)
        // だけをDB側の#Predicateで絞り込む(以前は全件取得後にSwift側でfilterしていた)。
        let predicate = #Predicate<LaterPhoto> {
            $0.isUnlocked && !$0.isColorGraded && $0.authorCloudKitUserRecordName == currentUserRecordName
        }
        guard let targets = try? modelContext.fetch(FetchDescriptor<LaterPhoto>(predicate: predicate)) else { return }
        guard !targets.isEmpty else {
            print("[GroupSync] チェキ加工マイグレーション: 対象0件")
            return
        }

        isMigratingChekiGrading = true
        defer { isMigratingChekiGrading = false }

        var successCount = 0
        var failureCount = 0
        var recordNamesNeedingResend: [String] = []

        for photo in targets {
            guard let groupID = photo.groupID, let group = fetchOne(LaterGroup.self, { $0.id == groupID }) else {
                failureCount += 1
                continue
            }
            await ChekiColorGrade.bakeIntoImageData(photo)
            if photo.isColorGraded {
                successCount += 1
                recordNamesNeedingResend.append(photo.ckRecordName ?? photo.id.uuidString)
                await markForUpload(photo: photo, in: group)
            } else {
                failureCount += 1
            }
        }
        try? modelContext.save()

        print("[GroupSync] チェキ加工マイグレーション: 対象\(targets.count)件、成功\(successCount)件、失敗\(failureCount)件")

        guard !recordNamesNeedingResend.isEmpty else { return }
        // 焼き込み済みの新しいバイト列を、他メンバーへも伝播させる
        // (これまでの未加工バージョンが既に送信済み・受信済みの可能性があるため、
        // 明示的に再送する)。
        await sendPendingChangesNow()
    }

    private func apply(record: CKRecord) {
        switch record.recordType {
        case AppRecordType.laterGroup:
            upsertGroup(from: record)
        case AppRecordType.userProfile:
            upsertUserProfile(from: record)
        case AppRecordType.laterPhoto:
            upsertPhoto(from: record)
        case AppRecordType.laterVideo:
            upsertVideo(from: record)
        case AppRecordType.photoVote:
            upsertVote(from: record)
        default:
            break
        }
        markGroupDirty(resolvedGroupID(for: record))
    }

    /// apply(record:)で反映した内容がどのグループに関係するかを特定する。
    /// dirtyマーキング専用で、実際の反映ロジックには関与しない。
    private func resolvedGroupID(for record: CKRecord) -> UUID? {
        switch record.recordType {
        case AppRecordType.laterGroup:
            return UUID(uuidString: record.recordID.recordName)
        case AppRecordType.userProfile, AppRecordType.laterPhoto, AppRecordType.laterVideo:
            return groupID(fromReferenceField: "group", in: record)
        case AppRecordType.photoVote:
            // PhotoVoteレコード自体は"group"参照を持たないため、"photo"参照から
            // 辿った先のLaterPhoto.groupIDを使う。
            guard let photoID = photoID(fromReferenceField: "photo", in: record) else { return nil }
            return fetchOne(LaterPhoto.self, { $0.id == photoID })?.groupID
        default:
            return nil
        }
    }

    private func applyDeletion(recordID: CKRecord.ID, recordType: CKRecord.RecordType) {
        let recordName = recordID.recordName
        switch recordType {
        case AppRecordType.photoVote:
            if let vote = fetchOne(PhotoVote.self, { $0.ckRecordName == recordName }) {
                markGroupDirty(vote.groupID)
                modelContext.delete(vote)
            }
        case AppRecordType.laterPhoto:
            if let photo = fetchOne(LaterPhoto.self, { $0.ckRecordName == recordName }) {
                markGroupDirty(photo.groupID)
                modelContext.delete(photo)
            }
        case AppRecordType.laterVideo:
            if let video = fetchOne(LaterVideo.self, { $0.ckRecordName == recordName }) {
                markGroupDirty(video.groupID)
                modelContext.delete(video)
            }
        case AppRecordType.userProfile:
            // グループ脱退(GroupSharingService.leaveGroup)は、離脱者自身のUserProfile
            // レコードをそのグループのゾーンから削除することで他メンバーへ知らせる。
            // このレコードは1グループにつき1件(zoneIDがそのままグループを特定する)ため、
            // 削除されたゾーンと一致するLaterGroup.membersからだけ、そのプロフィールを外す
            // (同じ人物が他のグループにも参加している場合、そちらの所属は維持する)。
            guard let profile = fetchOne(UserProfile.self, { $0.ckRecordName == recordName }) else { return }
            if let group = fetchOne(LaterGroup.self, { $0.cachedZoneID == recordID.zoneID }) {
                markGroupDirty(group.id)
                _ = group.removeMember(userID: profile.id)
            }
        default:
            break
        }
    }

    private func upsertGroup(from record: CKRecord) {
        let recordName = record.recordID.recordName
        let group = fetchOne(LaterGroup.self, { $0.ckRecordName == recordName })
            ?? (UUID(uuidString: recordName).map { id -> LaterGroup in
                let g = LaterGroup(name: "")
                g.id = id
                return g
            })
        guard let group else { return }
        group.apply(from: record)
        if modelContext.model(for: group.persistentModelID) == nil {
            modelContext.insert(group)
        }
    }

    private func upsertUserProfile(from record: CKRecord) {
        let recordName = record.recordID.recordName
        print("[GroupSync] upsertUserProfile呼び出し: recordName=\(recordName)")
        guard let groupID = groupID(fromReferenceField: "group", in: record) else {
            print("[GroupSync] upsertUserProfile失敗: recordName=\(recordName)にgroup参照フィールドが無い")
            return
        }
        guard let group = fetchOne(LaterGroup.self, { $0.id == groupID }) else {
            print("[GroupSync] upsertUserProfile失敗: groupID=\(groupID)に一致するLaterGroupがローカルに見つからない(recordName=\(recordName))")
            return
        }

        let cloudKitUserRecordName = record["cloudKitUserRecordName"] as? String

        // 最優先: cloudKitUserRecordName(恒久的な識別子)で一致するローカルオブジェクトを探す。
        // ckRecordNameはグループごとに異なる値になり得る(UserProfile.apply(from:)は
        // 受信のたびに上書きするため、複数グループに参加しているユーザーの場合は
        // 「最後に受信したグループ向けの値」しか残らない)ため、同一人物かどうかの
        // 判定にはもう使わない。ckRecordName一致はこの後のフォールバックとしてのみ残す
        // (cloudKitUserRecordNameがまだ同期されていない古いレコード向け)。
        if let cloudKitUserRecordName,
           let matching = fetchOne(UserProfile.self, { $0.cloudKitUserRecordName == cloudKitUserRecordName }) {
            matching.apply(from: record)
            if !group.isMember(matching) {
                print("[GroupSync] upsertUserProfile: addMember呼び出し profileID=\(matching.id), groupID=\(group.id), 現在のmembers.count=\(group.members.count)")
                let added = group.addMember(matching)
                print("[GroupSync] upsertUserProfile: addMember完了 結果=\(added), groupID=\(group.id), 更新後members.count=\(group.members.count)")
                print("[GroupSync] upsertUserProfile: グループ\(group.name)にメンバー\(matching.name)を追加(cloudKitUserRecordName一致経由)")
            }
            return
        }

        // フォールバック: cloudKitUserRecordNameがレコードに無い/まだ一致するローカル
        // オブジェクトが無い場合のみ、ckRecordName(このレコード自体の識別子)で探す。
        if let existing = fetchOne(UserProfile.self, { $0.ckRecordName == recordName }) {
            existing.apply(from: record)
            if !group.isMember(existing) {
                print("[GroupSync] upsertUserProfile: addMember呼び出し profileID=\(existing.id), groupID=\(group.id), 現在のmembers.count=\(group.members.count)")
                let added = group.addMember(existing)
                print("[GroupSync] upsertUserProfile: addMember完了 結果=\(added), groupID=\(group.id), 更新後members.count=\(group.members.count)")
                print("[GroupSync] upsertUserProfile: グループ\(group.name)にメンバー\(existing.name)を追加(ckRecordName一致経由)")
            }
            return
        }

        let name = record["name"] as? String ?? ""
        let username = record["username"] as? String ?? ""
        let profile = UserProfile(name: name, username: username)
        profile.apply(from: record)
        modelContext.insert(profile)
        print("[GroupSync] upsertUserProfile: addMember呼び出し profileID=\(profile.id), groupID=\(group.id), 現在のmembers.count=\(group.members.count)")
        let added = group.addMember(profile)
        print("[GroupSync] upsertUserProfile: addMember完了 結果=\(added), groupID=\(group.id), 更新後members.count=\(group.members.count)")
        print("[GroupSync] upsertUserProfile: グループ\(group.name)に新規メンバー\(name)を追加")
    }

    private func upsertPhoto(from record: CKRecord) {
        let recordName = record.recordID.recordName
        guard let groupID = groupID(fromReferenceField: "group", in: record),
              let group = fetchOne(LaterGroup.self, { $0.id == groupID }) else { return }

        if let existing = fetchOne(LaterPhoto.self, { $0.ckRecordName == recordName }) {
            try? existing.apply(from: record)
            resolveOwner(for: existing, in: group)
            return
        }

        guard let id = UUID(uuidString: recordName) else { return }
        let photo = LaterPhoto(
            imageData: Data(),
            unlockDate: (record["unlockDate"] as? Date) ?? Date()
        )
        photo.id = id
        photo.groupID = groupID
        try? photo.apply(from: record)
        modelContext.insert(photo)
        group.photos.append(photo)
        resolveOwner(for: photo, in: group)
    }

    /// authorCloudKitUserRecordNameから、グループの既存メンバー(UserProfile)を
    /// ローカルで解決してownerリレーションシップに繋ぎ直す。
    private func resolveOwner(for photo: LaterPhoto, in group: LaterGroup) {
        guard photo.owner == nil, let authorRecordName = photo.authorCloudKitUserRecordName else { return }
        if let match = group.members.first(where: { $0.cloudKitUserRecordName == authorRecordName }) {
            photo.owner = match
        }
    }

    private func upsertVideo(from record: CKRecord) {
        let recordName = record.recordID.recordName
        guard let groupID = groupID(fromReferenceField: "group", in: record),
              let group = fetchOne(LaterGroup.self, { $0.id == groupID }) else { return }

        if let existing = fetchOne(LaterVideo.self, { $0.ckRecordName == recordName }) {
            try? existing.apply(from: record)
            resolveOwner(for: existing, in: group)
            return
        }

        guard let id = UUID(uuidString: recordName) else { return }
        let video = LaterVideo(
            thumbnailData: Data(),
            durationSeconds: (record["durationSeconds"] as? Double) ?? 0,
            unlockDate: (record["unlockDate"] as? Date) ?? Date()
        )
        video.id = id
        video.groupID = groupID
        try? video.apply(from: record)
        modelContext.insert(video)
        group.videos.append(video)
        resolveOwner(for: video, in: group)
    }

    /// resolveOwner(for photo:in:)と同じロジックのLaterVideo版。
    private func resolveOwner(for video: LaterVideo, in group: LaterGroup) {
        guard video.owner == nil, let authorRecordName = video.authorCloudKitUserRecordName else { return }
        if let match = group.members.first(where: { $0.cloudKitUserRecordName == authorRecordName }) {
            video.owner = match
        }
    }

    private func upsertVote(from record: CKRecord) {
        let recordName = record.recordID.recordName
        if let existing = fetchOne(PhotoVote.self, { $0.ckRecordName == recordName }) {
            existing.apply(from: record)
            return
        }

        guard let photoID = photoID(fromReferenceField: "photo", in: record),
              let photo = fetchOne(LaterPhoto.self, { $0.id == photoID }),
              let groupID = photo.groupID,
              let group = fetchOne(LaterGroup.self, { $0.id == groupID }) else { return }

        let voterCloudKitUserRecordName = record["voterCloudKitUserRecordName"] as? String
        let voter = group.members.first(where: { $0.cloudKitUserRecordName == voterCloudKitUserRecordName })

        // PhotoVote.init(photo:voter:)はvoterを必須とするため、解決できない場合は
        // 匿名のプレースホルダーを使わず、まだメンバー情報が揃っていないとみなして
        // 次回のfetch時に再試行する(voterのUserProfile同期が先に来ることが多いため実害は小さい)。
        guard let voter else { return }

        let vote = PhotoVote(photo: photo, voter: voter)
        vote.photoID = photoID
        vote.groupID = groupID
        vote.apply(from: record)
        modelContext.insert(vote)
    }

    private func groupID(fromReferenceField field: String, in record: CKRecord) -> UUID? {
        guard let reference = record[field] as? CKRecord.Reference else { return nil }
        return UUID(uuidString: reference.recordID.recordName)
    }

    private func photoID(fromReferenceField field: String, in record: CKRecord) -> UUID? {
        guard let reference = record[field] as? CKRecord.Reference else { return nil }
        return UUID(uuidString: reference.recordID.recordName)
    }

    private func fetchOne<T: PersistentModel>(_ type: T.Type, _ predicate: (T) -> Bool) -> T? {
        (try? modelContext.fetch(FetchDescriptor<T>()))?.first(where: predicate)
    }

    private func fetchAll<T: PersistentModel>(_ type: T.Type, _ predicate: (T) -> Bool) -> [T] {
        (try? modelContext.fetch(FetchDescriptor<T>()))?.filter(predicate) ?? []
    }

    // MARK: - Send: ローカル変更をCKRecordへ変換

    private func buildRecord(for recordID: CKRecord.ID) -> CKRecord? {
        let recordName = recordID.recordName
        let ownerName = recordID.zoneID.ownerName
        // handleFailedSaveが.serverRecordChanged検知時に退避したサーバー側の現在の実体。
        // 存在すればこれへフィールドを上書きして送ることで「更新」として扱われる
        // (無ければ従来通りnil=ゼロから新規レコードとして「挿入」で送る)。
        // 一度使ったら取り除き、以降の(競合していない)通常の再送に影響しないようにする。
        let existing = conflictServerRecords.removeValue(forKey: recordID)

        if let group = fetchOne(LaterGroup.self, { $0.ckRecordName == recordName }) {
            return group.toCKRecord(existing: existing, ownerName: ownerName)
        }
        if let profileID = Self.parseProfileID(fromDeterministicRecordName: recordName),
           let profile = fetchOne(UserProfile.self, { $0.id == profileID }),
           // どのグループ宛かはrecordID.zoneIDで確定する。以前はprofile.ckRecordNameが
           // このrecordNameと一致するかで検索していたが、UserProfileはユーザーごとに
           // 1つのローカルオブジェクトであり、複数グループに参加するとそのフィールドは
           // 常に「最後に見た1つのグループ」しか表せない。そのため2つ目以降の
           // グループ宛のrecordNameとは一致せず、そのグループへは一度も送信されない
           // 不具合になっていた。recordName自体に決定論的に埋め込まれたprofileIDから
           // 直接オブジェクトを特定し、group側はzoneIDから独立に解決することで、
           // どのグループ向けの送信でも正しいUserProfileを見つけられるようにする。
           let group = fetchOne(LaterGroup.self, { $0.cachedZoneID == recordID.zoneID }),
           let groupRecordID = group.cachedRecordID {
            // profile.ckRecordName(nilの場合が多い。上記と同じ理由でグループ間で
            // 使い回せないため)に頼らず、CKSyncEngineから渡された正しいrecordID
            // (このメソッドの引数)を直接使ってベースレコードを組み立てる。
            let base = existing ?? CKRecord(recordType: AppRecordType.userProfile, recordID: recordID)
            return profile.toCKRecord(existing: base, zoneID: recordID.zoneID, groupRecordID: groupRecordID)
        }
        if let photo = fetchOne(LaterPhoto.self, { $0.ckRecordName == recordName }),
           let groupID = photo.groupID,
           let group = fetchOne(LaterGroup.self, { $0.id == groupID }),
           let groupRecordID = group.cachedRecordID {
            return try? photo.toCKRecord(existing: existing, zoneID: recordID.zoneID, groupRecordID: groupRecordID)
        }
        if let video = fetchOne(LaterVideo.self, { $0.ckRecordName == recordName }),
           let groupID = video.groupID,
           let group = fetchOne(LaterGroup.self, { $0.id == groupID }),
           let groupRecordID = group.cachedRecordID {
            return try? video.toCKRecord(existing: existing, zoneID: recordID.zoneID, groupRecordID: groupRecordID)
        }
        if let vote = fetchOne(PhotoVote.self, { $0.ckRecordName == recordName }),
           let photoID = vote.photoID,
           let photo = fetchOne(LaterPhoto.self, { $0.id == photoID }),
           let photoRecordID = photo.cachedRecordID,
           let groupID = photo.groupID,
           let group = fetchOne(LaterGroup.self, { $0.id == groupID }),
           let groupRecordID = group.cachedRecordID {
            return vote.toCKRecord(existing: existing, zoneID: recordID.zoneID, photoRecordID: photoRecordID, groupRecordID: groupRecordID)
        }
        return nil
    }

    /// markForUpload(userProfile:in:)が生成する決定論的recordName
    /// ("profile_<profileID>_<groupID>")から、profileID部分だけを取り出す。
    /// UUID文字列自体はハイフンのみでアンダースコアを含まないため、
    /// "_"区切りで安全に分解できる。
    private static func parseProfileID(fromDeterministicRecordName recordName: String) -> UUID? {
        let prefix = "profile_"
        guard recordName.hasPrefix(prefix) else { return nil }
        let parts = recordName.dropFirst(prefix.count).split(separator: "_")
        guard parts.count == 2 else { return nil }
        return UUID(uuidString: String(parts[0]))
    }

    /// 送信が成功したレコードのrecordChangeTagだけをローカルへ反映する(他のフィールドは
    /// 送信元のローカル値そのものなので触らない)。以前はここを何もしていなかったため、
    /// ローカルは「サーバーへ送った」ことしか記憶できず「送信成功後もサーバーが今
    /// 何のchangeTagを割り当てているか」を永久に知らないままだった。その結果、
    /// 呼び出し側(GroupSharingService.uploadOwnProfile等)が「既に同期済みかどうか」を
    /// 判定する手段が無く、画面を開くたびに無条件で再送 → 直前の成功分と衝突、を
    /// 繰り返す原因になっていた。
    private func markSynced(_ record: CKRecord) {
        let recordName = record.recordID.recordName
        switch record.recordType {
        case AppRecordType.laterGroup:
            fetchOne(LaterGroup.self, { $0.ckRecordName == recordName })?.ckRecordChangeTag = record.recordChangeTag
        case AppRecordType.userProfile:
            // グループ単位のタグ(LaterGroup.myProfileCKRecordChangeTag)を更新する。
            // UserProfile.ckRecordChangeTagはグループをまたいで使い回せないため、
            // 自分のプロフィール送信の「既に同期済みか」判定にはもう使わない
            // (GroupSharingService.uploadOwnProfile参照)。
            fetchOne(LaterGroup.self, { $0.cachedZoneID == record.recordID.zoneID })?.myProfileCKRecordChangeTag = record.recordChangeTag
        case AppRecordType.laterPhoto:
            if let photo = fetchOne(LaterPhoto.self, { $0.ckRecordName == recordName }) {
                photo.ckRecordChangeTag = record.recordChangeTag
                // 画像フィールドを含む保存が確認できた時点で「アップロード済み」とする
                // (isUnlocked==falseの間はtoCKRecordがimageフィールド自体を設定しないため、
                // ここでnilなら現像中のメタデータのみの保存であり、画像はまだ未送信)。
                if record["image"] != nil {
                    photo.isImageUploaded = true
                }
            }
        case AppRecordType.laterVideo:
            if let video = fetchOne(LaterVideo.self, { $0.ckRecordName == recordName }) {
                video.ckRecordChangeTag = record.recordChangeTag
                // 動画本体を含む保存が確認できた時点で、ローカルの一時ファイルはもう不要。
                // ここで削除することで、写真のようにDocuments & Dataへ動画バイト列が
                // 溜まり続けるのを防ぐ(サムネイルだけが端末に残る)。
                if record["video"] != nil {
                    video.isVideoUploaded = true
                    if let path = video.localFilePath {
                        try? FileManager.default.removeItem(atPath: path)
                        video.localFilePath = nil
                    }
                }
            }
        case AppRecordType.photoVote:
            fetchOne(PhotoVote.self, { $0.ckRecordName == recordName })?.ckRecordChangeTag = record.recordChangeTag
        default:
            break
        }
    }
}

// MARK: - CKSyncEngineDelegate

extension CloudKitManager: CKSyncEngineDelegate {
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let stateUpdate):
            saveState(stateUpdate.stateSerialization, isPrivate: syncEngine === privateEngine)

        case .fetchedRecordZoneChanges(let changes):
            await applyFetchedChanges(changes)

        case .sentRecordZoneChanges(let changes):
            if !changes.savedRecords.isEmpty {
                let summary = changes.savedRecords.map { "\($0.recordType)(\($0.recordID.recordName))" }.joined(separator: ", ")
                print("[GroupSync] sendChanges成功: \(changes.savedRecords.count)件送信完了 [\(summary)]")
                for saved in changes.savedRecords {
                    markSynced(saved)
                    retryAttemptCounts[saved.recordID] = nil
                    if saved.recordType == AppRecordType.laterPhoto {
                        print("[GroupSync] 画像再送信 recordName=\(saved.recordID.recordName), 成功")
                    }
                }
                try? modelContext.save()
            }
            for failedSave in changes.failedRecordSaves {
                print("[GroupSync] sendChanges失敗: recordID=\(failedSave.record.recordID) error=\(failedSave.error)")
                if failedSave.record.recordType == AppRecordType.laterPhoto {
                    print("[GroupSync] 画像再送信 recordName=\(failedSave.record.recordID.recordName), 失敗 error=\(failedSave.error)")
                }
                handleFailedSave(failedSave, syncEngine: syncEngine)
            }

        default:
            break
        }
    }

    /// 送信失敗を検知した際のリカバリ入口。.serverRecordChanged(競合)と、それ以外の
    /// 一時的なエラー(ネットワーク不調・レート制限等)を分けて扱う。
    private func handleFailedSave(_ failedSave: CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave, syncEngine: CKSyncEngine) {
        if failedSave.error.code == .serverRecordChanged, let serverRecord = failedSave.error.serverRecord {
            handleConflictedSave(failedSave, serverRecord: serverRecord, syncEngine: syncEngine)
            return
        }
        handleRetryableSaveIfNeeded(failedSave, syncEngine: syncEngine)
    }

    /// .serverRecordChanged(コード14/2004。「サーバーに既に同名レコードが存在する」)を
    /// 狙い撃ちして自動リカバリする。CKErrorが運んでくるserverRecordは、正しい
    /// recordChangeTagを持つサーバー側の現在の実体そのものなので、これをそのまま
    /// conflictServerRecordsに退避しておき、同じrecordIDを再度pendingRecordZoneChangesへ
    /// 積み直す。次回nextRecordZoneChangeBatch→buildRecord(for:)が呼ばれた際、
    /// ゼロからの新規レコードではなくこの退避しておいたレコードへフィールドを
    /// 上書きして送るため、「新規挿入」ではなく「更新」としてサーバーに受理される。
    private func handleConflictedSave(_ failedSave: CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave, serverRecord: CKRecord, syncEngine: CKSyncEngine) {
        let recordID = failedSave.record.recordID
        let isPhoto = failedSave.record.recordType == AppRecordType.laterPhoto
        print("[GroupSync] サーバー側の既存レコードを使って再送を試みます: recordID=\(recordID)")
        conflictServerRecords[recordID] = serverRecord
        syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
        retrySendAfterCurrentDelegateCallback(recordID: recordID, isPhoto: isPhoto, syncEngine: syncEngine, logSuffix: "衝突解消後の即時リトライ")
    }

    /// .serverRecordChanged以外の送信失敗(ネットワーク不調・レート制限・ゾーン混雑等の
    /// 一時的なエラー)は、CKSyncEngineが自動で再試行してくれるわけではない。
    /// 特にLaterPhoto(画像=CKAsset)は、isUnlockedがfalse→trueに変わった「その瞬間」に
    /// しかmarkForUploadが呼ばれない設計(evaluateGroupUnlockConditions参照)のため、
    /// 最初の送信がここで(競合以外の理由で)失敗すると、以降誰も再送を試みず、その写真の
    /// 画像だけが他メンバーへ永久に届かなくなってしまう。
    ///
    /// 1回目の失敗は即時リトライ(体感の速さを優先)。それでも失敗が続く場合は
    /// retryDelays(30秒→2分→10分)の間隔を空けて再試行し、それでも解決しなければ
    /// この即時系の仕組みでの再試行は諦め、resendOwnUnlockedPhotosIfNeeded()
    /// (フォアグラウンド復帰時・画面ポーリング時に定期的に動く再送保険)に委ねる。
    private func handleRetryableSaveIfNeeded(_ failedSave: CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave, syncEngine: CKSyncEngine) {
        guard isRetryableError(failedSave.error) else { return }
        let recordID = failedSave.record.recordID
        let isPhoto = failedSave.record.recordType == AppRecordType.laterPhoto
        syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])

        if (retryAttemptCounts[recordID] ?? 0) == 0 {
            retryAttemptCounts[recordID] = 1
            print("[GroupSync] 一時的なエラーのため即時リトライを試みます: recordID=\(recordID), errorCode=\(failedSave.error.code.rawValue)")
            retryImmediatelyThenBackoffIfNeeded(recordID: recordID, isPhoto: isPhoto, syncEngine: syncEngine, errorCode: failedSave.error.code.rawValue)
        } else {
            // 即時リトライ済みでまだ失敗している場合。以後はscheduleNextDelayedRetryが
            // 自分自身の失敗を検知して次の間隔を自己スケジュールし続けるため、ここでは
            // 二重にスケジュールしないよう何もしない(この関数はCKSyncEngineが独自に
            // 同じrecordIDの失敗イベントを重ねて配信してきた場合の保険的な入口に過ぎない)。
        }
    }

    /// handleRetryableSaveIfNeededの1回目の失敗に対する即時リトライ専用の経路。
    /// retrySendAfterCurrentDelegateCallback(衝突解消用)とは別に用意しており、
    /// これが失敗した場合はscheduleNextDelayedRetryへ引き継いでバックオフを開始する。
    private func retryImmediatelyThenBackoffIfNeeded(recordID: CKRecord.ID, isPhoto: Bool, syncEngine: CKSyncEngine, errorCode: Int) {
        DispatchQueue.main.async { [weak self, weak syncEngine] in
            guard let syncEngine, let self else { return }
            Task { @MainActor in
                do {
                    try await syncEngine.sendChanges()
                    if isPhoto {
                        print("[GroupSync] 画像再送信 recordName=\(recordID.recordName), 一時的なエラー後の即時リトライに成功")
                    }
                    self.retryAttemptCounts[recordID] = nil
                } catch {
                    if isPhoto {
                        print("[GroupSync] 画像再送信 recordName=\(recordID.recordName), 一時的なエラー後の即時リトライに失敗 error=\(error)")
                    }
                    self.scheduleNextDelayedRetry(recordID: recordID, isPhoto: isPhoto, syncEngine: syncEngine, errorCode: errorCode)
                }
            }
        }
    }

    /// retryDelays(30秒→2分→10分)の間隔を順に空けながら再送する。1回試して失敗したら
    /// 自分自身を呼び直して次の間隔をスケジュールする、自己完結した再試行チェーン
    /// (CKSyncEngineの失敗イベントが再度飛んでくるかどうかに依存しない)。
    private func scheduleNextDelayedRetry(recordID: CKRecord.ID, isPhoto: Bool, syncEngine: CKSyncEngine, errorCode: Int) {
        let attemptNumber = retryAttemptCounts[recordID] ?? 1 // 1 = 即時リトライ済み
        let delayIndex = attemptNumber - 1
        guard delayIndex < Self.retryDelays.count else {
            print("[GroupSync] 再送リトライの上限に達したため即時系の再試行は諦めます: recordID=\(recordID)。次回のフォアグラウンド復帰/画面ポーリング時の再送保険(resendOwnUnlockedPhotosIfNeeded)に委ねます")
            retryAttemptCounts[recordID] = nil
            return
        }
        let delay = Self.retryDelays[delayIndex]
        retryAttemptCounts[recordID] = attemptNumber + 1
        print("[GroupSync] 一時的なエラーが続いているため\(Int(delay))秒後に再送を試みます: recordID=\(recordID), errorCode=\(errorCode)")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak syncEngine] in
            guard let syncEngine, let self else { return }
            Task { @MainActor in
                do {
                    try await syncEngine.sendChanges()
                    if isPhoto {
                        print("[GroupSync] 画像再送信 recordName=\(recordID.recordName), \(Int(delay))秒後リトライに成功")
                    }
                    self.retryAttemptCounts[recordID] = nil
                } catch {
                    if isPhoto {
                        print("[GroupSync] 画像再送信 recordName=\(recordID.recordName), \(Int(delay))秒後リトライに失敗 error=\(error)")
                    }
                    self.scheduleNextDelayedRetry(recordID: recordID, isPhoto: isPhoto, syncEngine: syncEngine, errorCode: errorCode)
                }
            }
        }
    }

    private func isRetryableError(_ error: CKError) -> Bool {
        switch error.code {
        case .networkUnavailable, .networkFailure, .requestRateLimited, .zoneBusy, .serviceUnavailable, .serverResponseLost:
            return true
        // .batchRequestFailed(コード22)は、このレコード自体に問題があるのではなく、
        // 同じ保存バッチ内の「別のレコード」が失敗したことに巻き込まれてロールバック
        // されただけ(本当の原因は別レコードのCKError側に付く)。原因側のレコードは
        // serverRecordChanged/ネットワーク系のリトライ経路で別途再送されるため、
        // このレコード自身は単純にもう一度同じ内容で送り直せばよい。
        case .batchRequestFailed:
            return true
        default:
            return false
        }
    }

    /// ここで積み直すだけでは、次に何か別の操作がsendChanges()を呼ぶまで実際の
    /// 再送信が行われず反映が遅延する。ただし、この関数自体はCKSyncEngineDelegate.
    /// handleEvent(.sentRecordZoneChanges)からの実行中(=CKSyncEngine内部の
    /// デリゲートコールバック呼び出しの真っ最中)であるため、ここで直接(あるいは
    /// 単純にTask{}で包んだだけで)sendChanges()を再度awaitすると、CKSyncEngine側の
    /// 「デリゲートコールバック中の再帰呼び出しは保証できない」安全装置に触れ、
    /// caulk::mach::semaphoreのデッドロックでクラッシュする
    /// (CKSyncEngine.___CKSyncEngine_cannot_guarantee_serial_delegate_callbacks_if_you_recurse___)。
    /// Task{}だけでは同じMainActor上で現在のhandleEvent呼び出しが完全に巻き戻る前に
    /// 実行され得るため、DispatchQueue.main.asyncでイベントループの次のサイクルまで
    /// 確実に逃がしてからTaskを起動する。
    private func retrySendAfterCurrentDelegateCallback(recordID: CKRecord.ID, isPhoto: Bool, syncEngine: CKSyncEngine, logSuffix: String) {
        DispatchQueue.main.async { [weak syncEngine] in
            guard let syncEngine else { return }
            Task { @MainActor in
                do {
                    try await syncEngine.sendChanges()
                    if isPhoto {
                        print("[GroupSync] 画像再送信 recordName=\(recordID.recordName), \(logSuffix)に成功")
                    }
                } catch {
                    if isPhoto {
                        print("[GroupSync] 画像再送信 recordName=\(recordID.recordName), \(logSuffix)に失敗 error=\(error)")
                    }
                }
            }
        }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = context.options.scope
        let changes = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        guard !changes.isEmpty else { return nil }

        var recordsByID: [CKRecord.ID: CKRecord] = [:]
        for change in changes {
            guard case .saveRecord(let recordID) = change else { continue }
            if let record = buildRecord(for: recordID) {
                recordsByID[recordID] = record
            }
        }

        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changes) { recordID in
            recordsByID[recordID]
        }
    }
}
