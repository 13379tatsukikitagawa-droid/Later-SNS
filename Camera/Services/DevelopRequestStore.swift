import Foundation

/// ライブパネルの「develop」から、Homeタブ(TodayView)の現像シートを開くための橋渡し。
/// CaptureRequestStoreと同じ「Observableシングルトン」パターン。
@MainActor
@Observable
final class DevelopRequestStore {
    static let shared = DevelopRequestStore()

    var pendingRequestID: UUID?
    private(set) var startIndex = 0

    private init() {}

    func request(startIndex: Int = 0) {
        self.startIndex = startIndex
        pendingRequestID = UUID()
    }
}
