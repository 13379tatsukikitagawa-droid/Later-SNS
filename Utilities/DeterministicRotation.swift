import Foundation
import CoreGraphics

/// コルクボードに並ぶポラロイドカードの回転角度を、レコードのUUIDから決定論的に
/// 算出する。UUID.hashValueはプロセスごとにハッシュシードが変わり同じ値を返さない
/// ため使わず、UUIDの生バイト列をFNV-1aでハッシュして安定した値を得る
/// (再描画・スクロール・アプリの再起動をまたいでも同じカードは常に同じ角度になる)。
enum DeterministicRotation {
    static func degrees(seed: UUID, range: ClosedRange<Double> = -4...4) -> Double {
        var hash: UInt64 = 1469598103934665603 // FNV-1a offset basis
        withUnsafeBytes(of: seed.uuid) { buffer in
            for byte in buffer {
                hash ^= UInt64(byte)
                hash = hash &* 1099511628211 // FNV-1a prime
            }
        }
        let normalized = Double(hash % 1000) / 1000.0
        return range.lowerBound + normalized * (range.upperBound - range.lowerBound)
    }
}

/// World地図に置くピンの座標を、投稿のUUIDから決定論的に算出する。実際の撮影地点とは
/// 一切紐づけない「装飾的な」配置(Laterの匿名性の設計方針に合わせた選択。位置情報の
/// 取得・保存は行わない)。同じ考え方(安定したFNV-1aハッシュ)をx/y独立に2回適用する。
enum DeterministicMapPosition {
    static func point(
        for id: UUID,
        xRange: ClosedRange<Double> = 0.10...0.90,
        yRange: ClosedRange<Double> = 0.15...0.85
    ) -> CGPoint {
        let base = id.uuidString
        let nx = normalizedHash(base + "#x")
        let ny = normalizedHash(base + "#y")
        let x = xRange.lowerBound + nx * (xRange.upperBound - xRange.lowerBound)
        let y = yRange.lowerBound + ny * (yRange.upperBound - yRange.lowerBound)
        return CGPoint(x: x, y: y)
    }

    private static func normalizedHash(_ string: String) -> Double {
        var hash: UInt64 = 1469598103934665603 // FNV-1a offset basis
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211 // FNV-1a prime
        }
        return Double(hash % 1000) / 1000.0
    }
}
