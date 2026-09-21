import SwiftUI
import SwiftData

/// Homeタブの常設コンテンツ。ヘッダー(ブランドロゴ+日付+カウントダウン)→大型のMEカード→
/// (グループ未参加ならグループ作成ボタン、参加済みならグループ一覧)、の順に1本の
/// ScrollViewで縦に並べる。個々のグループの詳細(進捗リング・メンバー・撮影/投票)は
/// GroupHomeDetailViewが担う。撮影導線はタブバー中央のボタン(MainTabView)に一本化。
struct TodayShootingView: View {
    let groups: [LaterGroup]

    @Query private var profiles: [UserProfile]
    @Bindable private var groupSelection = GroupSelectionStore.shared
    /// MainTabViewが全タブを非表示のままマウントし続ける構成に変わったため、
    /// 自分のタブ(Home=0)が選択されていない間はポーリング(.task)が
    /// バックグラウンドで無駄にCloudKitへ問い合わせ続けないようにする。
    @Environment(\.selectedMainTabIndex) private var selectedMainTabIndex
    private static let homeTabIndex = 0

    @State private var memoryMatch: MemoryMatch?
    @State private var showingMemoryViewer = false
    @State private var showingDevelopingProgress = false
    @State private var showingCreateGroup = false

    private static let neonGreen = Color.brandGreen

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

    private var selectedState: GroupDailyState? {
        selectedGroup.map { GroupStatusPresenter.state(for: $0) }
    }

    /// 個人用スペース「ME」。オンボーディング完了後は常に1件存在する想定。
    private var personalSpaceGroup: LaterGroup? {
        groups.first(where: \.isPersonalSpace)
    }

    /// MEを除く、実際に他メンバーと共有しているグループ。
    private var otherGroups: [LaterGroup] {
        groups.filter { !$0.isPersonalSpace }
    }

    /// 自分が今日撮影した写真(現像中画面に渡す用。選択中グループ基準)
    private var myTodaysPhotos: [LaterPhoto] {
        guard let group = selectedGroup, let myID = UserProfile.current(from: profiles)?.id else { return [] }
        return group.currentCyclePhotos()
            .filter { $0.owner?.id == myID }
            .sorted { $0.captureDate < $1.captureDate }
    }

    /// まだ解禁(isUnlocked)されていない、現像中の写真の枚数。現像中ボタンのバッジ・
    /// 発光アニメーションの有無に使う。
    private var developingPhotoCount: Int {
        myTodaysPhotos.filter { !$0.isUnlocked }.count
    }

    /// 複数グループをまたぐ画面なので、単一ゾーンの即時フェッチではなく
    /// Private/Shared両DBの変更をまとめて取り込む広いリフレッシュにする。
    private func refreshAllGroups() async {
        // Homeタブ表示中は3秒おきに呼ばれ続けるループのため、ここでの所要時間が
        // データ量(写真件数)と共に伸びていないかが調査項目1・3の焦点になる。
        let token = PerformanceSignpost.begin("Home.refreshAllGroups")
        print("[GroupSync] TodayShootingView.refresh開始")
        guard let cloudKitManager = CloudKitManager.current else {
            print("[GroupSync] TodayShootingView.refresh中断: cloudKitManagerが未確定")
            PerformanceSignpost.end("Home.refreshAllGroups", token, detail: "中断(cloudKitManager未確定)")
            return
        }
        await cloudKitManager.fetchSharedChangesNow()
        await cloudKitManager.fetchPrivateChangesNow()
        // 画像再送の保険(resendOwnUnlockedPhotosIfNeeded)を、アプリのフォアグラウンド
        // 復帰時だけでなくHomeタブのこのポーリングからも呼べるようにする(60秒の
        // 最低間隔はCloudKitManager側で管理しているため、3秒ごとに呼んでも実害はない)。
        await cloudKitManager.resendOwnUnlockedPhotosIfNeeded()
        print("[GroupSync] TodayShootingView.refresh完了")
        PerformanceSignpost.end("Home.refreshAllGroups", token)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                BrandHeaderRow(developingPhotoCount: developingPhotoCount) {
                    showingDevelopingProgress = true
                }

                if groups.isEmpty {
                    noGroupGuide
                        .padding(.top, 44)
                } else {
                    AdaptiveCountdownBadge(state: selectedState)
                        .padding(.top, 6)

                    if let personalSpaceGroup {
                        meCard(personalSpaceGroup)
                    }

                    if let memoryMatch {
                        MemorySurpriseCardView(match: memoryMatch) {
                            MemorySurpriseManager.markSeenToday()
                            showingMemoryViewer = true
                        }
                    }

                    if otherGroups.isEmpty {
                        createGroupCard
                    } else {
                        groupListContent
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 90)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .refreshable {
            await refreshAllGroups()
        }
        .onAppear {
            checkForMemory()
            // 調査項目1: 起動からHome画面表示までの時間(初回のみ報告)。
            AppLaunchTiming.reportHomeDisplayedIfNeeded()
            PerformanceSignpost.event("Home.groupListDisplayed", detail: "groups.count=\(groups.count)")
        }
        .onChange(of: groupSelection.selectedGroupID) { _, _ in checkForMemory() }
        .task {
            // このHomeタブのトップ画面(Todayタブ)は、各グループカードの「◯枚 撮影済み」を
            // ローカルのSwiftDataから計算しているだけで、以前はプルリフレッシュか
            // プッシュ通知の到達を待たない限りCloudKitの最新状態を取りに行かなかった。
            // そのため、複数端末で同時に撮影すると、この画面を開いたままの端末だけ
            // 相手の撮影分が反映されず「片方しか増えない」ように見える不具合があった
            // (GroupHomeDetailView/GroupDetailView.taskと同じ方針で、開いている間は
            // 定期的に取りに行く)。
            while !Task.isCancelled {
                // MainTabViewは非表示中のタブも破棄せず裏で保持し続ける構成のため、
                // Homeタブが選択されていない間はネットワーク問い合わせをスキップする
                // (ループ自体は回し続け、タブへ戻った瞬間また取得を再開する)。
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
        .sheet(isPresented: $showingDevelopingProgress) {
            DevelopingProgressView(photos: myTodaysPhotos)
        }
    }

    // MARK: - MEカード(大型・主役級。ダークグラデーション背景+緑の縁取り)

    private func meCard(_ group: LaterGroup) -> some View {
        NavigationLink {
            GroupHomeDetailView(group: group)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Self.neonGreen.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: "person.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Self.neonGreen)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(group.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text(meStatusText(for: group))
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "1A1A1A"), Color(hex: "1A1A1A").opacity(0.92)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Self.neonGreen.opacity(0.4), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func meStatusText(for group: LaterGroup) -> String {
        switch GroupStatusPresenter.state(for: group) {
        case .shooting(_, _, _, let groupTotal, let groupTarget):
            return "\(groupTotal)/\(groupTarget)枚 撮影済み"
        case .unlocked:
            return "解禁中"
        }
    }

    // MARK: - グループ未参加時の「グループを作成する」ボタン(MEカードのすぐ下)

    private var createGroupCard: some View {
        Button {
            HapticsManager.swipeFeedback()
            showingCreateGroup = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("グループを作成する")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Self.neonGreen)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Self.neonGreen.opacity(0.5), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - グループ一覧(MEを除く、実際に参加しているグループが1件以上ある場合のみ)

    private var groupListContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("グループ")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            VStack(spacing: 12) {
                ForEach(otherGroups, id: \.id) { group in
                    NavigationLink {
                        GroupHomeDetailView(group: group)
                    } label: {
                        GroupCardRow(group: group, isSelected: group.id == selectedGroup?.id)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 未参加時の案内(groups自体が1件も無い、ME未作成の稀なケース用フォールバック)

    /// コルクボードにピン留めされたポラロイド風の空状態カード(PolaroidPromptCard)。
    /// 中身のテキスト・タップ時の挙動(showingCreateGroup = true)は以前のガイドと同じで、
    /// 見た目だけをコルクボードのデザインに合わせて差し替えている。
    private var noGroupGuide: some View {
        PolaroidPromptCard(
            heading: "誰かと一緒に、\n始めよう",
            caption: "グループに入ると、みんなで撮った記録も残せます",
            ctaTitle: "＋ グループを作る"
        ) {
            showingCreateGroup = true
        }
    }

    // MARK: - 節目の記憶

    private func checkForMemory() {
        memoryMatch = MemorySurpriseManager.findMemory(in: groups, preferredGroupID: groupSelection.selectedGroupID)
    }
}

// MARK: - 現像中ボタンのタップフィードバック(押している間だけきゅっと縮む)

struct DevelopingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - グループカード

private struct GroupCardRow: View {
    let group: LaterGroup
    let isSelected: Bool

    private var state: GroupDailyState {
        GroupStatusPresenter.state(for: group)
    }

    private var isNotStarted: Bool {
        if case .shooting(let hasStarted, _, _, _, _) = state { return !hasStarted }
        return false
    }

    private var isPersonalSpace: Bool { group.isPersonalSpace }

    private var borderColor: Color? {
        if isPersonalSpace { return Color.brandGreen.opacity(0.4) }
        guard isSelected else { return nil }
        return Color.brandGreen
    }

    private var statusText: String {
        switch state {
        case .shooting(let hasStarted, let achievedCount, let memberCount, let groupTotal, let groupTarget):
            if isPersonalSpace {
                return hasStarted ? "\(groupTotal)枚 撮影済み" : "まだ撮影していません"
            }
            if !hasStarted { return "未スタート" }
            return "\(achievedCount)/\(memberCount)人 撮影済み・\(groupTotal)/\(groupTarget)枚"
        case .unlocked:
            return "解禁中"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            if isPersonalSpace {
                ZStack {
                    Circle()
                        .fill(Color.brandGreen.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "person.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.brandGreen)
                }
            } else {
                GroupIconView(iconImageData: group.iconImageData, groupName: group.name, size: 40)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text(statusText)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(borderColor ?? Color.white.opacity(0.08), lineWidth: borderColor != nil ? 2 : 1)
        )
        .opacity(isNotStarted ? 0.55 : 1.0)
    }
}
