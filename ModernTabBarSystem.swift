import SwiftUI

// MARK: - Floating Tab Bar
/// Material背景の浮遊感のあるカスタムタブバー

struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    let photosTaken: Int
    let dailyGoal: Int = 5
    
    var body: some View {
        HStack(spacing: 0) {
            // ホームタブ
            ModernTabBarButton(
                icon: "house.fill",
                title: "ホーム",
                isSelected: selectedTab == 0
            ) {
                withAnimation(.spring(response: 0.3)) {
                    selectedTab = 0
                }
            }
            
            Spacer()
            
            // QRスキャンタブ
            ModernTabBarButton(
                icon: "qrcode.viewfinder",
                title: "スキャン",
                isSelected: selectedTab == 1
            ) {
                withAnimation(.spring(response: 0.3)) {
                    selectedTab = 1
                }
            }
            
            Spacer()
            
            // 中央のカメラボタン（スペース確保）
            Color.clear
                .frame(width: 80)
            
            Spacer()
            
            // 友達タブ
            ModernTabBarButton(
                icon: "person.2.fill",
                title: "友達",
                isSelected: selectedTab == 3
            ) {
                withAnimation(.spring(response: 0.3)) {
                    selectedTab = 3
                }
            }
            
            Spacer()
            
            // プロフィールタブ
            ModernTabBarButton(
                icon: "person.fill",
                title: "設定",
                isSelected: selectedTab == 4
            ) {
                withAnimation(.spring(response: 0.3)) {
                    selectedTab = 4
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        )
        .overlay {
            // 中央のカメラボタン
            CameraButton(
                photosTaken: photosTaken,
                dailyGoal: dailyGoal
            ) {
                withAnimation(.spring(response: 0.3)) {
                    selectedTab = 2
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Modern Tab Bar Button

struct ModernTabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        isSelected ?
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [.white.opacity(0.6), .white.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.bounce, value: isSelected)
                
                Text(title)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Camera Button

struct CameraButton: View {
    let photosTaken: Int
    let dailyGoal: Int
    let action: () -> Void
    
    @State private var isPulsing = false
    
    private var progress: Double {
        min(Double(photosTaken) / Double(dailyGoal), 1.0)
    }
    
    var body: some View {
        Button(action: {
            // ハプティックフィードバック（重厚な振動）
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            
            action()
        }) {
            ZStack {
                // プログレスリング（外側）
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: 6)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .blue.opacity(0.6), radius: 8)
                
                // カメラボタン本体
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: .blue.opacity(0.5), radius: 10, y: 5)
                    .overlay(
                        Circle()
                            .fill(.white)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                    )
                
                // 目標達成時のバッジ
                if photosTaken >= dailyGoal {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Circle()
                                .fill(.green)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                                .shadow(color: .green.opacity(0.6), radius: 4)
                                .offset(x: 4, y: 4)
                        }
                    }
                    .frame(width: 80, height: 80)
                }
            }
        }
        .offset(y: -30)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Main Container View

struct ModernMainContainerView: View {
    @State private var selectedTab: Int = 0
    @State private var photosTaken: Int = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // メインコンテンツ
            Group {
                switch selectedTab {
                case 0:
                    ModernHomeView()
                case 1:
                    ModernScannerView()
                case 2:
                    ModernCameraView(photosTaken: $photosTaken)
                case 3:
                    ModernFriendsView()
                case 4:
                    ModernProfileView()
                default:
                    ModernHomeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // フローティングタブバー
            FloatingTabBar(selectedTab: $selectedTab, photosTaken: photosTaken)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Modern Camera View

struct ModernCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var photosTaken: Int
    @State private var showingCapture = false
    
    let dailyGoal: Int = 5
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // ヘッダー
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding()
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text("\(photosTaken) / \(dailyGoal)")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                        
                        Text("今日の撮影")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding()
                }
                
                Spacer()
                
                // カメラプレビュー（実装時はAVFoundationを使用）
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.1))
                    .overlay(
                        VStack(spacing: 16) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.3))
                            
                            Text("カメラプレビュー")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    )
                    .padding()
                
                Spacer()
                
                // シャッターボタン
                shutterButton
                    .padding(.bottom, 40)
            }
        }
        .alert("撮影完了", isPresented: $showingCapture) {
            Button("OK") {
                photosTaken += 1
                
                // 目標達成時のハプティック
                if photosTaken >= dailyGoal {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error) // 金庫が閉まるような強力な振動
                }
            }
        } message: {
            Text("写真を撮影しました")
        }
    }
    
    private var shutterButton: some View {
        Button {
            // 撮影時のハプティック（重厚な振動）
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            
            showingCapture = true
        } label: {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 6)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .fill(.white)
                    .frame(width: 64, height: 64)
            }
        }
    }
}

// MARK: - Modern Scanner View

struct ModernScannerView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                
                Text("QRスキャナー")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("友達のQRコードをスキャン")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - Modern Friends View

struct ModernFriendsView: View {
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white.opacity(0.3))
                
                Text("友達リスト")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("フォロー中のユーザー")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - Modern Profile View

struct ModernProfileView: View {
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "person.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white.opacity(0.3))
                
                Text("プロフィール")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("設定とアカウント情報")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - Preview

#Preview("Floating Tab Bar") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            FloatingTabBar(selectedTab: .constant(0), photosTaken: 3)
        }
    }
}

#Preview("Main Container") {
    ModernMainContainerView()
}

#Preview("Camera View") {
    ModernCameraView(photosTaken: .constant(2))
}
