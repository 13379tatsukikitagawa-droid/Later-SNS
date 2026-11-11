import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// 【v22 A】撮影画面から 戻る 時間を はかる(LATER_SNAPSHOT_ONLY=back のときだけ。結果は LATER_SNAPSHOT_DIR/back-timing.txt)
@MainActor
struct BackTimingTests {
    /// ホームの 代わり(月が ちぢむ・ホームが うすく 出る。TodayView と 同じ 値)
    private struct HomeHarness: View {
        @State private var shoot = true
        @State private var homeOpacity = 0.0
        @State private var moonScale = 6.0
        var body: some View {
            ZStack {
                Color(white: 0.95).opacity(homeOpacity)
                Circle().fill(.yellow).frame(width: 90, height: 90).scaleEffect(moonScale)
                if shoot {
                    CaptureFlow(onCancel: {
                        var t = Transaction(); t.disablesAnimations = true
                        withTransaction(t) { shoot = false }
                        let m = HomeReturnMotion.moon
                        withAnimation(.timingCurve(0.3, 0, 0.2, 1, duration: m.scale)) { moonScale = 1 }
                        withAnimation(.easeOut(duration: m.homeDuration).delay(m.homeDelay)) { homeOpacity = 1 }
                        HomeReturnMotion.markStarted()
                    }, startsAtCapture: true)
                }
            }
        }
    }

    private func host<V: View>(_ view: V) -> UIWindow {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.windowLevel = .alert + 1
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        return window
    }

    private func run(_ path: BackTiming.Path, post name: Notification.Name) async throws -> String {
        let window = host(HomeHarness())
        try await Task.sleep(for: .seconds(1.5))   // 撮影画面が おちつくまで
        NotificationCenter.default.post(name: name, object: nil)
        try await Task.sleep(for: .seconds(1.5))
        window.isHidden = true
        let snap = BackTiming.snapshot()
        #expect(snap.path == path)
        return snap.marks.map { "  \($0.stage): \(String(format: "%.1f", $0.ms))ms" }.joined(separator: "\n")
    }

    @Test func 戻るの時間() async throws {
        guard let dir = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"],
              ProcessInfo.processInfo.environment["LATER_SNAPSHOT_ONLY"] == "back" else { return }
        var lines: [String] = []
        for round in 1...3 {
            lines.append("[\(round)回目] タグのカプセル→タグ画面")
            lines.append(try await run(.chipToTags, post: BackTiming.benchChip))
            lines.append("[\(round)回目] 「<」→ホーム")
            lines.append(try await run(.backToHome, post: BackTiming.benchBack))
        }
        let text = lines.joined(separator: "\n")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try text.write(toFile: dir + "/back-timing.txt", atomically: true, encoding: .utf8)
    }
}

/// 【v22 A】戻る 動きの 長さ(0.3秒以内)
struct BackMotionRuleTests {
    @Test func ホームへの動きは0_3秒以内() {
        #expect(HomeReturnMotion.moon.total <= 0.3 + 1e-9)
    }

    @Test @MainActor func タグ画面への切りかえは0_3秒以内() {
        #expect(CaptureFlow.backFade <= 0.3)
    }
}
