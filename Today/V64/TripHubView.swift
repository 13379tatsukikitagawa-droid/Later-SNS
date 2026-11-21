import SwiftUI

/// v110 §5:Trip の 一覧(Home の Trip ページ ・ きのうの Trip タブの どちらも これ 1つ)。
/// 上に 週の 帯(Trip の 色の 線)→ ボタン 2つ → いま / これから / おわった。
struct TripHubView: View {
    var items: [TripHubItem]
    var now: Date = Date()
    var onOpen: (UUID) -> Void = { _ in }
    var onNew: () -> Void = {}
    var onJoinKey: () -> Void = {}
    @Binding var position: ScrollPosition
    var topInset: CGFloat = 118
    var onScroll: (CGFloat) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var weekOffset = 0
    @State private var picked: Date?
    @State private var wiggle: UUID?
    @State private var note: String?
    @State private var blink = false

    private static let wd = ["月", "火", "水", "木", "金", "土", "日"]
    private var cal: Calendar { .current }
    private var thisWeek: Date { TripHubRules.weekStart(of: now, cal: cal) }
    private var week: Date { cal.date(byAdding: .day, value: weekOffset * 7, to: thisWeek) ?? thisWeek }

    private func phaseOf(_ t: TripHubItem) -> (phase: TripPhase, needsDates: Bool) { TripHubRules.phase(start: t.start, end: t.end, created: t.created, now: now, cal: cal) }
    private var live: [TripHubItem] { items.filter { phaseOf($0).phase == .live }.sorted { ($0.start ?? $0.created) > ($1.start ?? $1.created) } }
    private var upcoming: [TripHubItem] { items.filter { phaseOf($0).phase == .upcoming }.sorted { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) } }
    private var ended: [TripHubItem] { items.filter { phaseOf($0).phase == .ended }.sorted { ($0.end ?? $0.created) > ($1.end ?? $1.created) } }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: topInset)
                if items.isEmpty { emptyState }
                else {
                    weekCard.padding(.horizontal, 16)
                    buttons.padding(.horizontal, 16).padding(.top, 14)
                    if !live.isEmpty { liveSection }
                    if !upcoming.isEmpty { upcomingSection }
                    if !ended.isEmpty { endedSection }
                }
                Color.clear.frame(height: 140)
            }
        }
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self) { max(0, $0.contentOffset.y + $0.contentInsets.top) } action: { _, v in onScroll(v) }
        .overlay(alignment: .top) {
            if let note {
                Text(note).font(Typo.ui(800, 13)).foregroundStyle(Color(hex: "111113")).padding(.horizontal, 14).frame(height: 36)
                    .background(PopColor.sun, in: Capsule()).overlay(Capsule().strokeBorder(.white, lineWidth: 2)).padding(.top, topInset + 4).transition(.scale.combined(with: .opacity))
            }
        }
        .loopWhileVisible(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: $blink)   // v111
    }

    // MARK: 5-1 週の 帯

    private var weekCard: some View {
        let days = (0..<7).map { cal.date(byAdding: .day, value: $0, to: week) ?? week }
        let seg = TripHubRules.segments(items, weekStart: week, cal: cal)
        let fm = DateFormatter(); fm.dateFormat = "M/d"
        let month = cal.component(.month, from: days[3])
        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                arrow("chevron.left", -1)
                Text("\(month)月").font(Typo.ui(900, 22)).foregroundStyle(.white)
                Text("\(fm.string(from: days[0])) 〜 \(fm.string(from: days[6]))").font(Typo.label(11)).foregroundStyle(.white.opacity(0.5))
                Spacer(minLength: 0)
                if weekOffset != 0 {
                    Button { Haptics.play(.notch); withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { weekOffset = 0 } } label: {
                        Text("今週").font(Typo.ui(800, 12)).foregroundStyle(Color(hex: "111113")).padding(.horizontal, 12).frame(height: 28).background(PopColor.lime, in: Capsule())
                    }.buttonStyle(PopPressStyle()).frame(minHeight: 44)
                }
                arrow("chevron.right", 1)
            }
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    let d = days[i]
                    let isToday = cal.isDate(d, inSameDayAs: now)
                    let has = !TripHubRules.trips(on: d, in: items, cal: cal).isEmpty
                    let isPicked = picked.map { cal.isDate($0, inSameDayAs: d) } ?? false
                    Button { tapDay(d) } label: {
                        VStack(spacing: 3) {
                            Text(Self.wd[i]).font(Typo.ui(600, 10.5)).foregroundStyle(isToday ? Color(hex: "111113").opacity(0.7) : .white.opacity(0.5))
                            Text("\(cal.component(.day, from: d))").font(Typo.ui(800, 19)).foregroundStyle(isToday ? Color(hex: "111113") : .white)
                            Circle().fill(has ? (isToday ? Color(hex: "111113") : .white.opacity(0.7)) : .clear).frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity).frame(height: 62)
                        .background(isToday ? PopColor.lime : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white, lineWidth: isPicked ? 2 : 0))
                    }.buttonStyle(PopPressStyle())
                }
            }
            lines(seg.segments, overflow: seg.overflow)
        }
        .padding(12)
        .background(PopColor.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .gesture(DragGesture(minimumDistance: 24).onEnded { v in
            guard abs(v.translation.width) > abs(v.translation.height) * 1.5, abs(v.translation.width) > 40 else { return }
            shiftWeek(v.translation.width < 0 ? 1 : -1)
        })
        .id("weekcard")
    }

    private func arrow(_ name: String, _ dir: Int) -> some View {
        Button { shiftWeek(dir) } label: {
            Image(systemName: name).font(.system(size: 13, weight: .bold)).foregroundStyle(.white).frame(width: 34, height: 34).background(.white.opacity(0.08), in: Circle())
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }.buttonStyle(PopPressStyle()).accessibilityLabel(dir < 0 ? "まえの 週" : "つぎの 週")
    }

    private func shiftWeek(_ d: Int) {
        Haptics.play(.notch)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { weekOffset += d; picked = nil }
    }

    private func lines(_ segs: [TripHubRules.Segment], overflow: [Int: Int]) -> some View {
        let laneCount = min(3, (segs.map(\.lane).max() ?? -1) + 1)
        let extra = overflow.isEmpty ? 0 : 1
        return GeometryReader { g in
            let colW = g.size.width / 7
            ZStack(alignment: .topLeading) {
                ForEach(segs) { s in
                    if let t = items.first(where: { $0.id == s.id }) {
                        let span = s.last - s.first + 1
                        let r: CGFloat = 9
                        UnevenRoundedRectangle(topLeadingRadius: s.startsHere ? r : 2, bottomLeadingRadius: s.startsHere ? r : 2, bottomTrailingRadius: s.endsHere ? r : 2, topTrailingRadius: s.endsHere ? r : 2, style: .continuous)
                            .fill(PopColor.trip(t.color))
                            .overlay { if span >= 2 { Text(t.name).font(Typo.ui(800, 10.5)).foregroundStyle(Color(hex: "111113")).lineLimit(1).padding(.horizontal, 6) } }
                            .frame(width: colW * CGFloat(span) - 6, height: 18)
                            .offset(x: colW * CGFloat(s.first) + 3, y: CGFloat(s.lane) * 22)
                            .onTapGesture { Haptics.play(.pop); goTo(t.id) }
                    }
                }
                ForEach(overflow.keys.sorted(), id: \.self) { d in
                    Text("+\(overflow[d] ?? 0)").font(Typo.label(10)).foregroundStyle(.white.opacity(0.7)).frame(width: colW).offset(x: colW * CGFloat(d), y: 3 * 22)
                }
            }
        }
        .frame(height: laneCount == 0 ? 6 : CGFloat(laneCount + extra) * 22)
    }

    private func tapDay(_ d: Date) {
        Haptics.play(.tick)
        picked = d
        if let t = TripHubRules.trips(on: d, in: items, cal: cal).first { goTo(t.id) }
        else {
            let f = DateFormatter(); f.dateFormat = "M/d"
            flash("\(f.string(from: d)) は Trip なし ・ 新しい Trip で 作れます")
        }
    }

    private func goTo(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.4)) { position.scrollTo(id: id, anchor: .center) }
        guard !reduceMotion else { return }
        wiggle = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { if wiggle == id { wiggle = nil } }
    }

    private func flash(_ t: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { note = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { withAnimation(.easeOut(duration: 0.2)) { note = nil } }
    }

    // MARK: 5-2 ボタン

    private var buttons: some View {
        HStack(spacing: 10) {
            PopButton(title: "＋ 新しい Trip", kind: .lime) { onNew() }
            PopButton(title: "KEY で 入る", kind: .ghost) { onJoinKey() }
        }
    }

    private func header(_ title: String, count: Int? = nil, trailing: AnyView? = nil) -> some View {
        HStack(spacing: 8) {
            Text(title).font(Typo.ui(900, 22)).foregroundStyle(.white)
            if let count { Text("\(count)").font(Typo.ui(700, 11)).foregroundStyle(.white.opacity(0.6)).padding(.horizontal, 8).frame(height: 20).background(.white.opacity(0.08), in: Capsule()) }
            if let trailing { trailing }
            Spacer(minLength: 0)
        }.padding(.horizontal, 18).padding(.top, 26).padding(.bottom, 12)
    }

    // MARK: 5-3 いま

    private var liveSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("いま", trailing: AnyView(
                HStack(spacing: 5) { Circle().fill(Color(hex: "111113")).frame(width: 6, height: 6).opacity(blink ? 0.2 : 1); Text("LIVE").font(Typo.label(10)).tracking(1) }
                    .foregroundStyle(Color(hex: "111113")).padding(.horizontal, 9).frame(height: 22).background(PopColor.pink, in: Capsule()).overlay(Capsule().strokeBorder(.white, lineWidth: 2))))
            VStack(spacing: 16) { ForEach(live) { t in liveCard(t).id(t.id) } }.padding(.horizontal, 16)
        }
    }

    private func liveCard(_ t: TripHubItem) -> some View {
        let c = PopColor.trip(t.color)
        let (_, needsDates) = phaseOf(t)
        let tag: String = {
            if needsDates { return "日にちを 入れる" }
            if let s = t.start, let e = t.end { return "DAY \(TripHubRules.dayNumber(start: s, now: now, cal: cal)) / \(TripHubRules.totalDays(start: s, end: e, cal: cal))" }
            return "TRIP"
        }()
        let fm = DateFormatter(); fm.dateFormat = "M/d"
        let range: String = { if let s = t.start, let e = t.end { return "\(fm.string(from: s)) 〜 \(fm.string(from: e))" }; return "" }()
        return Button { Haptics.play(.pop); onOpen(t.id) } label: {
            ZStack(alignment: .bottomLeading) {
                Group { if let cover = t.cover { Image(uiImage: cover).resizable().scaledToFill() } else { LinearGradient(colors: [Color(hex: "3A3036"), Color(hex: "1B1A1E")], startPoint: .top, endPoint: .bottom) } }
                    .frame(maxWidth: .infinity).frame(height: 236).clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRIP").font(Typo.label(11)).tracking(2).foregroundStyle(c)
                    Text(t.name).font(Typo.ui(900, 34)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                    if !range.isEmpty { Text(range).font(Typo.ui(600, 13)).foregroundStyle(.white.opacity(0.8)) }
                    HStack(spacing: 10) {
                        HStack(spacing: -8) {
                            ForEach(Array(t.memberImages.enumerated()), id: \.offset) { i, img in
                                PopAvatar(image: img, name: t.memberNames[safe: i] ?? "", size: 28).overlay(Circle().strokeBorder(.black, lineWidth: 2))
                            }
                            if t.members > t.memberImages.count { Text("+\(t.members - t.memberImages.count)").font(Typo.ui(800, 10)).foregroundStyle(.white).frame(width: 28, height: 28).background(Color(hex: "2A2A2E"), in: Circle()).overlay(Circle().strokeBorder(.black, lineWidth: 2)) }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            (Text("\(t.shotsToday)").font(Typo.ui(900, 15)) + Text(" / \(t.perDay)枚").font(Typo.ui(600, 11)).foregroundColor(.white.opacity(0.7))).foregroundStyle(.white)
                            GeometryReader { g in ZStack(alignment: .leading) { Capsule().fill(.white.opacity(0.2)); Capsule().fill(c).frame(width: g.size.width * min(1, CGFloat(t.shotsToday) / CGFloat(max(1, t.perDay)))) } }.frame(height: 4)
                        }
                        Image(systemName: "chevron.right").font(.system(size: 14, weight: .black)).foregroundStyle(Color(hex: "111113")).frame(width: 40, height: 40).background(c, in: Circle())
                    }.padding(.top, 4)
                }.padding(16)
            }
            .frame(height: 236).clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(c, lineWidth: 3))
            .overlay(alignment: .topLeading) { PopTag(text: tag, color: c, tilt: -3).padding(.leading, 14).padding(.top, 14) }
            .overlay(alignment: .topTrailing) { PopTape(color: c, tilt: 8).offset(x: 6, y: -8) }
            .rotationEffect(.degrees(wiggle == t.id ? 1.5 : 0))
            .animation(wiggle == t.id ? .easeInOut(duration: 0.08).repeatCount(6, autoreverses: true) : .default, value: wiggle)
        }.buttonStyle(PopPressStyle())
    }

    // MARK: 5-4 これから

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("これから", count: upcoming.count)
            VStack(spacing: 12) { ForEach(upcoming) { t in upcomingRow(t).id(t.id) } }.padding(.horizontal, 16)
        }
    }

    private func upcomingRow(_ t: TripHubItem) -> some View {
        let c = PopColor.trip(t.color)
        let s = t.start ?? now
        let fm = DateFormatter(); fm.dateFormat = "M/d"
        let wd = Self.wd[(cal.component(.weekday, from: s) + 5) % 7]
        let days = (t.end.map { TripHubRules.totalDays(start: s, end: $0, cal: cal) } ?? 1)
        let left = TripHubRules.daysUntil(s, now: now, cal: cal)
        return Button { Haptics.play(.pop); onOpen(t.id) } label: {
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    Text(wd).font(Typo.ui(800, 10)); Text("\(cal.component(.day, from: s))").font(Typo.ui(900, 24)); Text("\(cal.component(.month, from: s))月").font(Typo.ui(700, 10))
                }.foregroundStyle(Color(hex: "111113")).frame(width: 56, height: 62).background(c, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(t.name).font(Typo.ui(800, 17)).foregroundStyle(.white).lineLimit(1)
                    Text("\(fm.string(from: s)) 〜 \(t.end.map { fm.string(from: $0) } ?? "") ・ \(days)日 ・ \(t.members)人").font(Typo.ui(500, 12)).foregroundStyle(.white.opacity(0.55)).lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 4)
                Group { if let cover = t.cover { Image(uiImage: cover).resizable().scaledToFill() } else { Color(hex: "2A2A2E") } }
                    .frame(width: 40, height: 50).clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .padding(3).background(PopColor.paper, in: RoundedRectangle(cornerRadius: 5, style: .continuous)).rotationEffect(.degrees(5))
            }
            .padding(12).background(PopColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(alignment: .topTrailing) { PopTag(text: "あと \(left)日", color: left <= 7 ? PopColor.sun : PopColor.sky, tilt: 3).offset(x: -6, y: -10) }
            .rotationEffect(.degrees(wiggle == t.id ? 1.2 : 0))
            .animation(wiggle == t.id ? .easeInOut(duration: 0.08).repeatCount(6, autoreverses: true) : .default, value: wiggle)
        }.buttonStyle(PopPressStyle())
    }

    // MARK: 5-5 おわった

    private var endedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("おわった アルバム")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)], spacing: 22) {
                ForEach(Array(ended.enumerated()), id: \.element.id) { i, t in albumTile(t, index: i).id(t.id) }
            }.padding(.horizontal, 22)
            Text("Trip は 旅の あいだ みんなで 1日 23枚。おわったら アルバムに なります").font(Typo.ui(500, 11.5)).foregroundStyle(.white.opacity(0.4)).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.horizontal, 28).padding(.top, 26)
        }
    }

    private func albumTile(_ t: TripHubItem, index: Int) -> some View {
        let tilt = index % 2 == 0 ? -2.5 : 2.5
        let fm = DateFormatter(); fm.dateFormat = "M/d"
        let meta = "\(fm.string(from: t.end ?? t.created)) ・ \(t.photoCount)枚"
        return Button { Haptics.play(.pop); onOpen(t.id) } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(PopColor.paper.opacity(0.7)).aspectRatio(0.78, contentMode: .fit).rotationEffect(.degrees(-tilt * 1.6)).offset(x: -4, y: 3)
                    ChekiFrame(caption: t.name, captionSize: 15, tilt: tilt) {
                        Group { if let c = t.cover { Image(uiImage: c).resizable().scaledToFill() } else { Color(hex: "2A2A2E") } }
                    }
                }
                .overlay(alignment: .topTrailing) { PopSticker(shape: .hash, color: PopColor.trip(t.color), size: 22, tilt: 10).offset(x: 8, y: -8) }
                Text(meta).font(Typo.label(10.5)).foregroundStyle(.white.opacity(0.55))
            }
            .rotationEffect(.degrees(wiggle == t.id ? 1.2 : 0))
            .animation(wiggle == t.id ? .easeInOut(duration: 0.08).repeatCount(6, autoreverses: true) : .default, value: wiggle)
        }.buttonStyle(PopPressStyle())
    }

    // MARK: 5-6 まだ 0件

    private var emptyState: some View {
        TripEmptyV111(onNew: onNew, onJoinKey: onJoinKey)
    }
}
