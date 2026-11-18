import Foundation
import CloudKit
import CryptoKit

// v96 C:ウィジェットの「つつく」。アプリを ひらかずに、拡張から CloudKit に ノック(MemberEvent "knock")を 書く。
// 書き方は アプリの KnockStore.knock と 同じ(1人に 1日 1回 = 同じ 名前の レコードは 2回 目で serverRecordChanged)。
// 拡張に iCloud(CloudKit)の entitlement が 必要(`LaterWidget.entitlements`)。

enum KnockSender {
    enum Outcome: Equatable { case sent, already, failed }

    static let containerID = "iCloud.jp.shotoku.later"
    private static let doneKey = "widget.knock.done.v1"

    /// アプリの LampIdentity.userHash と 同じ(画面に 出ない 匿名ハッシュ)
    static func userHash(_ source: String) -> String {
        let digest = SHA256.hash(data: Data(("lamp-v1|" + source).utf8))
        return digest.prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    static func recordName(window: String, from: String, to: String) -> String {
        "knock_\(window)_\(userHash(from))_\(userHash(to))"
    }

    static func alreadyDone(window: String, uid: String) -> Bool {
        (UserDefaults(suiteName: LattagShared.appGroup)?.stringArray(forKey: doneKey) ?? []).contains("\(window)|\(uid)")
    }

    private static func remember(window: String, uid: String) {
        guard let d = UserDefaults(suiteName: LattagShared.appGroup) else { return }
        var list = (d.stringArray(forKey: doneKey) ?? []).filter { $0.hasPrefix(window + "|") }
        list.append("\(window)|\(uid)")
        d.set(list, forKey: doneKey)
    }

    static func send(to friend: FriendRing, myRecordName: String?, myName: String, now: Date = Date()) async -> Outcome {
        let window = LaterDay.key(for: now)
        guard let me = myRecordName, !me.isEmpty, let t = friend.knock else { return .failed }
        if alreadyDone(window: window, uid: friend.uid) { return .already }
        let container = CKContainer(identifier: containerID)
        let db = t.shared ? container.sharedCloudDatabase : container.privateCloudDatabase
        let zone = CKRecordZone.ID(zoneName: t.zoneName, ownerName: t.zoneOwner)
        let record = CKRecord(recordType: "MemberEvent", recordID: CKRecord.ID(recordName: recordName(window: window, from: me, to: friend.uid), zoneID: zone))
        record["eventType"] = "knock"
        record["memberId"] = me
        record["memberName"] = String(myName.prefix(24))
        record["targetId"] = friend.uid
        record["eventAt"] = now
        if let p = t.parentRecordName {
            let parent = CKRecord.ID(recordName: p, zoneID: zone)
            record["groupRef"] = CKRecord.Reference(recordID: parent, action: .none)
            record.parent = CKRecord.Reference(recordID: parent, action: .none)
        }
        do {
            let result = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged)
            if case .failure(let error) = result.saveResults[record.recordID] {
                if (error as? CKError)?.code == .serverRecordChanged { remember(window: window, uid: friend.uid); return .already }
                return .failed
            }
            remember(window: window, uid: friend.uid)
            return .sent
        } catch {
            if (error as? CKError)?.code == .serverRecordChanged { remember(window: window, uid: friend.uid); return .already }
            return .failed
        }
    }
}
