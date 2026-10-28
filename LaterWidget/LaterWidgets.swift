import SwiftUI
import WidgetKit

// MARK: - バンドル

@main
struct LaterWidgetBundle: WidgetBundle {
    var body: some Widget {
        LaterSceneWidget()
        LaterTodayWidget()
        LaterYesterdayWidget()
        LaterWeekWidget()
        LaterLiveActivity()
        LaterShootControl()
        LaterOpenControl()
    }
}

// MARK: - 景色(小・中・大 + ロック画面の長方形・1行)

struct LaterSceneWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LaterWidgetShared.sceneKind, provider: LaterProvider()) { entry in
            LaterSceneEntryView(entry: entry)
        }
        .configurationDisplayName("Later")
        .description("ひとつの光。一日のなかで、景色が変わります。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

struct LaterSceneEntryView: View {
    let entry: LaterEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                LaterRectangularView(state: entry.state)
            case .accessoryInline:
                LaterInlineView(state: entry.state)
            default:
                LaterSceneView(state: entry.state, family: family)
            }
        }
        .widgetURL(LaterWidgetShared.deepLink(entry.state.phase))
        .containerBackground(for: .widget) { Color.black }
    }
}

// MARK: - ロック画面:丸(今日・昨日・7日)

struct LaterTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LaterWidgetShared.todayKind, provider: LaterProvider()) { entry in
            LaterTodayCircle(state: entry.state)
                .widgetURL(LaterWidgetShared.deepLink(entry.state.phase))
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("今日")
        .description("撮る前は、のこり時間で点が減ります。撮ったあとは、現像の進みで点が増えます。")
        .supportedFamilies([.accessoryCircular])
    }
}

struct LaterYesterdayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LaterWidgetShared.yesterdayKind, provider: LaterProvider()) { entry in
            LaterYesterdayCircle(state: entry.state)
                .widgetURL(LaterWidgetShared.deepLink(entry.state.phase))
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("昨日")
        .description("昨日の円盤。撮ると、封が解けます。")
        .supportedFamilies([.accessoryCircular])
    }
}

struct LaterWeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LaterWidgetShared.weekKind, provider: LaterProvider()) { entry in
            LaterWeekCircle(state: entry.state)
                .widgetURL(LaterWidgetShared.deepLink(entry.state.phase))
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("7日")
        .description("撮った日だけ、点が灯ります。")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - プレビュー(デモの ?view=sheet と見くらべる)

#Preview("小", as: .systemSmall) {
    LaterSceneWidget()
} timeline: {
    LaterPreviewData.entry(.U)
    LaterPreviewData.entry(.R)
    LaterPreviewData.entry(.D)
    LaterPreviewData.entry(.M)
}

#Preview("中", as: .systemMedium) {
    LaterSceneWidget()
} timeline: {
    LaterPreviewData.entry(.U)
    LaterPreviewData.entry(.R)
    LaterPreviewData.entry(.D)
    LaterPreviewData.entry(.M)
}

#Preview("大", as: .systemLarge) {
    LaterSceneWidget()
} timeline: {
    LaterPreviewData.entry(.U)
    LaterPreviewData.entry(.R)
    LaterPreviewData.entry(.D)
}

#Preview("長方形", as: .accessoryRectangular) {
    LaterSceneWidget()
} timeline: {
    LaterPreviewData.entry(.U)
    LaterPreviewData.entry(.R)
    LaterPreviewData.entry(.D)
}

#Preview("丸・今日", as: .accessoryCircular) {
    LaterTodayWidget()
} timeline: {
    LaterPreviewData.entry(.U)
    LaterPreviewData.entry(.D)
}

enum LaterPreviewData {
    static func entry(_ phase: LaterWidgetPhase) -> LaterEntry {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        func at(_ h: Int, _ m: Int) -> Date { calendar.date(bySettingHour: h, minute: m, second: 0, of: today)! }
        let now: Date
        var snapshot = LaterWidgetSnapshot.empty
        switch phase {
        case .U: now = at(15, 7)
        case .R: now = at(19, 20); snapshot.lastShotAt = at(18, 11); snapshot.hasYesterday = true
        case .D: now = at(22, 40); snapshot.lastShotAt = at(18, 11); snapshot.hasYesterday = true; snapshot.openedYesterday = true
        case .M: now = calendar.date(byAdding: .hour, value: 26, to: today)!
        }
        snapshot.history = [true, false, true, true, false, true]
        snapshot.dayKey = LaterWidgetDay.key(for: now)
        return LaterEntry(date: now, state: .derive(snapshot, now: now))
    }
}
