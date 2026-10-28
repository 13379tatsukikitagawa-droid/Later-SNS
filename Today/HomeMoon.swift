import SwiftUI

/// 画面の下の「月」。Homeの唯一の大きな操作(撮る・昨日をひらく・待つ)。
/// 幅330/390の円の、上の84ptだけが画面に見える。押すと、月がふくらんで次の画面になる。
enum MoonLayout {
    /// 見えている円弧の高さ(画面の下端から)
    static let visibleHeight: CGFloat = 84
    /// ホームインジケーターとの重なりが気になる時に、月を上げる量(12〜20ptで調整)
    static let lift: CGFloat = 0

    static func diameter(screenWidth: CGFloat) -> CGFloat { screenWidth * 330 / 390 }

    /// 月の中心(画面の座標、セーフエリアを含む全画面)
    static func center(in size: CGSize) -> CGPoint {
        let radius = diameter(screenWidth: size.width) / 2
        return CGPoint(x: size.width / 2, y: size.height - visibleHeight - lift + radius)
    }

    /// 画面の四隅まで届く倍率(画面の対角線 ÷ 月の半径)
    static func fullScale(in size: CGSize) -> CGFloat {
        let c = center(in: size)
        let radius = diameter(screenWidth: size.width) / 2
        let farthest = max(hypot(c.x, c.y), hypot(size.width - c.x, c.y))
        // 縁の光・線が画面の角に残らないよう、少しだけ余裕を持たせる。
        return farthest / radius * 1.04
    }

    /// dawn・first:白 → 桃 → 薄い紫 → 青(見えるのは上の約25%。ふくらむと藍まで)
    static let gradient = LinearGradient(stops: [
        .init(color: Color(hex: "FFFFFF"), location: 0),
        .init(color: Color(hex: "FFE6D3"), location: 0.07),
        .init(color: Color(hex: "FFC0A2"), location: 0.13),
        .init(color: Color(hex: "E3B9FF"), location: 0.20),
        .init(color: Color(hex: "93A7FF"), location: 0.27),
        .init(color: Color(hex: "4B60D4"), location: 0.42),
        .init(color: Color(hex: "2A2F78"), location: 1),
    ], startPoint: .top, endPoint: .bottom)

    /// ready:白 → 黄 → オレンジ → 紫(あたたかい)
    static let readyGradient = LinearGradient(stops: [
        .init(color: Color(hex: "FFFFFF"), location: 0),
        .init(color: Color(hex: "FFF3C4"), location: 0.07),
        .init(color: Color(hex: "FFC56B"), location: 0.14),
        .init(color: Color(hex: "FF9A4D"), location: 0.22),
        .init(color: Color(hex: "C97BE0"), location: 0.32),
        .init(color: Color(hex: "6B4BA8"), location: 0.5),
        .init(color: Color(hex: "241A3D"), location: 1),
    ], startPoint: .top, endPoint: .bottom)

    /// opened:白 → 青白 → 青
    static let openedGradient = LinearGradient(stops: [
        .init(color: Color(hex: "FFFFFF"), location: 0),
        .init(color: Color(hex: "E3EEFF"), location: 0.09),
        .init(color: Color(hex: "AEC9FF"), location: 0.18),
        .init(color: Color(hex: "6E8FE0"), location: 0.3),
        .init(color: Color(hex: "3D59B0"), location: 0.48),
        .init(color: Color(hex: "1C2654"), location: 1),
    ], startPoint: .top, endPoint: .bottom)

    static let ink = Color(hex: "1A1A22")
}

struct HomeMoon: View {
    enum Mode: Equatable {
        /// night・rest:暗い月。押すとやわらかい触覚2回+お知らせ(タップでは何も進まない)
        case dim(title: String, subtitle: String)
        /// dawn・first・opened:グラデーションの月。タップ
        case tap(title: String, subtitle: String, tone: Tone)
        /// ready:やや暗いグラデーション+長押しのゲージ
        case hold

        /// dawn/first(warm)とopened(cool)で、月の色を変える。
        /// deciding(decide)は warm と同じ月で、光だけ少しあたたかく・脈動3.2秒。
        enum Tone: Equatable { case warm, decide, cool }
    }

    let mode: Mode
    let screenSize: CGSize
    let holdModel: HoldGaugeModel
    let haptics: ExposureHaptics
    /// 月の中の文字の不透明度(ふくらむ時に消す)
    let textOpacity: Double
    let isInteractive: Bool
    let onTap: () -> Void
    let onHoldComplete: () -> Void
    /// night・rest(ロック中)に月を押して離した時。やわらかい触覚2回+お知らせは呼び出し側が出す。
    var onDimTap: () -> Void = {}
    /// 起動アニメーション中の、にじみの不透明度(nilなら通常の呼吸)と拡大
    var launchGlowOpacity: Double?
    var launchGlowScale: Double = 1
    /// 白 × シックのホーム(白い背景の上:夜の月は灰青、にじみは上向きのラベンダー+ピーチ、文字はインク)
    var chic = false

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isBreathing = false
    @State private var isPressed = false

    private var diameter: CGFloat { MoonLayout.diameter(screenWidth: screenSize.width) }

    var body: some View {
        TimelineView(.animation(paused: !holdModel.isMoving)) { context in
            let p = mode == .hold ? holdModel.progress(at: context.date) : 0
            moon(progress: p)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(gesture)
        .onAppear {
            guard !reduceMotion else { return }
            isBreathing = true
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
        .modifier(DisabledWhenDim(isDim: isDim))
        .accessibilityAction { if case .tap = mode { onTap() } }
        .accessibilityAction(named: "ひらく") {
            if mode == .hold { holdModel.finish(haptics: haptics, onComplete: onHoldComplete) }
        }
    }

    private var isDim: Bool {
        if case .dim = mode { return true }
        return false
    }

    // MARK: - 見た目

    /// 見えている円弧の、左右の端の角度(上=270°)。trimの割合で返す。
    private var visibleArc: (from: CGFloat, to: CGFloat) {
        let r = diameter / 2
        let theta = acos(max(-1, min(1, (r - MoonLayout.visibleHeight) / r))) * 180 / .pi
        return (CGFloat((270 - theta) / 360), CGFloat((270 + theta) / 360))
    }

    private func moon(progress p: Double) -> some View {
        let shape = Circle()
        return ZStack(alignment: .top) {
            // にじみ(横長のやわらかい光)。box-shadowではなく別のViewで、呼吸のように不透明度が変わる。
            glowLayer
                .scaleEffect(launchGlowScale)
                .offset(y: -40)
                .opacity(launchGlowOpacity ?? (reduceMotion ? 0.7 : (isBreathing ? 1 : 0.45)))
                .animation(reduceMotion ? nil : .easeInOut(duration: breathPeriod / 2).repeatForever(autoreverses: true), value: isBreathing)
                .allowsHitTesting(false)

            // 長押し:月の中心から、オレンジの光がひろがる
            if mode == .hold, p > 0 {
                Circle()
                    .fill(RadialGradient(colors: [HomePalette.orange.opacity(0.85), HomePalette.orange.opacity(0.25), .clear], center: .center, startRadius: 0, endRadius: diameter * 1.4 * CGFloat(p)))
                    .frame(width: diameter * 2.8 * CGFloat(p), height: diameter * 2.8 * CGFloat(p))
                    .offset(y: diameter / 2 - diameter * 1.4 * CGFloat(p))
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }

            ZStack(alignment: .top) {
                switch mode {
                case .dim where chic:
                    shape.fill(ChicMoon.nightGradient)
                    shape.strokeBorder(.black.opacity(0.06), lineWidth: 1)
                case .dim:
                    shape.fill(LinearGradient(stops: [
                        .init(color: Color(hex: "6E7896"), location: 0),
                        .init(color: Color(hex: "3A4462"), location: 0.12),
                        .init(color: Color(hex: "1A2038"), location: 0.3),
                        .init(color: Color(hex: "080A14"), location: 1),
                    ], startPoint: .top, endPoint: .bottom))
                    shape.strokeBorder(.white.opacity(0.14), lineWidth: 1)
                case .tap(_, _, let tone):
                    shape.fill(tone == .cool ? MoonLayout.openedGradient : MoonLayout.gradient)
                        .brightness(isPressed ? 0.06 : 0)
                    shape.strokeBorder(chic ? (palette.isNight ? palette.line : Color.black.opacity(0.06)) : .white.opacity(0.75), lineWidth: chic ? 1 : 1.5)
                    if chic && palette.isNight {
                        // 夜:朝焼けの下の方は、暗い地にとける
                        shape.fill(LinearGradient(stops: [
                            .init(color: palette.bg.opacity(0), location: 0.16),
                            .init(color: palette.bg.opacity(0.55), location: 0.3),
                            .init(color: palette.bg, location: 0.5),
                        ], startPoint: .top, endPoint: .bottom))
                            .allowsHitTesting(false)
                    }
                case .hold:
                    shape.fill(MoonLayout.readyGradient)
                    shape.strokeBorder(.white.opacity(0.6), lineWidth: 1.5)
                }
                label(color: textColor)
            }
            .frame(width: diameter, height: diameter)
            .clipShape(shape)

            // 長押し:月の縁を、白い線が左から右へたどる
            if mode == .hold, p > 0 {
                let arc = visibleArc
                shape
                    .trim(from: arc.from, to: arc.from + (arc.to - arc.from) * CGFloat(p))
                    .stroke(.white, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .shadow(color: .white.opacity(0.8), radius: 6)
                    .frame(width: diameter, height: diameter)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: diameter, height: diameter, alignment: .top)
        .scaleEffect(mode == .hold ? 1 + 0.035 * p : (isPressed ? 0.96 : 1))
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
    }

    /// にじみ(横長のやわらかい光)。box-shadowではなく別のViewで、呼吸のように不透明度が変わる。
    @ViewBuilder
    private var glowLayer: some View {
        if chic {
            ZStack {
                Ellipse()
                    .fill(ChicMoon.glowLavender)
                    .frame(width: diameter * 1.1, height: 150)
                    .blur(radius: 44)
                Ellipse()
                    .fill(ChicMoon.glowPeach)
                    .frame(width: diameter * 0.9, height: 100)
                    .blur(radius: 32)
                    .offset(y: 14)
            }
        } else {
            Ellipse()
                .fill(glowColor)
                .frame(width: diameter * 1.15, height: 130)
                .blur(radius: 42)
        }
    }

    private var breathPeriod: Double {
        switch mode {
        case .dim: return 7
        case .tap(_, _, let tone): return tone == .warm ? 3.6 : tone == .decide ? 3.2 : 4.4
        case .hold: return 2.4
        }
    }

    private var glowColor: Color {
        switch mode {
        case .dim: return Color(hex: "5A6A9A").opacity(0.22)
        case .tap(_, _, let tone):
            switch tone {
            case .warm: return Color(red: 1, green: 200 / 255, blue: 170 / 255).opacity(0.45)
            case .decide: return Color(red: 1, green: 190 / 255, blue: 150 / 255).opacity(0.5)
            case .cool: return Color(hex: "BFD6FF").opacity(0.42)
            }
        case .hold: return Color(hex: "FFB070").opacity(0.5)
        }
    }

    private var textColor: Color {
        switch mode {
        case .dim: return chic ? MoonLayout.ink : Color(hex: "B4BCD2")
        case .tap: return MoonLayout.ink
        case .hold: return MoonLayout.ink
        }
    }

    private var titleText: String {
        switch mode {
        case .dim(let title, _): return title
        case .tap(let title, _, _): return title
        case .hold: return holdModel.isDone ? "ひらきます" : "昨日をひらく"
        }
    }

    private func subtitleText(progress p: Double) -> String? {
        switch mode {
        case .dim(_, let subtitle): return subtitle
        case .tap(_, let subtitle, _): return subtitle
        case .hold: return holdModel.isDone ? nil : "長押し"
        }
    }

    /// 月の文字(弧の幅が決まっているため固定の大きさ。長い文言は16pt)
    private func label(color: Color) -> some View {
        TimelineView(.animation(paused: !holdModel.isMoving)) { context in
            let p = mode == .hold ? holdModel.progress(at: context.date) : 0
            let title = titleText
            let titleSize: CGFloat = title.count >= 9 ? 16 : 17
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: titleSize, weight: chic ? .heavy : .bold))
                    .tracking(-0.03 * titleSize)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: diameter * 0.58)
                    .frame(height: 22)
                    .padding(.top, 28 - 11)
                if let subtitle = subtitleText(progress: p), !dynamicTypeSize.isAccessibilitySize {
                    Text(subtitle)
                        .font(.system(size: 9.5, design: .monospaced))
                        .tracking(0.14 * 9.5)
                        .monospacedDigit()
                        .lineLimit(1)
                        .opacity(0.5)
                        .padding(.top, 54 - 28 - 11 - 6)
                }
            }
            .foregroundStyle(color)
            .dynamicTypeSize(.large)
        }
        .opacity(textOpacity)
        .allowsHitTesting(false)
    }

    // MARK: - 操作

    private var gesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isInteractive else { return }
                let inside = Circle().path(in: CGRect(x: 0, y: 0, width: diameter, height: diameter)).contains(value.location)
                switch mode {
                case .dim:
                    break
                case .tap:
                    // 押している間、少しへこんで少し明るくなる(触覚なし)。
                    if isPressed != inside { isPressed = inside }
                case .hold:
                    if inside {
                        holdModel.press(haptics: haptics, onComplete: onHoldComplete)
                    } else {
                        holdModel.lift(haptics: haptics)
                    }
                }
            }
            .onEnded { value in
                guard isInteractive else { return }
                switch mode {
                case .dim:
                    let inside = Circle().path(in: CGRect(x: 0, y: 0, width: diameter, height: diameter)).contains(value.location)
                    if inside { onDimTap() }
                case .tap:
                    let inside = Circle().path(in: CGRect(x: 0, y: 0, width: diameter, height: diameter)).contains(value.location)
                    isPressed = false
                    if inside { onTap() }
                case .hold:
                    holdModel.lift(haptics: haptics)
                }
            }
    }

    // MARK: - 読み上げ

    private var accessibilityLabel: String {
        switch mode {
        case .dim(let title, let subtitle): return "\(title)。\(subtitle)"
        case .tap(let title, _, _): return title
        case .hold: return "昨日をひらく"
        }
    }

    private var accessibilityHint: String {
        switch mode {
        case .dim: return "押すと、いつひらくか知らせます"
        case .tap(let title, _, let tone):
            if tone == .decide { return "タップで、昨日の1枚を投稿するか選びます" }
            return title == "今日を撮る" ? "タップで、タグをつけて撮影へ進みます" : ""
        case .hold: return "長押しでひらきます"
        }
    }
}

/// night・rest(ロック中)でも、押すとお知らせ(onDimTap)が出せるよう操作自体は無効化しない。
/// VoiceOverには「押すといつひらくか分かる」ボタンとして伝える。
private struct DisabledWhenDim: ViewModifier {
    let isDim: Bool

    func body(content: Content) -> some View {
        content.accessibilityAddTraits(isDim ? [.isButton] : [])
    }
}
