import CloudKit
import Foundation
import Testing
@testable import Later_再度

/// v23 グループの 部屋:フィルター・絵文字・受けとり・とりけす・7日・新しいのが あるか・そろった
@MainActor
struct GroupChatTests {
    private let zone = CKRecordZone.ID(zoneName: "g", ownerName: "owner")

    private func record(_ name: String, sender: String, text: String, at date: Date, kind: String = "text") -> CKRecord {
        let r = CKRecord(recordType: ChatRecordType.message, recordID: CKRecord.ID(recordName: name, zoneID: zone))
        r["senderId"] = sender
        r["kind"] = kind
        r["text"] = text
        r["sentAt"] = date
        r["expiresAt"] = date.addingTimeInterval(ChatRules.lifetime)
        return r
    }

    @Test func 送る前のフィルター() {
        #expect(ChatRules.check("090-1234-5678 に 電話して") != nil)
        #expect(ChatRules.check("渋谷区 1丁目 2番 3号") != nil)
        #expect(ChatRules.check("a@b.co に 送って") != nil)
        #expect(ChatRules.check("死ね") != nil)
        #expect(ChatRules.check("きょうの 空、きれい") == nil)
        #expect(ChatRules.check("3こま 撮った") == nil)
    }

    @Test func 絵文字だけなら大きく() {
        #expect(ChatRules.isEmojiOnly("😂"))
        #expect(ChatRules.isEmojiOnly("🔥🔥"))
        #expect(!ChatRules.isEmojiOnly("ok 😂"))
        #expect(!ChatRules.isEmojiOnly("123"))
    }

    @Test func スタンプは表のとおり() {
        #expect(ChatRules.stickers == ["それな", "エモい", "草", "天才", "かわいい", "うける", "わかる", "えぐい", "優勝", "おつかれ", "ねむい", "すき"])
        #expect(ChatRules.quickStickers.count == 5)
    }

    @Test func 受けとりと_新しいのがあるか_とりけす() {
        let store = GroupChatStore(load: false)
        let group = UUID()
        let now = Date()
        store.receive(record: record("m1", sender: "rena", text: "あと そらだけ", at: now), groupID: group, myRecordName: "me")
        #expect(store.visible(group, blocked: []).map(\.text) == ["あと そらだけ"])
        #expect(store.hasUnread(group, me: "me", blocked: []))
        store.markSeen(group, at: now.addingTimeInterval(1))
        #expect(!store.hasUnread(group, me: "me", blocked: []))
        // ブロックした 人は 見えない
        #expect(store.visible(group, blocked: ["rena"]).isEmpty)
        // 通報で 隠す
        store.hide("m1")
        #expect(store.visible(group, blocked: []).isEmpty)
        store.removeRecord(named: "m1")
        #expect(store.last(group, blocked: []) == nil)
    }

    @Test func 七日をすぎたものは出さず_掃除で消える() async {
        let store = GroupChatStore(load: false)
        let group = UUID()
        let old = Date().addingTimeInterval(-8 * 86_400)
        store.receive(record: record("old", sender: "rena", text: "むかし", at: old), groupID: group, myRecordName: "me")
        store.receive(record: record("new", sender: "rena", text: "いま", at: Date()), groupID: group, myRecordName: "me")
        #expect(store.visible(group, blocked: []).map(\.id) == ["new"])
        await store.prune(groups: [])
        #expect(store.messages[group]?.map(\.id) == ["new"])
    }

    @Test func そろった() {
        let a = GroupTogether.Member(id: "a", name: "a", seed: UUID(), avatarData: nil, isMe: true, shotToday: true)
        let b = GroupTogether.Member(id: "b", name: "b", seed: UUID(), avatarData: nil, isMe: false, shotToday: false)
        let c = GroupTogether.Member(id: "c", name: "c", seed: UUID(), avatarData: nil, isMe: false, shotToday: false)
        #expect(GroupTogether.status([a, b, c]) == "あと 2人で そろう")
        let b2 = GroupTogether.Member(id: "b", name: "b", seed: UUID(), avatarData: nil, isMe: false, shotToday: true)
        let c2 = GroupTogether.Member(id: "c", name: "c", seed: UUID(), avatarData: nil, isMe: false, shotToday: true)
        #expect(GroupTogether.status([a, b2, c2]) == "そろった")
        #expect(GroupTogether.status([a]) == nil)
    }

    @Test func 九時の区切り() {
        let cal = Calendar.current
        let day = cal.startOfDay(for: Date())
        let before = ChatMessage(id: "1", groupID: UUID(), senderId: "a", kind: .text, text: "x", sentAt: cal.date(byAdding: .hour, value: 8, to: day)!, expiresAt: .distantFuture)
        let after = ChatMessage(id: "2", groupID: UUID(), senderId: "a", kind: .text, text: "y", sentAt: cal.date(byAdding: .hour, value: 10, to: day)!, expiresAt: .distantFuture)
        #expect(ChatDivider.text(between: before, and: after) == "9:00 ・ きのうが ひらいた")
        #expect(ChatDivider.text(between: after, and: after) == nil)
    }
}
