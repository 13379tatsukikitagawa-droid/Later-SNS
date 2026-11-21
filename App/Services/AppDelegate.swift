//
//  AppDelegate.swift
//  Later 再度
//
//  グループ作成者が発行したCKShareの招待リンク(Messages/Mail/AirDropなどで共有した
//  https://www.icloud.com/share/... のURL)を別ユーザーが直接タップした際、
//  iOSはこのアプリをCloudKit共有の参加者として起動し、この委譲メソッドで
//  CKShare.Metadataを渡してくる。このアプリは単一ウィンドウ構成(明示的な
//  UIWindowSceneDelegateを持たない)ため、UIApplicationDelegate側で受け取る。

import UIKit
import CloudKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // GoogleService-Info.plistが無い間はFirebase Authenticationを安全にスキップする
        // (FirebaseConfigurator参照)。
        FirebaseConfigurator.configureIfPossible()
        // v72:通知 ・ リンクから 開いた 起動は オープニングの 短い 版
        if launchOptions?[.url] != nil || launchOptions?[.remoteNotification] != nil || launchOptions?[.shortcutItem] != nil { OpeningLaunch.short = true }

        // CKSubscription(グループの共有DB)からのサイレントプッシュを受け取るために必要。
        application.registerForRemoteNotifications()

        // 撮影通知(PhotoNotificationService)のCKQuerySubscription(ユーザーに見える
        // アラート付きPush)をフォアグラウンドでもバナー表示するため、また通知タップを
        // 拾うために必要。UNUserNotificationCenterのdelegateは1つしか持てないため、確実に起動時に
        // 生きているAppDelegate自身に持たせる。
        UNUserNotificationCenter.current().delegate = self
        // v111 §8-1:許可は 起動のたびには 聞かない。はじめて 友だち申請を 送った / 受けた 時、
        // はじめて Trip を 作った / 入った 時に、先に Lattag の シート(NotifAskSheetV111)を 出してから 聞く。
        // (上の registerForRemoteNotifications は 許可を 聞かないので 毎回 呼んで よい)

        // 期限切れ写真の片付け(第7章)。アプリを開かなくても、iOSのバックグラウンド更新の
        // タイミングで定期的に実行されるようにする(BGTaskSchedulerの要件上、起動完了前に登録する)。
        BackgroundMaintenance.register()
        BackgroundMaintenance.schedule()

        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    // 通知タップ時。撮影通知(PhotoNotificationService)は、タップした瞬間に該当
    // グループへ遷移させたいためGroupSelectionStoreを直接更新する。
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        handlePhotoNotificationTapIfNeeded(userInfo: userInfo)
        // v23:チャットの 通知(端末で 出した ローカル通知)→ その 部屋を ひらく
        if let raw = userInfo["chatGroup"] as? String, let groupID = UUID(uuidString: raw) {
            Task { @MainActor in NotificationCenter.default.post(name: .chatNotificationTapped, object: groupID) }
        }
        completionHandler()
    }

    /// 撮影通知(PhotoNotificationService)をタップした場合、desiredKeysでペイロードへ
    /// 含めておいたgroupIDStringから遷移先グループを特定する。SwiftDataへ問い合わせず
    /// ペイロードだけから解決できるため、AppDelegateはModelContextを持たなくてよい。
    private func handlePhotoNotificationTapIfNeeded(userInfo: [AnyHashable: Any]) {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKQueryNotification,
              notification.subscriptionID?.hasPrefix("photocaptured-") == true,
              let groupIDString = notification.recordFields?["groupIDString"] as? String,
              let groupID = UUID(uuidString: groupIDString) else { return }

        Task { @MainActor in
            GroupSelectionStore.shared.selectedGroupID = groupID
            NotificationCenter.default.post(name: .photoNotificationTapped, object: nil)
        }
    }

    // 後方互換のため残す。SwiftUIのシーンベースライフサイクルではiOSは基本的に
    // windowScene(_:userDidAcceptCloudKitShareWith:)(SceneDelegate側)を呼ぶため、
    // 実際の受け口はSceneDelegateに寄せている。
    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        print("[CKShare Accept] application(_:userDidAcceptCloudKitShareWith:) 受信(AppDelegate経路, 後方互換)")
        Task { @MainActor in
            ShareInviteInbox.shared.receive(cloudKitShareMetadata)
        }
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    // v108 (2):APNs の 端末トークン。Worker に 登録するのは 切りかえの スイッチが オンの とき(LaterApp)
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: "apnsTokenHex")
        if SocialFlag.useWorker { Task { await SocialClient.registerDevice(tokenHex: hex) } }
    }

    /// CKSubscriptionによるプッシュを受けて、CloudKitManagerに即座にfetchさせる。
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        // v108 (2):Worker からの 通知(`kind` つき)→ 裏で 友だちを 反映
        if SocialFlag.useWorker, userInfo["kind"] != nil {
            await FriendRequestBridgeV108.handlePush()
            return .newData
        }
        // v108 つなぎ:友だち申請の 通知 → 裏で 同期(A → B の Friendship を すぐ つくる)
        if let n = CKNotification(fromRemoteNotificationDictionary: userInfo), FriendRequestBridgeV108.isBridgeNotification(subscriptionID: n.subscriptionID) {
            await FriendRequestBridgeV108.handlePush()
            return .newData
        }
        await CloudKitManager.current?.handleRemoteNotification()
        return .newData
    }
}

extension Notification.Name {
    /// v23:チャットの 通知を タップした(object = グループの UUID)
    static let chatNotificationTapped = Notification.Name("chatNotificationTapped")
    /// 撮影通知(PhotoNotificationService)をタップした時に発行される。MainTabViewが
    /// これを監視してHomeタブへ切り替える。GroupSelectionStore.selectedGroupIDの更新は
    /// この通知より前に完了している。
    static let photoNotificationTapped = Notification.Name("photoNotificationTapped")
    /// World画面(モーダル)のボトムナビでプロフィールアイコンをタップした時に発行される。
    /// World自身はモーダルを閉じるだけで、MainTabViewがこれを監視してプロフィールタブへ
    /// 切り替える(World側からは選択中タブの状態を直接操作できないため)。
    static let switchToProfileTabRequested = Notification.Name("switchToProfileTabRequested")
}
