import Foundation

/// 「今どのグループを見ているか」をHomeと各画面で共有するための、
/// UserDefaultsで永続化されたObservableシングルトン。
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
