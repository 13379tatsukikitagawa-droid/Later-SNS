import SwiftUI

struct GoalSettingView: View {
    // 永続化: その日の目標枚数
    @AppStorage("dailyGoal") private var dailyGoal: Int = 3
    @AppStorage("countdownStartDate") private var countdownStartDate: String = ""
    @AppStorage("dailyGoalCount") private var dailyGoalCount: Int = 0
    @AppStorage("lastGoalSettingDate") private var lastGoalSettingDate: String = ""
    // 一時選択状態
    @State private var selectedGoal: Int = 3
    // 完了時に外側で遷移などを行いたい場合に使用
    var onComplete: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
        // 初期選択は保存値に合わせる
        _selectedGoal = State(initialValue: UserDefaults.standard.integer(forKey: "dailyGoal").nonZeroOr(3))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                content
            }
            .navigationTitle("目標設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var content: some View {
        VStack(spacing: 24) {
            header
            selectionRow
            tipText
            Spacer()
            decideButton
        }
        .padding(20)
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            Text("今日の目標枚数を選択")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("1〜5枚の中から選べます。いつでも変更できます")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }
    
    private var selectionRow: some View {
        HStack(spacing: 12) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedGoal = value
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text("\(value)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("枚")
                            .font(.caption)
                            .opacity(0.8)
                    }
                    .frame(width: 64, height: 64)
                    .foregroundStyle(selectedGoal == value ? .white : .white.opacity(0.8))
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selectedGoal == value ? Color.brandGreen : Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(selectedGoal == value ? Color.brandGreen.opacity(0.6) : Color.white.opacity(0.12), lineWidth: selectedGoal == value ? 2 : 1)
                    )
                    .shadow(color: selectedGoal == value ? Color.brandGreen.opacity(0.3) : .clear, radius: 10, x: 0, y: 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }
    
    private var tipText: some View {
        Text("目標は後から設定画面で変更できます")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }
    
    private var decideButton: some View {
        Button {
            // 保存
            dailyGoal = selectedGoal
            // カウントダウン開始（今日のキーを保存）
            let fmt = DateFormatter()
            fmt.calendar = Calendar.current
            fmt.locale = Locale.current
            fmt.timeZone = TimeZone.current
            fmt.dateFormat = "yyyy-MM-dd"
            countdownStartDate = fmt.string(from: Date())
            dailyGoalCount = selectedGoal
            lastGoalSettingDate = countdownStartDate
            // ハプティクス
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            // 完了
            if let onComplete { onComplete() } else { dismiss() }
        } label: {
            Text("この枚数で決定")
                .font(.headline.bold())
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [Color.brandGreen, Color.brandGreen.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.brandGreen.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private extension Int {
    func nonZeroOr(_ fallback: Int) -> Int {
        self == 0 ? fallback : self
    }
}

#Preview {
    GoalSettingView()
}
