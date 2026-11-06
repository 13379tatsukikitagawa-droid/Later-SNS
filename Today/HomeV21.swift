import SwiftUI

// v21 D:Home を「Later らしく」(見本:Docs/Mocks/later_v21.html の ホーム。390×844 の座標)。
// 大きな文字ではなく 素材で:白い紙(#FFFDFA)・光のにじみ・フィルムの番号・洗濯ひもとチェキ3まい・世界の光・印刷ズレの見出し・手書きの丸。
// 見出しは元と同じ大きさ(42pt)。下の「今日を撮る」(月)は、いまのまま(ユーザーの決定)。
// スクロールした先は「グループ」だけ(v17 の区画は外した)。

enum HomeV21Rules {
    /// 状態ごとの見出し(小さな一言・見出し・丸でかこむ言葉・補足)
    struct Headline: Equatable {
        let kicker: String
        let title: String
        let circled: String?
        let sub: String
    }

    static func headline(shots: Int, state: HomeState) -> Headline {
        // 夜(撮れない時間)は、いまの見出しのまま
        if state.isNight {
            let lines = HomeView.headline(state).replacingOccurrences(of: "\n", with: "")
            return Headline(kicker: "おやすみ。", title: lines, circled: ChicHomeView.circledWord(state), sub: HomeView.subline(state))
        }
        switch min(3, max(0, shots)) {
        case 0: return Headline(kicker: "はじめまして。", title: "今日を撮ってみよう。", circled: "撮って", sub: "あしたの朝に、今日の1枚がひらきます。")
        case 1: return Headline(kicker: "1こま、撮りました。", title: "今日は、あと2こま。", circled: "2", sub: "あしたの朝 9:00 に、まとめてひらきます。")
        case 2: return Headline(kicker: "2こま、撮りました。", title: "今日は、あと1こま。", circled: "1", sub: "あしたの朝 9:00 に、まとめてひらきます。")
        default: return Headline(kicker: "3こま、撮りました。", title: "今日は、ここまで。", circled: nil, sub: "あしたの 9:00 に、ひらきます。")
        }
    }

    /// 1まいめの下の マスキングテープのラベル
    static func tapeLabel(shots: Int) -> String? {
        switch shots {
        case 0: return "最初の1枚に、なります"
        case 1, 2: return "今日の1枚"
        default: return nil
        }
    }

    /// 洗濯ひものたるみ(見本:M0 8 Q195 48 390 8)
    static func sag(_ t: Double) -> Double { (1 - t) * (1 - t) * 8 + 2 * t * (1 - t) * 48 + t * t * 8 }
    static let chekiCenters: [Double] = [66, 195, 324].map { $0 / 390 }
    static let chekiTilts: [Double] = [-6, 2.5, 6]
    /// 世界の光:輪の半径(58 → 165・8.2 ずつ)
    static let ringRadii: [Double] = Array(stride(from: 58.0, through: 165.0, by: 8.2))
    static let wavePeriod: Double = 5.2
}

/// 1画面目(ヒーロー)。高さは画面ひとつぶん
struct HomeV21Hero: View {
    let state: HomeState
    let now: Date
    let shots: [Date]
    var videoDurations: [Date: Double] = [:]
    let width: CGFloat
    let height: CGFloat
    /// ヘッダーの下端(洗濯ひもは、これより下)
    var headerBottom: CGFloat = 0
    let isActive: Bool
    /// 撮ったあと・オープニングのあと、登場のアニメーションを流す
    let introToken: Int
    let onShoot: () -> Void
    let onOrb: () -> Void
    let onToast: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var intro: Double = 1
    @State private var swings: [Int: Int] = [:]

    private var k: CGFloat { width / 390 }
    private var ky: CGFloat { max(0.78, height / 844) }
    private var landing: FilmLanding { FilmLanding.shared }

    var body: some View {
        let headline = HomeV21Rules.headline(shots: shownShots.count, state: state)
        ZStack(alignment: .topLeading) {
            // 世界の光(中心 y = 335)
            HomeWorldLights(colored: !shots.isEmpty, reveal: intro, isActive: isActive && !reduceMotion, dateText: HomeV17Rules.dotDate(now))
                .frame(width: 390, height: 390)
                .scaleEffect(min(1, k))
                .position(x: width / 2, y: 335 * ky)
                .contentShape(Circle().inset(by: 110))
                .onTapGesture(perform: onOrb)
                .accessibilityLabel("世界の光。きのう撮られた写真")
                .accessibilityAddTraits(.isButton)
            stickers
            clothesline
            headlineBlock(headline)
                .frame(width: width)
                .position(x: width / 2, y: 530 * ky + 70)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .onChange(of: introToken) { _, _ in playIntro() }
        .onChange(of: landing.landedToken) { _, _ in
            if let index = landing.landedIndex { swings[index, default: 0] += 1 }
        }
        .onChange(of: shots.count) { _, count in
            if let pending = landing.pending, count > pending.index { landing.pending = nil; landing.landedIndex = nil }
        }
    }

    private var shownShots: [Date] {
        guard let pending = landing.pending, pending.index >= shots.count, pending.index < 3 else { return shots }
        return shots + [Date()]
    }

    // MARK: 洗濯ひもと チェキ

    private var clothesline: some View {
        let frames = HomeV17Rules.filmFrames(shots: shownShots, state: state)
        let top = max(170 * ky, headerBottom + 18)
        return ZStack(alignment: .topLeading) {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 8))
                p.addQuadCurve(to: CGPoint(x: width, y: 8), control: CGPoint(x: width / 2, y: 48))
            }
            .stroke(Color(hex: "111111"), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
            ForEach(frames) { frame in
                let t = HomeV21Rules.chekiCenters[frame.index]
                let y = HomeV21Rules.sag(t) + 2
                HomeV21Cheki(frame: frame, duration: duration(frame), tilt: HomeV21Rules.chekiTilts[frame.index], tape: frame.index == 0 ? HomeV21Rules.tapeLabel(shots: shownShots.count) : nil, bob: !reduceMotion && isActive)
                    .opacity(isFlying(frame.index) ? 0 : 1)
                    .keyframeAnimator(initialValue: 0.0, trigger: swings[frame.index, default: 0]) { content, extra in
                        content.rotationEffect(.degrees(extra), anchor: UnitPoint(x: 0.5, y: -0.05))
                    } keyframes: { _ in
                        KeyframeTrack {
                            CubicKeyframe(12, duration: 0.195); CubicKeyframe(-8, duration: 0.26); CubicKeyframe(5, duration: 0.26)
                            CubicKeyframe(-2.5, duration: 0.26); CubicKeyframe(0, duration: 0.325)
                        }
                    }
                    .offset(y: intro < 1 ? -70 * (1 - dropProgress(frame.index)) : 0)
                    .opacity(intro < 1 ? dropProgress(frame.index) : 1)
                    .position(x: width * t, y: y + 82)
                    .onTapGesture { tap(frame) }
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rect in
                        landing.slotFrames[frame.index] = rect
                    }
            }
        }
        .frame(width: width, height: 250)
        .offset(y: top)
    }

    private func duration(_ frame: HomeV17Rules.FilmFrame) -> Double? {
        guard case .shot(let index, let takenAt) = frame else { return nil }
        if let d = videoDurations[takenAt] { return d }
        if let pending = landing.pending, pending.index == index, pending.isVideo { return pending.duration }
        return nil
    }

    private func isFlying(_ index: Int) -> Bool {
        guard let pending = landing.pending else { return false }
        return pending.index == index && landing.landedIndex != index
    }

    private func tap(_ frame: HomeV17Rules.FilmFrame) {
        swings[frame.index, default: 0] += 1
        switch frame {
        case .shot:
            Haptics.play(.pop)
            onToast(duration(frame) != nil ? "動画は あしたの 9:00 に、ひらきます" : "9:00 に、仕上がります")
        case .next:
            Haptics.play(.click)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onShoot() }
        case .later, .rest:
            Haptics.play(.warn)
        }
    }

    // MARK: 見出し

    private func headlineBlock(_ h: HomeV21Rules.Headline) -> some View {
        VStack(spacing: 0) {
            Text(h.kicker)
                .font(.system(size: 17, weight: .heavy)).tracking(0.02 * 17)
                .foregroundStyle(Color(hex: "3A3A3F"))
                .opacity(stage(0.82))
                .offset(y: 12 * (1 - stage(0.82)))
            HomeMisprintHeadline(text: h.title, circled: h.circled, drawCircle: stage(1.5), width: width - 40)
                .padding(.top, 4)
                .opacity(stage(0.9))
            Text(h.sub)
                .font(.system(size: 13, weight: .medium)).tracking(0.02 * 13)
                .foregroundStyle(Color(hex: "8E8E93"))
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .opacity(stage(1.5))
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: ステッカー

    private var stickers: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !isActive || reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .topLeading) {
                sticker(V17Sticker(kind: .star, size: 40), x: 20 + 20, y: 206, t: t, period: 5, phase: 0)
                sticker(V17Sticker(kind: .flower, size: 44), x: width - 22 - 22, y: 474, t: t, period: 7, phase: 2)
            }
        }
        .allowsHitTesting(false)
        .opacity(stage(1.0))
    }

    private func sticker<V: View>(_ view: V, x: CGFloat, y: CGFloat, t: Double, period: Double, phase: Double) -> some View {
        let s = reduceMotion ? 0 : sin((t + phase) * 2 * .pi / period)
        return view
            .rotationEffect(.degrees(10 * s))
            .offset(y: -8 * s)
            .position(x: x, y: y * ky)
    }

    // MARK: 登場(オープニングのあと)

    /// 0〜1 の全体の進み(intro × 2.6秒 を見本の時刻にあわせる)
    private func stage(_ start: Double) -> Double {
        guard intro < 1 else { return 1 }
        let t = intro * 2.6
        return min(1, max(0, (t - start) / 0.5))
    }

    private func dropProgress(_ index: Int) -> Double {
        guard intro < 1 else { return 1 }
        let t = intro * 2.6
        let start = 0.3 + Double(index) * 0.13
        return min(1, max(0, (t - start) / 0.6))
    }

    private func playIntro() {
        guard !reduceMotion else {
            intro = 0
            withAnimation(.easeOut(duration: 0.3)) { intro = 1 }
            return
        }
        intro = 0
        withAnimation(.linear(duration: 2.6)) { intro = 1 }
        for i in 0..<3 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.7 + Double(i) * 0.13) { Haptics.play(.land, gap: 0) } }
    }
}

/// ホームのチェキ(幅 108・ふち 8・下 32・窓 116)
private struct HomeV21Cheki: View {
    let frame: HomeV17Rules.FilmFrame
    let duration: Double?
    let tilt: Double
    let tape: String?
    let bob: Bool

    var body: some View {
        let isNext: Bool = { if case .next = frame { return true } else { return false } }()
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !(bob && isNext))) { context in
            let s = bob && isNext ? sin(context.date.timeIntervalSinceReferenceDate * 2 * .pi / 4.2) : 0
            card
                .scaleEffect(isNext ? 1.07 : 1)
                .rotationEffect(.degrees(tilt + 1.8 * (s + 1) / 2), anchor: UnitPoint(x: 0.5, y: -0.05))
                .offset(y: -5 * (s + 1) / 2)
        }
    }

    private var card: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                window.frame(width: 92, height: 116).clipShape(RoundedRectangle(cornerRadius: 2))
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(width: 108, height: 156)
            .background(RoundedRectangle(cornerRadius: 3).fill(.white))
            .overlay(alignment: .bottomLeading) {
                if let word = caption {
                    Text(word).font(.system(size: 12, design: .serif).italic()).foregroundStyle(Color(hex: "8E8E93")).padding(.leading, 9).padding(.bottom, 9)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if let duration {
                    Text("▶ \(MilkCheki.durationText(duration))").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Color(hex: "FF8A2A")).padding(.trailing, 9).padding(.bottom, 9)
                } else if case .shot(_, let takenAt) = frame {
                    Text(takenAt.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                        .font(.custom("Caveat-Bold", size: 17)).foregroundStyle(Color(hex: "3A3A3C")).padding(.trailing, 9).padding(.bottom, 6)
                }
            }
            .shadow(color: shadow, radius: 14, y: 16)
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.black.opacity(0.04), lineWidth: 1))
            V17Tape(width: 36, height: 15).rotationEffect(.degrees(-4)).offset(y: -11)
            if let tape {
                Text(tape)
                    .font(.system(size: 11, weight: .heavy)).tracking(0.02 * 11)
                    .foregroundStyle(Color(hex: "3A2A10"))
                    .frame(width: 152, height: 25)
                    .background(V17Tape(width: 152, height: 25, stripe: 5).clipShape(ZigzagEnds()))
                    .rotationEffect(.degrees(-3))
                    .offset(y: 156 + 26 - 12)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var caption: String? {
        switch frame {
        case .shot: return duration == nil ? "today" : nil
        case .next: return "next"
        default: return nil
        }
    }

    private var label: String {
        switch frame {
        case .shot: return duration == nil ? "撮った写真。9:00 に、仕上がります" : "動画。あしたの 9:00 に、ひらきます"
        case .next: return "撮る"
        default: return "あとで"
        }
    }

    private var shadow: Color {
        if case .next = frame { return Color(red: 1, green: 0.42, blue: 0.1).opacity(0.5) }
        return Color(red: 0.16, green: 0.08, blue: 0.04).opacity(0.3)
    }

    @ViewBuilder
    private var window: some View {
        switch frame {
        case .shot:
            // ミルク色の 磨りガラス(中身は見せない)
            ZStack {
                RadialGradient(colors: [Color(hex: "FFB27A"), .clear], center: UnitPoint(x: 0.3, y: 0.3), startRadius: 0, endRadius: 60)
                RadialGradient(colors: [Color(hex: "9C86FF"), .clear], center: UnitPoint(x: 0.7, y: 0.7), startRadius: 0, endRadius: 60)
            }
            .background(Color(hex: "3A2A40"))
            .blur(radius: 8)
            .overlay(LinearGradient(colors: [Color(hex: "DDE6E2"), Color(hex: "C9D3E0")], startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.9))
            .overlay { if duration != nil { HStack { MEFilmHoles(); Spacer(); MEFilmHoles() } } }
        case .next:
            VStack(spacing: 4) {
                Image(systemName: "plus").font(.system(size: 20, weight: .bold))
                Text("撮る").font(.system(size: 13, weight: .heavy))
            }
            .foregroundStyle(Color(hex: "111111"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RadialGradient(stops: [
                .init(color: Color(hex: "FFB27A"), location: 0), .init(color: Color(hex: "FFD6BE"), location: 0.38), .init(color: Color(hex: "FBF7F0"), location: 0.72),
            ], center: UnitPoint(x: 0.5, y: 1.18), startRadius: 0, endRadius: 120))
        case .later, .rest:
            Text("あとで").font(.system(size: 12, weight: .medium)).foregroundStyle(Color(hex: "B9B6C0"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "FBF9F4"))
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color(hex: "D0CDD6"), style: StrokeStyle(lineWidth: 1.4, dash: [4, 3])))
        }
    }
}

/// テープの ふちを ギザギザに
private struct ZigzagEnds: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.02, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.02, y: r.midY))
        p.closeSubpath()
        return p
    }
}

/// 見出し:Black 42pt・字間 -5%・印刷ズレ(橙 30% を右下へ 1.6pt・青 22% を左上へ 1.2pt)・手書きの丸
struct HomeMisprintHeadline: View {
    let text: String
    let circled: String?
    /// 丸を描く進み 0〜1(0.76秒)
    let drawCircle: Double
    let width: CGFloat

    var body: some View {
        let size = min(42, width / (CGFloat(text.count) * 0.93))
        let parts = split()
        HStack(spacing: 0) {
            if !parts.pre.isEmpty { glyphs(parts.pre, size) }
            if let hit = parts.hit {
                glyphs(hit, size)
                    .overlay {
                        HandCircle()
                            .trim(from: 0, to: drawCircle)
                            .stroke(Color(hex: "F26A1B"), style: StrokeStyle(lineWidth: 3.6, lineCap: .round))
                            .padding(.horizontal, -9)
                            .padding(.vertical, -size * 0.12)
                    }
            }
            if !parts.post.isEmpty { glyphs(parts.post, size) }
        }
        .fixedSize()
        .accessibilityLabel(text)
    }

    private func glyphs(_ s: String, _ size: CGFloat) -> some View {
        let base = Text(s).font(.system(size: size, weight: .black)).tracking(-0.05 * size)
        return ZStack {
            base.foregroundStyle(Color(red: 1, green: 0.42, blue: 0.1).opacity(0.30)).offset(x: 1.6, y: 1)
            base.foregroundStyle(Color(red: 0.35, green: 0.43, blue: 1).opacity(0.22)).offset(x: -1.2, y: -0.4)
            base.foregroundStyle(Color(hex: "111111"))
        }
    }

    private func split() -> (pre: String, hit: String?, post: String) {
        guard let circled, let r = text.range(of: circled) else { return (text, nil, "") }
        return (String(text[..<r.lowerBound]), circled, String(text[r.upperBound...]))
    }
}

/// 手書きの丸(見本:M82 5C128 1 158 14 155 34 152 54 112 63 74 60 30 57 3 48 5 28 7 11 42 3 100 7 ・ 160×64)
struct HandCircle: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 160, sy = rect.height / 64
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var path = Path()
        path.move(to: p(82, 5))
        path.addCurve(to: p(155, 34), control1: p(128, 1), control2: p(158, 14))
        path.addCurve(to: p(74, 60), control1: p(152, 54), control2: p(112, 63))
        path.addCurve(to: p(5, 28), control1: p(30, 57), control2: p(3, 48))
        path.addCurve(to: p(100, 7), control1: p(7, 11), control2: p(42, 3))
        return path
    }
}

/// 世界の光:ドットの同心円(約 900 点・輪ごとに まわる向きが ぎゃく)・5.2秒ごとの光の波・1まい撮ったら色がつく・文字の輪(200秒で一周)。
/// 数字は出さない。画面の外・低電力モード・視差を減らす では止めて 1枚絵
struct HomeWorldLights: View {
    let colored: Bool
    /// 0〜1(中心から ひらく)
    let reveal: Double
    let isActive: Bool
    let dateText: String

    private struct Dot {
        let r: Double, a: Double, w: Double, s: Double, tw: Double, c: Double
    }

    private static let dots: [Dot] = {
        var rng = SeededRandom(seed: 21)
        func rand() -> Double { Double(rng.next() % 10_000) / 10_000 }
        var list: [Dot] = []
        let maxR = HomeV21Rules.ringRadii.last ?? 165
        for (ring, r) in HomeV21Rules.ringRadii.enumerated() {
            let n = Int((2 * Double.pi * r / 9.4).rounded())
            let dir: Double = ring % 2 == 1 ? 1 : -1
            for i in 0..<n {
                list.append(Dot(r: r, a: Double(i) / Double(n) * 2 * .pi, w: dir * (0.00004 + (maxR - r) * 0.0000012) * 1000,
                                s: 0.55 + rand() * 1.1 + (r / maxR) * 0.6, tw: rand() * 6.3, c: rand()))
            }
        }
        return list
    }()

    private static let palette: [Color] = [Color(red: 1, green: 0.54, blue: 0.16), Color(red: 1, green: 0.77, blue: 0.24), Color(red: 1, green: 0.47, blue: 0.63), Color(red: 0.43, green: 0.59, blue: 1), Color(red: 0.67, green: 0.51, blue: 1)]

    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    var body: some View {
        let running = isActive && !lowPower
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !running)) { context in
            let t = running ? context.date.timeIntervalSinceReferenceDate : 0
            ZStack {
                Canvas { ctx, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let maxR = HomeV21Rules.ringRadii.last ?? 165
                    let wave = (t.truncatingRemainder(dividingBy: HomeV21Rules.wavePeriod) / HomeV21Rules.wavePeriod) * (maxR + 34)
                    var gray = Path(), orange = Path(), ink = Path()
                    var colorPaths = [Path](repeating: Path(), count: 5)
                    for d in Self.dots {
                        guard d.r <= reveal * (maxR + 2) else { continue }
                        let an = d.a + t * d.w
                        let x = c.x + cos(an) * d.r, y = c.y + sin(an) * d.r
                        let b = exp(-pow((d.r - wave) / 11, 2))
                        var s = d.s * (1 + 1.1 * b)
                        if colored && d.c > 0.82 {
                            s *= 1.25
                            colorPaths[Int(d.c * 50) % 5].addEllipse(in: CGRect(x: x - s, y: y - s, width: 2 * s, height: 2 * s))
                        } else if d.c > 0.94 {
                            s *= 1.15
                            ink.addEllipse(in: CGRect(x: x - s, y: y - s, width: 2 * s, height: 2 * s))
                        } else if b > 0.12 {
                            orange.addEllipse(in: CGRect(x: x - s, y: y - s, width: 2 * s, height: 2 * s))
                        } else {
                            gray.addEllipse(in: CGRect(x: x - s, y: y - s, width: 2 * s, height: 2 * s))
                        }
                    }
                    ctx.fill(gray, with: .color(Color(red: 0.53, green: 0.52, blue: 0.57).opacity(0.42)))
                    ctx.fill(ink, with: .color(Color(red: 0.07, green: 0.07, blue: 0.08).opacity(0.55)))
                    ctx.fill(orange, with: .color(Color(red: 1, green: 0.54, blue: 0.16).opacity(0.85)))
                    for (i, path) in colorPaths.enumerated() { ctx.fill(path, with: .color(Self.palette[i].opacity(0.85))) }
                }
                // 文字の輪(200秒で一周)
                RingText(text: "LATER — WORLD LIGHTS — YESTERDAY — \(dateText) — ", radius: 182)
                    .rotationEffect(.degrees((t.truncatingRemainder(dividingBy: 200) / 200) * 360))
                    .opacity(reveal)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .accessibilityHidden(true)
    }
}

/// 円に沿った文字(等幅 8.5pt・灰)
private struct RingText: View {
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
                inner.draw(Text(String(ch)).font(.system(size: 8.5, design: .monospaced)).foregroundColor(Color(hex: "A9A6B0")), at: .zero)
            }
        }
        .frame(width: 390, height: 390)
    }
}

/// 地(じ):あたたかい白い紙 #FFFDFA + 光のにじみ 2つ(右上 橙・左下 藤)+ 左のふちのフィルムの番号
struct HomeV21Paper: View {
    let isActive: Bool
    let height: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15, paused: !isActive || reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let a = (1 - cos(t * 2 * .pi / 14)) / 2, b = (1 - cos(t * 2 * .pi / 17)) / 2
            ZStack(alignment: .topLeading) {
                Color(hex: "FFFDFA")
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.67, blue: 0.47).opacity(0.34), .clear], center: .center, startRadius: 0, endRadius: 190 * 0.68 * 1.47))
                    .frame(width: 380, height: 380)
                    .scaleEffect(1 + 0.12 * a)
                    .offset(x: 26 * a, y: 34 * a)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .offset(x: 120, y: 40)
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 0.75, green: 0.63, blue: 1).opacity(0.26), .clear], center: .center, startRadius: 0, endRadius: 190 * 0.68 * 1.47))
                    .frame(width: 380, height: 380)
                    .scaleEffect(1 + 0.12 * b)
                    .offset(x: -150 + 26 * b, y: 360 + 34 * b)
            }
        }
        .overlay(alignment: .topLeading) {
            Text("LATER 400 ・ 1 ▸ 2 ▸ 3 ▸ 4 ▸ 5 ▸ 6 ▸ 7 ▸ 8 ▸ 9 ▸ 10 ▸ 11 ▸ 11A ▸ 12")
                .font(.system(size: 7.5, design: .monospaced)).tracking(0.34 * 7.5)
                .foregroundStyle(Color(hex: "C9C6CF"))
                .fixedSize()
                .rotationEffect(.degrees(90), anchor: .topLeading)
                .offset(x: 14, y: 196)
        }
        .overlay { GrainView(seed: 7).opacity(0.07).blendMode(.multiply) }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// スクロールした先:グループ(Black 34pt)と、2つの大きなタイル(高さ 178・角 34)
struct HomeV21Groups: View {
    let summaries: [GroupSummary]
    let canCreate: Bool
    let isFrontmost: Bool
    let shotsToday: Int
    let onSelect: (UUID) -> Void
    let onCreate: () -> Void
    let onJoin: () -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("グループ").font(.system(size: 34, weight: .black)).tracking(-0.05 * 34).foregroundStyle(Color(hex: "111111")).padding(.leading, 24)
            if summaries.isEmpty {
                HStack(spacing: 14) {
                    tile(dark: true, icon: "plus", title: "つくる", note: "4〜8人のグループ", action: onCreate)
                    tile(dark: false, icon: "qrcode", title: "参加する", note: "合言葉・QR・リンク", action: onJoin)
                }
                .padding(.horizontal, 22)
            } else {
                HomeGroupStrip(summaries: summaries, canCreate: canCreate, isFrontmost: isFrontmost, entranceStart: nil,
                               onSelect: onSelect, onCreate: onCreate, onJoin: onJoin, onAdd: onAdd, arrivingID: nil, shotsToday: shotsToday)
            }
        }
    }

    private func tile(dark: Bool, icon: String, title: String, note: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Spacer(minLength: 0)
                Text(title).font(.system(size: 25, weight: .black)).tracking(-0.03 * 25).foregroundStyle(dark ? .white : Color(hex: "111111"))
                Text(note).font(.system(size: 12.5, weight: .medium)).foregroundStyle(dark ? Color(hex: "A7A7B2") : Color(hex: "8E8E93"))
            }
            .padding(22)
            .frame(maxWidth: .infinity, minHeight: 178, maxHeight: 178, alignment: .leading)
            .overlay(alignment: .topLeading) {
                Image(systemName: icon).font(.system(size: 22, weight: .bold))
                    .foregroundStyle(dark ? .white : Color(hex: "111111"))
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(dark ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "FFB05A"), Color(hex: "FF5A7A")], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color(hex: "EEEDF3"))))
                    .shadow(color: dark ? Color(red: 1, green: 0.35, blue: 0.4).opacity(0.4) : .clear, radius: 8, y: 6)
                    .padding(22)
            }
            .background(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(dark
                ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "17171C"), Color(hex: "2A2433")], startPoint: .topLeading, endPoint: .bottomTrailing))
                : AnyShapeStyle(LinearGradient(colors: [.white, Color(hex: "F6F4FB")], startPoint: .topLeading, endPoint: .bottomTrailing))))
            .overlay { if !dark { RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(Color(hex: "D5D3DE"), lineWidth: 2) } }
            .shadow(color: dark ? Color(red: 0.12, green: 0.08, blue: 0.16).opacity(0.55) : .clear, radius: 20, y: 20)
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
        .accessibilityLabel("\(title)。\(note)")
    }
}
