import SwiftUI
import SwiftData

/// v110 §5:Trip 一覧の 決まり(純粋な 計算。テスト できる)。日にちを 作り話で うめない。
enum TripPhase: Equatable { case live, upcoming, ended }

struct TripHubItem: Identifiable {
    let id: UUID
    var name: String
    var members: Int
    var memberImages: [UIImage?] = []
    var memberNames: [String] = []
    var cover: UIImage?
    var start: Date?
    var end: Date?
    var created: Date
    /// 0 pink ・ 1 sky ・ 2 sun ・ 3 lime
    var color: Int
    var shotsToday = 0
    var photoCount = 0
    var perDay = 23
}

enum TripHubRules {
    /// 日にちが ない 古い Trip を「いま」に 出す 期間(作って から 7日)
    static let undatedLiveDays = 7

    /// 作った 順に pink → sky → sun → lime
    static func nextColor(existing: [LaterGroup]) -> Int {
        existing.filter { !$0.isPersonalSpace }.count % 4
    }

    /// 保存された 色が あれば それ。なければ 作った 順(古い 方から)で きめる
    static func resolveColors(_ groups: [LaterGroup]) -> [UUID: Int] {
        let sorted = groups.filter { !$0.isPersonalSpace }.sorted { $0.creationDate < $1.creationDate }
        var out: [UUID: Int] = [:]
        for (i, g) in sorted.enumerated() { out[g.id] = (0..<4).contains(g.tripColor) ? g.tripColor : i % 4 }
        return out
    }

    /// いま / これから / おわった。`needsDates` = 日にちが 無い のに「いま」に 出して いる(日にちを 入れる タグ)
    static func phase(start: Date?, end: Date?, created: Date, now: Date, cal: Calendar = .current) -> (phase: TripPhase, needsDates: Bool) {
        let today = cal.startOfDay(for: now)
        if let s = start.map({ cal.startOfDay(for: $0) }), let e = end.map({ cal.startOfDay(for: $0) }) {
            if today < s { return (.upcoming, false) }
            if today > e { return (.ended, false) }
            return (.live, false)
        }
        let age = cal.dateComponents([.day], from: cal.startOfDay(for: created), to: today).day ?? 0
        return age <= undatedLiveDays ? (.live, true) : (.ended, false)
    }

    static func counts(_ items: [TripHubItem], now: Date, cal: Calendar = .current) -> (live: Int, upcoming: Int, ended: Int) {
        var l = 0, u = 0, e = 0
        for t in items {
            switch phase(start: t.start, end: t.end, created: t.created, now: now, cal: cal).phase { case .live: l += 1; case .upcoming: u += 1; case .ended: e += 1 }
        }
        return (l, u, e)
    }

    /// その 週の 月曜(月曜はじまり)
    static func weekStart(of date: Date, cal: Calendar = .current) -> Date {
        let d = cal.startOfDay(for: date)
        let wd = cal.component(.weekday, from: d)           // 1 = 日
        let back = (wd + 5) % 7                              // 月 = 0 … 日 = 6
        return cal.date(byAdding: .day, value: -back, to: d) ?? d
    }

    static func dayIndex(_ date: Date, weekStart: Date, cal: Calendar = .current) -> Int {
        cal.dateComponents([.day], from: weekStart, to: cal.startOfDay(for: date)).day ?? 0
    }

    struct Segment: Identifiable, Equatable {
        let id: UUID
        var lane: Int
        var first: Int        // 0…6
        var last: Int         // 0…6
        var startsHere: Bool
        var endsHere: Bool
    }

    /// 週の 帯の 線。日にちの ある Trip だけ。同じ 日に かさなる 時は 段を ふやす(3段 まで ・ それ 以上は overflow)
    static func segments(_ items: [TripHubItem], weekStart: Date, cal: Calendar = .current) -> (segments: [Segment], overflow: [Int: Int]) {
        let dated = items.compactMap { t -> (TripHubItem, Int, Int)? in
            guard let s = t.start, let e = t.end else { return nil }
            let a = dayIndex(s, weekStart: weekStart, cal: cal), b = dayIndex(e, weekStart: weekStart, cal: cal)
            guard b >= 0, a <= 6 else { return nil }
            return (t, a, b)
        }.sorted { ($0.1, $0.0.created) < ($1.1, $1.0.created) }
        var lanes: [[(Int, Int)]] = []
        var segs: [Segment] = []
        var overflow: [Int: Int] = [:]
        for (t, a, b) in dated {
            let first = max(0, a), last = min(6, b)
            var placed = -1
            for (i, lane) in lanes.enumerated() where !lane.contains(where: { $0.0 <= last && first <= $0.1 }) { placed = i; break }
            if placed < 0 { lanes.append([]); placed = lanes.count - 1 }
            lanes[placed].append((first, last))
            if placed < 3 { segs.append(.init(id: t.id, lane: placed, first: first, last: last, startsHere: a >= 0, endsHere: b <= 6)) }
            else { for d in first...last { overflow[d, default: 0] += 1 } }
        }
        return (segs, overflow)
    }

    /// ある 日に かかる Trip(日にち ありだけ)
    static func trips(on day: Date, in items: [TripHubItem], cal: Calendar = .current) -> [TripHubItem] {
        let d = cal.startOfDay(for: day)
        return items.filter { t in
            guard let s = t.start, let e = t.end else { return false }
            return cal.startOfDay(for: s) <= d && d <= cal.startOfDay(for: e)
        }
    }

    static func dayNumber(start: Date, now: Date, cal: Calendar = .current) -> Int {
        max(1, (cal.dateComponents([.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: now)).day ?? 0) + 1)
    }
    static func totalDays(start: Date, end: Date, cal: Calendar = .current) -> Int {
        max(1, (cal.dateComponents([.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: end)).day ?? 0) + 1)
    }
    static func daysUntil(_ start: Date, now: Date, cal: Calendar = .current) -> Int {
        max(0, cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: start)).day ?? 0)
    }

    /// 一覧用の まとめ(サムネ だけ。写真の 本体は 読まない)
    @MainActor static func items(from groups: [LaterGroup], now: Date = Date(), cal: Calendar = .current) -> [TripHubItem] {
        let trips = groups.filter { !$0.isPersonalSpace }
        let colors = resolveColors(trips)
        return trips.map { g in
            let today = g.photos.lazy.filter { cal.isDate($0.captureDate, inSameDayAs: now) }.count
            return TripHubItem(
                id: g.id, name: g.name, members: g.members.count,
                memberImages: g.members.prefix(4).map { V64Images.image(key: "tm\($0.id)", data: $0.profileImageData, maxPixel: 96) },
                memberNames: g.members.prefix(4).map(\.name),
                cover: V64Images.image(key: "tg\(g.id)", data: g.iconImageData, maxPixel: 480),
                start: g.tripStart, end: g.tripEnd, created: g.creationDate, color: colors[g.id] ?? 0,
                shotsToday: today, photoCount: g.photos.count)
        }
    }
}
