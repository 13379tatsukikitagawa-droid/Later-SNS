import Foundation
import UIKit

/// v108 (2) Worker(server/social-worker)への つなぎかえ。**切りかえの スイッチ `SocialFlag.useWorker` が オフの 間は 何も 呼ばない**
/// (今まで どおり CloudKit)。オンに するのは 実機で 確かめて から。
enum SocialFlag {
    /// DEBUG メニューの 手動スイッチ(今までの 名前)
    static let key = "useSocialWorker"
    /// Worker の `/v1/config` から 読んだ 前回の 値(読めない 時は これを 使う)
    static let remoteKey = "useSocialWorkerRemote"
    static var useWorker: Bool { UserDefaults.standard.bool(forKey: key) || UserDefaults.standard.bool(forKey: remoteKey) }
}

enum SocialClient {
    static let baseURL = URL(string: "https://later-social.later-social.workers.dev")!

    struct IncomingRequest: Decodable { let uid: String; let name: String?; let handle: String?; let recordName: String?; let createdAt: Double }
    struct Friend: Decodable { let uid: String; let name: String?; let handle: String?; let recordName: String? }
    private struct InboxResponse: Decodable { let requests: [IncomingRequest] }
    private struct FriendsResponse: Decodable { let friends: [Friend] }
    struct SendResult: Decodable { let status: String }

    enum Failure: Error { case noToken, http(Int), decode }

    private static func call(_ method: String, _ path: String, body: [String: Any]? = nil) async throws -> Data {
        guard let token = await AppleFirebaseAuth.idToken() else { throw Failure.noToken }
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.timeoutInterval = 15
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body { req.setValue("application/json", forHTTPHeaderField: "Content-Type"); req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw Failure.http(code) }
        return data
    }

    // MARK: Trip の 招待リンク(v109)

    struct TripLink: Decodable { let key: String; let groupName: String?; let fromName: String?; let dates: String?; let members: Int? }

    /// 受け取った トークンから KEY と Trip の 名前を 引く(ログイン 不要 ・ 1つの IP で 1分 10回 まで)。古い KEY 形式(maple24)は 404 → nil
    static func resolveTripLink(token: String) async -> TripLink? {
        guard let enc = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        var req = URLRequest(url: baseURL.appendingPathComponent("v1/trip-links/\(enc)"))
        req.timeoutInterval = 10
        guard let (data, resp) = try? await URLSession.shared.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(TripLink.self, from: data)
    }

    /// 招待リンクを 作る(トークンを 返す)。**アプリの 送る 文に つなぐのは、実機で たしかめて から**(いまは 呼ばない)
    static func createTripLink(key: String, groupName: String, fromName: String, dates: String, members: Int) async -> String? {
        struct R: Decodable { let token: String }
        guard let d = try? await call("POST", "/v1/trip-links", body: ["key": key, "groupName": groupName, "fromName": fromName, "dates": dates, "members": members]) else { return nil }
        return (try? JSONDecoder().decode(R.self, from: d))?.token
    }

    // MARK: リモート設定 ・ Trip の メンバー登録 ・ チャット通知(v111)

    /// 起動時と 前に 来た 時に 読む。読めない 時は 前回の 値を そのまま 使う(`useWorker` は 切りかえに 使う だけで この 呼び出しは 止めない)
    static func refreshConfig() async {
        struct C: Decodable { let useWorker: Bool }
        guard let d = try? await call("GET", "/v1/config"), let c = try? JSONDecoder().decode(C.self, from: d) else { return }
        UserDefaults.standard.set(c.useWorker, forKey: SocialFlag.remoteKey)
    }

    /// Trip の ID = LaterGroup.id(小文字の UUID)。共有ゾーンの 内側の 名前は 見る 人で かわる ため 使わない
    static func tripID(_ group: LaterGroup) -> String { group.id.uuidString.lowercased() }

    /// 入った 人が 自分で 登録する(何回 よんでも 同じ)
    static func joinTripMembership(_ group: LaterGroup) async {
        guard SocialFlag.useWorker, !group.isPersonalSpace else { return }
        _ = try? await call("POST", "/v1/trips/\(tripID(group))/members", body: [:])
    }
    static func leaveTripMembership(_ group: LaterGroup) async {
        guard SocialFlag.useWorker, !group.isPersonalSpace else { return }
        _ = try? await call("DELETE", "/v1/trips/\(tripID(group))/members", body: [:])
    }
    /// チャットを 送った 時。登録 ずみの ほかの メンバーへ(2分に 1回 まで ・ サーバーで 間引く)
    static func tripChatPush(group: LaterGroup, preview: String) async {
        guard SocialFlag.useWorker, !group.isPersonalSpace else { return }
        _ = try? await call("POST", "/v1/push/trip-chat", body: ["tripId": tripID(group), "tripName": group.name, "preview": preview])
    }

    // MARK: 自分

    /// ID ・ 名前 ・ CloudKit の 記録名を 登録(起動の たび ・ 同じ 内容なら 何も 変わらない)
    static func registerMe(handle: String, name: String, recordName: String?) async {
        _ = try? await call("POST", "/v1/me", body: ["handle": handle, "name": name, "recordName": recordName ?? ""])
    }

    /// APNs の 端末トークン(16進)を 登録 / ログアウトで 消す
    static func registerDevice(tokenHex: String) async {
        #if DEBUG
        let env = "development"
        #else
        let env = "production"
        #endif
        _ = try? await call("POST", "/v1/devices", body: ["token": tokenHex, "env": env])
    }
    static func unregisterDevice(tokenHex: String) async { _ = try? await call("DELETE", "/v1/devices", body: ["token": tokenHex]) }

    // MARK: 申請

    static func send(toRecordName: String) async -> SendResult? {
        guard let d = try? await call("POST", "/v1/requests", body: ["toRecordName": toRecordName]) else { return nil }
        return try? JSONDecoder().decode(SendResult.self, from: d)
    }
    static func accept(fromRecordName: String) async -> Bool { (try? await call("POST", "/v1/requests/accept", body: ["fromRecordName": fromRecordName])) != nil }
    static func decline(fromRecordName: String) async -> Bool { (try? await call("POST", "/v1/requests/decline", body: ["fromRecordName": fromRecordName])) != nil }
    static func inbox() async -> [IncomingRequest] {
        guard let d = try? await call("GET", "/v1/inbox"), let r = try? JSONDecoder().decode(InboxResponse.self, from: d) else { return [] }
        return r.requests
    }
    static func friends() async -> [Friend] {
        guard let d = try? await call("GET", "/v1/friends"), let r = try? JSONDecoder().decode(FriendsResponse.self, from: d) else { return [] }
        return r.friends
    }

    // MARK: 1回 だけ:CloudKit の 友だちを 移す(両方向の Friendship が ある 組 だけ)

    private static let migratedKey = "socialMigratedV108"
    @MainActor static func migrateLegacyFriendsOnce(recordName: String) async {
        guard SocialFlag.useWorker, !UserDefaults.standard.bool(forKey: migratedKey) else { return }
        let (mine, theirs) = await FriendCloud.friendIDs()
        let mutual = Array(mine.intersection(theirs))   // 片方 だけの 記録は 移さない
        guard let d = try? await call("POST", "/v1/migrate/friends", body: ["recordName": recordName, "friends": mutual]),
              (try? JSONSerialization.jsonObject(with: d)) != nil else { return }
        UserDefaults.standard.set(true, forKey: migratedKey)
    }

    /// Worker の 友だちを CloudKit の Friendship にも 反映(写真などの ほかの しくみが まだ CloudKit を 見る ため。v103 B〜E で なくす)
    @MainActor static func mirrorFriendsToCloudKit(myName: String) async {
        guard SocialFlag.useWorker else { return }
        let (outgoing, _) = await FriendCloud.friendIDs()
        for f in await friends() {
            guard let rn = f.recordName, !outgoing.contains(rn) else { continue }
            _ = await FriendCloud.connect(to: rn, myName: myName, myCount: 0, theirCount: 0)
        }
    }
}
