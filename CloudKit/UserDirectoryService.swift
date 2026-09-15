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
        return DirectoryProfile(id: id, name: name, username: username, bio: bio, avatarData: avatarData, cloudKitUserRecordName: cloudKitUserRecordName)
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

    /// idを指定して、他人が公開しているプロフィール情報を取得する。
    /// 相手がまだ一度もpublish(_:)を呼んでいない(=旧バージョンのまま/未編集)場合はnil。
    static func fetchProfile(id: UUID) async -> DirectoryProfile? {
        let recordID = CKRecord.ID(recordName: "\(directoryRecordIDPrefix)\(id.uuidString)")
        guard let record = try? await publicDatabase.record(for: recordID) else { return nil }
        return directoryProfile(from: record)
    }
}
