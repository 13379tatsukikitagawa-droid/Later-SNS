import Testing
@testable import Later_再度

struct VideoExposureRulesTests {
    @Test func releasingBeforeOneAndAHalfSecondsKeepsNothing() {
        #expect(VideoExposureRules.outcome(heldFor: 0.8, canRecord: true) == .discard)
        #expect(VideoExposureRules.outcome(heldFor: 1.49, canRecord: true) == .discard)
    }

    @Test func releasingBetweenOneAndAHalfAndTwoSecondsKeepsOnlyThePhoto() {
        #expect(VideoExposureRules.outcome(heldFor: 1.5, canRecord: true) == .photoOnly)
        #expect(VideoExposureRules.outcome(heldFor: 2.0, canRecord: true) == .photoOnly)
    }

    @Test func holdingPastTwoSecondsMakesAVideo() {
        #expect(VideoExposureRules.outcome(heldFor: 2.01, canRecord: true) == .video)
        #expect(VideoExposureRules.outcome(heldFor: 15, canRecord: true) == .video)
    }

    @Test func withoutRecordingAvailableItFallsBackToThePhoto() {
        #expect(VideoExposureRules.outcome(heldFor: 5, canRecord: false) == .photoOnly)
    }

    @Test func limitsAndMarks() {
        #expect(VideoExposureRules.maxDuration == 15)
        #expect(VideoExposureRules.softMarks == [5, 10])
        #expect(VideoExposureRules.previewMode == .visible)
    }
}
