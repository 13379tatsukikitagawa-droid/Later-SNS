import SwiftUI

/// 🎨 ロックシステムのデモ・説明用ビュー
struct DailyGoalLockSystemDemo: View {
    @State private var currentStep = 0
    @State private var simulatedPhotos = 0
    @State private var showLockDemo = false
    
    private let goal = 3
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // タイトル
                    VStack(spacing: 8) {
                        Text("🔒 Daily Goal Lock System")
                            .font(.title.bold())
                            .foregroundStyle(.white)
                        
                        Text("目標達成時の撮影ロックデモ")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 40)
                    
                    Spacer()
                    
                    // 現在の状態
                    currentStateView
                    
                    Spacer()
                    
                    // ステップ説明
                    stepExplanationView
                    
                    // アクションボタン
                    actionButtonsView
                        .padding(.bottom, 40)
                }
                .padding()
                
                // ロック演出デモ
                if showLockDemo {
                    DailyGoalLockOverlay(photosTaken: goal, goal: goal) {
                        showLockDemo = false
                        currentStep = 4
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Current State View
    
    private var currentStateView: some View {
        VStack(spacing: 20) {
            // 進捗表示
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 150, height: 150)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        simulatedPhotos >= goal ? Color.brandGreen : Color.blue,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: simulatedPhotos)
                
                VStack(spacing: 4) {
                    Text("\(simulatedPhotos)")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("/ \(goal)")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            // 状態テキスト
            statusTextView
        }
    }
    
    private var progress: CGFloat {
        CGFloat(simulatedPhotos) / CGFloat(goal)
    }
    
    private var statusTextView: some View {
        VStack(spacing: 8) {
            switch currentStep {
            case 0:
                Label("準備完了", systemImage: "checkmark.circle")
                    .foregroundStyle(.white)
            case 1...2:
                Label("撮影中...", systemImage: "camera.fill")
                    .foregroundStyle(.blue)
            case 3:
                Label("最後の一枚！", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            case 4:
                Label("ロック完了", systemImage: "lock.fill")
                    .foregroundStyle(.brandGreen)
            default:
                EmptyView()
            }
        }
        .font(.headline)
    }
    
    // MARK: - Step Explanation
    
    private var stepExplanationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("現在のステップ")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
            
            Text(stepDescription)
                .font(.body)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var stepDescription: String {
        switch currentStep {
        case 0:
            return "目標は\(goal)枚です。「撮影」ボタンをタップして写真を撮りましょう。"
        case 1:
            return "1枚目を撮影しました。あと\(goal - simulatedPhotos)枚です。"
        case 2:
            return "2枚目を撮影しました。次が最後です！"
        case 3:
            return "最後の一枚を撮影すると、ロック演出が発動します。"
        case 4:
            return "🎉 目標達成！撮影機能が完全にロックされました。翌日までお待ちください。"
        default:
            return ""
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            if currentStep < 4 {
                // 撮影ボタン
                Button {
                    takePhoto()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                        Text(currentStep == 3 ? "最後の一枚を撮影！" : "撮影する")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        currentStep == 3 
                            ? Color.orange
                            : Color.brandGreen
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else {
                // ロック状態
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                    Text("撮影完了")
                        .font(.headline.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.gray.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            // リセットボタン
            Button {
                resetDemo()
            } label: {
                Text("デモをリセット")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Actions
    
    private func takePhoto() {
        guard simulatedPhotos < goal else { return }
        
        // ハプティクス
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // 撮影枚数を増やす
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            simulatedPhotos += 1
            currentStep += 1
        }
        
        // 目標達成時の処理
        if simulatedPhotos >= goal {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showLockDemo = true
                }
            }
        }
    }
    
    private func resetDemo() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            currentStep = 0
            simulatedPhotos = 0
            showLockDemo = false
        }
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
}

#Preview {
    DailyGoalLockSystemDemo()
}
