import SwiftUI

/// グループの「今日の状態」を判定する純粋なロジック。TodayView.computeState、
/// GroupSwitcherHeader.statusLine、Home画面のグループ一覧、GroupHomeDetailViewが
/// それぞれ独自に同じ判定を再実装すると以前指摘のあった「ロジックの二重管理」に
/// なるため、ここに一本化する。副作用は一切持たない。
enum GroupDailyState: Equatable {
    /// 現在進行中サイクルの撮影状況。hasStarted: 今サイクルで1枚でも撮影されたか。
    /// achievedCount/memberCount: 個人の最低枚数を達成したメンバー数/全メンバー数。
    /// groupTotal/groupTarget: グループ全体の合計枚数/目標枚数。
    case shooting(hasStarted: Bool, achievedCount: Int, memberCount: Int, groupTotal: Int, groupTarget: Int)
    /// 撮影条件(全員撮影完了)は揃っているが、解禁時刻(翌朝9:00、unlockAt)にまだ
    /// 到達していない状態。「みんなの今日がそろいました」というメッセージと、
    /// unlockAtまでのカウントダウンをUI側で表示する。
    case waitingForUnlockTime(achievedCount: Int, memberCount: Int, unlockAt: Date)
    /// since: 直近の解禁が起きた瞬間(LaterGroup.lastUnlockAt)。次のサイクルで
    /// 誰か1人でも撮影を始めた時点で.shootingへ自然に戻る。閲覧可能期間は
    /// 次の解禁まで無期限(オープンエンド)。
    case unlocked(since: Date)

    /// 撮影ノルマ(全員撮影完了)を満たしているかどうか。.waitingForUnlockTime/.unlockedは
    /// 定義上常にtrue、.shootingはgroupTotal/groupTargetで判定する(条件成立直後、
    /// まだこの状態から.waitingForUnlockTimeへの遷移が反映されていない一瞬だけ
    /// .shootingのままtrueになりうる)。GroupHomeDetailView.checkGoalJustReached参照。
    var isShotGoalMet: Bool {
        switch self {
        case .shooting(_, _, _, let groupTotal, let groupTarget):
            return groupTarget > 0 && groupTotal >= groupTarget
        case .waitingForUnlockTime, .unlocked:
            return true
        }
    }
}

enum GroupStatusPresenter {
    static func state(for group: LaterGroup, now: Date = Date(), calendar: Calendar = .current) -> GroupDailyState {
        let currentCyclePhotos = group.currentCyclePhotos(now: now, calendar: calendar)
        let currentCycleVideos = group.currentCycleVideos(now: now, calendar: calendar)
        let currentCycleTotal = currentCyclePhotos.count + currentCycleVideos.count

        // 現在サイクルの写真/動画がそれぞれ確定させているunlockDate(翌朝9:00)の最大値。
        // CloudKitManager.runUnlockEvaluationが実際の解禁判定に使う値と同じ計算方法。
        func candidateUnlockAt() -> Date {
            (currentCyclePhotos.map(\.unlockDate) + currentCycleVideos.map(\.unlockDate)).max() ?? now
        }

        if group.isPersonalSpace {
            // MEには「全員達成」という概念が無い。共同投票フェーズも存在しないため、
            // 目標枚数に到達しているかどうかだけを示す。
            let shotConditionMet = GroupUnlockPolicy.shouldUnlockPersonalSpace(shotCount: currentCycleTotal, targetCount: group.personalDailyTargetCount)
            if shotConditionMet {
                let unlockAt = candidateUnlockAt()
                if !GroupUnlockPolicy.isUnlockTimeReached(unlockAt: unlockAt, now: now) {
                    return .waitingForUnlockTime(achievedCount: 1, memberCount: 1, unlockAt: unlockAt)
                }
            }
            return .shooting(
                hasStarted: currentCycleTotal > 0,
                achievedCount: shotConditionMet ? 1 : 0,
                memberCount: 1,
                groupTotal: currentCycleTotal,
                groupTarget: group.personalDailyTargetCount
            )
        }

        // 現在進行中サイクルにまだ1枚も無く、かつ過去に一度でも解禁されたことがあるなら、
        // 「直近解禁されたばかりで、次のサイクルはまだ誰も撮っていない」状態。
        // 次のサイクルで誰か1人でも撮影すれば.shootingへ自然に戻る。
        if currentCycleTotal == 0, let lastUnlockAt = group.lastUnlockAt {
            return .unlocked(since: lastUnlockAt)
        }

        let memberIDs = group.deduplicatedMemberIDs
        // 以前はmemberIDsごとにcurrentCyclePhotos全体をフィルタしており、
        // 「メンバー数×現在サイクルの写真数」に比例する計算量だった。事前に1回だけ
        // 撮影者IDごとの枚数を数えることで、「現在サイクルの写真数」1回分に削減する。
        var countsByOwnerID: [UUID: Int] = [:]
        for photo in currentCyclePhotos {
            guard let ownerID = photo.owner?.id else { continue }
            countsByOwnerID[ownerID, default: 0] += 1
        }
        for video in currentCycleVideos {
            guard let ownerID = video.owner?.id else { continue }
            countsByOwnerID[ownerID, default: 0] += 1
        }
        let achievedCount = memberIDs.filter { (countsByOwnerID[$0] ?? 0) >= GroupUnlockPolicy.individualMinimumPhotoCount }.count
        let groupTarget = GroupUnlockPolicy.dailyTargetPhotoCount(memberCount: memberIDs.count)

        let shotConditionMet = GroupUnlockPolicy.shouldUnlock(memberIDs: Set(memberIDs), currentCyclePhotoCountsByAuthor: countsByOwnerID)
        if shotConditionMet {
            let unlockAt = candidateUnlockAt()
            if !GroupUnlockPolicy.isUnlockTimeReached(unlockAt: unlockAt, now: now) {
                return .waitingForUnlockTime(achievedCount: achievedCount, memberCount: memberIDs.count, unlockAt: unlockAt)
            }
        }
        return .shooting(
            hasStarted: currentCycleTotal > 0,
            achievedCount: achievedCount,
            memberCount: memberIDs.count,
            groupTotal: currentCycleTotal,
            groupTarget: groupTarget
        )
    }
}

// MARK: - 状態の見た目(ラベル・色・数字)への変換

enum CountdownPresentation {
    struct Content {
        let label: String
        let labelColor: Color
        /// スコアボードの3ブロックに表示する値。撮影中は「達成人数/全体人数/合計枚数」、
        /// 時刻待ち中は「達成人数/全体人数/解禁までの残り時間」、解禁中は使わない
        /// (nilならプレーンなラベルだけを表示する)。
        let blocks: (primary: String, secondary: String, tertiary: String)?
        /// blocksの3ブロックそれぞれの見出し文言。状態によって変わる。
        let blockLabels: (primary: String, secondary: String, tertiary: String)
        let valueColor: Color
    }

    private static let defaultBlockLabels = (primary: "達成", secondary: "人数", tertiary: "枚数")

    /// 撮影中: ラベル「みんなの撮影を待っています」・数字は「達成人数/全体人数/合計枚数」を緑で。
    /// 時刻待ち中: 全員撮影完了済みだが翌朝9:00未到達。「みんなの今日がそろいました」+
    /// 解禁までの残り時間を表示する。
    /// 解禁中: 締切という概念が無くなったため、カウントダウンではなく静的な「解禁中」表示にする。
    static func content(for state: GroupDailyState, now: Date = Date()) -> Content {
        switch state {
        case .shooting(_, let achievedCount, let memberCount, let groupTotal, let groupTarget):
            return Content(
                label: "みんなの撮影を待っています",
                labelColor: .white.opacity(0.45),
                blocks: (
                    primary: "\(achievedCount)",
                    secondary: "\(memberCount)",
                    tertiary: "\(groupTotal)/\(groupTarget)"
                ),
                blockLabels: defaultBlockLabels,
                valueColor: Color.brandGreen
            )
        case .waitingForUnlockTime(let achievedCount, let memberCount, let unlockAt):
            return Content(
                label: "みんなの今日がそろいました。翌朝9:00に解禁されます",
                labelColor: .white.opacity(0.6),
                blocks: (
                    primary: "\(achievedCount)",
                    secondary: "\(memberCount)",
                    tertiary: formatRemaining(until: unlockAt, from: now)
                ),
                blockLabels: (primary: "達成", secondary: "人数", tertiary: "解禁まで"),
                valueColor: Color.brandGreen
            )
        case .unlocked:
            return Content(
                label: "解禁中",
                labelColor: .white.opacity(0.6),
                blocks: nil,
                blockLabels: defaultBlockLabels,
                valueColor: Color.brandGreen
            )
        }
    }

    /// unlockAtまでの残り時間を「8時間32分」のような短い文言にする。既に過ぎていれば
    /// "まもなく"(次のローカル時刻ゲート再チェックで解禁されるはずの端境期)を返す。
    private static func formatRemaining(until unlockAt: Date, from now: Date) -> String {
        let remaining = unlockAt.timeIntervalSince(now)
        guard remaining > 0 else { return "まもなく" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 { return "\(hours)時間\(minutes)分" }
        return "\(minutes)分"
    }
}

// MARK: - 状態表示バッジ(Home画面・グループ詳細画面で共用)

struct AdaptiveCountdownBadge: View {
    let state: GroupDailyState?

    private static let blockBackground = Color(red: 0.106, green: 0.106, blue: 0.098) // #1b1b19、背景よりはっきり明るくして境界を見やすくする
    private static let dummyColor = Color.white.opacity(0.35)

    var body: some View {
        if let state {
            let content = CountdownPresentation.content(for: state)
            VStack(spacing: 8) {
                Text(content.label)
                    .font(.system(size: 12))
                    .foregroundStyle(content.labelColor)
                    .kerning(1.4)

                if let blocks = content.blocks {
                    scoreboard(
                        primary: blocks.primary,
                        secondary: blocks.secondary,
                        tertiary: blocks.tertiary,
                        primaryLabel: content.blockLabels.primary,
                        secondaryLabel: content.blockLabels.secondary,
                        tertiaryLabel: content.blockLabels.tertiary,
                        color: content.valueColor
                    )
                }
            }
        } else {
            // 未参加などでグループの状態自体が無い場合のダミー表示。
            VStack(spacing: 8) {
                Text("みんなの撮影を待っています")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.3))
                    .kerning(1.4)

                scoreboard(primary: "--", secondary: "--", tertiary: "--", primaryLabel: "達成", secondaryLabel: "人数", tertiaryLabel: "枚数", color: Self.dummyColor)
            }
        }
    }

    private func scoreboard(primary: String, secondary: String, tertiary: String, primaryLabel: String, secondaryLabel: String, tertiaryLabel: String, color: Color) -> some View {
        HStack(spacing: 6) {
            block(text: primary, label: primaryLabel, color: color)
            separator(color: color)
            block(text: secondary, label: secondaryLabel, color: color)
            separator(color: color)
            block(text: tertiary, label: tertiaryLabel, color: color)
        }
    }

    private func block(text: String, label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(text)
                .font(.custom("Courier New", size: 26).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.5), radius: 4)

            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(width: 54)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Self.blockBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(color.opacity(0.55), lineWidth: 1.5)
        )
    }

    private func separator(color: Color) -> some View {
        Text("/")
            .font(.custom("Courier New", size: 24).weight(.bold))
            .foregroundStyle(color.opacity(0.65))
            .offset(y: -11)
    }
}
