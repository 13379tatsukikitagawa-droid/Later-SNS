import SwiftUI

// v17「下までスクロールできる Home」の決めごと(見本:Docs/Mocks/later_home_v17_scroll.html の v17css と最後の script)。
// 1画面目(v8)はそのまま。その下に続く区画の並び・数字・中身をここにまとめる。

/// 区画(おわり は、どの状態でも最後に付く)
enum HomeV17Section: String, CaseIterable, Identifiable {
    /// A 今日の film(物干しのチェキ)
    case film
    /// C あしたの朝、こう ひらく(長押しで現像)
    case develop
    /// B Later の1日(つまみ)
    case day
    /// D 昨日の世界で、多かったことば
    case words
    /// E ともだち
    case friends
    /// F Later の、3つの やくそく(初日だけ)
    case promises

    var id: String { rawValue }
}

enum HomeV17Rules {
    // MARK: 並び

    /// 状態ごとの区画の並び(この後に「おわり」が付く)
    static func order(_ state: HomeState) -> [HomeV17Section] {
        switch state {
        case .first: return [.film, .develop, .day, .words, .friends, .promises]
        case .dawn: return [.film, .words, .friends, .day, .develop]
        case .night, .rest: return [.film, .day, .develop, .friends, .words]
        case .deciding, .ready, .opened, .more: return [.film, .words, .friends, .day]
        }
    }

    // MARK: スクロールの動き

    /// オーブと文字の輪は、スクロールの 0.22倍だけ下にずれる(700pt まで)
    static let parallaxRate: CGFloat = 0.22
    static let parallaxCap: CGFloat = 700
    /// 文字の輪は、スクロール量 × 0.09度 回る
    static let ringDegreesPerPoint: Double = 0.09
    /// いちばん下の余白(最後の区画が月に隠れないように)
    static let bottomSpace: CGFloat = 240
    /// 区画が 12% 見えたら、下から 26pt・0.7秒でふわっと
    static let revealThreshold: Double = 0.12
    static let revealDistance: CGFloat = 26

    static func parallax(_ offset: CGFloat) -> CGFloat { min(max(offset, 0), parallaxCap) * parallaxRate }
    static func ringTurn(_ offset: CGFloat) -> Double { Double(max(offset, 0)) * ringDegreesPerPoint }
    /// ヘッダーの下地:8pt をこえたら出はじめる
    static func headerGlass(_ offset: CGFloat) -> Double { clamp01(Double(offset - 8) / 46) }
    /// 月の上の白いグラデーション:スクロールしたときだけ
    static func moonFade(_ offset: CGFloat) -> Double { clamp01(Double(offset) / 36) }
    /// 「SCROLL」のヒント:スクロールしたら消える
    static func cue(_ offset: CGFloat) -> Double { 1 - clamp01(Double(offset) / 30) }

    // MARK: 長押し・ためる

    /// 現像の長押し
    static let developHold: TimeInterval = 1.7
    /// とちゅうで はなしたら、もどる
    static let developRelease: TimeInterval = 0.38
    /// ひらいたあと、ミルクにもどるまで
    static let developShow: TimeInterval = 2.6
    static let developReturn: TimeInterval = 1.1
    /// つまみ:はなすと「いま」にもどる
    static let dayReturn: TimeInterval = 0.42

    /// ためている間の画面の揺れ(0〜1 → 0.4〜3pt)。ほぼ 0 なら揺らさない
    static func rattleAmplitude(_ level: Double) -> CGFloat {
        guard level > 0.05 else { return 0 }
        return 0.4 + 2.6 * CGFloat(clamp01(level))
    }

    // MARK: B Later の1日

    enum DayPhase: Equatable {
        case sleep, open, shoot, evening, lightsOut

        var title: String {
            switch self {
            case .sleep: return "おやすみ"
            case .open: return "9:00 ひらく"
            case .shoot: return "撮れる時間"
            case .evening: return "夜のいろ"
            case .lightsOut: return "24:00"
            }
        }

        var detail: String {
            switch self {
            case .sleep: return "写真は ミルクの中で、ゆっくり現像中。いまは撮れません。"
            case .open: return "昨日がひらく時間。あたらしい3こまが届きます。"
            case .shoot: return "1日3こままで。1枚撮ると、みんなの昨日も見られます。"
            case .evening: return "21:00 から、画面が夜のいろに。24:00 でおわりです。"
            case .lightsOut: return "24:00。ひらかなかった昨日の写真は、ここで消えます。"
            }
        }
    }

    static func phase(hour: Double) -> DayPhase {
        if hour >= 23.97 { return .lightsOut }
        if hour < 9 { return .sleep }
        if hour < 9.5 { return .open }
        if hour < 21 { return .shoot }
        return .evening
    }

    /// 0〜24(時)
    static func hour(of date: Date, calendar: Calendar = .current) -> Double {
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60 + Double(c.second ?? 0) / 3600
    }

    /// 「09:07」
    static func clockText(_ hour: Double) -> String {
        let total = Int((hour * 60).rounded()) % 1440
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// つまみを動かしたときの触覚(1時間ごと tick・9:00 をこえる thud・21:00 をこえる click・24:00 heart)
    static func dragHaptic(from old: Double, to new: Double) -> Haptics.Kind? {
        let a = Int(old.rounded(.down)), b = Int(new.rounded(.down))
        if phase(hour: new) == .lightsOut, phase(hour: old) != .lightsOut { return .heart }
        guard a != b else { return nil }
        if (a < 9) != (b < 9) { return .thud }
        if (a < 21) != (b < 21) { return .click }
        return .tick
    }

    // MARK: A 今日の film

    enum FilmFrame: Equatable, Identifiable {
        /// 撮った(時刻つき)
        case shot(index: Int, takenAt: Date)
        /// つぎ(「+ 撮る」)
        case next(index: Int)
        /// まだ(「あとで」)
        case later(index: Int)
        /// 夜で撮れない(ななめのしま)
        case rest(index: Int)

        var index: Int {
            switch self {
            case .shot(let i, _), .next(let i), .later(let i), .rest(let i): return i
            }
        }

        var id: Int { index }
    }

    static func filmFrames(shots: [Date], state: HomeState, canShootMore: Bool = true) -> [FilmFrame] {
        let taken = Array(shots.sorted().prefix(3))
        var frames: [FilmFrame] = taken.enumerated().map { .shot(index: $0, takenAt: $1) }
        for i in taken.count..<3 {
            if state.isNight { frames.append(.rest(index: i)) }
            else if i == taken.count && state.canShoot && canShootMore { frames.append(.next(index: i)) }
            else { frames.append(.later(index: i)) }
        }
        return frames
    }

    /// 物干しの糸のたるみ(見本の 346pt 幅で 6 → 40 → 6)。t は 0〜1
    static func sag(_ t: CGFloat) -> CGFloat {
        (1 - t) * (1 - t) * 6 + 2 * t * (1 - t) * 40 + t * t * 6
    }

    static let filmCenters: [CGFloat] = [62, 180, 298].map { $0 / 346 }
    static let filmTilts: [Double] = [-6, 2.5, 6]

    // MARK: D ことば

    enum WordsMode: Equatable {
        /// 初日:点線の空の行
        case empty
        /// 今日まだ撮っていない:鍵
        case locked
        /// 撮った日:タップで Mondo へ
        case open
    }

    static func wordsMode(state: HomeState, shotsToday: Int) -> WordsMode {
        if state == .first { return .empty }
        return shotsToday == 0 ? .locked : .open
    }

    static let wordRows = 5

    // MARK: 日付の文字

    /// 「10.26」
    static func dotDate(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 1).\(c.day ?? 1)"
    }

    /// 「'26 10 27」
    static func chekiDate(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "'%02d %d %d", (c.year ?? 2026) % 100, c.month ?? 1, c.day ?? 1)
    }

    /// 今日のフィルムの日(夜 0:00〜9:00 は、まだ前の日の窓)
    static func filmDay(now: Date, calendar: Calendar = .current) -> Date {
        DailyWindow.latest(for: now, calendar: calendar).open
    }

    /// つぎの 9:00
    static func nextOpen(now: Date, calendar: Calendar = .current) -> Date {
        PhotoDevelop.developDate(takenAt: now, calendar: calendar)
    }

    // MARK: E ともだち

    /// 今日(直近の窓)に撮ったこま数。同じ1枚がグループの数だけあるので、dedupeKey でまとめる
    static func shotCounts(groups: [LaterGroup], now: Date, calendar: Calendar = .current) -> [String: Int] {
        let window = DailyWindow.latest(for: now, calendar: calendar)
        var keys: [String: Set<String>] = [:]
        for group in groups {
            for photo in group.photos where photo.captureDate >= window.open && photo.captureDate < window.close {
                guard let author = photo.authorCloudKitUserRecordName ?? photo.owner?.cloudKitUserRecordName ?? photo.owner?.id.uuidString else { continue }
                keys[author, default: []].insert(photo.dedupeKey)
            }
        }
        return keys.mapValues { min(3, $0.count) }
    }

    /// グループのともだち + QR などで つながった人(同じ人は1人。12人まで)
    static func friends(group: [HomeFriend], bump: [BumpFriend], counts: [String: Int], myID: String?) -> [V17Friend] {
        var result: [V17Friend] = group.filter { !$0.isMe }.map { friend in
            V17Friend(id: friend.id, name: friend.name, avatarData: friend.avatarData, seed: friend.seed,
                      shotsToday: counts[friend.id] ?? (friend.hasShot ? 1 : 0), home: friend)
        }
        var seen = Set(result.map(\.id))
        for person in bump where person.id != myID && !seen.contains(person.id) {
            seen.insert(person.id)
            result.append(V17Friend(id: person.id, name: person.name, avatarData: nil, seed: seed(for: person.id),
                                    shotsToday: counts[person.id] ?? 0, home: nil))
        }
        return Array(result.prefix(FriendRules.maxFriends))
    }

    /// 顔の色を決めるための、id から作る固定の UUID
    static func seed(for id: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        for (i, b) in id.utf8.enumerated() { bytes[i % 16] = bytes[i % 16] &* 31 &+ b }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    private static func clamp01(_ v: Double) -> Double { min(1, max(0, v)) }
}

/// ともだちの列の1人
struct V17Friend: Identifiable, Equatable {
    let id: String
    let name: String
    let avatarData: Data?
    let seed: UUID
    /// 今日撮ったこま数(0〜3)
    let shotsToday: Int
    /// グループのともだち(つつける)。QR で つながっただけの人は nil
    let home: HomeFriend?
}

/// v17 の区画に渡す中身
struct HomeV17Data: Equatable {
    var shots: [Date] = []
    /// v20:動画のこま(撮った時刻 → 長さ)
    var videoDurations: [Date: Double] = [:]
    var words: [WorldWordsStore.Word] = []
    var countries: Int?
    var friends: [V17Friend] = []

    static let empty = HomeV17Data()
}

/// v17 の区画からの操作(TodayView がつなぐ)
struct HomeV17Actions {
    var toast: (String) -> Void = { _ in }
    /// 「+ 撮る」:月と同じく、タグ画面へ
    var shoot: () -> Void = {}
    /// 撮った日のことば:昨日のホーム(Mondo)へ(アイコン2回タップと同じ)
    var openMondo: () -> Void = {}
    /// 呼ぶ・合言葉・QR(ともだちの画面)
    var openFriends: () -> Void = {}
    /// v47:ことばのカード → Mondo を そのことばで しぼって ひらく
    var openWord: (String) -> Void = { _ in }
}

/// スクロール位置(ここを読む小さな View だけが、スクロールのたびに描きなおされる)
@Observable
final class HomeV17Scroll {
    var offset: CGFloat = 0
}

/// 長押しでためている間の、画面の揺れ(0〜1)
@Observable
final class HomeV17Feel {
    var rattle: Double = 0
}
