import CloudKit
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// 部屋の 見た目(LATER_SNAPSHOT_ONLY=chat のときだけ)
@MainActor
struct GroupChatSnapshotTests {
    @Test func 部屋() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"],
              ProcessInfo.processInfo.environment["LATER_SNAPSHOT_ONLY"] == "chat" else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let schema = Schema([LaterPhoto.self, LaterGroup.self, UserProfile.self, PhotoVote.self, BlockedUser.self, ExposureDay.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        let group = LaterGroup(name: "放課後クラブ")
        context.insert(group)
        for (i, n) in ["れな", "そら", "はる"].enumerated() {
            let p = UserProfile(name: n, username: n)
            p.cloudKitUserRecordName = "u\(i)"
            context.insert(p)
            _ = group.addMember(p)
        }
        let zone = CKRecordZone.ID(zoneName: "g", ownerName: "o")
        let base = Date().addingTimeInterval(-3600)
        let lines: [(String, String, String)] = [("u0", "text", "きのうの 夕焼け、やばかった"), ("u0", "text", "あと そらだけ…"), ("u1", "text", "いま 撮る!"), ("u2", "sticker", "それな"), ("u1", "text", "😂")]
        for (i, line) in lines.enumerated() {
            let r = CKRecord(recordType: ChatRecordType.message, recordID: CKRecord.ID(recordName: "snap\(i)", zoneID: zone))
            r["senderId"] = line.0
            r["kind"] = line.1
            if line.1 == "sticker" { r["stickerId"] = line.2 } else { r["text"] = line.2 }
            r["sentAt"] = base.addingTimeInterval(Double(i) * 60)
            GroupChatStore.shared.receive(record: r, groupID: group.id, myRecordName: nil)
        }
        for night in [false, true] {
            let view = GroupChatRoomView(group: group, onClose: {}, onOpenGroupSheet: {})
                .environment(\.palette, night ? .night : .day)
                .modelContainer(container)
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
            window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
            window.windowLevel = .alert + 1
            window.rootViewController = UIHostingController(rootView: view)
            window.makeKeyAndVisible()
            try await Task.sleep(for: .seconds(1.2))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
            try image.pngData()?.write(to: dir.appendingPathComponent("chat-\(night ? "night" : "day").png"))
            window.isHidden = true
        }
        for i in 0..<lines.count { GroupChatStore.shared.removeRecord(named: "snap\(i)") }
    }
}
