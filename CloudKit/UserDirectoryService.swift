import CloudKit
import Foundation

/// 不特定ユーザーへのプロフィール共有(laterapp://リンク/QRコード)のための、
/// Public DB上の最小限の公開ディレクトリ。GroupSharingServiceのGroupInvite
/// (合言葉→共有URLをPublic DBに置く)と同じ方針を、ユーザー単体に適用したもの。
/// グループの共有ゾーン経由の同期(CloudKitManager)とは完全に独立している。
enum UserDirectoryService {
    private static var publicDatabase: CKDatabase {
        CKContainer(identifier: CloudKitManager.containerIdentifier).publicCloudDatabase
    }

    /// 自分のプロフィールを公開ディレクトリへ発行/更新する。プロフィール作成時・編集時に呼ぶ。
    /// savePolicy: .changedKeysで、既存レコードの有無やchangeTagを気にせず上書きできるようにする
    /// (この用途では楽観ロックの衝突検知は不要なため)。
    static func publish(_ profile: UserProfile) async {
        let record = profile.toPublicDirectoryRecord()
        do {
            _ = try await publicDatabase.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys)
        } catch {
            print("UserDirectoryService: failed to publish profile: \(error)")
        }
    }

    struct DirectoryProfile: Identifiable {
        /// userdir_<id>のuuid部分。プレースホルダーのUserProfileを作る際の元情報として使う。
        let id: UUID
        let name: String
        let username: String
        let bio: String
        let avatarData: Data?
        /// このユーザー自身のiCloud上の識別子(CKContainer.userRecordID().recordName)。
        /// DM機能がsenderID/receiverIDとして使うため、旧バージョンで発行されたレコードには
        /// まだ無いことがある(その場合nil)。
        let cloudKitUserRecordName: String?
        /// 「名前で 見つかる」(古い レコードは オン あつかい)
        var discoverable = true
    }

    private static let directoryRecordIDPrefix = "userdir_"

    private static func directoryProfile(from record: CKRecord) -> DirectoryProfile? {
        guard record.recordID.recordName.hasPrefix(directoryRecordIDPrefix),
              let id = UUID(uuidString: String(record.recordID.recordName.dropFirst(directoryRecordIDPrefix.count))) else {
            return nil
        }
        let name = record["name"] as? String ?? ""
        let username = record["username"] as? String ?? ""
        let bio = record["bio"] as? String ?? ""
        var avatarData: Data?
        if let asset = record["avatar"] as? CKAsset, let fileURL = asset.fileURL {
            avatarData = try? Data(contentsOf: fileURL)
        }
        let cloudKitUserRecordName = record["cloudKitUserRecordName"] as? String
        var p = DirectoryProfile(id: id, name: name, username: username, bio: bio, avatarData: avatarData, cloudKitUserRecordName: cloudKitUserRecordName)
        if let d = record["discoverableByName"] as? Int64 { p.discoverable = d != 0 }
        return p
    }

    /// "@ユーザー名"の前方一致でPublic DBの公開ディレクトリを検索する。
    /// "username"にQUERYABLEのインデックスが必要(開発環境では初回save時に自動生成されるが、
    /// 本番デプロイ時は要確認)。
    static func search(usernamePrefix: String) async -> [DirectoryProfile] {
        let trimmed = usernamePrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let predicate = NSPredicate(format: "username BEGINSWITH %@", trimmed)
        let query = CKQuery(recordType: AppRecordType.userDirectory, predicate: predicate)
        do {
            let (results, _) = try await publicDatabase.records(matching: query, resultsLimit: 20)
            return results.compactMap { _, result in
                guard case .success(let record) = result else { return nil }
                return directoryProfile(from: record)
            }
        } catch {
            print("UserDirectoryService: search failed: \(error)")
            return []
        }
    }

    struct Hit: Identifiable {
        enum Kind { case exact, idPrefix, name }
        let profile: DirectoryProfile
        let kind: Kind
        var id: UUID { profile.id }
    }

    /// v94 C:ID ぴったり(いつでも)・ ID の 前方一致(2文字 から ・ 6人)・ 名前の 前方一致(8人)。
    /// 前方一致と 名前は 「名前で 見つかる」が オンの 人 だけ。ブロックした 人(blocked)は 出さない
    static func searchUsers(_ raw: String, blocked: Set<String> = [], myRecordName: String? = nil) async -> [Hit] {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        var out: [Hit] = []
        var seen = Set<UUID>()
        func keep(_ p: DirectoryProfile) -> Bool {
            if let rn = p.cloudKitUserRecordName, blocked.contains(rn) || rn == myRecordName { return false }
            return seen.insert(p.id).inserted
        }
        let isIDLike = q.hasPrefix("@") || q.unicodeScalars.allSatisfy { $0.isASCII }
        if isIDLike {
            let h = HandleRules.normalize(q)
            if h.count >= 1 {
                let exact = await search(usernamePrefix: h).filter { $0.username == h }
                for p in exact where keep(p) { out.append(Hit(profile: p, kind: .exact)) }
                if h.count >= 2 {
                    let pre = await search(usernamePrefix: h).filter { $0.username != h && $0.discoverable }
                    for p in pre.prefix(6) where keep(p) { out.append(Hit(profile: p, kind: .idPrefix)) }
                }
            }
        } else {
            let key = DirectoryNameKey.make(q)
            let predicate = NSPredicate(format: "nameSearch BEGINSWITH %@", key)
            let query = CKQuery(recordType: AppRecordType.userDirectory, predicate: predicate)
            if let (results, _) = try? await publicDatabase.records(matching: query, resultsLimit: 20) {
                for (_, r) in results { if case .success(let rec) = r, let p = directoryProfile(from: rec), p.discoverable, keep(p), out.count < 8 { out.append(Hit(profile: p, kind: .name)) } }
            }
        }
        return out
    }

    /// idを指定して、他人が公開しているプロフィール情報を取得する。
    /// 相手がまだ一度もpublish(_:)を呼んでいない(=旧バージョンのまま/未編集)場合はnil。
    static func fetchProfile(id: UUID) async -> DirectoryProfile? {
        let recordID = CKRecord.ID(recordName: "\(directoryRecordIDPrefix)\(id.uuidString)")
        guard let record = try? await publicDatabase.record(for: recordID) else { return nil }
        return directoryProfile(from: record)
    }

    /// v47:ともだちのQR/リンク(later://friend?u=<recordName>)から、名前を引く。
    /// "cloudKitUserRecordName"にQUERYABLEのインデックスが必要(開発環境では初回save時に自動生成。
    /// 本番デプロイ時は要確認)。相手が未publishなら nil(つながる処理自体は recordName だけで進められる)。
    static func fetchProfile(cloudKitUserRecordName: String) async -> DirectoryProfile? {
        let predicate = NSPredicate(format: "cloudKitUserRecordName == %@", cloudKitUserRecordName)
        let query = CKQuery(recordType: AppRecordType.userDirectory, predicate: predicate)
        do {
            let (results, _) = try await publicDatabase.records(matching: query, resultsLimit: 1)
            for (_, result) in results {
                if case .success(let record) = result, let profile = directoryProfile(from: record) { return profile }
            }
            return nil
        } catch {
            print("UserDirectoryService: fetchProfile(cloudKitUserRecordName:) failed: \(error)")
            return nil
        }
    }
}


/// 名前の 検索キー:小文字 + カタカナ → ひらがな + 空白なし
enum DirectoryNameKey {
    static func make(_ name: String) -> String {
        let hira = name.applyingTransform(.hiraganaToKatakana, reverse: true) ?? name
        return hira.lowercased().filter { !$0.isWhitespace }
    }
}
