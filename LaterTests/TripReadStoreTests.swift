import Testing
import Foundation
import CloudKit
@testable import Later_再度

/// v129 2章:既読 N と 未読の 数
@MainActor
struct TripReadStoreTests {
    private func t(_ m: Int) -> Date { Date(timeIntervalSinceReferenceDate: 800_000_000 + Double(m) * 60) }
    private func msg(_ id: String, _ who: String, _ m: Int, kind: ChatMessage.Kind = .text) -> ChatMessage {
        ChatMessage(id: id, groupID: UUID(), senderId: who, kind: kind, text: id, stickerId: nil, photoRecordName: nil, sentAt: t(m), expiresAt: t(m + 10_000))
    }

    @Test func readCountIsPeopleWhoReadAfterSending() {
        // me が 10分に 送った。a は 11分に 読んだ ・ b は 9分(前)・ c は ちょうど 10分
        let reads = ["me": t(30), "a": t(11), "b": t(9), "c": t(10)]
        #expect(TripReadRules.readCount(sentAt: t(10), senderId: "me", reads: reads) == 2)   // a と c ・ 自分は 数えない ・ b は まだ
    }

    @Test func readCountZeroWhenNobodyRead() {
        #expect(TripReadRules.readCount(sentAt: t(10), senderId: "me", reads: [:]) == 0)
        #expect(TripReadRules.readCount(sentAt: t(10), senderId: "me", reads: ["me": t(50)]) == 0)
    }

    @Test func unreadCountsOnlyOthersAfterLastRead() {
        let ms = [msg("1", "a", 1), msg("2", "a", 5), msg("3", "me", 6), msg("4", "b", 7), msg("s", "b", 8, kind: .system), msg("5", "b", 9)]
        #expect(TripReadRules.unread(ms, me: "me", lastRead: t(5)) == 2)       // 4 と 5(自分の 6 と system は 数えない)
        #expect(TripReadRules.unread(ms, me: "me", lastRead: nil) == 4)        // 1 2 4 5
        #expect(TripReadRules.unread(ms, me: "me", lastRead: t(100)) == 0)
    }

    @Test func recordNameIsStablePerUserAndGroup() {
        let g = UUID()
        #expect(TripReadRules.recordName(groupID: g, userId: "u1") == TripReadRules.recordName(groupID: g, userId: "u1"))
        #expect(TripReadRules.recordName(groupID: g, userId: "u1") != TripReadRules.recordName(groupID: g, userId: "u2"))
        #expect(TripReadRules.recordName(groupID: g, userId: "u1").hasPrefix("read_" + g.uuidString.lowercased() + "_"))
    }

    @Test func olderValueDoesNotOverwriteNewer() {
        let store = TripReadStore.shared
        let g = UUID()
        let r1 = CKRecordFor(g, "u9", t(20)), r2 = CKRecordFor(g, "u9", t(10))
        store.receive(record: r1, groupID: g)
        store.receive(record: r2, groupID: g)   // 古い 値は 無視
        #expect(store.lastRead(g, user: "u9") == t(20))
        store.removeRecord(named: TripReadRules.recordName(groupID: g, userId: "u9"))
        #expect(store.lastRead(g, user: "u9") == nil)
    }

    private func CKRecordFor(_ g: UUID, _ user: String, _ at: Date) -> CKRecord {
        let r = CKRecord(recordType: TripReadRecordType.state, recordID: CKRecord.ID(recordName: TripReadRules.recordName(groupID: g, userId: user)))
        r["userId"] = user; r["lastReadAt"] = at
        return r
    }
}
