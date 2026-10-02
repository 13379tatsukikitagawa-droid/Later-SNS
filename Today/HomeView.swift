import SwiftUI

/// Home画面(再設計 Step 2:状態で変わる1画面)。「今、何ができるか」を1つだけ伝える。
///
/// 上から:ヘッダー(ワードマーク+時間のカプセル)→ 点の輪(みんなの昨日)→ 見出しと説明 → ボタン1つ。
/// 状態はHomeState.resolve(now:myCaptureDates:)で決まり、ボタンの位置は全ての状態で同じ。
/// この画面では振動を一切使わない(Laterの振動は「撮る」「ひらく」「選ぶ」の3か所だけ)。
struct HomeView: View {
    /// 自分が撮った写真の撮影日時。
    let myCaptureDates: [Date]
    /// 昨日の枚数。nilなら取得できていない(「—」を表示する)。
    let yesterdayCount: Int?
    /// 撮影画面・仮の「昨日を見る」画面などで、Homeが覆われているか。
    let isCovered: Bool
    /// zoom遷移の起点(ボタンの位置)を撮影画面と共有するための名前空間。
    let transitionNamespace: Namespace.ID
    let onShoot: () -> Void
    let onViewYesterday: () -> Void
    /// 現在時刻。プレビューやテストでは任意の時刻を返す。
    var clock: () -> Date = Date.init

    static let primaryActionTransitionID = "home.primaryAction"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.selectedMainTabIndex) private var selectedMainTabIndex

    @ScaledMetric(relativeTo: .title) private var headlineSize: CGFloat = 27
    @ScaledMetric(relativeTo: .subheadline) private var bodySize: CGFloat = 13.5
    @ScaledMetric(relativeTo: .headline) private var buttonTextSize: CGFloat = 16

    @State private var now = Date()
    @State private var isOnScreen = false
    /// 登場演出を一度だけ行うためのフラグ(撮影から戻った時などは演出をやり直さない)。
    @State private var hasPlayedEntrance = false
    @State private var entranceStart: Date?
    @State private var isTextVisible = false
    @State private var isButtonVisible = false
    @State private var displayedCount = 0
    @State private var waveStart: Date?
    @State private var isBreathing = false
    @State private var isCapsuleDotLit = false

    private static let homeTabIndex = 0

    private var state: HomeState {
        HomeState.resolve(now: now, myCaptureDates: myCaptureDates)
    }

    private var isVisible: Bool {
        isOnScreen && scenePhase == .active && selectedMainTabIndex == Self.homeTabIndex && !isCovered
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 8)

            Spacer(minLength: 16)

            ringBlock
                .scaleEffect(isCovered ? 1.08 : 1)
                .opacity(isCovered ? 0.25 : 1)
                .animation(.easeInOut(duration: 0.45), value: isCovered)

            Spacer(minLength: 20)

            textBlock
                .frame(height: 196, alignment: .top)
                .padding(.horizontal, 24)
                .opacity(isTextVisible ? 1 : 0)
                .offset(y: isTextVisible || reduceMotion ? 0 : 12)

            primaryButton
                .opacity(isButtonVisible ? 1 : 0)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HomePalette.background.ignoresSafeArea())
        .overlay {
            FilmGrainOverlay(opacity: 0.05, blendMode: .normal)
                .ignoresSafeArea()
        }
        .onAppear {
            isOnScreen = true
            now = clock()
            playEntranceIfNeeded()
        }
        .onDisappear { isOnScreen = false }
        .onChange(of: scenePhase) { _, phase in
            // バックグラウンドから戻った時は時間が経っている可能性があるため再計算する。
            if phase == .active { updateNow() }
        }
        .onChange(of: state) { old, new in
            handleStateChange(from: old, to: new)
        }
        .onChange(of: countValue) { _, newValue in
            withAnimation(.easeOut(duration: 0.9)) { displayedCount = newValue }
        }
        .task(id: isVisible) {
            // 時刻の表示(消灯まで・9:00まで)は1分ごとに更新する。見えていない間は止める。
            guard isVisible else { return }
            updateNow()
            while !Task.isCancelled {
                let current = clock()
                let seconds = Calendar.current.component(.second, from: current)
                try? await Task.sleep(for: .seconds(Double(60 - seconds) + 0.05))
                guard !Task.isCancelled else { return }
                updateNow()
            }
        }
    }

    private func updateNow() {
        withAnimation(.easeInOut(duration: 0.5)) { now = clock() }
    }

    // MARK: - 登場・状態の切り替え

    private func playEntranceIfNeeded() {
        guard !hasPlayedEntrance else { return }
        hasPlayedEntrance = true
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.5)) {
                isTextVisible = true
                isButtonVisible = true
                displayedCount = countValue
            }
        } else {
            entranceStart = Date()
            withAnimation(.easeOut(duration: 0.9)) { displayedCount = countValue }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) { isTextVisible = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) { isButtonVisible = true }
        }
        startIdleAnimations()
    }

    private func startIdleAnimations() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { isBreathing = true }
        withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { isCapsuleDotLit = true }
    }

    private func handleStateChange(from old: HomeState, to new: HomeState) {
        // 9:00ちょうどに①→②(④)へ切り替わったら、点が中心から外側へ波のように光る。
        if case .beforeOpening = old, new.canShoot, !reduceMotion {
            waveStart = Date()
        }
        withAnimation(.easeOut(duration: 0.9)) { displayedCount = countValue }
    }

    // MARK: - ヘッダー

    private var header: some View {
        HStack {
            Text("Later")
                .font(.system(size: 19, weight: .bold))
                .tracking(-0.05 * 19)
                .foregroundStyle(.white)
            Spacer()
            timeCapsule
        }
    }

    /// 撮れる時間は「消灯まで 05:49」、9:00前は現在時刻(点はグレー)。
    private var timeCapsule: some View {
        let isOpenHours: Bool = {
            if case .beforeOpening = state { return false }
            if case .lightsOut = state { return false }
            return true
        }()
        let label = isOpenHours ? "消灯まで \(Self.lightsOutRemaining(from: now))" : Self.clockFormatter.string(from: now)
        return HStack(spacing: 7) {
            Circle()
                .fill(isOpenHours ? Color.white : HomePalette.disabledText)
                .frame(width: 5, height: 5)
                .opacity(isCapsuleDotLit ? 1 : 0.7)
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(HomePalette.surface))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isOpenHours ? "消灯まで \(Self.spokenDuration(Self.minutesUntilLightsOut(from: now)))" : "現在 \(Self.clockFormatter.string(from: now))")
    }

    // MARK: - 点の輪と中心

    private var ringTone: HomeDotRing.Tone {
        switch state {
        case .beforeOpening, .lightsOut: return .dim
        case .canShoot, .returning: return .bright
        case .shot: return .colored
        }
    }

    private var countValue: Int { yesterdayCount ?? 0 }

    private var ringBlock: some View {
        ZStack {
            Circle()
                .fill(glowColor)
                .frame(width: 250, height: 250)
                .blur(radius: 60)
                .animation(.easeInOut(duration: 0.5), value: ringTone)

            HomeDotRing(
                count: min(countValue, HomeDotRing.Layout.capacity),
                tone: ringTone,
                isAnimating: isVisible && !reduceMotion,
                entranceStart: entranceStart,
                waveStart: waveStart
            )

            centerLabel
        }
        .frame(width: HomeDotRing.diameter, height: HomeDotRing.diameter)
    }

    private var glowColor: Color {
        switch ringTone {
        case .dim: return .white.opacity(0.03)
        case .bright: return .white.opacity(0.07)
        case .colored: return HomePalette.orange.opacity(0.14)
        }
    }

    private var centerLabel: some View {
        let (number, caption) = centerTexts
        return VStack(spacing: 8) {
            Text(number)
                .font(.system(size: 42, weight: .bold))
                .tracking(-0.05 * 42)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(displayedCount)))
                .foregroundStyle(.white)
            Text(caption)
                .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                .tracking(0.14 * 9.5)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(centerAccessibilityLabel)
    }

    private var centerTexts: (String, String) {
        switch state {
        case .beforeOpening(let opensAt):
            return ("09:00", "まで \(Self.hoursMinutes(Self.minutesUntil(opensAt, from: now)))")
        case .lightsOut:
            return ("09:00", "明日、はじまる")
        default:
            guard let yesterdayCount else { return ("—", "昨日の枚数を確認できません") }
            if yesterdayCount == 0 { return ("0", "昨日は、まだ誰も撮っていません") }
            let caption = ringTone == .colored ? "枚の昨日が、ひらいた" : "枚の昨日が、閉じている"
            return (displayedCount.formatted(.number.grouping(.automatic)), caption)
        }
    }

    private var centerAccessibilityLabel: String {
        switch state {
        case .beforeOpening(let opensAt):
            return "撮影は9時にはじまります。あと\(Self.spokenDuration(Self.minutesUntil(opensAt, from: now)))。"
        case .lightsOut:
            return "今日の撮影は終わりました。明日9時にはじまります。"
        default:
            guard let yesterdayCount else { return "昨日の枚数を確認できません。" }
            if yesterdayCount == 0 { return "昨日は、まだ誰も撮っていません。" }
            let formatted = yesterdayCount.formatted(.number.grouping(.automatic))
            if ringTone == .colored { return "昨日の写真、\(formatted)枚がひらいています。" }
            return "昨日の写真、\(formatted)枚が閉じています。今日を撮ると、ひらきます。"
        }
    }

    // MARK: - 見出しと説明

    private var textBlock: some View {
        VStack(spacing: 12) {
            Text(headline)
                .font(.system(size: headlineSize, weight: .bold))
                .tracking(-0.045 * headlineSize)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.white)

            Text(description)
                .font(.system(size: bodySize))
                .tracking(-0.01 * bodySize)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .foregroundStyle(HomePalette.subText)
                .fixedSize(horizontal: false, vertical: true)

            extraInfo
                .padding(.top, 4)
        }
        .id(textIdentity)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.5), value: textIdentity)
        .frame(maxWidth: .infinity)
    }

    /// 見出し・ボタンのクロスフェード単位(状態の種類)。
    private var textIdentity: String {
        switch state {
        case .beforeOpening: return "before"
        case .canShoot: return "canShoot"
        case .shot: return "shot"
        case .returning: return "returning"
        case .lightsOut: return "lightsOut"
        }
    }

    private var headline: String {
        switch state {
        case .beforeOpening, .lightsOut: return "今日は、まだ\nはじまっていません。"
        case .canShoot, .returning: return "今日を撮ると、\nみんなの昨日がひらく。"
        case .shot: return "昨日が、\nひらいています。"
        }
    }

    private var description: String {
        switch state {
        case .beforeOpening: return "9:00 に、みんな同時にはじまります。"
        case .lightsOut: return "今日の撮影は、おしまいです。"
        case .canShoot: return "1日1枚。撮った写真は、その場では見られません。"
        case .returning: return "お休みしても、何も失いません。"
        case .shot: return "今日の1枚は、次にあなたが撮った瞬間にひらきます。"
        }
    }

    @ViewBuilder
    private var extraInfo: some View {
        switch state {
        case .shot(let shotAt):
            Text("今日の1枚は、預けました ・ \(Self.clockFormatter.string(from: shotAt))")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        case .returning(let waitingSince):
            waitingCard(since: waitingSince)
        default:
            EmptyView()
        }
    }

    /// ④の小さなカード。待っている写真の日付だけを出し、写真そのものは見せない。
    private func waitingCard(since date: Date) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.black)
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .fill(.white)
                        .frame(width: 5, height: 5)
                        .shadow(color: .white.opacity(0.7), radius: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text("あなたの \(Self.monthDayFormatter.string(from: date)) の1枚が、待っています")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                Text("次に撮ったとき、ひらきます")
                    .font(.system(size: 11.5))
                    .foregroundStyle(HomePalette.subText)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(HomePalette.surface))
        .accessibilityElement(children: .combine)
    }

    // MARK: - ボタン

    private var primaryButtonTitle: String {
        switch state {
        case .beforeOpening: return "9:00 に、はじまる"
        case .lightsOut: return "明日 9:00 に、はじまる"
        case .canShoot, .returning: return "今日を撮る"
        case .shot: return "昨日を見る"
        }
    }

    private var isPrimaryEnabled: Bool {
        switch state {
        case .canShoot, .returning, .shot: return true
        case .beforeOpening, .lightsOut: return false
        }
    }

    private var primaryButton: some View {
        Button {
            if case .shot = state {
                onViewYesterday()
            } else if state.canShoot {
                onShoot()
            }
        } label: {
            Text(primaryButtonTitle)
                .font(.system(size: buttonTextSize, weight: .semibold))
                .tracking(-0.01 * buttonTextSize)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 34)
                .frame(height: 56)
                .contentTransition(.opacity)
        }
        .buttonStyle(HomePrimaryButtonStyle(isEnabled: isPrimaryEnabled, breathes: state.canShoot && isBreathing))
        .disabled(!isPrimaryEnabled)
        .matchedTransitionSource(id: Self.primaryActionTransitionID, in: transitionNamespace)
        .animation(.easeInOut(duration: 0.5), value: textIdentity)
        .accessibilityLabel(primaryAccessibilityLabel)
    }

    private var primaryAccessibilityLabel: String {
        switch state {
        case .beforeOpening: return "9時にはじまります"
        case .lightsOut: return "明日9時にはじまります"
        default: return primaryButtonTitle
        }
    }

    // MARK: - 時刻の表記

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "M/d"
        return formatter
    }()

    private static func minutesUntil(_ date: Date, from now: Date) -> Int {
        max(0, Int(ceil(date.timeIntervalSince(now) / 60)))
    }

    private static func minutesUntilLightsOut(from now: Date) -> Int {
        Int((DailyExposureRules.remainingUntilLightsOut(from: now) ?? 0) / 60)
    }

    private static func lightsOutRemaining(from now: Date) -> String {
        hoursMinutes(minutesUntilLightsOut(from: now))
    }

    /// 「01:18」
    private static func hoursMinutes(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// 「1時間18分」
    private static func spokenDuration(_ minutes: Int) -> String {
        let hours = minutes / 60, rest = minutes % 60
        if hours == 0 { return "\(rest)分" }
        return rest == 0 ? "\(hours)時間" : "\(hours)時間\(rest)分"
    }
}

// MARK: - ボタンのスタイル

/// 白い丸いボタン(高さ56pt、完全な丸み、白い光)。押している間は0.97倍に縮み、光が少し強くなる。
/// 押せない時はグレー(#1C1C1E・文字#8E8E93)。
private struct HomePrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool
    /// 呼吸の山側にいるか(②④のみ。光が0.12↔0.28で3秒周期)。
    let breathes: Bool

    func makeBody(configuration: Configuration) -> some View {
        let glow: Double = {
            guard isEnabled else { return 0 }
            let base = breathes ? 0.28 : 0.12
            return configuration.isPressed ? base + 0.12 : base
        }()
        return configuration.label
            .foregroundStyle(isEnabled ? Color.black : HomePalette.disabledText)
            .background(Capsule().fill(isEnabled ? Color.white : HomePalette.surface))
            .shadow(color: .white.opacity(glow), radius: 18)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - プレビュー(時刻と撮影状況を差し込んで4つの状態を確認する)

private struct HomeViewPreview: View {
    let now: Date
    let captures: [Date]
    let count: Int?
    @Namespace private var namespace

    var body: some View {
        HomeView(
            myCaptureDates: captures,
            yesterdayCount: count,
            isCovered: false,
            transitionNamespace: namespace,
            onShoot: {},
            onViewYesterday: {},
            clock: { now }
        )
    }
}

private func previewDate(dayOffset: Int = 0, _ hour: Int, _ minute: Int) -> Date {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let day = calendar.date(byAdding: .day, value: dayOffset, to: today)!
    return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
}

#Preview("① 9:00前") {
    HomeViewPreview(now: previewDate(7, 42), captures: [previewDate(dayOffset: -1, 20, 5)], count: 1284)
}

#Preview("② 撮れる") {
    HomeViewPreview(now: previewDate(18, 11), captures: [previewDate(dayOffset: -1, 20, 5)], count: 1284)
}

#Preview("③ 撮った後") {
    HomeViewPreview(now: previewDate(18, 30), captures: [previewDate(18, 11)], count: 1284)
}

#Preview("④ お休み明け") {
    HomeViewPreview(now: previewDate(12, 0), captures: [previewDate(dayOffset: -3, 21, 40)], count: 12)
}

#Preview("昨日0枚") {
    HomeViewPreview(now: previewDate(12, 0), captures: [], count: 0)
}
