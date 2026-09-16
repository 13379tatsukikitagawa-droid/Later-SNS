import Foundation

/// 下部ナビゲーションの独立したHomeボタン(MainTabView)から、TodayView内部の
/// NavigationPathを空にする(グループ詳細等から一気にHomeのルートへ戻る)ための
/// 橋渡し。CaptureRequestStoreと同じ「Observableシングルトン」パターンに揃えている。
@MainActor
@Observable
final class HomeNavigationStore {
    static let shared = HomeNavigationStore()

    var popToRootRequestID: UUID?

    private init() {}
}
