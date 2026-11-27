import SwiftUI

// v136:ともだち 0人の Home。#レンズが 主役。
// 上から:見出し → 1行 → レンズ → ヒント → 「QRを見せる」「IDでさがす」 → 小さな 注記。
// レンズを 長押し(1.4秒)→ 招待カード。タップだけ なら「長押ししてね」。
struct EmptyFriendsV134: View {
    var screenHeight: CGFloat
    var actions: YesterdayV64Actions
    @State private var hint = Self.restHint
    @State private var hintTask: Task<Void, Never>?
    @State private var breathe = false
    @State private var progress = 0.0
    @State private var cooling = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let restHint = "長押しで招待リンクをつくる"
    static let tapHint = "長押ししてね"

    private var diameter: CGFloat { HomeV134Rules.lensDiameter(screenHeight: screenHeight) }

    var body: some View {
        VStack(spacing: 0) {
            Text("ともだちを追加").font(LTFont.ui(24, weight: .heavy)).foregroundStyle(.white)
            Text("ともだちのきのうの写真が、毎朝9:00から見られます")
                .font(LTFont.ui(13)).foregroundStyle(LTColor.ink2).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 6).padding(.horizontal, 24)
            lens.padding(.top, diameter > 140 ? 26 : 14)
            Text(hint).font(LTFont.ui(13, weight: .semibold)).foregroundStyle(LTColor.ink2)
                .frame(height: 20).padding(.top, 14).contentTransition(.opacity)
                .id(hint)
            HStack(spacing: 12) {
                pill("qrcode", "QRを見せる") { actions.showQR() }
                pill("magnifyingglass", "IDでさがす") { actions.searchByID() }
            }.padding(.top, 14).padding(.horizontal, 18)
            Text("ともだちの数は、ほかの人には表示されません")
                .font(LTFont.ui(11)).foregroundStyle(LTColor.ink3).padding(.top, 16)
        }
        .frame(maxWidth: .infinity)
        .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { breathe = true } } }
    }

    private var lens: some View {
        let ring = diameter + 16
        return ZStack {
            Circle().stroke(Color.white.opacity(0.10), lineWidth: 3).frame(width: ring, height: ring).opacity(progress > 0 ? 1 : 0)
            Circle().trim(from: 0, to: progress).stroke(LTColor.lime, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90)).frame(width: ring, height: ring)
            HashLensView(size: diameter, locked: false, glowing: true)
                .scaleEffect((reduceMotion ? 1 : (breathe ? 1.03 : 0.985)) * (1 - 0.07 * progress))
        }
        .frame(width: diameter + 28, height: diameter + 28)
        .contentShape(Circle())
        .onTapGesture { tapHint() }
        .holdToConfirm(duration: LensChargeSpec.duration, progress: $progress, isEnabled: !cooling, haptics: .lens, maximumDistance: 40) {
            LTHaptics.play(.lensDone)
            cooling = true                    // シートが 出ている 間に もう一度 長押ししても 2枚目は 出ない
            actions.openInviteCard()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { cooling = false; withAnimation(.easeOut(duration: 0.25)) { progress = 0 } }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("招待リンクをつくる")
        .accessibilityHint("長押しでつくります")
        .accessibilityAction(named: "招待リンクを送る") { actions.openInviteCard() }
    }

    private func tapHint() {
        LTHaptics.play(.tap)
        hintTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { hint = Self.tapHint }
        hintTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if !Task.isCancelled { withAnimation(.easeOut(duration: 0.2)) { hint = Self.restHint } }
        }
    }

    private func pill(_ icon: String, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button { LTHaptics.play(.tap); action() } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(title).font(LTFont.ui(14, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.85)
            }
            .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 48)
            .background(LTColor.surface1, in: Capsule())
            .overlay(Capsule().strokeBorder(LTColor.hairline2, lineWidth: 1))
        }.buttonStyle(HVPress(scale: 0.96))
    }
}
