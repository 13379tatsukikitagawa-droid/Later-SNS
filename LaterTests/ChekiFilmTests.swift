import CoreImage
import Foundation
import Testing
import UIKit
@testable import Later_再度

/// チェキ加工(FilmEmulation 2026-11)の決めごと
struct ChekiFilmTests {
    @Test func 黒は青みに持ち上がり白はクリームになる() {
        let c = FilmEmulation.Configuration.default
        let black = FilmEmulation.grade(SIMD3(0, 0, 0), c)
        #expect(abs(black.x - 0.070) < 0.001 && abs(black.y - 0.075) < 0.001 && abs(black.z - 0.105) < 0.001)
        #expect(black.z > black.x)
        let white = FilmEmulation.grade(SIMD3(1, 1, 1), c)
        #expect(abs(white.x - 0.965) < 0.001 && abs(white.y - 0.945) < 0.001 && abs(white.z - 0.915) < 0.001)
        #expect(white.x > white.z)
        // 中間は白っぽく(ガンマ 0.82)
        let mid = FilmEmulation.grade(SIMD3(0.4, 0.4, 0.4), c)
        #expect(mid.y > 0.4)
    }

    @Test func 緑は黄緑へ青は青緑へ() {
        let c = FilmEmulation.Configuration.default
        let green = FilmEmulation.grade(SIMD3(0.2, 0.7, 0.2), c)
        // 赤が少し増える(黄の方へ)
        #expect(green.x > green.z)
        let blue = FilmEmulation.grade(SIMD3(0.2, 0.3, 0.8), c)
        #expect(blue.y > 0.3)
    }

    @Test func 夜の撮影() {
        let cal = Calendar.current
        let day = cal.startOfDay(for: Date())
        #expect(FilmEmulation.isNightShot(cal.date(bySettingHour: 22, minute: 0, second: 0, of: day)!))
        #expect(FilmEmulation.isNightShot(cal.date(bySettingHour: 8, minute: 59, second: 0, of: day)!))
        #expect(!FilmEmulation.isNightShot(cal.date(bySettingHour: 15, minute: 0, second: 0, of: day)!))
    }

    @Test func LUTは33の3乗() {
        #expect(FilmEmulation.cubeData(.default).count == 33 * 33 * 33 * 4 * 4)
    }

    private static func sample(width: Int, height: Int) -> CIImage {
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }()).image { ctx in
            let cg = ctx.cgContext
            let colors = [UIColor(red: 0.95, green: 0.6, blue: 0.4, alpha: 1).cgColor, UIColor(red: 0.2, green: 0.3, blue: 0.6, alpha: 1).cgColor]
            cg.drawLinearGradient(CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!, start: .zero, end: CGPoint(x: 0, y: height), options: [])
            UIColor.white.setFill(); cg.fill(CGRect(x: width / 10, y: height / 10, width: width / 3, height: height / 3))
            UIColor.black.setFill(); cg.fill(CGRect(x: width / 2, y: height / 2, width: width / 3, height: height / 3))
            UIColor(red: 0.2, green: 0.7, blue: 0.25, alpha: 1).setFill(); cg.fill(CGRect(x: width / 10, y: height * 6 / 10, width: width / 4, height: height / 4))
            UIColor(red: 1, green: 0.95, blue: 0.8, alpha: 1).setFill(); cg.fillEllipse(in: CGRect(x: width * 6 / 10, y: height / 8, width: width / 8, height: width / 8))
        }
        return CIImage(cgImage: image.cgImage!)
    }

    /// 平均の色(sRGB 0〜1)
    private static func average(_ image: CIImage, in rect: CGRect, context: CIContext) -> SIMD3<Double> {
        let f = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: image, kCIInputExtentKey: CIVector(cgRect: rect)])!
        var px = [UInt8](repeating: 0, count: 4)
        context.render(f.outputImage!, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return SIMD3(Double(px[0]), Double(px[1]), Double(px[2])) / 255
    }

    @Test func 白い壁はクリームで黒は真っ黒にならない() {
        let context = CIContext()
        let input = Self.sample(width: 420, height: 560)
        let out = FilmEmulation.process(input, seed: 7)
        // CI の座標は左下が原点:白い四角は上の方、黒い四角は下の右
        let white = Self.average(out, in: CGRect(x: 60, y: 560 - 220, width: 80, height: 80), context: context)
        let black = Self.average(out, in: CGRect(x: 240, y: 30, width: 80, height: 80), context: context)
        // 真っ白ではなく、クリーム(青が赤より低い)
        #expect(white.z < 0.95 && white.x - white.z > 0.03)
        #expect(black.x > 0.05 && black.z >= black.x)
    }

    @Test func 加工の時間() {
        let context = CIContext()
        let input = Self.sample(width: 1080, height: 1440)
        _ = context.createCGImage(FilmEmulation.process(input, seed: 1), from: input.extent)
        let start = Date()
        _ = context.createCGImage(FilmEmulation.process(input, seed: 2), from: input.extent)
        let ms = Date().timeIntervalSince(start) * 1000
        print("[ChekiFilm] 1080x1440: \(Int(ms))ms")
        #expect(ms < 2000)
    }

    /// 見た目の確認(LATER_SNAPSHOT_DIR がある時だけ):前 / 後 と、見本の写真の黒・白の色
    @Test func 見た目() throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"] else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let context = CIContext()
        let input = Self.sample(width: 420, height: 560)
        for (name, image) in [("cheki-before", input), ("cheki-after", FilmEmulation.process(input, seed: 3))] {
            let cg = context.createCGImage(image, from: input.extent)!
            try UIImage(cgImage: cg).pngData()!.write(to: dir.appendingPathComponent("\(name).png"))
        }
        var night = FilmEmulation.Configuration.default
        night.nightFlash = true
        let cg = context.createCGImage(FilmEmulation.process(input, configuration: night, seed: 3), from: input.extent)!
        try UIImage(cgImage: cg).pngData()!.write(to: dir.appendingPathComponent("cheki-after-night.png"))
        // 見本(加工ずみ)の写真があれば、いちばん暗い所・明るい所の色を出す
        if let samples = ProcessInfo.processInfo.environment["LATER_CHEKI_SAMPLES"] {
            for file in (try? FileManager.default.contentsOfDirectory(atPath: samples)) ?? [] where file.hasSuffix(".jpeg") {
                guard let ui = UIImage(contentsOfFile: samples + "/" + file), let ci = CIImage(image: ui) else { continue }
                let minF = CIFilter(name: "CIAreaMinimum", parameters: [kCIInputImageKey: ci, kCIInputExtentKey: CIVector(cgRect: ci.extent)])!
                let maxF = CIFilter(name: "CIAreaMaximum", parameters: [kCIInputImageKey: ci, kCIInputExtentKey: CIVector(cgRect: ci.extent)])!
                var a = [UInt8](repeating: 0, count: 4), b = [UInt8](repeating: 0, count: 4)
                context.render(minF.outputImage!, toBitmap: &a, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
                context.render(maxF.outputImage!, toBitmap: &b, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
                print("[ChekiSample] \(file) min=\(a.prefix(3)) max=\(b.prefix(3))")
            }
        }
    }
}
