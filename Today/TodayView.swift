import SwiftUI
import SwiftData

/// Homeタブ(今日のミッション画面)。撮影中/投票中/終了の3状態を切り替えるだけの
/// 薄いコンテナで、各状態の中身は TodayShootingView / TodayVotingPromptView /
/// TodayFinishedView に分離している。
struct TodayView: View {
    @Environment(\.modelContext) private var context
    /// グループ詳細(GroupHomeDetailView)など、Home内でさらに奥へ遷移した状態で
    /// 撮影を開始した場合に、そのままだと撮影終了(完了/キャンセルどちらでも)後も
    /// 遷移先の画面に留まってしまう。撮影を開始する瞬間にこの経路を空にして
    /// ルート(グループ一覧)まで戻しておくことで、撮影後に必ずHomeが見える状態にする。
    @State private var navigationPath = NavigationPath()
    @State private var showingCamera = false
    @State private var showSuccessMessage = false
    @State private var pendingImageData: Data?
    @State private var pendingLocationName: String?
    @State private var showingPostTargetSelection = false
    @State private var pendingVideoURL: URL?
    @State private var pendingVideoThumbnail: UIImage?
    @State private var pendingVideoDuration: Double = 0
    @State private var showingVideoPostFlow = false
    @State private var showingMyPage = false

    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]
    @Bindable private var groupSelection = GroupSelectionStore.shared
    @Bindable private var captureRequest = CaptureRequestStore.shared
    @Bindable private var homeNavigation = HomeNavigationStore.shared

    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }

    private var userGroups: [LaterGroup] {
        guard let user = currentUser else { return [] }
        return groups.filter { $0.members.contains(where: { $0.id == user.id }) }
    }

    /// ヘッダーのアバターに緑ドットバッジを出すかどうか。自分が撮影した、まだ解禁
    /// されていない(=現像中の)写真が所属グループのどこかに1枚でもあれば表示する。
    private var hasDevelopingPhotos: Bool {
        guard let user = currentUser else { return false }
        return userGroups.contains { group in
            group.photos.contains { $0.owner?.id == user.id && !$0.isUnlocked }
        }
    }

    /// GroupSwitcherHeaderで選択されたグループを優先し、未選択ならME優先の並び順で
    /// 先頭のグループにする(Home画面の一覧・撮影ボタンの判定基準と統一)。
    private var currentGroup: LaterGroup? {
        let ordered = userGroups.meFirstOrdered()
        if let selectedID = groupSelection.selectedGroupID,
           let match = ordered.first(where: { $0.id == selectedID }) {
            return match
        }
        return ordered.first
    }

    private var personalSpaceGroupIDs: Set<UUID> {
        Set(groups.filter(\.isPersonalSpace).map(\.id))
    }

    /// カメラ画面の控えめな連続記録表示に渡す、直近の連続撮影日数。
    private var currentStreakCount: Int {
        UserProfile.current(from: profiles)?.currentStreak(personalSpaceGroupIDs: personalSpaceGroupIDs) ?? 0
    }

    /// Home画面の3モード。World=匿名グローバルフィード、Personal=ME、
    /// Community=Circle(既存の複数グループ表示)。TodayShootingViewは元々
    /// isPersonalSpaceで分岐する作りになっているため、渡すgroups配列を絞り込むだけで
    /// PersonalモードとCommunityモードを実現でき、TodayShootingView自体の変更は不要。
    enum HomeSelectorMode: String, CaseIterable {
        case world = "World"
        case personal = "Personal"
        case community = "Community"
    }
    @State private var selectedMode: HomeSelectorMode = .community

    private var personalOnlyGroups: [LaterGroup] {
        userGroups.filter(\.isPersonalSpace)
    }

    private var communityOnlyGroups: [LaterGroup] {
        userGroups.filter { !$0.isPersonalSpace }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                CorkboardBackground()

                VStack(spacing: 0) {
                    unifiedHeader
                        .padding(.top, 12)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    Group {
                        switch selectedMode {
                        case .world:
                            WorldLaterFeedView()
                        case .personal:
                            PersonalTodayView(group: personalOnlyGroups.first)
                        case .community:
                            TodayShootingView(groups: communityOnlyGroups)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.corkboardTabActive)
                    .clipShape(
                        .rect(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 18,
                            bottomTrailingRadius: 18,
                            topTrailingRadius: 0
                        )
                    )
                }
            }
            // 以前はここに.navigationTitle("Today's Mission")があったが、
            // TodayShootingView側で独自のヘッダー(現像中ボタン・絞りアイコン・日付・
            // カウントダウン)を組んでいるため、ネイティブのナビゲーションバー自体を
            // 非表示にして、その分の余白ごと詰める。NavigationStack自体は
            // グループ一覧のNavigationLink(GroupHomeDetailViewへの遷移)に必要なため残す。
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showingCamera) {
                CheckiCameraEntryView(
                    currentCount: currentGroup.map { myTodayCount(in: $0) } ?? 0,
                    limit: currentGroup.map { GroupUnlockPolicy.individualMaximumPhotoCount(for: $0) } ?? GroupUnlockPolicy.individualMinimumPhotoCount,
                    streakCount: currentStreakCount
                ) { imageData, locationName in
                    pendingImageData = imageData
                    pendingLocationName = locationName
                    showingCamera = false
                } onCaptureVideo: { videoURL, thumbnail, duration, locationName in
                    pendingVideoURL = videoURL
                    pendingVideoThumbnail = thumbnail
                    pendingVideoDuration = duration
                    pendingLocationName = locationName
                    showingCamera = false
                }
                .ignoresSafeArea()
            }
            // 撮影直後、キャプション入力は別画面に分けず投稿準備画面(写真プレビュー+
            // キャプション+投稿先選択を1画面にまとめたBeReal/setlog融合UI)へ直接進む。
            // 動画も同じ考え方で、動画専用の投稿準備画面(VideoPostFlowView)へ直接進む。
            .onChange(of: showingCamera) { _, isShowing in
                if !isShowing, pendingImageData != nil {
                    showingPostTargetSelection = true
                }
                if !isShowing, pendingVideoURL != nil {
                    showingVideoPostFlow = true
                }
            }
            .fullScreenCover(isPresented: $showingPostTargetSelection) {
                if let imageData = pendingImageData {
                    PostTargetGroupSelectionView(
                        imageData: imageData,
                        locationName: pendingLocationName,
                        onFinished: { success in
                            showingPostTargetSelection = false
                            pendingImageData = nil
                            pendingLocationName = nil
                            guard success else { return }
                            withAnimation(.spring()) {
                                showSuccessMessage = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation(.easeOut) {
                                    showSuccessMessage = false
                                }
                            }
                        }
                    )
                }
            }
            .fullScreenCover(isPresented: $showingVideoPostFlow) {
                if let videoURL = pendingVideoURL {
                    VideoPostFlowView(
                        videoURL: videoURL,
                        thumbnail: pendingVideoThumbnail,
                        durationSeconds: pendingVideoDuration,
                        locationName: pendingLocationName,
                        onFinished: { success in
                            showingVideoPostFlow = false
                            pendingVideoURL = nil
                            pendingVideoThumbnail = nil
                            pendingVideoDuration = 0
                            pendingLocationName = nil
                            guard success else { return }
                            withAnimation(.spring()) {
                                showSuccessMessage = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation(.easeOut) {
                                    showSuccessMessage = false
                                }
                            }
                        }
                    )
                }
            }
            .overlay {
                if showSuccessMessage {
                    successMessageOverlay
                }
            }
            .onChange(of: captureRequest.pendingRequestID) { _, newValue in
                guard newValue != nil else { return }
                navigationPath = NavigationPath()
                showingCamera = true
                captureRequest.pendingRequestID = nil
            }
            .onChange(of: homeNavigation.popToRootRequestID) { _, newValue in
                guard newValue != nil else { return }
                navigationPath = NavigationPath()
                homeNavigation.popToRootRequestID = nil
            }
        }
    }

    // MARK: - グループ進捗の集計

    private func myTodayCount(in group: LaterGroup) -> Int {
        guard let myID = UserProfile.current(from: profiles)?.id else { return 0 }
        return group.currentCyclePhotos().filter { $0.owner?.id == myID }.count
    }

    // MARK: - 成功メッセージオーバーレイ
    private var successMessageOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color.brandGreen)
                Text("投稿しました！")
                    .foregroundStyle(.white)
            }
            .font(.headline)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.brandBlack.opacity(0.95))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            .padding(.bottom, 50)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - 統合ヘッダー(ロゴ+World/Personal/Communityセレクター+アバター)

    /// 2026/9 MVP再設計: 以前は「タブ行(このセレクター)」と「ロゴ+現像中ボタン+
    /// アバターのヘッダー行(BrandHeaderRow)」の2段構成で、アクティブの合図も
    /// タブの背景色分け+上端の緑線の2重になっていた。これを1段に統合し、
    /// アクティブの合図も「白いカプセル」1つだけにする。「現像中」の専用ボタンは
    /// 廃止し、アバター右上の緑ドットバッジ(現像中の写真が実際にある時だけ表示)に
    /// 置き換える。BrandHeaderRowはPersonalTodayView/TodayShootingView側でも
    /// もう使わない(このヘッダーが3モード共通で常に上に乗るため)。
    private var unifiedHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.brandGreen)

            Spacer(minLength: 8)

            modeSegmentedControl

            Spacer(minLength: 8)

            avatarButton
        }
        .fullScreenCover(isPresented: $showingMyPage) {
            MyPageView()
        }
    }

    /// 1つの丸型セグメントコントロール。アクティブな項目だけに白〜クリームの
    /// カプセルを敷き、非アクティブは背景無し。インジケーターはこれ1種類だけ。
    private var modeSegmentedControl: some View {
        HStack(spacing: 2) {
            ForEach(HomeSelectorMode.allCases, id: \.self) { mode in
                let isActive = selectedMode == mode
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMode = mode
                    }
                } label: {
                    Text(mode.rawValue.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(0.3)
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(isActive ? Color(hex: "17110c") : Color(hex: "6b5f50"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background {
                            if isActive {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "fffdf9"), Color(hex: "ece5d5")],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "241a12"), Color(hex: "1c1712")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(Capsule().strokeBorder(Color.black.opacity(0.3), lineWidth: 1))
        )
    }

    /// ペルソナアバター。現像中の写真が実際にある時だけ、右上に緑のグロー付き
    /// ドットバッジを表示する(常時点灯にはしない)。タップでマイページを開く
    /// (旧「現像中」専用ボタンの導線もマイページ内に統合済み)。
    private var avatarButton: some View {
        Button {
            showingMyPage = true
        } label: {
            ZStack(alignment: .topTrailing) {
                CachedPhotoImage(
                    imageData: currentUser?.profileImageData,
                    cacheKey: "avatar_header_\(currentUser?.id.uuidString ?? "me")"
                ) { uiImage in
                    Image(uiImage: uiImage)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.brandGreen.opacity(0.6))
                }
                .frame(width: 30, height: 30)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.brandGreen.opacity(0.4), lineWidth: 1.2))

                if hasDevelopingPhotos {
                    Circle()
                        .fill(Color.brandGreen)
                        .frame(width: 11, height: 11)
                        .shadow(color: Color.brandGreen.opacity(0.8), radius: 4)
                        .overlay(Circle().strokeBorder(Color.corkboardBackground, lineWidth: 1.5))
                        .offset(x: 3, y: -3)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 画面状態

/// 画面中央のアクション要素(撮影ボタンが置かれる場所)の状態。GroupStatusPresenter.state(for:)と
/// 「個人の撮影上限に達しているか」の組み合わせで決まる。実際の描画分岐は
/// TodayShootingView/TodayVotingPromptView/TodayFinishedView側で行うため、
/// ここでは概念を明示するためのenumとして定義するに留める。
enum CaptureActionState: Equatable {
    case capture              // 撮影中・撮影可能
    case captureLimitReached  // 撮影中・個人の上限(GroupUnlockPolicy.individualMaximumPhotoCount)に到達済み
    case vote                 // 投票中
    case result                // 終了後
}
