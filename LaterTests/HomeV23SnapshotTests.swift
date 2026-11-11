import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// v23 の Home の 区画(LATER_SNAPSHOT_ONLY=v23 のときだけ)
@MainActor
struct HomeV23SnapshotTests {
    private static func image(_ hue: CGFloat) -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { ctx in
            let colors = [UIColor(hue: hue, saturation: 0.5, brightness: 0.95, alpha: 1).cgColor, UIColor(hue: hue + 0.15, saturation: 0.7, brightness: 0.6, alpha: 1).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 300, y: 400), options: [])
        }.jpegData(compressionQuality: 0.8)!
    }

    @Test func 区画() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"],
              ProcessInfo.processInfo.environment["LATER_SNAPSHOT_ONLY"] == "v23" else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let now = Date()
        let cal = Calendar.current
        var photos: [LaterPhoto] = []
        for ago in 0..<7 {
            for j in 0..<(ago == 0 ? 1 : (ago % 3) + 1) {
                let base = cal.date(byAdding: .day, value: -ago, to: cal.startOfDay(for: now))!
                let date = cal.date(bySettingHour: 10 + j * 3, minute: 12, second: 0, of: base)!
                let p = LaterPhoto(imageData: Self.image(CGFloat(ago * 3 + j) / 22), captureDate: date, unlockDate: date)
                p.tags = ["放課後"]
                photos.append(p)
            }
        }
        let days = MERules.days(photos: photos, now: now)
        // 昨日は すべて ひらいた ものとして 見る
        var yesterday = days.first { $0.ago == 1 }!
        let opened = yesterday.shots.map { MEShot(id: $0.id, takenAt: $0.takenAt, photoID: $0.photoID) }
        yesterday = MEDay(key: yesterday.key, date: yesterday.date, ago: 1, shots: opened, tags: [], developed: true)
        for (device, size) in [("se", CGSize(width: 375, height: 667)), ("promax", CGSize(width: 440, height: 956))] {
            for night in [false, true] {
                let ink = V17Ink(night: night)
                let view = ScrollView {
                    VStack(spacing: 60) {
                        V23YesterdaySection(day: yesterday, shots: opened, photos: photos, ink: ink, hintEligible: false)
                        V23WeekFilmSection(days: days, photos: photos, ink: ink)
                        V23WorldSection(ink: ink)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 40)
                }
                .background(night ? Color(hex: "0B0B0E") : Color(hex: "FBF8F3"))
                let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
                let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
                window.frame = CGRect(origin: .zero, size: CGSize(width: size.width, height: 1500))
                window.windowLevel = .alert + 1
                window.rootViewController = UIHostingController(rootView: view)
                window.makeKeyAndVisible()
                try await Task.sleep(for: .seconds(1.5))
                let shot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
                try shot.pngData()?.write(to: dir.appendingPathComponent("v23-\(device)-\(night ? "night" : "day").png"))
                window.isHidden = true
            }
        }
    }
}
