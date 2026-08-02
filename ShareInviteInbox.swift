//
//  ShareInviteInbox.swift
//  Later 再度
//
//  UIKitのAppDelegateコールバック(userDidAcceptCloudKitShareWith)で受け取った
//  CKShare.Metadataを、SwiftUI/ObservableObject側(RootView)へ橋渡しするための
//  単純な受け皿。AppDelegateはSwiftUIの環境やModelContextに直接アクセスできないため、
//  この共有インスタンス経由で受け渡す。

import CloudKit
internal import Combine
import Foundation

@MainActor
final class ShareInviteInbox: ObservableObject {
    static let shared = ShareInviteInbox()

    /// 受理待ちのメタデータ。受け入れ処理が終わったらnilに戻す。
    @Published var pendingMetadata: CKShare.Metadata?

    private init() {}

    func receive(_ metadata: CKShare.Metadata) {
        pendingMetadata = metadata
    }
}
