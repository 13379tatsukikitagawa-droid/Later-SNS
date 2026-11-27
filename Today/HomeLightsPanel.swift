import SwiftUI

/// 光のパネルの数え方(画面とは別に、テストできるようにまとめる)。時刻の計算はピルと同じ DailyWindow を使う。
enum LightsPanelLogic {
    /// 帯の進み(0〜1)。昼は 9:00→24:00、夜は 24:00→9:00。
    static func progress(now: Date, calendar: Calendar = .current) -> Double {
        let start: Date
        let end: Date
        if DailyWindow.isNight(now, calendar: calendar) {
            start = DailyWindow.latest(for: now, calendar: calendar).close
            end = DailyExposureRules.window(for: now, calendar: calendar).open
        } else {
            let w = DailyWindow.latest(for: now, calendar: calendar)
            start = w.open
            end = w.close
        }
        let span = end.timeIntervalSince(start)
        guard span > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(start) / span))
    }

    /// フィルムの行の文言(太字・小さい字)
    static func caption(taken: Int, isNight: Bool) -> (title: String, detail: String) {
        if isNight { return ("9:00に、3こま届く", "きょうは \(taken)こま 撮りました") }
        if FilmRoll.shotsRemaining(shotsToday: taken) > 0 {
            return ("のこり \(FilmRoll.shotsRemaining(shotsToday: taken))こま", "きょうは \(taken)こま 撮りました")
        }
        return ("今日は、ここまで", "\(taken)こま、撮りました")
    }

    static func heading(isNight: Bool) -> String { isNight ? "ひらくまで" : "24:00まで" }

    static func ruleText(isNight: Bool) -> String {
        isNight
            ? "9:00 に、昨日がひらけて、あたらしい3こまが届きます。"
            : "24:00 に、ひらいていない昨日の写真は消えます。フィルムは、あしたの9:00に3こま戻ります。"
    }

    /// v47:次の 24:00(消灯)までの分。すでに窓がひらいている/いないに関わらず、つねに「次の消灯」を出す
    static func minutesUntilClose(now: Date, calendar: Calendar = .current) -> Int {
        let window = DailyExposureRules.window(for: now, calendar: calendar)
        let target = now < window.close ? window.close : nextDayWindow(after: now, calendar: calendar).close
        return max(0, Int(target.timeIntervalSince(now) / 60))
    }

    /// v47:次の 9:00(ひらく)までの分
    static func minutesUntilOpen(now: Date, calendar: Calendar = .current) -> Int {
        let window = DailyExposureRules.window(for: now, calendar: calendar)
        let target = now < window.open ? window.open : nextDayWindow(after: now, calendar: calendar).open
        return max(0, Int(target.timeIntervalSince(now) / 60))
    }

    private static func nextDayWindow(after now: Date, calendar: Calendar) -> (open: Date, close: Date) {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return DailyExposureRules.window(for: tomorrow, calendar: calendar)
    }

    /// v47:帯(DayBar)の 0〜1。いまの「ひらいている窓(9:00)」から、つぎの「ひらく(9:00)」までの24時間
    static func dayBarFraction(now: Date, calendar: Calendar = .current) -> Double {
        let latest = DailyWindow.latest(for: now, calendar: calendar)
        let end = calendar.date(byAdding: .minute, value: 9 * 60, to: latest.close) ?? latest.close
        let span = end.timeIntervalSince(latest.open)
        guard span > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(latest.open) / span))
    }

    /// v47:帯のうち「消灯(赤い線)」の位置(latest.open を 0、つぎの開く9:00 を 1 とした場合)
    static func dayBarCloseFraction(now: Date, calendar: Calendar = .current) -> Double {
        let latest = DailyWindow.latest(for: now, calendar: calendar)
        let end = calendar.date(byAdding: .minute, value: 9 * 60, to: latest.close) ?? latest.close
        let span = end.timeIntervalSince(latest.open)
        guard span > 0 else { return 0 }
        return min(1, max(0, latest.close.timeIntervalSince(latest.open) / span))
    }

    /// v47:帯の上での、撮った時刻の位置(latest の窓の外は無視)
    static func dayBarFractions(captureDates: [Date], now: Date, calendar: Calendar = .current) -> [Double] {
        let latest = DailyWindow.latest(for: now, calendar: calendar)
        let end = calendar.date(byAdding: .minute, value: 9 * 60, to: latest.close) ?? latest.close
        let span = end.timeIntervalSince(latest.open)
        guard span > 0 else { return [] }
        return captureDates
            .filter { $0 >= latest.open && $0 < end }
            .map { min(1, max(0, $0.timeIntervalSince(latest.open) / span)) }
    }
}

/// パネルの外(画面を暗くして、押すととじる)
struct LightsPanelDim: View {
    let onTap: () -> Void

    var body: some View {
        // v53:0.35 だと、うしろの 丸い文字(オーブの 輪の 文字)が かすかに 透けて見えていた。しっかり 隠す。
        Rectangle()
            .fill(.black.opacity(0.68))
            .background(.ultraThinMaterial.opacity(0.6))
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                TapConsumption.mark()
                onTap()
            }
            .accessibilityHidden(true)
    }
}

/// v47:ピルが そのまま ひろがって なる、ライブのパネル。
/// 「● LIVE」+ いまの時刻 → 大きな残り時間(開いた場所で、消灯まで / ひらくまでのどちらが主役か変わる)
/// → もう一方を 小さく → 1日の帯(いまの位置・撮った時刻・消灯から先は現像ちゅうの斜線)→ 3こま + 大きなボタン。
struct LightsPanel: View {
    let now: Date
    let width: CGFloat
    /// どちらの画面から ひらいたか(today = 消灯までが主役、yesterday = ひらくまでが主役)
    var home: HomeKind = .today
    var namespace: Namespace.ID?
    /// 今日 撮った時刻(帯の緑の目盛りに使う。表示だけ)
    var captureDates: [Date] = []
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 撮った数は FilmCounter だけを見る(ピル・Home のフィルムと同じ数)
    private let film = FilmCounter.shared
    private let shape = RoundedRectangle(cornerRadius: 36, style: .continuous)

    var body: some View {
        TimelineView(.periodic(from: now, by: 1)) { context in
            liveContent(at: reduceMotion ? now : context.date)
        }
    }

    @ViewBuilder
    private func liveContent(at date: Date) -> some View {
        let taken = film.used
        let remaining = FilmRoll.shotsRemaining(shotsToday: taken)
        let closeMinutes = LightsPanelLogic.minutesUntilClose(now: date)
        let openMinutes = LightsPanelLogic.minutesUntilOpen(now: date)
        let primaryIsClose = home == .today
        let primaryMinutes = primaryIsClose ? closeMinutes : openMinutes
        let secondaryMinutes = primaryIsClose ? openMinutes : closeMinutes
        let primaryLabel = LightsPanelLogic.heading(isNight: !primaryIsClose)
        let secondaryLabel = LightsPanelLogic.heading(isNight: primaryIsClose)
        let seconds = 59 - Int(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 60))
        let minuteBucket = Int(date.timeIntervalSinceReferenceDate / 60)

        VStack(alignment: .leading, spacing: 0) {
            liveHeader(date: date)
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(primaryLabel)
                    .font(Typo.ui(600, 12))
                    .tracking(0.24)
                    .foregroundStyle(Color(hex: "8C8C93"))
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(hourPart(minutes: primaryMinutes))
                        .font(Typo.ui(900, 44))
                        .tracking(-2.2)
                        .contentTransition(.numericText(countsDown: true))
                        .foregroundStyle(.white)
                    Text(":")
                        .font(Typo.ui(800, 44))
                        .foregroundStyle(.white.opacity(0.35))
                    Text(minutePart(minutes: primaryMinutes))
                        .font(Typo.ui(900, 44))
                        .tracking(-2.2)
                        .contentTransition(.numericText(countsDown: true))
                        .foregroundStyle(.white)
                    Text(String(format: "%02d", seconds))
                        .font(Typo.ui(700, 16))
                        .tracking(-0.32)
                        .contentTransition(.numericText(countsDown: true))
                        .foregroundStyle(LaterColor.filmLight)
                        .padding(.leading, 2)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: primaryMinutes)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(primaryLabel) \(spoken(primaryMinutes))")
            }

            HStack(spacing: 6) {
                Text(secondaryLabel)
                    .font(Typo.ui(600, 11.5))
                    .foregroundStyle(Color(hex: "6C6C73"))
                Text(timeText(minutes: secondaryMinutes))
                    .font(Typo.ui(700, 12))
                    .contentTransition(.numericText(countsDown: true))
                    .foregroundStyle(Color(hex: "C9C9CF"))
            }
            .padding(.top, 4)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: secondaryMinutes)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(secondaryLabel) \(spoken(secondaryMinutes))")

            DayBar(now: date, captureDates: captureDates, reduceMotion: reduceMotion)
                .padding(.top, 16)

            Rectangle().fill(.white.opacity(0.10)).frame(height: 1)
                .padding(.vertical, 14)
                .accessibilityHidden(true)

            HStack(spacing: 8) {
                ForEach(0..<FilmRoll.shotsPerDay, id: \.self) { index in
                    FrameCell(index: index, taken: taken)
                }
            }
            .padding(.bottom, 10)

            ActionButton(remaining: remaining, taken: taken)
        }
        .padding(.top, 16)
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
        .frame(width: width, alignment: .leading)
        .background {
            if let namespace, #available(iOS 26.0, *) {
                shape.fill(Color(hex: "050506"))
                    .glassEffect(.regular, in: shape)
                    .matchedGeometryEffect(id: "lightsPill", in: namespace)
            } else {
                shape.fill(.ultraThinMaterial)
                    .background(shape.fill(Color(hex: "050506")))
            }
        }
        .overlay(shape.strokeBorder(.white.opacity(0.07), lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 56, y: 24)
        .contentShape(shape)
        .onTapGesture { TapConsumption.mark() }
        .gesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    if value.translation.height > 40, abs(value.translation.height) > abs(value.translation.width) { close() }
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape, close)
        .onAppear { openHaptic() }
        .onChange(of: minuteBucket) { _, _ in
            guard !reduceMotion else { return }
            Haptics.play(.tick)
        }
    }

    private func liveHeader(date: Date) -> some View {
        let blink = reduceMotion ? 1 : 0.4 + 0.6 * (0.5 + 0.5 * sin(date.timeIntervalSinceReferenceDate * 2 * .pi / 1.4))
        return HStack(spacing: 8) {
            HStack(spacing: 5) {
                Circle().fill(LaterColor.filmLight).frame(width: 6, height: 6).opacity(blink)
                Text("LIVE")
                    .font(Typo.label(9.5, bold: true))
                    .tracking(1.9)
                    .foregroundStyle(LaterColor.liveGreen)
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Capsule().fill(LaterColor.film.opacity(0.16)))
            Text(clockText(date))
                .font(Typo.label(10, bold: true))
                .tracking(1.4)
                .foregroundStyle(Color(hex: "5D5D63"))
            Spacer()
            Button(action: close) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "9A9AA3"))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color(hex: "1A1A1D")))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("とじる")
        }
    }

    private func close() {
        Haptics.play(.soft)
        onClose()
    }

    private func openHaptic() {
        guard !reduceMotion else { Haptics.play(.pop); return }
        Haptics.play(.pop)
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.07 * Double(i + 1)) {
                Haptics.play(.tick)
            }
        }
    }

    private func timeText(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? String(format: "%d:%02d", h, m) : "0:\(String(format: "%02d", m))"
    }

    private func hourPart(minutes: Int) -> String { "\(minutes / 60)" }
    private func minutePart(minutes: Int) -> String { String(format: "%02d", minutes % 60) }

    private func clockText(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return String(format: "%02d:%02d:%02d", c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
    }

    private func spoken(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "\(h)時間\(m)分" : "\(m)分"
    }

    /// 撮ったこま:ぼかした写真ふう + DEV → その枠の現像へ。空いたこま:+ → 撮影へ
    private struct FrameCell: View {
        let index: Int
        let taken: Int

        var body: some View {
            let isShot = index < taken
            Button {
                Haptics.play(.tick)
                if isShot {
                    DevelopRequestStore.shared.request(startIndex: index)
                } else {
                    CaptureRequestStore.shared.pendingRequestID = UUID()
                }
            } label: {
                ZStack {
                    if isShot {
                        LinearGradient(colors: [Color(hex: "3A2A20"), Color(hex: "1C1410")], startPoint: .top, endPoint: .bottom)
                        Text("DEV")
                            .font(V5.mono(9))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.85))
                    } else {
                        Color.white.opacity(0.05)
                        Text("+")
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(isShot ? 0.14 : 0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isShot ? "\(index + 1)こまめ、現像を見る" : "\(index + 1)こまめ、まだ。撮影へ")
        }
    }

    /// 残りがあれば 白い「shoot」、3こま撮ったら 緑の「develop」
    private struct ActionButton: View {
        let remaining: Int
        let taken: Int

        var body: some View {
            Button {
                Haptics.play(.click)
                if remaining > 0 {
                    CaptureRequestStore.shared.pendingRequestID = UUID()
                } else {
                    DevelopRequestStore.shared.request(startIndex: 0)
                }
            } label: {
                HStack(spacing: 8) {
                    Text(remaining > 0 ? "shoot" : "develop")
                        .font(.system(size: 14, weight: .bold))
                    Rectangle().fill(.black.opacity(0.18)).frame(width: 1, height: 12)
                    Text(remaining > 0 ? "\(remaining) LEFT" : "OPENS 9:00")
                        .font(V5.mono(11))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .foregroundStyle(remaining > 0 ? Color.black : Color.white)
                .background(Capsule().fill(remaining > 0 ? Color.white : LaterColor.film))
            }
            .buttonStyle(PressScaleStyle(scale: 0.97))
            .accessibilityLabel(remaining > 0 ? "撮影へ、のこり\(remaining)こま" : "現像を見る、ひらくのは9:00")
        }
    }
}

/// v47:1日の帯。0:00→24:00(赤い線=消灯)→あしたの9:00(緑=ひらく)。いまの位置に白い点、
/// 撮った時刻に小さな緑のこま、24:00から先は斜線(現像ちゅう)。
private struct DayBar: View {
    let now: Date
    let captureDates: [Date]
    let reduceMotion: Bool

    var body: some View {
        let progress = LightsPanelLogic.dayBarFraction(now: now)
        let closeAt = LightsPanelLogic.dayBarCloseFraction(now: now)
        let marks = LightsPanelLogic.dayBarFractions(captureDates: captureDates, now: now)

        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.10)).frame(height: 4)
                    // 消灯から先(現像ちゅう):斜線
                    DiagonalHatch(spacing: 5)
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                        .frame(width: max(0, w * (1 - closeAt)), height: 4)
                        .offset(x: w * closeAt)
                        .clipShape(Capsule())
                    Capsule()
                        .fill(LinearGradient(colors: [LaterColor.filmLight.opacity(0.25), LaterColor.filmLight.opacity(0.75)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, w * min(progress, closeAt)), height: 4)
                        .shadow(color: LaterColor.filmLight.opacity(0.35), radius: 4)
                    // 撮った時刻
                    ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                        Circle().fill(LaterColor.filmLight).frame(width: 5, height: 5)
                            .offset(x: w * mark - 2.5, y: 0)
                    }
                    // 消灯(赤い線)
                    Rectangle().fill(LaterColor.red).frame(width: 1.5, height: 10)
                        .offset(x: w * closeAt)
                    // いまの位置
                    Circle().fill(.white).frame(width: 9, height: 9)
                        .shadow(color: .white.opacity(0.7), radius: 4)
                        .offset(x: min(max(0, w * progress - 4.5), w - 9))
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 12)
            HStack {
                Text("0:00").foregroundStyle(Color(hex: "55555B"))
                Spacer()
                Text("24:00").foregroundStyle(LaterColor.red)
                Spacer()
                Text("9:00 OPEN").foregroundStyle(LaterColor.liveGreen)
            }
            .font(Typo.label(8.5, bold: true))
            .tracking(1.02)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("1日の帯、いま\(Int((progress * 100).rounded()))パーセント")
    }
}

/// 斜線のパターン(「現像ちゅう」の帯に使う)
private struct DiagonalHatch: Shape {
    var spacing: CGFloat = 5

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x: CGFloat = -rect.height
        while x < rect.width {
            path.move(to: CGPoint(x: x, y: rect.height))
            path.addLine(to: CGPoint(x: x + rect.height, y: 0))
            x += spacing
        }
        return path
    }
}
