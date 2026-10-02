import SwiftUI
import SwiftData

/// Homeタブのダッシュボード画面(2026/9 新デザイン仕様「① Home画面」に準拠)。
/// ヘッダー→ライブ活動通知バー→解禁カード→Daily Shotカード→グループ横スクロール→
/// 招待バナーの順に1本のScrollViewで縦に並べる。個々のグループの詳細(進捗リング・
/// メンバー・撮影/投票)はGroupHomeDetailViewが担う。撮影導線はタブバー中央のボタン
/// (MainTabView)と、Daily Shotカードの「撮る」ボタンの2箇所から同じCaptureRequestStore
/// 経由の導線に入る。
struct TodayShootingView: View {
    let groups: [LaterGroup]
    let streakCount: Int

    @Query private var profiles: [UserProfile]
    @Bindable private var groupSelection = GroupSelectionStore.shared
    @Bindable private var notificationManager = NotificationManager.shared
    /// MainTabViewが全タブを非表示のままマウントし続ける構成に変わったため、
    /// 自分のタブ(Home=0)が選択されていない間はポーリング(.task)が
    /// バックグラウンドで無駄にCloudKitへ問い合わせ続けないようにする。
    @Environment(\.selectedMainTabIndex) private var selectedMainTabIndex
    private static let homeTabIndex = 0
    /// 没入型v2のヘッダー・カウントダウン等は写真の壁の上に浮くすりガラス表現を使うが、
    /// 「透明度を下げる」設定が有効な端末では不透明なダーク塗りに切り替える。
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var memoryMatch: MemoryMatch?
    @State private var showingMemoryViewer = false
    @State private var showingCreateGroup = false
    @State private var showingNotifications = false
    @State private var showingInviteSheet = false
    @State private var showingGroupsOverview = false
    @State private var showingPersonalFromHome = false
    @State private var showingWorld = false

    private static let accent = Color.laterAccent
    private static let streakPurple = Color(hex: "B388FF")
    /// 「①Home画面」で指定された、通常グループの作成上限。
    private static var maxOtherGroupCount: Int { GroupMembershipPolicy.maxGroupsPerUser }

    /// GroupSwitcherHeaderで選択されたグループを優先し、未選択なら先頭のグループにする。
    /// (GroupHomeDetailViewを開くとそのグループのIDに更新されるため、Home画面の
    /// カウントダウンは「直近で見ていたグループ」を自然に反映する)
    private var selectedGroup: LaterGroup? {
        let ordered = groups.meFirstOrdered()
        if let selectedID = groupSelection.selectedGroupID,
           let match = ordered.first(where: { $0.id == selectedID }) {
            return match
        }
        return ordered.first
    }

    /// カウントダウンカードは「他メンバーと共有しているグループ」の状況を映す
    /// (MEには「全員達成」の概念が無いため)。参加中の共有グループが無ければnil。
    private var countdownGroup: LaterGroup? {
        if let selectedGroup, !selectedGroup.isPersonalSpace { return selectedGroup }
        return otherGroups.first
    }

    private var countdownState: GroupDailyState? {
        countdownGroup.map { GroupStatusPresenter.state(for: $0) }
    }

    /// 個人用スペース「ME」。オンボーディング完了後は常に1件存在する想定。
    private var personalSpaceGroup: LaterGroup? {
        groups.first(where: \.isPersonalSpace)
    }

    /// MEを除く、実際に他メンバーと共有しているグループ。
    private var otherGroups: [LaterGroup] {
        groups.filter { !$0.isPersonalSpace }
    }

    /// 「⑨はじめての起動・空の状態」を表示すべきかどうか。グループにも記録にも
    /// まだ何も無い新規ユーザー向けの判定(共有グループが無く、MEにも撮影が無い)。
    private var isFirstRun: Bool {
        otherGroups.isEmpty && (personalSpaceGroup?.photos.isEmpty ?? true)
    }

    /// 複数グループをまたぐ画面なので、単一ゾーンの即時フェッチではなく
    /// Private/Shared両DBの変更をまとめて取り込む広いリフレッシュにする。
    private func refreshAllGroups() async {
        let token = PerformanceSignpost.begin("Home.refreshAllGroups")
        print("[GroupSync] TodayShootingView.refresh開始")
        guard let cloudKitManager = CloudKitManager.current else {
            print("[GroupSync] TodayShootingView.refresh中断: cloudKitManagerが未確定")
            PerformanceSignpost.end("Home.refreshAllGroups", token, detail: "中断(cloudKitManager未確定)")
            return
        }
        await cloudKitManager.fetchSharedChangesNow()
        await cloudKitManager.fetchPrivateChangesNow()
        await cloudKitManager.resendOwnUnlockedPhotosIfNeeded()
        print("[GroupSync] TodayShootingView.refresh完了")
        PerformanceSignpost.end("Home.refreshAllGroups", token)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if isFirstRun {
                    // 没入型v2は写真の壁に重ねるすりガラスヘッダー(firstRunGlassHeader)を
                    // 自前で持つため、通常時のheaderはここでは出さない(二重表示防止)。
                    firstRunImmersiveHero
                } else {
                    header

                    if let liveActivityText {
                        liveActivityBar(liveActivityText)
                    }

                    countdownCard

                    if let personalSpaceGroup {
                        dailyShotCard(personalSpaceGroup)
                    }

                    groupsSection

                    if let memoryMatch {
                        MemorySurpriseCardView(match: memoryMatch) {
                            MemorySurpriseManager.markSeenToday()
                            showingMemoryViewer = true
                        }
                    }

                    inviteBanner
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.laterBackground.ignoresSafeArea())
        .refreshable {
            await refreshAllGroups()
        }
        .onAppear {
            checkForMemory()
            AppLaunchTiming.reportHomeDisplayedIfNeeded()
            PerformanceSignpost.event("Home.groupListDisplayed", detail: "groups.count=\(groups.count)")
        }
        .onChange(of: groupSelection.selectedGroupID) { _, _ in checkForMemory() }
        .task {
            while !Task.isCancelled {
                if selectedMainTabIndex == Self.homeTabIndex {
                    await refreshAllGroups()
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
        .fullScreenCover(isPresented: $showingMemoryViewer) {
            if let memoryMatch {
                MemorySurpriseViewerView(match: memoryMatch) {
                    showingMemoryViewer = false
                    self.memoryMatch = nil
                }
            }
        }
        .sheet(isPresented: $showingCreateGroup) {
            CircleCreateGroupView()
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsView()
        }
        .sheet(isPresented: $showingInviteSheet) {
            ShareSheet(activityItems: inviteShareItems)
        }
        .fullScreenCover(isPresented: $showingWorld) {
            // WorldLaterFeedView自身のヘッダーに閉じるXボタン(Environment(\.dismiss)経由)が
            // 既にあるため、ここでは重ねて追加のツールバー/Xボタンを用意しない
            // (以前は二重になっていた)。
            WorldLaterFeedView()
        }
        .navigationDestination(isPresented: $showingGroupsOverview) {
            GroupListView(groups: otherGroups) {
                showingCreateGroup = true
            }
        }
        .navigationDestination(isPresented: $showingPersonalFromHome) {
            PersonalTodayView(group: personalSpaceGroup)
        }
    }

    // MARK: - ① ヘッダー(ロゴ+ストリークバッジ+通知ベル)

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Self.accent)
                    .shadow(color: Self.accent.opacity(0.6), radius: 6)
                Text("Later")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.laterText)
            }

            Spacer()

            if !isFirstRun && streakCount > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("\(streakCount)")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Self.streakPurple))
            }

            homeWorldSwitcher

            Button {
                showingNotifications = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "bell.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                        )
                    if notificationManager.unreadCount > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().strokeBorder(Color.laterBackground, lineWidth: 1.5))
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    /// Home/World切替ピル。World画面と対になる導線で、Homeでは常にHomeがアクティブ
    /// 表示のまま、Worldをタップすると既存のfullScreenCover(showingWorld)を開く。
    private var homeWorldSwitcher: some View {
        HStack(spacing: 2) {
            Text("Home")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "04170B"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Self.accent))

            Button {
                showingWorld = true
            } label: {
                Text("World")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "7FA88E"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.laterCard)
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    // MARK: - ⑨はじめての起動・没入型v2(グループにも記録にもまだ何も無い新規ユーザー向け)
    //
    // 「Home初期画面（没入型v2）実装プロンプト」準拠。撮影の入口はタブバー中央の
    // CameraApertureButtonのみになる(「今日の1枚を撮る」ボタンは廃止)。ME個人スペースは
    // オンボーディング完了時点でLaterApp.ensurePersonalSpaceForCurrentUser()により
    // 必ず作成済みのため、MainTabView.captureAvailabilityがuserGroups.isEmptyで
    // ロックされることはない(撮影の入口が消える状態にはならない)。
    // 「N枚が現像中」の実数カウンター(仕様書§3)は、日次集計レコードの設計を要する
    // ためフェーズ2に見送っている(仕様書自身が許容している通り)。

    private var firstRunImmersiveHero: some View {
        VStack(spacing: 22) {
            firstRunHeroBlock
            firstRunCTASection
            firstRunGroupShelf
        }
    }

    /// 写真の壁(背景)+すりガラスのヘッダー+カウントダウンを1つの没入ブロックとして重ねる。
    ///
    /// 壁(HomeDevelopingWallView)は4列×118pt+すき間で実横幅が約504ptあり、画面幅(390pt前後)
    /// より広い。これをZStackの通常の子として置くと、SwiftUIは最大の子に合わせて親幅を
    /// 広げてしまい、本文全体が横にはみ出す(ヘッダー・本文の左右が画面から切れる不具合の
    /// 原因だった)。壁は`.background`側に置き、レイアウト幅を決めるのは
    /// `Color.clear.frame(maxWidth: .infinity)`だけにすることで、壁の実サイズが
    /// 上位のレイアウト幅に一切影響しないようにしている。
    private var firstRunHeroBlock: some View {
        Color.clear
            .frame(height: 500)
            .frame(maxWidth: .infinity)
            .background(alignment: .center) {
                HomeDevelopingWallView()
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .top) {
                VStack(spacing: 18) {
                    firstRunGlassHeader
                    Spacer(minLength: 8)
                    firstRunCountdownHero
                    Spacer(minLength: 8)
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .clipped()
            .padding(.horizontal, -20)
    }

    private var glassMaterial: AnyShapeStyle {
        reduceTransparency ? AnyShapeStyle(Color(hex: "10140F").opacity(0.94)) : AnyShapeStyle(.ultraThinMaterial)
    }

    private var firstRunGlassHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Self.accent)
                    .shadow(color: Self.accent.opacity(0.6), radius: 6)
                Text("Later")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            firstRunHomeWorldGlassSwitcher

            Button {
                showingNotifications = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(glassMaterial)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                        .overlay(
                            Image(systemName: "bell.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                        )
                    if notificationManager.unreadCount > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().strokeBorder(Color.laterBackground, lineWidth: 1.5))
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    /// Home/World切替ピル(すりガラス版)。アクティブのHomeは白〜クリームのカプセル、
    /// 非アクティブのWorldは白60%の文字にする(仕様書§5)。
    private var firstRunHomeWorldGlassSwitcher: some View {
        HStack(spacing: 2) {
            Text("Home")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "04170B"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        LinearGradient(colors: [.white, Color(hex: "F4EFE0")], startPoint: .top, endPoint: .bottom)
                    )
                )

            Button {
                showingWorld = true
            } label: {
                Text("World")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(3)
        .background(Capsule().fill(glassMaterial))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
    }

    /// 翌朝9:00までの残り時間。解禁時刻の計算はWorldLaterService.nextGlobalUnlockDate(_:)を
    /// 再利用し(World画面のカウントダウンと必ず同じ値になるようにするため)、別途計算しない。
    private var firstRunCountdownHero: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let target = WorldLaterService.nextGlobalUnlockDate(from: now)
            let remaining = max(0, Int(target.timeIntervalSince(now)))
            let hours = remaining / 3600
            let minutes = (remaining % 3600) / 60
            let seconds = remaining % 60
            let isBeforeNineAM = Calendar.current.component(.hour, from: now) < 9
            let dayLabel = isBeforeNineAM ? "今日" : "明日"

            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Self.accent)
                        .frame(width: 6, height: 6)
                        .shadow(color: Self.accent.opacity(0.8), radius: 4)
                    Text("NEXT DEVELOP · \(dayLabel) 09:00")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(1.1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(
                    Capsule().strokeBorder(Self.accent.opacity(0.5), lineWidth: 1)
                )

                HStack(spacing: 2) {
                    Text(String(format: "%02d", hours))
                    Text(":").foregroundStyle(Self.accent)
                    Text(String(format: "%02d", minutes))
                    Text(":").foregroundStyle(Self.accent)
                    Text(String(format: "%02d", seconds))
                }
                .font(.system(size: 52, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("次の現像まで\(hours)時間\(minutes)分")
        }
    }

    private var firstRunCTASection: some View {
        VStack(alignment: .leading, spacing: 14) {
            (
                Text("はじめての\n")
                    .foregroundStyle(Color.laterText)
                + Text("Daily Shot")
                    .foregroundStyle(Color(hex: "4ADE6C"))
                    .italic()
            )
            .font(.system(size: 25, weight: .bold))

            Text("毎日1枚、今日という日を残そう。撮った写真は翌朝9:00、みんなと同時に現像されます。")
                .font(.system(size: 13))
                .foregroundStyle(Color.laterText.opacity(0.62))
                .lineSpacing(3)

            Button {
                showingCreateGroup = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("グループを作る")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(Color(hex: "04170B"))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "6FF293"), Color(hex: "3FC767")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                                .blendMode(.overlay)
                        )
                )
                .shadow(color: Color(hex: "3FC767").opacity(0.35), radius: 14, x: 0, y: 8)
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    /// グループ棚(0/6)。1マス目は常に「新規作成」(緑破線+プラス)、残り5マスは
    /// 右へ行くほど枠・背景を薄くした空きマスにする(仕様書§4)。
    private var firstRunGroupShelf: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("グループ")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.laterText)
                Spacer()
                Text("0 / \(Self.maxOtherGroupCount)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.laterTextMuted)
            }

            HStack(spacing: 10) {
                Button {
                    showingCreateGroup = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                        Text("新規作成")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(Self.accent)
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .foregroundStyle(Self.accent.opacity(0.6))
                    )
                }
                .buttonStyle(.plain)

                ForEach(1..<Self.maxOtherGroupCount, id: \.self) { index in
                    let fade: Double = Double(index)
                    let fillOpacity: Double = max(0.015, 0.055 - fade * 0.008)
                    let strokeOpacity: Double = max(0.03, 0.14 - fade * 0.02)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(fillOpacity))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(strokeOpacity), lineWidth: 1.2)
                        )
                        .frame(width: 50, height: 50)
                }
            }
        }
    }

    // MARK: - ② ライブ活動通知バー

    /// 直近の撮影者名+未撮影メンバー数から組み立てる、実データに基づく短文。
    /// 見せる材料が無い(参加グループが無い/誰もまだ撮っていない)場合はnilにしてバー自体を隠す。
    private var liveActivityText: String? {
        guard let group = countdownGroup else { return nil }
        let recentPhoto = group.currentCyclePhotos().sorted { $0.captureDate > $1.captureDate }.first
        guard let recentName = recentPhoto?.owner?.name, !recentName.isEmpty else { return nil }

        if case .shooting(_, let achievedCount, let memberCount, _, _) = GroupStatusPresenter.state(for: group) {
            let remaining = max(memberCount - achievedCount, 0)
            if remaining > 0 {
                return "\(recentName)が投稿しました・あと\(remaining)人が撮影中"
            }
        }
        return "\(recentName)が投稿しました"
    }

    private func liveActivityBar(_ text: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Self.accent)
                .frame(width: 8, height: 8)
                .shadow(color: Self.accent.opacity(0.8), radius: 5)

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.laterTextMuted)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.laterCard))
        .overlay(Capsule().strokeBorder(Color.laterBorder, lineWidth: 1))
    }

    // MARK: - ③ 解禁カウントダウンカード

    private var countdownCard: some View {
        VStack(spacing: 14) {
            Text("解禁まで")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.laterTextMuted)

            if let countdownState {
                let content = CountdownPresentation.content(for: countdownState)
                Text(content.label)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.laterTextMuted)

                if let blocks = content.blocks {
                    HStack(spacing: 10) {
                        countdownBlock(value: blocks.primary, label: "達成")
                        Text(":").font(.system(size: 22, weight: .bold)).foregroundStyle(Self.accent.opacity(0.6))
                        countdownBlock(value: blocks.secondary, label: "人数")
                        Text(":").font(.system(size: 22, weight: .bold)).foregroundStyle(Self.accent.opacity(0.6))
                        countdownBlock(value: blocks.tertiary, label: "枚数")
                    }

                    ProgressView(value: progressFraction(for: countdownState))
                        .tint(Self.accent)
                        .padding(.top, 4)
                }
            } else {
                Text("グループに参加すると、みんなの進み具合が見られます")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.laterTextMuted)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.laterCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.laterBorder, lineWidth: 1.5)
        )
    }

    private func progressFraction(for state: GroupDailyState) -> Double {
        switch state {
        case .shooting(_, let achievedCount, let memberCount, _, _):
            return memberCount > 0 ? Double(achievedCount) / Double(memberCount) : 0
        case .unlocked:
            return 1
        }
    }

    private func countdownBlock(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("Courier New", size: 26).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Self.accent)
                .shadow(color: Self.accent.opacity(0.5), radius: 4)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.laterTextMuted)
        }
        .frame(width: 64)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Self.accent.opacity(0.55), lineWidth: 1.5)
        )
    }

    // MARK: - ④ 今日のDaily Shotカード(ME)

    private func dailyShotCard(_ group: LaterGroup) -> some View {
        NavigationLink {
            GroupHomeDetailView(group: group)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Self.accent.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: "person.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Self.accent)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("今日のDaily Shot")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.laterText)
                    Text(dailyShotStatusText(for: group))
                        .font(.system(size: 13))
                        .foregroundStyle(Color.laterTextMuted)
                }

                Spacer()

                Button {
                    HapticsManager.shutterClick()
                    CaptureRequestStore.shared.pendingRequestID = UUID()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("撮る")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.laterBackground)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Self.accent))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.laterCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.laterBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func dailyShotStatusText(for group: LaterGroup) -> String {
        switch GroupStatusPresenter.state(for: group) {
        case .shooting(let hasStarted, _, _, let groupTotal, _):
            return hasStarted ? "\(groupTotal)枚 撮影済み" : "まだ撮影していません"
        case .unlocked:
            return "解禁中"
        }
    }

    // MARK: - ⑤ グループセクション(横スクロール)

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("グループ（\(otherGroups.count)/\(Self.maxOtherGroupCount)）")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.laterText)

                Spacer()

                Button("すべて見る") {
                    showingGroupsOverview = true
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Self.accent)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    meChip

                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 52)

                    ForEach(otherGroups, id: \.id) { group in
                        NavigationLink {
                            GroupHomeDetailView(group: group)
                        } label: {
                            groupChip(group)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            groupSelection.selectedGroupID = group.id
                        })
                    }

                    newGroupChip
                }
            }
        }
    }

    /// グループ横スクロール先頭の「ME」チップ。個人ワークスペースへの入口で、
    /// 他のグループチップとは明確に区別できるアクセント色の塗りつぶしにする。
    /// 「グループ(N/10)」のカウントには含めない(グループではなく自分自身の枠のため)。
    private var meChip: some View {
        Button {
            showingPersonalFromHome = true
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "04170B").opacity(0.16))
                        .frame(width: 32, height: 32)
                    Image(systemName: "person.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "04170B"))
                }

                Text("ME")
                    .font(.system(size: 11.5, weight: .heavy))
                    .foregroundStyle(Color(hex: "04170B"))

                Text("\(meTotalPhotoCount)枚 撮影済み")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color(hex: "04170B").opacity(0.7))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: 80)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Self.accent))
        }
        .buttonStyle(.plain)
    }

    private var meTotalPhotoCount: Int {
        personalSpaceGroup?.photos.count ?? 0
    }

    private func groupChip(_ group: LaterGroup) -> some View {
        VStack(spacing: 10) {
            GroupIconView(
                iconImageData: group.iconImageData,
                groupName: group.name,
                size: 52,
                ringColor: group.accentColorHex.map { Color(hex: $0) }
            )
            .overlay(Circle().strokeBorder(group.accentColorHex == nil ? Color.laterBorder : Color.clear, lineWidth: 1.5))

            VStack(spacing: 3) {
                Text(group.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.laterText)
                    .lineLimit(1)
                Text(groupChipStatusText(group))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.laterTextMuted)
                    .lineLimit(1)
            }
        }
        .frame(width: 88)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.laterCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.laterBorder, lineWidth: 1)
        )
    }

    private func groupChipStatusText(_ group: LaterGroup) -> String {
        switch GroupStatusPresenter.state(for: group) {
        case .shooting(let hasStarted, let achievedCount, let memberCount, _, _):
            return hasStarted ? "\(achievedCount)/\(memberCount) READY" : "未スタート"
        case .unlocked:
            return "解禁中"
        }
    }

    private var newGroupChip: some View {
        let isAtLimit = otherGroups.count >= Self.maxOtherGroupCount
        return Button {
            guard !isAtLimit else { return }
            HapticsManager.swipeFeedback()
            showingCreateGroup = true
        } label: {
            VStack(spacing: 10) {
                Image(systemName: isAtLimit ? "lock.fill" : "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isAtLimit ? Color.laterTextMuted : Self.accent)
                    .frame(width: 52, height: 52)

                Text(isAtLimit ? "上限です" : "新規作成")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.laterTextMuted)
            }
            .frame(width: 88)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                    .foregroundStyle(Color.laterTextMuted.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
        .disabled(isAtLimit)
    }

    // MARK: - ⑥ 招待バナー

    private var inviteBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "gift.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Self.accent)

            Text("友達を招待してボーナス解禁")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.laterText)
                .lineLimit(2)

            Spacer(minLength: 8)

            Button("招待") {
                showingInviteSheet = true
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Self.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .overlay(Capsule().strokeBorder(Self.accent, lineWidth: 1.2))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.laterCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.laterBorder, lineWidth: 1)
        )
    }

    private var inviteShareItems: [Any] {
        ["Laterで、今日の一枚をみんなで撮っています。あなたも一緒にどうですか？\nhttps://13379tatsukikitagawa-droid.github.io/APP-Later2/"]
    }

    // MARK: - 節目の記憶

    private func checkForMemory() {
        memoryMatch = MemorySurpriseManager.findMemory(in: groups, preferredGroupID: groupSelection.selectedGroupID)
    }
}

