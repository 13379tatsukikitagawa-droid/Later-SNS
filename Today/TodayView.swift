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
    @State private var showingCaptionEntry = false
    @State private var pendingCaption: String = ""
    /// showingCaptionEntryが閉じ切った直後に撮影画面を開くべきかどうかのフラグ
    /// (キャンセル時はfalseのまま、次へ進む時だけtrueにする)。
    @State private var shouldOpenCameraAfterCaption = false
    @State private var showingCamera = false
    @State private var showSuccessMessage = false
    @State private var pendingImageData: Data?
    @State private var pendingLocationName: String?
    @State private var showingPostTargetSelection = false
    @State private var pendingVideoURL: URL?
    @State private var pendingVideoThumbnail: UIImage?
    @State private var pendingVideoDuration: Double = 0
    @State private var showingVideoPostFlow = false

    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]
    @Bindable private var groupSelection = GroupSelectionStore.shared
    @Bindable private var captureRequest = CaptureRequestStore.shared

    private var userGroups: [LaterGroup] {
        guard let user = UserProfile.current(from: profiles) else { return [] }
        return groups.filter { $0.members.contains(where: { $0.id == user.id }) }
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

    var body: some View {
        NavigationStack(path: $navigationPath) {
            TodayShootingView(groups: userGroups, streakCount: currentStreakCount)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            // 以前はここに.navigationTitle("Today's Mission")があったが、
            // TodayShootingView側で独自のヘッダー(ロゴ・ストリーク・通知ベル)を
            // 組んでいるため、ネイティブのナビゲーションバー自体を非表示にして、
            // その分の余白ごと詰める。NavigationStack自体はグループ一覧の
            // NavigationLink(GroupHomeDetailViewへの遷移)に必要なため残す。
            .toolbar(.hidden, for: .navigationBar)
            // 2026/9 新デザイン仕様「②キャプション入力画面」: 撮影の前にキャプションを
            // 書くステップ(STEP 1/2)を挟む。任意入力で、スキップしても「次へ」でも
            // そのまま撮影画面(showingCamera)へ進む。入力した文字列はpendingCaptionに
            // 保持し、投稿準備画面(PostTargetGroupSelectionView)まで引き継ぐ。
            .fullScreenCover(isPresented: $showingCaptionEntry) {
                CaptionEntryView(
                    initialCaption: pendingCaption,
                    onContinue: { caption in
                        pendingCaption = caption
                        shouldOpenCameraAfterCaption = true
                        showingCaptionEntry = false
                    },
                    onCancel: {
                        showingCaptionEntry = false
                    }
                )
            }
            // キャプション入力→撮影画面は別々のfullScreenCoverのため、同一トランザクション内で
            // 片方をfalseにしつつもう片方をtrueにすると、前の画面がまだ閉じきっていない状態で
            // 次のfullScreenCoverの提示が要求され、プレゼンテーションが競合してクラッシュする
            // ことがある(実際に発生した不具合)。showingCaptionEntryが実際にfalseへ
            // 反映されたのを見届けてから(onChange)、次のshowingCameraをtrueにする。
            .onChange(of: showingCaptionEntry) { _, isShowing in
                guard !isShowing, shouldOpenCameraAfterCaption else { return }
                shouldOpenCameraAfterCaption = false
                // dismissアニメーションが完全に終わってから次のfullScreenCoverを提示する
                // (即座にtrueにすると、前の画面がまだ閉じきっていない状態で次の提示が
                // 要求され、プレゼンテーションが競合してクラッシュすることがあった)。
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showingCamera = true
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CheckiCameraEntryView(
                    currentCount: currentGroup.map { myTodayCount(in: $0) } ?? 0,
                    limit: currentGroup.map { GroupUnlockPolicy.individualMaximumPhotoCount(for: $0) } ?? GroupUnlockPolicy.individualMinimumPhotoCount,
                    streakCount: currentStreakCount,
                    caption: pendingCaption
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
            //
            // showingCameraがfalseになった直後の同一トランザクション内で次のfullScreenCover
            // (showingPostTargetSelection/showingVideoPostFlow)をtrueにすると、撮影画面が
            // まだ閉じきっていない状態で次の提示が要求され、プレゼンテーションが競合して
            // 投稿準備画面が正しく開かない(=写真が撮影されただけでどこにも投稿されない)
            // 不具合があった。キャプション→撮影画面の遷移と同じく、閉じるアニメーションが
            // 完了するのを少し待ってから次の画面を開く。
            .onChange(of: showingCamera) { _, isShowing in
                guard !isShowing else { return }
                if pendingImageData != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showingPostTargetSelection = true
                    }
                }
                if pendingVideoURL != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showingVideoPostFlow = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showingPostTargetSelection) {
                if let imageData = pendingImageData {
                    PostTargetGroupSelectionView(
                        imageData: imageData,
                        locationName: pendingLocationName,
                        initialCaption: pendingCaption,
                        onFinished: { success in
                            showingPostTargetSelection = false
                            pendingImageData = nil
                            pendingLocationName = nil
                            pendingCaption = ""
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
                pendingCaption = ""
                showingCaptionEntry = true
                captureRequest.pendingRequestID = nil
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
