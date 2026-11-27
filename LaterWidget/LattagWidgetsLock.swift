import SwiftUI
import WidgetKit

// v96 B:ロック画面 4種(白 だけ ・ 色は iOS が きめる)。円 ① のこりの こま / 円 ② 9:00 まで / 長方形 / 1行

struct LattagLockRingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LattagShared.Kind.lockRing, provider: LattagProvider()) { e in
            LattagLockRingView(model: e.model).widgetURL(LattagShared.Link.shoot).containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("のこりの こま").description("今日 あと 何こま 撮れるか")
        .supportedFamilies([.accessoryCircular])
    }
}

struct LattagLockRingView: View {
    let model: WidgetModel
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            ForEach(0..<model.limit, id: \.self) { i in
                Circle().trim(from: 0.02, to: 0.31).stroke(i < model.remaining ? Color.white : Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90 + Double(i) * 120)).padding(3)
            }
            VStack(spacing: -2) {
                Text("\(model.remaining)").font(WFont.inter(900, 24)).monospacedDigit()
                Text("のこり").font(WFont.inter(800, 8))
            }.widgetAccentable()
        }
    }
}

struct LattagLockOpenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LattagShared.Kind.lockOpen, provider: LattagProvider()) { e in
            LattagLockOpenView(model: e.model).widgetURL(LattagShared.Link.develop).containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("9:00 まで").description("ひらくまでの 時間")
        .supportedFamilies([.accessoryCircular])
    }
}

struct LattagLockOpenView: View {
    let model: WidgetModel
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("9:00").font(WFont.inter(900, 14)).monospacedDigit()
                WTimer(from: model.now, to: model.opensAt).font(WFont.inter(900, 13)).frame(maxWidth: 40)
                Text("あと").font(WFont.inter(800, 8))
            }.widgetAccentable()
        }
    }
}

struct LattagLockRectWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LattagShared.Kind.lockRect, provider: LattagProvider()) { e in
            LattagLockRectView(model: e.model).widgetURL(e.model.part == .day ? LattagShared.Link.yesterday() : LattagShared.Link.shoot).containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Lattag").description("24:00まで ・ きのう")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct LattagLockRectView: View {
    let model: WidgetModel
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) { Image(systemName: "number.square.fill").font(.system(size: 9)); Text("Lattag").font(WFont.inter(800, 10)) }.opacity(0.85)
            if model.part == .day, let y = model.yesterday {
                Text("\(y.people)人が 撮りました").font(WFont.inter(900, 15)).lineLimit(1).minimumScaleFactor(0.7)
                Text("9:00 に ひらいた" + (y.tag.map { " ・ #" + $0 } ?? "")).font(WFont.inter(700, 10)).opacity(0.8).lineLimit(1)
            } else {
                HStack(spacing: 4) {
                    Text("24:00まで").font(WFont.inter(900, 14))
                    WTimer(from: model.now, to: model.part == .lightsOut ? model.opensAt : model.lightsOutAt).font(WFont.inter(900, 14)).frame(maxWidth: 70, alignment: .leading)
                }
                HStack(spacing: 5) { WBars(remaining: model.remaining, h: 9, w: 5, on: .white, off: .white.opacity(0.5)); Text("のこり \(model.remaining)こま").font(WFont.inter(700, 10)).opacity(0.85) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).widgetAccentable()
    }
}

struct LattagLockInlineWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LattagShared.Kind.lockInline, provider: LattagProvider()) { e in
            LattagLockInlineView(model: e.model).widgetURL(LattagShared.Link.shoot).containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("1行").description("時計の 上")
        .supportedFamilies([.accessoryInline])
    }
}

struct LattagLockInlineView: View {
    let model: WidgetModel
    var body: some View {
        (Text("# のこり \(model.remaining)こま ・ 24:00 ") + Text(timerInterval: model.now...max(model.lightsOutAt, model.now.addingTimeInterval(1)), pauseTime: nil, countsDown: true, showsHours: true))
    }
}
