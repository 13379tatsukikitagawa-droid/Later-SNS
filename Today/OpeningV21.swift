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

    private var k: Double { variant == .short ? 0.5 : 1 }
    var dot: Double { 0.09 }
    var focus: Double { 0.76 * k }
    var flash: Double { 1.0 * k }
    var chekiIn: Double { 1.2 * k }
    var tape: Double { 1.8 * k }
    var develop: Double { variant == .short ? chekiIn : 1.85 }
    var developDuration: Double { variant == .short ? 0.01 : 1.0 }
    var letters: Double { variant == .short ? 0.95 : 2.25 }
    var morph: Double { variant == .short ? 1.1 : 2.67 }
    var morphDuration: Double { 0.78 }
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
                let t = context.date.timeIntervalSince(start)
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
        .accessibilityLabel("Later。タップで とばす")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: 1コマ

    @ViewBuilder
    private func frame(t: Double, size: CGSize) -> some View {
        if variant == .fade {
            // 橙の点 → 白 → Home(0.4秒)
            ZStack {
                Color(hex: "07070A").opacity(max(0, 1 - t / 0.15))
                Color(hex: "FFFDFA").opacity(t < 0.15 ? t / 0.15 : max(0, 1 - (t - 0.2) / 0.2))
                Circle().fill(Color(hex: "FF8A2A")).frame(width: 12, height: 12).opacity(max(0, 1 - t / 0.15))
            }
        } else {
            let paper = t >= tl.flash
            let endFade = max(0, min(1, (t - (tl.end - 0.26)) / 0.26))
            ZStack {
                // 0〜1.0:まっ黒(Launch Screen と同じ)→ 1.0 で白い紙へ
                Color(hex: "07070A").opacity(paper ? 0 : 1)
                if paper {
                    HomeV21Paper(isActive: false, height: size.height)
                }
                if !paper { finder(t: t, size: size) }
                if paper { cheki(t: t, size: size) }
                // パシャ:まっ白に フラッシュ
                Color.white.opacity(flashOpacity(t))
            }
            .opacity(1 - endFade)
        }
    }

    private func flashOpacity(_ t: Double) -> Double {
        let s = tl.flash - 0.015, d = 0.43 * (variant == .short ? 0.6 : 1)
        let p = (t - s) / d
        guard p > 0, p < 1 else { return 0 }
        if p < 0.12 { return p / 0.12 }
        if p < 0.4 { return 1 }
        return 1 - (p - 0.4) / 0.6
    }

    /// 橙の点と、四すみの かぎかっこ(28pt・2.5pt)・下に「LATER」
    private func finder(t: Double, size: CGSize) -> some View {
        let c = CGPoint(x: size.width / 2, y: size.height * 0.46)
        let dotP = min(1, max(0, (t - tl.dot) / 0.22))
        let close = min(1, max(0, (t - 0.24 * (variant == .short ? 0.5 : 1)) / (0.56 * (variant == .short ? 0.5 : 1))))
        let squeeze = close < 0.78 ? close / 0.78 : 1 + 0.05 * sin((close - 0.78) / 0.22 * .pi)
        let half = CGSize(width: 150 - 9 * min(1, squeeze), height: 200 - 9 * min(1, squeeze))
        return ZStack {
            Circle().fill(Color(hex: "FF8A2A")).frame(width: 12, height: 12)
                .shadow(color: Color(hex: "FF8A2A"), radius: 10)
                .scaleEffect(dotP)
                .position(c)
            ForEach(0..<4, id: \.self) { i in
                let sx: CGFloat = i % 2 == 0 ? -1 : 1, sy: CGFloat = i < 2 ? -1 : 1
                OpeningBracket(corner: i)
                    .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .position(x: c.x + sx * (half.width - 14 + 150 * (1 - min(1, squeeze))), y: c.y + sy * (half.height - 14 + 200 * (1 - min(1, squeeze))))
                    .opacity(min(1, close * 3))
            }
            Text("LATER")
                .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(0.4 * 10)
                .foregroundStyle(.white.opacity(0.6))
                .position(x: c.x, y: c.y + 230)
                .opacity(min(1, max(0, (t - 0.7 * (variant == .short ? 0.5 : 1)) / 0.32)))
        }
    }

    /// チェキ(264×356)が下から にゅっ → テープ → 現像(ミルク → 夕焼け)→「Later」が1文字ずつ → 窓が ふくらんで 下のボタンの円へ
    private func cheki(t: Double, size: CGSize) -> some View {
        let w: CGFloat = 264, h: CGFloat = 356
        let center = CGPoint(x: size.width / 2, y: size.height * 0.45)
        // 出てくる(0.78秒・少し弾む)
        let inP = min(1, max(0, (t - tl.chekiIn) / 0.78))
        let rise: CGFloat = inP < 0.74 ? 780 * (1 - CGFloat(OpeningEase.out(inP / 0.74))) - 16 * CGFloat(inP / 0.74) : -16 * CGFloat(1 - (inP - 0.74) / 0.26)
        let tilt = inP < 0.74 ? -9 + 7 * (inP / 0.74) : -2 - (inP - 0.74) / 0.26
        // 現像
        let dev = variant == .short ? 1 : min(1, max(0, (t - tl.develop) / tl.developDuration))
        // 窓 → 円(2.67秒〜・0.78秒)
        let m = min(1, max(0, (t - tl.morph) / tl.morphDuration))
        let me = OpeningEase.inOut(m)
        let window = CGRect(x: center.x - 115, y: center.y - h / 2 + 12 + rise, width: 230, height: 270)
        let moonD = MoonLayout.diameter(screenWidth: size.width)
        let moonC = MoonLayout.center(in: size)
        let target = CGRect(x: moonC.x - moonD / 2, y: moonC.y - moonD / 2, width: moonD, height: moonD)
        let rect = OpeningEase.lerp(window, target, me)
        let radius = 5 + (moonD / 2 - 5) * me
        return ZStack(alignment: .topLeading) {
            // 白いふち(チェキ本体)
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(hex: "F7F4EE"))
                .frame(width: w, height: h)
                .shadow(color: .black.opacity(0.18), radius: 24, y: 18)
                .overlay(alignment: .bottomLeading) { wordmark(t: t).padding(.leading, 20).padding(.bottom, 18) }
                .rotationEffect(.degrees(tilt))
                .position(x: center.x, y: center.y + rise)
                .opacity(1 - min(1, max(0, (t - tl.morph) / 0.3)))
            // マスキングテープ
            V17Tape(width: 74, height: 24, stripe: 5)
                .rotationEffect(.degrees(-3))
                .position(x: center.x, y: center.y + rise - h / 2 - 4)
                .opacity(min(1, max(0, (t - tl.tape) / 0.26)) * (1 - min(1, max(0, (t - tl.morph) / 0.3))))
            // 窓(ミルク → 夕焼け)→ そのまま 下のボタンの円へ
            ZStack {
                LinearGradient(colors: [Color(hex: "B49BFF"), Color(hex: "FF9C8C"), Color(hex: "FFC9A2"), Color(hex: "FFEFE2")], startPoint: .top, endPoint: .bottom)
                    .opacity(dev)
                LinearGradient(colors: [Color(hex: "DDE6E2"), Color(hex: "C9D3E0")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(0.94 * (1 - dev))
            }
            .frame(width: rect.width, height: rect.height)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .rotationEffect(.degrees(tilt * (1 - me)))
            .position(x: rect.midX, y: rect.midY)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    /// 「Later」(Black 46pt)が 1文字ずつ印刷される(70msずれ)+ 橙の「11.06」
    private func wordmark(t: Double) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 10) {
            HStack(spacing: -2) {
                ForEach(Array("Later".enumerated()), id: \.offset) { i, ch in
                    let p = min(1, max(0, (t - tl.letters - Double(i) * 0.07) / 0.42))
                    Text(String(ch)).font(.system(size: 46, weight: .black)).tracking(-0.06 * 46).foregroundStyle(Color(hex: "111111"))
                        .opacity(p).offset(y: 12 * (1 - p)).blur(radius: 7 * (1 - p))
                }
            }
            SevenSegmentText(text: HomeV17Rules.dotDate(Date()), height: 16, color: Color(hex: "FF8A2A"))
                .frame(width: 58, height: 18)
                .opacity(min(1, max(0, (t - tl.letters - 0.45) / 0.3)))
        }
    }

    // MARK: バイブ・おわり

    private func scheduleHaptics() {
        func at(_ s: Double, _ work: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + s) { if !finished { work() } }
        }
        if variant == .fade { Haptics.play(.click); return }
        at(variant == .short ? 0.09 : 0.18) { Haptics.play(.pop) }
        at(tl.focus) { Haptics.play(.click) }
        at(tl.flash) { Haptics.play(.shutter) }
        at(tl.chekiIn + 0.03) { Haptics.play(.soft) }
        at(variant == .short ? tl.chekiIn + 0.5 : 1.9) { Haptics.play(.land) }
        if variant == .full {
            // 現像:じわっと強く(0.12 → 0.82)
            at(tl.develop) {
                ramp.start()
                Task { @MainActor in
                    let begin = Date()
                    while !finished {
                        let k = min(1, Date().timeIntervalSince(begin) / 1.0)
                        ramp.update(0.12 + 0.7 * k * k)
                        if k >= 1 { break }
                        try? await Task.sleep(for: .milliseconds(30))
                    }
                    ramp.stop()
                }
            }
            for i in 0..<5 { at(tl.letters + 0.03 + Double(i) * 0.07) { Haptics.play(.tick, gap: 0) } }
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

enum OpeningEase {
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
