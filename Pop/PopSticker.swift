import SwiftUI

enum PopShape: CaseIterable { case heart, star, spark, flower, hash }

private struct HeartShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); let w = r.width, h = r.height
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.92))
        p.addCurve(to: CGPoint(x: w * 0.04, y: h * 0.36), control1: CGPoint(x: w * 0.22, y: h * 0.74), control2: CGPoint(x: w * 0.04, y: h * 0.58))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.26), control1: CGPoint(x: w * 0.04, y: h * 0.12), control2: CGPoint(x: w * 0.38, y: h * 0.08))
        p.addCurve(to: CGPoint(x: w * 0.96, y: h * 0.36), control1: CGPoint(x: w * 0.62, y: h * 0.08), control2: CGPoint(x: w * 0.96, y: h * 0.12))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.92), control1: CGPoint(x: w * 0.96, y: h * 0.58), control2: CGPoint(x: w * 0.78, y: h * 0.74))
        p.closeSubpath()
        return p
    }
}

private struct StarShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); let c = CGPoint(x: r.midX, y: r.midY + r.height * 0.03), R = min(r.width, r.height) / 2
        for i in 0..<10 {
            let a = -Double.pi / 2 + Double(i) * .pi / 5, rad = i % 2 == 0 ? R : R * 0.46
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rad, y: c.y + CGFloat(sin(a)) * rad)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath(); return p
    }
}

/// 4つの とがりの きらり
private struct SparkShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); let c = CGPoint(x: r.midX, y: r.midY), R = min(r.width, r.height) / 2, k = R * 0.22
        p.move(to: CGPoint(x: c.x, y: c.y - R))
        p.addQuadCurve(to: CGPoint(x: c.x + R, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + R), control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x - R, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - R), control: CGPoint(x: c.x - k, y: c.y - k))
        p.closeSubpath(); return p
    }
}

private struct FlowerShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); let c = CGPoint(x: r.midX, y: r.midY), R = min(r.width, r.height) / 2, pr = R * 0.36
        for i in 0..<6 {
            let a = Double(i) * .pi / 3 - .pi / 2
            p.addEllipse(in: CGRect(x: c.x + CGFloat(cos(a)) * R * 0.58 - pr, y: c.y + CGFloat(sin(a)) * R * 0.58 - pr, width: pr * 2, height: pr * 2))
        }
        p.addEllipse(in: CGRect(x: c.x - R * 0.42, y: c.y - R * 0.42, width: R * 0.84, height: R * 0.84))
        return p
    }
}

/// `#` の 形(太い 4本の 線)
private struct HashShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); let w = r.width, h = r.height, t = w * 0.17
        for x in [0.30, 0.70] { p.addRoundedRect(in: CGRect(x: w * x - t / 2 + (x < 0.5 ? w * 0.02 : -w * 0.02), y: h * 0.08, width: t, height: h * 0.84), cornerSize: CGSize(width: t / 2, height: t / 2)) }
        for y in [0.34, 0.66] { p.addRoundedRect(in: CGRect(x: w * 0.08, y: h * y - t / 2, width: w * 0.84, height: t), cornerSize: CGSize(width: t / 2, height: t / 2)) }
        return p
    }
}

/// v110 §3-2:ステッカー。形と 色 だけ(顔 ・ 人の 絵は 作らない)。白い ふち 3pt ・ 下に かげ ・ すこし かたむける。
struct PopSticker: View {
    var shape: PopShape
    var color: Color
    var size: CGFloat = 34
    /// -15〜15°
    var tilt: Double = -8

    private var core: AnyShape {
        switch shape {
        case .heart: AnyShape(HeartShape())
        case .star: AnyShape(StarShape())
        case .spark: AnyShape(SparkShape())
        case .flower: AnyShape(FlowerShape())
        case .hash: AnyShape(HashShape())
        }
    }

    var body: some View {
        core.fill(color)
            .background { core.stroke(.white, style: StrokeStyle(lineWidth: 6, lineJoin: .round)) }
            .shadow(color: .black.opacity(0.35), radius: 4, y: 3)
            .frame(width: size, height: size)
            .padding(3)
            .rotationEffect(.degrees(max(-15, min(15, tilt))))
            .accessibilityHidden(true)
    }
}

/// 飛ぶ ステッカー(リアクション):上に 70pt ・ 0.4 → 1.25 → 1 ・ くるっと ・ 0.7秒。Reduce Motion では 動かさない。
struct PopFlyingSticker: View {
    var shape: PopShape
    var color: Color
    var trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var t: Double = 1

    var body: some View {
        PopSticker(shape: shape, color: color, size: 30, tilt: 0)
            .scaleEffect(t < 0.5 ? 0.4 + (1.25 - 0.4) * (t / 0.5) : 1.25 - 0.25 * ((t - 0.5) / 0.5))
            .rotationEffect(.degrees(t * 360))
            .offset(y: -70 * t)
            .opacity(t >= 1 ? 0 : (t < 0.7 ? 1 : 1 - (t - 0.7) / 0.3))
            .allowsHitTesting(false)
            .onChange(of: trigger) { _, _ in
                guard !reduceMotion else { return }
                t = 0
                withAnimation(.easeOut(duration: 0.7)) { t = 1 }
            }
    }
}
