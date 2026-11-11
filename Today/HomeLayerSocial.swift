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

    /// つつく(ノック)= heart
    static func knock() { Haptics.play(.heart) }
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

// MARK: - ノックを受けない(自分の設定)

enum KnockSetting {
    private static let key = "knockOff"

    /// 端末の写し(受けとる側の判定に使う。プロフィールの knockOff と同じ値)
    static var isOff: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
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

// MARK: - ノック

/// 自分が送ったノック。1人に1日1回。印(アイコンの小さな手)に使う。
@MainActor
@Observable
final class KnockStore {
    static let shared = KnockStore()

    struct Sent: Codable, Equatable {
        let target: String
        let window: String
        let recordName: String
        let zoneName: String
        let zoneOwner: String
        let at: Date
    }

    enum Result: Equatable {
        case sent
        /// 今日はもうノックした(サーバーにも、もうある)
        case already
        case failed
    }

    private static let key = "knocks.sent.v1"
    private(set) var sent: [Sent]
    /// 送っている途中(印を先に出す)
    private(set) var inFlight: Set<String> = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let list = try? JSONDecoder().decode([Sent].self, from: data) {
            sent = list
        } else {
            sent = []
        }
    }

    func hasKnocked(_ target: String, window: String) -> Bool {
        inFlight.contains("\(window)|\(target)") || sent.contains { $0.target == target && $0.window == window }
    }

    static func recordName(window: String, from: String, to: String) -> String {
        "knock_\(window)_\(LampIdentity.userHash(source: from))_\(LampIdentity.userHash(source: to))"
    }

    func knock(_ friend: HomeFriend, window: String, groups: [LaterGroup], myName: String) async -> Result {
        guard !hasKnocked(friend.id, window: window) else { return .already }
        guard let manager = CloudKitManager.current, let me = manager.currentUserRecordName,
              let group = groups.first(where: { friend.groupIDs.contains($0.id) && $0.cachedZoneID != nil }),
              let target = LayerCloud.target(for: group) else { return .failed }
        let flightKey = "\(window)|\(friend.id)"
        inFlight.insert(flightKey)
        defer { inFlight.remove(flightKey) }

        let name = Self.recordName(window: window, from: me, to: friend.id)
        let record = CKRecord(recordType: AppRecordType.memberEvent, recordID: CKRecord.ID(recordName: name, zoneID: target.zoneID))
        record["eventType"] = "knock"
        record["memberId"] = me
        record["memberName"] = String(myName.prefix(24))
        record["targetId"] = friend.id
        record["eventAt"] = Date()
        if let parent = target.parent {
            record["groupRef"] = CKRecord.Reference(recordID: parent, action: .none)
            record.parent = CKRecord.Reference(recordID: parent, action: .none)
        }
        do {
            // 同じ名前(同じ日・同じ相手)が、もうあれば失敗する = サーバー側でも1日1回
            let result = try await target.database.modifyRecords(saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged)
            if case .failure(let error) = result.saveResults[record.recordID] {
                if (error as? CKError)?.code == .serverRecordChanged {
                    remember(friend.id, window: window, record: record)
                    return .already
                }
                return .failed
            }
            remember(friend.id, window: window, record: record)
            return .sent
        } catch {
            if (error as? CKError)?.code == .serverRecordChanged {
                remember(friend.id, window: window, record: record)
                return .already
            }
            return .failed
        }
    }

    private func remember(_ target: String, window: String, record: CKRecord) {
        let zone = record.recordID.zoneID
        sent.removeAll { $0.target == target && $0.window == window }
        sent.append(Sent(target: target, window: window, recordName: record.recordID.recordName, zoneName: zone.zoneName, zoneOwner: zone.ownerName, at: Date()))
        save()
    }

    /// 2日より古いノックを消す(自分が送ったぶんだけ。競合は気にしない)
    func prune(now: Date = Date()) async {
        guard let manager = CloudKitManager.current else { return }
        let old = sent.filter { now.timeIntervalSince($0.at) > 2 * 86_400 }
        guard !old.isEmpty else { return }
        for item in old {
            let zoneID = CKRecordZone.ID(zoneName: item.zoneName, ownerName: item.zoneOwner)
            let isOwner = item.zoneOwner == manager.currentUserRecordName || item.zoneOwner == CKCurrentUserDefaultName
            let database = isOwner ? manager.container.privateCloudDatabase : manager.container.sharedCloudDatabase
            _ = try? await database.deleteRecord(withID: CKRecord.ID(recordName: item.recordName, zoneID: zoneID))
        }
        sent.removeAll { item in old.contains(item) }
        save()
    }

    private func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(sent), forKey: Self.key)
    }
}

/// 届いたノック(同期で受けとった MemberEvent の "knock")。自分あて・今日のぶんだけ、1回だけ知らせる。
@MainActor
enum KnockInbox {
    private static let seenKey = "knocks.seen.v1"

    /// ノックのレコードなら true(MemberEventStore には入れない)
    static func handle(record: CKRecord, myRecordName: String?, now: Date = Date()) -> Bool {
        guard record["eventType"] as? String == "knock" else { return false }
        guard let myRecordName, record["targetId"] as? String == myRecordName else { return true }
        guard !KnockSetting.isOff else { return true }
        // 今日の窓のノックだけ(古いものは、あとから届いても知らせない)
        guard let at = record["eventAt"] as? Date, DailyWindow.key(for: at) == DailyWindow.key(for: now), !DailyWindow.isNight(now) else { return true }
        let id = record.recordID.recordName
        var seen = UserDefaults.standard.stringArray(forKey: seenKey) ?? []
        guard !seen.contains(id) else { return true }
        seen.append(id)
        UserDefaults.standard.set(Array(seen.suffix(200)), forKey: seenKey)

        let name = (record["memberName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? String(localized: "notification.poke.someone")
        let text = String(format: String(localized: "notification.poke.inApp"), name)
        if UIApplication.shared.applicationState == .active {
            LayerHaptics.knock()
            MondoNotice.post(text)
        } else {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "notification.poke.title")
            content.body = String(format: String(localized: "notification.poke.body"), name)
            content.sound = .default
            let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
        return true
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
