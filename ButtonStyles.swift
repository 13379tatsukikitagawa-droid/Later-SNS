import SwiftUI

// MARK: - BounceButtonStyle
/// ボタンを押したときに軽くバウンスするスタイル
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BounceButtonStyle {
    static var bounce: BounceButtonStyle {
        BounceButtonStyle()
    }
}
