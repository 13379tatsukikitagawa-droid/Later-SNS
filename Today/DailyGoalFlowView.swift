import SwiftUI
import SwiftData

struct DailyGoalFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let profile: UserProfile
    var onFinish: (() -> Void)?
    
    @State private var goal: Int = 3
    
    private let minGoal = 1
    private let maxGoal = 10

    var body: some View {
        ZStack {
            // Background
            Color.brandBlack
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                closeButton
                Spacer()
                headerSection
                goalSelector
                Spacer()
                confirmButton
            }
            .padding(.top, 20)
        }
        .onAppear {
            goal = min(max(profile.dailyGoal, minGoal), maxGoal)
        }
    }
    
    // MARK: - View Components
    
    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.gray.opacity(0.6))
            }
        }
        .padding(.horizontal)
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.metering.center.weighted")
                .font(.system(size: 56))
                .foregroundStyle(.brandGreen)
                .symbolEffect(.bounce, value: goal)
            
            Text("今日の目標枚数")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            
            Text("1日に撮影する枚数を決めましょう。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }
    
    private var goalSelector: some View {
        VStack(spacing: 20) {
            Text("\(goal) 枚")
                .font(.system(size: 48, weight: .heavy))
                .foregroundStyle(.brandGreen)
                .contentTransition(.numericText())
            
            HStack(spacing: 32) {
                adjustButton(
                    systemName: "minus.circle.fill",
                    isEnabled: goal > minGoal,
                    action: { goal -= 1 }
                )
                
                adjustButton(
                    systemName: "plus.circle.fill",
                    isEnabled: goal < maxGoal,
                    action: { goal += 1 }
                )
            }
            
            Text(motivationalMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .animation(.easeInOut, value: goal)
                .frame(height: 20)
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 40)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    
    private func adjustButton(
        systemName: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.bouncy) {
                action()
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 50))
                .foregroundStyle(isEnabled ? .white : .white.opacity(0.3))
        }
        .disabled(!isEnabled)
    }
    
    private var confirmButton: some View {
        Button(action: saveGoalAndDismiss) {
            HStack(spacing: 8) {
                Text("これで始める")
                    .font(.headline)
                Image(systemName: "arrow.right")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.brandGreen)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
    
    // MARK: - Computed Properties
    
    private var motivationalMessage: String {
        switch goal {
        case 1:
            return "少しずつ、無理なく続けましょう"
        case 2...3:
            return "程よいペースで習慣化できます"
        case 4...5:
            return "素晴らしい目標です！"
        case 6...7:
            return "かなり意欲的な目標ですね"
        case 8...10:
            return "挑戦的な目標！頑張りましょう"
        default:
            return "あとから設定で変更できます"
        }
    }
    
    // MARK: - Actions
    
    private func saveGoalAndDismiss() {
        profile.dailyGoal = goal
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save goal: \(error)")
        }
        
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.2))
            onFinish?()
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview("目標設定フロー") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, configurations: config)
    let profile = UserProfile(name: "テストユーザー", username: "testuser")
    container.mainContext.insert(profile)
    
    return DailyGoalFlowView(profile: profile)
        .modelContainer(container)
}

