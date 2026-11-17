import SwiftUI

/// タブバーの代わり。行き先は Home と「あなた」(Profile)の2つだけなので、画面の下に帯は置かない。
/// Profileへは、Homeの右上のアバターのタップ、または画面の端(左右24pt以内)から始めた左へのスワイプで行く。
/// グループの列など、横に動くものの中で始めた指では開かない(v2.1:列のスクロールで誤って開いていた)。
/// 戻るのは、Profileの左上の「<」か、右へのスワイプ。切り替えで振動はしない。
struct MainNavigationView: View {
    private enum Screen {
        /// v54:Profile(あなた)と ME(Recap・7日)は 別の 画面。右上の 丸は Profile だけ ひらく
        case home, profile, me
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var screen: Screen = .home
    /// Profileの全画面ビューアが開いている間は、スワイプで画面を切りかえない
    @State private var isProfileViewerOpen = false
    /// Homeの中で、横の動きをその場所に任せる範囲(グループの列など。画面の座標)
    @State private var homeNoSwipeRegions: [CGRect] = []

    /// スワイプとみなす横の移動量
    private static let swipeThreshold: CGFloat = 70
    /// Profileを開くスワイプ:始める位置(画面の左右の端から)・距離・角度(水平から20°以内)
    static let edgeWidth: CGFloat = 24
    static let openDistance: CGFloat = 40
    static let maxAngleDegrees: Double = 20

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack {
                Color.black.ignoresSafeArea()

                // 幅は、ここで決めた width の1つだけ。中の画面が横に広くなっても、Home を右へずらさない
                TodayView(onOpenProfile: { show(.profile) }, onOpenMe: { show(.me) })
                    .frame(width: width)
                    .offset(x: screen != .home && !reduceMotion ? -width * 0.3 : 0)
                    .opacity(screen == .home ? 1 : 0)
                    .allowsHitTesting(screen == .home)
                    .simultaneousGesture(openProfileSwipe(width: width))
                    .onPreferenceChange(HomeNoSwipeRegionKey.self) { homeNoSwipeRegions = $0 }

                // v54:Profile(あなた)。右上の 丸・端スワイプから。右から 横に すべって 出る
                ProfileShelfView(
                    onBack: { show(.home) },
                    onShoot: {
                        show(.home)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            CaptureRequestStore.shared.pendingRequestID = UUID()
                        }
                    }
                )
                    .frame(width: width)
                    .offset(x: screen == .profile ? 0 : width)
                    .opacity(screen == .profile ? 1 : 0)
                    .allowsHitTesting(screen == .profile)
                    .simultaneousGesture(swipe(toward: .home))
                    .accessibilityHidden(screen != .profile)
                    .onPreferenceChange(ProfileViewerOpenKey.self) { isProfileViewerOpen = $0 }

                // v14 ③:ME 画面(Recap・7日)。タップした位置(ME カード・ALBUMS 見出し)から円形に広がって出る(0.7秒)。
                // 戻るときは、薄くなりながら縮む(0.4秒)。右上の 丸(アバター)は Profile を ひらく(ME とは 別)
                MEScreenV19(
                    onBack: { show(.home) },
                    onShoot: {
                        // Home に戻って、撮影の流れ(タグ → 撮影)をひらく
                        show(.home)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            CaptureRequestStore.shared.pendingRequestID = UUID()
                        }
                    }
                )
                    .frame(width: width)
                    .modifier(CircleReveal(isOpen: screen == .me, origin: MERevealOrigin.point ?? CGPoint(x: width - 44, y: 90)))
                    .allowsHitTesting(screen == .me)
                    .simultaneousGesture(swipe(toward: .home))
                    .accessibilityHidden(screen != .me)
            }
        }
        // HomeView・ProfileFilmViewは、見えている時だけアニメーションや同期を動かす。
        .environment(\.selectedMainTabIndex, screen == .home ? 0 : 1)
        .onReceive(NotificationCenter.default.publisher(for: .photoNotificationTapped)) { _ in
            // 撮影通知をタップした場合は、Homeへ戻す。
            show(.home)
        }
        .onReceive(NotificationCenter.default.publisher(for: .replayLaunchAnimation)) { _ in
            show(.home)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openGroupRequested)) { _ in
            show(.home)
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToProfileTabRequested)) { _ in
            show(.profile)
        }
    }

    private func show(_ target: Screen) {
        guard target != screen else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .easeOut(duration: 0.4)) {
            screen = target
        }
    }

    /// Homeで、画面の端から始めた左へのスワイプでProfileを開く。
    /// 列の中で始めた指・端でない場所から始めた指・斜めの動き・短い動きでは開かない。
    private func openProfileSwipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .global)
            .onEnded { value in
                guard screen == .home else { return }
                let opens = Self.shouldOpenProfile(
                    start: value.startLocation,
                    translation: value.translation,
                    screenWidth: width,
                    excluded: homeNoSwipeRegions
                )
                if opens { show(.profile) }
            }
    }

    /// Profileを開くかどうか(テストできるよう、判定だけを分ける)
    static func shouldOpenProfile(start: CGPoint, translation: CGSize, screenWidth: CGFloat, excluded: [CGRect]) -> Bool {
        let fromEdge = start.x <= edgeWidth || start.x >= screenWidth - edgeWidth
        guard fromEdge, !excluded.contains(where: { $0.contains(start) }) else { return false }
        let dx = translation.width, dy = translation.height
        guard dx < 0, -dx >= openDistance else { return false }
        return abs(dy) <= -dx * tan(maxAngleDegrees * .pi / 180)
    }

    /// Profile・ME では 右への スワイプで Home へ戻る(横の動きが 縦より 大きい時だけ)。
    private func swipe(toward target: Screen) -> some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width, dy = value.translation.height
                guard !isProfileViewerOpen, abs(dx) > abs(dy) * 1.5, abs(dx) > Self.swipeThreshold else { return }
                switch target {
                case .profile where dx < 0 && screen == .home: show(.profile)
                case .home where dx > 0 && screen != .home: show(.home)
                default: break
                }
            }
    }
}

/// Homeの中で「その場所で始めた横の動きは、その場所のもの」にする範囲(画面の座標)。
/// ここで始めた指では、Profileを開くスワイプが反応しない。
struct HomeNoSwipeRegionKey: PreferenceKey {
    static let defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - いま選ばれているタブ(0 = Home。以前は MainTabView.swift にあった)

struct SelectedMainTabIndexKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    var selectedMainTabIndex: Int {
        get { self[SelectedMainTabIndexKey.self] }
        set { self[SelectedMainTabIndexKey.self] = newValue }
    }
}
