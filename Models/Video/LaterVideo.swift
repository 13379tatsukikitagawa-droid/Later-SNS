//
//  LaterVideo.swift
//  Later 再度
//
//  動画専用のデータモデル(10秒・VGA画質)。LaterPhotoと構造は近いが、
//  動画本体(mp4バイト列)は端末に永続保持しない。常時ローカルに持つのは
//  サムネイル(thumbnailData)だけで、動画本体はタップ時にCloudKitManager経由で
//  都度フェッチし、再生後は破棄する(CloudKitManager.fetchVideoAsset(for:)参照)。
//  これにより、写真で起きたようなDocuments & Dataの肥大化を動画では避ける。

import Foundation
import SwiftData

@Model
final class LaterVideo {
    @Attribute(.unique) var id: UUID = UUID()
    @Attribute(.externalStorage) var thumbnailData: Data
    var durationSeconds: Double = 0
    var captureDate: Date
    var unlockDate: Date
    /// 写真の「ブラインド解禁」タイミングだけを共有する(evaluateGroupUnlockConditions参照)。
    /// 写真の投票による絞り込み(PhotoVisibilityPolicy)には参加しない — 解禁後は
    /// 保持期間(7日)内、常にグループ全員へ表示される。
    var isUnlocked: Bool = false
    var caption: String?
    var locationName: String?

    // 撮影者(所有者)
    @Relationship
    var owner: UserProfile?
    /// ownerのCloudKit識別子。LaterPhoto.authorCloudKitUserRecordNameと同じ理由で持つ。
    var authorCloudKitUserRecordName: String?
    var authorNameCache: String?
    var groupID: UUID?
    var groupNameCache: String?

    // CloudKit同期メタデータ
    var ckRecordName: String?
    var ckZoneName: String?
    var ckZoneOwnerName: String?
    var ckRecordChangeTag: String?
    /// 動画本体(CKAsset)が少なくとも一度はCloudKitへの保存に成功したか。
    /// trueになった時点でlocalFilePathのファイルは不要になるため削除する
    /// (CloudKitManager.markSynced参照)。
    var isVideoUploaded: Bool = false
    /// 撮影直後、アップロードが完了するまでの間だけ動画ファイルを指す一時的なローカルパス。
    /// アップロード確認後はファイルごと削除しnilに戻す(動画本体を端末に残さない設計の要)。
    var localFilePath: String?

    /// サムネイル画像キャッシュ(PhotoImageCache)用の安定したキー
    /// (LaterPhoto.imageCacheKeyと同じ理由)。
    var imageCacheKey: String { ckRecordName ?? id.uuidString }

    init(
        id: UUID = UUID(),
        thumbnailData: Data,
        durationSeconds: Double,
        captureDate: Date = Date(),
        unlockDate: Date,
        owner: UserProfile? = nil,
        caption: String? = nil
    ) {
        self.id = id
        self.thumbnailData = thumbnailData
        self.durationSeconds = durationSeconds
        self.captureDate = captureDate
        self.unlockDate = unlockDate
        self.owner = owner
        self.caption = caption
    }
}
