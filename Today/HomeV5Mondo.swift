import SwiftUI
import UIKit

// Home v5 の MONDO 画面。点の地球 → 見出し → 昨日多かったハッシュタグのランキング → すべての昨日 → 終わり。
// 数字(順位・光の数)は、ハッシュタグに対してだけ出す。人や写真1枚ごとの数字・順位は出さない。

// MARK: - 読みこみ

@MainActor
@Observable
final class MondoV5Loader {
    enum Phase: Equatable {
        case loading, empty, notReady, failed
        case ready(MondoDaySummary)
    }

    private(set) var phase: Phase = .loading
    private var loadedDayKey: String?

    func load(now: Date, blocked: Set<String>, force: Bool = false) async {
        let dayKey = MondoWindow.yesterdayKey(now: now)
        if !force, loadedDayKey == dayKey, case .ready = phase { return }
        if case .ready = phase {} else { phase = .loading }
        do {
            let summary = try await MondoService.shared.fetchDay(dayKey: dayKey, blocked: blocked)
            WorldCountStore.shared.record(summary)
            loadedDayKey = dayKey
            withAnimation(.easeOut(duration: 0.4)) {
                phase = summary.entries.isEmpty ? .empty : .ready(summary)
            }
        } catch MondoService.FetchError.notReady {
            withAnimation { phase = .notReady }
        } catch {
            withAnimation { phase = .failed }
        }
    }
}

// MARK: - 地球

// MARK: - 地球儀の回転(v14 ①)

typealias GlobeVector = (x: Double, y: Double, z: Double)

/// 3×3 の回転行列(行優先)。R = Rx(dy)·Ry(dx)·R でかけ足す(モックの rot() と同じ)
enum GlobeRotation {
    static let identity: [Double] = [1, 0, 0, 0, 1, 0, 0, 0, 1]

    static func rx(_ a: Double) -> [Double] { let c = cos(a), s = sin(a); return [1, 0, 0, 0, c, -s, 0, s, c] }
    static func ry(_ a: Double) -> [Double] { let c = cos(a), s = sin(a); return [c, 0, s, 0, 1, 0, -s, 0, c] }

    static func multiply(_ a: [Double], _ b: [Double]) -> [Double] {
        var o = [Double](repeating: 0, count: 9)
        for i in 0..<3 { for j in 0..<3 { o[i * 3 + j] = a[i * 3] * b[j] + a[i * 3 + 1] * b[3 + j] + a[i * 3 + 2] * b[6 + j] } }
        return o
    }

    static func apply(_ m: [Double], _ v: GlobeVector) -> GlobeVector {
        (m[0] * v.x + m[1] * v.y + m[2] * v.z, m[3] * v.x + m[4] * v.y + m[5] * v.z, m[6] * v.x + m[7] * v.y + m[8] * v.z)
    }

    /// ドラッグ(dx:横 → 縦軸まわり / dy:縦 → 横軸まわり)を、いまの回転にかけ足す
    static func step(_ r: [Double], dx: Double, dy: Double) -> [Double] {
        multiply(multiply(rx(dy), ry(dx)), r)
    }

    /// 最初の向き(少し傾けて日本のあたり)
    static let initial: [Double] = multiply(ry(-2.4), multiply(rx(-0.5), identity))
}

/// 回転・慣性(×0.95/フレーム)・自動のゆっくり斜め回転・12°ごとの tick
@MainActor @Observable
final class GlobeSpinner {
    var matrix: [Double] = GlobeRotation.initial
    var velocity: (dx: Double, dy: Double) = (0, 0)
    var dragging = false
    @ObservationIgnored private var accumulated: Double = 0
    @ObservationIgnored private var wasCoasting = false

    static let tickStep = 12.0 * .pi / 180
    static let friction = 0.95

    func rotate(dx: Double, dy: Double, onTick: () -> Void) {
        matrix = GlobeRotation.step(matrix, dx: dx, dy: dy)
        accumulated += hypot(dx, dy)
        while accumulated >= Self.tickStep {
            accumulated -= Self.tickStep
            Haptics.play(.tick, gap: 0.055)
            onTick()
        }
    }

    /// 60fps で、慣性 → 止まったら soft → 触っていなければ ゆっくり斜めに自動回転
    func run(autoSpin: Bool, onTick: @escaping () -> Void) async {
        var t = 0.0
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(16))
            t += 1.0 / 60
            guard !dragging else { continue }
            let speed = hypot(velocity.dx, velocity.dy)
            if speed > 0.0004 {
                rotate(dx: velocity.dx, dy: velocity.dy, onTick: onTick)
                velocity = (velocity.dx * Self.friction, velocity.dy * Self.friction)
                wasCoasting = true
            } else {
                if wasCoasting {
                    wasCoasting = false
                    Haptics.play(.soft)
                }
                velocity = (0, 0)
                if autoSpin {
                    matrix = GlobeRotation.step(matrix, dx: 0.0032 / 2, dy: sin(t / 3) * 0.0012 / 2)
                }
            }
        }
    }
}

/// フィボナッチ球(約725点)。1周 約60秒。奥の点ほどうすく小さく。指でなぞって回せる(約12°ごとに触覚)。
/// 白いガラスの球体+細い縁。その中に、写真が光る点(約46個)がまたたく。光る点は1つの Canvas にまとめて描く。
struct V5Globe: View {
    var diameter: CGFloat = 222
    var isAnimating = true
    var onTick: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.palette) private var palette
    /// v14 ①:回転は 3×3 行列で持ち、毎回かけ足す(yaw / pitch の2つの角度では持たない)
    @State private var spinner = GlobeSpinner()
    @State private var lastTranslation: CGSize = .zero
    @AppStorage("mondo.globeHintSeen") private var hintSeen = false

    /// 地球の大きさは、画面の幅から決める(固定の数字にしない)
    static func diameter(forWidth width: CGFloat) -> CGFloat {
        min(max(width, 0) * 0.64, 280)
    }

    /// Mondo のページでの大きさ(約222pt。狭い画面では幅に合わせて小さく)
    static func pageDiameter(forWidth width: CGFloat) -> CGFloat {
        min(222, diameter(forWidth: width))
    }

    private static let pointCount = 725
    private static let glintCount = 46
    private static let tickStep = 12.0 * .pi / 180

    private static let points: [(x: Double, y: Double, z: Double)] = {
        let golden = Double.pi * (3 - 5.0.squareRoot())
        return (0..<pointCount).map { i in
            let y = 1 - (Double(i) + 0.5) / Double(pointCount) * 2
            let r = (1 - y * y).squareRoot()
            let theta = golden * Double(i)
            return (cos(theta) * r, y, sin(theta) * r)
        }
    }()

    /// 写真が光る点(日々同じ場所でよい)
    private static let glints: [Int: Double] = {
        var g = SeededGenerator(seed: "v5-glints")
        var result: [Int: Double] = [:]
        while result.count < glintCount {
            result[Int(g.next() % UInt64(pointCount))] = Double(g.next() % 628) / 100
        }
        return result
    }()

    /// 球のまわりのやわらかい光(昼だけ。桃とラベンダー、20% → 0、約40pt外へ)
    private var glow: some View {
        let r = diameter / 2
        return ZStack {
            if !palette.isNight {
                glowCircle(Color(hex: "FFAA82"), dx: -14, dy: -10, r: r)
                glowCircle(Color(hex: "9678FF"), dx: 14, dy: 10, r: r)
            }
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
    }

    private func glowCircle(_ color: Color, dx: CGFloat, dy: CGFloat, r: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(0.2), color.opacity(0)], center: .center, startRadius: r - 8, endRadius: r + 40))
            .frame(width: diameter + 80, height: diameter + 80)
            .offset(x: dx, y: dy)
    }

    var body: some View {
        let animate = isAnimating && !reduceMotion
        let night = palette.isNight
        let ink = palette.ink
        let accent = palette.accent
        return ZStack {
            glow
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animate)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let m = spinner.matrix
                Canvas { ctx, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = min(size.width, size.height) / 2 - 1
                    let tilt = 0.35
                    let body = Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
                    if night {
                        ctx.fill(body, with: .linearGradient(
                            Gradient(colors: [Color(hex: "2A2A30"), Color(hex: "09090B")]),
                            startPoint: CGPoint(x: c.x, y: c.y - radius), endPoint: CGPoint(x: c.x, y: c.y + radius)
                        ))
                        let hl = CGPoint(x: c.x - radius * 0.25, y: c.y - radius * 0.55)
                        let hr = radius * 0.55
                        ctx.fill(Path(ellipseIn: CGRect(x: hl.x - hr, y: hl.y - hr * 0.5, width: hr * 2, height: hr)),
                                 with: .radialGradient(Gradient(colors: [.white.opacity(0.22), .white.opacity(0)]), center: hl, startRadius: 0, endRadius: hr))
                        ctx.stroke(body, with: .color(.white.opacity(0.14)), lineWidth: 1)
                    } else {
                        ctx.fill(body, with: .linearGradient(
                            Gradient(stops: [
                                .init(color: Color(hex: "FAFAFB"), location: 0),
                                .init(color: Color(hex: "F2F2F5"), location: 0.5),
                                .init(color: Color(hex: "E8E8ED"), location: 1),
                            ]),
                            startPoint: CGPoint(x: c.x - radius * 0.7, y: c.y - radius * 0.7),
                            endPoint: CGPoint(x: c.x + radius * 0.7, y: c.y + radius * 0.7)
                        ))
                        ctx.stroke(body, with: .color(Color(hex: "111111").opacity(0.18)), lineWidth: 1)
                    }
                    // 3本の大円(経線・赤道・もう1本の経線):縦にも回っているのが分かる
                    for k in 0..<3 {
                        var path = Path()
                        var on = false
                        for i in 0...96 {
                            let a = Double(i) / 96 * 2 * .pi
                            let v: GlobeVector = k == 0 ? (cos(a), 0, sin(a)) : (k == 1 ? (cos(a), sin(a), 0) : (0, cos(a), sin(a)))
                            let r = GlobeRotation.apply(m, v)
                            guard r.z >= 0 else { on = false; continue }
                            let pt = CGPoint(x: c.x + CGFloat(r.x) * radius, y: c.y - CGFloat(r.y) * radius)
                            if on { path.addLine(to: pt) } else { path.move(to: pt); on = true }
                        }
                        ctx.stroke(path, with: .color(ink.opacity(0.16)), lineWidth: 0.9)
                    }
                    _ = tilt
                    for (index, p) in Self.points.enumerated() {
                        let rotated = GlobeRotation.apply(m, (p.x, p.y, p.z))
                        let x = rotated.x, y = rotated.y, z = rotated.z
                        let depth = (z + 1) / 2
                        let point = CGPoint(x: c.x + CGFloat(x) * radius, y: c.y - CGFloat(y) * radius)
                        if let phase = Self.glints[index] {
                            guard depth > 0.35 else { continue }
                            let blink = 0.55 + 0.45 * sin(t * 1.6 + phase)
                            let r = 2.2 + 1.6 * blink
                            // 光の点:橙のやわらかいにじみ(点の半径の4倍、40% → 0)+ 点
                            let g = r / 2 * 4
                            ctx.fill(Path(ellipseIn: CGRect(x: point.x - g, y: point.y - g, width: g * 2, height: g * 2)),
                                     with: .radialGradient(Gradient(colors: [accent.opacity(0.4), accent.opacity(0)]), center: point, startRadius: 0, endRadius: g))
                            ctx.fill(Path(ellipseIn: CGRect(x: point.x - r / 2, y: point.y - r / 2, width: r, height: r)), with: .color(accent))
                            continue
                        }
                        // 手前 90%、奥 18%
                        let r = 0.55 + 0.75 * depth
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                            with: .color(ink.opacity(0.18 + 0.72 * depth))
                        )
                    }
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        // 地球の上で始めた横の動きは、Profile を開くスワイプにしない
        .background(GeometryReader { proxy in
            Color.clear.preference(key: HomeNoSwipeRegionKey.self, value: [proxy.frame(in: .global)])
        })
        .overlay(alignment: .bottom) {
            // 初回だけ「ドラッグで ぐるぐる」。触ったら消す
            if !hintSeen {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 12, weight: .bold))
                    Text("ドラッグで ぐるぐる").font(.system(size: 10.5, weight: .bold, design: .monospaced)).tracking(0.14 * 10.5)
                }
                .foregroundStyle(palette.groupAdd.note)
                .offset(y: 26)
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    if !spinner.dragging {
                        spinner.dragging = true
                        lastTranslation = .zero
                        Haptics.play(.soft)
                        if !hintSeen { withAnimation(.easeOut(duration: 0.4)) { hintSeen = true } }
                    }
                    // 横の移動 → 縦軸まわり、縦の移動 → 横軸まわり
                    let dx = Double(value.translation.width - lastTranslation.width) / Double(diameter) * 2.2
                    let dy = Double(value.translation.height - lastTranslation.height) / Double(diameter) * 2.2
                    lastTranslation = value.translation
                    spinner.rotate(dx: dx, dy: dy, onTick: onTick)
                    spinner.velocity = (dx, dy)
                }
                .onEnded { _ in
                    spinner.dragging = false
                    lastTranslation = .zero
                    if hypot(spinner.velocity.dx, spinner.velocity.dy) > 0.01 { Haptics.play(.soft) }
                }
        )
        .task(id: animate) { await spinner.run(autoSpin: animate, onTick: onTick) }
        .consumesTap()
        .accessibilityHidden(true)
    }
}

// MARK: - 落書き(地球のまわり)

/// 太陽(円+8本の光)。40×40 の箱。
private struct MondoSunShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 40
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        path.addEllipse(in: CGRect(x: c.x - 8 * s, y: c.y - 8 * s, width: 16 * s, height: 16 * s))
        for i in 0..<8 {
            let a = Double(i) / 8 * 2 * .pi
            path.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * 12 * s, y: c.y + CGFloat(sin(a)) * 12 * s))
            path.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * 17.5 * s, y: c.y + CGFloat(sin(a)) * 17.5 * s))
        }
        return path
    }
}

private struct MondoSunDoodle: View {
    @Environment(\.palette) private var palette
    let width: CGFloat

    var body: some View {
        let night = palette.isNight
        MondoSunShape()
            .stroke(night ? palette.ink.opacity(0.4) : ChicColor.ink, style: StrokeStyle(lineWidth: 2.3 * width / 40, lineCap: .round, lineJoin: .round))
            .background(
                Circle().fill(night ? palette.ink.opacity(0.4) : ChicColor.star)
                    .frame(width: width * 0.4, height: width * 0.4)
            )
            .frame(width: width, height: width)
    }
}

/// ゆっくり上下(4pt・1周3.2秒)とゆれ(6°)。止める条件のときは、そっと元にもどる。
private struct FloatingDoodle<Content: View>: View {
    let running: Bool
    let delay: Double
    @ViewBuilder let content: Content
    @State private var up = false

    var body: some View {
        content
            .offset(y: up ? 2 : -2)
            .rotationEffect(.degrees(up ? 3 : -3))
            .onChange(of: running, initial: true) { _, isRunning in
                if isRunning {
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(delay)) { up = true }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) { up = false }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// 地球と、そのまわりの4つの落書き(星・波・太陽・点)。撮る前は落書きだけ50%の濃さ。
private struct MondoGlobeStage: View {
    let width: CGFloat
    let diameter: CGFloat
    let isActive: Bool
    let locked: Bool
    let onTick: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = true

    var body: some View {
        let running = isActive && visible && !reduceMotion
        let h = diameter + 12
        return ZStack(alignment: .topLeading) {
            V5Globe(diameter: diameter, isAnimating: isActive && visible, onTick: onTick)
                .frame(width: width, height: diameter)
                .padding(.top, 6)

            ZStack(alignment: .topLeading) {
                FloatingDoodle(running: running, delay: 0) { ChicDoodle(kind: .star, width: 34) }
                    .position(x: 40, y: 30)
                FloatingDoodle(running: running, delay: 0.5) { ChicDoodle(kind: .wave, width: 58) }
                    .position(x: width - 50, y: 34)
                FloatingDoodle(running: running, delay: 1.0) { MondoSunDoodle(width: 36) }
                    .position(x: width - 34, y: h * 0.58)
                FloatingDoodle(running: running, delay: 1.5) { ChicDoodle(kind: .dots, width: 30) }
                    .position(x: 38, y: h - 30)
            }
            .frame(width: width, height: h, alignment: .topLeading)
            .opacity(locked ? 0.5 : 1)
            .animation(.easeInOut(duration: 1.4), value: locked)
        }
        .frame(width: width, height: h)
        .onScrollVisibilityChange(threshold: 0.05) { visible = $0 }
    }
}

// MARK: - 流れる黒い帯

/// 黒い帯(高さ32・-1.2°・幅は画面の110%)。26秒で1周、つなぎ目なく流れる。
/// 画面の外・背景・視差効果を減らすときは止まる。
private struct MondoBand: View {
    let width: CGFloat
    let lights: Int?
    let countries: Int?
    let dayLabel: String
    let isActive: Bool

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copyWidth: CGFloat = 0
    @State private var visible = true

    private static let period: Double = 26

    private var copy: Text {
        let lightsText = lights.map { "\($0) LIGHTS" } ?? "LIGHTS"
        let countriesText = countries.map { "\($0) COUNTRIES" } ?? "COUNTRIES"
        let rest = " \(lightsText)     \(countriesText)     YESTERDAY \(dayLabel)     今日を撮ると、ひらく     "
        return Text("●").foregroundColor(ChicColor.stamp) + Text(rest)
    }

    private func copyView() -> some View {
        copy
            .font(.system(size: 11.5, design: .monospaced))
            .tracking(0.14 * 11.5)
            .lineLimit(1)
            .fixedSize()
    }

    var body: some View {
        let night = palette.isNight
        let bandWidth = width * 1.1
        let running = isActive && visible && !reduceMotion
        let textColor: Color = night ? .black : .white
        return TimelineView(.animation(paused: !running)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = CGFloat(t.truncatingRemainder(dividingBy: Self.period) / Self.period)
            let offset = copyWidth > 0 ? -phase * copyWidth : 0
            HStack(spacing: 0) {
                copyView()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { copyWidth = $0 }
                copyView()
            }
            .foregroundStyle(textColor)
            .offset(x: offset)
            .frame(width: bandWidth, height: 32, alignment: .leading)
            .clipped()
        }
        .background(night ? palette.ink : Color(hex: "111111"))
        .rotationEffect(.degrees(-1.2))
        .frame(width: bandWidth)
        .frame(width: width)
        .padding(.top, 4)
        .padding(.bottom, 22)
        .onScrollVisibilityChange(threshold: 0.01) { visible = $0 }
        .accessibilityHidden(true)
    }
}

// MARK: - 昨日の一枚(大きなチェキ)

/// マスキングテープ(84×22・6ptごとの縞・72%)
private struct MondoTape: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<14, id: \.self) { index in
                Rectangle()
                    .fill((index % 2 == 0 ? ChicColor.tape : ChicColor.tapeLight).opacity(0.72))
                    .frame(width: 6)
            }
        }
        .frame(width: 84, height: 22)
        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
        .accessibilityHidden(true)
    }
}

/// 手書き風の太い丸ゴシック(Zen Kurenaido が入るまでの代わり)
private func mondoHandFont(_ size: CGFloat) -> Font {
    .system(size: size, weight: .heavy, design: .rounded)
}

/// 昨日の一枚。紙は幅 = 画面 - 56、高さ 470、-1.5°。撮る前は写真をぼかして「今日を撮ると、ひらく」。
private struct MondoBigPrint: View {
    static let height: CGFloat = 470

    let pick: AnnouncedPick
    let width: CGFloat
    let locked: Bool
    let onOpen: (CGPoint) -> Void

    private var stampText: String {
        let parts = pick.day.split(separator: "-")
        guard parts.count == 3 else { return pick.day }
        return "'\(parts[0].suffix(2)) \(parts[1]) \(parts[2])"
    }

    var body: some View {
        let photoWidth = max(0, width - 24)
        let photoHeight = Self.height - 12 - 66
        return ZStack(alignment: .topLeading) {
            photo(width: photoWidth, height: photoHeight)
                .padding(.leading, 12)
                .padding(.top, 12)
        }
        .frame(width: width, height: Self.height, alignment: .topLeading)
        .background {
            ZStack {
                // 影:#281E14 50%・ぼかし50・下へ34・縮め26
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(ChicColor.instaxShadow.opacity(0.5))
                    .padding(26)
                    .offset(y: 34)
                    .blur(radius: 25)
                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(ChicColor.instax)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(.black.opacity(0.05), lineWidth: 0.5))
        .overlay(alignment: .bottomLeading) { tags }
        .overlay(alignment: .top) {
            MondoTape()
                .rotationEffect(.degrees(3))
                .offset(y: -11)
        }
        .rotationEffect(.degrees(-1.5))
        .padding(.bottom, 8)
        .contentShape(Rectangle())
        .onSpatialTap(perform: onOpen)
        .allowsHitTesting(!locked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(locked ? "今日を撮ると、ひらく" : "昨日の一枚。\(pick.tags.map { "#\($0)" }.joined(separator: " "))")
    }

    private func photo(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            AnnouncedPhoto(pick: pick)
                .frame(width: width, height: height)
                .clipped()
                .saturation(locked ? 0.9 : 1)
                .brightness(locked ? 0.06 : 0)
                .blur(radius: locked ? 18 : 0, opaque: true)

            // 上の30%だけ暗く(黒32% → 0)
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.32), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: height * 0.3)
                Spacer(minLength: 0)
            }
            .allowsHitTesting(false)

            // 日付のスタンプ(右下)
            Text(stampText)
                .font(V5.mono(14, weight: .bold))
                .tracking(0.08 * 14)
                .foregroundStyle(ChicColor.stamp)
                .shadow(color: ChicColor.stamp.opacity(0.9), radius: 3)
                .shadow(color: ChicColor.stamp.opacity(0.5), radius: 8)
                .lineLimit(1)
                .padding(.trailing, 12)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .opacity(locked ? 0 : 1)

            lockOverlay
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .animation(.easeInOut(duration: 1.4), value: locked)
    }

    /// 下の厚いところの手書き風のハッシュタグ(左22・下18)
    private var tags: some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            ForEach(Array(pick.tags.prefix(2).enumerated()), id: \.offset) { index, tag in
                Text("#\(tag)")
                    .font(mondoHandFont(index == 0 ? 27 : 20))
                    .foregroundStyle(Color(hex: "2A2A2E").opacity(index == 0 ? 1 : 0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(maxWidth: width - 44, alignment: .leading)
        .padding(.leading, 22)
        .padding(.bottom, 18)
        .blur(radius: locked ? 6 : 0)
        .opacity(locked ? 0.6 : 1)
        .animation(.easeInOut(duration: 1.4), value: locked)
        .allowsHitTesting(false)
    }

    private var lockOverlay: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(.white)
                .frame(width: 66, height: 66)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 8)
                .overlay {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.black)
                }
            Text("今日を撮ると、ひらく")
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white))
        }
        .opacity(locked ? 1 : 0)
        .allowsHitTesting(false)
    }
}

// MARK: - 順位の数字(1位は橙、ほかはインクの輪郭だけ)

private struct OutlineNumber: View {
    @Environment(\.palette) private var palette
    let text: String
    let isTop: Bool

    var body: some View {
        // Instrument Serif が入るまでは、システムの明朝(セリフ)イタリックで代用
        let font = Font.system(size: 66, design: .serif).italic()
        ZStack {
            if isTop {
                Text(text)
                    .font(font)
                    .foregroundStyle(palette.accent)
            } else {
                // 輪郭だけ:インクをずらして重ね、中をカードの色で抜く
                ForEach(0..<8, id: \.self) { i in
                    let a = Double(i) / 8 * 2 * .pi
                    Text(text).font(font).foregroundStyle(palette.ink.opacity(0.7))
                        .offset(x: CGFloat(cos(a)) * 1.1, y: CGFloat(sin(a)) * 1.1)
                }
                Text(text).font(font).foregroundStyle(palette.isNight ? Color(hex: "1B1B1F") : palette.fill)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .accessibilityHidden(true)
    }
}

// MARK: - v49 見出し(地球の o・1文字ずつ ブラーから・「yesterday.」は 光る・世界の いまの時計)

/// 「MONDO · NOV 11」の 前の、脈打つ 点
private struct MondoPulsingDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle().fill(Darkroom.orange).opacity(pulse ? 0 : 0.55).scaleEffect(pulse ? 2.6 : 1)
            Circle().fill(Darkroom.orange)
        }
        .frame(width: 7, height: 7)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) { pulse = true }
        }
        .accessibilityHidden(true)
    }
}

/// 見出しの 文字を 1つずつ・ブラーから あらわれる(appeared が true に なるとき だけ)
private struct MondoLetterRow: View {
    let text: String
    let startIndex: Int
    let font: Font
    let color: Color
    let appeared: Bool
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { i, ch in
                Text(verbatim: ch == " " ? "\u{00A0}" : String(ch))
                    .font(font)
                    .foregroundStyle(color)
                    .opacity(appeared ? 1 : 0)
                    .blur(radius: appeared ? 0 : 6)
                    .offset(y: appeared ? 0 : 7)
                    .rotationEffect(.degrees(appeared ? 0 : 8))
                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.72).delay(Double(startIndex + i) * 0.045), value: appeared)
            }
        }
        .fixedSize()
    }
}

/// 「yesterday.」:1文字ずつ あらわれたあと、緑のグラデーションが やさしく 光りつづける
private struct MondoShineRow: View {
    let text: String
    let startIndex: Int
    let font: Font
    let appeared: Bool
    let reduceMotion: Bool

    private static let shineColors = [Darkroom.orange, Darkroom.paleGreen, Darkroom.orange, Color(hex: "C8F25A"), Darkroom.orange]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = (t / 5).truncatingRemainder(dividingBy: 1)
            let shift = CGFloat(phase) * 2.4 - 1.2
            HStack(spacing: 0) {
                ForEach(Array(text.enumerated()), id: \.offset) { i, ch in
                    Text(verbatim: String(ch))
                        .font(font)
                        .foregroundStyle(LinearGradient(colors: Self.shineColors, startPoint: UnitPoint(x: shift, y: 0), endPoint: UnitPoint(x: shift + 1.3, y: 0)))
                        .opacity(appeared ? 1 : 0)
                        .blur(radius: appeared ? 0 : 6)
                        .offset(y: appeared ? 0 : 7)
                        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.72).delay(Double(startIndex + i) * 0.045), value: appeared)
                }
            }
            .fixedSize()
        }
    }
}

/// 「w◯rld」の o が 地球:ゆっくり自転。押すと ぷにっと はやく回る(タップしても 画面は 動かない)
private struct MondoGlobeGlyph: View {
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var kickUntil: Date = .distantPast

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let kicking = context.date < kickUntil
            let duration = kicking ? 0.6 : 4.0
            let angle = (t.truncatingRemainder(dividingBy: duration) / duration) * 360
            ZStack {
                Circle().fill(Darkroom.orange)
                Image(systemName: "globe")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(.white.opacity(0.92))
                    .rotation3DEffect(.degrees(reduceMotion ? 0 : angle), axis: (x: 0, y: 1, z: 0))
                Circle().fill(Darkroom.star).frame(width: 5, height: 5).offset(x: 7, y: -8)
            }
        }
        .frame(width: 36, height: 36)
        .contentShape(Circle())
        .onTapGesture {
            Haptics.play(.pop)
            kickUntil = Date().addingTimeInterval(1.4)
            onTap()
        }
        .accessibilityHidden(true)
    }
}

/// 手描き風の線(「yesterday.」の下に、1本だけ すっと引かれる)
private struct HandDrawnUnderline: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w * 0.013, y: h * 0.69))
        p.addCurve(to: CGPoint(x: w * 0.667, y: h * 0.385),
                   control1: CGPoint(x: w * 0.2, y: h * 0.23),
                   control2: CGPoint(x: w * 0.433, y: h * 0.154))
        p.addCurve(to: CGPoint(x: w * 0.98, y: h * 0.4615),
                   control1: CGPoint(x: w * 0.9, y: h * 0.6154),
                   control2: CGPoint(x: w * 0.9333, y: h * 0.6923))
        return p
    }
}

/// MONDO の 見出し全体(点・日付・「The w🌐rld, yesterday.」・下線)
/// isActive が 変わった(タブを 切りかえて Mondo に 入った)ときだけ、もう一度 さいせい。タグの えらびなおしでは 動かない。
private struct MondoHeading: View {
    let dayKey: String
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 既定で 見える(入場アニメが なにかの理由で 動かなくても、文字が 消えたままには ならない)
    @State private var appeared = true
    @State private var didPlayEntrance = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                MondoPulsingDot()
                Text(verbatim: "MONDO · \(V5.monthDay(fromDayKey: dayKey).uppercased())")
                    .font(Darkroom.mono(10)).tracking(0.26 * 10).foregroundStyle(Darkroom.weak)
            }
            VStack(alignment: .leading, spacing: 2) {
                line1
                ZStack(alignment: .bottomLeading) {
                    line2
                    HandDrawnUnderline()
                        .trim(from: 0, to: appeared ? 1 : 0)
                        .stroke(Color(hex: "C8F25A"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 150, height: 14)
                        .offset(y: 8)
                        .opacity(reduceMotion ? 0 : 1)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).delay(1.0), value: appeared)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("MONDO。The world, yesterday.")
        .onAppear { playEntranceOnce() }
        .onChange(of: isActive) { _, active in
            guard active, didPlayEntrance, !reduceMotion else { return }
            replay()
        }
    }

    /// 最初の 1回だけ(見えている状態から、ふわっと あらわれる)。2回目以降は onChange の replay() だけが 動かす。
    /// 消す→出すを 同じ 瞬間に 並べると、SwiftUI が 2つの 変化を 1つに まとめてしまい、
    /// 文字が 消えた まま 戻らない ことが あった(実機で 確認ずみ)。すこし 間を あけて 確実に 別々の 更新に する。
    private func playEntranceOnce() {
        guard !didPlayEntrance else { return }
        didPlayEntrance = true
        guard !reduceMotion else { return }
        appeared = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { appeared = true }
    }

    private func replay() {
        appeared = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { appeared = true }
    }

    private var line1: some View {
        HStack(spacing: 0) {
            MondoLetterRow(text: "The w", startIndex: 0, font: .custom("InstrumentSerif-Regular", size: 58), color: .primary, appeared: appeared, reduceMotion: reduceMotion)
            MondoGlobeGlyph {}
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.2)
                .rotationEffect(.degrees(appeared ? 0 : -120))
                .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.62).delay(0.38), value: appeared)
            MondoLetterRow(text: "rld,", startIndex: 7, font: .custom("InstrumentSerif-Regular", size: 58), color: .primary, appeared: appeared, reduceMotion: reduceMotion)
        }
    }

    private var line2: some View {
        MondoShineRow(text: "yesterday.", startIndex: 12, font: .custom("InstrumentSerif-Italic", size: 64), appeared: appeared, reduceMotion: reduceMotion)
    }
}

/// 世界の いまの時間の帯:TOKYO・SEOUL・BANGKOK・PARIS・LONDON・NEW YORK・L.A.・SYDNEY。
/// 現地が 9〜21時なら 緑の点。26秒で 1周、つなぎ目なく 流れる。
private struct MondoWorldClockBand: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copyWidth: CGFloat = 0
    @State private var visible = true
    @State private var now = Date()

    private static let cities: [(name: String, utcOffset: Double)] = [
        ("TOKYO", 9), ("SEOUL", 9), ("BANGKOK", 7), ("PARIS", 1),
        ("LONDON", 0), ("NEW YORK", -5), ("L.A.", -8), ("SYDNEY", 11),
    ]
    private static let period: Double = 26

    private var line: Text {
        let utc = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "UTC") ?? .gmt, from: now)
        let hour = Double(utc.hour ?? 0) + Double(utc.minute ?? 0) / 60
        return Self.cities.reduce(Text(verbatim: "")) { acc, city in
            let local = ((hour + city.utcOffset).truncatingRemainder(dividingBy: 24) + 24).truncatingRemainder(dividingBy: 24)
            let hh = Int(local)
            let mm = Int((local - Double(hh)) * 60)
            let on = hh >= 9 && hh < 21
            let seg = Text(Image(systemName: "circle.fill")).font(.system(size: 5)).foregroundColor(on ? Darkroom.orange : Darkroom.faint)
                + Text(verbatim: "  \(city.name) ")
                + Text(verbatim: String(format: "%d:%02d", hh, mm)).fontWeight(.bold)
                + Text(verbatim: "     ")
            return acc + seg
        }
    }

    private func lineView() -> some View {
        line
            .font(.system(size: 10, design: .monospaced))
            .tracking(0.14 * 10)
            .foregroundStyle(Darkroom.weak)
            .lineLimit(1)
            .fixedSize()
    }

    var body: some View {
        let running = isActive && visible && !reduceMotion
        return TimelineView(.animation(paused: !running)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = CGFloat(t.truncatingRemainder(dividingBy: Self.period) / Self.period)
            let offset = copyWidth > 0 ? -phase * copyWidth : 0
            HStack(spacing: 0) {
                lineView().onGeometryChange(for: CGFloat.self) { $0.size.width } action: { copyWidth = $0 }
                lineView()
            }
            .offset(x: offset)
        }
        .frame(height: 30)
        .clipped()
        .mask(LinearGradient(colors: [.clear, .black, .black, .clear], startPoint: .leading, endPoint: .trailing))
        .overlay(alignment: .top) { Rectangle().fill(Darkroom.line).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Darkroom.line).frame(height: 1) }
        .onScrollVisibilityChange(threshold: 0.01) { visible = $0 }
        .task {
            while !Task.isCancelled {
                now = Date()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - MONDO 画面

struct HomeV5MondoPage: View {
    let phase: MondoV5Loader.Phase
    let dayKey: String
    let isActive: Bool
    let topInset: CGFloat
    let onTick: () -> Void
    let onSettings: () -> Void
    let onRetry: () -> Void
    /// ランキングの行、またはその中の写真を押した(押した位置・タグ・押した写真)
    let onOpenTag: (_ point: CGPoint, _ tag: String, _ entryID: String?) -> Void
    /// 「すべての昨日」のカードを押した
    let onOpenAll: (_ point: CGPoint, _ index: Int) -> Void
    /// 昨日の一枚(発表ずみ)。なければカードを出さない(初日・灯ゼロの日)
    var announced: AnnouncedPick?
    var onOpenAnnounced: (_ point: CGPoint) -> Void = { _ in }
    /// 増えるたびに、いちばん上まで滑らかにもどる(選択ずみのタブをもう一度タップ)
    var scrollToTopToken = 0
    /// 今日を撮る前に昨日のホームをひらいた:昨日のものはぼかして、ロックする(件数と地球は見える)
    var locked = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// v54:ScrollView を GeometryReader で 包むと、中の TimelineView(世界時計の帯)が
    /// 動くたびに スクロールの 位置計算が くずれ、見出しから 下が 見えなくなる ことが あった(実機で確認ずみ)。
    /// GeometryReader は 使わず、大きさは onGeometryChange で 一度だけ 受けとる。
    @State private var pageSize: CGSize = .zero
    /// v23:カギの 知らせ(0.6秒 ロックの ままなら 出す。解禁ずみで 一瞬 出ないように)
    @State private var showsLockNotice = false
    @State private var toast: String?
    /// v37:WORDS で えらんだ タグ(nil = EVERYONE)
    @State private var selectedTag: String?
    /// v37:ダブルタップで ひかりを ともした 写真(数は 出ない。端末だけ)
    @State private var lit: Set<String> = []
    /// v37:長押しで えらんだ「あなたの 1枚」(1日 1枚・24:00まで かえられる。端末だけ)
    @State private var yourOneID: String?
    /// v47:「Your one」未選択で押したとき、写真の一覧へ スクロールして ゆらす
    @State private var scrollToGridToken = 0
    @State private var shakeGrid = false

    private var summaryEntries: [MondoEntry] {
        if case .ready(let s) = phase { return s.entries }
        return []
    }

    private var summary: MondoDaySummary? {
        if case .ready(let s) = phase { return s }
        return nil
    }

    private var ranking: [RankedTag] {
        guard let summary else { return [] }
        return TagRanking.rank(summary.topTags, dayKey: summary.dayKey)
    }

    private var lights: [MondoLight] { MondoGeo.lights(from: summaryEntries) }

    /// タグを えらんで いれば その タグの 写真、でなければ 「すべての 昨日」
    private var gridEntries: [MondoEntry] {
        guard let summary else { return [] }
        if let tag = selectedTag { return TagRanking.photos(for: tag, in: summary.entries, dayKey: summary.dayKey) }
        return Array(summary.entries.prefix(MondoConfig.maxCards))
    }

    private var yourOneEntry: MondoEntry? {
        guard let yourOneID else { return nil }
        return summaryEntries.first { $0.id == yourOneID }
    }

    var body: some View {
        ScrollViewReader { reader in
            ZStack(alignment: .top) {
                Darkroom.bg.ignoresSafeArea()
                ScrollView(.vertical) {
                    page(width: pageSize.width, height: pageSize.height)
                        .padding(.top, topInset + 8)
                        .padding(.bottom, 130)
                        .containerRelativeFrame(.horizontal)
                        .id("v5top")
                }
                .scrollIndicators(.hidden)
                .onChange(of: scrollToTopToken) { _, _ in
                    withAnimation(.easeInOut(duration: 0.45)) { reader.scrollTo("v5top", anchor: .top) }
                }
                .onChange(of: scrollToGridToken) { _, _ in
                    withAnimation(.easeInOut(duration: 0.45)) { reader.scrollTo("v5grid", anchor: .top) }
                    guard !reduceMotion else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.1).repeatCount(5, autoreverses: true)) { shakeGrid = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { shakeGrid = false }
                    }
                }

                if showsLockNotice {
                    Button {
                        Haptics.play(.tick)
                        CaptureRequestStore.shared.pendingRequestID = UUID()
                    } label: {
                        Label { Text(verbatim: "shoot today to open") } icon: { Image(systemName: "lock.fill") }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).frame(height: 38)
                            .laterGlass(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, topInset + 160)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.3), value: showsLockNotice)
                }

                if let toast {
                    Text(verbatim: toast)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .laterGlass(Capsule())
                        .frame(maxWidth: .infinity, alignment: .top)
                        .padding(.top, topInset + 8)
                        .transition(.opacity.combined(with: .offset(y: -12)))
                        .allowsHitTesting(false)
                        .zIndex(3)
                        .animation(.easeOut(duration: 0.3), value: toast)
                }
            }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { pageSize = $0 }
        }
        .environment(\.colorScheme, .dark)
        .task(id: locked) {
            guard locked else { showsLockNotice = false; return }
            try? await Task.sleep(for: .seconds(0.6))
            if !Task.isCancelled, locked { showsLockNotice = true }
        }
        .onAppear { yourOneID = MondoYourOneStore.get(day: dayKey) }
        .onChange(of: dayKey) { _, day in yourOneID = MondoYourOneStore.get(day: day) }
    }

    // MARK: - 中身(1本の 長い スクロール)

    private func page(width: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Group {
                switch phase {
                case .ready(let summary):
                    readyBody(summary, width: width)
                default:
                    // 世界の 集計が まだ(または おくれている)とき:小さな 文字だけで ぽつんと 浮かせない。
                    // Home/Group の ロックと 同じく、ちゃんと 面を 持たせて、残りの 高さを うめる。
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Darkroom.card)
                        stateMessage
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: max(360, height - topInset - 360))
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                }
            }
            .blur(radius: locked ? 16 : 0)
            .saturation(locked ? 0.4 : 1)
            .allowsHitTesting(!locked)
            .animation(.easeInOut(duration: 1.4), value: locked)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                MondoHeading(dayKey: dayKey, isActive: isActive)
                    .frame(maxWidth: .infinity, alignment: .leading)
                settingsButton
            }
            .padding(.top, 6)
            .padding(.horizontal, 18)
            MondoWorldClockBand(isActive: isActive)
                .padding(.top, 20)
        }
        .padding(.bottom, 10)
    }

    // MARK: 中身(ひらいている とき)

    private func readyBody(_ s: MondoDaySummary, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            todaysOneSection
            wordsSection
            morningNowSection
            mapSection(s)
            gridSection(s)
                .id("v5grid")
                .rotationEffect(.degrees(shakeGrid ? 1.2 : 0))
            yourOneButton
                .padding(.horizontal, 18)
                .padding(.top, 18)
        }
    }

    @ViewBuilder
    private var todaysOneSection: some View {
        if let announced {
            MondoTodaysOne(pick: announced, onOpen: onOpenAnnounced)
                .padding(.horizontal, 18)
                .padding(.top, 10)
        }
    }

    @ViewBuilder
    private var wordsSection: some View {
        let currentRanking = ranking
        if !currentRanking.isEmpty {
            wordsLabel
            MondoWordsRow(ranking: currentRanking, selected: selectedTag, sample: wordSample, onSelect: selectTag)
        }
    }

    @ViewBuilder
    private var wordsLabel: some View {
        if selectedTag != nil {
            DarkLabel(text: "WORDS", trailing: "ALL ×", onTrailingTap: clearTag)
        } else {
            DarkLabel(text: "WORDS", trailing: "TOP 5")
        }
    }

    @ViewBuilder
    private var morningNowSection: some View {
        if let best = bestMorningLight {
            DarkLabel(text: "MORNING NOW", trailing: "9:00 →")
            MondoMorningNowBand(light: best)
                .padding(.horizontal, 18)
        }
    }

    @ViewBuilder
    private func mapSection(_ s: MondoDaySummary) -> some View {
        if !lights.isEmpty {
            DarkLabel(text: "MAP", trailing: "\(lights.count) PLACES")
            MondoMapSection(lights: lights, entries: s.entries, onOpen: openLight)
                .padding(.horizontal, 18)
        }
    }

    @ViewBuilder
    private func gridSection(_ s: MondoDaySummary) -> some View {
        let headerText: String = selectedTag.map { "#\($0)" } ?? "EVERYONE"
        DarkLabel(text: headerText, trailing: "TAP×2 LIGHT · HOLD ONE")
        if gridEntries.isEmpty {
            message("この タグの 写真は、まだ ありません", "")
                .padding(.horizontal, 18)
                .padding(.top, 10)
        } else {
            MondoPhotoGrid(
                entries: gridEntries,
                lit: lit,
                yourOneID: yourOneID,
                onOpen: { entry, point in openEntry(entry, point: point) },
                onLight: { toggleLight($0) },
                onPick: { pickYourOne($0) }
            )
            .padding(.horizontal, 18)
            .padding(.top, 2)
        }
    }

    private var yourOneButton: some View {
        let entry = yourOneEntry
        return GeometryReader { geo in
            Button {
                if let entry {
                    openEntry(entry, point: CGPoint(x: geo.frame(in: .global).midX, y: geo.frame(in: .global).midY))
                } else {
                    Haptics.play(.tick)
                    scrollToGridToken &+= 1
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: "Your one").font(.custom("InstrumentSerif-Regular", size: 22)).foregroundStyle(.white)
                        Text(verbatim: entry.flatMap { ($0.place?.label).map { "\($0) · results at 9:00" } } ?? "hold a photo to choose · until 24:00")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "8C8C93"))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Text(verbatim: "›").font(.system(size: 22)).foregroundStyle(Color(hex: "8C8C93"))
                }
                .padding(.horizontal, 18)
                .frame(height: 72)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Darkroom.card))
            }
            .buttonStyle(SquishButtonStyle(pressedScale: 0.98))
        }
        .frame(height: 72)
    }

    // MARK: - データ

    /// WORDS の タグの 見本写真(先頭2枚)
    private func wordSample(_ tag: String) -> [MondoEntry] {
        guard let summary else { return [] }
        return Array(TagRanking.photos(for: tag, in: summary.entries, dayKey: summary.dayKey).prefix(2))
    }

    /// いま どこかで 9:00(昨日が ひらく 時刻)に いちばん 近い 場所
    private var bestMorningLight: MondoLight? {
        guard !lights.isEmpty else { return nil }
        let utc = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "UTC") ?? .gmt, from: Date())
        let hour = Double(utc.hour ?? 0) + Double(utc.minute ?? 0) / 60
        func localHour(_ lon: Double) -> Double { ((hour + lon / 15).truncatingRemainder(dividingBy: 24) + 24).truncatingRemainder(dividingBy: 24) }
        func distanceFromNine(_ lon: Double) -> Double {
            let d = abs(localHour(lon) - 9)
            return min(d, 24 - d)
        }
        return lights.min { distanceFromNine($0.point.lon) < distanceFromNine($1.point.lon) }
    }

    // MARK: - 操作

    private func selectTag(_ tag: String) {
        Haptics.play(.tick)
        selectedTag = selectedTag == tag ? nil : tag
    }

    private func clearTag() {
        Haptics.play(.tick)
        selectedTag = nil
    }

    /// EVERYONE の とき:すべての昨日 と 同じ 並び。タグを えらんで いる とき:そのタグの フィード
    private func openEntry(_ entry: MondoEntry, point: CGPoint) {
        Haptics.play(.pop)
        if let tag = selectedTag {
            onOpenTag(point, tag, entry.id)
        } else if let index = gridEntries.firstIndex(where: { $0.id == entry.id }) {
            onOpenAll(point, index)
        }
    }

    /// MAP の ピン:その場所の 1枚目から、すべての昨日の 並びで ひらく
    private func openLight(_ light: MondoLight, point: CGPoint) {
        Haptics.play(.pop)
        let all = Array(summaryEntries.prefix(MondoConfig.maxCards))
        if let index = all.firstIndex(where: { light.entryIDs.contains($0.id) }) {
            onOpenAll(point, index)
        } else if let tag = light.tags.first {
            onOpenTag(point, tag, light.entryIDs.first)
        }
    }

    /// ダブルタップ:ひかりを ともす(数は 出ない。端末だけ)
    private func toggleLight(_ entry: MondoEntry) {
        if lit.contains(entry.id) { lit.remove(entry.id) } else { lit.insert(entry.id) }
    }

    /// 長押し:あなたの 1枚(1日 1枚・24:00まで かえられる)
    private func pickYourOne(_ entry: MondoEntry) {
        yourOneID = entry.id
        MondoYourOneStore.set(day: dayKey, entryID: entry.id)
        show("あなたの 1枚に えらびました ・ 24:00 まで かえられる")
    }

    private func show(_ message: String) {
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { if toast == message { toast = nil } }
    }

    /// 設定の「…」
    private var settingsButton: some View {
        Button(action: onSettings) {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Darkroom.card))
                .overlay(Circle().strokeBorder(Darkroom.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .consumesTap()
        .accessibilityLabel("Mondo の設定")
    }

    @ViewBuilder
    private var stateMessage: some View {
        VStack(spacing: 18) {
            switch phase {
            case .loading:
                message("世界を、たずねています", "")
            case .empty:
                message("昨日は、まだ誰も Mondo に出していません", "あしたの朝、また新しい世界がひらきます。")
            case .notReady:
                message("今日の Mondo は、まだ準備中です", "あしたの朝、また来てください。")
            case .failed:
                VStack(spacing: 16) {
                    message("いま、世界につながりません", "また あとで")
                    Button("もう一度", action: onRetry)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Darkroom.bg)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.white))
                        .consumesTap()
                }
            case .ready:
                EmptyView()
            }
            if case .ready = phase {} else { settingsButton }
        }
    }

    private func message(_ title: String, _ body: String) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            if !body.isEmpty {
                Text(body).font(.system(size: 12.5)).foregroundStyle(Darkroom.weak)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }
}

// MARK: - v37 TODAY'S ONE(世界が選んだ1枚・9:00発表)

private struct MondoTodaysOne: View {
    let pick: AnnouncedPick
    let onOpen: (CGPoint) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var place: String {
        if case .mondo(let entry) = pick.source { return entry.place?.label ?? "" }
        return ""
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let breathe = reduceMotion ? 0.5 : (sin(t * 2 * .pi / 3.4) + 1) / 2
            ZStack {
                AnnouncedPhoto(pick: pick).clipped()
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.35), location: 0),
                    .init(color: .clear, location: 0.3),
                    .init(color: .black.opacity(0.25), location: 0.55),
                    .init(color: Darkroom.bg.opacity(0.95), location: 1),
                ], startPoint: .top, endPoint: .bottom)
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: "FFC878").opacity(0.5 * (0.6 + 0.4 * breathe)), .clear], center: .center, startRadius: 0, endRadius: 130))
                    .frame(width: 260, height: 260)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
                Text(verbatim: "TODAY'S ONE · 9:00")
                    .font(V5.mono(10)).tracking(0.26 * 10).foregroundStyle(Color(hex: "FFB27A"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 20)
                if let tag = pick.tags.first {
                    let c = Darkroom.stickerColors(tag)
                    Text(verbatim: "#\(tag)").font(.system(size: 15, weight: .black)).foregroundStyle(c.1)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 11).fill(c.0))
                        .rotationEffect(.degrees(7))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(16)
                }
                VStack(spacing: 6) {
                    Text(verbatim: place.isEmpty ? "—" : place)
                        .font(.custom("InstrumentSerif-Regular", size: 34)).foregroundStyle(.white)
                    Text(verbatim: "picked by the world · no numbers")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 28)
            }
        }
        .frame(height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .onSpatialTap(perform: onOpen)
        .accessibilityLabel("世界が選んだ1枚。\(place)")
    }
}

// MARK: - v37 WORDS(きのう多かったことば TOP5)

private struct MondoWordsRow: View {
    let ranking: [RankedTag]
    let selected: String?
    let sample: (String) -> [MondoEntry]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(ranking.enumerated()), id: \.element.id) { index, ranked in
                    pill(index: index, ranked: ranked)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 4)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
    }

    private func pill(index: Int, ranked: RankedTag) -> some View {
        let on = selected == ranked.tag
        return Button {
            onSelect(ranked.tag)
        } label: {
            HStack(spacing: 10) {
                Text(verbatim: String(format: "%02d", index + 1))
                    .font(.custom("InstrumentSerif-Italic", size: 22))
                    .foregroundStyle(on ? Darkroom.orange : Darkroom.weak)
                Text(verbatim: ranked.tag)
                    .font(Darkroom.title(ranked.tag, size: 16))
                HStack(spacing: -12) {
                    ForEach(Array(sample(ranked.tag).enumerated()), id: \.element.id) { i, entry in
                        MondoTile(entry: entry, cornerRadius: 18)
                            .frame(width: 36, height: 36)
                            .overlay(Circle().strokeBorder(on ? .white : Darkroom.card, lineWidth: 2))
                            .zIndex(Double(2 - i))
                    }
                }
            }
            .foregroundStyle(on ? Color(hex: "111111") : .white)
            .padding(.leading, 14).padding(.trailing, 10)
            .frame(height: 56)
            .background(Capsule().fill(on ? Color.white : Darkroom.card))
            .overlay(alignment: .bottomLeading) {
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: "FFB27A"), Darkroom.orange], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(4, 60 * ranked.ratio), height: 3)
                    .padding(.leading, 14).padding(.bottom, 4)
            }
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.96))
        .clipShape(Capsule())
        .accessibilityLabel("#\(ranked.tag)。\(on ? "えらんでいる" : "")")
    }
}

// MARK: - v37 MORNING NOW(世界の9:00の帯)

private struct MondoMorningNowBand: View {
    let light: MondoLight

    private var localHourFraction: Double {
        let utc = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "UTC") ?? .gmt, from: Date())
        let hour = Double(utc.hour ?? 0) + Double(utc.minute ?? 0) / 60
        let local = ((hour + light.point.lon / 15).truncatingRemainder(dividingBy: 24) + 24).truncatingRemainder(dividingBy: 24)
        return local / 24
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    LinearGradient(colors: [Color(hex: "0E0E18"), Color(hex: "2A2040"), Color(hex: "FF9A62"), Color(hex: "FFE7C8"), Color(hex: "C9D6F0")], startPoint: .leading, endPoint: .trailing)
                    Rectangle().fill(.white).frame(width: 2)
                        .shadow(color: .white, radius: 10)
                        .offset(x: proxy.size.width * localHourFraction)
                }
            }
            .frame(height: 38)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: light.name).font(.custom("InstrumentSerif-Regular", size: 26)).foregroundStyle(.white)
                Text(verbatim: "is opening yesterday").font(.system(size: 12, weight: .medium)).foregroundStyle(Darkroom.weak)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Darkroom.card))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - v37 MAP(市区町村まで。点の地図 + 脈打つピン)

private struct MondoMapSection: View {
    let lights: [MondoLight]
    let entries: [MondoEntry]
    let onOpen: (MondoLight, CGPoint) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func position(_ p: GeoPoint) -> CGPoint {
        CGPoint(x: (p.lon + 180) / 360, y: (90 - p.lat) / 180)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                Canvas { ctx, size in
                    let spacing: CGFloat = 12
                    var x: CGFloat = 6
                    while x < size.width {
                        var y: CGFloat = 6
                        while y < size.height {
                            ctx.fill(Path(ellipseIn: CGRect(x: x - 0.6, y: y - 0.6, width: 1.2, height: 1.2)), with: .color(Color(hex: "2C2C31")))
                            y += spacing
                        }
                        x += spacing
                    }
                }
                RadialGradient(colors: [.clear, Darkroom.bg], center: .center, startRadius: proxy.size.width * 0.28, endRadius: proxy.size.width * 0.58)
                    .allowsHitTesting(false)
                ForEach(Array(lights.enumerated()), id: \.element.id) { index, light in
                    let p = position(light.point)
                    pin(light, index: index, entry: entries.first { light.entryIDs.contains($0.id) })
                        .position(x: proxy.size.width * p.x, y: proxy.size.height * p.y)
                }
                Text(verbatim: "city-level only")
                    .font(V5.mono(8.5)).tracking(0.2 * 8.5).foregroundStyle(Darkroom.faint)
                    .padding(.trailing, 14).padding(.bottom, 10)
            }
        }
        .frame(height: 230)
        .background(Color(hex: "111113"))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Darkroom.line, lineWidth: 1))
    }

    private func pin(_ light: MondoLight, index: Int, entry: MondoEntry?) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate - Double(index) * 0.3
            let s = reduceMotion ? 0 : (sin(t * 2 * .pi / 2.4) + 1) / 2
            ZStack {
                Circle().fill(Darkroom.orange)
                if let entry {
                    MondoTile(entry: entry, cornerRadius: 13).padding(3)
                }
            }
            .frame(width: 26, height: 26)
            .overlay(Circle().strokeBorder(Darkroom.bg, lineWidth: 2))
            .shadow(color: Darkroom.orange.opacity(0.7), radius: 8)
            .scaleEffect(1 + 0.15 * s)
        }
        .onSpatialTap { onOpen(light, $0) }
        .accessibilityLabel("\(light.name)。\(light.count)枚")
    }
}

// MARK: - v37 写真の一覧(EVERYONE / えらんだタグ)

private struct MondoPhotoGrid: View {
    let entries: [MondoEntry]
    let lit: Set<String>
    let yourOneID: String?
    let onOpen: (MondoEntry, CGPoint) -> Void
    let onLight: (MondoEntry) -> Void
    let onPick: (MondoEntry) -> Void

    private let columns = [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 9) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                MondoPhotoCell(
                    entry: entry,
                    height: (index % 4 == 1 || index % 4 == 2) ? 250 : 220,
                    isLit: lit.contains(entry.id),
                    isPicked: yourOneID == entry.id,
                    onOpen: { point in onOpen(entry, point) },
                    onLight: { onLight(entry) },
                    onPick: { onPick(entry) }
                )
            }
        }
    }
}

private struct MondoPhotoCell: View {
    let entry: MondoEntry
    let height: CGFloat
    let isLit: Bool
    let isPicked: Bool
    let onOpen: (CGPoint) -> Void
    let onLight: () -> Void
    let onPick: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var center: CGPoint = .zero
    @State private var burst = 0
    @State private var holding = false
    @State private var ring: CGFloat = 0
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MondoTile(entry: entry, cornerRadius: 20)
            LinearGradient(stops: [.init(color: .clear, location: 0.58), .init(color: .black.opacity(0.6), location: 1)], startPoint: .top, endPoint: .bottom)
            if let place = entry.place?.label, !place.isEmpty {
                Text(verbatim: place)
                    .font(.custom("InstrumentSerif-Italic", size: 17)).foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.leading, 12).padding(.bottom, 11)
            }
            if let tag = entry.tags.first {
                let c = Darkroom.stickerColors(tag)
                Text(verbatim: "#\(tag)").font(.system(size: 11.5, weight: .black)).foregroundStyle(c.1)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 8).fill(c.0))
                    .rotationEffect(.degrees(-6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(10)
            }
            if holding {
                RoundedRectangle(cornerRadius: 20, style: .continuous).trim(from: 0, to: ring)
                    .stroke(Darkroom.star, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .padding(2)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .topTrailing) {
            KeepStar()
                .frame(width: 26, height: 26)
                .rotationEffect(.degrees(-12))
                .padding(8)
                .scaleEffect(isPicked ? 1 : 0.01)
                .opacity(isPicked ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.45), value: isPicked)
        }
        .overlay {
            if isLit {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color(hex: "FFBE78").opacity(0.8), lineWidth: 2)
                    .shadow(color: Color(hex: "FFA050").opacity(0.7), radius: 14)
            }
        }
        .overlay {
            if burst > 0 {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: "FFDCA0").opacity(0.9), Color(hex: "FFA050").opacity(0)], center: .center, startRadius: 0, endRadius: 45))
                    .frame(width: 90, height: 90)
                    .keyframeAnimator(initialValue: 0.2, trigger: burst) { content, s in content.scaleEffect(s).opacity(s < 1.8 ? 1 : 0) } keyframes: { _ in
                        CubicKeyframe(reduceMotion ? 0.2 : 2.4, duration: reduceMotion ? 0.01 : 0.7)
                    }
                    .allowsHitTesting(false)
            }
        }
        .onGeometryChange(for: CGPoint.self) { proxy in
            let f = proxy.frame(in: .global)
            return CGPoint(x: f.midX, y: f.midY)
        } action: { center = $0 }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture(count: 2) {
            Haptics.play(.soft)
            burst += 1
            onLight()
        }
        .onTapGesture(count: 1) {
            onOpen(center)
        }
        .onLongPressGesture(minimumDuration: 0.68, maximumDistance: 9) {
            finishHold()
        } onPressingChanged: { pressing in
            holdTask?.cancel()
            if pressing {
                holdTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.16))
                    guard !Task.isCancelled else { return }
                    holding = true
                    ring = 0
                    Haptics.play(.tick)
                    withAnimation(.linear(duration: 0.52)) { ring = 1 }
                }
            } else {
                holding = false
                ring = 0
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((entry.place?.label ?? "") + (isPicked ? "。あなたの1枚" : ""))
        .accessibilityAction(named: "ひかりを ともす", onLight)
        .accessibilityAction(named: "あなたの 1枚に する", onPick)
    }

    private func finishHold() {
        holdTask?.cancel()
        holding = false
        ring = 0
        Haptics.play(.heart)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { Haptics.play(.success) }
        onPick()
    }
}

// MARK: - v37 あなたの1枚(1日1枚・24:00まで・端末だけ)

enum MondoYourOneStore {
    private static func key(_ day: String) -> String { "mondo.yourOne.\(day)" }
    static func get(day: String) -> String? { UserDefaults.standard.string(forKey: key(day)) }
    static func set(day: String, entryID: String) { UserDefaults.standard.set(entryID, forKey: key(day)) }
}

// MARK: - v19 の地球儀の舞台

/// 地球儀(Canvas は画面の高さぶん大きく描く:拡大しても切れない)+ 照準 + 落書き。
/// ふだんは丸の中だけ さわれる。拡大中は画面ぜんぶ(ほかの所をおすと、とじる)。
struct MondoGlobeStageV19: View {
    let controller: GlobeController
    let width: CGFloat
    let diameter: CGFloat
    let screenHeight: CGFloat
    let locked: Bool
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let h = diameter + 12
        let radius = Double(diameter) / 2
        let canvasHeight = screenHeight * 2
        let running = isActive && !reduceMotion
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                FloatingDoodle(running: running, delay: 0) { ChicDoodle(kind: .star, width: 34) }
                    .position(x: 40, y: 30)
                FloatingDoodle(running: running, delay: 0.5) { ChicDoodle(kind: .wave, width: 58) }
                    .position(x: width - 50, y: 34)
                FloatingDoodle(running: running, delay: 1.0) { MondoSunDoodle(width: 36) }
                    .position(x: width - 34, y: h * 0.58)
                FloatingDoodle(running: running, delay: 1.5) { ChicDoodle(kind: .dots, width: 30) }
                    .position(x: 38, y: h - 30)
            }
            .frame(width: width, height: h, alignment: .topLeading)
            .opacity((locked ? 0.5 : 1) * (controller.isZoomed ? 0 : 0.55))
            .allowsHitTesting(false)

            Color.clear
                .frame(width: width, height: h)
                .overlay {
                    GlobeCanvasV19(controller: controller, radius: radius)
                        .frame(width: width, height: canvasHeight)
                        .contentShape(controller.isZoomed ? AnyShape(Rectangle()) : AnyShape(Circle().size(width: diameter, height: diameter).offset(x: (width - diameter) / 2, y: (canvasHeight - diameter) / 2)))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { controller.dragChanged($0, radius: radius) }
                                .onEnded { controller.dragEnded($0, center: CGPoint(x: width / 2, y: canvasHeight / 2), radius: radius) }
                        )
                        .accessibilityElement()
                        .accessibilityLabel("地球儀。きのう撮られた場所が \(controller.lights.count) か所 光っています")
                        .accessibilityHint("下の場所の ボタンから、その場所へ 跳べます")
                }
            GlobeCrosshair(controller: controller)
                .position(x: width / 2, y: h / 2 + 11)
        }
        .frame(width: width, height: h)
        .zIndex(1)
    }
}
