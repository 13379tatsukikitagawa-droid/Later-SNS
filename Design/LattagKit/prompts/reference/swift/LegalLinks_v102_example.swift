// 参考(形の 見本)・ そのまま コピー しない。PROMPT_v102.md が 正解。型名 ・ 置き場所は 今の プロジェクトに 合わせる。
import SwiftUI
import SafariServices

/// 規約ページの リンク先。ここ 1か所だけに URL を 書く。
enum LegalLink: String, CaseIterable, Identifiable {
    case terms, privacy
    var id: String { rawValue }

    private static let site = "https://13379tatsukikitagawa-droid.github.io/APP-Later2/"
    var url: URL {
        switch self {
        case .terms:   return URL(string: Self.site + "terms.html")!
        case .privacy: return URL(string: Self.site + "privacy.html")!
        }
    }
    var title: String {
        switch self {
        case .terms:   return "利用規約"
        case .privacy: return "プライバシー"
        }
    }
}

/// アプリ内ブラウザ(SFSafariViewController)。「完了」で とじる。
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    var onFinish: () -> Void = {}

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let c = SFSafariViewController.Configuration()
        c.entersReaderIfAvailable = false
        c.barCollapsingEnabled = true
        let vc = SFSafariViewController(url: url, configuration: c)
        vc.preferredControlTintColor = UIColor(red: 200/255, green: 242/255, blue: 90/255, alpha: 1)   // ライム #C8F25A
        vc.preferredBarTintColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1)          // #1C1C1E
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onFinish) }

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onFinish: () -> Void
        init(_ f: @escaping () -> Void) { onFinish = f }
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            Haptics.play(.tick)        // とじた 時
            onFinish()
        }
    }
}

extension View {
    /// 使い方:`.legalSheet($legal)`(`@State var legal: LegalLink?`)
    func legalSheet(_ item: Binding<LegalLink?>) -> some View {
        fullScreenCover(item: item) { link in
            SafariView(url: link.url) { item.wrappedValue = nil }
                .ignoresSafeArea()
        }
    }
}

// サインイン画面の 下の 字(O04)の 形。重ねず、44pt の 当たり判定。
struct TermsNotice: View {
    @Binding var legal: LegalLink?
    var body: some View {
        ViewThatFits(in: .horizontal) {
            row
            VStack(spacing: 0) { Text("つづけると").font(.caption2); row2 }   // せまい 幅の とき
        }
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
    }
    private var row: some View {
        HStack(spacing: 0) {
            Text("つづけると ")
            link(.terms)
            Text("・")
            link(.privacy)
            Text(" に 同意(13歳以上)")
        }
    }
    private var row2: some View {
        HStack(spacing: 0) { link(.terms); Text("・"); link(.privacy); Text(" に 同意(13歳以上)") }
    }
    private func link(_ l: LegalLink) -> some View {
        Button {
            Haptics.play(.tick)
            legal = l
        } label: {
            Text(l.title).underline()
                .frame(minHeight: 44)                 // 押せる 大きさ 44pt
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(l.title)、リンク")
        .accessibilityAddTraits(.isLink)
    }
}
