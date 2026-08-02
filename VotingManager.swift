import SwiftUI
import SwiftData
import Observation

/// 🗳️ グループ内匿名投票システムの中核マネージャー
///
/// 元の実装は「投票セッション」をこのシングルトンのメモリ上にだけ保持していたが、
/// それでは複数端末間で状態が共有されず(そもそも各端末のメモリは別々)、
/// CloudKit同期とは原理的に噛み合わない。またこのアプリは写真ごとに解禁時刻が
/// ランダムなため、グループ全体で共通の「投票締切」という概念も成立しない。
/// そこで、投票の可否・締切判定はすべてSwiftData(=CloudKitで同期される永続データ)
/// から都度計算する形に変更した。得票数×0.7+反応速度スコア×0.3というスコアリング
/// アルゴリズム自体は元の実装をそのまま踏襲している。
@MainActor
@Observable
final class VotingManager {
    static let shared = VotingManager()

    /// 投票受付の目安時間(最初の解禁からこの時間が経過したら締め切り候補になる)
    let votingDuration: TimeInterval = 7200

    // MARK: - Legacy compatibility
    // 到達不能な旧UI(AnonymousVotingFeedView / CircleView / HomeView /
    // VotingAutomationManager)だけが参照する互換シム。新しい判定は上記の
    // isEligibleToVote/castVote/closeVotingIfReadyがSwiftDataから都度計算するため、
    // これらは実際には使われていない(ビルドを壊さないためだけに残す)。

    @Observable
    class VotingSession: Identifiable {
        let id = UUID()
        let unlockDate: Date
        let closingDate: Date
        let targetDate: String
        var hasVoted: Set<UUID> = []

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

    private(set) var activeVotingSession: VotingSession?

    func startVotingSession(for date: Date, unlockDate: Date) {
        let dateKey = date.formatted(.dateTime.year().month().day())
        activeVotingSession = VotingSession(unlockDate: unlockDate, closingDate: unlockDate.addingTimeInterval(votingDuration), targetDate: dateKey)
    }

    func closeSession() {
        activeVotingSession = nil
    }

    private init() {}

    /// 投票資格(その日のグループの達成メンバー=写真を撮影済みのメンバー)があるか
    func isEligibleToVote(voter: UserProfile, group: LaterGroup, date: Date, calendar: Calendar = .current) -> Bool {
        let todaysAuthorIDs = Set(group.photos
            .filter { calendar.isDate($0.captureDate, inSameDayAs: date) }
            .compactMap { $0.owner?.id })
        return todaysAuthorIDs.contains(voter.id)
    }

    /// 投票(変更)する。票数・投票者情報はUIに一切表示しない前提で扱うこと。
    @discardableResult
    func castVote(photo: LaterPhoto, voter: UserProfile, context: ModelContext) -> Bool {
        guard photo.isUnlocked else { return false }
        guard let groupID = photo.groupID,
              let group = try? context.fetch(FetchDescriptor<LaterGroup>()).first(where: { $0.id == groupID }) else {
            return false
        }
        guard isEligibleToVote(voter: voter, group: group, date: photo.captureDate) else { return false }

        let calendar = Calendar.current
        let captureDate = photo.captureDate

        // 既に確定(ベストショット選出済み)なら投票不可
        let alreadyDecided = group.photos.contains {
            $0.isGroupBestShot && calendar.isDate($0.captureDate, inSameDayAs: captureDate)
        }
        guard !alreadyDecided else { return false }

        // 同じ日の既存の自分の投票を取り消す(投票の変更に対応)
        let voterID = voter.id
        let existingVotes = (try? context.fetch(FetchDescriptor<PhotoVote>()))?.filter {
            $0.voter?.id == voterID && $0.groupID == groupID
                && calendar.isDate($0.photo?.captureDate ?? .distantPast, inSameDayAs: captureDate)
        } ?? []
        for existing in existingVotes {
            if existing.photo?.id == photo.id {
                // 既に同じ写真に投票済み
                return true
            }
            existing.photo?.voteCount = max(0, (existing.photo?.voteCount ?? 1) - 1)
            CloudKitManager.current?.markForDelete(vote: existing)
            context.delete(existing)
        }

        let reactionSpeed = Date().timeIntervalSince(photo.unlockDate)

        let vote = PhotoVote(photo: photo, voter: voter, reactionSpeed: max(0, reactionSpeed))
        vote.photoID = photo.id
        vote.groupID = groupID
        vote.voterCloudKitUserRecordName = CloudKitManager.current?.currentUserRecordName
        context.insert(vote)

        photo.voteCount += 1

        try? context.save()
        CloudKitManager.current?.markForUpload(vote: vote, in: group)

        HapticsManager.swipeFeedback()

        // 自分の投票で締切条件が揃う可能性があるため、その場でも判定する。
        _ = closeVotingIfReady(for: group, date: captureDate, context: context)

        return true
    }

    /// 締切条件(資格者全員が投票 or 最初の解禁から一定時間経過)が揃っていれば
    /// ベストショットを選出する。揃っていなければ何もしない。
    @discardableResult
    func closeVotingIfReady(for group: LaterGroup, date: Date, context: ModelContext) -> LaterPhoto? {
        let calendar = Calendar.current
        let todaysPhotos = group.photos.filter { calendar.isDate($0.captureDate, inSameDayAs: date) && $0.isUnlocked }
        guard !todaysPhotos.isEmpty else { return nil }
        guard !todaysPhotos.contains(where: { $0.isGroupBestShot }) else { return nil }

        let eligibleVoterIDs = Set(todaysPhotos.compactMap { $0.owner?.id })
        guard !eligibleVoterIDs.isEmpty else { return nil }

        let photoIDs = Set(todaysPhotos.map(\.id))
        let allVotes = (try? context.fetch(FetchDescriptor<PhotoVote>()))?.filter {
            guard let pid = $0.photo?.id else { return false }
            return photoIDs.contains(pid)
        } ?? []
        let votedVoterIDs = Set(allVotes.compactMap { $0.voter?.id })

        let everyoneVoted = eligibleVoterIDs.isSubset(of: votedVoterIDs)
        let earliestUnlock = todaysPhotos.map(\.unlockDate).min() ?? date
        let deadlinePassed = Date() >= earliestUnlock.addingTimeInterval(votingDuration)

        guard everyoneVoted || deadlinePassed else { return nil }

        return selectBestShot(for: group, targetDate: date, context: context)
    }

    /// 得票数×0.7 + 反応速度スコア×0.3でベストショットを選出する。
    @discardableResult
    func selectBestShot(for group: LaterGroup, targetDate: Date, context: ModelContext) -> LaterPhoto? {
        let calendar = Calendar.current
        let photos = group.photos.filter { photo in
            photo.isUnlocked && calendar.isDate(photo.captureDate, inSameDayAs: targetDate)
        }
        guard !photos.isEmpty else { return nil }
        guard !photos.contains(where: { $0.isGroupBestShot }) else { return nil }

        let rankedPhotos = photos.map { photo -> (photo: LaterPhoto, score: Double) in
            let voteScore = Double(photo.voteCount)

            let photoID = photo.id
            let votes = try? context.fetch(
                FetchDescriptor<PhotoVote>(
                    predicate: #Predicate<PhotoVote> { vote in
                        vote.photo?.id == photoID
                    }
                )
            )

            let avgReactionSpeed = votes?.map(\.reactionSpeed).reduce(0, +) ?? 0
            let speedScore = (votes?.isEmpty == false)
                ? 1000.0 / max(1, avgReactionSpeed / Double(votes!.count))
                : 0

            let totalScore = (voteScore * 0.7) + (speedScore * 0.3)
            return (photo, totalScore)
        }
        .sorted { $0.score > $1.score }

        guard let winner = rankedPhotos.first, winner.score > 0 || rankedPhotos.count == 1 else { return nil }

        winner.photo.isGroupBestShot = true
        winner.photo.votingClosedAt = Date()

        try? context.save()

        if let groupID = winner.photo.groupID,
           let group = try? context.fetch(FetchDescriptor<LaterGroup>()).first(where: { $0.id == groupID }) {
            CloudKitManager.current?.markForUpload(photo: winner.photo, in: group)
        }

        HapticsManager.unlockSuccess()

        return winner.photo
    }
}
