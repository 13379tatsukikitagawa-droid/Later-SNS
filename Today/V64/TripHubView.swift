import SwiftUI

/// v132 1章:Trip の 一覧(Home の Trip ページ ・ きのうの Trip タブの どちらも これ 1つ)。
/// 週の 帯(箱 なし)→ Boarding(搭乗パスの 束)→ ひらいた 写真 → 新しい Trip / KEY → Album。
struct TripHubView: View {
    var items: [TripHubItem]
    var now: Date = Date()
    var onOpen: (UUID) -> Void = { _ in }
    var onNew: () -> Void = {}
    var onJoinKey: () -> Void = {}
    @Binding var position: ScrollPosition
    var topInset: CGFloat = 118
    /// v134:大見出し(Barlow ・ 例 "Trip")。nil なら 出さない
    var title: String? = nil
    var onScroll: (CGFloat) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var weekOffset = 0
    @State private var picked: Date?
    @State private var frontRequest: UUID?
    @State private var note: String?
    @State private var frontID: UUID?

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
                if let title { DisplayTitle(text: title, size: 64).padding(.horizontal, 20).padding(.bottom, 10) }
                if items.isEmpty { emptyState }
                else {
                    weekStrip.padding(.horizontal, 16)
                    if !deck.isEmpty { boarding }
                    openedRow.padding(.horizontal, 16).padding(.top, deck.isEmpty ? 22 : 18)
                    newTrip.padding(.horizontal, 16).padding(.top, 18)
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
        .overlay(alignment: .bottom) {
            if topInset > 60 { LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: 128).allowsHitTesting(false) }
        }
    }

    // MARK: 1-1 週の 帯(箱 なし)

    private var weekStrip: some View {
        let days = (0..<7).map { cal.date(byAdding: .day, value: $0, to: week) ?? week }
        let seg = TripHubRules.segments(items, weekStart: week, cal: cal)
        let fm = DateFormatter(); fm.dateFormat = "M/d"
        let monthName = DateFormatter(); monthName.locale = Locale(identifier: "en_US"); monthName.dateFormat = "MMMM"
        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(monthName.string(from: days[3])).font(Typo.title(26)).foregroundStyle(.white)
                Text("\(fm.string(from: days[0])) 〜 \(fm.string(from: days[6]))").font(Typo.ui(700, 12.5)).foregroundStyle(Color(hex: "8E8E96"))
                Spacer(minLength: 0)
                if weekOffset != 0 {
                    Button { Haptics.play(.notch); withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { weekOffset = 0 } } label: {
                        Text("今週").font(Typo.ui(800, 12)).foregroundStyle(.white).padding(.horizontal, 12).frame(height: 28).background(.white.opacity(0.14), in: Capsule())
                    }.buttonStyle(PopPressStyle()).frame(minHeight: 44)
                }
                arrow("chevron.left", -1)
                arrow("chevron.right", 1)
            }
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    let d = days[i]
                    let isToday = cal.isDate(d, inSameDayAs: now)
                    let isPicked = picked.map { cal.isDate($0, inSameDayAs: d) } ?? false
                    Button { tapDay(d) } label: {
                        VStack(spacing: 4) {
                            Text(Self.wd[i]).font(Typo.ui(700, 11)).foregroundStyle(.white.opacity(0.5))
                            Text("\(cal.component(.day, from: d))").font(Typo.ui(900, 17)).foregroundStyle(isToday ? Color(hex: "111113") : .white)
                                .frame(width: 34, height: 34)
                                .background(isToday ? Color(hex: "FAFAF7") : .clear, in: Circle())
                                .overlay(Circle().strokeBorder(.white, lineWidth: isPicked && !isToday ? 2 : 0))
                        }
                        .frame(maxWidth: .infinity).frame(height: 66, alignment: .top).contentShape(Rectangle())
                    }.buttonStyle(PopPressStyle())
                }
            }
            lines(seg.segments, overflow: seg.overflow)
        }
        .gesture(DragGesture(minimumDistance: 24).onEnded { v in
            guard abs(v.translation.width) > abs(v.translation.height) * 1.5, abs(v.translation.width) > 40 else { return }
            shiftWeek(v.translation.width < 0 ? 1 : -1)
        })
        .id("weekcard")
    }

    private func arrow(_ name: String, _ dir: Int) -> some View {
        Button { shiftWeek(dir) } label: {
            Image(systemName: name).font(.system(size: 13, weight: .bold)).foregroundStyle(.white).frame(width: 32, height: 32).background(.white.opacity(0.1), in: Circle())
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }.buttonStyle(PopPressStyle()).accessibilityLabel(dir < 0 ? "まえの 週" : "つぎの 週")
    }

    private func shiftWeek(_ d: Int) {
        Haptics.play(.notch)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { weekOffset += d; picked = nil }
    }

    /// Trip の 日 = 下に Trip の 色の 線 5pt(かざり ・ 押す のは 日)+ はじめの 日に Trip 名
    private func lines(_ segs: [TripHubRules.Segment], overflow: [Int: Int]) -> some View {
        let laneCount = min(3, (segs.map(\.lane).max() ?? -1) + 1)
        return GeometryReader { g in
            let colW = g.size.width / 7
            ZStack(alignment: .topLeading) {
                ForEach(segs) { s in
                    if let t = items.first(where: { $0.id == s.id }) {
                        let span = s.last - s.first + 1
                        let r: CGFloat = 3
                        UnevenRoundedRectangle(topLeadingRadius: s.startsHere ? r : 0, bottomLeadingRadius: s.startsHere ? r : 0, bottomTrailingRadius: s.endsHere ? r : 0, topTrailingRadius: s.endsHere ? r : 0, style: .continuous)
                            .fill(PopColor.trip(t.color))
                            .frame(width: colW * CGFloat(span) - 4, height: 5)
                            .offset(x: colW * CGFloat(s.first) + 2, y: CGFloat(s.lane) * 22)
                        if s.startsHere {
                            Text(t.name).font(Typo.ui(800, 11)).foregroundStyle(PopColor.trip(t.color)).lineLimit(1)
                                .frame(width: colW * CGFloat(min(span, 3)) - 4, alignment: .leading)
                                .offset(x: colW * CGFloat(s.first) + 2, y: CGFloat(s.lane) * 22 + 7)
                        }
                    }
                }
                ForEach(overflow.keys.sorted(), id: \.self) { d in
                    Text("+\(overflow[d] ?? 0)").font(Typo.label(10)).foregroundStyle(.white.opacity(0.7)).frame(width: colW).offset(x: colW * CGFloat(d), y: 3 * 22)
                }
            }
        }
        .frame(height: laneCount == 0 ? 4 : CGFloat(laneCount) * 22)
        .allowsHitTesting(false)
    }

    private func tapDay(_ d: Date) {
        Haptics.play(.sel)
        picked = d
        if let t = TripHubRules.trips(on: d, in: items, cal: cal).first(where: { t in deck.contains { $0.id == t.id } }) ?? TripHubRules.trips(on: d, in: items, cal: cal).first {
            frontRequest = t.id
        } else {
            let f = DateFormatter(); f.dateFormat = "M/d"
            flash("\(f.string(from: d)) は Trip なし ・ 新しい Trip で 作れます")
        }
    }

    private func flash(_ t: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { note = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { withAnimation(.easeOut(duration: 0.2)) { note = nil } }
    }

    // MARK: 1-2 Boarding

    /// いま(新しい 順)→ これから(近い 順)。おわった は 束に 入れない
    private var deck: [TripHubItem] { live + upcoming }

    private var boarding: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Boarding").font(Typo.title(30, italic: true)).foregroundStyle(.white)
                Text("いま と これから").font(Typo.ui(700, 12.5)).foregroundStyle(Color(hex: "8E8E96"))
            }.padding(.horizontal, 18)
            BoardingStack(items: deck, liveIDs: Set(live.map(\.id)), now: now, frontID: $frontID, onOpen: onOpen, request: $frontRequest)
                .padding(.horizontal, 14)
        }.padding(.top, 14)
    }

    // MARK: 1-3 ひらいた 写真

    private var openedRow: some View {
        let front = deck.first { $0.id == frontID } ?? deck.first
        return OpenedPhotosRow(item: front, live: front.map { phaseOf($0).phase == .live } ?? false, now: now, onOpen: { if let f = front { onOpen(f.id) } })
            .animation(reduceMotion ? nil : .easeOut(duration: 0.32), value: frontID)
    }

    // MARK: 1-4 新しい Trip / KEY

    private var newTrip: some View {
        HStack(spacing: 10) {
            Button { Haptics.play(.pop); onNew() } label: {
                Text("＋ 新しい Trip を つくる").font(Typo.ui(800, 15)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 60)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6, 5])))
                    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }.buttonStyle(HVPress(scale: 0.98))
            Button { Haptics.play(.tick); onJoinKey() } label: {
                Text("KEY").font(Typo.ui(800, 14)).foregroundStyle(.white).frame(width: 76, height: 60)
                    .background(Color(hex: "1D1D20"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }.buttonStyle(HVPress(scale: 0.96))
        }
    }

    private var albumHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Album").font(Typo.title(30)).foregroundStyle(.white)
            Text("おわった ・ アルバム").font(Typo.ui(700, 12.5)).foregroundStyle(Color(hex: "8E8E96"))
            Spacer(minLength: 0)
        }.padding(.horizontal, 18).padding(.top, 30).padding(.bottom, 14)
    }

    // MARK: 5-5 おわった

    private var endedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            albumHeader
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)], spacing: 22) {
                ForEach(Array(ended.enumerated()), id: \.element.id) { i, t in albumTile(t, index: i).id(t.id) }
            }.padding(.horizontal, 22)
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
                    ChekiFrame(caption: t.name, captionSize: 22, tilt: tilt) {
                        Group { if let c = t.cover { Image(uiImage: c).resizable().scaledToFill() } else { Color(hex: "2A2A2E") } }
                    }
                }
                .overlay(alignment: .topTrailing) { PopSticker(shape: .hash, color: PopColor.trip(t.color), size: 22, tilt: 10).offset(x: 8, y: -8) }
                Text(meta).font(Typo.ui(700, 12)).foregroundStyle(Color(hex: "8E8E96"))
            }
        }.buttonStyle(PopPressStyle())
    }

    // MARK: 5-6 まだ 0件

    private var emptyState: some View {
        TripEmptyV111(onNew: onNew, onJoinKey: onJoinKey)
    }
}
