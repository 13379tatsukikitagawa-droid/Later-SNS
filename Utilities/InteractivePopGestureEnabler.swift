import SwiftUI
import UIKit

/// `.navigationBarHidden(true)` + カスタム戻るボタン(chevron等)の組み合わせは、
/// SwiftUIのNavigationStack上でも標準の左端エッジスワイプ(interactivePopGestureRecognizer)
/// を暗黙的に無効化してしまうことがある(ナビゲーションバーが無い=システム標準の
/// 戻るボタンも無い、とUIKit側が判断し、ジェスチャーの有効化を紐づけている挙動に由来する)。
/// このビューを`.background(...)`として差し込むと、実際のUIViewControllerを介して
/// 所属するUINavigationControllerのinteractivePopGestureRecognizerを直接有効化し、
/// デリゲートもnilにして「戻れる場合は常にスワイプ可能」に固定する。
private struct InteractivePopGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // .background()として挿入した時点ではまだ親のUINavigationControllerに
        // 接続されていないことがあるため、次のRunLoopで確実に反映させる。
        DispatchQueue.main.async {
            guard let navigationController = uiViewController.navigationController else { return }
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}

extension View {
    /// カスタムヘッダー(`.navigationBarHidden(true)`+独自の戻るボタン)を持つ
    /// プッシュ遷移先の画面に付ける。左端からのエッジスワイプで前の画面へ戻れるようにする。
    /// ルート画面(NavigationStackの先頭、タブのトップ画面など)には付ける必要はない
    /// (戻り先が無いため、たとえ有効化しても何も起きない)。
    func enableInteractivePopGesture() -> some View {
        background(InteractivePopGestureEnabler())
    }
}
