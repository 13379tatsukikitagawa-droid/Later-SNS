import SwiftUI
import WidgetKit

// v104:ウィジェット(えらぶ)シート + 案内(ホームで 置く)+ 自動で たしかめる。

/// 置けたか:`WidgetCenter` の いまの 設定の うち Lattag の ものの 数。ふえたら 置けた(テストでは provider を 差しかえる)。
enum WidgetPlacement {
    static let kinds = Set(LattagShared.Kind.all)
    static var provider: () async -> [String] = {
        await withCheckedContinuation { cont in
            WidgetCenter.shared.getCurrentConfigurations { result in
                if case .success(let infos) = result { cont.resume(returning: infos.map(\.kind)) } else { cont.resume(returning: []) }
            }
        }
    }
    static func count() async -> Int { await provider().filter { kinds.contains($0) }.count }
    static func increased(since base: Int) async -> Bool { await count() > base }
}

enum WidgetChoice: String, CaseIterable, Identifiable {
    case lens, until9, friend
    var id: String { rawValue }
    var title: String { switch self { case .lens: "レンズ"; case .until9: "9:00 まで"; case .friend: "友だちの 1枚" } }
    var desc: String { switch self { case .lens: "押すと すぐ 撮れる"; case .until9: "現像が ひらくまで"; case .friend: "きのうの 友だちを 1枚ずつ" } }
    @ViewBuilder func widget(_ m: WidgetModel) -> some View {
        switch self {
        case .lens: LattagLensView(model: m)
        case .until9: LattagUntil9View(model: m)
        case .friend: LattagFriendView(entry: LattagEntry(date: Date(), model: m, hourIndex: 0))
        }
    }
    var bg: Color { self == .until9 ? WColor.lime : WColor.ground }
}

/// シート「ウィジェット、置きますか?」(高さ = 中身)
struct WidgetGuideV96Sheet: View {
    /// はじめての 時は「あとで」、設定から 来た 時は「とじる」
    var firstTime = false
    var onClose: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var choice: WidgetChoice = .lens
    @State private var showsGuide = false
    @State private var awaiting = false
    @State private var baseline = 0
    @State private var toast: String?

    var body: some View {
        let m = WidgetGuideV96.sample()
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("ウィジェット、置きますか?").font(LF.inter(900, 22)).foregroundStyle(.white)
                Spacer(minLength: 8)
                Button { Haptics.play(.tick); onClose() } label: { Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44).background(.white.opacity(0.1), in: Circle()) }.buttonStyle(.plain).accessibilityLabel("とじる")
            }.padding(.top, 14)
            Text("ホーム画面に 置くと、撮りたくなる ・ 待ちたくなる。\n1つ えらんで ください。").font(LF.inter(600, 13)).foregroundStyle(.white.opacity(0.6)).fixedSize(horizontal: false, vertical: true).padding(.top, 2)
            VStack(spacing: 8) {
                ForEach(WidgetChoice.allCases) { c in row(c, m) }
            }.padding(.top, 16)
            Button { start() } label: {
                Text("ホームで 置く").font(LF.inter(800, 17)).foregroundStyle(HV.ink).frame(maxWidth: .infinity).frame(height: 56).background(HV.lime, in: Capsule())
            }.buttonStyle(HVPress(scale: 0.97)).padding(.top, 16)
            Button { Haptics.play(.soft); onClose() } label: {
                Text(firstTime ? "あとで ・ 設定から できます" : "とじる").font(LF.inter(600, 14)).foregroundStyle(.white.opacity(0.55)).frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(.plain).padding(.top, 2).padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .sheetFitsContent()
        .background(Color(hex: "141516").ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .overlay(alignment: .top) { if let toast { Text(toast).font(LF.inter(800, 14)).foregroundStyle(HV.ink).padding(.horizontal, 16).frame(height: 40).background(HV.lime, in: Capsule()).padding(.top, 14).transition(.move(edge: .top).combined(with: .opacity)) } }
        .fullScreenCover(isPresented: $showsGuide) {
            WidgetHowToV104(choice: choice, sample: m, onBack: { returned() })
        }
        .onChange(of: scenePhase) { _, p in if p == .active, awaiting { Task { await check(manual: false) } } }
    }

    private func row(_ c: WidgetChoice, _ m: WidgetModel) -> some View {
        let on = c == choice
        return Button { if !on { Haptics.play(.sel) }; choice = c } label: {
            HStack(spacing: 12) {
                c.widget(m).frame(width: 158, height: 158).scaleEffect(52.0 / 158.0).frame(width: 52, height: 52).background(c.bg).clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous)).allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.title).font(LF.inter(800, 16)).foregroundStyle(.white)
                    Text(c.desc).font(LF.inter(500, 12)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 22)).foregroundStyle(on ? HV.lime : .white.opacity(0.3))
            }
            .padding(.horizontal, 12).frame(height: 68)
            .background(on ? HV.lime.opacity(0.1) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(on ? HV.lime : .clear, lineWidth: 2))
        }.buttonStyle(.plain).accessibilityLabel("\(c.title)、\(c.desc)").accessibilityAddTraits(on ? [.isSelected] : [])
    }

    private func start() {
        Haptics.play(.click)
        Task { @MainActor in
            baseline = await WidgetPlacement.count()
            awaiting = true
            showsGuide = true
        }
    }

    /// 「Lattag に もどる」
    private func returned() {
        showsGuide = false
        Task { await check(manual: true) }
    }

    private func check(manual: Bool) async {
        guard awaiting else { return }
        if await WidgetPlacement.increased(since: baseline) {
            awaiting = false
            showsGuide = false
            Haptics.play(.success)
            say("ウィジェットを 置けました")
            try? await Task.sleep(for: .seconds(1.4))
            WidgetGuideV96.markSeen(); onClose()
        } else if manual {
            awaiting = false
            say("あとで 設定 › ウィジェット から できます")
        }
    }

    @MainActor private func say(_ t: String) {
        withAnimation(.smooth) { toast = t }
        Task { try? await Task.sleep(for: .seconds(2.4)); withAnimation(.smooth) { toast = nil } }
    }
}
