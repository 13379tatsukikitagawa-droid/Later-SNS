import Testing
import Foundation
@testable import Later_再度

struct ProfileArchiveRulesTests {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Tokyo")!; return c }
    private func at(_ d: Int, _ h: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h))! }

    @Test func todayCellIsFirstAndShowsNoPhoto() {
        let cs = ProfileArchiveRules.cells([at(22, 10), at(22, 12), at(21, 18)], now: at(22, 13), cal: cal)
        #expect(cs[0].kind == .today && cs[0].count == 2 && cs[0].coverIndex == nil)
        #expect(cs[1].kind == .opened && cs[1].day == cal.startOfDay(for: at(21, 0)))
    }

    @Test func yesterdayIsLockedBeforeNine() {
        let before = ProfileArchiveRules.cells([at(21, 18)], now: at(22, 8), cal: cal)
        #expect(before[1].kind == .locked && before[1].count == 1)
        let after = ProfileArchiveRules.cells([at(21, 18)], now: at(22, 9), cal: cal)
        #expect(after[1].kind == .opened && after[1].coverIndex == 0)
        #expect(ProfileArchiveRules.openedDays(before) == 0)
        #expect(ProfileArchiveRules.openedDays(after) == 1)
    }

    @Test func coverIsTheEarliestOpenedPhotoOfTheDay() {
        let cs = ProfileArchiveRules.cells([at(20, 18), at(20, 10), at(20, 14)], now: at(22, 12), cal: cal)
        #expect(cs[1].count == 3 && cs[1].coverIndex == 1)
    }

    @Test func emptyHasOnlyTodayCell() {
        let cs = ProfileArchiveRules.cells([], now: at(22, 12), cal: cal)
        #expect(cs.count == 1 && cs[0].kind == .today && cs[0].count == 0)
    }

    @Test func streakCountsBackFromTodayOrYesterday() {
        #expect(ProfileArchiveRules.streak([at(22, 10), at(21, 10), at(20, 10), at(18, 10)], now: at(22, 12), cal: cal) == 3)
        #expect(ProfileArchiveRules.streak([at(21, 10), at(20, 10)], now: at(22, 12), cal: cal) == 2)
        #expect(ProfileArchiveRules.streak([at(19, 10)], now: at(22, 12), cal: cal) == 0)
    }

    @Test func sinceLabelIsJapanese() {
        #expect(ProfileArchiveRules.sinceLabel(at(1, 10), now: at(22, 0), cal: cal) == "2026年11月 から")
    }
}
