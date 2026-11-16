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
    var trips: [(name: String, sub: String)] = []
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
            Text(text).font(LF.mono(11)).tracking(2.8).foregroundStyle(HVL.label)
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
    let data: HomeV64LowerData
    let input: HomeV64Input
    let actions: HomeV64Actions
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HVLabel(text: "ACTIVE")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(data.trips.enumerated()), id: \.offset) { _, t in
                        Button { Haptics.play(.pop); actions.openTrip() } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Spacer()
                                Text(t.name).font(LF.serif(24)).foregroundStyle(.white)
                                Text(t.sub).font(LF.inter(600, 11)).foregroundStyle(HVL.label)
                            }.padding(16).frame(width: 170, height: 248, alignment: .leading).background(HVL.card, in: RoundedRectangle(cornerRadius: 30))
                                .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(.white.opacity(0.12), lineWidth: 1))
                        }.buttonStyle(HVPress(scale: 0.97))
                    }
                    Button { Haptics.play(.tick); actions.openTrip() } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                ForEach(0..<3, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: "E8E4DA")).frame(width: 40, height: 56)
                                        .overlay(Group { if let img = input.tripSamples[safe: i] { Image(uiImage: img).resizable().scaledToFill().frame(width: 34, height: 44).clipped() } }.offset(y: -3))
                                        .rotationEffect(.degrees(Double(i - 1) * 8)).offset(x: CGFloat(i - 1) * 24, y: i == 1 ? -4 : 0)
                                }
                                Image(systemName: "plus").font(.system(size: 16, weight: .semibold)).foregroundStyle(HV.ink)
                                    .frame(width: 34, height: 34).background(Color(hex: "F4F1EA"), in: Circle()).offset(y: 34)
                            }.frame(height: 100)
                            Text("New trip").font(LF.serif(22)).foregroundStyle(.white)
                            Text("旅行 ・ 合宿 ・ イベント").font(LF.inter(600, 11)).foregroundStyle(HVL.label)
                        }
                        .frame(width: 170, height: 248).background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 30))
                        .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(.white.opacity(0.12), lineWidth: 1))
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
        VStack(alignment: .leading, spacing: 16) {
            Rectangle().fill(HVL.line).frame(height: 1).padding(.horizontal, 18)
            HVLabel(text: "YESTERDAY", trailing: data.weekday)
            hero(locked: locked)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(data.tiles) { t in tile(t, locked: locked) }
            }.padding(.horizontal, 14)
        }
    }

    private func hero(locked: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30).fill(Color(hex: "1A1618"))
            if let img = data.hero?.photo {
                Image(uiImage: img).resizable().scaledToFill().frame(width: 362, height: locked ? 330 : 450).clipped()
                    .blur(radius: locked ? 22 : 0).saturation(locked ? 0.35 : 1).brightness(locked ? 0.35 : 0)
                Color.black.opacity(locked ? 0.0 : 0.25)
                if locked { LinearGradient(stops: [.init(color: .clear, location: 0.45), .init(color: Color(hex: "0A0A0B"), location: 1)], startPoint: .top, endPoint: .bottom) }
            }
            if locked {
                VStack { Spacer()
                    HStack(spacing: 8) { Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)); Text("shoot today to open").font(LF.inter(800, 15)) }
                        .foregroundStyle(.white).padding(.horizontal, 18).frame(height: 38).hvGlass(radius: 19, tint: 0.12).padding(.bottom, 24)
                }
            } else if let h = data.hero {
                VStack(spacing: 10) {
                    Spacer()
                    Text("Yesterday").font(LF.serif(42)).tracking(-0.4).foregroundStyle(.white)
                    Text(h.dateLabel).font(LF.mono(10)).tracking(3).foregroundStyle(.white.opacity(0.6))
                    HStack {
                        stat("\(h.moments)", "Moments"); Spacer()
                        ZStack { Ellipse().stroke(HV.green, lineWidth: 2.5).frame(width: 70, height: 46).rotationEffect(.degrees(-6)); stat("\(h.daysLeft)d", "Left") }
                        Spacer(); stat("\(h.people)", "People ›")
                    }.padding(.horizontal, 34).padding(.top, 14)
                    HStack(spacing: 8) {
                        Button { Haptics.play(.pop); actions.openMondo() } label: {
                            HStack(spacing: 8) { Image(systemName: "globe").font(.system(size: 17, weight: .semibold)); Text("Mondo").font(LF.inter(800, 17)) }
                                .foregroundStyle(HV.ink).frame(maxWidth: .infinity).frame(height: 54).background(.white, in: Capsule())
                        }.buttonStyle(HVPress(scale: 0.97))
                        Image(systemName: "bubble.left").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white).frame(width: 54, height: 54).background(Color.white.opacity(0.12), in: Circle())
                    }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 16)
                }
                Text(h.tag).font(LF.inter(900, 14)).foregroundStyle(HV.ink).padding(.horizontal, 12).padding(.vertical, 8)
                    .background(h.tagColor, in: RoundedRectangle(cornerRadius: 12)).rotationEffect(.degrees(8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(18)
            }
        }
        .frame(width: 362, height: locked ? 330 : 450).clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .padding(.horizontal, 14)
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
                Text("\(t.name).").font(LF.serif(20, italic: true)).foregroundStyle(.white)
                Spacer()
                if locked { Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.white) }
                else if let tm = t.time { Text(tm).font(LF.mono(9.5)).foregroundStyle(Color(hex: "FF9A3C")) }
            }.padding(14)
        }
        .frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .overlay(alignment: .topTrailing) { if t.own { Image(systemName: "star").font(.system(size: 15, weight: .bold)).foregroundStyle(Color(hex: "FFD60A")).padding(12) } }
    }
}

/// Mondo の 列(人気タグ 3つ)
struct HVMondoRow: View {
    let input: HomeV64Input
    let data: HomeV64LowerData
    let actions: HomeV64Actions
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HVLabel(text: "MONDO", trailing: "9:00 の 世界 ›")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(data.mondo.enumerated()), id: \.offset) { i, m in
                        Button { input.locked ? Haptics.play(.warn) : actions.openMondo() } label: {
                            ZStack(alignment: .bottomLeading) {
                                if let img = m.photo { Image(uiImage: img).resizable().scaledToFill().frame(width: 156, height: 100).clipped().blur(radius: input.locked ? 8 : 0) }
                                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                                VStack(alignment: .leading, spacing: 2) { Text("0\(i + 1)").font(LF.mono(9)).foregroundStyle(HV.lime); Text(m.tag).font(LF.inter(800, 15)).foregroundStyle(.white) }.padding(12)
                            }.frame(width: 156, height: 100).background(HVL.card).clipShape(RoundedRectangle(cornerRadius: 20))
                        }.buttonStyle(HVPress(scale: 0.97))
                    }
                }.padding(.horizontal, 18)
            }
        }
    }
}

/// Albums(7日):日ごとに 3枚 + 「+N」
struct HVAlbums: View {
    let data: HomeV64LowerData
    let actions: HomeV64Actions
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HVLabel(text: "ALBUMS", trailing: "7 DAYS · RECAP ›")
            ForEach(Array(data.albums.enumerated()), id: \.element.id) { k, a in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(a.label).font(LF.serif(26)).tracking(-0.26).foregroundStyle(.white)
                        Spacer()
                        Text(a.left).font(LF.mono(9.5)).tracking(1.6).foregroundStyle(HVL.label)
                    }.padding(.horizontal, 18)
                    HStack(spacing: 10) {
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
                .opacity(1 - Double(k) * 0.07)
            }
        }
    }
}

/// On this day:1年 のこした 1枚
struct HVOnThisDay: View {
    let data: HomeV64LowerData
    var body: some View {
        if let o = data.onThisDay {
            VStack(alignment: .leading, spacing: 14) {
                HVLabel(text: "ON THIS DAY")
                HStack(spacing: 18) {
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color(hex: "F4F1EA"))
                        ZStack { Rectangle().fill(Color(hex: "3A3A3C")); if let img = o.photo { Image(uiImage: img).resizable().scaledToFill() } }.frame(width: 140, height: 118).clipped().offset(x: 7, y: 7).frame(maxHeight: .infinity, alignment: .top)
                        Text(o.date).font(LF.mono(9)).foregroundStyle(Color(hex: "FF9A3C")).padding(8)
                    }.frame(width: 154, height: 160).rotationEffect(.degrees(-4)).shadow(color: .black.opacity(0.6), radius: 14, y: 10)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(o.daysLeft) DAYS LEFT").font(LF.mono(10)).tracking(2).foregroundStyle(HVL.label)
                        HStack(spacing: 5) { Capsule().fill(.white).frame(width: 22, height: 6); Circle().fill(.white.opacity(0.3)).frame(width: 6, height: 6); Circle().fill(.white.opacity(0.3)).frame(width: 6, height: 6) }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.white).frame(width: 38, height: 38).background(Color.white.opacity(0.08), in: Circle())
                }.padding(.horizontal, 18)
            }
        }
    }
}

/// Friends カード(下)
struct HVFriendsCard: View {
    let input: HomeV64Input
    let actions: HomeV64Actions
    var body: some View {
        let took = input.friends.filter { $0.shots > 0 }.count
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                (Text("F").font(LF.serif(46, italic: true)).foregroundColor(HV.lime) + Text("riends").font(LF.serif(46)).foregroundColor(.white))
                Spacer()
                if took > 0 {
                    HStack(spacing: 6) { Circle().fill(Color(hex: "3BD35A")).frame(width: 9, height: 9); Text("\(took) shot today").font(LF.mono(12)).foregroundStyle(Color(hex: "7EE08F")) }
                        .padding(.horizontal, 12).frame(height: 36).background(Color(hex: "7EE08F").opacity(0.14), in: Capsule())
                }
                Image(systemName: "chevron.right").foregroundStyle(.white).frame(width: 38, height: 38).background(Color.white.opacity(0.08), in: Circle())
            }
            if input.requestCount > 0 {
                Button { Haptics.play(.sel); actions.openRequests() } label: { HStack(spacing: 10) {
                    HStack(spacing: -10) { ForEach(Array(input.requestFaces.prefix(3).enumerated()), id: \.offset) { i, f in
                        Circle().fill(f.color).frame(width: 30, height: 30).overlay(Circle().strokeBorder(.black, lineWidth: 2)) } }
                    Text("\(input.requestFaces.first?.initial ?? "") ほか から 申請").font(LF.inter(800, 15)).foregroundStyle(HV.ink)
                    Spacer()
                    Text("承認 ›").font(LF.mono(11)).foregroundStyle(HV.ink)
                }.padding(.horizontal, 14).frame(height: 46).background(HV.lime, in: Capsule()) }.buttonStyle(HVPress(scale: 0.98))
            }
            if input.friends.isEmpty {
                HStack { Text("No one yet").font(LF.inter(800, 16)).foregroundStyle(.white); Spacer(); Text("0/12").font(LF.serif(22, italic: true)).foregroundStyle(.white) }
                    .padding(16).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 20))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(input.friends.enumerated()), id: \.offset) { i, f in
                            VStack(alignment: .leading, spacing: 4) {
                                ZStack { Rectangle().fill(Color(hex: "3A3A3C")); if let img = f.image { Image(uiImage: img).resizable().scaledToFill() } }.frame(width: 96, height: 104).clipped()
                                Text(f.name).font(LF.serif(20, italic: false)).foregroundStyle(HV.ink)
                                HStack(spacing: 3) { ForEach(0..<3, id: \.self) { s in Capsule().fill(s < f.shots ? Color(hex: "3BD35A") : Color.black.opacity(0.12)).frame(width: 13, height: 5) } }
                            }.padding(8).frame(width: 112).background(Color(hex: "F4F1EA"), in: RoundedRectangle(cornerRadius: 6)).rotationEffect(.degrees(i % 2 == 0 ? -2 : 1.5))
                        }
                    }.padding(.vertical, 6)
                }
            }
            HStack(spacing: 8) {
                Button { Haptics.play(.sel); actions.addFriends() } label: {
                    HStack(spacing: 8) { Image(systemName: "plus").font(.system(size: 16, weight: .bold)); Text("Add").font(LF.inter(800, 17)) }
                        .foregroundStyle(.white).frame(width: 112, height: 54).background(Color.white.opacity(0.08), in: Capsule())
                }.buttonStyle(HVPress(scale: 0.97))
                HVCTA(title: "Open friends", width: 200) { actions.openFriends() }
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 30))
        .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(.white.opacity(0.1), lineWidth: 1))
        .padding(.horizontal, 14)
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
            Spacer().frame(height: 160)
        }
        .background(HVL.bg)
    }
}
