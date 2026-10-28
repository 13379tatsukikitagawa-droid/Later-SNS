import Foundation
import CoreGraphics
import Testing
@testable import Later_再度

/// はじめての説明などの、計算だけを確かめる。
struct CaptureSpotTests {
    @Test func guideShowsOnlyOnceAndNotWhileCovered() {
        #expect(FirstGuide.shouldShow(seen: false, isCovered: false))
        #expect(!FirstGuide.shouldShow(seen: true, isCovered: false))
        #expect(!FirstGuide.shouldShow(seen: false, isCovered: true))
        #expect(!FirstGuide.shouldShow(seen: false, isCovered: false, isAlreadyShowing: true))
    }

    @Test func globeSizeIsDerivedFromTheScreenWidth() {
        #expect(V5Globe.diameter(forWidth: 375) == 375 * 0.64)
        #expect(V5Globe.diameter(forWidth: 420) == 420 * 0.64)
        #expect(V5Globe.diameter(forWidth: 440) == 280)
        #expect(V5Globe.diameter(forWidth: 1000) == 280)
        #expect(V5Globe.diameter(forWidth: -5) == 0)
    }
}
