import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// v30 現像中の 画面:進み → チェキの 膜の 見え方
@MainActor
struct DevelopLookTests {
    private func near(_ a: Double, _ b: Double, _ e: Double = 0.0001) -> Bool { abs(a - b) < e }

    @Test func はじめはミルク色で見えない() {
        let l = DevelopLook.values(progress: 0)
        #expect(near(l.film, 0.97))
        #expect(near(l.blur, 16))
        #expect(near(l.saturation, 0.08))
        #expect(near(l.brightness, 1.55))
        #expect(near(l.tealTint, 0))
    }

    @Test func おわりでも膜は残る() {
        let l = DevelopLook.values(progress: 1)
        #expect(near(l.film, 0.47))
        #expect(near(l.blur, 5))
        #expect(near(l.saturation, 0.93))
        #expect(near(l.brightness, 1.10))
        #expect(near(l.tealTint, 0))
        #expect(l.film > 0.4)
        // はみ出しても 同じ
        #expect(DevelopLook.values(progress: 1.4) == l)
        #expect(DevelopLook.values(progress: -0.2) == DevelopLook.values(progress: 0))
    }

    @Test func 青緑は途中でいちばん強い() {
        let samples = stride(from: 0.0, through: 1.0, by: 0.01).map { DevelopLook.values(progress: $0).tealTint }
        let peak = samples.max() ?? 0
        let at = samples.firstIndex(of: peak) ?? 0
        #expect(near(peak, 0.6, 0.005))
        #expect(at > 5 && at < 95)
        #expect(samples.allSatisfy { $0 >= 0 && $0 <= 0.6 + 0.0001 })
    }

    @Test func 進むほど膜がうすくくっきり() {
        var prev = DevelopLook.values(progress: 0)
        for p in stride(from: 0.05, through: 1.0, by: 0.05) {
            let l = DevelopLook.values(progress: p)
            #expect(l.film < prev.film && l.blur < prev.blur && l.saturation > prev.saturation && l.brightness < prev.brightness)
            prev = l
        }
    }

    @Test func ひらくまでの表示() {
        #expect(DevelopViewerRules.opensIn(15 * 3600 + 9 * 60 + 30) == "15H 09M")
        #expect(DevelopViewerRules.opensIn(42 * 60) == "42M")
        #expect(DevelopViewerRules.ordinal(2) == "2ND")
    }

    // MARK: スナップショット(LATER_SNAPSHOT_ONLY=develop30)

    private static func image() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 600, height: 800)).image { ctx in
            let colors = [UIColor(red: 0.98, green: 0.62, blue: 0.35, alpha: 1).cgColor, UIColor(red: 0.2, green: 0.35, blue: 0.7, alpha: 1).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 600, y: 800), options: [])
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 180, y: 220, width: 240, height: 240))
            UIColor(red: 0.1, green: 0.5, blue: 0.3, alpha: 1).setFill()
            ctx.cgContext.fill(CGRect(x: 0, y: 600, width: 600, height: 200))
        }.jpegData(compressionQuality: 0.85)!
    }

    @Test func 現像中の画面() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"],
              ProcessInfo.processInfo.environment["LATER_SNAPSHOT_ONLY"] == "develop30" else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let container = try ModelContainer(for: Schema([LaterPhoto.self, LaterGroup.self, UserProfile.self, PhotoVote.self, BlockedUser.self, ExposureDay.self]),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let cal = Calendar.current
        let now = cal.date(bySettingHour: 23, minute: 51, second: 0, of: Date())!
        // 64% くらいの こま
        var shot = now.addingTimeInterval(-60)
        for m in stride(from: 1, through: 600, by: 1) {
            let d = now.addingTimeInterval(-Double(m) * 60)
            // 同じ 現像の 回(つぎの 9:00 が まだ さき)の こまだけ
            guard PhotoDevelop.developDate(takenAt: d) > now else { break }
            shot = d
            if DevelopViewerRules.density(takenAt: d, now: now) >= 0.64 { break }
        }
        let photo = LaterPhoto(imageData: Self.image(), captureDate: shot, unlockDate: shot)
        container.mainContext.insert(photo)
        let sizes: [(String, CGSize)] = [("se", CGSize(width: 375, height: 667)), ("max", CGSize(width: 440, height: 956))]
        for (label, size) in sizes {
            for (state, shots) in [("1shot", [shot]), ("0shot", [Date]())] {
                let view = HomeDevelopViewer(shots: shots, videoDurations: [:], used: shots.count, tones: DevelopProgress.defaultTones, now: now,
                                             photos: shots.isEmpty ? [] : [photo], onClose: {}, onShoot: {})
                    .modelContainer(container)
                let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
                let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
                window.frame = CGRect(origin: .zero, size: size)
                window.windowLevel = .alert + 1
                window.rootViewController = UIHostingController(rootView: view)
                window.makeKeyAndVisible()
                let waits: [(String, Double)] = shots.isEmpty ? [("end", 1.5)] : [("mid", 1.9), ("end", 5.0)]
                for (tag, wait) in waits {
                    try await Task.sleep(for: .seconds(wait))
                    let png = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
                    try png.pngData()?.write(to: dir.appendingPathComponent("develop30-\(label)-\(state)-\(tag).png"))
                }
                window.isHidden = true
            }
        }
    }
}
