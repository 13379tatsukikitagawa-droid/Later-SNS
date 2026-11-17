import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// v54:見本 A03(消灯まで ピル → ひらいた パネル)。LATER_SNAPSHOT_DIR が設定されている時だけ書き出す。
@MainActor
struct LightsPanelSnapshotTests {
    private static func date(_ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 18, of: Date())!
    }

    @Test func ピルとパネル() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"] else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let pill = LaterHeader(home: .today, clock: { Self.date(14, 32) })
            .environment(\.scenePhase, .active)
            .frame(width: 390, height: 160)
            .background(Color(hex: "EFEFEA"))
        try await render(pill, name: "lights_pill", size: CGSize(width: 390, height: 160))

        let panel = ZStack(alignment: .topLeading) {
            Color.black
            LightsPanel(now: Self.date(14, 32), width: 366, home: .today, onClose: {})
                .padding(.leading, 12)
                .padding(.top, 20)
        }
        .environment(\.scenePhase, .active)
        .frame(width: 390, height: 420)
        try await render(panel, name: "lights_panel", size: CGSize(width: 390, height: 420), background: .black)
    }

    private func render(_ view: some View, name: String, size: CGSize, background: UIColor = .white) async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"] else { return }
        let dir = URL(fileURLWithPath: path)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(origin: .zero, size: size)
        window.backgroundColor = background
        window.windowLevel = .alert + 1
        window.rootViewController = UIHostingController(rootView: view)
        window.rootViewController?.view.backgroundColor = background
        window.makeKeyAndVisible()
        try await Task.sleep(for: .seconds(1.5))
        let shot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        try shot.pngData()?.write(to: dir.appendingPathComponent("\(name).png"))
        window.isHidden = true
    }
}
