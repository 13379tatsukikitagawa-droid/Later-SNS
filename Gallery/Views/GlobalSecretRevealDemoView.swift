import SwiftUI

// MARK: - Global Secret Reveal Demo View
/// グローバル一斉解禁システムのデモとテストビュー

struct GlobalSecretRevealDemoView: View {
    @State private var manager = GlobalSecretRevealManager.shared
    @State private var showingSettings = false
    @State private var showingHistory = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 24) {
                        // ヘッダー
                        headerSection
                        
                        // 現在のステータス
                        currentStatusCard
                        
                        // 秘匿UIプレビュー
                        secretPhotoPreview
                        
                        // コントロールパネル
                        controlPanel
                        
                        // ユーザー設定
                        userSettingsCard
                        
                        // 解禁履歴
                        revealHistoryCard
                    }
                    .padding()
                }
            }
            .navigationTitle("シークレット一斉解禁")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                GlobalRevealSettingsView()
            }
            .monitorGlobalRevealStatus()
        }
    }
    
    // MARK: - Subviews
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.1),
                Color(red: 0.1, green: 0.05, blue: 0.15),
                Color(red: 0.05, green: 0.05, blue: 0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // アイコン
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: .blue.opacity(0.5), radius: 20)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 45))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)
            }
            
            Text("全ユーザー一斉解禁システム")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("全員が同じタイミングで写真を見ることができます")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 20)
    }
    
    private var currentStatusCard: some View {
        VStack(spacing: 16) {
            // ステータスヘッダー
            HStack {
                Text("現在の状態")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                statusBadge
            }
            
            Divider()
                .background(.white.opacity(0.2))
            
            // 解禁状態
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(
                    icon: manager.isGloballyRevealed ? "lock.open.fill" : "lock.fill",
                    iconColor: manager.isGloballyRevealed ? .green : .orange,
                    title: "グローバル状態",
                    value: manager.isGloballyRevealed ? "解禁中 🎉" : "ロック中"
                )
                
                if let seconds = manager.secondsUntilNextReveal() {
                    InfoRow(
                        icon: "clock.fill",
                        iconColor: .blue,
                        title: "次回解禁まで",
                        value: "秘密 🤫"
                    )
                    
                    // デバッグ用（本番では非表示）
                    #if DEBUG
                    Text("Debug: \(formatDuration(seconds))")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.leading, 36)
                    #endif
                }
                
                InfoRow(
                    icon: manager.hasUserCompletedGoal ? "checkmark.circle.fill" : "circle",
                    iconColor: manager.hasUserCompletedGoal ? .green : .gray,
                    title: "あなたの目標",
                    value: manager.hasUserCompletedGoal ? "達成済み ✓" : "未達成"
                )
                
                InfoRow(
                    icon: manager.canViewFeed() ? "eye.fill" : "eye.slash.fill",
                    iconColor: manager.canViewFeed() ? .green : .red,
                    title: "フィード閲覧",
                    value: manager.canViewFeed() ? "可能" : "不可"
                )
            }
            
            // 次回解禁時刻（デバッグ用）
            #if DEBUG
            VStack(alignment: .leading, spacing: 8) {
                Text("デバッグ情報")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
                
                Text("次回解禁: \(manager.nextGlobalRevealTime.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                    .monospaced()
            }
            .padding(.top, 8)
            #endif
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(manager.isGloballyRevealed ? .green : .orange)
                .frame(width: 8, height: 8)
            
            Text(manager.isGloballyRevealed ? "LIVE" : "LOCKED")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(manager.isGloballyRevealed ? .green.opacity(0.2) : .orange.opacity(0.2))
        )
    }
    
    private var secretPhotoPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("秘匿UI プレビュー")
                .font(.headline)
                .foregroundStyle(.white)
            
            let status: SecretStatus = {
                if manager.isGloballyRevealed {
                    return manager.hasUserCompletedGoal ? .developing : .userNotReady
                } else {
                    return .waitingForReveal
                }
            }()
            
            SecretPhotoCard(status: status, size: CGSize(width: 300, height: 380))
                .frame(maxWidth: .infinity)
                .padding(.vertical)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("コントロールパネル")
                .font(.headline)
                .foregroundStyle(.white)
            
            VStack(spacing: 12) {
                // 目標達成トグル
                ControlButton(
                    icon: manager.hasUserCompletedGoal ? "checkmark.circle.fill" : "circle",
                    title: "目標達成をトグル",
                    color: .green
                ) {
                    withAnimation {
                        manager.hasUserCompletedGoal.toggle()
                    }
                }
                
                // 即座に解禁
                ControlButton(
                    icon: "bolt.fill",
                    title: "即座に解禁（テスト）",
                    color: .orange
                ) {
                    withAnimation {
                        manager.forceRevealNow()
                    }
                }
                
                // 次回スケジュール
                ControlButton(
                    icon: "arrow.clockwise",
                    title: "次回解禁をスケジュール",
                    color: .blue
                ) {
                    withAnimation {
                        manager.completeCurrentRevealAndScheduleNext()
                    }
                }
                
                // システムリセット
                ControlButton(
                    icon: "trash.fill",
                    title: "システムをリセット",
                    color: .red
                ) {
                    withAnimation {
                        manager.resetSystem()
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var userSettingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("閲覧ポリシー設定")
                .font(.headline)
                .foregroundStyle(.white)
            
            VStack(spacing: 12) {
                PolicyOption(
                    title: "他人の写真は常に見れる",
                    description: "自分が未達成でも、解禁時に他人の写真は閲覧可能",
                    isSelected: manager.viewPolicy == .viewOthersEvenIfIncomplete
                ) {
                    manager.viewPolicy = .viewOthersEvenIfIncomplete
                }
                
                PolicyOption(
                    title: "自分が達成するまで全て見れない",
                    description: "自分の目標達成まで、全ての写真がブロックされる",
                    isSelected: manager.viewPolicy == .blockAllUntilSelfComplete
                ) {
                    manager.viewPolicy = .blockAllUntilSelfComplete
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var revealHistoryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("解禁履歴")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                if !manager.revealHistory.isEmpty {
                    Text("\(manager.revealHistory.count)件")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            if manager.revealHistory.isEmpty {
                Text("まだ解禁履歴がありません")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(manager.revealHistory.prefix(5)) { event in
                        HistoryRow(event: event)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
}

// MARK: - Supporting Views

private struct InfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
    }
}

private struct ControlButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

private struct PolicyOption: View {
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .green : .white.opacity(0.3))
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? .green.opacity(0.1) : .white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isSelected ? .green.opacity(0.4) : .white.opacity(0.1),
                                lineWidth: 1.5
                            )
                    )
            )
        }
    }
}

private struct HistoryRow: View {
    let event: RevealEvent
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.revealTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                
                Text(event.userWasReady ? "✓ 準備完了" : "⚠ 未完了")
                    .font(.caption)
                    .foregroundStyle(event.userWasReady ? .green : .orange)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.03))
        )
    }
}

// MARK: - Settings View

struct GlobalRevealSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var manager = GlobalSecretRevealManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.1)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // システム説明
                        VStack(alignment: .leading, spacing: 12) {
                            Text("システムについて")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            Text("このシステムは、全ユーザーが同じタイミングで写真を解禁される仕組みです。解禁時刻は前回の終了から12〜48時間後にランダムで設定され、夜間(22:00-09:00)は自動的に避けられます。")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial.opacity(0.3))
                        )
                        
                        // 機能説明
                        VStack(alignment: .leading, spacing: 16) {
                            Text("主な機能")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            FeatureItem(
                                icon: "clock.fill",
                                title: "ランダムスケジュール",
                                description: "12〜48時間のランダムな間隔で自動設定"
                            )
                            
                            FeatureItem(
                                icon: "moon.fill",
                                title: "夜間回避",
                                description: "22:00〜09:00は自動的に翌朝以降に調整"
                            )
                            
                            FeatureItem(
                                icon: "bell.fill",
                                title: "プッシュ通知",
                                description: "解禁の瞬間に全ユーザーへ通知"
                            )
                            
                            FeatureItem(
                                icon: "lock.open.fill",
                                title: "完全秘匿",
                                description: "カウントダウンなし、時間表示なし"
                            )
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial.opacity(0.3))
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

private struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    GlobalSecretRevealDemoView()
}

#Preview("Settings") {
    GlobalRevealSettingsView()
}
