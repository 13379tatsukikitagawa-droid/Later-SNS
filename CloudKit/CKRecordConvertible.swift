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
import os

private let logger = GroupSyncLogger.shared

enum AppRecordType {
    static let userProfile = "UserProfile"
    static let laterGroup = "LaterGroup"
    static let laterPhoto = "LaterPhoto"
    static let laterVideo = "LaterVideo"
    static let photoVote = "PhotoVote"
    static let groupInvite = "GroupInvite"
    static let userDirectory = "UserDirectory"
    static let report = "Report"
    static let block = "Block"
    static let worldPost = "WorldPost"
    static let todaysLaterSelection = "TodaysLaterSelection"
}

/// record.recordID.zoneID.ownerNameは、レコードの所有者自身が自分のprivateCloudDatabase
/// 経由でそのレコードを取得した場合、実際のCloudKitユーザーID(currentUserRecordName)ではなく
/// CloudKitの内部センチネル値CKCurrentUserDefaultName("__defaultOwner__")になる
/// (参加者がsharedCloudDatabase経由で同じゾーンを見る場合は実際のIDが返る)。これをそのまま
/// ckZoneOwnerNameとして保存すると、以降あらゆる箇所の「ownerName == currentUserRecordName」
/// 判定(CloudKitManager.fetchAndApplyZoneImmediately/engine(forZoneOwnerName:)/buildRecord等、
/// DB選択・エンジン選択の根幹)が常に不一致になり、本来privateCloudDatabaseを使うべき自分の
/// ゾーンをsharedCloudDatabase宛てに送ってしまい、サーバー側から
/// "Only shared zones can be accessed in the shared DB"(CKError 12)で拒否される。
/// ホストが自分のグループ画面を開いて同期するたびにこの上書きが起こり得るため、
/// apply(from:)でckZoneOwnerNameを設定する全箇所でこの関数を経由させる。
func resolvedZoneOwnerName(from record: CKRecord) -> String? {
    let rawOwnerName = record.recordID.zoneID.ownerName
    if rawOwnerName == CKCurrentUserDefaultName, let resolved = CloudKitManager.current?.currentUserRecordName {
        return resolved
    }
    return rawOwnerName
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

    /// includeAvatar: falseの場合、avatarフィールド自体を設定しない
    /// (CKError.quotaExceeded検知時、画像を除いて再試行するためのオプション。
    /// GroupSharingService.saveGroupRecords参照)。
    func toCKRecord(existing: CKRecord?, zoneID: CKRecordZone.ID, groupRecordID: CKRecord.ID, includeAvatar: Bool = true) -> CKRecord {
        let record = existing ?? CKRecord(recordType: AppRecordType.userProfile, recordID: recordID(zoneID: zoneID))
        record["name"] = name
        record["username"] = username
        record["bio"] = bio
        record["cloudKitUserRecordName"] = cloudKitUserRecordName
        record["firebaseUID"] = firebaseUID
        record["firebaseEmail"] = firebaseEmail
        record["group"] = CKRecord.Reference(recordID: groupRecordID, action: .deleteSelf)
        // CKShare(rootRecord: groupRecord)は階層共有(record.parentで連なるレコードのみが
        // 共有対象になる)方式のため、上のrecord["group"](通常のカスタムフィールド参照)とは
        // 別に、CloudKit予約のparentプロパティにもgroupRecordIDを設定する必要がある。
        // これが無いと、このレコード自体はゾーン内に保存されていても参加者側の
        // Shared DB経由のCKFetchRecordZoneChangesOperationには一切現れない
        // (「参加者がオーナーのUserProfileレコードを一切受信できない」不具合の原因)。
        // actionは.none(親削除に連動した自動削除はしない。削除はrecord["group"]側の
        // .deleteSelfで既に表現されているため、ここで重複させない)。
        record.parent = CKRecord.Reference(recordID: groupRecordID, action: .none)
        if includeAvatar, let profileImageData {
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
        firebaseUID = record["firebaseUID"] as? String ?? firebaseUID
        firebaseEmail = record["firebaseEmail"] as? String ?? firebaseEmail
        if let asset = record["avatar"] as? CKAsset, let fileURL = asset.fileURL {
            profileImageData = try? Data(contentsOf: fileURL)
        }
        ckRecordName = record.recordID.recordName
        ckZoneName = record.recordID.zoneID.zoneName
        ckZoneOwnerName = resolvedZoneOwnerName(from: record)
        ckRecordChangeTag = record.recordChangeTag
    }
}

// MARK: - UserProfile 公開ディレクトリ(不特定ユーザーへのプロフィール共有用、Public DB)
//
// 上のtoCKRecord/applyはグループの共有ゾーン内でのメンバー同期用。こちらは全く別物で、
// laterapp://リンク/QRコードで面識のない相手にidだけ渡された場合に、その相手の端末が
// ユーザー名・アイコンを引けるようにするための、Public DB上の最小限の公開レコード。
// recordIDは常にid.uuidStringから決定論的に決まる(GroupInviteの合言葉と同じ方針)。
extension UserProfile {
    var publicDirectoryRecordID: CKRecord.ID {
        CKRecord.ID(recordName: "userdir_\(id.uuidString)")
    }

    func toPublicDirectoryRecord() -> CKRecord {
        let record = CKRecord(recordType: AppRecordType.userDirectory, recordID: publicDirectoryRecordID)
        record["name"] = name
        record["username"] = username
        record["bio"] = bio
        // id(自己申告のローカルUUID)しか知らない相手からでも本当のiCloud識別子を
        // 引けるようにするため、自分のcloudKitUserRecordNameも公開しておく。
        record["cloudKitUserRecordName"] = cloudKitUserRecordName
        if let profileImageData {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
            if (try? profileImageData.write(to: tempURL)) != nil {
                record["avatar"] = CKAsset(fileURL: tempURL)
            }
        }
        return record
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

    /// includeIcon: falseの場合、iconフィールド自体を設定しない
    /// (CKError.quotaExceeded検知時、画像を除いて再試行するためのオプション。
    /// GroupSharingService.saveGroupRecords参照)。
    func toCKRecord(existing: CKRecord?, ownerName: String, includeIcon: Bool = true) -> CKRecord {
        let record = existing ?? CKRecord(recordType: AppRecordType.laterGroup, recordID: recordID(ownerName: ownerName))
        logger.debug("[GroupSync] toCKRecord: nameを設定中")
        record["name"] = name
        // "creationDate"はCKRecordがシステム予約語として自動管理するキーと衝突し、
        // 書き込もうとするとCKException(SIGABRT)でクラッシュするため別名にする。
        logger.debug("[GroupSync] toCKRecord: groupCreatedAtを設定中")
        record["groupCreatedAt"] = creationDate
        logger.debug("[GroupSync] toCKRecord: inviteCodeを設定中")
        record["inviteCode"] = inviteCode
        logger.debug("[GroupSync] toCKRecord: autoGenerateMissionを設定中")
        record["autoGenerateMission"] = autoGenerateMission
        logger.debug("[GroupSync] toCKRecord: isPrivateを設定中")
        record["isPrivate"] = isPrivate
        logger.debug("[GroupSync] toCKRecord: currentDailyMissionを設定中")
        record["currentDailyMission"] = currentDailyMission
        // MEの当日の目標撮影枚数。同じiCloudアカウントの別端末でも同じ目標・解禁判定に
        // なるよう、共有されないMEグループでもPrivate DB経由で同期する。
        logger.debug("[GroupSync] toCKRecord: personalDailyTargetCountを設定中")
        record["personalDailyTargetCount"] = personalDailyTargetCount
        logger.debug("[GroupSync] toCKRecord: personalTargetLastSetDateを設定中")
        record["personalTargetLastSetDate"] = personalTargetLastSetDate
        // 時間帯制限撤廃に伴い、「今のサイクル」の境界は日付からの計算ではなく
        // 実際に解禁が起きた瞬間になった。全メンバー間でサイクルの境界を一致させる
        // 必要があるため同期する(LaterGroup.currentCyclePhotos参照)。
        logger.debug("[GroupSync] toCKRecord: lastUnlockAtを設定中")
        record["lastUnlockAt"] = lastUnlockAt
        // CloudKitのCKRecordZoneは所有権を移せない(常に作成者のiCloudアカウントに残る)ため、
        // 「アプリ内で誰がホスト権限(招待リンク発行など)を持つか」はこのフィールドで
        // 別途表現し、全メンバー間で同期する。ホストが脱退した際の引き継ぎもこれを更新するだけで成立する。
        logger.debug("[GroupSync] toCKRecord: ownerCloudKitUserRecordNameを設定中")
        record["ownerCloudKitUserRecordName"] = ownerCloudKitUserRecordName
        // グループアイコン。UserProfile.toCKRecordのavatarと同じ方針(一時ファイル経由のCKAsset)。
        // オーナーに限らず全メンバーの端末から送信され得る(EditGroupView参照)。
        logger.debug("[GroupSync] toCKRecord: iconブロック開始")
        if includeIcon, let iconImageData {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
            do {
                try iconImageData.write(to: tempURL)
                // CKAsset(fileURL:)へ渡す直前に、書き込んだファイルが実際に存在するかを
                // 明示的に確認する。write(to:)自体が成功していれば通常は存在するはずだが、
                // 失敗時にnilのfileURLでCKAssetを生成することが絶対に無いよう、
                // 二重にガードする。
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    record["icon"] = CKAsset(fileURL: tempURL)
                } else {
                    logger.error("[GroupSync] LaterGroup.toCKRecord: icon一時ファイルが書き込み後に見つからないためicon設定をスキップ")
                }
            } catch {
                // os.Loggerは既定で変数の補間内容を"<private>"に伏せるため、原因調査の
                // 妨げにならないようprivacy: .publicを明示する。
                logger.error("[GroupSync] LaterGroup.toCKRecord: iconの一時ファイル書き込みに失敗 error=\(String(describing: error), privacy: .public)")
            }
        }
        return record
    }

    func apply(from record: CKRecord) {
        name = record["name"] as? String ?? name
        creationDate = record["groupCreatedAt"] as? Date ?? creationDate
        inviteCode = record["inviteCode"] as? String ?? inviteCode
        if let asset = record["icon"] as? CKAsset, let fileURL = asset.fileURL {
            iconImageData = try? Data(contentsOf: fileURL)
        }
        autoGenerateMission = record["autoGenerateMission"] as? Bool ?? autoGenerateMission
        isPrivate = record["isPrivate"] as? Bool ?? isPrivate
        currentDailyMission = record["currentDailyMission"] as? String
        personalDailyTargetCount = record["personalDailyTargetCount"] as? Int ?? personalDailyTargetCount
        personalTargetLastSetDate = record["personalTargetLastSetDate"] as? Date ?? personalTargetLastSetDate
        lastUnlockAt = record["lastUnlockAt"] as? Date ?? lastUnlockAt
        ownerCloudKitUserRecordName = record["ownerCloudKitUserRecordName"] as? String ?? ownerCloudKitUserRecordName
        ckRecordName = record.recordID.recordName
        ckZoneName = record.recordID.zoneID.zoneName
        ckZoneOwnerName = resolvedZoneOwnerName(from: record)
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
        record["locationName"] = locationName
        record["authorCloudKitUserRecordName"] = authorCloudKitUserRecordName
        record["authorNameCache"] = authorNameCache ?? owner?.name
        record["groupNameCache"] = groupNameCache
        // PhotoNotificationService(撮影通知のCKQuerySubscription)がプッシュペイロードに
        // desiredKeysとして含めるためのスカラー値。"group"(CKRecord.Reference)自体は
        // desiredKeysで直接取得できないため、遷移先グループを特定するためだけに
        // 文字列として複製しておく。
        record["groupIDString"] = groupID?.uuidString
        record["group"] = CKRecord.Reference(recordID: groupRecordID, action: .deleteSelf)
        // UserProfile.toCKRecordと同じ理由でparentを設定する(CKShareの階層共有に含めるため)。
        record.parent = CKRecord.Reference(recordID: groupRecordID, action: .none)

        if isUnlocked {
            do {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
                do {
                    try imageData.write(to: tempURL)
                } catch {
                    print("[GroupSync] LaterPhoto.toCKRecord: 画像書き込み失敗 recordID=\(recordID(zoneID: zoneID)), error=\(error)")
                    throw error
                }
                record["image"] = CKAsset(fileURL: tempURL)
            } catch {
                // 画像の設定だけを失敗させ、caption等の他フィールドは最低限送信できるように
                // ここで止める。record["image"]を設定しないまま(isUnlocked=falseの時と
                // 同じ状態)残りの処理(return record)まで到達させ、画像以外のフィールド
                // 更新を道連れにしない。
            }
        }

        return record
    }

    func apply(from record: CKRecord) throws {
        captureDate = record["captureDate"] as? Date ?? captureDate
        unlockDate = record["unlockDate"] as? Date ?? unlockDate
        isUnlocked = record["isUnlocked"] as? Bool ?? isUnlocked
        caption = record["caption"] as? String
        locationName = record["locationName"] as? String
        authorCloudKitUserRecordName = record["authorCloudKitUserRecordName"] as? String ?? authorCloudKitUserRecordName
        authorNameCache = record["authorNameCache"] as? String ?? authorNameCache
        groupNameCache = record["groupNameCache"] as? String ?? groupNameCache
        if let asset = record["image"] as? CKAsset {
            if let fileURL = asset.fileURL {
                do {
                    imageData = try Data(contentsOf: fileURL)
                } catch {
                    print("[GroupSync] LaterPhoto.apply: 画像読み込み失敗(Data変換エラー) recordName=\(record.recordID.recordName), fileURL=\(fileURL), error=\(error)")
                }
            } else {
                print("[GroupSync] LaterPhoto.apply: record内のCKAssetにfileURLが無い recordName=\(record.recordID.recordName)")
            }
        } else if isUnlocked {
            // isUnlocked=trueなのにimageキーが無い = 送信側の書き込みが失敗したか、
            // 投稿者側の再送信がまだ届いていない可能性が高い(現像中でisUnlocked=falseの
            // 写真は元々imageキーを持たないのが正常なので、その場合はログを出さない)。
            print("[GroupSync] LaterPhoto.apply: isUnlocked=trueだがrecord内にimageキーが存在しない recordName=\(record.recordID.recordName)")
        }
        ckRecordName = record.recordID.recordName
        ckZoneName = record.recordID.zoneID.zoneName
        ckZoneOwnerName = resolvedZoneOwnerName(from: record)
        ckRecordChangeTag = record.recordChangeTag
    }
}

// MARK: - LaterVideo (サムネイルは通常同期、動画本体は端末に永続保持しない)

extension LaterVideo {
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

    /// isUnlockedがfalse(ブラインド解禁待ち)の間は写真と同じくフィールドを一切設定しない
    /// (解禁タイミングを写真と揃えるため)。動画本体は、まだアップロード未確認
    /// (localFilePathが残っている)の間だけ、そのローカルファイルからCKAssetとして添付する。
    /// アップロード確認後(CloudKitManager.markSynced)はローカルの動画ファイル自体を
    /// 削除しているため、以降の再送ではサムネイルとメタデータだけを送り直す
    /// (動画データは既にCloudKit上にあるはずなので問題ない)。
    func toCKRecord(existing: CKRecord?, zoneID: CKRecordZone.ID, groupRecordID: CKRecord.ID) throws -> CKRecord {
        let record = existing ?? CKRecord(recordType: AppRecordType.laterVideo, recordID: recordID(zoneID: zoneID))
        record["captureDate"] = captureDate
        record["unlockDate"] = unlockDate
        record["isUnlocked"] = isUnlocked
        record["durationSeconds"] = durationSeconds
        record["caption"] = caption
        record["locationName"] = locationName
        record["authorCloudKitUserRecordName"] = authorCloudKitUserRecordName
        record["authorNameCache"] = authorNameCache ?? owner?.name
        record["groupNameCache"] = groupNameCache
        record["groupIDString"] = groupID?.uuidString
        record["group"] = CKRecord.Reference(recordID: groupRecordID, action: .deleteSelf)
        record.parent = CKRecord.Reference(recordID: groupRecordID, action: .none)

        if isUnlocked {
            let thumbTempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
            do {
                try thumbnailData.write(to: thumbTempURL)
                record["thumbnail"] = CKAsset(fileURL: thumbTempURL)
            } catch {
                print("[GroupSync] LaterVideo.toCKRecord: サムネイル書き込み失敗 recordID=\(recordID(zoneID: zoneID)), error=\(error)")
            }

            if let localFilePath, FileManager.default.fileExists(atPath: localFilePath) {
                record["video"] = CKAsset(fileURL: URL(fileURLWithPath: localFilePath))
            }
        }

        return record
    }

    /// 動画本体(CKAsset)は意図的にここで永続化しない。CKSyncEngineが同期の過程で
    /// システムのtmp領域へ一時ファイルとしてダウンロードすること自体は避けられないが、
    /// サムネイルだけを取り込み、動画バイト列はどこにもコピーしない。再生はタップ時に
    /// CloudKitManager.fetchVideoAsset(for:)で都度取得する(写真で起きたDocuments & Data
    /// 肥大化を動画では繰り返さないための設計)。
    func apply(from record: CKRecord) throws {
        captureDate = record["captureDate"] as? Date ?? captureDate
        unlockDate = record["unlockDate"] as? Date ?? unlockDate
        isUnlocked = record["isUnlocked"] as? Bool ?? isUnlocked
        durationSeconds = record["durationSeconds"] as? Double ?? durationSeconds
        caption = record["caption"] as? String
        locationName = record["locationName"] as? String
        authorCloudKitUserRecordName = record["authorCloudKitUserRecordName"] as? String ?? authorCloudKitUserRecordName
        authorNameCache = record["authorNameCache"] as? String ?? authorNameCache
        groupNameCache = record["groupNameCache"] as? String ?? groupNameCache

        if let asset = record["thumbnail"] as? CKAsset, let fileURL = asset.fileURL {
            do {
                thumbnailData = try Data(contentsOf: fileURL)
            } catch {
                print("[GroupSync] LaterVideo.apply: サムネイル読み込み失敗 recordName=\(record.recordID.recordName), error=\(error)")
            }
        }

        ckRecordName = record.recordID.recordName
        ckZoneName = record.recordID.zoneID.zoneName
        ckZoneOwnerName = resolvedZoneOwnerName(from: record)
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

    func toCKRecord(existing: CKRecord?, zoneID: CKRecordZone.ID, photoRecordID: CKRecord.ID, groupRecordID: CKRecord.ID) -> CKRecord {
        let record = existing ?? CKRecord(recordType: AppRecordType.photoVote, recordID: recordID(zoneID: zoneID))
        record["voterCloudKitUserRecordName"] = voterCloudKitUserRecordName
        record["roundNumber"] = roundNumber
        record["votedAt"] = votedAt
        record["reactionSpeed"] = reactionSpeed
        record["photo"] = CKRecord.Reference(recordID: photoRecordID, action: .deleteSelf)
        // UserProfile.toCKRecordと同じ理由でparentを設定する(CKShareの階層共有に含めるため)。
        // 親はphotoではなくgroupRecordを直接指す(groupRecordがCKShareのrootRecordのため、
        // 階層はgroupRecordを起点に1段でフラットに揃えておく)。
        record.parent = CKRecord.Reference(recordID: groupRecordID, action: .none)
        return record
    }

    func apply(from record: CKRecord) {
        voterCloudKitUserRecordName = record["voterCloudKitUserRecordName"] as? String ?? voterCloudKitUserRecordName
        roundNumber = record["roundNumber"] as? Int ?? roundNumber
        votedAt = record["votedAt"] as? Date ?? votedAt
        reactionSpeed = record["reactionSpeed"] as? TimeInterval ?? reactionSpeed
        ckRecordName = record.recordID.recordName
        ckZoneName = record.recordID.zoneID.zoneName
        ckZoneOwnerName = resolvedZoneOwnerName(from: record)
        ckRecordChangeTag = record.recordChangeTag
    }
}
