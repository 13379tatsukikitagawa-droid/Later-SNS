import SwiftUI
internal import Combine

/// MainTabViewの下部タブバー(CustomBottomBar)は画面全体の最前面に固定表示される
/// 構成のため、Homeタブ内のNavigationStackでさらに奥へ遷移した画面が自前の入力欄を
/// 画面最下部に置いても、タブバーがその上に重なって隠してしまう可能性がある。
/// タブバーを隠したい画面がisHiddenをtrueにし、MainTabView側がそれを見て
/// 表示/非表示を切り替える(現在この仕組みを使う画面は無い)。
@MainActor
final class TabBarVisibilityStore: ObservableObject {
    static let shared = TabBarVisibilityStore()

    @Published var isHidden = false

    private init() {}
}
