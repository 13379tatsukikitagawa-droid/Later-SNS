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

    static func heading(isNight: Bool) -> String { isNight ? "ひらくまで" : "消灯まで" }

    static func ruleText(isNight: Bool) -> String {
        isNight
            ? "9:00 に、昨日がひらけて、あたらしい3こまが届きます。"
            : "24:00 に、ひらいていない昨日の写真は消えます。フィルムは、あしたの9:00に3こま戻ります。"
    }
}

/// パネルの外(画面を暗くして、押すととじる)
struct LightsPanelDim: View {
    let onTap: () -> Void

    var body: some View {
        Rectangle()
            .fill(.black.opacity(0.35))
            .background(.ultraThinMaterial.opacity(0.35))
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                TapConsumption.mark()
                onTap()
            }
            .accessibilityHidden(true)
    }
}

/// 右上のピルの下に出る「消灯まで / ひらくまで」のパネル。
struct LightsPanel: View {
    let now: Date
    /// Home のフィルムと同じ、直近の窓で撮った枚数
    let taken: Int
    let width: CGFloat
    let onClose: () -> Void

    static var transition: AnyTransition { transition(anchor: .topTrailing) }

    static func transition(anchor: UnitPoint) -> AnyTransition {
        .scale(scale: 0.96, anchor: anchor)
            .combined(with: .opacity)
            .combined(with: .offset(y: -8))
    }

    var body: some View {
        let c = DailyWindow.capsule(now: now)
        let parts = DailyWindow.capsuleParts(now: now)
        let progress = LightsPanelLogic.progress(now: now)
        let caption = LightsPanelLogic.caption(taken: taken, isNight: c.isNight)
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)

        VStack(alignment: .leading, spacing: 0) {
            Text(parts.label)
                .font(.system(size: 10.5))
                .tracking(1.6)
                .foregroundStyle(Color(hex: "9A9AA3"))
            Text(parts.time)
                .font(V5.mono(40))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(Color(hex: "FFE9D6"))
                .shadow(color: Color(hex: "FF8C3C").opacity(0.45), radius: 9)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 2)
                .accessibilityLabel("\(parts.label) \(spoken(c.minutes))")
            Group { bar(progress: progress, isNight: c.isNight) }
                .padding(.top, 14)
            Rectangle().fill(.white.opacity(0.10)).frame(height: 1)
                .padding(.vertical, 14)
                .accessibilityHidden(true)
            HStack(spacing: 14) {
                FilmPips(taken: taken, isNight: c.isNight, pipSize: CGSize(width: 22, height: 30), spacing: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(caption.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(caption.detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color(hex: "9A9AA3"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .accessibilityElement(children: .combine)
            }
            Text(LightsPanelLogic.ruleText(isNight: c.isNight))
                .font(.system(size: 11))
                .lineSpacing(5)
                .foregroundStyle(Color(hex: "B7B7BF"))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
        }
        .padding(.top, 18)
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
        .frame(width: width, alignment: .leading)
        .background(shape.fill(.ultraThinMaterial))
        .background(shape.fill(Color(hex: "14100E").opacity(0.94)))
        .overlay(
            shape.strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "FFD6B0").opacity(0.45), location: 0),
                        .init(color: .clear, location: 0.5),
                        .init(color: Color(hex: "FF9650").opacity(0.25), location: 1)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.6), radius: 56, y: 24)
        .contentShape(shape)
        .onTapGesture { TapConsumption.mark() }
        .gesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    if value.translation.height > 40, abs(value.translation.height) > abs(value.translation.width) { onClose() }
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape, onClose)
    }

    private func bar(progress: Double, isNight: Bool) -> some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12)).frame(height: 4)
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: "FF9E5E"), Color(hex: "FFD0A6")], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, w * progress), height: 4)
                    Circle().fill(.white).frame(width: 10, height: 10)
                        .shadow(color: V5.amber.opacity(0.9), radius: 5)
                        .offset(x: min(max(0, w * progress - 5), w - 10))
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 10)
            HStack {
                Text(isNight ? "24:00" : "9:00")
                Spacer()
                Text(isNight ? "9:00" : "24:00")
            }
            .font(V5.mono(10))
            .foregroundStyle(Color(hex: "9A9AA3"))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(isNight ? "24:00から9:00" : "9:00から24:00")のうち、\(Int((progress * 100).rounded()))パーセント")
    }

    private func spoken(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "\(h)時間\(m)分" : "\(m)分"
    }
}
