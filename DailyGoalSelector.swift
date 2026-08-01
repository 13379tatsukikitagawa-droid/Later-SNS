import SwiftUI

struct DailyGoalSelector: View {
    @AppStorage("dailyGoal") private var dailyGoal: Int = 5
    @AppStorage("lastGoalSettingDate") private var lastGoalSettingDate: String = ""
    
    @State private var selectedCount: Int? = nil
    @State private var animatingNumber: Int? = nil
    @State private var showCamera: Bool = false
    @State private var photoManager = PhotoManager.shared
    
    var onMissionStart: () -> Void
    
    var body: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // メッセージ
                VStack(spacing: 12) {
                    Text("今日は何枚の思い出を残す？")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("目標を決めて、素敵な一日を記録しよう")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                // 枚数選択
                HStack(spacing: 16) {
                    ForEach(1...5, id: \.self) { number in
                        NumberButton(
                            number: number,
                            isSelected: selectedCount == number,
                            isAnimating: animatingNumber == number
                        ) {
                            selectNumber(number)
                        }
                    }
                }
                .padding(.horizontal)
                
                // ミッション開始ボタン
                Button {
                    startMission()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                        Text("ミッション開始")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(selectedCount != nil ? Color.brandBlack : .white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        selectedCount != nil 
                            ? Color.brandGreen 
                            : Color.white.opacity(0.1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(selectedCount == nil)
                .padding(.horizontal, 32)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedCount)
                
                Spacer()
            }
        }
    }
    
    private func selectNumber(_ number: Int) {
        // 選択状態を更新
        selectedCount = number
        
        // アニメーションをトリガー
        animatingNumber = number
        
        // 触覚フィードバック
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // アニメーション状態をリセット
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            animatingNumber = nil
        }
    }
    
    private func startMission() {
        guard let count = selectedCount else { return }
        
        // 保存処理（キーを統一）
        dailyGoal = count
        lastGoalSettingDate = CountdownBanner.todayKey()
        
        // PhotoManagerにも同期（dailyLimitを更新）
        // 注: UserProfileがない場合はAppStorageの値を使用
        Task { @MainActor in
            photoManager.resetIfNewDay()
        }
        
        // 触覚フィードバック
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
        
        // アニメーション付きで遷移
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showCamera = true
        }
        
        // コールバック実行
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onMissionStart()
        }
    }
}

private struct NumberButton: View {
    let number: Int
    let isSelected: Bool
    let isAnimating: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(number)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? Color.brandBlack : .white)
                .frame(width: 64, height: 64)
                .background(
                    Circle()
                        .fill(isSelected ? Color.brandGreen : Color.white.opacity(0.1))
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.brandGreen.opacity(0.3) : Color.white.opacity(0.2),
                            lineWidth: 2
                        )
                )
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(
                    isAnimating 
                        ? .spring(response: 0.3, dampingFraction: 0.4, blendDuration: 0)
                        : .spring(response: 0.3, dampingFraction: 0.7),
                    value: isAnimating
                )
        }
        .buttonStyle(DailyGoalBouncyButtonStyle())
    }
}

private struct DailyGoalBouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    DailyGoalSelector {
        print("Mission started!")
    }
}
