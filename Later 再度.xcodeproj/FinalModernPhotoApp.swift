import SwiftUI
import Combine

// MARK: - Final Modern Photo App
/// すべてのエラーを修正し、達成状況を統合した最終版アプリ
/// Note: メインのエントリポイントは LaterApp.swift に定義されています

// @main コメントアウト - LaterApp.swift がメインエントリポイントとして使用されます
// この App 構造体の機能は LaterApp.swift に統合されています

// MARK: - App Setup Functions
/// アプリの初期化処理（LaterApp から呼び出し可能）

func setupFinalModernPhotoApp() {
    // 通知の設定
    _ = GlobalRevealNotificationHandler.shared
    
    // バックグラウンド同期
    GlobalRevealBackgroundSyncTask.shared.registerBackgroundTask()
    GlobalRevealBackgroundSyncTask.shared.scheduleNextBackgroundSync()
    
    // ハプティクスの準備
    let generator = UIImpactFeedbackGenerator(style: .heavy)
    generator.prepare()
}

// MARK: - Final Main Container View

struct FinalMainContainerView: View {
    @State private var selectedTab: Int = 0
    @State private var achievementManager = PhotoAchievementManager.shared
    
    private var todayPhotoCount: Int {
        achievementManager.getPhotoCount(for: Date())
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // メインコンテンツ
            Group {
                switch selectedTab {
                case 0:
                    EnhancedHomeView()
                case 1:
                    ModernScannerView()
                case 2:
                    FinalCameraView()
                case 3:
                    ModernFriendsView()
                case 4:
                    ModernProfileView()
                default:
                    EnhancedHomeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // フローティングタブバー
            FinalFloatingTabBar(
                selectedTab: $selectedTab,
                photosTaken: todayPhotoCount
            )
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Final Floating Tab Bar (エラー修正版)

struct FinalFloatingTabBar: View {
    @Binding var selectedTab: Int
    let photosTaken: Int
    @State private var achievementManager = PhotoAchievementManager.shared
    
    private var dailyGoal: Int {
        achievementManager.dailyGoal
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // ホームタブ
            TabBarButton(
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
            TabBarButton(
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
            TabBarButton(
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
            TabBarButton(
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
            FinalCameraButton(
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

// MARK: - Final Camera Button (エラー修正版)

struct FinalCameraButton: View {
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
    }
}

// MARK: - Final Camera View (エラー修正版)

struct FinalCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var achievementManager = PhotoAchievementManager.shared
    @State private var showingCapture = false
    
    private var photosTaken: Int {
        achievementManager.getPhotoCount(for: Date())
    }
    
    private var dailyGoal: Int {
        achievementManager.dailyGoal
    }
    
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
                // 撮影枚数を増やす
                achievementManager.incrementPhotoCount(for: Date())
                
                // 目標達成時のハプティック
                if achievementManager.hasAchievedGoal(for: Date()) {
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

// MARK: - Swipe Gesture Handler
// Note: SwipeGestureHandler は AdvancedEffectsSystem.swift で定義されています

// MARK: - Heartbeat Monitor View Modifier (エラー修正版)
// Note: HeartbeatHapticsManager は AdvancedEffectsSystem.swift で定義されています

struct HeartbeatMonitorModifierFinal: ViewModifier {
    @StateObject private var hapticsManager = HeartbeatHapticsManager.shared
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                hapticsManager.checkAndStartIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                hapticsManager.checkAndStartIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                hapticsManager.stopHeartbeat()
            }
    }
}

extension View {
    func monitorHeartbeatFinal() -> some View {
        modifier(HeartbeatMonitorModifierFinal())
    }
}

// MARK: - Preview

#Preview("Final App") {
    FinalMainContainerView()
        .preferredColorScheme(.dark)
}

#Preview("Final Camera") {
    FinalCameraView()
}
