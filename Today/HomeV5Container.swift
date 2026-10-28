import SwiftData
import SwiftUI
import UIKit

/// 撮影後の Home(v5)。標準の TabView で、Mondo / グループ / カレンダー の3つの場所を切りかえる(iOS 26 では、浮かぶガラスのタブバー)。
/// ヘッダー(Later・消灯までのピル・アバター)は3つのタブで同じ。
/// 写真を見るのは、すべて縦の全画面ページ(VerticalPhotoViewer)。データの用意(グループ・タイル・Mondo)と、
/// ビューア・グループの部屋・位置の共有・はじめての説明をつなぐ。
struct HomeV5Container: View {
    let state: HomeState
    let now: Date
    let haptics: ExposureHaptics
    let shotsToday: Int
    let currentUser: UserProfile?
    let sharedGroups: [LaterGroup]
    let canCreateGroup: Bool
    let avatarImage: UIImage?
    let showsAvatarBadge: Bool
    /// 他のシート・画面が重なっている
    let isCovered: Bool
    let shotEvent: ShotEvent?
    let onOpenProfile: () -> Void
    let onOpenGroupSheet: (UUID) -> Void
    let onAddGroup: () -> Void
    /// 0 グループの GROUP 画面から。つくる(ステッカーの言葉を名前に入れて)・参加する
    var onCreateGroup: (String?) -> Void = { _ in }
    var onJoinGroup: () -> Void = {}
    /// 今日を撮る前に、手で昨日のホームをひらいた(昨日のものはぼかして、ロックする)
    var locked = false
    /// アバターの2回タップ・長押し(今日 / 昨日の切りかえ)
    var avatarSwitch = AvatarSwitch()

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var blockedUsers: [BlockedUser]
    @Query private var exposureDays: [ExposureDay]
    /// 右上の「消灯まで」ピルから出す光のパネル
    @State private var showsLightsPanel = false
    /// 新しいヘッダー(80pt)が、これまでの48ptより下へ広がった分(各ページの上の余白に足す)
    private static let headerExtra: CGFloat = 32
    @AppStorage(FirstGuide.seenKey) private var guideSeen = false
    @AppStorage("mondoSeen") private var mondoSeen = false

    /// 最後に見ていたタブ(mondo / group / calendar)。開きなおしても覚えている(はじめは Mondo)
    @AppStorage("homeV5LastTab") private var tabRaw = "mondo"
    /// はじめての使い方カード(1回だけ)
    @AppStorage("coach.tabs.v1") private var coachSeen = false
    @State private var seenSignature: Int?
    /// グループのタブのバッジ用:見たときのタイルの数
    @State private var seenTileCount = 0
    /// 選択ずみのタブをもう一度タップしたときの、「上へもどる」合図
    @State private var mondoTop = 0
    @State private var groupTop = 0
    @State private var calendarTop = 0
    /// カレンダーの NavigationStack(日の詳細は、ここに1段だけ push する。値は yyyy-MM-dd)
    @State private var calendarPath: [String] = []
    @State private var loader = MondoV5Loader()
    @State private var viewer: ViewerState?
    @State private var viewerShown = false
    @State private var roomGroupID: UUID?
    @State private var pendingLocation: (groupID: UUID, mode: GroupLocationMode)?
    @State private var modeRevision = 0
    @State private var showsMondoSettings = false
    @State private var showsWelcome = false
    @State private var reportEntry: MondoEntry?
    @State private var flight: CGFloat?
    @State private var avatarPop = false
    @State private var lampBoard = LampBoard.shared
    @State private var picks = AnnouncedPickStore.shared
    @State private var screenSize = CGSize(width: 390, height: 844)
    private let signals = HomeV5Signals.shared

    struct ViewerState: Identifiable {
        let id = UUID()
        let pages: [ViewerPage]
        let start: Int
        let anchor: UnitPoint
        /// 灯の表示(ボタン・右上の丸)を出すか。カレンダーから開いたときは出さない
        var usesLamps = true
    }

    // MARK: - データ

    private var blocked: Set<String> {
        Set(blockedUsers.map(\.blockedCloudKitUserRecordName))
    }

    private var sections: [GroupSectionModel] {
        _ = modeRevision
        let auras = GroupRingMath.auraIndices(for: sharedGroups.map(\.id))
        var aura: [UUID: Int] = [:]
        for (group, index) in zip(sharedGroups, auras) {
            aura[group.id] = GroupPalette.isValid(group.colorIndex) ? group.colorIndex : index
        }
        return GroupSections.build(
            groups: sharedGroups,
            myProfileID: currentUser?.id,
            myRecordName: CloudKitManager.current?.currentUserRecordName ?? currentUser?.cloudKitUserRecordName,
            blocked: blocked,
            shotsToday: shotsToday,
            now: now,
            auraIndices: aura
        )
    }

    private var dayKey: String { MondoWindow.yesterdayKey(now: now) }

    /// グループの「昨日」の撮影日(GROUP のタイルと同じ数え方)
    private var groupDayKey: String { ExposureDayStore.dayKey(for: DailyWindow.yesterday(for: now).open) }

    /// グループの灯の置き場所(グループの recordName。まだなければ端末の id)
    private func lampScope(for groupID: UUID) -> String? {
        sharedGroups.first { $0.id == groupID }.map { LampScope.group($0.ckRecordName ?? $0.id.uuidString) }
    }

    /// 発表された一枚(グループごと。なければタイルを出さない)
    private var announcedGroupPicks: [UUID: AnnouncedPick] {
        var result: [UUID: AnnouncedPick] = [:]
        for group in sharedGroups {
            guard let scope = lampScope(for: group.id), let pick = picks.group(day: groupDayKey, scope: scope) else { continue }
            result[group.id] = pick
        }
        return result
    }

    /// 自分が灯をともしているタイルの id(GROUP のタイルの右下の印)
    private var litTileIDs: Set<String> {
        var result = Set<String>()
        for section in sections {
            guard let scope = lampScope(for: section.id), let photo = lampBoard.litPhoto(day: groupDayKey, scope: scope) else { continue }
            if let tile = section.tiles.first(where: { $0.photoRecordName == photo }) { result.insert(tile.id) }
        }
        return result
    }

    private var shotDays: Set<String> { Set(exposureDays.map(\.dayKey)) }

    // MARK: - タブ

    private var tab: HomeTab {
        switch tabRaw {
        case "group": return .group
        case "calendar": return .calendar
        default: return .mondo
        }
    }

    private func store(_ tab: HomeTab) {
        switch tab {
        case .mondo: tabRaw = "mondo"
        case .group: tabRaw = "group"
        case .calendar: tabRaw = "calendar"
        }
    }

    /// 標準の TabView の選択。選択ずみのタブをもう一度タップしたときも set が呼ばれるので、そのときは上へもどる
    private var tabBinding: Binding<HomeTab> {
        Binding(
            get: { tab },
            set: { new in
                if new == tab {
                    scrollToTop(new)
                } else {
                    selectTab(new)
                }
            }
        )
    }

    private func selectTab(_ new: HomeTab) {
        UISelectionFeedbackGenerator().selectionChanged()
        if showsLightsPanel { setLightsPanel(false) }
        store(new)
        signals.activeTab = new
        if new == .group { markGroupSeen() }
        if new == .calendar { picks.markSeen() }
    }

    private func scrollToTop(_ tab: HomeTab) {
        switch tab {
        case .mondo: mondoTop += 1
        case .group: groupTop += 1
        case .calendar:
            if calendarPath.isEmpty { calendarTop += 1 } else { calendarPath.removeAll() }
        }
    }

    private func markGroupSeen() {
        seenSignature = GroupSections.activitySignature(sections)
        seenTileCount = totalTileCount
    }

    private var totalTileCount: Int { sections.reduce(0) { $0 + $1.tiles.count } }

    /// グループのタブのバッジ(新しいグループの写真の数。0 なら出さない)
    private var groupBadge: Int {
        guard tab != .group, let seenSignature, GroupSections.activitySignature(sections) != seenSignature else { return 0 }
        return max(1, totalTileCount - seenTileCount)
    }

    private var isCalm: Bool {
        scenePhase == .active && !isCovered && viewer == nil && roomGroupID == nil && calendarPath.isEmpty
    }

    /// 使い方カードを出していいか:説明・ようこそ・シートなどが終わっていて、まだ見ていない
    private var coachEligible: Bool {
        !locked && !coachSeen && guideSeen && mondoSeen && isCalm && !signals.isShowingGuide && !showsWelcome && !showsMondoSettings && pendingLocation == nil && reportEntry == nil && !showsLightsPanel
    }

    /// 撮影画面への入口を受けない:ビューア・グループの部屋・カレンダーの日の詳細・Mondo の設定・位置の確認・通報・ようこそ・光のパネル
    private var blocksCameraEntry: Bool {
        viewer != nil || roomGroupID != nil || !calendarPath.isEmpty || showsMondoSettings || pendingLocation != nil || reportEntry != nil || showsWelcome || showsLightsPanel
    }

    private func presentCoachIfNeeded() {
        guard coachEligible, !signals.isShowingCoach else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard coachEligible, !signals.isShowingCoach else { return }
            withAnimation(.easeOut(duration: 0.3)) { signals.isShowingCoach = true }
        }
    }

    private func dismissCoach() {
        coachSeen = true
        withAnimation(.easeOut(duration: 0.25)) { signals.isShowingCoach = false }
    }

    /// タブの中身の下に、タブバーの高さを測る
    private func measured<Content: View>(_ content: Content, safeBottom: CGFloat) -> some View {
        content.background {
            Color.clear
                .ignoresSafeArea()
                .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { inset in
                    signals.tabBarExtra = max(0, inset - safeBottom)
                }
        }
    }

    /// 光のパネルをひらく(ひらくとき1回だけ軽い触覚)・とじる
    private func setLightsPanel(_ open: Bool) {
        guard open != showsLightsPanel else { return }
        if open {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.8)) { showsLightsPanel = true }
        } else {
            withAnimation(.easeOut(duration: 0.25)) { showsLightsPanel = false }
        }
    }

    // MARK: - 本体

    var body: some View {
        GeometryReader { proxy in
            let top = proxy.safeAreaInsets.top
            ZStack(alignment: .top) {
                ChicColor.paper.ignoresSafeArea()

                TabView(selection: tabBinding) {
                    Tab("Mondo", systemImage: "globe.asia.australia.fill", value: HomeTab.mondo) {
                        measured(
                            HomeV5MondoPage(
                                phase: loader.phase,
                                dayKey: dayKey,
                                isActive: isCalm && tab == .mondo,
                                topInset: top + Self.headerExtra,
                                onTick: { haptics.playPattern(HomeHapticPattern.globeTick) },
                                onSettings: { showsMondoSettings = true },
                                onRetry: { Task { await loader.load(now: now, blocked: MondoService.blockedMondoIDs(blockedUsers), force: true) } },
                                onOpenTag: openTagFeed,
                                onOpenAll: openAll,
                                announced: picks.world(day: dayKey),
                                onOpenAnnounced: openAnnouncedWorld,
                                scrollToTopToken: mondoTop,
                                locked: locked
                            ),
                            safeBottom: proxy.safeAreaInsets.bottom
                        )
                    }

                    Tab("グループ", systemImage: "person.2.fill", value: HomeTab.group) {
                        measured(
                            HomeV5GroupPage(
                                sections: sections,
                                isActive: isCalm && tab == .group,
                                haptics: haptics,
                                shotEvent: shotEvent,
                                windowKey: DailyWindow.key(for: now),
                                topInset: top + Self.headerExtra,
                                canCreate: canCreateGroup,
                                onOpenRoom: openRoom,
                                onOpenTile: openGroupTile,
                                onCycleLocation: cycleLocation,
                                onAdd: onAddGroup,
                                userName: currentUser?.name ?? "",
                                onCreateGroup: onCreateGroup,
                                onJoinGroup: onJoinGroup,
                                announced: announcedGroupPicks,
                                litTileIDs: litTileIDs,
                                onOpenAnnounced: openAnnouncedGroup,
                                scrollToTopToken: groupTop,
                                locked: locked
                            ),
                            safeBottom: proxy.safeAreaInsets.bottom
                        )
                    }
                    .badge(groupBadge)

                    Tab("カレンダー", systemImage: "calendar", value: HomeTab.calendar) {
                        measured(calendarTab(topInset: top + Self.headerExtra), safeBottom: proxy.safeAreaInsets.bottom)
                    }
                }
                .tint(ChicColor.ink)

                V5HeaderScrim()
                    .opacity(calendarPath.isEmpty ? 1 : 0)

                if showsLightsPanel {
                    LightsPanelDim { setLightsPanel(false) }
                        .environment(\.colorScheme, .dark)
                        .transition(.opacity)
                }

                LaterHeader(
                    home: .yesterday,
                    shotsToday: shotsToday,
                    avatarImage: avatarImage,
                    avatarName: currentUser?.name ?? "",
                    showsBadge: showsAvatarBadge,
                    onAvatar: { if showsLightsPanel { setLightsPanel(false) } else { onOpenProfile() } },
                    onConsumption: { setLightsPanel(!showsLightsPanel) },
                    avatarSwitch: avatarSwitch,
                    clock: { now }
                )
                .overlay(alignment: .topTrailing) { avatarPulse(top: top) }
                // 日の詳細(1段 push)では、ナビゲーションバーと重ならないよう、ヘッダーを静かに消す
                .opacity(calendarPath.isEmpty ? 1 : 0)
                .allowsHitTesting(calendarPath.isEmpty)
                .accessibilityHidden(!calendarPath.isEmpty)

                if showsLightsPanel, calendarPath.isEmpty {
                    LightsPanel(
                        now: now,
                        taken: shotsToday,
                        width: min(300, proxy.size.width - 44),
                        onClose: { setLightsPanel(false) }
                    )
                    .padding(.top, LaterHeader.height + 6)
                    .padding(.leading, 20)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .environment(\.colorScheme, .dark)
                    .transition(LightsPanel.transition(anchor: .topLeading))
                }

                if let flight {
                    ShotFlightCard(progress: flight, size: proxy.size, topInset: top)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(.easeOut(duration: 0.25), value: calendarPath.isEmpty)
            .onAppear { screenSize = proxy.size }
            .onChange(of: proxy.size) { _, size in screenSize = size }
        }
        .overlay { roomLayer.environment(\.colorScheme, .dark) }
        .overlay { viewerLayer.environment(\.colorScheme, .dark) }
        .overlay { reportLayer.environment(\.colorScheme, .dark) }
        .overlay {
            Group {
            if signals.isShowingGuide {
                FirstGuideView(haptics: haptics, onDismiss: dismissGuide)
                    .transition(.opacity)
                    .zIndex(5)
            }
            if showsWelcome {
                MondoWelcomeView(haptics: haptics) {
                    mondoSeen = true
                    withAnimation(.easeOut(duration: 0.4)) { showsWelcome = false }
                }
                .transition(.opacity)
                .zIndex(6)
            }
            // はじめての使い方カード(1回だけ)。暗くするだけで、下は触れる(タブは止めない)。
            if signals.isShowingCoach {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea().allowsHitTesting(false)
                    TabsCoachCard(onDismiss: dismissCoach)
                }
                .transition(.opacity)
                .zIndex(6.5)
            }
            }
            .environment(\.colorScheme, .dark)
        }
        .sheet(isPresented: $showsMondoSettings) {
            MondoSettingsSheet(haptics: haptics, onShowWelcome: {
                showsMondoSettings = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { withAnimation { showsWelcome = true } }
            })
            .presentationDetents([.medium, .large])
            .presentationBackground(Color(hex: "121214"))
        }
        .alert("この位置を、グループに見せますか?", isPresented: Binding(get: { pendingLocation != nil }, set: { if !$0 { pendingLocation = nil } })) {
            Button("共有する") {
                LocationShareStore.hasConfirmed = true
                if let pendingLocation { applyMode(pendingLocation.mode, groupID: pendingLocation.groupID) }
                pendingLocation = nil
            }
            Button("やめる", role: .cancel) { pendingLocation = nil }
        } message: {
            Text("そのグループの人だけに、約500mの範囲(撮った場所)が見えます。正確な場所は、どこにも保存されません。いつでもオフにでき、オフにすると保存した位置も消えます。")
        }
        .task(id: dayKey) {
            await loader.load(now: now, blocked: MondoService.blockedMondoIDs(blockedUsers))
        }
        .onAppear {
            lampBoard.prune(now: now)
            seenSignature = GroupSections.activitySignature(sections)
            seenTileCount = totalTileCount
            signals.activeTab = tab
            if tab == .group { markGroupSeen() }
            presentCoachIfNeeded()
            if locked {
                // 撮る前に手でひらいたとき:説明・ようこそは出さない(撮ったあとの Home で出す)
            } else if FirstGuide.shouldShow(seen: guideSeen, isCovered: isCovered) {
                // 撮影後の Home をはじめて開いたとき、1回だけ説明を出す
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    if FirstGuide.shouldShow(seen: guideSeen, isCovered: isCovered, isAlreadyShowing: signals.isShowingGuide) { withAnimation(.easeOut(duration: 0.3)) { signals.isShowingGuide = true } }
                }
            } else if !mondoSeen {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { if !mondoSeen { withAnimation { showsWelcome = true } } }
            }
            if let shotEvent, Date().timeIntervalSince(shotEvent.at) < 3 { playFlight() }
        }
        .onChange(of: shotEvent?.id) { _, _ in
            if let shotEvent, Date().timeIntervalSince(shotEvent.at) < 3 { playFlight() }
        }
        .onChange(of: GroupSections.activitySignature(sections)) { _, value in
            if tab == .group { seenSignature = value; seenTileCount = totalTileCount }
        }
        .onChange(of: coachEligible) { _, _ in presentCoachIfNeeded() }
        .onChange(of: locked) { old, new in
            // 撮ったので、昨日がひらく:晴れはじめに、軽く1回
            if old, !new { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        }
        .onChange(of: blocksCameraEntry) { _, blocked in signals.blocksCameraEntry = blocked }
        .onChange(of: showsMondoSettings || pendingLocation != nil || reportEntry != nil || showsWelcome || viewer != nil || roomGroupID != nil || !calendarPath.isEmpty) { _, covered in if covered, showsLightsPanel { showsLightsPanel = false } }
        .onChange(of: signals.isShowingGuide) { _, showing in
            if !showing, !mondoSeen {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { if !mondoSeen { withAnimation { showsWelcome = true } } }
            }
        }
    }

    // MARK: - 撮影のあと:写真が右上のアバターへ飛ぶ

    private func playFlight() {
        guard !reduceMotion else {
            pulseAvatar()
            return
        }
        flight = 0
        DispatchQueue.main.async {
            withAnimation(.timingCurve(0.5, 0, 0.2, 1, duration: 1.25)) { flight = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            flight = nil
            pulseAvatar()
        }
    }

    private func pulseAvatar() {
        withAnimation(.spring(duration: 0.5, bounce: 0.6)) { avatarPop = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { withAnimation(.spring(duration: 0.4)) { avatarPop = false } }
    }

    /// アバターがふくらむ(光の輪)
    private func avatarPulse(top: CGFloat) -> some View {
        Circle()
            .strokeBorder(ChicColor.accent, lineWidth: 2)
            .frame(width: 36, height: 36)
            .scaleEffect(avatarPop ? 1.7 : 1)
            .opacity(avatarPop ? 0.9 : 0)
            .padding(.trailing, 20)
            .padding(.top, 12)
            .allowsHitTesting(false)
    }

    // MARK: - はじめての説明

    private func dismissGuide() {
        guideSeen = true
        withAnimation(.easeOut(duration: 0.25)) { signals.isShowingGuide = false }
    }

    // MARK: - 位置の共有

    private func cycleLocation(_ groupID: UUID) {
        haptics.playPattern(HomeHapticPattern.light)
        let next = LocationShareStore.mode(for: groupID).next()
        requestMode(next, groupID: groupID)
    }

    private func requestMode(_ mode: GroupLocationMode, groupID: UUID) {
        // はじめてオンにするときは、短い確認(だれに・どのくらい正確か・いつでも止められる)
        if mode != .off, !LocationShareStore.hasConfirmed {
            pendingLocation = (groupID, mode)
            return
        }
        applyMode(mode, groupID: groupID)
    }

    private func applyMode(_ mode: GroupLocationMode, groupID: UUID) {
        guard let group = sharedGroups.first(where: { $0.id == groupID }), let user = currentUser else { return }
        GroupLocationService.didChangeMode(mode, group: group, user: user, context: modelContext)
        modeRevision += 1
    }

    // MARK: - グループの部屋

    private func openRoom(_ groupID: UUID) {
        haptics.playPattern(HomeHapticPattern.light)
        withAnimation(.timingCurve(0.2, 0.9, 0.22, 1, duration: 0.45)) { roomGroupID = groupID }
    }

    @ViewBuilder
    private var roomLayer: some View {
        if let groupID = roomGroupID, let model = roomModel(groupID) {
            GroupRoomView(
                model: model,
                haptics: haptics,
                onClose: { withAnimation(.easeOut(duration: 0.3)) { roomGroupID = nil } },
                onSelectMode: { requestMode($0, groupID: groupID) },
                onOpenTile: { point, tileID in openGroupTile(point: point, groupID: groupID, tileID: tileID) },
                onMore: { onOpenGroupSheet(groupID) }
            )
            .background(V5.bg.ignoresSafeArea())
            .transition(.move(edge: .trailing).combined(with: .opacity))
            .zIndex(3)
        }
    }

    private func roomModel(_ groupID: UUID) -> GroupRoomModel? {
        guard let group = sharedGroups.first(where: { $0.id == groupID }),
              let section = sections.first(where: { $0.id == groupID }) else { return nil }
        let window = DailyWindow.latest(for: now)
        let todayPhotos = group.photos.filter { $0.captureDate >= window.open && $0.captureDate < window.close }
        let shotIDs = Set(todayPhotos.compactMap { $0.owner?.id })
        let shotNames = Set(todayPhotos.compactMap { $0.authorCloudKitUserRecordName })
        let members = group.members.map { member in
            GroupRoomMember(
                id: member.id,
                imageData: member.profileImageData,
                hasShotToday: shotIDs.contains(member.id) || (member.cloudKitUserRecordName.map(shotNames.contains) ?? false)
            )
        }
        let pins = SharedPlacePins.pins(
            group: group,
            myID: currentUser?.id,
            myMode: section.locationMode,
            unlockedKeys: section.unlockedIDs,
            now: now
        )
        return GroupRoomModel(section: section, members: members, pins: pins)
    }

    // MARK: - ビューアをひらく

    private func unitPoint(_ point: CGPoint) -> UnitPoint {
        UnitPoint(x: min(1, max(0, point.x / max(1, screenSize.width))), y: min(1, max(0, point.y / max(1, screenSize.height))))
    }

    private func present(pages: [ViewerPage], start: Int, at point: CGPoint, usesLamps: Bool = true) {
        guard !pages.isEmpty else { return }
        viewerShown = false
        viewer = ViewerState(pages: pages, start: max(0, min(start, pages.count - 1)), anchor: unitPoint(point), usesLamps: usesLamps)
        // 押したタイル(または行)の位置から、scale .14 → 1(0.6秒、cubic-bezier(.2,.9,.22,1))
        DispatchQueue.main.async {
            withAnimation(reduceMotion ? .easeOut(duration: 0.25) : .timingCurve(0.2, 0.9, 0.22, 1, duration: 0.6)) { viewerShown = true }
        }
    }

    private func closeViewer() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .timingCurve(0.3, 0.7, 0.3, 1, duration: 0.45)) { viewerShown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.22 : 0.47)) {
            viewer = nil
        }
    }

    @ViewBuilder
    private var viewerLayer: some View {
        if let viewer {
            VerticalPhotoViewer(
                pages: viewer.pages,
                startIndex: viewer.start,
                haptics: haptics,
                onMore: { reportEntry = $0 },
                lampBoard: viewer.usesLamps ? lampBoard : nil,
                now: now,
                onClose: closeViewer
            )
            .id(viewer.id)
            .background(V5.bg.ignoresSafeArea())
            .clipShape(RoundedRectangle(cornerRadius: viewerShown ? 0 : 70, style: .continuous))
            .scaleEffect(reduceMotion ? 1 : (viewerShown ? 1 : 0.14), anchor: viewer.anchor)
            .opacity(viewerShown ? 1 : 0)
            .ignoresSafeArea()
            .zIndex(4)
        }
    }

    /// MONDO:ランキングの行(または行の中の写真)→ そのタグの写真が、全画面で縦に並ぶ。続けて次のタグへ。
    private func openTagFeed(point: CGPoint, tag: String, entryID: String?) {
        guard case .ready(let summary) = loader.phase else { return }
        haptics.playPattern(HomeHapticPattern.light)
        let ranking = TagRanking.rank(summary.topTags, dayKey: summary.dayKey)
        let feed = TagFeed.pages(ranking: ranking, entries: summary.entries, dayKey: summary.dayKey)
        guard !feed.isEmpty else { return }
        var pages = feed.map { page in
            ViewerPage(
                id: page.id,
                source: .mondo(page.entry),
                tags: page.entry.tags,
                dayText: V5.monthDay(fromDayKey: page.entry.dayKey),
                label: "#\(page.tag)",
                counter: page.counterText,
                moreEntry: page.entry,
                lamp: worldLamp(for: page.entry)
            )
        }
        // 最後は「今日の Mondo は、ここまで。」の終わりのページ
        pages.append(ViewerPage(id: "end", kind: .end(title: "今日の Mondo は、ここまで。", body: "あしたの朝、また新しい世界がひらきます")))
        present(pages: pages, start: TagFeed.startIndex(in: feed, tag: tag, entryID: entryID), at: point)
    }

    /// MONDO:「すべての昨日」のカード
    private func openAll(point: CGPoint, index: Int) {
        guard case .ready(let summary) = loader.phase else { return }
        haptics.playPattern(HomeHapticPattern.light)
        let list = Array(summary.entries.prefix(MondoConfig.maxCards))
        var pages = list.enumerated().map { offset, entry in
            ViewerPage(
                id: "all|" + entry.id,
                source: .mondo(entry),
                tags: entry.tags,
                dayText: V5.monthDay(fromDayKey: entry.dayKey),
                label: "Mondo",
                counter: TagFeed.counterText(index: offset, total: list.count),
                moreEntry: entry,
                lamp: worldLamp(for: entry)
            )
        }
        pages.append(ViewerPage(id: "end", kind: .end(title: "今日の Mondo は、ここまで。", body: "あしたの朝、また新しい世界がひらきます")))
        present(pages: pages, start: index, at: point)
    }

    /// GROUP:タイル → そのグループの昨日の写真が縦に並ぶ。解禁前のタイルは、鍵つきのモザイクのページ。
    private func openGroupTile(point: CGPoint, groupID: UUID, tileID: String) {
        guard let section = sections.first(where: { $0.id == groupID }),
              let start = section.tiles.firstIndex(where: { $0.id == tileID }) else { return }
        let tile = section.tiles[start]
        // 解禁の動きの前は鍵のまま:本物の写真は、ひらいたものだけ
        if section.unlockedIDs.contains(tile.id) { haptics.playPattern(HomeHapticPattern.light) } else { haptics.playSoftDouble() }
        let pages = section.tiles.enumerated().map { offset, tile -> ViewerPage in
            let unlocked = section.unlockedIDs.contains(tile.id)
            return ViewerPage(
                id: tile.id,
                source: .local(unlocked ? tile.imageData : nil),
                tags: tile.tags,
                capturedAt: tile.capturedAt,
                authorSeed: tile.authorSeed,
                authorImage: tile.authorImage,
                showsAuthor: true,
                isLocked: !unlocked,
                tiny: tile.tiny,
                tinyKey: tile.id,
                label: section.name,
                counter: TagFeed.counterText(index: offset, total: section.tiles.count),
                lamp: groupLamp(section: section, tile: tile, isUnlocked: unlocked)
            )
        }
        present(pages: pages, start: start, at: point)
        if section.unlockedIDs.contains(tile.id) { haptics.playPattern(HomeHapticPattern.openViewer) }
    }

    // MARK: - 灯

    /// MONDO の写真の灯の置き場所。他人の写真だけ、灯をともせる(Mondo は通報・ブロックずみを除いて届く)
    private func worldLamp(for entry: MondoEntry) -> LampTarget {
        let canLamp = LampRules.canLamp(isMine: entry.isMine, isUnlocked: true, isBlocked: false, shotsToday: shotsToday)
        return LampTarget(day: entry.dayKey, scope: LampScope.world, photoRecordName: canLamp ? entry.id : nil)
    }

    /// GROUP の写真の灯の置き場所。ひらいた他人の写真だけ、灯をともせる(未解禁・自分の写真には出さない)
    private func groupLamp(section: GroupSectionModel, tile: V5GroupTile, isUnlocked: Bool) -> LampTarget? {
        guard let scope = lampScope(for: section.id) else { return nil }
        let canLamp = LampRules.canLamp(isMine: tile.isMine, isUnlocked: isUnlocked, isBlocked: false, shotsToday: shotsToday)
        return LampTarget(day: groupDayKey, scope: scope, photoRecordName: canLamp ? tile.photoRecordName : nil)
    }

    // MARK: - 発表された一枚・カレンダー

    /// MONDO:昨日の一枚 → 縦のビューアで開く(灯ボタンは出さない。点灯アイコンだけ静かに出す)
    private func openAnnouncedWorld(point: CGPoint) {
        guard let pick = picks.world(day: dayKey) else { return }
        haptics.playPattern(HomeHapticPattern.light)
        present(pages: [announcedPage(pick, isWorld: true)], start: 0, at: point, usesLamps: false)
    }

    /// GROUP:発表された一枚 → ビューアで開く(撮った人の顔の丸も出す)
    private func openAnnouncedGroup(point: CGPoint, groupID: UUID) {
        guard let pick = announcedGroupPicks[groupID] else { return }
        haptics.playPattern(HomeHapticPattern.light)
        present(pages: [announcedPage(pick, isWorld: false)], start: 0, at: point, usesLamps: false)
    }

    private func announcedPage(_ pick: AnnouncedPick, isWorld: Bool) -> ViewerPage {
        ViewerPage(
            id: "pick|" + pick.id,
            source: pick.source,
            tags: pick.tags,
            dayText: V5.monthDay(fromDayKey: pick.day),
            authorSeed: pick.authorSeed,
            authorImage: pick.authorImage,
            showsAuthor: !isWorld && pick.authorSeed != nil,
            label: "",
            showsLitMark: true,
            showsGlobe: isWorld
        )
    }

    /// カレンダーのタブ:NavigationStack の一番上のページ。戻るボタンはない(日をひらくと1段だけ push され、標準の「‹ カレンダー」で戻る)
    private func calendarTab(topInset: CGFloat) -> some View {
        NavigationStack(path: $calendarPath) {
            LampCalendarView(
                now: now,
                picks: picks.picks,
                shotDays: shotDays,
                haptics: haptics,
                onOpenDay: openCalendarDay,
                scrollToCurrentToken: calendarTop,
                topInset: topInset
            )
            .background(ChicColor.paper.ignoresSafeArea())
            .navigationTitle("カレンダー")
            // 共通ヘッダーを使うので、このページの標準バーは隠す(戻るボタンの名前には、上のタイトルが使われる)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { day in
                CalendarDayPage(
                    day: day,
                    pages: calendarDayPages(day),
                    haptics: haptics,
                    onClose: { calendarPath.removeAll() }
                )
            }
        }
    }

    private func calendarDayPages(_ day: String) -> [ViewerPage] {
        var pages: [ViewerPage] = []
        if let world = picks.world(day: day) { pages.append(announcedPage(world, isWorld: true)) }
        pages += picks.groupPicks(day: day).map { announcedPage($0, isWorld: false) }
        return pages
    }

    /// 日付をタップ:NavigationStack に1段だけ push する。1枚目が世界の一枚、続けてその日のグループの一枚。
    /// (写真を見るビューアそのものは、そのままページの中身として使う。MONDO / GROUP のタイルは、これまでどおり重ねて出すビューア)
    private func openCalendarDay(_ day: String) {
        guard !calendarDayPages(day).isEmpty else { return }
        calendarPath = [day]
    }

    // MARK: - 通報・ブロック

    @ViewBuilder
    private var reportLayer: some View {
        if let entry = reportEntry {
            MondoReportSheet(
                entry: entry,
                haptics: haptics,
                onReport: {
                    await MondoService.shared.report(entry)
                    await loader.load(now: now, blocked: MondoService.blockedMondoIDs(blockedUsers), force: true)
                },
                onBlock: {
                    await MondoService.shared.block(entry, modelContext: modelContext)
                },
                onWithdraw: {
                    await MondoService.shared.withdraw([entry.id])
                    MondoLocalStore.hide(entry.id)
                    await loader.load(now: now, blocked: MondoService.blockedMondoIDs(blockedUsers), force: true)
                },
                onClose: { reportEntry = nil }
            )
            .zIndex(7)
        }
    }
}

// MARK: - 飛んでいく写真

/// 撮った写真(小さな紙のカード)が、画面の中央から右上のアバターへ飛んでいく(1.25秒、少し回りながら縮む)
private struct ShotFlightCard: View {
    let progress: CGFloat
    let size: CGSize
    let topInset: CGFloat

    var body: some View {
        let start = CGPoint(x: size.width / 2, y: size.height / 2)
        let end = CGPoint(x: size.width - 38, y: topInset + 30)
        let p = progress
        // 少し弧を描く
        let x = start.x + (end.x - start.x) * p - 40 * sin(.pi * p)
        let y = start.y + (end.y - start.y) * p
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(ChicColor.instax)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(ChicColor.ink)
                .padding(.init(top: 8, leading: 8, bottom: 26, trailing: 8))
        }
        .frame(width: 130, height: 160)
        .shadow(color: ChicColor.instaxShadow.opacity(0.35), radius: 12, y: 6)
        .scaleEffect(1 - 0.84 * p)
        .rotationEffect(.degrees(Double(p) * 24))
        .opacity(p > 0.92 ? Double((1 - p) / 0.08) : 1)
        .position(x: x, y: y)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}


// MARK: - カレンダーの日の詳細(NavigationStack に1段 push)

/// 標準の戻るボタン(‹ カレンダー)・インラインのタイトル(10.25)・右上の「01 / 02」。
/// 戻るスワイプ(画面の左はし)はそのまま使える。タブバーは隠す。
private struct CalendarDayPage: View {
    let day: String
    let pages: [ViewerPage]
    let haptics: ExposureHaptics
    let onClose: () -> Void

    @State private var counter = ""

    var body: some View {
        VerticalPhotoViewer(pages: pages, startIndex: 0, haptics: haptics, onClose: onClose)
            .navigationChrome { page in
                guard let index = pages.firstIndex(where: { $0.id == page.id }) else { return }
                counter = String(format: "%02d / %02d", index + 1, pages.count)
            }
            .background(V5.bg.ignoresSafeArea())
            .navigationTitle(V5.monthDay(fromDayKey: day))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            // ビューアは暗いまま(タブの ink の色を引きつがない)
            .tint(Color(hex: "FFB277"))
            .environment(\.colorScheme, .dark)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text(counter)
                        .font(V5.mono(12))
                        .foregroundStyle(.white.opacity(0.85))
                        .contentTransition(.numericText())
                        .accessibilityLabel(counter.replacingOccurrences(of: "/", with: "枚目、全"))
                }
            }
    }
}
