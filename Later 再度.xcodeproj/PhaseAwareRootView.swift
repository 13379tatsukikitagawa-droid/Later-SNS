import SwiftUI
import SwiftData

/// 🎯 フェーズ連動型のルートビュー
/// 
/// TimeWindowEngineの現在のフェーズに応じて、表示する画面を自動的に切り替える。
struct PhaseAwareRootView: View {
    @StateObject private var timeEngine = TimeWindowEngine.shared
    @AppStorage("isSetupCompleted") private var isSetupCompleted: Bool = false
    
    // デバッグオーバーレイの表示切り替え（開発中のみtrueにする）
    @AppStorage("showDebugOverlay") private var showDebugOverlay: Bool = true
    
    var body: some View {
        ZStack {
            // メインコンテンツ
            if !isSetupCompleted {
                // オンボーディング中はフェーズに関係なくオンボーディングを表示
                OnboardingView()
                    .transition(.opacity)
            } else {
                // セットアップ完了後はフェーズに応じて画面を切り替え
                phaseContent
                    .transition(.opacity)
            }
            
            // デバッグオーバーレイ（開発中のみ表示）
            if showDebugOverlay {
                DebugTimeOverlay(engine: timeEngine)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: timeEngine.currentPhase)
        .animation(.easeInOut(duration: 0.5), value: isSetupCompleted)
        .onReceive(NotificationCenter.default.publisher(for: .timeWindowPhaseDidChange)) { notification in
            // フェーズ変更時の処理
            handlePhaseChange(notification: notification)
        }
    }
    
    // MARK: - Phase Content
    
    /// 現在のフェーズに応じたコンテンツ
    @ViewBuilder
    private var phaseContent: some View {
        switch timeEngine.currentPhase {
        case .shooting:
            // 0:00 〜 8:00: 撮影 & キャプション入力
            ShootingPhaseView()
            
        case .voting:
            // 8:00 〜 9:00: 完全匿名・投票
            VotingPhaseView()
            
        case .results:
            // 9:00 〜 23:59: 結果発表 & カレンダー
            ResultsPhaseView()
        }
    }
    
    // MARK: - Phase Change Handler
    
    /// フェーズ変更時のハンドラー
    private func handlePhaseChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let previousPhase = userInfo["previousPhase"] as? TimeWindowPhase,
              let currentPhase = userInfo["currentPhase"] as? TimeWindowPhase else {
            return
        }
        
        print("🔄 [PhaseAwareRootView] フェーズ遷移: \(previousPhase.rawValue) → \(currentPhase.rawValue)")
        
        // フェーズ遷移時の特別な処理をここに追加
        switch currentPhase {
        case .voting:
            // 投票フェーズ開始時: カメラをロック
            print("🔒 カメラ機能をロック")
            
        case .results:
            // 結果フェーズ開始時: カレンダーへの自動格納処理をトリガー
            print("📅 結果をカレンダーに格納")
            triggerResultsProcessing()
            
        case .shooting:
            // 撮影フェーズ開始時（日付が変わった時）: 前日のデータをリセット
            print("🔄 新しい日が始まりました")
        }
    }
    
    /// 結果フェーズ開始時の処理
    private func triggerResultsProcessing() {
        // TODO: 以下の処理を実装
        // 1. 投票結果を集計
        // 2. 1位の写真を全員のカレンダーに格納
        // 3. 自分の写真を自分のカレンダーに格納
        // 4. キャプションを解禁
    }
}

// MARK: - Shooting Phase View

/// 📸 撮影フェーズのビュー（0:00 〜 8:00）
struct ShootingPhaseView: View {
    var body: some View {
        MainTabView()
            .overlay(alignment: .top) {
                phaseIndicator(
                    icon: "camera.fill",
                    title: "撮影タイム",
                    color: "#00ff41"
                )
            }
    }
}

// MARK: - Voting Phase View

/// 🗳️ 投票フェーズのビュー（8:00 〜 9:00）
struct VotingPhaseView: View {
    @StateObject private var timeEngine = TimeWindowEngine.shared
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // フェーズインジケーター
                phaseIndicator(
                    icon: "hand.thumbsup.fill",
                    title: "投票タイム",
                    color: "#FF6B6B"
                )
                .padding(.top, 60)
                
                Spacer()
                
                // 投票UI（仮実装 - 後で本格的な投票画面に差し替え）
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 80))
                        .foregroundStyle(.white.opacity(0.3))
                    
                    Text("完全匿名で投票")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text("写真のみが表示されます\n投稿者名とキャプションは非表示")
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    // 残り時間
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                        Text("残り時間: \(timeEngine.currentPhase.formattedTimeUntilNextPhase(from: timeEngine.effectiveCurrentDate))")
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color(hex: "#FF6B6B"))
                    .padding(.top, 8)
                }
                
                Spacer()
                
                // TODO: 実際の投票UI（スワイプカード形式など）をここに実装
                Button {
                    // 投票画面へ遷移
                } label: {
                    Text("投票画面を開く（仮）")
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.black)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 32)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "#FF6B6B"))
                        )
                }
                .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - Results Phase View

/// 🏆 結果発表フェーズのビュー（9:00 〜 23:59）
struct ResultsPhaseView: View {
    var body: some View {
        MainTabView()
            .overlay(alignment: .top) {
                phaseIndicator(
                    icon: "trophy.fill",
                    title: "結果発表",
                    color: "#FFD93D"
                )
            }
    }
}

// MARK: - Shared Components

/// フェーズインジケーター（画面上部に表示）
private func phaseIndicator(icon: String, title: String, color: String) -> some View {
    HStack(spacing: 8) {
        Image(systemName: icon)
            .font(.system(size: 14))
        
        Text(title)
            .font(.system(.caption, design: .monospaced))
            .fontWeight(.semibold)
    }
    .foregroundStyle(Color(hex: color))
    .padding(.vertical, 8)
    .padding(.horizontal, 16)
    .background(
        Capsule()
            .fill(.black.opacity(0.7))
            .overlay(
                Capsule()
                    .stroke(Color(hex: color), lineWidth: 1)
            )
    )
    .shadow(color: Color(hex: color).opacity(0.3), radius: 8)
    .padding(.top, 8)
}

// MARK: - Preview

#Preview("撮影フェーズ") {
    PhaseAwareRootView()
        .modelContainer(for: [LaterPhoto.self, LaterGroup.self, UserProfile.self])
        .onAppear {
            TimeWindowEngine.shared.isDebugModeEnabled = true
            TimeWindowEngine.shared.forcePhase(.shooting)
        }
}

#Preview("投票フェーズ") {
    PhaseAwareRootView()
        .modelContainer(for: [LaterPhoto.self, LaterGroup.self, UserProfile.self])
        .onAppear {
            TimeWindowEngine.shared.isDebugModeEnabled = true
            TimeWindowEngine.shared.forcePhase(.voting)
        }
}

#Preview("結果フェーズ") {
    PhaseAwareRootView()
        .modelContainer(for: [LaterPhoto.self, LaterGroup.self, UserProfile.self])
        .onAppear {
            TimeWindowEngine.shared.isDebugModeEnabled = true
            TimeWindowEngine.shared.forcePhase(.results)
        }
}
