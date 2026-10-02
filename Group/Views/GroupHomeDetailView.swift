import SwiftUI
import SwiftData

/// Home画面のグループカードをタップした先の、グループ単体の詳細画面。
/// 状態(撮影中/解禁中/終了)によって中身が丸ごと切り替わる。
/// 撮影の実処理は複製せず、既存の仕組み(CaptureRequestStore経由のTodayView)に
/// そのまま委ねる。投票フェーズは撤去済みのため、解禁後はグループ全員の写真を
/// そのまま一覧表示する(GroupVotingViewは経由しない)。
struct GroupHomeDetailView: View {
    let group: LaterGroup

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var blockedUsers: [BlockedUser]
    @Bindable private var groupSelection = GroupSelectionStore.shared
    /// この画面はHomeタブのNavigationStackからのみpushされる(TodayShootingView経由)。
    /// MainTabViewは非表示中のタブも破棄せず裏で保持し続ける構成のため、他のタブへ
    /// 切り替えてもこのプッシュ先はそのままバックグラウンドに残り、.task(id:)の
    /// 3秒ループが動き続けてしまう。TodayShootingView.swiftと同じ方針で、
    /// Homeタブが選択されていない間はネットワーク問い合わせだけをスキップする。
    @Environment(\.selectedMainTabIndex) private var selectedMainTabIndex
    private static let homeTabIndex = 0

    @State private var showingGroupInfo = false
    @State private var showingTargetSheet = false
    @State private var pendingTargetCount = 1
    @State private var showGoalReachedAnimation = false
    @State private var reportTargetPhoto: LaterPhoto?
    @State private var selectedVideoForPlayback: LaterVideo?
    @State private var selectedPhotoForViewing: LaterPhoto?

    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }

    private var myID: UUID? {
        currentUser?.id
    }

    private var state: GroupDailyState {
        GroupStatusPresenter.state(for: group)
    }

    private var myTodayCount: Int {
        guard let myID else { return 0 }
        return group.currentCyclePhotos().filter { $0.owner?.id == myID }.count
    }

    /// 画面表示時に、このグループのゾーンを直接フェッチして最新のメンバー構成/写真を
    /// 取り込む。GroupDetailView.refreshMembers()と同じ仕組み(CloudKitManager.
    /// fetchAndApplyZoneImmediately)で、CKSyncEngineの自律的な同期を待たずに反映する。
    private func refreshGroupData() async {
        print("[GroupSync] GroupHomeDetailView.refresh開始: group=\(group.name)")
        guard let cloudKitManager = CloudKitManager.current, let zoneID = group.cachedZoneID else {
            print("[GroupSync] GroupHomeDetailView.refresh中断: cloudKitManagerまたはzoneIDが未確定")
            return
        }
        await cloudKitManager.fetchAndApplyZoneImmediately(zoneID: zoneID)
        await ensureOwnMembershipIsSynced(cloudKitManager: cloudKitManager)
        // 画像再送の保険(resendOwnUnlockedPhotosIfNeeded)を、アプリのフォアグラウンド
        // 復帰時だけでなくこの画面ポーリングからも呼べるようにし、撮影者本人がアプリを
        // 開き直さなくても、この画面が開いている間に自然と再送されるようにする。
        // CloudKitManager側に60秒の最低間隔があるため、3秒ごとに呼んでも実害はない。
        await cloudKitManager.resendOwnUnlockedPhotosIfNeeded()
        print("[GroupSync] GroupHomeDetailView.refresh完了: group=\(group.name)")
    }

    /// GroupDetailView.ensureOwnMembershipIsSyncedと同じ自己修復処理。古いビルドで
    /// 作成されたグループでは、ホスト自身のプロフィールレコードの保存だけが検知されずに
    /// 欠落したまま残っているケースがあったため、画面を開く/更新するたびに
    /// 自分の分だけは確実に共有ゾーンへ存在するよう再送する。
    private func ensureOwnMembershipIsSynced(cloudKitManager: CloudKitManager) async {
        guard let currentUser = UserProfile.current(from: profiles) else { return }
        if !group.isMember(currentUser) {
            _ = group.addMember(currentUser)
        }
        let sharingService = GroupSharingService(container: cloudKitManager.container, modelContext: modelContext, cloudKitManager: cloudKitManager)
        await sharingService.uploadOwnProfile(currentUser, to: group)
    }

    /// MEのみが対象。personalTargetLastSetDateが「今日」でなければ、その日初めて
    /// このME画面を開いたとみなして目標設定シートを表示する。確定するまでは
    /// 日付が更新されないため、シートを閉じるだけ(未確定)なら次に開いた時も再度表示される。
    private func checkTargetSheetIfNeeded() async {
        guard group.isPersonalSpace else { return }
        if let lastSet = group.personalTargetLastSetDate, Calendar.current.isDateInToday(lastSet) {
            return
        }
        // Tomorrow +1: 前日、自分のWorld Later投稿が誰かに選ばれていれば、その分だけ
        // 今日の目標のデフォルト提示値を底上げする(選んだのが誰かは一切問い合わせない)。
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let myWorldPosts = (try? modelContext.fetch(FetchDescriptor<WorldPost>(predicate: #Predicate { $0.isOwnPost }))) ?? []
        let recordNames = myWorldPosts.compactMap(\.ckRecordName)
        let bonus = await WorldLaterService.fetchSelectionCount(for: recordNames, on: yesterday, calendar: calendar)

        pendingTargetCount = group.personalDailyTargetCount + bonus
        showingTargetSheet = true
    }

    private func confirmDailyTarget(_ count: Int) {
        group.personalDailyTargetCount = count
        group.personalTargetLastSetDate = Date()
        try? modelContext.save()
        if let cloudKitManager = CloudKitManager.current {
            cloudKitManager.markForUpload(group: group)
            Task { await cloudKitManager.sendPendingChangesNow() }
        }
    }

    /// 撮影中(.shooting)のgroupTotal(現在の撮影数)がgroupTarget(目標枚数、MEなら
    /// personalDailyTargetCount、共有グループならGroupUnlockPolicy.dailyTargetPhotoCount)
    /// 未満から到達済みへ切り替わった「その瞬間」だけ、達成アニメーションを再生する。
    /// 画面を開いた時点で既に達成済みだった場合はoldとnewが同じ状態のままなので
    /// (.onChangeは初回描画では発火しない)、再演出はしない。
    private func checkGoalJustReached(old: GroupDailyState, new: GroupDailyState) {
        guard case .shooting(_, _, _, let oldTotal, let oldTarget) = old,
              case .shooting(_, _, _, let newTotal, let newTarget) = new else { return }
        let wasAchieved = oldTarget > 0 && oldTotal >= oldTarget
        let isAchieved = newTarget > 0 && newTotal >= newTarget
        guard !wasAchieved, isAchieved else { return }
        HapticsManager.unlockSuccess()
        showGoalReachedAnimation = true
        NotificationCenter.default.post(name: .neonFramePulseRequested, object: nil)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 0) {
                        progressCard
                            .padding(.top, 20)
                            .padding(.horizontal, 20)

                        pastUnlocksSection
                            .padding(.top, 32)
                    }
                }
                .refreshable {
                    await refreshGroupData()
                }
            }
            .background(Color.laterBackground.ignoresSafeArea())

            if showGoalReachedAnimation {
                GoalReachedAnimationView {
                    showGoalReachedAnimation = false
                }
                .zIndex(10)
            }
        }
        .navigationBarHidden(true)
        .enableInteractivePopGesture()
        .onAppear {
            // 撮影ボタンは既存のCaptureRequestStore経由(TodayView.currentGroup基準)を
            // そのまま使うため、この画面を開いた時点で「選択中グループ」をこのグループに
            // 合わせておく。これをしないと、別のグループが選択中のまま撮影してしまう。
            groupSelection.selectedGroupID = group.id
            Task { await checkTargetSheetIfNeeded() }
        }
        .onChange(of: state) { oldValue, newValue in
            checkGoalJustReached(old: oldValue, new: newValue)
        }
        .task(id: group.id) {
            // 招待リンクを送った後、この画面を開いたまま新メンバーの参加を待つケースを
            // 想定し、開いている間はプッシュ通知の到達を待たず定期的に取りに行く。
            // これによりメンバー一覧だけでなく、そこから動的に算出される目標枚数
            // (GroupUnlockPolicy.dailyTargetPhotoCount)もリアルタイムに追従する。
            while !Task.isCancelled {
                if selectedMainTabIndex == Self.homeTabIndex {
                    await refreshGroupData()
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
        .sheet(isPresented: $showingGroupInfo) {
            NavigationStack {
                // 脱退成功時は、このsheet(GroupDetailView自身)のdismissに加えて
                // GroupHomeDetailView自身もdismissし、脱退後に手動で戻らなくても
                // そのままHomeのグループ一覧まで戻れるようにする。
                GroupDetailView(group: group, onLeaveSuccess: { dismiss() })
            }
        }
        .sheet(isPresented: $showingTargetSheet) {
            MeDailyTargetSheet(initialValue: pendingTargetCount) { count in
                confirmDailyTarget(count)
            }
        }
        .sheet(item: $selectedVideoForPlayback) { video in
            VideoDetailPlayerView(video: video)
        }
        .sheet(item: $reportTargetPhoto) { photo in
            ReportSheet(targetType: .circlePhoto, targetID: photo.ckRecordName ?? photo.id.uuidString)
        }
        .sheet(item: $selectedPhotoForViewing) { photo in
            photoViewerSheet(photo)
        }
    }

    /// グリッドをタップした写真の全画面ビューア。撮影者名+長押しで報告できる。
    private func photoViewerSheet(_ photo: LaterPhoto) -> some View {
        ZStack {
            Color.laterBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                ChekiPhotoFrame(photo: photo)
                    .frame(maxWidth: 280)
                    .contextMenu {
                        if photo.owner?.id != currentUser?.id {
                            Button {
                                selectedPhotoForViewing = nil
                                reportTargetPhoto = photo
                            } label: {
                                Label("報告する", systemImage: "flag")
                            }
                        }
                    }

                HStack(spacing: 6) {
                    photoAuthorAvatar(photo.owner)
                    Text(photo.owner?.name ?? photo.authorNameCache ?? "不明")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.laterTextMuted)
                }
            }
        }
    }

    /// 撮影者アバター(小さな丸アイコン)。ownerがまだローカルに解決できていない場合は
    /// シルエットで代替する。
    private func photoAuthorAvatar(_ owner: UserProfile?) -> some View {
        Group {
            if let data = owner?.profileImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Circle()
                    .fill(Self.accent.opacity(0.2))
                    .overlay(
                        Text((owner?.name ?? "?").prefix(1))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Self.accent)
                    )
            }
        }
        .frame(width: 22, height: 22)
        .clipShape(Circle())
    }

    // MARK: - ヘッダー(戻る+グループ名/メンバー数+メンバー一覧ボタン)

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.laterText)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.laterCard))
            }

            Spacer()

            VStack(spacing: 2) {
                Text(group.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.laterText)
                    .lineLimit(1)
                Text(group.isPersonalSpace ? "個人スペース" : "固定メンバー\(group.members.count)人・匿名で公開")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.laterTextMuted)
            }

            Spacer()

            Button(action: { showingGroupInfo = true }) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.laterText)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.laterCard))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - ②進捗カード(撮影の進み具合。状態(撮影中/解禁中)で文言だけ切り替える)

    private static let accent = Color.laterAccent

    private var progressCard: some View {
        VStack(spacing: 20) {
            Text("撮影の進み具合")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.laterTextMuted)

            progressHeadline

            memberRow

            Text(progressFooterText)
                .font(.system(size: 12))
                .foregroundStyle(Color.laterTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            if case .shooting = state, !group.isPersonalSpace || myTodayCount < GroupUnlockPolicy.individualMaximumPhotoCount(for: group) {
                captureButton
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.laterCard))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.laterBorder, lineWidth: 1.5))
    }

    @ViewBuilder
    private var progressHeadline: some View {
        switch state {
        case .shooting(_, let achievedCount, let memberCount, _, _):
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(achievedCount)")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(Self.accent)
                Text("/ \(memberCount) READY")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.laterTextMuted)
            }
        case .unlocked:
            Text("解禁中！")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(Self.accent)
        }
    }

    private var progressFooterText: String {
        switch state {
        case .shooting(_, let achievedCount, let memberCount, _, _):
            if group.isPersonalSpace {
                return "目標枚数に到達すると、匿名で公開されます"
            }
            return achievedCount >= memberCount && memberCount > 0
                ? "まもなく匿名で一斉公開されます"
                : "全員が撮り終えると、匿名で一斉公開されます"
        case .unlocked:
            return "次の解禁まで見られます"
        }
    }

    private var memberRow: some View {
        HStack(spacing: 14) {
            ForEach(group.members, id: \.id) { member in
                memberAvatar(member)
            }
        }
    }

    /// 撮影済みはチェックマークバッジ、未撮影は透明度を落とすだけ(バッジ無し)。
    private func memberAvatar(_ member: UserProfile) -> some View {
        let achieved = memberAchievedToday(member)
        return ZStack(alignment: .bottomTrailing) {
            CachedPhotoImage(imageData: member.profileImageData, cacheKey: "avatar_\(member.id.uuidString)") { uiImage in
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ZStack {
                    Color.white.opacity(0.08)
                    Text(member.name.prefix(1))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(achieved ? Self.accent : Color.laterTextMuted)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(achieved ? Self.accent : Color.white.opacity(0.15), lineWidth: achieved ? 2 : 1))
            .opacity(achieved ? 1 : 0.4)

            if achieved {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Self.accent)
                    .background(Circle().fill(Color.laterCard).frame(width: 14, height: 14))
            }
        }
    }

    private func memberAchievedToday(_ member: UserProfile) -> Bool {
        group.currentCyclePhotos().filter { $0.owner?.id == member.id }.count >= GroupUnlockPolicy.individualMinimumPhotoCount
    }

    private var captureButton: some View {
        Button {
            CaptureRequestStore.shared.pendingRequestID = UUID()
        } label: {
            Text("撮影する（自分: \(myTodayCount)/\(GroupUnlockPolicy.individualMaximumPhotoCount(for: group))枚）")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.laterBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(Self.accent))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - ③過去の公開(3列グリッド。写真・動画をまとめて撮影日の新しい順に並べる)

    private enum UnlockedMediaItem: Identifiable {
        case photo(LaterPhoto)
        case video(LaterVideo)

        var id: String {
            switch self {
            case .photo(let photo): return "photo_\(photo.id.uuidString)"
            case .video(let video): return "video_\(video.id.uuidString)"
            }
        }

        var captureDate: Date {
            switch self {
            case .photo(let photo): return photo.captureDate
            case .video(let video): return video.captureDate
            }
        }
    }

    private var pastUnlockedItems: [UnlockedMediaItem] {
        let blockedIDs = Set(blockedUsers.map(\.blockedCloudKitUserRecordName))
        let photos = group.getUnlockedPhotos()
            .filter { photo in
                guard let authorID = photo.authorCloudKitUserRecordName else { return true }
                return !blockedIDs.contains(authorID)
            }
            .map(UnlockedMediaItem.photo)
        let videos = group.videos
            .filter(\.isUnlocked)
            .filter { video in
                guard let authorID = video.authorCloudKitUserRecordName else { return true }
                return !blockedIDs.contains(authorID)
            }
            .map(UnlockedMediaItem.video)
        return (photos + videos).sorted { $0.captureDate > $1.captureDate }
    }

    private static let gridColumns = [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)]

    @ViewBuilder
    private var pastUnlocksSection: some View {
        let items = pastUnlockedItems
        VStack(alignment: .leading, spacing: 14) {
            Text("過去の公開")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.laterText)
                .padding(.horizontal, 20)

            if items.isEmpty {
                Text("まだ公開された写真がありません")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.laterTextMuted)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            } else {
                LazyVGrid(columns: Self.gridColumns, spacing: 3) {
                    ForEach(items) { item in
                        pastUnlockCell(item)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    private func pastUnlockCell(_ item: UnlockedMediaItem) -> some View {
        Button {
            switch item {
            case .photo(let photo):
                selectedPhotoForViewing = photo
            case .video(let video):
                selectedVideoForPlayback = video
            }
        } label: {
            ZStack {
                switch item {
                case .photo(let photo):
                    CachedPhotoImage(imageData: photo.imageData, cacheKey: photo.imageCacheKey) { uiImage in
                        Image(uiImage: uiImage).resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.laterCard
                    }
                case .video(let video):
                    CachedPhotoImage(imageData: video.thumbnailData, cacheKey: video.imageCacheKey) { uiImage in
                        Image(uiImage: uiImage).resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.laterCard
                    }
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 4)
                }
            }
            .aspectRatio(1, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
