import SwiftUI

/// グループの「今日の状態」を判定する純粋なロジック。TodayView.computeState、
/// GroupSwitcherHeader.statusLine、Home画面のグループ一覧、GroupHomeDetailViewが
/// それぞれ独自に同じ判定を再実装すると以前指摘のあった「ロジックの二重管理」に
/// なるため、ここに一本化する。副作用は一切持たない。
enum GroupDailyState: Equatable {
    /// 現在進行中サイクルの撮影状況。hasStarted: 今サイクルで1枚でも撮影されたか。
    /// achievedCount/memberCount: 個人の最低枚数を達成したメンバー数/全メンバー数。
    /// groupTotal/groupTarget: グループ全体の合計枚数/目標枚数。
    /// 時間帯制限の撤廃に伴い締切(deadline)は無くなり、達成した瞬間に解禁される。
    case shooting(hasStarted: Bool, achievedCount: Int, memberCount: Int, groupTotal: Int, groupTarget: Int)
    /// since: 直近の解禁が起きた瞬間(LaterGroup.lastUnlockAt)。次のサイクルで
    /// 誰か1人でも撮影を始めた時点で.shootingへ自然に戻る。閲覧可能期間は
    /// 次の解禁まで無期限(オープンエンド)。
    case unlocked(since: Date)
}

enum GroupStatusPresenter {
    static func state(for group: LaterGroup, now: Date = Date(), calendar: Calendar = .current) -> GroupDailyState {
        let currentCyclePhotos = group.currentCyclePhotos(now: now, calendar: calendar)
        let currentCycleVideos = group.currentCycleVideos(now: now, calendar: calendar)
        let currentCycleTotal = currentCyclePhotos.count + currentCycleVideos.count

        if group.isPersonalSpace {
            // MEには「全員達成」という概念が無い。共同投票フェーズも存在しないため、
            // 目標枚数に到達しているかどうかだけを示す。
            return .shooting(
                hasStarted: currentCycleTotal > 0,
                achievedCount: currentCycleTotal >= group.personalDailyTargetCount ? 1 : 0,
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
        /// 解禁中は使わない(nilならプレーンなラベルだけを表示する)。
        let blocks: (primary: String, secondary: String, tertiary: String)?
        let valueColor: Color
    }

    /// 撮影中: ラベル「みんなの撮影を待っています」・数字は「達成人数/全体人数/合計枚数」を緑で。
    /// 解禁中: 締切という概念が無くなったため、カウントダウンではなく静的な「解禁中」表示にする。
    static func content(for state: GroupDailyState) -> Content {
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
                valueColor: Color.brandGreen
            )
        case .unlocked:
            return Content(
                label: "解禁中",
                labelColor: .white.opacity(0.6),
                blocks: nil,
                valueColor: Color.brandGreen
            )
        }
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
                        primaryLabel: "達成",
                        secondaryLabel: "人数",
                        tertiaryLabel: "枚数",
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
