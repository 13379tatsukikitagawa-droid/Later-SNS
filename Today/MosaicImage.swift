import ImageIO
import SwiftUI
import UIKit

/// 解禁前の写真に使う、とても小さな画像(22 × 48 px・PNG 数KB)と、その段階表示。
/// 高解像度の写真は、解禁前には使わない。色は元の写真から取るので、夕焼けは橙、夜は青と分かる。
enum MosaicRenderer {
    static let tinyColumns = 22
    static let tinyRows = 48

    /// フィルム加工後の画像から、mosaicTiny(PNG)を作る。画面いっぱいに合わせて中央を切りとる。
    static func makeTiny(from imageData: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        // 全体を読まず、小さく縮めてから使う(向きも直す)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 192,
        ]
        guard let small = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let target = CGSize(width: tinyColumns, height: tinyRows)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { context in
            context.cgContext.interpolationQuality = .high
            let ui = UIImage(cgImage: small)
            ui.draw(in: aspectFillRect(imageSize: ui.size, in: target))
        }
        return rendered.pngData()
    }

    /// 縦横比を保ったまま、枠をいっぱいに満たす描画の範囲
    static func aspectFillRect(imageSize: CGSize, in target: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return CGRect(origin: .zero, size: target) }
        let scale = max(target.width / imageSize.width, target.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (target.width - size.width) / 2, y: (target.height - size.height) / 2, width: size.width, height: size.height)
    }

    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 400
        return cache
    }()

    /// 段階ごとのドット絵。L2 は mosaicTiny そのまま、L0・L1 はそれを縮小する。L3(本物)は nil。
    /// 表示のときは .interpolation(.none) で、ドットを補間せずに拡大する。
    static func image(fromTiny tiny: Data, key: String, level: MosaicLevel) -> UIImage? {
        guard let grid = level.grid else { return nil }
        let cacheKey = "\(key)|\(level.rawValue)" as NSString
        if let hit = cache.object(forKey: cacheKey) { return hit }
        guard let base = UIImage(data: tiny), let cg = base.cgImage else { return nil }
        let result: UIImage?
        if cg.width == grid.columns, cg.height == grid.rows {
            result = base
        } else {
            result = downscale(cg, columns: grid.columns, rows: grid.rows)
        }
        if let result { cache.setObject(result, forKey: cacheKey) }
        return result
    }

    static func downscale(_ image: CGImage, columns: Int, rows: Int) -> UIImage? {
        guard columns > 0, rows > 0,
              let context = CGContext(
                data: nil, width: columns, height: rows, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: columns, height: rows))
        return context.makeImage().map { UIImage(cgImage: $0) }
    }

    /// 平均の色(mosaicTiny が無いときの、色だけの代わり)
    static func averageColor(fromTiny tiny: Data) -> Color? {
        guard let hex = MondoImageSanitizer.averageColorHex(tiny) else { return nil }
        return Color(hex: hex)
    }
}

/// モザイク(粗い四角のドット)。補間しない。mosaicTiny が無ければ、色のグラデーションだけ出す。
struct MosaicView: View {
    let tiny: Data?
    let key: String
    var level: MosaicLevel = .l0
    /// tiny が無いときの色
    var fallback: Color = Color(hex: "3A2A22")

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [fallback.opacity(0.9), fallback.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                if let tiny, let image = MosaicRenderer.image(fromTiny: tiny, key: key, level: level == .l3 ? .l2 : level) {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
            }
        }
        .accessibilityHidden(true)
    }
}
