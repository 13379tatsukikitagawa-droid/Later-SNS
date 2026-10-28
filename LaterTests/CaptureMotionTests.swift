import Testing
import Foundation
@testable import Later_再度

struct CaptureMotionTests {
    @Test func releasedProgressFallsFromTheValueAtReleaseToZeroInThreeTenths() {
        #expect(CaptureMotion.releasedProgress(from: 0.8, elapsed: 0) == 0.8)
        // p×(1-k)²:半分の時間(k=0.5)で、1/4 になる
        #expect(abs(CaptureMotion.releasedProgress(from: 0.8, elapsed: 0.15) - 0.2) < 0.0001)
        #expect(CaptureMotion.releasedProgress(from: 0.8, elapsed: 0.3) == 0)
        #expect(CaptureMotion.releasedProgress(from: 0.8, elapsed: 2) == 0)
    }

    @Test func apertureOpensWideAtRestAndClosesAtFull() {
        #expect(CaptureMotion.apertureRadius(0) == 380)
        #expect(CaptureMotion.apertureRadius(1) == 0)
        #expect(CaptureMotion.apertureRotation(0) == 30 * .pi / 180)
    }

    @Test func dialLightsOneTickPerSixtieth() {
        #expect(CaptureMotion.litDialTicks(0) == 0)
        #expect(CaptureMotion.litDialTicks(0.5) == 30)
        #expect(CaptureMotion.litDialTicks(1) == 60)
    }

    @Test func pearlAndStampFollowTheProgress() {
        #expect(CaptureMotion.pearlScale(0) == 1)
        #expect(abs(CaptureMotion.pearlScale(1) - 0.45) < 0.0001)
        #expect(CaptureMotion.stampOpacity(0) == 1)
        #expect(abs(CaptureMotion.stampOpacity(1) - 0.4) < 0.0001)
    }

    @Test func holdCaptionChangesOnlyWhileHolding() {
        #expect(CaptureMotion.holdCaption(progress: 0, holding: false) == "1日3こままで。長押しで撮る")
        #expect(CaptureMotion.holdCaption(progress: 0.2, holding: true) == "そのまま、持っていて")
        #expect(CaptureMotion.holdCaption(progress: 0.5, holding: true) == "もうすぐ")
        #expect(CaptureMotion.holdCaption(progress: 0.9, holding: false) == "1日3こままで。長押しで撮る")
    }
}

struct CaptureAfterShotTests {
    @Test func startsWithTheFlashAndTheChromeVisible() {
        let frame = CaptureAfterShot.frame(at: 0, reduceMotion: false)
        #expect(abs(frame.flash - 0.95) < 0.0001)
        #expect(frame.chrome == 1)
        #expect(frame.window == 1)
        #expect(frame.advance == 0)
        #expect(frame.takenFrame == 1)
    }

    @Test func filmIsAdvancedSixClicksAndStopsOneFrameLater() {
        // 巻き終わり(1.35秒)で、ちょうど1こま(242pt)
        let done = CaptureAfterShot.frame(at: 1.35, reduceMotion: false)
        #expect(abs(done.advance - CaptureAfterShot.frameStep) < 0.0001)
        #expect(abs(done.crankAngle - 360) < 0.0001)
        // 止まったまま(以降は動かない)
        let later = CaptureAfterShot.frame(at: 2.0, reduceMotion: false)
        #expect(abs(later.advance - CaptureAfterShot.frameStep) < 0.0001)
    }

    @Test func noClickMovesBeforeTheStart() {
        #expect(CaptureAfterShot.clickProgress(at: 0.4) == 0)
    }

    @Test func endsWithTheTakenFrameGoneAndTheNextOpeningShown() {
        let end = CaptureAfterShot.frame(at: CaptureAfterShot.total, reduceMotion: false)
        #expect(end.takenFrame == 0)
        #expect(abs(end.nextOpening - 0.7) < 0.0001)
        #expect(CaptureAfterShot.total == 2.25)
    }

    @Test func reducedMotionShowsTheFinalPictureWithoutMoving() {
        let frame = CaptureAfterShot.frame(at: 0.2, reduceMotion: true)
        #expect(frame.advance == CaptureAfterShot.frameStep)
        #expect(frame.crankAngle == 0)
        #expect(frame.takenFrame == 0)
        #expect(frame.chrome == 0)
        #expect(CaptureAfterShot.duration(reduceMotion: true) == 1.0)
    }

    @Test func nextOpeningMatchesTheDailyWindow() {
        #expect(CaptureAfterShot.nextOpeningText == "\(DailyExposureRules.openingHour):00")
    }
}
