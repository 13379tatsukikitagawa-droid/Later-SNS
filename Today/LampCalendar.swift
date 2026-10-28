import SwiftUI

// 1年間のカレンダー。発表された一枚(世界の一枚)が日付に残り、1年間見られる。
// 出していい文字は、日付・月の数字・年・曜日だけ。説明の文章は書かない。
// 発表されたデータ(DailyPick)はまだ無いので、AnnouncedPickStore が空のあいだは「一枚がない日」だけが並ぶ。

// MARK: - 計算

enum CalendarCellKind: Equatable {
    /// 発表ずみの日(世界の一枚の写真)
    case announced
    /// 発表待ち(昨日。9:00 前)
    case awaiting
    /// 今日
    case today
    /// 一枚がない日
    case empty
    /// 未来(何も出さない)
    case future
    /// 365日より前(薄い枠だけ)
    case beyondYear
}

struct CalendarDay: Equatable {
    /// yyyy-MM-dd
    let key: String
    let number: Int
}

struct CalendarMonth: Identifiable, Equatable {
    /// yyyy-MM
    let id: String
    let year: Int
    let month: Int
    /// 日曜はじまりで、1日の前に空けるマス数
    let leadingBlanks: Int
    let days: [CalendarDay]

    /// 「2026.10」
    var label: String { String(format: "%04d.%02d", year, month) }
}

enum LampCalendarModel {
    static let monthCount = 12
    /// 発表の時刻(その日の9:00)。これより前の「昨日」は発表待ち
    static let announceHour = 9
    static let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]

    /// 新しい月が先頭(最大12か月)
    static func months(now: Date, calendar: Calendar = .current) -> [CalendarMonth] {
        guard let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return [] }
        return (0..<monthCount).compactMap { offset -> CalendarMonth? in
            guard let first = calendar.date(byAdding: .month, value: -offset, to: thisMonth),
                  let range = calendar.range(of: .day, in: .month, for: first) else { return nil }
            let parts = calendar.dateComponents([.year, .month], from: first)
            let weekday = calendar.component(.weekday, from: first) // 日曜 = 1
            let days = range.map { day -> CalendarDay in
                let date = calendar.date(byAdding: .day, value: day - 1, to: first) ?? first
                return CalendarDay(key: LampRules.dayKey(for: date, calendar: calendar), number: day)
            }
            let year = parts.year ?? 0, month = parts.month ?? 0
            return CalendarMonth(id: String(format: "%04d-%02d", year, month), year: year, month: month, leadingBlanks: weekday - 1, days: days)
        }
    }

    /// マスの種類
    static func kind(day: String, now: Date, hasWorldPick: Bool, calendar: Calendar = .current) -> CalendarCellKind {
        guard let ago = LampRules.daysAgo(day: day, now: now, calendar: calendar) else { return .future }
        if ago < 0 { return .future }
        if !LampRules.isKept(day: day, now: now, calendar: calendar) { return .beyondYear }
        if ago == 0 { return .today }
        if hasWorldPick { return .announced }
        if ago == 1, calendar.component(.hour, from: now) < announceHour { return .awaiting }
        return .empty
    }

    /// 世界の一枚を見せる日。既定は「自分が1枚以上撮った日」だけ(撮らなかった日は、その日の世界の一枚を見せない)。
    static func showsWorldPick(day: String, shotDays: Set<String>) -> Bool {
        shotDays.contains(day)
    }

    /// 1日に出すグループの点の数(最大3つ)
    static let maxGroupDots = 3
    static func groupDotCount(_ picks: Int) -> Int { min(maxGroupDots, max(0, picks)) }

    /// マスの大きさ。幅は画面の幅から決める(7列・すき間6pt・縦長 3 : 4.3)
    static func cellSize(forWidth width: CGFloat, gap: CGFloat = 6) -> CGSize {
        let w = max(0, (width - gap * 6) / 7).rounded(.down)
        return CGSize(width: w, height: (w * 4.3 / 3).rounded())
    }
}

// MARK: - 画面

struct LampCalendarView: View {
    let now: Date
    let picks: [AnnouncedPick]
    /// 自分が1枚以上撮った日(yyyy-MM-dd)
    let shotDays: Set<String>
    let haptics: ExposureHaptics
    /// 戻る(‹)。nil なら、タブの一番上のページ(戻るボタンなし・共通ヘッダーの下から始まる)
    var onClose: (() -> Void)?
    /// 発表ずみの日をひらいた
    let onOpenDay: (_ day: String) -> Void
    /// 増えるたびに、いまの月まで滑らかにもどる(選択ずみのカレンダータブをもう一度タップ)
    var scrollToCurrentToken = 0

    /// 共通ヘッダーの上の余白(画面の上の安全領域の高さ。他のタブの topInset と同じ)
    var topInset: CGFloat = 0

    @State private var topMonth: String?
    @State private var contentWidth: CGFloat = 0

    private var months: [CalendarMonth] { LampCalendarModel.months(now: now) }

    private var worldByDay: [String: AnnouncedPick] {
        var result: [String: AnnouncedPick] = [:]
        for pick in picks where pick.isWorld && LampCalendarModel.showsWorldPick(day: pick.day, shotDays: shotDays) { result[pick.day] = pick }
        return result
    }

    private var groupCountByDay: [String: Int] {
        picks.filter { !$0.isWorld }.reduce(into: [:]) { $0[$1.day, default: 0] += 1 }
    }

    private var current: CalendarMonth? {
        months.first { $0.id == topMonth } ?? months.first
    }

    var body: some View {
        if onClose == nil { tabBody } else { overlayBody }
    }

    // MARK: タブの一番上のページ

    /// 共通ヘッダー(Later・ピル・アバター)は外が重ねる。ここは、その下(安全領域の中)から始める。
    /// ScrollView 自体は安全領域を無視しない:上は safeAreaInset のヘッダー、下はタブバーの自動の余白。
    private var tabBody: some View {
        let cell = LampCalendarModel.cellSize(forWidth: max(0, contentWidth - V5.edge * 2))
        return ScrollViewReader { reader in
            ScrollView(.vertical) {
                // 見出し(大きな月・12個の点・曜日)は、スクロールしても上に残す。
                // 下は ScrollView 自体がタブバーの下まで伸び、タブバーの分の余白を自動でとる(最後の行が隠れない)
                LazyVStack(spacing: 26, pinnedViews: [.sectionHeaders]) {
                    Section {
                        if contentWidth > 0 {
                            ForEach(months) { month in
                                monthBlock(month, cell: cell)
                                    .padding(.horizontal, V5.edge)
                                    .id(month.id)
                            }
                        }
                        footer
                            .padding(.bottom, 16)
                    } header: {
                        VStack(spacing: 0) {
                            // 共通ヘッダー(Later・ピル・アバター。上の4pt + 44pt)の分。他のタブと同じ数え方
                            Color.clear.frame(height: topInset + 48)
                            header
                                .padding(.horizontal, V5.edge)
                                .padding(.top, 4)
                            weekdayRow(cell: cell)
                                .padding(.horizontal, V5.edge)
                                .padding(.top, 14)
                                .padding(.bottom, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .background(ChicColor.paper.opacity(0.92))
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $topMonth, anchor: .top)
            .scrollIndicators(.hidden)
            .onChange(of: scrollToCurrentToken) { _, _ in
                guard let first = months.first?.id else { return }
                withAnimation(.easeInOut(duration: 0.45)) { reader.scrollTo(first, anchor: .top) }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = $0 }
        .onChange(of: topMonth) { old, new in
            guard old != nil, old != new else { return }
            haptics.playPattern(HomeHapticPattern.globeTick)
        }
    }

    // MARK: 重ねて出す(これまでの出し方。タブ化のあとは、ここから出さない)

    private var overlayBody: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let gridWidth = max(0, width - V5.edge * 2)
            let cell = LampCalendarModel.cellSize(forWidth: gridWidth)
            ZStack(alignment: .top) {
                ChicColor.paper.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, V5.edge)
                        .padding(.top, proxy.safeAreaInsets.top + 6)
                    weekdayRow(cell: cell)
                        .padding(.horizontal, V5.edge)
                        .padding(.top, 14)
                        .padding(.bottom, 8)
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 26, pinnedViews: []) {
                            ForEach(months) { month in
                                monthBlock(month, cell: cell)
                                    .id(month.id)
                            }
                            footer
                                .padding(.bottom, proxy.safeAreaInsets.bottom + 30)
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, V5.edge)
                        .padding(.top, 6)
                        .frame(width: width)
                    }
                    .scrollPosition(id: $topMonth, anchor: .top)
                    .scrollIndicators(.hidden)
                }
            }
            .frame(width: width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .onChange(of: topMonth) { old, new in
            guard old != nil, old != new else { return }
            haptics.playPattern(HomeHapticPattern.globeTick)
        }
    }

    // MARK: 上

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ChicColor.ink)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(ChicColor.paper))
                            .overlay(Circle().strokeBorder(ChicColor.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("閉じる")
                }

                Text("\(current?.month ?? 0)")
                    .font(.system(size: 70, weight: .bold))
                    .foregroundStyle(ChicColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                    .padding(.top, 6)
                Text(String(current?.year ?? 0))
                    .font(V5.mono(13, weight: .medium))
                    .tracking(0.14 * 13)
                    .foregroundStyle(ChicColor.sub)
            }
            Spacer(minLength: 0)
            monthDots
        }
    }

    /// 12か月ぶんの点。いま見ている月が橙に光る。古い3つは少し薄い
    private var monthDots: some View {
        VStack(spacing: 9) {
            ForEach(Array(months.enumerated()), id: \.element.id) { index, month in
                let isCurrent = month.id == (current?.id ?? "")
                Circle()
                    .fill(isCurrent ? ChicColor.accent : ChicColor.ink.opacity(index >= months.count - 3 ? 0.12 : 0.25))
                    .frame(width: isCurrent ? 8 : 6, height: isCurrent ? 8 : 6)
                    .animation(.easeOut(duration: 0.25), value: isCurrent)
            }
        }
        .padding(.top, 8)
        .accessibilityHidden(true)
    }

    private func weekdayRow(cell: CGSize) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(LampCalendarModel.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ChicColor.sub)
                    .frame(width: cell.width)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }

    // MARK: 月のかたまり

    private func monthBlock(_ month: CalendarMonth, cell: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Rectangle().fill(ChicColor.line).frame(height: 1)
                Text(month.label)
                    .font(V5.mono(10))
                    .tracking(0.1 * 10)
                    .foregroundStyle(ChicColor.sub)
                    .fixedSize()
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(cell.width), spacing: 6), count: 7), alignment: .leading, spacing: 6) {
                ForEach(0..<month.leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(width: cell.width, height: cell.height)
                }
                ForEach(month.days, id: \.key) { day in
                    let pick = worldByDay[day.key]
                    let kind = LampCalendarModel.kind(day: day.key, now: now, hasWorldPick: pick != nil)
                    let ago = LampRules.daysAgo(day: day.key, now: now) ?? 0
                    CalendarCell(
                        kind: kind,
                        number: day.number,
                        pick: pick,
                        groupDots: LampCalendarModel.groupDotCount(groupCountByDay[day.key] ?? 0),
                        daysAgo: ago
                    )
                    .frame(width: cell.width, height: cell.height)
                    .onTapGesture {
                        guard kind == .announced else { return }
                        haptics.playPattern(HomeHapticPattern.light)
                        onOpenDay(day.key)
                    }
                }
            }
        }
    }

    /// いちばん下:小さな点と 365
    private var footer: some View {
        VStack(spacing: 6) {
            Circle().fill(ChicColor.ink.opacity(0.2)).frame(width: 4, height: 4)
            Text("365")
                .font(V5.mono(10))
                .tracking(0.2 * 10)
                .foregroundStyle(ChicColor.sub)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .accessibilityHidden(true)
    }
}

// MARK: - 1マス

private struct CalendarCell: View {
    let kind: CalendarCellKind
    let number: Int
    let pick: AnnouncedPick?
    let groupDots: Int
    let daysAgo: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private let corner: CGFloat = 12

    var body: some View {
        content
            // 古い日ほど少しずつ薄れる(280日前までは100%)
            .saturation(LampRules.fadeSaturation(daysAgo: daysAgo))
            .opacity(LampRules.fadeOpacity(daysAgo: daysAgo))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(kind == .announced ? "\(number)日、一枚あり" : "\(number)日")
            .accessibilityAddTraits(kind == .announced ? .isButton : [])
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .announced:
            ZStack {
                if let pick { AnnouncedPhoto(pick: pick) }
                LinearGradient(colors: [.black.opacity(0.4), .clear, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                VStack {
                    dayNumber(.white)
                    Spacer(minLength: 0)
                    if groupDots > 0 {
                        HStack(spacing: 3) {
                            ForEach(0..<groupDots, id: \.self) { _ in
                                Circle().fill(V5.amber).frame(width: 4, height: 4).shadow(color: V5.amber, radius: 2)
                            }
                        }
                    }
                }
                .padding(5)
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous).strokeBorder(ChicColor.line, lineWidth: 1))
        case .awaiting:
            ZStack {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(ChicColor.accent.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                Circle()
                    .fill(ChicColor.accent)
                    .frame(width: 6, height: 6)
                    .opacity(pulse ? 1 : 0.5)
                VStack { dayNumber(ChicColor.sub); Spacer(minLength: 0) }.padding(5)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true }
            }
        case .today:
            ZStack {
                RoundedRectangle(cornerRadius: corner, style: .continuous).fill(ChicColor.fill)
                RoundedRectangle(cornerRadius: corner, style: .continuous).strokeBorder(ChicColor.ink, lineWidth: 2)
                VStack { dayNumber(ChicColor.ink); Spacer(minLength: 0) }.padding(5)
            }
        case .empty:
            ZStack {
                RoundedRectangle(cornerRadius: corner, style: .continuous).fill(ChicColor.fill)
                VStack { dayNumber(ChicColor.sub); Spacer(minLength: 0) }.padding(5)
            }
        case .future:
            Color.clear
        case .beyondYear:
            RoundedRectangle(cornerRadius: corner, style: .continuous).strokeBorder(ChicColor.line, lineWidth: 1)
        }
    }

    private func dayNumber(_ color: Color) -> some View {
        Text("\(number)")
            .font(V5.mono(8.5, weight: .medium))
            .foregroundStyle(color)
            .shadow(color: .black.opacity(kind == .announced ? 0.6 : 0), radius: 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
