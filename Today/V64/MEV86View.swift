import SwiftUI
import SwiftData

// P19(v75 C)+ P29(v86):ME = Recap が 主役。ヒーロー(今週 ・ 現像 ・ Ken Burns)→ 作成中 → Recaps → 60日の 縦線 → アルバム → 数字。
// 1日の 全画面 ・ Recap の 再生(ストーリーの 形)。見本:F09 F10 F13 F14 F15〜F18。写真は 端末の 自分の 写真から(サムネイルを 小さく 読む)。

struct MEV86Shot: Identifiable, Equatable {
    let id: String
    var date: Date
    var tag: String?
    var kept: Bool
    var image: UIImage?
    static func == (a: MEV86Shot, b: MEV86Shot) -> Bool { a.id == b.id && a.kept == b.kept }
}

struct MEV86Data {
    var shots: [MEV86Shot] = []
    var recaps: [RecapManifest] = []
    var now = Date()
    var year: Int { Calendar.current.component(.year, from: now) }
    var shotCount: Int { shots.count }
    var dayCount: Int { Set(shots.map { Calendar.current.startOfDay(for: $0.date) }).count }
    var keptCount: Int { shots.filter(\.kept).count }
    func shot(_ id: String) -> MEV86Shot? { shots.first { $0.id == id } }
    func shots(on day: Date) -> [MEV86Shot] { shots.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }.sorted { $0.date < $1.date } }
}

struct MEV86View: View {
    var data: MEV86Data
    var onBack: () -> Void = {}
    var onShoot: () -> Void = {}
    var onKeep: (String) -> Void = { _ in }
    var onSeen: (String) -> Void = { _ in }
    /// DEBUG
    var startRecap: String? = nil
    var startDay: Date? = nil
    var startPlay = false
    var startPlayT: Double? = nil
    var startScrollY: CGFloat? = nil
    var startScrub: Int? = nil
    var startMonth: Date? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var pos = ScrollPosition()
    @State private var playing: RecapManifest?
    @State private var dayFull: Date?
    @State private var month: Date = Date()
    @State private var scrubDay: Int = 0
    @State private var appeared = false
    @State private var seeded = false

    private var cal: Calendar { Calendar.current }
    private var hero: RecapManifest? { data.recaps.first }

    var body: some View {
        ZStack {
            Color(hex: "0A0A0B").ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header.rise(appeared, 0)
                    if let hero { heroCard(hero).rise(appeared, 1) }
                    building.padding(.horizontal, 16).padding(.top, 12).rise(appeared, 2)
                    recaps.rise(appeared, 3)
                    scrub.rise(appeared, 4)
                    album.rise(appeared, 5)
                    statsRow.padding(.horizontal, 16).padding(.top, 28).rise(appeared, 6)
                    Color.clear.frame(height: 80)
                }
            }
            .scrollPosition($pos)
            .ignoresSafeArea(edges: .top)
            if let day = dayFull { MEDayFull(day: day, shots: data.shots(on: day), onClose: { withAnimation(.easeOut(duration: 0.3)) { dayFull = nil } }, onKeep: onKeep).transition(.opacity.combined(with: .scale(scale: 1.04))).zIndex(5) }
            if let r = playing { RecapPlayer(recap: r, data: data, debugT: startPlayT, onClose: { withAnimation(.easeOut(duration: 0.3)) { playing = nil } }, onEnd: { onSeen(r.id) }).transition(.scale(scale: 0.92).combined(with: .opacity)).zIndex(6) }
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            guard !seeded else { return }
            seeded = true
            month = startMonth ?? data.now
            if let id = startRecap, let r = data.recaps.first(where: { $0.id == id }), startPlay { playing = r }
            else if startPlay, let r = hero { playing = r }
            if let d = startDay { dayFull = d }
            withAnimation(.easeOut(duration: 0.56)) { appeared = true }
            if let y = startScrollY { DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { pos.scrollTo(y: y) } }
        }
    }

    // MARK: ヘッダー

    private var header: some View {
        HStack(alignment: .center) {
            Button { Haptics.play(.tick); onBack() } label: {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44)
                    .background(.white.opacity(0.1), in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            }.buttonStyle(HVPress(scale: 0.92)).accessibilityLabel("もどる")
            Text("ME").font(Typo.ui(900, 40)).tracking(-2).foregroundStyle(.white).padding(.leading, 12)
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(data.shotCount) SHOTS").font(Typo.label(11)).tracking(2.2).foregroundStyle(.white.opacity(0.45))
                Text(String(data.year)).font(Typo.ui(900, 24)).foregroundStyle(.white)
            }
        }.padding(.horizontal, 16).padding(.top, 54).padding(.bottom, 16)
    }

    // MARK: ヒーロー(今週の Recap)

    private func heroCard(_ r: RecapManifest) -> some View {
        let w = UIScreen.main.bounds.width - 32
        return Button { Haptics.play(.projector); withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) { playing = r } } label: {
            ZStack(alignment: .topLeading) {
                KenBurns(ids: r.photoIDs, data: data, develop: r.state == .ready, active: scenePhase == .active && !reduceMotion).frame(width: w, height: w * 1.25)
                LinearGradient(stops: [.init(color: .black.opacity(0.55), location: 0), .init(color: .clear, location: 0.3), .init(color: .clear, location: 0.55), .init(color: .black.opacity(0.82), location: 1)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        if r.state == .ready { Text("NEW").font(Typo.ui(900, 12)).foregroundStyle(HV.ink).padding(.horizontal, 12).frame(height: 28).background(HV.lime, in: Capsule()) }
                        else { Text("▶ 見た").font(Typo.ui(800, 11)).foregroundStyle(.white).padding(.horizontal, 12).frame(height: 28).background(.white.opacity(0.2), in: Capsule()) }
                        Text("RECAP ・ \(Self.range(r))").font(Typo.label(10)).tracking(1.6).foregroundStyle(.white)
                    }
                    HStack(spacing: 4) { ForEach(0..<7, id: \.self) { i in Capsule().fill(.white.opacity(Self.hasDay(r, i, data) ? 0.9 : 0.28)).frame(height: 3) } }
                    Spacer()
                    Text("Your").font(Typo.title(46)).foregroundStyle(.white).frame(height: 44, alignment: .leading)
                    Text("week.").font(Typo.title(46, italic: true)).foregroundStyle(HV.lime).frame(height: 46, alignment: .leading)
                    HStack(spacing: 8) {
                        chip("\(r.shots) SHOTS"); chip("\(r.days) DAYS"); if let t = r.topTag { chip("#\(t)") }
                    }
                }.padding(16)
                PlayButton().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(18)
            }
            .frame(width: w, height: w * 1.25).clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }.buttonStyle(HVPress(scale: 0.985)).padding(.horizontal, 16).accessibilityLabel("Recap を 再生")
    }

    private func chip(_ t: String) -> some View {
        Text(t).font(Typo.label(11)).tracking(0.8).fontWeight(.bold).foregroundStyle(.white).padding(.horizontal, 12).frame(height: 32).background(.black.opacity(0.42), in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
    }

    static func range(_ r: RecapManifest) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "MMM d"
        let g = DateFormatter(); g.locale = Locale(identifier: "en_US"); g.dateFormat = "d"
        return r.kind == .month ? { f.dateFormat = "MMM yyyy"; return f.string(from: r.start).uppercased() }() : "\(f.string(from: r.start).uppercased())–\(g.string(from: r.end))"
    }
    static func hasDay(_ r: RecapManifest, _ i: Int, _ d: MEV86Data) -> Bool {
        let cal = Calendar.current
        guard let day = cal.date(byAdding: .day, value: i, to: r.start) else { return false }
        return r.photoIDs.contains { id in d.shot(id).map { cal.isDate($0.date, inSameDayAs: day) } ?? false }
    }

    // MARK: 次の Recap(作成中)

    private var building: some View {
        let b = RecapRules.building(now: data.now)
        let weekStart = RecapRules.weekStart(of: data.now)
        return HStack(spacing: 14) {
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 4)
                Circle().trim(from: 0, to: CGFloat(b.dayNumber) / 7).stroke(HV.lime, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: -2) { Text("\(b.dayNumber)").font(Typo.ui(900, 17)).foregroundStyle(.white); Text("/7").font(Typo.label(9)).foregroundStyle(.white.opacity(0.5)) }
            }.frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("次の Recap を つくって います").font(Typo.ui(800, 13)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
                Text("あと \(b.daysLeft)日 ・ \(b.dueText)").font(Typo.label(10.5)).lineLimit(1).minimumScaleFactor(0.8).foregroundStyle(.white.opacity(0.45))
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    let day = cal.date(byAdding: .day, value: i, to: weekStart) ?? weekStart
                    let shot = data.shots(on: day).last
                    let isToday = cal.isDate(day, inSameDayAs: data.now)
                    ZStack {
                        RoundedRectangle(cornerRadius: 3).fill(.white.opacity(day > data.now ? 0.07 : 0.16))
                        if let im = shot?.image { Image(uiImage: im).resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: 3)) }
                        if shot != nil { RoundedRectangle(cornerRadius: 3).strokeBorder(HV.lime, lineWidth: 1.5) }
                        else if isToday { RoundedRectangle(cornerRadius: 3).strokeBorder(HV.lime, lineWidth: 1.5).padding(2) }
                    }.frame(width: 9, height: 26)
                }
            }
        }.padding(.horizontal, 14).frame(height: 68).background(Color(hex: "121315"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: Recaps(これまで)

    private var recaps: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recaps").font(Typo.title(30)).foregroundStyle(.white)
                Spacer()
                Text("\(data.recaps.count) RECAPS").font(Typo.label(11)).tracking(2).foregroundStyle(.white.opacity(0.4))
            }.padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(data.recaps.sorted { ($0.kind == .month ? 0 : 1, $1.start) < ($1.kind == .month ? 0 : 1, $0.start) }) { r in recapCard(r) }
                }.scrollTargetLayout().padding(.horizontal, 0)
            }.scrollTargetBehavior(.viewAligned)
        }.padding(.top, 34)
    }

    private func recapCard(_ r: RecapManifest) -> some View {
        let w: CGFloat = r.kind == .month ? 150 : 124
        let cover = data.shot(r.cover)?.image
        return Button { Haptics.play(.projector); withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) { playing = r } } label: {
            ZStack(alignment: .topLeading) {
                Color(hex: "2A2326")
                if let cover { Image(uiImage: cover).resizable().scaledToFill() }
                LinearGradient(colors: [.black.opacity(0.35), .clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                if r.kind == .week { HStack(spacing: 3) { ForEach(0..<7, id: \.self) { i in Capsule().fill(.white.opacity(Self.hasDay(r, i, data) ? 0.9 : 0.3)).frame(height: 2.5) } }.padding(.horizontal, 12).padding(.top, 12) }
                VStack(alignment: .leading, spacing: 2) {
                    Spacer()
                    if r.kind == .month {
                        Text("MONTH").font(Typo.label(9)).tracking(1.8).foregroundStyle(.white.opacity(0.7))
                        let f = DateFormatter(); let _ = f.locale = Locale(identifier: "en_US"); let _ = f.dateFormat = "MMM"
                        Text(f.string(from: r.start).uppercased()).font(Typo.title(40)).foregroundStyle(.white)
                        Text(String(Calendar.current.component(.year, from: r.start))).font(Typo.label(10)).foregroundStyle(.white.opacity(0.7))
                    } else {
                        Text("WEEK").font(Typo.label(9)).tracking(1.8).foregroundStyle(.white.opacity(0.7))
                        Text(Self.range(r)).font(Typo.ui(800, 14)).foregroundStyle(.white)
                        Text("\(r.shots) shots").font(Typo.label(10)).foregroundStyle(.white.opacity(0.7))
                    }
                }.padding(12)
            }
            .frame(width: w, height: w * 14 / 9).clipShape(RoundedRectangle(cornerRadius: r.kind == .month ? 22 : 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: r.kind == .month ? 22 : 18, style: .continuous).strokeBorder(r.kind == .month ? HV.lime : .clear, lineWidth: 1.5))
        }.buttonStyle(HVPress(scale: 0.96)).padding(.leading, r.id == data.recaps.first?.id ? 16 : 0)
    }

    // MARK: 60日の 縦線

    private var scrub: some View {
        let days = (0..<60).map { cal.date(byAdding: .day, value: -(60 - $0), to: cal.startOfDay(for: data.now)) ?? data.now }
        let sel = days.indices.contains(scrubDay) ? scrubDay : 59
        let selDay = days[sel]
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Circle().fill(HV.lime).frame(width: 7, height: 7)
                Text("60 DAYS").font(Typo.label(11)).tracking(2).foregroundStyle(.white.opacity(0.6))
                Spacer()
                let sf = DateFormatter(); let _ = sf.dateFormat = "M/d"
                Text(sf.string(from: selDay)).font(Typo.ui(900, 22)).foregroundStyle(.white)
            }.padding(.horizontal, 22).padding(.top, 16)
            GeometryReader { g in
                let bw = g.size.width / 60
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        ForEach(0..<60, id: \.self) { i in
                            let n = data.shots(on: days[i]).count
                            Rectangle().fill(n == 0 ? Color.white.opacity(0.1) : (i % 2 == 0 ? Color(hex: "3BD35A") : HV.lime)).frame(width: max(1.2, bw - 1.6), height: n == 0 ? 22 : CGFloat(34 + n * 16)).frame(width: bw, height: 100, alignment: .bottom)
                        }
                    }
                    Rectangle().fill(.white).frame(width: 2, height: 100).offset(x: CGFloat(sel) * bw + bw / 2 - 1)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    let i = max(0, min(59, Int(v.location.x / bw)))
                    if i != scrubDay { scrubDay = i; Haptics.play(.tick) }
                })
            }.frame(height: 100).padding(.horizontal, 14).padding(.top, 8)
            HStack { Text("60 DAYS AGO"); Spacer(); Text("30"); Spacer(); Text("YESTERDAY") }.font(Typo.label(10)).tracking(1.6).foregroundStyle(.white.opacity(0.35)).padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 14)
        }
        .background(Color(hex: "121315"), in: RoundedRectangle(cornerRadius: 24, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 16).padding(.top, 34)
        .overlay(alignment: .bottom) { Color.clear.frame(height: 0) }
        .onAppear { if scrubDay == 0 { scrubDay = startScrub ?? 59 } }
        .background(Color.clear)
        .modifier(DaySection(day: selDay, data: data, open: { d in Haptics.play(.pop); withAnimation(.easeOut(duration: 0.45)) { dayFull = d } }))
    }

    // MARK: アルバム(月の カレンダー)

    private var album: some View {
        let first = cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month
        let count = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let lead = cal.component(.weekday, from: first) - 1
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "yyyy ・ MMM"
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Album").font(Typo.title(40)).foregroundStyle(.white)
                Spacer()
                monthButton("chevron.left", -1)
                Text(f.string(from: first).uppercased()).font(Typo.label(12)).tracking(2).foregroundStyle(.white.opacity(0.7)).frame(width: 110)
                monthButton("chevron.right", 1)
            }.padding(.horizontal, 16).padding(.top, 34)
            HStack(spacing: 4) { ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { Text($0).font(Typo.ui(600, 12)).foregroundStyle(.white.opacity(0.4)).frame(maxWidth: .infinity) } }.padding(.horizontal, 16).padding(.top, 20)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(0..<lead, id: \.self) { _ in Color.clear.aspectRatio(3 / 4, contentMode: .fit) }
                ForEach(1...count, id: \.self) { n in
                    let day = cal.date(byAdding: .day, value: n - 1, to: first) ?? first
                    albumCell(n, day)
                }
            }.padding(.horizontal, 16).padding(.top, 8).id(first)
                .transition(.push(from: .trailing))
        }
    }

    private func albumCell(_ n: Int, _ day: Date) -> some View {
        let list = data.shots(on: day)
        let future = day > data.now
        let last = list.last(where: \.kept) ?? list.last
        return Button { if !list.isEmpty { Haptics.play(.pop); withAnimation(.easeOut(duration: 0.45)) { dayFull = day } } } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: "141517"))
                if future { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white.opacity(0.07), lineWidth: 1) }
                if let im = last?.image { Image(uiImage: im).resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous)) }
                Text("\(n)").font(Typo.ui(800, 11)).foregroundStyle(.white.opacity(list.isEmpty ? 0.3 : 1)).padding(5)
                if list.count > 1 { Text("\(list.count)").font(Typo.ui(800, 10)).foregroundStyle(.white).frame(width: 18, height: 18).background(.black.opacity(0.6), in: Circle()).frame(maxWidth: .infinity, alignment: .topTrailing).padding(4) }
                if list.contains(where: \.kept) { Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(HV.lime).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(5) }
            }.aspectRatio(3 / 4, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }.buttonStyle(.plain)
    }

    private func monthButton(_ icon: String, _ d: Int) -> some View {
        Button { Haptics.play(.sel); withAnimation(.timingCurve(0.3, 1, 0.4, 1, duration: 0.38)) { month = cal.date(byAdding: .month, value: d, to: month) ?? month } } label: {
            Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(.white).frame(width: 34, height: 34).background(.white.opacity(0.1), in: Circle())
        }.buttonStyle(HVPress(scale: 0.92))
    }

    // MARK: 数字

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat("\(data.shotCount)", "SHOTS", HV.lime)
            Rectangle().fill(.white.opacity(0.08)).frame(width: 1)
            stat("\(data.dayCount)", "DAYS", .white)
            Rectangle().fill(.white.opacity(0.08)).frame(width: 1)
            stat("\(data.keptCount)", "KEPT ★", .white)
        }.frame(height: 72).background(Color(hex: "121315"), in: RoundedRectangle(cornerRadius: 24, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
    }
    private func stat(_ n: String, _ l: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(n).font(Typo.ui(900, 34)).foregroundStyle(c); Text(l).font(Typo.label(10)).tracking(2).foregroundStyle(.white.opacity(0.45)) }.padding(.horizontal, 20).frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 縦線で えらんだ 日の 見出し + 3枚(押すと 1日の 全画面)
private struct DaySection: ViewModifier {
    let day: Date
    let data: MEV86Data
    let open: (Date) -> Void
    func body(content: Content) -> some View {
        let list = data.shots(on: day)
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "E M/d"
        let g = DateFormatter(); g.locale = Locale(identifier: "en_US"); g.dateFormat = "EEE ・ MMM d"
        return VStack(alignment: .leading, spacing: 0) {
            content
            HStack(alignment: .firstTextBaseline) {
                Text(f.string(from: day)).font(Typo.title(40)).foregroundStyle(.white)
                Spacer()
                Text("\(g.string(from: day).uppercased()) ・ \(list.count) SHOTS").font(Typo.label(11)).tracking(1.6).foregroundStyle(HV.lime)
            }.padding(.horizontal, 16).padding(.top, 30)
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Button { open(day) } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: "141517"))
                            if list.indices.contains(i), let im = list[i].image { Image(uiImage: im).resizable().scaledToFill() }
                        }.aspectRatio(3 / 4, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
                    }.buttonStyle(HVPress(scale: 0.97))
                }
            }.padding(.horizontal, 16).padding(.top, 14)
        }
    }
}

/// 再生ボタン(外へ 広がる 輪 ・ 2.2秒)
private struct PlayButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ZStack {
            if !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: scenePhase != .active)) { ctx in
                    let u = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.2) / 2.2
                    Circle().stroke(HV.lime.opacity(0.5 * (1 - u)), lineWidth: 1.5).frame(width: 58 + 22 * u, height: 58 + 22 * u)
                }
            } else { Circle().stroke(HV.lime.opacity(0.4), lineWidth: 1.5).frame(width: 72, height: 72) }
            Circle().fill(.black.opacity(0.35)).background(.ultraThinMaterial, in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1.5)).frame(width: 58, height: 58)
            Image(systemName: "play.fill").font(.system(size: 20)).foregroundStyle(.white).offset(x: 2)
        }.frame(width: 80, height: 80)
    }
}

/// ヒーローの Ken Burns(2.6秒 ごとに 入れかわる ・ できた ばかりは 現像)
struct KenBurns: View {
    let ids: [String]
    let data: MEV86Data
    var develop = false
    var active = true
    @State private var started = Date()
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 20)) { ctx in
            let t = active ? ctx.date.timeIntervalSince(started) : 0
            let n = max(1, ids.count)
            let i = Int(t / 2.6) % n, u = (t.truncatingRemainder(dividingBy: 2.6)) / 2.6
            let prev = (i + n - 1) % n
            let dv = develop ? min(1, max(0, (t - 0.3) / 1.8)) : 1
            ZStack {
                Color(hex: "2A2326")
                if n > 1, t > 2.6, let im = data.shot(ids[prev])?.image { Image(uiImage: im).resizable().scaledToFill().opacity(max(0, 1 - u * 2.6 / 0.9)).scaleEffect(1.02) }
                if let im = data.shot(ids[i])?.image {
                    Image(uiImage: im).resizable().scaledToFill().scaleEffect(1.12 - 0.10 * u).opacity(t > 2.6 ? min(1, u * 2.6 / 0.9) : 1)
                        .blur(radius: 16 * (1 - dv)).grayscale(1 - dv).brightness(-0.25 * (1 - dv)).colorMultiply(Color(red: 1, green: 0.94 + 0.06 * dv, blue: 0.82 + 0.18 * dv))
                }
            }.clipped()
        }
    }
}

/// 1日の 全画面(横に ページング ・ ★ で のこす)
struct MEDayFull: View {
    let day: Date
    let shots: [MEV86Shot]
    var onClose: () -> Void
    var onKeep: (String) -> Void
    @State private var page = 0
    @State private var kept: Set<String> = []
    var body: some View {
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "日 M/d"
        let g = DateFormatter(); g.locale = Locale(identifier: "en_US"); g.dateFormat = "EEE"
        let t = DateFormatter(); t.dateFormat = "HH:mm"
        let cur = shots.indices.contains(page) ? shots[page] : nil
        return ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            HStack {
                Button { Haptics.play(.tick); onClose() } label: { Image(systemName: "xmark").font(.system(size: 16, weight: .black)).foregroundStyle(.white).frame(width: 44, height: 44).background(.white.opacity(0.12), in: Circle()) }.buttonStyle(.plain)
                Spacer()
                VStack(spacing: 3) {
                    Text(f.string(from: day)).font(Typo.ui(900, 22)).foregroundStyle(.white)
                    Text("\(g.string(from: day).uppercased()) ・ \(shots.count) SHOTS").font(Typo.label(11)).tracking(1.5).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Button { if let cur { Haptics.play(.pop); if kept.contains(cur.id) { kept.remove(cur.id) } else { kept.insert(cur.id) }; onKeep(cur.id) } } label: {
                    Image(systemName: (cur.map { kept.contains($0.id) || $0.kept } ?? false) ? "star.fill" : "star").font(.system(size: 17)).foregroundStyle((cur.map { kept.contains($0.id) || $0.kept } ?? false) ? HV.lime : .white).frame(width: 44, height: 44).background(.white.opacity(0.12), in: Circle())
                }.buttonStyle(.plain)
            }.padding(.horizontal, 16).padding(.top, 56)
            TabView(selection: $page) {
                ForEach(Array(shots.enumerated()), id: \.element.id) { i, s in
                    ZStack { Color(hex: "2A2326"); if let im = s.image { Image(uiImage: im).resizable().scaledToFill() } }
                        .frame(width: UIScreen.main.bounds.width - 32, height: (UIScreen.main.bounds.width - 32) * 4 / 3).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)).tag(i)
                }
            }.tabViewStyle(.page(indexDisplayMode: .never)).frame(height: (UIScreen.main.bounds.width - 32) * 4 / 3 + 10).padding(.top, 125)
            .onChange(of: page) { _, _ in Haptics.play(.tick) }
            VStack(spacing: 12) {
                Spacer()
                HStack(spacing: 8) {
                    if let cur { Text(t.string(from: cur.date)).font(Typo.label(12)).foregroundStyle(HV.lime).padding(.horizontal, 12).frame(height: 30).background(.white.opacity(0.1), in: Capsule()) }
                    if let tag = cur?.tag { Text("#\(tag)").font(Typo.ui(800, 13)).foregroundStyle(.white).padding(.horizontal, 12).frame(height: 30).background(.white.opacity(0.1), in: Capsule()) }
                    if let cur, kept.contains(cur.id) || cur.kept { Text("★ KEPT").font(Typo.label(11)).foregroundStyle(HV.ink).padding(.horizontal, 12).frame(height: 30).background(HV.lime, in: Capsule()) }
                }
                HStack(spacing: 6) { ForEach(shots.indices, id: \.self) { i in Circle().fill(.white.opacity(i == page ? 0.95 : 0.3)).frame(width: 6, height: 6) } }
            }.padding(.bottom, 60)
        }
    }
}
