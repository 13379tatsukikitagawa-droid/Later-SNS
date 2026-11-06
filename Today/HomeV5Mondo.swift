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

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// v19:さわれる地球儀
    @State private var globe = GlobeController()
    @State private var toast: String?

    private var summaryEntries: [MondoEntry] {
        if case .ready(let s) = phase { return s.entries }
        return []
    }

    var body: some View {
        let globeTop = topInset + 48
        return GeometryReader { geo in
        ScrollViewReader { reader in
        ZStack(alignment: .bottom) {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                MondoGlobeStageV19(
                    controller: globe,
                    width: geo.size.width,
                    diameter: V5Globe.pageDiameter(forWidth: geo.size.width),
                    screenHeight: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom,
                    locked: locked,
                    isActive: isActive
                )
                .visualEffect { content, proxy in
                    // スクロールで、上へ動きながら小さく(scale 1 → .78)・うすくなる(360ptで消える)
                    let minY = proxy.frame(in: .scrollView).minY
                    let progress = min(1, max(0, (globeTop - minY) / 360))
                    return content
                        .scaleEffect(1 - 0.22 * progress)
                        .opacity(1 - progress)
                }
                .padding(.top, globeTop)

                Group {
                titleBlock
                    .padding(.top, 10)
                    .offset(y: globe.isZoomed ? 20 : 0)

                MondoBand(
                    width: geo.size.width,
                    lights: bandLights,
                    countries: bandCountries,
                    dayLabel: V5.monthDay(fromDayKey: dayKey),
                    isActive: isActive
                )
                .padding(.top, 8)

                // v19:場所チップ(「どこかへ」+ 光が多い順)
                if !globe.lights.isEmpty {
                    MondoPlaceChips(controller: globe)
                        .frame(height: 44)
                        .padding(.top, 12)
                }

                // 昨日の一枚(幅 = 画面の幅 - 56)
                if let announced {
                    MondoBigPrint(pick: announced, width: max(0, geo.size.width - 56), locked: locked, onOpen: onOpenAnnounced)
                        .padding(.top, 14)
                } else if locked {
                    V5LockedNotice()
                        .padding(.top, 14)
                        .transition(.opacity)
                }

                Group {
                    switch phase {
                    case .ready(let summary):
                        readyContent(summary)
                            .padding(.top, 26)
                    default:
                        stateMessage
                            .padding(.top, 30)
                    }
                }
                }
                // 跳んでいる間・着いたあとは、文字・帯・チップ・ボタンを消す
                .opacity(globe.isZoomed ? 0 : 1)
                .allowsHitTesting(!globe.isZoomed)
            }
            .padding(.bottom, 130)
            // 中身の幅は、画面の幅と同じ1つだけ(中の写真・文字が広くても、横にずれない)
            .containerRelativeFrame(.horizontal)
            .id("v5top")
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(globe.isZoomed)
        .onChange(of: scrollToTopToken) { _, _ in
            withAnimation(.easeInOut(duration: 0.45)) { reader.scrollTo("v5top", anchor: .top) }
        }
        .onChange(of: globe.isZoomed) { _, zoomed in
            if zoomed { withAnimation(.easeInOut(duration: 0.35)) { reader.scrollTo("v5top", anchor: .top) } }
        }

        // 着いたら、下からカードがうかぶ
        if globe.cardOpen, let light = globe.selected {
            MondoPlaceCard(
                light: light,
                entries: light.entryIDs.compactMap { id in summaryEntries.first { $0.id == id } },
                locked: locked,
                onClose: { globe.close(quick: false) },
                onNext: { globe.jumpNext() },
                onOpenPhoto: { entry, point in
                    let list = Array(summaryEntries.prefix(MondoConfig.maxCards))
                    if let index = list.firstIndex(where: { $0.id == entry.id }) { onOpenAll(point, index) }
                },
                onToast: { show($0) }
            )
            .id(light.id)
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(2)
        }

        if let toast {
            Text(toast)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(GlassCapsule())
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, topInset + 8)
                .transition(.opacity.combined(with: .offset(y: -12)))
                .allowsHitTesting(false)
                .zIndex(3)
        }
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: globe.cardOpen)
        .animation(.easeOut(duration: 0.3), value: toast)
        }
        }
        // 跳んでいる間・着いたあとは、タブバーを下へ隠す
        .toolbar(globe.isZoomed ? .hidden : .visible, for: .tabBar)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: globe.isZoomed)
        .onAppear { syncGlobe() }
        .onChange(of: summaryEntries.map(\.id)) { _, _ in syncGlobe() }
        .onChange(of: isActive) { _, active in if active { globe.start() } else { globe.stop() } }
        .onDisappear { globe.stop() }
    }

    private func syncGlobe() {
        globe.reduceMotion = reduceMotion
        globe.lights = MondoGeo.lights(from: summaryEntries)
        if isActive { globe.start() }
    }

    private func show(_ message: String) {
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { if toast == message { toast = nil } }
    }

    // MARK: 見出し

    private var bandLights: Int? {
        guard case .ready(let s) = phase else { return nil }
        let world = WorldCountStore.shared
        return (world.dayKey == s.dayKey ? world.count : nil) ?? s.lightCount
    }

    private var bandCountries: Int? {
        guard case .ready(let s) = phase else { return nil }
        return s.countryCount
    }

    /// Inter Black が入っていればそれ、なければ太い丸ゴシック
    private var mondoFont: Font {
        UIFont(name: "Inter-Black", size: 50) != nil
            ? .custom("Inter-Black", fixedSize: 50)
            : .system(size: 50, weight: .heavy, design: .rounded)
    }

    private var yesterdayFont: Font {
        UIFont(name: "InstrumentSerif-Italic", size: 30) != nil
            ? .custom("InstrumentSerif-Italic", fixedSize: 30)
            : .system(size: 30, design: .serif).italic()
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Mondo")
                    .font(mondoFont)
                    .tracking(-0.05 * 50)
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("yesterday")
                    .font(yesterdayFont)
                    .foregroundStyle(palette.sub)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text("昨日の世界 · \(V5.monthDay(fromDayKey: dayKey))")
                .font(V5.mono(12, weight: .bold))
                .tracking(0.12 * 12)
                .foregroundStyle(palette.accentText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if case .ready(let s) = phase {
                let shown = bandLights ?? s.lightCount
                Text("\(shown.formatted(.number.grouping(.automatic))) の光 · \(s.countryCount) の国と地域")
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.sub)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.leading, 26)
        .padding(.trailing, V5.edge)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 設定の「…」(見出しの横から、ランキングの見出しの横へ移した)
    private var settingsButton: some View {
        Button(action: onSettings) {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.ink)
                .frame(width: 32, height: 32)
                .background(Circle().fill(palette.fill))
                .overlay(Circle().strokeBorder(palette.line, lineWidth: 1))
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
                        .foregroundStyle(palette.bg)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(palette.ink))
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
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(palette.ink)
            if !body.isEmpty {
                Text(body).font(.system(size: 12.5)).foregroundStyle(palette.sub)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }

    // MARK: 中身

    private func readyContent(_ s: MondoDaySummary) -> some View {
        let ranking = TagRanking.rank(s.topTags, dayKey: s.dayKey)
        let cards = Array(s.entries.prefix(MondoConfig.maxCards))
        return VStack(alignment: .leading, spacing: 18) {
            if !ranking.isEmpty {
                HStack(alignment: .center, spacing: 8) {
                    Text("昨日多かったハッシュタグ")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Text("TOP \(ranking.count)")
                        .font(V5.mono(11))
                        .tracking(1)
                        .foregroundStyle(palette.sub)
                    settingsButton
                }
                .padding(.horizontal, V5.edge)

                ForEach(ranking) { ranked in
                    RankRow(ranked: ranked, photos: Array(TagRanking.photos(for: ranked.tag, in: s.entries, dayKey: s.dayKey).prefix(TagRanking.photosPerRow)), locked: locked, onOpen: onOpenTag)
                        .padding(.horizontal, V5.edge)
                        .scrollTransition(.interactive) { content, phase in
                            content
                                .opacity(1 - abs(phase.value) * 0.5)
                                .offset(y: phase.value > 0 ? 26 * phase.value : 0)
                        }
                }
            } else {
                HStack { Spacer(); settingsButton }
                    .padding(.horizontal, V5.edge)
            }

            if !cards.isEmpty {
                Text("すべての昨日")
                    .font(V5.mono(9.5))
                    .tracking(0.16 * 9.5)
                    .foregroundStyle(palette.sub)
                    .padding(.horizontal, V5.edge)
                    .padding(.top, 14)

                ForEach(Array(cards.enumerated()), id: \.element.id) { index, entry in
                    AllCard(entry: entry, index: index, locked: locked, onOpen: { point in onOpenAll(point, index) })
                        .padding(.horizontal, V5.edge)
                        .scrollTransition(.interactive) { content, phase in
                            content.opacity(1 - abs(phase.value) * 0.45)
                        }
                }
            }

            endBlock
                .padding(.top, 16)
        }
    }

    private var endBlock: some View {
        VStack(spacing: 8) {
            Circle().fill(palette.accent).frame(width: 8, height: 8)
            Text("今日の Mondo は、ここまで。")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(palette.ink)
            Text("あしたの朝、また新しい世界がひらきます")
                .font(.system(size: 12.5))
                .foregroundStyle(palette.sub)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ランキングの行

private struct RankRow: View {
    @Environment(\.palette) private var palette
    let ranked: RankedTag
    let photos: [MondoEntry]
    let locked: Bool
    let onOpen: (_ point: CGPoint, _ tag: String, _ entryID: String?) -> Void

    private var isTop: Bool { ranked.rank == 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                OutlineNumber(text: "\(ranked.rank)", isTop: isTop)
                    .frame(width: 52)
                VStack(alignment: .leading, spacing: 8) {
                    Text("#\(ranked.tag)")
                        .font(.system(size: isTop ? 30 : 25, weight: .bold))
                        .tracking(-0.03 * (isTop ? 30 : 25))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    HStack(spacing: 10) {
                        Text("\(ranked.count) の光")
                            .font(V5.mono(11))
                            .foregroundStyle(isTop ? palette.ink : palette.sub)
                        // 棒:その日の1位の数に対する割合
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(palette.ink.opacity(0.08))
                                Capsule()
                                    .fill(isTop ? palette.accent : palette.ink)
                                    .frame(width: max(6, proxy.size.width * ranked.ratio))
                            }
                        }
                        .frame(height: 3)
                    }
                }
                Spacer(minLength: 0)
            }
            .onSpatialTap { onOpen($0, ranked.tag, nil) }

            HStack(spacing: 8) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, entry in
                    MondoTile(entry: entry, cornerRadius: 0)
                        .aspectRatio(3 / 4, contentMode: .fit)
                        .blur(radius: locked ? 18 : 0, opaque: true)
                        .clipped()
                        .chicPrint(side: 3, bottom: 10, rotation: index % 2 == 0 ? -2 : 1.6)
                        .frame(maxWidth: .infinity)
                        .onSpatialTap { onOpen($0, ranked.tag, entry.id) }
                }
                if photos.count < TagRanking.photosPerRow {
                    Spacer(minLength: 0)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(palette.ink)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(palette.bg))
                    .overlay(Circle().strokeBorder(palette.line, lineWidth: 1))
                    .onSpatialTap { onOpen($0, ranked.tag, nil) }
                    .accessibilityLabel("#\(ranked.tag)の写真をぜんぶ見る")
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(palette.fill))
        .overlay {
            if isTop {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(palette.accent, lineWidth: 1.5)
            }
        }
        .animation(.easeInOut(duration: 1.4), value: locked)
        .allowsHitTesting(!locked)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - すべての昨日のカード

private struct AllCard: View {
    let entry: MondoEntry
    var index = 0
    var locked = false
    let onOpen: (CGPoint) -> Void

    var body: some View {
        VStack(spacing: 0) {
            MondoTile(entry: entry, cornerRadius: 0)
                .frame(height: 360)
                .blur(radius: locked ? 18 : 0, opaque: true)
                .clipped()
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(entry.tags.prefix(2).enumerated()), id: \.offset) { tagIndex, tag in
                    Text("#\(tag)")
                        .font(mondoHandFont(tagIndex == 0 ? 20 : 15))
                        .foregroundStyle(tagIndex == 0 ? Color(hex: "2A2A2E") : ChicColor.sub)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text("昨日 · \(V5.monthDay(fromDayKey: entry.dayKey))")
                    .font(V5.mono(11))
                    .foregroundStyle(ChicColor.sub)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .padding(.top, 6)
            .blur(radius: locked ? 6 : 0)
            .opacity(locked ? 0.6 : 1)
            .allowsHitTesting(false)
        }
        .chicPrint(side: 12, bottom: 0, rotation: ChicTilt.degrees(index))
        .padding(.bottom, 4)
        .animation(.easeInOut(duration: 1.4), value: locked)
        .onSpatialTap(perform: onOpen)
        .allowsHitTesting(!locked)
        .accessibilityLabel("\(entry.tags.map { "#\($0)" }.joined(separator: " "))の昨日の1枚")
    }
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
