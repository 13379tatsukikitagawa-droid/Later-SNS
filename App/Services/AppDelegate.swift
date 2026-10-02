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

        // CKSubscription(グループの共有DB)からのサイレントプッシュを受け取るために必要。
        application.registerForRemoteNotifications()

        // 撮影通知(PhotoNotificationService)のCKQuerySubscription(ユーザーに見える
        // アラート付きPush)をフォアグラウンドでもバナー表示するため、また通知タップを
        // 拾うために必要。UNUserNotificationCenterのdelegateは1つしか持てないため、確実に起動時に
        // 生きているAppDelegate自身に持たせる。
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("[Notification] requestAuthorization failed: \(error)")
            }
        }

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

    /// CKSubscriptionによるプッシュを受けて、CloudKitManagerに即座にfetchさせる。
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        await CloudKitManager.current?.handleRemoteNotification()
        return .newData
    }
}

extension Notification.Name {
    /// 撮影通知(PhotoNotificationService)をタップした時に発行される。MainTabViewが
    /// これを監視してHomeタブへ切り替える。GroupSelectionStore.selectedGroupIDの更新は
    /// この通知より前に完了している。
    static let photoNotificationTapped = Notification.Name("photoNotificationTapped")
    /// World画面(モーダル)のボトムナビでプロフィールアイコンをタップした時に発行される。
    /// World自身はモーダルを閉じるだけで、MainTabViewがこれを監視してプロフィールタブへ
    /// 切り替える(World側からは選択中タブの状態を直接操作できないため)。
    static let switchToProfileTabRequested = Notification.Name("switchToProfileTabRequested")
}
