import SwiftUI
import UIKit
import LinkPresentation

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
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

