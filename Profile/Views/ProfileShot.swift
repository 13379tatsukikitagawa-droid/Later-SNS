import SwiftUI

/// その日の1枚が届いているグループ(MEは含めない)。
struct ProfileShareGroup: Equatable {
    let name: String
    /// 自分以外のメンバーの人数
    let otherMemberCount: Int
}

/// Profile に並べる写真の判定。点のフィールド・全画面ビューア・日付レールは、必ずここの結果を使う。
///
/// 出すのは「グループに共有した、毎日の1枚」だけ(直近7日・1日1枚)。
/// アイコン写真(UserProfile.profileImageData)・7日すぎ・自分で消した・MEにしか無い写真は出さない。
enum ProfileShot {
    /// レールの枠の数(写真の数にかかわらず、いつも7つ)
    static let railSlotCount = DailyExposureRules.photoRetentionDays

    /// 1日分の材料。ExposureDay(色・場所)と、その日のLaterPhoto(グループ・タグ)から作る。
    struct Source {
        let dayKey: String
        let captureDate: Date
        let colorHex: String?
        let locationName: String?
        let tags: [String]
        /// 空なら、どのグループにも共有していない(=出さない)
        let groups: [ProfileShareGroup]
        let isOnMondo: Bool
        /// 「投稿する」を選んだか。ひらいた日は、投稿した1枚だけを出す
        /// (まだひらいていない今日の1枚は、決める前なので出す)
        var isPosted = true
    }

    /// Profile に出す日(古い順)。プロフィール画面(星・フィルム)は、必ずこの結果を使う。
    static func shots(profile: UserProfile?, exposureDays: [ExposureDay], now: Date) -> [WeekDayPoint] {
        guard let profile else { return [] }
        let groupsByID = Dictionary(profile.groups.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let photosByDay = Dictionary(grouping: profile.photos) { ExposureDayStore.dayKey(for: $0.captureDate) }
        let published = Set(MondoLocalStore.published)
        let mondoID = MondoIdentity.id
        // 1日1件なので、7日ぶんを見るには新しい数件で足りる
        let sources = exposureDays.prefix(railSlotCount + 3).map { day -> Source in
            let photos = photosByDay[day.dayKey] ?? []
            var seenGroups = Set<UUID>()
            var groups: [ProfileShareGroup] = []
            for photo in photos {
                guard let groupID = photo.groupID, !seenGroups.contains(groupID),
                      let group = groupsByID[groupID], !group.isPersonalSpace else { continue }
                seenGroups.insert(groupID)
                groups.append(ProfileShareGroup(
                    name: group.name,
                    otherMemberCount: group.members.filter { $0.id != profile.id }.count
                ))
            }
            return Source(
                dayKey: day.dayKey,
                captureDate: day.captureDate,
                colorHex: day.colorHex,
                locationName: day.locationName,
                tags: photos.first?.tags ?? [],
                groups: groups,
                isOnMondo: published.contains(MondoIdentity.recordName(mondoID: mondoID, dayKey: day.dayKey)),
                isPosted: photos.allSatisfy(\.isPosted)
            )
        }
        return visibleShots(from: Array(sources), now: now)
    }

    /// 撮った日の翌朝9:00(ひらく時刻)。
    static func openDate(capturedAt: Date, calendar: Calendar = .current) -> Date {
        let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: capturedAt)) ?? capturedAt
        return calendar.date(byAdding: .hour, value: DailyExposureRules.openingHour, to: nextDay) ?? nextDay
    }

    static func isOpened(capturedAt: Date, now: Date, calendar: Calendar = .current) -> Bool {
        now >= openDate(capturedAt: capturedAt, calendar: calendar)
    }

    /// Profile に出す日。古い順 → 新しい順(最大7つ、1日1つ)。
    static func visibleShots(from sources: [Source], now: Date, calendar: Calendar = .current) -> [WeekDayPoint] {
        var seen = Set<String>()
        let shots = sources
            .sorted { $0.captureDate < $1.captureDate }
            .compactMap { source -> WeekDayPoint? in
                guard !source.groups.isEmpty, source.captureDate <= now, !seen.contains(source.dayKey) else { return nil }
                let remaining = DailyExposureRules.remainingDaysUntilExpiry(capturedAt: source.captureDate, now: now, calendar: calendar)
                guard remaining > 0 else { return nil }
                let opened = isOpened(capturedAt: source.captureDate, now: now, calendar: calendar)
                guard !opened || source.isPosted else { return nil }
                seen.insert(source.dayKey)
                return WeekDayPoint(
                    id: source.dayKey,
                    date: source.captureDate,
                    opened: opened,
                    color: opened ? source.colorHex.map { Color(hex: $0) } : nil,
                    locationName: source.locationName,
                    tags: source.tags,
                    showsPhoto: opened,
                    remainingDays: remaining,
                    groups: source.groups,
                    isOnMondo: source.isOnMondo
                )
            }
        return Array(shots.suffix(railSlotCount))
    }

    /// レールの7つの枠の日付キー。左が6日前、右端が今日。
    static func railDayKeys(now: Date, calendar: Calendar = .current) -> [String] {
        let today = calendar.startOfDay(for: now)
        return (0..<railSlotCount).map { index in
            let date = calendar.date(byAdding: .day, value: index - (railSlotCount - 1), to: today) ?? today
            let c = calendar.dateComponents([.year, .month, .day], from: date)
            // ExposureDayStore.dayKey と同じ形(「yyyy-MM-dd」)
            return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        }
    }

    /// フィルムの日付「'26 10 03」(撮った日)。
    static func filmStamp(for date: Date, calendar: Calendar = .current) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let c = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "'%02d %02d %02d", (c.year ?? 0) % 100, c.month ?? 0, c.day ?? 0)
    }

    /// 右上のピルの文言:「よいしょー ・ Mondo」「よいしょー ＋2」
    static func shareSummary(groups: [ProfileShareGroup], isOnMondo: Bool) -> String {
        var parts: [String] = []
        if let first = groups.first {
            parts.append(groups.count > 1 ? "\(first.name) ＋\(groups.count - 1)" : first.name)
        }
        if isOnMondo { parts.append("Mondo") }
        return parts.joined(separator: " ・ ")
    }

    /// 読み上げ用:「よいしょー、Mondo」
    static func spokenShareTargets(groups: [ProfileShareGroup], isOnMondo: Bool) -> String {
        (groups.map(\.name) + (isOnMondo ? ["Mondo"] : [])).joined(separator: "、")
    }
}
