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
