import Foundation

/// 「今どのグループを見ているか」をHome/投票画面/結果画面で共有するためのストア。
/// PhotoManager/VotingManager/UnlockTimeManagerと同じ「UserDefaultsで永続化された
/// Observableシングルトン」パターンに揃えている。
@MainActor
@Observable
final class GroupSelectionStore {
    static let shared = GroupSelectionStore()

    private let storageKey = "selectedGroupID"

    var selectedGroupID: UUID? {
        didSet {
            if let selectedGroupID {
                UserDefaults.standard.set(selectedGroupID.uuidString, forKey: storageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: storageKey)
            }
        }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: storageKey) {
            selectedGroupID = UUID(uuidString: raw)
        } else {
            selectedGroupID = nil
        }
    }
}
