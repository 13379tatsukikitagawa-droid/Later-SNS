import SwiftUI
import Testing
@testable import Later_再度

/// ウィジェットの置き方:手順の数・文言の決まりと、図の見た目(LATER_SNAPSHOT_DIR がある時だけ)
@MainActor
struct WidgetSetupTests {
    @Test func 手順() {
        #expect(WidgetPlace.home.steps.count == 5)
        #expect(WidgetPlace.lock.steps.count == 5)
        #expect(WidgetPlace.controls.steps.count == 4)
        // 長押しは、ホーム画面・ロック画面の最初だけ
        #expect(WidgetPlace.home.steps[0].longPress && WidgetPlace.lock.steps[0].longPress)
        #expect(WidgetPlace.allCases.flatMap(\.steps).filter(\.longPress).count == 2)
        // 押す場所は、画面の中
        for step in WidgetPlace.allCases.flatMap(\.steps) {
            #expect((0...390).contains(step.target.x) && (0...844).contains(step.target.y))
        }
    }

    /// 図の窓は「画面幅 − 56pt」。どの画面幅でも、押す場所(指と光の輪)が窓の中におさまる
    @Test func 図の窓は画面幅から決まる() {
        for screenWidth in [320.0, 375, 390, 402, 430, 440] as [CGFloat] {
            for height in [300.0, 344] as [CGFloat] {
                let width = screenWidth - 56
                let scale = width / 390
                for step in WidgetPlace.allCases.flatMap(\.steps) {
                    let offset = WidgetGuideWindow.offsetY(focus: step.focusY ?? step.target.y, scale: scale, windowHeight: height)
                    let y = step.target.y * scale - offset
                    let x = step.target.x * scale
                    #expect(y >= 0 && y <= height, "\(step.title) w=\(screenWidth) h=\(height) y=\(y)")
                    #expect(x >= 0 && x <= width)
                }
            }
        }
        #expect(WidgetGuideWindow(step: WidgetPlace.home.steps[0], reduceMotion: true, size: CGSize(width: 334, height: 344)).scale == 334.0 / 390)
    }

    @Test func 図() throws {
        guard let dir = HomeSnapshotTests.outputDirectory else { return }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for place in WidgetPlace.allCases {
            let row = HStack(spacing: 10) {
                ForEach(Array(place.steps.enumerated()), id: \.offset) { _, step in
                    WidgetGuideWindow(step: step, reduceMotion: true, size: CGSize(width: 334, height: 344))
                }
            }
            .padding(10)
            .background(Color.black)
            let renderer = ImageRenderer(content: row)
            renderer.scale = 1
            try #require(renderer.uiImage?.pngData()).write(to: dir.appendingPathComponent("widget_setup_\(place).png"))
        }
        // ② のカード(画面幅 320 / 390 / 440 で、はみ出さないか)
        let cards = HStack(alignment: .top, spacing: 20) {
            ForEach([320.0, 390, 440] as [CGFloat], id: \.self) { width in
                VStack(spacing: 10) {
                    ForEach(WidgetPlace.allCases) { place in
                        WidgetPlaceCard(place: place, isSelected: place == .home) {}
                    }
                    WidgetPlaceCard(place: .controls, isSelected: false, isAvailable: false) {}
                    WidgetPlacementList(check: PlacementCheck(home: true, lock: false, controls: true, liveActivities: false)) {}
                    WidgetIntroSample(reduceMotion: true)
                }
                .padding(.horizontal, 28)
                .frame(width: width)
            }
        }
        .padding(.vertical, 20)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: cards)
        renderer.scale = 2
        try #require(renderer.uiImage?.pngData()).write(to: dir.appendingPathComponent("widget_setup_cards.png"))
    }
}
