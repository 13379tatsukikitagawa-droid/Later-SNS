import UIKit
import CoreImage

/// 「現像中」プレビュー(DevelopingProgressView)専用の画像キャッシュ。ChekiColorGradeとは
/// 意図的に分離している: 現像途中の中間状態は写真1枚につき進捗を量子化した数だけ
/// (例: 2%刻みなら最大51通り)発生し、解禁が終われば二度と使わない一時的なものなので、
/// ディスクへは保存せずメモリキャッシュのみにする。
enum DevelopingPreviewCache {
    private static let context = CIContext()
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = ImageCacheLimits.countLimit
        cache.totalCostLimit = ImageCacheLimits.totalCostLimitBytes
        return cache
    }()

    /// 既にメモリキャッシュ済みなら同期的に即座に返す。
    static func cachedImage(forKey cacheKey: String) -> UIImage? {
        cache.object(forKey: cacheKey as NSString)
    }

    /// バックグラウンドでFilmEmulationを指定のconfigurationで適用し、結果をキャッシュに
    /// 格納して返す。cacheKeyには写真の識別子+量子化した進捗を含めること
    /// (DevelopingPreviewImage参照)。
    static func image(data: Data, cacheKey: String, configuration: FilmEmulation.Configuration, seed: UInt32) async -> UIImage? {
        if let cached = cache.object(forKey: cacheKey as NSString) {
            return cached
        }
        let result = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let sourceImage = UIImage(data: data), let cgImage = sourceImage.cgImage else { return nil }
            let ciImage = CIImage(cgImage: cgImage).oriented(CGImagePropertyOrientation(sourceImage.imageOrientation))
            let processed = FilmEmulation.process(ciImage, configuration: configuration, seed: seed)
            guard let outputCGImage = context.createCGImage(processed, from: ciImage.extent) else { return nil }
            return UIImage(cgImage: outputCGImage)
        }.value
        guard let result else { return nil }
        cache.setObject(result, forKey: cacheKey as NSString, cost: result.estimatedMemoryCost)
        return result
    }
}
