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

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // CKSubscription(グループの共有DB)からのサイレントプッシュを受け取るために必要。
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task { @MainActor in
            ShareInviteInbox.shared.receive(cloudKitShareMetadata)
        }
    }

    /// CKSubscriptionによるプッシュを受けて、CloudKitManagerに即座にfetchさせる。
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        await CloudKitManager.current?.handleRemoteNotification()
        return .newData
    }
}
