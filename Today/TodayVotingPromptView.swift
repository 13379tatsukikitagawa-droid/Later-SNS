import SwiftUI

/// 投票中(グループが解禁され、投票が締め切られていない)の画面内容。
/// 中央の横長ボタンからGroupVotingViewをシート表示する。
struct TodayVotingPromptView: View {
    let onStartVoting: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.brandGreen)

                Text("今日の写真が解禁されました")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button(action: onStartVoting) {
                HStack(spacing: 10) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 20, weight: .bold))
                    Text("今日の一枚に投票する")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(Color.brandBlack)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.brandGreen, Color.brandGreen.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.brandGreen.opacity(0.4), radius: 20, x: 0, y: 10)
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding()
    }
}
