import Foundation

/// 空間写真(奥行きのある写真)の時間割。描画(Metal)と文字の両方が、この値だけを読む。
/// 数値は Later-design/later_video_mock_v3_demo.html と同じ(経過秒 t は、ひらいた瞬間が 0)。
struct SpatialPhotoTimeline: Equatable {
    /// 視差の強さ(傾きの最大に対する、ずれの割合)
    static let fullStrength: Double = 0.032
    /// フォーカス面(0 = 一番奥、1 = 一番手前)
    static let focus: Double = 0.5
    static let zoom: Double = 1.07
    /// パールがレンズになる(半径 39 → 39 × 16.7 ≒ 651)
    static let pearlRadius: Double = 39
    static let pearlGrowth: Double = 16.7
    static let pearlDuration: Double = 1.6
    static let blurStart: Double = 10
    static let blurDuration: Double = 1.8
    static let scanRange: Range<Double> = 2.0..<4.4
    static let strengthRange: ClosedRange<Double> = 2.3...4.1
    static let swayStart: Double = 3.6
    static let hintRange: Range<Double> = 4.4..<7.4

    /// 写真の半径(端末の pt)。視差を減らすときは無限大(全体を見せる)
    var lensRadius: Double
    /// ディスクぼかしの半径(pt)。0 でピントが合った状態
    var blur: Double
    /// 視差の強さ。0 は静止画と同じ
    var strength: Double
    /// 「奥行きを読み取る」帯の位置(0 = 下、1 = 上)
    var scanProgress: Double
    var isScanning: Bool
    /// 手で傾けていなければ、ゆっくり自動で揺れる
    var isSwaying: Bool
    var showsHint: Bool

    /// 「奥行きを読み取っています NN%」の数字(帯の位置と同じ値)
    var scanPercent: Int? {
        isScanning ? Int((scanProgress * 100).rounded(.down)) : nil
    }

    static func at(_ t: Double, reduceMotion: Bool) -> SpatialPhotoTimeline {
        if reduceMotion {
            // 視差効果を減らす:静止画だけ(揺れ・帯・傾き反応はすべてオフ)
            return SpatialPhotoTimeline(
                lensRadius: .infinity, blur: 0, strength: 0, scanProgress: 1,
                isScanning: false, isSwaying: false, showsHint: false
            )
        }
        let lens = pearlRadius * pow(pearlGrowth, easeInOutCubic(t / pearlDuration))
        let blur = blurStart * (1 - easeInOutCubic(t / blurDuration))
        let scan = clamp((t - scanRange.lowerBound) / (scanRange.upperBound - scanRange.lowerBound))
        let strength = fullStrength * easeInOutCubic((t - strengthRange.lowerBound) / (strengthRange.upperBound - strengthRange.lowerBound))
        return SpatialPhotoTimeline(
            lensRadius: lens,
            blur: blur,
            strength: strength,
            scanProgress: scan,
            isScanning: scanRange.contains(t),
            isSwaying: t >= swayStart,
            showsHint: hintRange.contains(t)
        )
    }

    // MARK: - 数学(デモと同じ式)

    static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }

    static func easeInOutCubic(_ x: Double) -> Double {
        let x = clamp(x)
        return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }
}
