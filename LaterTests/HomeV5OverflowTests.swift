import SwiftUI
import UIKit
import Testing
@testable import Later_再度

/// 「画面の右がはみ出す」の確認。実際の UIKit の階層に載せて、縦スクロールの中身の幅が画面の幅を超えないことを見る。
/// 写真(fill)が土台の大きさを広げて、親の幅を押し広げていた不具合の再発を防ぐ。
@MainActor
struct HomeV5OverflowTests {
    private func scrollViews(in view: UIView) -> [UIScrollView] {
        var found: [UIScrollView] = []
        if let scroll = view as? UIScrollView { found.append(scroll) }
        for sub in view.subviews { found += scrollViews(in: sub) }
        return found
    }

    /// 横に長い写真を、MondoImageCache に入れておく(ネットワークに行かない)
    private func summary(dayKey: String) -> MondoDaySummary {
        let tags = ["散歩", "朝の光", "帰り道", "猫", "コーヒー", "夕焼け"]
        let entries = (0..<8).map { i in
            MondoEntry(id: "overflow-\(i)", mondoID: "m\(i)", name: "テスト\(i)", place: nil,
                       tags: [tags[i % 6], tags[(i + 1) % 6]], dayKey: dayKey, toneHex: "3A2A20", isMine: false)
        }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1600, height: 600)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1600, height: 600))
        }
        for entry in entries {
            MondoImageCache.shared.store(image.pngData()!, image: image, recordName: entry.id, kind: "thumb", dayKey: dayKey)
        }
        return MondoDaySummary(dayKey: dayKey, entries: entries, lightCount: 1280, countryCount: 12,
                               topTags: tags.enumerated().map { (tag: $0.element, count: 20 - $0.offset * 2) })
    }

    private func host<V: View>(_ view: V, width: CGFloat, height: CGFloat, typeSize: DynamicTypeSize = .large) throws -> (UIWindow, UIView) {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: width, height: height)
        let controller = UIHostingController(rootView: view.environment(\.dynamicTypeSize, typeSize).preferredColorScheme(.dark))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        return (window, controller.view)
    }

    @Test(arguments: HomeV5LayoutSnapshotTests.devices)
    func mondoContentNeverWiderThanTheScreen(_ device: HomeV5LayoutSnapshotTests.Device) async throws {
        let dayKey = "2026-10-26"
        let data = summary(dayKey: dayKey)
        for typeSize in [DynamicTypeSize.large, .xxxLarge, .accessibility3] {
            let page = ZStack(alignment: .top) {
                V5Backdrop(isAnimating: false)
                HomeV5MondoPage(phase: .ready(data), dayKey: dayKey, isActive: false, topInset: 59, onTick: {}, onSettings: {},
                                onRetry: {}, onOpenTag: { _, _, _ in }, onOpenAll: { _, _ in })
                LaterHeader(home: .yesterday, avatarName: "さ", showsBadge: false)
                    .padding(.top, 59)
            }
            let (window, root) = try host(page, width: device.size.width, height: device.size.height, typeSize: typeSize)
            try await Task.sleep(for: .milliseconds(400))
            root.layoutIfNeeded()
            let scrolls = scrollViews(in: root)
            #expect(!scrolls.isEmpty)
            for scroll in scrolls {
                #expect(scroll.contentSize.width <= device.size.width + 0.5, "\(device.name) \(typeSize): contentSize.width=\(scroll.contentSize.width)")
            }
            if typeSize == .large, let dir = HomeSnapshotTests.outputDirectory {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                try #require(image.pngData()).write(to: dir.appendingPathComponent("v5_mondo_real_\(device.name).png"))
            }
            window.isHidden = true
        }
    }

    @Test(arguments: HomeV5LayoutSnapshotTests.devices)
    func groupContentNeverWiderThanTheScreen(_ device: HomeV5LayoutSnapshotTests.Device) async throws {
        let page = ZStack(alignment: .top) {
            V5Backdrop(isAnimating: false)
            HomeV5GroupPage(sections: [], isActive: false, haptics: ExposureHaptics(), shotEvent: nil, windowKey: "overflow",
                            topInset: 59, canCreate: true, onOpenRoom: { _ in }, onOpenTile: { _, _, _ in },
                            onCycleLocation: { _ in }, onAdd: {})
        }
        let (window, root) = try host(page, width: device.size.width, height: device.size.height)
        try await Task.sleep(for: .milliseconds(300))
        root.layoutIfNeeded()
        // 横に動くスクロールは中身が画面より広くてよい。見るのは、スクロールの領域が画面からはみ出していないこと
        for scroll in scrollViews(in: root) {
            #expect(scroll.convert(scroll.bounds, to: nil).width <= device.size.width + 0.5)
        }
        window.isHidden = true
    }
}
