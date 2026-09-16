import SwiftUI

/// ダークパネル(#2c2116=corkboardTabActive)カードの中にラベル+入力欄を配置し、
/// 下線を緑にする共通の入力欄カード。EmailSignInView・JoinGroupByLinkViewなど、
/// コルクボード系のダーク画面での1行テキスト入力で使い回す。
struct DarkFieldCard<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.corkboardTabInactiveText)

            content()
                .font(.system(size: 16, weight: .medium))
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.brandGreen.opacity(0.7))
                        .frame(height: 1.5)
                }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.corkboardTabActive))
    }
}
