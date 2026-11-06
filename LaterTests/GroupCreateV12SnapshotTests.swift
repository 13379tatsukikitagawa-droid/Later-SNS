import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// 見た目の確認用:グループ作成 v13 の2ステップ +「できました」(昼・夜)。LATER_SNAPSHOT_DIR があるときだけ
@MainActor
struct GroupCreateV12SnapshotTests {
    @Test func 作成の3ステップ() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"] else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let schema = Schema([LaterPhoto.self, LaterGroup.self, UserProfile.self, PhotoVote.self, BlockedUser.self, ExposureDay.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        for night in [false, true] {
            for (step, name) in [(1, ""), (1, "あいうえおかきくけこさしすせ"), (2, "帰り道の4人"), (3, "帰り道の4人")] {
                let view = NewGroupFlowView(initialName: name, startStep: step, onClose: {})
                    .environment(\.palette, night ? .night : .day)
                    .modelContainer(container)
                let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
                let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
                window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
                window.rootViewController = UIHostingController(rootView: view)
                window.makeKeyAndVisible()
                try await Task.sleep(for: .seconds(1.2))
                let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                try image.pngData()?.write(to: dir.appendingPathComponent("create-\(night ? "night" : "day")-\(step)-\(name.isEmpty ? "empty" : String(name.count)).png"))
                window.isHidden = true
            }
        }
    }
}
