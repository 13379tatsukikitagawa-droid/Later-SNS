import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// 見た目の確認用:今日のホーム(ChicHomeView + 下の月)を、昼 / 夜 × 0〜3こま × SE / Pro Max で撮る。
/// 一番下までスクロールした状態も。LATER_SNAPSHOT_DIR と LATER_SNAPSHOT_ONLY=night のときだけ
@MainActor
struct HomeNightSnapshotTests {
    private static let groups: [GroupSummary] = [
        GroupSummary(id: UUID(), name: "放課後クラブ", iconData: nil, auraIndex: 0, memberCount: 5, postedYesterday: 3),
        GroupSummary(id: UUID(), name: "2-B のなかま", iconData: nil, auraIndex: 2, memberCount: 4, postedYesterday: 1),
    ]

    private func screen(palette: Palette, used: Int, size: CGSize) -> some View {
        let mode: HomeMoon.Mode = used >= 3
            ? .dim(title: TodayFilmRules.moonTitle(shots: used), subtitle: TodayFilmRules.moonSubtitle(shots: used))
            : .tap(title: TodayFilmRules.moonTitle(shots: used), subtitle: TodayFilmRules.moonSubtitle(shots: used), tone: .warm)
        return ZStack {
            ChicHomeView(state: .dawn, now: Date(), light: .count(12), developContent: .first, developTexture: nil, shotsToday: used,
                         tones: [], groupSummaries: Self.groups, canCreateGroup: true, isCovered: false, avatarImage: nil, avatarSeed: nil,
                         showsAvatarBadge: false, onOpenProfile: {}, avatarName: "あ", onDevelopTap: {}, onSelectGroup: { _ in }, onCreateGroup: {})
            HomeMoon(mode: mode, screenSize: size, holdModel: HoldGaugeModel(), haptics: ExposureHaptics(), textOpacity: 1,
                     isInteractive: false, onTap: {}, onHoldComplete: {}, chic: true, restful: used >= 3 && !palette.isNight)
                .position(MoonLayout.center(in: size))
        }
        .frame(width: size.width, height: size.height)
        .environment(\.palette, palette)
        .environment(\.colorScheme, palette.isNight ? .dark : .light)
    }

    private static func findScroll(in view: UIView) -> UIScrollView? {
        if let s = view as? UIScrollView, s.contentSize.height > s.bounds.height { return s }
        for sub in view.subviews { if let s = findScroll(in: sub) { return s } }
        return nil
    }

    @Test func 昼と夜() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"],
              ProcessInfo.processInfo.environment["LATER_SNAPSHOT_ONLY"] == "night" else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let saved = FilmCounter.shared.used
        defer { FilmCounter.shared.debugReplace(used: saved) }
        for (label, size) in [("se", CGSize(width: 375, height: 667)), ("promax", CGSize(width: 440, height: 956))] {
            for (palette, tag) in [(Palette.day, "day"), (Palette.night, "night")] {
                for used in 0...3 {
                    FilmCounter.shared.debugReplace(used: used)
                    for bottom in [false, true] {
                        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
                        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
                        window.frame = CGRect(origin: .zero, size: size)
                        window.windowLevel = .alert + 1
                        window.rootViewController = UIHostingController(rootView: screen(palette: palette, used: used, size: size))
                        window.makeKeyAndVisible()
                        try await Task.sleep(for: .seconds(1.6))
                        if bottom, let view = window.rootViewController?.view, let scroll = Self.findScroll(in: view) {
                            scroll.setContentOffset(CGPoint(x: 0, y: scroll.contentSize.height - scroll.bounds.height), animated: false)
                            try await Task.sleep(for: .seconds(1.4))
                        }
                        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                        }
                        try image.pngData()?.write(to: dir.appendingPathComponent("home-\(tag)-\(used)\(bottom ? "-bottom" : "")-\(label).png"))
                        window.isHidden = true
                    }
                }
            }
        }
    }
}
