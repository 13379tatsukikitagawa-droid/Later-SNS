import SwiftUI
import Testing
import WidgetKit
@testable import Later_再度

/// 見た目の確認用:ウィジェットの4状態×3サイズと、ロック画面の部品(LATER_SNAPSHOT_DIR がある時だけ)
@MainActor
struct WidgetSnapshotTests {
    static func state(_ phase: LaterWidgetPhase, percent100: Bool = false) -> LaterWidgetState {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        func at(_ h: Int, _ m: Int) -> Date { calendar.date(bySettingHour: h, minute: m, second: 0, of: today)! }
        var snap = LaterWidgetSnapshot.empty
        let now: Date
        switch phase {
        case .U: now = at(9, 12); snap.hasYesterday = true
        case .R: now = at(19, 20); snap.lastShotAt = at(18, 11); snap.hasYesterday = true
        case .D:
            now = percent100 ? calendar.date(byAdding: .minute, value: 32 * 60 + 59, to: today)! : at(23, 40)
            snap.lastShotAt = at(18, 11); snap.hasYesterday = true; snap.openedYesterday = true
        case .M: now = calendar.date(byAdding: .hour, value: 26, to: today)!
        }
        snap.history = [true, false, true, true, false, true]
        snap.dayKey = LaterWidgetDay.key(for: now)
        return .derive(snap, now: now)
    }

    @Test func render() throws {
        guard let dir = HomeSnapshotTests.outputDirectory else { return }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let sizes: [(WidgetFamily, CGSize)] = [(.systemSmall, CGSize(width: 170, height: 170)), (.systemMedium, CGSize(width: 364, height: 170)), (.systemLarge, CGSize(width: 364, height: 382))]
        let states = LaterWidgetPhase.allCases.map { Self.state($0) } + [Self.state(.D, percent100: true)]
        for (family, size) in sizes {
            let row = HStack(spacing: 12) {
                ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                    LaterSceneView(state: state, family: family)
                        .frame(width: size.width, height: size.height)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                }
            }
            .padding(12)
            .background(Color(white: 0.15))
            let renderer = ImageRenderer(content: row)
            renderer.scale = 2
            try #require(renderer.uiImage?.pngData()).write(to: dir.appendingPathComponent("widget_\(family).png"))
        }
        let accessories = HStack(spacing: 14) {
            ForEach(LaterWidgetPhase.allCases, id: \.self) { phase in
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        LaterTodayCircle(state: Self.state(phase)).frame(width: 60, height: 60)
                        LaterYesterdayCircle(state: Self.state(phase)).frame(width: 60, height: 60)
                        LaterWeekCircle(state: Self.state(phase)).frame(width: 60, height: 60)
                    }
                    LaterRectangularView(state: Self.state(phase)).frame(width: 160, height: 66)
                    LaterInlineView(state: Self.state(phase))
                }
            }
        }
        .padding(14)
        .foregroundStyle(.white)
        .background(Color(red: 0.2, green: 0.25, blue: 0.35))
        let renderer = ImageRenderer(content: accessories)
        renderer.scale = 2
        try #require(renderer.uiImage?.pngData()).write(to: dir.appendingPathComponent("widget_accessory.png"))
    }
}
