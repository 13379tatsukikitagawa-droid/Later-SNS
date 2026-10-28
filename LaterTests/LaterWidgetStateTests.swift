import Foundation
import Testing
@testable import Later_再度

/// ウィジェットの状態(時刻だけで決まる derive)
struct LaterWidgetStateTests {
    static let calendar = Calendar.current
    static let base = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_790_000_000))
    static func at(_ day: Int, _ h: Int, _ m: Int = 0) -> Date {
        calendar.date(byAdding: .minute, value: day * 1440 + h * 60 + m, to: base)!
    }

    func snapshot(day: Int, shotAt: Date? = nil, hasYesterday: Bool = false, opened: Bool = false) -> LaterWidgetSnapshot {
        LaterWidgetSnapshot(lastShotAt: shotAt, hasYesterday: hasYesterday, openedYesterday: opened,
                            history: [true, false, true, true, false, true],
                            dayKey: LaterWidgetDay.key(for: Self.at(day, 12)))
    }

    @Test func 四つの状態() {
        let shot = Self.at(0, 18, 11)
        #expect(LaterWidgetState.derive(snapshot(day: 0), now: Self.at(0, 15)).phase == .U)
        #expect(LaterWidgetState.derive(snapshot(day: 0, shotAt: shot, hasYesterday: true), now: Self.at(0, 19)).phase == .R)
        #expect(LaterWidgetState.derive(snapshot(day: 0, shotAt: shot, hasYesterday: true, opened: true), now: Self.at(0, 19)).phase == .D)
        #expect(LaterWidgetState.derive(snapshot(day: 0, shotAt: shot, hasYesterday: false), now: Self.at(0, 19)).phase == .D)
        // 24:00 を過ぎて未撮影
        #expect(LaterWidgetState.derive(snapshot(day: 0), now: Self.at(1, 0, 30)).phase == .M)
    }

    @Test func 日付またぎ() {
        let snap = snapshot(day: 0)
        // 23:59 → U、0:00 → M、9:00 → 新しい今日の U
        #expect(LaterWidgetState.derive(snap, now: Self.at(0, 23, 59)).phase == .U)
        #expect(LaterWidgetState.derive(snap, now: Self.at(1, 0, 0)).phase == .M)
        #expect(LaterWidgetState.derive(snap, now: Self.at(1, 8, 59)).phase == .M)
        let next = LaterWidgetState.derive(snap, now: Self.at(1, 9, 0))
        #expect(next.phase == .U && !next.hasYesterday)
        // 撮った日の翌 9:00:前の1枚が「昨日」になり、7日の点が1つずれる
        let shot = Self.at(0, 18, 11)
        let after = LaterWidgetState.derive(snapshot(day: 0, shotAt: shot), now: Self.at(1, 9, 30))
        #expect(after.phase == .U && after.hasYesterday)
        #expect(after.week == [false, true, true, false, true, true, false])
        // 撮影後の夜は、現像中のまま(9:00 で現像 100%)
        let night = LaterWidgetState.derive(snapshot(day: 0, shotAt: shot, opened: true), now: Self.at(1, 3))
        #expect(night.phase == .D && night.developProgress > 0.5 && night.developProgress < 1)
    }

    @Test func 現像の進みと月() {
        let shot = Self.at(0, 9)
        let state = LaterWidgetState.derive(snapshot(day: 0, shotAt: shot), now: Self.at(0, 21))
        #expect(state.developPercent == 50)
        let u = LaterWidgetState.derive(snapshot(day: 0), now: Self.at(0, 16, 30))
        #expect(abs(u.dayProgress - 0.5) < 0.001)
    }

    @Test func 値が空の初回でも_撮る前() throws {
        let defaults = try #require(UserDefaults(suiteName: "LaterWidgetStateTests"))
        defaults.removePersistentDomain(forName: "LaterWidgetStateTests")
        let empty = LaterWidgetSnapshot.load(defaults: defaults)
        #expect(empty == .empty)
        let state = LaterWidgetState.derive(empty, now: Self.at(0, 12))
        #expect(state.phase == .U && state.week.count == 7)
        // 保存して読みもどせる
        let snap = snapshot(day: 0, shotAt: Self.at(0, 10))
        snap.save(defaults: defaults)
        #expect(LaterWidgetSnapshot.load(defaults: defaults) == snap)
    }

    @Test func タップ先() {
        #expect(LaterWidgetShared.deepLink(.U).absoluteString == "later://widget/U")
        #expect(LaterWidgetShared.deepLink(.R).absoluteString == "later://widget/R")
    }
}
