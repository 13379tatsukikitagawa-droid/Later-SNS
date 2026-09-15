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
    static let scheme = "later"
    static let host = "join"

    /// CKShareの標準URLから、アプリ直接起動用のカスタムURLを組み立てる。
    /// パーセントエンコードに失敗することは通常無いが、失敗時はnilを返すため
    /// 呼び出し側は `GroupJoinLink.buildURL(shareURL: url) ?? url` のように
    /// 元のURLへフォールバックすること。
    static func buildURL(shareURL: URL) -> URL? {
        guard let encoded = shareURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "\(scheme)://\(host)?shareUrl=\(encoded)")
    }

    /// later://join?shareUrl=... から、元のCKShare標準URLを取り出す。
    /// scheme/hostが一致しない、またはshareUrlクエリが無い/不正な場合はnilを返す。
    static func extractShareURL(from url: URL) -> URL? {
        guard url.scheme == scheme, url.host == host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let shareURLString = components.queryItems?.first(where: { $0.name == "shareUrl" })?.value,
              let shareURL = URL(string: shareURLString)
        else {
            return nil
        }
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
