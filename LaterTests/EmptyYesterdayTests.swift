import SwiftUI
import Testing
@testable import Later_再度

@MainActor
struct EmptyYesterdayTests {
    @Test func copyMatchesDemo() {
        #expect(EmptyYesterdayView.copy(.everyone) == .init(kicker: "YESTERDAY ・ 0 LIGHTS", title: "昨日の写真は\nありません。", body: "グループの誰も、撮っていない日でした。"))
        #expect(EmptyYesterdayView.copy(.mine) == .init(kicker: "YOU ・ 0 LIGHTS", title: "昨日は\n撮っていません。", body: "自分の写真は、ありませんでした。"))
        #expect(EmptyYesterdayView.copy(.mondo) == .init(kicker: "MONDO", title: "まだ写真が\n届いていません。", body: "時間をおいて、もう一度ひらいてください。"))
    }

    /// ほめる・なぐさめる・責める言い回しを入れない
    @Test(arguments: [EmptyYesterdayView.Kind.everyone, .mine, .mondo])
    func noConsolingWords(_ kind: EmptyYesterdayView.Kind) {
        let c = EmptyYesterdayView.copy(kind)
        let text = c.kicker + c.title + c.body
        for word in ["それも一日", "責め", "大丈夫", "えらい", "すごい", "残念", "ごめん", "がんばり"] {
            #expect(!text.contains(word))
        }
    }

    @Test(arguments: [EmptyYesterdayView.Kind.everyone, .mine, .mondo])
    func export(_ kind: EmptyYesterdayView.Kind) throws {
        guard let dir = HomeSnapshotTests.outputDirectory else { return }
        let view = YesterdayViewer(
            items: kind == .mondo ? nil : [],
            scope: kind == .everyone ? .everyone : (kind == .mine ? .mine : .mondo),
            groups: [], haptics: ExposureHaptics(), onScopeChange: { _ in }, onRetry: {}, onClose: {},
            everyoneHasPhotos: kind == .mine, isReloading: false, showsTodayCard: true
        )
        .frame(width: 390, height: 844)
        .environment(\.colorScheme, .dark)
        let r = ImageRenderer(content: view)
        r.scale = 2
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try #require(r.uiImage?.pngData()).write(to: dir.appendingPathComponent("empty_\(kind).png"))
    }
}
