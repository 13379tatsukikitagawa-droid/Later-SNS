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
    /// このpostが自分自身の投稿かどうか(削除ボタンの表示可否にのみ使う、完全ローカルの判定)。
    var isOwnPost: Bool = false
    /// Today's Laterで選ばれた回数のローカルキャッシュ(表示のみ、集計の正はCloudKit側)。
    var selectionCount: Int = 0
    /// この端末で「非表示」にしたかどうか(完全にローカルな設定)。World Laterは
    /// 投稿者を特定できる情報を一切持たない設計のため、特定の「人」をブロックする
    /// ことはできない(ブロックはCircleの既知メンバーに対してのみ意味を持つ)。
    /// 代わりに、個々の投稿を自分の画面からだけ非表示にできるようにする。
    var isHidden: Bool = false

    /// 市区町村レベルまで粗く丸めた地名(実位置情報ベース。CLGeocoderのlocality/
    /// subLocalityをそのまま使う、装飾的な文字列ではない)。取得できなかった場合はnil。
    var locationRegion: String?
    /// 地図ピン配置用に、実際のGPS座標を小数点2桁(約1km四方)まで粗く丸めた値。
    /// 同じ丸め座標を持つ投稿同士は、自然に同一ピンへクラスタリングされる。
    var roundedLatitude: Double?
    var roundedLongitude: Double?
    /// 投稿に添えた一言キャプション。
    var caption: String?
    /// 翌朝9:00の解禁タイミング(captureDateの翌日9:00)。この時刻を過ぎるまで写真本体は
    /// ロックされ、地域・時刻・キャプションだけが先出しで見える。
    var unlockDate: Date = Date()
    /// 投稿時にローカルで抽出した代表色(HEX文字列、2〜3色)。Home画面「現像中の写真の壁」で、
    /// 画像データそのものをダウンロードせずに「何かが写っている気配」だけを見せるために使う。
    var dominantColorHexes: [String] = []

    // CloudKit同期メタデータ(Public DB、WorldLaterService参照)
    var ckRecordName: String?
    var ckRecordChangeTag: String?

    init(
        imageData: Data,
        captureDate: Date = Date(),
        isOwnPost: Bool = false,
        locationRegion: String? = nil,
        roundedLatitude: Double? = nil,
        roundedLongitude: Double? = nil,
        caption: String? = nil,
        unlockDate: Date = Date()
    ) {
        self.imageData = imageData
        self.captureDate = captureDate
        self.isOwnPost = isOwnPost
        self.locationRegion = locationRegion
        self.roundedLatitude = roundedLatitude
        self.roundedLongitude = roundedLongitude
        self.caption = caption
        self.unlockDate = unlockDate
    }

    var imageCacheKey: String { ckRecordName ?? id.uuidString }

    /// 解禁済みかどうか(翌朝9:00の解禁タイミングを過ぎているか)。
    var isUnlocked: Bool { Date() >= unlockDate }
}
