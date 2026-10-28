import AVFoundation
import CoreImage
import UIKit
import UniformTypeIdentifiers

/// 空間写真の深度マップ(8bit グレースケール)を作る。
/// 写真と一緒に保存する前提で、長辺 390px 以下・40KB 以下に収める。推論や変換は端末内だけで行う。
enum DepthMapEncoder {
    static let maxLongSide: CGFloat = 390
    static let maxBytes = 40 * 1024
    /// 境界のちぎれを減らすための、ぼかし(σ≒2px)
    static let blurRadius: Double = 2

    /// 深度(AVDepthData)から、近いほど明るい(視差)グレースケールを作る。
    /// 撮影時に深度が取れた機種(LiDAR・深度つきカメラ)で使う。
    static func grayscale(from depth: AVDepthData) -> UIImage? {
        let converted = depth.depthDataType == kCVPixelFormatType_DisparityFloat32
            ? depth
            : depth.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
        let buffer = converted.depthDataMap
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        var values = [Float](repeating: 0, count: width * height)
        for y in 0..<height {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: Float32.self)
            for x in 0..<width { values[y * width + x] = row[x] }
        }
        return grayscale(normalized: values, width: width, height: height)
    }

    /// 0〜1 に正規化した値から、グレースケールの画像を作る(NaN・無限大は 0 として扱う)。
    static func grayscale(normalized values: [Float], width: Int, height: Int) -> UIImage? {
        let finite = values.filter { $0.isFinite }
        guard let low = finite.min(), let high = finite.max(), width > 0, height > 0 else { return nil }
        let span = high - low
        let bytes: [UInt8] = values.map { v in
            guard v.isFinite, span > 0 else { return 0 }
            return UInt8(max(0, min(255, (v - low) / span * 255)))
        }
        return grayscaleImage(bytes: bytes, width: width, height: height)
    }

    static func grayscaleImage(bytes: [UInt8], width: Int, height: Int) -> UIImage? {
        guard bytes.count == width * height,
              let provider = CGDataProvider(data: Data(bytes) as CFData),
              let cg = CGImage(
                  width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
              )
        else { return nil }
        return UIImage(cgImage: cg)
    }

    /// 保存用のデータ。ぼかして、長辺 390px 以下に縮め、PNG(グレースケール)にする。
    /// 40KB を超えるときは少しずつ縮めて、それでも超えたら nil(呼び出し側は保存しない)。
    static func encodedForStorage(_ gray: UIImage) -> Data? {
        guard let source = gray.cgImage else { return nil }
        // 先に、ぼかして長辺 390px 以下に縮める
        var current = resized(blurred(source) ?? source, factor: 1) ?? source
        for _ in 0..<5 {
            if let data = pngData(current), data.count <= maxBytes { return data }
            guard let next = resized(current, factor: 0.85) else { break }
            current = next
        }
        return nil
    }

    /// Metal に渡すための RGBA(グレーを3色へ複製)。depth の r だけを使う。
    static func rgbaImage(from gray: UIImage) -> CGImage? {
        guard let source = gray.cgImage else { return nil }
        return redraw(source, width: source.width, height: source.height)
    }

    /// Metal に渡すための RGBA。長辺を maxLongSide に収める(写真は縮めて GPU に渡す)。
    static func downscaledRGBA(_ image: UIImage, maxLongSide: CGFloat) -> CGImage? {
        guard let source = image.cgImage else { return nil }
        let longSide = CGFloat(max(source.width, source.height))
        let factor = min(1, maxLongSide / longSide)
        return redraw(source, width: Int(CGFloat(source.width) * factor), height: Int(CGFloat(source.height) * factor))
    }

    // MARK: - 内部

    private static func blurred(_ image: CGImage) -> CGImage? {
        let context = CIContext(options: [.useSoftwareRenderer: false])
        let input = CIImage(cgImage: image)
        let output = input
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blurRadius])
            .cropped(to: input.extent)
        return context.createCGImage(output, from: input.extent, format: .L8, colorSpace: CGColorSpaceCreateDeviceGray())
    }

    private static func resized(_ image: CGImage, factor: CGFloat) -> CGImage? {
        let longSide = CGFloat(max(image.width, image.height))
        let scale = min(1, maxLongSide / longSide) * factor
        let width = max(1, Int(CGFloat(image.width) * scale))
        let height = max(1, Int(CGFloat(image.height) * scale))
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private static func redraw(_ image: CGImage, width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0, let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
