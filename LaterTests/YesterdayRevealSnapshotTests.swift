import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// 【D】現像の画面の 見た目(LATER_SNAPSHOT_DIR と LATER_SNAPSHOT_ONLY=reveal のときだけ)
@MainActor
struct YesterdayRevealSnapshotTests {
    private static func sample() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { ctx in
            let colors = [UIColor.systemOrange.cgColor, UIColor.systemPink.cgColor, UIColor.systemIndigo.cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1])!
            ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 300, y: 400), options: [])
        }
    }

    @Test func 現像の画面() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"],
              ProcessInfo.processInfo.environment["LATER_SNAPSHOT_ONLY"] == "reveal" else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let image = Self.sample()
        let tiny = MosaicRenderer.makeTiny(from: image.jpegData(compressionQuality: 0.9)!)
        for (label, size) in [("se", CGSize(width: 375, height: 667)), ("promax", CGSize(width: 440, height: 956))] {
            for (name, wait, plays) in [("mosaic", 0.4, true), ("done", 1.5, false)] {
                let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
                let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
                window.frame = CGRect(origin: .zero, size: size)
                window.windowLevel = .alert + 1
                window.rootViewController = UIHostingController(rootView: YesterdayRevealView(image: image, tiny: tiny, key: "snap-\(label)-\(name)", ordinal: 2, playsReveal: plays) { _ in })
                window.makeKeyAndVisible()
                try await Task.sleep(for: .seconds(wait))
                let shot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
                try shot.pngData()?.write(to: dir.appendingPathComponent("reveal-\(name)-\(label).png"))
                window.isHidden = true
            }
        }
    }
}
