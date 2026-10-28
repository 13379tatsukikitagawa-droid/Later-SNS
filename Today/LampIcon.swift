import SwiftUI

// 灯(ともしび)のアイコンとボタン。文字は使わない(VoiceOver のラベルだけ)。
// アイコンは 24×24 の座標で、外側のしずく + 中の小さなしずく。

// MARK: - 形

/// 外側のしずく(上がとがった炎のかたち)。`M12 2.6 C15.4 6.3 18.2 9.4 18.2 13.4 A6.2 6.2 0 0 1 5.8 13.4 C5.8 9.4 8.6 6.3 12 2.6 Z`
struct LampOuterShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let ox = rect.minX + (rect.width - 24 * s) / 2
        let oy = rect.minY + (rect.height - 24 * s) / 2
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
        var path = Path()
        path.move(to: p(12, 2.6))
        path.addCurve(to: p(18.2, 13.4), control1: p(15.4, 6.3), control2: p(18.2, 9.4))
        // A6.2 6.2 0 0 1 5.8 13.4(右から下を回る半円)
        let k: CGFloat = 0.5523 * 6.2
        path.addCurve(to: p(12, 19.6), control1: p(18.2, 13.4 + k), control2: p(12 + k, 19.6))
        path.addCurve(to: p(5.8, 13.4), control1: p(12 - k, 19.6), control2: p(5.8, 13.4 + k))
        path.addCurve(to: p(12, 2.6), control1: p(5.8, 9.4), control2: p(8.6, 6.3))
        path.closeSubpath()
        return path
    }
}

/// 中の小さなしずく。`M12 11.2 C13.7 13 14.8 14.3 14.8 15.9 A2.8 2.8 0 0 1 9.2 15.9 C9.2 14.3 10.3 13 12 11.2 Z`
struct LampInnerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let ox = rect.minX + (rect.width - 24 * s) / 2
        let oy = rect.minY + (rect.height - 24 * s) / 2
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
        var path = Path()
        path.move(to: p(12, 11.2))
        path.addCurve(to: p(14.8, 15.9), control1: p(13.7, 13), control2: p(14.8, 14.3))
        let k: CGFloat = 0.5523 * 2.8
        path.addCurve(to: p(12, 18.7), control1: p(14.8, 15.9 + k), control2: p(12 + k, 18.7))
        path.addCurve(to: p(9.2, 15.9), control1: p(12 - k, 18.7), control2: p(9.2, 15.9 + k))
        path.addCurve(to: p(12, 11.2), control1: p(9.2, 14.3), control2: p(10.3, 13))
        path.closeSubpath()
        return path
    }
}

enum LampPalette {
    /// ともっている中のしずく
    static let inner = Color(hex: "FF9A3D")
    static let glowCenter = Color(hex: "FFC682")
    static let glowMid = Color(hex: "FF7C2A")
    static let glowEdge = Color(hex: "782808")
    /// 発表のカードなどの、橙の細い光
    static let rim = Color(hex: "FFC48C")
}

// MARK: - アイコン

/// 灯のアイコン。消えている:外側は白(80%)の線、内側は薄い線。ともっている:外側は白く塗り、内側は橙で塗る。
struct LampIcon: View {
    var size: CGFloat = 24
    var isLit: Bool

    var body: some View {
        ZStack {
            if isLit {
                LampOuterShape().fill(.white)
                LampInnerShape().fill(LampPalette.inner)
            } else {
                LampOuterShape().stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: size / 24 * 1.6, lineJoin: .round))
                LampInnerShape().stroke(.white.opacity(0.32), style: StrokeStyle(lineWidth: size / 24 * 1.4, lineJoin: .round))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 点灯した丸(発表のカード・タイル・カレンダー用)。丸の中は橙のグラデーション、まわりに光のにじみ。
struct LampBadge: View {
    var diameter: CGFloat
    var breathes = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [LampPalette.glowCenter, LampPalette.glowMid, LampPalette.glowEdge], center: .center, startRadius: 0, endRadius: diameter * 0.62))
            Circle().strokeBorder(.white.opacity(0.28), lineWidth: 1)
            LampIcon(size: diameter * 0.56, isLit: true)
                .scaleEffect(breathe ? 1.07 : 1)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: LampPalette.glowMid.opacity(0.7), radius: diameter * 0.28)
        .onAppear {
            guard breathes, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}

// MARK: - ボタン(68pt)

/// 写真を見る画面の右下の灯ボタン。押すと橙に変わり、光の輪・火の粉・にじみが出る。
/// `burst` が増えるたびに、輪と火の粉を1回出す(ともしたときだけ増やす)。
struct LampButton: View {
    static let diameter: CGFloat = 68

    let isLit: Bool
    let burst: Int
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hint = false
    @State private var breathe = false
    @State private var ringPhase: CGFloat = 1
    @State private var sparkPhase: CGFloat = 1

    var body: some View {
        Button(action: action) {
            ZStack {
                base
                LampIcon(size: 36, isLit: isLit)
                    .scaleEffect(isLit && breathe ? 1.07 : 1)
            }
            .frame(width: Self.diameter, height: Self.diameter)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .overlay { effects }
        .consumesTap()
        .onAppear(perform: startLoops)
        .onChange(of: isLit) { _, _ in startLoops() }
        .onChange(of: burst) { _, _ in playBurst() }
        .accessibilityLabel("灯をともす")
        .accessibilityValue(isLit ? "ともっています" : "")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var base: some View {
        if isLit {
            Circle()
                .fill(RadialGradient(colors: [LampPalette.glowCenter, LampPalette.glowMid, LampPalette.glowEdge], center: .center, startRadius: 0, endRadius: Self.diameter * 0.62))
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                .shadow(color: LampPalette.glowMid.opacity(0.75), radius: 18)
                .shadow(color: LampPalette.glowMid.opacity(0.4), radius: 34)
                .transition(.opacity)
        } else {
            ZStack {
                Circle().fill(.ultraThinMaterial)
                Circle().fill(Color(hex: "0A0705").opacity(0.34))
                Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1)
                // はじめての人への合図:ごく弱いリングが、ゆっくり広がる(文字は出さない)
                Circle()
                    .strokeBorder(.white.opacity(0.5), lineWidth: 1)
                    .scaleEffect(hint ? 1.5 : 1)
                    .opacity(hint ? 0 : 0.5)
            }
        }
    }

    /// 光の輪(1 → 2.8倍、0.95秒)と、火の粉6個(放射状、0.85秒)
    private var effects: some View {
        ZStack {
            Circle()
                .strokeBorder(LampPalette.rim, lineWidth: 2)
                .frame(width: Self.diameter, height: Self.diameter)
                .scaleEffect(1 + 1.8 * ringPhase)
                .opacity(1 - ringPhase)
            ForEach(0..<6, id: \.self) { index in
                let angle = Double(index) / 6 * 2 * .pi + .pi / 6
                Circle()
                    .fill(LampPalette.glowCenter)
                    .frame(width: 5, height: 5)
                    .shadow(color: LampPalette.glowMid, radius: 3)
                    .offset(x: CGFloat(cos(angle)) * (24 + 40 * sparkPhase), y: CGFloat(sin(angle)) * (24 + 40 * sparkPhase))
                    .scaleEffect(1 - 0.6 * sparkPhase)
                    .opacity(1 - sparkPhase)
            }
        }
        .allowsHitTesting(false)
    }

    private func startLoops() {
        guard !reduceMotion else { return }
        if isLit {
            hint = false
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { breathe = true }
        } else {
            breathe = false
            hint = false
            withAnimation(.easeOut(duration: 2.8).repeatForever(autoreverses: false)) { hint = true }
        }
    }

    private func playBurst() {
        guard !reduceMotion else { return }
        ringPhase = 0
        sparkPhase = 0
        withAnimation(.easeOut(duration: 0.95)) { ringPhase = 1 }
        withAnimation(.easeOut(duration: 0.85)) { sparkPhase = 1 }
    }
}

// MARK: - 右上の小さな丸(34pt)

/// このビューアの「今日の灯」の状態。その場所で灯をともしているなら、どの写真を見ていても点灯して見える。
struct LampStatusDot: View {
    static let diameter: CGFloat = 34

    let isLit: Bool

    var body: some View {
        ZStack {
            if isLit {
                Circle()
                    .fill(RadialGradient(colors: [LampPalette.glowCenter, LampPalette.glowMid, LampPalette.glowEdge], center: .center, startRadius: 0, endRadius: Self.diameter * 0.62))
                    .shadow(color: LampPalette.glowMid.opacity(0.7), radius: 10)
            } else {
                Circle().fill(.ultraThinMaterial)
                Circle().fill(Color(hex: "0A0705").opacity(0.34))
            }
            Circle().strokeBorder(.white.opacity(isLit ? 0.3 : 0.14), lineWidth: 1)
            LampIcon(size: 18, isLit: isLit)
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .animation(.easeOut(duration: 0.3), value: isLit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isLit ? "ここでは、灯をともしています" : "ここでは、まだ灯をともしていません")
    }
}

// MARK: - 写真の右下からにじむ光

/// 灯をともしたとき、写真の右下から橙の光がにじむ(0.7秒)。点灯中は写真のふちが少し温かい色になる。
struct LampBloom: View {
    let burst: Int
    let isLit: Bool
    var cornerRadius: CGFloat = 46

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bloom: CGFloat = 1

    var body: some View {
        ZStack {
            // 最後の色は透明(四角く切れない)
            RadialGradient(colors: [LampPalette.glowMid.opacity(0.85), LampPalette.glowMid.opacity(0.25), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 360)
                .blendMode(.screen)
                .scaleEffect(0.6 + 0.6 * bloom, anchor: .bottomTrailing)
                .opacity(Double(1 - bloom * bloom))
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(LampPalette.rim.opacity(0.42), lineWidth: 2)
                .shadow(color: LampPalette.glowMid.opacity(0.4), radius: 10)
                .opacity(isLit ? 1 : 0)
                .animation(.easeOut(duration: 0.35), value: isLit)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .padding(6)
        .allowsHitTesting(false)
        .onChange(of: burst) { _, _ in
            guard !reduceMotion else { return }
            bloom = 0
            withAnimation(.easeOut(duration: 0.7)) { bloom = 1 }
        }
    }
}
