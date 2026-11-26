import Testing
import UIKit
import SwiftUI
@testable import Later_再度

// v134 Phase 1:土台(フォント ・ 色の 一本化 ・ 現像の 曲線)
struct V134FoundationTests {
    @Test func barlowIsBundled() {
        #expect(UIFont(name: "BarlowCondensed-ExtraBold", size: 20) != nil)
        #expect(UIFont(name: "SpaceMono-Bold", size: 12) != nil)
    }

    @Test func limeHasOneSource() {
        let ui = UIColor(LattagPalette.lime)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(Int((r * 255).rounded()) == 0xC8 && Int((g * 255).rounded()) == 0xF2 && Int((b * 255).rounded()) == 0x5A)
        for c in [LTColor.lime, LaterColor.lime, PopColor.lime, HV.lime, WColor.lime] {
            #expect(UIColor(c).isEqual(ui) || UIColor(c).cgColor.components == ui.cgColor.components)
        }
    }

    @Test func filmDevelopCurveIsMonotonic() {
        var last = -1.0
        for i in 0...10 {
            let q = FilmDevelop.smooth(Double(i) / 10)
            #expect(q >= last); last = q
        }
        #expect(FilmDevelop.smooth(0) == 0 && FilmDevelop.smooth(1) == 1)
    }
}
