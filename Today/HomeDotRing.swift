import SwiftUI

/// Homeの主役の「点の輪」。1つの点 = みんなの昨日の写真1枚(匿名)。
/// 228個のViewを並べず、Canvas 1枚にまとめて描く。点の座標・大きさ・位相は
/// 固定のシードで最初に1度だけ作り、毎フレーム乱数は使わない。
struct HomeDotRing: View {
    enum Tone: Equatable {
        /// ① 9:00前・消灯後:暗い(白6〜22%)
        case dim
        /// ②④ 撮れる:白く光る(白22〜92%)
        case bright
        /// ③ 撮った後:オレンジ→青→黄→オレンジに色づく
        case colored
    }

    /// 描く点の数(昨日の枚数。228より少なければその数だけ描く)。
    let count: Int
    let tone: Tone
    /// falseの間はアニメーションを止める(非アクティブ・Homeが見えていない時)。
    let isAnimating: Bool
    /// 登場演出(中心から外側へフェードイン)の開始時刻。nilなら演出なしで表示済み。
    let entranceStart: Date?
    /// 9:00に①→②へ切り替わった時の、白い光の波の開始時刻。
    let waveStart: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let diameter: CGFloat = 300

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isAnimating)) { context in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, time: context.date)
            }
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .overlay {
            if count == 0 {
                Circle()
                    .strokeBorder(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
                    .padding(Self.diameter / 2 - Layout.ringRadii[0])
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - 配置

    enum Layout {
        /// 外側から。合計228個。
        static let dotsPerRing = [72, 62, 52, 42]
        static let ringRadii: [CGFloat] = [142, 120, 98, 76]
        /// 1周の秒数(外側から)。向きは交互に逆。
        static let rotationPeriods: [Double] = [180, 140, 110, 80]
        static let rotationDirections: [Double] = [1, -1, 1, -1]
        /// ③では回転をほんの少し遅くする。
        static let coloredSpeedFactor = 0.7
        static let seed: UInt64 = 0x1A7E_2026
        static var capacity: Int { dotsPerRing.reduce(0, +) }
    }

    private struct Dot {
        let ring: Int
        let baseAngle: Double
        let radius: CGFloat
        let size: CGFloat
        let twinklePeriod: Double
        let twinklePhase: Double
        /// 点ごとの明るさの個性(0〜1)
        let level: Double
        /// 枚数が少ない時に、どの点から描くかの順番
        let priority: Double
    }

    private static let dots: [Dot] = {
        var rng = SplitMix64(seed: Layout.seed)
        var result: [Dot] = []
        for (ring, count) in Layout.dotsPerRing.enumerated() {
            for index in 0..<count {
                let step = 2 * Double.pi / Double(count)
                result.append(Dot(
                    ring: ring,
                    baseAngle: Double(index) * step + rng.next(in: -0.3...0.3) * step,
                    radius: Layout.ringRadii[ring] + CGFloat(rng.next(in: -2.5...2.5)),
                    size: CGFloat(rng.next(in: 1.6...3.3)),
                    twinklePeriod: rng.next(in: 3...7),
                    twinklePhase: rng.next(in: 0...(2 * .pi)),
                    level: rng.next(in: 0...1),
                    priority: rng.next(in: 0...1)
                ))
            }
        }
        return result
    }()

    /// 枚数がcapacityより少ない時は、priorityの小さい順にcount個だけ描く(数をごまかさない)。
    private static let dotsByPriority: [Dot] = dots.sorted { $0.priority < $1.priority }

    // MARK: - 描画

    private func draw(in graphics: inout GraphicsContext, size: CGSize, time: Date) {
        guard count > 0 else { return }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let visible = count >= Layout.capacity ? Self.dots : Array(Self.dotsByPriority.prefix(count))
        let t = time.timeIntervalSinceReferenceDate
        let isStill = reduceMotion
        let speedFactor = tone == .colored ? Layout.coloredSpeedFactor : 1
        let (low, high) = opacityRange

        for dot in visible {
            let rotation = isStill ? 0 : Layout.rotationDirections[dot.ring] * 2 * .pi * t / (Layout.rotationPeriods[dot.ring] / speedFactor)
            let angle = dot.baseAngle + rotation

            // またたき:鋭い山にして、同時に光る点が常に少数になるようにする。
            let twinkle = isStill ? 0 : pow(max(0, sin(dot.twinklePhase + 2 * .pi * t / dot.twinklePeriod)), 6)
            var opacity = low + (high - low) * (0.45 * dot.level + 0.55 * twinkle)
            opacity *= entranceAlpha(ring: dot.ring, time: time)
            opacity = min(1, opacity + waveBoost(ring: dot.ring, time: time))
            guard opacity > 0.005 else { continue }

            let point = CGPoint(x: center.x + cos(angle) * dot.radius, y: center.y + sin(angle) * dot.radius)
            let rect = CGRect(x: point.x - dot.size / 2, y: point.y - dot.size / 2, width: dot.size, height: dot.size)
            graphics.fill(Path(ellipseIn: rect), with: .color(color(at: angle).opacity(opacity)))
        }
    }

    private var opacityRange: (Double, Double) {
        switch tone {
        case .dim: return (0.06, 0.22)
        case .bright, .colored: return (0.22, 0.92)
        }
    }

    /// 中心(内側の輪)から外側へ、輪ごとに0.1秒ずつずらして0.6秒でフェードイン。
    private func entranceAlpha(ring: Int, time: Date) -> Double {
        guard let entranceStart, !reduceMotion else { return 1 }
        let orderFromCenter = Double(Layout.dotsPerRing.count - 1 - ring)
        let progress = (time.timeIntervalSince(entranceStart) - orderFromCenter * 0.1) / 0.6
        let clamped = min(1, max(0, progress))
        return 1 - pow(1 - clamped, 3)
    }

    /// 9:00の切り替わりで、中心から外側へ波のように白く光る(合計0.9秒、外側ほど遅れる)。
    private func waveBoost(ring: Int, time: Date) -> Double {
        guard let waveStart, !reduceMotion else { return 0 }
        let orderFromCenter = Double(Layout.dotsPerRing.count - 1 - ring)
        let local = (time.timeIntervalSince(waveStart) - orderFromCenter * 0.2) / 0.3
        guard local > 0, local < 1 else { return 0 }
        return 0.7 * sin(.pi * local)
    }

    private func color(at angle: Double) -> Color {
        guard tone == .colored else { return .white }
        return HomePalette.ringColor(atFraction: angle / (2 * .pi))
    }
}

// MARK: - 色

enum HomePalette {
    static let background = Color.black
    static let subText = Color(hex: "BCBBC0")
    static let surface = Color(hex: "1C1C1E")
    static let disabledText = Color(hex: "8E8E93")
    static let orange = Color(hex: "FF9E5E")
    static let blue = Color(hex: "3FA8FF")
    static let yellow = Color(hex: "FFCF5E")

    private static let ringStops: [(r: Double, g: Double, b: Double)] = [
        (1.0, 0.620, 0.369),  // #FF9E5E
        (0.247, 0.659, 1.0),  // #3FA8FF
        (1.0, 0.812, 0.369),  // #FFCF5E
        (1.0, 0.620, 0.369),  // #FF9E5E(1周して戻る)
    ]

    /// 輪の角度(0〜1周)に沿って、オレンジ→青→黄→オレンジをなめらかにつなぐ。
    static func ringColor(atFraction fraction: Double) -> Color {
        var f = fraction.truncatingRemainder(dividingBy: 1)
        if f < 0 { f += 1 }
        let segments = Double(ringStops.count - 1)
        let position = f * segments
        let index = min(Int(position), ringStops.count - 2)
        let local = position - Double(index)
        let a = ringStops[index], b = ringStops[index + 1]
        return Color(
            red: a.r + (b.r - a.r) * local,
            green: a.g + (b.g - a.g) * local,
            blue: a.b + (b.b - a.b) * local
        )
    }
}

// MARK: - 固定シードの乱数

private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        let unit = Double(nextUInt64() >> 11) / Double(1 << 53)
        return range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }
}
