import CoreGraphics
import Testing
import Foundation
@testable import Later_再度

struct DoubleTapSwitchRuleTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1000)

    @Test func twoCloseTapsWithinTheIntervalAndDistanceSwitch() {
        #expect(DoubleTapSwitchRule.isDoubleTap(
            firstAt: start, firstPoint: CGPoint(x: 100, y: 100),
            secondAt: start.addingTimeInterval(0.2), secondPoint: CGPoint(x: 110, y: 105)
        ))
    }

    @Test func aSlowSecondTapDoesNotSwitch() {
        #expect(!DoubleTapSwitchRule.isDoubleTap(
            firstAt: start, firstPoint: .zero,
            secondAt: start.addingTimeInterval(0.4), secondPoint: .zero
        ))
    }

    @Test func taps100PointsApartDoNotSwitch() {
        #expect(!DoubleTapSwitchRule.isDoubleTap(
            firstAt: start, firstPoint: .zero,
            secondAt: start.addingTimeInterval(0.1), secondPoint: CGPoint(x: 100, y: 0)
        ))
    }
}
