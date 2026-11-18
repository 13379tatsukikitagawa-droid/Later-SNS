// 参考(形の 見本)・ そのまま コピー しない。名前は 今の プロジェクトに 合わせる。
// PROMPT_v96.md 5章:アプリ が 書いて、ウィジェット extension が 読む。
import Foundation
import WidgetKit

enum LattagShared {
    static let appGroup = "group.<bundle>.shared"          // 今の Bundle ID に 合わせる
    static var container: URL { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)! }
    static var snapshotURL: URL { container.appendingPathComponent("WidgetSnapshot.json") }
    static func imageURL(_ name: String) -> URL { container.appendingPathComponent("w/\(name)") }
}

struct FriendRing: Codable, Hashable { var uid: String; var name: String; var initial: String; var colorHex: String; var shotsToday: Int; var thumb: String? }
struct YPhoto: Codable, Hashable { var uid: String; var name: String; var time: String; var tag: String?; var thumb: String }   // 9:00 すぎ だけ 本物
struct TripSnap: Codable, Hashable { var id: String; var title: String; var day: Int; var count: Int; var cover: String? }
struct NextItem: Codable, Hashable { var title: String; var sub: String; var url: String; var hot: Bool }

struct WidgetSnapshot: Codable {
    var shots: Int                 // 0...3
    var lightsOutAt: Date          // 今日の 24:00
    var opensAt: Date              // あしたの 9:00
    var unlockedYesterday: Bool    // 今日 1枚 撮った = きのうが ひらく
    var friends: [FriendRing]
    var yesterday: [YPhoto]        // unlockedYesterday == false の 時は 空(本物の 写真を 置かない)
    var lockedPreview: String?     // 1回 ぼかした 画像(ロック中の S3 / L1)
    var mondoTag: String?; var mondoCount: Int?; var mondoCities: Int?
    var trip: TripSnap?
    var next: NextItem?
    var devPercent: Int

    static func load() -> WidgetSnapshot? {
        guard let d = try? Data(contentsOf: LattagShared.snapshotURL) else { return nil }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(WidgetSnapshot.self, from: d)
    }
    func save() {   // アプリ 側 だけ
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        try? enc.encode(self).write(to: LattagShared.snapshotURL, options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// タイムライン:今 ・ 21:00(S2 が 黒へ)・ 24:00(消灯)・ 9:00(ひらく)。秒は Text(timerInterval:) が 動かす。
struct LattagEntry: TimelineEntry { let date: Date; let snap: WidgetSnapshot?; let phase: DayPhase }
enum DayPhase { case day, evening, lightsOut, opened }

func lattagTimelineDates(now: Date = .now, cal: Calendar = .current) -> [(Date, DayPhase)] {
    func at(_ h: Int, addDay: Int = 0) -> Date { cal.date(bySettingHour: h, minute: 0, second: 0, of: cal.date(byAdding: .day, value: addDay, to: now)!)! }
    let marks: [(Date, DayPhase)] = [(at(9), .opened), (at(21), .evening), (at(0, addDay: 1), .lightsOut), (at(9, addDay: 1), .opened)]
    return [(now, .day)] + marks.filter { $0.0 > now }
}
