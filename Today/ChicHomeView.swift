import SwiftData
import SwiftUI

/// 白 × シックの Home(撮る前の今日のホーム:first・dawn と、月が出る夜の night・rest)。
/// HomeView が、この状態のときだけ表示をこの View にゆずる。状態・時刻・操作は HomeView と同じものを受け取る。
/// 位置は上から順に積み(ヘッダー → 輪 → 見出し → カード → ボタン → 月のぶんの余白)、
/// 背の低い端末では輪を縮めて収める。
struct ChicHomeView: View {
    let state: HomeState
    let now: Date
    let light: YesterdayLight
    let developContent: HomeDevelopCard.Content
    let developTexture: UIImage?
    var shotsToday = 0
    let tones: [Color]
    let groupSummaries: [GroupSummary]
    let canCreateGroup: Bool
    let isCovered: Bool
    let avatarImage: UIImage?
    let avatarSeed: UUID?
    let showsAvatarBadge: Bool
    let onOpenProfile: () -> Void
    var avatarSwitch = AvatarSwitch()
    var avatarName = ""
    let onDevelopTap: () -> Void
    let onSelectGroup: (UUID) -> Void
    let onCreateGroup: () -> Void
    var onJoinGroup: () -> Void = {}
    var onAddGroup: () -> Void = {}
    var arrivingGroupID: UUID?
    var launch: LaunchFrame = .finished
    var onOrbTap: () -> Void = {}
    var isDiving = false
    /// 下へつづく層の中身と操作(HomeLayerModel.swift)
    var layerData: HomeLayerData = .empty
    var layerActions = HomeLayerActions()
    var todayShots: [TodayShot] = []
    var onOpenShot: (Int) -> Void = { _ in }
    /// v17:下へつづく区画の中身と操作
    var v17: HomeV17Data = .empty
    var v17Actions = HomeV17Actions()
    var bump: V17Bump?

    @Environment(\.palette) private var palette
    /// v23:自分の 写真(きのうの 3こま・7日の film)
    @Query private var profiles: [UserProfile]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.selectedMainTabIndex) private var selectedMainTabIndex
    @State private var isOnScreen = false
    @State private var showsLights = false
    /// スクロール位置(ここを読む小さな View だけが、スクロールのたびに描きなおされる)
    @State private var scroll = HomeV17Scroll()
    /// 長押しでためている間の揺れ
    @State private var feel = HomeV17Feel()
    @State private var scrollPosition = ScrollPosition(edge: .top)
    /// オープニングが おわった合図の回数(Home の登場に あとで使う。いまは使わない)
    @State private var introStart: Date?
    @State private var headIn = true
    @State private var cardIn = true
    @State private var groupsIn = true
    @State private var headCircle = 1.0
    /// オープニングの あとの 登場が 動いている間(はじめての 合図を 出さない)
    @State private var introRunning = false
    @State private var showsDevelop = false

    private static let homeTabIndex = 0
    /// 月の見えている高さ(84)+ 余白
    private static let moonReserve: CGFloat = 98

    private var isVisible: Bool {
        isOnScreen && scenePhase == .active && selectedMainTabIndex == Self.homeTabIndex && !isCovered
    }

    private func toggleLights() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.8)) { showsLights.toggle() }
    }

    private var motionOn: Bool { isVisible && HomeMotion.ambientAllowed(reduceMotion: reduceMotion) }

    var body: some View {
        GeometryReader { proxy in
            let fullHeight = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            let width = proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing
            let top = LaterHeader.topInset(proxy)
            let compact = fullHeight < 720

            ZStack(alignment: .top) {
                // v17:1画面目(v8 のまま)の下に、区画がつづく。ヘッダーと月は動かない
                ScrollView(.vertical) {
                    firstPage(top: top, width: width, compact: compact)
                        .frame(width: width)
                        .modifier(V17Rattle(feel: feel))
                        // はじめての 合図(first・unlock):中身を うすく ぼかす
                        .opacity(HintCenter.shared.spotlightOn ? 0.38 : 1)
                        .blur(radius: HintCenter.shared.spotlightOn && !reduceMotion ? 1.5 : 0)
                        .animation(.easeOut(duration: 0.5), value: HintCenter.shared.spotlightOn)
                }
                .scrollPosition($scrollPosition)
                .scrollIndicators(.hidden)
                .scrollDisabled(launch != .finished)
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top
                } action: { _, y in
                    scroll.offset = y
                    // v23:スポットライトの 合図(月)は、スクロールしたら 消す
                    if y > 12, HintCenter.shared.spotlightOn {
                        HintCenter.shared.touched(.first)
                        HintCenter.shared.touched(.unlock)
                    }
                }

                V17HeaderGlass(scroll: scroll, tint: palette.isNight ? palette.bg : ChicColor.paper, height: top + LaterHeader.height + 16, lineY: top + LaterHeader.height + 4)
                    .allowsHitTesting(false)

                LaterHeader(
                    home: .today,
                    avatarImage: avatarImage,
                    avatarName: avatarName,
                    showsBadge: showsAvatarBadge,
                    onAvatar: { if showsLights { withAnimation(.easeOut(duration: 0.25)) { showsLights = false } } else { onOpenProfile() } },
                    onConsumption: scrollToFilm,
                    avatarSwitch: avatarSwitch
                )
                .frame(width: width, height: LaterHeader.height)
                .padding(.top, top)
                .opacity(launch.headerOpacity * (isDiving ? 0 : 1) * (HintCenter.shared.spotlightOn ? 0.5 : 1))
                .animation(.easeOut(duration: 0.32), value: isDiving)
                .animation(.easeOut(duration: 0.5), value: HintCenter.shared.spotlightOn)

                // 月の上の白いグラデーション(スクロールしたときだけ)と、「SCROLL」のヒント
                V17BottomChrome(scroll: scroll, tint: palette.isNight ? palette.bg : ChicColor.paper, ink: palette.isNight ? Color.white : Color(hex: "111111"), showsCue: false)
                    .frame(width: width, height: fullHeight)
                    .allowsHitTesting(false)
            }
            .frame(width: width, height: fullHeight)
            .lightsPanelOverlay(isOpen: $showsLights, now: now, top: top, width: width)
        }
        .onChange(of: state.kind) { _, _ in
            // 状態が変わったら、いちばん上から(撮ったチェキが物干しへ とんでいる間は、今日の film のまま)
            guard FilmLanding.shared.pending == nil else { return }
            scrollPosition.scrollTo(edge: .top)
        }
        .onChange(of: FilmLanding.shared.scrollToken) { _, _ in
            // v22:撮ったら 毎回 Home の いちばん上へ(チェキは 今日のカードへ とぶ)
            withAnimation(.easeInOut(duration: reduceMotion ? 0.01 : 0.4)) {
                scrollPosition.scrollTo(edge: .top)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openingFinished)) { _ in
            playIntro()
        }
        .fullScreenCover(isPresented: $showsDevelop) {
            HomeDevelopViewer(shots: v17.shots, videoDurations: v17.videoDurations, used: FilmCounter.shared.used, tones: tones, now: now,
                              onClose: { showsDevelop = false }, onShoot: v17Actions.shoot)
        }
        .confirmationDialog(
            bump?.pending.map { "「\($0.name)」と つながる?" } ?? "",
            isPresented: Binding(get: { bump?.pending != nil }, set: { if !$0, bump?.pending != nil { bump?.cancel() } }),
            titleVisibility: .visible
        ) {
            Button("つながる") { bump?.confirm() }
            Button("やめる", role: .cancel) { bump?.cancel() }
        } message: {
            Text("相手の画面でも、きいています")
        }
        .background {
            if palette.isNight {
                ChicNightBackground().ignoresSafeArea()
            } else {
                ChicColor.paper.ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .onAppear { isOnScreen = true }
        .onDisappear { isOnScreen = false }
        // オープニングの あとの 登場・現像ビュー・ライト の間は 合図を 出さない
        .onChange(of: introRunning || showsDevelop || showsLights, initial: true) { _, on in HintCenter.shared.setBlocked("chicHome", on) }
    }

    /// v22 の 1画面目(見本 later_v22.html の ホーム):ガラスの球 → 見出し 2行 → 今日のカード → グループ。
    /// その下に 今日の film と、初回だけの 使いかたガイド。
    private func firstPage(top: CGFloat, width: CGFloat, compact: Bool) -> some View {
        let used = FilmCounter.shared.used
        let initial = HomeFirstDay.isInitial(now: now)
        let orbScale: CGFloat = compact ? 0.78 : 1
        let y = max(0, scroll.offset)
        return VStack(spacing: 0) {
            Color.clear.frame(height: top + LaterHeader.height + 3)

            HomeGlassOrb(used: used, initial: initial, dateText: HomeDevelopCard.stampText(now), isActive: isVisible && scroll.offset < 420,
                         introStart: introStart, onTap: openMondo)
                // はじめての 合図(orb):1枚 撮ったあと
                .firstHint(.orb, eligible: hintsAllowed && used >= 1 && scroll.offset < 40, edge: .bottom, shape: .circle, onDark: palette.isNight, gap: 4)
                .scaleEffect(orbScale * max(0.9, 1 - y / 2400))
                .frame(height: 254 * orbScale)
                .offset(y: y * 0.25)
                .opacity(max(0.15, 1 - y / 420))

            HomeV22Headline(headline: HomeV22Rules.headline(used: used, initial: initial), circle: headCircle, lineReveal: headIn ? 1 : 0, width: width)
                .padding(.top, 6)
                .offset(y: headIn ? 0 : 14)
                .opacity(headIn ? 1 : 0)
                .id("headline-\(used)-\(initial)")

            HomeTodayCard(used: used, initial: initial, now: now, onTap: openDevelop)
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .offset(y: cardIn ? 0 : 24)
                .opacity(cardIn ? 1 : 0)

            HomeV22Groups(summaries: groupSummaries, canCreate: canCreateGroup, isFrontmost: isVisible, shotsToday: used,
                          onSelect: onSelectGroup, onCreate: onCreateGroup, onJoin: onJoinGroup, onAdd: onAddGroup,
                          createHintEligible: hintsAllowed && FirstHintStore.isSeen(.orb))
                .padding(.top, 12)
                .offset(y: groupsIn ? 0 : 24)
                .opacity(groupsIn ? 1 : 0)

            // 今日の film(撮ったチェキは 上の カードへ とぶ。ここは 物干しで 見るところ)
            V17FilmSection(state: state, now: now, shots: v17.shots, videoDurations: v17.videoDurations, ink: V17Ink(night: palette.isNight), actions: v17Actions)
                .padding(.horizontal, 22)
                .padding(.top, 72)
                .v17Reveal()
                .id(HomeV17Section.film.rawValue)

            // v23:2日目から(MONDO の ことば → きのうの 3こま → 7日の film → WORLD)
            if !initial {
                v23Sections
            }

            // ともだち(D は あとで。いまは v17 の まま 置いておく)
            if let bump {
                V17FriendsSection(friends: v17.friends, ink: V17Ink(night: palette.isNight), feel: feel, actions: v17Actions, bump: bump)
                    .padding(.horizontal, 22)
                    .padding(.top, 72)
                    .v17Reveal()
            }

            Color.clear.frame(height: HomeV17Rules.bottomSpace)
        }
        .opacity(isDiving ? 0 : 1)
        .animation(.easeOut(duration: 0.32), value: isDiving)
    }

    /// v23 の 区画(見本 later_v23.html の d2only)
    @ViewBuilder
    private var v23Sections: some View {
        let ink = V17Ink(night: palette.isNight)
        let photos = UserProfile.current(from: profiles)?.photos ?? []
        let days = MERules.days(photos: photos, now: now)
        V17WordsSection(mode: HomeV17Rules.wordsMode(state: state, shotsToday: max(FilmCounter.shared.used, v17.shots.count)),
                        words: v17.words, countries: v17.countries, ink: ink, actions: v17Actions)
            .padding(.horizontal, 22)
            .padding(.top, 72)
            .v17Reveal()
        let yesterday = V23Rules.yesterdayShots(days)
        if let day = days.first(where: { $0.ago == 1 }), !yesterday.isEmpty {
            V23YesterdaySection(day: day, shots: yesterday, photos: photos, ink: ink,
                                hintEligible: hintsAllowed && FilmCounter.shared.used >= 1)
                .padding(.horizontal, 22)
                .padding(.top, 72)
                .v17Reveal()
        }
        V23WeekFilmSection(days: days, photos: photos, ink: ink, onToast: v17Actions.toast)
            .padding(.horizontal, 22)
            .padding(.top, 72)
            .v17Reveal()
        V23WorldSection(ink: ink)
            .padding(.horizontal, 22)
            .padding(.top, 72)
            .v17Reveal()
    }

    /// はじめての 合図を 出してよい(Home が 前面・オープニングと 登場が おわった・もぐっていない)
    private var hintsAllowed: Bool {
        isVisible && launch == .finished && !introRunning && !isDiving && !showsLights && !showsDevelop && bump?.pending == nil
    }

    private func openMondo() {
        // 下の区画を見ているあいだ(40pt より下)は、玉のタップで MONDO へ行かない
        guard scroll.offset <= LayerMotion.orbTapLimit else { return }
        if FilmCounter.shared.used > 0 {
            Haptics.play(.pop)
            onOrbTap()
        } else {
            Haptics.play(.warn)
        }
    }

    /// v22 G:今日のカード → 現像ビューが 下から せり上がる
    private func openDevelop() {
        showsDevelop = true
    }

    private func scrollToFilm() {
        Haptics.play(.detent)
        withAnimation(.easeInOut(duration: reduceMotion ? 0.01 : 0.45)) {
            scrollPosition.scrollTo(id: HomeV17Section.film.rawValue, anchor: UnitPoint(x: 0.5, y: 0.2))
        }
    }

    /// B-10:オープニングのあとの 登場(球 → 見出し → 丸 → カード → グループ)
    private func playIntro() {
        guard !reduceMotion else { return }
        introStart = Date()
        introRunning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { introRunning = false }
        headIn = false; cardIn = false; groupsIn = false; headCircle = 0
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.7)) { headIn = true }
        withAnimation(.timingCurve(0.5, 0, 0.3, 1, duration: 0.76).delay(1.38)) { headCircle = 1 }
        withAnimation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.62).delay(1.35)) { cardIn = true }
        withAnimation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.62).delay(1.48)) { groupsIn = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { Haptics.play(.land) }
    }
}
