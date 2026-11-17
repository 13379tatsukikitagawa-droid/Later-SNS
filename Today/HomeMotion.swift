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

