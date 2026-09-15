import SwiftUI
import SwiftData

/// 現在アクティブな(表示中の)メインタブのインデックス。各タブ配下のビューがこれを読んで
/// 「今アクティブか」を判定できるようにする(例: 非表示中のタブが自分のポーリング処理を
/// 無駄に回し続けないようにするため)。
struct SelectedMainTabIndexKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    var selectedMainTabIndex: Int {
        get { self[SelectedMainTabIndexKey.self] }
        set { self[SelectedMainTabIndexKey.self] = newValue }
    }
}

/// TabViewの選択値。ホームだけが実際にコンテンツを持つ通常のタブ。cameraは特殊枠で、
/// 選択されても画面は切り替わらず、代わりに撮影可否に応じたアクション
/// (撮影画面を開く/ロック案内を出す)だけが起こる。
///
/// 2026/9: Profileタブは廃止した。マイページへの導線は、Homeタブ内部の各画面
/// (BrandHeaderRow等)のヘッダー右端にあるアバターアイコンから開く
/// (Profile/Views/MyPageView.swift参照)。
private enum MainTabSelection: Hashable {
    case home, camera

    init(contentIndex: Int) {
        self = .home
    }
}

/// メインナビゲーション - Home / 撮影 の2項目のタブバー
/// (ネイティブTabView、iOS 26のLiquid Glass対応版)。
/// 「タブバー上をなぞって最寄りのタブへスナップする」独自ドラッグ操作は、
/// ネイティブのタブバーには存在しない挙動のため、タップのみの標準的な切り替えになる。
/// 中央の撮影ボタンは、ネイティブのタブバー項目がアイコンをテンプレート画像として扱い
/// 選択状態に応じて単色に塗り替えてしまう(独自の色付きボタンを埋め込んでも色が失われる)
/// ため、実体を持たない特殊タブの上に、常時緑のCameraApertureButtonを独立した
/// オーバーレイとして重ねている。
struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var groups: [LaterGroup]
    @Query private var profiles: [UserProfile]

    @State private var selectedTab = 0

    @State private var showCaptureToast = false
    @State private var captureToastMessage = ""

    /// タブ内でさらに奥へ遷移した画面が、自前の入力欄を画面最下部に持つ場合、
    /// `.toolbar(.hidden, for: .tabBar)`でネイティブのタブバー自体は隠せるが、
    /// 撮影ボタン(CameraApertureButton)はタブバーのtoolbarとは無関係の独立した
    /// `.overlay`として重ねているため、その仕組みだけでは連動して消えない。
    /// それらの画面がisHiddenをtrueにすることで、この撮影ボタンのオーバーレイも
    /// 連動して隠せるようにする(現在この仕組みを使う画面は無い)。
    @ObservedObject private var tabBarVisibility = TabBarVisibilityStore.shared

    private static let neonGreen = Color.brandGreen

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

    /// TabViewのselectionはMainTabSelectionで受けるが、実体(コンテンツの表示切り替え)は
    /// 既存のselectedTab(Int、Profileタブ廃止後は常に0=ホーム)のまま。cameraタブ自体は
    /// タップされない前提(下のcameraTab参照)のため、setter側にはcameraの分岐を
    /// 残していない(万一何らかの経路で.cameraが渡ってきても無視して現状維持する)。
    private var tabSelection: Binding<MainTabSelection> {
        Binding(
            get: { MainTabSelection(contentIndex: selectedTab) },
            set: { newValue in
                switch newValue {
                case .camera:
                    break
                case .home:
                    selectedTab = 0
                }
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            Tab(value: MainTabSelection.home) {
                TodayView()
            } label: {
                Label("ホーム", systemImage: selectedTab == 0 ? "house.fill" : "house")
                    .font(.system(size: 22))
            }

            // 中身・ラベルとも空にする。3項目均等配置のレイアウト上の「枠」だけを
            // ここで確保し、実際に見える撮影ボタン(常時緑のCameraApertureButton)は
            // ネイティブのテンプレート着色の影響を受けないよう、body側で
            // .overlay(alignment: .bottom)としてこの枠の真上に独立して重ねる。
            // .disabled(true)でこの枠自体がネイティブに選択されることを防いでいる
            // (以前はタップをこの枠へ素通りさせ、選択されたことをtabSelectionの
            // setterで打ち消す方式だったが、ネイティブTabViewが一瞬だけ本当に
            // このタブへ切り替わってしまい、空の中身(真っ黒画面)が一瞬見えてしまう
            // 不具合があった。撮影ボタンのタップは下のoverlay自身が直接処理する
            // ため、この枠は完全に非活性のレイアウト用プレースホルダーにする)。
            Tab(value: MainTabSelection.camera) {
                Color.clear
            } label: {
                Color.clear
            }
            .disabled(true)
        }
        // 文字ラベルは非表示にし、アイコンのみにする(直前までのアイコンオンリー表示を
        // 踏襲。VoiceOver用のラベル文字列自体はLabel(タイトル, systemImage:)に
        // そのまま残しているため、読み上げは維持される)。
        .labelStyle(.iconOnly)
        // 選択中タブのアイコンだけをテーマグリーンにする(HIGの「Liquid Glass上の
        // 色付けは強調したい要素だけに控えめに使う」原則)。非選択タブは標準のグレー/白のまま。
        .tint(Self.neonGreen)
        // 実機のアクセシビリティ文字サイズ設定(Dynamic Type)に関わらず、タブバーの
        // サイズ感をシミュレーターと常に一致させるため、標準サイズに固定する。
        .dynamicTypeSize(.large)
        .environment(\.selectedMainTabIndex, selectedTab)
        .overlay(alignment: .bottom) {
            // 実際に見える撮影ボタン本体。中身が空のcameraタブ(.disabled(true)で
            // ネイティブに選択されないようにしている)の真上に重ねる、それ自体が
            // タップを直接処理する独立したボタン。選択/非選択やテンプレート着色の
            // 影響を受けず、常にこの見た目のまま。タブバーのtoolbar自体とは無関係の
            // オーバーレイのため、自前の入力欄を持つ画面がtabBarVisibility.isHiddenを
            // trueにしている間はこちらも明示的に隠す。
            if !tabBarVisibility.isHidden {
                CameraApertureButton(isLocked: captureAvailability != .available, action: handleCaptureTap)
                    .offset(y: 8)
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
        .onChange(of: selectedTab) { _, _ in
            HapticsManager.swipeFeedback()
        }
        .onReceive(NotificationCenter.default.publisher(for: .photoNotificationTapped)) { _ in
            // 撮影通知(PhotoNotificationService)をタップした場合。GroupSelectionStore.
            // selectedGroupIDの更新はAppDelegate側で既に完了しており、ここではHomeタブへ
            // 切り替えるだけでよい(Home画面自体がGroupSelectionStoreを見て該当グループを表示する)。
            selectedTab = 0
        }
    }

    // MARK: - 撮影ボタンのタップ処理

    /// 実際の撮影処理(枚数上限・CloudKit保存・キャプション遷移)はTodayView側に
    /// 閉じたまま — CaptureRequestStore経由で「開いて」のシグナルを送るだけにし、
    /// ロジックの複製を避ける。撮影不可の状態(上限到達・投票中/終了後・未参加)では
    /// 遷移させず、.rigidハプティック+短いトーストでフィードバックする。
    private func handleCaptureTap() {
        switch captureAvailability {
        case .available:
            HapticsManager.shutterClick()
            selectedTab = 0
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
