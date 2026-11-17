import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// v54:見本 B01(Groups タブ ヒーロー、ロック中)。LATER_SNAPSHOT_DIR が設定されている時だけ書き出す。
@MainActor
struct HeroSnapshotTests {
    @Test func ヒーロー() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"] else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for locked in [true, false] {
            let view = YesterdayOnceHero(
                mosaic: [], groupName: nil, dateLabel: "NOV 12", groupsCount: 0, daysLeft: 6, friendsCount: 0,
                locked: locked, hoursToOpen: 18, introToken: 0,
                onCreate: {}, onJoin: {}, onFriends: {}
            )
            .padding(18)
            .frame(width: 390, height: 520)
            .background(Color.white)
            .environment(\.scenePhase, .active)

            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
            window.frame = CGRect(x: 0, y: 0, width: 390, height: 520)
            window.windowLevel = .alert + 1
            window.rootViewController = UIHostingController(rootView: view)
            window.makeKeyAndVisible()
            try await Task.sleep(for: .seconds(1.2))
            let shot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
            try shot.pngData()?.write(to: dir.appendingPathComponent("hero_\(locked ? "locked" : "open").png"))
            window.isHidden = true
        }
    }
}
