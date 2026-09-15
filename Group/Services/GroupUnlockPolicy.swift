import Foundation

/// グループの解禁条件を判定する純粋なロジック。副作用は一切持たない。
/// 実際にisUnlockedを立てたり画像を再送したりする処理は呼び出し側
/// (CloudKitManager/TodayView)が行う。
///
/// ■ 解禁方式(時間帯制限撤廃後)
/// 「その日の好きなタイミングで撮影できる」という設計に合わせ、解禁時刻の
/// ランダム決定・クールダウン・撮影締切といった時間帯制限は撤廃した。
/// 解禁条件は「グループ全員が基本撮影枠(1枚)を達成し、かつグループ全体が
/// 目標枚数(メンバー数)に到達していること」だけになり、達成した瞬間に解禁される。
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
    /// どうかを判定する。時間帯制限の撤廃に伴い、達成した瞬間に解禁してよい
    /// (以前あった「解禁時刻に到達するまで解禁しない」というゲートは無くなった)。
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
    /// 時間帯制限の撤廃に伴い、目標枚数に到達した瞬間に解禁してよい。
    static func shouldUnlockPersonalSpace(shotCount: Int, targetCount: Int) -> Bool {
        shotCount >= max(individualMinimumPhotoCount, targetCount)
    }
}
