import CloudKit
import Foundation
import Observation
import SwiftUI
import UIKit
import UserNotifications

// 今日のホームの層の、相手に届くもの:ノック(文字なし)と👍(灯)。
// どちらもグループの共有ゾーンに小さなレコードを置く(MemberEvent・Lamp のレコード型を使う)。
// 数・順位・だれが押したかは、どこにも出さない。

// MARK: - 触覚(モックの buzz と同じ文言)

@MainActor
enum LayerHaptics {
    /// v14:中身は Haptics(アプリ全体の辞書)に一本化。ここは今までの呼び名を残すだけ
    static func prepare() { Haptics.prepare() }

    /// カードを押した瞬間・シートをひらく・タグ・友だち = pop
    static func light() { Haptics.play(.pop) }

    /// シートを閉じる・いちばん上/下についた = soft
    static func soft() { Haptics.play(.soft) }

    /// カチ(切りかえ・層に入る・1コマすすむ)= tick
    static func selection() { Haptics.play(.tick, gap: Haptics.Tuning.scrollGap) }

    /// まだ開けないものを押した:やわらかく2回
    static func softDouble() {
        Haptics.play(.soft, gap: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { Haptics.play(.soft, gap: 0) }
    }

    /// 👍 = success
    static func medium() { Haptics.play(.success) }
}

// MARK: - スクロールの「カチ」(鳴らしすぎない)

/// 横・縦スクロールで、1つすすむたびに selection を1回。
/// 最短の間をあける(横 70ms・縦 140ms)。はやいフリック(つぎのコマまで 0.12秒未満)は、3コマに1回だけ。
@MainActor
final class ScrollTickHaptics {
    let minInterval: TimeInterval
    private var lastValue: AnyHashable?
    private var lastStep = Date.distantPast
    private var lastFire = Date.distantPast
    private var fastCount = 0
    /// 鳴らした回数(テスト用)
    private(set) var fired = 0
    private let clock: () -> Date
    private let play: () -> Void

    init(minInterval: TimeInterval = 0.07, clock: @escaping () -> Date = Date.init, play: @escaping () -> Void = LayerHaptics.selection) {
        self.minInterval = minInterval
        self.clock = clock
        self.play = play
    }

    /// 見えているコマ(または層)が変わった。はじめての値(画面に出たとき)では鳴らさない
    func step(_ value: AnyHashable?) {
        guard let value, value != lastValue else { return }
        let first = lastValue == nil
        lastValue = value
        let now = clock()
        defer { lastStep = now }
        guard !first else { return }
        if now.timeIntervalSince(lastStep) < 0.12 {
            fastCount += 1
            guard fastCount % 3 == 0 else { return }
        } else {
            fastCount = 0
        }
        guard now.timeIntervalSince(lastFire) >= minInterval else { return }
        lastFire = now
        fired += 1
        play()
    }
}

// MARK: - 共有ゾーンへ書く

@MainActor
enum LayerCloud {
    /// グループのゾーンと、書きこむデータベース(自分のゾーンなら private、相手のゾーンなら shared)
    static func target(for group: LaterGroup) -> (zoneID: CKRecordZone.ID, database: CKDatabase, parent: CKRecord.ID?)? {
        guard let manager = CloudKitManager.current, let zoneID = group.cachedZoneID else { return nil }
        let isOwner = zoneID.ownerName == manager.currentUserRecordName || zoneID.ownerName == CKCurrentUserDefaultName
        let database = isOwner ? manager.container.privateCloudDatabase : manager.container.sharedCloudDatabase
        // 階層共有:グループのレコードを親にしないと、参加者に届かない
        let parent = group.ckRecordName.map { CKRecord.ID(recordName: $0, zoneID: zoneID) }
        return (zoneID, database, parent)
    }
}

// MARK: - 古い版が書いた「つつく」の読みすて

/// 「つつく」機能は なくした。古い版が 共有ゾーンに 書いた knock の レコードが 届いても、
/// 何も 知らせず、MemberEventStore にも 入れない(true = ここで 捨てる)。
enum KnockInbox {
    static func handle(record: CKRecord, myRecordName: String?, now: Date = Date()) -> Bool {
        record["eventType"] as? String == "knock"
    }
}

// MARK: - 👍(灯)

/// 昨日のみんなへの👍。1日1回・数は出さない。ほかの写真を押すと、えらびなおせる(24:00まで)。
/// 中身は「灯」(LampBoard)。置き場所は、その写真のグループ。
@MainActor
enum HomeThumb {
    enum Outcome: Equatable {
        case first
        case changed
        case same
        /// 締め切り(24:00)を過ぎた
        case closed
    }

    static func scope(_ card: HomeYesterdayCard) -> String {
        card.groupRecordName ?? LampScope.group("group-\(card.groupID.uuidString)")
    }

    static func day(_ card: HomeYesterdayCard) -> String {
        LampRules.dayKey(for: card.captureDate)
    }

    /// 今日👍している写真(なければ nil)
    static func chosen(in cards: [HomeYesterdayCard], board: LampBoard) -> String? {
        cards.first { board.litPhoto(day: day($0), scope: scope($0)) == $0.photoRecordName }?.photoRecordName
    }

    static func choose(_ card: HomeYesterdayCard, in cards: [HomeYesterdayCard], board: LampBoard, now: Date = Date()) -> Outcome {
        guard LampRules.isOpen(photoDay: day(card), now: now) else { return .closed }
        let previous = cards.first { board.litPhoto(day: day($0), scope: scope($0)) == $0.photoRecordName }
        if previous?.photoRecordName == card.photoRecordName { return .same }
        // ほかのグループに置いていた👍は、取り消してから置く(1日に1つだけ)
        if let previous, scope(previous) != scope(card) {
            board.toggle(day: day(previous), scope: scope(previous), photoRecordName: previous.photoRecordName, now: now)
        }
        board.toggle(day: day(card), scope: scope(card), photoRecordName: card.photoRecordName, now: now)
        return previous == nil ? .first : .changed
    }
}

/// 灯のうち、グループに置いたものを、そのグループの共有ゾーンへ送る(世界の灯は、ここでは送らない)。
@MainActor
enum LampGroupSync {
    static func flush(groups: [LaterGroup]) async {
        let board = LampBoard.shared
        for change in board.pending {
            guard let group = groups.first(where: { $0.ckRecordName == change.lamp.scope }),
                  let target = LayerCloud.target(for: group) else { continue }
            let recordID = LampRecord.recordID(for: change.lamp, zoneID: target.zoneID)
            do {
                switch change.kind {
                case .save:
                    let record = LampRecord.makeRecord(from: change.lamp, zoneID: target.zoneID)
                    if let parent = target.parent { record.parent = CKRecord.Reference(recordID: parent, action: .none) }
                    _ = try await target.database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
                case .delete:
                    _ = try await target.database.modifyRecords(saving: [], deleting: [recordID])
                }
                board.markSent(change)
            } catch let error as CKError where error.code == .unknownItem {
                board.markSent(change)
            } catch {
                // つながったときに、もう一度(保留のまま残す)
            }
        }
    }
}

// MARK: - 昨日の世界のことば(Mondo の集計から、ことばだけ)

enum WorldWordsStore {
    private static let key = "worldWords.v1"

    struct Cached: Codable, Equatable {
        let dayKey: String
        let words: [String]
        /// v17:ことばごとの数(words と同じ並び)。古い保存にはない
        var counts: [Int]? = nil
        /// v17:ことばごとの写真の色(平均色の hex を3つまで)。写真そのものは持たない
        var tones: [[String]]? = nil
        var countryCount: Int? = nil
    }

    /// v17 の「昨日の世界で、多かったことば」の1行
    struct Word: Equatable, Identifiable {
        let tag: String
        let count: Int
        let tones: [String]
        var id: String { tag }
    }

    static func record(_ summary: MondoDaySummary) {
        let ranked = summary.topTags.sorted { $0.count != $1.count ? $0.count > $1.count : $0.tag < $1.tag }
        let tones: [[String]] = ranked.map { item in
            Array(summary.entries.filter { $0.tags.contains(item.tag) }.compactMap(\.toneHex).prefix(3))
        }
        let cached = Cached(dayKey: summary.dayKey, words: ranked.map(\.tag), counts: ranked.map(\.count), tones: tones, countryCount: summary.countryCount)
        UserDefaults.standard.set(try? JSONEncoder().encode(cached), forKey: key)
    }

    /// その日の集計(ことば)を持っているか(ことばが0こでも true)
    static func hasDay(_ dayKey: String) -> Bool {
        load()?.dayKey == dayKey
    }

    /// 昨日のことば(上位から)。昨日の集計でなければ空
    static func words(now: Date) -> [String] {
        guard let cached = load(), cached.dayKey == MondoWindow.yesterdayKey(now: now) else { return [] }
        return cached.words
    }

    /// 昨日のことば(数・色つき)と、国の数。昨日の集計でなければ空
    static func entries(now: Date) -> (words: [Word], countries: Int?) {
        guard let cached = load(), cached.dayKey == MondoWindow.yesterdayKey(now: now) else { return ([], nil) }
        let words = cached.words.enumerated().map { index, tag in
            Word(tag: tag, count: cached.counts?[safe: index] ?? 0, tones: cached.tones?[safe: index] ?? [])
        }
        return (words, cached.countryCount)
    }

    private static func load() -> Cached? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Cached.self, from: data)
    }
}
