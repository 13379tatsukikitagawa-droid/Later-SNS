import Testing
import Foundation
@testable import Later_再度

struct LattagLiveTests {
    private func t(_ h: Int, _ m: Int) -> Date {
        var c = Calendar(identifier: .gregorian); c.timeZone = .current
        return c.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: h, minute: m))!
    }
    private func phase(_ h: Int, _ m: Int, shots: Int, night: Bool = true, morning: Bool = true) -> LattagLiveAttributes.Phase? {
        LattagLiveClock.phase(now: t(h, m), shots: shots, shotYesterday: shots >= 1, night: night, morning: morning)
    }

    @Test func nightFilmThenLastCall() {
        #expect(phase(22, 59, shots: 1) == nil)
        #expect(phase(23, 0, shots: 1) == .film)
        #expect(phase(23, 49, shots: 0) == .film)
        #expect(phase(23, 50, shots: 2) == .lastCall)
        #expect(phase(23, 59, shots: 2) == .lastCall)
    }

    @Test func threeShotsOrLightsOutEnds() {
        #expect(phase(23, 10, shots: 3) == nil)
        #expect(phase(23, 55, shots: 3) == nil)
        #expect(phase(0, 0, shots: 1) == nil)
    }

    @Test func morningNeedsAShotAndSwitch() {
        #expect(phase(8, 29, shots: 1) == nil)
        #expect(phase(8, 30, shots: 1) == .opening)
        #expect(phase(8, 40, shots: 0) == nil)
        #expect(phase(9, 0, shots: 1) == nil)
        #expect(phase(8, 40, shots: 1, morning: false) == nil)
        #expect(phase(23, 10, shots: 1, night: false) == nil)
    }
}
