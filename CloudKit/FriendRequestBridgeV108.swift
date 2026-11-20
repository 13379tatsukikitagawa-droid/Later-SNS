import CloudKit
import Foundation
import SwiftData

/// v108 つなぎ:Cloudflare の Worker(social-worker)が できるまでの 間、CloudKit だけで
/// 「申請が とどいた / 承認された」通知と、おたがいの 申請の 自動 相互を 動かす。
/// Worker に つなぎかえる 時に、この ファイルと 呼び出し(v108 つなぎ)を 消す。
enum FriendRequestBridgeV108 {
    static let incomingPrefix = "friendreq-in-"
    static let acceptedPrefix = "friendreq-ok-"

    // MARK: 純粋な 決まり(テストできる)

    /// おたがいに 申請 して いる 相手(自分あての 申請の 送り主の うち、自分も 申請を 出して いる 人)
    static func crossedTargets(myRequests: [FriendRequests.Request], incoming: [FriendRequests.Request], me: String) -> [FriendRequests.Request] {
        let mine = Set(myRequests.filter { $0.fromUserID == me }.map(\.toUserID))
        return incoming.filter { $0.toUserID == me && mine.contains($0.fromUserID) }
    }

    static func isBridgeNotification(subscriptionID: String?) -> Bool {
        guard let id = subscriptionID else { return false }
        return id.hasPrefix(incomingPrefix) || id.hasPrefix(acceptedPrefix)
    }

    // MARK: 通知の 登録(公開DB ・ 起動の たびに 上書き)

    /// 文に 名前は 入れない(公開DB の ため)。`shouldSendContentAvailable` で 裏でも 同期を 走らせる
    static func setupSubscriptions(for me: String, container: CKContainer) async {
        let db = container.publicCloudDatabase

        let reqInfo = CKSubscription.NotificationInfo()
        reqInfo.alertBody = "友だち申請が とどきました"
        reqInfo.soundName = "default"
        reqInfo.shouldSendContentAvailable = true
        let req = CKQuerySubscription(recordType: FriendRequests.requestType,
                                      predicate: NSPredicate(format: "toUserID == %@", me),
                                      subscriptionID: incomingPrefix + me,
                                      options: [.firesOnRecordCreation, .firesOnRecordUpdate])
        req.notificationInfo = reqInfo

        let okInfo = CKSubscription.NotificationInfo()
        okInfo.alertBody = "友だち申請が 承認されました"
        okInfo.soundName = "default"
        okInfo.shouldSendContentAvailable = true
        let ok = CKQuerySubscription(recordType: FriendRequests.responseType,
                                     predicate: NSPredicate(format: "requesterID == %@ AND decision == %@", me, "accepted"),
                                     subscriptionID: acceptedPrefix + me,
                                     options: [.firesOnRecordCreation, .firesOnRecordUpdate])
        ok.notificationInfo = okInfo

        do { _ = try await db.modifySubscriptions(saving: [req, ok], deleting: []) }
        catch { print("[FriendBridge] subscription failed: \(error)") }
    }

    /// 通知が とどいた 時(裏でも):承認された 返事から 自分 → 相手の 友だちを つくり、おたがいの 申請も 相互に する
    @MainActor static func handlePush() async {
        let context = LaterApp.sharedModelContainer.mainContext
        let profiles = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        let name = UserProfile.current(from: profiles)?.name ?? ""
        await FriendRequests.syncAccepted(myName: name)
    }
}
