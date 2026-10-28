import Testing
import Foundation
@testable import Later_再度

struct ProfileFilmMathTests {
    @Test func framesStartWithTodayOnTheLeftAndGoBackSixDays() {
        let now = Date()
        let keys = ProfileFilmMath.dayKeys(now: now)
        #expect(keys.count == ProfileFilmMath.frameCount)
        #expect(keys.first == ExposureDayStore.dayKey(for: now))
        let sixDaysAgo = Calendar.current.date(byAdding: .day, value: -6, to: now) ?? now
        #expect(keys.last == ExposureDayStore.dayKey(for: sixDaysAgo))
    }

    @Test func olderFramesFadeBurnAndSepiaMore() {
        #expect(ProfileFilmMath.ageFade(ago: 0) == 1)
        #expect(abs(ProfileFilmMath.ageFade(ago: 6) - 0.73) < 0.0001)
        #expect(ProfileFilmMath.ageSaturation(ago: 0) > ProfileFilmMath.ageSaturation(ago: 6))
        #expect(ProfileFilmMath.ageSepia(ago: 0) == 0)
        #expect(ProfileFilmMath.ageBurn(ago: 6) > ProfileFilmMath.ageBurn(ago: 1))
    }

    @Test func centreFrameIsLargestAndTheEdgeFrameIsPlain() {
        #expect(abs(ProfileFilmMath.scale(distance: 0) - 1.22) < 0.0001)
        #expect(ProfileFilmMath.scale(distance: 1) == 1)
        #expect(ProfileFilmMath.scale(distance: 3) == 1)
    }

    @Test func opacityNeverDropsBelowTheFloor() {
        #expect(ProfileFilmMath.opacity(distance: 0, ago: 0) == 1)
        #expect(ProfileFilmMath.opacity(distance: 10, ago: 6) == 0.28)
    }

    @Test func outerFramesTiltAwayFromTheCentre() {
        let left = ProfileFilmMath.tiltDegrees(distance: 0.5, offset: -40)
        let right = ProfileFilmMath.tiltDegrees(distance: 0.5, offset: 40)
        #expect(left > 0)
        #expect(right < 0)
        #expect(abs(left + right) < 0.0001)
        #expect(ProfileFilmMath.tiltDegrees(distance: 0, offset: 0) == 0)
    }

    @Test func holdRingFillsInOneAndAHalfSecondsAndCompletesAtTheEnd() {
        #expect(abs(ProfileFilmMath.ringProgress(holdElapsed: 0.6) - 0.5) < 0.0001)
        #expect(ProfileFilmMath.ringProgress(holdElapsed: 5) == 1)
        #expect(!ProfileFilmMath.isHoldComplete(holdElapsed: 1.19))
        #expect(ProfileFilmMath.isHoldComplete(holdElapsed: 1.2))
    }

    @Test func tickIsNotRepeatedWithinNinetyMilliseconds() {
        let start = Date()
        #expect(ProfileFilmMath.shouldTick(last: nil, now: start))
        #expect(!ProfileFilmMath.shouldTick(last: start, now: start.addingTimeInterval(0.05)))
        #expect(ProfileFilmMath.shouldTick(last: start, now: start.addingTimeInterval(0.09)))
    }
}
