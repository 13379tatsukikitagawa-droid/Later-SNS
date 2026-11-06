import CloudKit
import Foundation

/// v20 動画の本体(mp4)の置き場所。
/// - 撮った人の端末:撮ったときのファイルを Application Support/LaterVideos に置く(送るとき CKAsset にする)
/// - ほかの人の端末:一覧はポスター(LaterPhoto.imageData)だけ。本体はタップしたときに CloudKit から取る
/// - 7日で、ポスターと同じタイミングで消す(PhotoExpiryMaintenance)。えらんだ1つは MEPickStore に写しを持つ
nonisolated enum LaterVideoStore {
    static let maxDuration: TimeInterval = 10
    static let minDuration: TimeInterval = 1

    static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LaterVideos", isDirectory: true)
    }

    static func url(fileName: String) -> URL { folder.appendingPathComponent(fileName) }

    /// 書き出した一時ファイルを、置き場所へ移す。ファイル名を返す
    static func adopt(_ tempURL: URL, prefix: String = "") throws -> String {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = "\(prefix)\(UUID().uuidString).mp4"
        try FileManager.default.moveItem(at: tempURL, to: url(fileName: name))
        return name
    }

    /// 端末にある本体(なければ nil)
    static func localURL(for photo: LaterPhoto) -> URL? {
        guard let name = photo.videoFileName else { return nil }
        let u = url(fileName: name)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    /// v21:まだ RETRO-8 に書き出していない、もとの ふつうの映像(送らない)
    static let rawPrefix = "raw-"

    static func isRaw(_ fileName: String?) -> Bool { fileName?.hasPrefix(rawPrefix) ?? false }

    static func deleteLocal(_ fileName: String?) {
        guard let fileName else { return }
        try? FileManager.default.removeItem(at: url(fileName: fileName))
    }

    enum FetchError: Error { case notReady, missing }

    /// タップしたときに本体を取る(端末にあればそれ)。取ったファイルは置き場所に保存し、7日で消える
    @MainActor
    static func fetch(_ photo: LaterPhoto) async throws -> URL {
        if let local = localURL(for: photo) { return local }
        guard let recordID = photo.cachedRecordID, let manager = CloudKitManager.current else { throw FetchError.notReady }
        let database = recordID.zoneID.ownerName == CKCurrentUserDefaultName || recordID.zoneID.ownerName == manager.currentUserRecordName
            ? manager.container.privateCloudDatabase
            : manager.container.sharedCloudDatabase
        let results = try await database.records(for: [recordID], desiredKeys: ["video"])
        guard let record = try results[recordID]?.get(), let asset = record["video"] as? CKAsset, let file = asset.fileURL else { throw FetchError.missing }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = "\(photo.ckRecordName ?? photo.id.uuidString).mp4"
        let target = url(fileName: name)
        try? FileManager.default.removeItem(at: target)
        try FileManager.default.copyItem(at: file, to: target)
        photo.videoFileName = name
        return target
    }
}
