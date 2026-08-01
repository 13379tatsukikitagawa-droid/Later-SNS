import SwiftUI
import SwiftData

// MARK: - 🎬 一括解禁システム完全デモ
/// すべての機能を統合したデモアプリ

struct GroupedUnlockSystemDemo: View {
    @State private var sessionManager = DailyPhotoSessionManager.shared
    @State private var showingCamera = false
    @State private var currentDate = Date()
    
    // タイマーで定期的に更新
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // ヘッダー
                        headerSection
                        
                        // セッション情報カード
                        sessionInfoCard
                        
                        // 解禁状態カード
                        unlockStatusCard
                        
                        // 写真ギャラリーボタン
                        galleryButton
                        
                        // デバッグ情報（開発中のみ）
                        #if DEBUG
                        debugSection
                        #endif
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("一括解禁システム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCamera = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.brandGreen)
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                SecretCameraView()
            }
            .onReceive(timer) { _ in
                currentDate = Date()
            }
        }
    }
    
    // MARK: - ヘッダーセクション
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.brandGreen, .brandGreen.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("全写真一括解禁")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            Text("1日の撮影を完了すると、全写真が同時に解禁されます")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 20)
    }
    
    // MARK: - セッション情報カード
    
    private var sessionInfoCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("今日のセッション")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Image(systemName: sessionManager.statusIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(sessionManager.statusColor)
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // 撮影枚数
            InfoRow(
                icon: "camera.fill",
                label: "撮影枚数",
                value: "\(sessionManager.photoCount) 枚",
                color: .blue
            )
            
            // セッション状態
            InfoRow(
                icon: sessionManager.statusIcon,
                label: "状態",
                value: sessionManager.statusMessage,
                color: sessionManager.statusColor
            )
            
            // セッション日付
            if let date = sessionManager.sessionDate {
                InfoRow(
                    icon: "calendar",
                    label: "日付",
                    value: date,
                    color: .purple
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - 解禁状態カード
    
    private var unlockStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("解禁状態")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                if sessionManager.arePhotosUnlocked() {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.orange)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            if sessionManager.isSessionLocked {
                if sessionManager.arePhotosUnlocked() {
                    // 解禁済み
                    unlockedStatusView
                } else {
                    // 現像中
                    developingStatusView
                }
            } else {
                // セッション進行中
                sessionInProgressView
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    sessionManager.arePhotosUnlocked() ? Color.green.opacity(0.3) : Color.orange.opacity(0.3),
                    lineWidth: 1.5
                )
        )
        .padding(.horizontal, 16)
    }
    
    // セッション進行中ビュー
    private var sessionInProgressView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)
                
                Text("撮影中")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            Text("目標枚数を達成すると、全写真が一括でロックされます")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }
    
    // 現像中ビュー
    private var developingStatusView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "hourglass")
                    .font(.system(size: 24))
                    .foregroundStyle(.orange)
                
                Text(sessionManager.developmentMessage)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            // 進行度バー
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    // 進行バー
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .orange.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * sessionManager.unlockProgress(),
                            height: 8
                        )
                        .animation(.linear(duration: 1.0), value: sessionManager.unlockProgress())
                }
            }
            .frame(height: 8)
            
            // 進行度段階表示
            HStack {
                let progress = sessionManager.unlockProgress()
                let stage = progress < 0.33 ? "初期段階" : progress < 0.66 ? "中期段階" : "後期段階"
                
                Text(stage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.orange)
                
                Spacer()
                
                Text("現像処理中")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            
            Text("⚠️ 具体的な残り時間は非表示です")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }
    
    // 解禁済みビュー
    private var unlockedStatusView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.green)
                
                Text("現像完了")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            Text("すべての写真が閲覧可能になりました！")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            // 解禁時刻表示
            if let unlockTime = sessionManager.targetUnlockTime {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                
                Text("解禁時刻: \(formatter.string(from: unlockTime))")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.15))
                    )
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - ギャラリーボタン
    
    private var galleryButton: some View {
        NavigationLink {
            SecretPhotoGalleryView()
        } label: {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 20, weight: .semibold))
                
                Text("写真ギャラリーを見る")
                    .font(.system(size: 17, weight: .semibold))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.brandGreen, .brandGreen.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: .brandGreen.opacity(0.4), radius: 15, x: 0, y: 8)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - デバッグセクション
    
    #if DEBUG
    private var debugSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("デバッグ情報")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Image(systemName: "ant.fill")
                    .foregroundStyle(.yellow)
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // ロック時刻
            if let lockTime = sessionManager.sessionLockTime {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                
                InfoRow(
                    icon: "lock.fill",
                    label: "ロック時刻",
                    value: formatter.string(from: lockTime),
                    color: .red
                )
            }
            
            // 解禁時刻
            if let unlockTime = sessionManager.targetUnlockTime {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                
                InfoRow(
                    icon: "lock.open.fill",
                    label: "解禁時刻",
                    value: formatter.string(from: unlockTime),
                    color: .green
                )
            }
            
            // 残り時間（デバッグ用）
            if let remaining = sessionManager.secondsUntilUnlock() {
                let hours = Int(remaining) / 3600
                let minutes = (Int(remaining) % 3600) / 60
                let seconds = Int(remaining) % 60
                
                InfoRow(
                    icon: "timer",
                    label: "残り時間",
                    value: String(format: "%02d:%02d:%02d", hours, minutes, seconds),
                    color: .orange
                )
            }
            
            // 進行度
            let progress = sessionManager.unlockProgress()
            InfoRow(
                icon: "chart.bar.fill",
                label: "進行度",
                value: String(format: "%.1f%%", progress * 100),
                color: .blue
            )
            
            // リセットボタン
            Button {
                sessionManager.resetSessionForTesting()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("セッションをリセット")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.red.opacity(0.3))
                )
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.yellow.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1.5)
        )
        .padding(.horizontal, 16)
    }
    #endif
}

// MARK: - サブビュー

/// 情報行
struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 24)
            
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - プレビュー
#Preview {
    GroupedUnlockSystemDemo()
        .modelContainer(for: LaterPhoto.self)
}
