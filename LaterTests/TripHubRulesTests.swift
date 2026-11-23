import Testing
import Foundation
@testable import Later_再度

struct TripHubRulesTests {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Tokyo")!; c.firstWeekday = 2; return c }
    private func d(_ m: Int, _ day: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: m, day: day))! }

    @Test func 日にちがあれば_いま_これから_おわった() {
        let now = d(11, 20)
        #expect(TripHubRules.phase(start: d(11, 19), end: d(11, 21), created: d(11, 1), now: now, cal: cal).phase == .live)
        #expect(TripHubRules.phase(start: d(11, 24), end: d(11, 26), created: d(11, 1), now: now, cal: cal).phase == .upcoming)
        #expect(TripHubRules.phase(start: d(10, 27), end: d(10, 29), created: d(10, 1), now: now, cal: cal).phase == .ended)
        // 初日と 最終日は「いま」
        #expect(TripHubRules.phase(start: d(11, 20), end: d(11, 20), created: d(11, 1), now: now, cal: cal).phase == .live)
    }

    @Test func 日にちがない古いTripは作って7日までいま_それより古いとおわった() {
        let now = d(11, 20)
        let a = TripHubRules.phase(start: nil, end: nil, created: d(11, 14), now: now, cal: cal)
        #expect(a.phase == .live && a.needsDates)
        let b = TripHubRules.phase(start: nil, end: nil, created: d(11, 12), now: now, cal: cal)
        #expect(b.phase == .ended && !b.needsDates)
    }

    @Test func 週は月曜はじまり() {
        #expect(TripHubRules.weekStart(of: d(11, 20), cal: cal) == d(11, 16))   // 金 → 月
        #expect(TripHubRules.weekStart(of: d(11, 22), cal: cal) == d(11, 16))   // 日 → その 週の 月
        #expect(TripHubRules.weekStart(of: d(11, 23), cal: cal) == d(11, 23))   // 月
    }

    private func item(_ s: Int, _ e: Int, color: Int = 0) -> TripHubItem {
        TripHubItem(id: UUID(), name: "t", members: 1, cover: nil, start: d(11, s), end: d(11, e), created: d(11, 1), color: color)
    }

    @Test func 線は同じ日がかさなると段がふえて3段まで() {
        let w = d(11, 16)
        let one = TripHubRules.segments([item(19, 21)], weekStart: w, cal: cal)
        #expect(one.segments.count == 1 && one.segments[0].lane == 0 && one.segments[0].first == 3 && one.segments[0].last == 5)
        let four = TripHubRules.segments([item(19, 21), item(19, 20), item(20, 22), item(20, 20)], weekStart: w, cal: cal)
        #expect(four.segments.count == 3)
        #expect(Set(four.segments.map(\.lane)) == [0, 1, 2])
        #expect(four.overflow.values.reduce(0, +) >= 1)
    }

    @Test func 週をまたぐ線ははしを切る() {
        let s = TripHubRules.segments([item(14, 18)], weekStart: d(11, 16), cal: cal).segments[0]
        #expect(s.first == 0 && s.last == 2 && !s.startsHere && s.endsHere)
        #expect(TripHubRules.segments([item(30, 30)], weekStart: d(11, 16), cal: cal).segments.isEmpty)
    }

    @Test func 日のTripと数え方() {
        let t = item(19, 21)
        #expect(TripHubRules.trips(on: d(11, 20), in: [t], cal: cal).count == 1)
        #expect(TripHubRules.trips(on: d(11, 23), in: [t], cal: cal).isEmpty)
        #expect(TripHubRules.dayNumber(start: d(11, 19), now: d(11, 20), cal: cal) == 2)
        #expect(TripHubRules.totalDays(start: d(11, 19), end: d(11, 21), cal: cal) == 3)
        #expect(TripHubRules.daysUntil(d(11, 24), now: d(11, 20), cal: cal) == 4)
        let c = TripHubRules.counts([t, item(24, 26), item(1, 2)], now: d(11, 20), cal: cal)
        #expect(c.live == 1 && c.upcoming == 1 && c.ended == 1)
    }
}

@MainActor
struct TripOpenedSummaryTests {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Tokyo")!; return c }
    private func at(_ d: Int, _ h: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h))! }

    @Test func todaysPhotosAreLockedAndNewestOpenedDayIsShown() {
        let dates = [at(20, 10), at(20, 18), at(21, 8), at(22, 12)]   // 22 日 12:00 = きょう(鍵)
        let s = TripHubRules.openedSummary(dates, tripStart: at(20, 0), now: at(22, 13), cal: cal)
        #expect(s.hasLocked)
        #expect(s.day == 2)            // 21 日の 8:00 の 写真は 21 日 9:00 に ひらいた
        #expect(s.count == 1)
        #expect(s.pick == [2])
        #expect(!s.pick.contains(3))   // きょうの 写真は 出さない
    }

    @Test func nothingOpenedYet() {
        let s = TripHubRules.openedSummary([at(22, 10)], tripStart: at(22, 0), now: at(22, 11), cal: cal)
        #expect(s.day == 0 && s.pick.isEmpty && s.hasLocked)
    }

    @Test func capsAtFourNewestOfTheDay() {
        let dates = (0..<6).map { at(20, 10 + $0) }
        let s = TripHubRules.openedSummary(dates, tripStart: at(20, 0), now: at(21, 12), cal: cal)
        #expect(s.count == 6 && s.pick == [5, 4, 3, 2])
    }
}
