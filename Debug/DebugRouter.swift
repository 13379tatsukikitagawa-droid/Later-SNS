#if DEBUG
import SwiftUI
import UIKit

/// DEBUG だけ:`lattag://debug/<名前>?t=<秒>` で 画面を 直接 出す(シミュレータで スクショを 撮って 見本と 比べる ため)。
/// 例:`xcrun simctl openurl booted "lattag://debug/opening?t=2.0"` / `lattag://debug/hide`
@MainActor
enum DebugRouter {
    private static weak var host: UIViewController?

    /// 処理したら true
    static func handle(_ url: URL) -> Bool {
        guard Brand.isOurScheme(url), url.host == "debug" else { return false }
        let name = url.lastPathComponent
        let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let t = q.first(where: { $0.name == "t" })?.value.flatMap(Double.init)
        switch name {
        case "hide": hide()
        case "opening": show(OpeningV21View(variant: .full, start: Date(), onFinish: { hide() })); OpeningDebug.frozenT = t
        default: return false
        }
        return true
    }

    /// 起動引数:`simctl launch booted <BID> -debugRoute opening -debugT 2.0`(確認ダイアログが 出る URL の かわり)
    static func runLaunchRoute() {
        let d = UserDefaults.standard
        guard let route = d.string(forKey: "debugRoute") else { return }
        var comps = URLComponents(string: "lattag://debug/\(route)")!
        if d.object(forKey: "debugT") != nil { comps.queryItems = [URLQueryItem(name: "t", value: String(d.double(forKey: "debugT")))] }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { _ = handle(comps.url!) }
    }

    /// 状態メニューの「オープニングを もう一度」:今の 画面の 上で 最初から(おわったら 取りのぞく)
    static func playOpening() {
        OpeningDebug.frozenT = nil
        show(OpeningV21View(variant: .full, start: Date(), onFinish: { hide() }))
    }

    static func show<V: View>(_ view: V) {
        hide()
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap(\.windows).first(where: \.isKeyWindow) else { return }
        let vc = UIHostingController(rootView: view)
        vc.view.frame = window.bounds
        vc.view.backgroundColor = .clear
        window.addSubview(vc.view)
        host = vc
        // 親 VC に つなぐ(SwiftUI の 環境が 動くように)
        window.rootViewController?.addChild(vc)
        vc.didMove(toParent: window.rootViewController)
    }

    static func hide() {
        OpeningDebug.frozenT = nil
        host?.willMove(toParent: nil)
        host?.view.removeFromSuperview()
        host?.removeFromParent()
        host = nil
    }
}

/// オープニングの 時間を 止めて 撮る ための 値
enum OpeningDebug {
    nonisolated(unsafe) static var frozenT: Double?
}
#endif
