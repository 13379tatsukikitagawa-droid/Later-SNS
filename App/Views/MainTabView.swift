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

/// TabViewの選択値。Home/Profileの2つは実際にコンテンツを持つ通常のタブ
/// (2026/9 新デザイン仕様「⑨⑩」のボトムナビに合わせ、World/PersonalはWave専用タブを
/// 廃止し、それぞれHomeヘッダーの地球儀アイコン/Profileヘッダーのグリッドアイコン
/// 経由でのプッシュ遷移にした)。cameraは撮影という単発アクションのための特殊枠で、
/// 選択されても画面は切り替わらず(MainTabView.tabSelectionのsetterがselectedTabを
/// 更新しない)、代わりに撮影可否に応じたアクション(撮影画面を開く/ロック案内を出す)
/// だけが起こる。
private enum MainTabSelection: Hashable {
    case home, camera, profile

    init(contentIndex: Int) {
        switch contentIndex {
        case 1: self = .profile
        default: self = .home
        }
    }
}

/// メインナビゲーション - Home / 撮影 / Profile の3項目のタブバー(ネイティブTabView、
/// iOS 26のLiquid Glass標準スタイル)。タブは「アプリのモード」だけを表し、見た目
/// (カプセル形状・ガラス質感・角丸・影)は一切自前で指定せず、システム標準の
/// 浮遊するガラスのタブバーにすべて委ねる。
///
/// 撮影はモードではなく単発のアクションだが、iPhoneの標準TabViewには「タブ群を
/// 左のカプセル・特定の1項目だけを右に独立したガラスボタンとして分離配置する」
/// 公開APIが`Tab(role: .search)`しか無い(Apple Musicの検索ボタンと同じ仕組み)。
/// 撮影ボタンをタブバー本体から見た目だけ独立させたいという要件を標準コンポーネント
/// だけで満たすため、意味的な用途は異なるがこの`role: .search`のピン留め挙動を
/// 撮影ボタンの配置に転用している(`.searchable`は付与しないため、検索固有の
/// 挙動は発生しない)。
struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var groups: [LaterGroup]
    @Query private var profiles: [UserProfile]

    @State private var selectedTab = 0

    @State private var showCaptureToast = false
    @State private var captureToastMessage = ""

    @ObservedObject private var tabBarVisibility = TabBarVisibilityStore.shared

    private static let accent = Color.laterAccent

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
    private var captureAvailability: CaptureAvailability {
        guard !userGroups.isEmpty else {
            return .blocked(message: "グループに参加すると撮影できます")
        }
        return .available
    }

    /// プロフィール画像(UserProfile.profileImageData)を円形にクリップして表示する
    /// オーバーレイ本体。ネイティブのタブ項目は写真のような非テンプレート画像を
    /// 正しく扱えず、実機のLiquid Glass選択ハイライト処理と衝突して崩れた表示になる
    /// ため、Tab自身のラベルには入れず独立したオーバーレイにしている。
    private var profilePhotoOverlay: some View {
        CachedPhotoImage(imageData: currentUser?.profileImageData, cacheKey: "avatar_\(currentUser?.id.uuidString ?? "me")") { uiImage in
            Image(uiImage: uiImage)
                .renderingMode(.original)
                .resizable()
                .scaledToFill()
                .frame(width: 26, height: 26)
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(
                        selectedTab == 1 ? Self.accent : Color.white.opacity(0.3),
                        lineWidth: 1.5
                    )
                )
        } placeholder: {
            EmptyView()
        }
    }

    /// TabViewのselectionはMainTabSelectionで受けるが、実体(コンテンツの表示切り替え)は
    /// 既存のselectedTab(Int, 0=ホーム/1=プロフィール)のまま。cameraが選ばれても
    /// selectedTabは更新せず(=見た目上どのタブも選択状態にならない)、代わりに
    /// 撮影アクションを直接発火する。
    private var tabSelection: Binding<MainTabSelection> {
        Binding(
            get: { MainTabSelection(contentIndex: selectedTab) },
            set: { newValue in
                switch newValue {
                case .camera:
                    handleCaptureTap()
                case .home:
                    selectedTab = 0
                case .profile:
                    selectedTab = 1
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

            Tab(value: MainTabSelection.profile) {
                ProfileFilmView()
            } label: {
                Label("プロフィール", systemImage: selectedTab == 1 ? "person.crop.circle.fill" : "person.crop.circle")
                    .font(.system(size: 22))
            }

            // 撮影ボタン。role: .searchによりHome/Profileのカプセルとは分離された、
            // 独立したガラスのボタンとしてタブバーの末尾(右側)に固定表示される。
            // 中身(content)はタップされても実際には表示されない(tabSelectionの
            // setterがselectedTabを更新しないため)ので、Color.clearでよい。
            Tab(value: MainTabSelection.camera, role: .search) {
                Color.clear
            } label: {
                Label(
                    captureAvailability == .available ? "撮影する" : "本日の撮影は終了しました",
                    systemImage: captureAvailability == .available ? "camera.aperture" : "lock.fill"
                )
                .font(.system(size: 22))
            }
        }
        // 文字ラベルは非表示にし、アイコンのみにする(VoiceOver用のラベル文字列自体は
        // Label(タイトル, systemImage:)にそのまま残しているため、読み上げは維持される)。
        .labelStyle(.iconOnly)
        // 選択中タブのアイコンだけをアクセントカラーにする(HIGの「Liquid Glass上の
        // 色付けは強調したい要素だけに控えめに使う」原則)。非選択タブは標準のグレー/白のまま。
        .tint(Self.accent)
        // 実機のアクセシビリティ文字サイズ設定(Dynamic Type)に関わらず、タブバーの
        // サイズ感をシミュレーターと常に一致させるため、標準サイズに固定する。
        .dynamicTypeSize(.large)
        .environment(\.selectedMainTabIndex, selectedTab)
        .overlay(alignment: .bottom) {
            // プロフィール写真本体。Home/Profileの2等分レイアウトの右列中央へ重ねる
            // (Profileタブ自身のアイコンの真上)。タップは受け取らず、下にある本来の
            // profileタブ自身のタップに委ねる。
            HStack(spacing: 0) {
                Color.clear.frame(maxWidth: .infinity)
                if !tabBarVisibility.isHidden {
                    profilePhotoOverlay
                        .frame(maxWidth: .infinity)
                } else {
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
            .allowsHitTesting(false)
            .offset(y: 8)
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
        .onReceive(NotificationCenter.default.publisher(for: .switchToProfileTabRequested)) { _ in
            // World画面(Homeの上のモーダル)のボトムナビからプロフィールが押された場合。
            selectedTab = 1
        }
    }

    // MARK: - 撮影ボタンのタップ処理

    /// 実際の撮影処理(1日1枚の判定・CloudKit保存)はTodayView/ExposureCameraView側に
    /// 閉じたまま — CaptureRequestStore経由で「開いて」のシグナルを送るだけにし、
    /// ロジックの複製を避ける。撮影不可の状態(上限到達・未参加)では遷移させず、
    /// .rigidハプティック+短いトーストでフィードバックする。
    private func handleCaptureTap() {
        switch captureAvailability {
        case .available:
            // 触覚は撮影画面の中(長押し・撮影の瞬間)だけで使うため、ここでは振動させない。
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
