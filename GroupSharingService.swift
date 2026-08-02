//
//  GroupSharingService.swift
//  Later 再度
//
//  グループ作成時のCKShare発行(合言葉→共有URLの解決含む)と、
//  参加コード経由でのShare受け入れを担当する。招待リンクを直接タップして
//  受け取ったCKShare.Metadataの受け入れにも同じacceptShare(metadata:)を使う。

import CloudKit
import Foundation
import SwiftData

enum GroupSharingError: LocalizedError {
    case notSignedIn
    case inviteNotFound
    case shareURLMissing
    case acceptFailed

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "iCloudアカウントの情報を取得できませんでした"
        case .inviteNotFound: return "合言葉が一致するグループが見つかりませんでした"
        case .shareURLMissing: return "共有リンクの取得に失敗しました"
        case .acceptFailed: return "グループへの参加に失敗しました"
        }
    }
}

@MainActor
final class GroupSharingService {
    private let container: CKContainer
    private let modelContext: ModelContext
    private let cloudKitManager: CloudKitManager

    init(container: CKContainer, modelContext: ModelContext, cloudKitManager: CloudKitManager) {
        self.container = container
        self.modelContext = modelContext
        self.cloudKitManager = cloudKitManager
    }

    /// 新規グループのゾーン+CKShareを作成し、合言葉(inviteCode)をPublic DBへ公開する。
    /// hostProfileは作成者自身のUserProfile。
    func createGroup(_ group: LaterGroup, hostProfile: UserProfile) async throws {
        guard let ownerName = cloudKitManager.currentUserRecordName else {
            throw GroupSharingError.notSignedIn
        }

        let zoneID = group.zoneID(ownerName: ownerName)
        let zone = CKRecordZone(zoneID: zoneID)
        _ = try await container.privateCloudDatabase.save(zone)

        let groupRecord = group.toCKRecord(existing: nil, ownerName: ownerName)
        let share = CKShare(rootRecord: groupRecord)
        share.publicPermission = .readWrite
        share[CKShare.SystemFieldKey.title] = group.name as CKRecordValue

        let hostRecordName = "profile_\(hostProfile.id.uuidString)_\(group.id.uuidString)"
        hostProfile.ckRecordName = hostRecordName
        hostProfile.cloudKitUserRecordName = ownerName
        let hostProfileRecord = hostProfile.toCKRecord(existing: nil, zoneID: zoneID, groupRecordID: groupRecord.recordID)

        let (saveResults, _) = try await container.privateCloudDatabase.modifyRecords(
            saving: [groupRecord, hostProfileRecord, share],
            deleting: []
        )

        guard case .success(let savedShareRecord) = saveResults[share.recordID],
              let savedShare = savedShareRecord as? CKShare,
              let shareURL = savedShare.url else {
            throw GroupSharingError.shareURLMissing
        }

        group.ownerCloudKitUserRecordName = ownerName
        group.ckRecordName = groupRecord.recordID.recordName
        group.ckZoneName = zoneID.zoneName
        group.ckZoneOwnerName = zoneID.ownerName
        group.ckShareURL = shareURL.absoluteString

        hostProfile.ckZoneName = zoneID.zoneName
        hostProfile.ckZoneOwnerName = zoneID.ownerName

        try modelContext.save()

        try await publishInvite(joinCode: group.inviteCode, shareURL: shareURL)
    }

    private func publishInvite(joinCode: String, shareURL: URL) async throws {
        let recordID = CKRecord.ID(recordName: Self.inviteRecordName(joinCode: joinCode))
        let record = CKRecord(recordType: AppRecordType.groupInvite, recordID: recordID)
        record["joinCode"] = joinCode
        record["shareURL"] = shareURL.absoluteString
        _ = try await container.publicCloudDatabase.save(record)
    }

    /// 合言葉を解決してCKShareを受け入れる。反映されたローカルデータがSwiftDataに
    /// 現れるまでには、この呼び出し後にも短い非同期の遅延がある。
    func joinGroup(wordPass: String) async throws {
        let recordID = CKRecord.ID(recordName: Self.inviteRecordName(joinCode: wordPass))

        let inviteRecord: CKRecord
        do {
            inviteRecord = try await container.publicCloudDatabase.record(for: recordID)
        } catch {
            throw GroupSharingError.inviteNotFound
        }

        guard let shareURLString = inviteRecord["shareURL"] as? String,
              let shareURL = URL(string: shareURLString) else {
            throw GroupSharingError.shareURLMissing
        }

        let metadatas = try await container.shareMetadatas(for: [shareURL])
        guard case .success(let metadata) = metadatas[shareURL] else {
            throw GroupSharingError.acceptFailed
        }

        try await acceptShare(metadata: metadata)
    }

    /// 招待リンクを直接タップして受け取ったCKShare.Metadataを受け入れる。
    /// AppDelegateのuserDidAcceptCloudKitShareWithからShareInviteInbox経由で呼ばれる。
    func acceptShare(metadata: CKShare.Metadata) async throws {
        let results = try await container.accept([metadata])
        guard case .success = results[metadata] else {
            throw GroupSharingError.acceptFailed
        }

        await cloudKitManager.fetchSharedChangesNow()
    }

    /// 参加後、自分自身のUserProfileをこのグループの共有ゾーンにもアップロードする。
    /// (accept直後はまだローカルにgroup/zone情報が無いため、ローカル反映を待ってから呼ぶ)
    func uploadOwnProfile(_ profile: UserProfile, to group: LaterGroup) {
        cloudKitManager.markForUpload(userProfile: profile, in: group)
    }

    private static func inviteRecordName(joinCode: String) -> String {
        "invite_\(joinCode)"
    }
}
