import UIKit

/// 写真の生Data→UIImageデコード結果を共有キャッシュする。ChekiColorGrade.image(data:cacheKey:)
/// (Camera/Views/ChekiPhotoFrame.swift)と同じNSCache+安定キーのパターンで、こちらは色調補正
/// なしの単純デコード用。複数の画面(ギャラリー・投票結果等)が同じ写真を表示する際、
/// デコードを1回で済ませ、かつメインスレッドをブロックしないために使う。
///
/// キーはdata.hashValueではなく、呼び出し側が渡す安定した識別子(CKRecord.recordName等、
/// アプリ再起動をまたいでも変わらないもの)を使う(data.hashValueはプロセスごとに
/// ハッシュシードがランダム化されるため、ディスクキャッシュ等の永続化用途には使えず、
/// メモリキャッシュとしても衝突検知のためだけに毎回フルバイト列を保持し続ける非効率がある)。
enum PhotoImageCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = ImageCacheLimits.countLimit
        cache.totalCostLimit = ImageCacheLimits.totalCostLimitBytes
        return cache
    }()

    /// 既にキャッシュ済みなら同期的に即座に返す(未キャッシュならnil)。
    static func cachedImage(forKey cacheKey: String) -> UIImage? {
        cache.object(forKey: cacheKey as NSString)
    }

    /// キャッシュ済みならそれを、無ければバックグラウンドでデコードしてキャッシュに
    /// 格納してから返す。
    static func image(data: Data, cacheKey: String) async -> UIImage? {
        if let cached = cache.object(forKey: cacheKey as NSString) {
            return cached
        }
        guard !data.isEmpty else { return nil }
        let decoded = await Task.detached(priority: .userInitiated) {
            UIImage(data: data)
        }.value
        guard let decoded else { return nil }
        cache.setObject(decoded, forKey: cacheKey as NSString, cost: decoded.estimatedMemoryCost)
        return decoded
    }
}
