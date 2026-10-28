import CloudKit
import CryptoKit
import Foundation
import Observation

// 灯(ともしび)の決めごと。1日に「MONDO で1つ」+「グループごとに1つ」。
// 名前は「投票」にしない。数字・順位・誰が灯したかは、どこにも出さない。
// ここは画面を持たない純粋な計算(テストしやすいよう、現在時刻とカレンダーは引数で受ける)。

// MARK: - 灯の1つ

/// 灯の置き場所。世界(MONDO)か、グループ。
enum LampScope {
    static let world = "world"

    /// グループの置き場所(グループの recordName)
    static func group(_ recordName: String) -> String { recordName }
}

/// 灯のレコード(CloudKit の `Lamp`)。同じ `(userId, day, scope)` は1つだけ。
struct Lamp: Codable, Equatable, Identifiable, Sendable {
    /// 撮影日 yyyy-MM-dd
    var day: String
    /// `world` またはグループの recordName
    var scope: String
    var photoRecordName: String
    /// 匿名ハッシュ。画面には出さない
    var userId: String
    var updatedAt: Date

    var id: String { LampRules.recordName(userHash: userId, day: day, scope: scope) }
}

/// 灯を押した結果(動きと触覚を選ぶのに使う)
enum LampOutcome: Equatable {
    /// 新しくともした
    case placed
    /// 別の写真から移した(前の写真の灯は消える)
    case moved(from: String)
    /// 同じ写真をもう一度押して、取り消した
    case cancelled
}

// MARK: - 規則

enum LampRules {
    /// グループは最大10個。1日に最大 1 + 10 個
    static let maxGroups = 10
    /// 選ばれた一枚を残す日数
    static let keepDays = 365
    /// カレンダーで薄れはじめる日数と、薄れきる日数
    static let fadeStartDays = 280
    static let fadeEndDays = 372
    /// 薄れたときの下限
    static let minOpacity = 0.18
    static let minSaturation = 0.25

    /// 重複しない recordName
    static func recordName(userHash: String, day: String, scope: String) -> String {
        "lamp_\(userHash)_\(day)_\(scope)"
    }

    // MARK: ともす・移す・取り消す

    /// 同じ `(userId, day, scope)` を1つだけにして、灯を置く・移す・取り消す。
    /// 同じ写真をもう一度 → 取り消し(削除)。別の写真 → 移す(上書き)。
    static func toggle(
        _ lamps: [Lamp],
        day: String,
        scope: String,
        photoRecordName: String,
        userId: String,
        now: Date
    ) -> (lamps: [Lamp], outcome: LampOutcome) {
        var result = lamps
        // 重複(同じ組が2つ以上)があっても、ここで1つに畳む
        let same = result.indices.filter { result[$0].userId == userId && result[$0].day == day && result[$0].scope == scope }
        let existing = same.last.map { result[$0] }
        for index in same.reversed() { result.remove(at: index) }

        if let existing, existing.photoRecordName == photoRecordName {
            return (result, .cancelled)
        }
        result.append(Lamp(day: day, scope: scope, photoRecordName: photoRecordName, userId: userId, updatedAt: now))
        if let existing { return (result, .moved(from: existing.photoRecordName)) }
        return (result, .placed)
    }

    /// その場所・その日の、自分の灯
    static func lamp(in lamps: [Lamp], day: String, scope: String, userId: String) -> Lamp? {
        lamps.last { $0.userId == userId && $0.day == day && $0.scope == scope }
    }

    /// 1日の灯の残り数(世界1つ + グループ数 − ともしている数。0以上)
    static func remaining(groupCount: Int, lamps: [Lamp], day: String, userId: String) -> Int {
        let total = 1 + min(max(0, groupCount), maxGroups)
        let used = Set(lamps.filter { $0.userId == userId && $0.day == day }.map(\.scope)).count
        return max(0, total - used)
    }

    // MARK: ともせる条件・締め切り

    /// 灯をともせる写真か。解禁できた他人の写真だけ(自分の写真・未解禁・ブロックずみには出さない)。
    /// 灯をともせるのは、その日に1枚以上撮った人だけ。
    static func canLamp(isMine: Bool, isUnlocked: Bool, isBlocked: Bool, shotsToday: Int) -> Bool {
        !isMine && isUnlocked && !isBlocked && shotsToday >= 1
    }

    /// 締め切り:撮影日の翌日の24:00(= 撮影日の2日後の0:00。ホームを開いている「今日」の終わり)。
    static func deadline(photoDay: String, calendar: Calendar = .current) -> Date? {
        guard let start = date(fromDayKey: photoDay, calendar: calendar) else { return nil }
        return calendar.date(byAdding: .day, value: 2, to: start)
    }

    /// まだ灯を動かせるか。撮影日の翌日(昨日の写真を見る今日)の24:00 まで。締め切りを過ぎたら押せない。
    static func isOpen(photoDay: String, now: Date, calendar: Calendar = .current) -> Bool {
        guard let deadline = deadline(photoDay: photoDay, calendar: calendar) else { return false }
        return now < deadline
    }

    // MARK: 決める(発表の規則。集計の方法そのものは作らない)

    /// 同数のときの固定のランダム。`day + photoRecordName` から決まるので、だれが計算しても同じ。
    static func tieBreakScore(day: String, photoRecordName: String) -> UInt64 {
        var generator = SeededGenerator(seed: "lamp-\(day)-\(photoRecordName)")
        return generator.next()
    }

    /// 灯の数(photoRecordName → 数)から、その場所の一枚を決める。ゼロなら nil(その日の一枚はなし)。
    static func pickWinner(counts: [String: Int], day: String) -> String? {
        let candidates = counts.filter { $0.value > 0 }
        guard let top = candidates.values.max() else { return nil }
        let tied = candidates.filter { $0.value == top }.keys
        return tied.min { a, b in
            let sa = tieBreakScore(day: day, photoRecordName: a)
            let sb = tieBreakScore(day: day, photoRecordName: b)
            return sa != sb ? sa > sb : a < b
        }
    }

    // MARK: 1年間の保持

    /// 選ばれた一枚を残す期限(撮影日 + 365日)
    static func keepUntil(day: String, calendar: Calendar = .current) -> Date? {
        guard let start = date(fromDayKey: day, calendar: calendar) else { return nil }
        return calendar.date(byAdding: .day, value: keepDays, to: start)
    }

    /// まだ残してよいか(期限を過ぎたら消す)
    static func isKept(day: String, now: Date, calendar: Calendar = .current) -> Bool {
        guard let until = keepUntil(day: day, calendar: calendar) else { return false }
        return now < until
    }

    /// 今日から数えて何日前か(今日=0)
    static func daysAgo(day: String, now: Date, calendar: Calendar = .current) -> Int? {
        guard let start = date(fromDayKey: day, calendar: calendar) else { return nil }
        return calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: now)).day
    }

    // MARK: 古い日ほど薄れる

    /// カレンダーのマスの濃さ。280日前までは100%。そこから372日前に向けて 100% → 18%。
    static func fadeOpacity(daysAgo: Int) -> Double {
        let t = fadeProgress(daysAgo: daysAgo)
        return 1 - t * (1 - minOpacity)
    }

    /// 彩度も、同じ進み方で下げる(1 → 0.25)
    static func fadeSaturation(daysAgo: Int) -> Double {
        let t = fadeProgress(daysAgo: daysAgo)
        return 1 - t * (1 - minSaturation)
    }

    private static func fadeProgress(daysAgo: Int) -> Double {
        guard daysAgo > fadeStartDays else { return 0 }
        return min(1, Double(daysAgo - fadeStartDays) / Double(fadeEndDays - fadeStartDays))
    }

    // MARK: 日付

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func date(fromDayKey key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    // MARK: 触覚(灯をともす)

    /// 灯をともす:soft 0.45 → 50ms後 → medium 0.7(強さ・鋭さ・時刻)
    static let placeHaptic: [(intensity: Float, sharpness: Float, at: TimeInterval)] = [
        (0.45, 0.15, 0),
        (0.7, 0.4, 0.05),
    ]
    /// 取り消す:light 1回
    static let cancelHaptic: [(intensity: Float, sharpness: Float, at: TimeInterval)] = [
        (0.3, 0.5, 0),
    ]
}

// MARK: - 匿名ID

enum LampIdentity {
    /// 画面に出さない匿名ハッシュ(元の ID から一方向に作る)
    static func userHash(source: String) -> String {
        let digest = SHA256.hash(data: Data(("lamp-v1|" + source).utf8))
        return digest.prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    private static let localKey = "lampLocalID"

    /// 自分の匿名ID。CloudKit のユーザーがわかるならそれから、まだなら端末のランダムな ID から作る。
    @MainActor
    static var current: String {
        if let name = CloudKitManager.current?.currentUserRecordName, !name.isEmpty {
            return userHash(source: name)
        }
        let defaults = UserDefaults.standard
        let local = defaults.string(forKey: localKey) ?? {
            let id = UUID().uuidString
            defaults.set(id, forKey: localKey)
            return id
        }()
        return userHash(source: local)
    }
}

// MARK: - CloudKit へ送るための準備(送信そのものと、サーバー側の集計はここでは作らない)

enum LampRecord {
    static let recordType = "Lamp"

    static func recordID(for lamp: Lamp, zoneID: CKRecordZone.ID? = nil) -> CKRecord.ID {
        if let zoneID { return CKRecord.ID(recordName: lamp.id, zoneID: zoneID) }
        return CKRecord.ID(recordName: lamp.id)
    }

    /// 送るレコード。世界の灯は Public DB(zoneID なし)、グループの灯はそのグループの共有ゾーン
    static func makeRecord(from lamp: Lamp, zoneID: CKRecordZone.ID? = nil) -> CKRecord {
        let record = CKRecord(recordType: recordType, recordID: recordID(for: lamp, zoneID: zoneID))
        record["day"] = lamp.day
        record["scope"] = lamp.scope
        record["photoRecordName"] = lamp.photoRecordName
        record["userId"] = lamp.userId
        record["updatedAt"] = lamp.updatedAt
        return record
    }

    static func lamp(from record: CKRecord) -> Lamp? {
        guard record.recordType == recordType,
              let day = record["day"] as? String,
              let scope = record["scope"] as? String,
              let photo = record["photoRecordName"] as? String,
              let userId = record["userId"] as? String,
              let updatedAt = record["updatedAt"] as? Date else { return nil }
        return Lamp(day: day, scope: scope, photoRecordName: photo, userId: userId, updatedAt: updatedAt)
    }
}

/// 送りそこねた変更。あとで CloudKit に送るとき、ここから取り出す。
struct LampPendingChange: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case save, delete }
    var kind: Kind
    var lamp: Lamp
}

// MARK: - 端末の保存

/// 灯の保存(端末の中)。撮影日から数日たった灯は捨てる。
enum LampStorage {
    private static let lampsKey = "lamps.v1"
    private static let pendingKey = "lamps.pending.v1"
    /// 灯を持っておく日数(締め切りのあと、少しだけ残す)
    static let keepDays = 4

    static func load(defaults: UserDefaults = .standard) -> [Lamp] {
        decode([Lamp].self, key: lampsKey, defaults: defaults) ?? []
    }

    static func save(_ lamps: [Lamp], defaults: UserDefaults = .standard) {
        if let data = try? encoder.encode(lamps) { defaults.set(data, forKey: lampsKey) }
    }

    static func loadPending(defaults: UserDefaults = .standard) -> [LampPendingChange] {
        decode([LampPendingChange].self, key: pendingKey, defaults: defaults) ?? []
    }

    static func savePending(_ pending: [LampPendingChange], defaults: UserDefaults = .standard) {
        if let data = try? encoder.encode(pending) { defaults.set(data, forKey: pendingKey) }
    }

    /// 古い灯を捨てる
    static func pruned(_ lamps: [Lamp], now: Date, calendar: Calendar = .current) -> [Lamp] {
        lamps.filter { lamp in (LampRules.daysAgo(day: lamp.day, now: now, calendar: calendar) ?? 0) <= keepDays }
    }

    /// 送る変更をためる。同じ灯への古い変更は、新しい変更で置きかえる
    static func appending(_ change: LampPendingChange, to pending: [LampPendingChange]) -> [LampPendingChange] {
        pending.filter { $0.lamp.id != change.lamp.id } + [change]
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static func decode<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try? d.decode(type, from: data)
    }
}

// MARK: - 画面から使う入れ物

/// 自分の灯。画面はここを見て、押したらここへ。
@MainActor
@Observable
final class LampBoard {
    static let shared = LampBoard()

    private(set) var lamps: [Lamp]
    private(set) var pending: [LampPendingChange]
    private let defaults: UserDefaults
    private let userIdProvider: () -> String

    init(defaults: UserDefaults = .standard, userIdProvider: (() -> String)? = nil) {
        self.defaults = defaults
        self.userIdProvider = userIdProvider ?? { LampIdentity.current }
        self.lamps = LampStorage.pruned(LampStorage.load(defaults: defaults), now: Date())
        self.pending = LampStorage.loadPending(defaults: defaults)
    }

    var userId: String { userIdProvider() }

    /// その場所・その日の、自分の灯をともしている写真(なければ nil)
    func litPhoto(day: String, scope: String) -> String? {
        LampRules.lamp(in: lamps, day: day, scope: scope, userId: userId)?.photoRecordName
    }

    /// その場所で、今日の灯をともしているか(右上の丸)
    func isLit(day: String, scope: String) -> Bool {
        litPhoto(day: day, scope: scope) != nil
    }

    /// 押した。同じ写真なら取り消し、別の写真なら移す。
    @discardableResult
    func toggle(day: String, scope: String, photoRecordName: String, now: Date = Date()) -> LampOutcome {
        let uid = userId
        let before = LampRules.lamp(in: lamps, day: day, scope: scope, userId: uid)
        let (next, outcome) = LampRules.toggle(lamps, day: day, scope: scope, photoRecordName: photoRecordName, userId: uid, now: now)
        lamps = next
        LampStorage.save(next, defaults: defaults)
        // CloudKit へ送る準備:ともした・移した → 保存、取り消した → 削除(送信は別の作業)
        switch outcome {
        case .placed, .moved:
            if let lamp = LampRules.lamp(in: next, day: day, scope: scope, userId: uid) {
                pending = LampStorage.appending(LampPendingChange(kind: .save, lamp: lamp), to: pending)
            }
        case .cancelled:
            if let before { pending = LampStorage.appending(LampPendingChange(kind: .delete, lamp: before), to: pending) }
        }
        LampStorage.savePending(pending, defaults: defaults)
        return outcome
    }

    /// 古い灯を捨てる(起動・復帰のとき)
    func prune(now: Date = Date()) {
        let kept = LampStorage.pruned(lamps, now: now)
        guard kept != lamps else { return }
        lamps = kept
        LampStorage.save(kept, defaults: defaults)
    }
}
