import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// v22:Home の ことば・初回・現像ビューの ルール
@MainActor
struct HomeV22Tests {
    @Test func 見出しの丸は状態ごと() {
        #expect(HomeV22Rules.headline(used: 0, initial: true).circled == "撮って")
        #expect(HomeV22Rules.headline(used: 0, initial: false).first == "おはよう。")
        #expect(HomeV22Rules.headline(used: 1, initial: true).circled == "2")
        #expect(HomeV22Rules.headline(used: 2, initial: false).circled == "1")
        #expect(HomeV22Rules.headline(used: 3, initial: true).circled == nil)
    }

    @Test func 現像の濃さは撮った直後0で9時に1() {
        let cal = Calendar.current
        let day = cal.startOfDay(for: Date())
        let taken = cal.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
        #expect(DevelopViewerRules.density(takenAt: taken, now: taken) == 0)
        let nine = PhotoDevelop.developDate(takenAt: taken)
        #expect(DevelopViewerRules.density(takenAt: taken, now: nine) == 1)
        let mid = taken.addingTimeInterval(nine.timeIntervalSince(taken) / 2)
        let d = DevelopViewerRules.density(takenAt: taken, now: mid)
        #expect(d > 0.5 && d < 0.7)
        #expect(DevelopViewerRules.playDuration(0) == 2.6)
        #expect(DevelopViewerRules.playDuration(1) == 5.0)
    }

    @Test func 初回ははじめての9時まで() {
        let defaults = UserDefaults(suiteName: "HomeV22Tests.\(UUID().uuidString)")!
        let cal = Calendar.current
        let day = cal.startOfDay(for: Date())
        let opened = cal.date(bySettingHour: 15, minute: 0, second: 0, of: day)!
        #expect(HomeFirstDay.isInitial(now: opened, defaults: defaults))
        let nextMorning = cal.date(byAdding: .hour, value: 18, to: opened)!.addingTimeInterval(60)
        #expect(!HomeFirstDay.isInitial(now: nextMorning, defaults: defaults))
    }

    @Test func 現像ビューのスナップショット() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"] else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let now = Date()
        let shots = [now.addingTimeInterval(-3 * 3600), now.addingTimeInterval(-600)]
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        window.rootViewController = UIHostingController(rootView: HomeDevelopViewer(shots: shots, videoDurations: [:], used: 2, tones: DevelopProgress.defaultTones, now: now, onClose: {}, onShoot: {}))
        window.makeKeyAndVisible()
        for (i, wait) in [0.5, 6.0].enumerated() {
            try await Task.sleep(for: .seconds(wait))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            try image.pngData()?.write(to: dir.appendingPathComponent("develop-\(i).png"))
        }
        window.isHidden = true
    }
}
