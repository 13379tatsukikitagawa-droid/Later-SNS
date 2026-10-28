import Foundation
import Testing
import CloudKit
@testable import Later_再度

/// 設定(名前・写真の保存の条件)と、抜ける(PendingLeave・抜けた記録・終わったグループ)
@MainActor
@Suite(.serialized)
struct GroupSettingsLeaveTests {
    @Test func 保存が出る条件() {
        // 変更なし → 出さない
        #expect(!GroupEditRules.canSave(originalName: "よいしょー", name: "よいしょー", photoChanged: false, colorChanged: false))
        // 前後の空白だけ → 変更なし
        #expect(!GroupEditRules.canSave(originalName: "よいしょー", name: " よいしょー ", photoChanged: false, colorChanged: false))
        // 名前・写真・色のどれかが違う → 出す
        #expect(GroupEditRules.canSave(originalName: "よいしょー", name: "よいしょ", photoChanged: false, colorChanged: false))
        #expect(GroupEditRules.canSave(originalName: "よいしょー", name: "よいしょー", photoChanged: true, colorChanged: false))
        #expect(GroupEditRules.canSave(originalName: "よいしょー", name: "よいしょー", photoChanged: false, colorChanged: true))
        // 空にはできない(絵文字だけ・空白だけも空)
        #expect(!GroupEditRules.canSave(originalName: "よいしょー", name: "   ", photoChanged: true, colorChanged: false))
        #expect(!GroupEditRules.canSave(originalName: "よいしょー", name: "🌅", photoChanged: false, colorChanged: false))
    }

    @Test func PendingLeaveは残り_二重にならない() {
        let id = UUID()
        PendingLeaveStore.begin(id)
        PendingLeaveStore.begin(id)
        #expect(PendingLeaveStore.contains(id))
        #expect(PendingLeaveStore.all.keys.filter { $0 == id.uuidString }.count == 1)
        PendingLeaveStore.finish(id)
        #expect(!PendingLeaveStore.contains(id))
    }

    @Test func 抜けた記録は一度見たら出ない_7日で消える() {
        let group = UUID()
        let now = Date()
        let fresh = MemberEventStore.Event(id: "e-\(UUID())", groupID: group, memberName: "しずく", eventAt: now.addingTimeInterval(-3600))
        let old = MemberEventStore.Event(id: "e-\(UUID())", groupID: group, memberName: "あおぞら", eventAt: now.addingTimeInterval(-8 * 86_400))
        MemberEventStore.add(fresh)
        MemberEventStore.add(old)
        #expect(MemberEventStore.unseen(groupID: group, now: now).map(\.id) == [fresh.id])
        #expect(MemberEventStore.expired(now: now).contains { $0.id == old.id })
        MemberEventStore.markSeen([fresh.id])
        #expect(MemberEventStore.unseen(groupID: group, now: now).isEmpty)
        MemberEventStore.remove(id: fresh.id)
        MemberEventStore.remove(id: old.id)
    }

    @Test func 抜けた記録のレコードを読む() {
        let zone = CKRecordZone.ID(zoneName: "z", ownerName: "o")
        let record = CKRecord(recordType: AppRecordType.memberEvent, recordID: CKRecord.ID(recordName: "memberevent_1", zoneID: zone))
        record["eventType"] = "left"
        record["memberName"] = "しずく"
        record["eventAt"] = Date(timeIntervalSince1970: 100)
        let group = UUID()
        let event = MemberEventStore.event(from: record, groupID: group)
        #expect(event?.memberName == "しずく")
        #expect(event?.groupID == group)
        record["eventType"] = "joined"
        #expect(MemberEventStore.event(from: record, groupID: group) == nil)
    }

    @Test func 抜けたゾーンは取りこまない_終わったグループは1回だけ() {
        let zone = CKRecordZone.ID(zoneName: "group_\(UUID())", ownerName: "owner")
        #expect(!LeftGroupsStore.contains(zone))
        LeftGroupsStore.add(zone)
        #expect(LeftGroupsStore.contains(zone))

        let ended = EndedGroupsStore.Ended(groupID: UUID(), name: "よいしょー", colorIndex: 1)
        EndedGroupsStore.add(ended)
        EndedGroupsStore.add(ended)
        #expect(EndedGroupsStore.pending.filter { $0.groupID == ended.groupID }.count == 1)
        while let next = EndedGroupsStore.popFirst() { if next.groupID == ended.groupID { break } }
        #expect(!EndedGroupsStore.pending.contains { $0.groupID == ended.groupID })
    }
}
