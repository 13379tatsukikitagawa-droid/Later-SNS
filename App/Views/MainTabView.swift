import SwiftUI
import SwiftData

/// 現在アクティブな(表示中の)メインタブのインデックス。各タブ配下のビューがこれを読んで
/// 「今アクティブか」を判定できるようにする(例: 非表示中のタブが自分のポーリング処理を
/// 無駄に回し続けないようにするため)。2026/9のMVP再設計でネイティブTabViewを廃止し
/// 常時Home(=TodayView)のみを表示する構成になったため、常に0を返す(デフォルト値のまま)。
struct SelectedMainTabIndexKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    var selectedMainTabIndex: Int {
        get { self[SelectedMainTabIndexKey.self] }
        set { self[SelectedMainTabIndexKey.self] = newValue }
    }
}

/// メインナビゲーション。
///
/// 2026/9 MVP再設計: 「タブが2つ(Home/撮影)しかないのに、ネイティブTabViewが
/// 5タブ分ありそうな横長のピル(Liquid Glassタブバー)を描画してしまい、独立した
/// 丸ボタン(撮影)を重ねると位置がおかしく見える」という指摘を受け、ネイティブ
/// TabView自体を廃止した。Homeは実質1画面(TodayView、内部にWorld/Personal/
/// Communityの切り替えを持つ)しか無いため、TabViewの代わりに直接TodayView()を
/// bodyとして表示し、その上にHome/シャッターの2つの独立した丸ボタン
/// (HomeAndShutterOverlay、共有の背景・枠を持たない)を重ねるだけの構成にする。
/// Profileタブは既に廃止済みで、マイページへの導線はTodayViewの統合ヘッダーの
/// アバターアイコンから開く(Profile/Views/MyPageView.swift参照)。
struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var groups: [LaterGroup]
    @Query private var profiles: [UserProfile]

    @State private var showCaptureToast = false
    @State private var captureToastMessage = ""

    /// タブ内でさらに奥へ遷移した画面が、自前の入力欄を画面最下部に持つ場合、
    /// この下部ボタンオーバーレイが邪魔になることがある。それらの画面が
    /// isHiddenをtrueにすることで、このオーバーレイも連動して隠せるようにする
    /// (現在この仕組みを使う画面は無い)。
    @ObservedObject private var tabBarVisibility = TabBarVisibilityStore.shared

    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }

    private var userGroups: [LaterGroup] {
        guard let user = currentUser else { return [] }
        return groups.filter { $0.members.contains(where: { $0.id == user.id }) }
    }

    // MARK: - 撮影可否判定(TodayShootingViewの選択中グループ判定と同じ基準)

    private enum CaptureAvailability: Equatable {
        case available
        case blocked(message: String)
    }

    /// setlog方式(1回の撮影を複数グループへ選択投稿)導入に伴い、シャッター自体は
    /// 「所属グループのうち1つでも撮影中なら押せる」判定にしている。締切/投票フェーズや
    /// グループごとの1日の上限は、投稿先を選ぶPostTargetGroupSelectionView側で
    /// グループごとにチェックボックスの活性/非活性として反映する(単一グループへの
    /// 依存を無くし、複数グループへの一括投稿を成立させるため)。MEのみ参加、または
    /// MEを含むいずれかのグループでまだ撮影可能なら、撮影可能なグループが1つでも
    /// 残っている限りロックしない。
    /// 撮影自体には時刻制限が無い(解禁だけが翌朝9:00固定)。参加グループが1つでも
    /// あれば、GroupDailyStateが.shooting/.waitingForUnlockTime/.unlockedのいずれでも
    /// 常に撮影可能。
    private var captureAvailability: CaptureAvailability {
        guard !userGroups.isEmpty else {
            return .blocked(message: "グループに参加すると撮影できます")
        }
        return .available
    }

    var body: some View {
        TodayView()
            .environment(\.selectedMainTabIndex, 0)
            .overlay(alignment: .bottom) {
                if !tabBarVisibility.isHidden {
                    HomeAndShutterOverlay(
                        isShutterLocked: captureAvailability != .available,
                        onHome: handleHomeTap,
                        onShutter: handleCaptureTap
                    )
                }
            }
            .overlay {
                NeonScreenFrame()
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                if showCaptureToast {
                    Text(captureToastMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color(white: 0.12)))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                        .padding(.bottom, 60)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .photoNotificationTapped)) { _ in
                // 撮影通知(PhotoNotificationService)をタップした場合。GroupSelectionStore.
                // selectedGroupIDの更新はAppDelegate側で既に完了しており、ここではHomeの
                // ルートへ戻すだけでよい(Home画面自体がGroupSelectionStoreを見て該当
                // グループを表示する)。
                HomeNavigationStore.shared.popToRootRequestID = UUID()
            }
    }

    // MARK: - Home/撮影ボタンのタップ処理

    private func handleHomeTap() {
        HapticsManager.swipeFeedback()
        HomeNavigationStore.shared.popToRootRequestID = UUID()
    }

    /// 実際の撮影処理(枚数上限・CloudKit保存・キャプション遷移)はTodayView側に
    /// 閉じたまま — CaptureRequestStore経由で「開いて」のシグナルを送るだけにし、
    /// ロジックの複製を避ける。撮影不可の状態(上限到達・投票中/終了後・未参加)では
    /// 遷移させず、.rigidハプティック+短いトーストでフィードバックする。
    private func handleCaptureTap() {
        switch captureAvailability {
        case .available:
            HapticsManager.shutterClick()
            CaptureRequestStore.shared.pendingRequestID = UUID()
        case .blocked(let message):
            presentCaptureBlockedFeedback(message: message)
        }
    }

    private func presentCaptureBlockedFeedback(message: String) {
        HapticsManager.shutterClick(style: .rigid)
        captureToastMessage = message

        withAnimation(.easeOut(duration: 0.2)) {
            showCaptureToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                showCaptureToast = false
            }
        }
    }

}

// MARK: - Preview

#Preview {
    MainTabView()
        .modelContainer(for: [UserProfile.self, LaterGroup.self, LaterPhoto.self], inMemory: true)
}
