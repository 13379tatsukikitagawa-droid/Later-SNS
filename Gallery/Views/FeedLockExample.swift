import SwiftUI

/// フィード投稿のロック状態を判定するヘルパー
struct FeedLockHelper {
    let photosTaken: Int
    let dailyGoal: Int
    let unlockManager: UnlockTimeManager
    
    init(photosTaken: Int, dailyGoal: Int) {
        self.photosTaken = photosTaken
        self.dailyGoal = dailyGoal
        self.unlockManager = UnlockTimeManager.shared
    }
    
    /// 指定インデックスの投稿がアンロックされているか判定
    func isPostUnlocked(at index: Int) -> Bool {
        // 自分の投稿は常に見える（実際の実装では投稿者IDで判定）
        // この例では最初の投稿が自分のものと仮定
        if index == 0 {
            return true
        }
        
        // 目標未達成なら全てロック
        guard photosTaken >= dailyGoal else {
            return false
        }
        
        // フィードがアンロックされているか確認
        guard unlockManager.isFeedUnlocked(photosTaken: photosTaken, dailyGoal: dailyGoal) else {
            return false
        }
        
        // アンロック可能な投稿数を取得
        let unlockedCount = unlockManager.unlockedPostCount(photosTaken: photosTaken, dailyGoal: dailyGoal)
        
        // このインデックスがアンロック範囲内か
        // 実際の実装ではランダム選択された投稿IDと照合
        return index < unlockedCount
    }
    
    /// ロック理由を取得
    func lockReason(for index: Int) -> FeedLockOverlay.LockReason? {
        // 自分の投稿はロックなし
        if index == 0 {
            return nil
        }
        
        // 目標未達成
        if photosTaken < dailyGoal {
            return .goalNotAchieved(current: photosTaken, goal: dailyGoal)
        }
        
        // 解禁時刻前
        if let secondsUntil = unlockManager.secondsUntilUnlock(), secondsUntil > 0 {
            return .beforeUnlock(timeRemaining: formatTime(secondsUntil))
        }
        
        // 閲覧期限終了
        if let lockTime = unlockManager.lockTime, Date() >= lockTime {
            return .afterDeadline
        }
        
        // アンロック枠不足
        let unlockedCount = unlockManager.unlockedPostCount(photosTaken: photosTaken, dailyGoal: dailyGoal)
        if index >= unlockedCount {
            return .insufficientPhotos
        }
        
        return nil
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 {
            return "\(h)時間\(m)分"
        } else {
            return "\(m)分"
        }
    }
}

// MARK: - サンプルフィードビュー

struct SampleFeedView: View {
    @AppStorage("photosTaken") private var photosTaken: Int = 0
    @AppStorage("dailyGoal") private var dailyGoal: Int = 3
    
    private let samplePosts = [
        ("自分の投稿", Color.blue),
        ("友達Aの投稿", Color.green),
        ("友達Bの投稿", Color.purple),
        ("友達Cの投稿", Color.orange),
        ("友達Dの投稿", Color.pink)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // カウントダウンバナー
                CountdownBanner()
                    .padding(.horizontal)
                
                // フィード投稿
                ForEach(Array(samplePosts.enumerated()), id: \.offset) { index, post in
                    FeedPostCard(
                        title: post.0,
                        color: post.1,
                        index: index,
                        photosTaken: photosTaken,
                        dailyGoal: dailyGoal
                    )
                }
            }
            .padding(.vertical)
        }
        .background(Color.brandBlack.ignoresSafeArea())
    }
}

struct FeedPostCard: View {
    let title: String
    let color: Color
    let index: Int
    let photosTaken: Int
    let dailyGoal: Int
    
    var body: some View {
        let helper = FeedLockHelper(photosTaken: photosTaken, dailyGoal: dailyGoal)
        let isLocked = !helper.isPostUnlocked(at: index)
        let lockReason = helper.lockReason(for: index)
        
        RoundedRectangle(cornerRadius: 16)
            .fill(color.gradient)
            .frame(height: 300)
            .overlay {
                VStack {
                    Text(title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text("投稿 #\(index + 1)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .feedLock(isLocked: isLocked, reason: lockReason)
            .padding(.horizontal)
    }
}

#Preview {
    SampleFeedView()
}
