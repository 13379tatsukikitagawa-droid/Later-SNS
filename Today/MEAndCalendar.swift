import SwiftData
import SwiftUI
import UIKit

// v14 ③ ME 画面 と ⑦ カレンダー。

// MARK: - ME の7日(リール)

struct MEReelDay: Identifiable, Equatable {
    enum Kind: Equatable {
        /// 仕上がる前(ロック)
        case locked
        case photo(Data?)
        /// 撮らなかった日
        case rest
    }

    let key: String
    let ago: Int
    let date: Date
    let kind: Kind
    /// 【B】ひらく前の 短い文(「あと2こま」/「9:00 に ひらく」)
    var lockedText: String = "9:00 に ひらく"
    var id: String { key }
}

enum MEReelRules {
    /// 今日 → きのう → … 7日分。今日の写真は PhotoDevelop が仕上がりと言うまでロック(本物を読まない)
    static func days(exposureDays: [ExposureDay], now: Date, calendar: Calendar = .current) -> [MEReelDay] {
        let todayStart = calendar.startOfDay(for: DailyWindow.latest(for: now, calendar: calendar).open)
        let byKey = Dictionary(exposureDays.map { ($0.dayKey, $0) }, uniquingKeysWith: { a, _ in a })
        return (0..<DailyExposureRules.photoRetentionDays).map { ago in
            let date = calendar.date(byAdding: .day, value: -ago, to: todayStart) ?? todayStart
            let key = ExposureDayStore.dayKey(for: date, calendar: calendar)
            let kind: MEReelDay.Kind
            var lockedText = "9:00 に ひらく"
            if let day = byKey[key] {
                // 【B】その日の 1枚目(記録は 1日1件・その日の 最初の 1枚)が ひらいているか
                let reveal = OwnReveal.status(takenAt: day.captureDate, now: now, calendar: calendar)
                kind = reveal.isOpen ? .photo(day.thumbnailData) : .locked
                lockedText = reveal.lockedText ?? lockedText
            } else {
                kind = .rest
            }
            return MEReelDay(key: key, ago: ago, date: date, kind: kind, lockedText: lockedText)
        }
    }

    /// 下の小さな文字:LOCKED / あと1日で きえる / あと◯日
    static func note(_ day: MEReelDay) -> String {
        switch day.kind {
        case .locked: return day.lockedText.hasPrefix("あと") ? day.lockedText : "LOCKED"
        case .rest: return "おやすみ"
        case .photo:
            let left = HomeLayerRules.filmDaysLeft(ago: day.ago)
            return left <= 1 ? "あと1日で きえる" : "あと\(left)日"
        }
    }
}

// MARK: - ME 画面

/// 戻る(44pt)・巨大「ME」+「きょうも いちまい。」・フィルムリール・「カレンダーで 見る」。
/// プロフィールの編集・設定は、右上の「プロフィール」から(これまでの画面)。
struct MEScreen: View {
    let onBack: () -> Void
    let onShoot: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \ExposureDay.captureDate, order: .reverse) private var exposureDays: [ExposureDay]
    @State private var centerKey: String?
    @State private var showsCalendar = false
    @State private var showsProfile = false
    @State private var lastCenter: String?

    private var days: [MEReelDay] { MEReelRules.days(exposureDays: exposureDays, now: Date()) }

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button {
                        Haptics.play(.soft)
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(palette.ink)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(palette.fill))
                            .overlay(Circle().strokeBorder(palette.line, lineWidth: 1))
                    }
                    .buttonStyle(SquishButtonStyle(pressedScale: 0.88))
                    .accessibilityLabel("戻る")
                    Spacer()
                    Button {
                        Haptics.play(.pop)
                        showsProfile = true
                    } label: {
                        Text("プロフィール")
                            .font(.system(size: 12.5, weight: .heavy))
                            .foregroundStyle(palette.ink)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(Capsule().fill(palette.fill))
                    }
                    .buttonStyle(SquishButtonStyle())
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 6) {
                    Text("ME")
                        .font(.system(size: 120, weight: .heavy))
                        .tracking(-0.09 * 120)
                        .foregroundStyle(palette.ink)
                        .frame(height: 104, alignment: .bottom)
                    Text("きょうも いちまい。")
                        .font(.system(size: 26, design: .serif).italic())
                        .foregroundStyle(palette.groupAdd.note)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                reel(width: proxy.size.width)
                    .frame(height: 330)
                    .padding(.top, 12)

                Spacer(minLength: 8)

                Button {
                    Haptics.play(.pop)
                    showsCalendar = true
                } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("カレンダーで 見る").font(.system(size: 20, weight: .heavy))
                            Text("色だけ ずっと のこる").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(palette.groupAdd.note)
                        }
                        Spacer()
                        Image(systemName: "calendar").font(.system(size: 22, weight: .semibold))
                    }
                    .foregroundStyle(palette.ink)
                    .padding(.horizontal, 20)
                    .frame(height: 92)
                    .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(palette.fill))
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(palette.line, lineWidth: 1))
                }
                .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
        .background(palette.bg.ignoresSafeArea())
        .fullScreenCover(isPresented: $showsCalendar) {
            LaterCalendarView(onClose: { showsCalendar = false })
                .environment(\.palette, palette)
        }
        .fullScreenCover(isPresented: $showsProfile) {
            ProfileShelfView(onBack: { showsProfile = false }, onShoot: {
                showsProfile = false
                onShoot()
            })
            .environment(\.palette, palette)
        }
        .onAppear { Haptics.prepare(.tick) }
    }

    /// フィルムリール:横スクロール + スナップ。中央が 1.0、離れるほど小さく(最大 0.8)・薄く・奥に傾く(最大 34°)
    private func reel(width: CGFloat) -> some View {
        let frameWidth: CGFloat = 124
        return ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(days) { day in
                    reelFrame(day)
                        .frame(width: frameWidth + 8)
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            let a = min(1, abs(phase.value))
                            return content
                                .scaleEffect(1 - 0.2 * a)
                                .opacity(1 - 0.45 * a)
                                .rotation3DEffect(.degrees(reduceMotion ? 0 : -34 * phase.value), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                        }
                        .id(day.key)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, (width - frameWidth - 8) / 2)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $centerKey, anchor: .center)
        .onChange(of: centerKey) { old, new in
            guard old != nil, let new else { return }
            // 中央が変わるたび tick。両端に来たら thud
            if new == days.first?.key || new == days.last?.key { Haptics.play(.thud) } else { Haptics.play(.tick) }
        }
    }

    private func reelFrame(_ day: MEReelDay) -> some View {
        VStack(spacing: 8) {
            Text(LayerFilmStripStamp.text(day.date))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(0.14 * 11)
                .foregroundStyle(palette.isNight ? Color(hex: "FFB074") : Color(hex: "C2410C"))
            ZStack {
                switch day.kind {
                case .locked:
                    LinearGradient(colors: [Color(hex: "EEE6DA").opacity(0.94), Color(hex: "D0DAE8").opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack(spacing: 8) {
                        Image(systemName: "lock.fill").font(.system(size: 22, weight: .bold))
                        Text(day.lockedText).font(.system(size: 13, weight: .heavy))
                    }
                    .foregroundStyle(Color(hex: "3A2A18"))
                case .photo(let data):
                    if let data, let image = LayerImageCache.avatar(data, key: "me-reel-\(day.key)") {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Color(hex: "3A2A22")
                    }
                case .rest:
                    palette.fill
                    VStack(spacing: 6) {
                        Image(systemName: "moon.fill").font(.system(size: 18))
                        Text("おやすみ").font(.system(size: 13, weight: .heavy))
                    }
                    .foregroundStyle(palette.groupAdd.note)
                }
            }
            .frame(width: 124, height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 16, y: 14)
            VStack(spacing: 2) {
                Text(HomeLayerRules.filmLabel(ago: day.ago)).font(.system(size: 14, weight: .heavy)).foregroundStyle(palette.ink)
                Text(MEReelRules.note(day)).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(palette.groupAdd.note)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(HomeLayerRules.filmLabel(ago: day.ago))。\(MEReelRules.note(day))")
    }
}

enum LayerFilmStripStamp {
    static func text(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.month, .day], from: date)
        return String(format: "%02d.%02d", c.month ?? 0, c.day ?? 0)
    }
}

/// 円形に広がって出る(タップした位置から)。戻るときは薄くなりながら縮む
struct CircleReveal: ViewModifier {
    let isOpen: Bool
    let origin: CGPoint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let reach = hypot(max(origin.x, proxy.size.width - origin.x), max(origin.y, proxy.size.height - origin.y)) * 2.1
            content
                .mask {
                    Circle()
                        .frame(width: reach, height: reach)
                        .scaleEffect(isOpen || reduceMotion ? 1 : 0.001)
                        .position(origin)
                        .ignoresSafeArea()
                }
                .opacity(isOpen ? 1 : 0)
                .scaleEffect(isOpen || reduceMotion ? 1 : 0.96)
        }
        .animation(isOpen ? .timingCurve(0.2, 0.9, 0.25, 1, duration: reduceMotion ? 0.2 : 0.7) : .easeIn(duration: reduceMotion ? 0.2 : 0.4), value: isOpen)
    }
}

// MARK: - カレンダー(⑦)

struct LaterCalendarCell: Identifiable, Equatable {
    enum Kind: Equatable {
        /// 月はじめの空き
        case blank
        /// 未来(点線でうすく)
        case future
        case today
        /// 撮った日(色)。old = 7日より古い(写真は消えた・色だけ)
        case shot(colorHex: String?, old: Bool)
        /// 撮っていない日(空)
        case empty
    }

    let id: String
    let day: Int
    let kind: Kind
    /// 👍(自分が押した日)
    var thumbed = false
}

struct CalendarMonthModel: Identifiable, Equatable {
    let id: String
    let year: Int
    let month: Int
    let shotCount: Int
    /// 週ごとの行(7つずつ)
    let weeks: [[LaterCalendarCell]]
}

enum LaterCalendarRules {
    /// 「yyyy-MM-dd」→ 日付
    static func date(fromKey key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// 写真は7日で消える。それより古い日は「色だけ」(ぼかして残す)
    static func isFaded(dayStart: Date, now: Date, calendar: Calendar = .current) -> Bool {
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: dayStart), to: today).day ?? 0
        return days >= DailyExposureRules.photoRetentionDays
    }

    /// 今月から months か月さかのぼる(新しい順)
    static func months(now: Date, count: Int = 3, colors: [String: String?], thumbs: Set<String>, calendar: Calendar = .current) -> [CalendarMonthModel] {
        let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let today = calendar.startOfDay(for: now)
        return (0..<count).compactMap { back in
            guard let start = calendar.date(byAdding: .month, value: -back, to: thisMonth),
                  let range = calendar.range(of: .day, in: .month, for: start) else { return nil }
            let lead = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
            var cells: [LaterCalendarCell] = (0..<lead).map { LaterCalendarCell(id: "b\(back)-\($0)", day: 0, kind: .blank) }
            var shots = 0
            for d in range {
                guard let date = calendar.date(byAdding: .day, value: d - 1, to: start) else { continue }
                let key = ExposureDayStore.dayKey(for: date, calendar: calendar)
                let kind: LaterCalendarCell.Kind
                if date > today {
                    kind = .future
                } else if date == today {
                    kind = .today
                } else if let color = colors[key] {
                    kind = .shot(colorHex: color, old: isFaded(dayStart: date, now: now, calendar: calendar))
                    shots += 1
                } else {
                    kind = .empty
                }
                cells.append(LaterCalendarCell(id: key, day: d, kind: kind, thumbed: thumbs.contains(key)))
            }
            while cells.count % 7 != 0 { cells.append(LaterCalendarCell(id: "t\(back)-\(cells.count)", day: 0, kind: .blank)) }
            let weeks = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0 + 7, cells.count)]) }
            let c = calendar.dateComponents([.year, .month], from: start)
            return CalendarMonthModel(id: "\(c.year ?? 0)-\(c.month ?? 0)", year: c.year ?? 0, month: c.month ?? 0, shotCount: shots, weeks: weeks)
        }
    }
}

struct LaterCalendarView: View {
    var onClose: (() -> Void)?

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \ExposureDay.captureDate, order: .reverse) private var exposureDays: [ExposureDay]
    @State private var currentMonth: String?
    @State private var peek: LaterCalendarCell?
    @State private var scrollTick = ScrollTickHaptics(minInterval: Haptics.Tuning.scrollGap)
    @State private var lastOffset: CGFloat = 0

    private var models: [CalendarMonthModel] {
        let colors = Dictionary(exposureDays.map { ($0.dayKey, $0.colorHex) }, uniquingKeysWith: { a, _ in a })
        let thumbs = Set(LampBoard.shared.lamps.map(\.day))
        return LaterCalendarRules.months(now: Date(), colors: colors, thumbs: thumbs)
    }

    var body: some View {
        let models = self.models
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 34, pinnedViews: [.sectionHeaders]) {
                    ForEach(models) { month in
                        Section {
                            weekdayRow
                            ForEach(Array(month.weeks.enumerated()), id: \.offset) { index, week in
                                weekRow(week)
                                    .scrollReveal(index)
                            }
                        } header: {
                            monthHeader(month)
                                .onScrollVisibilityChange(threshold: 0.9) { visible in
                                    if visible, currentMonth != month.id {
                                        if currentMonth != nil { Haptics.play(.thud) }
                                        currentMonth = month.id
                                    }
                                }
                        }
                        .id(month.id)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.trailing, 10)
                .padding(.top, 60)
                .padding(.bottom, 160)
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in
                // 少しスクロールするたび tick(70ms)。スクロールするとピークは閉じる
                if abs(y - lastOffset) > 40 {
                    lastOffset = y
                    Haptics.play(.tick, gap: Haptics.Tuning.scrollGap)
                    if peek != nil { withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { peek = nil } }
                }
            }
            .overlay(alignment: .trailing) {
                // 月スクラバー(小さな点)。タップでその月へ + soft
                VStack(spacing: 9) {
                    ForEach(models) { month in
                        Circle()
                            .fill(currentMonth == month.id ? Color(hex: "E85A0C") : palette.line)
                            .frame(width: 7, height: 7)
                            .scaleEffect(currentMonth == month.id ? 1.7 : 1)
                            .frame(width: 24, height: 22)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Haptics.play(.soft)
                                withAnimation(.easeInOut(duration: 0.45)) { reader.scrollTo(month.id, anchor: .top) }
                            }
                            .accessibilityLabel("\(month.month)月へ")
                            .accessibilityAddTraits(.isButton)
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: currentMonth)
                .padding(.trailing, 4)
            }
        }
        .background(palette.bg.ignoresSafeArea())
        .overlay(alignment: .topLeading) {
            if let onClose {
                Button {
                    Haptics.play(.soft)
                    onClose()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(palette.ink)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(palette.fill))
                }
                .buttonStyle(SquishButtonStyle(pressedScale: 0.88))
                .padding(.leading, 18)
                .padding(.top, 4)
                .accessibilityLabel("戻る")
            }
        }
        .overlay(alignment: .bottom) {
            if let peek { peekCard(peek).transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.72), value: peek)
    }

    private func monthHeader(_ month: CalendarMonthModel) -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text("\(month.month)")
                .font(.system(size: 88, weight: .heavy))
                .tracking(-0.08 * 88)
                .foregroundStyle(palette.ink)
            Spacer()
            Text("\(String(month.year)) ・ \(month.shotCount)日 撮った")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(0.2 * 11)
                .foregroundStyle(palette.groupAdd.note)
                .padding(.bottom, 10)
        }
        .padding(.vertical, 4)
        .background(LinearGradient(colors: [palette.bg, palette.bg, palette.bg.opacity(0)], startPoint: .top, endPoint: .bottom))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var weekdayRow: some View {
        HStack(spacing: 6) {
            ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { w in
                Text(w).font(.system(size: 11, weight: .bold)).foregroundStyle(palette.groupAdd.note).frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func weekRow(_ week: [LaterCalendarCell]) -> some View {
        HStack(spacing: 6) {
            ForEach(week) { cell in dayCard(cell) }
        }
    }

    @ViewBuilder
    private func dayCard(_ cell: LaterCalendarCell) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Group {
            switch cell.kind {
            case .blank:
                Color.clear
            case .future:
                shape.strokeBorder(palette.line, lineWidth: 1).opacity(0.55)
                    .overlay(alignment: .topLeading) { dayNumber(cell.day, light: false) }
            case .today:
                TodayBreathCard(day: cell.day)
            case .empty:
                shape.fill(palette.fill)
                    .overlay(alignment: .topLeading) { dayNumber(cell.day, light: false) }
            case .shot(let hex, let old):
                Button {
                    Haptics.play(cell.thumbed ? .success : .pop)
                    peek = cell
                } label: {
                    shape.fill(Color(hex: hex ?? "FF8A3D"))
                        // 7日より古い日:写真は消えた・色だけ(ぼかして残す)
                        .blur(radius: old ? 3 : 0)
                        .clipShape(shape)
                        .overlay(alignment: .topLeading) { dayNumber(cell.day, light: true) }
                        .overlay { if cell.thumbed { shape.strokeBorder(Color(hex: "E85A0C"), lineWidth: 2) } }
                        .overlay(alignment: .bottomTrailing) {
                            if cell.thumbed {
                                Circle().fill(Color(hex: "FFD60A")).frame(width: 7, height: 7)
                                    .shadow(color: Color(hex: "FFD60A").opacity(0.9), radius: 5)
                                    .padding(5)
                            }
                        }
                }
                .buttonStyle(SquishButtonStyle(pressedScale: 0.9))
                .accessibilityLabel("\(cell.day)日。撮った日\(cell.thumbed ? "。👍" : "")")
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    private func dayNumber(_ day: Int, light: Bool) -> some View {
        Text("\(day)")
            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
            .foregroundStyle(light ? Color.white : palette.groupAdd.note)
            .shadow(color: .black.opacity(light ? 0.4 : 0), radius: 2)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
    }

    /// 下から出るピークカード(写真ではなく、その日の色。7日より古い日は「写真は きえた・色だけ」)
    private func peekCard(_ cell: LaterCalendarCell) -> some View {
        let old: Bool = { if case .shot(_, let o) = cell.kind { return o } else { return false } }()
        let hex: String? = { if case .shot(let h, _) = cell.kind { return h } else { return nil } }()
        let date = LaterCalendarRules.date(fromKey: cell.id)
        let weekday = date.map { ["日", "月", "火", "水", "木", "金", "土"][Calendar.current.component(.weekday, from: $0) - 1] } ?? ""
        let left = date.map { max(0, DailyExposureRules.photoRetentionDays - (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: $0), to: Calendar.current.startOfDay(for: Date())).day ?? 0)) } ?? 0
        // 写真は 仕上がった日(PhotoDevelop)で、7日以内のときだけ
        // 【B】ひらいていない 前日の 写真は 出さない(色だけ)
        let thumb: Data? = old ? nil : exposureDays.first { $0.dayKey == cell.id && OwnReveal.isOpen(takenAt: $0.captureDate, now: Date()) }?.thumbnailData
        return HStack(spacing: 14) {
            ZStack {
                Color(hex: hex ?? "FF8A3D")
                if let thumb, let image = LayerImageCache.avatar(thumb, key: "cal-\(cell.id)") {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .frame(width: 92, height: 118)
            .blur(radius: old ? 12 : 0)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(LayerFilmStripStamp.text(date ?? Date()).replacingOccurrences(of: "^0", with: "", options: .regularExpression))
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(palette.ink)
                Text(old ? "\(weekday)曜 ・ 写真は きえた・色だけ" : "\(weekday)曜 ・ のこり \(max(1, left))日")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.groupAdd.note)
                if cell.thumbed {
                    Text("👍 きょうの 1枚")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color(hex: "2F6BFF")))
                        .padding(.top, 6)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(palette.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 30, y: 20)
        .padding(.horizontal, 14)
        .padding(.bottom, 30)
        .onTapGesture { peek = nil }
    }
}

/// 今日のカード:呼吸する枠
private struct TodayBreathCard: View {
    let day: Int
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let b = reduceMotion ? 0 : (1 - cos(t * 2 * .pi / 2.4)) / 2
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.fill)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(palette.ink, lineWidth: 2.5))
                .shadow(color: Color(hex: "FF6A1A").opacity(0.35 * b), radius: 7)
                .overlay(alignment: .topLeading) {
                    Text("\(day)")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.ink)
                        .padding(.horizontal, 6).padding(.vertical, 5)
                }
        }
        .accessibilityLabel("\(day)日。今日")
    }
}
