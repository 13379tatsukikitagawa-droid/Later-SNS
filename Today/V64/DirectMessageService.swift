import Foundation
import CloudKit

/// P07:友だちと 1対1 の チャット。CloudKit の 公開DB に 宣言ずみの `DirectMessage`(Later.ckdb)を つかう。
enum DirectMessages {
    static let recordType = "DirectMessage"

    struct Message: Identifiable, Equatable {
        let id: String
        let senderID: String
        let text: String
        let createdAt: Date
    }

    /// 2人で 同じ 部屋の ID(順番に よらない)
    static func conversationID(_ a: String, _ b: String) -> String { [a, b].sorted().joined(separator: "__") }

    /// 古い 順に ならべる(同時刻は id で 安定させる)
    static func ordered(_ m: [Message]) -> [Message] { m.sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) } }

    /// 送れる 文字か(空白だけ ・ 長すぎは だめ)
    static func clean(_ raw: String) -> String? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty || t.count > 500 ? nil : t
    }

    @MainActor private static var database: CKDatabase? { CloudKitManager.current?.container.publicCloudDatabase }
    @MainActor static var me: String? { CloudKitManager.current?.currentUserRecordName }

    @MainActor static func fetch(with other: String) async -> [Message] {
        guard let database, let me else { return [] }
        let q = CKQuery(recordType: recordType, predicate: NSPredicate(format: "conversationID == %@", conversationID(me, other)))
        guard let (results, _) = try? await database.records(matching: q, resultsLimit: 200) else { return [] }
        let list: [Message] = results.compactMap { try? $0.1.get() }.compactMap { r in
            guard let s = r["senderID"] as? String, let t = r["text"] as? String else { return nil }
            return Message(id: r.recordID.recordName, senderID: s, text: t, createdAt: r["createdAt"] as? Date ?? .distantPast)
        }
        return ordered(list)
    }

    @MainActor static func send(_ text: String, to other: String) async -> Message? {
        guard let database, let me, let t = clean(text) else { return nil }
        let id = "dm_\(UUID().uuidString)"
        let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: id))
        record["conversationID"] = conversationID(me, other)
        record["senderID"] = me
        record["receiverID"] = other
        record["text"] = t
        record["createdAt"] = Date()
        do { _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys) }
        catch { print("[DirectMessages] send failed: \(error)"); return nil }
        return Message(id: id, senderID: me, text: t, createdAt: Date())
    }
}
