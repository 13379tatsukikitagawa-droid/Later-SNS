import SwiftUI
import UIKit

/// プロフィール v5「あなたの星」の景色(夜空と地平線と、ひとつの光)。
/// 上半分は空(プロフィール写真が星になる)、下半分は水面(預けた日々が光の道になる)。
/// 動くものはすべて、親の TimelineView 1つから渡される時刻で描く。
/// 数字は「現像の%」と「日付」だけ。いいね・連続日数などは出さない。

// MARK: - 配置(390×844pt 基準。テストできるよう、計算はここに集める)

enum ProfileStarLayout {
    static let designSize = CGSize(width: 390, height: 844)

    static let planetCenter = CGPoint(x: 195, y: 214)
    static let planetDiameter: CGFloat = 176
    /// 140秒で1周
    static let planetRotationPeriod: TimeInterval = 140

    static let ringRadius: CGFloat = 106
    static let ringCount = 36

    static let tagOrbitRadiusX: CGFloat = 150
    static let tagOrbitRadiusY: CGFloat = 44
    static let tagOrbitTilt: Double = -9
    /// 90秒で1周
    static let tagOrbitPeriod: TimeInterval = 90

    static let nameY: CGFloat = 330
    static let sinceY: CGFloat = 380
    static let tagRowY: CGFloat = 412
    static let horizonY: CGFloat = 440
    static let horizonRadiusX: CGFloat = 520
    static let horizonRadiusY: CGFloat = 130
    static let headingY: CGFloat = 474

    static let slotCount = 7
    static let todayY: CGFloat = 736
    static let farthestY: CGFloat = 524
    static let zigzagAmplitude: CGFloat = 96
    /// 0=今日(中央)、そのあとは左右に交互
    private static let zigzag: [CGFloat] = [0, 1, -1, 1, -1, 1, -1]

    static let auroraPeriod: TimeInterval = 22
    static let lightPathPeriod: TimeInterval = 3.4
    static let ripplePeriod: TimeInterval = 3.6
    static let holdDuration: TimeInterval = 0.55

    /// 視差の最大(k=22 のとき ±14pt)
    static let maxParallax: CGFloat = 14
    static let maxParallaxK: CGFloat = 22

    /// 7日の点の中心(slot 0 = 今日がいちばん手前、6 = 6日前がいちばん奥)
    static func slotCenter(_ slot: Int) -> CGPoint {
        let d = CGFloat(min(max(slot, 0), slotCount - 1))
        let y = todayY - (todayY - farthestY) * d / CGFloat(slotCount - 1)
        // 奥ほど中央へ寄る(最小で50%)
        let narrowing = 1 - 0.5 * d / CGFloat(slotCount - 1)
        let x = planetCenter.x + zigzagAmplitude * narrowing * zigzag[Int(d)]
        return CGPoint(x: x, y: y)
    }

    /// 半径:今日 16pt、ほかは 12.5 → 6pt
    static func slotRadius(_ slot: Int) -> CGFloat {
        guard slot > 0 else { return 16 }
        let d = CGFloat(min(slot, slotCount - 1))
        return 12.5 - (12.5 - 6) * (d - 1) / CGFloat(slotCount - 2)
    }

    /// うすさ:1.0 → 0.45
    static func slotOpacity(_ slot: Int) -> Double {
        let d = Double(min(max(slot, 0), slotCount - 1))
        return 1 - 0.55 * d / Double(slotCount - 1)
    }

    /// 日付ラベルを点の右に置くか(左側の点は左に置く)
    static func labelOnRight(_ slot: Int) -> Bool {
        slotCenter(slot).x >= planetCenter.x
    }

    /// その日が、今日から何日前の枠か(9:00 区切り。0〜6 以外は nil)
    static func slot(for date: Date, now: Date, calendar: Calendar = .current) -> Int? {
        let key = LaterWidgetDay.key(for: date, calendar: calendar)
        let today = LaterWidgetDay.key(for: now, calendar: calendar)
        guard let gap = LaterWidgetDay.daysBetween(key, today), (0..<slotCount).contains(gap) else { return nil }
        return gap
    }

    /// 現像の進み(ウィジェットの円盤と同じ:撮影 → 次の 9:00 をまっすぐ)
    static func developProgress(shotAt: Date, now: Date) -> Double {
        let finish = DevelopProgress.finishDate(capturedAt: shotAt)
        let total = finish.timeIntervalSince(shotAt)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(shotAt) / total))
    }

    /// 灯る点の数:round(現像% × 36)
    static func litCount(progress: Double) -> Int {
        min(ringCount, max(0, Int((progress * Double(ringCount)).rounded())))
    }

    /// ウィジェットの「NN%」と同じ(切り捨て)
    static func developPercent(_ progress: Double) -> Int {
        Int((min(1, max(0, progress)) * 100).rounded(.down))
    }

    /// k × 傾き(傾きは -1〜1)。最大でも ±14pt
    static func parallax(k: CGFloat, tilt: Double) -> CGFloat {
        let value = k / maxParallaxK * maxParallax * CGFloat(min(1, max(-1, tilt)))
        return min(maxParallax, max(-maxParallax, value))
    }

    /// まわるタグの位置(惑星の中心から)と奥行き(0 = いちばん奥、1 = いちばん手前)
    static func tagOrbit(index: Int, count: Int, elapsed: TimeInterval) -> (offset: CGPoint, depth: Double) {
        let theta = 2 * Double.pi * (elapsed / tagOrbitPeriod) + 2 * Double.pi * Double(index) / Double(max(1, count)) + Double.pi / 2
        let x = Double(tagOrbitRadiusX) * cos(theta)
        let y = Double(tagOrbitRadiusY) * sin(theta)
        let phi = tagOrbitTilt * Double.pi / 180
        let rx = x * cos(phi) - y * sin(phi)
        let ry = x * sin(phi) + y * cos(phi)
        return (CGPoint(x: rx, y: ry), (sin(theta) + 1) / 2)
    }
}

// MARK: - 入力

enum ProfileStarMotion: Equatable {
    /// 視差・自転・公転・きらめき、すべて動く
    case full
    /// 視差効果を減らす:止めて、タグは名前の下に横並び
    case reduced
    /// 低電力モード:静止画(タグの軌道は止まった位置で出す)
    case still

    var isMoving: Bool { self == .full }
    var showsOrbitTags: Bool { self != .reduced }
}

/// 水面の1点(撮らなかった日は作らない)
struct ProfileStarDay: Equatable, Identifiable {
    let slot: Int
    /// ふれて・ひらける日(グループに共有した1枚)。nil なら見るだけの点
    let point: WeekDayPoint?
    let color: Color
    let date: Date

    var id: Int { slot }
    var isToday: Bool { slot == 0 }
}

struct ProfileStarInput {
    var image: UIImage?
    var planetColor: Color?
    /// 0 = 真珠、1 = 写真
    var reveal: Double = 1
    /// 登場のピント(0 → 1)
    var focus: Double = 1
    var tags: [String] = []
    var days: [ProfileStarDay] = []
    /// 今日撮った時刻。nil = 撮る前
    var todayShotAt: Date?
    var auroraColors: [Color] = []
    var now: Date = Date()
    var motion: ProfileStarMotion = .full
    var selectedSlot: Int?
    var pressStart: Date?
}

struct ProfileStarGeometry {
    let size: CGSize

    var sx: CGFloat { size.width / ProfileStarLayout.designSize.width }
    var sy: CGFloat { size.height / ProfileStarLayout.designSize.height }
    var s: CGFloat { min(sx, sy) }

    func pt(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * sx, y: p.y * sy) }
    func x(_ v: CGFloat) -> CGFloat { v * sx }
    func y(_ v: CGFloat) -> CGFloat { v * sy }
}

struct ProfileStarTilt: Equatable {
    var x: Double = 0
    var y: Double = 0

    func offset(_ k: CGFloat) -> CGSize {
        CGSize(width: ProfileStarLayout.parallax(k: k, tilt: x), height: ProfileStarLayout.parallax(k: k, tilt: y))
    }
}

// MARK: - 1コマ

/// ある時刻の景色を1枚描く。TimelineView の中で毎フレーム作り直す(スナップショットでもそのまま使う)。
struct ProfileStarFrame: View {
    let input: ProfileStarInput
    let time: Date
    let tilt: ProfileStarTilt
    let size: CGSize

    static let litColor = Color(red: 1, green: 0.78, blue: 0.62)
    static let shotHorizon = (r: 255.0, g: 150.0, b: 110.0)
    static let waitingHorizon = (r: 150.0, g: 150.0, b: 190.0)

    private var g: ProfileStarGeometry { ProfileStarGeometry(size: size) }
    /// 動きの時刻(止めているときは 0 に固定)
    private var elapsed: TimeInterval { input.motion.isMoving ? time.timeIntervalSinceReferenceDate : 0 }
    private var tiltIfMoving: ProfileStarTilt { input.motion.isMoving ? tilt : ProfileStarTilt() }
    /// 今日の現像の進み(ウィジェットと同じ計算)。nil = 撮る前
    private var todayProgress: Double? {
        input.todayShotAt.map { ProfileStarLayout.developProgress(shotAt: $0, now: time) }
    }

    var body: some View {
        let g = g
        let tilt = tiltIfMoving
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                drawAurora(in: &context, offset: tilt.offset(6))
                drawStardust(in: &context, offset: tilt.offset(3))
                drawHalo(in: &context, offset: tilt.offset(8))
            }

            if input.motion.showsOrbitTags {
                orbitTags(front: false, offset: tilt.offset(9))
            }

            ProfileStarPlanet(
                image: input.image,
                color: input.planetColor,
                rotation: (elapsed / ProfileStarLayout.planetRotationPeriod).truncatingRemainder(dividingBy: 1),
                reveal: input.reveal,
                diameter: ProfileStarLayout.planetDiameter * g.s
            )
            .blur(radius: input.focus < 1 ? 14 * (1 - input.focus) : 0)
            .opacity(input.focus)
            .position(g.pt(ProfileStarLayout.planetCenter))
            .offset(tilt.offset(10))

            Canvas { context, _ in
                drawRing(in: &context, offset: tilt.offset(10))
            }

            if input.motion.showsOrbitTags {
                orbitTags(front: true, offset: tilt.offset(9))
            }

            Canvas { context, _ in
                drawHorizon(in: &context, offset: tilt.offset(14))
                drawLightPath(in: &context, offset: tilt.offset(14))
                drawGlitter(in: &context, offset: tilt.offset(16))
                drawDays(in: &context, offset: tilt.offset(22))
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: タグ(奥側は小さく・うすく・少しぼかす。惑星の後ろに隠れてよい)

    private func orbitTags(front: Bool, offset: CGSize) -> some View {
        let tags = input.tags
        let center = g.pt(ProfileStarLayout.planetCenter)
        return ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
            let orbit = ProfileStarLayout.tagOrbit(index: index, count: tags.count, elapsed: elapsed)
            if (orbit.depth >= 0.5) == front {
                ProfileStarTag(text: tag)
                    .scaleEffect(0.7 + 0.3 * orbit.depth)
                    .opacity(0.35 + 0.65 * orbit.depth)
                    .blur(radius: front ? 0 : 1.4 * (1 - orbit.depth * 2))
                    .position(x: center.x + orbit.offset.x * g.s, y: center.y + orbit.offset.y * g.s)
                    .offset(offset)
            }
        }
    }

    // MARK: 空

    private func drawAurora(in context: inout GraphicsContext, offset: CGSize) {
        let colors = input.auroraColors.isEmpty ? [Color(red: 0.36, green: 0.4, blue: 0.7)] : Array(input.auroraColors.prefix(7))
        let n = colors.count
        let phase = 2 * Double.pi * elapsed / ProfileStarLayout.auroraPeriod
        for (i, color) in colors.enumerated() {
            let spread = n > 1 ? (CGFloat(i) - CGFloat(n - 1) / 2) * (300 / CGFloat(n - 1)) : 0
            let sway = CGFloat(sin(phase + Double(i) * 1.3)) * 26
            let lift = CGFloat(cos(phase * 0.8 + Double(i))) * 10
            let center = CGPoint(
                x: g.x(195 + spread + sway) + offset.width,
                y: g.y(96 + CGFloat(i % 2) * 34 + lift) + offset.height
            )
            let radius = 150 * g.s
            let rect = CGRect(x: center.x - radius, y: center.y - radius * 0.7, width: radius * 2, height: radius * 1.4)
            let alpha = input.auroraColors.isEmpty ? 0.18 : 0.32
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(Gradient(colors: [color.opacity(alpha), color.opacity(0)]), center: center, startRadius: 0, endRadius: radius)
            )
        }
    }

    private static let stars: [(x: CGFloat, y: CGFloat, r: CGFloat, a: Double, phase: Double)] = {
        var seed: UInt64 = 0x5EED_1A7E
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(1 << 31)
        }
        return (0..<90).map { _ in
            (x: CGFloat(next() * 390), y: CGFloat(20 + next() * 400), r: CGFloat(0.4 + next() * 0.9), a: 0.15 + next() * 0.55, phase: next() * 2 * .pi)
        }
    }()

    private func drawStardust(in context: inout GraphicsContext, offset: CGSize) {
        for star in Self.stars {
            let twinkle = input.motion.isMoving ? 0.75 + 0.25 * sin(elapsed / 2.6 + star.phase) : 1
            let p = CGPoint(x: g.x(star.x) + offset.width, y: g.y(star.y) + offset.height)
            let rect = CGRect(x: p.x - star.r, y: p.y - star.r, width: star.r * 2, height: star.r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(star.a * twinkle)))
        }
    }

    private func drawHalo(in context: inout GraphicsContext, offset: CGSize) {
        let color = input.planetColor ?? .white
        let c = g.pt(ProfileStarLayout.planetCenter)
        let center = CGPoint(x: c.x + offset.width, y: c.y + offset.height)
        let radius = 190 * g.s
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: color.opacity(input.planetColor == nil ? 0.14 : 0.26), location: 0.3),
                    .init(color: color.opacity(0), location: 1),
                ]),
                center: center, startRadius: 0, endRadius: radius
            )
        )
    }

    // MARK: 点の輪(撮る前は出さない)

    private func drawRing(in context: inout GraphicsContext, offset: CGSize) {
        guard let progress = todayProgress else { return }
        let lit = ProfileStarLayout.litCount(progress: progress)
        let c = g.pt(ProfileStarLayout.planetCenter)
        let center = CGPoint(x: c.x + offset.width, y: c.y + offset.height)
        let r = ProfileStarLayout.ringRadius * g.s
        let dot: CGFloat = 3.2 * g.s
        for i in 0..<ProfileStarLayout.ringCount {
            let angle = -Double.pi / 2 + 2 * .pi * Double(i) / Double(ProfileStarLayout.ringCount)
            let p = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            let isLit = i < lit
            let size = isLit ? dot : dot * 0.8
            let rect = CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size)
            if isLit {
                let glow = rect.insetBy(dx: -size * 1.2, dy: -size * 1.2)
                context.fill(Path(ellipseIn: glow), with: .radialGradient(
                    Gradient(colors: [Self.litColor.opacity(0.45), Self.litColor.opacity(0)]),
                    center: p, startRadius: 0, endRadius: glow.width / 2
                ))
            }
            context.fill(Path(ellipseIn: rect), with: .color(isLit ? Self.litColor : .white.opacity(0.16)))
        }
    }

    // MARK: 地平線と水面

    private var horizonRGB: (r: Double, g: Double, b: Double) {
        todayProgress == nil ? Self.waitingHorizon : Self.shotHorizon
    }

    private func horizonRect(offset: CGSize) -> CGRect {
        let rx = ProfileStarLayout.horizonRadiusX * g.sx
        let ry = ProfileStarLayout.horizonRadiusY * g.sy
        let cx = g.x(ProfileStarLayout.planetCenter.x) + offset.width
        let top = g.y(ProfileStarLayout.horizonY) + offset.height
        return CGRect(x: cx - rx, y: top, width: rx * 2, height: ry * 2)
    }

    private func drawHorizon(in context: inout GraphicsContext, offset: CGSize) {
        let rect = horizonRect(offset: offset)
        let rgb = horizonRGB
        let color = Color(red: rgb.r / 255, green: rgb.g / 255, blue: rgb.b / 255)

        // 地平線の上の、うすい光(横長のやわらかい楕円)
        var glow = context
        glow.translateBy(x: rect.midX, y: rect.minY)
        glow.scaleBy(x: 1, y: 0.2)
        let glowRadius = 230 * g.s
        glow.fill(
            Path(ellipseIn: CGRect(x: -glowRadius, y: -glowRadius, width: glowRadius * 2, height: glowRadius * 2)),
            with: .radialGradient(Gradient(colors: [color.opacity(0.24), color.opacity(0)]), center: .zero, startRadius: 0, endRadius: glowRadius)
        )

        // 水面(楕円のふちから下を、すべて水にする)
        var water = Path(ellipseIn: rect)
        water.addRect(CGRect(x: -40, y: rect.midY, width: size.width + 80, height: size.height - rect.midY + 40))
        context.fill(water, with: .linearGradient(
            Gradient(colors: [Color(red: 0.05, green: 0.06, blue: 0.11), Color(red: 0.01, green: 0.01, blue: 0.03)]),
            startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: size.height)
        ))

        // ふちの細いグラデの光(楕円の上半分だけ)
        var arc = Path()
        arc.addArc(center: .zero, radius: 1, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        let rim = arc.applying(CGAffineTransform(translationX: rect.midX, y: rect.midY).scaledBy(x: rect.width / 2, y: rect.height / 2))
        let fade = Gradient(stops: [
            .init(color: color.opacity(0), location: 0.3),
            .init(color: color.opacity(0.9), location: 0.5),
            .init(color: color.opacity(0), location: 0.7),
        ])
        let start = CGPoint(x: rect.minX, y: 0)
        let end = CGPoint(x: rect.maxX, y: 0)
        context.stroke(rim, with: .linearGradient(fade, startPoint: start, endPoint: end), lineWidth: 6 * g.s)
        context.stroke(rim, with: .linearGradient(fade, startPoint: start, endPoint: end), lineWidth: 1.2)
    }

    /// 水面の光の道:横に細い線が、ゆっくり伸び縮みして点滅する(3.4秒)
    private func drawLightPath(in context: inout GraphicsContext, offset: CGSize) {
        let rgb = horizonRGB
        let base = input.planetColor ?? Color(red: rgb.r / 255, green: rgb.g / 255, blue: rgb.b / 255)
        let cx = g.x(ProfileStarLayout.planetCenter.x) + offset.width
        let phase = 2 * Double.pi * elapsed / ProfileStarLayout.lightPathPeriod
        let count = 16
        for i in 0..<count {
            let depth = Double(i) / Double(count - 1)          // 0 = 地平線ぎわ、1 = 手前
            let y = g.y(ProfileStarLayout.horizonY + 10 + CGFloat(depth) * 250) + offset.height
            let breathe = input.motion.isMoving ? 0.5 + 0.5 * sin(phase + Double(i) * 0.9) : 0.6
            let width = g.x(CGFloat(18 + 52 * depth) * CGFloat(0.55 + 0.45 * breathe))
            let alpha = (0.1 + 0.28 * breathe) * (1 - depth * 0.5)
            let rect = CGRect(x: cx - width / 2, y: y - 1, width: width, height: 2)
            context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .linearGradient(
                Gradient(colors: [base.opacity(0), base.opacity(alpha), .white.opacity(alpha), base.opacity(alpha), base.opacity(0)]),
                startPoint: CGPoint(x: rect.minX, y: y), endPoint: CGPoint(x: rect.maxX, y: y)
            ))
        }
    }

    private static let sparkles: [(x: CGFloat, y: CGFloat, phase: Double)] = {
        var seed: UInt64 = 0xA11CE
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(1 << 31)
        }
        return (0..<34).map { _ in (x: CGFloat(20 + next() * 350), y: CGFloat(452 + next() * 330), phase: next() * 2 * .pi) }
    }()

    private func drawGlitter(in context: inout GraphicsContext, offset: CGSize) {
        for sparkle in Self.sparkles {
            let blink = input.motion.isMoving ? max(0, sin(elapsed / 1.9 + sparkle.phase)) : 0.3
            guard blink > 0.05 else { continue }
            let p = CGPoint(x: g.x(sparkle.x) + offset.width, y: g.y(sparkle.y) + offset.height)
            let w: CGFloat = 3 + 4 * CGFloat(blink)
            context.fill(Path(CGRect(x: p.x - w / 2, y: p.y - 0.5, width: w, height: 1)), with: .color(.white.opacity(0.35 * blink)))
        }
    }

    // MARK: 預けた日々(7日の点)

    func slotPoint(_ slot: Int, offset: CGSize) -> CGPoint {
        let p = g.pt(ProfileStarLayout.slotCenter(slot))
        return CGPoint(x: p.x + offset.width, y: p.y + offset.height)
    }

    private func drawDays(in context: inout GraphicsContext, offset: CGSize) {
        // 道(点線)は撮らなかった日も途切れずに続く
        for slot in 0..<(ProfileStarLayout.slotCount - 1) {
            var path = Path()
            path.move(to: slotPoint(slot, offset: offset))
            path.addLine(to: slotPoint(slot + 1, offset: offset))
            let alpha = 0.32 * ProfileStarLayout.slotOpacity(slot + 1)
            context.stroke(path, with: .color(.white.opacity(alpha)), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1, 5]))
        }

        let isSelecting = input.selectedSlot != nil
        let daysBySlot = Dictionary(input.days.map { ($0.slot, $0) }, uniquingKeysWith: { first, _ in first })

        // 撮る前:今日の枠は破線の輪
        if todayProgress == nil, daysBySlot[0] == nil {
            let p = slotPoint(0, offset: offset)
            let r = ProfileStarLayout.slotRadius(0) * g.s
            context.stroke(
                Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                with: .color(.white.opacity(isSelecting ? 0.2 : 0.5)),
                style: StrokeStyle(lineWidth: 1.2, dash: [3, 4])
            )
            drawLabel(slot: 0, date: input.now, center: p, radius: r, dimmed: isSelecting, in: &context)
        }

        // 奥 → 手前の順に描く
        for slot in stride(from: ProfileStarLayout.slotCount - 1, through: 0, by: -1) {
            guard let day = daysBySlot[slot] else { continue }
            let p = slotPoint(slot, offset: offset)
            var r = ProfileStarLayout.slotRadius(slot) * g.s
            var opacity = ProfileStarLayout.slotOpacity(slot)
            let isSelected = input.selectedSlot == slot
            if isSelecting {
                if isSelected { r *= 1.35; opacity = 1 } else { opacity *= 0.35 }
            }

            // 水面のうつり(縦長のぼかし楕円。今日は特に短い)
            let reflectionHeight = r * (day.isToday ? 1.5 : 3.2)
            let reflectionWidth = r * 1.3
            let reflectionCenter = CGPoint(x: p.x, y: p.y + r + reflectionHeight / 2 + 1)
            var reflection = context
            reflection.translateBy(x: reflectionCenter.x, y: reflectionCenter.y)
            reflection.scaleBy(x: 1, y: reflectionHeight / reflectionWidth)
            reflection.fill(
                Path(ellipseIn: CGRect(x: -reflectionWidth / 2, y: -reflectionWidth / 2, width: reflectionWidth, height: reflectionWidth)),
                with: .radialGradient(Gradient(colors: [day.color.opacity(0.32 * opacity), day.color.opacity(0)]), center: .zero, startRadius: 0, endRadius: reflectionWidth / 2)
            )

            // 今日の点には波紋(3.6秒周期)
            if day.isToday {
                let rings = input.motion.isMoving ? [0.0, 0.5] : [0.35]
                for shift in rings {
                    let q = ((elapsed / ProfileStarLayout.ripplePeriod) + shift).truncatingRemainder(dividingBy: 1)
                    let rx = r + 4 + 28 * CGFloat(q) * g.s
                    let ry = rx * 0.34
                    let center = CGPoint(x: p.x, y: p.y + r * 0.85)
                    context.stroke(
                        Path(ellipseIn: CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2)),
                        with: .color(day.color.opacity(0.45 * (1 - q) * opacity)),
                        lineWidth: 1
                    )
                }
            }

            // 光と点
            let glowRadius = r * 2.2
            context.fill(
                Path(ellipseIn: CGRect(x: p.x - glowRadius, y: p.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)),
                with: .radialGradient(Gradient(colors: [day.color.opacity(0.5 * opacity), day.color.opacity(0)]), center: p, startRadius: r * 0.6, endRadius: glowRadius)
            )
            let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(day.color.opacity(opacity)))
            context.fill(Path(ellipseIn: rect), with: .radialGradient(
                Gradient(colors: [.white.opacity(0.45 * opacity), .white.opacity(0)]),
                center: CGPoint(x: p.x - r * 0.3, y: p.y - r * 0.35), startRadius: 0, endRadius: r
            ))

            if isSelected {
                context.stroke(Path(ellipseIn: rect.insetBy(dx: -1.5, dy: -1.5)), with: .color(.white), lineWidth: 1.4)
                // 押し続けている間、リングが満ちる(ひらける日だけ)
                if let pressStart = input.pressStart, day.point?.opened == true {
                    let progress = min(1, max(0, time.timeIntervalSince(pressStart) / ProfileStarLayout.holdDuration))
                    var ring = Path()
                    ring.addArc(center: p, radius: r + 10, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * progress), clockwise: false)
                    context.stroke(ring, with: .color(.white), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                }
            }

            drawLabel(slot: slot, date: day.date, center: p, radius: r, dimmed: isSelecting && !isSelected, in: &context)
        }
    }

    private func drawLabel(slot: Int, date: Date, center: CGPoint, radius: CGFloat, dimmed: Bool, in context: inout GraphicsContext) {
        let onRight = ProfileStarLayout.labelOnRight(slot)
        let text = Text(Self.labelFormatter.string(from: date))
            .font(.system(size: 9.5 * g.s, design: .monospaced))
            .foregroundStyle(.white.opacity(dimmed ? 0.25 : 0.75))
        let gap = radius + 8
        context.draw(text, at: CGPoint(x: center.x + (onRight ? gap : -gap), y: center.y), anchor: onRight ? .leading : .trailing)
    }

    static let labelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM.dd"
        return formatter
    }()
}

// MARK: - 惑星(プロフィール写真)

/// 丸く切り抜き、右上から光・左下に影。ふちにうすい大気の光。写真をゆっくり横にすべらせて自転させる。
struct ProfileStarPlanet: View {
    let image: UIImage?
    let color: Color?
    /// 0〜1(140秒で1周)
    let rotation: Double
    let reveal: Double
    let diameter: CGFloat

    var body: some View {
        let d = diameter
        let atmosphere = color ?? Color(red: 0.75, green: 0.8, blue: 1)
        ZStack {
            if image == nil || reveal < 1 {
                pearl.opacity(image == nil ? 1 : 1 - reveal)
            }
            if let image {
                // 普通・鏡像・普通 と並べ、2枚ぶんで1周(継ぎ目が出ない)
                HStack(spacing: 0) {
                    tile(image)
                    tile(image).scaleEffect(x: -1, y: 1)
                    tile(image)
                }
                .frame(width: d * 3, height: d)
                .offset(x: d - CGFloat(rotation) * 2 * d)
                .frame(width: d, height: d)
                .opacity(reveal)
            }
            // 右上からの光
            RadialGradient(colors: [.white.opacity(0.3), .clear], center: UnitPoint(x: 0.74, y: 0.22), startRadius: 0, endRadius: d * 0.62)
            // 左下の影
            LinearGradient(stops: [
                .init(color: .clear, location: 0.38),
                .init(color: .black.opacity(0.72), location: 1),
            ], startPoint: .topTrailing, endPoint: .bottomLeading)
        }
        .frame(width: d, height: d)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(atmosphere.opacity(0.5), lineWidth: 1.5))
        .background(
            Circle()
                .fill(RadialGradient(stops: [
                    .init(color: atmosphere.opacity(0.4), location: 0.72),
                    .init(color: atmosphere.opacity(0), location: 1),
                ], center: .center, startRadius: 0, endRadius: d * 0.66))
                .frame(width: d * 1.32, height: d * 1.32)
        )
    }

    private func tile(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: diameter, height: diameter)
            .clipped()
    }

    private var pearl: some View {
        Circle().fill(RadialGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: Color(hex: "E9ECF0"), location: 0.24),
                .init(color: Color(hex: "9AA1AB"), location: 0.6),
                .init(color: Color(hex: "2B2F35"), location: 1),
            ],
            center: UnitPoint(x: 0.66, y: 0.26), startRadius: 0, endRadius: diameter
        ))
    }
}

// MARK: - タグ

struct ProfileStarTag: View {
    let text: String

    var body: some View {
        Text("#\(text)")
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.08)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
    }
}
