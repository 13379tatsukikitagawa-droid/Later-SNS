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
        case "friends": showRaw(FriendsV68Preview())
        case "tag": showRaw(TagScreen(left: 3, haptics: ExposureHaptics(), tags: .constant([]), place: nil).background(Color.black).preferredColorScheme(.dark))
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

    /// 見本画像と くらべる ため だけ:モックが かいている 端末の わく(ダイナミックアイランド ・ 時計 ・ 電波 ・ 電池 ・ 丸い かど)を 重ねる。本番には 入らない
    static func show<V: View>(_ view: V) {
        showRaw(ZStack { view; DebugMockChrome() })
    }

    static func showRaw<V: View>(_ view: V) {
        UITextField.appearance().keyboardAppearance = .dark
        UITextView.appearance().keyboardAppearance = .dark
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
        // v68 の 見本は 朝 7:33:50(ひらくまで 1:26:10)。-debugMock 1 で 見本と 同じ 時刻 ・ 同じ アバターに する
        if d.bool(forKey: "debugMock") {
            input.debugClock = Calendar.current.date(bySettingHour: 7, minute: 33, second: 50, of: Date())
            input.avatar = SampleData.photo("f")
        }
        input.avatarBadge = d.object(forKey: "debugBadge") == nil ? true : d.bool(forKey: "debugBadge")
        input.faces = SampleData.faces(count: d.integer(forKey: "debugFaces"))
        if d.bool(forKey: "debugBackdrop") {
            let k = d.string(forKey: "debugPhoto") ?? "d"
            input.backdrop = [SampleData.photo(k) ?? SampleData.blurryPhoto(seed: 1)]
            input.yesterdayPhoto = SampleData.photo("a") ?? SampleData.blurryPhoto(seed: 2)
        }
        input.page = d.integer(forKey: "debugPage")
        let names = ["あや", "れな", "そら"], cols = [Color(hex: "61DD7A"), Color(hex: "7FB0FF"), Color(hex: "6FCB8C")]
        input.friends = (0..<min(3, friends)).map { HomeV64Friend(id: "fr\($0)", name: names[$0], color: cols[$0], image: SampleData.photo(["b", "b", "f"][$0]), shots: [3, 2, 0][$0], time: ["17:05", "12:40", nil][$0]) }
        if input.requestCount > 0 {
            let rn = friends > 0 ? [("ひなた", "@hinata_3304", "1h", "a"), ("りこ", "@riko_6982", "2h", "c"), ("さき", "@saki_6611", "5h", "b")] : [("りこ", "@riko_6982", "2h", "c"), ("さき", "@saki_6611", "5h", "b")]
            input.requests = rn.enumerated().map { i, r in HomeV64Request(id: "rq\(i)", name: r.0, handle: r.1, ago: r.2, color: Color(hex: "7FB0FF"), image: SampleData.photo(r.3)) }
        }
        input.requestFaces = SampleData.faces(count: input.requestCount > 0 ? 3 : 0)
        input.yesterdayThumbs = true ? [HomeV64Thumb(id: "t0", image: SampleData.photo("a"), time: "18:42"), HomeV64Thumb(id: "t1", image: SampleData.photo("b"), time: "16:05"), HomeV64Thumb(id: "t2", image: SampleData.photo("c"), time: "21:13")] : []
        input.tripSamples = ["f", "c", "e"].compactMap { SampleData.photo($0) }
        input.debugScroll = CGFloat(d.integer(forKey: "debugScroll"))
        input.debugSection = d.string(forKey: "debugSection")
        var low = HomeV64LowerData()
        let P = SampleData.photo
        low.today = .init(thumbs: [P("c"), P("a"), P("e")], times: ["16:05"])
        low.hero = .init(photo: P("d"), tag: "#朝", tagColor: Color(hex: "9ED8FF"), dateLabel: "NOV 15", moments: 6, people: 4, daysLeft: 6)
        low.tiles = [.init(photo: P("d"), name: "あや", time: "17:05"), .init(photo: P("b"), name: "you", time: "16:05", own: true), .init(photo: P("d"), name: "れな", time: "12:40"), .init(photo: P("e"), name: "そら", time: "09:12")]
        low.mondo = [("#散歩", P("a")), ("#放課後", P("f")), ("#夕焼け", P("a"))]
        low.albums = (1...6).map { k in .init(label: "Nov \(16 - k)", left: "\(7 - k)D LEFT · \(["SUN", "SAT", "FRI", "THU", "WED", "TUE"][k - 1])", tiles: [[P("c"), P("d"), P("e")], [P("e"), P("f"), nil], [P("a"), P("b"), P("c")], [P("d"), P("e"), P("f")], [P("a"), P("c"), P("e")], [P("b"), P("d"), P("f")]][k - 1], more: [8, 5, 12, 3, 9, 6][k - 1]) }
        low.onThisDay = (P("c"), 335, "'26 10 17")
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
        y.viewerOnly = [.init(id: "m", photo: SampleData.photo("a"), name: "鎌倉市", time: nil, tag: "夕焼け")]
        y.now = Calendar.current.date(bySettingHour: 12, minute: 3, second: 0, of: Date()) ?? Date()
        return YesterdayV64View(input: y)
    }
}

struct DebugMockChrome: View {
    var clock: String = UserDefaults.standard.string(forKey: "debugClockText") ?? "11:55"
    var dark = false
    var body: some View {
        GeometryReader { g in
            let ink = Color(hex: "111111")
            ZStack(alignment: .topLeading) {
                // 丸い かど
                Canvas { ctx, size in
                    var p = Path(CGRect(origin: .zero, size: size))
                    p.addRoundedRect(in: CGRect(origin: .zero, size: size), cornerSize: CGSize(width: 50, height: 50), style: .continuous)
                    ctx.fill(p, with: .color(Color(hex: "0D0D0F")), style: FillStyle(eoFill: true))
                }
                Text(clock).font(LF.inter(700, 16)).foregroundStyle(UserDefaults.standard.bool(forKey: "debugChromeLight") ? .white : ink).offset(x: 42, y: 19)
                Capsule().fill(.black).frame(width: 122, height: 35).offset(x: (g.size.width - 122) / 2, y: 11)
                Image(systemName: "cellularbars").font(.system(size: 13, weight: .bold)).foregroundStyle(UserDefaults.standard.bool(forKey: "debugChromeLight") ? .white : ink).offset(x: 310, y: 21)
                RoundedRectangle(cornerRadius: 4).stroke(UserDefaults.standard.bool(forKey: "debugChromeLight") ? .white : ink, lineWidth: 1).frame(width: 25, height: 12).offset(x: 333, y: 23).opacity(0.9)
            }
        }
        .ignoresSafeArea().allowsHitTesting(false)
    }
}

/// DEBUG:Friends 画面(`-debugRoute friends -debugFriends 3 -debugRequests 1`)
struct FriendsV68Preview: View {
    private static func data(_ k: String) -> Data? { try? Data(contentsOf: URL(fileURLWithPath: "/tmp/lattag_ph/\(k).jpg")) }
    private var screen: FriendsV68View {
        let d = UserDefaults.standard
        let n = d.integer(forKey: "debugFriends")
        let names = ["あや", "れな", "そら"], shots = [true, true, false], keys = ["b", "b", "f"]
        let friends = (0..<min(3, n)).map { HomeFriend(id: "fr\($0)", name: names[$0], avatarData: Self.data(keys[$0]), seed: UUID(), hasShot: shots[$0], city: nil, mosaicTiny: Self.data(keys[$0]), mosaicKey: "m\($0)", tag: nil, knockOff: false, isMe: false, groupIDs: []) }
        let reqs: [FriendRequests.Request] = d.integer(forKey: "debugRequests") > 0
            ? [FriendRequests.Request(id: "r0", fromUserID: "u0", toUserID: "me", fromName: "りこ", createdAt: Date().addingTimeInterval(-7200), fromUsername: "riko_6982"),
               FriendRequests.Request(id: "r1", fromUserID: "u1", toUserID: "me", fromName: "さき", createdAt: Date().addingTimeInterval(-18000), fromUsername: "saki_6611")] : []
        return FriendsV68View(myName: "you", friends: friends, groups: [], onClose: {}, injectedRequests: reqs)
    }
    var body: some View { screen }
}
#endif
