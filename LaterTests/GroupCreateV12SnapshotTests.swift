import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// 見た目の確認用:グループ作成 v22(なまえ・つくっている・できた・おくった・失敗)× 昼夜 × SE / Pro Max。
/// LATER_SNAPSHOT_DIR と LATER_SNAPSHOT_ONLY=create のときだけ
@MainActor
struct GroupCreateV12SnapshotTests {
    @Test func 作成の画面() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"],
              ProcessInfo.processInfo.environment["LATER_SNAPSHOT_ONLY"] == "create" else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let schema = Schema([LaterPhoto.self, LaterGroup.self, UserProfile.self, PhotoVote.self, BlockedUser.self, ExposureDay.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let friends = (1...5).map { GroupCreateFriend(id: "f\($0)", name: "ともだち\($0)", avatarData: nil, seed: UUID()) }
        let cases: [(String, String, [GroupCreateFriend], NewGroupFlowView.Preview)] = [
            ("name-empty", "", [], .name),
            ("name-friends", "いつメン", friends, .name),
            ("creating", "いつメン", [], .creating),
            ("done-link", "いつメン", [], .doneLink),
            ("done-friends", "いつメン", friends, .doneFriends),
            ("failed", "いつメン", [], .failed),
        ]
        for (device, size) in [("se", CGSize(width: 375, height: 667)), ("promax", CGSize(width: 440, height: 956))] {
            for night in [false, true] {
                for (label, name, list, preview) in cases {
                    let view = NewGroupFlowView(initialName: name, friends: list, preview: preview, onClose: {})
                        .environment(\.palette, night ? .night : .day)
                        .modelContainer(container)
                    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
                    let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
                    window.frame = CGRect(origin: .zero, size: size)
                    window.windowLevel = .alert + 1
                    window.rootViewController = UIHostingController(rootView: view)
                    window.makeKeyAndVisible()
                    try await Task.sleep(for: .seconds(0.9))
                    let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                    }
                    try image.pngData()?.write(to: dir.appendingPathComponent("create-\(device)-\(night ? "night" : "day")-\(label).png"))
                    window.isHidden = true
                }
            }
        }
    }
}
