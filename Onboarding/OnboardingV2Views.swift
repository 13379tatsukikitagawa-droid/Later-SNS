import SwiftUI

// MARK: - ③ Laterの一日(24時間の輪を針が回る6場面)

/// 自動で進む6場面(合計 約25秒)。最後の場面で止まる。「つぎへ」で飛ばせる・線のタップでその場面へ。
/// 触覚はボタンだけ。Reduce Motion では自動で進めず、場面ごとに完成した絵(t=0.9)を出す。
struct LaterDayView: View {
    /// 画面が前面にあって、中身が出ているか(離れたら止める)
    let isActive: Bool
    let onFinish: () -> Void
    let onTapNext: () -> Void

    struct Scene {
        let duration: TimeInterval
        let title: String
        let body: String
    }

    static let scenes: [Scene] = [
        Scene(duration: 3.8, title: "Laterとは", body: "4〜8人のグループで、1日1枚の写真を見せ合うアプリです。"),
        Scene(duration: 4.3, title: "9:00、全員が同時にひらく", body: "毎朝9:00になると、グループ全員が同じ時刻に撮れるようになります。"),
        Scene(duration: 4.5, title: "1日1枚、長押しで撮る", body: "タグを選んで、1.5秒の長押し。プレビューも撮り直しもありません。"),
        Scene(duration: 4.0, title: "撮ると、昨日がひらく", body: "今日を撮った人だけが、みんなの昨日の写真を見られます。"),
        Scene(duration: 3.8, title: "24:00で、締め切り", body: "今日の写真は、あなたにもまだ見えません。過ぎると、その日はもう撮れません。"),
        Scene(duration: 4.8, title: "翌朝に現像、7日で消える", body: "写真は翌朝9:00に現像され、7日で消えます。"),
    ]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var index = 0
    @State private var sceneStart = Date()
    @State private var textVisible = true

    private var isLast: Bool { index == Self.scenes.count - 1 }
    private var autoplays: Bool { !reduceMotion && !voiceOverEnabled }

    var body: some View {
        GeometryReader { proxy in
            let metrics = OnboardingMetrics(size: proxy.size)
            TimelineView(.animation(paused: !isActive || !autoplays)) { context in
                let t = sceneProgress(at: context.date)
                ZStack(alignment: .topLeading) {
                    DayRing(scene: index, t: t)
                        .frame(width: 236, height: 236)
                        .position(x: proxy.size.width / 2, y: metrics.y(292) + 118)

                    progressBars(t: t)
                        .padding(.horizontal, 28)
                        .frame(width: proxy.size.width)
                        .offset(y: metrics.y(540))

                    sceneText
                        .padding(.horizontal, 28)
                        .frame(width: proxy.size.width, alignment: .leading)
                        .offset(y: metrics.y(576))
                }
                .onChange(of: t >= 1) { _, finished in
                    // 自動で次の場面へ(最後の場面で止まる)
                    if finished, autoplays, !isLast { show(index + 1) }
                }
            }

            Button(action: next) {
                Text(isLast ? "わかりました" : "つぎへ")
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.025 * 17)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(.white))
                    .shadow(color: .white.opacity(0.16), radius: 14)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, max(44, proxy.safeAreaInsets.bottom + 10))
        }
        .onChange(of: isActive) { _, active in
            // 離れていた間は止まっている。もどったら、その場面を最初から
            if active { sceneStart = Date() }
        }
        .accessibilityElement(children: .contain)
    }

    private func sceneProgress(at date: Date) -> Double {
        guard autoplays else { return 0.9 }
        return min(1, max(0, date.timeIntervalSince(sceneStart) / Self.scenes[index].duration))
    }

    private func progressBars(t: Double) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<Self.scenes.count, id: \.self) { i in
                GeometryReader { bar in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: "26262A"))
                        Capsule().fill(.white)
                            .frame(width: bar.size.width * (i < index ? 1 : (i == index ? (autoplays ? t : 1) : 0)))
                    }
                }
                .frame(height: 4)
                .padding(.vertical, 10) // 押せる範囲を上下10ptずつ広げる
                .contentShape(Rectangle())
                .onTapGesture { show(i) }
                .accessibilityHidden(true)
            }
        }
    }

    private var sceneText: some View {
        let scene = Self.scenes[index]
        return VStack(alignment: .leading, spacing: 6) {
            Text(scene.title)
                .font(.system(size: 21, weight: .bold))
                .tracking(-0.035 * 21)
                .foregroundStyle(.white)
            Text(scene.body)
                .font(.system(size: 15))
                .lineSpacing(15 * 0.65 - 4)
                .foregroundStyle(OnboardingPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(textVisible ? 1 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(scene.title)。\(scene.body)")
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    /// 場面を切りかえる:説明は0.2秒で消えて、0.17秒後に入れ替わって出る
    private func show(_ next: Int) {
        guard next != index || true else { return }
        withAnimation(.easeOut(duration: 0.2)) { textVisible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) {
            index = next
            sceneStart = Date()
            withAnimation(.easeOut(duration: 0.3)) { textVisible = true }
        }
    }

    private func next() {
        onTapNext()
        if isLast { onFinish() } else { show(index + 1) }
    }
}

/// 24時間の輪(半径92pt・太さ9pt)。0:00 が真上、時計回り。角度 = 時刻/24 × 360° − 90°
struct DayRing: View {
    let scene: Int
    let t: Double

    private static let radius: CGFloat = 92
    private static let center = CGPoint(x: 118, y: 118)

    private func S(_ a: Double, _ b: Double) -> Double { min(1, max(0, (t - a) / (b - a))) }
    private func ease(_ x: Double) -> Double { 1 - pow(1 - x, 3) }

    /// 針の時刻(nil なら針なし)
    private var hand: Double? {
        switch scene {
        case 0: return nil
        case 1: return 9 * ease(S(0, 0.5))
        case 2: return 9 + 5 * S(0, 0.35)
        case 3: return 14
        case 4: return 14 + 10 * S(0, 0.55)
        default: return 9 * S(0, 0.4)
        }
    }

    /// 撮れる時間(9:00〜24:00)の明るい弧:伸びた割合と明るさ
    private var arc: (grow: Double, opacity: Double) {
        switch scene {
        case 0: return (0, 0)
        case 1: return (ease(S(0.5, 0.85)), 1)
        case 2, 3: return (1, 1)
        case 4: return (1, 1 - 0.75 * S(0.6, 0.9))
        default: return (1, 0.25 + 0.75 * S(0.4, 0.55))
        }
    }

    private static func angle(_ hour: Double) -> Angle { .degrees(hour / 24 * 360 - 90) }
    private static func point(_ hour: Double, radius: CGFloat = radius) -> CGPoint {
        let a = angle(hour).radians
        return CGPoint(x: center.x + cos(a) * radius, y: center.y + sin(a) * radius)
    }

    var body: some View {
        ZStack {
            Canvas { context, _ in
                let c = Self.center, r = Self.radius
                // 土台
                context.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: "1C1C1F")), lineWidth: 9)
                // 撮れる時間の見本(薄い弧)
                var sample = Path()
                sample.addArc(center: c, radius: r, startAngle: Self.angle(9), endAngle: Self.angle(24), clockwise: false)
                context.stroke(sample, with: .color(.white.opacity(0.13)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                // 灯った弧:9:00から先へ伸びる
                let (grow, opacity) = arc
                if grow > 0 {
                    var lit = Path()
                    lit.addArc(center: c, radius: r, startAngle: Self.angle(9), endAngle: Self.angle(9 + 15 * grow), clockwise: false)
                    context.stroke(lit, with: .color(Color(hex: "E9E9ED").opacity(opacity)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                }
                // 軌跡と針
                if let hand {
                    if hand > 0.01 {
                        var trail = Path()
                        trail.addArc(center: c, radius: r, startAngle: Self.angle(0), endAngle: Self.angle(hand), clockwise: false)
                        context.stroke(trail, with: .color(.white.opacity(0.28)), lineWidth: 2)
                    }
                    let p = Self.point(hand)
                    var glow = context
                    glow.addFilter(.blur(radius: 7))
                    glow.fill(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)), with: .color(.white.opacity(0.7)))
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 6.5, y: p.y - 6.5, width: 13, height: 13)), with: .color(.white))
                }
                // 目盛り
                for hour in [0, 6, 12, 18] {
                    let p = Self.point(Double(hour), radius: 109)
                    context.draw(Text("\(hour)").font(.system(size: 10, design: .monospaced)).foregroundStyle(Color(hex: "6B6B70")), at: p)
                }
            }
            .frame(width: 236, height: 236)

            // 時刻表示(上部)
            if let hand {
                Text(timeLabel(hand))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(0.1 * 12)
                    .foregroundStyle(Color(hex: "BCBBC0"))
                    .frame(width: 236, height: 236, alignment: .top)
                    .padding(.top, 72)
            }

            inner
        }
        .accessibilityHidden(true)
    }

    private func timeLabel(_ hand: Double) -> String {
        let h = Int(hand) % 24, m = Int((hand - Double(Int(hand))) * 60)
        let base = String(format: "%d:%02d", hand >= 24 ? 24 : h, m)
        return scene == 5 ? "翌日 \(base)" : base
    }

    // MARK: 輪の中の絵(直径 約150pt)

    @ViewBuilder
    private var inner: some View {
        switch scene {
        case 0: seats(litBy: { k in t > 0.1 + 0.1 * Double(k) }, bounce: 0, label: "4〜8人")
        case 1:
            ZStack {
                seats(litBy: { _ in t >= 0.55 }, bounce: S(0.55, 0.7), label: nil)
                let u = S(0.55, 0.95)
                Circle().stroke(.white, lineWidth: 1.5)
                    .frame(width: 70, height: 70)
                    .scaleEffect(1 + 2.4 * u)
                    .opacity(u > 0 && u < 1 ? 0.8 * (1 - u) : 0)
            }
        case 2: shoot
        case 3: yesterdayCards
        case 4: sealedFrame
        default: developAndFade
        }
    }

    /// 8つの席(半径46pt・直径15pt)。5つが灯り、残り3つは点線
    private func seats(litBy: @escaping (Int) -> Bool, bounce: Double, label: String?) -> some View {
        let scale = bounce > 0 && bounce < 1 ? 1 + 0.3 * sin(bounce * .pi) : 1
        return ZStack {
            ForEach(0..<8, id: \.self) { k in
                let a = Double(k) / 8 * 2 * .pi - .pi / 2
                Group {
                    if k < 5 {
                        let lit = litBy(k)
                        Circle().fill(.white.opacity(lit ? 1 : 0.16))
                            .shadow(color: lit ? .white.opacity(0.8) : .clear, radius: 7)
                            .scaleEffect(lit ? scale : 1)
                    } else {
                        Circle().stroke(Color(hex: "3A3A3E"), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    }
                }
                .frame(width: 15, height: 15)
                .offset(x: cos(a) * 46, y: sin(a) * 46)
            }
            if let label {
                Text(label).font(.system(size: 13, design: .monospaced)).foregroundStyle(Color(hex: "BCBBC0"))
            }
        }
    }

    /// タグのチップ → ミニ長押し(1.5秒)→ 一瞬の光
    private var shoot: some View {
        let chip = S(0.12, 0.28), fill = S(0.4, 0.85), label = S(0.3, 0.45), flash = S(0.86, 1)
        return ZStack {
            Text("#散歩")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(Capsule().fill(.white))
                .offset(y: -44 + 8 * (1 - chip))
                .opacity(chip)
            ZStack {
                Circle().stroke(.white.opacity(0.18), lineWidth: 2.5).frame(width: 58, height: 58)
                Circle().trim(from: 0, to: fill).stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90)).frame(width: 58, height: 58)
                Circle().fill(.white).frame(width: 32 - 16 * fill, height: 32 - 16 * fill)
            }
            .offset(y: 8)
            Text("1.5秒").font(.system(size: 11, design: .monospaced)).foregroundStyle(Color(hex: "BCBBC0"))
                .offset(y: 52).opacity(label)
            Circle().fill(RadialGradient(colors: [.white, .clear], center: .center, startRadius: 0, endRadius: 75))
                .frame(width: 150, height: 150)
                .scaleEffect(1 + 0.4 * flash)
                .opacity(flash > 0 ? 0.85 * (1 - flash) : 0)
        }
    }

    /// 3枚のカードが扇形に重なり、現像のように色づく
    private var yesterdayCards: some View {
        let appear = S(0, 0.3), develop = S(0.3, 0.85), label = S(0.5, 0.8)
        let gradients: [[Color]] = [
            [Color(hex: "FFB070"), Color(hex: "E0603A")],
            [Color(hex: "7FB8FF"), Color(hex: "3F5FD8")],
            [Color(hex: "FFE08A"), Color(hex: "E8A93A")],
        ]
        return ZStack {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: gradients[i], startPoint: .top, endPoint: .bottom))
                    .frame(width: 48, height: 64)
                    .blur(radius: 14 * (1 - develop))
                    .saturation(0.3 + 0.7 * develop)
                    .rotationEffect(.degrees(Double(i - 1) * 13))
                    .offset(x: CGFloat(i - 1) * 22, y: -6 + 20 * (1 - appear))
                    .opacity(appear)
            }
            Text("昨日").font(.system(size: 11, design: .monospaced)).foregroundStyle(Color(hex: "BCBBC0"))
                .offset(y: 46).opacity(label)
        }
    }

    /// 黒い枠と白い点(あなたにも、まだ見えない)
    private var sealedFrame: some View {
        let appear = S(0, 0.25), label = S(0.35, 0.55)
        return ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.black)
                .frame(width: 62, height: 82)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.28), lineWidth: 1))
                .overlay(Circle().fill(.white).frame(width: 6, height: 6).shadow(color: .white.opacity(0.8), radius: 4))
                .offset(y: -6)
                .opacity(appear)
            Text("見えない").font(.system(size: 11, design: .monospaced)).foregroundStyle(Color(hex: "BCBBC0"))
                .offset(y: 50).opacity(label)
        }
    }

    /// 翌朝に現像 → 7つの点が灯る → 消える
    private var developAndFade: some View {
        let appear = t >= 0.4 ? 1.0 : 0, develop = S(0.4, 0.6), dots = S(0.5, 0.9), fade = S(0.9, 1)
        return ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "FFB070"), Color(hex: "B06AD8"), Color(hex: "4A6CE0")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 58, height: 76)
                .blur(radius: 12 * (1 - develop) + 6 * fade)
                .opacity(appear * (1 - 0.88 * fade))
                .offset(y: -10)
            HStack(spacing: 7) {
                ForEach(0..<7, id: \.self) { k in
                    let lit = dots * 7 > Double(k)
                    Circle().fill(.white.opacity(lit ? 1 : 0.16)).frame(width: 7, height: 7)
                        .shadow(color: lit ? .white.opacity(0.7) : .clear, radius: 3)
                }
            }
            .offset(y: 44)
        }
    }
}

// MARK: - ⑥ → ようこそ → 吸い込まれて Home へ(約5秒)

/// 1つの時計 t(ミリ秒)から全部を計算する。最後に、玉の位置から円がひらいて、下の Home が見える。
struct OnboardingWelcomeView: View {
    let start: Date
    let haptics: ExposureHaptics
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var firedRamp = false
    @State private var firedBurst = false
    @State private var loggedText = false
    @State private var finished = false
    @State private var simpleFade = 1.0

    private static let lines = ["ようこそ", "Laterへ"]

    var body: some View {
        GeometryReader { proxy in
            let metrics = OnboardingMetrics(size: proxy.size)
            let orbCenter = CGPoint(x: proxy.size.width / 2, y: metrics.y(OnboardingMetrics.orbCenterY))
            TimelineView(.animation(paused: finished)) { context in
                let t = context.date.timeIntervalSince(start) * 1000
                ZStack {
                    if reduceMotion || voiceOverEnabled {
                        simple(metrics: metrics, size: proxy.size)
                            .opacity(simpleFade)
                    } else {
                        stage(t: t, metrics: metrics, size: proxy.size, orbCenter: orbCenter)
                            // 4050〜4950:玉の位置から円がひらき、下の Home が見える
                            .mask(revealMask(t: t, center: orbCenter, size: proxy.size))
                    }
                }
                .onChange(of: Int(t / 50)) { _, _ in tick(t) }
            }
        }
        .allowsHitTesting(true) // 演出中は入力を受け付けない
        .accessibilityElement()
        .accessibilityLabel("ようこそ、Laterへ")
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: "ようこそ、Laterへ")
            if reduceMotion || voiceOverEnabled {
                // 全文を1.6秒見せて、0.4秒のクロスフェードで Home へ
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation(.easeInOut(duration: 0.4)) { simpleFade = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { finish() }
                }
            }
        }
    }

    private func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
    private func easeInOutCubic(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }

    private func tick(_ t: Double) {
        guard !reduceMotion, !voiceOverEnabled else { return }
        if t >= 2400, !loggedText {
            loggedText = true
            print(String(format: "[Welcome] W5 「ようこそ」の文字が出た(t = %.2fs)", t / 1000))
        }
        if t >= 2900, !firedRamp {
            firedRamp = true
            let r = OnboardingTuning.welcomeRamp
            haptics.playRamp(from: r.from, to: r.to, sharpness: r.sharpFrom, sharpnessTo: r.sharpTo, duration: 0.8)
        }
        if t >= 3950, !firedBurst {
            firedBurst = true
            haptics.fireCapture(intensity: OnboardingTuning.finishHaptic.intensity, sharpness: OnboardingTuning.finishHaptic.sharpness, tail: OnboardingTuning.finishTail)
        }
        if t >= 5000 { finish() }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinished()
    }

    // MARK: 舞台

    private func stage(t: Double, metrics: OnboardingMetrics, size: CGSize, orbCenter: CGPoint) -> some View {
        // 0〜1000:玉が小からヒーローへ
        let move = easeInOutCubic(clamp(t / 1000))
        let small = CGPoint(x: size.width / 2, y: metrics.y(OnboardingMetrics.smallOrbCenterY))
        let center = CGPoint(x: small.x + (orbCenter.x - small.x) * move, y: small.y + (orbCenter.y - small.y) * move)
        let baseScale = OnboardingMetrics.smallOrbScale + (1 - OnboardingMetrics.smallOrbScale) * move
        // 3700〜3950 ふくらむ、3950〜4250 縮んで消える
        let swell = t < 3700 ? 1 : (t < 3950 ? 1 + 0.25 * easeInOutCubic(clamp((t - 3700) / 250)) : 1.25 * (1 - clamp((t - 3950) / 300)))
        // 2900〜3700:吸い込み(q = u³)
        let u = clamp((t - 2900) / 800)
        let q = u * u * u
        let glowStrength = 0.3 + 0.5 * q

        return ZStack {
            Color.black
            // 玉の光
            Circle()
                .fill(RadialGradient(colors: [Color(red: 1, green: 0.85 + 0.15 * q, blue: 0.7 + 0.3 * q).opacity(glowStrength), .clear], center: .center, startRadius: 0, endRadius: 130))
                .frame(width: 260, height: 260)
                .position(center)
            // 点:色づく → 渦を巻いて玉の中心へすぼむ
            dots(t: t, center: center, scale: baseScale, q: q)
            OnboardingPearl()
                .scaleEffect(baseScale * swell)
                .position(center)
            // 「ようこそ / Laterへ」
            welcomeText(t: t)
                .scaleEffect(1 - 0.94 * q, anchor: UnitPoint(x: 0.5, y: (center.y - metrics.y(396)) / 110))
                .blur(radius: 10 * q)
                .opacity(1 - clamp((t - 3300) / 400))
                .frame(width: size.width)
                .position(x: size.width / 2, y: metrics.y(396) + 55)
        }
        .frame(width: size.width, height: size.height)
    }

    private func dots(t: Double, center: CGPoint, scale: CGFloat, q: Double) -> some View {
        let colorize = clamp(t / 620)
        let opacity = (0.3 + 0.7 * colorize) * (1 - clamp((t - 3500) / 200))
        let swirl = 220.0 * q
        let radius = OnboardingOrb.dotRadius * scale * CGFloat(1 - q)
        return ZStack {
            ForEach(0..<6, id: \.self) { k in
                let angle = Angle.degrees(-90 + 60 * Double(k) + swirl).radians
                let color = HomePalette.ringColor(atFraction: Double(k) / 6)
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .shadow(color: color.opacity(0.9), radius: 6)
                    .scaleEffect(1 - q)
                    .position(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                    .opacity(opacity)
            }
        }
    }

    /// 1文字ずつ 100ms ずらし、各文字 520ms で現像(不透明度 0→1・ぼかし 12→0・下から 10pt)
    private func welcomeText(t: Double) -> some View {
        VStack(spacing: 40 * 0.3) {
            ForEach(Array(Self.lines.enumerated()), id: \.offset) { lineIndex, line in
                let offset = lineIndex == 0 ? 0 : Self.lines[0].count
                Text(line)
                    .font(.system(size: 40, weight: .bold))
                    .tracking(-0.045 * 40)
                    .foregroundStyle(.white)
                    .textRenderer(DevelopRevealRenderer(t: t - 1000, firstIndex: offset))
            }
        }
    }

    private func revealMask(t: Double, center: CGPoint, size: CGSize) -> some View {
        let p = easeInOutCubic(clamp((t - 4050) / 900))
        let radius = 1000 * p
        return Rectangle()
            .fill(.white)
            .overlay(
                Circle()
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                    .blendMode(.destinationOut)
            )
            .compositingGroup()
            .frame(width: size.width, height: size.height)
    }

    private func simple(metrics: OnboardingMetrics, size: CGSize) -> some View {
        ZStack {
            Color.black
            OnboardingOrb(litCount: 6, bloom: 1, dotCount: 6)
                .position(x: size.width / 2, y: metrics.y(OnboardingMetrics.orbCenterY))
            Text("ようこそ\nLaterへ")
                .font(.system(size: 40, weight: .bold))
                .tracking(-0.045 * 40)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .position(x: size.width / 2, y: metrics.y(396) + 55)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// 1つのテキストに、文字ごとのずらしで不透明度・ぼかし・位置をかける(文字ごとに別の View にしない)
private struct DevelopRevealRenderer: TextRenderer {
    /// 「ようこそ」が始まってからの経過(ミリ秒)
    var t: Double
    /// この行の最初の文字が、全体で何文字目か
    var firstIndex: Int

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        var index = firstIndex
        for line in layout {
            for run in line {
                for slice in run {
                    let p = min(1, max(0, (t - Double(index) * 100) / 520))
                    var copy = context
                    copy.opacity = p
                    if p < 1 { copy.addFilter(.blur(radius: 12 * (1 - p))) }
                    copy.translateBy(x: 0, y: 10 * (1 - p))
                    copy.draw(slice)
                    index += 1
                }
            }
        }
    }
}

// MARK: - ④ タグ(あなたを3つのタグで表すと)

/// 候補のチップ + 点線の「＋ 自由に追加」。選んだチップは白く反転。最大3つで、ほかは28%で押せない。
struct OnboardingTagChips: View {
    let candidates: [String]
    let selected: [String]
    let onToggle: (String) -> Void
    let onAdd: () -> Void

    private var isFull: Bool { selected.count >= OnboardingRules.maxSelfTags }

    var body: some View {
        OnboardingFlowLayout(spacing: 10) {
            ForEach(candidates, id: \.self) { tag in
                let isSelected = selected.contains(tag)
                let isLocked = !isSelected && isFull
                Button { onToggle(tag) } label: {
                    Text("#\(tag)")
                        .font(.system(size: 16, weight: .semibold))
                        .tracking(-0.02 * 16)
                        .foregroundStyle(isSelected ? Color.black : OnboardingPalette.quietText)
                        .padding(.horizontal, 17)
                        .frame(height: 42)
                        .background(Capsule().fill(isSelected ? Color.white : OnboardingPalette.surface))
                }
                .buttonStyle(PressScaleStyle(scale: 0.96))
                .disabled(isLocked)
                .opacity(isLocked ? 0.28 : 1)
                .accessibilityLabel(tag)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityValue(isLocked ? "選べません" : "")
            }
            Button(action: onAdd) {
                Text("＋ 自由に追加")
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.02 * 16)
                    .foregroundStyle(OnboardingPalette.secondaryText)
                    .padding(.horizontal, 17)
                    .frame(height: 42)
                    .overlay(Capsule().strokeBorder(Color(hex: "3A3A3E"), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
            }
            .buttonStyle(PressScaleStyle(scale: 0.96))
            .disabled(isFull)
            .opacity(isFull ? 0.28 : 1)
            .accessibilityValue(isFull ? "選べません" : "")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.2), value: selected)
    }
}

/// 「最大3つまで」と「2 / 3」
struct OnboardingTagCount: View {
    let count: Int

    var body: some View {
        HStack {
            Text("最大\(OnboardingRules.maxSelfTags)つまで")
                .font(.system(size: 12))
                .foregroundStyle(OnboardingPalette.note)
            Spacer()
            Text("\(count) / \(OnboardingRules.maxSelfTags)")
                .font(.system(size: 12, design: .monospaced))
                .tracking(0.1 * 12)
                .foregroundStyle(OnboardingPalette.subText)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("タグ \(count)個、最大\(OnboardingRules.maxSelfTags)個")
    }
}

/// 「＋ 自由に追加」の入力欄(②のニックネームと同じ作り。左に「#」を固定)
struct OnboardingTagInputField: View {
    @Binding var text: String
    var focus: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            HStack(spacing: 2) {
                Text("#")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(OnboardingPalette.secondaryText)
                    .accessibilityHidden(true)
                TextField("", text: $text, prompt: Text("タグ").foregroundStyle(Color(hex: "3A3A3E")))
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.04 * 34)
                    .foregroundStyle(.white)
                    .tint(.white)
                    .focused(focus)
                    .submitLabel(.done)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(onSubmit)
                    .onChange(of: text) { _, value in
                        let cleaned = Self.clean(value)
                        if cleaned != value { text = cleaned }
                    }
                    .accessibilityLabel("タグ、入力欄")
            }
            .frame(height: 64)
            Rectangle().fill(.white.opacity(0.35)).frame(height: 1.5)
            Text("\(text.count) / \(OnboardingRules.tagMaxLength)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(OnboardingPalette.note)
                .monospacedDigit()
                .padding(.top, 15)
        }
    }

    /// 「#」と空白を取り除き、12文字までにする
    static func clean(_ value: String) -> String {
        let removed = value.filter { $0 != "#" && $0 != "＃" && !$0.isWhitespace }
        return String(removed.prefix(OnboardingRules.tagMaxLength))
    }
}
