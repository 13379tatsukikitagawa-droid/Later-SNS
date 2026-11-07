import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// 見た目の確認用:昨日 → グループ タブ(ヒーロー)と、プロフィールの「カレンダー」。LATER_SNAPSHOT_DIR があるときだけ
@MainActor
struct YesterdayGroupSnapshotTests {
    static let sizes: [(String, CGSize)] = [("se", CGSize(width: 375, height: 667)), ("promax", CGSize(width: 440, height: 956))]

    private func shoot<V: View>(_ view: V, name: String, size: CGSize, dir: URL, wait: Double = 2.2, scroll: CGFloat = 0) async throws {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        try await Task.sleep(for: .seconds(wait))
        if scroll > 0, let view = window.rootViewController?.view, let sv = Self.findScroll(in: view) {
            sv.setContentOffset(CGPoint(x: 0, y: scroll), animated: false)
            try await Task.sleep(for: .seconds(1.2))
        }
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try image.pngData()?.write(to: dir.appendingPathComponent("\(name).png"))
        window.isHidden = true
    }

    private static func findScroll(in view: UIView) -> UIScrollView? {
        if let s = view as? UIScrollView, s.contentSize.height > s.bounds.height { return s }
        for sub in view.subviews { if let s = findScroll(in: sub) { return s } }
        return nil
    }

    private func groupTab(palette: Palette, sections: [GroupSectionModel]) -> some View {
        ZStack(alignment: .top) {
            (palette.isNight ? Color.black : Color.white).ignoresSafeArea()
            HomeV5GroupPage(sections: sections, isActive: true, haptics: ExposureHaptics(), shotEvent: nil, windowKey: "snap",
                            topInset: 59, canCreate: true, onOpenRoom: { _ in }, onOpenTile: { _, _, _ in },
                            onCycleLocation: { _ in }, onAdd: {}, userName: "あおい")
            LaterHeader(home: .yesterday, avatarName: "あ", showsBadge: false)
                .padding(.top, 59)
        }
        .environment(\.palette, palette)
        .environment(\.colorScheme, palette.isNight ? .dark : .light)
    }

    @Test func 画面() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"] else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let schema = Schema([LaterPhoto.self, LaterGroup.self, UserProfile.self, PhotoVote.self, BlockedUser.self, ExposureDay.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let only = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_ONLY"] ?? "all"
        for (label, size) in Self.sizes {
            if only == "all" || only == "me" {
                try await shoot(MEScreenV19(onBack: {}, onShoot: {}).modelContainer(container), name: "yg-me-\(label)", size: size, dir: dir)
            }
            if only == "all" || only == "group" {
                for (palette, tag) in [(Palette.day, "day"), (Palette.night, "night")] {
                    try await shoot(groupTab(palette: palette, sections: []), name: "yg-group-\(tag)-\(label)", size: size, dir: dir, wait: 2.6)
                    if label == "se" {
                        try await shoot(groupTab(palette: palette, sections: []), name: "yg-group-\(tag)-\(label)-scrolled", size: size, dir: dir, wait: 2.6, scroll: 260)
                    }
                }
            }
        }
    }
}
