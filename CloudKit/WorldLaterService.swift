import CloudKit
import CoreLocation
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

    // MARK: - 解禁時刻

    /// 翌朝9:00の解禁タイミング(captureDateの暦日の翌日9:00)。撮影がその日の何時であっても、
    /// 常に「翌朝」まで待つ(グループの「全員撮り終えた瞬間」解禁とは異なる、World独自の
    /// 固定タイミング解禁)。
    static func worldUnlockDate(for captureDate: Date, calendar: Calendar = .current) -> Date {
        let startOfCaptureDay = calendar.startOfDay(for: captureDate)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfCaptureDay) else { return captureDate }
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: nextDay) ?? nextDay
    }

    /// 「いま」から見た、直近の毎朝9:00解禁時刻(今が9:00より前ならその日の9:00、
    /// 過ぎていれば翌日の9:00)。撮影日を起点にするworldUnlockDate(for:)とは異なり、
    /// Home画面のカウントダウン・World画面のカウントダウンなど「次はいつ解禁されるか」
    /// を表示する箇所は必ずこちらを使う(表示ごとに別々に計算すると、端末の再起動
    /// タイミング等でずれる可能性があるため、単一の関数に統一する)。
    static func nextGlobalUnlockDate(from now: Date = Date(), calendar: Calendar = .current) -> Date {
        let todayNineAM = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        if now < todayNineAM { return todayNineAM }
        return calendar.date(byAdding: .day, value: 1, to: todayNineAM) ?? todayNineAM
    }

    // MARK: - 投稿

    /// World Laterへ1枚投稿する。撮影者情報は一切添付しない。位置は市区町村レベルまで
    /// 粗く丸めた座標のみ保存し(装飾的な座標ではなく実位置情報ベース)、写真本体は
    /// 翌朝9:00まで解禁されない(地域・時刻・キャプションは先出しで見える)。
    @discardableResult
    static func submitPost(imageData: Data, captureDate: Date, locationRegion: String?, caption: String?) async throws -> WorldPost {
        let coordinate = await OneShotLocationFetcher().fetchRoundedCoordinate()
        let unlockDate = worldUnlockDate(for: captureDate)
        // Home画面「現像中の写真の壁」用の代表色。壁は解禁前の投稿を並べて見せる演出のため、
        // 画像データそのものではなく、この2〜3色の代表色(ぼかしたグラデーション用)だけを
        // 先出しで公開する。抽出はローカル(自分の端末)で行い、CKAssetの画像本体とは別に
        // 軽量なフィールドとして保存する。
        let dominantColors = DominantColorExtractor.extractHexColors(from: imageData)

        let record = CKRecord(recordType: AppRecordType.worldPost)
        record["captureDate"] = captureDate
        record["postedAt"] = Date()
        record["unlockDate"] = unlockDate
        if !dominantColors.isEmpty {
            record["dominantColorHexes"] = dominantColors as CKRecordValue
        }
        if let locationRegion, !locationRegion.isEmpty {
            record["locationRegion"] = locationRegion
        }
        if let caption, !caption.isEmpty {
            record["caption"] = caption
        }
        if let coordinate {
            record["roundedLatitude"] = coordinate.lat
            record["roundedLongitude"] = coordinate.lon
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        try imageData.write(to: tempURL)
        record["image"] = CKAsset(fileURL: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let saved = try await container.publicCloudDatabase.save(record)
        let post = WorldPost(
            imageData: imageData,
            captureDate: captureDate,
            isOwnPost: true,
            locationRegion: locationRegion,
            roundedLatitude: coordinate?.lat,
            roundedLongitude: coordinate?.lon,
            caption: caption,
            unlockDate: unlockDate
        )
        post.dominantColorHexes = dominantColors
        post.ckRecordName = saved.recordID.recordName
        post.ckRecordChangeTag = saved.recordChangeTag
        return post
    }

    /// 自分の投稿を取り下げる(Public DBから削除)。
    static func deletePost(_ post: WorldPost) async {
        guard let ckRecordName = post.ckRecordName else { return }
        try? await container.publicCloudDatabase.deleteRecord(withID: CKRecord.ID(recordName: ckRecordName))
    }

    /// 直近の投稿を新しい順にまとめて取得する。自分の投稿かどうかは
    /// CKRecord.creatorUserRecordIDとcurrentUserRecordNameの一致で判定する
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
            let isOwnPost = currentUserRecordName != nil && record.creatorUserRecordID?.recordName == currentUserRecordName
            let unlockDate = record["unlockDate"] as? Date ?? worldUnlockDate(for: captureDate)
            let post = WorldPost(
                imageData: data,
                captureDate: captureDate,
                isOwnPost: isOwnPost,
                locationRegion: record["locationRegion"] as? String,
                roundedLatitude: record["roundedLatitude"] as? Double,
                roundedLongitude: record["roundedLongitude"] as? Double,
                caption: record["caption"] as? String,
                unlockDate: unlockDate
            )
            post.ckRecordName = recordID.recordName
            post.ckRecordChangeTag = record.recordChangeTag
            return post
        }
    }

    // MARK: - Home画面「現像中の写真の壁」用の軽量タイル

    /// 壁の1タイル分。地域・投稿時刻・代表色のみを保持し、写真本体(imageData)は
    /// 一切含まない。SwiftData @Modelではなく、その場で描画するためだけの
    /// 使い捨ての値型にしている(端末へ永続化する必要が無いデータのため)。
    struct DevelopingWallTile: Identifiable {
        let id: String
        let locationRegion: String?
        let postedAt: Date
        let colorHexes: [String]
    }

    /// Home画面「現像中の写真の壁」向けに、当日分の投稿を軽量に取得する。
    /// fetchRecentPosts(画像本体をCKAssetごとダウンロードする)とは意図的に別関数にし、
    /// desiredKeysで「地域・投稿時刻・代表色」の3フィールドだけに絞ることで、
    /// 解禁前の写真データが背景描画のためだけに端末へ届くことを防ぐ。
    static func fetchTodayDevelopingWallTiles(limit: Int = 30, calendar: Calendar = .current) async -> [DevelopingWallTile] {
        let startOfToday = calendar.startOfDay(for: Date())
        let predicate = NSPredicate(format: "postedAt >= %@", startOfToday as NSDate)
        let query = CKQuery(recordType: AppRecordType.worldPost, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "postedAt", ascending: false)]

        let desiredKeys = ["postedAt", "locationRegion", "dominantColorHexes"]
        guard let (results, _) = try? await container.publicCloudDatabase.records(
            matching: query,
            desiredKeys: desiredKeys,
            resultsLimit: limit
        ) else {
            return []
        }

        return results.compactMap { recordID, result -> DevelopingWallTile? in
            guard case .success(let record) = result else { return nil }
            let colorHexes = record["dominantColorHexes"] as? [String] ?? []
            guard !colorHexes.isEmpty else { return nil }
            return DevelopingWallTile(
                id: recordID.recordName,
                locationRegion: record["locationRegion"] as? String,
                postedAt: record["postedAt"] as? Date ?? Date(),
                colorHexes: colorHexes
            )
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

// MARK: - 投稿時の一度きりの位置取得(市区町村レベルまで丸めた座標)

/// 撮影時のCameraLocationNameProvider(表示用の地名文字列のみを持つ)とは別に、
/// 投稿の瞬間にもう一度だけ現在地を取得し、地図ピン配置用の座標を得る。
/// 小数点2桁(約1km四方)に丸めることで、正確なGPS座標は保存しない。
private final class OneShotLocationFetcher: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    func fetchRoundedCoordinate() async -> (lat: Double, lon: Double)? {
        guard let location = await fetchLocation() else { return nil }
        let coordinate = location.coordinate
        return (
            lat: (coordinate.latitude * 100).rounded() / 100,
            lon: (coordinate.longitude * 100).rounded() / 100
        )
    }

    private func fetchLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.delegate = self
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            default:
                continuation.resume(returning: nil)
                self.continuation = nil
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation?.resume(returning: locations.last)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }
}
