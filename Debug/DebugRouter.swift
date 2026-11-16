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
        case "home": show(HomeV64Preview())
        case "yesterday": show(YesterdayV64Preview())
        case "develop": show(DevelopV64View(count: 3, times: ["11:57", "12:30", "14:02"], now: Calendar.current.date(bySettingHour: 11, minute: 57, second: 0, of: Date()) ?? Date()))
        case "tag": show(TagScreen(left: 3, haptics: ExposureHaptics(), tags: .constant([]), place: nil).background(Color.black))
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

/// DEBUG:Home(V64)を 起動引数の 状態で 直接 出す。
/// 例:`-debugRoute home -debugShots 2 -debugFriends 3 -debugRequests 1 -debugHint 1 -debugBackdrop 1`
struct HomeV64Preview: View {
    var body: some View {
        let d = UserDefaults.standard
        var input = HomeV64Input()
        input.shotsUsed = d.integer(forKey: "debugShots")
        input.isNight = d.bool(forKey: "debugNight")
        input.isFirstDay = d.bool(forKey: "debugFirstDay")
        let friends = d.integer(forKey: "debugFriends")
        input.friendCount = friends
        input.requestCount = d.integer(forKey: "debugRequests")
        input.showHint = d.bool(forKey: "debugHint")
        input.pressedFocus = d.bool(forKey: "debugFocus")
        input.spotlight = d.bool(forKey: "debugVeil")
        input.openLiveAtStart = d.bool(forKey: "debugLive")
        input.debugClock = d.bool(forKey: "debugLive") ? Calendar.current.date(bySettingHour: 11, minute: 54, second: 59, of: Date()) : nil
        input.avatarBadge = d.object(forKey: "debugBadge") == nil ? true : d.bool(forKey: "debugBadge")
        input.faces = SampleData.faces(count: d.integer(forKey: "debugFaces"))
        if d.bool(forKey: "debugBackdrop") {
            let k = d.string(forKey: "debugPhoto") ?? "d"
            input.backdrop = [SampleData.photo(k) ?? SampleData.blurryPhoto(seed: 1)]
            input.yesterdayPhoto = SampleData.photo("a") ?? SampleData.blurryPhoto(seed: 2)
        }
        input.page = d.integer(forKey: "debugPage")
        let names = ["あや", "れな", "そら"], cols = [Color(hex: "61DD7A"), Color(hex: "7FB0FF"), Color(hex: "6FCB8C")]
        input.friends = (0..<min(3, friends)).map { HomeV64Friend(id: "fr\($0)", name: names[$0], color: cols[$0], image: SampleData.photo(["d", "d", "f"][$0]), shots: [3, 2, 0][$0]) }
        input.requestFaces = SampleData.faces(count: input.requestCount > 0 ? 3 : 0)
        input.yesterdayThumbs = true ? [HomeV64Thumb(id: "t0", image: SampleData.photo("a"), time: "18:42"), HomeV64Thumb(id: "t1", image: SampleData.photo("b"), time: "16:05"), HomeV64Thumb(id: "t2", image: SampleData.photo("c"), time: "21:13")] : []
        input.tripSamples = ["f", "b", "d"].compactMap { SampleData.photo($0) }
        input.debugScroll = CGFloat(d.integer(forKey: "debugScroll"))
        input.debugSection = d.string(forKey: "debugSection")
        var low = HomeV64LowerData()
        let P = SampleData.photo
        low.today = .init(thumbs: [P("c"), P("a"), P("e")], times: ["16:05"])
        low.hero = .init(photo: P("d"), tag: "#朝", tagColor: Color(hex: "9ED8FF"), dateLabel: "NOV 15", moments: 6, people: 4, daysLeft: 6)
        low.tiles = [.init(photo: P("d"), name: "あや", time: "17:05"), .init(photo: P("b"), name: "you", time: "16:05", own: true), .init(photo: P("d"), name: "れな", time: "12:40"), .init(photo: P("e"), name: "そら", time: "09:12")]
        low.mondo = [("#夕焼け", P("a")), ("#放課後", P("e")), ("#帰り道", P("d"))]
        low.albums = (1...6).map { k in .init(label: "Nov \(16 - k)", left: "\(7 - k)D LEFT · \(["SUN", "SAT", "FRI", "THU", "WED", "TUE"][k - 1])", tiles: [P("c"), P("d"), P("a")], more: [8, 5, 12, 3, 9, 6][k - 1]) }
        low.onThisDay = (P("a"), 335, "'25 11 17")
        input.lower = low
        input.now = Calendar.current.date(bySettingHour: 11, minute: 54, second: 0, of: Date()) ?? Date()
        return HomeV64View(input: input).background(Color.black).ignoresSafeArea()
    }
}

extension SampleData {
    /// DEBUG(シミュレータ)だけ:モックから 取り出した 見本写真(`/tmp/lattag_ph/<a-f>.jpg`)。無ければ nil
    static func photo(_ key: String) -> UIImage? { UIImage(contentsOfFile: "/tmp/lattag_ph/\(key).jpg") }

    static func faces(count: Int) -> [HomeV64Face] {
        let colors = [Color(hex: "EE5E9C"), Color(hex: "9ED8FF"), Color(hex: "C8F25A")]
        return (0..<min(3, count)).map { HomeV64Face(id: "f\($0)", initial: ["あ", "ケ", "ゆ"][$0], color: colors[$0], image: photo(["d", "c", "b"][$0])) }
    }

    /// 見本の 写真の かわり(ぼかして 使う 色の 面)
    static func blurryPhoto(seed: Int) -> UIImage {
        let size = CGSize(width: 260, height: 356)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let palettes: [[UIColor]] = [[UIColor(red: 0.62, green: 0.45, blue: 0.42, alpha: 1), UIColor(red: 0.2, green: 0.26, blue: 0.55, alpha: 1), UIColor(red: 0.06, green: 0.07, blue: 0.14, alpha: 1)],
                                         [UIColor(red: 0.95, green: 0.6, blue: 0.3, alpha: 1), UIColor(red: 0.3, green: 0.18, blue: 0.2, alpha: 1), UIColor(red: 0.5, green: 0.35, blue: 0.5, alpha: 1)]]
            let p = palettes[seed % palettes.count]
            let g = CGGradient(colorsSpace: nil, colors: p.map(\.cgColor) as CFArray, locations: [0, 0.55, 1])!
            ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: size.width * 0.4, y: size.height), options: [])
            for i in 0..<4 {
                let c = p[i % p.count].withAlphaComponent(0.7)
                c.setFill()
                ctx.cgContext.fillEllipse(in: CGRect(x: CGFloat(i * 53 % 200), y: CGFloat(i * 97 % 280), width: 120, height: 120))
            }
        }
    }
}

/// DEBUG:Lattag yesterday(`-debugShots 2 -debugTab 1 -debugRequests 1`)
struct YesterdayV64Preview: View {
    var body: some View {
        let d = UserDefaults.standard
        var y = YesterdayV64Input()
        y.shotsUsed = d.integer(forKey: "debugShots")
        y.startTab = d.integer(forKey: "debugTab")
        y.scrollToMe = d.bool(forKey: "debugScrollMe")
        y.startViewing = d.string(forKey: "debugViewing")
        y.shotFriends = d.integer(forKey: "debugShotFriends")
        y.requestCount = d.integer(forKey: "debugRequests")
        y.requestFaces = SampleData.faces(count: y.requestCount > 0 ? 3 : 0)
        y.cells = [.init(id: "a", photo: SampleData.photo("a"), name: "あや", time: "17:05", tag: nil), .init(id: "b", photo: SampleData.photo("d"), name: "れな", time: "12:40", tag: nil), .init(id: "c", photo: SampleData.photo("b"), name: "そら", time: "09:12", tag: nil), .init(id: "d", photo: SampleData.photo("e"), name: "you", time: "16:05", tag: nil)]
        y.mondoPhoto = SampleData.photo("a")
        y.now = Calendar.current.date(bySettingHour: 12, minute: 3, second: 0, of: Date()) ?? Date()
        return YesterdayV64View(input: y)
    }
}
#endif
