import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// 見た目の確認(LATER_SNAPSHOT_DIR がある時だけ):v21 の撮影画面(カメラはないので映像は黒)
@MainActor
struct CaptureV21SnapshotTests {
    private func shoot<V: View>(_ view: V, size: CGSize, name: String, dir: URL) async throws {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        try await Task.sleep(for: .seconds(0.8))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        try image.pngData()?.write(to: dir.appendingPathComponent("\(name).png"))
        window.isHidden = true
    }

    @Test func 撮影画面() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"] else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (label, size, top, bottom) in [("pro", CGSize(width: 402, height: 874), 62.0, 34.0), ("se", CGSize(width: 375, height: 667), 20.0, 0.0)] {
            for mode in [CaptureMode.photo, .video] {
                let layout = CaptureLayout(size: size, safeTop: top, safeBottom: bottom)
                let view = CaptureScreenV21(camera: CaptureCameraModel(), layout: layout, tags: ["雨の日", "放課後", "帰り道"], place: "渋谷区", left: 2,
                                            mode: .constant(mode), onBack: {}, onEditTags: {}, onPhoto: {}, onRecorded: { _ in })
                try await shoot(view, size: size, name: "capture-\(label)-\(mode.rawValue)", dir: dir)
            }
        }
    }
}
