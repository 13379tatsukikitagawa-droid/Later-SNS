import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// v32 まんなかの 丸(LATER_SNAPSHOT_ONLY=orb のときだけ)
@MainActor
struct HomeOrbSnapshotTests {
    private static func photo() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300)).image { ctx in
            let colors = [UIColor(hue: 0.08, saturation: 0.6, brightness: 0.95, alpha: 1).cgColor, UIColor(hue: 0.6, saturation: 0.6, brightness: 0.5, alpha: 1).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 300, y: 300), options: [])
        }
    }

    @Test func 万能ボタン() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"],
              ProcessInfo.processInfo.environment["LATER_SNAPSHOT_ONLY"] == "orb" else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        typealias Input = HomeOrbRules.Input
        let cases: [(String, Input, String?)] = [
            ("shoot", Input(used: 0, remaining: 3, hasGroups: false), nil),
            ("yesterday", Input(used: 1, remaining: 2, hasGroups: true, openedYesterday: 1), nil),
            ("join", Input(hasInvite: true, used: 1, remaining: 2, hasGroups: true, openedYesterday: 1), "いつメン"),
            ("chat", Input(used: 2, remaining: 1, hasUnread: true, hasGroups: true, openedYesterday: 2), "部活のみんな"),
            ("done", Input(used: 3, remaining: 0, hasGroups: true, openedYesterday: 0), nil),
        ]
        let image = Self.photo()
        for (label, input, name) in cases {
            for night in [false, true] {
                for width in [375.0, 440.0] {
                    let view = VStack(spacing: 0) {
                        Color.clear.frame(height: 40)
                        HomeGlassOrb(input: input, dateText: "11.11", isActive: false, centerName: name,
                                     yesterdayImage: label == "yesterday" ? image : nil,
                                     onCenter: { _ in }, onSatellite: { _ in })
                        Text(verbatim: "\(label) · \(night ? "night" : "day") · \(Int(width))")
                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(.gray)
                            .padding(.top, 40)
                        Spacer(minLength: 0)
                    }
                    .frame(width: width, height: 680)
                    .background(night ? Color(hex: "0E0E12") : ChicColor.paper)
                    .environment(\.palette, night ? .night : .day)
                    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
                    let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
                    window.frame = CGRect(x: 0, y: 0, width: width, height: 680)
                    window.windowLevel = .alert + 1
                    window.rootViewController = UIHostingController(rootView: view)
                    window.makeKeyAndVisible()
                    try await Task.sleep(for: .seconds(1.5))
                    let shot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
                    try shot.pngData()?.write(to: dir.appendingPathComponent("orb-\(label)-\(night ? "night" : "day")-\(Int(width)).png"))
                    window.isHidden = true
                }
            }
        }
    }
}
