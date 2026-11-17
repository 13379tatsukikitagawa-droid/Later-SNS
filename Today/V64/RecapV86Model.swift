import Foundation

// P29(v86)C:Recap が ちゃんと できる しくみ(端末の 中で つくる ・ 写真の 中身は 入れない ・ 数字 と ID だけ)。
// 週 = 毎週 月曜 9:00(前の 月〜日 ・ 3枚 以上)/ 月 = 毎月 1日 9:00(前の 月 ・ 5枚 以上 ・ 最大 30枚 ・ 1日 1枚)。
// 何度 呼ばれても 同じ id は 2つ 作らない(冪等)。

struct RecapShot: Equatable {
    let id: String
    let date: Date
    let tag: String?
    let kept: Bool
}

enum RecapKind: String, Codable { case week, month }
enum RecapState: String, Codable { case building, ready, seen }

struct RecapManifest: Codable, Identifiable, Equatable {
    var id: String
    var kind: RecapKind
    var start: Date
    var end: Date
    var photoIDs: [String]
    var shots: Int
    var days: Int
    var kept: Int
    var peakHour: Int?
    var topTag: String?
    var cover: String
    var state: RecapState
    var createdAt: Date
}

enum RecapRules {
    static let weekMin = 3
    static let monthMin = 5
    static let monthMax = 30
    static let buildHour = 9

    static func calendar() -> Calendar { var c = Calendar(identifier: .gregorian); c.firstWeekday = 2; c.timeZone = .current; return c }

    /// 日付を 含む 週の はじまり(月曜 0:00)
    static func weekStart(of d: Date, _ cal: Calendar = calendar()) -> Date {
        let day = cal.startOfDay(for: d)
        let wd = (cal.component(.weekday, from: day) + 5) % 7   // 月 = 0 … 日 = 6
        return cal.date(byAdding: .day, value: -wd, to: day) ?? day
    }

    static func weekID(_ start: Date, _ cal: Calendar = calendar()) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: start)
        return String(format: "w-%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
    static func monthID(_ start: Date, _ cal: Calendar = calendar()) -> String {
        let c = cal.dateComponents([.year, .month], from: start)
        return String(format: "m-%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    /// その Recap が できる 時刻(週 = 次の 月曜 9:00 ・ 月 = 翌月 1日 9:00)
    static func dueDate(weekStart s: Date, _ cal: Calendar = calendar()) -> Date {
        let next = cal.date(byAdding: .day, value: 7, to: s) ?? s
        return cal.date(bySettingHour: buildHour, minute: 0, second: 0, of: next) ?? next
    }
    static func dueDate(monthStart s: Date, _ cal: Calendar = calendar()) -> Date {
        let next = cal.date(byAdding: .month, value: 1, to: s) ?? s
        return cal.date(bySettingHour: buildHour, minute: 0, second: 0, of: next) ?? next
    }

    /// 作る べき なのに ない Recap を まとめて 返す(最近 `lookbackWeeks` 週 / `lookbackMonths` か月)
    static func missing(now: Date, shots: [RecapShot], existing: [RecapManifest], lookbackWeeks: Int = 12, lookbackMonths: Int = 6, _ cal: Calendar = calendar()) -> [RecapManifest] {
        let have = Set(existing.map(\.id))
        var out: [RecapManifest] = []
        let thisWeek = weekStart(of: now, cal)
        for k in 1...lookbackWeeks {
            guard let s = cal.date(byAdding: .day, value: -7 * k, to: thisWeek) else { continue }
            let id = weekID(s, cal)
            guard !have.contains(id), now >= dueDate(weekStart: s, cal) else { continue }
            guard let e = cal.date(byAdding: .day, value: 7, to: s) else { continue }
            let list = shots.filter { $0.date >= s && $0.date < e }.sorted { $0.date < $1.date }
            guard list.count >= weekMin else { continue }
            out.append(manifest(id: id, kind: .week, start: s, end: cal.date(byAdding: .day, value: -1, to: e) ?? e, picks: list, now: now, cal))
        }
        let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        for k in 1...lookbackMonths {
            guard let s = cal.date(byAdding: .month, value: -k, to: thisMonth) else { continue }
            let id = monthID(s, cal)
            guard !have.contains(id), now >= dueDate(monthStart: s, cal) else { continue }
            guard let e = cal.date(byAdding: .month, value: 1, to: s) else { continue }
            let list = shots.filter { $0.date >= s && $0.date < e }.sorted { $0.date < $1.date }
            guard list.count >= monthMin else { continue }
            out.append(manifest(id: id, kind: .month, start: s, end: cal.date(byAdding: .day, value: -1, to: e) ?? e, picks: onePerDay(list, cal), now: now, cal, statsFrom: list))
        }
        return out
    }

    /// 1日 1枚(★ が あれば ★ ・ なければ その日の 最後の 1枚)・ 最大 30枚
    static func onePerDay(_ list: [RecapShot], _ cal: Calendar = calendar()) -> [RecapShot] {
        var byDay: [Date: [RecapShot]] = [:]
        for s in list { byDay[cal.startOfDay(for: s.date), default: []].append(s) }
        let picks = byDay.keys.sorted().compactMap { d -> RecapShot? in
            let day = byDay[d]!.sorted { $0.date < $1.date }
            return day.last(where: \.kept) ?? day.last
        }
        return Array(picks.suffix(monthMax))
    }

    private static func manifest(id: String, kind: RecapKind, start: Date, end: Date, picks: [RecapShot], now: Date, _ cal: Calendar, statsFrom: [RecapShot]? = nil) -> RecapManifest {
        let all = statsFrom ?? picks
        let days = Set(all.map { cal.startOfDay(for: $0.date) }).count
        var hours: [Int: Int] = [:]
        for s in all { hours[cal.component(.hour, from: s.date), default: 0] += 1 }
        var tags: [String: Int] = [:]
        for s in all { if let t = s.tag, !t.isEmpty { tags[t, default: 0] += 1 } }
        let cover = picks.first(where: \.kept) ?? picks.first
        return RecapManifest(id: id, kind: kind, start: start, end: end, photoIDs: picks.map(\.id), shots: all.count, days: days, kept: all.filter(\.kept).count,
                             peakHour: hours.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }?.key,
                             topTag: tags.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }?.key, cover: cover?.id ?? "", state: .ready, createdAt: now)
    }

    /// 写真が 消えて いたら とばす。のこりが 条件より 少なければ nil(リストから 消す)
    static func pruned(_ m: RecapManifest, available: Set<String>) -> RecapManifest? {
        var r = m
        r.photoIDs = m.photoIDs.filter { available.contains($0) }
        guard r.photoIDs.count >= (m.kind == .week ? weekMin : monthMin) else { return nil }
        if !available.contains(r.cover) { r.cover = r.photoIDs.first ?? "" }
        return r
    }

    /// 今週の 作成中(何日目か 1〜7)と のこり 日数 ・ できる 時刻
    static func building(now: Date, _ cal: Calendar = calendar()) -> (dayNumber: Int, daysLeft: Int, dueText: String) {
        let s = weekStart(of: now, cal)
        let n = (cal.dateComponents([.day], from: s, to: cal.startOfDay(for: now)).day ?? 0) + 1
        let left = 7 - n
        return (n, left, left == 0 ? "あした 9:00 に できる" : "月曜 9:00 に できる")
    }

    /// 次に つくる 時刻(ローカル通知の 予約 用):次の 月曜 9:00
    static func nextMonday9(after now: Date, _ cal: Calendar = calendar()) -> Date {
        let s = weekStart(of: now, cal)
        let due = dueDate(weekStart: s, cal)
        return due > now ? due : dueDate(weekStart: cal.date(byAdding: .day, value: 7, to: s) ?? s, cal)
    }
}

/// Recap の 一覧を 端末に のこす(JSON)+ iCloud(NSUbiquitousKeyValueStore)に 同期。機種変更 ・ 入れなおしで 戻る
@MainActor
final class RecapStore {
    static let shared = RecapStore()
    private let key = "recaps.v1"
    private(set) var items: [RecapManifest] = []

    private var fileURL: URL {
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("recaps.json")
    }

    init() { load() }

    private func load() {
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        if let d = try? Data(contentsOf: fileURL), let l = try? dec.decode([RecapManifest].self, from: d) { items = l }
        else if let d = NSUbiquitousKeyValueStore.default.data(forKey: key), let l = try? dec.decode([RecapManifest].self, from: d) { items = l }
        items.sort { $0.start > $1.start }
    }

    private func save() {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        guard let d = try? enc.encode(items) else { return }
        try? d.write(to: fileURL, options: .atomic)
        if d.count < 800_000 { NSUbiquitousKeyValueStore.default.set(d, forKey: key); NSUbiquitousKeyValueStore.default.synchronize() }
    }

    /// アプリを ひらいた 時:作る べき Recap を 作る(本命)。作った 数を 返す
    @discardableResult
    func refresh(now: Date, shots: [RecapShot]) -> Int {
        let available = Set(shots.map(\.id))
        items = items.compactMap { RecapRules.pruned($0, available: available) }
        let made = RecapRules.missing(now: now, shots: shots, existing: items)
        items.append(contentsOf: made)
        items.sort { $0.start > $1.start }
        save()
        return made.count
    }

    func markSeen(_ id: String) {
        guard let i = items.firstIndex(where: { $0.id == id }), items[i].state != .seen else { return }
        items[i].state = .seen
        save()
    }

    /// DEBUG:見本の 一覧を 差しこむ
    func replace(_ list: [RecapManifest]) { items = list.sorted { $0.start > $1.start } }
}
