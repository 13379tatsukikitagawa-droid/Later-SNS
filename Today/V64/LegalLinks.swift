import SafariServices
import SwiftUI

/// v102:利用規約 と プライバシーポリシー。文章は アプリに 持たず、サイトの ページを ひらく だけ。
/// URL は ここだけに 書く(変わる 時は ここだけ 直す)。
enum LegalLink: String, CaseIterable, Identifiable {
    case terms, privacy
    var id: String { rawValue }

    static let siteBase = "https://13379tatsukikitagawa-droid.github.io/APP-Later2/"
    var url: URL {
        URL(string: Self.siteBase + (self == .terms ? "terms.html" : "privacy.html"))!
    }
    var title: String { self == .terms ? "利用規約" : "プライバシー" }
}

/// アプリ内ブラウザ(SFSafariViewController)。色は ライム + 暗い バー。
struct LegalSafariView: UIViewControllerRepresentable {
    let link: LegalLink
    var onFinish: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish) }
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let c = SFSafariViewController.Configuration()
        c.entersReaderIfAvailable = false
        c.barCollapsingEnabled = true
        let vc = SFSafariViewController(url: link.url, configuration: c)
        vc.preferredControlTintColor = UIColor(red: 0xC8 / 255, green: 0xF2 / 255, blue: 0x5A / 255, alpha: 1)
        vc.preferredBarTintColor = UIColor(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255, alpha: 1)
        vc.delegate = context.coordinator
        Haptics.play(.soft)
        return vc
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onFinish: () -> Void
        init(_ f: @escaping () -> Void) { onFinish = f }
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            Haptics.play(.tick)
            onFinish()
        }
    }
}

extension View {
    /// 規約 / プライバシーを 下から シートで ひらく。
    func legalSheet(_ item: Binding<LegalLink?>) -> some View {
        fullScreenCover(item: item) { link in
            LegalSafariView(link: link) { item.wrappedValue = nil }.ignoresSafeArea()
        }
    }
}
