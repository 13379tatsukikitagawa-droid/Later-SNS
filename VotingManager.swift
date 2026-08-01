import SwiftUI
import SwiftData
import Observation

/// 🗳️ グループ内匿名投票システムの中核マネージャー
@MainActor
@Observable
final class VotingManager {
    // MARK: - Singleton
    
    static let shared
    = VotingManager()
    
    // MARK: - Properties
    
    /// 投票フェーズの制限時間（2時間 = 7200秒）
    let votingDuration: TimeInterval = 7200
    
    /// 現在アクティブな投票セッション
    private(set) var activeVotingSession: VotingSession?
    
    // MARK: - Voting Session
    
    @Observable
    class VotingSession: Identifiable {
        let id = UUID()
        let unlockDate: Date
        let closingDate: Date
        let targetDate: String // "yyyy-MM-dd" 形式
        var hasVoted: Set<UUID> = [] // 投票済みユーザーID
        
        init(unlockDate: Date, closingDate: Date, targetDate: String) {
            self.unlockDate = unlockDate
            self.closingDate = closingDate
            self.targetDate = targetDate
        }
        
        var isActive: Bool {
            let now = Date()
            return now >= unlockDate && now < closingDate
        }
        
        var isClosed: Bool {
            Date() >= closingDate
        }
        
        var timeRemaining: TimeInterval {
            max(0, closingDate.timeIntervalSince(Date()))
        }
        
        var progressPercentage: Double {
            let total = closingDate.timeIntervalSince(unlockDate)
            let elapsed = Date().timeIntervalSince(unlockDate)
            return min(1.0, max(0, elapsed / total))
        }
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 解禁イベントを開始（写真が一斉解禁される瞬間）
    func startVotingSession(for date: Date, unlockDate: Date) {
        let closingDate = unlockDate.addingTimeInterval(votingDuration)
        let dateKey = date.formatted(.dateTime.year().month().day())
        
        activeVotingSession = VotingSession(
            unlockDate: unlockDate,
            closingDate: closingDate,
            targetDate: dateKey
        )
        
        print("🗳️ Voting session started for \(dateKey)")
        print("   Unlock: \(unlockDate)")
        print("   Closes: \(closingDate)")
    }
    
    /// 投票を記録
    func castVote(
        photo: LaterPhoto,
        voter: UserProfile,
        context: ModelContext
    ) -> Bool {
        guard let session = activeVotingSession, session.isActive else {
            print("❌ No active voting session")
            return false
        }
        
        // 既に投票済みかチェック
        guard !session.hasVoted.contains(voter.id) else {
            print("❌ User already voted")
            HapticsManager.errorFeedback()
            return false
        }
        
        // 投票速度を計算
        let reactionSpeed = Date().timeIntervalSince(session.unlockDate)
        
        // 投票を記録
        let vote = PhotoVote(
            photo: photo,
            voter: voter,
            reactionSpeed: reactionSpeed
        )
        context.insert(vote)
        
        // 写真の投票数を増やす
        photo.voteCount += 1
        
        // 投票済みマークを追加
        activeVotingSession?.hasVoted.insert(voter.id)
        
        try? context.save()
        
        // ハプティクスフィードバック
        HapticsManager.swipeFeedback()
        
        print("✅ Vote cast for photo \(photo.id) by \(voter.name)")
        
        return true
    }
    
    /// 投票締め切り後、ベストショットを選出
    func selectBestShot(
        for group: LaterGroup,
        targetDate: Date,
        context: ModelContext
    ) -> LaterPhoto? {
        guard let session = activeVotingSession, session.isClosed else {
            print("❌ Voting session not closed yet")
            return nil
        }
        
        // その日のグループ写真を取得
        let calendar = Calendar.current
        let photos = group.photos.filter { photo in
            calendar.isDate(photo.captureDate, inSameDayAs: targetDate)
        }
        
        guard !photos.isEmpty else { return nil }
        
        // アルゴリズム: 得票数 × 0.7 + 反応速度スコア × 0.3
        let rankedPhotos = photos.map { photo -> (photo: LaterPhoto, score: Double) in
            let voteScore = Double(photo.voteCount)
            
            // 反応速度スコア（早いほど高得点）
            let photoID = photo.id
            let votes = try? context.fetch(
                FetchDescriptor<PhotoVote>(
                    predicate: #Predicate<PhotoVote> { vote in
                        vote.photo?.id == photoID
                    }
                )
            )
            
            let avgReactionSpeed = votes?.map(\.reactionSpeed).reduce(0, +) ?? 0
            let speedScore = votes?.isEmpty == false
                ? 1000.0 / (avgReactionSpeed / Double(votes!.count))
                : 0
            
            let totalScore = (voteScore * 0.7) + (speedScore * 0.3)
            
            return (photo, totalScore)
        }
        .sorted { $0.score > $1.score }
        
        // 1位を「栄光の1枚」に選出
        guard let winner = rankedPhotos.first else { return nil }
        
        winner.photo.isGroupBestShot = true
        winner.photo.votingClosedAt = Date()
        
        try? context.save()
        
        print("🏆 Best shot selected: \(winner.photo.id) with score \(winner.score)")
        
        // ハプティクス演出
        HapticsManager.unlockSuccess()
        
        return winner.photo
    }
    
    /// 投票セッションをクリーンアップ
    func closeSession() {
        activeVotingSession = nil
    }
}
