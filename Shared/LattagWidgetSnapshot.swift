import Foundation
import SwiftUI
import CoreText
#if canImport(UIKit)
import UIKit
#endif

// v96:アプリ が 書いて、ウィジェット(拡張)が 読む。両方の ターゲットで コンパイルする。
// 写真の ルール(PROMPT_v96 §5):9:00 まえ ・ 自分が 今日 撮って いない 時は、本物の 友だちの 写真を App Group に 置かない。
// 置いて よいのは 「1回 ぼかした 画像」と 友だちの アイコン ・ 名前 ・ 数 だけ。

enum LattagShared {
    static let appGroup = LaterWidgetShared.appGroup

    static var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }
    static var snapshotURL: URL? { container?.appendingPathComponent("WidgetSnapshot.json") }
    /// 小さな 画像の 置き場(w/<name>)
    static var imageDir: URL? { container?.appendingPathComponent("w", isDirectory: true) }
    static func imageURL(_ name: String) -> URL? { imageDir?.appendingPathComponent(name) }

    // ウィジェットの kind(ギャラリーの 並び順)
    enum Kind {
        static let lens = "LattagLens"          // S1
        static let until9 = "LattagUntil9"      // S2
        static let friendPhoto = "LattagFriend" // S3
        static let mondo = "LattagMondo"        // S4
        static let friends = "LattagFriends"    // M1
        static let yesterday = "LattagYesterday" // M2
        static let trip = "LattagTrip"          // M3
        static let board = "LattagBoard"        // L1
        static let lockRing = "LattagLockRing"  // 円 ①
        static let lockOpen = "LattagLockOpen"  // 円 ②
        static let lockRect = "LattagLockRect"  // 長方形
        static let lockInline = "LattagLockInline" // 1行
        static let all = [lens, until9, friendPhoto, mondo, friends, yesterday, trip, board, lockRing, lockOpen, lockRect, lockInline]
    }

    // タップの 行き先(PROMPT_v96 §0)
    enum Link {
        static let shoot = URL(string: "lattag://shoot")!
        static let develop = URL(string: "lattag://develop")!
        static let friends = URL(string: "lattag://friends")!
        static let mondo = URL(string: "lattag://mondo")!
        static func yesterday(friend uid: String? = nil) -> URL {
            guard let uid, !uid.isEmpty else { return URL(string: "lattag://yesterday")! }
            var c = URLComponents(); c.scheme = "lattag"; c.host = "yesterday"; c.queryItems = [URLQueryItem(name: "f", value: uid)]
            return c.url ?? URL(string: "lattag://yesterday")!
        }
        static func trip(_ id: String) -> URL { URL(string: "lattag://trip/\(id)") ?? URL(string: "lattag://friends")! }
    }
}

// MARK: - スナップショット

/// 友だち 1人(M1 の 輪 ・ S3 ・ L1)
struct FriendRing: Codable, Hashable, Identifiable {
    var uid: String
    var name: String
    var initial: String
    var colorHex: String
    /// 今日 撮った こま(0...3)
    var shotsToday: Int
    /// アイコン(App Group の ファイル名。プロフィールの 写真 ・ 120px)
    var avatar: String?
    var id: String { uid }
}

/// きのうの 1枚(ひらいた 後 ・ 自分が 今日 撮った 時 だけ)
struct YPhoto: Codable, Hashable, Identifiable {
    var uid: String
    var name: String
    /// "21:12"
    var time: String
    var tag: String?
    /// App Group の ファイル名(300px JPEG)
    var thumb: String
    var id: String { thumb }
}

/// 1日の 友だちの まとめ(数 ・ タグ だけ。写真 なし)
struct DaySummary: Codable, Hashable {
    /// LaterDay.key(この 日の 写真)
    var dayKey: String
    /// 撮った 人の 数
    var people: Int
    /// 写真の 枚数
    var count: Int
    var tag: String?
    /// 撮った 人の 名前(手書きの 名札 ・ 最大 5)
    var names: [String]
}

struct TripSnap: Codable, Hashable {
    var id: String
    var title: String
    /// "11/19 THU ・ 3人"
    var sub: String
    var day: Int
    var count: Int
    var total: Int
    var passNo: Int
    /// 撮った こまの 位置(0..<total)。最後の 1つが 「さっき」
    var filled: [Int]
    var cover: String?
}

struct NextItem: Codable, Hashable {
    var title: String
    var sub: String
    var url: String
    var hot: Bool
}

struct WidgetSnapshot: Codable, Equatable {
    static let version = 1
    var version = WidgetSnapshot.version
    /// 書いた 時の 「その日」(LaterDay.key)
    var dayKey: String
    var writtenAt: Date
    /// 今日 撮った こま
    var shots: Int
    var limit: Int
    /// 今日 撮った 時刻(古い 順)
    var shotTimes: [Date]
    /// 今日 撮った こまの ぼかし(現像中 ・ 120px)
    var shotBlurs: [String]
    var friends: [FriendRing]
    /// 今日の 友だち(9:00 に ひらく 分)の まとめ。写真は 置かない
    var today: DaySummary?
    /// きのう の 友だちの まとめ
    var yesterday: DaySummary?
    /// きのうの 写真(本物)。自分が 今日 撮った 時 だけ 入る。それ以外は 空
    var yesterdayPhotos: [YPhoto]
    /// ロック中に 見せる 「1回 ぼかした」 画像(ファイル名)
    var lockedPreviews: [String]
    var mondoTag: String?
    var mondoCount: Int?
    var mondoCountries: Int?
    var trip: TripSnap?
    var next: NextItem?
    /// 自分
    var myRecordName: String?
    var myName: String

    static let empty = WidgetSnapshot(dayKey: "", writtenAt: .distantPast, shots: 0, limit: 3, shotTimes: [], shotBlurs: [], friends: [], today: nil, yesterday: nil, yesterdayPhotos: [], lockedPreviews: [], mondoTag: nil, mondoCount: nil, mondoCountries: nil, trip: nil, next: nil, myRecordName: nil, myName: "")

    static func decoder() -> JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }
    static func encoder() -> JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.sortedKeys]; return e }

    static func load(from url: URL? = LattagShared.snapshotURL) -> WidgetSnapshot {
        guard let url, let data = try? Data(contentsOf: url),
              let s = try? decoder().decode(WidgetSnapshot.self, from: data), s.version == version else { return .empty }
        return s
    }

    func save(to url: URL? = LattagShared.snapshotURL) {
        guard let url, let data = try? Self.encoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

/// FilmCounter が App Group に 書く こま(撮った 瞬間に 書かれる。スナップショットより 早い)
enum WidgetFilm {
    static func shots(now: Date, defaults: UserDefaults? = UserDefaults(suiteName: LattagShared.appGroup), calendar: Calendar = .current) -> Int? {
        guard let d = defaults, d.string(forKey: "filmCounter.dayKey") == LaterDay.key(for: now, calendar: calendar) else { return nil }
        return d.stringArray(forKey: "filmCounter.usedIDs")?.count
    }
}

// MARK: - 時間(9:00 ひらく ・ 21:00 夜 ・ 24:00 消灯)

enum WidgetDayClock {
    static let nightHour = 21

    /// 今の 時間帯
    enum Part: Equatable {
        /// 9:00〜21:00
        case day
        /// 21:00〜24:00(S2 が 黒へ)
        case evening
        /// 0:00〜9:00(消灯 ・ ひらく 待ち)
        case lightsOut
    }

    static func part(_ now: Date, calendar: Calendar = .current) -> Part {
        let h = calendar.component(.hour, from: now)
        if h < LaterDay.openingHour { return .lightsOut }
        if h >= nightHour { return .evening }
        return .day
    }

    /// 今日の 消灯(24:00)
    static func lightsOut(_ now: Date, calendar: Calendar = .current) -> Date { LaterWidgetDay.lightsOut(of: now, calendar: calendar) }
    /// 次の 9:00
    static func opens(_ now: Date, calendar: Calendar = .current) -> Date { LaterWidgetDay.nextOpening(after: now, calendar: calendar) }
    /// 今日の 21:00
    static func evening(_ now: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .hour, value: nightHour - LaterDay.openingHour, to: LaterDay.start(of: now, calendar: calendar)) ?? now
    }

    /// タイムラインの 予約:今 ・ 21:00 ・ 24:00 ・ 9:00(+ S3 用に 1時間ごと)
    static func entryDates(from now: Date, hourly: Bool = false, calendar: Calendar = .current) -> [Date] {
        var dates: Set<Date> = [now]
        let opens = opens(now, calendar: calendar)
        for d in [evening(now, calendar: calendar), lightsOut(now, calendar: calendar), opens] where d > now { dates.insert(d) }
        if hourly {
            var t = calendar.nextDate(after: now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime) ?? now
            while t < opens { dates.insert(t); t = t.addingTimeInterval(3600) }
        }
        return dates.sorted()
    }
}

// MARK: - 読む 側の 形(時間で 決まる)

/// スナップショット + 今の 時刻 → 画面に 出す 値。9:00 を またいで アプリが 開かれて いなくても 切りかえる。
struct WidgetModel: Equatable {
    let now: Date
    let part: WidgetDayClock.Part
    let shots: Int
    let limit: Int
    let lightsOutAt: Date
    let opensAt: Date
    let friends: [FriendRing]
    /// きのう(今 見られる 側)の まとめ
    let yesterday: DaySummary?
    /// きのうが 自分に ひらいて いるか(今日 1枚 撮った)
    let unlocked: Bool
    let yesterdayPhotos: [YPhoto]
    let lockedPreviews: [String]
    let shotBlurs: [String]
    let mondoTag: String?
    let mondoCount: Int?
    let mondoCountries: Int?
    let trip: TripSnap?
    let next: NextItem?
    let myRecordName: String?
    let myName: String

    var remaining: Int { max(0, limit - shots) }
    var isDone: Bool { shots >= limit }
    /// 現像の 進み(最初に 撮った 時 → 9:00)
    let devPercent: Int
    /// 9:00 まえ(消灯中)
    var beforeNine: Bool { part == .lightsOut }
    var friendsShot: Int { friends.filter { $0.shotsToday > 0 }.count }

    static func make(_ s: WidgetSnapshot, now: Date, filmShots: Int? = nil, calendar: Calendar = .current) -> WidgetModel {
        let key = LaterDay.key(for: now, calendar: calendar)
        let sameDay = s.dayKey == key
        let gap = LaterWidgetDay.daysBetween(s.dayKey, key) ?? 99
        // 日が かわった(9:00 を すぎた):今日の まとめ が きのう に なる。こまも 友だちも 0 から
        let shots = sameDay ? max(s.shots, filmShots ?? 0) : (filmShots ?? 0)
        let friends = sameDay ? s.friends : s.friends.map { var f = $0; f.shotsToday = 0; return f }
        let yesterday: DaySummary? = sameDay ? s.yesterday : (gap == 1 ? s.today : nil)
        // 本物の 写真は 同じ 日に 書いた 物 だけ(書いた 時に 自分が 撮って いた)
        let photos = sameDay && shots > 0 ? s.yesterdayPhotos : []
        let firstShot = sameDay ? s.shotTimes.first : nil
        var dev = 0
        let opens = WidgetDayClock.opens(now, calendar: calendar)
        if let firstShot {
            let total = opens.timeIntervalSince(firstShot)
            dev = total > 0 ? Int((min(1, max(0, now.timeIntervalSince(firstShot) / total)) * 100).rounded(.down)) : 100
        }
        return WidgetModel(
            now: now,
            part: WidgetDayClock.part(now, calendar: calendar),
            shots: min(shots, max(1, s.limit)),
            limit: max(1, s.limit),
            lightsOutAt: WidgetDayClock.lightsOut(now, calendar: calendar),
            opensAt: opens,
            friends: friends,
            yesterday: yesterday,
            unlocked: shots > 0,
            yesterdayPhotos: photos,
            lockedPreviews: s.lockedPreviews,
            shotBlurs: sameDay ? s.shotBlurs : [],
            mondoTag: s.mondoTag,
            mondoCount: s.mondoCount,
            mondoCountries: s.mondoCountries,
            trip: s.trip,
            next: sameDay ? s.next : nil,
            myRecordName: s.myRecordName,
            myName: s.myName,
            devPercent: dev
        )
    }
}

// MARK: - 色(PROMPT_v96 §0 の 値 だけ)

enum WColor {
    static let ground = Color(hex6: 0x0B0B0C)
    static let lime = Color(hex6: 0xC8F25A)
    static let paper = Color(hex6: 0xF4F1EA)
    static let pink = Color(hex6: 0xEE5E9C)
    static let sky = Color(hex6: 0x9ED8FF)
    static let stamp = Color(hex6: 0xE0481A)
    /// 3枚 撮った 後の 暗い 帯
    static let doneBand = Color(hex6: 0x2A2F1D)

    static func hex(_ s: String) -> Color {
        Color(hex6: UInt32(s.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x888888)
    }
}

extension Color {
    init(hex6: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex6 >> 16) & 0xFF) / 255, green: Double((hex6 >> 8) & 0xFF) / 255, blue: Double(hex6 & 0xFF) / 255, opacity: opacity)
    }
}

// MARK: - 書体(拡張でも 使える。LF と 同じ 名前)

enum WFont {
    static func inter(_ weight: Int, _ size: CGFloat) -> Font {
        let name: String
        switch weight {
        case ..<600: name = "Inter-Medium"
        case 600..<750: name = "Inter-Bold"
        case 750..<850: name = "Inter-ExtraBold"
        default: name = "Inter-Black"
        }
        return .custom(name, fixedSize: size)
    }

    static func mono(_ size: CGFloat, bold: Bool = true) -> Font {
        .custom(bold ? "SpaceMono-Bold" : "SpaceMono-Regular", fixedSize: size)
    }

    static func serif(_ size: CGFloat, italic: Bool = false) -> Font {
        cascaded(italic ? "InstrumentSerif-Italic" : "InstrumentSerif-Regular", "NotoSerifJP-Bold", size)
    }

    static func hand(_ size: CGFloat) -> Font { cascaded("Caveat-SemiBold", "KleeOne-SemiBold", size) }

    private static func cascaded(_ base: String, _ fallback: String, _ size: CGFloat) -> Font {
        #if canImport(UIKit)
        guard let b = UIFont(name: base, size: size) else { return .system(size: size) }
        guard let f = UIFont(name: fallback, size: size) else { return Font(b) }
        return Font(UIFont(descriptor: b.fontDescriptor.addingAttributes([.cascadeList: [f.fontDescriptor]]), size: size))
        #else
        return .custom(base, fixedSize: size)
        #endif
    }
}

// MARK: - 大きな 日本語の 書体(8MB × 2)は 拡張に 入れず、アプリが App Group へ 1回 コピーし、拡張が 読みこむ


enum WidgetSharedFonts {
    static let files = ["NotoSerifJP-Bold.ttf", "KleeOne-SemiBold.ttf"]
    static var dir: URL? { LattagShared.container?.appendingPathComponent("fonts", isDirectory: true) }

    /// アプリ 側:無ければ コピー
    static func install(from bundle: Bundle = .main) {
        guard let dir else { return }
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        for f in files {
            let to = dir.appendingPathComponent(f)
            guard !fm.fileExists(atPath: to.path), let from = bundle.url(forResource: f, withExtension: nil) else { continue }
            try? fm.copyItem(at: from, to: to)
        }
    }

    /// 拡張 側:プロセスに 1回 だけ 登録
    static let register: Void = {
        guard let dir else { return }
        for f in files {
            let url = dir.appendingPathComponent(f)
            if FileManager.default.fileExists(atPath: url.path) {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }()
}
