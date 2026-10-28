import SwiftUI
import SwiftData

/// Home。画面の中身はHomeView(v3)で、ここはデータの用意・状態(HomeState)と時刻の決定・
/// CloudKitの定期同期と、画面の下の「月」による切り替え(Home → タグ → 撮影、Home → 昨日を見る)、
/// グループのシート・現像シートを受け持つ。
///
/// 状態はここで1か所だけ計算し(HomeState.resolve)、HomeViewと月は同じ値を見て表示する。
/// 時計(clock)は外から差しかえられる。
struct TodayView: View {
    /// 右上のアバター・左スワイプでProfileへ(MainNavigationViewが切り替える)
    var onOpenProfile: () -> Void = {}
    /// 現在時刻(テスト・プレビューでは任意の時刻を返す)
    var clock: () -> Date = Date.init

    private enum Screen {
        case home, shoot, yesterday, mondo
        /// 昨日の自分の1枚がひらく → 投稿するか選ぶ
        case decide
    }

    /// 昨日の光の取得状況(取得できていない・失敗を「0」にしない)
    private enum SyncStatus {
        case loading, ok, failed
    }

    @Environment(\.modelContext) private var context
    @Environment(\.selectedMainTabIndex) private var selectedMainTabIndex
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    private static let homeTabIndex = 0

    @State private var now = Date()
    @State private var screen: Screen = .home
    @State private var screenSize: CGSize = .zero
    /// 画面全体の大きさ(撮影画面を払って閉じる判定・円のひろがりに使う)
    @State private var rootSize: CGSize = .zero
    /// 月のふくらみ(1 → 画面を満たす倍率)と、各層の不透明度
    @State private var moonScale: CGFloat = 1
    @State private var moonOpacity = 1.0
    @State private var moonTextOpacity = 1.0
    @State private var homeOpacity = 1.0
    @State private var bottomFadeOpacity = 1.0
    /// ひらく瞬間に画面をおおうオレンジの光
    @State private var openLightScale: CGFloat = 0.01
    @State private var openLightOpacity = 0.0
    /// 月が動いている間は操作を受けつけない(二重のタップを防ぐ)
    @State private var isMoonAnimating = false
    /// タグ画面の各要素をずらして入れる時の、開始までの遅れ(nilなら演出なし)
    @State private var shootEntranceDelay: Double?
    @State private var holdModel = HoldGaugeModel()
    @State private var haptics = ExposureHaptics()
    /// 撮影画面(暗転したまま閉じる)から戻った直後に、Homeの上に一瞬だけ残す黒い幕。
    @State private var isShowingExposureVeil = false
    /// その日の最初の1枚のあと、月の中心から広がる光(白→ピンク)。progress 0〜1・opacity は消えるとき
    @State private var firstLightProgress: CGFloat = 0
    @State private var firstLightOpacity = 0.0
    /// 光の下で、2画面(v5)をフェードインさせるための不透明度
    @State private var v5Opacity = 1.0
    /// ロック中の月を押した時に、2.3秒だけ出す小さなお知らせ。
    @State private var lockedToast: String?
    /// 「追加」タイルから出す、参加する / つくる のシート
    @State private var showingAddGroupSheet = false
    @State private var addSheetHeight: CGFloat = 300
    /// グループ作成(4ステップ)
    @State private var showingNewGroup = false
    /// 空の GROUP 画面のステッカーから開いたとき、最初から入れておくグループ名
    @State private var newGroupPrefill: String?
    /// グループのシート
    @State private var sheetGroup: LaterGroup?
    /// いま入ったグループ(Home の列に「ぽんと入る」)
    @State private var arrivingGroupID: UUID?
    /// グループの招待の QR(画面いっぱいに重ねる)
    @State private var inviteQR: (url: URL, aura: Int)?
    @State private var showingDevelopSheet = false
    /// グループの設定(グループの画面の上に重ねる。「←」でもどる)
    @State private var settingsGroup: LaterGroup?
    /// 抜ける(確認 → 長押し → 抜ける動き)
    @State private var leaveSnapshot: LeaveSnapshot?
    @State private var leavingGroup: LaterGroup?
    /// 参加していたグループが終わった(その1回だけ)
    @State private var endedGroup: EndedGroupsStore.Ended?
    /// 昨日を見る画面の範囲
    @State private var yesterdayScope: YesterdayScope = .everyone
    @State private var syncStatus: SyncStatus = .loading
    @State private var developTexture: UIImage?
    /// 起動アニメーションの1本の時計(nilなら出していない・終わった)
    @State private var launchClock: LaunchClock?
    /// Reduce Motion の起動:黒 → Home の250msフェード
    @State private var launchFadeOpacity = 0.0
    /// ウォーム起動の、光だけ0.4秒きらめく開始時刻
    @State private var sparkleStart: Date?
    @State private var wasInBackground = false
    /// Mondo へのダイブ中(光の球に吸い込まれる)
    @State private var isDivingToMondo = false
    /// ビューアの「Mondo」の範囲の取得
    @State private var mondoLoad: MondoLoad = .idle
    /// 撮った瞬間の合図(撮影後の Home v5:写真が右上のアバターへ飛び、1.4秒後に GROUP の解禁)
    @State private var shotEvent: ShotEvent?

    // MARK: 今日 / 昨日 のホームの手動切りかえ(アバターの2回タップ・長押し)
    /// 手で選んだ日(DailyWindow.key)。その日だけ有効(次の日・9:00以降は、自動の決めかたにもどる)
    @AppStorage("home.pickedOnDay") private var pickedOnDay: String = ""
    /// 手で選んだホーム(HomeKind.rawValue)
    @AppStorage("home.current") private var pickedKindRaw: String = ""
    private enum IrisMode { case circle, fade }
    /// 切りかえ中だけ、2つのホームを重ねて出す(nil なら、いまのホームだけ)
    @State private var irisMode: IrisMode?
    @State private var irisRadius: CGFloat = 0
    @State private var irisFade = 1.0
    @State private var isSwitchingHome = false
    @State private var avatarCenter: CGPoint = .zero
    @State private var avatarFlipToken = 0
    @State private var showsHomeMenu = false
    @State private var switchChip: HomeKind?
    @State private var chipGeneration = 0
    @State private var rootFrame: CGRect = .zero
    private let v5Signals = HomeV5Signals.shared

    // MARK: 撮影画面をひらく
    /// 撮れないときのカード
    @State private var cameraDenied: (title: String, detail: String)?
    @State private var cameraDeniedGeneration = 0

    private enum MondoLoad: Equatable {
        case idle, loading, failed
        case loaded([MondoEntry])
    }
    /// 最後に長押しで昨日をひらいた窓(DailyWindow.key)。窓が変わる9:00で自然にリセットされる。
    @AppStorage("yesterdayOpenedWindow") private var openedWindowKey: String = ""
    /// 解禁のアニメーションを見せた窓(DailyWindow.key)。一度見た解禁は、くり返さない
    @AppStorage("yesterdayUnlockPlayedWindow") private var unlockPlayedWindowKey: String = ""
    /// 選ぶ画面で、解禁のアニメーションから始めるか
    @State private var decidePlaysUnlock = false
    /// 選び終えて、結果を見せている間(この間は state が変わっても画面を閉じない)
    @State private var isFinishingDecision = false
    /// 選ぶ画面に出す昨日の1枚(開いた時点で写す。「消す」で写真が消えても、結果を見せ終えるまで残す)
    @State private var decideSnapshot: DecideSnapshot?

    private struct DecideSnapshot {
        let image: UIImage?
        let capturedAt: Date
        let groups: [ProfileShareGroup]
        let showsMondo: Bool
    }
    @AppStorage(AvatarBadge.pendingKey) private var avatarBadgePending: String = ""
    @AppStorage(AvatarBadge.acknowledgedKey) private var avatarBadgeAcknowledged: String = ""

    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]
    @Query(sort: \ExposureDay.captureDate, order: .reverse) private var exposureDays: [ExposureDay]
    @Query private var blockedUsers: [BlockedUser]
    @Bindable private var captureRequest = CaptureRequestStore.shared

    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }

    private var userGroups: [LaterGroup] {
        guard let user = currentUser else { return [] }
        return groups.filter { $0.members.contains(where: { $0.id == user.id }) }
    }

    /// MEを除いた、参加中のグループ
    private var sharedGroups: [LaterGroup] {
        // 新しく作った・入ったグループが先頭(投稿数では並べない)
        userGroups.filter { !$0.isPersonalSpace }.sorted { ($0.joinedAt ?? $0.creationDate) > ($1.joinedAt ?? $1.creationDate) }
    }

    private var myCaptureDates: [Date] {
        currentUser?.photos.map(\.captureDate) ?? []
    }

    private var hasDeposited: Bool {
        !exposureDays.isEmpty || !myCaptureDates.isEmpty
    }

    // MARK: - 状態(1か所で計算する)

    private func homeState(at date: Date) -> HomeState {
        HomeState.resolve(
            now: date,
            myCaptureDates: myCaptureDates,
            hasDeposited: hasDeposited,
            openedWindowKey: openedWindowKey.isEmpty ? nil : openedWindowKey,
            yesterdayDecision: YesterdayDecision.resolve(yesterdayOwnPosted: yesterdayOwnPhotos(at: date).map(\.isPosted))
        )
    }

    /// 昨日の窓の、自分の写真(グループごとの複製を含む)
    private func yesterdayOwnPhotos(at date: Date) -> [LaterPhoto] {
        guard let currentUser else { return [] }
        return YesterdayPostStore.yesterdayOwnPhotos(of: currentUser, now: date)
    }

    private var state: HomeState { homeState(at: now) }

    /// 自動で決まるホーム:撮影後(ready / opened / more)は昨日のホーム、それ以外は今日のホーム。
    private var autoHomeKind: HomeKind { state.usesGroupHome ? .yesterday : .today }

    /// いま見せるホーム。今日手で選んでいれば、それ。なければ自動(撮ったあとは昨日、まだなら今日)。
    private var homeKind: HomeKind {
        if pickedOnDay == DailyWindow.key(for: now), let kind = HomeKind(rawValue: pickedKindRaw) { return kind }
        return autoHomeKind
    }

    /// 昨日のホーム(v5:MONDO / GROUP / カレンダー)を見せているか。
    private var usesV5Home: Bool { homeKind == .yesterday }

    /// 今日を撮る前に、手で昨日のホームをひらいている(昨日のものは、ぼかしてロック)
    private var yesterdayLocked: Bool { usesV5Home && !state.usesGroupHome }

    /// 切りかえ中は、2つのホームをどちらも出す
    private var rendersToday: Bool { !usesV5Home || irisMode != nil }
    private var rendersV5: Bool { usesV5Home || irisMode != nil }

    /// 白 × シックのホームを見せているか(撮る前の今日のホーム。背景・月の下のフェードも白地用にする)
    private var isChicHome: Bool { state.usesChicHome && !usesV5Home }

    private var avatarSwitch: AvatarSwitch {
        AvatarSwitch(
            current: homeKind,
            flipToken: avatarFlipToken,
            onSwitch: { switchHome(to: homeKind.other) },
            onMenu: presentHomeMenu,
            onCenter: { avatarCenter = $0 }
        )
    }

    /// 直近の窓で撮った枚数(同じ1枚のグループごとの複製は数えない。上限は FilmRoll.shotsPerDay)
    private var shotsInLatestWindow: Int {
        let window = DailyWindow.latest(for: clock())
        return FilmRoll.distinctShotCount(myCaptureDates.filter { $0 >= window.open && $0 < window.close })
    }

    /// 昨日の光(件数だけを数える。昨日の写真の画像はHomeで取得しない)。
    /// ユーザー未確定・まだ同期していない間は「確認中」、同期に失敗して0件の時は「失敗」。
    private var yesterdayLight: YesterdayLight {
        guard currentUser != nil else { return .loading }
        let count = HomeState.yesterdayPhotoCount(in: userGroups, now: now)
        if count > 0 { return .count(count) }
        switch syncStatus {
        case .loading: return .loading
        case .failed: return .failed
        case .ok: return .count(0)
        }
    }

    /// グループの列の要約(昨日、投稿した人数。だれが投稿したかは持たない)
    private var groupSummaries: [GroupSummary] {
        GroupRingMath.summaries(for: sharedGroups, now: now)
    }

    /// 今日(直近の窓)預けた人数(グループごと。誰が預けたかは出さない)
    private var depositedToday: [UUID: Int] {
        let window = DailyWindow.latest(for: now)
        var result: [UUID: Int] = [:]
        for group in sharedGroups {
            let authors = Set(group.photos.filter { $0.captureDate >= window.open && $0.captureDate < window.close }.map(\.dedupeKey))
            result[group.id] = authors.count
        }
        return result
    }

    private func yesterdayDepositors(in group: LaterGroup) -> Int {
        let window = DailyWindow.yesterday(for: now)
        return Set(group.photos.filter { $0.captureDate >= window.open && $0.captureDate < window.close }.map(\.dedupeKey)).count
    }

    // MARK: - 現像カード

    /// 現像カードに出す1枚の撮影時刻
    private var developCapture: Date? {
        switch state {
        case .night, .deciding, .ready, .opened, .more:
            let window = DailyWindow.latest(for: now)
            return myCaptureDates.filter { $0 >= window.open && $0 < window.close }.max()
                ?? exposureDays.first { $0.captureDate >= window.open && $0.captureDate < window.close }?.captureDate
        case .dawn:
            let open = DailyWindow.latest(for: now).open
            let fromPhotos = myCaptureDates.filter { $0 < open }.max()
            let fromDays = exposureDays.first { $0.captureDate < open }?.captureDate
            return [fromPhotos, fromDays].compactMap { $0 }.max()
        case .rest, .first:
            return nil
        }
    }

    private var developContent: HomeDevelopCard.Content {
        switch state {
        case .rest: return .rest
        case .first: return .first
        case .dawn:
            guard let at = developCapture else { return .rest }
            return .developed(capturedAt: at)
        case .night, .deciding, .ready, .opened, .more:
            guard let at = developCapture else { return .first }
            return .developing(capturedAt: at, isNight: state.isNight)
        }
    }

    private var developDay: ExposureDay? {
        guard let at = developCapture else { return nil }
        let key = ExposureDayStore.dayKey(for: at)
        return exposureDays.first { $0.dayKey == key }
    }

    private var developTones: [Color] {
        let tones = developDay?.toneHexes.map { Color(hex: $0) } ?? []
        return tones.count >= 3 ? tones : DevelopProgress.defaultTones
    }

    // MARK: - 昨日を見る

    private func groupItems(_ scope: YesterdayScope) -> [YesterdayItem] {
        let target: [LaterGroup]
        switch scope {
        case .group(let id): target = userGroups.filter { $0.id == id }
        default: target = userGroups
        }
        let items = YesterdayItem.collect(
            from: target,
            myRecordName: CloudKitManager.current?.currentUserRecordName ?? currentUser?.cloudKitUserRecordName,
            myProfileID: currentUser?.id,
            blocked: Set(blockedUsers.map(\.blockedCloudKitUserRecordName)),
            now: now
        )
        return scope == .mine ? items.filter(\.isMine) : items
    }

    private var yesterdayItems: [YesterdayItem]? {
        if yesterdayScope == .mondo {
            guard case .loaded(let entries) = mondoLoad else { return nil }
            return entries.map(MondoViewer.item)
        }
        let items = groupItems(yesterdayScope)
        if items.isEmpty, syncStatus == .failed, yesterdayScope != .mine { return nil }
        return items
    }

    private var mondoImageLoader: ((YesterdayItem) async -> UIImage?)? {
        guard yesterdayScope == .mondo else { return nil }
        return { item in await mondoImage(item) }
    }

    private func retryYesterday() {
        Task {
            if yesterdayScope == .mondo { await loadMondoForViewer() } else { await refreshAllGroups() }
        }
    }

    private var yesterdayViewer: some View {
        YesterdayViewer(
            items: yesterdayItems,
            scope: yesterdayScope,
            groups: sharedGroups,
            haptics: haptics,
            onScopeChange: changeYesterdayScope,
            onRetry: retryYesterday,
            onClose: closeYesterday,
            totalCount: yesterdayScope == .mondo ? WorldCountStore.shared.count : nil,
            remoteImage: mondoImageLoader,
            everyoneHasPhotos: !groupItems(.everyone).isEmpty,
            isReloading: yesterdayScope == .mondo && mondoLoad == .loading,
            showsTodayCard: shotsInLatestWindow > 0
        )
    }

    /// ビューアを開くときの範囲:自分が0枚で、みんなに写真があるなら、はじめから「みんな」(空の画面に着地させない)
    private func openingScope(_ requested: YesterdayScope) -> YesterdayScope {
        guard requested == .mine, groupItems(.mine).isEmpty, !groupItems(.everyone).isEmpty else { return requested }
        return .everyone
    }

    /// 範囲をかえる。Mondo は、そのとき取りに行く
    private func changeYesterdayScope(_ scope: YesterdayScope) {
        withAnimation(.easeInOut(duration: 0.4)) { yesterdayScope = scope }
        if scope == .mondo, mondoLoad != .loading { Task { await loadMondoForViewer() } }
    }

    private func loadMondoForViewer() async {
        mondoLoad = .loading
        let dayKey = ExposureDayStore.dayKey(for: DailyWindow.yesterday(for: now).open)
        do {
            let summary = try await MondoService.shared.fetchDay(dayKey: dayKey, blocked: MondoService.blockedMondoIDs(blockedUsers))
            WorldCountStore.shared.record(summary)
            mondoLoad = .loaded(Array(summary.entries.prefix(MondoConfig.maxCards)))
        } catch {
            // 取得の失敗・集計がまだ:空の画面(エラーコードや英語は出さない)
            mondoLoad = .failed
        }
    }

    private func mondoImage(_ item: YesterdayItem) async -> UIImage? {
        guard case .loaded(let entries) = mondoLoad, let entry = entries.first(where: { $0.id == item.id }) else { return nil }
        if let full = await MondoService.shared.fullImage(for: entry) { return full }
        return await MondoService.shared.thumbnail(for: entry)
    }

    /// 画面の中身(型チェックを軽くするため、修飾子の列 body とは分けている)
    private var rootStack: some View {
        ZStack {
            (isChicHome && screen == .home ? Color.white : Color.black).ignoresSafeArea()

            if rendersToday {
            TimelineView(.animation(paused: launchClock == nil && sparkleStart == nil)) { context in
            HomeView(
                state: state,
                now: now,
                light: WorldCountStore.shared.light,
                developContent: developContent,
                developTexture: developTexture,
                shotsToday: shotsInLatestWindow,
                tones: developTones,
                openedTones: DevelopProgress.defaultTones,
                groupSummaries: groupSummaries,
                canCreateGroup: sharedGroups.count < GroupMembershipPolicy.maxGroupsPerUser,
                isCovered: isHomeCovered,
                holdModel: holdModel,
                avatarImage: currentUser?.profileImageData.flatMap(UIImage.init(data:)),
                avatarSeed: currentUser?.id,
                showsAvatarBadge: !avatarBadgePending.isEmpty,
                onOpenProfile: onOpenProfile,
                avatarSwitch: avatarSwitch,
                avatarName: currentUser?.name ?? "",
                onDevelopTap: { showingDevelopSheet = true },
                onSelectGroup: { id in sheetGroup = sharedGroups.first { $0.id == id } },
                onCreateGroup: { newGroupPrefill = nil; showingNewGroup = true },
                onJoinGroup: {
                    NotificationCenter.default.post(name: .joinFlowRequested, object: JoinFlowStart.scan)
                },
                onAddGroup: { showingAddGroupSheet = true },
                arrivingGroupID: arrivingGroupID,
                launch: launchFrame(at: context.date),
                sparkle: sparkle(at: context.date),
                onOrbTap: tapOrb,
                isDiving: isDivingToMondo
            )
            }
            .opacity(homeOpacity)
            .allowsHitTesting(screen == .home && !isMoonAnimating && launchClock == nil && irisMode == nil)
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: "撮影画面をひらく") { openCameraFromAccessibility() }
            }

            // 撮影後の Home(v5)。撮影画面などの下にも残しておく(もどったとき、画面の位置を保つ)
            if rendersV5 {
                HomeV5Container(
                    state: state,
                    now: now,
                    haptics: haptics,
                    shotsToday: shotsInLatestWindow,
                    currentUser: currentUser,
                    sharedGroups: sharedGroups,
                    canCreateGroup: sharedGroups.count < GroupMembershipPolicy.maxGroupsPerUser,
                    avatarImage: currentUser?.profileImageData.flatMap(UIImage.init(data:)),
                    showsAvatarBadge: !avatarBadgePending.isEmpty,
                    isCovered: isHomeCovered,
                    shotEvent: shotEvent,
                    onOpenProfile: onOpenProfile,
                    onOpenGroupSheet: { id in sheetGroup = sharedGroups.first { $0.id == id } },
                    onAddGroup: { showingAddGroupSheet = true },
                    onCreateGroup: { prefill in
                        newGroupPrefill = prefill
                        showingNewGroup = true
                    },
                    onJoinGroup: {
                        NotificationCenter.default.post(name: .joinFlowRequested, object: JoinFlowStart.scan)
                    },
                    locked: yesterdayLocked,
                    avatarSwitch: avatarSwitch
                )
                .opacity(v5Opacity * (irisMode == .fade ? irisFade : 1))
                // カメラの絞り:アバターの中心から広がる円の中だけ、昨日のホームを見せる
                .clipShape(IrisClip(active: irisMode == .circle, center: irisCenterLocal, radius: irisRadius))
                .allowsHitTesting(screen == .home && launchClock == nil && v5Opacity > 0.99 && irisMode == nil)
                .accessibilityElement(children: .contain)
                .accessibilityAction(named: "撮影画面をひらく") { openCameraFromAccessibility() }
                // 切りかえ中だけ、今日のホームの上に重ねる(ふだんは宣言の順のまま)
                .zIndex(irisMode == nil ? 0 : 1)

                if irisMode == .circle {
                    IrisRing(center: irisCenterLocal, radius: irisRadius)
                        .zIndex(2)
                }
            }

            switch screen {
            case .home:
                EmptyView()
            case .shoot:
                // 撮影画面は、下の drawerLayer(左から出てくる引き出し)
                EmptyView()
            case .yesterday:
                yesterdayViewer
                .transition(.opacity)
            case .mondo:
                MondoRootView(now: now, haptics: haptics, onClose: closeMondo)
                    .transition(.opacity)
            case .decide:
                decideView
                    .transition(.opacity)
            }

            if rendersToday {
            // 月のうしろの、画面の下から黒へのフェード(月の下半分は黒へ溶ける)。白 × シックのホームでは出さない
            LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                .frame(height: 120)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .opacity(screen == .home && !isChicHome ? bottomFadeOpacity : 0)
                .allowsHitTesting(false)
                .ignoresSafeArea()

            // 月は画面の下端からの距離で置くため、セーフエリアを含む全画面の座標で配置する。
            GeometryReader { proxy in
                TimelineView(.animation(paused: launchClock == nil)) { context in
                    let frame = launchFrame(at: context.date)
                    moonLayer(size: proxy.size, launch: frame)
                        .offset(y: frame.moonOffset)
                        .opacity(frame.moonOpacity * (isDivingToMondo ? 0 : 1))
                        .animation(.easeOut(duration: 0.32), value: isDivingToMondo)
                }
                .onAppear { screenSize = proxy.size }
                .onChange(of: proxy.size) { _, size in screenSize = size }
            }
            .ignoresSafeArea()

            // 月の下端の黒(月の下半分を黒へ溶かす)
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: 40)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .opacity(screen == .home && !isChicHome ? bottomFadeOpacity : 0)
                .allowsHitTesting(false)
                .ignoresSafeArea()

            // ひらく瞬間の、画面をおおうオレンジの光
            GeometryReader { proxy in
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: "FFE2C2"), HomePalette.orange, Color(hex: "C2603A")], center: .center, startRadius: 0, endRadius: 60))
                    .frame(width: 120, height: 120)
                    .scaleEffect(openLightScale)
                    .position(x: proxy.size.width / 2, y: proxy.size.height - MoonLayout.visibleHeight / 2)
                    .opacity(openLightOpacity)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            }

            // 撮影画面。月のタップでひらく。
            if screen == .shoot {
                ShootFlowView(
                    shotsToday: shotsInLatestWindow,
                    entranceDelay: shootEntranceDelay,
                    onCaptured: saveExposure,
                    onFinished: finishExposure,
                    onClose: shrinkMoonBack
                )
                .simultaneousGesture(closeShootSwipe)
                .transition(
                    !usesV5Home ? .opacity.combined(with: .scale(scale: 1.06))
                        : (reduceMotion ? .opacity : .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 1.06)),
                            removal: .move(edge: .leading)
                        ))
                )
                .zIndex(10)
            }

            // 起動アニメーション中:画面のどこかをタップしたら、200msで最後へ(Homeの操作は終わるまで無効)
            if launchClock != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture(perform: skipLaunch)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("起動のアニメーションを飛ばす")
                    .zIndex(20)
            }

            // 切りかえたあとの小さなチップ(アバターの下に1.1秒)
            if let chip = switchChip, !showsHomeMenu {
                HomeSwitchChip(avatarImage: currentUser?.profileImageData.flatMap(UIImage.init(data:)), avatarSeed: currentUser?.id, kind: chip)
                    .position(x: min(max(irisCenterLocal.x, 80), max(80, rootFrame.width - 80)), y: irisCenterLocal.y + 22 + 36)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .allowsHitTesting(false)
                    .zIndex(17)
            }

            // 長押しのメニュー(アバターの下・右そろえ)
            if showsHomeMenu {
                HomeSwitchMenu(
                    current: homeKind,
                    avatarCenter: avatarCenter,
                    onPick: pickHomeFromMenu,
                    onClose: { withAnimation(.easeOut(duration: 0.15)) { showsHomeMenu = false } }
                )
                .transition(.opacity)
                .zIndex(18)
            }

            // Reduce Motion の起動(黒 → Home の250msフェード)
            if launchFadeOpacity > 0 {
                Color.black
                    .ignoresSafeArea()
                    .opacity(launchFadeOpacity)
                    .allowsHitTesting(false)
                    .zIndex(21)
            }

            if isShowingExposureVeil {
                Color.black
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if firstLightOpacity > 0 {
                FirstShotLight(progress: firstLightProgress)
                    .opacity(firstLightOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .zIndex(22)
            }

            if let lockedToast {
                toast(lockedToast)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if let group = sheetGroup {
                BottomSheetContainer(topInset: 150, onClose: { sheetGroup = nil }) {
                    GroupSheet(
                        group: group,
                        summary: groupSummaries.first { $0.id == group.id }
                            ?? GroupRingMath.summaries(for: [group], now: now)[0],
                        state: state,
                        haptics: haptics,
                        onClose: { sheetGroup = nil },
                        onOpen: { openYesterday(scope: .group(group.id)) },
                        onView: { viewYesterday(scope: .group(group.id)) },
                        onSettings: { settingsGroup = group },
                        onShowQR: { url in
                            let aura = groupSummaries.first { $0.id == group.id }?.auraIndex ?? 0
                            withAnimation(.easeOut(duration: 0.25)) { inviteQR = (url, aura) }
                        }
                    )
                }
                .id(group.id)
                .zIndex(10)
            }

            if let group = settingsGroup {
                BottomSheetContainer(
                    topInset: 70,
                    fill: AnyShapeStyle(LinearGradient(colors: [Color(hex: "1B1B1F"), Color(hex: "0C0C0E")], startPoint: .top, endPoint: .bottom)),
                    onClose: { settingsGroup = nil }
                ) {
                    GroupSettingsView(group: group, haptics: haptics, onBack: { settingsGroup = nil }, onLeave: {
                        guard let user = currentUser else { return }
                        leavingGroup = group
                        withAnimation(.easeOut(duration: 0.25)) { leaveSnapshot = LeaveSnapshot(group: group, user: user) }
                    })
                }
                .id("settings-\(group.id)")
                .zIndex(12)
            }

            if let snapshot = leaveSnapshot {
                GroupLeaveOverlay(snapshot: snapshot, haptics: haptics, perform: {
                    guard let group = leavingGroup, let user = currentUser else { throw GroupLeaveService.LeaveError.notReady }
                    try await GroupLeaveService.leave(group, user: user, context: context)
                }, onCancel: {
                    withAnimation(.easeOut(duration: 0.25)) { leaveSnapshot = nil }
                    leavingGroup = nil
                }, onHome: {
                    // Home へ:そのグループは列から小さくなって消え、右のグループが左へ寄る
                    settingsGroup = nil
                    sheetGroup = nil
                    leavingGroup = nil
                    withAnimation(.easeOut(duration: 0.3)) { leaveSnapshot = nil }
                    presentToast("『\(snapshot.name)』から抜けました")
                })
                .transition(.opacity)
                .zIndex(40)
            }

            if let ended = endedGroup {
                GroupEndedView(ended: ended) {
                    withAnimation(.easeOut(duration: 0.3)) { endedGroup = nil }
                    showNextEndedGroup()
                }
                .transition(.opacity)
                .zIndex(41)
            }

            if let inviteQR {
                InviteQROverlay(url: inviteQR.url, auraIndex: inviteQR.aura) {
                    withAnimation(.easeOut(duration: 0.25)) { self.inviteQR = nil }
                }
                .transition(.opacity)
                .zIndex(30)
            }

            if showingDevelopSheet, let at = developCapture {
                BottomSheetContainer(
                    topInset: 100,
                    fill: AnyShapeStyle(LinearGradient(colors: [Color(hex: "1B1B1F"), Color(hex: "0C0C0E")], startPoint: .top, endPoint: .bottom)),
                    onClose: { showingDevelopSheet = false }
                ) {
                    DevelopSheet(
                        capturedAt: at,
                        isDeveloped: state == .dawn,
                        now: now,
                        texture: developTexture,
                        tones: developTones,
                        haptics: haptics
                    )
                }
                .zIndex(10)
            }
        }
    }

    private var lifecycleLayer: some View {
        rootStack
        .onAppear {
            AppLaunchTiming.reportHomeDisplayedIfNeeded()
            haptics.prepare()
            showNextEndedGroup()
            now = clock()
            openYesterdayForGroupHome()
            beginLaunchIfNeeded()
        }
        .task(id: now) {
            // 世界の光:昨日の数を1回だけ取りに行く(その日の窓の間はキャッシュ)。ネットワークは待たない
            await WorldCountStore.shared.refreshIfNeeded(now: now, blocked: MondoService.blockedMondoIDs(blockedUsers))
        }
        .task(id: developDay?.dayKey) {
            guard let day = developDay else {
                developTexture = nil
                return
            }
            developTexture = await DevelopTexture.make(from: day.thumbnailData, key: "develop-\(day.dayKey)")
        }
        .task {
            // 時刻は1分ごと(分の変わり目)に進める。9:00・24:00ちょうどで状態が切りかわる。
            while !Task.isCancelled {
                let seconds = Calendar.current.component(.second, from: clock())
                try? await Task.sleep(for: .seconds(Double(60 - seconds) + 0.05))
                guard !Task.isCancelled else { return }
                updateNow()
            }
        }
        .task {
            // Homeが見えている間だけ同期する。
            while !Task.isCancelled {
                if selectedMainTabIndex == Self.homeTabIndex {
                    await refreshAllGroups()
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // バックグラウンドから戻った時・時計を変えた時は時間が経っている可能性があるため再計算する。
            if phase == .background { wasInBackground = true }
            if phase == .active {
                updateNow()
                showNextEndedGroup()
                syncWidget()
                // Mondo:送れなかった公開を、もう一度送る
                Task { await MondoService.shared.retryPending(context: context) }
                // ウォーム起動:アニメーションなし。光だけ0.4秒きらめく。
                if wasInBackground, launchClock == nil, !reduceMotion {
                    sparkleStart = Date()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { sparkleStart = nil }
                }
                wasInBackground = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            updateNow()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            updateNow()
        }
        .onReceive(NotificationCenter.default.publisher(for: MondoNotice.name)) { note in
            // 静かに知らせる(触覚なし・理由は細かく言わない)
            if let text = note.userInfo?["text"] as? String { presentToast(text) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .groupEnded)) { _ in
            showNextEndedGroup()
        }
        .onReceive(NotificationCenter.default.publisher(for: .groupJoined)) { note in
            guard let id = note.object as? UUID else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                arrivingGroupID = id
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { arrivingGroupID = nil }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .homeToastRequested)) { note in
            // 小さなお知らせ(触覚なし)
            if let text = note.object as? String {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { presentToast(text) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openGroupRequested)) { note in
            // 招待リンクをひらいた人が、すでにメンバーだった:そのグループの画面へ
            guard let id = note.object as? UUID, let group = sharedGroups.first(where: { $0.id == id }) else { return }
            if screen == .home { sheetGroup = group }
        }
        .onReceive(NotificationCenter.default.publisher(for: .replayLaunchAnimation)) { note in
            replayLaunch(note)
        }
        .onChange(of: state) { old, new in
            if case .ready = new { holdModel.reset() }
            openYesterdayForGroupHome()
            reportDevelopFinishedIfNeeded()
            // 9:00 をまたいだ:決めないままの昨日の1枚は、静かに消す(お知らせなし)
            YesterdayPostStore.pruneUndecided(context: context, cloudKitManager: CloudKitManager.current, now: clock())
            if screen == .decide, !isFinishingDecision, !isDeciding(new) {
                closeDecision(toast: nil)
            }
        }
        // Homeの上に昨日のビューア・撮影・シートなどが重なっている間は、端のスワイプでもProfileを開かない
        // (その画面で始めた横の動きは、その画面のもの)
        .preference(key: HomeNoSwipeRegionKey.self, value: isHomeCovered ? [CGRect.infinite] : [])
        .onGeometryChange(for: CGSize.self) { $0.size } action: { rootSize = $0 }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rootFrame = $0 }
        .onChange(of: state.usesGroupHome) { _, shot in
            // 撮ったら、手で選んだ分は外す(今日のホームで撮ったときは、これまでどおり昨日のホームへ)
            if shot { pickedOnDay = ""; pickedKindRaw = "" }
        }
        .onChange(of: screen) { _, value in
            if value != .home, showsHomeMenu { showsHomeMenu = false }
        }
    }

    var body: some View {
        entryLayer
        // 追加シートの間、後ろのHomeを暗く(黒55%)
        .overlay {
            Color.black.opacity(showingAddGroupSheet ? 0.55 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.3), value: showingAddGroupSheet)
        }
        .sheet(isPresented: $showingAddGroupSheet) {
            GroupAddSheet(
                groupCount: sharedGroups.count,
                onJoin: { chooseFromAddSheet { NotificationCenter.default.post(name: .joinFlowRequested, object: JoinFlowStart.scan) } },
                onCreate: { chooseFromAddSheet { newGroupPrefill = nil; showingNewGroup = true } }
            )
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { addSheetHeight = $0 }
            .presentationDetents([.height(addSheetHeight)])
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(34)
            .presentationDragIndicator(.hidden)
            .environment(\.colorScheme, .dark)
        }
        .fullScreenCover(isPresented: $showingNewGroup) {
            NewGroupFlowView(initialName: newGroupPrefill) { showingNewGroup = false }
        }
        // ウィジェット:撮影・昨日をひらく・日付が変わる(状態が変わる)たびに、値を書いて更新
        .onAppear { syncWidget() }
        .onChange(of: state) { _, _ in syncWidget() }
        .onChange(of: openedWindowKey) { _, _ in syncWidget() }
        .onChange(of: myCaptureDates.count) { _, _ in syncWidget() }
        .onChange(of: captureRequest.pendingRequestID) { _, newValue in
            guard newValue != nil else { return }
            captureRequest.pendingRequestID = nil
            guard screen == .home else { return }
            if homeState(at: clock()).canShoot {
                if usesV5Home { openShootV5() } else { expandMoon(to: .shoot) }
            } else if usesV5Home {
                // もう撮れない・時間外:カードで知らせる
                showCameraDenied(deniedDecision(for: homeState(at: clock())), feedback: true)
            }
        }
    }

    // MARK: - 今日 / 昨日 の切りかえ

    /// アバターの中心(このビューの座標)。まだ測れていないときは、右上の角に近い場所
    private var irisCenterLocal: CGPoint {
        if avatarCenter == .zero { return CGPoint(x: max(0, rootFrame.width - 42), y: 70) }
        return CGPoint(x: avatarCenter.x - rootFrame.minX, y: avatarCenter.y - rootFrame.minY)
    }

    private func presentHomeMenu() {
        guard !isSwitchingHome, screen == .home, launchClock == nil, !isMoonAnimating, !isHomeCovered else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { showsHomeMenu = true }
    }

    /// メニューの行をタップ:とじて、0.12秒あとに切りかえる
    private func pickHomeFromMenu(_ kind: HomeKind) {
        withAnimation(.easeOut(duration: 0.15)) { showsHomeMenu = false }
        guard kind != homeKind else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { switchHome(to: kind) }
    }

    /// 手でホームを切りかえる(その日だけ有効)。切りかえ中のタップは無視する。
    /// 昨日のホームは円(カメラの絞り)で 0.6 秒、もどるときは 0.55 秒。視差効果を減らす が入っているときは、0.2秒のクロスフェードだけ。
    private func switchHome(to target: HomeKind) {
        guard !isSwitchingHome, target != homeKind, screen == .home, launchClock == nil, !isMoonAnimating else { return }
        isSwitchingHome = true
        showsHomeMenu = false
        switchChip = nil
        avatarFlipToken &+= 1

        func commit() {
            pickedOnDay = DailyWindow.key(for: clock())
            pickedKindRaw = target.rawValue
        }
        var instant = Transaction()
        instant.disablesAnimations = true
        let diagonal = max(1, hypot(rootFrame.width, rootFrame.height))
        let duration: Double

        if reduceMotion {
            duration = 0.2
            withTransaction(instant) {
                irisFade = target == .yesterday ? 0 : 1
                irisMode = .fade
                commit()
            }
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: duration)) { irisFade = target == .yesterday ? 1 : 0 }
            }
        } else if target == .yesterday {
            duration = 0.6
            withTransaction(instant) {
                irisRadius = 0
                irisMode = .circle
                commit()
            }
            DispatchQueue.main.async {
                withAnimation(.timingCurve(0.6, 0, 0.2, 1, duration: duration)) { irisRadius = diagonal }
            }
        } else {
            duration = 0.55
            withTransaction(instant) {
                irisRadius = diagonal
                irisMode = .circle
                commit()
            }
            DispatchQueue.main.async {
                withAnimation(.timingCurve(0.6, 0, 0.2, 1, duration: duration)) { irisRadius = 0 }
            }
        }

        // 切りかえた直後:カチッ(rigid)→ 0.04秒あとにふわっ(soft)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.03) {
            withTransaction(instant) {
                irisMode = nil
                irisFade = 1
                irisRadius = 0
            }
            isSwitchingHome = false
            showSwitchChip(target)
            AccessibilityNotification.Announcement("\(target.title)のホーム").post()
        }
    }

    /// 切りかえたあと、アバターの下に小さなチップを1.1秒だけ出す
    private func showSwitchChip(_ kind: HomeKind) {
        chipGeneration += 1
        let generation = chipGeneration
        withAnimation(.easeOut(duration: 0.2)) { switchChip = kind }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            guard generation == chipGeneration else { return }
            withAnimation(.easeOut(duration: 0.25)) { switchChip = nil }
        }
    }

    // MARK: - 起動アニメーション

    private func launchFrame(at date: Date) -> LaunchFrame {
        guard let launchClock else { return .finished }
        return LaunchFrame.at(launchClock.t(at: date), kind: launchClock.kind)
    }

    private func sparkle(at date: Date) -> Double {
        guard let sparkleStart else { return 0 }
        let u = date.timeIntervalSince(sparkleStart) / 0.4
        return u >= 1 ? 0 : sin(.pi * max(0, u))
    }

    /// コールドスタートの最初の1回だけ。ネットワークは待たず、前回の値(端末内のデータ)でそのまま進める。
    private func beginLaunchIfNeeded() {
        guard let kind = LaunchCoordinator.beginColdLaunchIfNeeded(now: clock()) else { return }
        // 撮影後の Home(v5)は、起動アニメーションを使わない(MONDO / GROUP が静かに出る)
        if homeState(at: clock()).usesGroupHome { return }
        if reduceMotion {
            launchFadeOpacity = 1
            withAnimation(.easeOut(duration: 0.25)) { launchFadeOpacity = 0 }
            return
        }
        let speed: Double = ProcessInfo.processInfo.isLowPowerModeEnabled ? 2 : 1
        let clock = LaunchClock(kind: kind, start: Date(), speed: speed)
        // 起動では触覚を鳴らさない(撮る・ひらく・えらぶ、のためにとっておく)
        launchClock = clock
        scheduleLaunchEnd(clock)
    }

    /// デバッグ:設定メニューから、種類・速さ・止める時刻を指定して再生しなおす。
    private func replayLaunch(_ note: Notification) {
        guard let raw = note.userInfo?["kind"] as? String, let kind = LaunchKind(rawValue: raw) else { return }
        var clock = LaunchClock(kind: kind, start: Date(), speed: note.userInfo?["speed"] as? Double ?? 1)
        clock.frozenT = note.userInfo?["frozenT"] as? Double
        haptics.cancelHold()
        launchClock = clock
        scheduleLaunchEnd(clock)
    }

    private func scheduleLaunchEnd(_ clock: LaunchClock) {
        let remaining = clock.remaining(at: Date())
        guard remaining.isFinite else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining + 0.02) {
            guard launchClock == clock, clock.isFinished(at: Date()) else { return }
            launchClock = nil
        }
    }

    /// タップで、すぐ最後へ(200ms)。進行中の触覚はすぐ止める。
    private func skipLaunch() {
        guard var clock = launchClock, clock.skip == nil else { return }
        let now = Date()
        clock.skip = (now, clock.t(at: now))
        launchClock = clock
        haptics.cancelHold()
        scheduleLaunchEnd(clock)
    }

    private func updateNow() {
        withAnimation(.easeInOut(duration: 0.5)) { now = clock() }
    }

    /// 現像ずみ(dawn)になったら、アバターの白い点を点ける(その1枚につき1度)。
    private func reportDevelopFinishedIfNeeded() {
        guard case .developed(let at) = developContent else { return }
        let key = String(Int(at.timeIntervalSince1970))
        guard key != avatarBadgeAcknowledged, key != avatarBadgePending else { return }
        avatarBadgePending = key
    }

    // MARK: - 月

    private func moonLayer(size: CGSize, launch: LaunchFrame) -> some View {
        let plan = state.moonPlan(yesterday: yesterdayLight)
        return HomeMoon(
            mode: moonMode(for: plan),
            screenSize: size,
            holdModel: holdModel,
            haptics: haptics,
            textOpacity: moonTextOpacity,
            isInteractive: screen == .home && !isMoonAnimating,
            onTap: {
                // 押した瞬間の時刻で判定しなおす(表示中の状態が古い可能性があるため)。
                let current = homeState(at: clock()).moonPlan(yesterday: yesterdayLight)
                switch current {
                case .shoot: expandMoon(to: .shoot)
                case .decide:
                    haptics.playTransient(intensity: 0.25, sharpness: 0.4)
                    openDecision(playsUnlock: false)
                case .review: viewYesterday(scope: .everyone)
                case .open, .locked: updateNow()
                }
            },
            onHoldComplete: { openYesterday(scope: .everyone) },
            onDimTap: {
                if case .locked(let title, _) = plan { presentLockedToast(title) }
            },
            launchGlowOpacity: launch.moonGlowOpacity,
            launchGlowScale: launch.moonGlowScale,
            chic: isChicHome
        )
        .id(plan)
        .scaleEffect(moonScale, anchor: .center)
        .position(MoonLayout.center(in: size))
        .opacity(moonOpacity)
        .allowsHitTesting(screen == .home && !isMoonAnimating && launchClock == nil)
    }

    private func moonMode(for plan: HomeState.MoonPlan) -> HomeMoon.Mode {
        switch plan {
        case .locked(let title, let subtitle): return .dim(title: title, subtitle: subtitle)
        case .shoot: return .tap(title: "今日を撮る", subtitle: "タップ", tone: .warm)
        case .decide: return .tap(title: "昨日の1枚を選ぶ", subtitle: "タップ", tone: .decide)
        case .open: return .hold
        case .review: return .tap(title: "昨日をもう一度見る", subtitle: "タップ", tone: .cool)
        }
    }

    /// 月がふくらんで、タグの画面になる(760ms・cubic-bezier(0.62, 0, 0.28, 1)・約22倍)。
    /// ふくらみきる直前(約700ms)でタグ画面を出し、白い円は520msで消える。触覚なし。
    private func expandMoon(to target: Screen) {
        guard !isMoonAnimating, screen == .home else { return }
        isMoonAnimating = true

        if reduceMotion {
            shootEntranceDelay = nil
            withAnimation(.easeInOut(duration: 0.25)) {
                screen = target
                homeOpacity = 0
                moonOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { isMoonAnimating = false }
            return
        }

        let fullScale = MoonLayout.fullScale(in: screenSize)
        withAnimation(.easeOut(duration: 0.42)) { homeOpacity = 0 }
        withAnimation(.easeOut(duration: 0.3)) { bottomFadeOpacity = 0 }
        withAnimation(.easeOut(duration: 0.2)) { moonTextOpacity = 0 }
        withAnimation(.timingCurve(0.62, 0, 0.28, 1, duration: 0.76)) { moonScale = fullScale }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            shootEntranceDelay = 0.05
            screen = target
            withAnimation(.easeOut(duration: 0.52)) { moonOpacity = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.22) { isMoonAnimating = false }
    }

    /// 長押しが1.2秒に達した:ひらいた記録を残し、オレンジの光が画面をおおって(700ms・約22倍)、
    /// その下から昨日を見る画面が出る。光は約600msで消える。
    private func openYesterday(scope: YesterdayScope) {
        openedWindowKey = DailyWindow.key(for: clock())
        yesterdayScope = openingScope(scope)
        sheetGroup = nil
        guard !isMoonAnimating else { return }
        isMoonAnimating = true

        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.25)) {
                screen = .yesterday
                homeOpacity = 0
                moonOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { isMoonAnimating = false }
            return
        }

        openLightScale = 0.4
        openLightOpacity = 1
        withAnimation(.timingCurve(0.6, 0, 0.3, 1, duration: 0.7)) { openLightScale = 22 }
        withAnimation(.easeOut(duration: 0.3)) { moonTextOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                screen = .yesterday
                homeOpacity = 0
                moonOpacity = 0
                bottomFadeOpacity = 0
            }
            withAnimation(.easeOut(duration: 0.6)) { openLightOpacity = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            openLightScale = 0.01
            isMoonAnimating = false
        }
    }

    /// opened:昨日をもう一度見る(タップ)
    private func viewYesterday(scope: YesterdayScope) {
        yesterdayScope = openingScope(scope)
        sheetGroup = nil
        expandMoon(to: .yesterday)
    }

    private func closeYesterday() {
        holdModel.reset()
        shrinkMoonBack()
    }

    /// 「×」で、月が縮んでHomeに戻る(640ms)。入力中のタグは下書きとして残る。
    private func shrinkMoonBack() {
        guard !isMoonAnimating, screen != .home else { return }
        if usesV5Home {
            // 撮影後の Home:撮影画面が左へ引っこむ(視差効果を減らす が入っているときは、フェード)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            withAnimation(reduceMotion ? .easeOut(duration: 0.25) : .spring(response: 0.45, dampingFraction: 0.86)) { screen = .home }
            return
        }
        isMoonAnimating = true
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.25)) {
                screen = .home
                homeOpacity = 1
                moonOpacity = 1
                moonScale = 1
                moonTextOpacity = 1
                bottomFadeOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { isMoonAnimating = false }
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            moonScale = MoonLayout.fullScale(in: screenSize)
            moonOpacity = 1
            moonTextOpacity = 0
            screen = .home
        }
        withAnimation(.timingCurve(0.3, 0, 0.2, 1, duration: 0.64)) { moonScale = 1 }
        withAnimation(.easeOut(duration: 0.455).delay(0.245)) { homeOpacity = 1 }
        withAnimation(.easeOut(duration: 0.3).delay(0.34)) { bottomFadeOpacity = 1 }
        withAnimation(.easeOut(duration: 0.3).delay(0.5)) { moonTextOpacity = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { isMoonAnimating = false }
    }

    /// 複数グループをまたぐ画面なので、Private/Shared両DBの変更をまとめて取り込む。
    private func refreshAllGroups() async {
        guard let cloudKitManager = CloudKitManager.current else {
            if syncStatus == .loading { syncStatus = .failed }
            return
        }
        let ok = await cloudKitManager.fetchAllChangesNow()
        // 一度でも取れていれば、そのあとの一時的な失敗では「失敗」にしない。
        if ok { syncStatus = .ok } else if syncStatus != .ok { syncStatus = .failed }
        await cloudKitManager.resendOwnUnlockedPhotosIfNeeded()
    }

    // MARK: - 撮影した1枚の保存

    private func saveExposure(imageData: Data, exposureStart: Date, tags: [String], locationName: String?) -> Bool {
        guard let user = currentUser else { return false }
        do {
            try DailyExposureStore.save(
                imageData: imageData,
                captureDate: exposureStart,
                tags: tags,
                locationName: locationName,
                user: user,
                groups: userGroups,
                context: context
            )
            return true
        } catch {
            print("[PhotoSave Error] 撮影した1枚の保存に失敗: \(error)")
            return false
        }
    }

    /// 「預けました」を見せ終えた。黒い幕を残したまま撮影画面を外してHomeに戻し(状態は ready)、
    /// 幕をゆっくり(0.6秒)フェードさせる。Homeにもどった瞬間に、ごく軽く1回。
    private func finishExposure() {
        if isDeciding(homeState(at: clock())) {
            finishExposureIntoDecision()
            return
        }
        // その日の最初の1枚:月の中心から光が広がり、光の下で2画面に切りかわる(2枚目以降は光なし)
        if shotsInLatestWindow == 1, !reduceMotion {
            playFirstShotLight()
            return
        }
        shotEvent = ShotEvent()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isShowingExposureVeil = true
            screen = .home
            moonScale = 1
            moonOpacity = 1
            moonTextOpacity = 1
            homeOpacity = 1
            bottomFadeOpacity = 1
            now = clock()
        }
        haptics.playTransient(intensity: 0.25, sharpness: 0.3)
        withAnimation(.easeOut(duration: 0.6).delay(0.05)) {
            isShowingExposureVeil = false
        }
    }

    /// 最初の1枚の瞬間:光が0.76秒で広がる → 光が着いた瞬間に軽く1回・下で2画面に切りかえ、
    /// 2画面が0.6秒でフェードイン・光が0.6秒でフェードアウト。「消灯まで」の時刻は同じ関数(DailyWindow)のまま。
    private func playFirstShotLight() {
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            v5Opacity = 0
            firstLightProgress = 0
            firstLightOpacity = 1
        }
        withAnimation(.easeIn(duration: 0.76)) { firstLightProgress = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.76) {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                screen = .home
                moonScale = 1
                moonOpacity = 1
                moonTextOpacity = 1
                homeOpacity = 1
                bottomFadeOpacity = 1
                now = clock()
            }
            shotEvent = ShotEvent()
            withAnimation(.easeOut(duration: 0.6)) {
                v5Opacity = 1
                firstLightOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) { firstLightProgress = 0 }
            }
        }
    }

    // MARK: - グループが終わった

    /// 終わったグループを、1つずつ「このグループは、終わりました。」で知らせる(見逃してもよい)
    private func showNextEndedGroup() {
        guard endedGroup == nil, leaveSnapshot == nil, let next = EndedGroupsStore.popFirst() else { return }
        if sheetGroup?.id == next.groupID { sheetGroup = nil }
        if settingsGroup?.id == next.groupID { settingsGroup = nil }
        withAnimation(.easeOut(duration: 0.3)) { endedGroup = next }
    }

    // MARK: - 昨日の1枚を、投稿するか選ぶ

    private func isDeciding(_ state: HomeState) -> Bool {
        if case .deciding = state { return true }
        return false
    }

    /// 「預けました」のあと、そのまま解禁へ(昨日の自分の1枚がある日だけ)
    private func finishExposureIntoDecision() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isShowingExposureVeil = true
            now = clock()
            homeOpacity = 0
            moonOpacity = 0
            bottomFadeOpacity = 0
        }
        openDecision(playsUnlock: unlockPlayedWindowKey != DailyWindow.key(for: clock()))
        withAnimation(.easeOut(duration: 0.6).delay(0.05)) {
            isShowingExposureVeil = false
        }
    }

    /// 選ぶ画面を開く。解禁は、その窓で一度だけ見せる
    private func openDecision(playsUnlock: Bool) {
        let key = DailyWindow.key(for: clock())
        decidePlaysUnlock = playsUnlock && unlockPlayedWindowKey != key
        unlockPlayedWindowKey = key
        isFinishingDecision = false
        sheetGroup = nil
        let photos = yesterdayOwnPhotos(at: clock())
        guard let first = photos.first else {
            closeDecision(toast: nil)
            return
        }
        decideSnapshot = DecideSnapshot(
            image: UIImage(data: first.imageData),
            capturedAt: first.captureDate,
            groups: shareGroups(of: photos),
            showsMondo: MondoService.isPublic
        )
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            screen = .decide
            homeOpacity = 0
            moonOpacity = 0
            bottomFadeOpacity = 0
        }
    }

    @ViewBuilder
    private var decideView: some View {
        if let snapshot = decideSnapshot {
            UnlockPostView(
                image: snapshot.image,
                capturedAt: snapshot.capturedAt,
                groups: snapshot.groups,
                showsMondo: snapshot.showsMondo,
                playsUnlock: decidePlaysUnlock,
                haptics: haptics,
                onDecide: decide,
                onFinished: { outcome in
                    let summary = ProfileShot.shareSummary(groups: snapshot.groups, isOnMondo: snapshot.showsMondo)
                    let text = outcome == .posted
                        ? (summary.isEmpty ? "投稿しました" : "投稿しました\n" + summary)
                        : "消しました\n昨日の1枚"
                    closeDecision(toast: text)
                }
            )
        } else {
            Color.black.ignoresSafeArea()
        }
    }

    /// その1枚が届くグループ(MEを除く)
    private func shareGroups(of photos: [LaterPhoto]) -> [ProfileShareGroup] {
        var seen = Set<UUID>()
        return photos.compactMap { photo in
            guard let id = photo.groupID, seen.insert(id).inserted,
                  let group = userGroups.first(where: { $0.id == id }), !group.isPersonalSpace else { return nil }
            return ProfileShareGroup(name: group.name, otherMemberCount: group.members.filter { $0.id != currentUser?.id }.count)
        }
    }

    private func decide(_ outcome: UnlockPostView.Outcome) {
        isFinishingDecision = true
        // 押した瞬間の写真で処理する(9:00 をまたいで、すでに消えている場合は何もしない)
        let photos = yesterdayOwnPhotos(at: clock()).filter { !$0.isPosted }
        guard !photos.isEmpty else { return }
        switch outcome {
        case .posted:
            if let currentUser { YesterdayPostStore.post(photos, user: currentUser, context: context) }
        case .skipped:
            YesterdayPostStore.skip(photos, context: context)
        }
    }

    /// Homeへもどる(ready)。選んだときだけ、小さなお知らせ+ごく軽く1回(昨日がひらける)
    private func closeDecision(toast: String?) {
        withAnimation(.easeOut(duration: 0.4)) {
            screen = .home
            homeOpacity = 1
            moonOpacity = 1
            moonScale = 1
            moonTextOpacity = 1
            bottomFadeOpacity = 1
            now = clock()
        }
        isFinishingDecision = false
        decideSnapshot = nil
        if let toast {
            haptics.playTransient(intensity: 0.25, sharpness: 0.4)
            presentToast(toast)
        }
    }

    // MARK: - Mondo(光の球から入る)

    // MARK: - 撮影画面をひらく(VoiceOver)

    /// 撮影画面を下へ120pt以上・左へ110pt以上払ったら閉じる。下のシャッターまわり(長押し1.5秒)では始めない
    private var closeShootSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard screen == .shoot else { return }
                let reservedBottom: CGFloat = 260
                guard value.startLocation.y < max(0, rootSize.height - reservedBottom) else { return }
                let isLeft = value.translation.width < -CameraOpenRule.swipeLeftToClose
                    && abs(value.translation.height) < abs(value.translation.width)
                let isDown = value.translation.height > CameraOpenRule.swipeDownToClose
                    && abs(value.translation.width) < abs(value.translation.height)
                guard isLeft || isDown else { return }
                shrinkMoonBack()
            }
    }

    private func dismissTabsCoach() {
        UserDefaults.standard.set(true, forKey: "coach.tabs.v1")
        v5Signals.isShowingCoach = false
    }

    /// はじめての説明・使い方カードが出ていれば閉じる(そのまま撮影画面へ)
    private func dismissIntroCards() {
        if v5Signals.isShowingGuide {
            UserDefaults.standard.set(true, forKey: FirstGuide.seenKey)
            v5Signals.isShowingGuide = false
        }
        if v5Signals.isShowingCoach { dismissTabsCoach() }
    }

    /// 撮影画面をひらく要求を受けない状態:撮影画面・別の画面・シート・全画面カバー・ビューア・詳細・入力中など
    private func deniedDecision(for state: HomeState) -> CameraOpenRule.Decision {
        state.isNight ? .deniedNight : .deniedShotsUsed
    }

    /// 撮れないとき:エラーの触覚+中央のカードを1.6秒。VoiceOver には読み上げる
    private func showCameraDenied(_ decision: CameraOpenRule.Decision, feedback: Bool) {
        guard let copy = CameraOpenRule.deniedCopy(decision) else { return }
        if feedback {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        cameraDeniedGeneration += 1
        let generation = cameraDeniedGeneration
        withAnimation(.easeOut(duration: 0.2)) { cameraDenied = copy }
        if UIAccessibility.isVoiceOverRunning, let spoken = CameraOpenRule.deniedSpoken(decision) {
            UIAccessibility.post(notification: .announcement, argument: spoken)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + CameraOpenRule.deniedCardSeconds) {
            guard generation == cameraDeniedGeneration else { return }
            withAnimation(.easeOut(duration: 0.25)) { cameraDenied = nil }
        }
    }

    /// VoiceOver の「撮影画面をひらく」。撮れるときはひらき、撮れないときは理由を読む(連打の間隔は見ない)
    private func openCameraFromAccessibility() {
        guard screen == .home, !isHomeCovered, !isMoonAnimating, launchClock == nil else { return }
        let state = homeState(at: clock())
        guard CameraOpenRule.canOpen(canShoot: state.canShoot, shotsToday: shotsInLatestWindow) else {
            showCameraDenied(deniedDecision(for: state), feedback: false)
            return
        }
        dismissIntroCards()
        if usesV5Home { openShootV5() } else { expandMoon(to: .shoot) }
    }

    /// ことわりのカードの層
    private var cameraDeniedOverlay: some View {
        ZStack {
            if let denied = cameraDenied {
                CameraDeniedCard(title: denied.title, detail: denied.detail)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }

    /// 画面の土台(ことわりのカード)
    private var entryLayer: some View {
        lifecycleLayer
            .background(Color.black.ignoresSafeArea())
            .overlay { cameraDeniedOverlay }
    }

    /// 撮影後の Home(v5)から撮影画面へ。
    /// 触覚「トトン」・撮影画面は scale 1.06 → 1・フェードイン(0.55秒)。
    /// Reduce Motion のときは、0.2秒のフェード。
    private func openShootV5() {
        guard !isMoonAnimating, screen == .home else { return }
        haptics.playPattern(HomeHapticPattern.openShoot)
        shootEntranceDelay = nil
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.55)) { screen = .shoot }
    }

    /// 撮影後の Home(v5)に入ったら、昨日をひらいたことにする(月の長押しは、もうない)
    private func openYesterdayForGroupHome() {
        guard case .ready = homeState(at: clock()) else { return }
        openedWindowKey = DailyWindow.key(for: clock())
    }

    private func tapOrb() {
        guard screen == .home, !isMoonAnimating, launchClock == nil else { return }
        switch homeState(at: clock()).mondoGate {
        case .enter:
            diveIntoMondo()
        case .locked(let title, let message):
            haptics.playSoftDouble()
            presentToast(title + "\n" + message)
        }
    }

    /// 光の球に吸い込まれる(合計 約0.9秒)。球は720msで5.5倍にふくらんで消え、ほかは320msで消える。
    /// 560msの時点で、次の画面(ようこそ or Mondo トップ)が下から静かに出る。途中のタップは無視する。
    private func diveIntoMondo() {
        isMoonAnimating = true
        haptics.playTransient(intensity: 0.3, sharpness: 0.4)
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.3)) {
                screen = .mondo
                homeOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isMoonAnimating = false }
            return
        }
        isDivingToMondo = true
        withAnimation(.easeOut(duration: 0.3)) { bottomFadeOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
            screen = .mondo
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            homeOpacity = 0
            isMoonAnimating = false
        }
    }

    /// 戻る(‹):Mondo をフェードアウト → Home が 500ms で 0 → 1。ダイブで消した要素は元にもどす。
    private func closeMondo() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { isDivingToMondo = false }
        withAnimation(.easeOut(duration: 0.3)) { screen = .home }
        withAnimation(.easeOut(duration: 0.5)) {
            homeOpacity = 1
            bottomFadeOpacity = 1
        }
    }

    // MARK: - ロック中の月のお知らせ

    /// やわらかく2回(強さ0.4・鋭さ0.2、間90ms)+ 2.3秒だけお知らせ。
    private func presentLockedToast(_ text: String) {
        haptics.playSoftDouble()
        presentToast(text)
    }

    /// ウィジェットに渡す値(写真そのもの・他の人の名前は渡さない)
    private func syncWidget() {
        let current = clock()
        LaterWidgetBridge.update(
            captureDates: myCaptureDates,
            hasYesterday: HomeState.yesterdayPhotoCount(in: userGroups, now: current) > 0,
            openedYesterday: openedWindowKey == DailyWindow.key(for: current),
            now: current
        )
    }

    /// Homeの上に別の画面・シートが重なっているか
    private var isHomeCovered: Bool {
        screen != .home || showingNewGroup || sheetGroup != nil || showingDevelopSheet || showingAddGroupSheet
    }

    /// 追加シートで選んだ:ごく軽く1回(えらぶ)→ シートを閉じてから、いつもの画面へ
    private func chooseFromAddSheet(_ open: @escaping () -> Void) {
        haptics.playTransient(intensity: 0.3, sharpness: 0.5)
        showingAddGroupSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: open)
    }

    private func presentToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.2)) { lockedToast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            withAnimation(.easeOut(duration: 0.2)) { if lockedToast == text { lockedToast = nil } }
        }
    }

    private func toast(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, MoonLayout.visibleHeight + 36)
    }
}

// MARK: - 画面状態

/// 画面中央のアクション要素(撮影ボタンが置かれる場所)の状態。GroupStatusPresenter.state(for:)と
/// 「個人の撮影上限に達しているか」の組み合わせで決まる。実際の描画分岐は
/// TodayShootingView側で行うため、
/// ここでは概念を明示するためのenumとして定義するに留める。
enum CaptureActionState: Equatable {
    case capture              // 撮影中・撮影可能
    case captureLimitReached  // 撮影中・個人の上限(GroupUnlockPolicy.individualMaximumPhotoCount)に到達済み
    case vote                 // 投票中
    case result                // 終了後
}
