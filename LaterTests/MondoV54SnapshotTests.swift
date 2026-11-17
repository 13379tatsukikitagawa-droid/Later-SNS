import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// v54:Mondo タブの「空っぽ」バグの再発確認用。phase: .ready に 中身を 入れて、見出し〜EVERYONE まで
/// ちゃんと 出るかを 画像で 確かめる。LATER_SNAPSHOT_DIR が設定されている時だけ書き出す。
@MainActor
struct MondoV54SnapshotTests {
    private static func entry(_ id: String, tags: [String]) -> MondoEntry {
        MondoEntry(id: id, mondoID: id, name: "さ", place: MondoPlace(countryCode: "JP", countryName: "日本", region: "東京都"),
                   tags: tags, dayKey: "2026-11-11", toneHex: "7CD48E", isMine: id == "mine")
    }

    private static var summary: MondoDaySummary {
        MondoDaySummary(
            dayKey: "2026-11-11",
            entries: (0..<10).map { entry("e\($0)", tags: $0 % 3 == 0 ? ["夕焼け"] : ["朝ごはん"]) },
            lightCount: 128, countryCount: 12,
            topTags: [("夕焼け", 40), ("朝ごはん", 22), ("猫", 15), ("海", 9), ("雨", 5)]
        )
    }

    @Test func mondoタブ() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"] else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for locked in [false, true] {
            let view = HomeV5MondoPage(
                phase: .ready(Self.summary), dayKey: "2026-11-11", isActive: true, topInset: 0,
                onTick: {}, onSettings: {}, onRetry: {}, onOpenTag: { _, _, _ in }, onOpenAll: { _, _ in },
                locked: locked
            )
            .environment(\.scenePhase, .active)

            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
            window.frame = CGRect(x: 0, y: 0, width: 390, height: 1400)
            window.backgroundColor = .black
            window.windowLevel = .alert + 1
            window.rootViewController = UIHostingController(rootView: view)
            window.rootViewController?.view.backgroundColor = .black
            window.makeKeyAndVisible()
            try await Task.sleep(for: .seconds(2.0))
            let shot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
            try shot.pngData()?.write(to: dir.appendingPathComponent("mondo_\(locked ? "locked" : "open").png"))
            window.isHidden = true
        }
    }
}
