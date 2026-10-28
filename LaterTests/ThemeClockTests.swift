import Testing
import Foundation
@testable import Later_再度

@MainActor
struct ThemeClockTests {
    private var tokyo: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    private func date(_ h: Int, _ m: Int) -> Date {
        tokyo.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: h, minute: m))!
    }

    private func makeClock(_ d: Date) -> ThemeClock {
        let defaults = UserDefaults(suiteName: "ThemeClockTests-\(UUID().uuidString)")!
        return ThemeClock(now: d, defaults: defaults)
    }

    @Test func isNightBoundaries() {
        #expect(ThemeClock.isNight(date(0, 0), calendar: tokyo))
        #expect(ThemeClock.isNight(date(8, 59), calendar: tokyo))
        #expect(!ThemeClock.isNight(date(9, 0), calendar: tokyo))
        #expect(!ThemeClock.isNight(date(23, 59), calendar: tokyo))
    }

    @Test func refreshAppliesWhenUnlocked() {
        let clock = makeClock(date(12, 0))
        #expect(clock.mode == .day)
        clock.refresh(now: date(1, 0), calendar: tokyo)
        #expect(clock.mode == .night)
    }

    @Test func lockedRefreshKeepsModeUntilUnlock() {
        let clock = makeClock(date(12, 0))
        clock.isLocked = true
        clock.refresh(now: date(1, 0), calendar: tokyo)
        #expect(clock.mode == .day)
        clock.isLocked = false
        #expect(clock.mode == .night)
    }

    @Test func lockedRefreshBackToSameModeDropsPending() {
        let clock = makeClock(date(12, 0))
        clock.isLocked = true
        clock.refresh(now: date(1, 0), calendar: tokyo)
        clock.refresh(now: date(13, 0), calendar: tokyo)
        clock.isLocked = false
        #expect(clock.mode == .day)
    }

    @Test func nextChangeIsNearestMidnightOrNine() {
        let s1 = ThemeClock.secondsUntilNextChange(from: date(8, 0), calendar: tokyo)
        #expect(abs(s1 - 3600.5) < 0.01)
        let s2 = ThemeClock.secondsUntilNextChange(from: date(23, 0), calendar: tokyo)
        #expect(abs(s2 - 3600.5) < 0.01)
    }

    @Test func paletteHexConstants() {
        #expect(Palette.day.bgHex.rgb == 0xFFFFFF)
        #expect(Palette.night.bgHex.rgb == 0x09090B)
        #expect(Palette.day.paperHex == Palette.night.paperHex)
        #expect(Palette.night.fillHex.alpha == 0.09)
        #expect(Palette.for(.night) == Palette.night)
        #expect(Palette.for(.day) == Palette.day)
    }
}
