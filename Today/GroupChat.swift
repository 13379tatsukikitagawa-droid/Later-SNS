import CloudKit
import Foundation
import SwiftData
import UIKit
import UserNotifications

// MARK: - グループの 部屋(チャット)のデータ(v23)
//
// - メッセージは グループの 共有ゾーンに 置く(GroupChatMessage)。ノック(MemberEvent)と 同じく、
//   書くときは ゾーンへ 直接、受けとるのは いつもの 同期(CKSyncEngine)で apply(record:) から。
// - 端末では SwiftData に 入れず、グループごとの JSON に 持つ(7日で 消えるので スキーマを ふやさない)
// - 7日を すぎた ものは 出さない + 掃除で 消す(自分が 送った ものは サーバーからも 消す)
// - はった スタンプ:GroupChatSticker(1人 1メッセージに 1つ)。数は 出さない
//
// CloudKit(Development で 作る → 実機で 確かめる → Production に Deploy):
//   GroupChatMessage:groupRef(REFERENCE)/ senderId(STRING)/ kind(STRING)/ text(STRING)/ stickerId(STRING)/
//                     photoRef(REFERENCE・任意)/ sentAt(DATE/TIME)/ expiresAt(DATE/TIME)
//   GroupChatSticker:messageRef(REFERENCE)/ senderId(STRING)/ stickerId(STRING)

enum ChatRecordType {
    static let message = "GroupChatMessage"
    static let sticker = "GroupChatSticker"
}

/// 決めごと(画面を 持たない)
enum ChatRules {
    static let maxLength = 200
    static let lifetime: TimeInterval = 7 * 86_400

    /// スタンプ = ハッシュタグ(Later の 言葉)
    static let stickers = ["それな", "エモい", "草", "天才", "かわいい", "うける", "わかる", "えぐい", "優勝", "おつかれ", "ねむい", "すき"]
    /// 長押しの 上に 出す 5つ
    static let quickStickers = ["それな", "エモい", "草", "天才", "かわいい"]
    /// ダブルタップで はる
    static let doubleTapSticker = "それな"

    /// 絵文字だけ(3つまで)なら 大きく
    static func isEmojiOnly(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= 3 else { return false }
        return trimmed.allSatisfy { ch in ch.unicodeScalars.contains { $0.properties.isEmojiPresentation } || (ch.unicodeScalars.first?.properties.isEmoji == true && ch.unicodeScalars.count > 1) }
    }

    /// 送る前の フィルター。当たったら やさしい 文を 返す(送らない)
    static func check(_ text: String) -> String? {
        let t = text.lowercased()
        // 電話番号っぽい(数字 10〜11けた。ハイフン・空白は 無視)
        let digits = t.filter { $0.isNumber || "０１２３４５６７８９".contains($0) }
        if digits.count >= 10 { return "電話番号は、ここでは 送れません" }
        // 住所っぽい(丁目・番地・号 と 数字)
        if t.range(of: #"[0-9０-９]+\s*(丁目|番地|番|号)"#, options: .regularExpression) != nil || t.contains("〒") {
            return "住所は、ここでは 送れません"
        }
        // メール・外の SNS の ID
        if t.range(of: #"[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}"#, options: .regularExpression) != nil {
            return "メールアドレスは、ここでは 送れません"
        }
        for word in banned where t.contains(word) {
            return "その ことばは、ここでは 送れません"
        }
        return nil
    }

    /// 禁止ワード(いやがらせ・性的な ことば)。運用で ふやす
    static let banned: [String] = ["死ね", "しね", "殺す", "ころす", "きもい", "キモい", "ブス", "うざい", "消えろ", "せっくす", "セックス", "ちんこ", "まんこ", "おっぱい", "裸", "エロ", "援交", "パパ活", "line交換", "ライン交換", "インスタ教えて"]
}

/// 1つの メッセージ(端末に 持つ 形)
struct ChatMessage: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case text, sticker, photoReply, system
    }

    enum Status: String, Codable {
        case sending, sent, failed
    }

    let id: String
    let groupID: UUID
    let senderId: String
    let kind: Kind
    var text: String
    var stickerId: String?
    /// 返信した 写真(LaterPhoto の レコード名)
    var photoRecordName: String?
    let sentAt: Date
    let expiresAt: Date
    var status: Status = .sent

    func isExpired(now: Date = Date()) -> Bool { now >= expiresAt }
}

/// はった スタンプ(1人 1メッセージに 1つ)
struct ChatSticker: Codable, Identifiable, Equatable {
    let id: String
    let groupID: UUID
    let messageID: String
    let senderId: String
    let stickerId: String
}

/// 部屋の データ(端末の 中・グループごと)
@MainActor
@Observable
final class GroupChatStore {
    static let shared = GroupChatStore()

    private(set) var messages: [UUID: [ChatMessage]] = [:]
    private(set) var stickers: [UUID: [ChatSticker]] = [:]
    /// 最後に 部屋を 見た 時刻(新しいのが あれば オレンジの 点)
    private(set) var lastSeen: [UUID: Date] = [:]
    /// 通報して 自分の 画面から 隠した メッセージ
    private(set) var hidden: Set<String> = []
    /// 通知を 切った グループ
    private(set) var muted: Set<UUID> = []
    /// いま 開いている 部屋(この 部屋の 通知は 出さない)
    var openRoom: UUID?

    @ObservationIgnored private let launchedAt = Date()
    @ObservationIgnored private var lastNotified: [UUID: Date] = [:]

    private struct Snapshot: Codable {
        var messages: [UUID: [ChatMessage]]
        var stickers: [UUID: [ChatSticker]]
        var lastSeen: [UUID: Date]
        var hidden: Set<String>
        var muted: Set<UUID>
    }

    private static var fileURL: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("group-chat.v1.json")
    }

    init(load: Bool = true) {
        guard load, let data = try? Data(contentsOf: Self.fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        messages = snapshot.messages
        stickers = snapshot.stickers
        lastSeen = snapshot.lastSeen
        hidden = snapshot.hidden
        muted = snapshot.muted
        // 送っている 途中で 終わった ものは「!」に
        for (group, list) in messages {
            messages[group] = list.map { var m = $0; if m.status == .sending { m.status = .failed }; return m }
        }
    }

    private func persist() {
        let snapshot = Snapshot(messages: messages, stickers: stickers, lastSeen: lastSeen, hidden: hidden, muted: muted)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    // MARK: 読む

    /// 見せる メッセージ(7日以内・隠したもの・ブロックした人を のぞく。古い順)
    func visible(_ groupID: UUID, blocked: Set<String>, now: Date = Date()) -> [ChatMessage] {
        (messages[groupID] ?? [])
            .filter { !$0.isExpired(now: now) && !hidden.contains($0.id) && !blocked.contains($0.senderId) }
            .sorted { $0.sentAt < $1.sentAt }
    }

    func stickers(on messageID: String, groupID: UUID) -> [ChatSticker] {
        (stickers[groupID] ?? []).filter { $0.messageID == messageID }
    }

    /// 最後の メッセージ(行の 小さい文)
    func last(_ groupID: UUID, blocked: Set<String>) -> ChatMessage? {
        visible(groupID, blocked: blocked).last
    }

    /// 新しいのが あるか(自分の 以外)
    func hasUnread(_ groupID: UUID, me: String?, blocked: Set<String>) -> Bool {
        guard let last = visible(groupID, blocked: blocked).last(where: { $0.senderId != me && $0.kind != .system }) else { return false }
        return last.sentAt > (lastSeen[groupID] ?? .distantPast)
    }

    /// 見ていない 数(自分の ・ システムの は 数えない)
    func unreadCount(_ groupID: UUID, me: String?, blocked: Set<String>) -> Int {
        let seen = lastSeen[groupID] ?? .distantPast
        return visible(groupID, blocked: blocked).filter { $0.senderId != me && $0.kind != .system && $0.sentAt > seen }.count
    }

    func markSeen(_ groupID: UUID, at date: Date = Date()) {
        lastSeen[groupID] = date
        persist()
    }

    func isMuted(_ groupID: UUID) -> Bool { muted.contains(groupID) }

    func setMuted(_ groupID: UUID, _ on: Bool) {
        if on { muted.insert(groupID) } else { muted.remove(groupID) }
        persist()
    }

    /// 通報:自分の 画面で すぐ 隠す
    func hide(_ messageID: String) {
        hidden.insert(messageID)
        persist()
    }

    // MARK: 同期から(CloudKitManager.apply)

    /// 受けとった レコード。自分の 送った ものの 返りは「送れた」に
    func receive(record: CKRecord, groupID: UUID, myRecordName: String?) {
        switch record.recordType {
        case ChatRecordType.message:
            guard let message = Self.message(from: record, groupID: groupID) else { return }
            var list = messages[groupID] ?? []
            let isNew = !list.contains { $0.id == message.id }
            list.removeAll { $0.id == message.id }
            list.append(message)
            messages[groupID] = list
            persist()
            if isNew, message.senderId != myRecordName { didReceive(message) }
        case ChatRecordType.sticker:
            guard let sticker = Self.sticker(from: record, groupID: groupID) else { return }
            var list = stickers[groupID] ?? []
            list.removeAll { $0.id == sticker.id }
            list.append(sticker)
            stickers[groupID] = list
            persist()
        default:
            break
        }
    }

    func removeRecord(named name: String) {
        for (group, list) in messages where list.contains(where: { $0.id == name }) {
            messages[group] = list.filter { $0.id != name }
            stickers[group] = (stickers[group] ?? []).filter { $0.messageID != name }
        }
        for (group, list) in stickers where list.contains(where: { $0.id == name }) {
            stickers[group] = list.filter { $0.id != name }
        }
        persist()
    }

    static func message(from record: CKRecord, groupID: UUID) -> ChatMessage? {
        guard let sender = record["senderId"] as? String,
              let kindRaw = record["kind"] as? String, let kind = ChatMessage.Kind(rawValue: kindRaw),
              let sentAt = record["sentAt"] as? Date else { return nil }
        let expires = record["expiresAt"] as? Date ?? sentAt.addingTimeInterval(ChatRules.lifetime)
        let text = String((record["text"] as? String ?? "").prefix(ChatRules.maxLength))
        let photo = (record["photoRef"] as? CKRecord.Reference)?.recordID.recordName
        return ChatMessage(id: record.recordID.recordName, groupID: groupID, senderId: sender, kind: kind, text: text,
                           stickerId: record["stickerId"] as? String, photoRecordName: photo, sentAt: sentAt, expiresAt: expires)
    }

    static func sticker(from record: CKRecord, groupID: UUID) -> ChatSticker? {
        guard let sender = record["senderId"] as? String, let stickerId = record["stickerId"] as? String,
              let ref = record["messageRef"] as? CKRecord.Reference else { return nil }
        return ChatSticker(id: record.recordID.recordName, groupID: groupID, messageID: ref.recordID.recordName, senderId: sender, stickerId: stickerId)
    }

    // MARK: 送る

    enum SendError: Error { case notReady }

    /// 送る:自分の 画面に すぐ 出す → ゾーンへ 保存。失敗したら「!」(タップで 再送)
    @discardableResult
    func send(kind: ChatMessage.Kind, text: String = "", stickerId: String? = nil, photoRecordName: String? = nil, group: LaterGroup, now: Date = Date()) -> ChatMessage? {
        guard let me = CloudKitManager.current?.currentUserRecordName else { return nil }
        let id = "chat_\(UUID().uuidString)"
        let message = ChatMessage(id: id, groupID: group.id, senderId: me, kind: kind, text: String(text.prefix(ChatRules.maxLength)),
                                  stickerId: stickerId, photoRecordName: photoRecordName, sentAt: now,
                                  expiresAt: now.addingTimeInterval(ChatRules.lifetime), status: .sending)
        var list = messages[group.id] ?? []
        list.append(message)
        messages[group.id] = list
        markSeen(group.id, at: now)
        upload(message, group: group)
        let preview: String
        switch kind { case .text: preview = text; case .sticker: preview = "ステッカー"; default: preview = "写真" }
        Task { await SocialClient.tripChatPush(group: group, preview: preview) }
        return message
    }

    func retry(_ message: ChatMessage, group: LaterGroup) {
        update(message.id, groupID: group.id) { $0.status = .sending }
        upload(message, group: group)
    }

    private func upload(_ message: ChatMessage, group: LaterGroup) {
        guard let target = LayerCloud.target(for: group) else {
            update(message.id, groupID: group.id) { $0.status = .failed }
            return
        }
        let record = CKRecord(recordType: ChatRecordType.message, recordID: CKRecord.ID(recordName: message.id, zoneID: target.zoneID))
        if let parent = target.parent {
            record["groupRef"] = CKRecord.Reference(recordID: parent, action: .none)
            // 階層共有:グループの レコードを 親に しないと、参加者に 届かない
            record.parent = CKRecord.Reference(recordID: parent, action: .none)
        }
        record["senderId"] = message.senderId
        record["kind"] = message.kind.rawValue
        if !message.text.isEmpty { record["text"] = message.text }
        if let stickerId = message.stickerId { record["stickerId"] = stickerId }
        if let photo = message.photoRecordName {
            record["photoRef"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: photo, zoneID: target.zoneID), action: .none)
        }
        record["sentAt"] = message.sentAt
        record["expiresAt"] = message.expiresAt
        let groupID = group.id
        Task { @MainActor in
            do {
                let result = try await target.database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
                if case .failure(let error) = result.saveResults[record.recordID] { throw error }
                update(message.id, groupID: groupID) { $0.status = .sent }
            } catch {
                CloudDiagnostics.record("メッセージを 送る", CloudDiagnostics.report(error))
                update(message.id, groupID: groupID) { $0.status = .failed }
            }
        }
    }

    private func update(_ id: String, groupID: UUID, _ change: (inout ChatMessage) -> Void) {
        guard var list = messages[groupID], let index = list.firstIndex(where: { $0.id == id }) else { return }
        change(&list[index])
        messages[groupID] = list
        persist()
    }

    /// とりけす(自分の メッセージ):画面から 消して、サーバーからも 消す
    func unsend(_ message: ChatMessage, group: LaterGroup) {
        removeRecord(named: message.id)
        guard message.status != .failed, let target = LayerCloud.target(for: group) else { return }
        Task { _ = try? await target.database.deleteRecord(withID: CKRecord.ID(recordName: message.id, zoneID: target.zoneID)) }
    }

    /// スタンプを はる / もう一度で はがす(1人 1メッセージに 1つ。ちがう スタンプなら 入れかえ)
    func toggleSticker(_ stickerId: String, on message: ChatMessage, group: LaterGroup) -> Bool {
        guard let me = CloudKitManager.current?.currentUserRecordName, let target = LayerCloud.target(for: group) else { return false }
        let name = "chatstk_\(message.id)_\(LampIdentity.userHash(source: me))"
        let mine = (stickers[group.id] ?? []).first { $0.id == name }
        var list = (stickers[group.id] ?? []).filter { $0.id != name }
        if mine?.stickerId == stickerId {
            stickers[group.id] = list
            persist()
            Task { _ = try? await target.database.deleteRecord(withID: CKRecord.ID(recordName: name, zoneID: target.zoneID)) }
            return false
        }
        list.append(ChatSticker(id: name, groupID: group.id, messageID: message.id, senderId: me, stickerId: stickerId))
        stickers[group.id] = list
        persist()
        let record = CKRecord(recordType: ChatRecordType.sticker, recordID: CKRecord.ID(recordName: name, zoneID: target.zoneID))
        record["messageRef"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: message.id, zoneID: target.zoneID), action: .none)
        record["senderId"] = me
        record["stickerId"] = stickerId
        if let parent = target.parent { record.parent = CKRecord.Reference(recordID: parent, action: .none) }
        Task { _ = try? await target.database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys) }
        return true
    }

    // MARK: 7日を すぎた ものの 掃除

    /// 端末から 消す。自分が 送った ものは サーバーからも 消す
    func prune(groups: [LaterGroup], now: Date = Date()) async {
        let me = CloudKitManager.current?.currentUserRecordName
        var deletions: [(LaterGroup, String)] = []
        for (groupID, list) in messages {
            let expired = list.filter { $0.isExpired(now: now) }
            guard !expired.isEmpty else { continue }
            messages[groupID] = list.filter { !$0.isExpired(now: now) }
            let ids = Set(expired.map(\.id))
            stickers[groupID] = (stickers[groupID] ?? []).filter { !ids.contains($0.messageID) }
            if let group = groups.first(where: { $0.id == groupID }) {
                for message in expired where message.senderId == me { deletions.append((group, message.id)) }
            }
        }
        persist()
        for (group, name) in deletions {
            guard let target = LayerCloud.target(for: group) else { continue }
            _ = try? await target.database.deleteRecord(withID: CKRecord.ID(recordName: name, zoneID: target.zoneID))
        }
    }

    // MARK: 通知((b)「新しいメッセージが あります」だけ。名前・本文・グループ名は 出さない)

    private func didReceive(_ message: ChatMessage) {
        guard message.kind != .system, !message.isExpired() else { return }
        // 起動して 最初の 取りこみ(古い ものの まとめ取り)では 鳴らさない
        guard message.sentAt > launchedAt.addingTimeInterval(-120) else { return }
        if openRoom == message.groupID {
            Haptics.play(.soft)
            return
        }
        guard !muted.contains(message.groupID) else { return }
        // 同じ グループは 1分に 1回まで
        if let last = lastNotified[message.groupID], Date().timeIntervalSince(last) < 60 { return }
        lastNotified[message.groupID] = Date()
        let content = UNMutableNotificationContent()
        content.body = String(localized: "notification.chat.new")
        content.sound = .default
        content.threadIdentifier = "chat"
        content.userInfo = ["chatGroup": message.groupID.uuidString]
        let request = UNNotificationRequest(identifier: "chat_\(message.groupID.uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
