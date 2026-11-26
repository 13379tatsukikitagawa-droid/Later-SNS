import Testing
import Foundation
@testable import Later_再度

struct HomeV134RulesTests {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Tokyo")!; return c }
    private func date(_ h: Int, _ m: Int, day: Int = 26) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: h, minute: m))! }

    @Test func filmStatusByState() {
        let a = HomeV134Rules.filmStatus(shots: 0, now: date(12, 30), calendar: cal)
        #expect(a.title == "今日のフィルム" && a.sub == "24:00の消灯まで、あと3枚" && !a.lensLocked)
        #expect(a.target == date(0, 0, day: 27))
        let b = HomeV134Rules.filmStatus(shots: 1, now: date(12, 30), calendar: cal)
        #expect(b.title == "今日のフィルム 1/3" && b.sub == "あしたの9:00にひらく" && !b.lensLocked)
        #expect(b.target == date(9, 0, day: 27))
        #expect(HomeV134Rules.filmStatus(shots: 3, now: date(12, 30), calendar: cal).lensLocked)
        let n = HomeV134Rules.filmStatus(shots: 0, now: date(8, 46), calendar: cal)
        #expect(n.title == "消灯中" && n.night && n.lensLocked && n.target == date(9, 0))
    }

    @Test func yesterdayCardTexts() {
        let l = HomeV134Rules.yesterdayCard(opened: 0, total: 3, shots: 0, night: false)
        #expect(l.line1 == "今日を1枚撮ると、1枚ひらく" && l.button == .shoot)
        let p = HomeV134Rules.yesterdayCard(opened: 1, total: 3, shots: 1, night: false)
        #expect(p.line1 == "1枚ひらいた" && p.line2 == "あと2枚は、撮るたびにひらく")
        #expect(HomeV134Rules.yesterdayCard(opened: 3, total: 3, shots: 1, night: false).line1 == "きのうは、ぜんぶひらいた")
        #expect(HomeV134Rules.yesterdayCard(opened: 0, total: 3, shots: 3, night: false).button == .tomorrow)
        let n = HomeV134Rules.yesterdayCard(opened: 0, total: 3, shots: 0, night: true)
        #expect(n.button == .from9 && n.line1 == "9:00に、あかりがついたら撮れる")
    }

    @Test func waitedAndLabels() {
        #expect(HomeV134Rules.waitedLabel(captured: date(16, 42, day: 25), calendar: cal) == "16h18m")
        #expect(HomeV134Rules.waitedLabel(captured: date(22, 14, day: 25), calendar: cal) == "10h46m")
        #expect(HomeV134Rules.dayLabel(date(10, 0, day: 25)) == "11.25 WED")
        #expect(HomeV134Rules.stamp(date(10, 0, day: 25)) == "'26 11 25")
    }
}

struct GoodMorningLiveRulesTests {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Tokyo")!; return c }
    private func date(_ h: Int, _ m: Int, day: Int = 26) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: h, minute: m))! }

    @Test func goodMorningOncePerDayAfterNine() {
        #expect(HomeV134Rules.shouldShowGoodMorning(now: date(9, 5), lastShownDay: nil, hasYesterday: true, calendar: cal))
        #expect(!HomeV134Rules.shouldShowGoodMorning(now: date(8, 59), lastShownDay: nil, hasYesterday: true, calendar: cal))
        #expect(!HomeV134Rules.shouldShowGoodMorning(now: date(12, 0), lastShownDay: "20261126", hasYesterday: true, calendar: cal))
        #expect(HomeV134Rules.shouldShowGoodMorning(now: date(9, 0, day: 27), lastShownDay: "20261126", hasYesterday: true, calendar: cal))
        #expect(!HomeV134Rules.shouldShowGoodMorning(now: date(10, 0), lastShownDay: nil, hasYesterday: false, calendar: cal))
        #expect(HomeV134Rules.dayKey(date(9, 0), calendar: cal) == "20261126")
    }

    @Test func liveActivityWaitsFromFirstShotUntilNine() {
        let nine = date(9, 0, day: 27)
        #expect(!LattagLiveClock.isWaiting(shots: 0, now: date(12, 30), opensAt: nine))
        #expect(LattagLiveClock.isWaiting(shots: 1, now: date(12, 30), opensAt: nine))
        #expect(LattagLiveClock.isWaiting(shots: 3, now: date(23, 59), opensAt: nine))
        #expect(!LattagLiveClock.isWaiting(shots: 3, now: nine, opensAt: nine))
    }
}

struct WaitedRulesTests {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Tokyo")!; return c }
    private func date(_ h: Int, _ m: Int, day: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: h, minute: m))! }

    @Test func waitedBigLabel() {
        #expect(HomeV134Rules.waitedBig(captured: date(17, 12, day: 25), calendar: cal) == "15H 48M")
        #expect(HomeV134Rules.waitedBig(captured: date(22, 14, day: 25), calendar: cal) == "10H 46M")
    }

    @Test func monthlyTotalsSumPerDay() {
        let caps = [date(22, 0, day: 25), date(18, 0, day: 25), date(12, 0, day: 3), date(10, 0, day: 30).addingTimeInterval(86400 * 5)]   // 最後は 12月
        let t = HomeV134Rules.waitedTotals(captures: caps, month: date(12, 0, day: 10), calendar: cal)
        #expect(t.perDay.count == 30)
        #expect(Int(t.perDay[24]) == 11 + 15)
        #expect(Int(t.perDay[2]) == 21)
        #expect(t.hours == 11 + 15 + 21)
    }
}
