//
//  CloudKitManager.swift
//  Later 再度
//
//  CKSyncEngineを2系統(Private DB / Shared DB)保持し、SwiftDataとの
//  相互反映を行う。オーナーとして作ったグループはPrivate DB、招待されて
//  参加したグループはShared DBに属するため、両方を監視する必要がある。

import CloudKit
import Foundation
import SwiftData

@MainActor
final class CloudKitManager: NSObject {
    static let containerIdentifier = "iCloud.jp.shotoku.later"

    /// AppDelegate(UIKit側のリモート通知コールバック)からアクセスするための参照。
    static weak var current: CloudKitManager?

    let container: CKContainer
    private let modelContext: ModelContext

    private(set) var currentUserRecordName: String?

    private var privateEngine: CKSyncEngine?
    private var sharedEngine: CKSyncEngine?

    private static let privateStateFileName = "ck_sync_state_private.json"
    private static let sharedStateFileName = "ck_sync_state_shared.json"
    private static let privateSubscriptionID = "later2-private-db-subscription"
    private static let sharedSubscriptionID = "later2-shared-db-subscription"

    init(modelContext: ModelContext) {
        self.container = CKContainer(identifier: Self.containerIdentifier)
        self.modelContext = modelContext
        super.init()
    }

    /// サインイン後に一度だけ呼ぶ。CKSyncEngineの起動と自動同期の開始を行う。
    func start() async {
        do {
            currentUserRecordName = try await container.userRecordID().recordName
        } catch {
            print("CloudKitManager: failed to fetch userRecordID: \(error)")
        }

        var privateConfig = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: Self.loadState(fileName: Self.privateStateFileName),
            delegate: self
        )
        privateConfig.subscriptionID = Self.privateSubscriptionID
        privateEngine = CKSyncEngine(privateConfig)

        var sharedConfig = CKSyncEngine.Configuration(
            database: container.sharedCloudDatabase,
            stateSerialization: Self.loadState(fileName: Self.sharedStateFileName),
            delegate: self
        )
        sharedConfig.subscriptionID = Self.sharedSubscriptionID
        sharedEngine = CKSyncEngine(sharedConfig)

        Self.current = self
    }

    /// グループ参加直後など、すぐにShared DBの内容を反映させたい場合に呼ぶ。
    func fetchSharedChangesNow() async {
        try? await sharedEngine?.fetchChanges()
    }

    /// CKSubscriptionからのリモート通知(プッシュ)を受けて呼ばれる。
    func handleRemoteNotification() async {
        try? await privateEngine?.fetchChanges()
        try? await sharedEngine?.fetchChanges()
    }

    // MARK: - ローカル変更のアップロード登録

    func markForUpload(userProfile: UserProfile, in group: LaterGroup) {
        inheritZone(zoneName: &userProfile.ckZoneName, zoneOwnerName: &userProfile.ckZoneOwnerName, from: group)
        if userProfile.ckRecordName == nil {
            userProfile.ckRecordName = "profile_\(userProfile.id.uuidString)_\(group.id.uuidString)"
        }
        try? modelContext.save()
        enqueueSave(zoneOwnerName: userProfile.ckZoneOwnerName, recordName: userProfile.ckRecordName, zoneName: userProfile.ckZoneName)
    }

    func markForUpload(group: LaterGroup) {
        guard let zoneOwnerName = group.ckZoneOwnerName, let zoneName = group.ckZoneName, let recordName = group.ckRecordName else { return }
        try? modelContext.save()
        enqueueSave(zoneOwnerName: zoneOwnerName, recordName: recordName, zoneName: zoneName)
    }

    func markForUpload(photo: LaterPhoto, in group: LaterGroup) {
        inheritZone(zoneName: &photo.ckZoneName, zoneOwnerName: &photo.ckZoneOwnerName, from: group)
        if photo.ckRecordName == nil {
            photo.ckRecordName = photo.id.uuidString
        }
        try? modelContext.save()
        enqueueSave(zoneOwnerName: photo.ckZoneOwnerName, recordName: photo.ckRecordName, zoneName: photo.ckZoneName)
    }

    func markForUpload(vote: PhotoVote, in group: LaterGroup) {
        inheritZone(zoneName: &vote.ckZoneName, zoneOwnerName: &vote.ckZoneOwnerName, from: group)
        if vote.ckRecordName == nil, let photoID = vote.photoID, let voterName = vote.voterCloudKitUserRecordName {
            vote.ckRecordName = PhotoVote.deterministicRecordName(roundNumber: vote.roundNumber, photoID: photoID, voterCloudKitUserRecordName: voterName)
        }
        try? modelContext.save()
        enqueueSave(zoneOwnerName: vote.ckZoneOwnerName, recordName: vote.ckRecordName, zoneName: vote.ckZoneName)
    }

    func markForDelete(vote: PhotoVote) {
        guard let recordName = vote.ckRecordName, let zoneName = vote.ckZoneName, let ownerName = vote.ckZoneOwnerName else { return }
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        engine(forZoneOwnerName: ownerName)?.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID)])
    }

    private func inheritZone(zoneName: inout String?, zoneOwnerName: inout String?, from group: LaterGroup) {
        if zoneName == nil { zoneName = group.ckZoneName }
        if zoneOwnerName == nil { zoneOwnerName = group.ckZoneOwnerName }
    }

    private func enqueueSave(zoneOwnerName: String?, recordName: String?, zoneName: String?) {
        guard let zoneOwnerName, let recordName, let zoneName else { return }
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: zoneOwnerName)
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        engine(forZoneOwnerName: zoneOwnerName)?.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
    }

    private func engine(forZoneOwnerName ownerName: String?) -> CKSyncEngine? {
        if let ownerName, let currentUserRecordName, ownerName != currentUserRecordName {
            return sharedEngine
        }
        return privateEngine
    }

    // MARK: - State persistence

    private static func stateFileURL(fileName: String) -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(fileName)
    }

    private static func loadState(fileName: String) -> CKSyncEngine.State.Serialization? {
        let url = stateFileURL(fileName: fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private func saveState(_ serialization: CKSyncEngine.State.Serialization, isPrivate: Bool) {
        let fileName = isPrivate ? Self.privateStateFileName : Self.sharedStateFileName
        let url = Self.stateFileURL(fileName: fileName)
        guard let data = try? JSONEncoder().encode(serialization) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url)
    }

    // MARK: - Fetch: サーバーからの受信をローカルへ反映

    private func applyFetchedChanges(_ event: CKSyncEngine.Event.FetchedRecordZoneChanges) {
        for modification in event.modifications {
            apply(record: modification.record)
        }
        for deletion in event.deletions {
            applyDeletion(recordID: deletion.recordID, recordType: deletion.recordType)
        }
        try? modelContext.save()
    }

    private func apply(record: CKRecord) {
        switch record.recordType {
        case AppRecordType.laterGroup:
            upsertGroup(from: record)
        case AppRecordType.userProfile:
            upsertUserProfile(from: record)
        case AppRecordType.laterPhoto:
            upsertPhoto(from: record)
        case AppRecordType.photoVote:
            upsertVote(from: record)
        default:
            break
        }
    }

    private func applyDeletion(recordID: CKRecord.ID, recordType: CKRecord.RecordType) {
        let recordName = recordID.recordName
        switch recordType {
        case AppRecordType.photoVote:
            if let vote = fetchOne(PhotoVote.self, { $0.ckRecordName == recordName }) {
                modelContext.delete(vote)
            }
        case AppRecordType.laterPhoto:
            if let photo = fetchOne(LaterPhoto.self, { $0.ckRecordName == recordName }) {
                modelContext.delete(photo)
            }
        default:
            break
        }
    }

    private func upsertGroup(from record: CKRecord) {
        let recordName = record.recordID.recordName
        let group = fetchOne(LaterGroup.self, { $0.ckRecordName == recordName })
            ?? (UUID(uuidString: recordName).map { id -> LaterGroup in
                let g = LaterGroup(name: "")
                g.id = id
                return g
            })
        guard let group else { return }
        group.apply(from: record)
        if modelContext.model(for: group.persistentModelID) == nil {
            modelContext.insert(group)
        }
    }

    private func upsertUserProfile(from record: CKRecord) {
        let recordName = record.recordID.recordName
        guard let groupID = groupID(fromReferenceField: "group", in: record),
              let group = fetchOne(LaterGroup.self, { $0.id == groupID }) else { return }

        let cloudKitUserRecordName = record["cloudKitUserRecordName"] as? String

        if let existing = fetchOne(UserProfile.self, { $0.ckRecordName == recordName }) {
            existing.apply(from: record)
            if !group.isMember(userID: existing.id) {
                _ = group.addMember(existing)
            }
            return
        }

        // 同じCloudKitユーザーの別グループ用プロフィールが既にローカルにあれば、
        // それを流用する(同一人物を複数のUserProfileとして重複させない)。
        if let cloudKitUserRecordName,
           let matching = fetchOne(UserProfile.self, { $0.cloudKitUserRecordName == cloudKitUserRecordName }) {
            matching.apply(from: record)
            if !group.isMember(userID: matching.id) {
                _ = group.addMember(matching)
            }
            return
        }

        let name = record["name"] as? String ?? ""
        let username = record["username"] as? String ?? ""
        let profile = UserProfile(name: name, username: username)
        profile.apply(from: record)
        modelContext.insert(profile)
        _ = group.addMember(profile)
    }

    private func upsertPhoto(from record: CKRecord) {
        let recordName = record.recordID.recordName
        guard let groupID = groupID(fromReferenceField: "group", in: record),
              let group = fetchOne(LaterGroup.self, { $0.id == groupID }) else { return }

        if let existing = fetchOne(LaterPhoto.self, { $0.ckRecordName == recordName }) {
            try? existing.apply(from: record)
            resolveOwner(for: existing, in: group)
            return
        }

        guard let id = UUID(uuidString: recordName) else { return }
        let photo = LaterPhoto(
            imageData: Data(),
            unlockDate: (record["unlockDate"] as? Date) ?? Date()
        )
        photo.id = id
        photo.groupID = groupID
        try? photo.apply(from: record)
        modelContext.insert(photo)
        group.photos.append(photo)
        resolveOwner(for: photo, in: group)
    }

    /// authorCloudKitUserRecordNameから、グループの既存メンバー(UserProfile)を
    /// ローカルで解決してownerリレーションシップに繋ぎ直す。
    private func resolveOwner(for photo: LaterPhoto, in group: LaterGroup) {
        guard photo.owner == nil, let authorRecordName = photo.authorCloudKitUserRecordName else { return }
        if let match = group.members.first(where: { $0.cloudKitUserRecordName == authorRecordName }) {
            photo.owner = match
        }
    }

    private func upsertVote(from record: CKRecord) {
        let recordName = record.recordID.recordName
        if let existing = fetchOne(PhotoVote.self, { $0.ckRecordName == recordName }) {
            existing.apply(from: record)
            return
        }

        guard let photoID = photoID(fromReferenceField: "photo", in: record),
              let photo = fetchOne(LaterPhoto.self, { $0.id == photoID }),
              let groupID = photo.groupID,
              let group = fetchOne(LaterGroup.self, { $0.id == groupID }) else { return }

        let voterCloudKitUserRecordName = record["voterCloudKitUserRecordName"] as? String
        let voter = group.members.first(where: { $0.cloudKitUserRecordName == voterCloudKitUserRecordName })

        // PhotoVote.init(photo:voter:)はvoterを必須とするため、解決できない場合は
        // 匿名のプレースホルダーを使わず、まだメンバー情報が揃っていないとみなして
        // 次回のfetch時に再試行する(voterのUserProfile同期が先に来ることが多いため実害は小さい)。
        guard let voter else { return }

        let vote = PhotoVote(photo: photo, voter: voter)
        vote.photoID = photoID
        vote.groupID = groupID
        vote.apply(from: record)
        modelContext.insert(vote)
    }

    private func groupID(fromReferenceField field: String, in record: CKRecord) -> UUID? {
        guard let reference = record[field] as? CKRecord.Reference else { return nil }
        return UUID(uuidString: reference.recordID.recordName)
    }

    private func photoID(fromReferenceField field: String, in record: CKRecord) -> UUID? {
        guard let reference = record[field] as? CKRecord.Reference else { return nil }
        return UUID(uuidString: reference.recordID.recordName)
    }

    private func fetchOne<T: PersistentModel>(_ type: T.Type, _ predicate: (T) -> Bool) -> T? {
        (try? modelContext.fetch(FetchDescriptor<T>()))?.first(where: predicate)
    }

    private func fetchAll<T: PersistentModel>(_ type: T.Type, _ predicate: (T) -> Bool) -> [T] {
        (try? modelContext.fetch(FetchDescriptor<T>()))?.filter(predicate) ?? []
    }

    // MARK: - Send: ローカル変更をCKRecordへ変換

    private func buildRecord(for recordID: CKRecord.ID) -> CKRecord? {
        let recordName = recordID.recordName
        let ownerName = recordID.zoneID.ownerName

        if let group = fetchOne(LaterGroup.self, { $0.ckRecordName == recordName }) {
            return group.toCKRecord(existing: nil, ownerName: ownerName)
        }
        if let profile = fetchOne(UserProfile.self, { $0.ckRecordName == recordName }),
           let groupID = fetchAll(LaterGroup.self, { $0.members.contains(where: { $0.id == profile.id }) }).first?.id,
           let group = fetchOne(LaterGroup.self, { $0.id == groupID }),
           let groupRecordID = group.cachedRecordID {
            return profile.toCKRecord(existing: nil, zoneID: recordID.zoneID, groupRecordID: groupRecordID)
        }
        if let photo = fetchOne(LaterPhoto.self, { $0.ckRecordName == recordName }),
           let groupID = photo.groupID,
           let group = fetchOne(LaterGroup.self, { $0.id == groupID }),
           let groupRecordID = group.cachedRecordID {
            return try? photo.toCKRecord(existing: nil, zoneID: recordID.zoneID, groupRecordID: groupRecordID)
        }
        if let vote = fetchOne(PhotoVote.self, { $0.ckRecordName == recordName }),
           let photoID = vote.photoID,
           let photo = fetchOne(LaterPhoto.self, { $0.id == photoID }),
           let photoRecordID = photo.cachedRecordID {
            return vote.toCKRecord(existing: nil, zoneID: recordID.zoneID, photoRecordID: photoRecordID)
        }
        return nil
    }
}

// MARK: - CKSyncEngineDelegate

extension CloudKitManager: CKSyncEngineDelegate {
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let stateUpdate):
            saveState(stateUpdate.stateSerialization, isPrivate: syncEngine === privateEngine)

        case .fetchedRecordZoneChanges(let changes):
            applyFetchedChanges(changes)

        case .sentRecordZoneChanges(let changes):
            for failedSave in changes.failedRecordSaves {
                print("CloudKitManager: save failed for \(failedSave.record.recordID): \(failedSave.error)")
            }

        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = context.options.scope
        let changes = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        guard !changes.isEmpty else { return nil }

        var recordsByID: [CKRecord.ID: CKRecord] = [:]
        for change in changes {
            guard case .saveRecord(let recordID) = change else { continue }
            if let record = buildRecord(for: recordID) {
                recordsByID[recordID] = record
            }
        }

        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changes) { recordID in
            recordsByID[recordID]
        }
    }
}
