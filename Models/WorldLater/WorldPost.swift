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

    // CloudKit同期メタデータ(Public DB、WorldLaterService参照)
    var ckRecordName: String?
    var ckRecordChangeTag: String?

    init(imageData: Data, captureDate: Date = Date(), isOwnPost: Bool = false) {
        self.imageData = imageData
        self.captureDate = captureDate
        self.isOwnPost = isOwnPost
    }

    var imageCacheKey: String { ckRecordName ?? id.uuidString }
}
