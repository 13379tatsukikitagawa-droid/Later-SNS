import SwiftUI

/// コルクボード上のカード類(PolaroidPromptCard・PersonalTodayViewの今日のカード・
/// World地図カード)で共通して使う、緑のピン留めアイコン。
struct CorkboardPin: View {
    var size: CGFloat = 18

    var body: some View {
        Circle()
            .fill(Color.brandGreen)
            .frame(width: size, height: size)
            .overlay(Circle().stroke(.black.opacity(0.25), lineWidth: 1))
            .shadow(color: Color.brandGreen.opacity(0.4), radius: 3, x: 0, y: 2)
    }
}
