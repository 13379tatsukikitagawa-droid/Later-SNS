import SwiftUI

// v136:ともだち 0人の Home。#レンズが 主役。
// 上から:見出し → 1行 → レンズ → ヒント → 「QRを見せる」「IDでさがす」 → 小さな 注記。
// レンズの 長押し(招待リンク)は 次の 段で つなぐ。いまは タップで 「長押ししてね」。
struct EmptyFriendsV134: View {
    var screenHeight: CGFloat
    var actions: YesterdayV64Actions
    @State private var hint = Self.restHint
    @State private var hintTask: Task<Void, Never>?
    @State private var breathe = false
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
        Button {
            LTHaptics.play(.tap)
            hintTask?.cancel()
            withAnimation(.easeOut(duration: 0.2)) { hint = Self.tapHint }
            hintTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                if !Task.isCancelled { withAnimation(.easeOut(duration: 0.2)) { hint = Self.restHint } }
            }
        } label: {
            HashLensView(size: diameter, locked: false, glowing: true)
                .scaleEffect(reduceMotion ? 1 : (breathe ? 1.03 : 0.985))
                .frame(width: diameter + 24, height: diameter + 24)
                .contentShape(Circle())
        }
        .buttonStyle(HVPress(scale: 0.96))
        .accessibilityLabel("招待リンクをつくる")
        .accessibilityHint("長押しでつくります")
        .accessibilityAction(named: "招待リンクを送る") { actions.shareLink() }
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
