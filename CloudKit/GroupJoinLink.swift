import Foundation

/// later://join?shareUrl=<エンコードされたCKShare URL> 形式の、アプリを直接起動して
/// グループへ参加するためのカスタムURLスキームリンク。
///
/// CKShare標準のURL(https://www.icloud.com/share/...)は、iOS側の判断でSafari/iCloud標準
/// 画面が開いてしまう既知の問題があるため、共有時にこのカスタムスキームでラップして送る。
/// 受け取り側の実処理(CKShare.Metadataの解決〜受諾)は、CKShare標準URLをそのまま扱う
/// 既存のGroupSharingService.resolveShareMetadata/acceptShareをそのまま再利用する
/// (このラッパーはURLの組み立て/分解だけを担当し、CloudKit連携ロジックには一切手を入れない)。
enum GroupJoinLink {
    static let scheme = Brand.scheme  // 新しい リンク。古い later:// も 受けつける
    static let host = "join"

    /// CKShareの標準URLから、アプリ直接起動用のカスタムURLを組み立てる。
    /// v22 J-2:以前と同じ形に戻す。`shareUrl=` のあとは エンコードしない
    /// (例:later://join?shareUrl=https://www.icloud.com/share/048QUuOQglIyxDdrKDRVre3wg)。
    /// 組み立てに失敗したときだけ、エンコードした形にする。nil なら呼び出し側で元のURLへフォールバック。
    static func buildURL(shareURL: URL) -> URL? {
        let raw = shareURL.absoluteString
        if let url = URL(string: "\(scheme)://\(host)?shareUrl=\(raw)"), extractShareURL(from: url) == shareURL {
            return url
        }
        guard let encoded = raw.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        return URL(string: "\(scheme)://\(host)?shareUrl=\(encoded)")
    }

    /// later://join?shareUrl=... から、元のCKShare標準URLを取り出す(エンコードあり・なし どちらも読める)。
    /// scheme/hostが一致しない、またはshareUrlクエリが無い/不正な場合はnilを返す。
    static func extractShareURL(from url: URL) -> URL? {
        guard Brand.isOurScheme(url), url.host == host else { return nil }
        // shareUrl= のうしろを そのまま 取る(エンコードなしだと、CKShare の URL の中の ? や # で 切れることがあるため)
        let text = url.absoluteString
        guard let range = text.range(of: "shareUrl=") else { return nil }
        var value = String(text[range.upperBound...])
        if value.lowercased().hasPrefix("http%3a") || value.contains("%2F") || value.contains("%2f") {
            value = value.removingPercentEncoding ?? value
        }
        guard let shareURL = URL(string: value), shareURL.scheme?.hasPrefix("http") == true else { return nil }
        return shareURL
    }

    /// CKShare標準URL(https://www.icloud.com/share/...)そのものかどうかを判定する。
    /// LINEやメールなど、this appのlater://ラッパーを経由せず素のCKShare URLがそのまま
    /// 共有された場合、OSのCKShare専用ルーティング(userDidAcceptCloudKitShareWith)が
    /// 何らかの理由で発火せず、代わりに通常のURLとしてonOpenURLに渡ってくることがある。
    /// その場合でも同じ参加処理へフォールバックできるようにするための判定。
    static func isCKShareURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.hasSuffix("icloud.com") && url.path.hasPrefix("/share/")
    }
}
