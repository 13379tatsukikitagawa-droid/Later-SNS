//
//  CKRecordConvertible.swift
//  Later 再度
//
//  SwiftDataモデル ⇔ CKRecord の変換をまとめる層。
//  各モデルはローカルの正としてSwiftDataに残り、ここでCKRecordとの
//  相互変換ロジックだけを持つ(CloudKitManagerから呼ばれる)。
//
//  「CKRecordType」はCloudKitフレームワーク自身が予約しているtypealiasなので、
//  自作の定数名前空間は必ず別名(AppRecordType)にする。

import CloudKit
import Foundation

enum AppRecordType {
    static let userProfile = "UserProfile"
    static let laterGroup = "LaterGroup"
    static let laterPhoto = "LaterPhoto"
    static let photoVote = "PhotoVote"
    static let groupInvite = "GroupInvite"
}

enum CloudKitZoneNaming {
    static func groupZoneName(groupID: UUID) -> String {
        "group-\(groupID.uuidString)"
    }
}

// MARK: - UserProfile (グループの共有ゾーン内に、メンバーごとのスナップショットとして同期する)

extension UserProfile {
    func recordID(zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: ckRecordName ?? "profile_\(id.uuidString)", zoneID: zoneID)
    }

    var cachedZoneID: CKRecordZone.ID? {
        guard let zoneName = ckZoneName, let ownerName = ckZoneOwnerName else { return nil }
        return CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
    }

    var cachedRecordID: CKRecord.ID? {
        guard let zoneID = cachedZoneID, let recordName = ckRecordName else { return nil }
        return CKRecord.ID(recordName: recordName, zoneID: zoneID)
    }

    func toCKRecord(existing: CKRecord?, zoneID: CKRecordZone.ID, groupRecordID: CKRecord.ID) -> CKRecord {
        let record = existing ?? CKRecord(recordType: AppRecordType.userProfile, recordID: recordID(zoneID: zoneID))
        record["name"] = name
        record["username"] = username
        record["bio"] = bio
        record["cloudKitUserRecordName"] = cloudKitUserRecordName
        record["group"] = CKRecord.Reference(recordID: groupRecordID, action: .deleteSelf)
        if let profileImageData {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
            if (try? profileImageData.write(to: tempURL)) != nil {
                record["avatar"] = CKAsset(fileURL: tempURL)
            }
        }
        return record
    }

    func apply(from record: CKRecord) {
        name = record["name"] as? String ?? name
        username = record["username"] as? String ?? username
        bio = record["bio"] as? String ?? bio
        cloudKitUserRecordName = record["cloudKitUserRecordName"] as? String ?? cloudKitUserRecordName
        if let asset = record["avatar"] as? CKAsset, let fileURL = asset.fileURL {
            profileImageData = try? Data(contentsOf: fileURL)
        }
        ckRecordName = record.recordID.recordName
        ckZoneName = record.recordID.zoneID.zoneName
        ckZoneOwnerName = record.recordID.zoneID.ownerName
        ckRecordChangeTag = record.recordChangeTag
    }
}

// MARK: - LaterGroup (CKShareのルートレコード。オーナーのPrivate DBカスタムゾーン)

extension LaterGroup {
    func zoneID(ownerName: String) -> CKRecordZone.ID {
        CKRecordZone.ID(
            zoneName: ckZoneName ?? CloudKitZoneNaming.groupZoneName(groupID: id),
            ownerName: ckZoneOwnerName ?? ownerName
        )
    }

    func recordID(ownerName: String) -> CKRecord.ID {
        CKRecord.ID(recordName: ckRecordName ?? id.uuidString, zoneID: zoneID(ownerName: ownerName))
    }

    var cachedZoneID: CKRecordZone.ID? {
        guard let zoneName = ckZoneName, let ownerName = ckZoneOwnerName else { return nil }
        return CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
    }

    var cachedRecordID: CKRecord.ID? {
        guard let zoneID = cachedZoneID, let recordName = ckRecordName else { return nil }
        return CKRecord.ID(recordName: recordName, zoneID: zoneID)
    }

    func toCKRecord(existing: CKRecord?, ownerName: String) -> CKRecord {
        let record = existing ?? CKRecord(recordType: AppRecordType.laterGroup, recordID: recordID(ownerName: ownerName))
        record["name"] = name
        record["creationDate"] = creationDate
        record["inviteCode"] = inviteCode
        record["autoGenerateMission"] = autoGenerateMission
        record["isPrivate"] = isPrivate
        record["currentDailyMission"] = currentDailyMission
        return record
    }

    func apply(from record: CKRecord) {
        name = record["name"] as? String ?? name
        creationDate = record["creationDate"] as? Date ?? creationDate
        inviteCode = record["inviteCode"] as? String ?? inviteCode
        autoGenerateMission = record["autoGenerateMission"] as? Bool ?? autoGenerateMission
        isPrivate = record["isPrivate"] as? Bool ?? isPrivate
        currentDailyMission = record["currentDailyMission"] as? String
        ckRecordName = record.recordID.recordName
        ckZoneName = record.recordID.zoneID.zoneName
        ckZoneOwnerName = record.recordID.zoneID.ownerName
        ckRecordChangeTag = record.recordChangeTag
    }
}

// MARK: - LaterPhoto (画像はCKAsset。isUnlockedがfalseの間は一切添付しない)

extension LaterPhoto {
    func recordID(zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: ckRecordName ?? id.uuidString, zoneID: zoneID)
    }

    var cachedZoneID: CKRecordZone.ID? {
        guard let zoneName = ckZoneName, let ownerName = ckZoneOwnerName else { return nil }
        return CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
    }

    var cachedRecordID: CKRecord.ID? {
        guard let zoneID = cachedZoneID, let recordName = ckRecordName else { return nil }
        return CKRecord.ID(recordName: recordName, zoneID: zoneID)
    }

    /// isUnlockedがfalse(現像中)の間は画像フィールドを一切設定しない。CKRecordは
    /// 明示的にセットしたキーしかサーバーへ送らないため、現像中の写真は本文(CKAsset)を
    /// 持たないレコードとしてCloudKit上に存在する。他のメンバーの端末はこのレコードを
    /// 同期しても画像バイト列を一切受け取らず、解禁後に投稿者側から再送されて初めて取得できる。
    func toCKRecord(existing: CKRecord?, zoneID: CKRecordZone.ID, groupRecordID: CKRecord.ID) throws -> CKRecord {
        let record = existing ?? CKRecord(recordType: AppRecordType.laterPhoto, recordID: recordID(zoneID: zoneID))
        record["captureDate"] = captureDate
        record["unlockDate"] = unlockDate
        record["isUnlocked"] = isUnlocked
        record["caption"] = caption
        record["authorCloudKitUserRecordName"] = authorCloudKitUserRecordName
        record["authorNameCache"] = authorNameCache ?? owner?.name
        record["group"] = CKRecord.Reference(recordID: groupRecordID, action: .deleteSelf)

        if isUnlocked {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
            try imageData.write(to: tempURL)
            record["image"] = CKAsset(fileURL: tempURL)
        }

        return record
    }

    func apply(from record: CKRecord) throws {
        captureDate = record["captureDate"] as? Date ?? captureDate
        unlockDate = record["unlockDate"] as? Date ?? unlockDate
        isUnlocked = record["isUnlocked"] as? Bool ?? isUnlocked
        caption = record["caption"] as? String
        authorCloudKitUserRecordName = record["authorCloudKitUserRecordName"] as? String ?? authorCloudKitUserRecordName
        authorNameCache = record["authorNameCache"] as? String ?? authorNameCache
        if let asset = record["image"] as? CKAsset, let fileURL = asset.fileURL {
            imageData = try Data(contentsOf: fileURL)
        }
        ckRecordName = record.recordID.recordName
        ckZoneName = record.recordID.zoneID.zoneName
        ckZoneOwnerName = record.recordID.zoneID.ownerName
        ckRecordChangeTag = record.recordChangeTag
    }
}

// MARK: - PhotoVote ((roundNumber, photoID, voter)で決定論的recordName)

extension PhotoVote {
    static func deterministicRecordName(roundNumber: Int, photoID: UUID, voterCloudKitUserRecordName: String) -> String {
        "vote_r\(roundNumber)_\(photoID.uuidString)_\(voterCloudKitUserRecordName)"
    }

    func recordID(zoneID: CKRecordZone.ID) -> CKRecord.ID {
        guard let photoID, let voterCloudKitUserRecordName else {
            return CKRecord.ID(recordName: ckRecordName ?? "vote_\(id.uuidString)", zoneID: zoneID)
        }
        let name = ckRecordName ?? Self.deterministicRecordName(roundNumber: roundNumber, photoID: photoID, voterCloudKitUserRecordName: voterCloudKitUserRecordName)
        return CKRecord.ID(recordName: name, zoneID: zoneID)
    }

    func toCKRecord(existing: CKRecord?, zoneID: CKRecordZone.ID, photoRecordID: CKRecord.ID) -> CKRecord {
        let record = existing ?? CKRecord(recordType: AppRecordType.photoVote, recordID: recordID(zoneID: zoneID))
        record["voterCloudKitUserRecordName"] = voterCloudKitUserRecordName
        record["roundNumber"] = roundNumber
        record["votedAt"] = votedAt
        record["reactionSpeed"] = reactionSpeed
        record["photo"] = CKRecord.Reference(recordID: photoRecordID, action: .deleteSelf)
        return record
    }

    func apply(from record: CKRecord) {
        voterCloudKitUserRecordName = record["voterCloudKitUserRecordName"] as? String ?? voterCloudKitUserRecordName
        roundNumber = record["roundNumber"] as? Int ?? roundNumber
        votedAt = record["votedAt"] as? Date ?? votedAt
        reactionSpeed = record["reactionSpeed"] as? TimeInterval ?? reactionSpeed
        ckRecordName = record.recordID.recordName
        ckZoneName = record.recordID.zoneID.zoneName
        ckZoneOwnerName = record.recordID.zoneID.ownerName
        ckRecordChangeTag = record.recordChangeTag
    }
}
