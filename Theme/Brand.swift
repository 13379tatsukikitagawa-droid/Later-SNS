import Foundation

/// v62:アプリの 名前は ここだけに 書く。画面・共有の 文・通知は `Brand` から 出す。
/// 中身の 名前(Bundle ID・型名・Firebase・CloudKit・フォント名 `Later Mincho`)は 変えない。
enum Brand {
    /// 画面・共有の 文章
    static let name = "Lattag"
    /// 大文字の ラベル(LATTAG · FRIEND CARD など)
    static let caps = "LATTAG"
    /// 読み(Siri・VoiceOver)
    static let spoken = "レイタグ"
    /// `lattag://join?shareUrl=...`
    static let scheme = "lattag"
    /// 古い 招待リンク(`later://`)も 開く
    static let legacyScheme = "later"
    /// `https://later-app-f2606.firebaseapp.com/u/<id>`(ドメイン 取得前は 今の ドメインの まま 使える よう 1か所に)
    static let domain = "later-app-f2606.firebaseapp.com"   // v108:持って いる ドメインだけ(lattag.app は 持って いない)

    /// 受けつける URL スキーム(新しい もの + 古い もの)
    static let acceptedSchemes: Set<String> = [scheme, legacyScheme, "laterapp"]

    static func isOurScheme(_ url: URL) -> Bool {
        guard let s = url.scheme?.lowercased() else { return false }
        return acceptedSchemes.contains(s)
    }
}
