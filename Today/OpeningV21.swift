import SwiftUI

// v21 E:オープニング「パシャ → チェキ → 現像 → 日の出」(見本:Docs/Mocks/later_v21.html の オープニング)。
// Later の物語を そのまま 3秒で:撮る(パシャ)→ チェキがでてくる → ミルク色から現像される → その窓が丸くふくらんで Home の下のボタンになる。
// 時間は1本(TimelineView)。窓 → 円 は、1つの形(角丸の四角 → 円)の補間で描く。にじみは放射状グラデーション。音は出さない。
// ゼロから起動した時だけ。タップでとばせる。はじめては フル(約 3.4秒)、2回目からは 短縮版(約 1.7秒)。設定で オン / 短く / オフ。
// 視差を減らす:橙の点 → 白 → Home を 0.4秒のフェードだけ(click 1つ)。

enum OpeningMode: String, CaseIterable, Identifiable {
    case on, short, off
    var id: String { rawValue }
    var title: String {
        switch self {
        case .on: return "オン"
        case .short: return "短く"
        case .off: return "オフ"
        }
    }
}

enum OpeningSettings {
    private static let modeKey = "opening.mode"
    private static let seenKey = "opening.fullSeen"

    static var mode: OpeningMode {
        get { UserDefaults.standard.string(forKey: modeKey).flatMap(OpeningMode.init(rawValue:)) ?? .on }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: modeKey) }
    }

    /// 今回の起動で流すもの(nil = 流さない)
    static func variant(reduceMotion: Bool) -> OpeningVariant? {
        switch mode {
        case .off: return nil
        case _ where reduceMotion: return .fade
        case .short: return .short
        case .on:
            if UserDefaults.standard.bool(forKey: seenKey) { return .short }
            UserDefaults.standard.set(true, forKey: seenKey)
            return .full
        }
    }
}

enum OpeningVariant: Equatable {
    case full, short, fade

    var duration: Double {
        switch self {
        case .full: return 3.7
        case .short: return 1.9
        case .fade: return 0.4
        }
    }
}

/// 時刻表(秒)。短縮版は、点 → パシャ → (もう現像ずみの)チェキ → 日の出
struct OpeningTimeline: Equatable {
    let variant: OpeningVariant

    var k: Double { variant == .short ? 0.5 : 1 }
    var dot: Double { 0.09 * k }
    var focus: Double { 0.76 * k }
    var flash: Double { 1.0 * k }
    var chekiIn: Double { 1.2 * k }
    var tape: Double { 1.8 * k }
    var develop: Double { 1.85 * k }
    var developDuration: Double { 1.0 * k }
    var letters: Double { 2.25 * k }
    var morph: Double { 2.67 * k }
    var morphDuration: Double { 0.78 * k }
    var end: Double { variant.duration }
}

struct OpeningV21View: View {
    let variant: OpeningVariant
    let start: Date
    let onFinish: () -> Void

    @State private var finished = false
    @State private var skippedAt: Double?
    @State private var ramp = HapticRamp()

    private var tl: OpeningTimeline { OpeningTimeline(variant: variant) }

    var body: some View {
        GeometryReader { proxy in
            let size = CGSize(width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
                              height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom)
            TimelineView(.animation) { context in
                #if DEBUG
                let t = OpeningDebug.frozenT ?? context.date.timeIntervalSince(start)
                #else
                let t = context.date.timeIntervalSince(start)
                #endif
                frame(t: t, size: size)
                    .onChange(of: t >= tl.end) { _, done in if done { finish() } }
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { skip() }
        .onAppear(perform: scheduleHaptics)
        .onDisappear { ramp.stop() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lattag。タップで とばす")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: 1コマ(モック v64 の `openAnims` / `playOpen`。時間は モックの 秒を そのまま。短縮版は 全体を 半分の 長さに)

    private var k: Double { variant == .short ? 0.5 : 1 }
    /// モックの `s`秒 から `d`秒かけて 0→1(`t` は 実時間)
    private func prog(_ t: Double, _ s: Double, _ d: Double) -> Double {
        min(1, max(0, (t - s * k) / (d * k)))
    }

    @ViewBuilder
    private func frame(t: Double, size: CGSize) -> some View {
        if variant == .fade {
            // 視差を減らす:ファインダーの点 → 白 → Home(0.4秒)
            ZStack {
                Color(hex: "07070A").opacity(max(0, 1 - t / 0.15))
                Color.white.opacity(t < 0.15 ? t / 0.15 : max(0, 1 - (t - 0.2) / 0.2))
                Circle().fill(Color(hex: "24A73E")).frame(width: 12, height: 12).opacity(max(0, 1 - t / 0.15))
            }
        } else {
            let paper = t >= tl.flash
            let endFade = max(0, min(1, (t - (tl.end - 0.26)) / 0.26))
            ZStack {
                // 0〜1.0:まっ黒(Launch Screen と同じ)→ 1.0 で 緑の紙へ
                Color(hex: "07070A").opacity(paper ? 0 : 1)
                if paper { OpeningPage(size: size) }
                if !paper { finder(t: t, size: size) }
                if paper { cheki(t: t, size: size) }
                // パシャ:まっ白に フラッシュ
                Color.white.opacity(flashOpacity(t))
            }
            .opacity(1 - endFade)
        }
    }

    private func flashOpacity(_ t: Double) -> Double {
        let s = tl.flash - 0.015 * k, d = 0.43 * k
        let p = (t - s) / d
        guard p > 0, p < 1 else { return 0 }
        if p < 0.12 { return p / 0.12 }
        if p < 0.4 { return 1 }
        return 1 - (p - 0.4) / 0.6
    }

    /// 緑の点(12pt)と、四すみの かぎかっこ(28pt・2.5pt)・下に「LATTAG ・ 11.06」
    private func finder(t: Double, size: CGSize) -> some View {
        let yOff = (size.height - 844) / 2
        // `.odot`:0.09s から 1.0s。scale 0→1(22%)→ 保つ(90%)→ 1.6 で 消える
        let dp = prog(t, 0.09, 1.0)
        let dotScale: Double = dp < 0.22 ? OpeningEase.bezier(0, 0, 0.58, 1, dp / 0.22) : (dp < 0.9 ? 1 : 1 + 0.6 * OpeningEase.bezier(0, 0, 0.58, 1, (dp - 0.9) / 0.1))
        let dotOpacity: Double = dp < 0.22 ? dp / 0.22 : (dp < 0.9 ? 1 : 1 - (dp - 0.9) / 0.1)
        // `.obr i`:0.24s から 0.56s。外から ±150 / ±200 動いて 9 行きすぎ → 0
        let bp = prog(t, 0.24, 0.56)
        let be = OpeningEase.bezier(0.5, 0, 0.3, 1, bp)
        let travel: (Double, Double) -> Double = { amp, be in be < 0.78 ? amp * (1 - be / 0.78) - 9 * (be / 0.78) : -9 * (1 - (be - 0.78) / 0.22) }
        let bo = bp < 0.3 ? bp / 0.3 : 1
        return ZStack {
            Circle().fill(Color(hex: "24A73E")).frame(width: 12, height: 12)
                .shadow(color: Color(hex: "24A73E").opacity(0.75), radius: 11)
                .scaleEffect(dotScale).opacity(dotOpacity)
                .position(x: size.width / 2, y: 368 + yOff)
            ForEach(0..<4, id: \.self) { i in
                let sx: CGFloat = i % 2 == 0 ? -1 : 1, sy: CGFloat = i < 2 ? -1 : 1
                let home = CGPoint(x: sx < 0 ? 62 + 14 : size.width - 62 - 14, y: (sy < 0 ? 190 : 518) + 14 + yOff)
                OpeningBracket(corner: i)
                    .stroke(.white.opacity(0.92), style: StrokeStyle(lineWidth: 2.5, lineCap: .butt))
                    .frame(width: 28, height: 28)
                    .position(x: home.x + sx * travel(150, be), y: home.y + sy * travel(200, be))
                    .opacity(bo)
            }
            Text("\(Brand.caps) ・ \(OpeningStyle.shortDate(Date()))")
                .font(LF.mono(10, bold: false)).tracking(0.32 * 10)
                .foregroundStyle(.white.opacity(0.55))
                .position(x: size.width / 2, y: 566 + 7 + yOff)
                .opacity(prog(t, 0.7, 0.32))
        }
    }

    /// チェキ(264×356)が 下から にゅっ → テープ → 窓に 空が のぼる → 「Lattag」が 1文字ずつ → 窓が 丸く ふくらんで 下の月へ
    private func cheki(t: Double, size: CGSize) -> some View {
        let w: CGFloat = 264, h: CGFloat = 356
        let yOff = (size.height - 844) / 2
        let origin = CGPoint(x: (size.width - w) / 2, y: 190 + yOff)
        // `.och`:1.2s から 0.78秒。cubic-bezier(.3,.9,.3,1) のあと 74% で -16 → 0
        let ip = OpeningEase.bezier(0.3, 0.9, 0.3, 1, prog(t, 1.2, 0.78))
        let rise: CGFloat = ip < 0.74 ? 780 - (780 + 16) * CGFloat(ip / 0.74) : -16 * CGFloat(1 - (ip - 0.74) / 0.26)
        let tiltIn: Double = ip < 0.74 ? -9 + 7 * (ip / 0.74) : -2 - (ip - 0.74) / 0.26
        // `.ofr`:2.33s から 0.32秒 -3° → 0°
        let tilt = tiltIn + 3 * OpeningEase.bezier(0.42, 0, 0.58, 1, prog(t, 2.33, 0.32))
        // 窓 → 円(2.67s〜 0.78秒)
        let m = OpeningEase.bezier(0.65, 0, 0.25, 1, prog(t, 2.67, 0.78))
        let groupOpacity = 1 - OpeningEase.bezier(0, 0, 0.58, 1, prog(t, 2.67, 0.3))
        let sky = OpeningEase.bezier(0.3, 0.6, 0.2, 1, prog(t, 1.85, 1.05))
        let milk = 1 - OpeningEase.bezier(0.42, 0, 0.58, 1, prog(t, 1.9, 1.15))
        let window = CGRect(x: origin.x + 17, y: origin.y + 17, width: 230, height: 270)
        let moonD = MoonLayout.diameter(screenWidth: size.width)
        let moonC = MoonLayout.center(in: size)
        let target = CGRect(x: moonC.x - moonD / 2, y: moonC.y - moonD / 2, width: moonD, height: moonD)
        let rect = OpeningEase.lerp(window, target, m)
        let radius = 5 + (moonD / 2 - 5) * m
        return ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                // 白い ふち(チェキ本体)
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(Color(red: 70 / 255, green: 35 / 255, blue: 20 / 255).opacity(0.45))
                        .frame(width: w - 36, height: h - 36).blur(radius: 30).offset(y: 36)
                    RoundedRectangle(cornerRadius: 6).fill(.white)
                    RoundedRectangle(cornerRadius: 6).strokeBorder(.black.opacity(0.05), lineWidth: 1)
                }
                .frame(width: w, height: h)
                // 窓(うすい ベージュ → 空が のぼる → ミルクが ひく)
                ZStack {
                    Color(hex: "F1EDE6")
                    OpeningSky()
                        .offset(y: 270 * CGFloat(1 - sky))
                        .blur(radius: 10 * (1 - sky))
                    Color(hex: "F4F0E9").opacity(milk)
                }
                .frame(width: 230, height: 270)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .offset(x: 17, y: 17)
                .opacity(m > 0 ? 0 : 1)
                // 「Lattag」(Black 44pt・-0.065em)が 1文字ずつ
                HStack(spacing: 0) {
                    ForEach(Array(Brand.name.enumerated()), id: \.offset) { i, ch in
                        let p = OpeningEase.bezier(0.2, 0.8, 0.2, 1, prog(t, 2.25 + Double(i) * 0.07, 0.42))
                        Text(String(ch)).font(LF.inter(900, 44)).tracking(-0.065 * 44)
                            .foregroundStyle(Color(hex: "111111"))
                            .opacity(p).offset(y: 12 * (1 - p)).blur(radius: 7 * (1 - p))
                    }
                }
                .fixedSize()
                .offset(x: 19, y: h - 13 - 44)
                Text(OpeningStyle.shortDate(Date(), apostrophe: true)).font(LF.mono(12.5)).tracking(0.08 * 12.5)
                    .foregroundStyle(Color(hex: "24A73E"))
                    .opacity(prog(t, 2.7, 0.3))
                    .fixedSize()
                    .frame(width: w - 18, height: 19, alignment: .trailing)
                    .offset(y: h - 19 - 19)
                // マスキングテープ(1.8s から 0.26秒)
                V17Tape(width: 80, height: 25, stripe: 5)
                    .opacity(0.94 * prog(t, 1.8, 0.26))
                    .rotationEffect(.degrees(-3))
                    .offset(x: (w - 80) / 2, y: -12 - 14 * CGFloat(1 - prog(t, 1.8, 0.26)))
            }
            .frame(width: w, height: h, alignment: .topLeading)
            .rotationEffect(.degrees(tilt))
            .offset(x: origin.x, y: origin.y + rise)
            .opacity(groupOpacity)
            // 2.67s〜:窓が そのまま 丸く ふくらんで 月に
            if m > 0 {
                ZStack {
                    OpeningSky()
                    OpeningMoonFill().opacity(OpeningEase.bezier(0.42, 0, 1, 1, prog(t, 2.75, 0.7)))
                }
                .frame(width: rect.width, height: rect.height)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .position(x: rect.midX, y: rect.midY)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    // MARK: バイブ・おわり

    private func scheduleHaptics() {
        func at(_ s: Double, _ work: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + s) { if !finished { work() } }
        }
        if variant == .fade { Haptics.play(.click); return }
        at(0.18 * tl.k) { Haptics.play(.pop) }
        at(tl.focus) { Haptics.play(.click) }
        at(tl.flash) { Haptics.play(.shutter) }
        at(tl.chekiIn + 0.03) { Haptics.play(.soft) }
        at(1.9 * tl.k) { Haptics.play(.land) }
        do {
            // 現像:じわっと強く(0.12 → 0.82)
            at(tl.develop) {
                ramp.start()
                Task { @MainActor in
                    let begin = Date()
                    while !finished {
                        let k = min(1, Date().timeIntervalSince(begin) / tl.developDuration)
                        ramp.update(0.12 + 0.7 * k * k)
                        if k >= 1 { break }
                        try? await Task.sleep(for: .milliseconds(30))
                    }
                    ramp.stop()
                }
            }
            for i in 0..<5 { at(tl.letters + (0.03 + Double(i) * 0.07) * tl.k) { Haptics.play(.tick, gap: 0) } }
        }
        at(tl.morph) { ramp.stop(); Haptics.play(.heart) }
        at(tl.end - 0.24) { Haptics.play(.land) }
    }

    private func skip() {
        guard !finished else { return }
        Haptics.play(.tick)
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        ramp.stop()
        onFinish()
    }
}

/// かぎかっこ(0 左上・1 右上・2 左下・3 右下)
private struct OpeningBracket: Shape {
    let corner: Int
    func path(in r: CGRect) -> Path {
        var p = Path()
        switch corner {
        case 0: p.move(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        case 1: p.move(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        case 2: p.move(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        default: p.move(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        }
        return p
    }
}

enum OpeningStyle {
    /// モックの `p2`:「11.06」(出だしの 点つき「'26 11 06」)
    static func shortDate(_ d: Date, apostrophe: Bool = false) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        let yy = (c.year ?? 2026) % 100
        return apostrophe ? String(format: "'%02d %02d %02d", yy, c.month ?? 1, c.day ?? 1) : String(format: "%02d.%02d", c.month ?? 1, c.day ?? 1)
    }
}

/// 緑の紙(`.opg`):#C3F1CC に 右上の 緑と 左の ラベンダーの にじみ
struct OpeningPage: View {
    let size: CGSize
    var body: some View {
        ZStack {
            Color(hex: "C3F1CC")
            glow(Color(red: 120 / 255, green: 226 / 255, blue: 141 / 255).opacity(0.30), cx: 0.92, cy: 0.08)
            glow(Color(red: 190 / 255, green: 160 / 255, blue: 255 / 255).opacity(0.24), cx: 0, cy: 0.72)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    /// `radial-gradient(60% 38% at cx cy, color, transparent 70%)`
    private func glow(_ c: Color, cx: CGFloat, cy: CGFloat) -> some View {
        EllipticalGradient(stops: [.init(color: c, location: 0), .init(color: c.opacity(0), location: 0.7)], center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
            .frame(width: size.width * 1.2, height: size.height * 0.76)
            .position(x: size.width * cx, y: size.height * cy)
    }
}

/// 窓の 空(`.osk`):下から 白い 光、上から 緑 → ピンク → 青むらさき
struct OpeningSky: View {
    var body: some View {
        GeometryReader { g in
            ZStack {
                LinearGradient(stops: [
                    .init(color: Color(hex: "C3F1CC"), location: 0), .init(color: Color(hex: "A3EBB1"), location: 0.30),
                    .init(color: Color(hex: "87E59A"), location: 0.58), .init(color: Color(hex: "E39CF2"), location: 0.82),
                    .init(color: Color(hex: "A99BFF"), location: 1)], startPoint: .top, endPoint: .bottom)
                EllipticalGradient(stops: [.init(color: .white.opacity(0.92), location: 0), .init(color: .white.opacity(0), location: 0.72)],
                                   center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
                    .frame(width: g.size.width * 1.5, height: g.size.height * 0.92)
                    .position(x: g.size.width / 2, y: g.size.height)
            }
        }
    }
}

/// 月に なる 円の 中(`.omorph .mB`):上の まん中から 白 → 緑 → ピンク → 青むらさき
struct OpeningMoonFill: View {
    var body: some View {
        GeometryReader { g in
            RadialGradient(stops: [
                .init(color: .white, location: 0), .init(color: Color(hex: "C3F1CC"), location: 0.09),
                .init(color: Color(hex: "98E8A8"), location: 0.26), .init(color: Color(hex: "87E59A"), location: 0.46),
                .init(color: Color(hex: "E39CF2"), location: 0.68), .init(color: Color(hex: "A99BFF"), location: 1)],
                center: UnitPoint(x: 0.5, y: 0), startRadius: 0,
                endRadius: (g.size.width * g.size.width / 4 + g.size.height * g.size.height).squareRoot())
        }
    }
}

enum OpeningEase {
    /// CSS の `cubic-bezier(a,b,c,d)`(x → 進み具合)
    static func bezier(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ x: Double) -> Double {
        let x = min(1, max(0, x))
        if x == 0 || x == 1 { return x }
        func bx(_ t: Double) -> Double { 3 * (1 - t) * (1 - t) * t * a + 3 * (1 - t) * t * t * c + t * t * t }
        func by(_ t: Double) -> Double { 3 * (1 - t) * (1 - t) * t * b + 3 * (1 - t) * t * t * d + t * t * t }
        var lo = 0.0, hi = 1.0
        for _ in 0..<30 { let m = (lo + hi) / 2; if bx(m) < x { lo = m } else { hi = m } }
        return by((lo + hi) / 2)
    }
    static func out(_ x: Double) -> Double { 1 - pow(1 - min(1, max(0, x)), 3) }
    static func inOut(_ x: Double) -> Double {
        let x = min(1, max(0, x))
        return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }
    static func lerp(_ a: CGRect, _ b: CGRect, _ t: Double) -> CGRect {
        let k = CGFloat(t)
        return CGRect(x: a.minX + (b.minX - a.minX) * k, y: a.minY + (b.minY - a.minY) * k,
                      width: a.width + (b.width - a.width) * k, height: a.height + (b.height - a.height) * k)
    }
}

extension Notification.Name {
    /// オープニングが終わった(Home の登場を流す)
    static let openingFinished = Notification.Name("openingFinished")
}

/// Home の うしろ:まっ白(ChicColor.paper)に、やわらかい光が 2つ(右上に だいだい・左下に ラベンダー)。
/// ぼかしは つかわず、放射状のグラデーションで。ゆっくり ただよう(14秒・17秒)。
struct HomeGlowBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                let a = t / 14 * 2 * .pi
                let b = t / 17 * 2 * .pi
                ZStack {
                    ChicColor.paper
                    bloom(Color(hex: "FF8A2A"), opacity: 0.34)
                        .position(x: geo.size.width - 40 + 24 * cos(a), y: 90 + 20 * sin(a))
                    bloom(Color(hex: "B9A4F0"), opacity: 0.26)
                        .position(x: 40 + 22 * sin(b), y: geo.size.height - 120 + 24 * cos(b))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func bloom(_ color: Color, opacity: Double) -> some View {
        RadialGradient(colors: [color.opacity(opacity), color.opacity(0)], center: .center, startRadius: 0, endRadius: 190)
            .frame(width: 380, height: 380)
    }
}
