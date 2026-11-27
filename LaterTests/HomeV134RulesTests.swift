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

    @Test func zeroFriendsHome() {
        #expect(HomeV134Rules.hasNoFriends(friendCount: 0))
        #expect(!HomeV134Rules.hasNoFriends(friendCount: 1))
    }
    @Test func lensShrinksOnShortScreens() {
        #expect(HomeV134Rules.lensDiameter(screenHeight: 874) == 168)     // 大きい 画面
        #expect(HomeV134Rules.lensDiameter(screenHeight: 844) == 168)
        #expect(HomeV134Rules.lensDiameter(screenHeight: 667) < 168)      // iPhone SE
        #expect(HomeV134Rules.lensDiameter(screenHeight: 667) >= 100)
        #expect(HomeV134Rules.lensDiameter(screenHeight: 480) == 100)     // 下限
    }
}

struct LensChargeSpecTests {
    @Test func eightTicksWithShrinkingGaps() {
        let t = LensChargeSpec.tickTimes()
        #expect(t.count == 8)
        #expect(abs(LensChargeSpec.gap(0) - 0.22) < 1e-9)
        #expect(abs(LensChargeSpec.gap(6) - 0.10) < 1e-9)
        for i in 1..<6 { #expect(LensChargeSpec.gap(i) < LensChargeSpec.gap(i - 1)) }
        #expect(t.last! < LensChargeSpec.duration)          // 1.4 秒の 前に 全部 鳴りおわる
    }
    @Test func tickStrengthRisesAsSpec() {
        #expect(LensChargeSpec.intensity(0) == 0.25)
        #expect(abs(LensChargeSpec.intensity(7) - 0.85) < 1e-6)
        #expect(LensChargeSpec.sharpness(0) == 0.4)
        #expect(abs(LensChargeSpec.sharpness(7) - 0.8) < 1e-6)
        for i in 1..<8 { #expect(LensChargeSpec.intensity(i) > LensChargeSpec.intensity(i - 1)) }
    }
    @Test func lensDoneIsItsOwnMomentNotOpened() {
        // 9:00 に ひらく(opened)と 同じ 意味に ならないよう、別の case(コンパイルで 保証)
        let a: LTHaptics.Moment = .lensDone, b: LTHaptics.Moment = .opened
        #expect("\(a)" != "\(b)")
    }
}

struct InviteCardRulesV136Tests {
    @Test func lineURLEncodesText() {
        let u = InviteCardRulesV136.lineURL(text: "Lattag で つながろう https://x/y?a=1")
        #expect(u?.scheme == "line")
        #expect(u?.absoluteString.contains(" ") == false)
    }
    @Test func displayLinkHidesScheme() {
        #expect(InviteCardRulesV136.displayLink(URL(string: "https://lattag.app/u/abc")!) == "lattag.app/u/abc")
    }
    @Test func emptyNameFallsBack() {
        #expect(InviteCardRulesV136.shownName("  ") == "ともだち")
        #expect(InviteCardRulesV136.shownName("たつき") == "たつき")
    }
}
