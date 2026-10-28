//
//  SceneDelegate.swift
//  Later 再度
//
//  windowScene(_:userDidAcceptCloudKitShareWith:)は、シーンベースのUIWindowSceneDelegate
//  に対してiOSがCKShare招待の受け入れ時に呼び出すコールバック。
//  AppDelegate.application(_:userDidAcceptCloudKitShareWith:)とは別経路のため、
//  こちらも同じ受け口(ShareInviteInbox)へ委譲する。

import UIKit
import CloudKit

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    /// 通知から起動した時は、起動アニメーションを morning ではなく normal にする。
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if connectionOptions.notificationResponse != nil {
            MainActor.assumeIsolated { LaunchCoordinator.launchedFromNotification = true }
        }
    }

    /// 起動画面からHomeへのつなぎ目で白がちらつかないよう、ウィンドウの背景も黒にする。
    func sceneWillEnterForeground(_ scene: UIScene) {
        Self.paintAppWindowsBlack(in: scene)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        Self.paintAppWindowsBlack(in: scene)
    }

    /// 黒くするのはアプリ本体のウィンドウだけ。キーボード・編集メニューの入るシステムのウィンドウ
    /// (UITextEffectsWindow など。アプリの画面より上にある)まで黒くすると、キーボードを出したまま
    /// 別のアプリから戻った時に、画面全体が黒でおおわれてしまう。
    static func paintAppWindowsBlack(in scene: UIScene) {
        (scene as? UIWindowScene)?.windows
            .filter { isAppWindow($0) }
            .forEach { $0.backgroundColor = .black }
    }

    static func isAppWindow(_ window: UIWindow) -> Bool {
        guard window.windowLevel == .normal else { return false }
        if let textEffects = NSClassFromString("UITextEffectsWindow"), window.isKind(of: textEffects) { return false }
        return true
    }

    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        print("""
        [CKShare Accept] windowScene(_:userDidAcceptCloudKitShareWith:) 受信(SceneDelegate経路)
          containerIdentifier = \(cloudKitShareMetadata.containerIdentifier)
          rootRecordID = \(String(describing: cloudKitShareMetadata.hierarchicalRootRecordID))
          share.url = \(cloudKitShareMetadata.share.url?.absoluteString ?? "nil")
        """)
        Task { @MainActor in
            ShareInviteInbox.shared.receive(cloudKitShareMetadata)
        }
    }
}
