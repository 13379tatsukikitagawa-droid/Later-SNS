import SwiftUI

/// 白 × シック(v7)の色。フェーズ1では「撮る前の今日のホーム」だけが使う。
enum ChicColor {
    static let paper = Color(hex: "FFFFFF")
    static let ink = Color(hex: "111111")
    static let sub = Color(hex: "6E6E73")
    static let fill = Color(hex: "F3F3F6")
    static let accent = Color(hex: "FF6A1A")
    /// チェキの白い紙
    static let instax = Color(hex: "FFFDF8")
    static let instaxShadow = Color(hex: "281E14")
    static let tape = Color(hex: "FFD60A")
    static let tapeLight = Color(hex: "FFEC96")
    static let stamp = Color(hex: "FF8A3D")
    static let star = Color(hex: "FFD60A")
    static let wave = Color(hex: "3D7BFF")
    static let flower = Color(hex: "FF5DA2")
    static let moonInk = Color(hex: "1A1A22")
    /// 細い線(白地の上の枠)
    static let line = Color(hex: "E4E4E8")
}

extension Palette {
    /// 夜のパレットか(昼のホームの色はそのまま、夜だけ切りかえるのに使う)
    var isNight: Bool { self == .night }
}

/// 夜のホームの背景:夜の地色に、左上と下の端だけ、ごくうすい暖色のにじみ(粒なし)
struct ChicNightBackground: View {
    private let night = Palette.night

    var body: some View {
        ZStack {
            night.bg
            RadialGradient(colors: [night.accent.opacity(0.06), .clear], center: .topLeading, startRadius: 0, endRadius: 360)
            RadialGradient(colors: [night.accent.opacity(0.06), .clear], center: .bottom, startRadius: 0, endRadius: 380)
        }
    }
}

/// 夜の輪の球(暗いガラス):上が明るい灰、下が黒に近い。上にやわらかいハイライト、縁は暖かい灰のうす線。300×300 の箱。
struct ChicNightSphere: View {
    private let night = Palette.night
    private let side: CGFloat = 250

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(hex: "2A2A30"), Color(hex: "111114")], startPoint: .top, endPoint: .bottom))
            Ellipse()
                .fill(night.ink.opacity(0.14))
                .frame(width: side * 0.5, height: side * 0.16)
                .blur(radius: 10)
                .offset(x: -side * 0.1, y: -side * 0.36)
            Circle().strokeBorder(Color(hex: "C9B8A8").opacity(0.25), lineWidth: 1)
        }
        .frame(width: side, height: side)
        .frame(width: 300, height: 300)
        .accessibilityHidden(true)
    }
}

// MARK: - チェキの紙(フェーズ2:撮影後のホーム)

extension View {
    /// 写真(角のない絵)のまわりに、チェキの白い紙をつける。下だけ厚い。やわらかい影つき。
    /// rotation は、見ためのかたむき(度)。0 ならまっすぐ。
    func chicPrint(side: CGFloat, bottom: CGFloat, rotation: Double = 0) -> some View {
        self
            .padding(.horizontal, side)
            .padding(.top, side)
            .padding(.bottom, bottom)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(ChicColor.instax)
                    .shadow(color: ChicColor.instaxShadow.opacity(0.35), radius: 12, y: 6)
            )
            .rotationEffect(.degrees(rotation))
    }
}

/// 一覧の中の位置(0から)に応じた、かたむき(-1.5° / +1.2° を交互)
enum ChicTilt {
    static func degrees(_ index: Int) -> Double { index % 2 == 0 ? -1.5 : 1.2 }
}

extension HomeState {
    /// 白 × シックのホームで見せる状態(撮る前:first・dawn と、月が出る夜の night・rest)
    var usesChicHome: Bool {
        switch self {
        case .first, .dawn, .night, .rest: return true
        default: return false
        }
    }
}

// MARK: - 落書き(デモのSVGのパスをそのまま写した Shape)

/// 40×40 の箱に描かれた星(M20 3.5 c1.6 7.6 …)
struct ChicStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 40
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        var path = Path()
        path.move(to: p(20, 3.5))
        path.addCurve(to: p(35.5, 19.8), control1: p(21.6, 11.1), control2: p(25.2, 15.1))
        path.addCurve(to: p(20.1, 36.5), control1: p(25.3, 23.4), control2: p(21.6, 27.7))
        path.addCurve(to: p(4, 19.9), control1: p(18.2, 27.7), control2: p(14.5, 23.5))
        path.addCurve(to: p(20, 3.5), control1: p(14.3, 15.5), control2: p(18.2, 11.3))
        path.closeSubpath()
        return path
    }
}

/// 60×24 の箱に描かれた波線(M3 14 c5-9 10-9 13 0 s9 9 13 0 …)
struct ChicWaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 60
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        var path = Path()
        path.move(to: p(3, 14))
        path.addCurve(to: p(16, 14), control1: p(8, 5), control2: p(13, 5))
        path.addCurve(to: p(29, 14), control1: p(19, 23), control2: p(25, 23))
        path.addCurve(to: p(42, 14), control1: p(33, 5), control2: p(38, 5))
        path.addCurve(to: p(56, 13), control1: p(46, 23), control2: p(51, 22))
        return path
    }
}

/// 30×30 の箱に散らした4つの点
struct ChicDotsShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 30
        var path = Path()
        for (x, y, r) in [(6.0, 8.0, 3.0), (18.0, 5.0, 2.2), (24.0, 17.0, 3.4), (11.0, 22.0, 2.0)] as [(CGFloat, CGFloat, CGFloat)] {
            path.addEllipse(in: CGRect(x: rect.minX + (x - r) * s, y: rect.minY + (y - r) * s, width: r * 2 * s, height: r * 2 * s))
        }
        return path
    }
}

/// 40×40 の箱の花(中心(20,20)のまわりに5枚の花びら ellipse cx20 cy10 rx6.5 ry8 + まんなかの円)
struct ChicFlowerDoodle: View {
    @Environment(\.palette) private var palette

    var body: some View {
        let night = palette.isNight
        let fill = night ? palette.ink.opacity(0.4) : ChicColor.flower
        let coreFill = night ? palette.ink.opacity(0.4) : ChicColor.star
        let stroke = night ? palette.ink.opacity(0.5) : ChicColor.ink
        return Canvas { context, size in
            let s = size.width / 40
            let line = 2.2 * s
            for index in 0..<5 {
                var petal = Path(ellipseIn: CGRect(x: (20 - 6.5) * s, y: (10 - 8) * s, width: 13 * s, height: 16 * s))
                let center = CGPoint(x: 20 * s, y: 20 * s)
                let transform = CGAffineTransform(translationX: center.x, y: center.y)
                    .rotated(by: CGFloat(index) * 72 * .pi / 180)
                    .translatedBy(x: -center.x, y: -center.y)
                petal = petal.applying(transform)
                context.fill(petal, with: .color(fill))
                context.stroke(petal, with: .color(stroke), lineWidth: line)
            }
            let core = Path(ellipseIn: CGRect(x: (20 - 5.5) * s, y: (20 - 5.5) * s, width: 11 * s, height: 11 * s))
            context.fill(core, with: .color(coreFill))
            context.stroke(core, with: .color(stroke), lineWidth: line)
        }
    }
}

/// 落書きの種類
enum ChicDoodleKind {
    case star, wave, flower, dots
}

/// 落書き1つ(width を指定。縦は種類ごとの比で決まる)。装飾なので VoiceOver からは隠す。
struct ChicDoodle: View {
    @Environment(\.palette) private var palette
    let kind: ChicDoodleKind
    let width: CGFloat

    var body: some View {
        content
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .star:
            ChicStarShape()
                .fill(palette.isNight ? palette.ink.opacity(0.4) : ChicColor.star)
                .overlay(ChicStarShape().stroke(palette.isNight ? palette.ink.opacity(0.5) : ChicColor.ink, style: StrokeStyle(lineWidth: 2.3 * width / 40, lineJoin: .round)))
                .frame(width: width, height: width)
        case .wave:
            ChicWaveShape()
                .stroke(palette.isNight ? palette.ink.opacity(0.4) : ChicColor.wave, style: StrokeStyle(lineWidth: 4.2 * width / 60, lineCap: .round, lineJoin: .round))
                .frame(width: width, height: width * 24 / 60)
        case .flower:
            ChicFlowerDoodle()
                .frame(width: width, height: width)
        case .dots:
            ChicDotsShape()
                .fill(palette.isNight ? palette.ink.opacity(0.5) : ChicColor.ink)
                .frame(width: width, height: width)
        }
    }
}

// MARK: - 見出しを囲む、手描きの楕円

/// デモの SVG パス(M.12w .18h C … )をそのまま比率で写した、少しゆがんだ楕円
struct ChicScribbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + w * x, y: rect.minY + h * y) }
        var path = Path()
        path.move(to: p(0.12, 0.18))
        path.addCurve(to: p(0.98, 0.52), control1: p(0.5, -0.08), control2: p(1.02, 0.05))
        path.addCurve(to: p(0.04, 0.6), control1: p(0.95, 1.02), control2: p(0.2, 1.05))
        path.addCurve(to: p(0.62, 0.1), control1: p(-0.02, 0.3), control2: p(0.3, 0.06))
        return path
    }
}

/// 手描きの楕円を、0.5秒待って 1.1 秒でなぞり描く。視差効果を減らすときは、描き終えた形を出す。
struct ChicScribble: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    var body: some View {
        ChicScribbleShape()
            .trim(from: 0, to: reduceMotion ? 1 : progress)
            .stroke(palette.accent, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            .padding(.horizontal, -8)
            .padding(.vertical, -6)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                progress = 0
                withAnimation(.timingCurve(0.6, 0, 0.2, 1, duration: 1.1).delay(0.5)) { progress = 1 }
            }
    }
}

// MARK: - マスキングテープ

/// 黄色いテープ(72%の縞)。36×13。呼び出し側で回す。
struct ChicTape: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<9, id: \.self) { index in
                Rectangle()
                    .fill((index % 2 == 0 ? ChicColor.tape : ChicColor.tapeLight).opacity(0.72))
                    .frame(width: 4)
            }
        }
        .frame(width: 36, height: 13)
        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
        .accessibilityHidden(true)
    }
}

// MARK: - 文字の輪 + 点の輪

/// 回る輪:点の輪と、まわりの文字(WORLD LIGHTS — YESTERDAY — 10.25 — LATER —)。300×300 の箱。
struct ChicRingArt: View {
    @Environment(\.palette) private var palette
    /// 「10.25」のような日付
    let dateText: String

    private static let dots: [(angle: Double, radius: CGFloat, size: CGFloat, level: Double)] = {
        var result: [(Double, CGFloat, CGFloat, Double)] = []
        func unit(_ n: Int) -> Double {
            var x = UInt64(truncatingIfNeeded: n) &* 0x9E37_79B9_7F4A_7C15 &+ 0x1A7E_2026
            x = (x ^ (x >> 30)) &* 0xBF58_476D_1CE4_E5B9
            x = (x ^ (x >> 27)) &* 0x94D0_49BB_1331_11EB
            x ^= x >> 31
            return Double(x % 10_000) / 10_000
        }
        var n = 0
        for (ring, spec) in [(66, CGFloat(118)), (54, 100), (42, 82), (30, 64)].enumerated() {
            let count = spec.0
            for index in 0..<count {
                n += 1
                let step = 2 * Double.pi / Double(count)
                result.append((
                    Double(index) * step + (unit(n * 3) - 0.5) * 0.6 * step + Double(ring) * 0.2,
                    spec.1 + CGFloat(unit(n * 5) - 0.5) * 5,
                    CGFloat(1.4 + unit(n * 7) * 1.8),
                    unit(n * 11)
                ))
            }
        }
        return result
    }()

    var body: some View {
        let night = palette.isNight
        let ink = palette.ink
        let dotBase = night ? 0.08 : 0.1
        let dotRange = night ? 0.37 : 0.4
        let textOpacity = night ? 0.45 : 0.55
        return Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for dot in Self.dots {
                let x = center.x + dot.radius * CGFloat(cos(dot.angle))
                let y = center.y + dot.radius * CGFloat(sin(dot.angle))
                let rect = CGRect(x: x - dot.size / 2, y: y - dot.size / 2, width: dot.size, height: dot.size)
                context.fill(Path(ellipseIn: rect), with: .color(ink.opacity(dotBase + dot.level * dotRange)))
            }
            let chars = Array("WORLD LIGHTS — YESTERDAY — \(dateText) — LATER — WORLD LIGHTS — YESTERDAY — \(dateText) — LATER — ")
            let radius: CGFloat = 134
            for (index, ch) in chars.enumerated() where ch != " " {
                let angle = -Double.pi / 2 + 2 * Double.pi * Double(index) / Double(chars.count)
                var layer = context
                layer.translateBy(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
                layer.rotate(by: .radians(angle + Double.pi / 2))
                layer.draw(
                    Text(String(ch)).font(.system(size: 9.4, design: .monospaced)).foregroundColor(ink.opacity(textOpacity)),
                    at: .zero, anchor: .center
                )
            }
        }
        .frame(width: 300, height: 300)
        .accessibilityHidden(true)
    }
}

// MARK: - 月の色

enum ChicMoon {
    /// 夜の月(灰青)
    static let nightGradient = LinearGradient(stops: [
        .init(color: Color(hex: "F4F5FB"), location: 0),
        .init(color: Color(hex: "DFE2F2"), location: 0.12),
        .init(color: Color(hex: "B9BEDD"), location: 0.22),
        .init(color: Color(hex: "8A90B8"), location: 0.38),
        .init(color: Color(hex: "4A4F7A"), location: 0.62),
        .init(color: Color(hex: "1E2040"), location: 1),
    ], startPoint: .top, endPoint: .bottom)
    static let glowLavender = Color(red: 150 / 255, green: 120 / 255, blue: 1).opacity(0.28)
    static let glowPeach = Color(red: 1, green: 170 / 255, blue: 130 / 255).opacity(0.25)
}
