import UIKit

/// PhotoImageCache・ChekiColorGradeが使うNSCacheの上限を一箇所にまとめる。
/// 値は妥当な初期値であり、実機での挙動を見ながら調整してよい。
enum ImageCacheLimits {
    /// 同時にメモリ上に保持する画像の枚数上限。
    static let countLimit = 50
    /// 合計の概算バイト数上限(デコード後のビットマップサイズの近似値の合計)。
    static let totalCostLimitBytes = 100 * 1024 * 1024 // 100MB
}

extension UIImage {
    /// NSCache.setObject(_:forKey:cost:)に渡すための概算バイト数。
    /// costを指定しない(常に0の)ままだとtotalCostLimitが何の効果も持たないため、
    /// デコード後のビットマップサイズ(1行あたりバイト数 × 高さ)の近似値を使う。
    var estimatedMemoryCost: Int {
        guard let cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
