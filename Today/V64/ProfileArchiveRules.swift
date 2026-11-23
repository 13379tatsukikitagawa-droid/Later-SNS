import Foundation

// P58 B(v132 2章):プロフィール = アーカイブ。ひらいた 日の 数え方(画面を 持たない)。
// 1マス = 1日。きょうの マスは 写真を 出さない。9:00 まえは きのうの マスも 鍵(`PhotoDevelop` と 同じ 1つの 判定)。

struct ProfileDayCell: Identifiable, Equatable {
    enum Kind: Equatable { case today, locked, opened }
    var day: Date
    var kind: Kind
    /// today = きょう 撮った 枚数 ・ locked = まだ ひらいて いない 枚数 ・ opened = ひらいた 枚数
    var count: Int
    /// opened の 表紙(その 日の 1枚目 = いちばん 早く 撮った ひらいた 写真)の 番号
    var coverIndex: Int?
    var id: Date { day }
}

enum ProfileArchiveRules {
    /// 新しい 日が 先。いちばん 前は かならず きょうの マス
    static func cells(_ dates: [Date], now: Date, cal: Calendar = .current) -> [ProfileDayCell] {
        let today = cal.startOfDay(for: now)
        var byDay: [Date: [(Int, Date)]] = [:]
        for (i, d) in dates.enumerated() { byDay[cal.startOfDay(for: d), default: []].append((i, d)) }
        var out = [ProfileDayCell(day: today, kind: .today, count: byDay[today]?.count ?? 0, coverIndex: nil)]
        for day in byDay.keys.filter({ $0 < today }).sorted(by: >) {
            let photos = byDay[day] ?? []
            let developed = photos.filter { PhotoDevelop.isDeveloped(takenAt: $0.1, now: now, calendar: cal) }
            if let first = developed.min(by: { $0.1 < $1.1 }) {
                out.append(ProfileDayCell(day: day, kind: .opened, count: developed.count, coverIndex: first.0))
            } else {
                out.append(ProfileDayCell(day: day, kind: .locked, count: photos.count, coverIndex: nil))
            }
        }
        return out
    }

    /// 日 ひらいた
    static func openedDays(_ cells: [ProfileDayCell]) -> Int { cells.filter { $0.kind == .opened }.count }

    /// 日 れんぞく:きょう(まだ なくても よい)から さかのぼって、撮った 日が つづく 数
    static func streak(_ dates: [Date], now: Date, cal: Calendar = .current) -> Int {
        let days = Set(dates.map { cal.startOfDay(for: $0) })
        var day = cal.startOfDay(for: now)
        if !days.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day) ?? day }
        var n = 0
        while days.contains(day) { n += 1; day = cal.date(byAdding: .day, value: -1, to: day) ?? day }
        return n
    }

    /// 「2026年11月 から」
    static func sinceLabel(_ first: Date?, now: Date, cal: Calendar = .current) -> String {
        let d = first ?? now
        return "\(cal.component(.year, from: d))年\(cal.component(.month, from: d))月 から"
    }
}
