import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// v28/v29 暗室(LATER_SNAPSHOT_ONLY=dark のときだけ)
@MainActor
struct HomeDarkroomSnapshotTests {
    private static func image(_ hue: CGFloat) -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { ctx in
            let colors = [UIColor(hue: hue, saturation: 0.55, brightness: 0.95, alpha: 1).cgColor, UIColor(hue: hue + 0.2, saturation: 0.7, brightness: 0.5, alpha: 1).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 300, y: 400), options: [])
        }.jpegData(compressionQuality: 0.8)!
    }

    @Test func 暗室() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"],
              ProcessInfo.processInfo.environment["LATER_SNAPSHOT_ONLY"] == "dark" else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let schema = Schema([LaterPhoto.self, LaterGroup.self, UserProfile.self, PhotoVote.self, BlockedUser.self, ExposureDay.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        let me = UserProfile(name: "わたし", username: "me")
        context.insert(me)
        let group = LaterGroup(name: "いつメン")
        context.insert(group)
        _ = group.addMember(me)
        var friends: [UserProfile] = []
        for (i, n) in ["あや", "れな"].enumerated() {
            let p = UserProfile(name: n, username: n)
            p.cloudKitUserRecordName = "u\(i)"
            context.insert(p)
            _ = group.addMember(p)
            friends.append(p)
        }
        let now = Date()
        let y = DailyWindow.yesterday(for: now)
        for (i, f) in friends.enumerated() {
            let d = y.open.addingTimeInterval(Double(i + 1) * 3600)
            let p = LaterPhoto(imageData: Self.image(CGFloat(i) * 0.3), captureDate: d, unlockDate: d)
            p.isPosted = true
            p.authorCloudKitUserRecordName = f.cloudKitUserRecordName
            p.tags = i == 0 ? ["朝"] : ["カフェ"]
            p.groupID = group.id
            context.insert(p)
            group.photos.append(p)
        }
        for k in 0..<4 {
            let base = Calendar.current.date(byAdding: .day, value: -k, to: DailyWindow.latest(for: now).open)!
            for j in 0..<(k == 0 ? 1 : 2) {
                let d = base.addingTimeInterval(Double(j) * 7200 + 1800)
                let p = LaterPhoto(imageData: Self.image(CGFloat(k * 2 + j) / 9), captureDate: d, unlockDate: d, owner: me)
                p.tags = ["放課後"]
                context.insert(p)
            }
        }
        let data = DarkroomData.make(me: me, groups: [group], blocked: [], now: now)
        for (label, night, offset) in [("day-1", false, 0.0), ("day-2", false, 1700.0), ("night-1", true, 0.0)] {
            let view = VStack(spacing: 0) {
                Color(hex: "FBF8F3").frame(height: 60)
                DuskTodaySection(shots: data.todayShots, now: now, night: night, onShoot: {}, onOpenDevelop: {})
                DarkroomSection(data: data, groups: [group], summaries: GroupRingMath.summaries(for: [group], now: now), invites: [],
                                words: [WorldWordsStore.Word(tag: "夕焼け", count: 3, tones: ["FF9A62", "EE5E9C"]), WorldWordsStore.Word(tag: "カフェ", count: 2, tones: ["9ED8FF", "5AD6B0"])],
                                friends: [], now: now, onOpenChat: { _ in }, onCreateGroup: {}, onJoin: { _ in }, onOpenMondo: {},
                                onOpenFriends: {}, onOpenPhoto: { _ in }, onToast: { _ in })
                Spacer(minLength: 0)
            }
            .frame(width: 393, height: 3600, alignment: .top)
            .offset(y: -offset)
            .frame(width: 393, height: 1700, alignment: .top)
            .clipped()
            .background(night ? Color(hex: "0A0A0B") : Color(hex: "FBF8F3"))
            .modelContainer(container)
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
            window.frame = CGRect(x: 0, y: 0, width: 393, height: 1700)
            window.windowLevel = .alert + 1
            window.rootViewController = UIHostingController(rootView: view)
            window.makeKeyAndVisible()
            try await Task.sleep(for: .seconds(2))
            let shot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
            try shot.pngData()?.write(to: dir.appendingPathComponent("dark-\(label).png"))
            window.isHidden = true
        }
    }
}
