import SwiftUI

// v22 B:Home は v17 の形のまま 仕上げる(見本:Docs/Mocks/later_v22.html の ホーム。390×844 の座標)。
// 上から:ヘッダー(〜150)→ 世界の光 = ガラスの球(高さ 254)→ 見出し(2行・30pt)→ 今日のカード(90)→ グループ(17pt + タイル 80)。
// 下の月は TodayView(上のふち 742)。スクロールした先は 今日の film → 使いかたガイド(初回だけ)。
// 数は ぜんぶ FilmCounter。

enum HomeV22Rules {
    struct Headline: Equatable {
        let first: String
        let second: String
        /// 2行目で 手書きの丸で かこむ言葉
        let circled: String?
        let sub: String
    }

    /// 状態ごとの見出し(v21 D-3 と同じ文)。initial = 初回(はじめての 9:00 まで)
    static func headline(used: Int, initial: Bool) -> Headline {
        switch min(3, max(0, used)) {
        case 0:
            return initial
                ? Headline(first: "はじめまして。", second: "今日を撮ってみよう。", circled: "撮って", sub: "あしたの朝に、今日の1枚がひらきます。")
                : Headline(first: "おはよう。", second: "今日も、撮ってみよう。", circled: "撮って", sub: "あしたの朝に、今日の1枚がひらきます。")
        case 1: return Headline(first: "1こま、撮りました。", second: "今日は、あと2こま。", circled: "2", sub: "あしたの朝 9:00 に、まとめてひらきます。")
        case 2: return Headline(first: "2こま、撮りました。", second: "今日は、あと1こま。", circled: "1", sub: "あしたの朝 9:00 に、まとめてひらきます。")
        default: return Headline(first: "3こま、撮りました。", second: "今日は、ここまで。", circled: nil, sub: "あしたの 9:00 に、ひらきます。")
        }
    }

    /// 球の まんなかの字
    static func orbCenter(used: Int, initial: Bool) -> (title: String, sub: String) {
        if used > 0 { return ("世界が、ひらきました", "TAP ・ MONDO") }
        return initial ? ("ここから、はじまる", "YOUR FIRST LIGHT") : ("きのうの 世界", "今日を撮ると、ひらく")
    }

    /// 今日のカードの文
    static func card(used: Int, initial: Bool) -> (title: String, sub: String) {
        switch min(3, max(0, used)) {
        case 0: return (initial ? "最初の1枚に、なります" : "今日の 1こま目", "撮ると、あしたの朝に 仕上がります")
        case 3: return ("3こま、預けました", "あしたの 9:00 に、まとめて ひらきます")
        default: return ("今日の1枚を、預けました", "9:00 まで ミルク色 ・ 中身は ひみつ")
        }
    }

    /// 9:00 までの時間「3:44」
    static func untilNine(now: Date, calendar: Calendar = .current) -> String {
        let next = PhotoDevelop.developDate(takenAt: now, calendar: calendar)
        let m = max(0, Int(next.timeIntervalSince(now) / 60))
        return "\(m / 60):\(String(format: "%02d", m % 60))"
    }
}

/// 初回(アプリを入れた日から、はじめての 9:00 まで)。端末に保存する
enum HomeFirstDay {
    private static let key = "home.firstOpenedAt"
    private static let guideKey = "home.guideClosed"

    static func firstOpenedAt(now: Date = Date(), defaults: UserDefaults = .standard) -> Date {
        if let date = defaults.object(forKey: key) as? Date { return date }
        defaults.set(now, forKey: key)
        return now
    }

    /// はじめての 9:00 が まだ来ていない
    static func isInitial(now: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = .standard) -> Bool {
        let first = firstOpenedAt(now: now, defaults: defaults)
        return now < PhotoDevelop.developDate(takenAt: first, calendar: calendar)
    }

    static var guideClosed: Bool {
        get { UserDefaults.standard.bool(forKey: guideKey) }
        set { UserDefaults.standard.set(newValue, forKey: guideKey) }
    }
}

// MARK: - 世界の光(ガラスの球)

struct HomeGlassOrb: View {
    let used: Int
    let initial: Bool
    let dateText: String
    let isActive: Bool
    /// 登場の はじまり(nil = もう出ている)。球が ぷくっと → ドットが 中心から 1.3秒で ひらく
    var introStart: Date?
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var shake = 0

    private var running: Bool { isActive && !reduceMotion && !lowPower }
    private var intro: Bool { !reduceMotion && introStart.map { Date().timeIntervalSince($0) < 1.6 } ?? false }

    var body: some View {
        let center = HomeV22Rules.orbCenter(used: used, initial: initial)
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !running && !intro)) { context in
            let t = running ? context.date.timeIntervalSinceReferenceDate : 0
            let reveal = Self.reveal(now: context.date, start: reduceMotion ? nil : introStart)
            ZStack {
                // うしろの ふんわり光(桃〜藤)
                Circle()
                    .fill(RadialGradient(stops: [
                        .init(color: Color(red: 1, green: 0.78, blue: 0.67).opacity(0.38), location: 0),
                        .init(color: Color(red: 0.86, green: 0.78, blue: 1).opacity(0.26), location: 0.45),
                        .init(color: .clear, location: 0.7),
                    ], center: .center, startRadius: 0, endRadius: 150))
                    .frame(width: 300, height: 300)
                // 6.4秒ごとの 波紋(2つ)
                ForEach(0..<2, id: \.self) { i in
                    let p = ((t + Double(i) * 3.2).truncatingRemainder(dividingBy: 6.4)) / 6.4
                    Circle().stroke(Color(red: 1, green: 0.59, blue: 0.43).opacity(0.35), lineWidth: 1.2)
                        .frame(width: 192, height: 192)
                        .scaleEffect(1 + 0.42 * p)
                        .opacity(running ? 0.9 * (1 - p) : 0)
                }
                // 外の文字の輪(200秒で一周)
                HomeRingText(text: "LATER — WORLD LIGHTS — YESTERDAY — \(dateText) — ", radius: 128)
                    .rotationEffect(.degrees((t.truncatingRemainder(dividingBy: 200) / 200) * 360))
                    .opacity(reveal)
                // ガラスの球
                ZStack {
                    Circle().fill(RadialGradient(stops: [
                        .init(color: .white, location: 0), .init(color: Color(hex: "FBFBFD"), location: 0.3),
                        .init(color: Color(hex: "F1F1F5"), location: 0.72), .init(color: Color(hex: "E7E7EE"), location: 1),
                    ], center: UnitPoint(x: 0.32, y: 0.24), startRadius: 0, endRadius: 120))
                    HomeOrbDots(used: used, t: t, reveal: reveal)
                    // 左上の つや
                    Ellipse().fill(LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 184 * 0.44, height: 184 * 0.16)
                        .rotationEffect(.degrees(-16))
                        .offset(x: -184 * 0.08, y: -184 * 0.34)
                    VStack(spacing: 5) {
                        Text(center.title).font(.system(size: 13.5, weight: .heavy)).tracking(0.22 * 13.5).foregroundStyle(Color(hex: "1A1A22"))
                            .shadow(color: .white, radius: 5)
                        Text(center.sub).font(.system(size: 7.5, design: .monospaced)).tracking(0.24 * 7.5).foregroundStyle(Color(hex: "9C99A6"))
                    }
                    .opacity(reveal)
                }
                .frame(width: 184, height: 184)
                .overlay {
                    // 虹色のふち(2pt・24秒で ゆっくり回る)
                    Circle()
                        .strokeBorder(AngularGradient(colors: [Color(hex: "FFB38A"), Color(hex: "F7A8D8"), Color(hex: "B9A4FF"), Color(hex: "8EC5FF"), Color(hex: "9EE6D0"), Color(hex: "FFE08A"), Color(hex: "FFB38A")], center: .center), lineWidth: 2)
                        .rotationEffect(.degrees((t.truncatingRemainder(dividingBy: 24) / 24) * 360))
                }
                .shadow(color: Color(red: 0.47, green: 0.35, blue: 0.63).opacity(0.35), radius: 20, y: 18)
                .scaleEffect(0.7 + 0.3 * min(1, reveal * 1.4))
                // MONDO のピル(球の 下のふち)
                mondoPill(reveal: reveal).offset(y: 78 + 13)
                    .keyframeAnimator(initialValue: 0.0, trigger: shake) { content, x in content.offset(x: x) } keyframes: { _ in
                        KeyframeTrack { LinearKeyframe(-5, duration: 0.05); LinearKeyframe(5, duration: 0.07); LinearKeyframe(-3, duration: 0.06); LinearKeyframe(0, duration: 0.05) }
                    }
                // ステッカー(星・波線・花・点)
                stickers(t: t, reveal: reveal)
            }
            .frame(height: 254)
        }
        .contentShape(Rectangle().inset(by: 30))
        .onTapGesture {
            if used == 0 { shake += 1 }
            onTap()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(used > 0 ? "世界の光。押すと Mondo へ" : "世界の光。1枚 撮ると、Mondo が ひらきます")
        .accessibilityAddTraits(.isButton)
    }

    static func reveal(now: Date, start: Date?) -> Double {
        guard let start else { return 1 }
        let k = min(1, max(0, now.timeIntervalSince(start) / 1.3))
        return 1 - pow(1 - k, 3)
    }

    private func mondoPill(reveal: Double) -> some View {
        let open = used > 0
        return HStack(spacing: 5) {
            if !open { Image(systemName: "lock.fill").font(.system(size: 9, weight: .bold)) }
            Text("MONDO").font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(0.2 * 9.5)
            if open { Text("›").font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: "FF8A2A")) }
        }
        .foregroundStyle(open ? .white : Color(hex: "111111"))
        .padding(.leading, 9).padding(.trailing, 10)
        .frame(height: 26)
        .background(Capsule().fill(open ? Color(hex: "111111") : .white))
        .overlay { if !open { Capsule().strokeBorder(Color(hex: "111111"), lineWidth: 1.4) } }
        .shadow(color: .black.opacity(0.3), radius: 7, y: 6)
        .opacity(reveal)
    }

    private func stickers(t: Double, reveal: Double) -> some View {
        let s = running ? sin(t * 2 * .pi / 5) : 0, s2 = running ? sin(t * 2 * .pi / 6) : 0
        return ZStack {
            ChicDoodle(kind: .star, width: 36).rotationEffect(.degrees(10 * s)).offset(x: -195 + 26 + 18, y: -127 + 2 + 18 - 7 * s)
            ChicDoodle(kind: .wave, width: 50).rotationEffect(.degrees(-8 * s2)).offset(x: 195 - 26 - 25, y: -127 + 22 + 10 + 5 * s2)
            ChicDoodle(kind: .flower, width: 38).rotationEffect(.degrees(10 * s2)).offset(x: 195 - 34 - 19, y: -127 + 206 + 19 - 7 * s2)
            ChicDoodle(kind: .dots, width: 26).offset(x: -195 + 34 + 13, y: -127 + 212 + 13 + 5 * s)
        }
        .opacity(reveal)
        .allowsHitTesting(false)
    }
}

/// 球の中の ドット(世界の光)と「あなたの光」(半径 58 の 橙の点線の輪。撮った数だけ ともる)
private struct HomeOrbDots: View {
    let used: Int
    let t: Double
    let reveal: Double

    private struct Dot { let r, a, w, s, tw, c: Double }

    private static let dots: [Dot] = {
        var rng = SeededRandom(seed: 22)
        func rand() -> Double { Double(rng.next() % 10_000) / 10_000 }
        let maxR = 86.0
        var list: [Dot] = []
        var ring = 0
        for r in stride(from: 14.0, through: maxR, by: 7.2) {
            let n = Int((2 * Double.pi * r / 7.6).rounded())
            let dir: Double = ring % 2 == 1 ? 1 : -1
            for i in 0..<n {
                list.append(Dot(r: r, a: Double(i) / Double(n) * 2 * .pi, w: dir * (0.00005 + (maxR - r) * 0.0000016) * 1000,
                                s: 0.5 + rand() * 0.9 + (r / maxR) * 0.5, tw: rand() * 6.3, c: rand()))
            }
            ring += 1
        }
        return list
    }()

    private static let palette: [Color] = [Color(red: 1, green: 0.54, blue: 0.16), Color(red: 1, green: 0.77, blue: 0.24), Color(red: 1, green: 0.47, blue: 0.63), Color(red: 0.43, green: 0.59, blue: 1), Color(red: 0.67, green: 0.51, blue: 1)]

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxR = 86.0
            // 光の波は ひかえめ(橙が 帯にならないように)
            let wave = (t.truncatingRemainder(dividingBy: 5.2) / 5.2) * (maxR + 30)
            var gray = Path(), ink = Path(), warm = Path()
            var colors = [Path](repeating: Path(), count: 5)
            for d in Self.dots where d.r <= reveal * (maxR + 2) {
                let an = d.a + t * d.w
                let x = c.x + cos(an) * d.r, y = c.y + sin(an) * d.r * 0.96
                let b = exp(-pow((d.r - wave) / 9, 2))
                var s = d.s * (1 + 0.55 * b)
                if used > 0 && d.c > 0.8 {
                    s *= 1.2
                    colors[Int(d.c * 50) % 5].addEllipse(in: CGRect(x: x - s, y: y - s, width: 2 * s, height: 2 * s))
                } else if d.c > 0.95 {
                    s *= 1.1
                    ink.addEllipse(in: CGRect(x: x - s, y: y - s, width: 2 * s, height: 2 * s))
                } else if b > 0.3 {
                    warm.addEllipse(in: CGRect(x: x - s, y: y - s, width: 2 * s, height: 2 * s))
                } else {
                    gray.addEllipse(in: CGRect(x: x - s, y: y - s, width: 2 * s, height: 2 * s))
                }
            }
            ctx.fill(gray, with: .color(Color(red: 0.55, green: 0.53, blue: 0.6).opacity(0.38)))
            ctx.fill(ink, with: .color(Color(red: 0.07, green: 0.07, blue: 0.08).opacity(0.5)))
            ctx.fill(warm, with: .color(Color(red: 1, green: 0.59, blue: 0.31).opacity(0.55)))
            for (i, path) in colors.enumerated() { ctx.fill(path, with: .color(Self.palette[i].opacity(0.8))) }

            // あなたの光
            let R = 58.0, rot = t * 0.18
            var ring = Path()
            ring.addEllipse(in: CGRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R))
            ctx.stroke(ring, with: .color(Color(red: 1, green: 0.42, blue: 0.1).opacity(0.35 * reveal)), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
            for i in 0..<3 {
                let an = rot - .pi / 2 + Double(i) * 2.0944
                let p = CGPoint(x: c.x + cos(an) * R, y: c.y + sin(an) * R)
                if i < used {
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 12, y: p.y - 12, width: 24, height: 24)),
                             with: .radialGradient(Gradient(stops: [
                                .init(color: Color(red: 1, green: 0.59, blue: 0.24).opacity(0.95), location: 0),
                                .init(color: Color(red: 1, green: 0.47, blue: 0.16).opacity(0.5), location: 0.35),
                                .init(color: .clear, location: 1),
                             ]), center: p, startRadius: 0, endRadius: 12))
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.2, y: p.y - 2.2, width: 4.4, height: 4.4)), with: .color(.white))
                } else {
                    let next = i == used
                    let r = next ? 4.2 : 3.2
                    let alpha = next ? 0.75 + 0.25 * sin(t * 4) : 0.4
                    ctx.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)),
                               with: .color(Color(red: 1, green: 0.42, blue: 0.1).opacity(alpha * reveal)), lineWidth: 1.3)
                }
            }
        }
        .frame(width: 184, height: 184)
        .clipShape(Circle())
    }
}

/// 円に沿った文字(等幅 8pt・灰)
struct HomeRingText: View {
    let text: String
    let radius: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let chars = Array(text)
            let step = 2 * Double.pi / Double(chars.count)
            for (i, ch) in chars.enumerated() {
                let a = -Double.pi / 2 + Double(i) * step
                var inner = ctx
                inner.translateBy(x: c.x + cos(a) * radius, y: c.y + sin(a) * radius)
                inner.rotate(by: .radians(a + .pi / 2))
                inner.draw(Text(String(ch)).font(.system(size: 8, design: .monospaced)).foregroundColor(Color(hex: "A9A6B0")), at: .zero)
            }
        }
        .frame(width: radius * 2 + 20, height: radius * 2 + 20)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 見出し(2行・Black 30pt・字間 -4.5%・手書きの丸は文字に ぴったり)

/// v22 ホームの 文字と 面の色(昼 / 夜)。夜(21:00〜9:00)は 背景が ほぼ黒なので、昼の色を そのまま 使わない。
/// 夜の目安:本文 4.5:1 以上・大きな見出し 3:1 以上・小さな説明も #A1A1A8 より 暗くしない
struct HomeV22Ink: Equatable {
    let night: Bool

    private func pick(_ day: String, _ night: String) -> Color { Color(hex: self.night ? night : day) }
    /// 見出し・タイトル
    var ink: Color { pick("111111", "F5F5F7") }
    /// 小さな説明
    var sub: Color { pick("8E8E93", "A1A1A8") }
    /// 数字(1 / 3 など)
    var meta: Color { pick("6E6E73", "B4B4BB") }
    var chevron: Color { pick("C7C7CC", "8E8E95") }
    /// 今日のカードの面
    var card: Color { pick("FFFFFF", "18181C") }
    /// うすい面(参加する・ガイドの カード)
    var soft: Color { night ? Color.white.opacity(0.07) : Color(hex: "F4F3F7") }
    var softLine: Color { night ? Color.white.opacity(0.14) : Color(hex: "E3E2E9") }
    var guideCard: Color { night ? Color.white.opacity(0.07) : Color(hex: "F6F5F8") }
    /// こま(撮った = 塗り・つぎ = ふち・まだ = 点線)
    var slot: Color { pick("111111", "F5F5F7") }
    var slotDash: Color { pick("C9C8CE", "6E6E76") }
    /// 目じるしの 文字
    var marker: Color { pick("3A3A3C", "D1D1D6") }
    var faint: Color { pick("AEAEB2", "A1A1A8") }
    /// 白い ボタンの 面
    var button: Color { night ? Color.white.opacity(0.1) : .white }
}

struct HomeV22Headline: View {
    let headline: HomeV22Rules.Headline
    /// 丸を描く進み 0〜1
    var circle: Double = 1
    var lineReveal: Double = 1
    let width: CGFloat

    @Environment(\.palette) private var palette
    private var colors: HomeV22Ink { HomeV22Ink(night: palette.isNight) }

    var body: some View {
        VStack(spacing: 0) {
            line(headline.first, circled: nil)
            line(headline.second, circled: headline.circled)
                .opacity(lineReveal)
            Text(headline.sub)
                .font(.system(size: 13, weight: .medium)).tracking(0.02 * 13)
                .foregroundStyle(colors.sub)
                .padding(.top, 7)
        }
        .frame(width: width)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(headline.first + headline.second + headline.sub)
    }

    private func line(_ text: String, circled: String?) -> some View {
        let size = min(30, (width - 32) / (CGFloat(text.count) * 0.96))
        let font = Font.system(size: size, weight: .black)
        let parts: (String, String?, String) = {
            guard let circled, let r = text.range(of: circled) else { return (text, nil, "") }
            return (String(text[..<r.lowerBound]), circled, String(text[r.upperBound...]))
        }()
        // 文字の ならびを そのまま はかって、丸の言葉の上に 丸を置く
        return HStack(spacing: 0) {
            if !parts.0.isEmpty { Text(parts.0) }
            if let hit = parts.1 {
                Text(hit).overlay {
                    HomeHandCircle()
                        .trim(from: 0, to: circle)
                        .stroke(Color(hex: "F26A1B"), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                        .padding(.horizontal, hit.count == 1 ? -12 : -8)
                        .padding(.vertical, -size * 0.12)
                }
            }
            if !parts.2.isEmpty { Text(parts.2) }
        }
        .font(font)
        .tracking(-0.045 * size)
        .foregroundStyle(colors.ink)
        .lineLimit(1)
        .fixedSize()
        .frame(height: size * 1.24)
    }
}

/// 手書きの丸(見本:M84 6C128 2 157 15 154 34 151 54 112 62 76 60 32 58 4 49 6 29 8 12 44 4 104 8 ・ 160×64)
struct HomeHandCircle: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 160, sy = rect.height / 64
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var path = Path()
        path.move(to: p(84, 6))
        path.addCurve(to: p(154, 34), control1: p(128, 2), control2: p(157, 15))
        path.addCurve(to: p(76, 60), control1: p(151, 54), control2: p(112, 62))
        path.addCurve(to: p(6, 29), control1: p(32, 58), control2: p(4, 49))
        path.addCurve(to: p(104, 8), control1: p(8, 12), control2: p(44, 4))
        return path
    }
}

// MARK: - 今日のカード(今日の film の入口)

struct HomeTodayCard: View {
    let used: Int
    let initial: Bool
    let now: Date
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.palette) private var palette
    @State private var bounce = 0
    private var landing: FilmLanding { FilmLanding.shared }
    private var colors: HomeV22Ink { HomeV22Ink(night: palette.isNight) }

    var body: some View {
        let text = HomeV22Rules.card(used: used, initial: initial)
        Button(action: onTap) {
            HStack(spacing: 14) {
                cheki
                VStack(alignment: .leading, spacing: 3) {
                    Text(text.title).font(.system(size: 15.5, weight: .black)).tracking(-0.02 * 15.5).foregroundStyle(colors.ink).lineLimit(1).minimumScaleFactor(0.8)
                    Text(text.sub).font(.system(size: 11.5, weight: .medium)).foregroundStyle(colors.sub).lineLimit(1).minimumScaleFactor(0.8)
                    HStack(spacing: 6) {
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in slot(i) }
                        }
                        Text("\(used) / 3").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(0.1 * 10).foregroundStyle(colors.meta)
                        Spacer(minLength: 0)
                        if used >= 3 {
                            Text("あと \(HomeV22Rules.untilNine(now: now))").font(.system(size: 10, design: .monospaced)).tracking(0.06 * 10).foregroundStyle(palette.accent)
                        }
                    }
                    .padding(.top, 4)
                }
                Text("›").font(.system(size: 22)).foregroundStyle(colors.chevron).padding(.trailing, 2)
            }
            .padding(.leading, 10).padding(.trailing, 12)
            .frame(height: 90)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(colors.card))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(LinearGradient(colors: [Color(hex: "FFCFB4"), Color(hex: "E8D6FF"), Color(hex: "CFE0FF"), Color(hex: "FFE7B8")], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5).opacity(palette.isNight ? 0.55 : 1))
            .shadow(color: Color(red: 0.47, green: 0.31, blue: 0.63).opacity(palette.isNight ? 0.2 : 0.35), radius: 15, y: 14)
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.98))
        .keyframeAnimator(initialValue: 1.0, trigger: bounce) { content, s in content.scaleEffect(s) } keyframes: { _ in
            KeyframeTrack { CubicKeyframe(1.04, duration: 0.12); SpringKeyframe(1, duration: 0.3) }
        }
        .onChange(of: landing.landedToken) { _, _ in bounce += 1 }
        .accessibilityLabel("\(text.title)。\(text.sub)。今日 \(used)こま。押すと 現像ビューへ")
    }

    private var cheki: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                window.clipShape(RoundedRectangle(cornerRadius: 2))
                Spacer(minLength: 0).frame(height: 12)
            }
            .padding(5)
            .frame(width: 64, height: 76)
            .background(RoundedRectangle(cornerRadius: 3).fill(.white))
            .shadow(color: .black.opacity(0.28), radius: 9, y: 10)
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.black.opacity(0.04), lineWidth: 1))
            V17Tape(width: 30, height: 13).rotationEffect(.degrees(-8)).offset(x: 4, y: -9)
        }
        .rotationEffect(.degrees(-4))
        .offset(y: -5)
        // 撮ったチェキが とんでくる先(画面の座標)。こまの番号は どれでも、この カードの 写真の所
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rect in
            for i in 0..<3 { landing.slotFrames[i] = rect }
        }
    }

    @ViewBuilder
    private var window: some View {
        if used == 0 {
            ZStack(alignment: .bottom) {
                Color(hex: "0E0E10")
                Circle().fill(.white).frame(width: 6, height: 6).shadow(color: .white, radius: 4).frame(maxHeight: .infinity)
                Text(HomeV17Rules.dotDate(now)).font(.system(size: 7.5, weight: .bold, design: .monospaced)).foregroundStyle(Color(hex: "FF7A1A")).padding(.bottom, 3)
            }
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
                let s = reduceMotion ? 0 : (sin(context.date.timeIntervalSinceReferenceDate * 2 * .pi / 2.2) + 1) / 2
                ZStack {
                    LinearGradient(colors: [Color(hex: "E9EEEA"), Color(hex: "D3DAE5")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().fill(Color(hex: "FF8A2A")).frame(width: 6, height: 6).shadow(color: Color(hex: "FF8A2A").opacity(0.8), radius: 4)
                        .scaleEffect(1 + 0.5 * s).opacity(1 - 0.4 * s)
                }
            }
        }
    }

    private func slot(_ i: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 3)
        return ZStack {
            if i < used {
                shape.fill(colors.slot)
                Circle().fill(Color(hex: "FF8A2A")).frame(width: 4, height: 4)
            } else if i == used {
                shape.strokeBorder(colors.slot, lineWidth: 1.6)
            } else {
                shape.strokeBorder(colors.slotDash, style: StrokeStyle(lineWidth: 1.4, dash: [2, 2]))
            }
        }
        .frame(width: 11, height: 14)
    }
}

// MARK: - グループ(17pt + 横長のタイル 80)

struct HomeV22Groups: View {
    let summaries: [GroupSummary]
    let canCreate: Bool
    let isFrontmost: Bool
    let shotsToday: Int
    let onSelect: (UUID) -> Void
    let onCreate: () -> Void
    let onJoin: () -> Void
    let onAdd: () -> Void

    @Environment(\.palette) private var palette
    private var colors: HomeV22Ink { HomeV22Ink(night: palette.isNight) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if summaries.isEmpty {
                Text("グループ").font(.system(size: 17, weight: .black)).tracking(-0.02 * 17).foregroundStyle(colors.ink).padding(.leading, 4)
                HStack(spacing: 10) {
                    tile(dark: true, icon: "plus", title: "つくる", note: "4〜8人の グループ", action: onCreate)
                    tile(dark: false, icon: "qrcode", title: "参加する", note: "合言葉・QR・リンク", action: onJoin)
                }
            } else {
                HomeGroupStrip(summaries: summaries, canCreate: canCreate, isFrontmost: isFrontmost, entranceStart: nil,
                               onSelect: onSelect, onCreate: onCreate, onJoin: onJoin, onAdd: onAdd, arrivingID: nil, shotsToday: shotsToday)
                    .padding(.horizontal, -18)
            }
        }
        .padding(.horizontal, 18)
    }

    private func tile(dark: Bool, icon: String, title: String, note: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.play(.tick)
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 17, weight: .bold))
                    .foregroundStyle(dark ? .white : Color(hex: "111111"))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(dark ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "FFB05A"), Color(hex: "FF5A7A")], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.white)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 16, weight: .black)).tracking(-0.02 * 16).foregroundStyle(dark ? .white : colors.ink)
                    Text(note).font(.system(size: 10.5, weight: .medium)).foregroundStyle(dark ? Color(hex: "A7A7B2") : colors.sub).lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(dark
                ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "141418"), Color(hex: "2A2433")], startPoint: .topLeading, endPoint: .bottomTrailing))
                : AnyShapeStyle(colors.soft)))
            // 夜は 黒い タイルも 背景に とけないよう、うすい ふちを つける
            .overlay { if !dark || palette.isNight { RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(colors.softLine, lineWidth: dark ? 1 : 1.4) } }
            .shadow(color: dark ? Color(red: 0.12, green: 0.08, blue: 0.16).opacity(0.6) : .clear, radius: 13, y: 14)
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
        .accessibilityLabel("\(title)。\(note)")
    }
}

// MARK: - 使いかたガイド(初回だけ・とじられる)

struct HomeV22Guide: View {
    let now: Date
    let onClose: () -> Void

    @Environment(\.palette) private var palette
    private var colors: HomeV22Ink { HomeV22Ink(night: palette.isNight) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Circle().fill(Color(hex: "FF6A1A")).frame(width: 6, height: 6)
                Text("HOW IT WORKS").font(.system(size: 9.5, design: .monospaced)).tracking(0.2 * 9.5).foregroundStyle(colors.sub)
            }
            Text("あしたの朝、\nこう ひらく。").font(.system(size: 28, weight: .black)).tracking(-0.045 * 28).foregroundStyle(colors.ink).padding(.top, 8)
            HStack(alignment: .top, spacing: 8) {
                step(icon: AnyView(Circle().fill(RadialGradient(colors: [Color(hex: "FFD08A"), Color(hex: "FF7A4A"), Color(hex: "E04A6A")], center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: 22)).overlay(Circle().strokeBorder(.white, lineWidth: 3))),
                     title: "ながおしで 撮る", note: "1日3こま")
                step(icon: AnyView(RoundedRectangle(cornerRadius: 4).fill(LinearGradient(colors: [Color(hex: "E9EEEA"), Color(hex: "D3DAE5")], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 32).shadow(color: .black.opacity(0.15), radius: 5, y: 4)),
                     title: "ミルク色で 預ける", note: "中身は 見えない")
                step(icon: AnyView(Circle().fill(RadialGradient(stops: [.init(color: .white, location: 0), .init(color: Color(hex: "FFC9A2"), location: 0.34), .init(color: Color(hex: "E39CF2"), location: 0.78), .init(color: Color(hex: "A99BFF"), location: 1)], center: .top, startRadius: 0, endRadius: 40))),
                     title: "9:00 に ひらく", note: "えらんだ1枚は 1年")
            }
            .padding(.top, 16)
            dayBar.padding(.top, 14)
            Button {
                Haptics.play(.soft)
                onClose()
            } label: {
                Text("このガイドを とじる").font(.system(size: 11.5, weight: .bold)).foregroundStyle(colors.sub)
                    .padding(.horizontal, 16).frame(height: 34)
                    .background(Capsule().fill(colors.button)).overlay(Capsule().strokeBorder(colors.softLine, lineWidth: 1.2))
            }
            .buttonStyle(SquishButtonStyle(pressedScale: 0.96))
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
        .padding(.horizontal, 22)
    }

    private func step(icon: AnyView, title: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            icon.frame(width: 38, height: 38).padding(.bottom, 8)
            Text(title).font(.system(size: 13, weight: .heavy)).tracking(-0.01 * 13).foregroundStyle(colors.ink).fixedSize(horizontal: false, vertical: true)
            Text(note).font(.system(size: 10, weight: .medium)).foregroundStyle(colors.sub)
        }
        .padding(.horizontal, 10).padding(.top, 12).padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(colors.guideCard))
    }

    /// Later の 1日:0〜24時の帯(夜 → 朝 → 昼 → 夕)+「いま」のつまみ・9:00 ひらく・24:00 消灯
    private var dayBar: some View {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        let k = Double((c.hour ?? 0) * 60 + (c.minute ?? 0)) / 1440
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Later の 1日").font(.system(size: 13, weight: .heavy)).foregroundStyle(colors.ink)
                Spacer()
                Text("いま \(HomeV17Rules.clockText(HomeV17Rules.hour(of: now)))").font(.system(size: 10)).tracking(0.08 * 10).foregroundStyle(palette.accent)
            }
            GeometryReader { proxy in
                let w = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(LinearGradient(stops: [
                        .init(color: Color(hex: "2B2A4A"), location: 0), .init(color: Color(hex: "4A3A6A"), location: 0.18), .init(color: Color(hex: "FFB38A"), location: 0.34),
                        .init(color: Color(hex: "FFE7C8"), location: 0.45), .init(color: Color(hex: "FFF6E8"), location: 0.6), .init(color: Color(hex: "FFC9A2"), location: 0.76),
                        .init(color: Color(hex: "9C86FF"), location: 0.9), .init(color: Color(hex: "2B2A4A"), location: 1),
                    ], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 16)
                    marker("9:00 ひらく", x: w * 9 / 24)
                    marker("24:00 消灯", x: w - 1, alignRight: true)
                    Circle().fill(.white).overlay(Circle().fill(Color(hex: "FF6A1A")).padding(6)).overlay(Circle().strokeBorder(Color(hex: "111111"), lineWidth: 2))
                        .frame(width: 20, height: 20).shadow(color: .black.opacity(0.25), radius: 5, y: 4)
                        .position(x: w * k, y: 8)
                }
            }
            .frame(height: 16)
            .padding(.top, 30)
            HStack {
                ForEach(["0", "6", "12", "18", "24"], id: \.self) { h in
                    Text(h).font(.system(size: 9)).tracking(0.06 * 9).foregroundStyle(colors.faint)
                    if h != "24" { Spacer() }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(colors.guideCard))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Later の 1日。9:00 に ひらき、24:00 に 消灯")
    }

    private func marker(_ text: String, x: CGFloat, alignRight: Bool = false) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 1).fill(colors.slot).frame(width: 2, height: 24)
            Text(text).font(.system(size: 9.5, weight: .bold)).foregroundStyle(colors.marker).fixedSize()
                .offset(x: alignRight ? -30 : 0, y: -26)
        }
        .position(x: x, y: 8)
    }
}
