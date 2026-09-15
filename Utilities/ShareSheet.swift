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

