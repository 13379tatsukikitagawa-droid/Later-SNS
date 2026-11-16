import SwiftUI

/// モックの `cubic-bezier(a,b,c,d)` を 名前つきで。`withAnimation(LGMotion.pop(0.4)) { … }`
enum LGMotion {
    /// (.3,1.4,.5,1) はねる(ぷにっ)
    static func bounce(_ d: Double = 0.4) -> Animation { .timingCurve(0.3, 1.4, 0.5, 1, duration: d) }
    /// (.2,.8,.3,1) すっと 止まる
    static func settle(_ d: Double = 0.4) -> Animation { .timingCurve(0.2, 0.8, 0.3, 1, duration: d) }
    /// (.3,1.2,.4,1) ゆるい はね
    static func gentle(_ d: Double = 0.4) -> Animation { .timingCurve(0.3, 1.2, 0.4, 1, duration: d) }
    /// (.3,1.6,.4,1) つよい はね
    static func springy(_ d: Double = 0.4) -> Animation { .timingCurve(0.3, 1.6, 0.4, 1, duration: d) }
    /// (.3,1.25,.4,1) 目次の 印(すべって のびる)0.44秒
    static func dock(_ d: Double = 0.44) -> Animation { .timingCurve(0.3, 1.25, 0.4, 1, duration: d) }
    /// CSS ease-out 相当
    static func easeOut(_ d: Double = 0.3) -> Animation { .timingCurve(0, 0, 0.58, 1, duration: d) }

    /// 名前の 一覧(プレビュー・テスト用)
    static let all: [(name: String, curve: (Double, Double, Double, Double))] = [
        ("bounce", (0.3, 1.4, 0.5, 1)), ("settle", (0.2, 0.8, 0.3, 1)),
        ("gentle", (0.3, 1.2, 0.4, 1)), ("springy", (0.3, 1.6, 0.4, 1)),
        ("dock", (0.3, 1.25, 0.4, 1)),
    ]
}
