import Foundation
import Testing
@testable import Later_再度

struct LightsPanelTests {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    private func date(_ h: Int, _ m: Int) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: h, minute: m))!
    }

    @Test func dayProgress() {
        #expect(LightsPanelLogic.progress(now: date(9, 0), calendar: cal) == 0)
        #expect(abs(LightsPanelLogic.progress(now: date(16, 30), calendar: cal) - 0.5) < 0.001)
        #expect(LightsPanelLogic.progress(now: date(23, 59), calendar: cal) > 0.99)
    }

    @Test func nightProgress() {
        #expect(LightsPanelLogic.progress(now: date(0, 0), calendar: cal) == 0)
        #expect(abs(LightsPanelLogic.progress(now: date(4, 30), calendar: cal) - 0.5) < 0.001)
        #expect(LightsPanelLogic.progress(now: date(8, 59), calendar: cal) > 0.99)
    }

    @Test func captions() {
        #expect(LightsPanelLogic.caption(taken: 1, isNight: false).title == "のこり 2こま")
        #expect(LightsPanelLogic.caption(taken: 1, isNight: false).detail == "きょうは 1こま 撮りました")
        #expect(LightsPanelLogic.caption(taken: 3, isNight: false).title == "今日は、ここまで")
        #expect(LightsPanelLogic.caption(taken: 3, isNight: false).detail == "3こま、撮りました")
        #expect(LightsPanelLogic.caption(taken: 2, isNight: true).title == "9:00に、3こま届く")
        #expect(LightsPanelLogic.caption(taken: 2, isNight: true).detail == "きょうは 2こま 撮りました")
    }
}
