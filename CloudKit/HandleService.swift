import CloudKit
import Foundation

// v94 B:ID(@ユーザー名)。きまり(純粋)と、CloudKit Public DB での 予約(同じ ID を ふせぐ)。
// 注意:この アプリの 友だち / ディレクトリは CloudKit。Firebase は 認証だけ なので、`usernames` の かわりに
// Public DB の `UserHandle` レコード(recordName = handle_<id>)を ifServerRecordUnchanged で 作って 重ならない ように する。

enum HandleRules {
    static let minLength = 3, maxLength = 20
    static let reservedWords = ["lattag", "admin", "support", "official", "help", "team", "null", "root", "staff", "api", "www"]
    static let changeIntervalDays = 14

    enum Problem: Equatable {
        case tooShort, tooLong, badChar, dotEdge, doubleDot, allDigits, reserved
        var message: String {
            switch self {
            case .tooShort: return "\(HandleRules.minLength)文字 以上"
            case .tooLong: return "\(HandleRules.maxLength)文字 まで"
            case .badChar: return "英小文字 ・ 数字 ・ _ ・ . だけ"
            case .dotEdge: return ". で はじまる / おわる のは だめ"
            case .doubleDot: return ".. は つかえません"
            case .allDigits: return "数字 だけは つかえません"
            case .reserved: return "この ID は つかえません"
            }
        }
    }

    /// 全角 → 半角 ・ 大文字 → 小文字 ・ 使えない 字は のぞく(入力 中に かける)
    static func normalize(_ raw: String) -> String {
        let half = raw.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? raw
        return String(half.lowercased().unicodeScalars.filter { ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "_" || $0 == "." }.map(Character.init))
    }

    static func validate(_ h: String) -> Problem? {
        if h.count < minLength { return .tooShort }
        if h.count > maxLength { return .tooLong }
        if h.unicodeScalars.contains(where: { !(("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "_" || $0 == ".") }) { return .badChar }
        if h.hasPrefix(".") || h.hasSuffix(".") { return .dotEdge }
        if h.contains("..") { return .doubleDot }
        if h.allSatisfy(\.isNumber) { return .allDigits }
        if reservedWords.contains(h) || h.hasPrefix("lattag") { return .reserved }
        return nil
    }

    /// 名前を ローマ字に して 候補を 3つ(例 ゆい → yui_1118)
    static func suggestions(fromName name: String, now: Date = Date(), salt: Int = 0) -> [String] {
        let latin = (name.applyingTransform(.toLatin, reverse: false) ?? name).applyingTransform(.stripDiacritics, reverse: false) ?? name
        var base = normalize(latin.replacingOccurrences(of: " ", with: ""))
        base = base.replacingOccurrences(of: ".", with: "_")
        if base.count < 2 { base = "user" }
        base = String(base.prefix(12))
        let f = DateFormatter(); f.dateFormat = "MMdd"; f.locale = Locale(identifier: "en_US_POSIX")
        let md = f.string(from: now)
        var out = ["\(base)_\(md)", "\(base)\(10 + (abs(salt) * 7 + 23) % 90)", "\(base)_\((abs(salt) * 13 + 4) % 100)"]
        out = out.map { String($0.prefix(maxLength)) }.filter { validate($0) == nil }
        return Array(NSOrderedSet(array: out)) as? [String] ?? out
    }

    /// 前回の 変更から 14日 たったか(のこり 日数。0 なら かえられる)
    static func daysUntilChange(lastChange: Date?, now: Date = Date()) -> Int {
        guard let lastChange else { return 0 }
        let passed = Calendar.current.dateComponents([.day], from: lastChange, to: now).day ?? 0
        return max(0, changeIntervalDays - passed)
    }
}

enum HandleService {
    enum Availability: Equatable {
        case ok, mine, taken, invalid(HandleRules.Problem), unknown
    }

    private static var db: CKDatabase { CKContainer(identifier: CloudKitManager.containerIdentifier).publicCloudDatabase }
    private static func recordID(_ h: String) -> CKRecord.ID { CKRecord.ID(recordName: "handle_\(h)") }
    private static var cache: [String: Availability] = [:]
    private static let lastChangeKey = "handle.changedAt", claimedKey = "handle.claimed"

    /// いま 自分が ID を きめて あるか(まだなら ID を きめる シートを 出す)
    static var hasClaimed: Bool { UserDefaults.standard.bool(forKey: claimedKey) }
    static var lastChange: Date? { UserDefaults.standard.object(forKey: lastChangeKey) as? Date }

    static func check(_ raw: String, ownerKey: String) async -> Availability {
        let h = HandleRules.normalize(raw)
        if let p = HandleRules.validate(h) { return .invalid(p) }
        if let c = cache[h] { return c }
        do {
            let rec = try await db.record(for: recordID(h))
            let owner = rec["ownerKey"] as? String
            let released = rec["releasedAt"] as? Date
            let result: Availability = owner == ownerKey && released == nil ? .mine : ((released.map { $0 < Date() } ?? false) ? .ok : .taken)
            cache[h] = result
            return result
        } catch let e as CKError where e.code == .unknownItem {
            cache[h] = .ok; return .ok
        } catch {
            return .unknown
        }
    }

    /// 予約して ID を かえる。同じ ID は だれかが 先に とって いたら taken
    @discardableResult
    static func claim(_ raw: String, ownerKey: String, previous: String?) async -> Availability {
        let h = HandleRules.normalize(raw)
        if let p = HandleRules.validate(h) { return .invalid(p) }
        let id = recordID(h)
        do {
            let rec: CKRecord
            if let existing = try? await db.record(for: id) {
                let owner = existing["ownerKey"] as? String
                let released = existing["releasedAt"] as? Date
                if owner == ownerKey && released == nil { markClaimed(); return .mine }
                guard let released, released < Date() else { return .taken }
                rec = existing
            } else { rec = CKRecord(recordType: "UserHandle", recordID: id) }
            rec["ownerKey"] = ownerKey
            rec["claimedAt"] = Date()
            rec["releasedAt"] = nil
            let (saved, _) = try await db.modifyRecords(saving: [rec], deleting: [], savePolicy: .ifServerRecordUnchanged)
            if case .failure = saved[id] { cache[h] = .taken; return .taken }
            cache[h] = .mine
            // 前の ID は 14日間 だれも とれない
            if let previous, previous != h, let old = try? await db.record(for: recordID(previous)), (old["ownerKey"] as? String) == ownerKey {
                old["releasedAt"] = Calendar.current.date(byAdding: .day, value: HandleRules.changeIntervalDays, to: Date())
                _ = try? await db.modifyRecords(saving: [old], deleting: [], savePolicy: .changedKeys)
                cache[previous] = nil
            }
            markClaimed(changed: previous != nil && previous != h)
            return .mine
        } catch {
            return .unknown
        }
    }

    private static func markClaimed(changed: Bool = true) {
        UserDefaults.standard.set(true, forKey: claimedKey)
        if changed { UserDefaults.standard.set(Date(), forKey: lastChangeKey) }
    }
}
