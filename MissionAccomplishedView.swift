import SwiftUI

/// 🎉 目標達成時に表示する「Mission Accomplished!」画面
struct MissionAccomplishedView: View {
    let photosTaken: Int
    let goal: Int
    var onDismiss: () -> Void
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var confettiTrigger = false
    
    var body: some View {
        ZStack {
            // 背景（半透明の黒）
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            VStack(spacing: 30) {
                // トロフィーアイコン
                Image(systemName: "trophy.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.brandGreen, Color.brandGreen.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(scale)
                    .opacity(opacity)
                
                // メインメッセージ
                VStack(spacing: 12) {
                    Text("Mission Accomplished!")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("今日の目標 \(goal) 枚を達成しました！")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.brandGreen)
                        .multilineTextAlignment(.center)
                    
                    Text("素晴らしい思い出を残せましたね✨")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .scaleEffect(scale)
                .opacity(opacity)
                
                // 統計情報
                HStack(spacing: 30) {
                    MissionStatItem(icon: "camera.fill", value: "\(photosTaken)", label: "撮影枚数")
                    MissionStatItem(icon: "checkmark.circle.fill", value: "\(goal)", label: "目標達成")
                }
                .scaleEffect(scale)
                .opacity(opacity)
                
                // 閉じるボタン
                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.brandGreen)
                        .clipShape(Capsule())
                }
                .padding(.top, 20)
                .scaleEffect(scale)
                .opacity(opacity)
            }
            .padding()
        }
        .onAppear {
            // アニメーション開始
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // 触覚フィードバック
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
            
            // 連続ハプティクス（お祝い）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            scale = 0.8
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

/// 統計表示アイテム
private struct MissionStatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(Color.brandGreen)
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(width: 120)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    MissionAccomplishedView(photosTaken: 3, goal: 3) {
        print("Dismissed")
    }
}
