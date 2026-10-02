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

    /// 上から下への縦グラデーション(見えるのは上の約25%:白 → 桃 → 薄い紫。ふくらむと藍まで)
    static let gradient = LinearGradient(stops: [
        .init(color: Color(hex: "FFFFFF"), location: 0),
        .init(color: Color(hex: "FFE6D3"), location: 0.07),
        .init(color: Color(hex: "FFC0A2"), location: 0.13),
        .init(color: Color(hex: "E3B9FF"), location: 0.20),
        .init(color: Color(hex: "93A7FF"), location: 0.27),
        .init(color: Color(hex: "4B60D4"), location: 0.42),
        .init(color: Color(hex: "2A2F78"), location: 1),
    ], startPoint: .top, endPoint: .bottom)

    static let ink = Color(hex: "1A1A22")
}

struct HomeMoon: View {
    enum Mode: Equatable {
        /// ① 9:00前・24:00後:暗い月。押せない
        case dim(title: String)
        /// ②④⑤・③':グラデーションの月。タップ
        case tap(title: String, subtitle: String)
        /// ③:やや暗いグラデーション+長押しのゲージ
        case hold
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
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { isBreathing = true }
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

    private func moon(progress p: Double) -> some View {
        let shape = Circle()
        return ZStack(alignment: .top) {
            switch mode {
            case .dim:
                shape.fill(LinearGradient(colors: [Color(hex: "2A2A2E"), Color(hex: "151517")], startPoint: .top, endPoint: .bottom))
                shape.strokeBorder(.white.opacity(0.12), lineWidth: 1)
            case .tap:
                shape.fill(MoonLayout.gradient)
                    .brightness(isPressed ? 0.06 : 0)
                shape.strokeBorder(.white.opacity(0.75), lineWidth: 1.5)
            case .hold:
                // 状態③:やや暗いグラデーション。押している間、下から明るいグラデーションがたまる。
                shape.fill(MoonLayout.gradient)
                    .saturation(0.7)
                    .brightness(-0.3)
                shape.fill(MoonLayout.gradient)
                    .mask(alignment: .top) { gaugeMask(p) }
                if p > 0.01 && p < 1 && !reduceMotion {
                    Capsule()
                        .fill(.white.opacity(0.8))
                        .frame(width: diameter * 0.8, height: 10)
                        .blur(radius: 5)
                        .offset(y: gaugeTop(p) - 5)
                        .allowsHitTesting(false)
                }
                shape.strokeBorder(.white.opacity(0.5), lineWidth: 1.5)
            }

            label(color: textColor)
            if mode == .hold {
                label(color: MoonLayout.ink)
                    .mask(alignment: .top) { gaugeMask(p) }
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(shape)
        .shadow(color: glowColor, radius: glowRadius)
        .scaleEffect(mode == .hold ? 1 - 0.018 * p : (isPressed ? 0.96 : 1))
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
    }

    /// 見えている円弧(上端から84pt)に対して、下端から p×84pt の高さまで明るい層を見せる。
    private func gaugeTop(_ p: Double) -> CGFloat {
        MoonLayout.visibleHeight * (1 - CGFloat(p))
    }

    private func gaugeMask(_ p: Double) -> some View {
        Rectangle()
            .frame(width: diameter, height: max(0, diameter - gaugeTop(p)))
            .offset(y: gaugeTop(p))
    }

    private var glowColor: Color {
        if isDim { return .clear }
        let opacity = reduceMotion ? 0.33 : (isBreathing ? 0.42 : 0.24)
        return Color(red: 1, green: 200 / 255, blue: 170 / 255).opacity(opacity)
    }

    private var glowRadius: CGFloat {
        isDim ? 0 : (reduceMotion ? 38 : (isBreathing ? 45 : 30))
    }

    private var textColor: Color {
        switch mode {
        case .dim: return Color(hex: "8E8E93")
        case .tap: return MoonLayout.ink
        case .hold: return .white
        }
    }

    private var titleText: String {
        switch mode {
        case .dim(let title): return title
        case .tap(let title, _): return title
        case .hold:
            if holdModel.isDone { return "ひらきます" }
            return holdModel.isPressing ? "そのまま、持っていて…" : "現像された昨日を見る"
        }
    }

    private func subtitleText(progress p: Double) -> String? {
        switch mode {
        case .dim: return nil
        case .tap(_, let subtitle): return subtitle
        case .hold:
            if holdModel.isDone { return nil }
            if holdModel.isPressing {
                return String(format: "あと %.1f 秒", max(0, (1 - p) * HoldToOpenRules.duration))
            }
            return "長押しで、ひらく"
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
                    .font(.system(size: titleSize, weight: .bold))
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
                    break
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
        case .dim(let title): return title.contains("明日") ? "明日9時にはじまります" : "9時にはじまります"
        case .tap(let title, _): return title
        case .hold: return "現像された昨日を見る"
        }
    }

    private var accessibilityHint: String {
        switch mode {
        case .dim: return ""
        case .tap(let title, _): return title == "今日を撮る" ? "タグをつけて、撮影へ進みます" : ""
        case .hold: return "長押しでひらきます"
        }
    }
}

private struct DisabledWhenDim: ViewModifier {
    let isDim: Bool

    func body(content: Content) -> some View {
        if isDim {
            content.accessibilityAddTraits(.isStaticText).disabled(true)
        } else {
            content
        }
    }
}
