#if DEBUG
import SwiftUI
import SwiftData
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
        case "opening": show(OpeningV72View(variant: .full, start: Date(), onFinish: { hide() })); OpeningDebug.frozenT = t
        case "home": show(HomeV64Preview())
        case "yesterday": show(YesterdayV64Preview())
        case "develop": show(DevelopV64View(count: 3, times: ["11:57", "12:30", "14:02"], now: Calendar.current.date(bySettingHour: 11, minute: 57, second: 0, of: Date()) ?? Date()))
        case "friends": showRaw(FriendsV68Preview())
        case "trip": showRaw(TripV83Preview())
        case "triphome": showRaw(TripHomeV83Preview())
        case "me": showRaw(MEV86Preview())
        case "friendcard": showRaw(ZStack { Color(hex: "151413").ignoresSafeArea(); FriendCardV82Sheet(name: "れな", avatar: SampleData.photo("d"), tag: "雨の日", city: nil, times: ["08:14", "12:40"], mosaics: [SampleData.photo("d"), SampleData.photo("d")]).frame(height: 650).frame(maxHeight: .infinity, alignment: .bottom) })
        case "dm": showRaw(DirectMessageView(friendID: "x", friendName: "れな", yesterdayCount: 4, injected: [.init(id: "1", senderID: "れな", text: "きのうの 写真 みた?", createdAt: Date()), .init(id: "2", senderID: "れな", text: "わたしの 帰り道", createdAt: Date())]))
        case "profile": showRaw(ProfileV82View(data: ProfileV82Data(name: "ゆい", username: "yui_0612", avatar: UserDefaults.standard.bool(forKey: "debugNoPhoto") ? nil : SampleData.photo("f"), tags: ["カフェ", "音楽", "夜型"], since: "Oct 2026", streak: 11, shots: 48, kept: 9, recapPhotos: [SampleData.photo("d")], recapRange: "NOV 9–15", weekHas: [true, true, true, true, true, true, true]), debugScrollY: UserDefaults.standard.object(forKey: "debugScrollY") == nil ? nil : CGFloat(UserDefaults.standard.double(forKey: "debugScrollY"))))
        case "profileedit": showRaw(ProfileEditV88View(name: "ゆい", tags: ["カフェ", "音楽", "夜型"], avatar: SampleData.photo("f"), onPhoto: {}, onSave: { _, _ in }, onClose: {}))
        case "music": showRaw(MusicSheet(current: nil, onDone: { _ in }))
        case "reveal": showRaw(ReleaseRevealV89View(image: SampleData.photo("d"), ordinal: 1, count: 2, tag: "放課後", time: "17:42", place: "鎌倉市", playsReveal: true, onFinish: { _ in }))
        case "qr": showRaw(SelfQRChekiV92View(name: "ゆい", username: "yui_0612", link: "https://lattag.app/u/yui_0612", photo: SampleData.photo("f"), tags: ["カフェ", "音楽", "夜型"], onClose: {}))
        case "shutter": showRaw(HStack(spacing: 8) { ForEach([0.0, 0.4, 0.75, 1.0], id: \.self) { k in ShutterIconV94(progress: k, holding: k > 0, video: false, recording: false, dead: false, late: false, snapToken: 0).frame(width: 104, height: 104) } }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black))
        case "trippass": showRaw(TripPassView(data: DebugTripV98.pass, newlyMade: UserDefaults.standard.object(forKey: "debugNew") as? Bool ?? true, onStart: {}, onClose: {}))
        case "tripboard": showRaw(TripBoardingView(name: "京都 2泊3日", date: "11/18", key: "meadow95", cover: SampleData.photo("d"), me: "ゆい", people: [TripSeatPerson(id: "1", name: "ゆい", image: SampleData.photo("f"))], onSend: {}, onQR: {}))
        case "tripseats": showRaw(VStack { TripSeatMap(people: DebugTripV98.people, small: true).padding(16) }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(hex: "111113")))
        case "intro": showRaw(IntroStoryView(kind: IntroKind(rawValue: UserDefaults.standard.string(forKey: "debugIntroKind") ?? "") ?? .friends, startAt: UserDefaults.standard.double(forKey: "debugIntroAt"), onClose: { _ in }))
        case "widgetguide": showRaw(WidgetGuideV96Sheet(onClose: {}))
        case "live": showRaw(DebugLiveView())
        case "widgets": showRaw(DebugWidgetsView())
        case "settings": showRaw(SettingsV87Sheet(name: "ゆい", username: "yui_0612", avatar: SampleData.photo("f"), blockedCount: 0))
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
        show(OpeningV72View(variant: .full, start: Date(), onFinish: { hide() }))
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
            // v82 の 見本は 12:39:22(消灯まで 11:20:38)。夜は -debugNight 1(7:33:50)
            input.debugClock = d.bool(forKey: "debugNight") ? Calendar.current.date(bySettingHour: 7, minute: 33, second: 50, of: Date()) : Calendar.current.date(bySettingHour: 12, minute: 39, second: 22, of: Date())
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
        if d.bool(forKey: "debugTrip") {
            let faces = [("ゆ", "F4F1EA"), ("れ", "7FB0FF"), ("あ", "61DD7A"), ("そ", "61D278")].map { HomeV64Face(id: $0.0, initial: $0.0, color: Color(hex: $0.1)) }
            input.trip = HomeV64TripInfo(id: UUID(), name: "Kyoto", members: faces, frames: [0, 1, 2, 1, 3, 2, 0, 1] + [Int?](repeating: nil, count: 15), cover: SampleData.photo("b"), sub: "京都 2泊3日 ・ 11.16 — 11.18", dayText: "DAY 2 / 3", unread: 2)
        }
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
        if d.bool(forKey: "debugTrip") { low.trips = [(id: UUID(), name: "Kyoto", sub: "京都 2泊3日", cover: SampleData.photo("b"), day: "DAY 2 / 3", unread: 2)] }
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

/// DEBUG:Lattag yesterday(`-debugShots 2 -debugTab 1 -debugNotices 1 -debugMine 1 -debugMondo open|stage|empty -debugFilter 帰り道`)
struct YesterdayV64Preview: View {
    var body: some View {
        let d = UserDefaults.standard
        var y = YesterdayV64Input()
        let ph = { (k: String) in SampleData.photo(k) }
        y.shotsUsed = d.object(forKey: "debugShots") == nil ? 2 : d.integer(forKey: "debugShots")
        y.startTab = d.integer(forKey: "debugTab")
        y.startViewing = d.string(forKey: "debugViewing")
        y.requestCount = d.integer(forKey: "debugRequests")
        y.avatar = ph("f"); y.avatarName = "you"
        y.openNotices = d.bool(forKey: "debugNotices")
        y.openMine = d.bool(forKey: "debugMine")
        if d.object(forKey: "debugScrollY") != nil { y.debugScrollY = CGFloat(d.double(forKey: "debugScrollY")) }
        y.mineIndex = d.object(forKey: "debugMineIndex") == nil ? 1 : d.integer(forKey: "debugMineIndex")
        y.now = Calendar.current.date(bySettingHour: 12, minute: 3, second: 0, of: Date()) ?? Date()
        y.mine = [.init(id: "m1", image: ph("b"), time: "09:12", tag: "帰り道"), .init(id: "m2", image: ph("d"), time: "13:40", tag: "放課後"), .init(id: "m3", image: ph("e"), time: "18:05", tag: "夕焼け")]
        let rx: [UIImage?] = [ph("d"), ph("a"), ph("f")]
        y.posts = [
            .init(id: "rena", name: "れな", avatar: ph("d"), place: "鎌倉市", when: "きのう 17:00", photos: [.init(id: "r1", image: ph("a"), time: "17:00", tag: "夕焼け"), .init(id: "r2", image: ph("b"), time: "13:10", tag: "おやつ"), .init(id: "r3", image: ph("c"), time: "09:30", tag: "電車")], caption: nil, reactors: rx),
            .init(id: "aya", name: "あや", avatar: ph("a"), place: "横浜市", when: "きのう 18:05", photos: [.init(id: "a1", image: ph("e"), time: "18:05", tag: "おやつ"), .init(id: "a2", image: ph("f"), time: "12:40", tag: "教室"), .init(id: "a3", image: ph("a"), time: "17:30", tag: "夕焼け")], caption: "この 自販機 すき", reactors: [ph("d"), ph("a"), ph("e")]),
            .init(id: "hina", name: "ひなた", avatar: ph("b"), photos: [.init(id: "h1", image: ph("f"), time: "", tag: nil)], caption: nil, published: false),
            .init(id: "sora", name: "そら", avatar: ph("c"), place: "藤沢市", when: "きのう 09:12", photos: [.init(id: "s1", image: ph("c"), time: "09:12", tag: "電車"), .init(id: "s2", image: ph("d"), time: "16:00", tag: "帰り道")], caption: nil, reactors: [ph("a")]),
            .init(id: "yui", name: "ゆい", avatar: ph("e"), photos: [.init(id: "y1", image: ph("a"), time: "", tag: nil)], caption: nil, published: false),
        ]
        y.cells = [.init(id: "a1", photo: ph("a"), name: "あや", time: "17:05", tag: "夕焼け"), .init(id: "m", photo: ph("a"), name: "鎌倉市", time: nil, tag: "夕焼け")]
        y.notices = [
            .init(id: "n1", name: "あや", avatar: ph("a"), text: "あなたの #夕焼け に リアクション", time: "2分", isNew: true),
            .init(id: "n2", name: "れな", avatar: ph("c"), text: "コメント「この 空 すき」", time: "14分", isNew: true),
            .init(id: "n3", name: "ひなた", avatar: ph("b"), text: "友だち申請が とどきました", time: "1時間", isNew: true, approveID: "r1"),
            .init(id: "n4", kind: .lattag, name: "Lattag", avatar: nil, text: "きのうの 3枚が ひらきました", time: "9:00"),
            .init(id: "n5", kind: .mondo, name: "Mondo", avatar: nil, text: "#夕焼け が 世界 1位に", time: "9:00"),
            .init(id: "n6", name: "そら", avatar: ph("d"), text: "あなたの #帰り道 に リアクション", time: "きのう"),
        ]
        switch d.string(forKey: "debugFriendsMode") ?? "" {
        case "first": y.mine = []; y.posts = []; y.friendCount = 0
        case "nofriends": y.posts = []; y.friendCount = 0
        case "noown": y.mine = []; y.friendCount = 3
        default: y.friendCount = 3
        }
        var m = YesterdayMondoInput()
        let mode = d.string(forKey: "debugMondo") ?? "open"
        m.hasPosts = mode != "empty"; m.startOpened = mode == "open"; m.filterTag = d.string(forKey: "debugFilter")
        m.dayLabel = "11/16"
        m.cities = [.init(id: "tk", name: "TOKYO", lat: 35.7, lon: 139.7, photo: ph("a")), .init(id: "bk", name: "BANGKOK", lat: 13.7, lon: 100.5, photo: ph("e")), .init(id: "sl", name: "SEOUL", lat: 37.5, lon: 127, photo: ph("d")), .init(id: "sy", name: "SYDNEY", lat: -33.9, lon: 151.2, photo: ph("f")), .init(id: "pa", name: "PARIS", lat: 48.9, lon: 2.3, photo: ph("c")), .init(id: "ny", name: "NEW YORK", lat: 40.7, lon: -74, photo: ph("b"))]
        m.tags = [.init(id: "t1", name: "夕焼け", count: 1203, cities: 92, photos: [ph("a"), ph("c")], delta: 2), .init(id: "t2", name: "帰り道", count: 864, cities: 64, photos: [ph("b")], delta: nil), .init(id: "t3", name: "放課後", count: 712, cities: 48, photos: [ph("d")], delta: -1),
                  .init(id: "t4", name: "おやつ", count: 540, cities: 30, photos: [ph("e"), ph("a")], delta: 3), .init(id: "t5", name: "雨の日", count: 388, cities: 18, photos: [ph("c"), ph("b")], delta: -2), .init(id: "t6", name: "教室", count: 301, cities: 12, photos: [ph("f"), ph("d")], delta: 1),
                  .init(id: "t7", name: "電車", count: 257, cities: 10, photos: [ph("b"), ph("a")], delta: nil), .init(id: "t8", name: "自販機", count: 198, cities: 9, photos: [ph("c"), ph("e")], delta: 4)]
        m.todaysOne = .init(id: "one", photo: ph("a"), city: "鎌倉市", time: "17:42", tag: "夕焼け")
        m.world = [.init(id: "w1", photo: ph("a"), city: "TOKYO", time: "17:42", tag: "夕焼け"), .init(id: "w2", photo: ph("d"), city: "SEOUL", time: "18:10", tag: "帰り道"), .init(id: "w3", photo: ph("b"), city: "PARIS", time: "10:05", tag: "おやつ"), .init(id: "w4", photo: ph("c"), city: "BANGKOK", time: "15:20", tag: "電車")]
        y.mondo = m
        return YesterdayV64View(input: y)
    }
}

/// DEBUG:Trip を つくる(`-debugStep 0〜3 -debugPass 1 -debugTripName "京都 2泊3日"`)
struct TripV83Preview: View {
    var body: some View {
        let d = UserDefaults.standard
        let ph = { (k: String) in SampleData.photo(k) }
        let cal = Calendar.current
        let y = cal.component(.year, from: Date())
        var draft = TripDraft()
        draft.name = d.string(forKey: "debugTripName") ?? ""
        draft.start = cal.date(from: DateComponents(year: y, month: 11, day: 17)) ?? Date()
        draft.end = cal.date(from: DateComponents(year: y, month: 11, day: 19)) ?? Date()
        draft.invited = ["a", "b"]
        let step = d.integer(forKey: "debugStep")
        draft.coverIndex = step == 3 && !d.bool(forKey: "debugPass") ? 3 : 0
        let friends = [("a", "れな"), ("b", "あや"), ("c", "そら"), ("d", "ひなた")].map { GroupCreateFriend(id: $0.0, name: $0.1, avatarData: nil, seed: UUID()) }
        return TripNewV83View(friends: friends, photos: ["a", "b", "c", "d", "e", "f"].map { ph($0) }, myAvatar: ph("f"), startStep: step, startDraft: draft, onClose: {}, previewPass: d.bool(forKey: "debugPass"), todayOverride: draft.start)
            .modelContainer(for: [UserProfile.self, LaterGroup.self], inMemory: true)
    }
}

/// DEBUG:Trip の ホーム(`-debugScrollY 400`)
struct TripHomeV83Preview: View {
    var body: some View {
        let d = UserDefaults.standard
        let ph = { (k: String) in SampleData.photo(k) }
        let ms: [TripHomeData.Member] = [.init(id: "me", name: "you", avatar: ph("f")), .init(id: "a", name: "れな", avatar: nil), .init(id: "b", name: "あや", avatar: nil), .init(id: "c", name: "そら", avatar: nil)]
        var data = TripHomeData(name: "Kyoto", sub: "京都 2泊3日 ・ 11/16 — 11/18", dayNumber: 2, dayTotal: 3, cover: ph("b"), members: ms, shotsToday: 7, shooters: Array(ms.prefix(3)))
        let all = ["b", "c", "d", "e", "f", "a", "b", "c"].map { ph($0) }
        data.days = [.init(id: "d1", label: "DAY 1 ・ 11/16(月)", opened: 23, photos: all), .init(id: "d2", label: "DAY 2 ・ 11/17(火)", opened: 7, photos: all, isToday: true), .init(id: "d3", label: "DAY 3 ・ 11/18(水)", opened: 0, photos: Array(repeating: nil, count: 4), isFuture: true)]
        data.chatLine = ("れな", "あと そらだけ。はよ 撮って")
        data.unread = 2
        return TripHomeV83View(data: data, debugScrollY: d.object(forKey: "debugScrollY") == nil ? nil : CGFloat(d.double(forKey: "debugScrollY")))
    }
}

/// DEBUG:ME(`-debugMeState ready|seen -debugMeScroll 700 -debugMeDay 2026-11-16 -debugMePlay 1 -debugMePlayT 0.8`)
struct MEV86Preview: View {
    var body: some View {
        let d = UserDefaults.standard
        let cal = RecapRules.calendar()
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 12, minute: 39, second: 22)) ?? Date()
        let keys = ["a", "b", "c", "d", "e", "f"]
        let tags = ["夕焼け", "帰り道", "おやつ", "教室", "電車", "自販機"]
        var shots: [MEV86Shot] = []
        let perDay = [2, 0, 2, 2, 1, 3, 2, 0, 2, 3, 3, 3, 3, 2, 3, 3]
        var n = 0
        for back in stride(from: 80, through: 1, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -back, to: cal.startOfDay(for: now)) else { continue }
            let dayN = cal.component(.day, from: day)
            let count = back <= 16 && cal.component(.month, from: day) == 11 ? perDay[min(15, dayN - 1)] : [1, 0, 0, 1, 0, 1, 0][back % 7]
            for k in 0..<count {
                let t = cal.date(bySettingHour: 9 + k * 4, minute: 12 + back % 40, second: 0, of: day) ?? day
                shots.append(MEV86Shot(id: "p\(n)", date: t, tag: tags[(n + k) % 6], kept: (n % 3 == 0), image: SampleData.photo(keys[(n * 5 + k) % 6])))
                n += 1
            }
        }
        var recaps = RecapRules.missing(now: now, shots: shots.map { RecapShot(id: $0.id, date: $0.date, tag: $0.tag, kept: $0.kept) }, existing: [])
        recaps.sort { $0.start > $1.start }
        recaps = Array(recaps.prefix(9))
        if let i = recaps.firstIndex(where: { $0.kind == .week }) {
            let seen = (d.string(forKey: "debugMeState") ?? "seen") == "seen"
            recaps[i].state = seen ? .seen : .ready
            recaps[i].cover = recaps[i].photoIDs.first ?? ""
        }
        for i in recaps.indices where i > 1 { recaps[i].state = .seen }
        var data = MEV86Data(shots: shots, recaps: recaps, now: now)
        data.shots = shots
        var day: Date? = nil
        if let s = d.string(forKey: "debugMeDay") { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; day = f.date(from: s) }
        return MEV86View(data: data, startDay: day, startPlay: d.bool(forKey: "debugMePlay"), startPlayT: d.object(forKey: "debugMePlayT") == nil ? nil : d.double(forKey: "debugMePlayT"),
                         startScrollY: d.object(forKey: "debugMeScroll") == nil ? nil : CGFloat(d.double(forKey: "debugMeScroll")), startScrub: d.object(forKey: "debugMeScrub") == nil ? nil : d.integer(forKey: "debugMeScrub"))
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


#if DEBUG
enum DebugTripV98 {
    static var people: [TripSeatPerson] { [("ゆい", "f"), ("れな", "d"), ("そら", "f"), ("みお", "d")].enumerated().map { TripSeatPerson(id: "\($0.offset)", name: $0.element.0, image: SampleData.photo($0.element.1)) } }
    static var pass: TripPassData {
        TripPassData(name: "京都 2泊3日", sub: "Kyoto trip", from: "NOV 18", to: "NOV 20", days: 3, key: "meadow95", link: "https://lattag.app/t/meadow95",
                     cover: SampleData.photo("d"), members: people.map(\.image), names: people.map(\.name))
    }
}
#endif
