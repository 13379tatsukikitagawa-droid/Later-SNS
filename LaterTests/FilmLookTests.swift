import CoreImage
import Testing
import UIKit
@testable import Later_再度

/// v107 §7-1:色見本(chart_in.png)に LUT だけ かけた 結果が 答え(chart_*_lut_only.png)と 1画素 ±3/255 以内
struct FilmLookTests {
    private final class Anchor {}
    private func fixture(_ name: String) -> CIImage? {
        let b = Bundle(for: Anchor.self)
        guard let url = b.url(forResource: name, withExtension: "png") ?? b.url(forResource: name, withExtension: "png", subdirectory: "FilmFixtures") else { return nil }
        return CIImage(contentsOf: url)
    }
    private func rgba(_ img: CIImage) -> [UInt8] {
        let w = Int(img.extent.width), h = Int(img.extent.height)
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        FilmLook.shared.context.render(img, toBitmap: &buf, rowBytes: w * 4, bounds: img.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return buf
    }
    private func maxDiff(cheki: Bool, answer: String) throws -> Int {
        let input = try #require(fixture("chart_in"))
        let want = try #require(fixture(answer))
        let got = FilmLook.shared.lutOnly(input, cheki: cheki).cropped(to: input.extent)
        let a = rgba(got), b = rgba(want)
        #expect(a.count == b.count)
        var worst = 0
        for i in stride(from: 0, to: min(a.count, b.count), by: 4) { for c in 0..<3 { worst = max(worst, abs(Int(a[i + c]) - Int(b[i + c]))) } }
        return worst
    }
    @Test func chekiLUTMatchesAnswer() throws { #expect(try maxDiff(cheki: true, answer: "chart_cheki_lut_only") <= 3) }
    @Test func retro8LUTMatchesAnswer() throws { #expect(try maxDiff(cheki: false, answer: "chart_retro8_lut_only") <= 3) }

    @Test func chekiJPEGShapeAndNoMetadata() throws {
        let img = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 3000)).image { c in
            UIColor.orange.setFill(); c.fill(CGRect(x: 0, y: 0, width: 2000, height: 3000))
        }
        let data = try #require(FilmLook.shared.chekiJPEG(from: img, seed: 7))
        let out = try #require(UIImage(data: data))
        #expect(max(out.size.width, out.size.height) <= 1441)
        #expect(abs(out.size.width / out.size.height - 0.75) < 0.01)
        let again = try #require(FilmLook.shared.chekiJPEG(from: img, seed: 7))
        #expect(again == data)   // 同じ seed なら 同じ 粒子
        let src = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
        #expect(props?[kCGImagePropertyGPSDictionary] == nil)
    }
}

struct InstaxShareFrameTests {
    @Test func cardRatioAndPaper() throws {
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { c in UIColor.blue.setFill(); c.fill(CGRect(x: 0, y: 0, width: 300, height: 400)) }
        let out = InstaxShareFrame.compose(photo: photo, date: Date(timeIntervalSince1970: 1_700_000_000), width: 540)
        #expect(out.size.width == 540)
        #expect(abs(out.size.height - 860) <= 1)            // 54:86
        let cg = try #require(out.cgImage)
        let w = cg.width, h = cg.height
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = try #require(CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        func px(_ x: Int, _ y: Int) -> (Int, Int, Int) { let i = (y * w + x) * 4; return (Int(buf[i]), Int(buf[i + 1]), Int(buf[i + 2])) }
        let corner = px(3, 3); #expect(abs(corner.0 - 246) <= 2 && abs(corner.1 - 243) <= 2 && abs(corner.2 - 234) <= 2)
        let mid = px(270, 330); #expect(mid.2 > 200 && mid.0 < 60)
    }
}
