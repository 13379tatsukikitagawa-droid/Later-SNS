import UIKit

/// 撮影直後の写真から、代表色(HEX文字列、最大3色)だけを抽出する。
/// Home画面「現像中の写真の壁」・World画面は、解禁前の写真本体を一切端末に
/// ダウンロードしない設計のため、投稿する本人の端末でこの代表色だけを抽出して
/// CloudKitへ添える(抽出後、元画像はこの処理と無関係にそのままCKAssetとして
/// アップロードされる=普段通りの投稿フロー。代表色はあくまで「解禁前に他メンバーへ
/// 先出しする」ための軽量な副産物)。
enum DominantColorExtractor {
    /// サムネイルを3x3にまで縮小し、その9マスの平均色から代表的な3色を選ぶ
    /// (単純平均1色だけだと写真全体が同じような灰色に潰れて見えるため、
    /// 明るさが離れた3マスを選んで多少の階調を残す)。
    static func extractHexColors(from imageData: Data, count: Int = 3) -> [String] {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else { return [] }

        let side = 3
        guard let pixels = downsampledPixels(cgImage, side: side) else { return [] }

        let sorted = pixels.sorted { $0.brightness < $1.brightness }
        guard !sorted.isEmpty else { return [] }

        let pickCount = min(count, sorted.count)
        let step = max(1, sorted.count / pickCount)
        var picked: [String] = []
        var index = 0
        while picked.count < pickCount && index < sorted.count {
            picked.append(sorted[index].hex)
            index += step
        }
        return picked
    }

    private struct Pixel {
        let hex: String
        let brightness: Double
    }

    private static func downsampledPixels(_ cgImage: CGImage, side: Int) -> [Pixel]? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * side
        var rawData = [UInt8](repeating: 0, count: bytesPerRow * side)

        guard let context = CGContext(
            data: &rawData,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        var pixels: [Pixel] = []
        for row in 0..<side {
            for col in 0..<side {
                let offset = (row * side + col) * bytesPerPixel
                let r = rawData[offset]
                let g = rawData[offset + 1]
                let b = rawData[offset + 2]
                let brightness = (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b))
                let hex = String(format: "#%02X%02X%02X", r, g, b)
                pixels.append(Pixel(hex: hex, brightness: brightness))
            }
        }
        return pixels
    }
}
