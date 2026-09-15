import SwiftUI

/// ツールバーに表示する進捗バッジ
struct GoalProgressBadge: View {
    let current: Int
    let goal: Int
    
    private var isComplete: Bool {
        current >= goal
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(isComplete ? Color.brandGreen : .white.opacity(0.6))
            
            Text("\(current)/\(goal)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(isComplete ? Color.brandGreen : .white)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isComplete ? Color.brandGreen.opacity(0.2) : Color.white.opacity(0.1))
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    isComplete ? Color.brandGreen.opacity(0.4) : Color.white.opacity(0.2),
                    lineWidth: 1
                )
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isComplete)
    }
}

#if DEBUG
struct GoalProgressBadge_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            GoalProgressBadge(current: 0, goal: 3)
            GoalProgressBadge(current: 1, goal: 3)
            GoalProgressBadge(current: 2, goal: 3)
            GoalProgressBadge(current: 3, goal: 3)
            GoalProgressBadge(current: 5, goal: 5)
        }
        .padding()
        .background(Color.brandBlack)
    }
}
#endif
