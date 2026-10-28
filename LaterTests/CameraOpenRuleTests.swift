import Foundation
import CoreGraphics
import Testing
@testable import Later_再度

/// 撮影画面をひらく判定(純粋なロジック)
struct CameraOpenRuleTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1000)

    private func decide(
        blocked: Bool = false,
        at: Date? = nil,
        last: Date? = nil,
        canShoot: Bool = true,
        night: Bool = false,
        shots: Int = 0
    ) -> CameraOpenRule.Decision {
        CameraOpenRule.decide(isBlocked: blocked, now: at ?? t0, lastAccepted: last,
                             canShoot: canShoot, isNight: night, shotsToday: shots)
    }

    @Test func opensWhenAShotIsAllowed() {
        #expect(decide() == .open)
        #expect(decide(shots: FilmRoll.shotsPerDay - 1) == .open)
    }

    @Test func ignoredWhenBlocked() {
        #expect(decide(blocked: true) == .ignore)
        #expect(decide(blocked: true, canShoot: false, night: true) == .ignore)
    }

    @Test func ignoresRequestsWithin0_9SecondsOfTheLastOne() {
        #expect(decide(at: t0.addingTimeInterval(0.89), last: t0) == .ignore)
        #expect(decide(at: t0.addingTimeInterval(0.91), last: t0) == .open)
        #expect(decide(at: t0.addingTimeInterval(5), last: t0) == .open)
    }

    @Test func deniedAfterTheLastShot() {
        #expect(decide(shots: FilmRoll.shotsPerDay) == .deniedShotsUsed)
        #expect(decide(canShoot: false) == .deniedShotsUsed)
    }

    @Test func deniedAtNight() {
        #expect(decide(canShoot: false, night: true) == .deniedNight)
        #expect(decide(canShoot: false, night: true, shots: FilmRoll.shotsPerDay) == .deniedNight)
    }

    @Test func deniedCopyMatchesTheSpec() {
        #expect(CameraOpenRule.deniedCopy(.deniedShotsUsed)?.title == "今日は、ここまで")
        #expect(CameraOpenRule.deniedCopy(.deniedShotsUsed)?.detail == "3こま、撮りました")
        #expect(CameraOpenRule.deniedCopy(.deniedNight)?.title == "おやすみの時間")
        #expect(CameraOpenRule.deniedCopy(.deniedNight)?.detail == "9:00に、3こま届く")
        #expect(CameraOpenRule.deniedCopy(.open) == nil)
        #expect(CameraOpenRule.deniedCopy(.ignore) == nil)
    }

    @Test func canOpenNeedsTimeAndRemainingShots() {
        #expect(CameraOpenRule.canOpen(canShoot: true, shotsToday: 0))
        #expect(CameraOpenRule.canOpen(canShoot: true, shotsToday: FilmRoll.shotsPerDay - 1))
        #expect(!CameraOpenRule.canOpen(canShoot: true, shotsToday: FilmRoll.shotsPerDay))
        #expect(!CameraOpenRule.canOpen(canShoot: false, shotsToday: 0))
    }

    @Test func closeSwipeDistances() {
        #expect(CameraOpenRule.swipeDownToClose == 120)
        #expect(CameraOpenRule.swipeLeftToClose == 110)
    }
}
