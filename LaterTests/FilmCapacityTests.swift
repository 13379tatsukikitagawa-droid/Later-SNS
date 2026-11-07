import Foundation
import Testing
@testable import Later_再度

/// 2026-11-08 だけ 撮れる数が 15(その日の 9:00 〜 翌 0:00)。ほかの日は 3
struct FilmCapacityTests {
    private var tokyo: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        tokyo.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    @Test func 十一月八日だけ十五枚() {
        #expect(FilmRoll.capacity(now: date(8, 9), calendar: tokyo) == 15)
        #expect(FilmRoll.capacity(now: date(8, 23, 59), calendar: tokyo) == 15)
        #expect(FilmRoll.capacity(now: date(8, 8, 59), calendar: tokyo) == 3)   // 9:00 前は 11/7 の続き
        #expect(FilmRoll.capacity(now: date(9, 9), calendar: tokyo) == 3)
        #expect(FilmRoll.capacity(now: date(7, 12), calendar: tokyo) == 3)
    }

    @MainActor @Test func のこりも十五から数える() {
        let name = "film-capacity-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let now = date(8, 12)
        let counter = FilmCounter(defaults: defaults, clock: { now }, calendar: tokyo)
        #expect(counter.remaining == 15)
        for _ in 0..<15 { #expect(counter.consume(captureID: UUID(), source: "screen")) }
        #expect(counter.remaining == 0)
        #expect(!counter.consume(captureID: UUID(), source: "screen"))
    }
}
