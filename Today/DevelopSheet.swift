import SwiftUI

/// 現像シート(現像カードをタップ)。主役は写真:チェキを大きく(窓 240×320pt)、数字と説明は
/// チェキの白い部分と、下の細い時間の線に置く。写真の中身はぼかしたまま(色と濃さだけ)。
/// 撮った時刻からいままでの現像を早送りで見せ、プリントを押し続けると写真の鼓動が伝わる。
struct DevelopSheet: View {
    let capturedAt: Date
    /// dawn(現像ずみ・昨日の1枚)
    let isDeveloped: Bool
    let now: Date
    let texture: UIImage?
    var tones: [Color] = DevelopProgress.defaultTones
    let haptics: ExposureHaptics
    /// falseなら登場と早送りをせず、いまの濃さで止まった状態から始める
    var playsEntrance = true
    /// チェキの後ろに、写真の色をぼんやり映すか(気になる場合はここで消せる)
    var showsColorGlow = true

    enum Timing {
        static let printEntrance: TimeInterval = 0.8
        static let fastForwardDelay: TimeInterval = 0.7
        static let fastForward: TimeInterval = 3.6
    }

    enum Layout {
        static let block = CGSize(width: 322, height: 486)
        static let dotFrame = CGSize(width: 304, height: 470)
        static let print = CGSize(width: 266, height: 430)
        static let printOrigin = CGPoint(x: 29, y: 27)
        static let window = CGSize(width: 240, height: 320)
        static let windowOrigin = CGPoint(x: 13, y: 14)
        /// 見出し〜ヒント(縮めない部分)
        static let lowerHeight: CGFloat = 250
        static let lineWidth: CGFloat = 276
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPrintShown = false
    @State private var playStart: Date?
    @State private var isPlaying = false
    @State private var isHolding = false
    @State private var beatTask: Task<Void, Never>?
    @State private var beatScale: CGFloat = 1
    @State private var tilt = GlassTilt()

    private var span: TimeInterval {
        DevelopProgress.finishDate(capturedAt: capturedAt).timeIntervalSince(capturedAt)
    }

    /// いまの経過割合(撮影 → 次の9:00)
    private var targetFraction: Double {
        isDeveloped ? 1 : DevelopDensity.fraction(capturedAt: capturedAt, now: now)
    }

    var body: some View {
        GeometryReader { proxy in
            // 小さい機種:チェキの全体を縮める(下の部分は縮めない)
            let available = proxy.size.height - 12 - 17 - 18 - Layout.lowerHeight
            let scale = min(1, max(0.5, available / Layout.block.height))
            TimelineView(.animation(paused: !isPlaying)) { context in
                let fraction = targetFraction * playbackProgress(at: context.date)
                content(fraction: fraction, scale: scale)
            }
        }
        .onAppear(perform: start)
        .onDisappear {
            stopBeat()
            tilt.stop()
        }
    }

    // MARK: - 再生

    /// 0 → 1(e = 1 − (1 − u)^2.2)
    private func playbackProgress(at date: Date) -> Double {
        guard let playStart else { return reduceMotion || !playsEntrance ? 1 : 0 }
        guard isPlaying else { return 1 }
        let u = min(1, max(0, date.timeIntervalSince(playStart) / Timing.fastForward))
        return 1 - pow(1 - u, 2.2)
    }

    private func start() {
        if !reduceMotion { tilt.start() }
        guard playsEntrance else {
            isPrintShown = true
            return
        }
        // 「視差効果を減らす」:落ちてくる動きと早送りをやめ、1秒のクロスフェードだけ
        withAnimation(reduceMotion ? .easeInOut(duration: 1) : .timingCurve(0.2, 0.8, 0.2, 1, duration: Timing.printEntrance)) {
            isPrintShown = true
        }
        replay(after: reduceMotion ? 0 : Timing.fastForwardDelay)
    }

    private func replay(after delay: TimeInterval = 0) {
        playStart = nil
        isPlaying = false
        guard !reduceMotion else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let start = Date()
            playStart = start
            isPlaying = true
            // さらさら(弱 → 少し強く)→ 終わりにトン(弱)
            haptics.playDevelopRustle(duration: Timing.fastForward, peak: Float(0.15 + 0.3 * DevelopDensity.density(targetFraction)))
            DispatchQueue.main.asyncAfter(deadline: .now() + Timing.fastForward + 0.05) {
                if playStart == start { isPlaying = false }
            }
        }
    }

    // MARK: - 中身

    private func content(fraction: Double, scale: CGFloat) -> some View {
        let d = DevelopDensity.density(fraction)
        let shownNow = capturedAt.addingTimeInterval(fraction * span)
        let developedNow = isDeveloped && fraction >= 1
        let lit = developedNow ? DevelopDensity.dotCount : DevelopDensity.litDots(capturedAt: capturedAt, now: shownNow)
        return VStack(spacing: 0) {
            Capsule().fill(.white.opacity(0.2)).frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 12)

            Text(isDeveloped ? "昨日の1枚" : "今日の1枚")
                .font(.system(size: 10.5, design: .monospaced))
                .tracking(0.2 * 10.5)
                .foregroundStyle(Color(hex: "8E8E93"))

            printBlock(density: d, lit: lit, developed: developedNow, shownNow: shownNow)
                .scaleEffect(scale)
                .frame(width: Layout.block.width * scale, height: Layout.block.height * scale)
                .padding(.top, 4)

            VStack(spacing: 6) {
                Text(isDeveloped ? "今日を撮ると、ひらきます" : "9:00 に、仕上がります")
                    .font(.system(size: 17, weight: .bold))
                    .tracking(-0.03 * 17)
                    .foregroundStyle(.white)
                Text("色だけが、濃くなっていきます。まだ見られません")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            timeLine(fraction: developedNow ? 1 : fraction, shownNow: shownNow, developed: developedNow)
                .padding(.top, 14)

            Button { replay() } label: {
                Text("もういちど、現像を見る")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(.white.opacity(0.1)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .opacity(reduceMotion ? 0 : 1)

            Text("押し続けると、写真の鼓動が伝わる")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(hex: "6B6B70"))
                .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 点の輪 + チェキ(322×486)

    private func printBlock(density d: Double, lit: Int, developed: Bool, shownNow: Date) -> some View {
        let tiltActive = !reduceMotion && !isHolding
        let tx = tiltActive ? tilt.x : 0
        let ty = tiltActive ? tilt.y : 0
        return ZStack(alignment: .topLeading) {
            // チェキの後ろに、写真の色がぼんやり映る(濃さは現像の濃さにそろえる)
            if showsColorGlow {
                Ellipse()
                    .fill(RadialGradient(colors: glowColors, center: .center, startRadius: 0, endRadius: 260))
                    .frame(width: 440, height: 540)
                    .blur(radius: 54)
                    .opacity(0.3 * d)
                    .offset(x: (Layout.block.width - 440) / 2, y: (Layout.block.height - 540) / 2)
                    .allowsHitTesting(false)
            }

            SealDotFrame(lit: lit, isDeveloped: developed, isAnimating: !reduceMotion)
                .frame(width: Layout.dotFrame.width, height: Layout.dotFrame.height)
                .offset(x: (Layout.block.width - Layout.dotFrame.width) / 2, y: (Layout.block.height - Layout.dotFrame.height) / 2)

            chekiPrint(density: d, developed: developed, shownNow: shownNow, glossAngle: 135 + 50 * tx)
                .frame(width: Layout.print.width, height: Layout.print.height)
                .rotationEffect(.degrees(-2.2), anchor: .bottom)
                .scaleEffect(beatScale, anchor: .center)
                .offset(x: Layout.printOrigin.x, y: Layout.printOrigin.y)
                .offset(y: isPrintShown || reduceMotion ? 0 : -70)
                .opacity(isPrintShown ? 1 : 0)
        }
        .frame(width: Layout.block.width, height: Layout.block.height, alignment: .topLeading)
        // 傾き(パララックス):左右 ±6度・上下 ±5度。長押しの鼓動のあいだは止める
        .rotation3DEffect(.degrees(6 * tx), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .rotation3DEffect(.degrees(-5 * ty), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
        .animation(.easeOut(duration: 0.2), value: isHolding)
    }

    private var glowColors: [Color] {
        let c = tones.count >= 3 ? Array(tones.prefix(3)) : DevelopProgress.defaultTones
        return [c[0], c[1].opacity(0.7), .clear]
    }

    private func chekiPrint(density d: Double, developed: Bool, shownNow: Date, glossAngle: Double) -> some View {
        let paper = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return ZStack(alignment: .topLeading) {
            paper.fill(LinearGradient(colors: [Color(hex: "F7F4EE"), Color(hex: "ECE8DF")], startPoint: .top, endPoint: .bottom))

            ChekiDevelopImage(texture: texture, tones: tones, density: d, isSheet: true, isAnimating: !reduceMotion)
                .frame(width: Layout.window.width, height: Layout.window.height)
                .overlay(gloss(angle: glossAngle))
                .clipped()
                .offset(x: Layout.windowOrigin.x, y: Layout.windowOrigin.y)

            caption(developed: developed, shownNow: shownNow)
                .padding(.horizontal, 17)
                .padding(.bottom, 13)
                .frame(width: Layout.print.width, height: Layout.print.height, alignment: .bottom)
        }
        .clipShape(paper)
        .shadow(color: .black.opacity(0.65), radius: 22, y: 22)
        .shadow(color: HomePalette.orange.opacity(0.14), radius: 28)
        .contentShape(paper)
        .gesture(heartbeatGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// つや(角度は傾きで 135度 ± 50度)
    private func gloss(angle: Double) -> some View {
        let r = angle * .pi / 180
        let dx = cos(r) * 0.5, dy = sin(r) * 0.5
        return LinearGradient(
            stops: [.init(color: .white.opacity(0), location: 0.3), .init(color: .white.opacity(0.16), location: 0.5), .init(color: .white.opacity(0), location: 0.7)],
            startPoint: UnitPoint(x: 0.5 - dx, y: 0.5 - dy),
            endPoint: UnitPoint(x: 0.5 + dx, y: 0.5 + dy)
        )
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    /// チェキの下の白い部分:残り時間 + きょう / 日付 ・ 9:00 まで
    private func caption(developed: Bool, shownNow: Date) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .lastTextBaseline) {
                if developed {
                    Text("READY")
                        .font(.system(size: 27, design: .monospaced))
                        .tracking(0.06 * 27)
                        .foregroundStyle(Color(hex: "C8742F"))
                } else {
                    Text(DevelopDensity.remainingText(capturedAt: capturedAt, now: shownNow))
                        .font(.system(size: 36, weight: .light, design: .monospaced))
                        .tracking(-0.07 * 36)
                        .monospacedDigit()
                        .foregroundStyle(Color(hex: "4B473F"))
                }
                Spacer(minLength: 0)
                Text(isDeveloped ? "きのう" : "きょう")
                    .font(.system(size: 15).italic())
                    .foregroundStyle(Color(hex: "8A867B"))
            }
            Text("\(Self.filmDate(capturedAt)) ・ \(developed ? "現像ずみ" : "9:00 まで")")
                .font(.system(size: 9, design: .monospaced))
                .tracking(0.14 * 9)
                .foregroundStyle(Color(hex: "A09C91"))
        }
    }

    // MARK: - 時間の線(幅276・高さ44)

    private func timeLine(fraction: Double, shownNow: Date, developed: Bool) -> some View {
        let w = Layout.lineWidth
        let f = CGFloat(min(1, max(0, fraction)))
        let x = w * f
        // 点の上の時刻は、左右の端から 64pt 内側までで止める
        let labelX = min(max(x, 64), w - 64)
        return ZStack(alignment: .topLeading) {
            if !developed {
                Text(isPlaying ? Self.clock(shownNow) : "NOW  \(Self.clock(shownNow))")
                    .font(.system(size: 9.5, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(HomePalette.orange)
                    .fixedSize()
                    .position(x: labelX, y: 6)
            }
            Capsule().fill(.white.opacity(0.14)).frame(width: w, height: 2).offset(y: 19)
            Capsule()
                .fill(LinearGradient(colors: [HomePalette.orange.opacity(0.25), HomePalette.orange], startPoint: .leading, endPoint: .trailing))
                .frame(width: max(2, x), height: 2)
                .offset(y: 19)
            Circle()
                .fill(HomePalette.orange)
                .frame(width: 10, height: 10)
                .shadow(color: HomePalette.orange.opacity(0.9), radius: 5)
                .position(x: x, y: 20)
            if !developed {
                HStack {
                    Text("\(Self.clock(capturedAt)) に預けた")
                    Spacer()
                    Text("9:00 仕上がり")
                }
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color(hex: "6B6B70"))
                .frame(width: w)
                .offset(y: 31)
            }
        }
        .frame(width: w, height: 44, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    // MARK: - 鼓動(変更なし)

    private var heartbeatGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isHolding else { return }
                isHolding = true
                startBeat()
            }
            .onEnded { _ in stopBeat() }
    }

    /// 間隔は 1500ms − 900ms × (経過時間/24時間)。dawn は 560ms 固定。
    private var beatInterval: TimeInterval {
        if isDeveloped { return 0.56 }
        let elapsed = min(1, max(0, now.timeIntervalSince(capturedAt) / (24 * 3600)))
        return 1.5 - 0.9 * elapsed
    }

    private func startBeat() {
        beatTask?.cancel()
        beatTask = Task { @MainActor in
            while !Task.isCancelled {
                haptics.playHeartbeat()
                if !reduceMotion {
                    withAnimation(.easeOut(duration: 0.12)) { beatScale = 1.03 }
                    withAnimation(.easeInOut(duration: 0.35).delay(0.12)) { beatScale = 1 }
                }
                try? await Task.sleep(for: .seconds(beatInterval))
            }
        }
    }

    private func stopBeat() {
        isHolding = false
        beatTask?.cancel()
        beatTask = nil
        withAnimation(.easeOut(duration: 0.2)) { beatScale = 1 }
    }

    // MARK: - 表記・読み上げ

    private var accessibilityText: String {
        if isDeveloped { return "昨日の1枚、現像ずみ。今日を撮ると、ひらきます" }
        let minutes = max(0, Int(DevelopProgress.finishDate(capturedAt: capturedAt).timeIntervalSince(now) / 60))
        return "今日の1枚、あと\(minutes / 60)時間\(minutes % 60)分で仕上がります"
    }

    private static func clock(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private static func filmDate(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "'%02d %02d %02d", (c.year ?? 0) % 100, c.month ?? 0, c.day ?? 0)
    }
}

/// 点の輪:角丸四角(304×470・角丸30)の線にそって、24個の点(上の中央から時計まわり)。
/// 点灯:オレンジ(READY は #ffd2ae)・半径3pt・先頭ほど濃い(.3 → .85)。先頭は 4.4pt でぼんやり光り、2.2秒周期でふくらむ。
/// 消灯:白・半径1.8pt・透明度 .2
struct SealDotFrame: View {
    let lit: Int
    let isDeveloped: Bool
    let isAnimating: Bool

    var body: some View {
        TimelineView(.animation(paused: !isAnimating)) { context in
            let pulse = isAnimating ? DevelopDots.pulse(context.date.timeIntervalSinceReferenceDate) : 0
            Canvas { ctx, size in
                let rect = CGRect(origin: .zero, size: size)
                let path = Self.framePath(in: rect, radius: 30)
                let n = DevelopDensity.dotCount
                for i in 0..<n {
                    let f = CGFloat(i) / CGFloat(n)
                    let p = i == 0 ? CGPoint(x: rect.midX, y: rect.minY) : (path.trimmedPath(from: 0, to: f).currentPoint ?? .zero)
                    let (radius, color, glow) = style(index: i, pulse: pulse)
                    if glow {
                        var g = ctx
                        g.addFilter(.blur(radius: radius * 1.4))
                        g.fill(Path(ellipseIn: CGRect(x: p.x - radius * 1.9, y: p.y - radius * 1.9, width: radius * 3.8, height: radius * 3.8)), with: .color(color.opacity(0.6)))
                    }
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func style(index i: Int, pulse: Double) -> (CGFloat, Color, Bool) {
        if isDeveloped { return (3, Color(hex: "FFD2AE"), true) }
        guard i < lit else { return (1.8, .white.opacity(0.2), false) }
        if i == lit - 1 { return (4.4 * (1 + 0.15 * pulse), HomePalette.orange, true) }
        let age = lit <= 1 ? 1 : Double(i) / Double(lit - 1)
        return (3, HomePalette.orange.opacity(0.3 + 0.55 * age), false)
    }

    /// 上の中央から時計まわりの角丸長方形
    static func framePath(in r: CGRect, radius: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - radius, y: r.minY))
        p.addArc(center: CGPoint(x: r.maxX - radius, y: r.minY + radius), radius: radius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - radius))
        p.addArc(center: CGPoint(x: r.maxX - radius, y: r.maxY - radius), radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX + radius, y: r.maxY))
        p.addArc(center: CGPoint(x: r.minX + radius, y: r.maxY - radius), radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + radius))
        p.addArc(center: CGPoint(x: r.minX + radius, y: r.minY + radius), radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}
