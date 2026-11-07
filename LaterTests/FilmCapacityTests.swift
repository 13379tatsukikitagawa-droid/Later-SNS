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
        #expect(FilmRoll.capacity(now: date(8, 8, 59), calendar: tokyo) == 15)   // 11/7 の 日(11/8 の 夜中も)も 15
        #expect(FilmRoll.capacity(now: date(7, 12), calendar: tokyo) == 15)
        #expect(FilmRoll.capacity(now: date(9, 9), calendar: tokyo) == 3)
        #expect(FilmRoll.capacity(now: date(6, 12), calendar: tokyo) == 3)
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

/// 2026-11-08 の 0:00〜9:00 も 撮れる(11/7 の 窓が 11/8 9:00 まで のびる)
struct OpenNightTests {
    private var tokyo: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        tokyo.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    @Test func 十一月八日の夜中だけ撮れる() {
        #expect(!DailyWindow.isNight(date(8, 0, 30), calendar: tokyo))
        #expect(!DailyWindow.isNight(date(8, 8, 59), calendar: tokyo))
        #expect(DailyExposureRules.window(for: date(8, 3), calendar: tokyo).open == date(7, 9))
        #expect(DailyExposureRules.window(for: date(8, 3), calendar: tokyo).close == date(8, 9))
        #expect(DailyExposureRules.window(for: date(7, 12), calendar: tokyo).close == date(8, 9))
        // 9:00 からは ふつう
        #expect(DailyExposureRules.window(for: date(8, 9), calendar: tokyo).open == date(8, 9))
        #expect(DailyExposureRules.window(for: date(8, 9), calendar: tokyo).close == date(9, 0))
        // ほかの日の 夜中は 撮れない
        #expect(DailyWindow.isNight(date(9, 3), calendar: tokyo))
        #expect(DailyWindow.isNight(date(7, 3), calendar: tokyo))
        // 夜中に 撮った 1枚は、11/8 9:00 に「昨日」として ひらく
        let yesterday = DailyWindow.yesterday(for: date(8, 10), calendar: tokyo)
        #expect(yesterday.open == date(7, 9) && yesterday.close == date(8, 9))
        #expect(FilmRoll.capacity(now: date(8, 3), calendar: tokyo) == 15)
    }
}
