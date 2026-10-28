import Foundation
import Testing
@testable import Later_再度

/// 1日3こまフィルム:枚数の上限・のこり・昨日の解禁の数(min(今日, 昨日) − ひらいた数)。
@MainActor
struct FilmRollTests {
    @Test func threeShotsPerDay() {
        #expect(FilmRoll.shotsPerDay == 3)
        #expect(FilmRoll.shotsRemaining(shotsToday: 0) == 3)
        #expect(FilmRoll.shotsRemaining(shotsToday: 2) == 1)
        #expect(FilmRoll.shotsRemaining(shotsToday: 3) == 0)
        #expect(FilmRoll.shotsRemaining(shotsToday: 4) == 0)
    }

    @Test func unlockCreditsIsTheSmallerDayCountMinusOpened() {
        // 昨日3・今日2 → 2
        #expect(FilmRoll.unlockCredits(shotsToday: 2, shotsYesterday: 3, opened: 0) == 2)
        // 昨日1・今日3 → 1(昨日の数が上限)
        #expect(FilmRoll.unlockCredits(shotsToday: 3, shotsYesterday: 1, opened: 0) == 1)
        // すでに1つひらいていれば、残りだけ
        #expect(FilmRoll.unlockCredits(shotsToday: 2, shotsYesterday: 3, opened: 1) == 1)
        // 0未満にはならない
        #expect(FilmRoll.unlockCredits(shotsToday: 0, shotsYesterday: 3, opened: 0) == 0)
        #expect(FilmRoll.unlockCredits(shotsToday: 2, shotsYesterday: 3, opened: 5) == 0)
    }

    @Test func sameShotCountedOnceAcrossGroupCopies() {
        let a = Date(timeIntervalSince1970: 1_000)
        let b = Date(timeIntervalSince1970: 2_000)
        #expect(FilmRoll.distinctShotCount([a, a, a, b]) == 2)
        #expect(FilmRoll.distinctShotCount([]) == 0)
    }

    @Test func canBeginStopsAtTheDailyLimit() {
        let tokyo: Calendar = {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
            return calendar
        }()
        let noon = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 12))!
        #expect(DailyExposureRules.canBeginExposure(at: noon, shotsToday: 2, calendar: tokyo))
        #expect(!DailyExposureRules.canBeginExposure(at: noon, shotsToday: 3, calendar: tokyo))
        let night = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 3))!
        #expect(!DailyExposureRules.canBeginExposure(at: night, shotsToday: 0, calendar: tokyo))
    }

    @Test func homeShowsMoreUntilThirdShot() {
        let tokyo: Calendar = {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
            return calendar
        }()
        let now = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 14))!
        let window = DailyWindow.latest(for: now, calendar: tokyo)
        let first = window.open.addingTimeInterval(3_600)
        let second = window.open.addingTimeInterval(7_200)
        let third = window.open.addingTimeInterval(10_800)
        let key = DailyWindow.key(for: now, calendar: tokyo)

        let one = HomeState.resolve(now: now, myCaptureDates: [first, first], hasDeposited: true, openedWindowKey: key, yesterdayDecision: .posted, calendar: tokyo)
        #expect(one == .more(shotAt: first, remaining: 2))

        let two = HomeState.resolve(now: now, myCaptureDates: [first, second], hasDeposited: true, openedWindowKey: key, yesterdayDecision: .posted, calendar: tokyo)
        #expect(two == .more(shotAt: second, remaining: 1))

        let three = HomeState.resolve(now: now, myCaptureDates: [first, second, third], hasDeposited: true, openedWindowKey: key, yesterdayDecision: .posted, calendar: tokyo)
        #expect(three == .opened(shotAt: third))
    }
}
