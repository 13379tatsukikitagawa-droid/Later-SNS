import SwiftUI

/// フィード投稿がロックされている際のスタイリッシュなオーバーレイ
struct FeedLockOverlay: View {
    let lockReason: LockReason
    
    enum LockReason {
        case goalNotAchieved(current: Int, goal: Int) // 目標未達成
        case insufficientPhotos // 撮影枚数不足（アンロック枠を使い切った）
        case beforeUnlock(timeRemaining: String) // 解禁時刻前
        case afterDeadline // 閲覧期限終了
        
        var icon: String {
            switch self {
            case .goalNotAchieved: return "lock.fill"
            case .insufficientPhotos: return "camera.fill"
            case .beforeUnlock: return "hourglass"
            case .afterDeadline: return "moon.zzz.fill"
            }
        }
        
        var title: String {
            switch self {
            case .goalNotAchieved: return "目標未達成のためロック中"
            case .insufficientPhotos: return "未撮影分につきロック中"
            case .beforeUnlock: return "解禁時刻前"
            case .afterDeadline: return "閲覧期限終了"
            }
        }
        
        var message: String? {
            switch self {
            case .goalNotAchieved(let current, let goal):
                return "あと\(goal - current)枚撮影で解禁"
            case .insufficientPhotos:
                return "もっと撮影すると閲覧可能に"
            case .beforeUnlock(let time):
                return "解禁まで\(time)"
            case .afterDeadline:
                return "明日をお楽しみに"
            }
        }
        
        var accentColor: Color {
            switch self {
            case .goalNotAchieved: return .red
            case .insufficientPhotos: return .orange
            case .beforeUnlock: return .blue
            case .afterDeadline: return .purple
            }
        }
    }
    
    var body: some View {
        ZStack {
            // ブラー効果
            Rectangle()
                .fill(.ultraThinMaterial)
            
            // グラデーションオーバーレイ
            LinearGradient(
                colors: [
                    lockReason.accentColor.opacity(0.3),
                    lockReason.accentColor.opacity(0.1),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // コンテンツ
            VStack(spacing: 12) {
                // アイコン
                ZStack {
                    Circle()
                        .fill(lockReason.accentColor.opacity(0.2))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: lockReason.icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(lockReason.accentColor)
                }
                .shadow(color: lockReason.accentColor.opacity(0.3), radius: 12, x: 0, y: 4)
                
                // タイトル
                Text(lockReason.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                
                // メッセージ
                if let message = lockReason.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            .padding(24)
        }
    }
}

// MARK: - View Extension for Easy Lock Application

extension View {
    /// フィード投稿にロックオーバーレイを適用
    func feedLock(isLocked: Bool, reason: FeedLockOverlay.LockReason?) -> some View {
        self.overlay {
            if isLocked, let reason = reason {
                FeedLockOverlay(lockReason: reason)
            }
        }
    }
}

// MARK: - Preview

#Preview("Goal Not Achieved") {
    RoundedRectangle(cornerRadius: 16)
        .fill(.blue.gradient)
        .frame(width: 300, height: 400)
        .overlay {
            FeedLockOverlay(lockReason: .goalNotAchieved(current: 1, goal: 3))
        }
}

#Preview("Insufficient Photos") {
    RoundedRectangle(cornerRadius: 16)
        .fill(.green.gradient)
        .frame(width: 300, height: 400)
        .overlay {
            FeedLockOverlay(lockReason: .insufficientPhotos)
        }
}

#Preview("Before Unlock") {
    RoundedRectangle(cornerRadius: 16)
        .fill(.purple.gradient)
        .frame(width: 300, height: 400)
        .overlay {
            FeedLockOverlay(lockReason: .beforeUnlock(timeRemaining: "2時間30分"))
        }
}

#Preview("After Deadline") {
    RoundedRectangle(cornerRadius: 16)
        .fill(.orange.gradient)
        .frame(width: 300, height: 400)
        .overlay {
            FeedLockOverlay(lockReason: .afterDeadline)
        }
}
