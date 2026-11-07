import Foundation
import Testing
@testable import Later_再度

// v22 A:のこり(FilmCounter)。日の区切りは LaterDay.key(9:00 開始、0:00〜9:00 は前の日の続き)。
@MainActor
struct FilmCounterTests {
    private var tokyo: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        tokyo.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func store() -> UserDefaults {
        let name = "film-counter-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// 時計を差しかえられるカウンター
    private final class Clock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private func counter(_ defaults: UserDefaults, _ clock: Clock) -> FilmCounter {
        FilmCounter(defaults: defaults, clock: { clock.now }, calendar: tokyo, capacity: { _, _ in 3 })
    }

    @Test func threeConsumesLeaveNothing() {
        let c = counter(store(), Clock(date(7, 12)))
        #expect(c.remaining == 3)
        for _ in 0..<3 { #expect(c.consume(captureID: UUID(), source: "screen")) }
        #expect(c.used == 3)
        #expect(c.remaining == 0)
    }

    @Test func fourthIsRefused() {
        let c = counter(store(), Clock(date(7, 12)))
        for _ in 0..<3 { c.consume(captureID: UUID(), source: "volume") }
        #expect(!c.consume(captureID: UUID(), source: "screen"))
        #expect(c.used == 3)
        #expect(c.usedIDs.count == 3)
    }

    @Test func sameIDCountsOnce() {
        let c = counter(store(), Clock(date(7, 12)))
        let id = UUID()
        c.consume(captureID: id, source: "screen")
        c.consume(captureID: id, source: "screen")
        #expect(c.used == 1)
        #expect(c.remaining == 2)
    }

    @Test func rollsOverOnNextDay() {
        let clock = Clock(date(7, 12))
        let c = counter(store(), clock)
        for _ in 0..<3 { c.consume(captureID: UUID(), source: "screen") }
        clock.now = date(8, 10)
        #expect(c.remaining == 3)   // 読むだけでも 3
        #expect(c.consume(captureID: UUID(), source: "screen"))
        #expect(c.used == 1)
        #expect(c.dayKey == "2026-11-08")
    }

    @Test func resetsAtNineAm() {
        let clock = Clock(date(7, 8, 59))
        let c = counter(store(), clock)
        c.consume(captureID: UUID(), source: "screen")   // 8:59 は 6日の続き
        #expect(c.dayKey == "2026-11-06")
        clock.now = date(7, 9, 0)
        c.refresh()
        #expect(c.dayKey == "2026-11-07")
        #expect(c.used == 0)
        #expect(c.remaining == 3)
    }

    @Test func sameDayUntilMidnightAndRestIsPreviousWindow() {
        let clock = Clock(date(7, 9, 0))
        let c = counter(store(), clock)
        c.consume(captureID: UUID(), source: "screen")
        for (h, m) in [(23, 59), (0, 0), (0, 30), (8, 58)] {
            clock.now = h == 23 ? date(7, h, m) : date(8, h, m)
            c.refresh()
            #expect(c.dayKey == "2026-11-07", "\(h):\(m)")
            #expect(c.used == 1, "\(h):\(m)")
        }
    }

    @Test func dayKeyMatchesDailyWindow() {
        for (d, h, m) in [(7, 8, 59), (7, 9, 0), (7, 23, 59), (8, 0, 0), (8, 0, 30), (8, 9, 0)] {
            let t = date(d, h, m)
            #expect(LaterDay.key(for: t, calendar: tokyo) == DailyWindow.key(for: t, calendar: tokyo))
            #expect(LaterDay.key(for: t, calendar: tokyo) == LaterWidgetDay.key(for: t, calendar: tokyo))
        }
    }

    @Test func persistsAcrossInstances() {
        let defaults = store()
        let clock = Clock(date(7, 12))
        let a = counter(defaults, clock)
        a.consume(captureID: UUID(), source: "screen")
        a.consume(captureID: UUID(), source: "movie")
        let b = counter(defaults, clock)
        #expect(b.used == 2)
        #expect(b.usedIDs == a.usedIDs)
        // 次の日に作りなおすと、0
        clock.now = date(8, 12)
        #expect(counter(defaults, clock).used == 0)
    }

    @Test func reconcileNeverDecreases() {
        let c = counter(store(), Clock(date(7, 12)))
        c.consume(captureID: UUID(), source: "screen")
        c.consume(captureID: UUID(), source: "screen")
        let before = c.usedIDs
        c.reconcile(serverIDs: [])
        #expect(c.usedIDs == before)
        c.reconcile(serverIDs: ["a"])   // 1つ(2つ持っているので、減らない・増えない)
        #expect(c.used >= 2)
        #expect(Array(c.usedIDs.prefix(2)) == before)
    }

    @Test func reconcileIncreasesInOrder() {
        let c = counter(store(), Clock(date(7, 12)))
        c.consume(captureID: UUID(), source: "screen")
        let first = c.usedIDs[0]
        c.reconcile(serverIDs: ["x", "y"])
        #expect(c.used == 3)
        #expect(c.usedIDs == [first, "x", "y"])
        c.reconcile(serverIDs: ["z"])   // 上限をこえない
        #expect(c.used == 3)
    }

    @Test func reconcileFromSavedKeysDoesNotDoubleCount() {
        let c = counter(store(), Clock(date(7, 12)))
        c.consume(captureID: UUID(), source: "screen")   // まだ保存中
        c.reconcile(savedKeys: ["me|1"])                   // 保存が終わった(同じ1枚)
        #expect(c.used == 1)
        c.reconcile(savedKeys: ["me|1", "me|2"])           // ほかの端末の1枚
        #expect(c.used == 2)
        c.reconcile(savedKeys: [])
        #expect(c.used == 2)
    }
}
