import Foundation

/// 節目の記憶(7日前・1ヶ月前・半年前・1年前・2年前...)を判定する純粋なロジック。
/// 副作用は既読フラグの読み書き(UserDefaults)のみに限定している。
struct MemoryMatch: Identifiable {
    let id = UUID()
    let offsetLabel: String
    let targetDate: Date
    let photo: LaterPhoto
    let group: LaterGroup
}

enum MemorySurpriseManager {
    private struct Milestone {
        let label: String
        let dateAdding: (Date, Calendar) -> Date?
    }

    /// 遠い過去から順に並べる(先にマッチした方を優先するため)。
    private static func milestones(maxYears: Int = 20) -> [Milestone] {
        var result: [Milestone] = []
        if maxYears >= 3 {
            for year in stride(from: maxYears, through: 3, by: -1) {
                result.append(Milestone(label: "\(year)年前の今日") { today, cal in
                    cal.date(byAdding: .year, value: -year, to: today)
                })
            }
        }
        result.append(Milestone(label: "2年前の今日") { today, cal in cal.date(byAdding: .year, value: -2, to: today) })
        result.append(Milestone(label: "1年前の今日") { today, cal in cal.date(byAdding: .year, value: -1, to: today) })
        result.append(Milestone(label: "半年前の今日") { today, cal in cal.date(byAdding: .month, value: -6, to: today) })
        result.append(Milestone(label: "1ヶ月前の今日") { today, cal in cal.date(byAdding: .month, value: -1, to: today) })
        result.append(Milestone(label: "1週間前の今日") { today, cal in cal.date(byAdding: .day, value: -7, to: today) })
        return result
    }

    /// ユーザーが所属する全グループの写真から、今日チェックすべき節目の記憶を1件だけ返す。
    /// 既に今日開封済みならnilを返す(1日1件・既読で非表示の原則)。
    static func findMemory(
        in groups: [LaterGroup],
        preferredGroupID: UUID?,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> MemoryMatch? {
        guard !isSeenToday(today, calendar: calendar) else { return nil }

        for milestone in milestones() {
            guard let targetDate = milestone.dateAdding(today, calendar) else { continue }
            if let match = bestMatch(for: targetDate, in: groups, preferredGroupID: preferredGroupID, calendar: calendar) {
                return MemoryMatch(offsetLabel: milestone.label, targetDate: targetDate, photo: match.photo, group: match.group)
            }
        }
        return nil
    }

    /// 現在選択中のグループを最優先し、その中ではグループのベストショットを優先する。
    private static func bestMatch(
        for targetDate: Date,
        in groups: [LaterGroup],
        preferredGroupID: UUID?,
        calendar: Calendar
    ) -> (photo: LaterPhoto, group: LaterGroup)? {
        let orderedGroups = groups.sorted { a, _ in a.id == preferredGroupID }

        for group in orderedGroups {
            let candidates = group.photos
                .filter { $0.isUnlocked && calendar.isDate($0.captureDate, inSameDayAs: targetDate) }
            guard !candidates.isEmpty else { continue }

            if let best = candidates.first(where: { $0.isGroupBestShot }) {
                return (best, group)
            }
            if let earliest = candidates.sorted(by: { $0.captureDate < $1.captureDate }).first {
                return (earliest, group)
            }
        }
        return nil
    }

    // MARK: - 既読管理(UserDefaults、今日の日付キーで管理)

    private static let seenDatesKey = "memorySurpriseSeenDates"

    private static func dateKey(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func isSeenToday(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let seen = UserDefaults.standard.stringArray(forKey: seenDatesKey) ?? []
        return seen.contains(dateKey(for: date, calendar: calendar))
    }

    /// カードをタップして「開封」した瞬間に呼ぶ(表示しただけでは既読にしない)。
    static func markSeenToday(_ date: Date = Date(), calendar: Calendar = .current) {
        var seen = Set(UserDefaults.standard.stringArray(forKey: seenDatesKey) ?? [])
        seen.insert(dateKey(for: date, calendar: calendar))
        UserDefaults.standard.set(Array(seen), forKey: seenDatesKey)
    }
}
