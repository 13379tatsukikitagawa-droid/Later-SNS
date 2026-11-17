import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// v54:見本 C01(Friend 画面)。LATER_SNAPSHOT_DIR が設定されている時だけ書き出す。
@MainActor
struct FriendScreenSnapshotTests {
    private static func friend(_ name: String, shot: Bool) -> HomeFriend {
        HomeFriend(id: name, name: name, avatarData: nil, seed: UUID(), hasShot: shot, city: nil,
                   mosaicTiny: nil, mosaicKey: "", tag: nil, knockOff: false, isMe: false, groupIDs: [])
    }

    @Test func friend画面() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"] else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let view = FriendScreenV48(
            myName: "ゆい", myColorIndex: 2, myAvatarData: nil,
            friends: [Self.friend("れな", shot: true), Self.friend("あや", shot: true), Self.friend("そら", shot: false)],
            groups: [], onClose: {}
        )

        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.backgroundColor = .black
        window.windowLevel = .alert + 1
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        try await Task.sleep(for: .seconds(1.5))
        let shot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        try shot.pngData()?.write(to: dir.appendingPathComponent("friend_screen.png"))
        window.isHidden = true
    }
}
