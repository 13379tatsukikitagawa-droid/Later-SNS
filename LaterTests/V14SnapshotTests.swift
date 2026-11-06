import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// 見た目の確認用(v14):撮影前・チェキ フィード・ME・カレンダー・ともだち・現像ページャー。LATER_SNAPSHOT_DIR があるときだけ
@MainActor
struct V14SnapshotTests {
    private func shoot<V: View>(_ view: V, name: String, dir: URL, height: CGFloat = 874) async throws {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(x: 0, y: 0, width: 402, height: height)
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        try await Task.sleep(for: .seconds(1.4))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try image.pngData()?.write(to: dir.appendingPathComponent("v14-\(name).png"))
        window.isHidden = true
    }

    private func photo(_ hue: CGFloat) -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { ctx in
            UIColor(hue: hue, saturation: 0.55, brightness: 0.85, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
        }.jpegData(compressionQuality: 0.8)!
    }

    @Test func 画面() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"] else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let schema = Schema([LaterPhoto.self, LaterGroup.self, UserProfile.self, PhotoVote.self, BlockedUser.self, ExposureDay.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let now = Date()
        let shots = [TodayShot(id: "a", takenAt: now.addingTimeInterval(-3600 * 3), city: "渋谷区"), TodayShot(id: "b", takenAt: now.addingTimeInterval(-3600), city: "渋谷区")]
        let seed = UUID()
        let pages = [
            ViewerPage(id: "p1", source: .local(photo(0.05)), tags: ["ゆうやけ", "部活"], capturedAt: now.addingTimeInterval(-86400), authorSeed: seed, showsAuthor: true, label: "ひるやすみ会", authorName: "ぱんちゃ", city: "渋谷区"),
            ViewerPage(id: "p2", source: .local(photo(0.6)), tags: ["さんぽ"], capturedAt: now.addingTimeInterval(-86000), authorSeed: seed, showsAuthor: true, label: "ひるやすみ会", authorName: "ぱんちゃ", city: "渋谷区"),
        ]
        let friends = (0..<5).map { i in
            HomeFriend(id: "f\(i)", name: ["れな", "みお", "ここ", "りさ", "ゆず"][i], avatarData: nil, seed: UUID(), hasShot: i % 2 == 0, city: nil, mosaicTiny: nil, mosaicKey: "f\(i)", tag: "夕焼け", knockOff: false, isMe: false, groupIDs: [])
        }
        for (palette, tag) in [(Palette.day, "day"), (Palette.night, "night")] {
            try await shoot(TagScreen(left: 3, haptics: ExposureHaptics(), tags: .constant(["さんぽ"]), place: "渋谷区").environment(\.palette, palette), name: "tag-\(tag)", dir: dir)
            try await shoot(TagScreen(left: 3, haptics: ExposureHaptics(), tags: .constant([]), place: "渋谷区").environment(\.palette, palette), name: "tag-se-\(tag)", dir: dir, height: 667)
            try await shoot(VerticalPhotoViewer(pages: pages, startIndex: 0, haptics: ExposureHaptics(), onClose: {}).environment(\.palette, palette), name: "feed-\(tag)", dir: dir)
            try await shoot(MEScreen(onBack: {}, onShoot: {}).environment(\.palette, palette).modelContainer(container), name: "me-\(tag)", dir: dir)
            try await shoot(LaterCalendarView(onClose: {}).environment(\.palette, palette).modelContainer(container), name: "calendar-\(tag)", dir: dir)
            try await shoot(FriendsHubView(myName: "たつき", friends: friends, groups: [], onClose: {}).environment(\.palette, palette).modelContainer(container), name: "friends-\(tag)", dir: dir)
            try await shoot(DevelopPager(shots: shots, now: now, startIndex: 1, onClose: {}).background(Color(hex: "1B1B1F")), name: "pager-\(tag)", dir: dir)
            var data = HomeLayerData()
            data.friends = friends
            try await shoot(ScrollView { LaterTodayHome(state: .ready(shotAt: now), now: now, shots: shots, data: data, actions: HomeLayerActions(), isActive: false, onOpenShot: { _ in }, onShoot: {}, onOpenMe: {}, onFriend: { _ in }, onInvite: {}).padding(.top, 100) }.background(palette.bg).environment(\.palette, palette), name: "today-\(tag)", dir: dir)
        }
    }
}
