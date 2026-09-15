import Foundation
import SwiftData

/// World Later(匿名グローバルフィード)に公開された1枚。Public DBのWorldPostレコードの
/// ローカルキャッシュ。投稿者を特定できる情報(名前・ユーザー名・アイコン等)は
/// 一切保持しない — 保持しているのはisOwnPost(自分の投稿かどうかのローカル判定)
/// だけで、これはCKRecord.creatorUserRecordIDとCKContainer.userRecordID()を
/// ローカルで比較した結果であり、他ユーザーへ送信・表示することはない。
@Model
final class WorldPost {
    @Attribute(.unique) var id: UUID = UUID()
    @Attribute(.externalStorage) var imageData: Data
    var captureDate: Date
    /// 解禁時刻(撮影日の翌朝9:00、GroupUnlockPolicy.nextUnlockThreshold参照)。
    /// これに到達するまでは画像本体を表示せず、地域名・時刻・キャプションのみ見せる。
    var unlockDate: Date = Date()
    /// 実際に解禁済みかどうかのローカルキャッシュ表示用フラグ。真の判定は都度
    /// `Date() >= unlockDate` で行ってよいが、フェッチ直後の表示分岐を簡単にするため保持する。
    var isUnlocked: Bool = false
    /// 区市町村レベルまで丸めた撮影地の地名(CameraLocationNameProvider参照)。
    /// 緯度経度などの精密な位置情報は一切保持しない。
    var locationRegion: String?
    /// 撮影時に添えた一言キャプション。
    var caption: String?
    /// このpostが自分自身の投稿かどうか(削除ボタンの表示可否にのみ使う、完全ローカルの判定)。
    var isOwnPost: Bool = false
    /// Today's Laterで選ばれた回数のローカルキャッシュ(表示のみ、集計の正はCloudKit側)。
    var selectionCount: Int = 0
    /// この端末で「非表示」にしたかどうか(完全にローカルな設定)。World Laterは
    /// 投稿者を特定できる情報を一切持たない設計のため、特定の「人」をブロックする
    /// ことはできない(ブロックはCircleの既知メンバーに対してのみ意味を持つ)。
    /// 代わりに、個々の投稿を自分の画面からだけ非表示にできるようにする。
    var isHidden: Bool = false

    // CloudKit同期メタデータ(Public DB、WorldLaterService参照)
    var ckRecordName: String?
    var ckRecordChangeTag: String?

    init(
        imageData: Data,
        captureDate: Date = Date(),
        unlockDate: Date = Date(),
        isUnlocked: Bool = false,
        locationRegion: String? = nil,
        caption: String? = nil,
        isOwnPost: Bool = false
    ) {
        self.imageData = imageData
        self.captureDate = captureDate
        self.unlockDate = unlockDate
        self.isUnlocked = isUnlocked
        self.locationRegion = locationRegion
        self.caption = caption
        self.isOwnPost = isOwnPost
    }

    var imageCacheKey: String { ckRecordName ?? id.uuidString }
}
