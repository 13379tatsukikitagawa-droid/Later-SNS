import SwiftUI

/// タブバーの代わり。行き先は Home と「あなた」(Profile)の2つだけなので、画面の下に帯は置かない。
/// Profileへは、Homeの右上のアバターのタップ、または左へのスワイプで行く。
/// 戻るのは、Profileの左上の「<」か、右へのスワイプ。切り替えで振動はしない。
struct MainNavigationView: View {
    private enum Screen {
        case home, profile
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var screen: Screen = .home

    /// スワイプとみなす横の移動量
    private static let swipeThreshold: CGFloat = 70

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack {
                Color.black.ignoresSafeArea()

                TodayView(onOpenProfile: { show(.profile) })
                    .offset(x: screen == .profile && !reduceMotion ? -width * 0.3 : 0)
                    .opacity(screen == .home ? 1 : 0)
                    .allowsHitTesting(screen == .home)
                    .simultaneousGesture(swipe(toward: .profile))

                ProfileImmersiveView(onBack: { show(.home) })
                    .offset(x: screen == .profile || reduceMotion ? 0 : width)
                    .opacity(screen == .profile ? 1 : 0)
                    .allowsHitTesting(screen == .profile)
                    .simultaneousGesture(swipe(toward: .home))
                    .accessibilityHidden(screen != .profile)
            }
        }
        // HomeView・ProfileImmersiveViewは、見えている時だけアニメーションや同期を動かす。
        .environment(\.selectedMainTabIndex, screen == .home ? 0 : 1)
        .onReceive(NotificationCenter.default.publisher(for: .photoNotificationTapped)) { _ in
            // 撮影通知をタップした場合は、Homeへ戻す。
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

    /// Homeでは左へ、Profileでは右へのスワイプで切り替える(横の動きが縦より大きい時だけ)。
    private func swipe(toward target: Screen) -> some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width, dy = value.translation.height
                guard abs(dx) > abs(dy) * 1.5, abs(dx) > Self.swipeThreshold else { return }
                switch target {
                case .profile where dx < 0 && screen == .home: show(.profile)
                case .home where dx > 0 && screen == .profile: show(.home)
                default: break
                }
            }
    }
}
