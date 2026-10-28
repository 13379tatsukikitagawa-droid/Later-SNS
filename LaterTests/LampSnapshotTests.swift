import SwiftUI
import UIKit
import Testing
@testable import Later_再度

/// 灯・発表のカード・カレンダーの見た目の確認(LATER_SNAPSHOT_DIR があるときは画像も書き出す)と、
/// 「画面の右がはみ出さない」の確認。
@MainActor
struct LampSnapshotTests {
    private static let devices = HomeV5LayoutSnapshotTests.devices

    private func scrollViews(in view: UIView) -> [UIScrollView] {
        var found: [UIScrollView] = []
        if let scroll = view as? UIScrollView { found.append(scroll) }
        for sub in view.subviews { found += scrollViews(in: sub) }
        return found
    }

    private func host<V: View>(_ view: V, width: CGFloat, height: CGFloat) throws -> (UIWindow, UIView) {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: width, height: height)
        let controller = UIHostingController(rootView: view.preferredColorScheme(.dark))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        return (window, controller.view)
    }

    private func write(_ window: UIWindow, name: String) throws {
        guard let dir = HomeSnapshotTests.outputDirectory else { return }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try #require(image.pngData()).write(to: dir.appendingPathComponent("\(name).png"))
    }

    /// 色のグラデーションの写真(JPEG)
    private func photoData(_ hue: CGFloat, size: CGSize = CGSize(width: 900, height: 1200)) -> Data {
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let colors = [UIColor(hue: hue, saturation: 0.7, brightness: 0.95, alpha: 1).cgColor,
                          UIColor(hue: fmod(hue + 0.12, 1), saturation: 0.8, brightness: 0.35, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
        }
        return image.jpegData(compressionQuality: 0.8)!
    }

    private func worldPick(day: String, hue: CGFloat, tags: [String] = ["夕焼け", "帰り道"]) -> AnnouncedPick {
        AnnouncedPick(day: day, scope: LampScope.world, photoRecordName: "w-\(day)", tags: tags, source: .local(photoData(hue)))
    }

    private func groupPick(day: String, scope: String, hue: CGFloat) -> AnnouncedPick {
        AnnouncedPick(day: day, scope: scope, photoRecordName: "g-\(day)-\(scope)", tags: ["朝ごはん"], source: .local(photoData(hue)),
                      authorSeed: UUID(), authorImage: nil)
    }

    // MARK: 灯のアイコンとボタン

    @Test(arguments: devices)
    func lampControlsRender(_ device: HomeV5LayoutSnapshotTests.Device) throws {
        let view = ZStack {
            LinearGradient(colors: [Color(hex: "C97B4A"), Color(hex: "2A1A12")], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 28) {
                HStack(spacing: 30) {
                    LampButton(isLit: false, burst: 0, action: {})
                    LampButton(isLit: true, burst: 0, action: {})
                }
                HStack(spacing: 24) {
                    LampStatusDot(isLit: false)
                    LampStatusDot(isLit: true)
                    LampBadge(diameter: 42)
                    LampBadge(diameter: 32)
                    LampTileMark()
                }
                HStack(spacing: 24) {
                    LampIcon(size: 48, isLit: false)
                    LampIcon(size: 48, isLit: true)
                }
            }
        }
        let (window, root) = try host(view, width: device.size.width, height: device.size.height)
        root.layoutIfNeeded()
        try write(window, name: "v6_lamp_controls_\(device.name)")
        window.isHidden = true
    }

    // MARK: ヘッダー(ロゴ・ピル・カレンダー・アバターがはみ出さない)

    @Test(arguments: devices)
    func headerWithCalendarFits(_ device: HomeV5LayoutSnapshotTests.Device) async throws {
        for (type, dot) in [(DynamicTypeSize.large, true), (.accessibility3, false)] {
            let view = ZStack(alignment: .top) {
                V5Backdrop(isAnimating: false)
                LaterHeader(home: .yesterday, avatarName: "さ", showsBadge: true)
                    .padding(.top, 59)
            }
            .environment(\.dynamicTypeSize, type)
            let (window, root) = try host(view, width: device.size.width, height: 160)
            try await Task.sleep(for: .milliseconds(200))
            root.layoutIfNeeded()
            // 右端のアバター(44pt + 余白20pt)が画面の中に収まっている
            let avatar = findAccessibility(in: root, label: "あなたのページ、新しい変化があります")
            if let avatar {
                let frame = avatar.convert(avatar.bounds, to: root)
                #expect(frame.maxX <= device.size.width + 0.5, "\(device.name) \(type)")
            }
            if type == .large { try write(window, name: "v6_header_\(device.name)") }
            window.isHidden = true
        }
    }

    private func findAccessibility(in view: UIView, label: String) -> UIView? {
        if view.accessibilityLabel == label { return view }
        for sub in view.subviews { if let found = findAccessibility(in: sub, label: label) { return found } }
        return nil
    }

    // MARK: MONDO・GROUP

    @Test(arguments: devices)
    func mondoAnnouncedCard(_ device: HomeV5LayoutSnapshotTests.Device) async throws {
        let pick = worldPick(day: "2026-10-26", hue: 0.07)
        let page = ZStack(alignment: .top) {
            V5Backdrop(isAnimating: false)
            HomeV5MondoPage(phase: .notReady, dayKey: "2026-10-26", isActive: false, topInset: 59, onTick: {}, onSettings: {}, onRetry: {},
                            onOpenTag: { _, _, _ in }, onOpenAll: { _, _ in }, announced: pick, onOpenAnnounced: { _ in })
            V5HeaderScrim()
            LaterHeader(home: .yesterday, avatarName: "さ", showsBadge: false)
                .padding(.top, 59)
        }
        let (window, root) = try host(page, width: device.size.width, height: device.size.height)
        try await Task.sleep(for: .milliseconds(500))
        root.layoutIfNeeded()
        for scroll in scrollViews(in: root) {
            #expect(scroll.contentSize.width <= device.size.width + 0.5, "\(device.name): \(scroll.contentSize.width)")
        }
        try write(window, name: "v6_mondo_card_\(device.name)")
        window.isHidden = true
    }

    @Test(arguments: devices)
    func groupAnnouncedTile(_ device: HomeV5LayoutSnapshotTests.Device) async throws {
        let gid = UUID()
        let tiles = (0..<3).map { i in
            V5GroupTile(id: "t\(i)", authorSeed: UUID(), authorImage: nil, tags: ["散歩"], tiny: nil, imageData: photoData(0.3 + CGFloat(i) * 0.1),
                        capturedAt: Date(), isMine: i == 0, photoRecordName: "photo\(i)")
        }
        let section = GroupSectionModel(id: gid, name: "朝活ぐるーぷ", iconData: nil, auraIndex: 0, memberCount: 4, shotToday: 2,
                                        tiles: tiles, unlockedIDs: ["t0", "t1"], locationMode: .off)
        let pick = groupPick(day: "2026-10-26", scope: "g", hue: 0.55)
        let page = ZStack(alignment: .top) {
            V5Backdrop(isAnimating: false)
            HomeV5GroupPage(sections: [section], isActive: false, haptics: ExposureHaptics(), shotEvent: nil, windowKey: "lamp-snap",
                            topInset: 59, canCreate: true, onOpenRoom: { _ in }, onOpenTile: { _, _, _ in }, onCycleLocation: { _ in }, onAdd: {},
                            announced: [gid: pick], litTileIDs: ["t1"], onOpenAnnounced: { _, _ in })
            V5HeaderScrim()
            LaterHeader(home: .yesterday, avatarName: "さ", showsBadge: false)
                .padding(.top, 59)
        }
        let (window, root) = try host(page, width: device.size.width, height: device.size.height)
        try await Task.sleep(for: .milliseconds(500))
        root.layoutIfNeeded()
        for scroll in scrollViews(in: root) where scroll.contentSize.height > scroll.contentSize.width * 0 {
            // 縦のスクロールは画面の幅を超えない(タイルの横スクロールは別)
            if scroll.contentSize.width > device.size.width + 0.5 {
                #expect(scroll.bounds.width < device.size.width, "\(device.name)")
            }
        }
        try write(window, name: "v6_group_tile_\(device.name)")
        window.isHidden = true
    }

    // MARK: カレンダー

    @Test(arguments: devices)
    func calendarRendersAndFits(_ device: HomeV5LayoutSnapshotTests.Device) async throws {
        let now = Date()
        let cal = Calendar.current
        func key(_ ago: Int) -> String { LampRules.dayKey(for: cal.date(byAdding: .day, value: -ago, to: now)!) }
        var picks: [AnnouncedPick] = []
        var shot = Set<String>()
        for ago in [2, 3, 4, 6, 9, 10, 15, 22, 40, 90, 150, 220, 285, 310, 340, 360] {
            picks.append(worldPick(day: key(ago), hue: CGFloat(ago % 12) / 12))
            shot.insert(key(ago))
        }
        picks.append(groupPick(day: key(3), scope: "a", hue: 0.1))
        picks.append(groupPick(day: key(3), scope: "b", hue: 0.2))
        picks.append(groupPick(day: key(10), scope: "a", hue: 0.3))
        let view = LampCalendarView(now: now, picks: picks, shotDays: shot, haptics: ExposureHaptics(), onClose: {}, onOpenDay: { _ in })
        let (window, root) = try host(view, width: device.size.width, height: device.size.height)
        try await Task.sleep(for: .milliseconds(700))
        root.layoutIfNeeded()
        for scroll in scrollViews(in: root) {
            #expect(scroll.contentSize.width <= device.size.width + 0.5, "\(device.name): \(scroll.contentSize.width)")
        }
        try write(window, name: "v6_calendar_\(device.name)")
        window.isHidden = true
    }

    @Test func emptyCalendarFitsToo() async throws {
        let view = LampCalendarView(now: Date(), picks: [], shotDays: [], haptics: ExposureHaptics(), onClose: {}, onOpenDay: { _ in })
        let (window, root) = try host(view, width: 375, height: 667)
        try await Task.sleep(for: .milliseconds(400))
        for scroll in scrollViews(in: root) {
            #expect(scroll.contentSize.width <= 375.5)
        }
        window.isHidden = true
    }

    // MARK: 写真を見る画面

    @Test(arguments: devices)
    func viewerWithLamp(_ device: HomeV5LayoutSnapshotTests.Device) async throws {
        let defaults = UserDefaults(suiteName: "lamp-snap-\(UUID().uuidString)")!
        let board = LampBoard(defaults: defaults, userIdProvider: { "snap" })
        let now = Date()
        let yesterday = LampRules.dayKey(for: Calendar.current.date(byAdding: .day, value: -1, to: now)!)
        let pages = (0..<3).map { i in
            ViewerPage(id: "p\(i)", source: .local(photoData(0.05 + CGFloat(i) * 0.2)), tags: ["散歩", "朝"], capturedAt: now, authorSeed: UUID(),
                       showsAuthor: true, label: "朝活ぐるーぷ", counter: "0\(i + 1) / 03",
                       lamp: LampTarget(day: yesterday, scope: "g", photoRecordName: "photo\(i)"))
        }
        for lit in [false, true] {
            if lit { _ = board.toggle(day: yesterday, scope: "g", photoRecordName: "photo0", now: now) }
            let view = VerticalPhotoViewer(pages: pages, startIndex: 0, haptics: ExposureHaptics(), lampBoard: board, now: now, onClose: {})
            let (window, root) = try host(view, width: device.size.width, height: device.size.height)
            try await Task.sleep(for: .milliseconds(600))
            root.layoutIfNeeded()
            try write(window, name: "v6_viewer_\(lit ? "lit" : "unlit")_\(device.name)")
            window.isHidden = true
        }
    }
}
