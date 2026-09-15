import Foundation
import SwiftData

/// 自分がブロックしたユーザーのローカルな記録。CloudKit(Private DB、Blockレコード)を
/// 正として、起動時にModerationService.refreshBlockedUsersIfNeededで同期する。
/// Circle/World Laterの一覧表示側は、CloudKitへ都度問い合わせずこのローカルモデルだけを
/// 見てブロック済みユーザーの投稿を除外できる。
@Model
final class BlockedUser {
    @Attribute(.unique) var blockedCloudKitUserRecordName: String
    var createdAt: Date
    /// このBlockレコード自体のCKRecord.recordName(削除=ブロック解除の際に必要)。
    var ckRecordName: String?

    init(blockedCloudKitUserRecordName: String, createdAt: Date = Date(), ckRecordName: String? = nil) {
        self.blockedCloudKitUserRecordName = blockedCloudKitUserRecordName
        self.createdAt = createdAt
        self.ckRecordName = ckRecordName
    }
}
