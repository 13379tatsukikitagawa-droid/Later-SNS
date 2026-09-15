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

    /// 直近に解禁時刻を迎えたサイクルの写真すべて(撮影者を問わない)。投票フェーズ撤去に
    /// 伴い、選出を待たずグループ全員分をそのまま一覧表示する。暦日ではなくサイクル単位で
    /// グルーピングするため、解禁が暦日をまたいでいても正しく同一サイクルとして扱われる。
    /// ブロック済みユーザーの写真はここで除外する(ModerationService参照)。
    private var todaysUnlockedPhotos: [LaterPhoto] {
        let blockedIDs = Set(blockedUsers.map(\.blockedCloudKitUserRecordName))
        return group.mostRecentCyclePhotos()
            .filter(\.isUnlocked)
            .filter { photo in
                guard let authorID = photo.authorCloudKitUserRecordName else { return true }
                return !blockedIDs.contains(authorID)
            }
            .sorted { $0.captureDate < $1.captureDate }
    }

    /// todaysUnlockedPhotosの動画版。以前はこの画面がLaterVideoを一切参照しておらず、
    /// 撮影・フィルム加工・CloudKitアップロードまで正常に完了していても、解禁後に
    /// どこにも表示されない(ユーザーからは「動画撮影ができない」ように見える)不具合の
    /// 原因になっていた。
    private var todaysUnlockedVideos: [LaterVideo] {
        let blockedIDs = Set(blockedUsers.map(\.blockedCloudKitUserRecordName))
        return group.mostRecentCycleVideos()
            .filter(\.isUnlocked)
            .filter { video in
                guard let authorID = video.authorCloudKitUserRecordName else { return true }
                return !blockedIDs.contains(authorID)
            }
            .sorted { $0.captureDate < $1.captureDate }
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
        // fetchAndApplyZoneImmediatelyはCloudKit側に新規変更が無ければ内部で早期returnし、
        // evaluateGroupUnlockConditions()を呼ばない。そのため「全員撮影完了済みで、
        // 時計が9:00を過ぎるのを待っているだけ」のケースは、ここで別途ローカル専用の
        // 時刻チェックを毎ポーリングで行う(ネットワークアクセス無し、コスト無視できる)。
        await cloudKitManager.evaluateLocallyPendingTimeGatedUnlocks()
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
        guard !old.isShotGoalMet, new.isShotGoalMet else { return }
        HapticsManager.unlockSuccess()
        showGoalReachedAnimation = true
        NotificationCenter.default.post(name: .neonFramePulseRequested, object: nil)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header

                AdaptiveCountdownBadge(state: state)
                    .padding(.top, 24)

                ScrollView {
                    content
                }
                .refreshable {
                    await refreshGroupData()
                }
            }
            .background(Color.brandBlack.ignoresSafeArea())

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
    }

    // MARK: - ヘッダー

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }

            Spacer()

            Text(group.name)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Button(action: { showingGroupInfo = true }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - 状態別の中身

    @ViewBuilder
    private var content: some View {
        switch state {
        case .shooting(_, let achievedCount, let memberCount, let groupTotal, let groupTarget):
            shootingContent(achievedCount: achievedCount, memberCount: memberCount, groupTotal: groupTotal, groupTarget: groupTarget)
        case .waitingForUnlockTime(let achievedCount, let memberCount, let unlockAt):
            waitingForUnlockTimeContent(achievedCount: achievedCount, memberCount: memberCount, unlockAt: unlockAt)
        case .unlocked:
            unlockedContent
        }
    }

    // MARK: - 撮影中

    private func shootingContent(achievedCount: Int, memberCount: Int, groupTotal: Int, groupTarget: Int) -> some View {
        VStack(spacing: 0) {
            progressRing(total: groupTotal, target: groupTarget)
                .padding(.top, 20)

            memberSection(achievedCount: achievedCount, memberCount: memberCount)
                .padding(.top, 32)

            myCountFooter
                .padding(.top, 32)

            captureButton
        }
    }

    // MARK: - 全員撮影完了・時刻待ち(「予告編」待機画面)

    /// 全員の撮影は完了しているが翌朝9:00にまだ到達していない状態。各メンバーの
    /// スロットを「PHOTO 01」のように匿名で並べ、撮影済みメンバーは地域・時刻・
    /// キャプションだけを見せて写真本体は🔒にする(GroupStatusPresenter.
    /// GroupDailyState.waitingForUnlockTime)。
    private func waitingForUnlockTimeContent(achievedCount: Int, memberCount: Int, unlockAt: Date) -> some View {
        VStack(spacing: 0) {
            AdaptiveCountdownBadge(state: state)
                .padding(.top, 28)

            photoSlotGrid
                .padding(.top, 32)

            Spacer(minLength: 24)
        }
    }

    private var photoSlotGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 100), spacing: 14)]
        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(Array(group.members.enumerated()), id: \.element.id) { index, member in
                photoSlotCard(index: index + 1, member: member)
            }
        }
        .padding(.horizontal, 24)
    }

    private func photoSlotCard(index: Int, member: UserProfile) -> some View {
        let photo = memberCurrentCyclePhoto(member)
        return VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(photo != nil ? 0.08 : 0.03))
                Image(systemName: photo != nil ? "lock.fill" : "camera")
                    .font(.system(size: photo != nil ? 20 : 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(photo != nil ? 0.4 : 0.15))
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(photo != nil ? Color.brandGreen.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
            )

            Text(String(format: "PHOTO %02d", index))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
                .kerning(1.2)

            if let photo {
                VStack(spacing: 2) {
                    if let locationName = photo.locationName, !locationName.isEmpty {
                        Label(locationName, systemImage: "mappin")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    Text(photo.captureDate.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                    if let caption = photo.caption, !caption.isEmpty {
                        Text(caption)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            } else {
                Text("未撮影")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .frame(width: 104)
    }

    private func memberCurrentCyclePhoto(_ member: UserProfile) -> LaterPhoto? {
        group.currentCyclePhotos().first { $0.owner?.id == member.id }
    }

    private func progressRing(total: Int, target: Int) -> some View {
        let progress = target > 0 ? min(1.0, Double(total) / Double(target)) : 0
        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 10)
                .frame(width: 180, height: 180)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.brandGreen, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)

            VStack(spacing: 2) {
                Text("\(total)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("/ \(target)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private func memberSection(achievedCount: Int, memberCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("メンバー（\(achievedCount)/\(memberCount)人 撮影済み）")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(group.members, id: \.id) { member in
                        memberAvatar(member)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func memberAvatar(_ member: UserProfile) -> some View {
        let achieved = memberAchievedToday(member)
        return VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                CachedPhotoImage(imageData: member.profileImageData, cacheKey: "avatar_\(member.id.uuidString)") { uiImage in
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ZStack {
                        Color.white.opacity(0.08)
                        Text(member.name.prefix(1))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(achieved ? Color.brandGreen : .white.opacity(0.4))
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(achieved ? Color.brandGreen : Color.white.opacity(0.15), lineWidth: achieved ? 2 : 1)
                )
                .saturation(achieved ? 1 : 0.3)
                .opacity(achieved ? 1 : 0.6)

                if !achieved {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(4)
                        .background(Circle().fill(Color.black.opacity(0.75)))
                }
            }

            Text(member.name)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .frame(width: 56)
        }
    }

    private func memberAchievedToday(_ member: UserProfile) -> Bool {
        group.currentCyclePhotos().filter { $0.owner?.id == member.id }.count >= GroupUnlockPolicy.individualMinimumPhotoCount
    }

    private var myCountFooter: some View {
        HStack(spacing: 6) {
            Text("自分")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
            Text("\(myTodayCount)/\(GroupUnlockPolicy.individualMaximumPhotoCount(for: group))")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            Text("枚")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.bottom, 14)
    }

    private var captureButton: some View {
        Button {
            CaptureRequestStore.shared.pendingRequestID = UUID()
        } label: {
            Text("撮影する")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.brandGreen)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - 解禁中

    /// 投票フェーズ撤去に伴い、選出を待たずその日解禁された写真をそのまま一覧表示する。
    private var unlockedContent: some View {
        VStack(spacing: 0) {
            Text("解禁中・次の解禁まで見られます")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 24)

            photoGallery(todaysUnlockedPhotos, topPadding: 24)

            // 2026/9: 動画機能はUI導線のみ一時非表示(コードは残す、上のmodeToggle
            // 非表示化と同じ方針)。todaysUnlockedVideos自体は今後もisEmptyでない
            // 可能性がある(過去に動画機能が有効だった時の投稿)ため、表示だけ止める。
            // if !todaysUnlockedVideos.isEmpty {
            //     videoGallery(todaysUnlockedVideos)
            // }
        }
        .sheet(item: $selectedVideoForPlayback) { video in
            VideoDetailPlayerView(video: video)
        }
    }


    /// 解禁済みの写真を撮影者情報つきで縦に並べる共通レイアウト。解禁中(unlockedContent)・
    /// 閲覧期間終了後(finishedContent、写真がある場合)の両方で共用する。投票フェーズ撤去に
    /// 伴い、選出を待たず撮影者を常に明示する(以前のisAuthorRevealedによる匿名化は行わない)。
    /// topPadding: unlockedContentは上に案内文があるため詰め、finishedContentは
    /// 案内文が無いため広めに取る。
    private func photoGallery(_ photos: [LaterPhoto], topPadding: CGFloat = 80) -> some View {
        VStack(spacing: 28) {
            ForEach(photos) { photo in
                VStack(spacing: 12) {
                    ChekiPhotoFrame(photo: photo)
                        .frame(maxWidth: 240)
                        .contextMenu {
                            if photo.owner?.id != currentUser?.id {
                                Button {
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
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(.top, topPadding)
        .padding(.bottom, 40)
        .sheet(item: $reportTargetPhoto) { photo in
            ReportSheet(targetType: .groupPhoto, targetID: photo.ckRecordName ?? photo.id.uuidString)
        }
    }

    /// 解禁済みの動画を撮影者情報つきで縦に並べる、photoGalleryの動画版。一覧では
    /// LaterVideo.thumbnailData(静止画1枚)だけを描画し、動画本体はタップ時に
    /// VideoDetailPlayerView側でCloudKitManager.fetchVideoAsset(for:)経由で
    /// 都度フェッチする(この一覧自体が動画本体を読み込むことは無い)。
    private func videoGallery(_ videos: [LaterVideo]) -> some View {
        VStack(spacing: 28) {
            ForEach(videos) { video in
                VStack(spacing: 12) {
                    Button {
                        selectedVideoForPlayback = video
                    } label: {
                        ZStack {
                            CachedPhotoImage(imageData: video.thumbnailData, cacheKey: video.imageCacheKey) { uiImage in
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            }
                            .frame(maxWidth: 240)
                            .aspectRatio(3.0 / 4.0, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                            )

                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.9))
                                .shadow(radius: 6)
                        }
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 6) {
                        photoAuthorAvatar(video.owner)
                        Text(video.owner?.name ?? video.authorNameCache ?? "不明")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 40)
    }

    /// 解禁済み写真の撮影者アバター(小さな丸アイコン)。
    /// ownerがまだローカルに解決できていない場合はシルエットで代替する。
    private func photoAuthorAvatar(_ owner: UserProfile?) -> some View {
        Group {
            if let data = owner?.profileImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Circle()
                    .fill(Color.brandGreen.opacity(0.2))
                    .overlay(
                        Text((owner?.name ?? "?").prefix(1))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.brandGreen)
                    )
            }
        }
        .frame(width: 22, height: 22)
        .clipShape(Circle())
    }
}
