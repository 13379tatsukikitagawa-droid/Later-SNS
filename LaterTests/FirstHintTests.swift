import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// はじめての 合図:1回に 1つ・表の 順・一生に 1回・落ち着いてから・出さない 間
@MainActor
struct FirstHintTests {
    private func fresh() -> (HintCenter, UserDefaults) {
        let name = "first-hint-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (HintCenter(defaults: defaults), defaults)
    }

    @Test func 文言は表のとおり() {
        #expect(FirstHintKey.allCases == [.first, .unlock, .tag, .shoot, .orb, .keep, .grp])
        #expect(FirstHintKey.keep.text == "長押しで、1年 のこす")
        #expect(FirstHintKey.first.text == "ここから、1枚目")
        #expect(FirstHintKey.unlock.text == "撮ると、きのうが 1枚 ひらく")
        #expect(FirstHintKey.tag.text == "ひとこと タグ。なくても OK")
        #expect(FirstHintKey.shoot.text == "ながおしで 撮る")
        #expect(FirstHintKey.orb.text == "タップで、みんなの 今日")
        #expect(FirstHintKey.grp.text == "ともだちと、見せあう")
        #expect(FirstHintKey.shoot.dwell == 1.3)
        #expect(FirstHintKey.orb.dwell == 0.8)
        #expect(FirstHintKey.first.spotlight && FirstHintKey.unlock.spotlight && !FirstHintKey.orb.spotlight)
    }

    @Test func 落ち着くまでは出さない() {
        let (center, _) = fresh()
        let t0 = Date()
        center.update(.orb, ready: true, now: t0)
        center.evaluate(now: t0.addingTimeInterval(0.5))
        #expect(center.active == nil)
        center.evaluate(now: t0.addingTimeInterval(0.81))
        #expect(center.active == .orb)
    }

    @Test func 一回に一つ_表の順() {
        let (center, _) = fresh()
        let t0 = Date()
        center.update(.grp, ready: true, now: t0)
        center.update(.orb, ready: true, now: t0)
        center.evaluate(now: t0.addingTimeInterval(1))
        #expect(center.active == .orb)
        // 出ている 間は ほかを 出さない
        center.evaluate(now: t0.addingTimeInterval(2))
        #expect(center.active == .orb)
    }

    @Test func さわると消えて_一生に一回() {
        let (center, defaults) = fresh()
        let t0 = Date()
        center.update(.tag, ready: true, now: t0)
        center.evaluate(now: t0.addingTimeInterval(1))
        #expect(center.active == .tag)
        #expect(FirstHintStore.isSeen(.tag, defaults: defaults))
        center.touched(.tag)
        #expect(center.active == nil)
        // もう 出ない
        center.update(.tag, ready: true, now: t0.addingTimeInterval(5))
        center.evaluate(now: t0.addingTimeInterval(10))
        #expect(center.active == nil)
        // 設定の「もう一度」で もどる
        FirstHintStore.resetAll(defaults: defaults)
        #expect(!FirstHintStore.isSeen(.tag, defaults: defaults))
    }

    @Test func 画面を移ると消える() {
        let (center, _) = fresh()
        let t0 = Date()
        center.update(.shoot, ready: true, now: t0)
        center.evaluate(now: t0.addingTimeInterval(1.4))
        #expect(center.active == .shoot)
        center.update(.shoot, ready: false)
        #expect(center.active == nil)
    }

    @Test func シートの間は出さず_出ていたら消す() {
        let (center, _) = fresh()
        let t0 = Date()
        center.setBlocked("sheet", true)
        center.update(.orb, ready: true, now: t0)
        center.evaluate(now: t0.addingTimeInterval(1))
        #expect(center.active == nil)
        center.setBlocked("sheet", false)
        center.evaluate(now: t0.addingTimeInterval(2))
        #expect(center.active == .orb)
        center.setBlocked("toast", true)
        #expect(center.active == nil)
    }
}

/// 見た目(LATER_SNAPSHOT_ONLY=hint のときだけ)
@MainActor
struct FirstHintSnapshotTests {
    @Test func ふきだし() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"],
              ProcessInfo.processInfo.environment["LATER_SNAPSHOT_ONLY"] == "hint" else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (label, dark) in [("light", false), ("dark", true)] {
            HintCenter.shared.resetForTesting()
            FirstHintStore.resetAll()
            let view = ZStack {
                (dark ? Color(hex: "050506") : Color(hex: "FBF8F3")).ignoresSafeArea()
                VStack(spacing: 120) {
                    RoundedRectangle(cornerRadius: 22).fill(Color(hex: "1A1A20")).frame(width: 170, height: 80)
                        .firstHint(.grp, eligible: !dark, edge: .top, shape: .rounded(22), onDark: dark)
                    ZStack {
                        Circle().stroke(.white.opacity(0.28), lineWidth: 2).frame(width: 98, height: 98)
                        Circle().fill(.white).frame(width: 76, height: 76)
                        if HintCenter.shared.active == .shoot { ShutterHintDemo() }
                    }
                    .frame(width: 104, height: 104)
                    .firstHint(.shoot, eligible: dark, edge: .top, shape: .circle, onDark: true, gap: 22)
                }
            }
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
            window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
            window.windowLevel = .alert + 1
            window.rootViewController = UIHostingController(rootView: view)
            window.makeKeyAndVisible()
            try await Task.sleep(for: .seconds(2.6))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
            try image.pngData()?.write(to: dir.appendingPathComponent("hint-\(label).png"))
            window.isHidden = true
        }
        HintCenter.shared.resetForTesting()
        FirstHintStore.resetAll()
    }
}
