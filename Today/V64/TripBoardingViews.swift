import SwiftUI

// P58 A(v132 1章):Trip の 一覧の 部品 = 週の 帯(箱 なし)・ 搭乗パスの 束 ・ ひらいた 写真の 行。

// MARK: パス 1枚

/// 右の 上下に 半径 11 の 切りかき(チケットの 穴)。左の 角丸 26
private struct PassShape: Shape {
    var notchX: CGFloat
    func path(in r: CGRect) -> Path {
        let body = Path(roundedRect: r, cornerRadii: .init(topLeading: 26, bottomLeading: 26, bottomTrailing: 14, topTrailing: 14), style: .continuous)
        var holes = Path()
        holes.addEllipse(in: CGRect(x: notchX - 11, y: -11, width: 22, height: 22))
        holes.addEllipse(in: CGRect(x: notchX - 11, y: r.height - 11, width: 22, height: 22))
        return body.subtracting(holes)
    }
}

struct BoardingPass: View {
    var item: TripHubItem
    var live: Bool
    var now: Date
    /// いちばん 前の パス だけ 下半分(日付 ・ 足)を 出す
    var front: Bool
    var cal: Calendar = .current

    private static let stubW: CGFloat = 92
    static let height: CGFloat = 240

    private var color: Color { PopColor.trip(item.color) }
    private var fm: DateFormatter { let f = DateFormatter(); f.dateFormat = "M/d"; return f }

    var body: some View {
        GeometryReader { g in
            let notchX = g.size.width - Self.stubW
            ZStack(alignment: .topLeading) {
                PassShape(notchX: notchX).fill(Color(hex: "F4F1EA"))
                    .shadow(color: .black.opacity(0.55), radius: 13, y: 14)
                HStack(spacing: 0) {
                    main.frame(width: notchX)
                    stub.frame(width: Self.stubW)
                }
                .clipShape(PassShape(notchX: notchX))
            }
        }
        .frame(height: Self.height)
    }

    // 左:Trip 名 ・ 出発 / 帰り ・ 足
    private var main: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.name).font(Typo.mincho(28)).foregroundStyle(.black).lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 4)
                Text(live ? "🔒 9:00 に ひらく" : (item.start.map { "\(fm.string(from: $0)) 出発" } ?? "日にち 未定"))
                    .font(Typo.ui(800, 12)).foregroundStyle(Color(hex: "6A675E")).lineLimit(1).fixedSize()
            }
            HStack(alignment: .bottom, spacing: 8) {
                dateBlock("出発", item.start)
                ZStack(alignment: .trailing) {
                    Rectangle().fill(.clear).frame(height: 2)
                        .overlay { Line().stroke(Color(hex: "CFCABD"), style: StrokeStyle(lineWidth: 2, dash: [4, 4])) }
                    Circle().fill(color).frame(width: 10, height: 10).overlay(Circle().strokeBorder(.black, lineWidth: 2))
                }.frame(height: 10).padding(.bottom, 8)
                dateBlock("帰り", item.end)
            }.padding(.top, 16)
            .opacity(front ? 1 : 0)
            Spacer(minLength: 0)
            foot.opacity(front ? 1 : 0)
        }
        .padding(.top, 18).padding(.leading, 16).padding(.bottom, 16).padding(.trailing, 20)
    }

    private func dateBlock(_ label: String, _ d: Date?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(Typo.ui(800, 10.5)).foregroundStyle(Color(hex: "6A675E"))
            Text(d.map { fm.string(from: $0) } ?? "--").font(Typo.ui(900, 20)).monospacedDigit().foregroundStyle(.black)
        }
    }

    private var foot: some View {
        VStack(spacing: 10) {
            Line().stroke(Color(hex: "CFCABD"), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])).frame(height: 1.5)
            HStack(spacing: 10) {
                HStack(spacing: -8) {
                    ForEach(Array(item.memberImages.prefix(3).enumerated()), id: \.offset) { i, img in
                        PopAvatar(image: img, name: item.memberNames[safe: i] ?? "", size: 28).overlay(Circle().strokeBorder(Color(hex: "F4F1EA"), lineWidth: 2))
                    }
                }
                if live {
                    VStack(alignment: .leading, spacing: 4) {
                        (Text("\(item.shotsToday)").font(Typo.ui(900, 15)) + Text(" / \(item.perDay)枚").font(Typo.ui(700, 11)).foregroundColor(Color(hex: "6A675E"))).foregroundStyle(.black)
                        GeometryReader { g in ZStack(alignment: .leading) { Capsule().fill(.black.opacity(0.12)); Capsule().fill(.black).frame(width: g.size.width * min(1, CGFloat(item.shotsToday) / CGFloat(max(1, item.perDay)))) } }.frame(height: 5)
                    }
                } else {
                    let days = (item.start != nil && item.end != nil) ? TripHubRules.totalDays(start: item.start!, end: item.end!, cal: cal) : 0
                    Text(days > 0 ? "\(days)日 ・ \(item.members)人" : "\(item.members)人").font(Typo.ui(800, 13)).foregroundStyle(.black)
                    Spacer(minLength: 0)
                }
                if live { Spacer(minLength: 0) }
                Image(systemName: "arrow.right").font(.system(size: 17, weight: .black)).foregroundStyle(HV.ink)
                    .frame(width: 46, height: 46).background(HV.lime, in: Circle())
                    .background(Circle().fill(Color(hex: "97C235")).offset(y: 3))
            }
        }
    }

    // 右の 半券
    private var stub: some View {
        ZStack(alignment: .leading) {
            color
            Line(vertical: true).stroke(.black.opacity(0.32), style: StrokeStyle(lineWidth: 2, dash: [4, 4])).frame(width: 2)
            VStack(spacing: 0) {
                Text(live ? "DAY" : "あと").font(Typo.ui(900, 11)).foregroundStyle(.black.opacity(0.7)).padding(.top, 22)
                Text(stubValue).font(Typo.ui(900, 26)).foregroundStyle(.black).lineLimit(1).minimumScaleFactor(0.6).monospacedDigit()
                Spacer(minLength: 0)
                Barcode().fill(.black).frame(width: 52, height: 46).padding(.bottom, 16)
            }.frame(maxWidth: .infinity)
        }
    }

    private var stubValue: String {
        if live {
            if let s = item.start, let e = item.end { return "\(TripHubRules.dayNumber(start: s, now: now, cal: cal))/\(TripHubRules.totalDays(start: s, end: e, cal: cal))" }
            return "—"
        }
        guard let s = item.start else { return "—" }
        return "\(TripHubRules.daysUntil(s, now: now, cal: cal))日"
    }
}

private struct Line: Shape {
    var vertical = false
    func path(in r: CGRect) -> Path {
        var p = Path()
        if vertical { p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.midX, y: r.maxY)) }
        else { p.move(to: CGPoint(x: r.minX, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY)) }
        return p
    }
}

private struct Barcode: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let widths: [CGFloat] = [2, 1, 3, 1, 2, 1, 1, 3, 2, 1, 3, 1, 2, 2, 1, 3, 1, 2]
        var x: CGFloat = 0
        for (i, w) in widths.enumerated() {
            if i % 2 == 0, x + w <= r.width { p.addRect(CGRect(x: r.minX + x, y: r.minY, width: w, height: r.height)) }
            x += w + 0.6
        }
        return p
    }
}

// MARK: パスの 束

struct BoardingStack: View {
    var items: [TripHubItem]            // いま → これから(近い 順)
    var liveIDs: Set<UUID>
    var now: Date
    @Binding var frontID: UUID?
    var onOpen: (UUID) -> Void
    @Binding var request: UUID?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var deck: [UUID] = []
    @State private var stood = false
    @State private var lifting: UUID?

    private static let peek: CGFloat = 56

    private var ordered: [TripHubItem] { deck.compactMap { id in items.first { $0.id == id } } }

    var body: some View {
        let n = ordered.count
        ZStack(alignment: .top) {
            ForEach(Array(ordered.enumerated()), id: \.element.id) { k, t in
                let lift = lifting == t.id
                BoardingPass(item: t, live: liveIDs.contains(t.id), now: now, front: k == 0)
                    .padding(.horizontal, 2)
                    .brightness(k == 0 ? 0 : -0.14)
                    .scaleEffect(stood ? 1 - CGFloat(k) * 0.045 : 0.9, anchor: .top)
                    .rotation3DEffect(.degrees(reduceMotion ? 0 : (stood ? Double(k) * 7 : -58)), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.5)
                    .rotationEffect(.degrees(lift ? -10 : 0))
                    .offset(y: (stood ? CGFloat(n - 1 - k) * Self.peek : CGFloat(n - 1 - k) * Self.peek + 220) - (lift ? 34 : 0))
                    .opacity(stood ? 1 : 0)
                    .zIndex(Double(n - k))
                    .animation(reduceMotion ? .easeOut(duration: 0.25) : .timingCurve(0.34, 1.3, 0.64, 1, duration: 0.72).delay(stood ? Double(n - 1 - k) * 0.09 : 0), value: stood)
                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.72), value: deck)
                    .onTapGesture { tap(t.id, at: k) }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("\(t.name)\(k == 0 ? "。ひらく" : "。前に 出す")")
            }
        }
        .frame(height: BoardingPass.height + CGFloat(max(0, n - 1)) * Self.peek + 14, alignment: .top)
        .onAppear { syncDeck(); DispatchQueue.main.async { stood = true } }
        .onChange(of: items.map(\.id)) { _, _ in syncDeck() }
        .onChange(of: deck.first) { _, new in frontID = new }
        .onChange(of: request) { _, id in
            guard let id, deck.contains(id), deck.first != id else { request = nil; return }
            Haptics.play(.land)
            var d = deck; d.removeAll { $0 == id }; d.insert(id, at: 0); deck = d; request = nil
        }
    }

    private func syncDeck() {
        let ids = items.map(\.id)
        var next = deck.filter { ids.contains($0) }
        for id in ids where !next.contains(id) { next.append(id) }
        deck = next
        frontID = next.first
    }

    private func tap(_ id: UUID, at k: Int) {
        if k == 0 { Haptics.play(.pop); onOpen(id); return }
        Haptics.play(.land)
        lifting = id
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.16)) {
            lifting = nil
            var d = deck; d.removeAll { $0 == id }; d.insert(id, at: 0)
            deck = d
        }
    }
}

// MARK: ひらいた 写真(1行)

struct OpenedPhotosRow: View {
    var item: TripHubItem?
    var live: Bool
    var now: Date
    var onOpen: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button { Haptics.play(.pop); onOpen() } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ひらいた 写真").font(Typo.ui(900, 14)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
                    Text(caption).font(Typo.ui(700, 11.5)).foregroundStyle(Color(hex: "8E8E96")).lineLimit(1)
                }.frame(width: 104, alignment: .leading)
                HStack(spacing: -8) { photos }.frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 14).padding(.vertical, 12).frame(minHeight: 78)
            .background(Color(hex: "111113"), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(HVPress(scale: 0.985))
        .id(item?.id)
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
        .accessibilityLabel("ひらいた 写真。\(caption)")
    }

    private var empty: Bool { item == nil || (item!.openedThumbs.isEmpty && !item!.hasLocked) || !live }

    private var caption: String {
        guard let item else { return "まだ 写真なし" }
        if !live { return item.start.map { "\(Self.md($0)) から" } ?? "まだ 写真なし" }
        return item.openedDay > 0 ? "DAY \(item.openedDay) ・ \(item.openedCount)枚" : "あした 9:00 から"
    }

    private static func md(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: d) }

    @ViewBuilder private var photos: some View {
        if let item, live {
            ForEach(Array(item.openedThumbs.prefix(4).enumerated()), id: \.offset) { i, img in
                mini(img, tilt: i % 2 == 0 ? -3 : 3, locked: false)
            }
            if item.hasLocked { mini(item.lockedThumb, tilt: 3, locked: true) }
            if item.openedThumbs.isEmpty && !item.hasLocked {
                ForEach(0..<3, id: \.self) { _ in dashed }
            }
        } else {
            ForEach(0..<3, id: \.self) { _ in dashed }
        }
    }

    private var dashed: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(.white.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])).frame(width: 40, height: 52)
    }

    private func mini(_ img: UIImage?, tilt: Double, locked: Bool) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Group { if let img { Image(uiImage: img).resizable().scaledToFill() } else { Color(hex: "2A2A2E") } }
                if locked {
                    Color.black.opacity(0.25)
                    Image(systemName: "lock.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                }
            }
            .frame(width: 46 - 8, height: 46 - 8).clipped()
            .padding(.top, 4).padding(.horizontal, 4).padding(.bottom, 10)
        }
        .background(PopColor.paper, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
        .rotationEffect(.degrees(tilt))
        .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
    }
}
