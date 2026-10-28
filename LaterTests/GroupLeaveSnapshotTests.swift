import SwiftUI
import Testing
@testable import Later_再度

/// 見た目の確認用:抜ける前の確認(LATER_SNAPSHOT_DIR が設定されている時だけ)
@MainActor
struct GroupLeaveSnapshotTests {
    @Test func dialog() throws {
        guard let dir = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"].map({ URL(fileURLWithPath: $0) }) else { return }
        let user = UserProfile(name: "あおぞら", username: "")
        let other = UserProfile(name: "しずく", username: "")
        let group = LaterGroup(name: "よいしょー")
        _ = group.addMember(user)
        _ = group.addMember(other)
        let view = GroupLeaveOverlay(snapshot: LeaveSnapshot(group: group, user: user), haptics: ExposureHaptics(), perform: {}, onCancel: {}, onHome: {})
            .frame(width: 390, height: 844)
            .background(Color.black)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try #require(image.pngData()).write(to: dir.appendingPathComponent("leave_dialog.png"))
    }
}
