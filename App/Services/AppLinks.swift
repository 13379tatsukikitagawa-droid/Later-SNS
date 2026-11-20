import Foundation

/// v108 §5:リンクの ドメインと ストアの URL を 1か所に まとめる(独自ドメインに かえる 時は ここだけ)。
enum AppLinks {
    /// いまの 共有リンクの ドメイン(Firebase Hosting)
    static let webHost = "later-app-f2606.firebaseapp.com"
    /// 公開前は TestFlight の 公開リンク(あれば)に かえる
    static let storeURL = "https://apps.apple.com/app/id6797838593"

    static func friendURL(handle: String) -> URL? { URL(string: "https://\(webHost)/u/\(handle)?openExternalBrowser=1") }
    static func tripURL(token: String) -> URL? { URL(string: "https://\(webHost)/t/\(token)?openExternalBrowser=1") }

    enum Link: Equatable { case friend(handle: String), trip(token: String) }

    /// どの ドメインの `/u/<ID>` `/t/<トークン>` も うけとる(持って いない ドメインの リンクは 受けない)
    static func parse(_ url: URL) -> Link? {
        // ページの「アプリで ひらく」:later://u/<ID> ・ later://t/<トークン>
        if Brand.isOurScheme(url), let h = url.host?.lowercased(), h == "u" || h == "t" {
            let id = url.lastPathComponent
            guard !id.isEmpty, id != "/", id.count <= 40 else { return nil }
            if h == "t" { return .trip(token: id) }
            let n = HandleRules.normalize(id)
            return HandleRules.validate(n) == nil ? .friend(handle: n) : nil
        }
        guard let host = url.host?.lowercased(), host == webHost else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, !parts[1].isEmpty, parts[1].count <= 40 else { return nil }
        switch parts[0] {
        case "u":
            let h = HandleRules.normalize(parts[1])
            return HandleRules.validate(h) == nil ? .friend(handle: h) : nil
        case "t": return .trip(token: parts[1])
        default: return nil
        }
    }

    /// 貼りつけた 文から(`/u/…` `/t/…` の どちらも)
    static func parse(text: String) -> Link? {
        text.split(whereSeparator: { $0.isWhitespace }).lazy.compactMap { URL(string: String($0)) }.compactMap { parse($0) }.first
    }
}
