import SwiftUI

/// 画面の下の「地球」。Homeの唯一の大きな操作(撮る・昨日をひらく・待つ)。
/// v54:見本 #hmoon(幅600・直径の上の方だけ 画面に見える、黒い 地球)。
enum MoonLayout {
    /// 見えている円弧の高さ(画面の下端から)。見本:844 − 712 = 132
    static let visibleHeight: CGFloat = 132
    /// ホームインジケーターとの重なりが気になる時に、月を上げる量(12〜20ptで調整)
    static let lift: CGFloat = 0

    /// 見本:幅390で 直径600
    static func diameter(screenWidth: CGFloat) -> CGFloat { screenWidth * 600 / 390 }

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

    /// v54:黒い 地球(見本:radial-gradient(circle at 50% 30%, #1C1C1C 0%, #0D0D0D 60%, #050505 100%))。
    /// 昼夜・状態に かかわらず 同じ(撮る・きのう・長押しは 文字と 上に のる 色だけで 伝える)。
    static func earthGradient(diameter: CGFloat) -> RadialGradient {
        RadialGradient(stops: [
            .init(color: Color(hex: "1C1C1C"), location: 0),
            .init(color: Color(hex: "0D0D0D"), location: 0.6),
            .init(color: Color(hex: "050505"), location: 1),
        ], center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: diameter / 2)
    }
}

struct HomeMoon: View {
    enum Mode: Equatable {
        /// night・rest:暗い地球。押すとやわらかい触覚2回+お知らせ(タップでは何も進まない)
        case dim(title: String, subtitle: String)
        /// dawn・first・opened:タップ
        case tap(title: String, subtitle: String, tone: Tone)
        /// ready:長押しのゲージ
        case hold

        /// dawn/first(warm)とopened(cool)で、光の あたたかさを 変える。
        /// deciding(decide)は warm と同じで、光だけ 少し あたたかく・脈動3.2秒。
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
    /// v54:地球は いつも 同じ見た目なので 使わない(呼び出し側との互換のために 残す)
    var chic = false
    var restful = false

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
            // にじみ(横長のやわらかい光)。呼吸のように不透明度が変わる。
            glowLayer
                .scaleEffect(launchGlowScale)
                .offset(y: -40)
                .opacity(launchGlowOpacity ?? (reduceMotion ? 0.7 : (isBreathing ? 1 : 0.45)))
                .animation(reduceMotion ? nil : .easeInOut(duration: breathPeriod / 2).repeatForever(autoreverses: true), value: isBreathing)
                .allowsHitTesting(false)

            // 長押し:地球の中心から、緑の光がひろがる
            if mode == .hold, p > 0 {
                Circle()
                    .fill(RadialGradient(colors: [LaterColor.film.opacity(0.85), LaterColor.film.opacity(0.25), .clear], center: .center, startRadius: 0, endRadius: diameter * 1.4 * CGFloat(p)))
                    .frame(width: diameter * 2.8 * CGFloat(p), height: diameter * 2.8 * CGFloat(p))
                    .offset(y: diameter / 2 - diameter * 1.4 * CGFloat(p))
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }

            ZStack(alignment: .top) {
                shape.fill(MoonLayout.earthGradient(diameter: diameter))
                EarthDots(diameter: diameter)
                shape.strokeBorder(.white.opacity(0.14), lineWidth: 1)
                // v54:見本の 3本線(白・赤・金)と 緑の 輪(上のほう、i.mat / i.r2)
                rim
                if mode == .hold, p > 0 {
                    // 長押し中は 進んだ分だけ 緑が 強くなる
                    shape.fill(LaterColor.film.opacity(0.18 * p))
                }
                if isPressed { shape.fill(.white.opacity(0.06)) }
                label(color: .white)
            }
            .frame(width: diameter, height: diameter)
            .clipShape(shape)

            // 長押し:地球の縁を、白い線が左から右へたどる
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

    private static let rimColors: [Color] = [.white, LaterColor.red, LaterColor.gold]

    /// v54:見本 i.r2(緑のふち)と i.mat(白・赤・金の 3本線)を、見えている 弧の あたりに
    private var rim: some View {
        let r = diameter / 2
        let arc = visibleArc
        return ZStack {
            Circle().inset(by: 14).strokeBorder(Color(hex: "96E8A7").opacity(0.25), lineWidth: 1)
            ForEach(0..<Self.rimColors.count, id: \.self) { i in
                Circle()
                    .trim(from: arc.from, to: arc.to)
                    .stroke(Self.rimColors[i], lineWidth: 2.2)
                    .frame(width: r * 2 - CGFloat(i) * 7, height: r * 2 - CGFloat(i) * 7)
                    .position(x: r, y: r)
            }
        }
        .allowsHitTesting(false)
    }

    /// にじみ(横長のやわらかい光)。呼吸のように不透明度が変わる。
    private var glowLayer: some View {
        Ellipse()
            .fill(glowColor)
            .frame(width: diameter * 1.15, height: 130)
            .blur(radius: 42)
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
            case .warm: return LaterColor.filmPale.opacity(0.4)
            case .decide: return LaterColor.filmLight.opacity(0.4)
            case .cool: return Color(hex: "BFD6FF").opacity(0.42)
            }
        case .hold: return LaterColor.film.opacity(0.5)
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

    /// 地球の中の 文字(見本 #hmt:Inter 900 25px / #hms:Space Mono 700 10.5px 緑)
    private func label(color: Color) -> some View {
        TimelineView(.animation(paused: !holdModel.isMoving)) { context in
            let p = mode == .hold ? holdModel.progress(at: context.date) : 0
            let title = titleText
            VStack(spacing: 6) {
                Text(title)
                    .font(Typo.ui(900, 25))
                    .tracking(-0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: diameter * 0.58)
                    .frame(height: 30)
                    .padding(.top, 28 - 11)
                if let subtitle = subtitleText(progress: p), !dynamicTypeSize.isAccessibilitySize {
                    MoonSubtitle(text: subtitle)
                        .font(Typo.label(10.5, bold: true))
                        .tracking(1.47)
                        .lineLimit(1)
                        .padding(.top, 2)
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

/// v54:月の下の字。先頭の「●」(のこり)は 緑(LaterColor.film)、「○」(使った)は そのまま
private struct MoonSubtitle: View {
    let text: String

    var body: some View {
        let dots = text.prefix { $0 == "●" }
        let rest = text.dropFirst(dots.count)
        return (Text(String(dots)).foregroundColor(LaterColor.film) + Text(String(rest)).foregroundColor(LaterColor.filmPale))
    }
}

/// v54:見本 canvas#mgl の かわり。フィボナッチ球(約260点)を 正面から見た ドットの 世界地図ふう。回らない(静か)。
private struct EarthDots: View {
    let diameter: CGFloat

    private struct Dot { let x, y, z: Double }
    private static let count = 260
    private static let points: [Dot] = {
        let golden = Double.pi * (3 - 5.0.squareRoot())
        return (0..<count).map { i in
            let y = 1 - (Double(i) + 0.5) / Double(count) * 2
            let r = (1 - y * y).squareRoot()
            let theta = golden * Double(i)
            return Dot(x: cos(theta) * r, y: y, z: sin(theta) * r)
        }
    }()

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = size.width / 2
            for d in Self.points where d.z > -0.1 {
                let x = c.x + d.x * r, y = c.y + d.y * r
                let s = 1.1 + 0.9 * max(0, d.z)
                let a = 0.10 + 0.22 * max(0, d.z)
                ctx.fill(Path(ellipseIn: CGRect(x: x - s, y: y - s, width: 2 * s, height: 2 * s)), with: .color(.white.opacity(a)))
            }
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
