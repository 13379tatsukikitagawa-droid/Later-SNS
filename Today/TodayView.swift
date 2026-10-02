import SwiftUI
import SwiftData

/// Homeタブ(今日のミッション画面)。中身はTodayShootingViewに分離した薄いコンテナで、
/// 撮影〜投稿の画面遷移(fullScreenCover)だけを受け持つ。
struct TodayView: View {
    @Environment(\.modelContext) private var context
    /// グループ詳細(GroupHomeDetailView)など、Home内でさらに奥へ遷移した状態で
    /// 撮影を開始した場合に、そのままだと撮影終了(完了/キャンセルどちらでも)後も
    /// 遷移先の画面に留まってしまう。撮影を開始する瞬間にこの経路を空にして
    /// ルート(グループ一覧)まで戻しておくことで、撮影後に必ずHomeが見える状態にする。
    @State private var navigationPath = NavigationPath()
    @State private var showingCamera = false
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

    var body: some View {
        NavigationStack(path: $navigationPath) {
            TodayShootingView(groups: userGroups)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            // TodayShootingView側で独自のヘッダー(ロゴ・通知ベル)を組んでいるため、
            // ネイティブのナビゲーションバー自体を非表示にして、その分の余白ごと詰める。
            // NavigationStack自体はグループ一覧のNavigationLink(GroupHomeDetailViewへの
            // 遷移)に必要なため残す。
            .toolbar(.hidden, for: .navigationBar)
            // 再設計 Step 1: 撮影の前のキャプション入力・撮影後の投稿準備画面(プレビュー)は
            // 挟まない。タグは撮影画面の中で選び、撮った瞬間に保存して暗転する。
            .fullScreenCover(isPresented: $showingCamera) {
                ExposureCameraView(
                    hasShotToday: hasShotToday,
                    onCaptured: saveExposure,
                    onFinished: finishExposure,
                    onClose: { showingCamera = false }
                )
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
