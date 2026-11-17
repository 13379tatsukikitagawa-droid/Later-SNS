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
    var onOpenMe: () -> Void = {}
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
    /// v61:じぶんの きのうを ひらく(Home の Yesterday ページの CTA から)
    var onOpenYesterday: () -> Void = {}
    var isDiving = false
    /// 下へつづく層の中身と操作(HomeLayerModel.swift)
    var layerData: HomeLayerData = .empty
    var layerActions = HomeLayerActions()
    var todayShots: [TodayShot] = []
    var onOpenShot: (Int) -> Void = { _ in }
    /// v17:下へつづく区画の中身と操作
    var v17: HomeV17Data = .empty
    var v17Actions = HomeV17Actions()
    /// v28/v29 暗室:グループ(ACTIVE)・部屋を ひらく・写真に 返信
    var groups: [LaterGroup] = []
    var onOpenChat: (UUID) -> Void = { _ in }
    var onReplyPhoto: (UUID, LaterPhoto) -> Void = { _, _ in }

    @Environment(\.palette) private var palette
    /// v23:自分の 写真(きのうの 3こま・7日の film)
    @Query private var profiles: [UserProfile]
    @Query private var blockedUsers: [BlockedUser]
    /// v28:暗室に 入った(ヘッダーも 黒に)・下の フェードを 黒に
    @State private var darkOn = false
    @State private var bottomDark = false
    @State private var viewerItem: DarkroomPhoto?
    @State private var invites: [FriendInviteCard] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.selectedMainTabIndex) private var selectedMainTabIndex
    @State private var isOnScreen = false
    @State private var showsLights = false
    /// v47:ピル ⇄ パネルの変形
    @Namespace private var lightsNS
    /// v47:暗室のひも。セーフライト(赤)が ついているか
    @AppStorage("darkroom.safelight.v1") private var safelightOn = false
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

                V17HeaderGlass(scroll: scroll, tint: darkOn ? Darkroom.bg : (palette.isNight ? palette.bg : ChicColor.paper), height: top + LaterHeader.height + 16, lineY: top + LaterHeader.height + 4)
                    .allowsHitTesting(false)

                LaterHeader(
                    home: .today,
                    avatarImage: avatarImage,
                    avatarName: avatarName,
                    showsBadge: showsAvatarBadge,
                    onAvatar: { if showsLights { withAnimation(.easeOut(duration: 0.25)) { showsLights = false } } else { onOpenProfile() } },
                    onConsumption: toggleLights,
                    avatarSwitch: avatarSwitch,
                    namespace: lightsNS
                )
                // v28:暗室に 入ったら ヘッダーも 黒に(ロゴ 白・ピル 黒)
                .environment(\.palette, darkOn ? .night : palette)
                .animation(.easeOut(duration: 0.45), value: darkOn)
                .frame(width: width, height: LaterHeader.height)
                .padding(.top, top)
                .opacity(launch.headerOpacity * (isDiving ? 0 : 1) * (HintCenter.shared.spotlightOn ? 0.5 : 1))
                .animation(.easeOut(duration: 0.32), value: isDiving)
                .animation(.easeOut(duration: 0.5), value: HintCenter.shared.spotlightOn)

                // 月の上の白いグラデーション(スクロールしたときだけ)と、「SCROLL」のヒント
                V17BottomChrome(scroll: scroll, tint: bottomDark ? Darkroom.bg : (palette.isNight ? palette.bg : ChicColor.paper), ink: bottomDark || palette.isNight ? Color.white : Color(hex: "111111"), showsCue: false)
                    .frame(width: width, height: fullHeight)
                    .allowsHitTesting(false)
            }
            .frame(width: width, height: fullHeight)
            .lightsPanelOverlay(isOpen: $showsLights, now: now, top: top, width: width, home: .today, namespace: lightsNS, captureDates: todayShots.map(\.takenAt))
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
        .fullScreenCover(item: $viewerItem) { item in
            DarkroomViewer(item: item, onClose: { viewerItem = nil }, onReply: { photo in
                viewerItem = nil
                if let group = photo.groupID {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onReplyPhoto(group, photo.photo) }
                }
            })
        }
        .task(id: isVisible) {
            // v32:招待は 毎日 よむ(まんなかの 丸の Join)。Home が 前に 出るたびに
            guard isVisible else { return }
            invites = await FriendCloud.inbox()
        }
        .fullScreenCover(isPresented: $showsDevelop) {
            // 自分の 写真だけ(撮った 時刻で さがす)。本人の 端末で ぼかして 見せる
            let mine = UserProfile.current(from: profiles)?.photos ?? []
            HomeDevelopViewer(shots: v17.shots, videoDurations: v17.videoDurations, used: FilmCounter.shared.used, tones: tones, now: now,
                              photos: v17.shots.map { d in mine.first { $0.captureDate == d } },
                              onClose: { showsDevelop = false }, onShoot: v17Actions.shoot)
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

            // v35:まんなかの 丸 = 万能ボタンを、画面いっぱいの 主役に(v32 の 行き先・処理は そのまま)
            let orb = orbContext
            HomeOrbHero(input: orb.input, dateText: HomeDevelopCard.stampText(now), isActive: isVisible && scroll.offset < 420,
                         centerName: orb.centerName, yesterdayPhoto: orb.yesterdayPhoto, introStart: introStart,
                         onCenter: { runOrb($0, center: true) }, onSatellite: { runOrb($0, center: false) },
                         onLocked: { v17Actions.toast(String(localized: "home.orb.locked")) },
                         groupSummaries: groupSummaries, canCreateGroup: canCreateGroup,
                         onCreateGroup: onCreateGroup, onJoinGroup: onJoinGroup, onSelectGroup: onSelectGroup,
                         onOpenYesterday: onOpenYesterday,
                         hintEligible: hintsAllowed && scroll.offset < 40)
                .scaleEffect(orbScale * max(0.9, 1 - y / 2400))
                .frame(height: HomeOrbHero.height * orbScale)
                .offset(y: y * 0.25)
                .opacity(max(0.15, 1 - y / 420))

            if initial {
            HomeV22Headline(headline: HomeV22Rules.headline(used: used, initial: initial), circle: headCircle, lineReveal: headIn ? 1 : 0, width: width)
                .padding(.top, 6)
                .offset(y: headIn ? 0 : 14)
                .opacity(headIn ? 1 : 0)
                .id("headline-\(used)-\(initial)")

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

            // ともだち(D は あとで。いまは v17 の まま 置いておく)
            V17FriendsSection(friends: v17.friends, ink: V17Ink(night: palette.isNight), feel: feel, actions: v17Actions)
                .padding(.horizontal, 22)
                .padding(.top, 72)
                .v17Reveal()

            Color.clear.frame(height: HomeV17Rules.bottomSpace)
            } else {
                darkroomPages
            }
        }
        .opacity(isDiving ? 0 : 1)
        .animation(.easeOut(duration: 0.32), value: isDiving)
    }

    private var initialDay: Bool { HomeFirstDay.isInitial(now: now) }

    /// v28/v29:2日目からの Home の 下(夕暮れ → 暗室 → SEE YOU AT 9:00)
    @ViewBuilder
    private var darkroomPages: some View {
        let blocked = Set(blockedUsers.map(\.blockedCloudKitUserRecordName))
        let data = DarkroomData.make(me: UserProfile.current(from: profiles), groups: groups, blocked: blocked, now: now)
        VStack(spacing: 0) {
            DuskTodaySection(shots: data.todayShots, now: now, night: palette.isNight,
                             onShoot: v17Actions.shoot, onOpenDevelop: openDevelop)
                .padding(.top, -6)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rect in
                    updateDark(dusk: rect)
                }
            ZStack {
                VStack(spacing: 0) {
                    DarkroomSection(
                        data: data, groups: groups, summaries: groupSummaries, invites: invites, words: v17.words,
                        friends: layerData.friends, now: now,
                        onOpenChat: onOpenChat, onCreateGroup: onCreateGroup,
                        onJoin: { card in
                            guard let url = card.shareURL else { v17Actions.toast(String(localized: "darkroom.invite.expired")); return }
                            // 今の「入る」と 同じ(本人が 押したときだけ 共有を 受けいれる)
                            InviteCardStore.set(.accepted, for: card.id)
                            if let i = invites.firstIndex(where: { $0.id == card.id }) { invites[i].status = .accepted }
                            NotificationCenter.default.post(name: .joinFlowRequested, object: JoinFlowStart.link(url))
                        },
                        onOpenMondo: v17Actions.openMondo,
                        onOpenWord: v17Actions.openWord,
                        onOpenFriends: v17Actions.openFriends,
                        onOpenPhoto: { viewerItem = $0 },
                        onToast: v17Actions.toast,
                        keepHintEligible: hintsAllowed && FilmCounter.shared.used >= 1,
                        onOpenYesterday: avatarSwitch.onSwitch,
                        onOpenMe: onOpenMe
                    )
                    DarkroomSafelightString(isOn: $safelightOn)
                        .padding(.top, 36)
                        .padding(.bottom, 28)
                        .frame(maxWidth: .infinity)
                        .background(Darkroom.bg)
                }
                if safelightOn {
                    Color(hex: "D81E1E").opacity(0.22)
                        .blendMode(.multiply)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: safelightOn)
            Darkroom.bg.frame(height: HomeV17Rules.bottomSpace)
        }
    }

    /// 夕暮れの 6割が 画面の 上(約120pt)に 来たら ヘッダーを 黒に。5割5分が 画面に 入ったら 下の フェードを 黒に
    private func updateDark(dusk rect: CGRect) {
        guard !palette.isNight else {
            if darkOn { darkOn = false }
            bottomDark = true
            return
        }
        let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.height ?? 852
        let on = rect.minY + rect.height * 0.62 < 120
        if on != darkOn {
            darkOn = on
            Haptics.play(.tick)
        }
        let bottom = rect.minY + rect.height * 0.55 < screen
        if bottom != bottomDark { bottomDark = bottom }
    }

    /// はじめての 合図を 出してよい(Home が 前面・オープニングと 登場が おわった・もぐっていない)
    private var hintsAllowed: Bool {
        isVisible && launch == .finished && !introRunning && !isDiving && !showsLights && !showsDevelop
    }

    // MARK: v32 まんなかの 丸

    private struct OrbContext {
        var input: HomeOrbRules.Input
        var invite: FriendInviteCard?
        var chatGroup: UUID?
        var centerName: String?
        var yesterdayPhoto: LaterPhoto?
    }

    /// 今の データから 丸の 入力を 組む(招待・新しい メッセージ・きのうの 自分の 1枚)
    private var orbContext: OrbContext {
        let used = FilmCounter.shared.used
        let blocked = Set(blockedUsers.map(\.blockedCloudKitUserRecordName))
        let me = CloudKitManager.current?.currentUserRecordName
        let invite = invites.first { $0.status == .pending && $0.shareURL != nil }
        let unread = groups.first { GroupChatStore.shared.hasUnread($0.id, me: me, blocked: blocked) }
        let opened = OwnReveal.openedYesterdayCount(now: now)
        let input = HomeOrbRules.Input(hasInvite: invite != nil, used: used, remaining: FilmCounter.shared.remaining,
                                       hasUnread: unread != nil, hasGroups: !groups.isEmpty, openedYesterday: opened)
        let center = HomeOrbRules.center(input)
        var photo: LaterPhoto?
        if center == .yesterday, opened > 0, let mine = UserProfile.current(from: profiles)?.photos,
           let day = MERules.days(photos: mine, now: now).first(where: { $0.ago == 1 }) {
            let open = day.shots.filter { $0.reveal.isOpen }
            let kept = MEPickStore.pick(day: day.key)
            let shot = open.first { $0.id == kept } ?? open.first
            photo = shot.flatMap { s in mine.first { $0.id == s.photoID } }
        }
        let name: String? = switch center {
        case .join: invite?.groupName
        case .chat: unread?.name
        default: nil
        }
        return OrbContext(input: input, invite: invite, chatGroup: (unread ?? groups.first)?.id, centerName: name, yesterdayPhoto: photo)
    }

    /// 丸(まんなか・まわり)の 行き先。処理は 今の ボタンと 同じ ものを 呼ぶだけ
    private func runOrb(_ action: HomeOrbAction, center: Bool) {
        // 下の区画を見ているあいだ(40pt より下)は、丸の タップで 動かない
        guard scroll.offset <= LayerMotion.orbTapLimit else { return }
        let context = orbContext
        switch action {
        case .join:
            guard let card = context.invite else { return }
            guard let url = card.shareURL else { v17Actions.toast(String(localized: "darkroom.invite.expired")); return }
            // 今の「入る」と 同じ(本人が 押したときだけ 共有を 受けいれる)
            InviteCardStore.set(.accepted, for: card.id)
            if let i = invites.firstIndex(where: { $0.id == card.id }) { invites[i].status = .accepted }
            NotificationCenter.default.post(name: .joinFlowRequested, object: JoinFlowStart.link(url))
        case .shoot:
            v17Actions.shoot()
        case .chat:
            if let id = context.chatGroup { onOpenChat(id) } else { onCreateGroup() }
        case .yesterday:
            if center { onOrbTap() } else { v17Actions.openMondo() }
        case .develop:
            openDevelop()
        case .newGroup:
            onCreateGroup()
        case .mondo:
            v17Actions.openMondo()
        case .friends:
            v17Actions.openFriends()
        case .trip:
            // v61:四すみの Trip は Home の 中で ページを スライドするだけ(HomeGlassOrb 側で 処理)。
            // ここに 来ることは ない はずだが、万一 来ても グループを つくる 入口に ふっておく。
            onCreateGroup()
        }
    }

    /// v22 G:今日のカード → 現像ビューが 下から せり上がる
    private func openDevelop() {
        showsDevelop = true
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
