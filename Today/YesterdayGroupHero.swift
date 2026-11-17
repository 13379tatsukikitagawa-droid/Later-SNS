import SwiftUI
import UIKit

/// バイブ(表どおり)。設定で 切っていれば 鳴らさない
enum YesterdayHeroHaptics {
    static func light() { guard Haptics.isEnabled else { return }; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func rigid() { guard Haptics.isEnabled else { return }; UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func selection() { guard Haptics.isEnabled else { return }; UISelectionFeedbackGenerator().selectionChanged() }
    /// ドクン:medium → 0.12秒後に light
    static func heartbeat() {
        guard Haptics.isEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { light() }
    }
}

/// 下から 26pt 浮いて 出る(バイブなし)。token が かわるたびに もう一度。「視差を減らす」は フェードだけ
struct YesterdayRise: ViewModifier {
    let delay: Double
    let token: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = true

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 26)
            .onChange(of: token) { _, _ in
                var hide = Transaction()
                hide.disablesAnimations = true
                withTransaction(hide) { shown = false }
                let animation: Animation = reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.55, dampingFraction: 0.72).delay(delay)
                // 消すのと 出すのを 同じ更新に まとめない(まとめると 動かない)
                DispatchQueue.main.async { withAnimation(animation) { shown = true } }
            }
    }
}

extension View {
    func yesterdayRise(_ delay: Double, token: Int) -> some View { modifier(YesterdayRise(delay: delay, token: token)) }
}
