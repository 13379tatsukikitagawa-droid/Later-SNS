import Foundation
import Testing
@testable import Later_再度

/// Mondo の窓:9:00 区切り・日本時間に固定(サーバの UTC の日付と同じ)
struct MondoWindowTests {
    static func jst(_ s: String) -> Date {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return f.date(from: s)!
    }

    @Test func 九時区切り() {
        #expect(MondoWindow.dayKey(for: Self.jst("2026-10-15T09:00:00+09:00")) == "2026-10-15")
        #expect(MondoWindow.dayKey(for: Self.jst("2026-10-15T23:59:00+09:00")) == "2026-10-15")
        // 0:00〜8:59 は前の日の窓
        #expect(MondoWindow.dayKey(for: Self.jst("2026-10-16T08:59:00+09:00")) == "2026-10-15")
        #expect(MondoWindow.dayKey(for: Self.jst("2026-10-16T09:00:00+09:00")) == "2026-10-16")
    }

    @Test func 昨日() {
        let defaults = UserDefaults.standard
        let before = defaults.bool(forKey: MondoWindow.debugTodayAsYesterdayKey)
        defer { defaults.set(before, forKey: MondoWindow.debugTodayAsYesterdayKey) }
        defaults.set(false, forKey: MondoWindow.debugTodayAsYesterdayKey)
        #expect(MondoWindow.yesterdayKey(now: Self.jst("2026-10-16T10:00:00+09:00")) == "2026-10-15")
        #expect(MondoWindow.yesterdayKey(now: Self.jst("2026-10-17T00:30:00+09:00")) == "2026-10-15")
        // サーバの「今日」は UTC の日付。日本時間の 9:00 区切りと同じになる
        let now = Self.jst("2026-10-17T00:30:00+09:00")
        let utcToday = ISO8601DateFormatter().string(from: now).prefix(10)
        #expect(MondoWindow.dayKey(for: now) == utcToday)
        // デバッグ:今日の窓を、昨日として読む
        defaults.set(true, forKey: MondoWindow.debugTodayAsYesterdayKey)
        #expect(MondoWindow.yesterdayKey(now: now) == "2026-10-16")
    }

    @Test func 海外の端末でも同じ窓() {
        // ニューヨークの 10/16 21:00 = 日本の 10/17 10:00 → 窓は 2026-10-17
        let f = ISO8601DateFormatter()
        let ny = f.date(from: "2026-10-17T01:00:00Z")!
        #expect(MondoWindow.dayKey(for: ny) == "2026-10-17")
    }
}
