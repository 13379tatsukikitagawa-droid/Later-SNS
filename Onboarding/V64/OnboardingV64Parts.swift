import SwiftUI

// P01:はじめての設定(モック v64 の `.ob`)の 部品。値は spec/screens/O03〜O11.json と mock/src/style.css(1461〜1650)の 最終値。
// 色は TOKENS.md の ものだけ。見本の写真(PH)は 実機に 作らない ので、壁の 写真は 色の 面に している。

enum OB {
    static let bg = Color(hex: "070708")
    static let sub = Color(hex: "8E8E95")
    static let kicker = Color(hex: "B9B9C0")
    static let line = Color.white.opacity(0.10)
    static let accent = Color(hex: "239E3C")
    static let stamp = Color(hex: "24A73E")
    static let paper = Color(hex: "FAF8F2")

    /// 名前の ハッシュで 決まる 色(OBP)
    static let palette: [(Color, Color)] = [
        (Color(hex: "61D278"), Color(hex: "EE5E9C")), (Color(hex: "9ED8FF"), Color(hex: "9B8CFF")),
        (Color(hex: "C8F25A"), Color(hex: "18FA45")), (Color(hex: "63DC7B"), Color(hex: "FFD25A")),
        (Color(hex: "B28CFF"), Color(hex: "F27CC0")), (Color(hex: "5AC8FF"), Color(hex: "3A4ACF")),
    ]
    /// タグの 候補(OBT)
    static let tags = ["#ねむい", "#推し活", "#カフェ", "#部活", "#音楽", "#さんぽ", "#甘党", "#夜型", "#ゲーム", "#映画", "#ダンス"]
    /// チェキに はる タグの 色・字・かたむき(OBTC)
    static let tagStyle: [(bg: Color, fg: Color, rot: Double)] = [
        (Color(hex: "EE5E9C"), .white, -8), (Color(hex: "C8F25A"), Color(hex: "111111"), 7), (Color(hex: "9ED8FF"), Color(hex: "111111"), 5),
    ]
    /// ミルク色の 膜の 濃さ(OBMK)
    static func milk(_ s: OBStep) -> Double {
        switch s { case .signin, .mail, .sent: return 1; case .name, .id: return 0.8; case .tag: return 0.5; case .fr: return 0.26; case .nt: return 0.1; case .go: return 0 }
    }
    /// 友だちの 丸が ういている 位置(OBDOT)
    static let dots: [CGPoint] = [CGPoint(x: -148, y: 50), CGPoint(x: 148, y: 34), CGPoint(x: -150, y: 138), CGPoint(x: 150, y: 128), CGPoint(x: -140, y: 222), CGPoint(x: 142, y: 218)]

    /// モックの `hash`(名前 → 色の 番号)
    static func colorIndex(for name: String) -> Int {
        var h = 0
        for u in name.unicodeScalars { h = (h &* 31 &+ Int(u.value)) & 0x7fffffff }
        return h % palette.count
    }
}

enum OBStep: String, CaseIterable {
    case signin = "in", mail, sent, name, id, tag, fr, nt, go

    var back: OBStep? {
        switch self { case .id: return .name; case .tag: return .id; case .fr: return .tag; case .nt: return .fr; case .mail: return .signin; case .sent: return .mail; default: return nil }
    }
    /// 「01 / 04」の 番号(なければ nil)
    var page: Int? {
        switch self { case .name: return 1; case .id: return 1; case .tag: return 2; case .fr: return 3; case .nt: return 4; default: return nil }
    }
    var pageLabel: String { ["", "YOU", "TAG", "FRIENDS", "NOTICE"][page ?? 0] }
    /// チェキの 上の 位置・かたむき・大きさ(`.obc`)
    var chekiTop: CGFloat {
        switch self { case .signin, .mail, .sent: return 150; case .nt: return 206; case .go: return 150; default: return 128 }
    }
    var chekiRotation: Double { self == .nt ? 2 : (self == .go ? -2 : -3) }
    var chekiScale: CGFloat { self == .nt ? 0.92 : (self == .go ? 1.22 : 1) }
    var showsBrand: Bool { self == .signin || self == .mail || self == .sent }
    var wallOpacity: Double { self == .signin ? 0.26 : ((self == .mail || self == .sent) ? 0.12 : 0) }
}

// MARK: - 背景(色の にじみ 2つ + 写真の 壁)

struct OBGlow: View {
    let c1: Color, c2: Color, opacity: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: reduceMotion)) { ctx in
            let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
            // gbd:15 秒・19 秒で ゆっくり ただよう(alternate)
            let a = (sin(t / 15 * .pi) + 1) / 2, b = (sin(t / 19 * .pi + 1) + 1) / 2
            GeometryReader { g in
                ZStack(alignment: .topLeading) {
                    Circle().fill(c1).frame(width: 340, height: 340).blur(radius: 80).opacity(opacity)
                        .offset(x: -110 + 40 * a, y: 40 - 30 * a)
                    Circle().fill(c2).frame(width: 340, height: 340).blur(radius: 80).opacity(opacity)
                        .offset(x: g.size.width + 130 - 340 - 40 * b, y: 240 + 30 * b)
                }
            }
        }
        .animation(.easeInOut(duration: 1.2), value: c1)
        .animation(.easeInOut(duration: 1.2), value: opacity)
        .allowsHitTesting(false)
    }
}

/// サインインの うしろで ゆっくり 流れる チェキの 壁(`.obwall`)。写真は 色の 面。
struct OBWall: View {
    let opacity: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let tint: [Color] = [Color(hex: "3D5A48"), Color(hex: "5A4A3D"), Color(hex: "3D4A5A"), Color(hex: "5A3D4F"), Color(hex: "4E5A3D"), Color(hex: "3D5558")]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || opacity == 0)) { ctx in
            let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
            HStack(alignment: .top, spacing: 12) {
                ForEach(0..<4, id: \.self) { c in
                    let dur = [38.0, 46, 38, 52][c], reverse = c == 1 || c == 3
                    let p = (t.truncatingRemainder(dividingBy: dur)) / dur
                    column(c).offset(y: CGFloat(reverse ? (p - 1) : -p) * columnHeight)
                        .padding(.top, c == 1 ? -60 : 0)
                }
            }
            .frame(width: 390 + 60, height: 844 + 80, alignment: .top)
            .clipped()
        }
        .frame(width: 390, height: 844)
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0.04), .init(color: .black, location: 0.20), .init(color: .black, location: 0.40), .init(color: .clear, location: 0.60)], startPoint: .top, endPoint: .bottom))
        .opacity(opacity)
        .animation(.easeInOut(duration: 1.2), value: opacity)
        .allowsHitTesting(false)
    }

    private var columnHeight: CGFloat { 7 * (108 + 12) }

    private func column(_ c: Int) -> some View {
        VStack(spacing: 12) {
            ForEach(0..<14, id: \.self) { i in
                let k = i % 7
                let milk = (c + k) % 3 == 0
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(LinearGradient(colors: [tint[(c * 3 + k * 5) % 6], tint[(c * 3 + k * 5 + 2) % 6].opacity(0.7)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 76, height: 84)
                        .saturation(milk ? 0.2 : 0.7)
                        .blur(radius: milk ? 4 : 0)
                        .clipped()
                    Spacer(minLength: 0)
                }
                .padding(5)
                .frame(width: 86, height: 108)
                .background(Color(hex: "EDEAE2"), in: RoundedRectangle(cornerRadius: 2))
                .rotationEffect(.degrees(Double((c * 7 + k * 11) % 9 - 4) * 0.8))
            }
        }
    }
}

// MARK: - チェキ(`.obc`)

struct OBCheki: View {
    let step: OBStep
    let initial: String
    let colors: (Color, Color)
    let photo: UIImage?
    let tags: [String]
    let friendInitials: [(String, Color)]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { ctx in
            // obfl:5 秒の ふわふわ(-4 → 5)
            let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
            let float = CGFloat(0.5 + 0.5 * sin(t / 5 * .pi)) * 9 - 4
            card.offset(y: float)
        }
    }

    private var card: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 5).fill(OB.paper)
                .shadow(color: .black.opacity(0.9), radius: 30, x: 0, y: 30)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.06), lineWidth: 1))
            // 写真の 面(色 → 名前の 頭文字 / えらんだ 写真)
            ZStack {
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [colors.0, colors.1], startPoint: UnitPoint(x: 0.1, y: 0), endPoint: UnitPoint(x: 0.9, y: 1))
                    Text(initial).font(LF.inter(900, 76)).foregroundStyle(.white).shadow(color: .black.opacity(0.18), radius: 7, y: 2)
                }
                // ミルク色の 膜(現像前)+ さっと 光が 走る
                ZStack {
                    LinearGradient(colors: [Color(hex: "EEF3EE"), Color(hex: "DDE6E6")], startPoint: UnitPoint(x: 0.3, y: 0), endPoint: UnitPoint(x: 0.7, y: 1))
                    if !reduceMotion { OBShine() }
                }
                .opacity(OB.milk(step))
                .animation(.timingCurve(0.3, 0.1, 0.3, 1, duration: 1.1), value: step)
            }
            .frame(width: 160, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .offset(x: 10, y: 10)
            Text(OpeningStyle.shortDate(Date(), apostrophe: true)).font(LF.mono(10)).tracking(0.6)
                .foregroundStyle(OB.stamp).shadow(color: Color(red: 1, green: 0.48, blue: 0.16).opacity(0.55), radius: 6)
                .fixedSize()
                .frame(width: 180 - 12, height: 12, alignment: .trailing)
                .offset(y: 216 - 13 - 12)
            // 貼った タグ(最大 3)
            ForEach(Array(tags.prefix(3).enumerated()), id: \.offset) { i, tag in
                let s = OB.tagStyle[i]
                Text(tag).font(LF.inter(900, 12.5)).foregroundStyle(s.fg).lineLimit(1).fixedSize()
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(s.bg, in: RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.6), radius: 6, y: 6)
                    .rotationEffect(.degrees(s.rot))
                    .offset(x: i == 1 ? 180 - 70 : (i == 0 ? -34 : -26), y: [20, 92, 150][i])
                    .transition(.scale(scale: 2.4).combined(with: .opacity))
            }
            // ういている 友だちの 丸(申請した 人)
            ForEach(Array(friendInitials.prefix(6).enumerated()), id: \.offset) { i, f in
                Text(f.0).font(LF.inter(800, 13)).foregroundStyle(.white)
                    .frame(width: 34, height: 34).background(f.1, in: Circle())
                    .overlay(Circle().stroke(Color(hex: "070708"), lineWidth: 2.5).padding(-2.5))
                    .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1.5).padding(-4))
                    .position(x: 90 + OB.dots[i].x, y: OB.dots[i].y)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 180, height: 216)
        .animation(.timingCurve(0.3, 1.4, 0.4, 1, duration: 0.42), value: tags)
        .animation(.timingCurve(0.3, 1.4, 0.4, 1, duration: 0.42), value: friendInitials.count)
    }
}

private struct OBShine: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
            let p = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.2) / 3.2
            GeometryReader { g in
                // 110deg の 帯が 左から 右へ(3.2秒の うち 前半だけ はしる)
                let k = min(1, p * 2)
                LinearGradient(colors: [.clear, .white.opacity(0.75), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: g.size.width * 0.5, height: g.size.height * 2)
                    .rotationEffect(.degrees(20))
                    .position(x: -g.size.width * 0.3 + CGFloat(k) * g.size.width * 1.6, y: g.size.height / 2)
            }
        }
    }
}

// MARK: - ボタン

struct OBButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, plain }
    var kind: Kind = .primary
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
        Group {
            switch kind {
            case .primary:
                label.font(LF.inter(800, 16.5)).tracking(0.165)
                    .foregroundStyle(enabled ? Color(hex: "111111") : OB.sub)
                    .frame(maxWidth: .infinity).frame(height: 60)
                    .background(enabled ? Color.white : OB.line, in: Capsule())
            case .secondary:
                label.font(LF.inter(800, 16)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1))
            case .plain:
                label.font(LF.inter(700, 13.5)).foregroundStyle(OB.sub)
                    .frame(maxWidth: .infinity).frame(height: 36)
                    .contentShape(Rectangle().inset(by: -4))   // 押せる 広さは 44pt
            }
        }
        .scaleEffect(configuration.isPressed && kind != .plain ? 0.96 : 1)
        .animation(.timingCurve(0.3, 1.6, 0.4, 1, duration: 0.25), value: configuration.isPressed)
    }
}

/// ようこその 見出し・ふつうの 見出し(Later Mincho 29pt / 行の 高さ 1.42)
struct OBHeading: View {
    let parts: [(String, Bool)]   // (字, 強調か)
    var size: CGFloat = 29

    var body: some View {
        parts.reduce(Text("")) { acc, p in
            acc + Text(p.0).foregroundColor(p.1 ? OB.stamp : .white)
        }
        .font(LGFont.mincho(size))
        .lineSpacing(size * 1.42 - (UIFont(name: "NotoSerifJP-Bold", size: size)?.lineHeight ?? size * 1.45))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - ながおし(`.obhd`)

struct OBHoldButton: View {
    let onProgress: (Double) -> Void
    let onFinish: () -> Void
    @State private var start: Date?
    @State private var done = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let duration = 1.7
    @State private var lastTick = Date.distantPast
    @State private var lastBuzz = Date.distantPast
    @State private var lastRumble = Date.distantPast

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { ctx in
            let p = start.map { min(1, ctx.date.timeIntervalSince($0) / duration) } ?? 0
            ZStack {
                Circle().stroke(Color.white.opacity(0.14), lineWidth: 12).frame(width: 100, height: 100)
                Circle().trim(from: 0, to: p).stroke(OB.accent, style: StrokeStyle(lineWidth: 12, lineCap: .butt))
                    .rotationEffect(.degrees(-90)).frame(width: 100, height: 100)
                Circle().fill(RadialGradient(colors: [.white, Color(hex: "E9E4DA")], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 80))
                    .frame(width: 88, height: 88)
                    .shadow(color: .white.opacity(0.5), radius: 20)
                    .scaleEffect(1 - p * 0.28)
            }
            .frame(width: 112, height: 112)
            .onChange(of: p) { _, v in tick(v) }
        }
        .frame(width: 112, height: 112)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in begin() }
            .onEnded { _ in release() })
        .accessibilityLabel("ながおしで はじめる")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onFinish() }
    }

    private func begin() {
        guard start == nil, !done else { return }
        start = Date(); lastTick = start!; lastBuzz = start!; lastRumble = start!
        Haptics.play(.click)
    }

    private func release() {
        guard !done else { return }
        if start != nil { Haptics.play(.soft) }
        start = nil
        onProgress(0)
    }

    /// バイブ:はじめは 間を あけて コツコツ → だんだん 速く → 最後は ずっと ブルブル
    private func tick(_ p: Double) {
        guard start != nil, !done else { return }
        onProgress(p * p)
        let now = Date()
        if p < 0.45 {
            if now.timeIntervalSince(lastTick) > (200 - p * 260) / 1000 { lastTick = now; Haptics.play(.tick, gap: 0) }
        } else if p < 0.8 {
            if now.timeIntervalSince(lastBuzz) > (90 - (p - 0.45) * 150) / 1000 { lastBuzz = now; Haptics.play(.buzz, gap: 0) }
        } else if now.timeIntervalSince(lastRumble) > 0.07 {
            lastRumble = now; Haptics.play(.rumble, gap: 0)
        }
        if p >= 1 { done = true; onFinish() }
    }
}

// MARK: - 通知の 見本(`.obn`)

struct OBNoticeCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("9:00").font(LF.mono(12)).foregroundStyle(OB.accent).shadow(color: OB.accent, radius: 4)
                .frame(width: 42, height: 42).background(Color(hex: "0B0B0D"), in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.white.opacity(0.12), lineWidth: 1))
                .padding(.top, 14)
            VStack(alignment: .leading, spacing: 2) {
                HStack { Text(Brand.name).font(LF.inter(700, 13.5)); Spacer(); Text("9:00").font(LF.inter(500, 12)).foregroundStyle(.white.opacity(0.55)) }
                    .frame(height: 16)
                Text("きのうが、ひらきました").font(LF.inter(500, 14.5)).frame(height: 21, alignment: .leading)
            }
            .foregroundStyle(.white)
            .padding(.top, 8.3)
        }
        .padding(.horizontal, 14)
        .frame(height: 70, alignment: .top)
        .background(Color(red: 60 / 255, green: 60 / 255, blue: 66 / 255).opacity(0.72), in: RoundedRectangle(cornerRadius: 24))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.8), radius: 20, y: 20)
        .padding(.horizontal, 16)
    }
}
