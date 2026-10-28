import SwiftUI

/// Home画面(v3)。状態(HomeState)と時刻は TodayView が1か所で決めて渡し、ここは表示するだけ。
///
/// 上端からの位置(iPhone 15・390×844 基準):ヘッダー60 → 光の球112〜412 → 見出し432 →
/// 現像カード536(高さ88)→ グループの見出し644 → グループの丸664。月だけは画面の下端から置くため、
/// Homeの上に重なる層として TodayView が持つ。高さが足りない機種では、ヘッダーより下を縦に詰める。
struct HomeView: View {
    let state: HomeState
    let now: Date
    let light: YesterdayLight
    let developContent: HomeDevelopCard.Content
    /// 現像カード・あなたの光に使う、強くぼかした色だけの画像
    let developTexture: UIImage?
    /// 今日撮った枚数(のこりフィルムに出す)
    var shotsToday: Int = 0
    let tones: [Color]
    /// ひらいたあとの光の色(昨日の写真の代表色)
    let openedTones: [Color]
    /// MEを除いた、参加中のグループの要約(昨日、投稿した人数)
    let groupSummaries: [GroupSummary]
    /// まだグループをつくれるか
    let canCreateGroup: Bool
    /// タグ画面・撮影画面・昨日を見る画面などで、Homeが覆われているか
    let isCovered: Bool
    /// 月の長押しの進み具合(球の色づきが同じ値を読む)
    let holdModel: HoldGaugeModel
    let avatarImage: UIImage?
    let avatarSeed: UUID?
    let showsAvatarBadge: Bool
    let onOpenProfile: () -> Void
    /// アバターの2回タップ・長押し(今日 / 昨日の切りかえ)
    var avatarSwitch = AvatarSwitch()
    var avatarName = ""
    let onDevelopTap: () -> Void
    let onSelectGroup: (UUID) -> Void
    let onCreateGroup: () -> Void
    var onJoinGroup: () -> Void = {}
    /// 列の先頭の「追加」タイルを押した(追加シートを出す)
    var onAddGroup: () -> Void = {}
    var arrivingGroupID: UUID?
    /// 起動アニメーションの、いまの時刻の見た目(LaunchFrame.at)。終わったら .finished
    var launch: LaunchFrame = .finished
    /// ウォーム起動の、0.4秒だけのきらめき(0〜1)
    var sparkle: Double = 0
    /// 光の球(230pt の円ぜんたい)をタップした(Mondo の入口)
    var onOrbTap: () -> Void = {}
    /// Mondo へのダイブ中(球は 5.5倍にふくらんで消え、ほかの要素は 320ms で消える)
    var isDiving = false

    private static let homeTabIndex = 0
    private static let baseHeight: CGFloat = 844

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// カプセルの文字の Dynamic Type の倍率(17ptで止める)
    @State private var showsLights = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.selectedMainTabIndex) private var selectedMainTabIndex

    @State private var isOnScreen = false
    /// 入場の開始時刻(状態が切りかわったとき・開き直したときだけ。2.8秒後に外す)
    @State private var entranceStart: Date?
    /// 常に動くもの(カードの光・オーブの波紋)の基準時刻
    @State private var ambientStart = Date()

    /// ひらいたあと(まだ撮れる more を含む)。Mondo の球の見た目を出す
    private var isOpened: Bool {
        switch state {
        case .opened, .more: return true
        default: return false
        }
    }

    private var isVisible: Bool {
        isOnScreen && scenePhase == .active && selectedMainTabIndex == Self.homeTabIndex && !isCovered
    }

    var body: some View {
        if state.usesChicHome {
            // 撮る前の今日のホームは、白 × シック(ChicHomeView)
            ChicHomeView(
                state: state, now: now, light: light,
                developContent: developContent, developTexture: developTexture,
                shotsToday: shotsToday, tones: tones,
                groupSummaries: groupSummaries, canCreateGroup: canCreateGroup,
                isCovered: isCovered,
                avatarImage: avatarImage, avatarSeed: avatarSeed, showsAvatarBadge: showsAvatarBadge,
                onOpenProfile: onOpenProfile, avatarSwitch: avatarSwitch, avatarName: avatarName,
                onDevelopTap: onDevelopTap, onSelectGroup: onSelectGroup, onCreateGroup: onCreateGroup,
                onJoinGroup: onJoinGroup, onAddGroup: onAddGroup, arrivingGroupID: arrivingGroupID,
                launch: launch, onOrbTap: onOrbTap, isDiving: isDiving
            )
        } else {
            darkBody
        }
    }

    private var darkBody: some View {
        GeometryReader { proxy in
            let fullHeight = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            // 高さが844より低い機種は、ヘッダーより下の位置を縦に詰め、球も少し小さくする。
            let k = min(1, max(0.72, (fullHeight - 200) / (Self.baseHeight - 200)))
            let top = max(proxy.safeAreaInsets.top, 44)
            let y: (CGFloat) -> CGFloat = { v in top + (v - 60) * k }

            let width = proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing
            ZStack(alignment: .top) {
                LaterHeader(
                    home: .today,
                    shotsToday: shotsToday,
                    avatarImage: avatarImage,
                    avatarName: avatarName,
                    showsBadge: showsAvatarBadge,
                    onAvatar: { if showsLights { withAnimation(.easeOut(duration: 0.25)) { showsLights = false } } else { onOpenProfile() } },
                    onConsumption: toggleLights,
                    avatarSwitch: avatarSwitch
                )
                    .environment(\.palette, .night)
                    .environment(\.colorScheme, .dark)
                    .frame(width: width, height: LaterHeader.height)
                    .offset(y: top)
                    .opacity(launch.headerOpacity * (isDiving ? 0 : 1))
                    .animation(.easeOut(duration: 0.32), value: isDiving)

                orb
                    .overlay {
                        OrbRipple(start: ambientStart, diameter: HomeLightOrb.Layout.diameter, isActive: ambientActive)
                    }
                    .scaleEffect(k)
                    .frame(width: HomeLightOrb.Layout.box * k, height: HomeLightOrb.Layout.box * k)
                    .offset(y: y(112))
                    .scaleEffect(isCovered && !isDiving ? 1.08 : 1)
                    .opacity(isCovered && !isDiving ? 0.25 : 1)
                    .animation(.easeInOut(duration: 0.45), value: isCovered)
                    .scaleEffect(isDiving ? 5.5 : 1, anchor: UnitPoint(x: 0.5, y: y(262) / max(1, fullHeight)))
                    .opacity(isDiving ? 0 : 1)
                    .animation(reduceMotion ? .easeOut(duration: 0.3) : .timingCurve(0.5, 0, 0.3, 1, duration: 0.72), value: isDiving)


                TimelineView(.animation(paused: entranceStart == nil)) { context in
                    textBlock(now: context.date)
                }
                    .padding(.horizontal, 24)
                    .frame(width: width)
                    .offset(y: y(432) + launch.headOffset)
                    .opacity(launch.headOpacity * (isDiving ? 0 : 1))
                    .animation(.easeOut(duration: 0.32), value: isDiving)

                TimelineView(.animation(paused: entranceStart == nil)) { context in
                    HomeDevelopCard(
                        content: developContent,
                        now: now,
                        texture: developTexture,
                        tones: tones,
                        isAnimating: isVisible && !reduceMotion,
                        film: (taken: shotsToday, isNight: state.isNight),
                        onTap: onDevelopTap
                    )
                    .overlay {
                        CardShimmer(start: ambientStart, isActive: ambientActive)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    }
                    .entrance(entrance(context.date, delay: 0.3, duration: 0.85), dy: reduceMotion ? 0 : 22)
                }
                .padding(.horizontal, 20)
                .frame(width: width)
                .offset(y: y(536) + launch.cardOffset)
                .opacity(launch.cardOpacity * (isDiving ? 0 : 1))
                    .animation(.easeOut(duration: 0.32), value: isDiving)

                HomeGroupStrip(
                    summaries: groupSummaries,
                    canCreate: canCreateGroup,
                    isFrontmost: isVisible,
                    entranceStart: entranceStart,
                    onSelect: onSelectGroup,
                    onCreate: onCreateGroup,
                    onJoin: onJoinGroup,
                    onAdd: onAddGroup,
                    arrivingID: arrivingGroupID,
                    shotsToday: shotsToday
                )
                .frame(width: width, alignment: .leading)
                .offset(y: y(624) + launch.groupOffset)
                .opacity(launch.groupOpacity * (isDiving ? 0 : 1))
                    .animation(.easeOut(duration: 0.32), value: isDiving)
            }
            .frame(width: width, height: fullHeight, alignment: .top)
            .background(alignment: .top) {
                HomeBackdrop(kind: state.kind, orbCenterY: y(262), height: fullHeight)
                    .frame(width: width, height: fullHeight)
                    .clipped()
                    .opacity(launch.bgOpacity)
            }
            .ignoresSafeArea()
            .lightsPanelOverlay(isOpen: $showsLights, now: now, taken: shotsToday, top: top, width: width)
        }
        .background(Color.black.ignoresSafeArea())
        .overlay {
            FilmGrainOverlay(opacity: 0.05 * launch.bgOpacity, blendMode: .normal)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onAppear { isOnScreen = true }
        .onDisappear { isOnScreen = false }
        // 入場は「状態が切りかわったとき」「アプリを開き直したとき」だけ(時計の更新・同期の再描画では流さない)
        .onChange(of: state.kind) { _, _ in startEntrance() }
        .onChange(of: scenePhase) { old, new in
            if old == .background, new == .active { startEntrance() }
        }
        .onChange(of: isVisible) { _, visible in
            if visible { ambientStart = Date() }
        }
    }

    private var ambientActive: Bool {
        isVisible && HomeMotion.ambientAllowed(reduceMotion: reduceMotion)
    }

    private func entrance(_ now: Date, delay: Double, duration: Double) -> Double {
        HomeMotion.entrance(start: entranceStart, now: now, delay: delay, duration: duration, reduceMotion: reduceMotion)
    }

    private func startEntrance() {
        // 起動アニメーションの最中は、そちらにまかせる
        guard launch == .finished else { return }
        let start = Date()
        entranceStart = start
        DispatchQueue.main.asyncAfter(deadline: .now() + HomeMotion.entranceDuration) {
            if entranceStart == start { entranceStart = nil }
        }
    }

    // MARK: - ヘッダー(LaterHeader.swift)

    private func toggleLights() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.8)) { showsLights.toggle() }
    }

    // MARK: - 光の球

    private var orbLook: HomeLightOrb.Look {
        switch state {
        case .night, .rest, .dawn: return .closed
        case .deciding, .ready: return .ready
        case .opened, .more: return .opened
        case .first: return .first
        }
    }

    private var orb: some View {
        TimelineView(.animation(paused: !holdModel.isMoving)) { context in
            let openProgress: Double = {
                if case .ready = state { return holdModel.progress(at: context.date) }
                return 0
            }()
            HomeLightOrb(
                look: orbLook,
                light: light,
                tones: openedTones,
                myColor: hasMyLight ? HomePalette.orange : nil,
                openProgress: openProgress,
                isAnimating: isVisible && !reduceMotion,
                launch: launch,
                myLightCap: hasShotToday ? 1 : 0.6,
                sparkle: sparkle,
                showsMondo: isOpened
            )
            .contentShape(Circle().size(width: HomeLightOrb.Layout.diameter, height: HomeLightOrb.Layout.diameter)
                .offset(x: (HomeLightOrb.Layout.box - HomeLightOrb.Layout.diameter) / 2, y: (HomeLightOrb.Layout.box - HomeLightOrb.Layout.diameter) / 2))
            .onTapGesture(perform: onOrbTap)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(isOpened ? "Mondo に入ります" : "")
        }
    }

    /// 今日の1枚をまだ撮っていない(dawn)。起動で、あなたの光をうすく(上限0.6)
    private var hasShotToday: Bool {
        if case .dawn = state { return false }
        return true
    }

    /// あなたの光:預けた1枚が現像中・現像ずみの時だけ
    private var hasMyLight: Bool {
        switch developContent {
        case .developing, .developed: return true
        case .rest, .first: return false
        }
    }

    // MARK: - 見出しと補足

    private func textBlock(now: Date) -> some View {
        let lines = Self.headline(state).components(separatedBy: "\n")
        let blur: CGFloat = reduceMotion ? 0 : 12
        let dy: CGFloat = reduceMotion ? 0 : 12
        return VStack(spacing: 10) {
            VStack(spacing: 28 * 0.28 - 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .entrance(entrance(now, delay: Double(index) * 0.14, duration: 0.95), blur: blur, dy: dy)
                }
            }
            .font(.system(size: 28, weight: .bold))
            .tracking(-0.05 * 28)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(.white)
            .accessibilityElement(children: .combine)
            Text(Self.subline(state))
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(HomePalette.subText)
                .entrance(entrance(now, delay: 0.4, duration: 0.95), blur: blur, dy: dy)
        }
        .frame(maxWidth: .infinity)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    static func headline(_ state: HomeState) -> String {
        switch state {
        case .night: return "おやすみ。\n朝に、仕上がります。"
        case .rest: return "今日は、\nおやすみ。"
        case .dawn: return "今日を撮ると、\n昨日がひらく。"
        case .deciding: return "昨日の1枚、\nどうする?"
        case .ready: return "昨日が、\nひらけます。"
        case .opened, .more: return "昨日を、\nひらきました。"
        case .first: return "はじめまして。\n今日を撮ってみよう。"
        }
    }

    static func subline(_ state: HomeState) -> String {
        switch state {
        case .night: return "9:00になると、また撮れます。"
        case .rest: return "あしたの朝9:00から、また撮れます。"
        case .dawn: return "昨日の光が、まだ閉じています。"
        case .deciding: return "選ぶと、みんなの昨日がひらけます。"
        case .ready: return "長押しで、みんなの昨日がひらく。"
        case .opened: return "今日の1枚は、あしたの朝に仕上がります。"
        case .more(_, let remaining): return "あと \(remaining) こま、撮れます。"
        case .first: return "あしたの朝に、今日の1枚がひらきます。"
        }
    }
}

/// 画面全体の、状態ごとのやわらかい光(黒の上の楕円グラデーション。下から1つ・球のうしろに1つ)。
/// 切りかえは1秒のクロスフェード。
struct HomeBackdrop: View {
    let kind: String
    let orbCenterY: CGFloat
    let height: CGFloat

    var body: some View {
        let colors = Self.colors(kind)
        ZStack(alignment: .top) {
            Color.black
                .frame(maxWidth: .infinity)
            Ellipse()
                .fill(RadialGradient(colors: [colors.orb, .clear], center: .center, startRadius: 0, endRadius: 220))
                .frame(width: 440, height: 400)
                .offset(y: orbCenterY - 200)
            Ellipse()
                .fill(RadialGradient(colors: [colors.bottom, .clear], center: .center, startRadius: 0, endRadius: 300))
                .frame(width: 640, height: 420)
                .offset(y: height - 170)
        }
        .frame(height: height)
        .animation(.easeInOut(duration: 1), value: kind)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    static func colors(_ kind: String) -> (orb: Color, bottom: Color) {
        switch kind {
        case "night": return (Color(hex: "4A4FB0").opacity(0.22), Color(hex: "3A3F9E").opacity(0.32))
        case "rest": return (Color(hex: "3A4060").opacity(0.18), Color(hex: "2B3150").opacity(0.26))
        case "dawn": return (Color(hex: "FF9A4D").opacity(0.16), Color(hex: "FF8A3D").opacity(0.3))
        case "ready", "deciding": return (Color(hex: "FF8F7A").opacity(0.2), Color(hex: "FF7E6B").opacity(0.34))
        case "opened", "more": return (Color(hex: "BFD6FF").opacity(0.16), Color(hex: "A8C8FF").opacity(0.28))
        default: return (Color.white.opacity(0.08), Color.white.opacity(0.12))
        }
    }
}

// MARK: - プレビュー(6つの状態)

private struct HomeViewPreview: View {
    let state: HomeState
    let content: HomeDevelopCard.Content
    var light: YesterdayLight = .count(128)
    let now: Date
    @State private var holdModel = HoldGaugeModel()
    @State private var haptics = ExposureHaptics()

    var body: some View {
        ZStack {
            HomeView(
                state: state,
                now: now,
                light: light,
                developContent: content,
                developTexture: nil,
                tones: DevelopProgress.defaultTones,
                openedTones: DevelopProgress.defaultTones,
                groupSummaries: [],
                canCreateGroup: true,
                isCovered: false,
                holdModel: holdModel,
                avatarImage: nil,
                avatarSeed: UUID(),
                showsAvatarBadge: false,
                onOpenProfile: {},
                onDevelopTap: {},
                onSelectGroup: { _ in },
                onCreateGroup: {}
            )
            GeometryReader { proxy in
                HomeMoon(
                    mode: Self.mode(state.moonPlan(yesterday: light)),
                    screenSize: proxy.size,
                    holdModel: holdModel,
                    haptics: haptics,
                    textOpacity: 1,
                    isInteractive: true,
                    onTap: {},
                    onHoldComplete: {}
                )
                .position(MoonLayout.center(in: proxy.size))
            }
            .ignoresSafeArea()
        }
    }

    static func mode(_ plan: HomeState.MoonPlan) -> HomeMoon.Mode {
        switch plan {
        case .locked(let t, let s): return .dim(title: t, subtitle: s)
        case .shoot: return .tap(title: "今日を撮る", subtitle: "タップ", tone: .warm)
        case .decide: return .tap(title: "昨日の1枚を選ぶ", subtitle: "タップ", tone: .decide)
        case .open: return .hold
        case .review: return .tap(title: "昨日をもう一度見る", subtitle: "タップ", tone: .cool)
        }
    }
}

private func previewDate(dayOffset: Int = 0, _ hour: Int, _ minute: Int) -> Date {
    let calendar = Calendar.current
    let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: Date()))!
    return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
}

#Preview("night") {
    HomeViewPreview(state: .night, content: .developing(capturedAt: previewDate(dayOffset: -1, 20, 10), isNight: true), now: previewDate(6, 40))
}

#Preview("rest") {
    HomeViewPreview(state: .rest, content: .rest, now: previewDate(6, 40))
}

#Preview("dawn") {
    HomeViewPreview(state: .dawn, content: .developed(capturedAt: previewDate(dayOffset: -1, 18, 11)), now: previewDate(9, 6))
}

#Preview("ready") {
    HomeViewPreview(state: .ready(shotAt: previewDate(9, 8)), content: .developing(capturedAt: previewDate(9, 8), isNight: false), now: previewDate(14, 20))
}

#Preview("opened") {
    HomeViewPreview(state: .opened(shotAt: previewDate(9, 8)), content: .developing(capturedAt: previewDate(9, 8), isNight: false), now: previewDate(14, 20))
}

#Preview("first") {
    HomeViewPreview(state: .first, content: .first, light: .count(0), now: previewDate(12, 0))
}
