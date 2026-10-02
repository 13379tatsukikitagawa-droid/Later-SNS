import SwiftUI

// MARK: - 色

enum OnboardingPalette {
    static let background = Color.black
    static let text = Color.white
    /// 静けさのパート(ルッキズム)の文字色
    static let quietText = Color(hex: "E9E9ED")
    static let secondaryText = Color(hex: "8E8E93")
    static let subText = Color(hex: "BCBBC0")
    static let note = Color(hex: "6B6B70")
    static let counts = Color(hex: "6F6F75")
    static let surface = Color(hex: "1C1C1E")
}

/// 画面の高さ844pt(デザインの基準)に対する縦方向の倍率。小さい端末でも同じ比率で配置する。
struct OnboardingMetrics {
    let size: CGSize

    var scale: CGFloat { min(1.1, max(0.75, size.height / 844)) }
    func y(_ value: CGFloat) -> CGFloat { value * scale }

    static let orbCenterY: CGFloat = 170
    static let historyTop: CGFloat = 196
    static let historyHeight: CGFloat = 162
    static let textTop: CGFloat = 372
    static let visualCenterY: CGFloat = 312
    static let irisCenterY: CGFloat = 362
    static let wordCenterY: CGFloat = 530
}

// MARK: - 真珠の玉

/// 画面上部の白い真珠のような球と、まわりの8つの点(進み具合)。
struct OnboardingOrb: View {
    let litCount: Int
    /// 結びの長押しの進み具合(0〜1)。0.04を超えると点が色づき、光が薄いオレンジになる。
    var bloom: Double = 0
    /// 値が変わるたびに、玉が1回だけ明るく脈打つ(名前の確定)。
    var pulseTrigger: Int = 0

    static let pearlDiameter: CGFloat = 78
    static let dotRadius: CGFloat = 74

    var body: some View {
        ZStack {
            glow
            dots
            pearl
        }
        .frame(width: 200, height: 200)
        .keyframeAnimator(initialValue: 1.0, trigger: pulseTrigger) { content, scale in
            content
                .scaleEffect(scale)
                .brightness((scale - 1) * 1.2)
        } keyframes: { _ in
            CubicKeyframe(1.12, duration: 0.45)
            CubicKeyframe(1.0, duration: 0.45)
        }
        .accessibilityHidden(true)
    }

    private var isBlooming: Bool { bloom > 0.04 }

    private var glow: some View {
        let color: Color = isBlooming
            ? Color(red: 1, green: (170 + 60 * (1 - bloom)) / 255, blue: 100 / 255).opacity(0.22 + 0.14 * bloom)
            : .white.opacity(0.22)
        return Circle()
            .fill(RadialGradient(colors: [color, .clear], center: .center, startRadius: 0, endRadius: 98))
            .frame(width: Self.pearlDiameter + 80 + 80, height: Self.pearlDiameter + 80 + 80)
    }

    private var dots: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                let angle = Angle.degrees(-90 + 45 * Double(index)).radians
                let color = dotColor(index)
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                    .shadow(color: index < litCount || isBlooming ? color.opacity(0.9) : .clear, radius: 5)
                    .offset(x: cos(angle) * Self.dotRadius, y: sin(angle) * Self.dotRadius)
                    .animation(.easeInOut(duration: 0.6), value: litCount)
            }
        }
    }

    private func dotColor(_ index: Int) -> Color {
        if isBlooming {
            return HomePalette.ringColor(atFraction: Double(index) / 8).opacity(0.3 + 0.7 * min(1, bloom * 1.6))
        }
        return index < litCount ? .white : .white.opacity(0.16)
    }

    private var pearl: some View {
        Circle()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: Color(hex: "E9ECF0"), location: 0.24),
                        .init(color: Color(hex: "9AA1AB"), location: 0.6),
                        .init(color: Color(hex: "2B2F35"), location: 1),
                    ],
                    center: UnitPoint(x: 0.34, y: 0.26),
                    startRadius: 0,
                    endRadius: 77
                )
            )
            .overlay(
                Circle().fill(LinearGradient(colors: [.clear, .black.opacity(0.3)], startPoint: .center, endPoint: .bottom))
            )
            .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
            .overlay(
                Ellipse()
                    .fill(RadialGradient(colors: [.white.opacity(0.85), .white.opacity(0)], center: .center, startRadius: 0, endRadius: 15))
                    .frame(width: 30, height: 16)
                    .rotationEffect(.degrees(-24))
                    .offset(x: -12, y: -24)
            )
            .frame(width: Self.pearlDiameter, height: Self.pearlDiameter)
            .shadow(color: .white.opacity(0.28), radius: 25)
    }
}

/// 背景の上部の薄い白い光(上端から楕円)。
struct OnboardingSpotlight: View {
    var body: some View {
        GeometryReader { proxy in
            Ellipse()
                .fill(RadialGradient(colors: [.white.opacity(0.17), .clear], center: .center, startRadius: 0, endRadius: proxy.size.width * 0.62))
                .frame(width: proxy.size.width * 1.4, height: 460)
                .position(x: proxy.size.width / 2, y: -20)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - タイプライター

/// 1文字ずつ表示するタイミング。1文字58ms、「、」のあと+190ms、「。」のあと+340ms、改行で+360ms。
/// Reduce Motionのときは1行ずつ(0.3秒ずつ)。
struct TypewriterSchedule {
    /// 文字(改行以外)ごとの表示開始時刻(秒)
    let revealTimes: [Double]
    /// 打ち終わって、カーソルが消える時刻(この時点でボタンを出す)
    let finishTime: Double

    static let characterInterval = 0.058
    static let afterComma = 0.19
    static let afterPeriod = 0.34
    static let newlinePause = 0.36
    static let caretLinger = 0.45
    static let lineFadeInterval = 0.3

    init(text: String, reduceMotion: Bool) {
        var times: [Double] = []
        var t = 0.0
        if reduceMotion {
            for character in text {
                if character == "\n" { t += Self.lineFadeInterval; continue }
                times.append(t)
            }
            revealTimes = times
            finishTime = t + Self.lineFadeInterval
            return
        }
        for character in text {
            if character == "\n" { t += Self.newlinePause; continue }
            times.append(t)
            t += Self.characterInterval
            if character == "、" { t += Self.afterComma }
            if character == "。" { t += Self.afterPeriod }
        }
        revealTimes = times
        finishTime = t + Self.caretLinger
    }
}

/// 1つのTextとして描き、文字(グリフ)ごとに不透明度0→1・ブラー5pt→0・下から3ptで現す。
private struct TypewriterRenderer: TextRenderer {
    var elapsed: Double
    let revealTimes: [Double]
    let reduceMotion: Bool
    let showsCaret: Bool

    var animatableData: Double {
        get { elapsed }
        set { elapsed = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        var index = 0
        var lastRect: CGRect?
        let duration = reduceMotion ? TypewriterSchedule.lineFadeInterval : 0.22
        for line in layout {
            for run in line {
                for slice in run {
                    let start = index < revealTimes.count ? revealTimes[index] : (revealTimes.last ?? 0)
                    index += 1
                    let progress = (elapsed - start) / duration
                    guard progress > 0 else { continue }
                    lastRect = slice.typographicBounds.rect
                    if progress >= 1 {
                        context.draw(slice)
                        continue
                    }
                    var glyphContext = context
                    glyphContext.opacity = progress
                    if !reduceMotion {
                        glyphContext.translateBy(x: 0, y: 3 * (1 - progress))
                        glyphContext.addFilter(.blur(radius: 5 * (1 - progress)))
                    }
                    glyphContext.draw(slice)
                }
            }
        }
        if showsCaret, let rect = lastRect {
            let caret = CGRect(x: rect.maxX + 2, y: rect.minY + rect.height * 0.12, width: 2, height: rect.height * 0.8)
            context.fill(Path(caret), with: .color(.white))
        }
    }
}

struct TypewriterText: View {
    let lines: [OnboardingLine]
    let fontSize: CGFloat
    let primaryColor: Color
    let schedule: TypewriterSchedule
    let start: Date
    /// trueなら全文を即座に出す(スキップ・VoiceOver・打ち終わった後)。
    let showsEverything: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: showsEverything)) { context in
            let elapsed = showsEverything ? Double.infinity : context.date.timeIntervalSince(start)
            let typing = elapsed < schedule.finishTime - TypewriterSchedule.caretLinger + 0.001
            let lingering = elapsed < schedule.finishTime
            let blinkOn = elapsed.truncatingRemainder(dividingBy: 0.9) < 0.45
            Self.text(lines, fontSize: fontSize, primaryColor: primaryColor)
                .textRenderer(TypewriterRenderer(
                    elapsed: elapsed,
                    revealTimes: schedule.revealTimes,
                    reduceMotion: reduceMotion,
                    showsCaret: !reduceMotion && !showsEverything && (typing || (lingering && blinkOn))
                ))
                .lineSpacing(fontSize * 0.42)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        // タイプの途中でも、全文が最初から読み上げられるようにする。
        .accessibilityLabel(Self.plainText(lines))
    }

    static func plainText(_ lines: [OnboardingLine]) -> String {
        lines.map(\.text).joined().replacingOccurrences(of: "\n", with: "")
    }

    static func text(_ lines: [OnboardingLine], fontSize: CGFloat, primaryColor: Color) -> Text {
        var attributed = AttributedString()
        for line in lines {
            var segment = AttributedString(line.text)
            segment.foregroundColor = line.tone == .primary ? primaryColor : OnboardingPalette.secondaryText
            attributed += segment
        }
        return Text(attributed)
            .font(.system(size: fontSize, weight: .semibold))
            .tracking(-0.04 * fontSize)
    }
}

// MARK: - 長押しボタン

/// 長押しの進み具合。押している間は経過時間/1.5秒、離すと0.26秒で0へ戻る(線形)。
/// ボタン・玉・背景の光が、同じ値をそれぞれのTimelineViewから読む。
@MainActor
@Observable
final class OnboardingHoldModel {
    static let duration: TimeInterval = 1.5
    static let releaseDuration: TimeInterval = 0.26

    private(set) var pressStart: Date?
    private(set) var releaseFrom: (progress: Double, at: Date)?
    /// 一度満ちたら、指を離しても再開しない(二重判定をしない)。
    private(set) var isDone = false
    private(set) var completedAt: Date?

    func progress(at date: Date) -> Double {
        if isDone { return 1 }
        if let pressStart { return min(1, max(0, date.timeIntervalSince(pressStart) / Self.duration)) }
        if let releaseFrom {
            return max(0, releaseFrom.progress - date.timeIntervalSince(releaseFrom.at) / Self.releaseDuration)
        }
        return 0
    }

    var isMoving: Bool {
        pressStart != nil || releaseFrom != nil
            || (completedAt.map { Date().timeIntervalSince($0) < 1 } ?? false)
    }

    /// 押し始め。離した直後に押し直した場合は、戻りかけの位置から続ける。戻り値は満ちるまでの残り秒数。
    func begin(at date: Date = Date()) -> TimeInterval? {
        guard !isDone, pressStart == nil else { return nil }
        let current = progress(at: date)
        pressStart = date.addingTimeInterval(-current * Self.duration)
        releaseFrom = nil
        return (1 - current) * Self.duration
    }

    func release(at date: Date = Date()) {
        guard !isDone, pressStart != nil else { return }
        releaseFrom = (progress(at: date), date)
        pressStart = nil
    }

    func complete(at date: Date = Date()) {
        guard !isDone else { return }
        isDone = true
        completedAt = date
        pressStart = nil
        releaseFrom = nil
    }

    func reset() {
        pressStart = nil
        releaseFrom = nil
        isDone = false
        completedAt = nil
    }
}

struct OnboardingHoldButton: View {
    let model: OnboardingHoldModel
    var diameter: CGFloat = 108
    let label: String
    let sublabel: String
    /// VoiceOverの代わりの操作(アクセシビリティアクション)の名前
    let accessibilityActionName: String
    let onBegin: (_ remaining: TimeInterval) -> Void
    let onRelease: () -> Void
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isTouching = false
    @State private var isBreathing = false
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation(paused: !model.isMoving && reduceMotion)) { context in
                let progress = model.progress(at: context.date)
                button(progress: progress, date: context.date)
            }
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isTouching) { _, state, _ in state = true }
                    .onChanged { _ in begin() }
                    .onEnded { _ in release() }
            )
            .onChange(of: isTouching) { _, touching in
                // システムのジェスチャーで中断された時も「離した」と同じ扱いにする。
                if !touching { release() }
            }
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityHint("ダブルタップしたまま押し続けると、進みます")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: accessibilityActionName) { complete() }

            Text(label)
                .font(.system(size: 14.5, weight: .semibold))
                .tracking(-0.02 * 14.5)
                .foregroundStyle(.white)
                .padding(.top, 16)
                .accessibilityHidden(true)

            Text(sublabel)
                .font(.system(size: 9.5, design: .monospaced))
                .tracking(0.14 * 9.5)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .accessibilityHidden(true)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { isBreathing = true }
        }
        .onDisappear { holdTask?.cancel() }
    }

    private func button(progress: Double, date: Date) -> some View {
        let ringRadius = diameter / 2 - 5
        let discDiameter = 56 * diameter / 108 * (1 - 0.55 * progress)
        let orbitAngle = reduceMotion ? 0 : date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) / 6 * 360
        let rippleProgress = model.completedAt.map { min(1, date.timeIntervalSince($0) / 0.7) }
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [.white.opacity(0.1), .clear], center: .center, startRadius: 0, endRadius: diameter * 0.7))
                .frame(width: diameter + 44, height: diameter + 44)
                .scaleEffect(isBreathing ? 1.18 : 1)
                .opacity(isBreathing ? 0.65 : 1)

            Circle()
                .stroke(.white.opacity(0.18), lineWidth: 2.5)
                .frame(width: ringRadius * 2, height: ringRadius * 2)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(.white, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: ringRadius * 2, height: ringRadius * 2)

            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
                .shadow(color: .white, radius: 5)
                .opacity(progress > 0.02 ? 0 : 0.55)
                .offset(y: -ringRadius)
                .rotationEffect(.degrees(orbitAngle))

            Circle()
                .fill(RadialGradient(colors: [.white, Color(hex: "E4E4E8")], center: UnitPoint(x: 0.34, y: 0.28), startRadius: 0, endRadius: discDiameter * 0.8))
                .frame(width: discDiameter, height: discDiameter)
                .shadow(color: .white.opacity(0.5 + 0.3 * progress), radius: 11 - 4 * progress)

            if let rippleProgress, rippleProgress < 1 {
                Circle()
                    .stroke(.white, lineWidth: 2)
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(1 + 1.6 * rippleProgress)
                    .opacity(0.9 * (1 - rippleProgress))
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private func begin() {
        guard let remaining = model.begin() else { return }
        onBegin(remaining)
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled, model.pressStart != nil else { return }
            complete()
        }
    }

    private func release() {
        guard model.pressStart != nil, !model.isDone else { return }
        holdTask?.cancel()
        model.release()
        onRelease()
    }

    private func complete() {
        guard !model.isDone else { return }
        holdTask?.cancel()
        model.complete()
        onComplete()
    }
}

// MARK: - 開幕

/// 開幕(質問の前、約7秒。デモの数値どおり):ファインダーの角 → 絞りが開く →
/// 「Later」が現像されるように現れる → 絞りが玉になって上へ。スキップ・途中停止はできない。
struct OnboardingOpeningView: View {
    let start: Date
    let metrics: OnboardingMetrics

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 開幕全体の長さ(この時刻に質問0のタイプが始まる)。
    static func duration(reduceMotion: Bool) -> TimeInterval { reduceMotion ? 2.6 : 7.0 }
    /// 玉と背景の光が現れ始める時刻。
    static func orbRevealTime(reduceMotion: Bool) -> TimeInterval { reduceMotion ? 2.0 : 6.0 }

    private static let irisRadius: CGFloat = 96
    private static let wordmark = Array("Later")

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
            ZStack {
                if !reduceMotion {
                    brackets(t: t)
                    iris(t: t)
                }
                wordmark(t: t)
            }
            .frame(width: metrics.size.width, height: metrics.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Later")
    }

    // MARK: 角

    private func brackets(t: Double) -> some View {
        let appear = Easing.easeOut(Easing.clamp((t - 0.5) / 0.9))
        let disappear = Easing.clamp((t - 5.5) / 0.9)
        let opacity = appear * (1 - disappear)
        let inset: CGFloat = 34
        let top = metrics.y(120), bottom = metrics.size.height - metrics.y(120)
        let slide = 14 * (1 - appear)
        return ZStack {
            bracket(rotation: 0).position(x: inset + 15 + slide, y: top + 15 + slide)
            bracket(rotation: 90).position(x: metrics.size.width - inset - 15 - slide, y: top + 15 + slide)
            bracket(rotation: 270).position(x: inset + 15 + slide, y: bottom - 15 - slide)
            bracket(rotation: 180).position(x: metrics.size.width - inset - 15 - slide, y: bottom - 15 - slide)
        }
        .opacity(opacity)
    }

    private func bracket(rotation: Double) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 30))
            path.addLine(to: CGPoint(x: 0, y: 8))
            path.addQuadCurve(to: CGPoint(x: 8, y: 0), control: .zero)
            path.addLine(to: CGPoint(x: 30, y: 0))
        }
        .stroke(.white.opacity(0.75), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        .frame(width: 30, height: 30)
        .rotationEffect(.degrees(rotation))
    }

    // MARK: 絞り

    private func iris(t: Double) -> some View {
        let fadeIn = Easing.clamp((t - 0.5) / 0.8)
        let fadeOut = Easing.clamp((t - 6.0) / 0.9)
        let open = Easing.easeInOutCubic(Easing.clamp((t - 1.2) / 1.6))
        let close = Easing.easeInOutCubic(Easing.clamp((t - 5.5) / 1.1))
        let aperture = t < 5.5 ? open : 1 - close * 0.96
        let rotation = t < 5.5 ? open * .pi / 6 : .pi / 6 * (1 - close)
        let rise = CubicBezier(0.6, 0, 0.2, 1).value(at: Easing.clamp((t - 5.5) / 1.3))
        let travel = metrics.y(OnboardingMetrics.irisCenterY) - metrics.y(OnboardingMetrics.orbCenterY)

        return Canvas { context, size in
            Self.drawIris(in: &context, size: size, aperture: aperture, rotation: rotation)
        }
        .frame(width: 200, height: 200)
        .scaleEffect(1 - 0.61 * rise)
        .position(x: metrics.size.width / 2, y: metrics.y(OnboardingMetrics.irisCenterY) - travel * rise)
        .opacity(fadeIn * (1 - fadeOut))
    }

    /// 六角形の穴(半径0→64pt)と、各辺を円の縁まで延ばした羽根の線。頂点は毎フレーム計算する。
    private static func drawIris(in context: inout GraphicsContext, size: CGSize, aperture: Double, rotation: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let R = irisRadius
        let body = Path(ellipseIn: CGRect(x: center.x - R, y: center.y - R, width: R * 2, height: R * 2))
        context.fill(body, with: .radialGradient(
            Gradient(colors: [Color(hex: "2A2D33"), Color(hex: "0C0D10")]),
            center: CGPoint(x: center.x, y: center.y - R * 0.2), startRadius: 0, endRadius: R * 1.4
        ))
        context.stroke(body, with: .color(.white.opacity(0.55)), lineWidth: 1.5)

        let r = max(0.001, aperture * 64)
        let vertices: [CGPoint] = (0..<6).map { k in
            let a = rotation + Double(k) * .pi / 3
            return CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a))
        }
        var hexagon = Path()
        hexagon.addLines(vertices)
        hexagon.closeSubpath()
        context.fill(hexagon, with: .radialGradient(
            Gradient(stops: [
                .init(color: .white, location: 0),
                .init(color: .white.opacity(0.85), location: 0.55),
                .init(color: Color(hex: "FFD9B3").opacity(0), location: 1),
            ]),
            center: center, startRadius: 0, endRadius: r
        ))

        for k in 0..<6 {
            let a = vertices[k], b = vertices[(k + 1) % 6]
            var dx = b.x - a.x, dy = b.y - a.y
            let length = max(0.0001, hypot(dx, dy))
            dx /= length
            dy /= length
            let px = b.x - center.x, py = b.y - center.y
            let projection = px * dx + py * dy
            let c = px * px + py * py - R * R
            let t = -projection + sqrt(max(0, projection * projection - c))
            var blade = Path()
            blade.move(to: b)
            blade.addLine(to: CGPoint(x: b.x + dx * t, y: b.y + dy * t))
            context.stroke(blade, with: .color(.white.opacity(0.28)), lineWidth: 1.2)
        }
        context.stroke(hexagon, with: .color(.white.opacity(0.7)), lineWidth: 1)
    }

    // MARK: 「Later」

    private func wordmark(t: Double) -> some View {
        let fadeOut = reduceMotion ? Easing.clamp((t - 1.8) / 0.6) : Easing.clamp((t - 5.5) / 0.9)
        return HStack(spacing: 0) {
            ForEach(Array(Self.wordmark.enumerated()), id: \.offset) { index, character in
                let progress: Double = reduceMotion
                    ? Easing.clamp(t / 0.8)
                    : Easing.easeOut(Easing.clamp((t - 2.8 - 0.23 * Double(index)) / 1.5))
                Text(String(character))
                    .font(.system(size: 58, weight: .bold))
                    .tracking(-0.045 * 58)
                    .foregroundStyle(.white)
                    .opacity(progress)
                    .blur(radius: reduceMotion ? 0 : 14 * (1 - progress))
                    .offset(y: reduceMotion ? 0 : 18 * (1 - progress))
            }
        }
        .opacity(1 - fadeOut)
        .position(x: metrics.size.width / 2, y: metrics.y(OnboardingMetrics.wordCenterY))
    }
}

enum Easing {
    static func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
    static func easeOut(_ t: Double) -> Double { 1 - pow(1 - t, 3) }
    static func easeInOutCubic(_ t: Double) -> Double {
        t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }
}

/// CSSのcubic-bezier(x1, y1, x2, y2)と同じ曲線。
struct CubicBezier {
    let x1, y1, x2, y2: Double

    init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }

    func value(at x: Double) -> Double {
        guard x > 0 else { return 0 }
        guard x < 1 else { return 1 }
        // xからパラメータsを二分法で求め、yを返す。
        var low = 0.0, high = 1.0, s = x
        for _ in 0..<24 {
            s = (low + high) / 2
            if Self.bezier(s, x1, x2) < x { low = s } else { high = s }
        }
        return Self.bezier(s, y1, y2)
    }

    private static func bezier(_ s: Double, _ p1: Double, _ p2: Double) -> Double {
        let inv = 1 - s
        return 3 * inv * inv * s * p1 + 3 * inv * s * s * p2 + s * s * s
    }
}

// MARK: - ペルソナのアイコン

/// 自動で割り当てるペルソナのアイコン。ユーザーごとに決まった配置の白い点(顔は使わない)。
/// 初回設定で撮ったプロフィール画像が現像されるまでの間などに表示する。
struct PersonaIcon: View {
    let seed: UUID

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle().fill(Color.black)
                Circle().strokeBorder(.white.opacity(0.14), lineWidth: max(1, side * 0.012))
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(.white.opacity(point.opacity))
                        .frame(width: side * point.size, height: side * point.size)
                        .position(x: side * point.x, y: side * point.y)
                }
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("ペルソナのアイコン")
    }

    private var points: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] {
        // UUIDのバイト列から決まるシード(FNV-1a)。同じユーザーなら毎回同じ配置になる。
        var state = withUnsafeBytes(of: seed.uuid) { bytes in
            bytes.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        }
        func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(1 << 53)
        }
        let count = 5 + Int(next() * 3)
        return (0..<count).map { index in
            let angle = next() * 2 * .pi
            let radius = 0.12 + next() * 0.24
            return (
                x: 0.5 + CGFloat(cos(angle) * radius),
                y: 0.5 + CGFloat(sin(angle) * radius),
                size: index == 0 ? 0.11 : 0.04 + CGFloat(next()) * 0.04,
                opacity: index == 0 ? 1 : 0.45 + next() * 0.45
            )
        }
    }
}

// MARK: - 折り返して並べる

/// タグのチップなどを、横に並べて入りきらなければ折り返す。
struct OnboardingFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
