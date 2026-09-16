import Foundation

/// JoinGroupByLinkView(招待リンク貼り付け画面)から、LaterApp(RootView)の既存の
/// handleGroupJoinLink(shareURL:)へリンクを橋渡しするためのストア。CaptureRequestStore/
/// GroupSelectionStoreと同じ「Observableシングルトン」パターンに揃えている。
/// CloudKit連携ロジック(CKShare.Metadataの解決〜受諾)自体はRootView側の既存実装を
/// そのまま再利用し、ここでは「貼り付けられたURL」を渡すだけの薄い仲介役にする。
@MainActor
@Observable
final class GroupJoinRequestStore {
    static let shared = GroupJoinRequestStore()

    var pendingURL: URL?

    private init() {}
}
