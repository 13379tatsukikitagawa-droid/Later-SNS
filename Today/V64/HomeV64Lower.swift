import SwiftUI

// P04:Home の 下(スクロール した 所)。上から Today(今日の フィルム)→ Active → Yesterday → Mondo → Albums → On this day → Friends。
// 見本:L01〜L11(mock/src/app.js の arcToday / arcActive / arcYesterday / arcMondo / arcAlbums / arcFriends)。背景は #0A0A0B。

struct HomeV64LowerData {
    struct Today { var thumbs: [UIImage?] = []; var times: [String] = [] }
    struct Hero { var photo: UIImage?; var tag: String = "#朝"; var tagColor: Color = Color(hex: "9ED8FF"); var dateLabel = "NOV 15"; var moments = 0; var people = 0; var daysLeft = 6 }
    struct Tile: Identifiable { let id = UUID(); var photo: UIImage?; var name: String; var time: String?; var own = false; var kept = false }
    struct Album: Identifiable { let id = UUID(); var label: String; var left: String; var tiles: [UIImage?]; var more: Int }
    var today = Today()
    var hero: Hero?
    var tiles: [Tile] = []
    var mondo: [(tag: String, photo: UIImage?)] = []
    var albums: [Album] = []
    var onThisDay: (photo: UIImage?, daysLeft: Int, date: String)?
    var trips: [(id: UUID?, name: String, sub: String, cover: UIImage?, day: String, unread: Int)] = []
    var weekday = "SUN"
}

enum HVL {
    static let bg = Color(hex: "0A0A0B")
    static let line = Color.white.opacity(0.08)
    static let label = Color(hex: "8E8E93")
    static let card = Color(hex: "121214")
}

struct HVLabel: View {
    let text: String
    var trailing: String? = nil
    var body: some View {
        HStack {
            Text(text).font(LF.mono(10.5)).tracking(2.1).foregroundStyle(HVL.label)
            Spacer()
            if let trailing { Text(trailing).font(LF.mono(10)).tracking(2.0).foregroundStyle(HVL.label.opacity(0.8)) }
        }
        .padding(.horizontal, 18)
    }
}

/// Today(今日の フィルム):3こま + 現像の すすみ + 時刻
struct HVTodayPanel: View {
    let input: HomeV64Input
    let data: HomeV64LowerData
    let action: () -> Void

    var body: some View {
        let n = input.shotsUsed
        let df = DateFormatter()
        let _ = df.dateFormat = "MMM d"
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Today").font(LF.serif(34)).tracking(-0.34).foregroundStyle(.white)
                    Spacer()
                    (Text("\(n)").font(LF.serif(30, italic: true)) + Text("/3").font(LF.serif(20, italic: true)).foregroundColor(Color(hex: "6E6E75"))).foregroundStyle(.white)
                }
                HStack(spacing: 7) {
                    Circle().fill(HV.lime).frame(width: 6, height: 6)
                    Text("\(n > 0 ? "DEVELOPING" : "EMPTY FILM") · \(df.string(from: input.now).uppercased())").font(LF.mono(10)).tracking(1.6).foregroundStyle(Color(hex: "9A9AA0"))
                }
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        ZStack {
                            RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(i < n ? 0.12 : 0.05))
                            if i < n, let img = data.today.thumbs[safe: i] ?? nil { Image(uiImage: img).resizable().scaledToFill().blur(radius: 6).saturation(0.4) }
                            if i == n { VStack(spacing: 4) { Image(systemName: "plus").font(.system(size: 14, weight: .bold)); Text("SHOOT").font(LF.mono(8)).tracking(1.2) }.foregroundStyle(HV.lime) }
                        }
                        .frame(maxWidth: .infinity).frame(height: 118).clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.10), lineWidth: 1))
                    }
                }
                HStack {
                    Text(n > 0 ? "\(data.today.times.first ?? "") shot" : "9:00 start").font(LF.mono(10)).foregroundStyle(.white)
                    Spacer()
                    Text(n > 0 ? "opens 9:00" : "lights out · 24:00").font(LF.serif(14, italic: true)).foregroundStyle(Color(hex: "9A9AA0"))
                }
            }
            .padding(18)
            .background(Color(red: 18 / 255, green: 16 / 255, blue: 20 / 255).opacity(0.86), in: RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(.white.opacity(0.07), lineWidth: 1))
            .shadow(color: .black.opacity(0.8), radius: 30, y: 30)
        }
        .buttonStyle(HVPress(scale: 0.98))
        .padding(.horizontal, 14)
    }
}

/// Active:進行中の Trip と「New trip」
struct HVActiveRow: View {
    var body: some View { VStack(spacing: 0) { HVAnchor(id: "sec-active"); content } }
    let data: HomeV64LowerData
    let input: HomeV64Input
    let actions: HomeV64Actions
    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HVLabel(text: "ACTIVE")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(data.trips.enumerated()), id: \.offset) { _, t in
                        Button { Haptics.play(.pop); if let id = t.id { actions.openTripHome(id) } else { actions.openTrip() } } label: {
                            ZStack(alignment: .topLeading) {
                                HVL.card
                                if let c = t.cover { Image(uiImage: c).resizable().scaledToFill().frame(width: 195, height: 248).clipped() }
                                LinearGradient(colors: [.black.opacity(0.3), .clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                                Text(t.day).font(LF.mono(10)).tracking(1.5).foregroundStyle(.white).padding(16)
                                VStack(alignment: .leading, spacing: 4) {
                                    Spacer()
                                    Text(t.name).font(LF.serif(36)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                                    Text(t.sub).font(LF.mono(11)).foregroundStyle(.white.opacity(0.75))
                                    HVTripFilm(trip: input.trip ?? HomeV64TripInfo(name: t.name, members: [], frames: []), height: 28, numbers: false).padding(.top, 6)
                                    Text("\(input.trip?.frames.filter { $0 != nil }.count ?? 0)/23").font(LF.serif(15, italic: true)).foregroundStyle(.white.opacity(0.7))
                                }.padding(14)
                                if t.unread > 0 { Text("\(t.unread)").font(LF.inter(800, 12)).foregroundStyle(.white).frame(width: 24, height: 24).background(Color(hex: "E02B2B"), in: Circle()).frame(maxWidth: .infinity, alignment: .trailing).padding(16) }
                            }.frame(width: 195, height: 248).clipShape(RoundedRectangle(cornerRadius: 24))
                                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.12), lineWidth: 1))
                        }.buttonStyle(HVPress(scale: 0.97))
                    }
                    Button { Haptics.play(.tick); actions.openTrip() } label: {
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(hex: "0E0E0F"))
                            ForEach(0..<3, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 3).fill(Color(hex: "E8E4DA")).frame(width: i == 1 ? 52 : 62, height: i == 1 ? 68 : 75)
                                    .overlay(Group { if let img = input.tripSamples[safe: i] { Image(uiImage: img).resizable().scaledToFill().frame(width: i == 1 ? 46 : 56, height: i == 1 ? 58 : 64).clipped() } else { Color(hex: "3A3A3C").frame(width: 46, height: 58) } }.offset(y: -3))
                                    .rotationEffect(.degrees(i == 0 ? -7 : (i == 2 ? 7 : 0)))
                                    .offset(x: [38, 59, 70][i], y: [53, 56, 53][i])
                            }
                            Image(systemName: "plus").font(.system(size: 15, weight: .semibold)).foregroundStyle(HV.ink)
                                .frame(width: 34, height: 34).background(Color(hex: "F4EFEA"), in: Circle()).offset(x: 68, y: 106)
                            Text("New trip").font(LF.serif(24)).foregroundStyle(.white).frame(width: 170).offset(y: 143)
                            Text("旅行 ・ 合宿 ・ イベント").font(LF.inter(600, 10.5)).foregroundStyle(HVL.label).frame(width: 170).offset(y: 182)
                        }
                        .frame(width: 170, height: 248)
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
                    }.buttonStyle(HVPress(scale: 0.97))
                }.padding(.horizontal, 18)
            }
        }
    }
}

/// Yesterday:大きな カード + ともだち / じぶんの 写真の 並び
struct HVYesterdayBlock: View {
    let input: HomeV64Input
    let data: HomeV64LowerData
    let actions: HomeV64Actions

    var body: some View {
        let locked = input.locked
        VStack(alignment: .leading, spacing: 8) {
            HVAnchor(id: "sec-yesterday")
            Rectangle().fill(HVL.line).frame(height: 1).padding(.horizontal, 18)
            HVLabel(text: "YESTERDAY", trailing: data.weekday).padding(.top, 8).padding(.bottom, 6)
            if input.isFirstDay { firstDay } else { hero(locked: locked) }
            if !input.isFirstDay {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(data.tiles) { t in tile(t, locked: locked) }
                }.padding(.horizontal, 14)
            }
        }
    }

    private func hero(locked: Bool) -> some View {
        // モック `.ayh`:ロック中も 開いて いる ときも 同じ 並び(幅 362 × 高さ 452)。ロック中は ぼかした 空 + 白い「shoot today to open」
        ZStack(alignment: .topLeading) {
            if locked {
                LinearGradient(stops: [.init(color: Color(hex: "BDB8C4"), location: 0), .init(color: Color(hex: "E9DDE2"), location: 0.34), .init(color: Color(hex: "7A6A70"), location: 0.56), .init(color: Color(hex: "1E1A1C"), location: 0.8)], startPoint: .top, endPoint: .bottom)
            } else {
                Color(hex: "1A1618")
                if let img = data.hero?.photo { Image(uiImage: img).resizable().scaledToFill().frame(width: 362, height: 452).clipped() }
                LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.28), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
            }
            if locked {
                HStack(spacing: 8) { Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)); Text("shoot today to open").font(LF.inter(800, 13)) }
                    .foregroundStyle(HV.ink).frame(width: 177, height: 38).background(.white, in: Capsule()).offset(x: 92, y: 150)
            }
            let h = data.hero
            Text("Yesterday").font(LF.serif(54)).foregroundStyle(.white).frame(width: 362, height: 78).offset(y: 206)
            Text(h?.dateLabel ?? "NOV 15").font(LF.mono(10.5)).tracking(3).foregroundStyle(.white.opacity(0.7)).frame(width: 362).offset(y: 268)
            stat("\(h?.moments ?? 6)", "Moments").frame(width: 100).offset(x: 31, y: 296)
            ZStack { Ellipse().stroke(HV.green, lineWidth: 2.5).frame(width: 68, height: 46).rotationEffect(.degrees(-4)); stat("\(h?.daysLeft ?? 6)d", "Left") }.frame(width: 100).offset(x: 131, y: 296)
            stat("\(h?.people ?? 4)", "People ›").frame(width: 100).offset(x: 231, y: 296)
            Button { Haptics.play(.pop); locked ? Haptics.play(.warn) : actions.openMondo() } label: {
                HStack(spacing: 8) { Image(systemName: "globe").font(.system(size: 17, weight: .semibold)); Text("Mondo").font(LF.inter(800, 17)) }
                    .foregroundStyle(HV.ink).frame(width: 268, height: 54).background(.white, in: Capsule())
            }.buttonStyle(HVPress(scale: 0.97)).offset(x: 16, y: 382)
            Image(systemName: "bubble.left").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white).frame(width: 54, height: 54).background(Color.white.opacity(0.14), in: Circle()).offset(x: 292, y: 382)
            if !locked, let h { Text(h.tag).font(LF.inter(900, 14)).foregroundStyle(HV.ink).padding(.horizontal, 12).padding(.vertical, 8).background(h.tagColor, in: RoundedRectangle(cornerRadius: 12)).rotationEffect(.degrees(8)).offset(x: 293, y: 18) }
        }
        .frame(width: 362, height: 452).clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .padding(.horizontal, 14)
    }

    /// はじめての 日:空っぽの カード(点線の チェキ 3つ + 「TODAY'S 1ST」+ カウントダウン)
    private var firstDay: some View {
        let cal = Calendar.current
        let open = cal.date(bySettingHour: 9, minute: 0, second: 0, of: cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: input.now)) ?? input.now) ?? input.now
        let sec = max(0, Int(open.timeIntervalSince(input.now)))
        return VStack(spacing: 0) {
            ZStack {
                ForEach([-1, 1], id: \.self) { sgn in
                    RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [4, 4])).frame(width: 96, height: 118)
                        .rotationEffect(.degrees(Double(sgn) * 10)).offset(x: CGFloat(sgn) * 70, y: 12)
                }
                RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.5), lineWidth: 1).background(RadialGradient(colors: [HV.lime.opacity(0.18), .clear], center: .center, startRadius: 0, endRadius: 60), in: RoundedRectangle(cornerRadius: 6)).frame(width: 96, height: 118)
                    .overlay(Text("TODAY'S 1ST").font(LF.mono(9)).tracking(1.6).foregroundStyle(HV.lime).padding(.bottom, 12), alignment: .bottom)
            }.frame(height: 150).padding(.top, 26)
            Text("Yesterday").font(LF.serif(52)).tracking(-1).foregroundStyle(.white).padding(.top, 40)
            Text("今日 撮った 1枚が、あしたの 朝 9:00 に\nここで ひらきます。").font(LF.inter(500, 13)).foregroundStyle(.white.opacity(0.66)).multilineTextAlignment(.center).lineSpacing(4).padding(.top, 30)
            HStack(spacing: 10) {
                HVLiveDot()
                Text("9:00 まで \(sec / 3600)h \(String(format: "%02d", (sec % 3600) / 60))m").font(LF.mono(11, bold: true).italic()).tracking(1.4).foregroundStyle(.white.opacity(0.85))
            }.padding(.horizontal, 18).frame(height: 34).background(Color.white.opacity(0.06), in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1)).padding(.vertical, 20)
        }
        .frame(width: 362).background(Color(hex: "161618"), in: RoundedRectangle(cornerRadius: 30))
        .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(.white.opacity(0.08), lineWidth: 1)).padding(.horizontal, 14)
    }

    private func stat(_ n: String, _ l: String) -> some View {
        VStack(spacing: 2) { Text(n).font(LF.serif(34, italic: true)).foregroundStyle(.white); Text(l).font(LF.inter(600, 13)).foregroundStyle(.white.opacity(0.75)) }
    }

    private func tile(_ t: HomeV64LowerData.Tile, locked: Bool) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 26).fill(HVL.card)
            if let img = t.photo { Image(uiImage: img).resizable().scaledToFill().blur(radius: locked ? 14 : 0).saturation(locked ? 0.4 : 1) }
            LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .center, endPoint: .bottom)
            HStack {
                if !locked { Text("\(t.name).").font(LF.serif(20, italic: true)).foregroundStyle(.white) }
                Spacer()
                if locked { Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.white) }
                else if let tm = t.time { Text(tm).font(LF.mono(9.5)).foregroundStyle(Color(hex: "FF9A3C")) }
            }.padding(14)
        }
        .frame(height: 212).clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .overlay(alignment: .topTrailing) { if t.own { Image(systemName: "star").font(.system(size: 15, weight: .bold)).foregroundStyle(Color(hex: "FFD60A")).padding(12) } }
    }
}

/// セクションの 頭に 置く 目印(DEBUG の 位置あわせ ・ 目次から の スクロール 用)
struct HVAnchor: View {
    let id: String
    var body: some View { Color.clear.frame(height: 0).id(id) }
}

/// Mondo の 列(人気タグ):高さ 188 の 縦長カード(数字 ・ タグ)
struct HVMondoRow: View {
    let input: HomeV64Input
    let data: HomeV64LowerData
    let actions: HomeV64Actions
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HVAnchor(id: "sec-mondo")
            Rectangle().fill(HVL.line).frame(height: 1).padding(.horizontal, 18)
            HVLabel(text: "MONDO", trailing: "TOP 5").padding(.top, 18)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(Array(data.mondo.enumerated()), id: \.offset) { i, m in
                        Button { input.locked ? Haptics.play(.warn) : actions.openMondo() } label: {
                            ZStack(alignment: .bottomLeading) {
                                LinearGradient(colors: [Color(hex: "3A2E3A"), Color(hex: "14100F")], startPoint: .top, endPoint: .bottom)
                                if let img = m.photo { Image(uiImage: img).resizable().scaledToFill().frame(width: 142, height: 188).clipped().blur(radius: input.locked ? 10 : 0) }
                                LinearGradient(colors: [.black.opacity(0.1), .clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                                Text(String(format: "%02d", i + 1)).font(LF.serif(40, italic: true)).foregroundStyle(.white.opacity(0.95)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(.leading, 12).padding(.top, 6)
                                Text(m.tag).font(LGFont.mincho(21)).foregroundStyle(.white).padding(14)
                                if input.locked { Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(.white).frame(width: 30, height: 30).background(Color.black.opacity(0.6), in: Circle()).frame(maxWidth: .infinity, maxHeight: .infinity) }
                            }
                            .frame(width: 142, height: 188).clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
                        }.buttonStyle(HVPress(scale: 0.97))
                    }
                }.padding(.horizontal, 14)
            }.padding(.top, 14)
        }
    }
}

/// Albums(7日):日ごとに 3枚 + 「+N」(4列)
struct HVAlbums: View {
    let data: HomeV64LowerData
    let actions: HomeV64Actions
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HVAnchor(id: "sec-albums")
            Rectangle().fill(HVL.line).frame(height: 1).padding(.horizontal, 18)
            HVLabel(text: "ALBUMS", trailing: "7 DAYS · RECAP ›").padding(.top, 14)
            ForEach(Array(data.albums.enumerated()), id: \.element.id) { k, a in
                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(a.label).font(LF.serif(26)).tracking(-0.26).foregroundStyle(.white).frame(height: 25)
                        Spacer()
                        Text(a.left).font(LF.mono(9.5)).tracking(1.6).foregroundStyle(HVL.label)
                    }.padding(.horizontal, 18)
                    HStack(spacing: 7) {
                        ForEach(0..<3, id: \.self) { j in
                            ZStack {
                                RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.02))
                                if let img = a.tiles[safe: j] ?? nil { Image(uiImage: img).resizable().scaledToFill() }
                            }.frame(maxWidth: .infinity).frame(height: 112).clipShape(RoundedRectangle(cornerRadius: 18))
                                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.10), lineWidth: 1))
                        }
                        ZStack {
                            if let img = a.tiles.first ?? nil { Image(uiImage: img).resizable().scaledToFill().blur(radius: 10).brightness(-0.1) }
                            Text("+\(a.more)").font(LF.inter(600, 18)).foregroundStyle(.white)
                        }.frame(maxWidth: .infinity).frame(height: 112).background(HVL.card).clipShape(RoundedRectangle(cornerRadius: 18))
                    }.padding(.horizontal, 14)
                }
                .padding(.top, k == 0 ? 14 : 22)
                .opacity(1 - Double(k) * 0.07)
            }
        }
    }
}

/// On this day:1年 のこした 1枚(ポラロイド + 日付 + のこり)
struct HVOnThisDay: View {
    let data: HomeV64LowerData
    var body: some View {
        if let o = data.onThisDay {
            VStack(alignment: .leading, spacing: 0) {
                HVAnchor(id: "sec-onthisday")
                Rectangle().fill(HVL.line).frame(height: 1).padding(.horizontal, 18)
                HVLabel(text: "ON THIS DAY", trailing: "1 MONTH AGO").padding(.top, 20)
                HStack(alignment: .top, spacing: 18) {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color(hex: "F4F1EA"))
                        ZStack { Rectangle().fill(Color(hex: "3A3A3C")); if let img = o.photo { Image(uiImage: img).resizable().scaledToFill() } }
                            .frame(width: 136, height: 146).clipped().offset(x: 9, y: 9)
                        Text(o.date).font(LF.mono(9)).foregroundStyle(Color(hex: "FF9A3C")).offset(x: 86, y: 134)
                        Image(systemName: "sparkle").font(.system(size: 18, weight: .bold)).foregroundStyle(Color(hex: "FFD60A")).offset(x: 10, y: 160)
                    }.frame(width: 154, height: 186).rotationEffect(.degrees(-4)).shadow(color: .black.opacity(0.6), radius: 14, y: 10)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Oct 17").font(LF.serif(44)).tracking(-0.9).foregroundStyle(.white).padding(.top, 14)
                        Text("1 month ago").font(LF.serif(19, italic: true)).foregroundStyle(HVL.label)
                        ZStack(alignment: .leading) { Capsule().fill(Color.white.opacity(0.08)).frame(height: 3); Capsule().fill(Color(hex: "24A03C")).frame(width: 150, height: 3) }.padding(.top, 14)
                        Text("\(o.daysLeft) DAYS LEFT").font(LF.mono(10)).tracking(2).foregroundStyle(HVL.label)
                        HStack(spacing: 5) { Capsule().fill(.white).frame(width: 14, height: 5); Circle().fill(.white.opacity(0.3)).frame(width: 5, height: 5); Circle().fill(.white.opacity(0.3)).frame(width: 5, height: 5) }
                    }
                    Spacer(minLength: 0)
                }.padding(.horizontal, 16).padding(.top, 24)
            }
        }
    }
}

/// 下の ぜんぶを たばねる
struct HVLowerSections: View {
    let input: HomeV64Input
    let data: HomeV64LowerData
    let actions: HomeV64Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 34) {
            HVTodayPanel(input: input, data: data) { input.shotsUsed == 0 ? actions.shoot() : actions.openDevelop() }.id("today")
            HVActiveRow(data: data, input: input, actions: actions)
            HVYesterdayBlock(input: input, data: data, actions: actions)
            if !input.isFirstDay {
                HVMondoRow(input: input, data: data, actions: actions)
                HVAlbums(data: data, actions: actions)
                HVOnThisDay(data: data)
            }
            HVFriendsCard(input: input, actions: actions)
            Spacer().frame(height: 404)
        }
        .background(alignment: .top) { VStack(spacing: 0) { Color.clear.frame(height: 90); HVL.bg } }
    }
}
