import CoreGraphics
import Foundation

// Home v5(撮影後の Home:MONDO / GROUP の2画面)の、見た目に依存しない決めごと。
// 配置・判定・順番・段階は、テストしやすいようにここへ集める。

// MARK: - どの状態で v5 を出すか

extension HomeState {
    /// 撮影後の Home(v5)を出す状態。撮った(ready)・昨日をひらいた(opened)・まだ撮れる(more)。
    /// それより前の状態(first / dawn / night / rest / deciding)の Home は、今回は触らない。
    var usesGroupHome: Bool {
        switch self {
        case .ready, .opened, .more: return true
        default: return false
        }
    }
}

// MARK: - 昨日の写真の解禁(GROUP)

/// 解禁の数は min(今日の撮影枚数, 昨日の枚数)。解禁される写真はランダムだが、
/// 日付+グループ ID をシードにして、その日は同じ順番に固定する(開くたびに入れかわらない)。
enum UnlockPlan {
    /// ひらける枚数(自分の写真は数えない。他の人の写真の数が上限)
    static func credits(shotsToday: Int, candidates: Int) -> Int {
        max(0, min(min(shotsToday, FilmRoll.shotsPerDay), candidates))
    }

    /// その日の解禁の順番。写真が増えても、もとの写真どうしの前後は変わらない(キーごとの点数で並べる)。
    static func order(keys: [String], groupID: UUID, dayKey: String) -> [String] {
        let seed = "unlock-\(dayKey)-\(groupID.uuidString)"
        func score(_ key: String) -> UInt64 {
            var generator = SeededGenerator(seed: seed + "|" + key)
            return generator.next()
        }
        return keys.sorted { a, b in
            let sa = score(a), sb = score(b)
            return sa != sb ? sa < sb : a < b
        }
    }

    /// ひらいている写真のキー
    static func unlockedKeys(keys: [String], groupID: UUID, dayKey: String, shotsToday: Int) -> [String] {
        let count = credits(shotsToday: shotsToday, candidates: keys.count)
        return Array(order(keys: keys, groupID: groupID, dayKey: dayKey).prefix(count))
    }
}

/// モザイクの段階。L0 は 6×13、L1 は 11×24、L2 は 22×48(mosaicTiny そのまま)、L3 は本物の写真。
enum MosaicLevel: Int, CaseIterable, Comparable {
    case l0, l1, l2, l3

    static func < (a: MosaicLevel, b: MosaicLevel) -> Bool { a.rawValue < b.rawValue }

    /// ドットの数(横×縦)。L3 は写真なので nil
    var grid: (columns: Int, rows: Int)? {
        switch self {
        case .l0: return (6, 13)
        case .l1: return (11, 24)
        case .l2: return (22, 48)
        case .l3: return nil
        }
    }
}

/// 解禁の動きの時間割(撮影のあと)。
enum UnlockTimeline {
    /// 撮影のあと、解禁が始まるまで
    static let startDelay: TimeInterval = 1.4
    /// 1枚ずつずらす間隔
    static let stagger: TimeInterval = 0.52
    /// 1枚の中の段階(L1 → L2 → L3 に入る時刻)
    static let stageOffsets: [TimeInterval] = [0, 0.26, 0.52]
    /// 1枚の動きの長さ(約1.1秒)
    static let tileDuration: TimeInterval = 1.1

    /// i 枚目(0始まり)の開始時刻(撮影の瞬間から数える)
    static func startTime(forIndex index: Int) -> TimeInterval {
        startDelay + stagger * Double(index)
    }

    /// 1枚の開始からの経過時間でのモザイクの段階
    static func level(atElapsed elapsed: TimeInterval) -> MosaicLevel {
        if elapsed < stageOffsets[0] { return .l0 }
        if elapsed < stageOffsets[1] { return .l1 }
        if elapsed < stageOffsets[2] { return .l2 }
        return .l3
    }

    /// 全部ひらききるまで(最後の1枚の動きの終わり)
    static func totalDuration(count: Int) -> TimeInterval {
        guard count > 0 else { return 0 }
        return startTime(forIndex: count - 1) + tileDuration
    }
}

// MARK: - 触覚のパターン

/// 触覚の「長さ(ms)」のならび。偶数番目が鳴る長さ、奇数番目があき。新しい種類は増やさず、
/// 第8章の表の数字をそのまま持つ。
enum HomeHapticPattern {
    /// 画面をダブルタップで切りかえ:トトッ
    static let switchScreen = [10, 60, 16]
    /// 撮影画面をひらく:トトン
    static let openShoot = [16, 70, 26]
    /// 昨日の写真が1枚ひらく:ぱら…(モザイク4段)
    static let unlockTile = [8, 70, 10, 70, 14, 70, 24]
    /// グループの人が撮った:ぽっ
    static let groupShot = [10, 70, 6]
    /// 全画面のビューアをひらく:じわっと → トン
    static let openViewer = [4, 50, 8, 50, 14, 50, 26]
    /// 縦に1枚止まる:カチッ
    static let pageStop = [9]
    /// 地球をなぞる(約12°ごと):カチッ
    static let globeTick = [9]
    /// ごく軽く1回
    static let light = [10]

    /// 鳴らす位置(秒)と強さ。長さが長いほど、少し強い。
    static func pulses(_ pattern: [Int]) -> [(time: TimeInterval, intensity: Float)] {
        var result: [(TimeInterval, Float)] = []
        var cursor = 0
        for (index, ms) in pattern.enumerated() {
            if index.isMultiple(of: 2) {
                result.append((TimeInterval(cursor) / 1000, min(1, 0.25 + Float(ms) / 40)))
            }
            cursor += ms
        }
        return result
    }
}

// MARK: - MONDO のハッシュタグ・ランキング

struct RankedTag: Equatable, Identifiable {
    let tag: String
    let count: Int
    /// 1始まり
    let rank: Int
    /// その日の1位の数に対する割合(棒の長さ)
    let ratio: Double

    var id: String { tag }
}

enum TagRanking {
    /// 上位に出す数(TOP 6)
    static let limit = 6
    /// 行の中に出す写真の数
    static let photosPerRow = 4
    /// 1つのタグのフィードの最大枚数(デモは8枚、本番は12枚)
    static let feedPerTag = 12

    /// 数の多い順。同数は日付シードで決まる並び(投稿の速さでは決めない)。
    static func rank(_ topTags: [(tag: String, count: Int)], dayKey: String, limit: Int = TagRanking.limit) -> [RankedTag] {
        func tie(_ tag: String) -> UInt64 {
            var generator = SeededGenerator(seed: "rank-\(dayKey)-\(tag)")
            return generator.next()
        }
        let sorted = topTags.sorted { a, b in
            if a.count != b.count { return a.count > b.count }
            return tie(a.tag) < tie(b.tag)
        }
        let top = sorted.prefix(limit)
        let maxCount = max(1, top.first?.count ?? 1)
        return top.enumerated().map { index, item in
            RankedTag(tag: item.tag, count: item.count, rank: index + 1, ratio: min(1, max(0, Double(item.count) / Double(maxCount))))
        }
    }

    /// そのタグの写真の並び。日付+タグをシードにした固定のシャッフル(速さ・人気で選ばない)。
    static func photos(for tag: String, in entries: [MondoEntry], dayKey: String) -> [MondoEntry] {
        MondoAggregator.seededShuffle(entries.filter { $0.tags.contains(tag) }, seed: "feed-\(dayKey)-\(tag)")
    }
}

/// フィードの1ページ(1タグの中の1枚)。
struct FeedPage: Identifiable, Equatable {
    let tag: String
    let entry: MondoEntry
    /// そのタグの中での位置(0始まり)
    let index: Int
    /// 分母:そのタグの光の数
    let total: Int

    var id: String { tag + "|" + entry.id }

    /// 「03 / 30」
    var counterText: String { TagFeed.counterText(index: index, total: total) }
}

enum TagFeed {
    /// ランキング順に、タグごとの写真を縦に並べる。1つ目のタグが終わったら、続けて次のタグへ。
    static func pages(ranking: [RankedTag], entries: [MondoEntry], dayKey: String, perTag: Int = TagRanking.feedPerTag) -> [FeedPage] {
        ranking.flatMap { ranked -> [FeedPage] in
            let list = Array(TagRanking.photos(for: ranked.tag, in: entries, dayKey: dayKey).prefix(perTag))
            // 分母は、そのタグの光の数(ただし、実際に並ぶ枚数より小さくならない)
            let total = max(ranked.count, list.count)
            return list.enumerated().map { FeedPage(tag: ranked.tag, entry: $1, index: $0, total: total) }
        }
    }

    /// 押した写真(タグと写真)から始めるページの位置。なければタグの先頭、それもなければ 0。
    static func startIndex(in pages: [FeedPage], tag: String, entryID: String?) -> Int {
        if let entryID, let hit = pages.firstIndex(where: { $0.tag == tag && $0.entry.id == entryID }) { return hit }
        return pages.firstIndex { $0.tag == tag } ?? 0
    }

    static func counterText(index: Int, total: Int) -> String {
        String(format: "%02d / %02d", index + 1, total)
    }
}

// MARK: - 位置情報の共有(グループごと)

/// 位置の共有のモード。初期値はオフ。
enum GroupLocationMode: String, CaseIterable, Codable {
    case off
    /// 写真を撮った場所だけ、そのグループの人に見える
    case shotPlace
    /// いまの場所(おおまか)が見える
    case now

    var title: String {
        switch self {
        case .off: return "オフ"
        case .shotPlace: return "撮った場所"
        case .now: return "いま"
        }
    }

    /// 選べるモード。「いま」は、方針が決まるまで出さない(LocationPolicy.nowModeEnabled)。
    static var available: [GroupLocationMode] {
        LocationPolicy.nowModeEnabled ? allCases : [.off, .shotPlace]
    }

    /// ボタンを押したときの次のモード(オフ → 撮った場所 → いま → オフ)
    func next(available: [GroupLocationMode] = GroupLocationMode.available) -> GroupLocationMode {
        guard let index = available.firstIndex(of: self) else { return available.first ?? .off }
        return available[(index + 1) % available.count]
    }
}

enum LocationPolicy {
    /// 丸める格子(度)。0.005° はおよそ500m
    static let gridStep = 0.005
    /// 「いま」モードを今回入れるか。10代の利用者が多い可能性があるため、確認が取れるまで入れない。
    static let nowModeEnabled = false
    /// 「いま」の更新が無いまま、ピンをうすくして消すまで(秒)
    static let staleAfter: TimeInterval = 60 * 60
    /// ピンをうすくし始める割合
    static func pinOpacity(updatedAt: Date, now: Date) -> Double {
        let age = now.timeIntervalSince(updatedAt)
        if age >= staleAfter { return 0 }
        if age <= staleAfter / 2 { return 1 }
        return 1 - (age - staleAfter / 2) / (staleAfter / 2)
    }
}

/// 緯度経度を、約500mの格子に丸める。正確な GPS は、どこにも保存・送信しない。
enum LocationRounding {
    /// 1つの値を格子に丸める(小数第3位まで)
    static func round(_ value: Double, step: Double = LocationPolicy.gridStep) -> Double {
        let snapped = (value / step).rounded() * step
        return (snapped * 1000).rounded() / 1000
    }

    static func cell(latitude: Double, longitude: Double) -> (latitude: Double, longitude: Double) {
        (round(latitude), round(longitude))
    }

    /// 2点の距離(km)。丸めた位置どうしで測る
    static func distanceKm(from a: (latitude: Double, longitude: Double), to b: (latitude: Double, longitude: Double)) -> Double {
        let radius = 6371.0
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let la1 = a.latitude * .pi / 180, la2 = b.latitude * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(la1) * cos(la2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radius * asin(min(1, h.squareRoot()))
    }

    /// 「0.6 km」
    static func distanceText(_ km: Double) -> String {
        String(format: "%.1f km", km)
    }
}

// MARK: - はじめての説明

enum FirstGuide {
    /// 端末の中だけ(CloudKit には送らない)
    static let seenKey = "homeV5GuideSeen"

    /// 撮影後の Home をはじめて開いたとき、1回だけ出す。見たことがあれば出さない。他の画面が重なっている・もう出ている間も出さない。
    static func shouldShow(seen: Bool, isCovered: Bool, isAlreadyShowing: Bool = false) -> Bool {
        !seen && !isCovered && !isAlreadyShowing
    }
}

// MARK: - 撮影のあとの合図

/// 撮った瞬間の合図。写真が右上のアバターへ飛び、1.4秒後に GROUP の解禁が始まる。
struct ShotEvent: Equatable {
    let id: UUID
    let at: Date

    init(at: Date = Date()) {
        self.id = UUID()
        self.at = at
    }
}
