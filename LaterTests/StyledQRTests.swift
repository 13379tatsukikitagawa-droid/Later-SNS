import Testing
import SwiftUI
import CoreImage
@testable import Later_再度

@MainActor
struct StyledQRTests {
    /// シミュレータでは Vision の バーコードが 動かない ため CIDetector で 読む(実機でも 同じ QR を 読める)
    static func read(_ cg: CGImage) -> String? {
        let d = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        return (d?.features(in: CIImage(cgImage: cg)).first as? CIQRCodeFeature)?.messageString
    }

    private func decode(_ text: String, side: CGFloat = 232) -> String? {
        guard let m = QRMatrix.make(text) else { return nil }
        let view = StyledQRView(matrix: m, progress: 1, side: side).padding(side / CGFloat(m.count) * 4).background(Color(hex: "FBFAF6"))
        let r = ImageRenderer(content: view)
        r.scale = 4
        guard let ui = r.uiImage, let cg = ui.cgImage else { print("QRTEST no image"); return nil }
        try? ui.pngData()?.write(to: URL(fileURLWithPath: "/tmp/qrtest_\(text.count).png"))
        return Self.read(cg)
    }

    @Test func 友だちリンクを読める() {
        let link = "later://friend?u=_a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6"
        #expect(decode(link) == link)
    }

    @Test func 短いURLも読める() {
        let link = "https://lattag.app/u/yui_0612"
        #expect(decode(link) == link)
    }
}

@MainActor
struct VisionSanity {
    @Test func 普通のQRは読める() {
        let img = QRImage.make("https://lattag.app/u/yui_0612")!
        let padded = UIGraphicsImageRenderer(size: CGSize(width: img.size.width + 80, height: img.size.height + 80)).image { c in
            UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: CGSize(width: img.size.width + 80, height: img.size.height + 80)))
            img.draw(at: CGPoint(x: 40, y: 40))
        }
        #expect(StyledQRTests.read(padded.cgImage!) == "https://lattag.app/u/yui_0612")
    }
}
