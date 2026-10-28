import SwiftUI

/// Homeの動き(v4)。入場・常に動くもの(ゆっくり・小さく)の時間と見た目をまとめる。
/// 触覚は足さない。「視差効果を減らす」では入場は不透明度だけ、常に動くものは止める。
enum HomeMotion {
    /// 入場の全体(これをすぎたら入場用の状態を外す)
    static let entranceDuration: TimeInterval = 2.8

    /// cubic-bezier(.2,.8,.2,1)
    static func ease(_ x: Double) -> Double {
        cubicBezier(x, 0.2, 0.8, 0.2, 1)
    }

    /// 入場の進み具合(0〜1)。start がなければ入場していない(=1)。
    static func entrance(start: Date?, now: Date, delay: Double, duration: Double, reduceMotion: Bool) -> Double {
        guard let start else { return 1 }
        if reduceMotion {
            return min(1, max(0, now.timeIntervalSince(start) / 0.3))
        }
        let u = (now.timeIntervalSince(start) - delay) / duration
        return ease(min(1, max(0, u)))
    }

    /// 常に動くもの(回転・またたき・カードの光・オーブの波紋)を動かしてよいか
    static func ambientAllowed(reduceMotion: Bool) -> Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    /// CSS の cubic-bezier(x1, y1, x2, y2)。x から y を求める(二分法)。
    static func cubicBezier(_ x: Double, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        guard x > 0 else { return 0 }
        guard x < 1 else { return 1 }
        func bez(_ t: Double, _ p1: Double, _ p2: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t
        }
        var lo = 0.0, hi = 1.0, t = x
        for _ in 0..<24 {
            t = (lo + hi) / 2
            if bez(t, x1, x2) < x { lo = t } else { hi = t }
        }
        return bez(t, y1, y2)
    }
}

/// 入場:ぼかし+下から → くっきり(progress 0〜1)。
struct EntranceEffect: ViewModifier {
    let progress: Double
    var blur: CGFloat = 0
    var dy: CGFloat = 12
    var scaleFrom: CGFloat = 1

    func body(content: Content) -> some View {
        let p = CGFloat(progress)
        return content
            .blur(radius: blur * (1 - p))
            .offset(y: dy * (1 - p))
            .scaleEffect(scaleFrom + (1 - scaleFrom) * p)
            .opacity(progress)
    }
}

extension View {
    func entrance(_ progress: Double, blur: CGFloat = 0, dy: CGFloat = 12, scaleFrom: CGFloat = 1) -> some View {
        modifier(EntranceEffect(progress: progress, blur: blur, dy: dy, scaleFrom: scaleFrom))
    }
}

/// 月の上のカード:9秒ごとに、うすい光の帯が1回、左から右へ(白 7.5%・幅 55%)。最初は 2秒後。
struct CardShimmer: View {
    let start: Date
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(paused: !isActive)) { context in
            GeometryReader { proxy in
                let elapsed = context.date.timeIntervalSince(start) - 2
                let phase = elapsed < 0 ? -1 : elapsed.truncatingRemainder(dividingBy: 9)
                let sweep = 1.4
                if isActive, phase >= 0, phase < sweep {
                    let u = HomeMotion.ease(phase / sweep)
                    let bandWidth = proxy.size.width * 0.55
                    LinearGradient(colors: [.clear, .white.opacity(0.075), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: bandWidth)
                        .offset(x: -bandWidth + (proxy.size.width + bandWidth) * u)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// オーブ(丸い時計):6.4秒ごとに、うすい波紋が広がる(0.6倍 → 1.22倍、不透明度 .45 → 0)。2つ重ね、2つ目は3.2秒おくらせる。
struct OrbRipple: View {
    let start: Date
    let diameter: CGFloat
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(paused: !isActive)) { context in
            let t = context.date.timeIntervalSince(start)
            ZStack {
                if isActive {
                    ForEach(0..<2, id: \.self) { i in
                        let local = t - Double(i) * 3.2
                        let p = local < 0 ? 0 : local.truncatingRemainder(dividingBy: 6.4) / 6.4
                        Circle()
                            .stroke(.white.opacity(0.45 * (1 - p)), lineWidth: 1)
                            .frame(width: diameter, height: diameter)
                            .scaleEffect(0.6 + 0.62 * p)
                            .opacity(local < 0 ? 0 : 1)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
