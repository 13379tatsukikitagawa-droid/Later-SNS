import SwiftUI

// P02:Home(上)= ヘッダー ・ カメラカード(ぼかした 写真 + ガラス)・ 四すみ ・ ピル ・ 目次 ・ 月(今日を撮る)。
// 見本:H01〜H10。仕様:PROMPT_v64(ぼかした 写真 + ガラス)→ v65(仕上げ)→ v66(カメラの 絵だけ ・ 上と 下を ガラス ・ はじめての 日)。

struct HomeV64Face: Identifiable, Equatable {
    let id: String
    let initial: String
    let color: Color
    var image: UIImage? = nil
    static func == (a: HomeV64Face, b: HomeV64Face) -> Bool { a.id == b.id && a.initial == b.initial }
}

/// 画面を 描く ための 値(状態は ぜんぶ ここに 集める。DEBUG の 状態メニューも この 値を 作る)
struct HomeV64Input {
    var shotsUsed = 0
    var limit = 3
    var isNight = false
    var isFirstDay = false
    /// 今日 撮った 友だち(多い 順)
    var faces: [HomeV64Face] = []
    var friendCount = 0
    var requestCount = 0
    var avatar: UIImage?
    var avatarName = ""
    var avatarBadge = false
    /// v131:写真の カードの Friends に 敷く 友だちの アイコン写真(なければ 色の 地)
    var friendsCardPhoto: UIImage?
    /// v108:お知らせの 数(未対応の 友だち申請 + Trip の 招待)
    var inboxCount = 0
    /// うしろに ぼかして 敷く 写真(友だちの 今日 → 自分の きのう → なし)
    var backdrop: [UIImage] = []
    /// 3枚 撮りおわった とき、まんなかの 窓に 出す きのうの 写真
    var yesterdayPhoto: UIImage?
    var friends: [HomeV64Friend] = []
    var requestFaces: [HomeV64Face] = []
    var requests: [HomeV64Request] = []
    var yesterdayThumbs: [HomeV64Thumb] = []
    var trip: HomeV64TripInfo? = nil
    var tripItems: [TripHubItem] = []
    var tripSamples: [UIImage] = []
    var lower = HomeV64LowerData()
    var debugScroll: CGFloat = 0
    /// DEBUG:セクションの 頭を 画面の このへんに あわせる(例 \"sec-mondo:157\")
    var debugSection: String? = nil
    var now = Date()
    var showHint = false
    var pressedFocus = false
    /// はじめの 合図:ほかを ぼかして うすく して、月と ふきだしだけ のこす
    var spotlight = false
    /// DEBUG:ライブパネルを 最初から ひらく / 時刻を 止める
    var openLiveAtStart = false
    var debugClock: Date? = nil
    /// 最初に 出す ページ(DEBUG の 見本どり 用)
    var page = 0

    var remaining: Int { max(0, limit - shotsUsed) }
    var done: Bool { shotsUsed >= limit }
    var locked: Bool { shotsUsed == 0 }
}

struct HomeV64Actions {
    var shoot: () -> Void = {}
    var openYesterday: () -> Void = {}
    var openFriends: () -> Void = {}
    var openTrip: () -> Void = {}
    var openTripHome: (_ id: UUID) -> Void = { _ in }
    var joinKey: () -> Void = {}
    var openProfile: () -> Void = {}
    var openDevelop: () -> Void = {}
    var openLive: () -> Void = {}
    var addFriends: () -> Void = {}
    var scrollToToday: () -> Void = {}
    var scanQR: () -> Void = {}
    var openRequests: () -> Void = {}
    var openInbox: () -> Void = {}
    var openChat: (_ friendID: String, _ name: String) -> Void = { _, _ in }
    var approve: (_ requestID: String) -> Void = { _ in }
    var dismissRequest: (_ requestID: String) -> Void = { _ in }
    var shareLink: () -> Void = {}
    var showQR: () -> Void = {}
    var searchByID: () -> Void = {}
}

struct HomeV64View: View {
    var input: HomeV64Input
    var actions = HomeV64Actions()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressing = false
    @State private var page = 0
    @State private var pageSeeded = false
    @State private var showLive = false
    @State private var wantsToday = 0
    @State private var entered = false
    @State private var tourStep: Int?
    @State private var showWidgetGuide = false

    @State private var scrollY: CGFloat = 0
    @State private var dragVal: CGFloat = 0
    @State private var compact = false
    @State private var mini = false
    @State private var scrollTopTick = 0
    @State private var afFlash = false
    @State private var lastCompactTick = Date.distantPast

    var body: some View {
        GeometryReader { g in
            let f = HV.Frame(w: g.size.width, h: g.size.height)
            let dark = 1.0
            ZStack(alignment: .topLeading) {
                Color(hex: "0A0A0B")
                // うしろ:単色の 黒(v74)。写真 ・ ぼかし ・ 光の 層は なし。スクロールで 0.68倍の 速さで 上へ
                Color.black.frame(width: f.w, height: 1010)
                    .offset(y: -scrollY * 0.68)
                    .opacity(1 - Double(min(1, max(0, (scrollY - 420) / 380))))
                HV68Dusk(width: f.w).offset(y: 692 + 2 * f.mid)
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        ZStack(alignment: .topLeading) {
                            // v89 A:カード(# ・ レンズ ・ 4ページ)は スクロールの 中。どこを なぞっても たてに 動く(外に 置くと 指が ScrollView に とどかない)
                            card(f)
                                .frame(width: f.w, height: 810 + 2 * f.mid, alignment: .topLeading)
                                .offset(y: 0.2 * scrollY)
                                .opacity(max(0, 1 - Double(scrollY) / 560) * (entered || reduceMotion ? 1 : 0))
                                .scaleEffect(entered || reduceMotion ? 1 : 1.06)
                                .allowsHitTesting(scrollY < 700)
                                .modifier(HVVeil(on: input.spotlight || showLive, dim: input.spotlight))
                            Color.clear.frame(width: 1, height: 1).id("top")
                            VStack(spacing: 0) { Color.clear.frame(width: 1, height: input.debugScroll); Color.clear.frame(width: 1, height: 1).id("dbg"); Spacer(minLength: 0) }.frame(width: 1)
                            VStack(spacing: 0) {
                                Color.clear.frame(height: 810 + 2 * f.mid)
                                HVLowerSections(input: input, data: input.lower, actions: actions).frame(width: f.w)
                            }
                        }
                        }
                    .onChange(of: wantsToday) { _, _ in withAnimation(.easeInOut(duration: 0.6)) { proxy.scrollTo("today", anchor: .top) } }
                    .onChange(of: scrollTopTick) { _, _ in proxy.scrollTo("top", anchor: .top) }
                    .scrollHaptics()
                    .onScrollGeometryChange(for: CGFloat.self) { max(0, $0.contentOffset.y + $0.contentInsets.top) } action: { _, new in
                        scrollY = new
                        let want = new > 60
                        let wantMini = new > 150
                        if wantMini != mini { mini = wantMini; if wantMini { Haptics.play(.notch) } }
                        if want != compact, Date().timeIntervalSince(lastCompactTick) > 0.3 { compact = want; lastCompactTick = Date(); Haptics.play(.tick) }
                    }
                    .onAppear {
                        if let sec = input.debugSection, let y = Double(sec.split(separator: ":").last ?? "150") {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { proxy.scrollTo(String(sec.split(separator: ":").first ?? ""), anchor: UnitPoint(x: 0.5, y: y / Double(f.h))) }
                        } else if input.debugScroll > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { proxy.scrollTo("dbg", anchor: .top) } }
                    }
                }
                // 上の ブロック(ページの 5まい)は 上へ ながれて うすく なる
                Group {
                    HV68Header(input: input, f: f, compact: compact, scrollY: scrollY, entered: entered || reduceMotion,
                               onYesterday: actions.openYesterday, onProfile: actions.openProfile, onInbox: actions.openInbox,
                               onLive: { actions.openLive(); withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showLive = true } })
                }
                .modifier(HVVeil(on: input.spotlight || showLive, dim: input.spotlight))
                .animation(.easeOut(duration: 0.35), value: input.spotlight)
                // v131:150pt より 下で 小さな 列(カード 3枚は 消える)
                HVMiniRowV131(requestCount: input.requestCount, onSelect: { i in
                    if i == 3 { actions.openYesterday() } else { withAnimation(nil) { scrollTop() }; goPage(i) }
                }, onUp: { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) { scrollTop() } })
                .scaleEffect(mini ? 1 : 0.7)
                .offset(y: mini ? 0 : 40)
                .opacity(mini ? 1 : 0)
                .allowsHitTesting(mini)
                .animation(reduceMotion ? .easeOut(duration: 0.2) : .timingCurve(0.3, 1.35, 0.5, 1, duration: 0.5), value: mini)
                .frame(width: f.w, height: f.h, alignment: .bottom)
                .padding(.bottom, 26)
                HVCountdownV100(active: !input.spotlight && tourStep == nil && !showLive).frame(width: f.w, height: f.h)
                if showLive { HVLivePanel(input: input, onClose: { withAnimation(.easeOut(duration: 0.25)) { showLive = false } }, onShoot: actions.shoot).zIndex(10) }
            }
            .frame(width: f.w, height: f.h, alignment: .topLeading)
            .environment(\.hvDark, dark)
        }
        .ignoresSafeArea()
        .overlay {
            if let tourStep { HomeTourV95View(start: tourStep, onDone: { finished in withAnimation(.easeOut(duration: 0.25)) { self.tourStep = nil }
                if finished, !WidgetGuideV96.seen { WidgetGuideV96.markSeen(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showWidgetGuide = true } } }).transition(.opacity) }
        }
        .sheet(isPresented: $showWidgetGuide) { WidgetGuideV96Sheet(firstTime: true) { showWidgetGuide = false } }
        .onChange(of: page) { _, p in
            // v99:Friends(1)・ Trip(2)に はじめて 来て 0.62秒 とどまったら 説明を 出す(素通りは 出さない)
            guard (1...2).contains(p), let kind = IntroKind.allCases[safe: p - 1], !IntroStore.seen(kind) else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
                guard page == p, tourStep == nil, !input.spotlight, !showLive, !IntroStore.seen(kind) else { return }
                let d = UserDefaults.standard
                guard d.bool(forKey: OnboardingStorage.completedKey) || d.bool(forKey: "isSetupCompleted") else { return }
                NotificationCenter.default.post(name: IntroStore.requested, object: IntroRequest(kind: kind))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: IntroStore.goCameraPage)) { _ in goPage(0) }
        .onReceive(NotificationCenter.default.publisher(for: HomeTour.replayRequested)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { withAnimation(.easeOut(duration: 0.25)) { tourStep = 0 } }
        }
        .onAppear {
            if !pageSeeded { page = input.page; pageSeeded = true; if input.openLiveAtStart { showLive = true } }
            scheduleTour()
            if !entered {
                withAnimation(.timingCurve(0.2, 0.8, 0.3, 1, duration: 0.9)) { entered = true }
                afFlash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) { afFlash = false }
            }
        }
    }

    /// v95-4:はじめての 説明は 1回 だけ(初回設定の あと)。`-debugTour N` で N 番目から 出す
    private func scheduleTour() {
        let d = UserDefaults.standard
        if d.object(forKey: "debugTour") != nil { DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { tourStep = d.integer(forKey: "debugTour") }; return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-debugRoute") { return }
        #endif
        guard !HomeTour.seen, d.bool(forKey: OnboardingStorage.completedKey) || d.bool(forKey: "isSetupCompleted") else { return }
        FirstHintStore.markSeen(.first)   // 「ここから、1枚目」は この 説明に 置きかえ
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { if !HomeTour.seen, !showLive { withAnimation(.easeOut(duration: 0.3)) { tourStep = 0 } } }
    }

    // MARK: カード(5ページの 横スライド + 目次)

    private struct _Unused {}
    private func scrollTop() { scrollTopTick += 1 }
    private func goPage(_ i: Int, delay: Double = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let changed = i != page
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { page = i }
            if changed { Haptics.play(.sel) }
        }
    }

    private func card(_ f: HV.Frame) -> some View {
        let cardW = f.w - 20, top: CGFloat = 178 + f.mid
        let views: [AnyView] = [
            AnyView(cameraPage(f)),
            AnyView(HVFriendsPage(input: input, cardW: cardW, actions: actions)),
            AnyView(HVTripPage(input: input, cardW: cardW, actions: actions)),
        ]
        return ZStack(alignment: .topLeading) {
            // ページは 画面の はばで 切る(# の 横の 棒が 画面の はしまで とどく ように)。中身の はばは カードの まま
            HVPager(pages: views, page: $page, width: f.w, contentWidth: cardW, onChange: { _ in Haptics.play(.sel) }, onDrag: { dragVal = $0 })
                .frame(width: f.w, height: 508)
                .offset(x: 0, y: top)
            // v131:NEXT の 下の 写真の カード 3枚(どの ページでも 同じ 所)。スクロールで 小さな 列に かわる
            HVPhotoCardsV131(model: HVCardsModel(input), page: page, width: f.w,
                             onFriends: { goPage(1) }, onTrip: { goPage(2) }, onYesterday: actions.openYesterday)
                .offset(y: 652 + f.mid)
                .opacity(mini ? 0 : 1)
                .allowsHitTesting(!mini)
                .animation(.easeOut(duration: 0.2), value: mini)
        }
    }

    /// ページ 0:カメラ(カード内の 座標 = 絶対 − (10, 178))
    private func pop(_ i: Int) -> some ViewModifier { HVCornerPop(entered: entered, index: i) }

    private func cameraPage(_ f: HV.Frame) -> some View {
        // 座標は 画面の はば いっぱい(x = 画面の x ・ y = 画面の y − 178)。レンズの 中心 = (中央, 画面の 392)
        ZStack(alignment: .topLeading) {
            HV72Hash(width: f.w, cy: 214).position(x: f.cx, y: 220)
            HV68Lens(input: input, pressing: pressing, onPress: { p in
                pressing = p
                if p { Haptics.play(.click) }
            }, onTap: {
                if input.done { Haptics.play(.click); actions.openYesterday() } else { Haptics.play(.shutter); actions.shoot() }
            })
            .position(x: f.cx, y: 426 - 178)
            // v131:レンズの 下(NEXT の 上)に ライムの 札「タップで 撮る」(押す じゃまは しない)
            if !input.done {
                Text("タップで 撮る").font(Typo.ui(800, 11.5)).tracking(Typo.em(11.5, 0.06)).foregroundStyle(Color(hex: "111113"))
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(HV.lime, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Color(hex: "0A0A0B"), lineWidth: 3).padding(-3))
                    .fixedSize()
                    .position(x: f.cx, y: 523.75 - 178)
                    .allowsHitTesting(false)
            }
            // v131:NEXT(紙の カード ・ 上から 538)
            HVNextCapsule(input: input, actions: actions, onLive: { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showLive = true } })
                .frame(width: 340).position(x: f.cx, y: 575 - 178 + 5)
        }
        .frame(width: f.w, height: 508, alignment: .topLeading)
    }

}

// MARK: - 背景

// MARK: - カードの うしろ(ぼかした 写真 + 光のもれ + かげ + 粒子)

/// フィルムの 粒子(0.9秒で 4コマ だけ ずらす)。粒の 画像は 1回 だけ 作って 使いまわす
struct HVGrain: View {
    private static let tile: UIImage = {
        let size = CGSize(width: 160, height: 160)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double((seed >> 33) & 0xFFFF) / 65535 }
            for _ in 0..<700 {
                UIColor.white.withAlphaComponent(rnd() * 0.9).setFill()
                ctx.cgContext.fill(CGRect(x: rnd() * 160, y: rnd() * 160, width: 1.4, height: 1.4))
            }
        }
    }()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.225)) { ctx in
            let k = reduceMotion || scenePhase != .active ? 0 : Int(ctx.date.timeIntervalSinceReferenceDate / 0.225) % 4
            Image(uiImage: Self.tile).resizable(resizingMode: .tile)
                .offset(x: CGFloat(k % 2) * 53, y: CGFloat(k / 2) * 71)
                .frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - レンズ(ガラスの ボタン・目盛り・3本の 弧)

// MARK: - 四すみ

/// 通知の 赤い 点(1.8秒ごとに 輪が ひろがる)
struct HVBadge: View {
    var size: CGFloat = 16
    @State private var p: Double = 0
    var body: some View {
        ZStack {
            Circle().stroke(HV.red.opacity(0.6 * (1 - p)), lineWidth: 2).frame(width: size + 18 * p, height: size + 18 * p)
            Circle().fill(HV.red).overlay(Circle().strokeBorder(.white, lineWidth: 2)).frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .loopWhileVisible(.linear(duration: 1.8).repeatForever(autoreverses: false), value: $p)   // v111:見えて いる 間 だけ
    }
}

// MARK: - 下の ピル / 上の チップ

struct HVLiveDot: View {
    @State private var p: Double = 0
    var body: some View {
        ZStack {
            Circle().stroke(HV.lime.opacity(0.5 * (1 - p)), lineWidth: 4.5 * p + 0.5).frame(width: 7 + 9 * p, height: 7 + 9 * p)
            Circle().fill(HV.lime).frame(width: 7, height: 7)
        }
        .frame(width: 7, height: 7)
        .loopWhileVisible(.linear(duration: 2.2).repeatForever(autoreverses: false), value: $p)   // v111
    }
}

// MARK: - 目次(ナビピル)

// MARK: - ヘッダーの 部品

struct HVScrollKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct HVDarkKey: EnvironmentKey { static let defaultValue: Double = 0 }
extension EnvironmentValues {
    var hvDark: Double { get { self[HVDarkKey.self] } set { self[HVDarkKey.self] = newValue } }
}

/// 四すみが レンズの 中心から ポンと とび出す(0.76秒・0.18秒後から 0.09秒ずつ)
struct HVCornerPop: ViewModifier {
    let entered: Bool
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .scaleEffect(entered || reduceMotion ? 1 : 0.2)
            .rotationEffect(.degrees(entered || reduceMotion ? 0 : -160))
            .opacity(entered || reduceMotion ? 1 : 0)
            .animation(.timingCurve(0.3, 1.1, 0.4, 1, duration: 0.76).delay(0.18 + 0.09 * Double(index)), value: entered)
    }
}

/// ライブパネル / はじめの 合図の ときだけ ぼかす(いつもは なにも かけない)
struct HVVeil: ViewModifier {
    let on: Bool
    let dim: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if on { content.blur(radius: 5).opacity(dim ? 0.55 : 1) } else { content }
    }
}

/// カードの 下の かげ(モック:0 30px 60px -24px 黒 60% = ひろがり なしで 下だけ)
struct HVCardShadow: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 40, style: .continuous).fill(Color.black.opacity(0.5))
            .padding(.horizontal, 14).padding(.vertical, 22).blur(radius: 26).offset(y: 26).allowsHitTesting(false)
    }
}

// MARK: - v131:写真の カード 3枚(NEXT の 下)と スクロール 中の 小さな 列

/// カードの 色(v114 の 3色。この カードと 小さな 列 だけに 使う)
enum HVCardTint {
    static let friends = Color(hex: "FF9CC8")
    static let trip = Color(hex: "7CCBFF")
    static let yesterday = Color(hex: "FFD84D")
    static let badge = Color(hex: "FF4D6D")
    static let ground = Color(hex: "141416")
    static let milk = Color(hex: "FAFAF7")
}

/// カード 3枚に 出す 中身(HomeV64Input から 作る)
struct HVCardsModel {
    var friendsPhoto: UIImage?
    var friendFaces: [HomeV64Face]
    var requestCount: Int
    var friendsLine: String
    var tripPhoto: UIImage?
    var tripTag: String?
    var tripLine: String
    var yesterdayPhoto: UIImage?
    var open: Bool
    var yesterdayLine: String

    @MainActor init(_ i: HomeV64Input) {
        // 友だちの カードは アイコン写真 だけ(今日の 写真 ・ モザイクは 出さない)
        friendsPhoto = i.friendsCardPhoto
        friendFaces = Array((i.requestFaces.isEmpty ? i.friends.map { HomeV64Face(id: $0.id, initial: String($0.name.prefix(1)), color: $0.color, image: $0.avatar) } : i.requestFaces).prefix(3))
        requestCount = i.requestCount
        let took = i.friends.filter { $0.shots > 0 }.count
        friendsLine = i.requestCount > 0 ? "\(i.requestCount)人 から 申請" : took > 0 ? "\(took)人 撮った" : (i.friendCount > 0 || !i.friends.isEmpty) ? "まだ だれも" : "よんで みよう"
        let cal = Calendar.current
        let live = i.tripItems.first { TripHubRules.phase(start: $0.start, end: $0.end, created: $0.created, now: i.now).phase == .live }
        tripPhoto = live?.cover
        if let live, let st = live.start, let en = live.end {
            tripTag = "DAY \(TripHubRules.dayNumber(start: st, now: i.now, cal: cal)) / \(TripHubRules.totalDays(start: st, end: en, cal: cal))"
        }
        tripLine = live.map { "\($0.name) ・ いま" } ?? "つくる"
        yesterdayPhoto = i.yesterdayThumbs.first?.image ?? i.yesterdayPhoto
        open = cal.component(.hour, from: i.now) >= 9
        yesterdayLine = open ? "ひらいた" : "9:00 に ひらく"
    }
}

struct HVPhotoCardsV131: View {
    let model: HVCardsModel
    /// いま ひらいて いる ページ(1 = Friends ・ 2 = Trip)
    let page: Int
    let width: CGFloat
    let onFriends: () -> Void
    let onTrip: () -> Void
    let onYesterday: () -> Void

    var body: some View {
        let w = (width - 32 - 20) / 3
        HStack(spacing: 10) {
            card(title: "Friends", size: 34, tint: HVCardTint.friends, on: page == 1, w: w, photo: model.friendsPhoto, tinted: true, locked: false, line: model.friendsLine, label: "Friends") {
                HStack(spacing: 0) {
                    HStack(spacing: -8) {
                        ForEach(model.friendFaces) { f in
                            HVCardFace(face: f).frame(width: 24, height: 24).overlay(Circle().strokeBorder(HVCardTint.ground, lineWidth: 2).padding(-2))
                        }
                    }
                    Spacer(minLength: 0)
                    if model.requestCount > 0 {
                        Text(verbatim: "\(model.requestCount)").font(Typo.ui(800, 11)).foregroundStyle(.white)
                            .padding(.horizontal, 6).frame(minWidth: 20, minHeight: 20).background(HVCardTint.badge, in: Capsule())
                    }
                }
            } action: { onFriends() }
            card(title: "Trip", size: 46, tint: HVCardTint.trip, on: page == 2, w: w, photo: model.tripPhoto, tinted: false, locked: false, line: model.tripLine, label: "Trip") {
                HStack {
                    Spacer(minLength: 0)
                    if let tag = model.tripTag {
                        Text(tag).font(Typo.ui(800, 10.5)).foregroundStyle(HVCardTint.trip).lineLimit(1)
                            .padding(.horizontal, 7).frame(height: 20).background(Color(hex: "111113").opacity(0.72), in: Capsule())
                    }
                }
            } action: { onTrip() }
            card(title: "Yesterday", size: 30, tint: HVCardTint.yesterday, on: false, w: w, photo: model.yesterdayPhoto, tinted: false, locked: !model.open, line: model.yesterdayLine, label: "Yesterday") {
                EmptyView()
            } action: { onYesterday() }
        }
        .padding(.horizontal, 16)
        .frame(width: width)
    }

    private func card<Top: View>(title: String, size: CGFloat, tint: Color, on: Bool, w: CGFloat, photo: UIImage?, tinted: Bool, locked: Bool, line: String, label: String,
                                 @ViewBuilder top: () -> Top, action: @escaping () -> Void) -> some View {
        Button { Haptics.play(.pop); action() } label: {
            ZStack(alignment: .bottomLeading) {
                HVCardTint.ground
                if let photo {
                    // 9:00 まえ:小さく して 1回 だけ ぼかした 画像(毎フレーム ぼかさない)
                    Image(uiImage: locked ? HVCardBlur.locked(photo) : photo).resizable().scaledToFill()
                        .frame(width: w, height: 120).clipped()
                    if tinted { tint.opacity(0.3).blendMode(.softLight) }
                } else if locked {
                    Color(hex: "1C1C1F")
                }
                LinearGradient(stops: [.init(color: Color(hex: "0A0A0B").opacity(0), location: 0.25), .init(color: Color(hex: "0A0A0B").opacity(0.15), location: 0.45), .init(color: Color(hex: "0A0A0B").opacity(0.82), location: 1)], startPoint: .top, endPoint: .bottom)
                if locked {
                    ZStack {
                        Circle().fill(Color(hex: "111113").opacity(0.7))
                        Image(systemName: "lock").font(.system(size: 13, weight: .bold)).foregroundStyle(HVCardTint.milk)
                    }
                    .frame(width: 30, height: 30)
                    .position(x: w / 2, y: 120 * 0.38)
                }
                top().padding(.horizontal, 10).frame(maxHeight: .infinity, alignment: .top).padding(.top, 10)
                VStack(alignment: .leading, spacing: 5) {
                    Text(verbatim: title).font(Typo.title(size)).tracking(Typo.em(size, -0.02)).foregroundStyle(HVCardTint.milk)
                        .lineLimit(1).minimumScaleFactor(16 / size)
                        .shadow(color: .black.opacity(0.45), radius: 6, y: 2)
                    HStack(spacing: 5) {
                        Circle().fill(tint).frame(width: 6, height: 6).shadow(color: tint, radius: 3)
                        Text(line).font(Typo.ui(800, 10.5)).tracking(Typo.em(10.5, 0.02)).foregroundStyle(Color(hex: "E9E9EC")).lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                .padding(.horizontal, 11).padding(.bottom, 11)
            }
            .frame(width: w, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(on ? tint : .white.opacity(0.12), lineWidth: on ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(HVCardPress())
        .accessibilityLabel(label)
    }
}

/// 押すと 0.95 → ばね(cubic-bezier(.34,1.56,.64,1) .25s)
struct HVCardPress: ButtonStyle {
    var scale: CGFloat = 0.95
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.timingCurve(0.34, 1.56, 0.64, 1, duration: 0.25), value: configuration.isPressed)
    }
}

/// 人の 丸(写真 か 名前の 1文字 + 色)
struct HVCardFace: View {
    let face: HomeV64Face
    var body: some View {
        ZStack {
            Circle().fill(face.color)
            if let img = face.image { Image(uiImage: img).resizable().scaledToFill().clipShape(Circle()) }
            else { Text(face.initial).font(Typo.ui(800, 11)).foregroundStyle(Color(hex: "111113")) }
        }
    }
}

/// 9:00 まえの きのうの カード:64px に 縮めて 1回 だけ ぼかす(blur 7 ・ 彩度 0.6 ・ 明るさ 0.8)。結果は キャッシュ
enum HVCardBlur {
    @MainActor private static var cache: [ObjectIdentifier: UIImage] = [:]
    @MainActor static func locked(_ src: UIImage) -> UIImage {
        let key = ObjectIdentifier(src)
        if let c = cache[key] { return c }
        let out = make(src) ?? src
        if cache.count > 8 { cache.removeAll() }
        cache[key] = out
        return out
    }
    private static func make(_ src: UIImage) -> UIImage? {
        let side: CGFloat = 64
        let scale = side / max(1, max(src.size.width, src.size.height))
        let size = CGSize(width: max(1, src.size.width * scale), height: max(1, src.size.height * scale))
        let small = UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }()).image { _ in src.draw(in: CGRect(origin: .zero, size: size)) }
        guard let ci = CIImage(image: small) else { return nil }
        let blurred = ci.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 3.8])
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.6])
            .applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: 0.8, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 0.8, z: 0, w: 0), "inputBVector": CIVector(x: 0, y: 0, z: 0.8, w: 0)])
            .cropped(to: ci.extent)
        guard let cg = CIContext(options: [.useSoftwareRenderer: false]).createCGImage(blurred, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// v120 / v131:150pt より 下へ スクロール した 時の 小さな 列(黒い 丸 + 色の 絵 × 3 + ↑)
struct HVMiniRowV131: View {
    let requestCount: Int
    let onSelect: (Int) -> Void
    let onUp: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            dot(.friends, tint: HVCardTint.friends, label: "Friends", badge: requestCount) { onSelect(1) }
            dot(.trip, tint: HVCardTint.trip, label: "Trip", badge: 0) { onSelect(2) }
            dot(.yesterday, tint: HVCardTint.yesterday, label: "Yesterday", badge: 0) { onSelect(3) }
            Button { Haptics.play(.tick); onUp() } label: {
                ZStack {
                    Circle().fill(Color(hex: "2A2A2F"))
                    Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold)).foregroundStyle(HVCardTint.milk)
                }
                .frame(width: 38, height: 38).frame(width: 44, height: 44).contentShape(Circle())
            }
            .buttonStyle(HVCardPress(scale: 0.9))
            .accessibilityLabel("上へ もどる")
        }
        .padding(.leading, 12).padding(.trailing, 10).padding(.top, 8).padding(.bottom, 6)
        .background(Color(red: 22 / 255, green: 22 / 255, blue: 24 / 255).opacity(0.94), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.9), radius: 17, y: 16)
    }

    private func dot(_ kind: HVIconKind, tint: Color, label: String, badge: Int, _ action: @escaping () -> Void) -> some View {
        Button { Haptics.play(.pop); action() } label: {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle().fill(Color(hex: "1C1C1F"))
                    Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    HVIcon(kind: kind, size: 21, color: tint)
                }
                .frame(width: 46, height: 46)
                if badge > 0 {
                    Text(verbatim: "\(badge)").font(Typo.ui(800, 10.5)).foregroundStyle(.white)
                        .padding(.horizontal, 4).frame(minWidth: 18, minHeight: 18)
                        .background(HVCardTint.badge, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color(hex: "161618"), lineWidth: 2).padding(-2))
                        .offset(x: 5, y: -5)
                }
            }
            .padding(.bottom, 4)
            .contentShape(Circle())
        }
        .buttonStyle(HVCardPress(scale: 0.88))
        .accessibilityLabel(label)
    }
}
