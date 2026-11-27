import SwiftUI
import WidgetKit
import AppIntents

// v96 C:中 ・ 大(M1 Friends / M2 きのう / M3 Trip / L1 ボード)。見本 widgets/v96/M1〜L1。

// MARK: 共通:チェキ

struct WCheki: View {
    var photo: UIImage?
    var name: String
    var time: String
    var width: CGFloat
    var tilt: Double
    var tape: Color
    var blurred = false
    var body: some View {
        let ph = width - 12
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Group {
                    if let photo { Image(uiImage: photo).resizable().widgetAccentedRenderingMode(.desaturated).scaledToFill() }
                    else { Color(hex6: 0x3A3A3C) }
                }.frame(width: ph, height: ph * 1.05).clipped().blur(radius: blurred ? 9 : 0).clipped().padding(.top, 6)
                HStack(alignment: .firstTextBaseline) {
                    Text(name).font(WFont.hand(width * 0.17)).foregroundStyle(Color(hex6: 0x1A1A1C)).lineLimit(1).minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                    Text(time).font(WFont.mono(max(6, width * 0.065))).foregroundStyle(WColor.stamp)
                }.padding(.horizontal, 8).padding(.top, 2)
                Spacer(minLength: 0)
            }
            .frame(width: width, height: width * 1.22).background(WColor.paper)
            .shadow(color: .black.opacity(0.45), radius: 5, y: 3)
            Rectangle().fill(tape.opacity(0.85)).frame(width: width * 0.38, height: 9).offset(y: -4).rotationEffect(.degrees(-3))
        }
        .rotationEffect(.degrees(tilt))
    }
}

private func wPeople(_ m: WidgetModel) -> [(name: String, time: String, image: UIImage?)] {
    if m.unlocked && !m.yesterdayPhotos.isEmpty { return m.yesterdayPhotos.map { ($0.name, $0.time, WImage.load($0.thumb)) } }
    let prev = WImage.load(m.lockedPreviews.first)
    let names = m.yesterday?.names ?? m.friends.map(\.name)
    return names.prefix(5).enumerated().map { i, n in
        (n, "", WImage.load(m.lockedPreviews[safeW: i]) ?? prev)
    }
}

// MARK: M1 Friends

struct LattagFriendsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LattagShared.Kind.friends, provider: LattagProvider()) { e in
            LattagFriendsView(model: e.model).widgetURL(LattagShared.Link.friends)
                .containerBackground(for: .widget) { WColor.ground }
        }
        .configurationDisplayName("Friends").description("今日 だれが 撮った?")
        .supportedFamilies([.systemMedium])
    }
}

struct LattagFriendsView: View {
    let model: WidgetModel
    var body: some View {
        let waiting = model.friends.filter { $0.shotsToday == 0 }
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Friends").font(WFont.serif(24)).foregroundStyle(.white)
                HStack(spacing: 4) { Circle().fill(WColor.lime).frame(width: 6, height: 6); Text("\(model.friendsShot)人 撮った").font(WFont.inter(800, 11)).foregroundStyle(WColor.lime) }.widgetAccentable()
                Spacer()
                Text("9:00 OPEN").font(WFont.mono(8)).foregroundStyle(.white.opacity(0.4))
            }
            if model.friends.isEmpty {
                Spacer()
                Text("友だちを よぶと、ここに ならびます").font(WFont.inter(700, 12)).foregroundStyle(.white.opacity(0.6)).frame(maxWidth: .infinity)
                Spacer()
            } else {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(model.friends.prefix(5)) { f in ring(f).frame(maxWidth: .infinity) }
                }
                nextRow(waiting)
            }
        }.padding(14)
    }

    private func ring(_ f: FriendRing) -> some View {
        VStack(spacing: 3) {
            ZStack {
                ForEach(Array(0..<3), id: \.self) { k in
                    Circle().trim(from: 0.012, to: 0.32).stroke(k < f.shotsToday ? WColor.lime : Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90 + Double(k) * 120)).frame(width: 52, height: 52)
                }
                ZStack {
                    Circle().fill(WColor.hex(f.colorHex))
                    if let img = WImage.load(f.avatar) { Image(uiImage: img).resizable().widgetAccentedRenderingMode(.desaturated).scaledToFill() }
                    else { Text(f.initial).font(WFont.inter(900, 15)).foregroundStyle(.white) }
                }.frame(width: 42, height: 42).clipShape(Circle()).saturation(f.shotsToday > 0 ? 1 : 0.3)
            }.frame(width: 54, height: 54)
            Text(f.name).font(WFont.inter(800, 10)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
        }
    }

    private func nextRow(_ waiting: [FriendRing]) -> some View {
        HStack(spacing: 8) {
            Text("NEXT").font(WFont.mono(8)).foregroundStyle(WColor.lime)
            Text(waiting.isEmpty ? "みんな 撮りました" : (waiting.prefix(2).map(\.name).joined(separator: " と ") + " が まだ")).font(WFont.inter(800, 13)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .padding(.leading, 12).padding(.trailing, 4).frame(height: 36).background(Color.white.opacity(0.07), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.08)))
    }
}

// MARK: M2 きのう

struct LattagYesterdayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LattagShared.Kind.yesterday, provider: LattagProvider()) { e in
            LattagYesterdayView(model: e.model).widgetURL(LattagShared.Link.yesterday())
                .containerBackground(for: .widget) { WColor.ground }
        }
        .configurationDisplayName("きのう").description("9:00 に ひらいた 3枚")
        .supportedFamilies([.systemMedium])
    }
}

/// v134:ともだちが「のせた」きのうの 写真いっぱい +「◯◯の きのう」+「11H 03M 見ないで待った」+ 右下に 小さい #レンズ(見本 70)
struct LattagYesterdayView: View {
    let model: WidgetModel
    /// "21:12" → 翌朝 9:00 までの 時間("11H 48M")
    static func waited(_ hm: String) -> String? {
        let p = hm.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2 else { return nil }
        let mins = ((9 * 60 - (p[0] * 60 + p[1])) % 1440 + 1440) % 1440
        return String(format: "%dH %02dM", mins / 60, mins % 60)
    }
    var body: some View {
        let ppl = wPeople(model)
        let locked = !(model.unlocked && !model.yesterdayPhotos.isEmpty)
        let first = ppl.first
        ZStack {
            Color(hex6: 0x0E0E10)
            if let img = first?.image {
                Image(uiImage: img).resizable().scaledToFill().blur(radius: locked ? 18 : 0).overlay(Color.black.opacity(locked ? 0.35 : 0.12))
            }
            LinearGradient(colors: [.black.opacity(0.35), .clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Circle().fill(.white).frame(width: 22, height: 22).overlay(Text(String((first?.name ?? "き").prefix(1))).font(.system(size: 11, weight: .heavy)).foregroundStyle(.black))
                    Text(first.map { "\($0.name)の きのう" } ?? "きのう").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                    Spacer()
                }
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        if locked {
                            Text("1枚 撮ると ひらく").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                        } else if let w = first.flatMap({ Self.waited($0.time) }) {
                            Text(w).font(.custom("BarlowCondensed-ExtraBold", size: 30)).foregroundStyle(.white)
                            Text("見ないで待った").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    Spacer()
                    WLiveLens(size: 30)
                }
            }.padding(14)
        }
    }
}

// MARK: M3 Trip

struct LattagTripWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LattagShared.Kind.trip, provider: LattagProvider()) { e in
            Group {
                if let t = e.model.trip { LattagTripView(trip: t).widgetURL(LattagShared.Link.trip(t.id)) }
                else { LattagTripEmpty().widgetURL(LattagShared.Link.friends) }
            }.containerBackground(for: .widget) { WColor.ground }
        }
        .configurationDisplayName("Trip").description("みんなの 枚数")
        .supportedFamilies([.systemMedium]).contentMarginsDisabled()
    }
}

struct LattagTripEmpty: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("Trip").font(WFont.serif(30)).foregroundStyle(.white)
            Text("旅行 ・ 合宿 ・ イベント。1日 23枚を、みんなで。").font(WFont.inter(700, 11)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center).padding(.horizontal, 20)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LattagTripView: View {
    let trip: TripSnap
    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Group { if let img = WImage.load(trip.cover) { Image(uiImage: img).resizable().widgetAccentedRenderingMode(.desaturated).scaledToFill() } else { LinearGradient(colors: [Color(hex6: 0x3A3A3C), Color(hex6: 0x1A1A1C)], startPoint: .top, endPoint: .bottom) } }
                    .frame(width: 112).clipped()
                Text("LATTAG").font(WFont.inter(900, 13)).foregroundStyle(.white).padding(10)
            }.frame(width: 112)
            VStack(alignment: .leading, spacing: 0) {
                HStack { Text("TRIP PASS").font(WFont.mono(8)).foregroundStyle(Color(hex6: 0x6C6C73)); Spacer(); Text(verbatim: "No." + String(trip.passNo)).font(WFont.mono(8)).foregroundStyle(Color(hex6: 0x6C6C73)) }
                Text(trip.title).font(WFont.inter(900, 22)).foregroundStyle(Color(hex6: 0x0B0B0C)).lineLimit(1).minimumScaleFactor(0.5).padding(.top, 2)
                HStack(spacing: 6) {
                    Text("DAY \(trip.day)").font(WFont.inter(900, 12)).foregroundStyle(WColor.lime).padding(.horizontal, 8).padding(.vertical, 3).background(Color(hex6: 0x0B0B0C), in: RoundedRectangle(cornerRadius: 8))
                    Text(trip.sub).font(WFont.mono(9)).foregroundStyle(Color(hex6: 0x1A1A1C)).lineLimit(1).minimumScaleFactor(0.6)
                }.padding(.top, 4)
                Spacer(minLength: 2)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(trip.count)").font(WFont.inter(900, 36)).foregroundStyle(Color(hex6: 0x0B0B0C))
                    Text("/ \(trip.total)枚 ・ みんなで").font(WFont.inter(700, 10)).foregroundStyle(Color(hex6: 0x555555))
                }
                cells.padding(.top, 4)
            }
            .padding(.horizontal, 12).padding(.vertical, 12).frame(maxWidth: .infinity).background(WColor.paper)
            Rectangle().fill(WColor.lime).frame(width: 10)
        }
        .overlay(alignment: .topLeading) { Circle().fill(WColor.ground).frame(width: 14, height: 14).offset(x: 105, y: -7) }
        .overlay(alignment: .bottomLeading) { Circle().fill(WColor.ground).frame(width: 14, height: 14).offset(x: 105, y: 7) }
    }

    private var cells: some View {
        let n = max(1, trip.total)
        let filled = Set(trip.filled), last = trip.filled.last
        return HStack(spacing: 2) {
            ForEach(Array(0..<n), id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5).fill(filled.contains(i) ? (i == last ? WColor.lime.opacity(0.9) : Color(hex6: 0x0B0B0C)) : Color(hex6: 0xE0DDD2)).frame(height: 7)
            }
        }
    }
}

// MARK: L1 Lattag ボード

struct LattagBoardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LattagShared.Kind.board, provider: LattagProvider()) { e in
            LattagBoardView(model: e.model).widgetURL(LattagShared.Link.shoot)
                .containerBackground(for: .widget) { WColor.ground }
        }
        .configurationDisplayName("Lattag ボード").description("きのうの 友だちと 今日")
        .supportedFamilies([.systemLarge])
    }
}

struct LattagBoardView: View {
    let model: WidgetModel
    private var locked: Bool { !(model.unlocked && !model.yesterdayPhotos.isEmpty) }
    var body: some View {
        let ppl = wPeople(model)
        VStack(spacing: 0) {
            header.padding(.horizontal, 14).padding(.top, 12)
            ZStack {
                ForEach(Array(ppl.prefix(5).enumerated()), id: \.offset) { i, p in
                    WCheki(photo: p.image, name: p.name, time: p.time, width: 94, tilt: [-5, 3, 6, -3, 4][i], tape: [WColor.pink, WColor.lime, WColor.sky, WColor.lime, WColor.pink][i], blurred: locked)
                        .offset(x: CGFloat([-100, 4, 104, -52, 54][i]), y: CGFloat([-58, -64, -54, 56, 60][i]))
                }
                if locked {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill").font(.system(size: 12, weight: .black)).foregroundStyle(Color(hex6: 0x0B0B0C)).frame(width: 26, height: 26).background(WColor.lime, in: Circle())
                        Text("あと \(max(1, model.remaining == 0 ? 0 : 1))枚 撮ると ひらく").font(WFont.inter(900, 14)).foregroundStyle(.white)
                    }.padding(.horizontal, 12).frame(height: 40).background(.black.opacity(0.88), in: Capsule()).overlay(Capsule().strokeBorder(WColor.lime, lineWidth: 2))
                } else {
                    VStack(spacing: 0) {
                        Text("\(model.yesterday?.count ?? 0)").font(WFont.inter(900, 34)).foregroundStyle(.white)
                        Text("枚 ・ きのう").font(WFont.inter(700, 9)).foregroundStyle(WColor.lime)
                    }.offset(x: 142, y: 20)
                    if let tag = model.yesterday?.tag { Text("#" + tag).font(WFont.inter(900, 12)).foregroundStyle(Color(hex6: 0x0B0B0C)).padding(.horizontal, 9).padding(.vertical, 4).background(WColor.lime, in: RoundedRectangle(cornerRadius: 9)).rotationEffect(.degrees(-6)).offset(x: -104, y: 20) }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            nextCapsule.padding(.horizontal, 12).padding(.bottom, 12)
        }
    }

    private var header: some View {
        HStack {
            Text("Lattag").font(WFont.inter(900, 26)).foregroundStyle(.white)
            Spacer()
            HStack(spacing: 6) {
                if model.beforeNine || !model.unlocked {
                    Text("24:00まで").font(WFont.inter(700, 9)).foregroundStyle(.white.opacity(0.6))
                    WTimer(from: model.now, to: model.part == .lightsOut ? model.opensAt : model.lightsOutAt).font(WFont.inter(900, 14)).foregroundStyle(.white).frame(maxWidth: 64)
                } else {
                    Text("ひらいた").font(WFont.inter(700, 9)).foregroundStyle(.white.opacity(0.6))
                    Text("\(model.yesterday?.people ?? 0)人").font(WFont.inter(900, 14)).foregroundStyle(.white)
                }
                WBars(remaining: model.remaining, h: 12, w: 5).widgetAccentable()
            }.padding(.horizontal, 10).frame(height: 30).background(Color.white.opacity(0.08), in: Capsule())
        }
    }

    private var nextCapsule: some View {
        let item = model.next
        let title = item?.title ?? (model.remaining > 0 ? "のこり \(model.remaining)こま ・ 撮る" : "今日は ここまで")
        let sub = item?.sub ?? "24:00まで " + WTimeText.hm(model.lightsOutAt.timeIntervalSince(model.now))
        return HStack(spacing: 10) {
            Image(systemName: "camera.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(Color(hex6: 0x0B0B0C)).frame(width: 40, height: 40).background(WColor.lime, in: Circle()).widgetAccentable()
            VStack(alignment: .leading, spacing: 1) {
                Text("NEXT").font(WFont.mono(8)).foregroundStyle(WColor.lime)
                Text(title).font(WFont.inter(900, 14)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                Text(sub).font(WFont.inter(600, 10)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.6)).frame(width: 30, height: 30).background(Color.white.opacity(0.1), in: Circle())
        }
        .padding(.horizontal, 10).frame(height: 56).background(Color.white.opacity(0.07), in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.08)))
    }
}
