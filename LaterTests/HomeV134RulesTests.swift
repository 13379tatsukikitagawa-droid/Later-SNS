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
