import SwiftUI
import UIKit
internal import Combine

// v112 3章:画面の フレーム(setlog の ような ふち)。
// 画面 ぜんぶの まわりに 9pt の 色の ふち。アプリの 上に もう 1枚 UIWindow を 重ねる(押す じゃまを しない)ので、
// シート ・ 全画面 カバー ・ 撮影画面の 上にも 出る。スクショや 共有する 画像には 入らない(かぶせて いる だけ)。

/// フレームの 7色(この 色は フレーム だけに 使う)
enum ScreenFrameColor: String, CaseIterable, Identifiable {
    case lime, pink, sky, lemon, lavender, milk, none

    var id: String { rawValue }

    var color: Color? {
        switch self {
        case .lime: return LattagPalette.lime
        case .pink: return Color(hex: "FFB8D6")
        case .sky: return Color(hex: "A9DCFF")
        case .lemon: return Color(hex: "FFE07A")
        case .lavender: return Color(hex: "D5C8FF")
        case .milk: return Color(hex: "F4F1EA")
        case .none: return nil
        }
    }

    var title: String {
        switch self {
        case .lime: return "ライム"
        case .pink: return "ピンク"
        case .sky: return "そら"
        case .lemon: return "レモン"
        case .lavender: return "ラベンダー"
        case .milk: return "ミルク"
        case .none: return "なし"
        }
    }
}

/// えらんだ 色(端末 + iCloud の キー値)と、出して いいか(オープニングの 間は 出さない)
@MainActor
final class ScreenFrameStore: ObservableObject {
    static let shared = ScreenFrameStore()
    static let key = "ui.frameColor"

    @Published private(set) var current: ScreenFrameColor
    @Published var visible = false

    private init() {
        let kvs = NSUbiquitousKeyValueStore.default
        let raw = kvs.string(forKey: Self.key) ?? UserDefaults.standard.string(forKey: Self.key)
        current = raw.flatMap(ScreenFrameColor.init(rawValue:)) ?? .lime
        NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: kvs, queue: .main) { _ in
            MainActor.assumeIsolated {
                guard let r = NSUbiquitousKeyValueStore.default.string(forKey: Self.key), let c = ScreenFrameColor(rawValue: r), c != ScreenFrameStore.shared.current else { return }
                ScreenFrameStore.shared.apply(c, save: false)
            }
        }
        kvs.synchronize()
    }

    func set(_ c: ScreenFrameColor) { apply(c, save: true) }

    private func apply(_ c: ScreenFrameColor, save: Bool) {
        withAnimation(.easeInOut(duration: 0.45)) { current = c }
        guard save else { return }
        UserDefaults.standard.set(c.rawValue, forKey: Self.key)
        NSUbiquitousKeyValueStore.default.set(c.rawValue, forKey: Self.key)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    /// テープ などに 使う 色(なし の 時は ライム)
    var accent: Color { current.color ?? LattagPalette.lime }
}

/// 端末の 画面の 角丸(わかる 物 だけ)。中の 角 = 画面の 角丸 − 9pt。わからない 端末は 44pt
enum ScreenFrameMetrics {
    static let width: CGFloat = 9

    @MainActor static var innerRadius: CGFloat {
        let h = Int(max(UIScreen.main.nativeBounds.width, UIScreen.main.nativeBounds.height))
        let display: CGFloat? = [
            2532: 47.33,   // iPhone 12 / 13 / 14 / 16e(390pt)
            2340: 44,      // mini
            2778: 53.33,   // Plus / Pro Max(12・13)・ 14 Plus
            2556: 55, 2796: 55, 2622: 62, 2868: 62,
        ][h]
        guard let display else { return 44 }
        return max(0, display - width)
    }
}

/// ふち(外の 四角 − 中の 角丸)+ 内がわに うすい 線(黒 18% ・ 1pt)と うすい 影
struct ScreenFrameView: View {
    @ObservedObject var store = ScreenFrameStore.shared

    var body: some View {
        let r = ScreenFrameMetrics.innerRadius
        let w = ScreenFrameMetrics.width
        ZStack {
            if let c = store.current.color {
                ScreenFrameShape(inset: w, radius: r).fill(c, style: FillStyle(eoFill: true))
                // はめこんだ 感じ:内がわの 影(1回 だけ 描く。動かない)
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .stroke(Color.black.opacity(0.35), lineWidth: 8)
                    .blur(radius: 5)
                    .padding(w)
                    .mask(RoundedRectangle(cornerRadius: r, style: .continuous).padding(w))
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.18), lineWidth: 1)
                    .padding(w)
            }
        }
        .ignoresSafeArea()
        .opacity(store.visible ? 1 : 0)
        .animation(.easeOut(duration: 0.4), value: store.visible)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ScreenFrameShape: Shape {
    let inset: CGFloat
    let radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path(rect.insetBy(dx: -2, dy: -2))
        p.addRoundedRect(in: rect.insetBy(dx: inset, dy: inset), cornerSize: CGSize(width: radius, height: radius), style: .continuous)
        return p
    }
}

/// 押せない 窓(触れても 下の 窓へ とおす)
private final class ScreenFrameWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}

/// 状態バーの 見た目は 下の 窓に まかせる(この 窓は 決めない)
private final class ScreenFrameHost: UIHostingController<ScreenFrameView> {
    override var prefersStatusBarHidden: Bool { Self.mainRoot?.prefersStatusBarHidden ?? false }
    override var preferredStatusBarStyle: UIStatusBarStyle { Self.mainRoot?.preferredStatusBarStyle ?? .default }
    private static var mainRoot: UIViewController? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first { !($0 is ScreenFrameWindow) && $0.windowLevel == .normal }?.rootViewController
    }
}

enum ScreenFrameInstaller {
    @MainActor private static var window: UIWindow?

    /// アプリの 窓の 上に 1回 だけ 重ねる。オープニングが 終わったら 0.4秒で ふわっと 出す
    @MainActor static func install() {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        let w = ScreenFrameWindow(windowScene: scene)
        w.windowLevel = .normal + 1
        w.backgroundColor = .clear
        w.isUserInteractionEnabled = false
        let host = ScreenFrameHost(rootView: ScreenFrameView())
        host.view.backgroundColor = .clear
        w.rootViewController = host
        w.isHidden = false
        window = w
    }
}

/// 設定 › 見た目 › フレームの色(黒い シート ・ 4列の 見本 ・ 押すと すぐ 変わる)
struct ScreenFrameColorSheet: View {
    @ObservedObject var store = ScreenFrameStore.shared
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("フレームの色").font(Typo.ui(900, 22)).foregroundStyle(.white)
                Spacer()
                Button { Haptics.play(.tick); onClose() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 36, height: 36).background(.white.opacity(0.1), in: Circle())
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("とじる")
            }
            Text("画面の ふちの 色。いつでも かえられる").font(Typo.ui(700, 13)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                .padding(.top, 4)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 16) {
                ForEach(ScreenFrameColor.allCases) { c in swatch(c) }
            }
            .padding(.top, 22)
        }
        .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "0B0C0D").ignoresSafeArea())
        .presentationDetents([.height(300)])
        .presentationBackground(Color(hex: "0B0C0D"))
    }

    private func swatch(_ c: ScreenFrameColor) -> some View {
        let on = store.current == c
        return Button { Haptics.play(.click); store.set(c) } label: {
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(c.color ?? Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color(hex: "111113")).padding(c == .none ? 0 : 7)
                    if c == .none { Image(systemName: "slash.circle").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white.opacity(0.5)) }
                }
                .frame(width: 56, height: 56)
                .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous).strokeBorder(.white, lineWidth: on ? 2.5 : 0).padding(-4))
                Text(c.title).font(Typo.ui(700, 11.5)).foregroundStyle(.white.opacity(on ? 1 : 0.6)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity).contentShape(Rectangle())
        }
        .buttonStyle(HVPress(scale: 0.94))
        .accessibilityLabel(c.title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
