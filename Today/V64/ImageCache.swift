import UIKit
import ImageIO

/// P11:写真の デコードを 1回に する。キーは (写真の ID + 用途 + 大きさ)。`NSCache` で 上限を つける。
/// 表示サイズへ 縮めて 読む(フル解像度を 小さな 部品に 使わない)。
enum V64Images {
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 120
        c.totalCostLimit = 48 * 1024 * 1024
        return c
    }()

    /// `data` を 長い辺 `maxPixel` 以下に 縮めて 読む。`key` が 同じなら 2回目からは キャッシュ。
    static func image(key: String, data: Data?, maxPixel: CGFloat = 640) -> UIImage? {
        guard let data else { return nil }
        let k = "\(key)#\(Int(maxPixel))#\(data.count)" as NSString
        if let hit = cache.object(forKey: k) { return hit }
        let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                                     kCGImageSourceShouldCacheImmediately: true, kCGImageSourceThumbnailMaxPixelSize: maxPixel]
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        let img = UIImage(cgImage: cg)
        cache.setObject(img, forKey: k, cost: cg.width * cg.height * 4)
        return img
    }

    /// 背景に 敷く ぼかし済みの 小さな 画像(元の 大きな 画像を 毎回 ぼかさない)
    static func blurred(key: String, source: UIImage, maxPixel: CGFloat = 96, radius: CGFloat) -> UIImage {
        let k = "\(key)#blur#\(Int(maxPixel))#\(Int(radius))" as NSString
        if let hit = cache.object(forKey: k) { return hit }
        let scale = min(1, maxPixel / max(source.size.width, source.size.height))
        let size = CGSize(width: max(1, source.size.width * scale), height: max(1, source.size.height * scale))
        let small = UIGraphicsImageRenderer(size: size).image { _ in source.draw(in: CGRect(origin: .zero, size: size)) }
        var out = small
        if let ci = CIImage(image: small), let f = CIFilter(name: "CIGaussianBlur") {
            f.setValue(ci.clampedToExtent(), forKey: kCIInputImageKey)
            f.setValue(radius * scale, forKey: kCIInputRadiusKey)
            if let o = f.outputImage, let cg = CIContext().createCGImage(o, from: ci.extent) { out = UIImage(cgImage: cg) }
        }
        cache.setObject(out, forKey: k, cost: Int(size.width * size.height * 4))
        return out
    }
}
