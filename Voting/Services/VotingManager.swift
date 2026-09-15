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
    /// 「ボタンを押しても何も起きない」という報告があったため、途中のguardで
    /// 早期returnした場合にどの条件で弾かれたのかを[Vote]タグ付きで必ずログへ残す
    /// (票数自体はログに出さない)。
    @discardableResult
    func castVote(photo: LaterPhoto, voter: UserProfile, context: ModelContext) -> Bool {
        let photoLabel = photo.ckRecordName ?? photo.id.uuidString
        guard photo.isUnlocked else {
            print("[Vote] castVote失敗: photo.isUnlockedがfalse recordName=\(photoLabel)")
            return false
        }
        guard let groupID = photo.groupID,
              let group = try? context.fetch(FetchDescriptor<LaterGroup>()).first(where: { $0.id == groupID }) else {
            print("[Vote] castVote失敗: groupIDまたはgroupを解決できない recordName=\(photoLabel), groupID=\(String(describing: photo.groupID))")
            return false
        }
        guard isEligibleToVote(voter: voter, group: group, date: photo.captureDate) else {
            print("[Vote] castVote失敗: 投票資格なし(本日このグループで撮影したメンバーではない) voter=\(voter.name), recordName=\(photoLabel)")
            return false
        }

        let calendar = Calendar.current
        let captureDate = photo.captureDate

        // 既に確定(ベストショット選出済み)なら投票不可
        let alreadyDecided = group.photos.contains {
            $0.isGroupBestShot && calendar.isDate($0.captureDate, inSameDayAs: captureDate)
        }
        guard !alreadyDecided else {
            print("[Vote] castVote失敗: この日は既に選出確定済み recordName=\(photoLabel)")
            return false
        }

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

        do {
            try context.save()
        } catch {
            print("[Vote] castVote失敗: context.saveが例外 recordName=\(photoLabel), error=\(error)")
            return false
        }
        CloudKitManager.current?.markForUpload(vote: vote, in: group)

        print("[Vote] castVote成功: recordName=\(photoLabel), voter=\(voter.name)")
        HapticsManager.swipeFeedback()

        // 投票はここでは票数を記録するだけにとどめ、確定(選出済みにする処理)は
        // その場では行わない。以前は「資格者全員が投票済みなら即座に確定」する
        // 早期確定ロジックがここにあったが、少人数グループでは投票直後に結果が
        // 見えてしまう不具合につながっていたため廃止した。確定は必ず締切時刻(23:00)を
        // 過ぎてから、closeVotingIfReady(グループを開いたタイミング等)でまとめて行う。

        return true
    }

    /// 投票締切時刻(23:00固定。呼び出し元が無く実行経路からは外れているが、
    /// このファイル自体は除外対象の旧UIから参照されているため残っている)を
    /// 過ぎていれば、その日の投票結果をまとめて確定する。
    /// 過ぎていなければ何もしない。以前あった「資格者全員が投票済みなら即座に
    /// 確定してよい」という早期確定の考え方は廃止した(少人数グループで投票直後に
    /// 結果が見えてしまっていたため)。
    @discardableResult
    func closeVotingIfReady(for group: LaterGroup, date: Date, context: ModelContext) -> [LaterPhoto] {
        let calendar = Calendar.current
        let todaysPhotos = group.photos.filter { calendar.isDate($0.captureDate, inSameDayAs: date) && $0.isUnlocked }
        guard !todaysPhotos.isEmpty else { return [] }
        guard !todaysPhotos.contains(where: { $0.isGroupBestShot }) else { return [] }

        var deadlineComponents = calendar.dateComponents([.year, .month, .day], from: date)
        deadlineComponents.hour = 23
        let votingDeadline = calendar.date(from: deadlineComponents) ?? date
        guard Date() >= votingDeadline else { return [] }

        return selectBestShot(for: group, targetDate: date, context: context)
    }

    /// 1票以上入った写真をすべて「選出済み」として確定する(最多得票1枚だけを選ぶ
    /// 処理・同票による決選投票は廃止。複数の写真が同時に選出される場合がある)。
    @discardableResult
    func selectBestShot(for group: LaterGroup, targetDate: Date, context: ModelContext) -> [LaterPhoto] {
        let calendar = Calendar.current
        let photos = group.photos.filter { photo in
            photo.isUnlocked && calendar.isDate(photo.captureDate, inSameDayAs: targetDate)
        }
        guard !photos.isEmpty else { return [] }
        guard !photos.contains(where: { $0.isGroupBestShot }) else { return [] }

        let winners = photos.filter { $0.voteCount >= 1 }
        guard !winners.isEmpty else { return [] }

        let decidedAt = Date()
        for winner in winners {
            winner.isGroupBestShot = true
            winner.votingClosedAt = decidedAt
        }

        try? context.save()

        if let groupID = winners.first?.groupID,
           let group = try? context.fetch(FetchDescriptor<LaterGroup>()).first(where: { $0.id == groupID }),
           let cloudKitManager = CloudKitManager.current {
            Task {
                for winner in winners {
                    await cloudKitManager.markForUpload(photo: winner, in: group)
                }
                await cloudKitManager.sendPendingChangesNow()
            }
        }

        HapticsManager.unlockSuccess()

        return winners
    }
}
