import SwiftUI

// v17 の区画(A〜G)。見た目の数字は見本(Docs/Mocks/later_home_v17_scroll.html の v17css)にそろえる。

// MARK: - 色と字

/// 区画の色。昼は見本どおり(白・#F3F3F6・#111・#FF6A1A)。夜(21:00〜9:00)は黒地に白
struct V17Ink {
    let night: Bool

    var ink: Color { night ? .white : Color(hex: "111111") }
    /// 夜の 小さな 説明は #A1A1A8 より 暗くしない(背景が ほぼ黒)
    var sub: Color { night ? Color(hex: "A1A1A8") : Color(hex: "8E8E93") }
    var body: Color { night ? Color.white.opacity(0.62) : Color(hex: "6E6E73") }
    var text: Color { night ? Color.white.opacity(0.82) : Color(hex: "3A3A3C") }
    var faint: Color { night ? Color.white.opacity(0.3) : Color(hex: "AEAEB2") }
    var fill: Color { night ? Color.white.opacity(0.08) : Color(hex: "F3F3F6") }
    var card: Color { night ? Color.white.opacity(0.05) : .white }
    var line: Color { night ? Color.white.opacity(0.1) : Color(hex: "F0F0F3") }
    /// 黒いボタン(夜は白いボタン)
    var button: Color { night ? .white : Color(hex: "111111") }
    var onButton: Color { night ? Color(hex: "111111") : .white }
    static let orange = Color(hex: "FF6A1A")
    static let rainbow: [Color] = ["FFC9A8", "FFB3D1", "C9B2FF", "A8D8FF", "B8F0C8"].map { Color(hex: $0) }
    /// 見本の写真の色(scene)
    static let scene: [Color] = [Color(red: 1, green: 0.62, blue: 0.37), Color(red: 0.25, green: 0.66, blue: 1),
                                 Color(red: 1, green: 0.81, blue: 0.37), Color(red: 1, green: 0.48, blue: 0.66),
                                 Color(red: 0.55, green: 0.84, blue: 0.67)]
}

enum V17Font {
    static func mono(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .monospaced) }
    static func serif(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif).italic() }
    static func hand(_ size: CGFloat) -> Font { .custom("Caveat-Bold", size: size) }
}

// MARK: - 区画の見出し

/// オレンジの点 + 英字の小見出し / 日本語の見出し(英字だけ斜体)/ 右はしの手書きの数字
struct V17SectionHeader: View {
    let kicker: String
    let title: String
    var accent: String?
    var number: String?
    let ink: V17Ink

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Circle().fill(V17Ink.orange).frame(width: 6, height: 6)
                Text(kicker.uppercased())
                    .font(V17Font.mono(9.5))
                    .tracking(0.2 * 9.5)
                    .foregroundStyle(ink.sub)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                titleText
                    .font(.system(size: 25, weight: .heavy))
                    .tracking(-0.035 * 25)
                    .lineSpacing(2)
                    .foregroundStyle(ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if let number {
                    Text(number)
                        .font(V17Font.hand(30))
                        .foregroundStyle(V17Ink.orange)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .padding(.bottom, 9)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var titleText: Text {
        guard let accent else { return Text(title) }
        return Text("\(title)\(Text(" " + accent).font(V17Font.serif(28)).foregroundColor(ink.body))")
    }
}

// MARK: - 出てくる動き(12% 見えたら、下から 26pt・0.7秒。1回だけ)

private struct V17Reveal: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        let visible = shown || reduceMotion
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : HomeV17Rules.revealDistance)
            .onScrollVisibilityChange(threshold: HomeV17Rules.revealThreshold) { isVisible in
                guard isVisible, !shown else { return }
                withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.8)) { shown = true }
            }
    }
}

extension View {
    func v17Reveal() -> some View { modifier(V17Reveal()) }

    /// 触ったところが、こまかく揺れる(0.22秒)
    func v17Jolt(_ trigger: Int) -> some View {
        keyframeAnimator(initialValue: CGSize.zero, trigger: trigger) { content, offset in
            content.offset(offset)
        } keyframes: { _ in
            KeyframeTrack(\.width) {
                LinearKeyframe(-2, duration: 0.044)
                LinearKeyframe(2, duration: 0.044)
                LinearKeyframe(-1.5, duration: 0.044)
                LinearKeyframe(1, duration: 0.044)
                LinearKeyframe(0, duration: 0.044)
            }
            KeyframeTrack(\.height) {
                LinearKeyframe(1, duration: 0.044)
                LinearKeyframe(-1, duration: 0.044)
                LinearKeyframe(0, duration: 0.044)
                LinearKeyframe(1, duration: 0.044)
                LinearKeyframe(0, duration: 0.044)
            }
        }
    }
}

/// ためている間、中身ぜんぶを こまかく揺らす(視差効果を減らす のときは揺らさない)
struct V17Rattle: ViewModifier {
    let feel: HomeV17Feel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let amplitude = reduceMotion ? 0 : HomeV17Rules.rattleAmplitude(feel.rattle)
        TimelineView(.animation(minimumInterval: 1.0 / 25.0, paused: amplitude == 0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            // 80ms で1往復(見本の v7rat)
            let s = sin(t * 2 * .pi / 0.08)
            content.offset(x: amplitude == 0 ? 0 : -amplitude * s, y: amplitude == 0 ? 0 : amplitude * 0.5 * s)
        }
    }
}

// MARK: - ステッカー(見本の DOO:星・花・太陽)

enum V17StickerKind { case star, flower, sun }

struct V17Sticker: View {
    let kind: V17StickerKind
    var size: CGFloat = 30

    var body: some View {
        Canvas { context, canvas in
            let k = canvas.width / 40
            context.scaleBy(x: k, y: k)
            let ink = Color(hex: "111111")
            switch kind {
            case .star:
                var path = Path()
                path.move(to: CGPoint(x: 20, y: 3.5))
                path.addCurve(to: CGPoint(x: 35.5, y: 19.8), control1: CGPoint(x: 21.6, y: 11.1), control2: CGPoint(x: 25.2, y: 15.1))
                path.addCurve(to: CGPoint(x: 20.1, y: 36.5), control1: CGPoint(x: 25.3, y: 23.4), control2: CGPoint(x: 21.6, y: 27.7))
                path.addCurve(to: CGPoint(x: 4, y: 19.9), control1: CGPoint(x: 18.2, y: 27.7), control2: CGPoint(x: 14.5, y: 23.5))
                path.addCurve(to: CGPoint(x: 20, y: 3.5), control1: CGPoint(x: 14.3, y: 15.5), control2: CGPoint(x: 18.2, y: 11.3))
                path.closeSubpath()
                context.fill(path, with: .color(Color(hex: "FFD60A")))
                context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 2.3, lineJoin: .round))
            case .flower:
                for angle in stride(from: 0.0, to: 360.0, by: 72.0) {
                    var petal = Path(ellipseIn: CGRect(x: 13.5, y: 2, width: 13, height: 16))
                    petal = petal.applying(CGAffineTransform(translationX: -20, y: -20).concatenating(CGAffineTransform(rotationAngle: angle * .pi / 180)).concatenating(CGAffineTransform(translationX: 20, y: 20)))
                    context.fill(petal, with: .color(Color(hex: "FF5DA2")))
                    context.stroke(petal, with: .color(ink), lineWidth: 2.2)
                }
                let center = Path(ellipseIn: CGRect(x: 14.5, y: 14.5, width: 11, height: 11))
                context.fill(center, with: .color(Color(hex: "FFD60A")))
                context.stroke(center, with: .color(ink), lineWidth: 2.2)
            case .sun:
                for angle in stride(from: 0.0, to: 360.0, by: 45.0) {
                    var ray = Path()
                    ray.move(to: CGPoint(x: 20, y: 3))
                    ray.addLine(to: CGPoint(x: 20, y: 8))
                    ray = ray.applying(CGAffineTransform(translationX: -20, y: -20).concatenating(CGAffineTransform(rotationAngle: angle * .pi / 180)).concatenating(CGAffineTransform(translationX: 20, y: 20)))
                    context.stroke(ray, with: .color(ink), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                }
                let disc = Path(ellipseIn: CGRect(x: 11, y: 11, width: 18, height: 18))
                context.fill(disc, with: .color(Color(hex: "FFD60A")))
                context.stroke(disc, with: .color(ink), lineWidth: 2.3)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 黄色いマスキングテープ
struct V17Tape: View {
    var width: CGFloat = 34
    var height: CGFloat = 15
    var stripe: CGFloat = 4

    var body: some View {
        Canvas { context, size in
            var x: CGFloat = 0
            var odd = false
            while x < size.width {
                context.fill(Path(CGRect(x: x, y: 0, width: stripe, height: size.height)), with: .color(Color(hex: odd ? "FFE874" : "FFD60A")))
                x += stripe
                odd.toggle()
            }
        }
        .frame(width: width, height: height)
        .opacity(0.92)
        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
        .accessibilityHidden(true)
    }
}

/// 見本の写真の色(ぼかした色の重なり)。本物の写真は使わない
struct V17Scene: View {
    let seed: Int

    var body: some View {
        let a = V17Ink.scene[seed % 5], b = V17Ink.scene[(seed + 1) % 5], c = V17Ink.scene[(seed + 2) % 5]
        ZStack {
            LinearGradient(colors: [Color(hex: "F3F3F6"), Color(hex: "E6E6EB")], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [c.opacity(0.8), c.opacity(0)], center: UnitPoint(x: 0.5, y: 0.9), startRadius: 0, endRadius: 50)
            RadialGradient(colors: [b.opacity(0.9), b.opacity(0)], center: UnitPoint(x: CGFloat(70 - seed * 5 % 20) / 100, y: CGFloat(62 + seed * 3 % 15) / 100), startRadius: 0, endRadius: 60)
            RadialGradient(colors: [a.opacity(0.95), a.opacity(0)], center: UnitPoint(x: CGFloat(24 + seed * 7 % 30) / 100, y: CGFloat(30 + seed * 11 % 25) / 100), startRadius: 0, endRadius: 55)
        }
    }
}

/// 乳白色のもや(見本の devFx の milk)。d = 現像の濃さ 0〜1
struct V17Milk: View {
    let density: Double

    var body: some View {
        LinearGradient(colors: [Color(hex: "D3E0D8"), Color(hex: "BFD0E0")], startPoint: UnitPoint(x: 0.33, y: 0), endPoint: UnitPoint(x: 0.67, y: 1))
            .opacity(pow(1 - min(1, max(0, density)), 0.8) * 0.94)
    }
}

// MARK: - A 今日の film

struct V17FilmSection: View {
    let state: HomeState
    let now: Date
    let shots: [Date]
    var videoDurations: [Date: Double] = [:]
    let ink: V17Ink
    let actions: HomeV17Actions

    @State private var swings: [Int: Int] = [:]
    /// 数と「のこり」は FilmCounter だけを見る
    private let film = FilmCounter.shared

    /// 動画のこまの長さ(とんでいる最中の こまは、引きついだ長さ)
    private func videoDuration(_ frame: HomeV17Rules.FilmFrame) -> Double? {
        guard case .shot(let index, let takenAt) = frame else { return nil }
        if let d = videoDurations[takenAt] { return d }
        if let pending = landing.pending, pending.index == index, pending.isVideo { return pending.duration }
        return nil
    }
    private var landing: FilmLanding { FilmLanding.shared }

    /// 撮ったばかりで、まだ保存が終わっていない こまも、ミルク色の「撮った」として出す
    private var shownShots: [Date] {
        guard let pending = landing.pending, pending.index >= shots.count, pending.index < 3 else { return shots }
        return shots + [Date()]
    }

    private var frames: [HomeV17Rules.FilmFrame] { HomeV17Rules.filmFrames(shots: shownShots, state: state, canShootMore: film.remaining > 0) }

    /// とんでいる最中の こまは、まだ出さない(とんでいるチェキと重ならないように)
    private func isFlying(_ index: Int) -> Bool {
        guard let pending = landing.pending else { return false }
        return pending.index == index && landing.landedIndex != index
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            V17SectionHeader(kicker: "TODAY'S FILM ・ \(HomeV17Rules.dotDate(HomeV17Rules.filmDay(now: now)))",
                             title: "今日の", accent: "film", number: "\(film.used) / 3", ink: ink)
            GeometryReader { proxy in
                let w = proxy.size.width
                ZStack(alignment: .topLeading) {
                    clothesline(width: w)
                    ForEach(frames) { frame in
                        let t = HomeV17Rules.filmCenters[frame.index]
                        let x = w * t
                        let y = HomeV17Rules.sag(t) + 4
                        cheki(frame)
                            .opacity(isFlying(frame.index) ? 0 : 1)
                            .keyframeAnimator(initialValue: 0.0, trigger: swings[frame.index, default: 0]) { content, extra in
                                content.rotationEffect(.degrees(HomeV17Rules.filmTilts[frame.index] + extra), anchor: UnitPoint(x: 0.5, y: -6.0 / 137.0))
                            } keyframes: { _ in
                                KeyframeTrack {
                                    CubicKeyframe(11, duration: 0.195)
                                    CubicKeyframe(-8, duration: 0.26)
                                    CubicKeyframe(5, duration: 0.26)
                                    CubicKeyframe(-2.5, duration: 0.26)
                                    CubicKeyframe(0, duration: 0.325)
                                }
                            }
                            .position(x: x, y: y + 137 / 2)
                    }
                }
            }
            .frame(height: 196)
            .padding(.horizontal, -6)
            .onChange(of: landing.landedToken) { _, _ in
                // テープでとまって、ゆらゆら揺れて止まる(1.3秒)
                if let index = landing.landedIndex { swings[index, default: 0] += 1 }
            }
            .onChange(of: shots.count) { _, count in
                // 保存が終わって、本物のこまが来たら、置いておいた こまを外す
                if let pending = landing.pending, count > pending.index { landing.pending = nil; landing.landedIndex = nil }
            }
            HStack {
                Text("撮った写真は、9:00 まで ミルク色")
                Spacer(minLength: 8)
                Text(state.isNight ? "NEXT ・ 9:00" : "のこり \(film.remaining)")
            }
            .font(V17Font.mono(9.5))
            .tracking(0.14 * 9.5)
            .foregroundStyle(ink.sub)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.top, 4)
        }
    }

    private func clothesline(width w: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 6))
                p.addQuadCurve(to: CGPoint(x: w, y: 6), control: CGPoint(x: w / 2, y: 40))
            }
            .stroke(ink.ink, style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
            Circle().fill(ink.ink).frame(width: 6, height: 6).position(x: 2, y: 6)
            Circle().fill(ink.ink).frame(width: 6, height: 6).position(x: w - 2, y: 6)
        }
        .accessibilityHidden(true)
    }

    private func cheki(_ frame: HomeV17Rules.FilmFrame) -> some View {
        Button { tap(frame) } label: {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    image(frame)
                        .frame(width: 84, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                    Spacer(minLength: 0)
                }
                .padding(7)
                .frame(width: 98, height: 137)
                .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Color.white))
                .overlay(alignment: .bottomLeading) { caption(frame) }
                .overlay(alignment: .bottomTrailing) { timeText(frame) }
                .shadow(color: shadowColor(frame), radius: 13, y: 14)
                .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(borderColor(frame), lineWidth: 1))
                V17Tape()
                    .rotationEffect(.degrees(-4))
                    .offset(y: -11)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label(frame))
    }

    @ViewBuilder
    private func image(_ frame: HomeV17Rules.FilmFrame) -> some View {
        switch frame {
        case .shot(let i, let takenAt) where videoDuration(frame) != nil:
            // 動画:穴あきのミルク色(撮った絵は見せない)
            MilkCheki(isVideo: true, duration: nil, stamp: "")
                .shadow(radius: 0)
                .padding(-7)
                .id("\(i)-\(takenAt.timeIntervalSinceReferenceDate)")
        case .shot(let i, let takenAt):
            let d = DevelopDensity.density(DevelopDensity.fraction(capturedAt: takenAt, now: now))
            ZStack {
                V17Scene(seed: 20 + i * 3)
                    .blur(radius: (1 - d) * 4 + 4)
                    .saturation(0.2 + 1.05 * d)
                    .contrast(0.7 + 0.4 * d)
                    .brightness(-0.15 * (1 - d))
                    .padding(-8)
                V17Milk(density: d)
            }
        case .next:
            VStack(spacing: 4) {
                Image(systemName: "plus").font(.system(size: 17, weight: .bold))
                Text("撮る").font(.system(size: 13, weight: .heavy))
            }
            .foregroundStyle(Color(hex: "111111"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color(hex: "111111"), style: StrokeStyle(lineWidth: 1.6, dash: [4, 3])))
        case .later:
            Text("あとで")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "AEAEB2"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color(hex: "C7C7CC"), style: StrokeStyle(lineWidth: 1.4, dash: [4, 3])))
        case .rest:
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
                var x: CGFloat = -size.height
                while x < size.width {
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: size.height))
                    p.addLine(to: CGPoint(x: x + size.height, y: 0))
                    context.stroke(p, with: .color(Color(hex: "F3F3F6")), lineWidth: 6)
                    x += 17
                }
            }
        }
    }

    @ViewBuilder
    private func caption(_ frame: HomeV17Rules.FilmFrame) -> some View {
        let word: String? = {
            switch frame {
            case .shot: return "today"
            case .next: return "next"
            case .rest: return "rest"
            case .later: return nil
            }
        }()
        if let word {
            Text(word).font(V17Font.serif(12)).foregroundStyle(Color(hex: "8E8E93")).padding(.leading, 9).padding(.bottom, 9)
        }
    }

    @ViewBuilder
    private func timeText(_ frame: HomeV17Rules.FilmFrame) -> some View {
        if let duration = videoDuration(frame) {
            Text("▶ \(MilkCheki.durationText(duration))")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "FF8A2A"))
                .padding(.trailing, 9)
                .padding(.bottom, 8)
        } else if case .shot(_, let takenAt) = frame {
            Text(takenAt.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                .font(V17Font.hand(17))
                .foregroundStyle(Color(hex: "3A3A3C"))
                .padding(.trailing, 9)
                .padding(.bottom, 6)
        }
    }

    private func shadowColor(_ frame: HomeV17Rules.FilmFrame) -> Color {
        if case .next = frame { return Color(red: 1, green: 0.42, blue: 0.1).opacity(0.45) }
        return Color(red: 0.16, green: 0.08, blue: 0.04).opacity(0.28)
    }

    private func borderColor(_ frame: HomeV17Rules.FilmFrame) -> Color {
        if case .next = frame { return V17Ink.orange.opacity(0.25) }
        return Color.black.opacity(0.035)
    }

    private func label(_ frame: HomeV17Rules.FilmFrame) -> String {
        switch frame {
        case .shot(let i, _): return "\(i + 1)こめ。9:00 に、仕上がります"
        case .next: return "撮る"
        case .later(let i): return "\(i + 1)こめ。あとで"
        case .rest(let i): return "\(i + 1)こめ。おやすみの時間"
        }
    }

    private func tap(_ frame: HomeV17Rules.FilmFrame) {
        swings[frame.index, default: 0] += 1
        switch frame {
        case .shot where videoDuration(frame) != nil:
            Haptics.play(.pop)
            actions.toast("動画は あしたの 9:00 に、ひらきます")
        case .shot:
            Haptics.play(.pop)
            actions.toast("9:00 に、仕上がります\nいまは、ミルクの中")
        case .next:
            Haptics.play(.click)
            if state.canShoot {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { actions.shoot() }
            } else {
                actions.toast("いまは、撮れません\n9:00 になると、また撮れます")
            }
        case .rest:
            Haptics.play(.double)
            actions.toast("おやすみの時間\n9:00 に、あたらしい3こま")
        case .later:
            Haptics.play(.double)
            actions.toast("つぎの1こまから\n順番に、撮れます")
        }
    }
}

// MARK: - B Later の1日

struct V17DaySection: View {
    let now: Date
    let ink: V17Ink

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// つまみの時刻(nil = いま)
    @State private var dragHour: Double?
    @State private var dragging = false
    @State private var returnTask: Task<Void, Never>?
    @State private var pillJolt = 0

    private var nowHour: Double { HomeV17Rules.hour(of: now) }
    private var hour: Double { dragHour ?? nowHour }

    var body: some View {
        let phase = HomeV17Rules.phase(hour: hour)
        VStack(alignment: .leading, spacing: 0) {
            V17SectionHeader(kicker: "A DAY ON LATER", title: "Later の1日", accent: "a day", number: "24h", ink: ink)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(HomeV17Rules.clockText(hour))
                            .font(.system(size: 50, weight: .heavy))
                            .tracking(-0.05 * 50)
                            .monospacedDigit()
                            .foregroundStyle(Color(hex: "111111"))
                        if abs(hour - nowHour) < 0.05 {
                            Text("now").font(V17Font.serif(18)).foregroundStyle(Color(hex: "8E8E93"))
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    Spacer(minLength: 8)
                    pill(phase)
                        .v17Jolt(pillJolt)
                        .padding(.top, 6)
                }
                Text(phase.detail)
                    .font(.system(size: 13, weight: .medium))
                    .lineSpacing(3)
                    .foregroundStyle(Color(hex: "3A3A3C"))
                    .frame(minHeight: 42, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .padding(.bottom, 18)
                track
                ticks.padding(.top, 9)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 18)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(ink.night ? Color.white.opacity(0.92) : Color(hex: "F3F3F6")))
            Text("つまみを 左右に うごかすと、1日の ながれが わかります。")
                .font(.system(size: 12.5, weight: .medium))
                .lineSpacing(4)
                .foregroundStyle(ink.body)
                .padding(.top, 12)
        }
        .onDisappear { returnTask?.cancel() }
    }

    private func pill(_ phase: HomeV17Rules.DayPhase) -> some View {
        let isNight = phase == .sleep || phase == .lightsOut
        let isOpen = phase == .open
        return HStack(spacing: 6) {
            Circle()
                .fill(isOpen ? Color.white : (isNight ? Color(hex: "6B5FC8") : V17Ink.orange))
                .frame(width: 6, height: 6)
            Text(phase.title)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
        }
        .foregroundStyle(isNight ? Color(hex: "111111") : .white)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Capsule().fill(isNight ? Color.white : (isOpen ? V17Ink.orange : Color(hex: "111111"))))
        .overlay { if isNight { Capsule().strokeBorder(Color(hex: "111111"), lineWidth: 1.4) } }
        .animation(.easeOut(duration: 0.25), value: phase)
        .fixedSize()
    }

    private var track: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(stops: [
                        .init(color: Color(hex: "24264F"), location: 0),
                        .init(color: Color(hex: "4A4AA0"), location: 0.30),
                        .init(color: Color(hex: "FF9A5A"), location: 0.375),
                        .init(color: Color(hex: "FFD9B0"), location: 0.46),
                        .init(color: Color(hex: "FFC6D2"), location: 0.72),
                        .init(color: Color(hex: "C9B2FF"), location: 0.92),
                        .init(color: Color(hex: "3A3570"), location: 1),
                    ], startPoint: .leading, endPoint: .trailing))
                    .overlay(Capsule().strokeBorder(Color.black.opacity(0.06), lineWidth: 1))
                ForEach([0.0, 9, 21, 24], id: \.self) { h in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 2, height: 16)
                        .position(x: w * h / 24, y: 23)
                }
                V17SunDot().frame(width: 22, height: 22).position(x: w * 9 / 24, y: 23)
                // 「いま」の目印
                VStack(spacing: 1) {
                    Text("いま").font(V17Font.mono(8.5)).tracking(0.14 * 8.5).foregroundStyle(Color(hex: "111111"))
                    Image(systemName: "arrowtriangle.down.fill").font(.system(size: 5)).foregroundStyle(Color(hex: "111111"))
                }
                .fixedSize()
                .position(x: w * nowHour / 24, y: -12)
                // つまみ
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().fill(V17Ink.orange).frame(width: 9, height: 9))
                    .overlay(Circle().strokeBorder(Color(hex: "111111"), lineWidth: 2))
                    .frame(width: 38, height: 38)
                    .shadow(color: .black.opacity(0.25), radius: 9, y: 8)
                    .scaleEffect(dragging ? 1.12 : 1)
                    .animation(.easeOut(duration: 0.15), value: dragging)
                    .position(x: w * hour / 24, y: 23)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let next = min(24, max(0, value.location.x / max(1, w) * 24))
                        if !dragging {
                            dragging = true
                            returnTask?.cancel()
                            Haptics.play(.pop)
                        }
                        move(to: next)
                    }
                    .onEnded { _ in release() }
            )
        }
        .frame(height: 46)
        .accessibilityElement()
        .accessibilityLabel("Later の1日")
        .accessibilityValue("\(HomeV17Rules.clockText(hour))、\(HomeV17Rules.phase(hour: hour).title)")
        .accessibilityAdjustableAction { direction in
            let step: Double = direction == .increment ? 1 : -1
            move(to: min(24, max(0, hour + step)))
        }
    }

    private var ticks: some View {
        HStack {
            ForEach([0, 3, 6, 9, 12, 15, 18, 21, 24], id: \.self) { h in
                Text("\(h)")
                    .font(V17Font.mono(8.5))
                    .foregroundStyle(h == 9 || h == 24 ? Color(hex: "111111") : Color(hex: "AEAEB2"))
                    .frame(width: 16)
                if h != 24 { Spacer(minLength: 0) }
            }
        }
        .padding(.horizontal, 2)
        .accessibilityHidden(true)
    }

    private func move(to next: Double) {
        let old = hour
        if let kind = HomeV17Rules.dragHaptic(from: old, to: next) {
            Haptics.play(kind, gap: kind == .tick ? 0.03 : nil)
            if kind == .thud { pillJolt += 1 }
        }
        dragHour = next
    }

    /// はなすと 0.42秒で「いま」にもどる
    private func release() {
        guard dragging else { return }
        dragging = false
        Haptics.play(.soft)
        let from = hour, to = nowHour
        guard !reduceMotion else { dragHour = nil; return }
        returnTask?.cancel()
        returnTask = Task { @MainActor in
            let start = Date()
            while !Task.isCancelled {
                let k = min(1, Date().timeIntervalSince(start) / HomeV17Rules.dayReturn)
                let e = 1 - pow(1 - k, 3)
                dragHour = from + (to - from) * e
                if k >= 1 { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
            if !Task.isCancelled { dragHour = nil }
        }
    }
}

private struct V17SunDot: View {
    var body: some View {
        Circle()
            .fill(Color(hex: "FFD60A"))
            .overlay(Circle().strokeBorder(Color(hex: "111111"), lineWidth: 1.6))
            .padding(6)
            .accessibilityHidden(true)
    }
}

// MARK: - C あしたの朝、こう ひらく

struct V17DevelopSection: View {
    let now: Date
    let ink: V17Ink
    let feel: HomeV17Feel

    @State private var density: Double = 0
    @State private var holding = false
    @State private var opened = false
    @State private var loop: Task<Void, Never>?
    @State private var burstToken = 0
    @State private var ramp = HapticRamp()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            V17SectionHeader(kicker: "HOW IT DEVELOPS", title: "あしたの朝、\nこう ひらく。", ink: ink)
            VStack(spacing: 0) {
                bigCheki
                    .padding(.top, 14)
                holdButton
                    .padding(.top, 30)
                Text(opened ? "ひらいた写真は、7日で 消えます" : "はなすと、ミルクに もどります")
                    .font(V17Font.mono(9.5))
                    .tracking(0.14 * 9.5)
                    .foregroundStyle(ink.sub)
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity)
        }
        .onDisappear { cancelAll() }
    }

    private var bigCheki: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                ZStack {
                    V17SampleSky()
                        .blur(radius: (1 - density) * 7)
                        .saturation(0.25 + 0.85 * density)
                        .contrast(0.75 + 0.3 * density)
                        .padding(-14)
                    V17Milk(density: density)
                }
                .frame(height: 236)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(width: 224, height: 236 + 12 + 54)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.white))
            .overlay(alignment: .bottomLeading) {
                Text("tomorrow").font(V17Font.serif(17)).foregroundStyle(Color(hex: "8E8E93")).padding(.leading, 16).padding(.bottom, 18)
            }
            .overlay(alignment: .bottomTrailing) {
                Text(HomeV17Rules.chekiDate(HomeV17Rules.nextOpen(now: now)))
                    .font(V17Font.hand(26)).foregroundStyle(Color(hex: "FF7A1A")).padding(.trailing, 16).padding(.bottom, 14)
            }
            .shadow(color: opened ? Color(red: 1, green: 0.55, blue: 0.35).opacity(0.65) : Color(red: 0.24, green: 0.12, blue: 0.04).opacity(0.35),
                    radius: opened ? 30 : 25, y: opened ? 30 : 30)
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(opened ? Color(red: 1, green: 0.55, blue: 0.35).opacity(0.3) : Color.black.opacity(0.035), lineWidth: 1))
            V17Tape(width: 64, height: 22, stripe: 5)
                .rotationEffect(.degrees(3))
                .offset(y: -14)
            V17StickerBurst(token: burstToken)
                .frame(width: 224, height: 302)
                .allowsHitTesting(false)
        }
        .rotationEffect(.degrees(-2.5))
        .animation(.easeOut(duration: 0.3), value: opened)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(opened ? "9:00 に、こうなる" : "あしたの朝の写真。いまはミルク色")
    }

    private var holdButton: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.25), lineWidth: 2.4)
                Circle()
                    .trim(from: 0, to: density)
                    .stroke(Color(hex: "FF8A4A"), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle().fill(Color.white).frame(width: 8, height: 8)
            }
            .frame(width: 24, height: 24)
            .padding(3)
            Text(opened ? "9:00 に、こうなる" : "長押しで、9:00 にする")
                .font(.system(size: 15, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(ink.onButton)
        .padding(.leading, 20)
        .padding(.trailing, 26)
        .frame(height: 54)
        .background(Capsule().fill(ink.button))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 14)
        .scaleEffect(holding ? 0.96 : 1)
        .animation(.easeOut(duration: 0.16), value: holding)
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !holding && !opened { begin() } }
                .onEnded { _ in end() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("長押しで、9:00 にする")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { finish() }
    }

    private func begin() {
        holding = true
        loop?.cancel()
        Haptics.play(.pop)
        ramp.start()
        let startDensity = density
        let start = Date().addingTimeInterval(-startDensity * HomeV17Rules.developHold)
        loop = Task { @MainActor in
            while !Task.isCancelled && holding {
                let v = min(1, Date().timeIntervalSince(start) / HomeV17Rules.developHold)
                density = v
                ramp.update(v)
                feel.rattle = v
                if v >= 1 { finish(); return }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func end() {
        guard holding else { return }
        holding = false
        loop?.cancel()
        ramp.stop()
        feel.rattle = 0
        Haptics.play(.soft)
        back(over: HomeV17Rules.developRelease)
    }

    /// ひらいた:チェキが光り、ステッカーがはじける。2.6秒後にミルクへもどる
    private func finish() {
        holding = false
        loop?.cancel()
        ramp.stop()
        feel.rattle = 0
        density = 1
        opened = true
        Haptics.play(.burst)
        burstToken += 1
        loop = Task { @MainActor in
            try? await Task.sleep(for: .seconds(HomeV17Rules.developShow))
            guard !Task.isCancelled else { return }
            back(over: HomeV17Rules.developReturn)
        }
    }

    private func back(over duration: TimeInterval) {
        let from = density
        loop?.cancel()
        loop = Task { @MainActor in
            let start = Date()
            while !Task.isCancelled {
                let k = min(1, Date().timeIntervalSince(start) / duration)
                density = from * (1 - k)
                if k >= 1 { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
            if !Task.isCancelled { opened = false }
        }
    }

    private func cancelAll() {
        loop?.cancel()
        ramp.stop()
        feel.rattle = 0
        holding = false
        density = 0
        opened = false
    }
}

/// 見本の絵(空と夕日と町)。ユーザーの写真は使わない
private struct V17SampleSky: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Color(hex: "5B8DEF"), Color(hex: "A9C6FF"), Color(hex: "FFD3A8"), Color(hex: "FF9A6A")], startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(RadialGradient(colors: [Color(hex: "FFF4D6"), Color(hex: "FFC56A"), Color(hex: "FFC56A").opacity(0)], center: .center, startRadius: 0, endRadius: 60))
                .frame(width: 120, height: 120)
                .offset(x: 30, y: -70)
            Path { p in
                p.move(to: CGPoint(x: 0, y: 70))
                p.addCurve(to: CGPoint(x: 240, y: 50), control1: CGPoint(x: 70, y: 30), control2: CGPoint(x: 150, y: 90))
                p.addLine(to: CGPoint(x: 240, y: 110))
                p.addLine(to: CGPoint(x: 0, y: 110))
                p.closeSubpath()
            }
            .fill(Color(hex: "3C3A64"))
            .frame(height: 110)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    Rectangle().fill(Color(hex: "26244A")).frame(width: 16, height: CGFloat([34, 52, 26, 60, 40, 30, 48][i]))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// ひらいたときに はじける ステッカー(星・花・太陽)
private struct V17StickerBurst: View {
    let token: Int
    @State private var shown = false

    private static let items: [(V17StickerKind, CGFloat, CGFloat, Double)] = [
        (.star, -26, 30, -14), (.flower, 200, 12, 12), (.sun, 214, 214, 8), (.star, -22, 236, -8), (.flower, 96, -34, 0),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(Self.items.enumerated()), id: \.offset) { index, item in
                V17Sticker(kind: item.0, size: 30)
                    .rotationEffect(.degrees(shown ? item.3 : 0))
                    .scaleEffect(shown ? 1 : 0.2)
                    .opacity(shown ? 1 : 0)
                    .animation(.spring(response: 0.42, dampingFraction: 0.5).delay(Double(index) * 0.06), value: shown)
                    .offset(x: item.1, y: item.2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: token) { _, _ in
            shown = false
            DispatchQueue.main.async { shown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + HomeV17Rules.developShow) { shown = false }
        }
    }
}

// MARK: - D 昨日の世界で、多かったことば

struct V17WordsSection: View {
    let mode: HomeV17Rules.WordsMode
    let words: [WorldWordsStore.Word]
    let countries: Int?
    let ink: V17Ink
    let actions: HomeV17Actions

    @State private var jolts: [Int: Int] = [:]

    private var rows: [WorldWordsStore.Word?] {
        if mode == .empty || words.isEmpty { return Array(repeating: nil, count: HomeV17Rules.wordRows) }
        return Array(words.prefix(HomeV17Rules.wordRows))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            V17SectionHeader(kicker: "MONDO ・ YESTERDAY'S WORDS", title: "昨日の世界で、\n多かったことば", number: "top 5", ink: ink)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, word in
                    row(index: index, word: word)
                        .v17Jolt(jolts[index, default: 0])
                    if index < rows.count - 1 { Rectangle().fill(ink.line).frame(height: 1) }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(ink.night ? Color.white.opacity(0.06) : .white))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(LinearGradient(colors: V17Ink.rainbow, startPoint: UnitPoint(x: 0, y: 0.2), endPoint: UnitPoint(x: 1, y: 0.8)), lineWidth: 1.5)
            )
            footer.padding(.top, mode == .empty ? 0 : 14)
        }
    }

    private func row(index: Int, word: WorldWordsStore.Word?) -> some View {
        Button { tap(index: index, word: word) } label: {
            HStack(spacing: 14) {
                Text(String(format: "%02d", index + 1))
                    .font(V17Font.mono(11))
                    .foregroundStyle(ink.faint)
                    .frame(width: 22, alignment: .leading)
                if let word {
                    Text("#\(word.tag)")
                        .font(.system(size: 18, weight: .heavy))
                        .tracking(-0.02 * 18)
                        .foregroundStyle(ink.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    thumbs(word.tones, seed: index)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ink.ink)
                        .padding(.trailing, 4)
                } else {
                    Canvas { context, size in
                        var x: CGFloat = 0
                        while x < size.width {
                            context.fill(Path(CGRect(x: x, y: 0, width: min(10, size.width - x), height: size.height)), with: .color(ink.fill))
                            x += 14
                        }
                    }
                    .frame(width: 110, height: 14)
                    .clipShape(Capsule())
                    Spacer(minLength: 0)
                    HStack(spacing: -9) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle().fill(ink.fill)
                                .overlay(Circle().strokeBorder(Color(hex: "D1D1D6"), style: StrokeStyle(lineWidth: 1.4, dash: [3, 2])))
                                .frame(width: 28, height: 28)
                        }
                    }
                }
            }
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(word.map { "\(index + 1)位、#\($0.tag)" } ?? "まだ、ことばはありません")
    }

    private func thumbs(_ tones: [String], seed: Int) -> some View {
        let locked = mode == .locked
        let colors: [Color] = (0..<3).map { i in
            if let hex = tones[safe: i] { return Color(hex: hex) }
            return V17Ink.scene[(seed + i * 2) % 5]
        }
        return HStack(spacing: -9) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(RadialGradient(colors: [colors[i], colors[i].opacity(0.55)], center: .center, startRadius: 0, endRadius: 16))
                    .blur(radius: locked ? 6 : 3)
                    .saturation(locked ? 0.5 : 1)
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(ink.night ? Color.black : Color.white, lineWidth: 2))
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var footer: some View {
        switch mode {
        case .empty:
            Text("あしたの朝から、ここに 世界の昨日の ことばが 並びます。")
                .font(.system(size: 12.5, weight: .medium))
                .lineSpacing(4)
                .foregroundStyle(ink.body)
                .padding(.top, 12)
        case .locked:
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold))
                    Text("今日を撮ると、ひらく").font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(ink.onButton)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(ink.button))
                Spacer()
                countriesText
            }
        case .open:
            HStack {
                Text(words.isEmpty ? "昨日のことばを、読みこみ中" : "タップで、そのことばの昨日へ")
                    .font(V17Font.mono(9.5)).tracking(0.14 * 9.5).foregroundStyle(ink.sub)
                Spacer()
                countriesText
            }
        }
    }

    @ViewBuilder
    private var countriesText: some View {
        if let countries, countries > 0 {
            Text("\(countries) COUNTRIES").font(V17Font.mono(9.5)).tracking(0.14 * 9.5).foregroundStyle(ink.sub)
        }
    }

    private func tap(index: Int, word: WorldWordsStore.Word?) {
        switch mode {
        case .empty:
            Haptics.play(.double)
            actions.toast("あしたの朝から\n世界の昨日が、ここに並びます")
        case .locked:
            Haptics.play(.double)
            jolts[index, default: 0] += 1
            actions.toast("今日を撮ると、ひらきます\n1枚で、世界の昨日が見られる")
        case .open:
            guard word != nil else {
                Haptics.play(.double)
                return
            }
            Haptics.play(.click)
            jolts[index, default: 0] += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { actions.openMondo() }
        }
    }
}

// MARK: - E ともだち

struct V17FriendsSection: View {
    let friends: [V17Friend]
    let ink: V17Ink
    let feel: HomeV17Feel
    let actions: HomeV17Actions
    let bump: V17Bump

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            V17SectionHeader(kicker: "FRIENDS", title: "ともだち", number: "\(friends.count) / \(FriendRules.maxFriends)", ink: ink)
            if friends.isEmpty {
                V17FriendsEmpty(ink: ink, feel: feel, actions: actions, bump: bump)
            } else {
                V17FriendsRow(friends: friends, ink: ink, feel: feel, actions: actions)
                Text("まわりの光 = 今日 撮った こま数。長押しで、つよく つつけます。")
                    .font(.system(size: 12.5, weight: .medium))
                    .lineSpacing(4)
                    .foregroundStyle(ink.body)
                    .padding(.top, 12)
            }
        }
    }
}

/// 0人:2台のスマホ・「ふって つながる」(長押し 1.5秒の代わりつき)
private struct V17FriendsEmpty: View {
    let ink: V17Ink
    let feel: HomeV17Feel
    let actions: HomeV17Actions
    let bump: V17Bump

    @State private var progress: Double = 0
    @State private var holding = false
    @State private var loop: Task<Void, Never>?
    @State private var ramp = HapticRamp()
    @State private var pulse = 0

    /// 本物の「ふる」の強さと、長押しの強さの大きいほう
    private var gauge: Double { max(progress, bump.shakeEnergy) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("まだ、だれも。")
                .font(.system(size: 21, weight: .heavy))
                .tracking(-0.03 * 21)
                .foregroundStyle(Color(hex: "111111"))
                .frame(maxWidth: 190, alignment: .leading)
            Text("となりの人と、スマホを ふるだけ。12人まで つながれます。")
                .font(.system(size: 12.5, weight: .medium))
                .lineSpacing(4)
                .foregroundStyle(Color(hex: "6E6E73"))
                .frame(maxWidth: 190, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.bottom, 18)
            shakeButton
                .scaleEffect(pulse.isMultiple(of: 2) ? 1 : 1.06)
                .animation(.spring(response: 0.25, dampingFraction: 0.4), value: pulse)
            HStack(spacing: 18) {
                link("合言葉で 呼ぶ")
                link("QR を 見せる")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(ink.night ? Color.white.opacity(0.92) : Color(hex: "F3F3F6")))
        .overlay(alignment: .topTrailing) {
            V17TwoPhones().frame(width: 118, height: 96).padding(.trailing, 10).padding(.top, 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        // 見えているあいだだけ、近くの相手をさがす(ふるのも、ここで受けとる)
        .onScrollVisibilityChange(threshold: 0.3) { visible in
            if visible { bump.start() } else { bump.stop() }
        }
        .onDisappear { loop?.cancel(); ramp.stop(); feel.rattle = 0; bump.stop() }
        .onChange(of: bump.connectedToken) { _, _ in
            pulse += 1
        }
        .onChange(of: bump.shakeEnergy) { _, energy in
            if !holding { feel.rattle = energy > 0.05 ? 0.15 + energy * 0.85 : 0 }
        }
    }

    private var shakeButton: some View {
        ZStack(alignment: .leading) {
            GeometryReader { proxy in
                LinearGradient(colors: [Color(hex: "FFB36A"), Color(hex: "FF6A3D"), Color(hex: "FF5DA2"), Color(hex: "9A7CFF")], startPoint: .leading, endPoint: .trailing)
                    .frame(width: proxy.size.width * gauge)
            }
            HStack(spacing: 8) {
                Image(systemName: "iphone.radiowaves.left.and.right").font(.system(size: 15, weight: .bold))
                Text(bump.isPairing ? "BUMP!" : "ふって つながる").font(.system(size: 15, weight: .heavy))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 56)
        .background(Color(hex: "111111"))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.35), radius: 14, y: 14)
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !holding { begin() } }
                .onEnded { _ in end(completed: false) }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ふって つながる。スマホを ふるか、長押し")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { complete() }
    }

    private func link(_ title: String) -> some View {
        Button {
            Haptics.play(.pop)
            actions.openFriends()
        } label: {
            Text(title)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(Color(hex: "3A3A3C"))
                .padding(.bottom, 2)
                .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: "111111")).frame(height: 1.4) }
        }
        .buttonStyle(.plain)
    }

    private func begin() {
        holding = true
        Haptics.play(.pop)
        ramp.start()
        bump.start()
        loop?.cancel()
        let start = Date()
        loop = Task { @MainActor in
            var lastTick = Date.distantPast
            while !Task.isCancelled && holding {
                let k = min(1, Date().timeIntervalSince(start) / HomeV17Rules.bumpHold)
                progress = k
                ramp.update(k)
                feel.rattle = 0.15 + k * 0.85
                // ためるほど、カリッ → カチッ が速くなる
                if Date().timeIntervalSince(lastTick) > 0.23 - k * 0.16 {
                    lastTick = Date()
                    Haptics.play(k > 0.7 ? .click : .tick, gap: 0)
                }
                if k >= 1 { complete(); return }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func end(completed: Bool) {
        guard holding else { return }
        holding = false
        loop?.cancel()
        ramp.stop()
        feel.rattle = 0
        withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
        if !completed { Haptics.play(.soft) }
    }

    /// 1.5秒ためた:ふり切ったのと同じく、近くの相手に「ふった」を送る
    private func complete() {
        end(completed: true)
        Haptics.play(.success)
        pulse += 1
        bump.bumpByHold()
    }
}

/// 1人以上:丸い顔の列(まわりの3つの点 = 今日撮ったこま数)
private struct V17FriendsRow: View {
    let friends: [V17Friend]
    let ink: V17Ink
    let feel: HomeV17Feel
    let actions: HomeV17Actions

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(friends) { friend in
                    V17FriendCell(friend: friend, ink: ink, feel: feel, actions: actions)
                }
                callCell
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 6)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -22)
    }

    private var callCell: some View {
        Button {
            Haptics.play(.pop)
            actions.openFriends()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle().stroke(Color(hex: "E5E5EA"), lineWidth: 1.2).padding(3)
                    Circle().fill(ink.night ? Color.clear : Color.white)
                        .overlay(Circle().strokeBorder(ink.ink, style: StrokeStyle(lineWidth: 1.6, dash: [4, 3])))
                        .padding(5)
                    Image(systemName: "plus").font(.system(size: 17, weight: .bold)).foregroundStyle(ink.ink)
                }
                .frame(width: 66, height: 66)
                Text("呼ぶ").font(.system(size: 12.5, weight: .bold)).foregroundStyle(ink.ink)
                Text("あと \(max(0, FriendRules.maxFriends - friends.count))").font(V17Font.mono(8.5)).tracking(0.1 * 8.5).foregroundStyle(ink.sub)
            }
            .frame(width: 66)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("ともだちを呼ぶ")
    }
}

private struct V17FriendCell: View {
    let friend: V17Friend
    let ink: V17Ink
    let feel: HomeV17Feel
    let actions: HomeV17Actions

    @State private var wobble = 0
    @State private var charge: Double = 0
    @State private var holdStart: Date?
    @State private var pressed = false
    @State private var loop: Task<Void, Never>?
    @State private var result: String?
    @State private var ramp = HapticRamp()

    var body: some View {
        VStack(spacing: 6) {
            face
                .keyframeAnimator(initialValue: (angle: 0.0, scale: 1.0), trigger: wobble) { content, v in
                    content.rotationEffect(.degrees(v.angle)).scaleEffect(v.scale)
                } keyframes: { _ in
                    KeyframeTrack(\.angle) {
                        LinearKeyframe(-9, duration: 0.14)
                        LinearKeyframe(7, duration: 0.14)
                        LinearKeyframe(-3, duration: 0.14)
                        LinearKeyframe(0, duration: 0.13)
                    }
                    KeyframeTrack(\.scale) {
                        LinearKeyframe(1.06, duration: 0.14)
                        LinearKeyframe(1, duration: 0.41)
                    }
                }
                .onTapGesture {
                    wobble += 1
                    Haptics.play(.pop)
                }
            Text(friend.name)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(ink.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(friend.shotsToday) / 3").font(V17Font.mono(8.5)).tracking(0.1 * 8.5).foregroundStyle(ink.sub)
            knockChip
        }
        .frame(width: 66)
        .onDisappear { loop?.cancel(); ramp.stop() }
    }

    private var face: some View {
        ZStack {
            Canvas { context, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let r = size.width / 2 * 30 / 33
                context.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: "E5E5EA")), lineWidth: 1.2)
                for k in 0..<3 {
                    let a = -Double.pi / 2 + Double(k) * 2 * .pi / 3
                    let on = k < friend.shotsToday
                    let dot: CGFloat = on ? 3.6 : 2.4
                    let p = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
                    context.fill(Path(ellipseIn: CGRect(x: p.x - dot, y: p.y - dot, width: dot * 2, height: dot * 2)), with: .color(on ? V17Ink.orange : Color(hex: "C7C7CC")))
                }
            }
            LayerAvatar(data: friend.avatarData, seed: friend.seed, name: friend.name)
                .padding(8)
        }
        .frame(width: 66, height: 66)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(friend.name)、今日 \(friend.shotsToday)こま")
    }

    private var knockChip: some View {
        let done = result != nil
        return Text(result ?? "つつく")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(done || !friend.canKnock ? ink.body : ink.onButton)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(done || !friend.canKnock ? ink.fill : ink.button))
            .overlay(alignment: .bottomLeading) {
                GeometryReader { proxy in
                    Rectangle().fill(V17Ink.orange).frame(width: proxy.size.width * charge, height: 3)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !pressed { pressed = true; begin() } }
                    .onEnded { _ in pressed = false; release() }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(done ? "\(friend.name) を つついた" : "\(friend.name) を つつく。長押しで、つよく")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { holdStart = Date(); release() }
    }

    private func begin() {
        guard result == nil else { return }
        guard friend.canKnock else {
            holdStart = nil
            Haptics.play(.double)
            if friend.home?.knockOff == true {
                actions.toast("\(friend.name) は、つつきを受けとっていません")
            } else {
                actions.toast("同じグループの ともだちだけ、つつけます")
            }
            return
        }
        holdStart = Date()
        Haptics.play(.tick)
        ramp.start()
        loop?.cancel()
        loop = Task { @MainActor in
            while !Task.isCancelled, let start = holdStart {
                let v = min(1, Date().timeIntervalSince(start) / HomeV17Rules.knockFull)
                charge = v
                ramp.update(v)
                feel.rattle = v * 0.75
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    /// はなした:0.9秒より長く ためたら「つよく」。相手に届くのは、どちらも ふつうの つつく
    private func release() {
        guard let start = holdStart, let home = friend.home else { holdStart = nil; return }
        holdStart = nil
        loop?.cancel()
        ramp.stop()
        feel.rattle = 0
        let strong = Date().timeIntervalSince(start) > HomeV17Rules.strongKnock
        withAnimation(.easeOut(duration: 0.2)) { charge = 0 }
        Haptics.play(strong ? .burst : .heart)
        wobble += 1
        result = strong ? "つよく" : "つついた"
        actions.knock(home)
    }
}

/// 2台のスマホのステッカー
private struct V17TwoPhones: View {
    var body: some View {
        Canvas { context, _ in
            func phone(x: CGFloat, color: String, angle: Double, pivot: CGPoint) {
                var ctx = context
                ctx.translateBy(x: pivot.x, y: pivot.y)
                ctx.rotate(by: .degrees(angle))
                ctx.translateBy(x: -pivot.x, y: -pivot.y)
                let body = Path(roundedRect: CGRect(x: x, y: 14, width: 40, height: 72), cornerRadius: 10)
                ctx.fill(body, with: .color(Color(hex: color)))
                ctx.stroke(body, with: .color(Color(hex: "111111")), lineWidth: 2.3)
                let screen = Path(roundedRect: CGRect(x: x + 8, y: 22, width: 24, height: 44), cornerRadius: 4)
                ctx.fill(screen, with: .color(.white))
                ctx.stroke(screen, with: .color(Color(hex: "111111")), lineWidth: 1.8)
            }
            phone(x: 16, color: "FFC9A8", angle: -13, pivot: CGPoint(x: 36, y: 52))
            phone(x: 64, color: "C9B2FF", angle: 13, pivot: CGPoint(x: 84, y: 52))
            var lines = Path()
            lines.move(to: CGPoint(x: 57, y: 10)); lines.addLine(to: CGPoint(x: 60, y: 2))
            lines.move(to: CGPoint(x: 64, y: 12)); lines.addLine(to: CGPoint(x: 71, y: 6))
            lines.move(to: CGPoint(x: 51, y: 9)); lines.addLine(to: CGPoint(x: 50, y: 1))
            context.stroke(lines, with: .color(Color(hex: "111111")), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}

/// ホームの「ふって つながる」(ShakeConnect を、見えているあいだだけ動かす)
@MainActor @Observable
final class V17Bump {
    @ObservationIgnored private let shake = ShakeConnect()
    @ObservationIgnored private var running = false
    @ObservationIgnored var myName: () -> String = { "" }
    @ObservationIgnored var friendCount: () -> Int = { 0 }
    @ObservationIgnored var onToast: (String) -> Void = { _ in }
    /// つながったときに1つ進む
    private(set) var connectedToken = 0
    /// 相手が見つかった(「つながる?」をきいている)
    var pending: (name: String, id: String)?

    var shakeEnergy: Double {
        if case .shaking(let e) = shake.phase { return e }
        return 0
    }

    var isPairing: Bool {
        switch shake.phase {
        case .confirm, .connected: return true
        default: return false
        }
    }

    nonisolated init() {}

    func start() {
        guard !running, let me = CloudKitManager.current?.currentUserRecordName else { return }
        running = true
        shake.start(name: myName(), recordName: me)
        watch()
    }

    func stop() {
        guard running, pending == nil else { return }
        running = false
        shake.stop()
    }

    /// 長押し 1.5秒:ふり切ったのと同じ。近くに相手がいなければ、そう伝える
    func bumpByHold() {
        if !running { start() }
        shake.bumpByHold()
        let hadPeer = shake.hasNearbyPeer
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            guard let self, self.pending == nil, !self.isPairing else { return }
            self.onToast(hadPeer ? "相手も いっしょに ふってね" : "近くに、ふっている人が 見つかりません")
        }
    }

    func confirm() {
        guard let pending else { return }
        Task { @MainActor in
            let result = await FriendCloud.connect(to: pending.id, myName: myName(), myCount: friendCount(), theirCount: 0)
            switch result {
            case .success:
                Haptics.play(.success)
                BumpFriendStore.remember(id: pending.id, name: pending.name)
                shake.confirmed()
                connectedToken += 1
                onToast("BUMP!\n「\(pending.name)」と、つながりました")
            case .failure(let error):
                Haptics.play(.warn)
                onToast(error.message)
                shake.reset()
            }
            self.pending = nil
        }
    }

    func cancel() {
        Haptics.play(.soft)
        pending = nil
        shake.reset()
    }

    private func watch() {
        withObservationTracking {
            _ = shake.phase
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.running else { return }
                if case .confirm(let name, let id) = self.shake.phase, self.pending == nil {
                    self.pending = (name, id)
                }
                self.watch()
            }
        }
    }
}

// MARK: - F Later の、3つの やくそく

struct V17PromisesSection: View {
    let ink: V17Ink
    @State private var page: Int? = 0

    private struct Card: Identifiable {
        let id: Int
        let number: String
        let sticker: V17StickerKind
        let title: String
        let note: String
        let dark: Bool
    }

    private let cards: [Card] = [
        Card(id: 0, number: "01", sticker: .star, title: "いいねは、\nない。", note: "数字で くらべない。\n届くのは、光の強さだけ。", dark: false),
        Card(id: 1, number: "02", sticker: .flower, title: "フォローも、\nない。", note: "つながるのは、スマホを ふった人だけ。12人まで。", dark: true),
        Card(id: 2, number: "03", sticker: .sun, title: "7日で、\nきえる。", note: "えらんだ1枚だけ、カレンダーに 1年 のこる。", dark: false),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            V17SectionHeader(kicker: "3 PROMISES", title: "Later の、3つの\nやくそく", accent: "promises", ink: ink)
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(cards) { card in
                        cardView(card).id(card.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 22)
                .padding(.top, 4)
                .padding(.bottom, 10)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $page, anchor: .center)
            .padding(.horizontal, -22)
            .onChange(of: page) { old, new in
                if old != nil, new != nil, old != new { Haptics.play(.detent) }
            }
        }
    }

    private func cardView(_ card: Card) -> some View {
        let fg: Color = card.dark ? .white : Color(hex: "111111")
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(card.dark ? Color(hex: "111111") : (ink.night ? Color.white.opacity(0.92) : Color(hex: "F3F3F6")))
            Text(card.number)
                .font(V17Font.serif(46))
                .foregroundStyle(fg)
                .padding(.leading, 20)
                .padding(.top, 20)
            V17Sticker(kind: card.sticker, size: 66)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 16)
                .padding(.top, 18)
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                Text(card.title)
                    .font(.system(size: 24, weight: .heavy))
                    .tracking(-0.04 * 24)
                    .lineSpacing(3)
                    .foregroundStyle(fg)
                    .fixedSize(horizontal: false, vertical: true)
                Text(card.note)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineSpacing(3)
                    .foregroundStyle(card.dark ? Color.white.opacity(0.6) : Color(hex: "6E6E73"))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
            .padding(20)
        }
        .frame(width: 236, height: 268)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture { Haptics.play(.pop) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("やくそく \(card.number)。\(card.title.replacingOccurrences(of: "\n", with: ""))\(card.note.replacingOccurrences(of: "\n", with: ""))")
    }
}

// MARK: - G おわり

struct V17EndSection: View {
    let now: Date
    let ink: V17Ink
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var jolt = 0

    var body: some View {
        VStack(spacing: 0) {
            ring
                .v17Jolt(jolt)
                .onTapGesture {
                    jolt += 1
                    Haptics.play(.thud)
                }
                .accessibilityLabel("またあした")
                .accessibilityAddTraits(.isButton)
            HStack(alignment: .top, spacing: -2) {
                Text("Later")
                    .font(.system(size: 58, weight: .black))
                    .tracking(-0.06 * 58)
                    .foregroundStyle(ink.ink)
                Text("today")
                    .font(V17Font.serif(22))
                    .foregroundStyle(ink.sub)
                    .offset(y: -6)
            }
            .padding(.top, 22)
            .accessibilityElement(children: .combine)
            Text("SEE YOU AT 9:00 ─ \(HomeV17Rules.dotDate(HomeV17Rules.nextOpen(now: now)))")
                .font(V17Font.mono(9.5))
                .tracking(0.14 * 9.5)
                .foregroundStyle(ink.sub)
                .padding(.top, 16)
            Text("きょうも、いい1日を。")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(ink.text)
                .padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
    }

    private var ring: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive || reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let angle = (isActive && !reduceMotion) ? (t.truncatingRemainder(dividingBy: 9) / 9) * 360 : 0
            ZStack {
                Circle()
                    .fill(AngularGradient(colors: V17Ink.rainbow + [Color(hex: "FFE08A"), Color(hex: "FFC9A8")], center: .center))
                    .rotationEffect(.degrees(angle))
                Circle().fill(ink.night ? Color.black : Color.white).padding(3)
                Circle().fill(ink.ink).frame(width: 9, height: 9)
            }
            .frame(width: 64, height: 64)
        }
    }
}

// MARK: - 区画の並び(状態ごと)

struct HomeV17Stack: View {
    let state: HomeState
    let now: Date
    let data: HomeV17Data
    let actions: HomeV17Actions
    let feel: HomeV17Feel
    let bump: V17Bump?
    let isActive: Bool

    @Environment(\.palette) private var palette

    var body: some View {
        let ink = V17Ink(night: palette.isNight)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(HomeV17Rules.order(state)) { section in
                content(section, ink: ink)
                    .padding(.horizontal, 22)
                    .padding(.top, 46)
                    .v17Reveal()
                    .id(section.rawValue)
            }
            V17EndSection(now: now, ink: ink, isActive: isActive)
                .v17Reveal()
            Color.clear.frame(height: HomeV17Rules.bottomSpace)
        }
        .id(state.kind)
    }

    @ViewBuilder
    private func content(_ section: HomeV17Section, ink: V17Ink) -> some View {
        switch section {
        case .film:
            V17FilmSection(state: state, now: now, shots: data.shots, videoDurations: data.videoDurations, ink: ink, actions: actions)
        case .develop:
            V17DevelopSection(now: now, ink: ink, feel: feel)
        case .day:
            V17DaySection(now: now, ink: ink)
        case .words:
            V17WordsSection(mode: HomeV17Rules.wordsMode(state: state, shotsToday: max(FilmCounter.shared.used, data.shots.count)),
                            words: data.words, countries: data.countries, ink: ink, actions: actions)
        case .friends:
            if let bump {
                V17FriendsSection(friends: data.friends, ink: ink, feel: feel, actions: actions, bump: bump)
            }
        case .promises:
            V17PromisesSection(ink: ink)
        }
    }
}

// MARK: - 固定の飾り(スクロール位置だけを読む)

/// ヘッダーの下地:8pt をこえたら、白のグラデーション(下に細い線)が 0.2秒でふわっと
struct V17HeaderGlass: View {
    let scroll: HomeV17Scroll
    let tint: Color
    let height: CGFloat
    let lineY: CGFloat

    var body: some View {
        let shown = HomeV17Rules.headerGlass(scroll.offset)
        ZStack(alignment: .topLeading) {
            LinearGradient(stops: [
                .init(color: tint, location: 0),
                .init(color: tint, location: 0.64),
                .init(color: tint.opacity(0.86), location: 0.8),
                .init(color: tint.opacity(0), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: [.clear, Color(hex: "E8E8ED"), Color(hex: "E8E8ED"), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
                .padding(.horizontal, 22)
                .opacity(0.9)
                .offset(y: lineY)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .opacity(shown)
        .animation(.easeOut(duration: 0.2), value: shown > 0.5)
        .accessibilityHidden(true)
    }
}

/// 月の上の白いグラデーション(スクロールしたときだけ)と、左下の縦書き「SCROLL」
struct V17BottomChrome: View {
    let scroll: HomeV17Scroll
    let tint: Color
    let ink: Color
    let showsCue: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let offset = scroll.offset
        ZStack(alignment: .bottomLeading) {
            // 月(下から 102pt)の 後ろは 背景の色で うめて、上 48pt で 透明へ。
            // 後ろの カードの 文字が 月の 文字と まざって 読めなくならないよう、スクロールしていなくても 敷く
            LinearGradient(stops: [
                .init(color: tint.opacity(0), location: 0),
                .init(color: tint.opacity(0.85), location: 0.22),
                .init(color: tint, location: 0.32),
                .init(color: tint, location: 1),
            ], startPoint: .top, endPoint: .bottom)
            .frame(height: MoonLayout.visibleHeight + 48)
            .frame(maxWidth: .infinity)

            V17ScrollCue(ink: ink, animated: !reduceMotion)
                .padding(.leading, 24)
                .padding(.bottom, 10)
                .opacity(showsCue ? HomeV17Rules.cue(offset) : 0)
                .animation(.easeOut(duration: 0.3), value: showsCue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

/// 縦書きの「SCROLL」と、のびる線
private struct V17ScrollCue: View {
    let ink: Color
    let animated: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text("SCROLL")
                .font(V17Font.mono(8.5))
                .tracking(0.24 * 8.5)
                .foregroundStyle(Color(hex: "8E8E93"))
                .fixedSize()
                .rotationEffect(.degrees(90))
                .frame(width: 12, height: 50)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animated)) { context in
                // 1.8秒:0 → のびる(50%)→ そのまま消える
                let p = animated ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8) / 1.8 : 0.5
                let grow = min(1, p * 2)
                let fade = p < 0.5 ? 1 : 1 - (p - 0.5) * 2
                LinearGradient(colors: [ink, ink.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(width: 1.5, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 1))
                    .scaleEffect(x: 1, y: grow, anchor: .top)
                    .opacity(fade)
            }
            .frame(width: 1.5, height: 22)
        }
    }
}

/// スクロールの 0.22倍だけ下にずらす(奥行き)
struct V17Parallax<Content: View>: View {
    let scroll: HomeV17Scroll
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content().offset(y: reduceMotion ? 0 : HomeV17Rules.parallax(scroll.offset))
    }
}

/// スクロール量 × 0.09度 回す
struct V17ScrollTurn<Content: View>: View {
    let scroll: HomeV17Scroll
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content().rotationEffect(.degrees(reduceMotion ? 0 : HomeV17Rules.ringTurn(scroll.offset)))
    }
}
