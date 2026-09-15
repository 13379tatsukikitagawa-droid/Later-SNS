import Foundation

/// グループの解禁条件を判定する純粋なロジック。副作用は一切持たない。
/// 実際にisUnlockedを立てたり画像を再送したりする処理は呼び出し側
/// (CloudKitManager/TodayView)が行う。
///
/// ■ 解禁方式(2026/9 固定9:00解禁の再導入)
/// 「その日の好きなタイミングで撮影できる」という撮影側の自由度は維持するが、
/// 解禁(閲覧可能になるタイミング)は「撮影日の翌朝9:00」で全ユーザー共通に固定する。
/// 撮影時刻はランダムでよいが、解禁時刻はいつも9:00、という構造。
/// 解禁条件は「グループ全員が基本撮影枠(1枚)を達成していること」と「9:00に到達していること」の
/// 両方が揃うことになった(isAllMembersShotCompleted/shouldUnlockと、
/// isUnlockTimeReachedをAND)。全員揃っていても9:00前なら非公開のままになる。
/// 「サイクル」の境界(=いつからいつまでの写真を今回の目標達成としてカウントするか)は、
/// 日付からの計算ではなく、LaterGroup.lastUnlockAt(直近に実際に解禁が起きた瞬間、
/// 全メンバー間で同期される)になった。LaterGroup.currentCyclePhotos/
/// mostRecentCyclePhotos参照。
///
/// ■ 個人の撮影枚数・目標枚数のルール(変更なし)
/// - 個人の基本撮影枠は1日1枚。全員がこの1枚を撮り終えている必要がある。
/// - 1人が1サイクルに撮影できる上限も、最低枚数と同じ1枚(individualMaximumPhotoCountPerMember)。
/// - グループ全体の目標枚数は「メンバー数×1」、つまりグループの人数がそのまま目標枚数になる。
///
/// ■ 投票フェーズについて
/// 投票フェーズは既に実行経路から撤去済み(VotingManager.shared.castVote等の呼び出しは
/// 実行経路から外している。除外対象の旧UIがVotingManagerのAPIを直接参照しているため、
/// ファイル自体は削除していない)。
enum GroupUnlockPolicy {
    /// 個人の基本撮影枠(1人が1サイクルに必ず撮る必要がある最低枚数)。
    /// 全メンバーがこれを満たすことが「全員撮影完了」の条件になる。
    static let individualMinimumPhotoCount = 1

    /// 通常グループ(ME以外)で1人が1サイクルに撮影できる上限。
    static let individualMaximumPhotoCountPerMember = individualMinimumPhotoCount

    /// そのサイクル・そのグループの目標枚数 = メンバー数×individualMaximumPhotoCountPerMember(=1)。
    /// つまりグループの人数がそのまま目標枚数になる。
    static func dailyTargetPhotoCount(memberCount: Int) -> Int {
        guard memberCount > 0 else { return 0 }
        return memberCount * individualMaximumPhotoCountPerMember
    }

    /// グループ全員が基本撮影枠(1枚)を撮り終えているか。解禁条件(shouldUnlock)の
    /// 前提条件として使う。
    static func isAllMembersShotCompleted(memberIDs: Set<UUID>, todaysPhotoCountsByAuthor: [UUID: Int]) -> Bool {
        guard !memberIDs.isEmpty else { return false }
        return memberIDs.allSatisfy { (todaysPhotoCountsByAuthor[$0] ?? 0) >= individualMinimumPhotoCount }
    }

    /// 「今この人が撮ってよい上限枚数」。MEはユーザー自身が設定した当日の目標枚数
    /// (personalDailyTargetCount)に合わせ、それ以外の通常グループは常に
    /// individualMaximumPhotoCountPerMemberを返す。
    static func individualMaximumPhotoCount(for group: LaterGroup, date: Date = Date(), calendar: Calendar = .current) -> Int {
        if group.isPersonalSpace {
            return max(individualMinimumPhotoCount, group.personalDailyTargetCount)
        }
        return individualMaximumPhotoCountPerMember
    }

    /// 条件(全メンバーが基本撮影枠を達成・グループ全体が目標枚数に到達)が揃っているか
    /// どうかを判定する。**これは「撮影が完了しているか」だけの判定であり、
    /// 実際に解禁してよいかどうかにはisUnlockTimeReached()もANDする必要がある**
    /// (呼び出し側のCloudKitManager.evaluateGroupUnlockConditions参照)。
    ///
    /// - Parameters:
    ///   - currentCyclePhotoCountsByAuthor: 現在進行中サイクル(LaterGroup.
    ///     currentCyclePhotos参照)の撮影者ごとの枚数。
    static func shouldUnlock(
        memberIDs: Set<UUID>,
        currentCyclePhotoCountsByAuthor: [UUID: Int]
    ) -> Bool {
        // 条件1: 全メンバーが基本撮影枠(1枚)を達成している
        guard isAllMembersShotCompleted(memberIDs: memberIDs, todaysPhotoCountsByAuthor: currentCyclePhotoCountsByAuthor) else { return false }

        // 条件2: グループ全体が目標枚数(メンバー数)に到達している
        let totalPhotos = currentCyclePhotoCountsByAuthor.values.reduce(0, +)
        let target = dailyTargetPhotoCount(memberCount: memberIDs.count)
        return totalPhotos >= target
    }

    /// 個人スペース(ME)向けの解禁判定。共同投票が無いため「全員が基本枠を達成し、
    /// グループ全体が目標枚数に到達する」という条件(shouldUnlock)は適用せず、代わりに
    /// 「その日ユーザー自身が設定した目標撮影枚数(targetCount)に到達しているか」だけを見る。
    /// これも「撮影が完了しているか」だけの判定であり、isUnlockTimeReached()を別途ANDする。
    static func shouldUnlockPersonalSpace(shotCount: Int, targetCount: Int) -> Bool {
        shotCount >= max(individualMinimumPhotoCount, targetCount)
    }

    /// 撮影日の翌朝9:00(ローカルタイムゾーン基準)を返す。この時刻が実際の解禁時刻
    /// (unlockAt)になる。撮影時刻がいつであっても「翌朝9:00」に揃う。
    static func nextUnlockThreshold(after captureDate: Date, calendar: Calendar = .current) -> Date {
        let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: captureDate)) ?? captureDate
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: nextDay) ?? nextDay
    }

    /// 「時刻ゲート」が開いているか(=now >= unlockAt)。shouldUnlock/shouldUnlockPersonalSpaceの
    /// 撮影完了判定と別にANDして使う。unlockAtは通常、サイクル内の各写真/動画が既に
    /// 持っているunlockDate(nextUnlockThresholdで撮影時に確定済み)の最大値を渡す。
    static func isUnlockTimeReached(unlockAt: Date, now: Date = Date()) -> Bool {
        now >= unlockAt
    }
}
