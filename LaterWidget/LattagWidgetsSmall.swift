import SwiftUI
import WidgetKit

// v96 B:小 3種(S1 レンズ ・ S2 9:00 まで ・ S3 友だちの 1枚)。見本 widgets/v96/S1〜S3。

// MARK: S1 レンズ ・ すぐ撮る

struct LattagLensWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LattagShared.Kind.lens, provider: LattagProvider()) { e in
            LattagLensView(model: e.model).widgetURL(LattagShared.Link.shoot)
                .containerBackground(for: .widget) { WColor.ground }
        }
        .configurationDisplayName("レンズ").description("押すと すぐ 撮れる")
        .supportedFamilies([.systemSmall]).contentMarginsDisabled()
    }
}

struct LattagLensView: View {
    let model: WidgetModel
    private var done: Bool { model.isDone }
    var body: some View {
        ZStack {
            WHashBand(color: done ? WColor.doneBand : WColor.lime).widgetAccentable()
            WLens(done: done).offset(y: -14)
            VStack { Spacer(); capsule.padding(.horizontal, 10).padding(.bottom, 10) }
        }
    }
    private var capsule: some View {
        HStack(spacing: 5) {
            WBars(remaining: done ? 0 : model.remaining, h: 12, w: 5).widgetAccentable()
            Text(done ? "9:00 OPEN" : "のこり \(model.remaining)").font(WFont.inter(900, 12)).foregroundStyle(.white).lineLimit(1).fixedSize().layoutPriority(2)
            Spacer(minLength: 0)
            WTimer(from: model.now, to: model.lightsOutAt).font(WFont.mono(8)).foregroundStyle(.white.opacity(0.65)).frame(maxWidth: 40, alignment: .trailing)
        }
        .padding(.horizontal, 10).frame(height: 32)
        .background(Color.black.opacity(0.85), in: Capsule())
    }
}

// MARK: S2 9:00 まで(ライム)/ 21:00 から 消灯まで(黒)

struct LattagUntil9Widget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LattagShared.Kind.until9, provider: LattagProvider()) { e in
            LattagUntil9View(model: e.model).widgetURL(LattagShared.Link.develop)
                .containerBackground(for: .widget) { Color(hex6: 0x0E0E10) }
        }
        .configurationDisplayName("9:00 まで").description("現像が ひらくまで")
        .supportedFamilies([.systemSmall]).contentMarginsDisabled()
    }
}

/// v134:ひらくまで(小)。#レンズ + フィルム 3枠 + 大きい 残り時間(Barlow)+ ライムの 進み(見本 70)
struct LattagUntil9View: View {
    let model: WidgetModel
    private var night: Bool { model.part == .evening }
    private var target: Date { night ? model.lightsOutAt : model.opensAt }
    private var progress: Double {
        let total: Double = 24 * 3600
        return min(1, max(0.03, 1 - target.timeIntervalSince(model.now) / total))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                WLiveLens(size: 30)
                Spacer(minLength: 0)
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(i < model.shots ? Color(hex6: 0xECEAE3) : .clear)
                            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(.white.opacity(i < model.shots ? 0 : 0.3), lineWidth: 1))
                            .frame(width: 9, height: 14)
                    }
                }
            }
            Spacer(minLength: 4)
            Text(night ? "24:00まで" : "ひらくまで").font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex6: 0xA3A3AB))
            WTimer(from: model.now, to: target)
                .font(.custom("BarlowCondensed-ExtraBold", size: 40)).foregroundStyle(LinearGradient(colors: [.white, Color(hex6: 0x8C8C94)], startPoint: .top, endPoint: .bottom)).widgetAccentable()
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule().fill(WColor.lime).frame(width: g.size.width * progress).widgetAccentable()
                }
            }.frame(height: 4).padding(.top, 4)
        }
        .padding(14)
    }
}

// MARK: S3 友だちの 1枚

struct LattagFriendWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LattagShared.Kind.friendPhoto, provider: LattagProvider(hourly: true)) { e in
            LattagFriendView(entry: e)
                .containerBackground(for: .widget) { WColor.ground }
        }
        .configurationDisplayName("友だちの 1枚").description("きのうの 友だちを 1枚ずつ")
        .supportedFamilies([.systemSmall]).contentMarginsDisabled()
    }
}

struct LattagFriendView: View {
    let entry: LattagEntry
    private var m: WidgetModel { entry.model }
    var body: some View {
        if m.beforeNine || !m.unlocked || m.yesterdayPhotos.isEmpty { locked.widgetURL(m.unlocked ? LattagShared.Link.friends : LattagShared.Link.shoot) }
        else {
            let list = m.yesterdayPhotos
            let i = ((entry.hourIndex % list.count) + list.count) % list.count
            open(list[i], index: i, total: list.count).widgetURL(LattagShared.Link.yesterday(friend: list[i].uid))
        }
    }

    private func open(_ p: YPhoto, index: Int, total: Int) -> some View {
        let friend = m.friends.first { $0.uid == p.uid }
        return ZStack {
            VStack(spacing: 0) {
                ZStack {
                    Rectangle().fill(WColor.paper)
                    VStack(spacing: 0) {
                        Group { if let img = WImage.load(p.thumb) { Image(uiImage: img).resizable().widgetAccentedRenderingMode(.desaturated).scaledToFill() } else { Color.gray } }
                            .frame(width: 118, height: 106).clipped().padding(.top, 8)
                        HStack(alignment: .firstTextBaseline) {
                            Text(p.name).font(WFont.hand(19)).foregroundStyle(Color(hex6: 0x1A1A1C)).lineLimit(1).minimumScaleFactor(0.6)
                            Spacer(minLength: 0)
                            Text(p.time).font(WFont.mono(7)).foregroundStyle(WColor.stamp)
                        }.padding(.horizontal, 10).padding(.top, 3)
                        Spacer(minLength: 0)
                    }
                }
                .frame(width: 134, height: 150).shadow(color: .black.opacity(0.4), radius: 6, y: 3)
                .rotationEffect(.degrees(-5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(.leading, 6).padding(.top, 4)
            if let tag = p.tag { Text("#" + tag).font(WFont.inter(900, 11)).foregroundStyle(Color(hex6: 0x111111)).padding(.horizontal, 8).padding(.vertical, 4).background(WColor.pink, in: RoundedRectangle(cornerRadius: 8)).rotationEffect(.degrees(-6)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(10).padding(.bottom, 14) }
            Group {
                if let f = friend { avatar(f) } else { Circle().fill(WColor.lime).frame(width: 34, height: 34).overlay(Text(String(p.name.prefix(1))).font(WFont.inter(900, 14)).foregroundStyle(.black)) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(8)
            HStack(spacing: 3) { Circle().fill(WColor.lime).frame(width: 5, height: 5); Text("\(index + 1) / \(total) ›").font(WFont.mono(8)).foregroundStyle(.white.opacity(0.85)) }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).padding(.leading, 12).padding(.bottom, 8)
        }
        .background { Group { if let img = WImage.load(p.thumb) { Image(uiImage: img).resizable().widgetAccentedRenderingMode(.desaturated).scaledToFill().blur(radius: 14).opacity(0.5) } }.clipped() }
        .clipped()
    }

    private func avatar(_ f: FriendRing) -> some View {
        ZStack {
            Circle().fill(WColor.hex(f.colorHex))
            if let img = WImage.load(f.avatar) { Image(uiImage: img).resizable().widgetAccentedRenderingMode(.desaturated).scaledToFill() }
            else { Text(f.initial).font(WFont.inter(900, 14)).foregroundStyle(.white) }
        }.frame(width: 34, height: 34).clipShape(Circle()).overlay(Circle().strokeBorder(WColor.lime, lineWidth: 2))
    }

    private var locked: some View {
        ZStack {
            Group {
                if let img = WImage.load(m.lockedPreviews.first) { Image(uiImage: img).resizable().widgetAccentedRenderingMode(.desaturated).scaledToFill().blur(radius: 10) }
                else { LinearGradient(colors: [Color(hex6: 0x2A2326), Color(hex6: 0x151313)], startPoint: .top, endPoint: .bottom) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
            Color.black.opacity(0.25)
            VStack(spacing: 8) {
                Image(systemName: "lock.fill").font(.system(size: 20, weight: .black)).foregroundStyle(Color(hex6: 0x0B0B0C)).frame(width: 46, height: 46).background(WColor.lime, in: Circle()).widgetAccentable()
                Text("1枚 撮ると ひらく").font(WFont.inter(900, 13)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                if m.friendsShot > 0 { Text("\(m.friendsShot)人が まってる").font(WFont.inter(700, 10)).foregroundStyle(WColor.lime) }
            }
        }
    }
}

