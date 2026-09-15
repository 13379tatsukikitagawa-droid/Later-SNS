import CloudKit
import Foundation
import SwiftData

/// World Later(匿名グローバルフィード)・Today's Later(選出)のCloudKit連携。
/// UserDirectoryServiceと同じ方針(グループの共有ゾーン同期(CloudKitManager)とは
/// 完全に独立した、Public DBへの軽量な直接操作)で実装する。
///
/// 匿名性について: WorldPost/TodaysLaterSelectionレコードにはカスタムフィールドとして
/// 投稿者・選択者を特定できる情報を一切含めない。ただしCloudKitの仕様上、Public DBに
/// 保存されたレコードにはCKRecord.creatorUserRecordID(作成者のiCloud上のハッシュ化された
/// 識別子)がシステムメタデータとして常に付与される。このアプリはこれをUI上で
/// 取得・表示せず、「自分の投稿かどうか」の判定にのみローカルで使う(isOwnPost)。
/// これは自前のサーバーを持たないアプリがCloudKitの上で実現できる、実務上の匿名性の
/// 限界であり、暗号学的な匿名性(運営側からも一切追跡不可能)までは保証しない。
enum WorldLaterService {
    private static var container: CKContainer {
        CKContainer(identifier: CloudKitManager.containerIdentifier)
    }

    // MARK: - 投稿

    /// World Laterへ1枚投稿する。撮影者情報は一切添付しない。位置情報は区市町村レベルの
    /// 地名(locationRegion)のみ、緯度経度は送らない。unlockDateは撮影日の翌朝9:00
    /// (GroupUnlockPolicy.nextUnlockThreshold)で、解禁までは他ユーザー側でも画像本体を
    /// 表示しない(WorldLaterFeedView側の判定)。
    @discardableResult
    static func submitPost(
        imageData: Data,
        captureDate: Date,
        locationRegion: String? = nil,
        caption: String? = nil
    ) async throws -> WorldPost {
        let unlockDate = GroupUnlockPolicy.nextUnlockThreshold(after: captureDate)
        let record = CKRecord(recordType: AppRecordType.worldPost)
        record["captureDate"] = captureDate
        record["postedAt"] = Date()
        record["unlockDate"] = unlockDate
        record["locationRegion"] = locationRegion
        record["caption"] = caption
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        try imageData.write(to: tempURL)
        record["image"] = CKAsset(fileURL: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let saved = try await container.publicCloudDatabase.save(record)
        let post = WorldPost(
            imageData: imageData,
            captureDate: captureDate,
            unlockDate: unlockDate,
            isUnlocked: Date() >= unlockDate,
            locationRegion: locationRegion,
            caption: caption,
            isOwnPost: true
        )
        post.ckRecordName = saved.recordID.recordName
        post.ckRecordChangeTag = saved.recordChangeTag
        return post
    }

    /// recordNameを指定して1件だけ取得する(カレンダー機能でTodaysLaterSelection.
    /// targetPostRecordNameから元のWorldPostを引くために使う)。fetchRecentPostsの
    /// 直近件数の範囲外でも取得できるよう、直接IDでフェッチする。
    static func fetchPost(recordName: String, currentUserRecordName: String?) async -> WorldPost? {
        guard let record = try? await container.publicCloudDatabase.record(for: CKRecord.ID(recordName: recordName)),
              let asset = record["image"] as? CKAsset,
              let fileURL = asset.fileURL,
              let data = try? Data(contentsOf: fileURL) else { return nil }
        let captureDate = record["captureDate"] as? Date ?? Date()
        let unlockDate = record["unlockDate"] as? Date ?? GroupUnlockPolicy.nextUnlockThreshold(after: captureDate)
        let isOwnPost = currentUserRecordName != nil && record.creatorUserRecordID?.recordName == currentUserRecordName
        let post = WorldPost(
            imageData: data,
            captureDate: captureDate,
            unlockDate: unlockDate,
            isUnlocked: Date() >= unlockDate,
            locationRegion: record["locationRegion"] as? String,
            caption: record["caption"] as? String,
            isOwnPost: isOwnPost
        )
        post.ckRecordName = recordName
        post.ckRecordChangeTag = record.recordChangeTag
        return post
    }

    /// 自分の投稿を取り下げる(Public DBから削除)。
    static func deletePost(_ post: WorldPost) async {
        guard let ckRecordName = post.ckRecordName else { return }
        try? await container.publicCloudDatabase.deleteRecord(withID: CKRecord.ID(recordName: ckRecordName))
    }

    /// 直近の投稿を新しい順にまとめて取得する。自分の投稿かどうかは
    /// CKRecord.creatorUserRecordIDとcurrentUserRecordIDの一致で判定する
    /// (レコード自体には撮影者情報を含めていないため)。
    static func fetchRecentPosts(limit: Int = 30, currentUserRecordName: String?) async -> [WorldPost] {
        let query = CKQuery(recordType: AppRecordType.worldPost, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "postedAt", ascending: false)]
        guard let (results, _) = try? await container.publicCloudDatabase.records(matching: query, resultsLimit: limit) else {
            return []
        }
        return results.compactMap { recordID, result -> WorldPost? in
            guard case .success(let record) = result,
                  let asset = record["image"] as? CKAsset,
                  let fileURL = asset.fileURL,
                  let data = try? Data(contentsOf: fileURL) else { return nil }
            let captureDate = record["captureDate"] as? Date ?? Date()
            let unlockDate = record["unlockDate"] as? Date ?? GroupUnlockPolicy.nextUnlockThreshold(after: captureDate)
            let isOwnPost = currentUserRecordName != nil && record.creatorUserRecordID?.recordName == currentUserRecordName
            let post = WorldPost(
                imageData: data,
                captureDate: captureDate,
                unlockDate: unlockDate,
                isUnlocked: Date() >= unlockDate,
                locationRegion: record["locationRegion"] as? String,
                caption: record["caption"] as? String,
                isOwnPost: isOwnPost
            )
            post.ckRecordName = recordID.recordName
            post.ckRecordChangeTag = record.recordChangeTag
            return post
        }
    }

    // MARK: - Today's Laterの選出

    /// 見た投稿を「今日のLater」として選ぶ。1日1回までの制約は呼び出し側
    /// (TodaysLaterSelectionのローカル記録)で確認済みであること。
    static func submitSelection(targetPostRecordName: String, reasonTag: String) async throws {
        let record = CKRecord(recordType: AppRecordType.todaysLaterSelection)
        record["targetPostRecordName"] = targetPostRecordName
        record["reasonTag"] = reasonTag
        record["selectedAt"] = Date()
        _ = try await container.publicCloudDatabase.save(record)
    }

    /// 指定した自分の投稿群が、指定日に何回選ばれたかを数える(Tomorrow +1判定用)。
    /// 個々の選択者が誰かは一切取得しない(件数だけを見る)。
    static func fetchSelectionCount(for postRecordNames: [String], on date: Date, calendar: Calendar = .current) async -> Int {
        guard !postRecordNames.isEmpty else { return 0 }
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        let predicate = NSPredicate(
            format: "targetPostRecordName IN %@ AND selectedAt >= %@ AND selectedAt < %@",
            postRecordNames, startOfDay as NSDate, endOfDay as NSDate
        )
        let query = CKQuery(recordType: AppRecordType.todaysLaterSelection, predicate: predicate)
        guard let (results, _) = try? await container.publicCloudDatabase.records(matching: query) else { return 0 }
        return results.filter { if case .success = $0.1 { return true } else { return false } }.count
    }
}
