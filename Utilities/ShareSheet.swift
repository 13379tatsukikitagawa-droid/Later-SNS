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
final class ProfileShareItem: NSObject, UIActivityItemSource {
    private let name: String
    private let username: String
    private let url: URL
    private let descriptionText: String?

    init(name: String, username: String, url: URL, description: String? = nil) {
        self.name = name
        self.username = username
        self.url = url
        self.descriptionText = description
    }

    // MARK: - UIActivityItemSource
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "\(name) (@\(username)) on Later"
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = url
        metadata.url = url
        if let desc = descriptionText, !desc.isEmpty {
            metadata.title = "\(name) (@\(username)) — \(desc)"
        } else {
            metadata.title = "\(name) (@\(username)) on Later"
        }
        return metadata
    }
}

/// グループ招待リンクの共有用。プレーンテキストとして共有する(URLオブジェクトのまま
/// 渡すと、LINE等一部アプリの共有シートで「Cannot issue sandbox extension」エラーに
/// なり共有自体が失敗することがあったため)。ただし、プレーンテキストのままだと
/// UIActivityViewControllerのプレビューが汎用の「A」アイコンになってしまうため、
/// activityViewControllerLinkMetadata(_:)でLaterのロゴ入りLPLinkMetadataを返し、
/// プレビューにアプリらしいアイコン・タイトルが出るようにする。
final class ShareLinkItemSource: NSObject, UIActivityItemSource {
    private let text: String
    private let title: String

    init(text: String, title: String) {
        self.text = text
        self.title = title
    }

    // MARK: - UIActivityItemSource
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        text
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        text
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        title
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        // Media.xcassets内の"Later"(通常のimageset、AppIcon本体と同じシャッターロゴ)を使う。
        // AppIcon.appiconset自体はUIImage(named:)経由での取得が保証されないため、
        // 通常のimageset経由でロゴ画像を用意している。
        if let icon = UIImage(named: "Later") {
            metadata.iconProvider = NSItemProvider(object: icon)
        }
        return metadata
    }
}


// MARK: - グループの招待(v13)

/// グループの招待を共有するときの中身。ただの文字(String)を渡すと、共有シートの左上が「A」(文字)になるため、
/// LPLinkMetadata で Later のアイコン(Assets の LaterShareIcon・1024px・角丸なし)とリンクを渡す。
final class GroupInviteItemSource: NSObject, UIActivityItemSource {
    let groupName: String
    let passphrase: String?
    let url: URL

    init(groupName: String, passphrase: String?, url: URL) {
        self.groupName = groupName
        self.passphrase = passphrase
        self.url = url
    }

    /// 共有シートの見出し:「{グループ名}」に招待されました。
    static func title(groupName: String) -> String {
        "「\(groupName)」に招待されました。"
    }

    /// 共有する本文:
    /// 「{グループ名}」に招待されました。
    /// 合言葉:{合言葉}
    /// {招待リンク}
    static func text(groupName: String, passphrase: String?, url: URL) -> String {
        var lines = [title(groupName: groupName)]
        if let passphrase, !passphrase.isEmpty { lines.append("合言葉:\(passphrase)") }
        lines.append(url.absoluteString)
        return lines.joined(separator: "\n")
    }

    private var text: String { Self.text(groupName: groupName, passphrase: passphrase, url: url) }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        text
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        text
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        Self.title(groupName: groupName)
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = Self.title(groupName: groupName)
        metadata.originalURL = url
        metadata.url = url
        if let icon = UIImage(named: "LaterShareIcon") {
            metadata.iconProvider = NSItemProvider(object: icon)
            metadata.imageProvider = NSItemProvider(object: icon)
        }
        return metadata
    }
}
