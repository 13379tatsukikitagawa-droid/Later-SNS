import CloudKit
import Foundation
import SwiftData
import UIKit
#if canImport(SensitiveContentAnalysis)
import SensitiveContentAnalysis
#endif

/// Mondo の公開・取り下げ・取得・通報・ブロック。保存先は CloudKit の Public DB。
///
/// 公開レコード(MondoPhoto)は撮った本人が作る。どれを見せるかは、サーバ(server/mondo-worker)が
/// 画像審査のあとで作る MondoDay(承認した写真の一覧と集計)だけで決める。公開レコードの中の値は
/// 本人が書きかえられるため、「承認ずみ」の印として信用しない。
@MainActor
final class MondoService {
    static let shared = MondoService()

    static let publicKey = "mondoPublic"

    /// 自分の1枚を Mondo に出すか(初期値はオフ)
    static var isPublic: Bool {
        get { UserDefaults.standard.object(forKey: publicKey) as? Bool ?? MondoConfig.publicByDefault }
        set { UserDefaults.standard.set(newValue, forKey: publicKey) }
    }

    private var database: CKDatabase {
        CKContainer(identifier: CloudKitManager.containerIdentifier).publicCloudDatabase
    }

    enum PublishResult: Equatable {
        case published
        case off
        /// 不適切の可能性が高い(グループにだけ届く)
        case notAllowed
        case failed
    }

    enum FetchError: Error {
        /// サーバ(画像審査)がまだない・その日の MondoDay がまだできていない
        case notReady
        case network
    }

    // MARK: - 公開

    /// 撮った1枚を、設定がオンなら Mondo に出す。画像は縮小して Exif を落とし、場所は国・地域だけ。
    /// photoID を渡すと、送れなかったときに再送のキューに残す
    func publishIfEnabled(imageData: Data, captureDate: Date, tags: [String], name: String, photoID: UUID? = nil) async -> PublishResult {
        MondoLog.write("start env=\(MondoLog.environment)")
        guard Self.isPublic else {
            MondoLog.write("skipped(reason=mondoPublicOff)")
            return .off
        }
        if await isLikelySensitive(imageData) {
            MondoLog.write("skipped(reason=sensitive)")
            return .notAllowed
        }
        guard let image = MondoImageSanitizer.sanitizedJPEG(from: imageData, maxDimension: MondoConfig.imageMaxDimension),
              let thumb = MondoImageSanitizer.sanitizedJPEG(from: imageData, maxDimension: MondoConfig.thumbMaxDimension, quality: 0.7)
        else {
            MondoLog.write("error(code=sanitizeFailed)")
            return .failed
        }

        let dayKey = MondoWindow.dayKey(for: captureDate)
        let mondoID = MondoIdentity.id
        let recordName = MondoIdentity.recordName(mondoID: mondoID, dayKey: dayKey)
        let record = CKRecord(recordType: MondoConfig.photoRecordType, recordID: CKRecord.ID(recordName: recordName))
        record["mondoID"] = mondoID
        record["name"] = String(name.prefix(24))
        record["dayKey"] = dayKey
        record["tags"] = MondoTags.publishable(tags)
        record["toneHex"] = MondoImageSanitizer.averageColorHex(thumb)
        if let place = MondoPlaceCache.latest {
            record["countryCode"] = place.countryCode
            record["countryName"] = place.countryName
            record["region"] = place.region
        }
        do {
            record["image"] = try Self.asset(image)
            record["thumb"] = try Self.asset(thumb)
            let (results, _) = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
            if case .failure(let error)? = results[record.recordID] { throw error }
            MondoLocalStore.addPublished(recordName)
            if let photoID { MondoPublishQueue.remove(photoID.uuidString) }
            MondoLog.write("ok(recordType=\(MondoConfig.photoRecordType) window=\(dayKey))")
            return .published
        } catch {
            let ck = error as? CKError
            MondoLog.write("error(code=\(ck.map { String($0.code.rawValue) } ?? "-"), detail=\(String(describing: ck?.localizedDescription ?? "\(error)").prefix(160)))")
            // 通信・一時的な失敗は、あとで送りなおす(スキーマの不足などは、送りなおしても同じなので記録だけ)
            if let photoID, ck.map(Self.isRetryable) ?? true { MondoPublishQueue.add(photoID) }
            return .failed
        }
    }

    private static func isRetryable(_ error: CKError) -> Bool {
        [.networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy, .notAuthenticated, .partialFailure, .internalError].contains(error.code)
    }

    /// 送れなかった公開を、もう一度送る(アプリを開いたとき・投稿のあと)。まだ「昨日」として見える窓のぶんだけ
    func retryPending(context: ModelContext, now: Date = Date()) async {
        let pending = MondoPublishQueue.pending
        guard !pending.isEmpty, Self.isPublic else { return }
        let oldest = MondoWindow.dayKey(for: now.addingTimeInterval(-24 * 3600))
        let photos = (try? context.fetch(FetchDescriptor<LaterPhoto>())) ?? []
        for id in pending {
            guard let photo = photos.first(where: { $0.id.uuidString == id }), photo.isPosted,
                  MondoWindow.dayKey(for: photo.captureDate) >= oldest else {
                MondoPublishQueue.remove(id)
                continue
            }
            let name = UserProfile.current(from: (try? context.fetch(FetchDescriptor<UserProfile>())) ?? [])?.name ?? ""
            _ = await publishIfEnabled(imageData: photo.imageData, captureDate: photo.captureDate, tags: photo.tags, name: name, photoID: photo.id)
        }
    }

    /// 端末側の SensitiveContentAnalysis(使える設定・端末のときだけ)。使えない時は false(サーバの審査に任せる)。
    private func isLikelySensitive(_ data: Data) async -> Bool {
        #if canImport(SensitiveContentAnalysis)
        guard MondoConfig.usesSensitiveContentAnalysis else { return false }
        let analyzer = SCSensitivityAnalyzer()
        guard analyzer.analysisPolicy != .disabled, let cg = UIImage(data: data)?.cgImage else { return false }
        return (try? await analyzer.analyzeImage(cg).isSensitive) ?? false
        #else
        return false
        #endif
    }

    private static func asset(_ data: Data) throws -> CKAsset {
        let url = CKAssetTempFiles.newURL()
        try data.write(to: url)
        return CKAsset(fileURL: url)
    }

    // MARK: - 取り下げ

    /// 公開した自分の分を、すべて消す(「Mondo に出す」をオフにした時)
    func withdrawAll() async {
        let names = MondoLocalStore.published
        MondoLog.delete(kind: "optOut", count: names.count)
        guard !names.isEmpty else { return }
        await withdraw(names)
    }

    func withdraw(_ recordNames: [String]) async {
        let ids = recordNames.map { CKRecord.ID(recordName: $0) }
        do {
            _ = try await database.modifyRecords(saving: [], deleting: ids)
            MondoLocalStore.removePublished(recordNames)
        } catch {
            // すでに消えているものは、記録から外す
            if let ck = error as? CKError, ck.code == .partialFailure || ck.code == .unknownItem {
                MondoLocalStore.removePublished(recordNames)
            }
            print("[Mondo] 取り下げに失敗: \(error)")
        }
    }

    /// 公開から48時間を過ぎた自分の分を消す(サーバの削除の保険)
    func pruneOwnExpired(now: Date = Date()) async {
        let calendar = Calendar.current
        let expired = MondoLocalStore.published.filter { name in
            guard let key = name.split(separator: "_").last,
                  let day = Self.dayFormatter.date(from: String(key)) else { return false }
            let published = calendar.date(byAdding: .hour, value: DailyExposureRules.openingHour, to: day) ?? day
            return now.timeIntervalSince(published) > MondoConfig.retention + 15 * 3600
        }
        MondoLog.delete(kind: "expire", count: expired.count)
        if !expired.isEmpty { await withdraw(expired) }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - 取得

    /// 昨日の Mondo。サーバの MondoDay(承認した写真)を読む。開発用の設定の時だけ、端末側で集計する。
    func fetchDay(dayKey: String, blocked: Set<String>) async throws -> MondoDaySummary {
        MondoImageCache.shared.keepOnly(dayKey: dayKey)
        let hidden = MondoLocalStore.hidden
        let myID = MondoIdentity.id
        if MondoConfig.requiresServerApproval {
            return try await fetchApprovedDay(dayKey: dayKey, hidden: hidden, blocked: blocked, myID: myID)
        }
        // 開発用(デバッグビルドのみ):審査なしで、昨日の公開レコードを直接読む(案A)
        let query = CKQuery(recordType: MondoConfig.photoRecordType, predicate: NSPredicate(format: "dayKey == %@", dayKey))
        do {
            let (results, _) = try await database.records(matching: query, desiredKeys: Self.textKeys, resultsLimit: 200)
            let entries = results.compactMap { _, result in (try? result.get()).flatMap { Self.entry(from: $0, myID: myID) } }
            MondoLog.read("window=\(dayKey) env=\(MondoLog.environment) predicate=dayKey==\(dayKey) count=\(entries.count) error=-")
            let summary = MondoAggregator.summarize(entries, dayKey: dayKey, hidden: hidden, blocked: blocked)
            MondoLog.filter(before: entries.count, after: summary.entries.count, removedBy: "hidden|blocked")
            return summary
        } catch {
            MondoLog.read("window=\(dayKey) env=\(MondoLog.environment) predicate=dayKey==\(dayKey) count=0 error=\((error as? CKError).map { String($0.code.rawValue) } ?? "\(error)")")
            throw FetchError.network
        }
    }

    private func fetchApprovedDay(dayKey: String, hidden: Set<String>, blocked: Set<String>, myID: String) async throws -> MondoDaySummary {
        let dayRecord: CKRecord
        do {
            dayRecord = try await database.record(for: CKRecord.ID(recordName: "mondoday_\(dayKey)"))
        } catch let error as CKError where error.code == .unknownItem {
            MondoLog.read("window=\(dayKey) env=\(MondoLog.environment) predicate=recordName==mondoday_\(dayKey) count=0 error=notReady(MondoDay なし)")
            throw FetchError.notReady
        } catch {
            MondoLog.read("window=\(dayKey) env=\(MondoLog.environment) predicate=recordName==mondoday_\(dayKey) count=0 error=\((error as? CKError).map { String($0.code.rawValue) } ?? "\(error)")")
            throw FetchError.network
        }
        let allNames = dayRecord["photoNames"] as? [String] ?? []
        let names = allNames.filter { !hidden.contains($0) }
        MondoLog.read("window=\(dayKey) env=\(MondoLog.environment) predicate=recordName==mondoday_\(dayKey) count=\(allNames.count) error=-")
        let wanted = Array(names.prefix(120))
        var entries: [MondoEntry] = []
        if !wanted.isEmpty {
            do {
                let results = try await database.records(for: wanted.map { CKRecord.ID(recordName: $0) }, desiredKeys: Self.textKeys)
                let byName = results.compactMapValues { try? $0.get() }
                entries = wanted.compactMap { name in byName[CKRecord.ID(recordName: name)].flatMap { Self.entry(from: $0, myID: myID) } }
            } catch {
                throw FetchError.network
            }
        }
        let before = entries.count
        entries = entries.filter { !blocked.contains($0.mondoID) && $0.dayKey == dayKey }
        MondoLog.filter(before: allNames.count, after: entries.count, removedBy: "hidden=\(allNames.count - names.count) blockedOrOtherDay=\(before - entries.count)")
        let tags = dayRecord["topTags"] as? [String] ?? []
        let counts = dayRecord["topTagCounts"] as? [Int] ?? []
        return MondoDaySummary(
            dayKey: dayKey,
            entries: entries,
            lightCount: dayRecord["lightCount"] as? Int ?? entries.count,
            countryCount: dayRecord["countryCount"] as? Int ?? Set(entries.compactMap { $0.place?.countryCode }).count,
            topTags: zip(tags, counts).prefix(MondoConfig.maxBubbles).map { (tag: $0.0, count: $0.1) }
        )
    }

    private static let textKeys = ["mondoID", "name", "dayKey", "tags", "toneHex", "countryCode", "countryName", "region"]

    private static func entry(from record: CKRecord, myID: String) -> MondoEntry? {
        guard let mondoID = record["mondoID"] as? String, let dayKey = record["dayKey"] as? String else { return nil }
        let place = (record["countryCode"] as? String).map {
            MondoPlace(countryCode: $0, countryName: record["countryName"] as? String ?? $0, region: record["region"] as? String)
        }
        return MondoEntry(
            id: record.recordID.recordName,
            mondoID: mondoID,
            name: record["name"] as? String ?? "だれか",
            place: place,
            tags: MondoTags.publishable(record["tags"] as? [String] ?? []),
            dayKey: dayKey,
            toneHex: record["toneHex"] as? String,
            isMine: mondoID == myID
        )
    }

    // MARK: - 画像(サムネイル → 大きい画像の2段階)

    func thumbnail(for entry: MondoEntry) async -> UIImage? {
        await image(for: entry, key: "thumb")
    }

    func fullImage(for entry: MondoEntry) async -> UIImage? {
        await image(for: entry, key: "image")
    }

    private func image(for entry: MondoEntry, key: String) async -> UIImage? {
        let cache = MondoImageCache.shared
        if let hit = cache.image(recordName: entry.id, kind: key, dayKey: entry.dayKey) { return hit }
        guard let record = try? await database.records(for: [CKRecord.ID(recordName: entry.id)], desiredKeys: [key])[CKRecord.ID(recordName: entry.id)]?.get(),
              let asset = record[key] as? CKAsset, let url = asset.fileURL, let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        cache.store(data, image: image, recordName: entry.id, kind: key, dayKey: entry.dayKey)
        return image
    }

    // MARK: - 通報・ブロック

    /// この写真を報告する。その人の端末ではすぐ見えなくなる。複数の報告で自動で保留(サーバ)。
    func report(_ entry: MondoEntry) async {
        MondoLocalStore.hide(entry.id)
        try? await ModerationService.submitReport(
            targetType: .mondoPhoto,
            targetID: entry.id,
            reason: .inappropriate,
            detail: "",
            reporterCloudKitUserRecordName: CloudKitManager.current?.currentUserRecordName
        )
    }

    /// この人を見えなくする(Private DB に保存して、端末をまたいで同期)
    func block(_ entry: MondoEntry, modelContext: ModelContext) async {
        _ = try? await ModerationService.blockUser(
            cloudKitUserRecordName: Self.blockKey(entry.mondoID),
            displayName: entry.name,
            modelContext: modelContext
        )
    }

    /// BlockedUser に入れる、Mondo の人の印(グループのブロックと同じ一覧で管理する)
    static func blockKey(_ mondoID: String) -> String { "mondo:\(mondoID)" }

    static func blockedMondoIDs(_ blocked: [BlockedUser]) -> Set<String> {
        Set(blocked.map(\.blockedCloudKitUserRecordName).filter { $0.hasPrefix("mondo:") }.map { String($0.dropFirst(6)) })
    }
}

// MARK: - 画像のキャッシュ(メモリ + ディスク。窓が変わったら破棄)

final class MondoImageCache: @unchecked Sendable {
    static let shared = MondoImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private let root: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("mondo", isDirectory: true)
    }()

    private func url(recordName: String, kind: String, dayKey: String) -> URL {
        root.appendingPathComponent(dayKey, isDirectory: true).appendingPathComponent("\(recordName)_\(kind).jpg")
    }

    func image(recordName: String, kind: String, dayKey: String) -> UIImage? {
        let key = "\(recordName)_\(kind)" as NSString
        if let hit = memory.object(forKey: key) { return hit }
        guard let data = try? Data(contentsOf: url(recordName: recordName, kind: kind, dayKey: dayKey)), let image = UIImage(data: data) else { return nil }
        memory.setObject(image, forKey: key)
        return image
    }

    func store(_ data: Data, image: UIImage, recordName: String, kind: String, dayKey: String) {
        memory.setObject(image, forKey: "\(recordName)_\(kind)" as NSString)
        let file = url(recordName: recordName, kind: kind, dayKey: dayKey)
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: file)
    }

    /// その日のぶんだけ残す(窓が変わったら破棄)
    func keepOnly(dayKey: String) {
        guard let days = try? FileManager.default.contentsOfDirectory(atPath: root.path) else { return }
        for day in days where day != dayKey {
            try? FileManager.default.removeItem(at: root.appendingPathComponent(day))
        }
    }
}

// MARK: - 世界の光(昨日、Mondo に公開された写真の数)

/// 昨日の窓に Mondo に公開され、審査を通った写真の数(MondoDay.lightCount)。
/// Home の光の球・Mondo トップの見出し・Mondo のビューアの枚数は、ここだけを読む(別々に計算しない)。
/// 「昨日」の数なので、取得できたら、その日の窓の間はキャッシュする(開くたびに取りに行かない)。
@MainActor
@Observable
final class WorldCountStore {
    static let shared = WorldCountStore()

    private struct Cached: Codable {
        let dayKey: String
        let count: Int
        let countryCount: Int
    }

    private static let key = "worldLightCount"

    /// いま出す数(nil なら一度も取得できていない)
    private(set) var count: Int?
    private(set) var countryCount: Int?
    /// 出している数が、どの日(dayKey)のものか
    private(set) var dayKey: String?

    @ObservationIgnored private var inFlight = false
    /// 取れなかったときは、10分おきにだけ取りなおす(集計の更新前・通信できないとき)
    @ObservationIgnored private var lastAttempt: Date?
    static let retryInterval: TimeInterval = 600

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let cached = try? JSONDecoder().decode(Cached.self, from: data) {
            count = cached.count
            countryCount = cached.countryCount
            dayKey = cached.dayKey
        }
    }

    /// 昨日の数を取りに行く。すでに昨日の数を持っていれば何もしない。
    /// 集計の更新前(9:00〜9:10)・通信できないときは、最後に取得した数をそのまま出す(空にしない)。
    func refreshIfNeeded(now: Date, blocked: Set<String> = []) async {
        let yesterday = MondoWindow.yesterdayKey(now: now)
        guard dayKey != yesterday, !inFlight else { return }
        if let lastAttempt, now.timeIntervalSince(lastAttempt) < Self.retryInterval, lastAttempt <= now { return }
        lastAttempt = now
        inFlight = true
        defer { inFlight = false }
        if let summary = try? await MondoService.shared.fetchDay(dayKey: yesterday, blocked: blocked) {
            record(summary)
        }
    }

    /// Mondo トップが取得した集計を、そのまま共有する(同じ値にそろえる)
    func record(_ summary: MondoDaySummary) {
        count = summary.lightCount
        countryCount = summary.countryCount
        dayKey = summary.dayKey
        let cached = Cached(dayKey: summary.dayKey, count: summary.lightCount, countryCount: summary.countryCount)
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    /// Home の光の球に出す値
    var light: YesterdayLight {
        count.map { .count($0) } ?? .loading
    }
}
