import CloudKit
import Foundation

// P57 C(v129 2章 データ):既読 = メンバー ごとの `TripReadState`(Trip の 共有ゾーン ・ lastReadAt)。
//   CloudKit(Development で 作る → 実機 2台で 確かめる → Production に Deploy は あなた):
//   TripReadState:groupRef(REFERENCE)/ userId(STRING)/ lastReadAt(DATE/TIME)
//   レコード名 = "read_<グループ ID(小文字)>_<userId>" で 1人 1つ(上書き)。親 = グループの レコード(共有で 届く ため)。

enum TripReadRecordType { static let state = "TripReadState" }

/// 数えかた(画面も 通信も 持たない ・ テストする)
enum TripReadRules {
    /// 自分の メッセージ(sentAt)を 読んだ 人の 数 = 送った 人 以外で、lastReadAt が sentAt 以降の 人
    static func readCount(sentAt: Date, senderId: String, reads: [String: Date]) -> Int {
        reads.filter { $0.key != senderId && $0.value >= sentAt }.count
    }

    /// 未読の 数 = 自分の lastReadAt より 後に 来た 相手の メッセージ(システムは 数えない)
    static func unread(_ messages: [ChatMessage], me: String?, lastRead: Date?) -> Int {
        let seen = lastRead ?? .distantPast
        return messages.filter { $0.senderId != me && $0.kind != .system && $0.sentAt > seen }.count
    }

    /// 1秒に 1回 まで(ひらいて いる 間 ・ 閉じた 時)
    static let minInterval: TimeInterval = 1

    static func recordName(groupID: UUID, userId: String) -> String { "read_\(groupID.uuidString.lowercased())_\(userId)" }
}

@MainActor
@Observable
final class TripReadStore {
    static let shared = TripReadStore()

    /// グループ ID → (userId → lastReadAt)
    private(set) var reads: [UUID: [String: Date]] = [:]

    @ObservationIgnored private var lastUpload: [UUID: Date] = [:]
    @ObservationIgnored private var pending: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private let key = "tripReadState.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: [String: Date]].self, from: data) {
            reads = Dictionary(uniqueKeysWithValues: decoded.compactMap { k, v in UUID(uuidString: k).map { ($0, v) } })
        }
    }

    private func persist() {
        let raw = Dictionary(uniqueKeysWithValues: reads.map { ($0.key.uuidString, $0.value) })
        if let data = try? JSONEncoder().encode(raw) { UserDefaults.standard.set(data, forKey: key) }
    }

    // MARK: 読む

    func lastRead(_ groupID: UUID, user: String?) -> Date? { user.flatMap { reads[groupID]?[$0] } }

    func readCount(of message: ChatMessage) -> Int {
        TripReadRules.readCount(sentAt: message.sentAt, senderId: message.senderId, reads: reads[message.groupID] ?? [:])
    }

    /// 部屋の 下の バー ・ Home の Trip に 出す 未読の 数
    func unread(_ groupID: UUID, me: String?, messages: [ChatMessage]) -> Int {
        TripReadRules.unread(messages, me: me, lastRead: lastRead(groupID, user: me))
    }

    // MARK: 同期から(CloudKitManager.apply)

    func receive(record: CKRecord, groupID: UUID) {
        guard record.recordType == TripReadRecordType.state,
              let user = record["userId"] as? String, let at = record["lastReadAt"] as? Date else { return }
        var map = reads[groupID] ?? [:]
        // 古い 値で 新しい 値を 上書き しない(自分の 端末の 更新が 先に 進んで いる 時)
        if let old = map[user], old >= at { return }
        map[user] = at
        reads[groupID] = map
        persist()
    }

    func removeRecord(named name: String) {
        // レコード名 "read_<groupID>_<userId>" から 消す(退会 ・ 共有を 外れた 人)
        for (gid, map) in reads {
            let prefix = "read_\(gid.uuidString.lowercased())_"
            guard name.hasPrefix(prefix) else { continue }
            var m = map; m.removeValue(forKey: String(name.dropFirst(prefix.count)))
            reads[gid] = m
        }
        persist()
    }

    // MARK: 書く(ひらいて いる 間 と 閉じた 時 ・ 1秒に 1回 まで)

    /// 「ここまで 読んだ」。自分の 端末には すぐ 入れて、CloudKit へは 間引いて 送る
    func markRead(group: LaterGroup, at date: Date = Date(), flush: Bool = false) {
        guard let me = CloudKitManager.current?.currentUserRecordName else { return }
        let gid = group.id
        var map = reads[gid] ?? [:]
        if let old = map[me], old >= date { return }
        map[me] = date
        reads[gid] = map
        persist()
        let wait = flush ? 0 : max(0, TripReadRules.minInterval - Date().timeIntervalSince(lastUpload[gid] ?? .distantPast))
        pending[gid]?.cancel()
        if wait <= 0 { upload(group: group, user: me) }
        else {
            pending[gid] = Task { [weak self] in
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled else { return }
                self?.upload(group: group, user: me)
            }
        }
    }

    private func upload(group: LaterGroup, user: String) {
        let gid = group.id
        pending[gid] = nil
        lastUpload[gid] = Date()
        guard let at = reads[gid]?[user], let target = LayerCloud.target(for: group) else { return }
        let record = CKRecord(recordType: TripReadRecordType.state,
                              recordID: CKRecord.ID(recordName: TripReadRules.recordName(groupID: gid, userId: user), zoneID: target.zoneID))
        if let parent = target.parent {
            record["groupRef"] = CKRecord.Reference(recordID: parent, action: .none)
            record.parent = CKRecord.Reference(recordID: parent, action: .none)
        }
        record["userId"] = user
        record["lastReadAt"] = at
        Task {
            do {
                let result = try await target.database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
                if case .failure(let error) = result.saveResults[record.recordID] { throw error }
            } catch {
                CloudDiagnostics.record("既読を 送る", CloudDiagnostics.report(error))
            }
        }
    }
}
