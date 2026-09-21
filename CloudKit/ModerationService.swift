import CloudKit
import Foundation
import SwiftData

/// 通報・ブロック機能。UserDirectoryServiceと同じ方針(グループの共有ゾーン同期
/// (CloudKitManager)とは完全に独立した、軽量なCKRecord直接操作)で実装する。
///
/// 通報(Report)はPublic DBに書き込むだけの一方向の記録で、アプリ側から読み返すことは
/// ない(モデレーションはCloudKitダッシュボード側で行う想定)。ブロック(Block)は
/// 自分のPrivate DBに保存する個人設定で、起動時にローカル(BlockedUser)へ同期し、
/// Circle/World Laterの一覧表示側はローカルの同期結果だけを見て除外を判定する。
enum ModerationService {
    private static var container: CKContainer {
        CKContainer(identifier: CloudKitManager.containerIdentifier)
    }

    // MARK: - 通報

    enum ReportTargetType: String {
        case worldPost
        case circlePhoto
        case user
    }

    enum ReportReason: String, CaseIterable, Identifiable {
        case inappropriate = "不適切な内容"
        case spam = "スパム・宣伝"
        case harassment = "嫌がらせ・誹謗中傷"
        case other = "その他"

        var id: String { rawValue }
    }

    /// 通報を1件送信する。reporterCloudKitUserRecordNameは悪用対策(同一人物からの
    /// 大量通報の検知)のためだけに保存し、アプリのUI上で他者に開示することはない。
    static func submitReport(
        targetType: ReportTargetType,
        targetID: String,
        reason: ReportReason,
        detail: String,
        reporterCloudKitUserRecordName: String?
    ) async throws {
        let record = CKRecord(recordType: AppRecordType.report)
        record["targetType"] = targetType.rawValue
        record["targetID"] = targetID
        record["reason"] = reason.rawValue
        record["detail"] = detail
        record["reporterCloudKitUserRecordName"] = reporterCloudKitUserRecordName
        record["reportedAt"] = Date()
        _ = try await container.publicCloudDatabase.save(record)
    }

    // MARK: - ブロック

    /// ユーザーを1人ブロックする。Private DB(自分専用、他人からは見えない)に保存し、
    /// 同時にローカル(BlockedUser)へも即座に反映する。
    @discardableResult
    static func blockUser(cloudKitUserRecordName: String, modelContext: ModelContext) async throws -> BlockedUser {
        let record = CKRecord(recordType: AppRecordType.block)
        record["blockedCloudKitUserRecordName"] = cloudKitUserRecordName
        record["blockedAt"] = Date()
        let saved = try await container.privateCloudDatabase.save(record)

        let blocked = BlockedUser(
            blockedCloudKitUserRecordName: cloudKitUserRecordName,
            createdAt: (saved["blockedAt"] as? Date) ?? Date(),
            ckRecordName: saved.recordID.recordName
        )
        modelContext.insert(blocked)
        try? modelContext.save()
        return blocked
    }

    /// ブロックを解除する。CloudKit側のBlockレコードを削除し、ローカルの記録も消す。
    static func unblockUser(_ blocked: BlockedUser, modelContext: ModelContext) async {
        if let ckRecordName = blocked.ckRecordName {
            let recordID = CKRecord.ID(recordName: ckRecordName)
            try? await container.privateCloudDatabase.deleteRecord(withID: recordID)
        }
        modelContext.delete(blocked)
        try? modelContext.save()
    }

    /// 起動時に一度、Private DBのBlockレコード一覧をローカル(BlockedUser)へ同期する。
    /// 件数は少ない前提のため、CKSyncEngineは使わず単純な全件クエリで十分。
    static func refreshBlockedUsersIfNeeded(modelContext: ModelContext) async {
        let query = CKQuery(recordType: AppRecordType.block, predicate: NSPredicate(value: true))
        guard let (results, _) = try? await container.privateCloudDatabase.records(matching: query) else { return }

        let existing = (try? modelContext.fetch(FetchDescriptor<BlockedUser>())) ?? []
        var existingByRecordName = Dictionary(uniqueKeysWithValues: existing.compactMap { blocked -> (String, BlockedUser)? in
            guard let name = blocked.ckRecordName else { return nil }
            return (name, blocked)
        })

        for (recordID, result) in results {
            guard case .success(let record) = result,
                  let blockedID = record["blockedCloudKitUserRecordName"] as? String else { continue }
            if existingByRecordName.removeValue(forKey: recordID.recordName) == nil {
                let blocked = BlockedUser(
                    blockedCloudKitUserRecordName: blockedID,
                    createdAt: (record["blockedAt"] as? Date) ?? Date(),
                    ckRecordName: recordID.recordName
                )
                modelContext.insert(blocked)
            }
        }
        // サーバー側で既に削除済み(=他端末でブロック解除済み)のローカル残骸を掃除する。
        for stale in existingByRecordName.values {
            modelContext.delete(stale)
        }
        try? modelContext.save()
    }
}
