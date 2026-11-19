import Testing
import Foundation
@testable import Later_再度

@MainActor
struct WidgetOfferV104Tests {
    @Test func 置けたかは_Lattagの数がふえた時だけ() async {
        let saved = WidgetPlacement.provider
        defer { WidgetPlacement.provider = saved }
        WidgetPlacement.provider = { ["LattagLens", "OtherApp.Widget"] }
        #expect(await WidgetPlacement.count() == 1)
        #expect(await WidgetPlacement.increased(since: 0))
        #expect(!(await WidgetPlacement.increased(since: 1)))
        WidgetPlacement.provider = { ["LattagLens", "LattagMondo"] }
        #expect(await WidgetPlacement.increased(since: 1))
        WidgetPlacement.provider = { [] }
        #expect(!(await WidgetPlacement.increased(since: 0)))
    }

    @Test func 案内は5場面_約11秒_最後で止まる() {
        #expect(WidgetHowTo.scenes.count == 5)
        #expect(WidgetHowTo.scene(at: 0) == 0)
        #expect(WidgetHowTo.scene(at: 2.3) == 1)
        #expect(WidgetHowTo.scene(at: 100) == 4)
        #expect(WidgetHowTo.progress(at: 100) == 1)
        #expect(WidgetHowTo.typedChars(at: 0) == 0)
        #expect(WidgetHowTo.typedChars(at: 100) == 6)
        #expect(WidgetHowTo.hapticSchedule.count == 8)
        #expect(WidgetHowTo.hapticSchedule.last?.1 == .success)
    }
}
