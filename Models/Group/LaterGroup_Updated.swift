import Foundation
import SwiftUI
import SwiftData

/// グループ（Circle）のデータモデル
@Model
class LaterGroup {
    var id: UUID = UUID()
    var name: String
    var creationDate: Date
    var inviteCode: String = "" // グループ招待コード

    /// グループアイコン画像。オーナーに限らず、全メンバーが変更できる
    /// (EditGroupView参照)。未設定ならnilのままで、表示側がプレースホルダーに切り替える。
    var iconImageData: Data?

    /// グループ作成時にカラーステッカーで選んだアクセント色(#RRGGBB、Color(hex:)で復元)。
    /// グループ一覧画面などのアバターリング色に使う。未設定ならデフォルトのアクセント色。
    var accentColorHex: String?

    // 🌟 グループに参加しているユーザーたち
    @Relationship(inverse: \UserProfile.groups)
    var members: [UserProfile] = []
    
    // 🌟 グループで共有されている写真たち
    @Relationship(deleteRule: .cascade)
    var photos: [LaterPhoto] = []

    // 🎬 グループで共有されている動画たち。目標達成枚数のカウントは写真と合算する
    // (LaterGroup.currentCycleVideos()/currentCycleContentCount(ownerID:)参照)。
    @Relationship(deleteRule: .cascade)
    var videos: [LaterVideo] = []

    // 🏆 ホスト管理
    @Relationship
    var host: UserProfile?
    
    // 🎯 グループ設定
    var autoGenerateMission: Bool = false // ミッション自動生成
    var isPrivate: Bool = true // プライバシー設定（true: 招待のみ, false: 検索可能）
    var currentDailyMission: String? // 今日のミッション
    var missionGeneratedDate: Date? // ミッション生成日

    /// 全ユーザーがデフォルトで持つ、個人用の疑似グループ「ME」かどうか。
    /// true の場合、投票フェーズ・1日5枚上限・共同実績(選出回数/連続選出)の
    /// カウント対象から外れる(判定はGroupStatusPresenter/GroupUnlockPolicy/
    /// ProfileView側で分岐する。ここでは単なるフラグの保持のみ)。
    var isPersonalSpace: Bool = false

    // CloudKit同期メタデータ(このグループはCKShareのルートレコード)
    var ownerCloudKitUserRecordName: String?
    var ckRecordName: String?
    var ckZoneName: String?
    var ckZoneOwnerName: String?
    var ckRecordChangeTag: String?
    /// CKShare.url(招待コード経路の解決結果をキャッシュ)
    var ckShareURL: String?

    /// 「自分自身のUserProfileレコード(このグループの共有ゾーン内、
    /// recordName="profile_<自分のid>_<このグループのid>")」の、直近の送信成功時点の
    /// recordChangeTag。UserProfileはユーザーごとに1つのローカルオブジェクトだが、
    /// 複数グループに参加すると、そのグループの数だけ別々のCKRecord(recordNameが
    /// グループごとに異なる)を送信する必要がある。以前はこの状態をUserProfile側の
    /// 単一のckRecordChangeTagフィールドで管理しており、あるグループへの送信成功で
    /// セットされたタグが別のグループへの送信要否判定に誤って使い回され、
    /// 新しく参加したグループには一度もプロフィールが送信されない不具合があった。
    /// この値はグループ自身(=グループごとに一意なオブジェクト)に持たせることで、
    /// 「自分がこのグループへ自分のプロフィールを送信済みかどうか」を
    /// グループ単位で正しく判定できるようにする(CloudKitManager.markSynced/
    /// GroupSharingService.uploadOwnProfile参照)。
    var myProfileCKRecordChangeTag: String?

    /// 「ME」の当日の目標撮影枚数(1〜20)。isPersonalSpace限定の概念で、ユーザー自身が
    /// 日ごとに設定する。その日まだ確定していない場合は1をデフォルトとして扱う
    /// (以前の「最低1枚撮ればその日は解禁対象」という挙動を後方互換で維持する)。
    var personalDailyTargetCount: Int = 1

    /// 直近の解禁が実際に起きた瞬間。時間帯制限(ランダム解禁時刻・クールダウン)を
    /// 撤廃したことで、「今のサイクル」の境界は日付から計算できる値ではなく、
    /// 「全員が撮り終えて実際に解禁された瞬間」というサーバーイベントになった。
    /// 全メンバー間でこの境界を一致させる必要があるため、CKRecordConvertibleで
    /// 同期する(CloudKitManager.evaluateGroupUnlockConditions参照)。
    /// nilは「一度も解禁されたことがない(=creationDateが境界)」を意味する。
    var lastUnlockAt: Date?

    /// 直近でpersonalDailyTargetCountを確定した日付。この日付が「今日」でなければ、
    /// ME画面を開いた際に目標設定シートを表示する(日付が変わるたびに再設定を促す)。
    var personalTargetLastSetDate: Date?

    private static func generateGroupCode(length: Int = 6) -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<length).map { _ in chars.randomElement()! })
    }
    
    init(name: String, host: UserProfile? = nil, autoGenerateMission: Bool = false, isPrivate: Bool = true) {
        self.id = UUID()
        self.name = name
        self.creationDate = Date()
        self.host = host
        self.inviteCode = Self.generateGroupCode()
        self.autoGenerateMission = autoGenerateMission
        self.isPrivate = isPrivate
    }
}

// MARK: - グループメンバー管理の拡張

extension LaterGroup {
    /// メンバーがグループに所属しているかチェック(ローカルUUID一致のみ)。
    /// idの出どころが分からない/UserProfileオブジェクトを持っていない場面
    /// (例: CKRecordのreferenceから取り出したUUIDだけを持つ場合)専用。
    /// UserProfileオブジェクトを持っている場合は、同一人物の重複オブジェクトも
    /// 検出できるisMember(_:)を使うこと。
    func isMember(userID: UUID) -> Bool {
        members.contains(where: { $0.id == userID })
    }

    /// idに加えてcloudKitUserRecordName(恒久的な識別子)でも一致を見る、
    /// より正確な所属判定。ローカルに同一人物を指す複数のUserProfileオブジェクト
    /// (idは異なるがcloudKitUserRecordNameは同じ)が存在してしまった場合でも、
    /// 「既にメンバーとして扱われている」と正しく判定できる
    /// (isMember(userID:)だけだとidだけの一致判定のため、この重複を見逃し
    /// addMemberで二重に追加してしまう不具合があった)。
    func isMember(_ profile: UserProfile) -> Bool {
        if isMember(userID: profile.id) { return true }
        guard let cloudKitUserRecordName = profile.cloudKitUserRecordName, !cloudKitUserRecordName.isEmpty else {
            return false
        }
        return members.contains(where: { $0.cloudKitUserRecordName == cloudKitUserRecordName })
    }

    /// メンバーを追加(重複チェック付き)。isMember(_:)によりcloudKitUserRecordName
    /// ベースの重複も検出するため、同一人物の別UserProfileオブジェクトが既に
    /// メンバーになっていれば追加しない。
    func addMember(_ user: UserProfile) -> Bool {
        guard !isMember(user) else {
            return false // すでにメンバー
        }
        members.append(user)
        return true
    }
    
    /// メンバーを削除
    func removeMember(userID: UUID) -> Bool {
        guard let index = members.firstIndex(where: { $0.id == userID }) else {
            return false // メンバーが見つからない
        }
        members.remove(at: index)
        return true
    }
    
    /// ホストかどうかをチェック(ローカルのhostリレーションシップ基準。作成した本人の
    /// 端末でのみ正しい — hostフィールドはCloudKitへ同期されないため、他メンバーの
    /// 端末では常にfalseになる。他メンバーの端末でも正しく判定したい場合は
    /// isHost(cloudKitUserRecordName:)を使うこと)。
    func isHost(userID: UUID) -> Bool {
        return host?.id == userID
    }

    /// ownerCloudKitUserRecordName(CKRecordとして全メンバー間で同期される、現在の
    /// アプリ内ホストのiCloud識別子)を基準にホストかどうかを判定する。脱退時の
    /// ホスト引き継ぎ後も、全メンバーの端末で正しく最新のホストを反映できる。
    func isHost(cloudKitUserRecordName: String?) -> Bool {
        guard let cloudKitUserRecordName, !cloudKitUserRecordName.isEmpty else { return false }
        return ownerCloudKitUserRecordName == cloudKitUserRecordName
    }
}

extension Sequence where Element == LaterGroup {
    /// Home画面の一覧・デフォルト選択で使う並び順: MEを先頭に、それ以外は元の順序のまま。
    func meFirstOrdered() -> [LaterGroup] {
        let me = filter(\.isPersonalSpace)
        let others = filter { !$0.isPersonalSpace }
        return me + others
    }
}

// MARK: - 個人用スペース「ME」

extension LaterGroup {
    static let personalSpaceName = "ME"

    /// このプロフィールが既にMEを持っていればそれを返し、無ければ新規作成して返す。
    /// アカウント作成時(オンボーディング完了時)に加え、既存ユーザーへの遡及付与
    /// (アプリ起動時の補完呼び出し)にも使う冪等なヘルパー。ME同士の重複作成を防ぐため
    /// 必ずこの関数経由で作成すること。
    @discardableResult
    static func ensurePersonalSpace(for profile: UserProfile, context: ModelContext) -> LaterGroup {
        if let existing = profile.groups.first(where: { $0.isPersonalSpace }) {
            return existing
        }
        let me = LaterGroup(name: personalSpaceName, host: profile, autoGenerateMission: false, isPrivate: true)
        me.isPersonalSpace = true
        context.insert(me)
        _ = me.addMember(profile)
        return me
    }
}

// MARK: - グループ写真管理の拡張

extension LaterGroup {
    /// 現在進行中(まだ解禁されていない)撮影サイクルに属する写真を取得。時間帯制限の
    /// 撤廃に伴い、サイクルの境界は日付からの計算ではなく、直近に実際に解禁が起きた
    /// 瞬間(lastUnlockAt)になった。一度も解禁されたことがなければcreationDateが
    /// 境界になる。
    func currentCyclePhotos(now: Date = Date(), calendar: Calendar = .current) -> [LaterPhoto] {
        let boundary = lastUnlockAt ?? creationDate
        return photos.filter { $0.captureDate > boundary }
    }

    /// 現在進行中サイクルに属する動画(currentCyclePhotosの動画版)。
    func currentCycleVideos(now: Date = Date(), calendar: Calendar = .current) -> [LaterVideo] {
        let boundary = lastUnlockAt ?? creationDate
        return videos.filter { $0.captureDate > boundary }
    }

    /// 直近に解禁されたサイクルに属する写真。解禁の瞬間、そのサイクルの写真は
    /// unlockDateがlastUnlockAtと同じ値に揃えられる(CloudKitManager.
    /// evaluateGroupUnlockConditions参照)ため、その一致で「直近の解禁バッチ」を
    /// 特定できる。一度も解禁されたことがなければ空配列。
    func mostRecentCyclePhotos(now: Date = Date(), calendar: Calendar = .current) -> [LaterPhoto] {
        guard let lastUnlockAt else { return [] }
        return photos.filter { $0.isUnlocked && $0.unlockDate == lastUnlockAt }
    }

    /// 直近に解禁されたサイクルに属する動画(mostRecentCyclePhotosの動画版)。
    /// evaluateGroupUnlockConditionsは写真と動画の両方にunlockDate=lastUnlockAtを
    /// 揃えて設定するため、判定方法は写真と完全に同じでよい。
    func mostRecentCycleVideos(now: Date = Date(), calendar: Calendar = .current) -> [LaterVideo] {
        guard let lastUnlockAt else { return [] }
        return videos.filter { $0.isUnlocked && $0.unlockDate == lastUnlockAt }
    }

    /// 目標達成枚数のカウントは写真・動画を合算する(仕様変更)。現在進行中サイクルで
    /// 指定ユーザーが撮影した写真+動画の合計枚数。isSelectable(枚数上限判定)・
    /// 解禁条件判定(CloudKitManager.evaluateGroupUnlockConditions)双方で同じ考え方を使う。
    func currentCycleContentCount(ownerID: UUID, now: Date = Date(), calendar: Calendar = .current) -> Int {
        currentCyclePhotos(now: now, calendar: calendar).filter { $0.owner?.id == ownerID }.count
            + currentCycleVideos(now: now, calendar: calendar).filter { $0.owner?.id == ownerID }.count
    }

    /// 特定の日に選出された(1票以上入った)写真をすべて取得。複数枚が同時に
    /// 選出される場合があるため配列で返す(単一の「今日の一枚」という制約は廃止)。
    func getBestShots(for date: Date) -> [LaterPhoto] {
        let calendar = Calendar.current

        return photos.filter { photo in
            photo.isGroupBestShot && calendar.isDate(photo.captureDate, inSameDayAs: date)
        }
    }
    
    /// アンロック済みの写真のみを取得
    func getUnlockedPhotos() -> [LaterPhoto] {
        photos.filter { $0.isUnlocked }
    }
    
    /// 投票中の写真を取得
    func getVotingPhotos() -> [LaterPhoto] {
        photos.filter { $0.votingPhaseActive }
    }
}

// MARK: - グループ統計の拡張

extension LaterGroup {
    /// グループの活動日数
    var activeDays: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(photos.map { calendar.startOfDay(for: $0.captureDate) })
        return uniqueDays.count
    }
    
    /// 総写真数
    var totalPhotos: Int {
        photos.count
    }
    
    /// メンバー数
    var memberCount: Int {
        members.count
    }

    /// cloudKitUserRecordName(恒久的な識別子)を基準に重複除去した、メンバーの
    /// idリスト。addMember(_:)/isMember(_:)による重複防止・CloudKitManager.
    /// deduplicateGroupMembers()による既存データのマイグレーションを入れても、
    /// 万一membersに同一人物の重複UserProfileが残っていた場合に、目標撮影枚数・
    /// 達成人数の集計(GroupStatusPresenter/CloudKitManager.evaluateGroupUnlockConditions)
    /// だけは水増しされないようにするための保険。cloudKitUserRecordNameが
    /// 未同期のメンバーはid単位でそのまま数える(重複しているかどうか判断できないため)。
    var deduplicatedMemberIDs: [UUID] {
        var seenKeys = Set<String>()
        var result: [UUID] = []
        for member in members {
            let key: String
            if let cloudKitUserRecordName = member.cloudKitUserRecordName, !cloudKitUserRecordName.isEmpty {
                key = cloudKitUserRecordName
            } else {
                key = "local_\(member.id.uuidString)"
            }
            guard seenKeys.insert(key).inserted else { continue }
            result.append(member.id)
        }
        return result
    }
    
    /// グループの年齢（作成からの日数）
    var ageInDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: creationDate, to: Date())
        return components.day ?? 0
    }
}

// MARK: - グループバリデーション

extension LaterGroup {
    /// グループ名が有効かチェック
    var isValidName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// 招待コードが有効かチェック
    var isValidInviteCode: Bool {
        !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// グループが有効かチェック
    var isValid: Bool {
        isValidName && !members.isEmpty
    }
}
