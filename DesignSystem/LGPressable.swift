import SwiftUI

/// 押すと 沈む / ふくらむ ボタン。押せる 範囲は 44 × 44pt 以上。
struct LGPressableStyle: ButtonStyle {
    enum Mode { case sink, swell }
    var mode: Mode = .sink
    var haptic: Haptics.Kind? = .tick

    func makeBody(configuration: Configuration) -> some View {
        let scale: CGFloat = mode == .sink ? 0.94 : 1.08
        configuration.label
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(LGMotion.bounce(0.22), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed, let haptic { Haptics.play(haptic) }
            }
    }
}

extension ButtonStyle where Self == LGPressableStyle {
    static var lgPressable: LGPressableStyle { LGPressableStyle() }
    static func lgPressable(_ mode: LGPressableStyle.Mode, haptic: Haptics.Kind? = .tick) -> LGPressableStyle {
        LGPressableStyle(mode: mode, haptic: haptic)
    }
}
