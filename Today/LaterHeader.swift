import SwiftUI
import UIKit

// MARK: - 時間の書き方(テストできるように、画面とは分けている)

/// 「消灯まで」の残り時間の書き方。時計に見える「12:56」は使わない。
/// 1時間より多い:`12h 56m` / 1時間より少ない:`56m` / 最後の1時間(23:00〜):`00:56:12`(秒つき)
enum LaterHeaderTime {
    /// 最後の1時間(昼のあいだで、消灯まで1時間以内)か
    static func isLastHour(now: Date, calendar: Calendar = .current) -> Bool {
        let window = DailyExposureRules.window(for: now, calendar: calendar)
        guard now >= window.open else { return false }
        let remaining = window.close.timeIntervalSince(now)
        return remaining > 0 && remaining <= 3600
    }

    /// 残り時間の文字。分は DailyWindow.capsule(光のパネルと同じ数え方)、最後の1時間の秒は同じ消灯の時刻から出す。
    static func text(now: Date, calendar: Calendar = .current) -> String {
        if isLastHour(now: now, calendar: calendar) {
            let window = DailyExposureRules.window(for: now, calendar: calendar)
            let total = max(0, Int(window.close.timeIntervalSince(now)))
            return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        }
        let minutes = DailyWindow.capsule(now: now, calendar: calendar).minutes
        let hours = minutes / 60, rest = minutes % 60
        return hours > 0 ? "\(hours)h \(rest)m" : "\(rest)m"
    }

    /// VoiceOver 用(「12時間56分」「56分」)
    static func spokenDuration(_ minutes: Int) -> String {
        let hours = minutes / 60, rest = minutes % 60
        if hours == 0 { return "\(rest)分" }
        return rest == 0 ? "\(hours)時間" : "\(hours)時間\(rest)分"
    }
}

/// ヘッダーの更新の時刻。ふだんは毎分(分の頭にそろえる)、最後の1時間は毎秒。止めるときは最初の1回だけ。
struct LaterHeaderSchedule: TimelineSchedule {
    var active: Bool

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnySequence<Date> {
        guard active else { return AnySequence([startDate]) }
        return AnySequence(sequence(first: startDate) { previous in
            if LaterHeaderTime.isLastHour(now: previous) {
                let whole = floor(previous.timeIntervalSinceReferenceDate)
                return Date(timeIntervalSinceReferenceDate: whole + 1)
            }
            return Calendar.current.nextDate(after: previous, matching: DateComponents(second: 0), matchingPolicy: .nextTime)
                ?? previous.addingTimeInterval(60)
        })
    }
}

// MARK: - フォント(入っていなければ、システムの字にもどす。フォントのファイルは足さない)

private enum HeaderFont {
    static func logo() -> Font {
        UIFont(name: "Inter-Black", size: 31) != nil
            ? .custom("Inter-Black", fixedSize: 31)
            : .system(size: 31, weight: .heavy, design: .rounded)
    }

    static func label() -> Font {
        UIFont(name: "InstrumentSerif-Italic", size: 16) != nil
            ? .custom("InstrumentSerif-Italic", fixedSize: 16)
            : .system(size: 16, design: .serif).italic()
    }

    static func mono(_ size: CGFloat) -> Font {
        UIFont(name: "SpaceMono-Bold", size: size) != nil
            ? .custom("SpaceMono-Bold", fixedSize: size)
            : .system(size: size, weight: .bold, design: .monospaced)
    }

    static func initial() -> Font {
        UIFont(name: "Inter-Black", size: 15) != nil
            ? .custom("Inter-Black", fixedSize: 15)
            : .system(size: 15, weight: .heavy, design: .rounded)
    }
}

// MARK: - ヘッダー(今日・昨日のホームで同じもの)

/// 左上の「Later」+ 小さな today / yesterday、右上のアバター、ロゴの下の「消灯まで」の行。
/// 高さ 87pt(安全領域の上から)。1行目の中心は 30pt、「消灯まで」の行の中心は 71pt
/// (ロゴの下から ピルの上まで、前より 7pt あける)。
struct LaterHeader: View {
    static let height: CGFloat = 87
    /// 「消灯まで」の行の 上端(前は 49)
    static let pillTop: CGFloat = 56

    /// ヘッダーの上端(安全領域の高さ)。昨日のホーム(HomeV5Container)は安全領域の中に置くので、
    /// 今日のホームも同じ値にそろえる。Safe Area を無視する親の中では proxy が 0 になるため、窓の値も見る。
    static func topInset(_ proxy: GeometryProxy) -> CGFloat {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        let window = (windows.first(where: \.isKeyWindow) ?? windows.first)?.safeAreaInsets.top ?? 0
        return max(proxy.safeAreaInsets.top, window)
    }

    let home: HomeKind
    /// フィルムの残りは FilmCounter だけを見る
    private let film = FilmCounter.shared
    var avatarImage: UIImage?
    var avatarName = ""
    var showsBadge = false
    var onAvatar: () -> Void = {}
    /// 「消灯まで」の行を押したとき(光のパネルをひらく・とじる)
    var onConsumption: () -> Void = {}
    var avatarSwitch = AvatarSwitch()
    var clock: () -> Date = Date.init

    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var onScreen = false

    private var tickActive: Bool { onScreen && scenePhase == .active }

    var body: some View {
        ZStack(alignment: .topLeading) {
            topRow
                .padding(.top, 8)
            let remaining = film.remaining
            TimelineView(LaterHeaderSchedule(active: tickActive)) { context in
                consumption(now: clock(), tick: context.date, remaining: remaining)
            }
            .padding(.top, Self.pillTop)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: Self.height, alignment: .top)
        .onAppear { onScreen = true }
        .onDisappear { onScreen = false }
    }

    // MARK: 1行目

    private var topRow: some View {
        HStack(spacing: 0) {
            logo
            Spacer(minLength: 12)
            HomeAvatarControl(
                avatarImage: avatarImage, name: avatarName, showsBadge: showsBadge,
                onProfile: onAvatar, control: avatarSwitch
            )
            .padding(.trailing, 16)
        }
        .padding(.leading, 20)
        .frame(height: 44)
    }

    private var logo: some View {
        HStack(alignment: .center, spacing: 4) {
            Text("Lattag")
                .font(HeaderFont.logo())
                .tracking(-0.05 * 31)
                .foregroundStyle(palette.ink)
                .accessibilityLabel("Lattag")
            homeLabel
                .offset(y: -14)
        }
        .fixedSize()
        .dynamicTypeSize(.large)
    }

    /// v22:「today / yesterday」の文字ボタン(セリフ斜体 16pt。いまの方は #6E6E73、もう一方は #C2C1C7)。押すと もう一方のホームへ(sel)
    private var homeLabel: some View {
        Button {
            Haptics.play(.detent)
            avatarSwitch.onSwitch()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("today").foregroundStyle(homeLabelColor(selected: home == .today))
                Text("/").font(.system(size: 13)).foregroundStyle(Color(hex: palette.isNight ? "4A4A50" : "DADADF"))
                Text("yesterday").foregroundStyle(homeLabelColor(selected: home == .yesterday))
            }
            .font(.system(size: 16, design: .serif).italic())
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.96))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: home)
        .accessibilityLabel(home == .today ? "いまは 今日のホーム。押すと 昨日のホームへ" : "いまは 昨日のホーム。押すと 今日のホームへ")
    }

    /// today / yesterday の 色。夜は 背景が ほぼ黒なので、いまの方は 明るく、もう一方も 読める 灰色(#8E8E93 = 約6:1)
    private func homeLabelColor(selected: Bool) -> Color {
        if palette.isNight { return Color(hex: selected ? "E5E5EA" : "8E8E93") }
        return Color(hex: selected ? "6E6E73" : "C2C1C7")
    }

    // MARK: 「消灯まで」の行

    private func consumption(now: Date, tick: Date, remaining: Int) -> some View {
        let capsule = DailyWindow.capsule(now: now)
        let label = DailyWindow.capsuleParts(now: now).label
        let lastHour = LaterHeaderTime.isLastHour(now: now)
        let timeText = LaterHeaderTime.text(now: now)
        let pulseOn = lastHour && !reduceMotion && tickActive
        let dim = pulseOn && Int(tick.timeIntervalSinceReferenceDate) % 2 != 0
        let onInk = palette.bg
        let textColor = lastHour ? onInk : palette.ink
        let dotColor = palette.isNight ? Color(hex: "FF9E5E") : palette.accent
        let usedFrame = palette.isNight ? Color.white.opacity(0.25) : Color(hex: "D1D1D6")
        let spoken = "\(label) \(LaterHeaderTime.spokenDuration(capsule.minutes))。フィルム のこり\(remaining)枚"

        let content = HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
                .background(Circle().fill(dotColor.opacity(0.16)).frame(width: 13, height: 13))
                .opacity(dim ? 0.6 : 1)
                .animation(.easeInOut(duration: 1), value: dim)
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(textColor)
                .lineLimit(1)
            Text(timeText)
                .font(HeaderFont.mono(12.5))
                .monospacedDigit()
                .foregroundStyle(textColor)
                .lineLimit(1)
                .fixedSize()
            Rectangle()
                .fill(lastHour ? onInk.opacity(0.2) : palette.line)
                .frame(width: 1, height: 11)
            HStack(spacing: 3) {
                ForEach(0..<FilmRoll.shotsPerDay, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(index < remaining ? dotColor : usedFrame)
                        .frame(width: 6, height: 9)
                }
            }
            Text("\(remaining)")
                .font(HeaderFont.mono(11))
                .foregroundStyle(lastHour ? onInk.opacity(0.6) : palette.sub)
            Text("›")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(lastHour ? onInk.opacity(0.6) : palette.sub)
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .frame(height: 30)
        .background(Capsule().fill(palette.ink).opacity(lastHour ? 1 : 0))
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.3), value: lastHour)

        return Button {
            TapConsumption.mark()
            onConsumption()
        } label: { content }
            .buttonStyle(.plain)
            .padding(.leading, 10)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spoken)
            .accessibilityHint("ダブルタップで詳細")
    }
}

// MARK: - 光のパネル(今日のホーム用。昨日のホームは HomeV5Container が持つ)

extension View {
    /// 「消灯まで」の行から光のパネルをひらく(暗幕つき)。top はヘッダーの上端(安全領域の高さ)。
    func lightsPanelOverlay(isOpen: Binding<Bool>, now: Date, top: CGFloat, width: CGFloat) -> some View {
        overlay {
            ZStack(alignment: .topLeading) {
                if isOpen.wrappedValue {
                    LightsPanelDim { withAnimation(.easeOut(duration: 0.25)) { isOpen.wrappedValue = false } }
                        .environment(\.colorScheme, .dark)
                        .transition(.opacity)
                    LightsPanel(
                        now: now,
                        width: min(300, width - 44),
                        onClose: { withAnimation(.easeOut(duration: 0.25)) { isOpen.wrappedValue = false } }
                    )
                    .padding(.top, top + LaterHeader.height + 6)
                    .padding(.leading, 20)
                    .environment(\.colorScheme, .dark)
                    .transition(LightsPanel.transition(anchor: .topLeading))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
