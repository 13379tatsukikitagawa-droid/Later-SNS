import Testing
import CoreGraphics
@testable import Later_再度

struct GroupEmptyYouthTests {
    @Test func radiusShrinksOnNarrowScreens() {
        #expect(GroupEmptyYouth.horizontalRadius(screenWidth: 430) == 128)
        #expect(GroupEmptyYouth.horizontalRadius(screenWidth: 375) == 128)
        #expect(GroupEmptyYouth.horizontalRadius(screenWidth: 320) < 128)
    }

    @Test func firstSeatIsAtTop() {
        let p = GroupEmptyYouth.seatOffset(index: 0, rx: 128)
        #expect(abs(p.x) < 0.001)
        #expect(abs(p.y + 86) < 0.001)
    }

    @Test func sevenSeatColors() {
        #expect(GroupEmptyYouth.seatColors.count == 7)
        #expect(GroupEmptyYouth.stickers.map(\.word) == ["放課後", "いつメン", "部活", "帰り道"])
    }
}
