import SwiftUI
import SwiftData

/// Homeタブ。画面の中身はHomeView(再設計 Step 2)で、ここはデータの用意・
/// CloudKitの定期同期・撮影画面などへの遷移(fullScreenCover)だけを受け持つ。
struct TodayView: View {
    @Environment(\.modelContext) private var context
    /// グループ詳細(GroupHomeDetailView)など、Home内でさらに奥へ遷移した状態で
    /// 撮影を開始した場合に、そのままだと撮影終了(完了/キャンセルどちらでも)後も
    /// 遷移先の画面に留まってしまう。撮影を開始する瞬間にこの経路を空にして
    /// ルート(グループ一覧)まで戻しておくことで、撮影後に必ずHomeが見える状態にする。
    @State private var navigationPath = NavigationPath()
    @State private var showingCamera = false
    /// 「昨日を見る」の仮の画面(本当の画面はStep 3以降で作る)。
    @State private var showingYesterday = false
    /// Homeのボタンの位置から撮影画面が広がるzoom遷移に使う。
    @Namespace private var homeTransition
    @Environment(\.selectedMainTabIndex) private var selectedMainTabIndex
    private static let homeTabIndex = 0
    /// 撮影画面(暗転したまま閉じる)から戻った直後に、Homeの上に一瞬だけ残す黒い幕。
    /// fullScreenCoverの閉じるアニメーション(下へスライド)を使わず、暗い画面のまま
    /// ゆっくりフェードしてHomeへ移るために使う。
    @State private var isShowingExposureVeil = false

    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]
    @Bindable private var captureRequest = CaptureRequestStore.shared

    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }

    private var userGroups: [LaterGroup] {
        guard let user = currentUser else { return [] }
        return groups.filter { $0.members.contains(where: { $0.id == user.id }) }
    }

    private var hasShotToday: Bool {
        guard let user = currentUser else { return false }
        return DailyExposureRules.hasShot(on: Date(), by: user)
    }

    private var myCaptureDates: [Date] {
        currentUser?.photos.map(\.captureDate) ?? []
    }

    /// 件数だけを数える(昨日の写真の画像はHomeで取得しない)。ユーザー未確定の間は「—」。
    private var yesterdayCount: Int? {
        guard currentUser != nil else { return nil }
        return HomeState.yesterdayPhotoCount(in: userGroups, now: Date())
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            HomeView(
                myCaptureDates: myCaptureDates,
                yesterdayCount: yesterdayCount,
                isCovered: showingCamera || showingYesterday,
                transitionNamespace: homeTransition,
                onShoot: { showingCamera = true },
                onViewYesterday: { showingYesterday = true }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // HomeView側で独自のヘッダーを組んでいるため、ネイティブのナビゲーションバーは出さない。
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                AppLaunchTiming.reportHomeDisplayedIfNeeded()
            }
            .task {
                // MainTabViewは全タブをマウントし続けるため、Homeタブが選ばれている間だけ同期する。
                while !Task.isCancelled {
                    if selectedMainTabIndex == Self.homeTabIndex {
                        await refreshAllGroups()
                    }
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                }
            }
            // 再設計 Step 1: 撮影後の投稿準備画面(プレビュー)は挟まない。撮った瞬間に保存して暗転する。
            // 撮影の前に、今日にタグをつける画面(TagBeforeShootView)を挟む。下からせり上がって開き、
            // 「撮影へ」「タグなしで撮る」で同じフルスクリーンの中の撮影画面(Step 1)へ進む。
            .fullScreenCover(isPresented: $showingCamera) {
                ShootFlowView(
                    hasShotToday: hasShotToday,
                    onCaptured: saveExposure,
                    onFinished: finishExposure,
                    onClose: { showingCamera = false }
                )
            }
            .fullScreenCover(isPresented: $showingYesterday) {
                YesterdayPlaceholderView { showingYesterday = false }
                    .navigationTransition(.zoom(sourceID: HomeView.primaryActionTransitionID, in: homeTransition))
            }
            .overlay {
                if isShowingExposureVeil {
                    Color.black
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .onChange(of: captureRequest.pendingRequestID) { _, newValue in
                guard newValue != nil else { return }
                navigationPath = NavigationPath()
                showingCamera = true
                captureRequest.pendingRequestID = nil
            }
        }
    }

    /// 複数グループをまたぐ画面なので、Private/Shared両DBの変更をまとめて取り込む。
    private func refreshAllGroups() async {
        guard let cloudKitManager = CloudKitManager.current else { return }
        await cloudKitManager.fetchSharedChangesNow()
        await cloudKitManager.fetchPrivateChangesNow()
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

    /// 暗転画面を見せ終えた。黒い幕を残したまま撮影画面をアニメーションなしで閉じ、
    /// 幕をゆっくり(0.6秒)フェードさせてHomeへ戻る。
    private func finishExposure() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isShowingExposureVeil = true
            showingCamera = false
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.05)) {
            isShowingExposureVeil = false
        }
    }
}

/// 「昨日を見る」の仮の画面。本当の画面(昨日の写真を見る・Today's Later)は後のStepで作る。
private struct YesterdayPlaceholderView: View {
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            VStack(spacing: 10) {
                Text("昨日を見る")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text("この画面は、後の Step で作ります。")
                    .font(.system(size: 13))
                    .foregroundStyle(HomePalette.subText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HomePalette.subText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("閉じる")
            .padding(.leading, 8)
        }
        .preferredColorScheme(.dark)
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
