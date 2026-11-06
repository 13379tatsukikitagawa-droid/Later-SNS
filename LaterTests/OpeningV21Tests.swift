import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// v21 E:オープニング
@MainActor
struct OpeningV21Tests {
    @Test func 時刻表() {
        let full = OpeningTimeline(variant: .full)
        #expect(full.flash == 1.0 && full.chekiIn == 1.2 && full.develop == 1.85 && full.letters == 2.25 && full.morph == 2.67)
        #expect(abs(full.end - 3.7) < 0.001)
        let short = OpeningTimeline(variant: .short)
        #expect(short.end < 2 && short.morph < full.morph)
        #expect(OpeningVariant.fade.duration == 0.4)
    }

    @Test func はじめてはフル_2回目からは短く() {
        let d = UserDefaults.standard
        let savedMode = d.string(forKey: "opening.mode"), savedSeen = d.object(forKey: "opening.fullSeen")
        defer {
            d.set(savedMode, forKey: "opening.mode")
            d.set(savedSeen, forKey: "opening.fullSeen")
        }
        d.removeObject(forKey: "opening.fullSeen")
        OpeningSettings.mode = .on
        #expect(OpeningSettings.variant(reduceMotion: false) == .full)
        #expect(OpeningSettings.variant(reduceMotion: false) == .short)
        #expect(OpeningSettings.variant(reduceMotion: true) == .fade)
        OpeningSettings.mode = .off
        #expect(OpeningSettings.variant(reduceMotion: false) == nil)
        OpeningSettings.mode = .short
        #expect(OpeningSettings.variant(reduceMotion: false) == .short)
    }

    @Test func 見た目() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"] else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let size = CGSize(width: 402, height: 874)
        for t in [0.6, 1.5, 2.1, 2.5, 3.0, 3.35] {
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
            window.frame = CGRect(origin: .zero, size: size)
            let start = Date().addingTimeInterval(-t + 0.25)
            window.rootViewController = UIHostingController(rootView: OpeningV21View(variant: .full, start: start, onFinish: {}))
            window.makeKeyAndVisible()
            try await Task.sleep(for: .seconds(0.25))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
            try image.pngData()?.write(to: dir.appendingPathComponent(String(format: "opening-%.2f.png", t)))
            window.isHidden = true
        }
    }
}
