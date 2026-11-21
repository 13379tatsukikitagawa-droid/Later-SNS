import SwiftUI

// P04:Home の 下(スクロール した 所)。上から Today(今日の フィルム)→ Active → Yesterday → Albums → On this day → Friends。
// 見本:L01〜L11(mock/src/app.js の arcToday / arcActive / arcYesterday / arcMondo / arcAlbums / arcFriends)。背景は #0A0A0B。

struct HomeV64LowerData {
    struct Today { var thumbs: [UIImage?] = []; var times: [String] = []; var dates: [Date] = [] }
    struct Hero { var photo: UIImage?; var tag: String = "#朝"; var tagColor: Color = Color(hex: "9ED8FF"); var dateLabel = "NOV 15"; var moments = 0; var people = 0; var daysLeft = 6 }
    struct Tile: Identifiable { let id = UUID(); var photo: UIImage?; var name: String; var time: String?; var own = false; var kept = false }
    struct Album: Identifiable { let id = UUID(); var label: String; var left: String; var tiles: [UIImage?]; var more: Int; var hot = false }
    var today = Today()
    var hero: Hero?
    var tiles: [Tile] = []
    var albums: [Album] = []
    var onThisDay: (photo: UIImage?, daysLeft: Int, date: String)?
    var trips: [(id: UUID?, name: String, sub: String, cover: UIImage?, day: String, unread: Int)] = []
}

enum HVL {
    static let bg = Color(hex: "0A0A0B")
    static let line = Color.white.opacity(0.08)
    static let label = Color(hex: "8E8E93")
    static let card = Color(hex: "121214")

    /// v119 5章:アルバムの のこり(「あと 6日 ・ 金」/「あした 消える」)。2日 以下は ライム
    static func albumLeft(daysLeft: Int, date: Date) -> (text: String, hot: Bool) {
        if daysLeft <= 1 { return ("あした 消える", true) }
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "E"
        return ("あと \(daysLeft)日 ・ \(f.string(from: date))", daysLeft <= 2)
    }

    /// きのうの 曜日(「土曜日」)
    static func weekdayJA(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "EEEE"
        return f.string(from: date)
    }
}

struct HVLabel: View {
    let text: String
    var trailing: String? = nil
    var body: some View {
        // v119 5章:日本語 ・ 12.5pt 太字 ・ 灰色(等幅 ・ 広い 字間は やめる)
        HStack(alignment: .firstTextBaseline) {
            Text(text).font(Typo.ui(800, 12.5)).foregroundStyle(Color(hex: "8C8C93"))
            Spacer()
            if let trailing { Text(trailing).font(Typo.ui(700, 11.5)).foregroundStyle(Color(hex: "6E6E75")).lineLimit(1) }
        }
        .padding(.horizontal, 20)
    }
}

/// v121 2章 + v119 2章:Today の カード(すけない 地 ・ 3枠 = チェキ / ライムの「撮る」/ 点線 + 数字 ・ 進みの 線)
struct HVTodayPanel: View {
    let input: HomeV64Input
    let data: HomeV64LowerData
    let onShoot: () -> Void
    let onDevelop: () -> Void

    static let ground = Color(hex: "121014")

    var body: some View {
        let n = min(input.shotsUsed, 3)
        let md = { () -> String in let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: input.now) }()
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "Today").font(Typo.title(38)).tracking(Typo.titleTracking(38)).foregroundStyle(.white)
                Spacer()
                (Text(verbatim: "\(n)").font(Typo.title(36)).foregroundColor(HVCardTint.milk) + Text(verbatim: "/3").font(Typo.title(21)).foregroundColor(Color(hex: "6E6E75")))
            }
            HStack(spacing: 7) {
                Circle().fill(HV.lime).frame(width: 6, height: 6).shadow(color: HV.lime, radius: 4)
                Text(n > 0 ? "現像中 ・ \(md)" : "まだ 0枚 ・ \(md)").font(Typo.ui(700, 13)).foregroundStyle(Color(hex: "8C8C93")).lineLimit(1)
            }
            .padding(.top, 9)
            HStack(alignment: .top, spacing: 14) {
                ForEach(0..<3, id: \.self) { i in frame(i, n: n) }
            }
            .frame(height: 126)
            .padding(.top, 20)
            progress(n: n).padding(.top, 24)
            HStack {
                leftLine(n: n)
                Spacer(minLength: 8)
                Text(rightLine(n: n)).font(Typo.ui(700, 12.5)).foregroundStyle(HV.lime).lineLimit(1)
            }
            .padding(.top, 12)
        }
        .padding(.top, 22).padding(.horizontal, 20).padding(.bottom, 20)
        .background(Self.ground, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(.white.opacity(0.07), lineWidth: 1))
        .padding(.horizontal, 14)
    }

    // MARK: 3枠

    @ViewBuilder private func frame(_ i: Int, n: Int) -> some View {
        if i < n {
            Button { Haptics.play(.pop); onDevelop() } label: { cheki(i) }
                .buttonStyle(HVPress(scale: 0.96))
                .frame(maxWidth: .infinity)
        } else if i == n {
            Button { Haptics.play(.shutter); onShoot() } label: {
                VStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 26, weight: .bold))
                    Text("撮る").font(Typo.ui(800, 15))
                }
                .foregroundStyle(Color(hex: "111113"))
                .frame(maxWidth: .infinity).frame(height: 120)
            }
            .buttonStyle(HVLedgePress(face: HV.lime, ledge: Color(hex: "97C235"), radius: 20, depth: 6))
            .frame(maxWidth: .infinity)
            .accessibilityLabel("撮る")
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.white.opacity(0.16), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                Text(verbatim: "\(i + 1)").font(Typo.title(30)).foregroundStyle(.white.opacity(0.16))
            }
            .frame(maxWidth: .infinity).frame(height: 126)
            .accessibilityHidden(true)
        }
    }

    /// 撮った 枠 = チェキ(ミルクの 紙 ・ 写真は 上 6 / 横 6 / 下 24 ・ 下に 時間 と 現像の %)
    private func cheki(_ i: Int) -> some View {
        let tilt: [Double] = [-2.2, 1.6, -1.2]
        let p = developProgress(i)
        return VStack(spacing: 0) {
            ZStack {
                Color(hex: "D9D5CC")
                if let img = data.today.thumbs[safe: i] ?? nil { Image(uiImage: img).resizable().scaledToFill().blur(radius: 6).saturation(0.4) }
                // 白い まく(現像が すすむほど うすく)
                Color.white.opacity(0.78 - 0.5 * p)
            }
            .clipped()
            .padding([.top, .horizontal], 6)
            HStack {
                Text(data.today.times[safe: i] ?? "").font(Typo.ui(700, 10)).foregroundStyle(Color(hex: "111113"))
                Spacer(minLength: 0)
                Text(verbatim: "\(Int((p * 100).rounded()))%").font(Typo.ui(700, 10)).foregroundStyle(Color(hex: "8C8C93"))
            }
            .padding(.horizontal, 7).frame(height: 24)
        }
        .frame(height: 126)
        .background(HVCardTint.milk, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 6, y: 4)
        .rotationEffect(.degrees(tilt[i]))
        .accessibilityLabel("\(data.today.times[safe: i] ?? "") に 撮った")
    }

    // MARK: 進みの 線 と 下の 字

    private func progress(n: Int) -> some View {
        let p = n > 0 ? developProgress(0) : 0
        return GeometryReader { g in
            let w = g.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.1)).frame(height: 6)
                Capsule().fill(LinearGradient(colors: [Color(hex: "E4F9A8"), HV.lime], startPoint: .leading, endPoint: .trailing)).frame(width: max(6, w * p), height: 6)
                Circle().fill(HV.lime).frame(width: 14, height: 14).overlay(Circle().strokeBorder(Self.ground, lineWidth: 3).padding(-3))
                    .offset(x: min(w - 14, max(0, w * p - 7)))
            }
            .frame(height: 14)
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func leftLine(n: Int) -> some View {
        if n > 0 {
            (Text(data.today.times.first ?? "").foregroundColor(.white) + Text(" に 撮った").foregroundColor(Color(hex: "8C8C93"))).font(Typo.ui(700, 12.5)).lineLimit(1)
        } else {
            (Text(verbatim: "9:00").foregroundColor(.white) + Text(" から").foregroundColor(Color(hex: "8C8C93"))).font(Typo.ui(700, 12.5)).lineLimit(1)
        }
    }

    private func rightLine(n: Int) -> String {
        let cal = Calendar.current
        if n > 0 {
            let s = max(0, Int(nextOpen.timeIntervalSince(input.now)))
            return "あと \(s / 3600)h \((s % 3600) / 60)m で ひらく"
        }
        let end = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: input.now) ?? input.now)
        let s = max(0, Int(end.timeIntervalSince(input.now)))
        return "消灯 \(s / 3600)h \((s % 3600) / 60)m"
    }

    /// あしたの 9:00
    private var nextOpen: Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: input.now)) ?? input.now
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    /// 撮って から あしたの 9:00 までの うち、すすんだ わりあい(0〜1)
    private func developProgress(_ i: Int) -> Double {
        guard let t = data.today.dates[safe: i] else { return 0 }
        let total = nextOpen.timeIntervalSince(t)
        guard total > 0 else { return 1 }
        return min(1, max(0, input.now.timeIntervalSince(t) / total))
    }
}

/// v119 4章 + v121 4章:Trip の かたまり(Friends と 同じ 形の カード)。0件 = New trip の 行(高さ 150)/ ある 時 = カードの 中で 横スクロール
struct HVActiveRow: View {
    var body: some View { VStack(spacing: 0) { HVAnchor(id: "sec-active"); content } }
    let data: HomeV64LowerData
    let input: HomeV64Input
    let actions: HomeV64Actions

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HVBlockHeader(title: "Trip", action: actions.openTrip) { HVBlockLine(text: "旅行 ・ 合宿 ・ イベントを みんなで") }
                .padding(.horizontal, 20)
            if data.trips.isEmpty {
                newTripRow.padding(.horizontal, 16).padding(.top, 14)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(data.trips.enumerated()), id: \.offset) { _, t in tripCard(t) }
                        newTripTile
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 14)
            }
        }
        .padding(.top, 20).padding(.bottom, 14)
        .background(Color(hex: "111113"), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(.white.opacity(0.07), lineWidth: 1))
        .padding(.horizontal, 14)
    }

    /// 0件:New trip の 行(高さ 150 ・ 角丸 26 ・ 空色の うすい 光 ・ チェキ 3枚 0.9倍 ・ 右に 空色の + の 丸 52 ・ 段 5pt)
    private var newTripRow: some View {
        Button { Haptics.play(.pop); actions.openTrip() } label: {
            HStack(spacing: 0) {
                chekiFan.scaleEffect(0.9).frame(width: 112, height: 150)
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: "New trip").font(Typo.title(33)).tracking(Typo.titleTracking(33)).foregroundStyle(.white).lineLimit(1)
                    Text("2〜7日の アルバム").font(Typo.ui(700, 13)).foregroundStyle(Color(hex: "8C8C93")).lineLimit(1)
                }
                .padding(.leading, 16)
                Spacer(minLength: 6)
                ZStack {
                    Circle().fill(Color(hex: "4E9CD1")).offset(y: 5)
                    Circle().fill(HVCardTint.trip)
                    Image(systemName: "plus").font(.system(size: 20, weight: .bold)).foregroundStyle(Color(hex: "111113"))
                }
                .frame(width: 52, height: 52).padding(.trailing, 18)
            }
            .frame(height: 150)
            .background(Color(hex: "1A1A1D"), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .background(LinearGradient(colors: [HVCardTint.trip.opacity(0.16), HVCardTint.trip.opacity(0)], startPoint: .topLeading, endPoint: .center), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(LinearGradient(colors: [HVCardTint.trip.opacity(0.16), HVCardTint.trip.opacity(0)], startPoint: .topLeading, endPoint: .center).clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous)).allowsHitTesting(false))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(HVPress(scale: 0.97))
        .accessibilityLabel("New trip")
    }

    /// チェキ 3枚の 扇
    private var chekiFan: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                VStack(spacing: 0) {
                    Group { if let img = input.tripSamples[safe: i] { Image(uiImage: img).resizable().scaledToFill() } else { Color(hex: "3A3A3C") } }
                        .frame(width: 56, height: 58).clipped().padding([.top, .horizontal], 4)
                    Spacer(minLength: 0)
                }
                .frame(width: 64, height: 78)
                .background(Color(hex: "F4F1EA"), in: RoundedRectangle(cornerRadius: 3))
                .shadow(color: .black.opacity(0.45), radius: 6, y: 4)
                .rotationEffect(.degrees([-8.0, 6.0, -1.0][i]))
                .offset(x: [-14.0, 14.0, 0][i], y: [2.0, 2.0, -2.0][i])
            }
        }
        .offset(x: 8)
    }

    private func tripCard(_ t: (id: UUID?, name: String, sub: String, cover: UIImage?, day: String, unread: Int)) -> some View {
        Button { Haptics.play(.pop); if let id = t.id { actions.openTripHome(id) } else { actions.openTrip() } } label: {
            ZStack(alignment: .topLeading) {
                Color(hex: "1A1A1D")
                if let c = t.cover { Image(uiImage: c).resizable().scaledToFill().frame(width: 180, height: 220).clipped() }
                LinearGradient(colors: [.black.opacity(0.3), .clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                Text(t.day).font(Typo.ui(800, 11)).foregroundStyle(HVCardTint.trip).padding(.horizontal, 8).frame(height: 22).background(Color(hex: "111113").opacity(0.72), in: Capsule()).padding(14)
                VStack(alignment: .leading, spacing: 4) {
                    Spacer()
                    Text(t.name).font(Typo.mincho(26)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                    Text(t.sub).font(Typo.ui(700, 11.5)).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                }.padding(14)
                if t.unread > 0 { Text("\(t.unread)").font(Typo.ui(800, 12)).foregroundStyle(.white).frame(width: 24, height: 24).background(HVCardTint.badge, in: Circle()).frame(maxWidth: .infinity, alignment: .trailing).padding(14) }
            }
            .frame(width: 180, height: 220).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(HVPress(scale: 0.97))
    }

    private var newTripTile: some View {
        Button { Haptics.play(.tick); actions.openTrip() } label: {
            VStack(spacing: 10) {
                chekiFan.scaleEffect(0.8).frame(height: 96)
                Text(verbatim: "New trip").font(Typo.title(26)).foregroundStyle(.white).lineLimit(1)
                ZStack {
                    Circle().fill(Color(hex: "4E9CD1")).offset(y: 4)
                    Circle().fill(HVCardTint.trip)
                    Image(systemName: "plus").font(.system(size: 16, weight: .bold)).foregroundStyle(Color(hex: "111113"))
                }.frame(width: 40, height: 40)
            }
            .frame(width: 150, height: 220)
            .background(Color(hex: "1A1A1D"), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(HVPress(scale: 0.97))
        .accessibilityLabel("New trip")
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
            HVAnchor(id: "sec-yesterday", locked: input.locked)
            Rectangle().fill(HVL.line).frame(height: 1).padding(.horizontal, 18)
            HVLabel(text: "きのう", trailing: HVL.weekdayJA(Calendar.current.date(byAdding: .day, value: -1, to: input.now) ?? input.now)).padding(.top, 8).padding(.bottom, 6)
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
                HStack(spacing: 8) { Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)); Text("shoot today to open").font(Typo.ui(800, 13)) }
                    .foregroundStyle(HV.ink).frame(width: 177, height: 38).background(.white, in: Capsule()).offset(x: 92, y: 150)
            }
            let h = data.hero
            Text("Yesterday").font(Typo.title(54)).foregroundStyle(.white).frame(width: 362, height: 78).offset(y: 206)
            Text(h?.dateLabel ?? "").font(Typo.ui(700, 10.5)).foregroundStyle(.white.opacity(0.7)).frame(width: 362).offset(y: 268)
            stat("\(h?.moments ?? 0)", "枚").frame(width: 100).offset(x: 31, y: 296)
            ZStack { Ellipse().stroke(HV.lime, lineWidth: 2.5).frame(width: 68, height: 46).rotationEffect(.degrees(-4)); stat("\(h?.daysLeft ?? 6)日", "のこり") }.frame(width: 100).offset(x: 131, y: 296)
            stat("\(h?.people ?? 0)", "人 ›").frame(width: 100).offset(x: 231, y: 296)
            // v119:Mondo の ボタン → 「きのうを ひらく」(きのうの 画面へ)
            Button { Haptics.play(.pop); actions.openYesterday() } label: {
                Text("きのうを ひらく").font(Typo.ui(800, 14.5)).foregroundStyle(Color(hex: "111111"))
                    .frame(width: 268, height: 54).background(.white, in: Capsule())
            }
            .buttonStyle(HVPress(scale: 0.97))
            .offset(x: 16, y: 382)
            Image(systemName: "bubble.left").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white).frame(width: 54, height: 54).background(Color.white.opacity(0.12), in: Circle()).offset(x: 292, y: 382)
            if !locked, let h { Text(h.tag).font(Typo.ui(900, 14)).foregroundStyle(HV.ink).padding(.horizontal, 12).padding(.vertical, 8).background(h.tagColor, in: RoundedRectangle(cornerRadius: 12)).rotationEffect(.degrees(8)).offset(x: 293, y: 18) }
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
                    .overlay(Text("TODAY'S 1ST").font(Typo.label(9)).tracking(1.6).foregroundStyle(HV.lime).padding(.bottom, 12), alignment: .bottom)
            }.frame(height: 150).padding(.top, 26)
            Text("Yesterday").font(Typo.title(52)).tracking(-1).foregroundStyle(.white).padding(.top, 40)
            Text("今日 撮った 1枚が、あしたの 朝 9:00 に\nここで ひらきます。").font(Typo.ui(500, 13)).foregroundStyle(.white.opacity(0.66)).multilineTextAlignment(.center).lineSpacing(4).padding(.top, 30)
            HStack(spacing: 10) {
                HVLiveDot()
                Text("9:00 まで \(sec / 3600)h \(String(format: "%02d", (sec % 3600) / 60))m").font(Typo.label(11, bold: true).italic()).tracking(1.4).foregroundStyle(.white.opacity(0.85))
            }.padding(.horizontal, 18).frame(height: 34).background(Color.white.opacity(0.06), in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1)).padding(.vertical, 20)
        }
        .frame(width: 362).background(Color(hex: "161618"), in: RoundedRectangle(cornerRadius: 30))
        .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(.white.opacity(0.08), lineWidth: 1)).padding(.horizontal, 14)
    }

    private func stat(_ n: String, _ l: String) -> some View {
        VStack(spacing: 2) { Text(n).font(Typo.title(31)).foregroundStyle(.white); Text(l).font(Typo.ui(700, 11.5)).foregroundStyle(.white.opacity(0.62)) }
    }

    private func tile(_ t: HomeV64LowerData.Tile, locked: Bool) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(hex: "161618"))
            if let img = t.photo { Image(uiImage: img).resizable().scaledToFill().blur(radius: locked ? 14 : 0).saturation(locked ? 0.4 : 1) }
            LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .center, endPoint: .bottom)
            HStack {
                if !locked { Text(t.own ? "わたし." : "\(t.name).").font(Typo.title(21)).foregroundStyle(.white).lineLimit(1) }
                Spacer()
                if locked { Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.white) }
                else if let tm = t.time { Text(tm).font(Typo.label(9.5)).foregroundStyle(Color(hex: "FF9A3C")) }
            }.padding(14)
        }
        .frame(height: 212).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .overlay(alignment: .topTrailing) { if t.own { Image(systemName: "star").font(.system(size: 15, weight: .bold)).foregroundStyle(Color(hex: "FFD60A")).padding(12) } }
    }
}

/// セクションの 頭に 置く 目印(DEBUG の 位置あわせ ・ 目次から の スクロール 用)
struct HVAnchor: View {
    let id: String
    /// かぎ付き(撮る まえの Yesterday ・ Mondo)= knock
    var locked = false
    var body: some View { Color.clear.frame(height: 0).id(id).hapticSection(id, locked: locked) }
}

/// Albums(7日):日ごとに 3枚 + 「+N」(4列)
struct HVAlbums: View {
    let data: HomeV64LowerData
    let actions: HomeV64Actions
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HVAnchor(id: "sec-albums")
            Rectangle().fill(HVL.line).frame(height: 1).padding(.horizontal, 18)
            HVLabel(text: "アルバム", trailing: "7日で 消える ・ まとめ ›").padding(.top, 14)
            ForEach(Array(data.albums.enumerated()), id: \.element.id) { k, a in
                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(a.label).font(Typo.title(25)).tracking(Typo.titleTracking(25)).foregroundStyle(.white).frame(height: 25)
                        Spacer()
                        Text(a.left).font(Typo.ui(700, 11)).foregroundStyle(a.hot ? HV.lime : Color(hex: "55555B")).lineLimit(1)
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
                            Text("+\(a.more)").font(Typo.ui(600, 15)).foregroundStyle(.white)
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
                HVLabel(text: "この日", trailing: "1か月 前").padding(.top, 20)
                HStack(alignment: .top, spacing: 18) {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color(hex: "F4F1EA"))
                        ZStack { Rectangle().fill(Color(hex: "3A3A3C")); if let img = o.photo { Image(uiImage: img).resizable().scaledToFill() } }
                            .frame(width: 136, height: 146).clipped().offset(x: 9, y: 9)
                        Text(o.date).font(Typo.label(9)).foregroundStyle(Color(hex: "FF9A3C")).offset(x: 86, y: 134)
                        Image(systemName: "sparkle").font(.system(size: 18, weight: .bold)).foregroundStyle(Color(hex: "FFD60A")).offset(x: 10, y: 160)
                    }.frame(width: 154, height: 186).rotationEffect(.degrees(-4)).shadow(color: .black.opacity(0.6), radius: 14, y: 10)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Oct 17").font(Typo.title(44)).tracking(-0.9).foregroundStyle(.white).padding(.top, 14)
                        Text("1か月 前").font(Typo.ui(700, 14)).foregroundStyle(HVL.label)
                        ZStack(alignment: .leading) { Capsule().fill(Color.white.opacity(0.08)).frame(height: 3); Capsule().fill(HV.lime).frame(width: 150, height: 3) }.padding(.top, 14)
                        Text("あと \(o.daysLeft)日").font(Typo.ui(700, 12)).foregroundStyle(HVL.label)
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
        VStack(alignment: .leading, spacing: 14) {
            HVTodayPanel(input: input, data: data, onShoot: actions.shoot, onDevelop: actions.openDevelop).id("today")
            HVFriendsCard(input: input, actions: actions)   // v95-9:今日の フィルムの すぐ 下
            HVActiveRow(data: data, input: input, actions: actions)
            HVYesterdayBlock(input: input, data: data, actions: actions)
            if !input.isFirstDay {
                HVAlbums(data: data, actions: actions)
                HVOnThisDay(data: data)
            }
            Spacer().frame(height: 404)
        }
        .background(alignment: .top) { VStack(spacing: 0) { Color.clear.frame(height: 90); HVL.bg } }
    }
}
