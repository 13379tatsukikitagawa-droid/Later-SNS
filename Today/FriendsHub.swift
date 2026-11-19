import CloudKit
import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI
import UIKit

// v14 ⑤ ともだち:プロフィールを見せるだけで つながる。
// 3つのサブタブ:呼ぶ(プロフィールカード・送る・コピー・QR)/ グループに えらぶ / とどいた。
//
// CloudKit(公開 DB。Development で作ってから Production に Deploy):
// - Friendship(fromUserId, toUserId, fromName, createdAt):片方が作ると「申請」、相手も作ると「成立」(相互)。
//   公開 DB は作った人しか書きかえられない(_creator)ので、承認は「相手が自分の Friendship を作る」で表す。
// - GroupInviteCard(fromUserId, fromName, toUserId, groupName, memberCount, shareURL, createdAt):招待カード。
//   本人が「入る」を押して、共有(CKShare)を受けいれるまで、グループには入らない。「あとで」は端末に pending のまま残す。

// MARK: - 決まり

extension FriendRules {
    /// 招待カードを送れる人数(グループの上限 8人 − 自分)
    static let maxInvitees = GroupMembershipPolicy.maxMembersPerGroup - 1

    /// 相互で成立しているか(自分 → 相手、相手 → 自分 の両方がある)
    static func isMutual(mine: Set<String>, theirs: Set<String>, other: String) -> Bool {
        mine.contains(other) && theirs.contains(other)
    }

    /// 友達のリンク(QR にも入れる)
    static func link(recordName: String) -> URL {
        var c = URLComponents()
        c.scheme = "later"
        c.host = "friend"
        c.queryItems = [URLQueryItem(name: "u", value: recordName)]
        return c.url ?? URL(string: "later://friend")!
    }

    static func recordName(from url: URL) -> String? {
        guard Brand.isOurScheme(url), url.host == "friend" else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "u" }?.value
    }
}

enum InviteCardStatus: String, Codable, Sendable {
    case pending, accepted, declined
}

struct FriendInviteCard: Identifiable, Equatable {
    let id: String
    let fromName: String
    let groupName: String
    let memberCount: Int
    let shareURL: URL?
    var status: InviteCardStatus
}

// MARK: - CloudKit

@MainActor
enum FriendCloud {
    static let friendshipType = "Friendship"
    static let inviteType = "GroupInviteCard"

    private static var database: CKDatabase? { CloudKitManager.current?.container.publicCloudDatabase }

    /// つながる:自分 → 相手 の Friendship を作る(相手も作ると成立)。どちらかが 12人なら作らない
    static func connect(to other: String, myName: String, myCount: Int, theirCount: Int) async -> Result<Void, FriendError> {
        guard FriendRules.canConnect(myCount: myCount, theirCount: theirCount) else { return .failure(.full) }
        guard let database, let me = CloudKitManager.current?.currentUserRecordName, me != other else { return .failure(.notReady) }
        let record = CKRecord(recordType: friendshipType, recordID: CKRecord.ID(recordName: "friend_\(me)_\(other)"))
        record["fromUserId"] = me
        record["toUserId"] = other
        record["fromName"] = String(myName.prefix(24))
        record["createdAt"] = Date()
        do {
            _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
            return .success(())
        } catch {
            return .failure(.network)
        }
    }

    /// 自分が出した相手 / 自分あての相手(recordName の集合)
    static func friendIDs() async -> (mine: Set<String>, theirs: Set<String>) {
        guard let database, let me = CloudKitManager.current?.currentUserRecordName else { return ([], []) }
        async let out = ids(database, field: "fromUserId", equals: me, take: "toUserId")
        async let incoming = ids(database, field: "toUserId", equals: me, take: "fromUserId")
        return await (out, incoming)
    }

    /// v17:QR などで つながった人(自分が「つながる」を押した相手)。名前は、相手の Friendship の fromName か、つながったときの控え
    static func connections() async -> [BumpFriend] {
        guard let database, let me = CloudKitManager.current?.currentUserRecordName else { return BumpFriendStore.cached }
        async let out = records(database, field: "fromUserId", equals: me)
        async let incoming = records(database, field: "toUserId", equals: me)
        let (outs, ins) = await (out, incoming)
        guard let outs else { return BumpFriendStore.cached }
        var names: [String: String] = [:]
        for record in ins ?? [] {
            if let id = record["fromUserId"] as? String, let name = record["fromName"] as? String, !name.isEmpty { names[id] = name }
        }
        let sorted = outs.sorted { ($0["createdAt"] as? Date ?? .distantPast) < ($1["createdAt"] as? Date ?? .distantPast) }
        let friends: [BumpFriend] = sorted.compactMap { record in
            guard let id = record["toUserId"] as? String else { return nil }
            return BumpFriend(id: id, name: names[id] ?? BumpFriendStore.name(for: id) ?? "ともだち")
        }
        BumpFriendStore.cached = friends
        return friends
    }

    private static func records(_ database: CKDatabase, field: String, equals value: String) async -> [CKRecord]? {
        let query = CKQuery(recordType: friendshipType, predicate: NSPredicate(format: "%K == %@", field, value))
        guard let (results, _) = try? await database.records(matching: query, resultsLimit: 50) else { return nil }
        return results.compactMap { try? $0.1.get() }
    }

    private static func ids(_ database: CKDatabase, field: String, equals value: String, take: String) async -> Set<String> {
        let query = CKQuery(recordType: friendshipType, predicate: NSPredicate(format: "%K == %@", field, value))
        guard let (results, _) = try? await database.records(matching: query, resultsLimit: 50) else { return [] }
        return Set(results.compactMap { try? $0.1.get()[take] as? String })
    }

    /// 招待カードを送る(友達だけ。グループにはまだ入らない)
    static func sendInvites(to friends: [String], groupName: String, memberCount: Int, shareURL: URL?, myName: String) async -> Bool {
        guard let database, let me = CloudKitManager.current?.currentUserRecordName else { return false }
        let records = friends.map { other -> CKRecord in
            let record = CKRecord(recordType: inviteType, recordID: CKRecord.ID(recordName: "invite_\(me)_\(other)_\(UUID().uuidString.prefix(8))"))
            record["fromUserId"] = me
            record["fromName"] = String(myName.prefix(24))
            record["toUserId"] = other
            record["groupName"] = groupName
            record["memberCount"] = Int64(memberCount)
            record["shareURL"] = shareURL?.absoluteString
            record["createdAt"] = Date()
            return record
        }
        return (try? await database.modifyRecords(saving: records, deleting: [])) != nil
    }

    /// 自分あての招待カード(状態は端末に持つ:pending のものは「とどいた」に残る)
    static func inbox() async -> [FriendInviteCard] {
        guard let database, let me = CloudKitManager.current?.currentUserRecordName else { return [] }
        let query = CKQuery(recordType: inviteType, predicate: NSPredicate(format: "toUserId == %@", me))
        guard let (results, _) = try? await database.records(matching: query, resultsLimit: 30) else { return [] }
        return results.compactMap { id, result in
            guard let record = try? result.get() else { return nil }
            return FriendInviteCard(
                id: id.recordName,
                fromName: record["fromName"] as? String ?? "",
                groupName: record["groupName"] as? String ?? "",
                memberCount: Int(record["memberCount"] as? Int64 ?? 0),
                shareURL: (record["shareURL"] as? String).flatMap(URL.init(string:)),
                status: InviteCardStore.status(id.recordName)
            )
        }
    }
}

enum FriendError: Error, Equatable {
    case full, notReady, network
    var message: String {
        switch self {
        case .full: return FriendRules.fullMessage
        case .notReady: return "iCloud に つながってから、もう一度"
        case .network: return "送れませんでした。つながってから、もう一度"
        }
    }
}

/// 招待カードの状態(端末に持つ。公開 DB のカードは送った人しか書きかえられないため)
enum InviteCardStore {
    private static let key = "inviteCard.status"

    static func status(_ id: String, defaults: UserDefaults = .standard) -> InviteCardStatus {
        let all = defaults.dictionary(forKey: key) as? [String: String] ?? [:]
        return all[id].flatMap(InviteCardStatus.init(rawValue:)) ?? .pending
    }

    static func set(_ status: InviteCardStatus, for id: String, defaults: UserDefaults = .standard) {
        var all = defaults.dictionary(forKey: key) as? [String: String] ?? [:]
        all[id] = status.rawValue
        defaults.set(all, forKey: key)
    }
}

// MARK: - つながった人の控え

/// QR などで つながった人(公開 DB の Friendship から)
struct BumpFriend: Codable, Equatable, Identifiable {
    let id: String
    let name: String
}

/// QR などで つながった人の控え(端末の中だけ。通信できないときと、名前の控えに使う)
@MainActor
enum BumpFriendStore {
    private static let listKey = "bumpFriends.v1"
    private static let namesKey = "bumpFriendNames.v1"

    static var cached: [BumpFriend] {
        get { (UserDefaults.standard.data(forKey: listKey)).flatMap { try? JSONDecoder().decode([BumpFriend].self, from: $0) } ?? [] }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: listKey) }
    }

    static func name(for id: String) -> String? {
        (UserDefaults.standard.dictionary(forKey: namesKey) as? [String: String])?[id]
    }

    /// つながった瞬間:名前を控え、一覧にも足す(つぎの読み込みを待たずに、列に出す)
    static func remember(id: String, name: String) {
        var names = (UserDefaults.standard.dictionary(forKey: namesKey) as? [String: String]) ?? [:]
        names[id] = name
        UserDefaults.standard.set(names, forKey: namesKey)
        var list = cached
        if !list.contains(where: { $0.id == id }) { list.append(BumpFriend(id: id, name: name)); cached = list }
        NotificationCenter.default.post(name: .bumpFriendsChanged, object: nil)
    }
}

extension Notification.Name {
    static let bumpFriendsChanged = Notification.Name("bumpFriendsChanged")
}

// v98:古い 「ともだち ・ 呼ぶ / グループに えらぶ / とどいた」画面(FriendsHubView)は 消した。友だちを ふやす 入口は FriendsV68View の さがす 画面 1つ。

/// QR の画像(CoreImage)
enum QRImage {
    static func make(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
