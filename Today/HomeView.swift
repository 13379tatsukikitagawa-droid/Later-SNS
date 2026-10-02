import SwiftUI

/// Home画面(再設計 Step 2 + v2:状態で変わる1画面)。「今、何ができるか」を1つだけ伝える。
///
/// 上から:ヘッダー(Later・時間のカプセル・アバター)→ 点の輪(みんなの昨日、260pt)→ 見出しと説明
/// → 現像カード(預けた1枚の色と濃さ)→ グループの段。画面の下の「月」(撮る・ひらく・待つ)は、
/// 次の画面になってふくらむため、Homeの上に重なる層としてTodayViewが持つ。
/// 状態はHomeState.resolveで決まる。振動は「ひらく」の長押し(月)だけで使う。
struct HomeView: View {
    /// 自分が撮った写真の撮影日時。
    let myCaptureDates: [Date]
    /// これまでに1枚でも預けたか(写真が7日で削除された後も、記録から判定する)
    let hasDeposited: Bool
    /// 今日より前で、最後に預けた1枚の撮影時刻
    let lastDepositBeforeToday: Date?
    /// 今日、長押しで昨日をひらいたか
    let openedToday: Bool
    /// 昨日の枚数。nilなら取得できていない(「—」を表示する)。
    let yesterdayCount: Int?
    /// 日付(ExposureDay.dayKey)ごとの、写真の主要な3色
    let tonesByDay: [String: [Color]]
    /// MEを除いた、参加中のグループ
    let groups: [LaterGroup]
    /// 円をそのグループの点だけに絞っている時のグループ
    let selectedGroupID: UUID?
    /// タグ画面・撮影画面・仮の「昨日を見る」画面などで、Homeが覆われているか。
    let isCovered: Bool
    /// 月の長押し(③)の進み具合。円の色づきが同じ値を読む。
    let holdModel: HoldGaugeModel
    /// 右上のアバター(プロフィール画像。なければペルソナのアイコン)
    let avatarImage: UIImage?
    let avatarSeed: UUID?
    /// あなたのページに、見ていない変化がある(現像が100%になった)
    let showsAvatarBadge: Bool
    let onOpenProfile: () -> Void
    /// 現像が100%になった(アバターの白い点を点ける)。引数は、その1枚を表すキー。
    let onDevelopFinished: (String) -> Void
    /// グループの輪をタップした(nilなら「みんな」に戻る)
    let onSelectGroup: (LaterGroup?) -> Void
    let onCreateGroup: () -> Void
    /// 現在時刻。プレビューやテストでは任意の時刻を返す。
    var clock: () -> Date = Date.init

    private static let homeTabIndex = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.selectedMainTabIndex) private var selectedMainTabIndex

    @ScaledMetric(relativeTo: .title) private var headlineSize: CGFloat = 25
    @ScaledMetric(relativeTo: .subheadline) private var bodySize: CGFloat = 13

    @State private var now = Date()
    @State private var isOnScreen = false
    /// 登場演出を一度だけ行うためのフラグ(撮影から戻った時などは演出をやり直さない)。
    @State private var hasPlayedEntrance = false
    @State private var entranceStart: Date?
    @State private var isTextVisible = false
    @State private var isCardVisible = false
    @State private var isStripVisible = false
    @State private var displayedCount = 0
    @State private var waveStart: Date?
    @State private var isBreathing = false
    @State private var isCapsuleDotLit = false
    /// 現像カードと「あなたの1点」に表示している濃さ(開くたびに0からのぼる)
    @State private var displayedDevelop: Double = 0
    @State private var myDotPulseStart: Date?

    private var state: HomeState {
        HomeState.resolve(now: now, myCaptureDates: myCaptureDates, hasDeposited: hasDeposited, openedToday: openedToday)
    }

    private var isVisible: Bool {
        isOnScreen && scenePhase == .active && selectedMainTabIndex == Self.homeTabIndex && !isCovered
    }

    var body: some View {
        GeometryReader { proxy in
            let fixedHeight: CGFloat = 450
            let ringSize = min(260, max(220, proxy.size.height - fixedHeight))
            let isCompact = proxy.size.height - fixedHeight < 220
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                ringBlock(size: ringSize)
                    .padding(.top, 4)
                    .scaleEffect(isCovered ? 1.08 : (selectedGroupID == nil ? 1 : 0.92))
                    .opacity(isCovered ? 0.25 : 1)
                    .animation(.easeInOut(duration: 0.45), value: isCovered)
                    .animation(.easeInOut(duration: 0.5), value: selectedGroupID)
                    .contentShape(Circle())
                    .onTapGesture { if selectedGroupID != nil { onSelectGroup(nil) } }

                textBlock
                    .frame(height: 88, alignment: .top)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .opacity(isTextVisible ? 1 : 0)
                    .offset(y: isTextVisible || reduceMotion ? 0 : 12)

                developCard
                    .frame(height: HomeDevelopCard.height)
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
                    .opacity(isCardVisible ? 1 : 0)

                HomeGroupStrip(
                    groups: groups,
                    selectedGroupID: selectedGroupID,
                    showsLabel: !isCompact,
                    onSelect: { group in onSelectGroup(group.id == selectedGroupID ? nil : group) },
                    onCreate: onCreateGroup
                )
                .padding(.top, 24)
                .opacity(isStripVisible ? 1 : 0)

                // 画面の下の月(TodayViewが重ねる)の場所
                Spacer(minLength: MoonLayout.visibleHeight + 16)
            }
            .frame(width: proxy.size.width)
        }
        .background(HomePalette.background.ignoresSafeArea())
        .overlay {
            FilmGrainOverlay(opacity: 0.05, blendMode: .normal)
                .ignoresSafeArea()
        }
        .onAppear {
            isOnScreen = true
            now = clock()
            playEntranceIfNeeded()
            playDevelopRise()
            reportDevelopFinishedIfNeeded()
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
        .onChange(of: developTarget) { old, new in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { displayedDevelop = new }
            // 100%になった瞬間に開いていたら、「あなたの1点」の輪が1回だけふくらんで消える(振動なし)。
            if old < 1, new >= 1, isVisible, !reduceMotion { myDotPulseStart = Date() }
            reportDevelopFinishedIfNeeded()
        }
        .task(id: isVisible) {
            // 時刻の表示と現像の濃さは1分ごとに更新する。見えていない間は止める。
            guard isVisible else { return }
            updateNow()
            while !Task.isCancelled {
                let seconds = Calendar.current.component(.second, from: clock())
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
                isCardVisible = true
                isStripVisible = true
                displayedCount = countValue
            }
        } else {
            entranceStart = Date()
            withAnimation(.easeOut(duration: 0.9)) { displayedCount = countValue }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) { isTextVisible = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.45)) { isCardVisible = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.7)) { isStripVisible = true }
        }
        startIdleAnimations()
    }

    /// 開くたびに、現像カードと「あなたの1点」がいまの濃さまで0.9秒かけてのぼる。
    private func playDevelopRise() {
        let target = developTarget
        guard !reduceMotion else {
            displayedDevelop = target
            return
        }
        displayedDevelop = 0
        withAnimation(.easeOut(duration: 0.9)) { displayedDevelop = target }
    }

    private func startIdleAnimations() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { isBreathing = true }
        withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { isCapsuleDotLit = true }
    }

    private func handleStateChange(from old: HomeState, to new: HomeState) {
        // 9:00ちょうどに①→②(④⑤)へ切り替わったら、点が中心から外側へ波のように光る。
        if case .beforeOpening = old, new.canShoot, !reduceMotion {
            waveStart = Date()
        }
        if case .shot = new {
            holdModel.reset()
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
            avatarButton
                .padding(.leading, 12 - 4)
        }
    }

    /// 右上のアバター(直径36pt、タップ領域44pt)。右上の白い点は「見ていない変化がある」時だけ。
    private var avatarButton: some View {
        Button(action: onOpenProfile) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let avatarImage {
                        Image(uiImage: avatarImage).resizable().aspectRatio(contentMode: .fill)
                    } else if let avatarSeed {
                        PersonaIcon(seed: avatarSeed)
                    } else {
                        Circle().fill(HomePalette.surface)
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.55), lineWidth: 1.5))
                .overlay(Circle().stroke(.black, lineWidth: 2).padding(-1))

                if showsAvatarBadge {
                    Circle()
                        .fill(.white)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(.black, lineWidth: 2))
                        .shadow(color: .white.opacity(0.7), radius: 4)
                        .offset(x: 2, y: -2)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showsAvatarBadge ? "あなたのページ、新しい変化があります" : "あなたのページ")
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
        case .canShoot, .returning, .firstDay, .shot: return .bright
        case .opened: return .colored
        }
    }

    private var countValue: Int { yesterdayCount ?? 0 }

    private func ringBlock(size: CGFloat) -> some View {
        TimelineView(.animation(paused: !holdModel.isMoving)) { context in
            let openProgress: Double = {
                if case .shot = state { return holdModel.progress(at: context.date) }
                return 0
            }()
            ZStack {
                Circle()
                    .fill(glowColor(openProgress: openProgress))
                    .frame(width: size * 0.84, height: size * 0.84)
                    .blur(radius: 52)
                    .animation(.easeInOut(duration: 0.5), value: ringTone)

                HomeDotRing(
                    count: min(countValue, HomeDotRing.Layout.capacity),
                    tone: ringTone,
                    isAnimating: isVisible && !reduceMotion,
                    entranceStart: entranceStart,
                    waveStart: waveStart,
                    openProgress: openProgress,
                    myDot: myDot
                )
                .scaleEffect(size / HomeDotRing.diameter)
                .frame(width: size, height: size)

                centerLabel(openProgress: openProgress)
            }
            .frame(width: size, height: size)
        }
    }

    private func glowColor(openProgress: Double) -> Color {
        switch ringTone {
        case .dim: return .white.opacity(0.03)
        case .colored: return HomePalette.orange.opacity(0.14)
        case .bright:
            // 長押しでひらいている間は、白から薄いオレンジへ。
            guard openProgress > 0 else { return .white.opacity(0.07) }
            return Color(red: 1, green: 1 - 0.38 * openProgress, blue: 1 - 0.63 * openProgress).opacity(0.07 + 0.07 * openProgress)
        }
    }

    private func centerLabel(openProgress: Double) -> some View {
        let (number, caption) = centerTexts(openProgress: openProgress)
        return VStack(spacing: 7) {
            Text(number)
                .font(.system(size: 38, weight: .bold))
                .tracking(-0.05 * 38)
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

    private func centerTexts(openProgress: Double) -> (String, String) {
        switch state {
        case .beforeOpening(let opensAt):
            return ("09:00", "まで \(Self.hoursMinutes(Self.minutesUntil(opensAt, from: now)))")
        case .lightsOut:
            return ("09:00", "明日、はじまる")
        default:
            guard let yesterdayCount else { return ("—", "昨日の枚数を確認できません") }
            if yesterdayCount == 0 { return ("0", "昨日は、まだ誰も撮っていません") }
            let number = displayedCount.formatted(.number.grouping(.automatic))
            switch state {
            case .shot:
                if holdModel.isDone { return (number, "枚の昨日が、ひらいた") }
                return (number, openProgress > 0.5 ? "枚の昨日が、ひらきかけている" : "枚の昨日が、現像ずみ")
            case .opened:
                return (number, "枚の昨日が、ひらいた")
            default:
                return (number, "枚の昨日が、閉じている")
            }
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
            switch state {
            case .shot: return "昨日の写真、\(formatted)枚が現像されました。長押しでひらきます。"
            case .opened: return "昨日の写真、\(formatted)枚がひらいています。"
            default: return "昨日の写真、\(formatted)枚が閉じています。今日を撮ると、ひらきます。"
            }
        }
    }

    // MARK: - 見出しと説明

    private var textBlock: some View {
        VStack(spacing: 8) {
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
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(HomePalette.subText)
        }
        .id(state.kind)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.5), value: state.kind)
        .frame(maxWidth: .infinity)
    }

    private var headline: String {
        switch state {
        case .beforeOpening, .lightsOut: return "今日は、まだ\nはじまっていません。"
        case .canShoot, .returning, .firstDay: return "今日を撮ると、\nみんなの昨日がひらく。"
        case .shot: return "昨日が、\n現像されました。"
        case .opened: return "昨日が、\nひらいています。"
        }
    }

    private var description: String {
        switch state {
        case .beforeOpening: return "撮影は 9:00 から。"
        case .lightsOut: return "今日の撮影は、おしまいです。"
        case .canShoot: return "あなたの昨日の1枚も、同時にひらきます。"
        case .returning: return "お休みしても、何も失いません。"
        case .firstDay: return "はじめての1枚を、預けましょう。"
        case .shot: return "長押しで、みんなの昨日がひらく。"
        case .opened: return "今日の1枚は、明日の朝に仕上がります。"
        }
    }

    // MARK: - 現像

    /// 現像カードに出す1枚。撮った後は今日の1枚、それ以外は最後に預けた1枚。
    private var developSubject: DevelopSubject? {
        let calendar = Calendar.current
        switch state {
        case .shot(let at), .opened(let at):
            return DevelopSubject(kind: .today, capturedAt: at, tones: tones(for: at))
        case .firstDay:
            return nil
        default:
            guard let last = lastDepositBeforeToday else { return nil }
            let isYesterday = calendar.isDateInYesterday(last)
            let kind: DevelopSubject.Kind
            if case .returning = state {
                kind = .waiting(last)
            } else {
                kind = isYesterday ? .yesterday : .waiting(last)
            }
            return DevelopSubject(kind: kind, capturedAt: last, tones: tones(for: last))
        }
    }

    private func tones(for date: Date) -> [Color] {
        let key = ExposureDayStore.dayKey(for: date)
        let tones = tonesByDay[key] ?? []
        return tones.count >= 3 ? tones : DevelopProgress.defaultTones
    }

    /// 現在時刻と撮影時刻から計算した濃さ(保存しない)
    private var developTarget: Double {
        guard let subject = developSubject else { return 0 }
        return DevelopProgress.progress(capturedAt: subject.capturedAt, now: now)
    }

    @ViewBuilder
    private var developCard: some View {
        switch state {
        case .firstDay:
            HomeDevelopCard(subject: nil, progress: 0)
        default:
            if let subject = developSubject {
                HomeDevelopCard(subject: subject, progress: displayedDevelop)
                    .id(subject.capturedAt)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.5), value: subject.capturedAt)
            } else {
                Color.clear
            }
        }
    }

    /// 現像が100%になったら、アバターの白い点を点ける(その1枚につき1度)。
    private func reportDevelopFinishedIfNeeded() {
        guard let subject = developSubject, developTarget >= 1 else { return }
        onDevelopFinished(String(Int(subject.capturedAt.timeIntervalSince1970)))
    }

    /// 円の中の「あなたの1点」。預けた1枚がない時(⑤)は出さない。
    private var myDot: HomeDotRing.MyDot? {
        guard let subject = developSubject else { return nil }
        let p = displayedDevelop
        return HomeDotRing.MyDot(color: DevelopProgress.developed(subject.tones[0], p), progress: p, pulseStart: myDotPulseStart)
    }

    // MARK: - 時刻の表記

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
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

// MARK: - プレビュー(時刻と撮影状況を差し込んで状態を確認する)

private struct HomeViewPreview: View {
    let now: Date
    let captures: [Date]
    let count: Int?
    var openedToday = false
    @State private var holdModel = HoldGaugeModel()

    var body: some View {
        HomeView(
            myCaptureDates: captures,
            hasDeposited: !captures.isEmpty,
            lastDepositBeforeToday: captures.filter { $0 < Calendar.current.startOfDay(for: now) }.max(),
            openedToday: openedToday,
            yesterdayCount: count,
            tonesByDay: [:],
            groups: [],
            selectedGroupID: nil,
            isCovered: false,
            holdModel: holdModel,
            avatarImage: nil,
            avatarSeed: UUID(),
            showsAvatarBadge: true,
            onOpenProfile: {},
            onDevelopFinished: { _ in },
            onSelectGroup: { _ in },
            onCreateGroup: {},
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
    HomeViewPreview(now: previewDate(7, 42), captures: [previewDate(dayOffset: -1, 18, 11)], count: 1284)
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

#Preview("⑤ はじめての日") {
    HomeViewPreview(now: previewDate(12, 0), captures: [], count: 0)
}
