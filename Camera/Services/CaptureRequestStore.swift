import Foundation

/// MainTabViewの撮影専用ボタンから、Homeタブ(TodayView)のカメラシートを開くための
/// 橋渡し。GroupSelectionStoreと同じ「Observableシングルトン」パターンに揃えている。
/// 実際の撮影処理(枚数上限チェック・CloudKit保存・キャプション画面遷移)はTodayView側に
/// 閉じたまま複製しない — ここは「開いて」のシグナルを送るだけの薄い仲介役。
@MainActor
@Observable
final class CaptureRequestStore {
    static let shared = CaptureRequestStore()

    var pendingRequestID: UUID?

    private init() {}
}
