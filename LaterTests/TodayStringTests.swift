import Testing
import Foundation
@testable import Later_再度

/// v132 3章:Today の ひも(9:00 → あした 9:00 の 24時間)
@MainActor
struct TodayStringTests {
    private func at(_ h: Int, _ m: Int, day: Int = 22) -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 11; c.day = day; c.hour = h; c.minute = m
        return Calendar.current.date(from: c)!
    }

    @Test func dayPosition() {
        #expect(HVTodayString.dayPosition(at(9, 0)) == 0)
        #expect(HVTodayString.dayPosition(at(0, 0)) == 0.625)   // 24:00 の 消灯
        #expect(abs(HVTodayString.dayPosition(at(8, 50)) - (23 + 50.0 / 60) / 24) < 1e-9)
    }

    @Test func untilNine() {
        #expect(HVTodayString.untilNine(at(11, 40)) == "21:20")
        #expect(HVTodayString.untilNine(at(8, 50)) == "0:10")
        #expect(HVTodayString.untilNine(at(21, 30)) == "11:30")
    }

    @Test func develop() {
        #expect(HVTodayString.develop(takenAt: at(9, 0), now: at(9, 0)) == 0)
        #expect(HVTodayString.develop(takenAt: at(9, 0), now: at(21, 0)) == 0.5)
        #expect(HVTodayString.develop(takenAt: at(9, 0), now: at(9, 0, day: 23)) == 1)
    }

    @Test func stringShape() {
        // 枠の まんなかは ひもの 上(モック:y は 30〜58 の 間)
        for x in HVTodayString.slotX { let y = HVTodayString.y(atX: x); #expect(y > 8 && y < 58) }
    }
}
