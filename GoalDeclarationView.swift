import SwiftUI

struct GoalDeclarationView: View {
    let currentGoal: Int
    var onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 28) {
                Text("今日のミッション")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(.white)
                Text("今日は \(currentGoal) 枚 撮影します")
                    .font(.system(size: 34, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("宣言してから撮影に進みましょう")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.7))

                Button(action: onConfirm) {
                    Text("宣言して撮影に進む")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.top, 10)
            }
            .padding(28)
        }
    }
}

#Preview {
    GoalDeclarationView(currentGoal: 3) {}
}
