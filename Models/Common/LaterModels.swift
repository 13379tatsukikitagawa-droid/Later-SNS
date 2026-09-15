import Foundation
import SwiftUI
import SwiftData

// MARK: - ユーザープロフィール
@Model
final class UserProfile {
    var id: UUID = UUID()
    var name: String
    var username: String
    var bio: String = "" // 🌟 一言バイオ（自己紹介）
    var profileImageData: Data?
    /// プロフィール(名前・自己紹介・写真)を最後に編集した日時。チェキ風プロフィール
    /// カードの日付表示に使う(撮影日ではなく更新日)。
    var profileUpdatedAt: Date?
    var inviteCode: String = ""
    var dailyGoal: Int = 3 // 🌟 目標枚数（初期値3）
    /// Sign in with Appleのユーザー識別子。同じApple IDで再サインインした際に
    /// 同じUserProfileを再利用するためのキー。
    var appleUserID: String?
    /// Firebase Authentication(メールのマジックリンク)でサインインした場合のユーザー識別子・
    /// メールアドレス。appleUserIDと同じ役割(同じメールで再サインインした際に同じ
    /// UserProfileを再利用するためのキー)を、Sign in with Apple以外の認証手段に対して果たす。
    ///
    /// 注意: CloudKitの同期範囲(cloudKitUserRecordName)はデバイスのiCloudアカウントに
    /// 紐づいており、Firebase Authとは独立した仕組みのため、この値だけでは変えられない。
    /// つまり、同じメールでも別のiCloudアカウントの端末からサインインした場合、
    /// アプリのアカウント(プロフィール識別)としては同一人物と認識できても、
    /// Circle/写真等のCloudKitデータそのものはその端末のiCloudアカウント側にしか存在しない
    /// (Appleの設計上、他社の認証基盤からCloudKitの同期範囲を越境させることはできない)。
    var firebaseUID: String?
    var firebaseEmail: String?

    /// プロフィール画面のPinsエリアにピン留めした写真(LaterPhoto.id)。ピン留め順を
    /// そのまま表示順にするため配列で保持する。最大件数はUserProfile.maxPinnedPhotos。
    /// このデータはローカル(SwiftData)のみで永続化し、CloudKitへは同期しない
    /// (UserProfileのCKRecordはグループごとに複製されるため、あくまで個人的な
    /// 表示設定であるピン留めをそこに載せると不要な複雑さが増えるため)。
    var pinnedPhotoIDs: [UUID] = []

    // CloudKit同期メタデータ
    /// CKContainer.userRecordID.recordName — CloudKit上のこのユーザーの識別子
    var cloudKitUserRecordName: String?
    var ckRecordName: String?
    var ckZoneName: String?
    var ckZoneOwnerName: String?
    var ckRecordChangeTag: String?

    // このユーザーが撮影した写真
    @Relationship(deleteRule: .cascade, inverse: \LaterPhoto.owner)
    var photos: [LaterPhoto] = []
    
    // このユーザーが参加しているグループ
    @Relationship
    var groups: [LaterGroup] = []
    
    private static func generateInviteCode(length: Int = 8) -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") // avoid ambiguous chars
        return String((0..<length).map { _ in chars.randomElement()! })
    }
    
    init(name: String, username: String, dailyGoal: Int = 3) {
        self.id = UUID()
        self.name = name
        self.username = username
        self.dailyGoal = dailyGoal
        self.inviteCode = UserProfile.generateInviteCode()
    }
}

extension UserProfile {
    /// Pinsエリアにピン留めできる写真の最大枚数。
    static let maxPinnedPhotos = 6

    /// 「自分」を安全に解決する。CloudKit同期でグループメンバーの
    /// UserProfileがローカルに増えると`profiles.first`は他人を指しうるため、
    /// 必ずこちらを使うこと。
    static func current(from profiles: [UserProfile]) -> UserProfile? {
        if let idString = UserDefaults.standard.string(forKey: "currentProfileID"),
           let id = UUID(uuidString: idString),
           let match = profiles.first(where: { $0.id == id }) {
            return match
        }
        return profiles.first
    }

    /// 直近(昨日を起点)から連続して、いずれかのグループで1日最低撮影枚数を
    /// 達成できている日数。ME(personalSpaceGroupIDsで渡される個人スペース)の
    /// 写真は共同実績にカウントしないため除外する。ProfileViewのストリーク表示・
    /// カメラ画面の控えめな連続記録表示の両方から呼ばれる、二重管理を避けるための
    /// 共通ロジック。
    func currentStreak(personalSpaceGroupIDs: Set<UUID>, calendar: Calendar = .current) -> Int {
        let countablePhotos = photos.filter { photo in
            guard let groupID = photo.groupID else { return true }
            return !personalSpaceGroupIDs.contains(groupID)
        }
        var count = 0
        var day = calendar.startOfDay(for: Date())
        for _ in 0..<3650 {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
            let photosThatDay = countablePhotos.filter { calendar.isDate($0.captureDate, inSameDayAs: day) }
            guard photosThatDay.count >= GroupUnlockPolicy.individualMinimumPhotoCount else { break }
            count += 1
        }
        return count
    }
}

// MARK: - 撮影した写真 (思い出の封印データ)
@Model
final class LaterPhoto {
    var id: UUID = UUID()
    @Attribute(.externalStorage) var imageData: Data
    var captureDate: Date
    var unlockDate: Date
    var isUnlocked: Bool = false
    /// ChekiColorGrade.bakeIntoImageData(_:)でFilmEmulationの焼き込みが完了済みかどうか。
    /// isUnlocked==falseから移行する前(=このプロパティ導入前)に既に解禁済みだった写真は
    /// falseのままなので、CloudKitManager.migrateChekiGradingForOwnPhotos()の対象になる。
    /// 焼き込み処理を誤って二重適用しない(=同じ画像に多重にグレイン等を重ねない)ための
    /// 冪等性ガードも兼ねる。
    var isColorGraded: Bool = false
    /// この写真の画像本体(CKAsset)が、少なくとも一度はCloudKitへの保存に成功したか。
    /// CloudKitManager.markSynced(_:)が、画像フィールドを含む保存の成功を確認した時点で
    /// trueにする。CloudKitManager.resendOwnUnlockedPhotosIfNeeded()が「解禁済みなのに
    /// 画像がまだ届いていない写真」だけをDB側の#Predicateで絞り込むために使う
    /// (グループ数・写真数が増えても、無関係な写真まで毎回全件取得しないようにするため)。
    var isImageUploaded: Bool = false

    // 🌟 キャプション（記憶の封印）
    var caption: String?

    /// 撮影地の地名(逆ジオコーディング結果、市区町村名程度)。位置情報の許可が無い/
    /// 取得に失敗した場合はnil(TrueBlindCameraView.CameraLocationNameProvider参照)。
    var locationName: String?

    // 撮影者（所有者）
    @Relationship
    var owner: UserProfile?
    /// ownerのCloudKit識別子。ownerはローカルのリレーションシップなので、他端末が
    /// このレコードを受信した際に「誰が撮影したか」を判定できる唯一の手がかりとして使う。
    var authorCloudKitUserRecordName: String?
    /// 撮影者名のキャッシュ(owner解決前でも表示に使えるように)
    var authorNameCache: String?
    var groupID: UUID?
    /// 撮影時のグループ名のキャッシュ。PhotoNotificationService(撮影通知の
    /// CKQuerySubscription)のアラート文言(タイトルにグループ名を含める)で、
    /// レコード自身のフィールドだけから文言を組み立てる必要があるために持たせている
    /// (authorNameCacheと同じ理由)。
    var groupNameCache: String?

    // 🏆 グループ投票関連
    var voteCount: Int = 0
    var isGroupBestShot: Bool = false // その日のグループベストに選ばれたか
    var votingClosedAt: Date? // 投票締切時刻

    // 🎭 匿名性管理
    var votingPhaseActive: Bool = false // 投票フェーズ中はtrue

    // CloudKit同期メタデータ
    var ckRecordName: String?
    var ckZoneName: String?
    var ckZoneOwnerName: String?
    var ckRecordChangeTag: String?

    /// 画像キャッシュ(PhotoImageCache/ChekiColorGrade)用の安定したキー。ckRecordNameは
    /// CloudKitへの初回保存が完了するまでnilのため、それまではローカルのidにフォールバックする
    /// (どちらもアプリ再起動をまたいで変わらない値で、data.hashValueのようにプロセスごとに
    /// 変化しない)。
    var imageCacheKey: String { ckRecordName ?? id.uuidString }

    init(imageData: Data, captureDate: Date = Date(), unlockDate: Date, owner: UserProfile? = nil, caption: String? = nil) {
        self.id = UUID()
        self.imageData = imageData
        self.captureDate = captureDate
        self.unlockDate = unlockDate
        self.owner = owner
        self.caption = caption
    }
}

// MARK: - 撮影者の匿名化

extension LaterPhoto {
    /// 撮影者情報(ユーザー名・プロフィール画像)を表示してよいかどうか。
    /// 「その日のグループベストに選ばれた」瞬間(=投票が締め切られ、今日の一枚が
    /// 決定した後)にのみtrueになる。それ以外(投票前・投票中、かつ最終的に
    /// ベストに選ばれなかった写真は投票後も含め)は常にfalseで、一覧・詳細画面側は
    /// これに応じて名前を「匿名メンバー」に、アバターを非表示に切り替える。
    var isAuthorRevealed: Bool {
        isGroupBestShot
    }

    /// 匿名フェーズでの代替表示名。
    static let anonymousAuthorLabel = "匿名メンバー"
}

// MARK: - 投票記録
@Model
final class PhotoVote {
    var id: UUID = UUID()
    var photo: LaterPhoto?
    var voter: UserProfile?
    var votedAt: Date
    var reactionSpeed: TimeInterval // 解禁からの投票速度（秒）

    /// photo/voterのローカルUUIDだけでなく、CloudKit上で解決するための識別子
    var photoID: UUID?
    var groupID: UUID?
    var voterCloudKitUserRecordName: String?
    /// 通常投票=1、同票による決選投票=2以降
    var roundNumber: Int = 1

    // CloudKit同期メタデータ
    var ckRecordName: String?
    var ckZoneName: String?
    var ckZoneOwnerName: String?
    var ckRecordChangeTag: String?

    init(photo: LaterPhoto, voter: UserProfile, reactionSpeed: TimeInterval = 0) {
        self.id = UUID()
        self.photo = photo
        self.voter = voter
        self.votedAt = Date()
        self.reactionSpeed = reactionSpeed
    }
}

// MARK: - グループ（サークル）
// LaterGroup の定義は LaterGroup_Updated.swift に移動されました

