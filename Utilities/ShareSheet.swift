import SwiftUI
import UIKit
import LinkPresentation

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    /// 共有が完了した(true)/キャンセルされた(false)いずれの場合でも呼ばれる。
    /// 呼び出し側はここで画面を閉じる(dismiss)想定。
    var onCompletion: ((Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        if let onCompletion {
            controller.completionWithItemsHandler = { _, completed, _, _ in
                onCompletion(completed)
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum LinkInviteGenerator {
    static func profileInviteURL(for id: UUID, code: String? = nil) -> URL {
        if let code, !code.isEmpty {
            return URL(string: "https://later.app/i/\(code)")!
        } else {
            return URL(string: "https://later.app/user/\(id.uuidString)")!
        }
    }
}

// MARK: - 共有の 中身(v111 §2 ・ 友だち と Trip で 1つ)

/// 共有シートに 渡す 物。送る 中身は 文と URL のまま、共有シートの 左上の 絵だけ Lattag の アイコン(Assets の `AppIconShare` ・ 1024px ・ 角丸は iOS が つける)に する。
final class LattagShareItem: NSObject, UIActivityItemSource {
    let text: String
    let title: String
    let url: URL?

    init(text: String, title: String, url: URL? = nil) {
        self.text = text
        self.title = title
        self.url = url ?? Self.firstURL(in: text)
    }

    /// 友だち:「たつき から Lattag の 友だち申請」
    static func friend(text: String, name: String) -> LattagShareItem {
        LattagShareItem(text: text, title: name.isEmpty ? "Lattag の 友だち申請" : "\(name) から Lattag の 友だち申請")
    }

    /// Trip:「『修学旅行』の Trip に 招待」
    static func trip(text: String, groupName: String) -> LattagShareItem {
        LattagShareItem(text: text, title: "『\(groupName)』の Trip に 招待")
    }

    static func firstURL(in text: String) -> URL? {
        guard let d = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let r = NSRange(text.startIndex..., in: text)
        return d.firstMatch(in: text, options: [], range: r)?.url
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any { text }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? { text }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String { title }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.originalURL = url
        metadata.url = url
        if let icon = UIImage(named: "AppIconShare") {
            metadata.iconProvider = NSItemProvider(object: icon)
            metadata.imageProvider = NSItemProvider(object: icon)
        }
        return metadata
    }
}
