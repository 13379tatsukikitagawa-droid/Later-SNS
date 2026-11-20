import Foundation
import CloudKit

/// P07:友だちの 申請 → 承認。CloudKit の 公開DB に 宣言ずみの `ConnectionRequest` / `ConnectionResponse` を つかう
/// (CloudKitSchema/Later.ckdb)。つながり(`Friendship`)は これまでどおり おたがいの 記録が そろうと 相互。
///
/// - 申請:自分が ConnectionRequest を つくる(`req_<自分>_<相手>`)。作った 本人しか 書きかえられない ので、
///   受けとった 側は 返事を ConnectionResponse に 書く(承認 / 見おくり)。
/// - 承認した 側:返事を 書いて、自分 → 相手の Friendship も つくる。
/// - 申請した 側:次の 同期で「承認された」返事を 見つけたら、自分 → 相手の Friendship を つくる(syncAccepted)。
enum FriendRequests {
    static let requestType = "ConnectionRequest"
    static let responseType = "ConnectionResponse"

    struct Request: Identifiable, Equatable {
        let id: String
        let fromUserID: String
        let toUserID: String
        let fromName: String
        let createdAt: Date
        var fromUsername: String = ""
    }

    struct Response: Equatable {
        let requesterID: String
        let responderID: String
        let decision: String
    }

    // MARK: 純粋な 決まり(テストできる)

    /// 自分あての 申請の うち、まだ 返事を して いない もの(新しい 順)。同じ 相手からの 重複は 1つに。
    static func pending(requests: [Request], myResponses: [Response], me: String) -> [Request] {
        let answered = Set(myResponses.filter { $0.responderID == me }.map(\.requesterID))
        var seen = Set<String>()
        return requests
            .filter { $0.toUserID == me && !answered.contains($0.fromUserID) && seen.insert($0.fromUserID).inserted }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// 自分の 申請に 「承認」が 返ってきた 相手(Friendship を つくる 相手)
    static func acceptedTargets(myRequests: [Request], responses: [Response], me: String) -> [String] {
        let targets = Set(myRequests.filter { $0.fromUserID == me }.map(\.toUserID))
        return responses.filter { $0.decision == "accepted" && targets.contains($0.responderID) && $0.requesterID == me }.map(\.responderID)
    }

    // MARK: CloudKit

    @MainActor private static var database: CKDatabase? { CloudKitManager.current?.container.publicCloudDatabase }
    @MainActor private static var me: String? { CloudKitManager.current?.currentUserRecordName }

    /// 申請を 送る(同じ 相手への 2回目は 上書き)
    @MainActor static func send(to other: String, toName: String, myName: String, myUsername: String = "") async -> Bool {
        if SocialFlag.useWorker {   // v108 (2):Worker(切りかえの スイッチ オン の とき だけ)
            guard let r = await SocialClient.send(toRecordName: other) else { return false }
            if r.status == "mutual" || r.status == "already" { _ = await FriendCloud.connect(to: other, myName: myName, myCount: 0, theirCount: 0) }
            return true
        }
        guard let database, let me, me != other else { return false }
        let record = CKRecord(recordType: requestType, recordID: CKRecord.ID(recordName: "req_\(me)_\(other)"))
        record["fromUserID"] = me
        record["toUserID"] = other
        record["fromUserName"] = String(myName.prefix(24))
        record["fromUsername"] = myUsername
        record["toUserName"] = String(toName.prefix(24))
        record["toUsername"] = ""
        record["status"] = "pending"
        record["createdAt"] = Date()
        do { _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys) }
        catch { print("[FriendRequests] send failed: \(error)"); return false }
        // v108 つなぎ:相手が すでに こちらに 申請 して いたら、承認 なしで すぐ 相互
        await acceptCrossed(myName: myName)
        return true
    }

    /// とどいている 申請(返事まえ)
    @MainActor static func incoming() async -> [Request] {
        if SocialFlag.useWorker {
            return await SocialClient.inbox().compactMap { r in
                guard let rn = r.recordName, !rn.isEmpty else { return nil }
                return Request(id: "w_" + r.uid, fromUserID: rn, toUserID: me ?? "", fromName: r.name ?? "", createdAt: Date(timeIntervalSince1970: r.createdAt / 1000), fromUsername: r.handle ?? "")
            }
        }
        guard let database, let me else { return [] }
        let reqs = await requests(database, field: "toUserID", equals: me)
        let myResp = await responses(database, field: "responderID", equals: me)
        return pending(requests: reqs, myResponses: myResp, me: me)
    }

    /// 承認 / 見おくり
    @MainActor static func respond(to r: Request, accept: Bool, myName: String) async -> Bool {
        if SocialFlag.useWorker {
            if accept {
                guard await SocialClient.accept(fromRecordName: r.fromUserID) else { return false }
                _ = await FriendCloud.connect(to: r.fromUserID, myName: myName, myCount: 0, theirCount: 0)
                return true
            }
            return await SocialClient.decline(fromRecordName: r.fromUserID)
        }
        guard let database, let me else { return false }
        let record = CKRecord(recordType: responseType, recordID: CKRecord.ID(recordName: "res_\(me)_\(r.fromUserID)"))
        record["requesterID"] = r.fromUserID
        record["responderID"] = me
        record["responderName"] = String(myName.prefix(24))
        record["responderUsername"] = ""
        record["decision"] = accept ? "accepted" : "declined"
        record["respondedAt"] = Date()
        do {
            _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
            if accept { _ = await FriendCloud.connect(to: r.fromUserID, myName: myName, myCount: 0, theirCount: 0) }
            return true
        } catch { print("[FriendRequests] respond failed: \(error)"); return false }
    }

    /// 自分が 出した 申請に 「承認」が 返って きて いたら、こちら側の Friendship も つくる(あいてが もう 友だち なら なにも しない)
    @MainActor static func syncAccepted(myName: String) async {
        if SocialFlag.useWorker { await SocialClient.mirrorFriendsToCloudKit(myName: myName); return }
        guard let database, let me else { return }
        await acceptCrossed(myName: myName)   // v108 つなぎ
        let mine = await requests(database, field: "fromUserID", equals: me)
        let resp = await responses(database, field: "requesterID", equals: me)
        let targets = acceptedTargets(myRequests: mine, responses: resp, me: me)
        guard !targets.isEmpty else { return }
        let (outgoing, _) = await FriendCloud.friendIDs()
        for t in targets where !outgoing.contains(t) {
            _ = await FriendCloud.connect(to: t, myName: myName, myCount: 0, theirCount: 0)
        }
    }


    /// v108 つなぎ:おたがいに 申請 して いる 相手は 承認 なしで 相互に する(返事 + 自分 → 相手)
    @MainActor static func acceptCrossed(myName: String) async {
        guard let database, let me else { return }
        let mine = await requests(database, field: "fromUserID", equals: me)
        let crossed = FriendRequestBridgeV108.crossedTargets(myRequests: mine, incoming: await incoming(), me: me)
        for r in crossed { _ = await respond(to: r, accept: true, myName: myName) }
    }

    // MARK: 読みとり

    @MainActor private static func requests(_ db: CKDatabase, field: String, equals value: String) async -> [Request] {
        let q = CKQuery(recordType: requestType, predicate: NSPredicate(format: "%K == %@", field, value))
        guard let (results, _) = try? await db.records(matching: q, resultsLimit: 50) else { return [] }
        return results.compactMap { try? $0.1.get() }.compactMap { r in
            guard let from = r["fromUserID"] as? String, let to = r["toUserID"] as? String else { return nil }
            return Request(id: r.recordID.recordName, fromUserID: from, toUserID: to, fromName: r["fromUserName"] as? String ?? "", createdAt: r["createdAt"] as? Date ?? .distantPast, fromUsername: r["fromUsername"] as? String ?? "")
        }
    }

    @MainActor private static func responses(_ db: CKDatabase, field: String, equals value: String) async -> [Response] {
        let q = CKQuery(recordType: responseType, predicate: NSPredicate(format: "%K == %@", field, value))
        guard let (results, _) = try? await db.records(matching: q, resultsLimit: 50) else { return [] }
        return results.compactMap { try? $0.1.get() }.compactMap { r in
            guard let req = r["requesterID"] as? String, let res = r["responderID"] as? String else { return nil }
            return Response(requesterID: req, responderID: res, decision: r["decision"] as? String ?? "")
        }
    }
}
