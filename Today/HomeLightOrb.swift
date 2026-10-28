import SwiftUI

/// Homeの「光の球」(旧:点線の輪と「0」)。昨日、預けた人の数だけ、ガラスの球の中で光がきらめく。
/// 写真そのものは見せない。ひらいたあと(opened)だけ、光に昨日の写真の代表色がつく。
struct HomeLightOrb: View {
    enum Look: Equatable {
        /// night・rest・dawn:白くきらめく(閉じている)
        case closed
        /// ready:白〜うすいオレンジ。球が心臓のようにゆっくりふくらむ
        case ready
        /// opened:色がつく(1.35倍・不透明度0.85)
        case opened
        /// first:中央にひとつだけ(脈打つ)
        case first
    }

    enum Layout {
        static let diameter: CGFloat = 230
        static let box: CGFloat = 300
        static let maxDots = 84
        static let goldenAngle = 2.39996
        /// 数字を出す時は、中央をあけた環状(半径54〜104pt)
        static let ringRadii: ClosedRange<CGFloat> = 54...104
        /// 球全体の回転(rad/ms)
        static let rotationPerMs = 0.00005
    }

    let look: Look
    let light: YesterdayLight
    /// opened の光の色(昨日の写真の代表色)
    var tones: [Color] = DevelopProgress.defaultTones
    /// 「あなたの光」(預けた1枚がない時はnil)
    var myColor: Color?
    /// 長押しでひらいている間の進み具合(0〜1)。球がオレンジに色づく。
    var openProgress: Double = 0
    let isAnimating: Bool
    /// 起動アニメーションの見た目(ガラス・あなたの光・波紋・世界の光のひろがり・数字が0から増える)
    var launch: LaunchFrame = .finished
    /// あなたの光の不透明度の上限(今日の1枚をまだ撮っていない日は 0.6)
    var myLightCap: Double = 1
    /// ウォーム起動の、0.4秒だけ、あなたの光がゆっくり光る(0〜1)
    var sparkle: Double = 0
    /// opened のとき、数字の下に小さく「MONDO ›」
    var showsMondo = false

    var body: some View {
        TimelineView(.animation(paused: !isAnimating)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            orb(t: t)
        }
        .frame(width: Layout.box, height: Layout.box)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func orb(t: Double) -> some View {
        let beat = look == .ready ? 1 + 0.025 * heartbeat(t) : 1
        return ZStack {
            // まわりの、状態の色のにじみ
            Circle()
                .fill(haloColor)
                .frame(width: Layout.diameter * 1.15, height: Layout.diameter * 1.15)
                .blur(radius: 46)
                .opacity(launch.haloOpacity)

            sphere
                .scaleEffect(launch.glassScale)
                .opacity(launch.glassOpacity)

            Canvas { context, size in
                drawLights(in: &context, size: size, t: t)
            }
            .frame(width: Layout.diameter, height: Layout.diameter)
            .clipShape(Circle())

            centerLabel
        }
        .scaleEffect(beat)
    }

    /// ガラスの質感(白の放射グラデ・縁取り1pt・内側の影)
    private var sphere: some View {
        let d = Layout.diameter
        return ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [.white.opacity(0.16), .white.opacity(0.05), .white.opacity(0.015)],
                    center: UnitPoint(x: 0.36, y: 0.28),
                    startRadius: 0,
                    endRadius: d * 0.72
                ))
            if openProgress > 0 {
                Circle()
                    .fill(RadialGradient(colors: [HomePalette.orange.opacity(0.45 * openProgress), .clear], center: .center, startRadius: 0, endRadius: d / 2))
            }
            Circle()
                .stroke(.black.opacity(0.55), lineWidth: 22)
                .blur(radius: 14)
                .clipShape(Circle())
            Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1)
        }
        .frame(width: d, height: d)
    }

    private var haloColor: Color {
        switch look {
        case .closed: return .white.opacity(0.06)
        case .first: return .white.opacity(0.05)
        case .ready: return HomePalette.orange.opacity(0.16 + 0.2 * openProgress)
        case .opened: return Color(hex: "BFD6FF").opacity(0.14)
        }
    }

    // MARK: - 中の光

    /// 数字を出すか(0 も「0」として出す。first は出さない)。取得できていない時は「—」
    private var showsNumber: Bool {
        look != .first
    }

    /// 数字の大きさ:「,」を含めた文字数で決める(〜3文字 58pt・4〜5文字 52pt・6文字以上 46pt)
    static func numberFontSize(_ text: String) -> CGFloat {
        switch text.count {
        case ...3: return 58
        case 4...5: return 52
        default: return 46
        }
    }

    static func formatted(_ n: Int) -> String {
        n.formatted(.number.grouping(.automatic).locale(Locale(identifier: "en_US")))
    }

    /// あなたの光の位置:球の外側の縁(R × 0.9)を、40秒で1周する。起動のひろがりの起点にもなる
    private static func myLightPoint(center: CGPoint, t: Double) -> CGPoint {
        let angle = t * 2 * .pi / 40 - .pi / 3
        let orbit = Layout.diameter / 2 * 0.9
        return CGPoint(x: center.x + cos(angle) * orbit, y: center.y + sin(angle) * orbit * 0.82)
    }

    private func drawLights(in context: inout GraphicsContext, size: CGSize, t: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let rotation = t * 1000 * Layout.rotationPerMs
        // 起動:点は最初から最終の位置。あなたの光に近い点から、波のように灯る(rv)
        let origin = look == .first ? center : Self.myLightPoint(center: center, t: t)
        let sweep = launch.sweep
        func reveal(_ point: CGPoint) -> Double {
            guard sweep < 1 else { return 1 }
            let d = hypot(point.x - origin.x, point.y - origin.y) / Layout.diameter
            return LaunchFrame.reveal(sweep: sweep, distance: d)
        }

        switch light {
        case .count(let n) where n > 0 && look != .first:
            let count = min(n, Layout.maxDots)
            for i in 0..<count {
                let seed = Self.seed(i)
                let fraction = (Double(i) + 0.5) / Double(count)
                let span: CGFloat = Layout.ringRadii.upperBound - Layout.ringRadii.lowerBound
                let r: CGFloat = Layout.ringRadii.lowerBound + span * CGFloat(fraction.squareRoot())
                let angle: Double = Double(i) * Layout.goldenAngle + rotation
                let point = CGPoint(x: center.x + CGFloat(cos(angle)) * r, y: center.y + CGFloat(sin(angle)) * r)
                let rv = reveal(point)
                if rv <= 0.001 { continue }
                let period = 0.7 + 0.9 * seed.a
                let twinkle = 0.5 + 0.5 * sin(2 * .pi * t / period + seed.b * 2 * .pi)
                var radius = 1.3 + 1.9 * seed.c
                var opacity = min(1, 0.35 + 0.65 * twinkle)
                let color: Color
                switch look {
                case .opened:
                    radius *= 1.35
                    opacity = 0.85
                    color = tones.isEmpty ? .white : tones[i % tones.count]
                case .ready:
                    color = seed.a > 0.5 ? Color(hex: "FFE2C8") : .white
                default:
                    color = .white
                }
                drawDot(in: &context, at: point, radius: radius * LaunchFrame.revealScale(rv), color: color,
                        opacity: opacity * LaunchFrame.revealOpacity(rv))
            }
        case .count:
            break
        case .loading, .failed:
            guard look != .first else { break }
            // 一度も取得できていない:粒は少なめに、静かにゆれる(エラー文言は出さない)
            for i in 0..<12 {
                let seed = Self.seed(i)
                let fraction = (Double(i) + 0.5) / 12
                let r: CGFloat = Layout.ringRadii.lowerBound + (Layout.ringRadii.upperBound - Layout.ringRadii.lowerBound) * CGFloat(fraction.squareRoot())
                let sway = 0.08 * sin(2 * .pi * t / 6 + seed.b * 6)
                let angle: Double = Double(i) * Layout.goldenAngle + rotation + sway
                let point = CGPoint(x: center.x + CGFloat(cos(angle)) * r, y: center.y + CGFloat(sin(angle)) * r)
                let rv = reveal(point)
                if rv <= 0.001 { continue }
                drawDot(in: &context, at: point, radius: (1.4 + 0.8 * seed.c) * LaunchFrame.revealScale(rv), color: .white,
                        opacity: (0.18 + 0.12 * sin(2 * .pi * t / 4 + seed.a * 6)) * LaunchFrame.revealOpacity(rv))
            }
        }

        // 初日:中央にひとつだけ脈打つ(これが「あなたの光」。起動ではともって、輪が一度ひろがるだけ)
        if look == .first {
            let pulse = 0.5 + 0.5 * sin(2 * .pi * t / 2.2)
            drawDot(in: &context, at: center, radius: 3 + 1.2 * pulse + 1.5 * sparkle, color: .white,
                    opacity: (0.55 + 0.45 * pulse) * launch.youOpacity)
            drawPulse(in: &context, at: center, color: Color(red: 1, green: 200 / 255, blue: 150 / 255))
            return
        }

        // あなたの光:輪(半径9pt)つきのオレンジの点が、球の縁をゆっくり回る。
        // 「あなたの光」がない日は描かない(起点は見せず、世界の光の波だけ)
        if let myColor {
            let opacity = launch.youOpacity * myLightCap
            if sparkle > 0 {
                drawDot(in: &context, at: origin, radius: 3 + 3 * sparkle, color: myColor, opacity: 0.5 * sparkle * myLightCap)
            }
            drawDot(in: &context, at: origin, radius: 3, color: myColor, opacity: opacity)
            let ring = Path(ellipseIn: CGRect(x: origin.x - 9, y: origin.y - 9, width: 18, height: 18))
            context.stroke(ring, with: .color(myColor.opacity(0.55 * opacity)), lineWidth: 1)
            drawPulse(in: &context, at: origin, color: Color(red: 1, green: 200 / 255, blue: 150 / 255))
        }
    }

    /// あなたの光の波紋:半径 9 + 150 × pl(球の座標 300 での値を、球の大きさに換算)/ 太さ1.6 / 0.6 × (1 − pl)
    private func drawPulse(in context: inout GraphicsContext, at point: CGPoint, color: Color) {
        let pl = launch.pulse
        guard pl > 0, pl < 1 else { return }
        let radius = (9 + 150 * pl) * Layout.diameter / 300
        let ring = Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        context.stroke(ring, with: .color(color.opacity(0.6 * (1 - pl) * myLightCap)), lineWidth: 1.6)
    }

    private func drawDot(in context: inout GraphicsContext, at point: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        var glow = context
        glow.addFilter(.blur(radius: radius * 1.6))
        glow.fill(Path(ellipseIn: CGRect(x: point.x - radius * 1.8, y: point.y - radius * 1.8, width: radius * 3.6, height: radius * 3.6)), with: .color(color.opacity(opacity * 0.45)))
        context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)), with: .color(color.opacity(opacity)))
    }

    /// 0〜1の「ドクン」。周期約2秒で、ふくらんでゆっくり戻る。
    private func heartbeat(_ t: Double) -> Double {
        let phase = (t / 2).truncatingRemainder(dividingBy: 1)
        return pow(sin(.pi * phase), 6) * 2 - 1
    }

    /// 点ごとに決まった乱数(毎フレーム同じ値)
    private static func seed(_ i: Int) -> (a: Double, b: Double, c: Double) {
        func f(_ x: Double) -> Double { (sin(x) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude }
        let x = Double(i) + 1
        return (f(x * 12.9898), f(x * 78.233), f(x * 37.719))
    }

    // MARK: - 数字

    private var centerLabel: some View {
        VStack(spacing: 6) {
            if showsNumber {
                // 起動中は 0 から増える(光が集まるイメージ)。新しい値が来ても、やり直さず目標を変えるだけ。
                let n = light.value.map { Int((Double($0) * launch.countFraction).rounded()) }
                let text = n.map(Self.formatted) ?? "—"
                let size = Self.numberFontSize(light.value.map(Self.formatted) ?? text)
                Text(text)
                    .font(.system(size: size, weight: .light))
                    .tracking(-0.05 * size)
                    .monospacedDigit()
                    .lineLimit(1)
                    .contentTransition(.numericText(value: Double(n ?? 0)))
                    .foregroundStyle(.white.opacity(n == nil ? 0.6 : 1))
                Text("世界の光 ・ 昨日")
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(0.2 * 10)
                    .foregroundStyle(.white.opacity(0.55))
                if showsMondo {
                    Text("MONDO ›")
                        .font(.system(size: 9.5, design: .monospaced))
                        .tracking(0.2 * 9.5)
                        .foregroundStyle(HomePalette.orange)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().strokeBorder(HomePalette.orange.opacity(0.45), lineWidth: 1))
                        .padding(.top, 4)
                        .transition(.opacity)
                }
            } else if launch.countOpacity >= 1 {
                Text(emptyCaption)
                    .font(.system(size: 11, design: .monospaced))
                    .tracking(0.08 * 11)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(width: 170)
                    .padding(.top, look == .first ? 70 : 24)
            }
        }
        .opacity(launch.countOpacity)
        .animation(.easeInOut(duration: 0.6), value: light)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    private var emptyCaption: String { "ここから、はじまる" }

    private var accessibilityText: String {
        if look == .first { return "ここから、はじまる" }
        guard let n = light.value else { return "昨日の世界の光" }
        return "昨日、世界で\(Self.formatted(n))枚の光があります"
    }
}
