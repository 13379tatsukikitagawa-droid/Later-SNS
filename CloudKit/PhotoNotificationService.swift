import CloudKit
import Foundation

/// グループメンバーが写真を撮影した際に、他のメンバーへAlert形式のプッシュ通知を
/// 届けるためのCKQuerySubscription登録(Public DBではなくPrivate/Shared DB向け)。
///
/// LaterPhotoは各グループ専用のカスタムゾーン内にあり、そのゾーンは常にグループの
/// ホストが所有する。そのため、
/// - 自分がホストのグループの写真は自分のPrivate DBで作成される
/// - 自分がメンバー(非ホスト)のグループの写真はホストのゾーン、つまり自分のShared DBに
///   反映される
/// という違いがあり、両方のデータベースにそれぞれ1件ずつサブスクリプションを
/// 登録する必要がある(ゾーンを問わずデータベース全体が対象になるため、
/// 参加している全グループを一括でカバーできる)。
///
/// MEグループ(isPersonalSpace)は他ユーザーと共有されないため、この仕組みだけで
/// 自然に通知対象から除外される(自分以外の誰かのShared/Private DBに現れることが無い)。
enum PhotoNotificationService {
    private static func subscriptionID(for userRecordName: String, suffix: String) -> String {
        "photocaptured-\(suffix)-\(userRecordName)"
    }

    /// 自分以外が撮影した写真の作成をトリガーに、Alert通知を発火するサブスクリプションを
    /// Private DB・Shared DBの両方に登録する。同じsubscriptionIDで上書き保存されるだけなので、
    /// アプリ起動のたびに呼んでも重複登録にはならない。
    static func setupNotificationSubscriptions(for userRecordName: String, container: CKContainer) async {
        let predicate = NSPredicate(format: "authorCloudKitUserRecordName != %@", userRecordName)

        let info = CKSubscription.NotificationInfo()
        info.titleLocalizationKey = "photo_captured_title"
        info.titleLocalizationArgs = ["groupNameCache"]
        info.alertLocalizationKey = "photo_captured_body"
        info.alertLocalizationArgs = ["authorNameCache"]
        info.shouldBadge = true
        info.soundName = "default"
        // タップ時にどのグループへ遷移すべきかを、SwiftDataへ問い合わせずプッシュ
        // ペイロードだけから解決できるよう、groupIDString(LaterPhoto.groupIDの文字列複製)を
        // 明示的にペイロードへ含める。
        info.desiredKeys = ["groupIDString"]

        let targets: [(database: CKDatabase, suffix: String)] = [
            (container.privateCloudDatabase, "private"),
            (container.sharedCloudDatabase, "shared")
        ]

        for target in targets {
            let subscription = CKQuerySubscription(
                recordType: AppRecordType.laterPhoto,
                predicate: predicate,
                subscriptionID: subscriptionID(for: userRecordName, suffix: target.suffix),
                options: [.firesOnRecordCreation]
            )
            subscription.notificationInfo = info

            do {
                _ = try await target.database.modifySubscriptions(saving: [subscription], deleting: [])
            } catch {
                print("[GroupSync] PhotoNotificationService setupNotificationSubscriptions failed (\(target.suffix)): \(error)")
            }
        }
    }
}
