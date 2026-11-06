import CoreImage
import CoreVideo
import Foundation
import Testing
import UIKit
@testable import Later_再度

/// 動画の質感 RETRO-8(vlook.py の値)
struct RetroLookTests {
    private static func sample(width: Int, height: Int, dark: Bool) -> CIImage {
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: f).image { ctx in
            let cg = ctx.cgContext
            let top = dark ? UIColor(red: 0.08, green: 0.07, blue: 0.12, alpha: 1) : UIColor(red: 0.95, green: 0.62, blue: 0.42, alpha: 1)
            let bottom = dark ? UIColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1) : UIColor(red: 0.25, green: 0.3, blue: 0.45, alpha: 1)
            cg.drawLinearGradient(CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1])!, start: .zero, end: CGPoint(x: 0, y: height), options: [])
            UIColor(white: dark ? 0.9 : 1, alpha: 1).setFill()
            for i in 0..<6 { cg.fillEllipse(in: CGRect(x: width / 8 + i * width / 8, y: height / 3, width: width / 14, height: width / 14)) }
            UIColor(white: 0.15, alpha: 1).setFill(); cg.fill(CGRect(x: width / 3, y: height / 2, width: width / 3, height: height / 3))
        }
        return CIImage(cgImage: image.cgImage!)
    }

    @Test func 値はvlookと同じ() {
        let p = RetroLookParams.default
        #expect(p.baseWidth == 360 && p.resScale == 0.80 && p.sharpenSigma == 1.0 && p.sharpenAmount == 0.85)
        #expect(p.gamma == 0.93 && p.contrast == 1.08 && p.saturation == 1.10)
        #expect(p.lift == [0.030, 0.032, 0.040] && p.warm == [1.035, 1.0, 0.955])
        #expect(p.ghost == 0.14 && p.bandLevels == 44 && p.bandBelow == 0.34 && p.vignette == 0.16)
        #expect(abs(p.exposure(at: 3.3 / 4) - 1.045) < 0.0001)
        #expect(RetroStamp.text(for: Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 5))!) == "'26 11 05")
    }

    @Test func カーネルが動く() {
        let look = RetroLook()
        let input = Self.sample(width: 540, height: 720, dark: false)
        let out = look.process(input, time: 0, stampText: "'26 11 05", light: false)
        #expect(out.extent == input.extent)
        #expect(look.context.createCGImage(out, from: out.extent) != nil)
    }

    /// 1コマの時間(540×720)。シミュレーターの数字は目安。実機(いちばん古い iPhone 11 / SE2)で測ること
    @Test func 一コマの時間() throws {
        let look = RetroLook()
        let input = Self.sample(width: 540, height: 720, dark: true)
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 540, 720, kCVPixelFormatType_32BGRA, [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer)
        let pixelBuffer = try #require(buffer)
        for i in 0..<5 { look.context.render(look.process(input, time: Double(i) / 30, velocityX: 40, stampText: "'26 11 05", light: false), to: pixelBuffer) }
        let n = 30
        let start = Date()
        for i in 0..<n {
            look.context.render(look.process(input, time: Double(i) / 30, velocityX: 40, stampText: "'26 11 05", light: false), to: pixelBuffer)
        }
        let ms = Date().timeIntervalSince(start) * 1000 / Double(n)
        let start2 = Date()
        for i in 0..<n {
            look.context.render(look.process(input, time: Double(i) / 30, stampText: "'26 11 05", light: true), to: pixelBuffer)
        }
        let light = Date().timeIntervalSince(start2) * 1000 / Double(n)
        print("[RetroLook] 540x720 1コマ: \(String(format: "%.1f", ms))ms(熱いときの軽い版: \(String(format: "%.1f", light))ms)")
    }

    @Test func 見た目() throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"] else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for dark in [false, true] {
            let look = RetroLook()
            let input = Self.sample(width: 540, height: 720, dark: dark)
            var out = input
            for i in 0..<3 { out = look.process(input, time: Double(i) / 30, velocityX: 0, stampText: "'26 11 05", light: false) }
            let name = dark ? "retro-night" : "retro-day"
            try UIImage(cgImage: look.context.createCGImage(input, from: input.extent)!).pngData()!.write(to: dir.appendingPathComponent("\(name)-before.png"))
            try UIImage(cgImage: look.context.createCGImage(out, from: input.extent)!).pngData()!.write(to: dir.appendingPathComponent("\(name)-after.png"))
        }
        // 見本の写真(作業用フォルダにある時だけ。アプリには入れない)
        if let samples = ProcessInfo.processInfo.environment["LATER_RETRO_SAMPLE"], let ui = UIImage(contentsOfFile: samples), let ci = CIImage(image: ui) {
            let look = RetroLook()
            let scaled = ci.transformed(by: CGAffineTransform(scaleX: 540 / ci.extent.width, y: 720 / ci.extent.height))
            var out = scaled
            for i in 0..<3 { out = look.process(scaled, time: Double(i) / 30, stampText: "'26 11 05", light: false) }
            try UIImage(cgImage: look.context.createCGImage(out, from: scaled.extent)!).pngData()!.write(to: dir.appendingPathComponent("retro-sample-after.png"))
        }
    }
}
