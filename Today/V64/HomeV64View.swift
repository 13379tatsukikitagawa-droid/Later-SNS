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
    /// うしろに ぼかして 敷く 写真(友だちの 今日 → 自分の きのう → なし)
    var backdrop: [UIImage] = []
    /// 3枚 撮りおわった とき、まんなかの 窓に 出す きのうの 写真
    var yesterdayPhoto: UIImage?
    var friends: [HomeV64Friend] = []
    var requestFaces: [HomeV64Face] = []
    var requests: [HomeV64Request] = []
    var yesterdayThumbs: [HomeV64Thumb] = []
    var trip: HomeV64TripInfo? = nil
    var tripSamples: [UIImage] = []
    var mondo = HomeV64MondoInfo()
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
    var openMondo: () -> Void = {}
    var openProfile: () -> Void = {}
    var openDevelop: () -> Void = {}
    var openLive: () -> Void = {}
    var addFriends: () -> Void = {}
    var scrollToToday: () -> Void = {}
    var scanQR: () -> Void = {}
    var openRequests: () -> Void = {}
    var openChat: (_ friendID: String, _ name: String) -> Void = { _, _ in }
    var approve: (_ requestID: String) -> Void = { _ in }
    var dismissRequest: (_ requestID: String) -> Void = { _ in }
    var poke: (_ friendID: String) -> Void = { _ in }
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
                            VStack(spacing: 0) { Color.clear.frame(width: 1, height: input.debugScroll); Color.clear.frame(width: 1, height: 1).id("dbg"); Spacer(minLength: 0) }.frame(width: 1)
                            VStack(spacing: 0) {
                                Color.clear.frame(height: 810 + 2 * f.mid)
                                HVLowerSections(input: input, data: input.lower, actions: actions).frame(width: f.w)
                            }
                        }
                        }
                    .onChange(of: wantsToday) { _, _ in withAnimation(.easeInOut(duration: 0.6)) { proxy.scrollTo("today", anchor: .top) } }
                    .onScrollGeometryChange(for: CGFloat.self) { max(0, $0.contentOffset.y + $0.contentInsets.top) } action: { _, new in
                        scrollY = new
                        let want = new > 60
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
                               onYesterday: actions.openYesterday, onProfile: actions.openProfile,
                               onLive: { actions.openLive(); withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showLive = true } })
                }
                .modifier(HVVeil(on: input.spotlight || showLive, dim: input.spotlight))
                .animation(.easeOut(duration: 0.35), value: input.spotlight)
                moon(f)
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
        .sheet(isPresented: $showWidgetGuide) { WidgetGuideV96Sheet { showWidgetGuide = false } }
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
            AnyView(HVMondoPage(input: input, cardW: cardW, actions: actions)),
        ]
        return ZStack(alignment: .topLeading) {
            // ページは 画面の はばで 切る(# の 横の 棒が 画面の はしまで とどく ように)。中身の はばは カードの まま
            HVPager(pages: views, page: $page, width: f.w, contentWidth: cardW, onChange: { _ in Haptics.play(.sel) }, onDrag: { dragVal = $0 })
                .frame(width: f.w, height: 508)
                .offset(x: 0, y: top)
            // 目次(ページに 重ねる)
            HVDock(selected: page) { i in goPage(i) }
                .position(x: f.cx, y: 650 + f.mid)
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
            .position(x: f.cx, y: 214)
            // v95-8:NEXT(レンズの すぐ 下 ・ 画面の 上 514)
            HVNextCapsule(input: input, actions: actions, onLive: { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showLive = true } })
                .frame(width: 318).position(x: f.cx, y: 514 - 178 + 34)
        }
        .frame(width: f.w, height: 508, alignment: .topLeading)
    }

    // MARK: 月(今日を撮る)

    private func moon(_ f: HV.Frame) -> some View {
        let d = MoonLayout.diameter(screenWidth: f.w)
        let top = 712 + 2 * f.mid
        return ZStack(alignment: .top) {
            HVMoon(input: input, d: d) { Haptics.play(.click); if input.done { actions.openYesterday() } else { actions.shoot() } }
                .frame(width: d, height: d)
                .position(x: f.cx, y: top + d / 2)
            if input.showHint {
                HVHintBubble(text: "撮ると、きのうが 1枚 ひらく").position(x: f.cx, y: 694.2 + 19 + 2 * f.mid)
            }
        }
        .frame(width: f.w, height: f.h, alignment: .top)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var size: CGFloat = 16
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { ctx in
            let p = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8) / 1.8
            ZStack {
                Circle().stroke(HV.red.opacity(0.6 * (1 - p)), lineWidth: 2).frame(width: size + 18 * p, height: size + 18 * p)
                Circle().fill(HV.red).overlay(Circle().strokeBorder(.white, lineWidth: 2)).frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 下の ピル / 上の チップ

struct HVLiveDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { ctx in
            let p = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.2) / 2.2
            ZStack {
                Circle().stroke(HV.lime.opacity(0.5 * (1 - p)), lineWidth: 4.5 * p + 0.5).frame(width: 7 + 9 * p, height: 7 + 9 * p)
                Circle().fill(HV.lime).frame(width: 7, height: 7)
            }
        }
        .frame(width: 7, height: 7)
    }
}

// MARK: - 目次(ナビピル)

struct HVDock: View {
    let selected: Int
    let onSelect: (Int) -> Void
    @Namespace private var ns
    // Camera は # の 画面。そこでは 出さない(v79)。ほかの ページでは 左に 小さな 丸(字 なし)= Camera へ もどる
    private let items: [(Int, HVIconKind, String)] = [(1, .friends, "Friends"), (2, .trip, "Trip"), (3, .mondo, "Mondo")]

    var body: some View {
        HStack(spacing: 4) {
            if selected != 0 {
                Button { Haptics.play(.tick); onSelect(0) } label: {
                    ZStack {
                        Circle().stroke(.white.opacity(0.78), lineWidth: 1.8).frame(width: 16.4, height: 16.4)
                        Circle().fill(.white.opacity(0.78)).frame(width: 7.2, height: 7.2)
                    }
                    .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(HVPress(scale: 1.08))
                .accessibilityLabel("Camera")
            }
            ForEach(items, id: \.0) { item in
                let on = item.0 == selected
                Button { Haptics.play(.tick); onSelect(item.0) } label: {
                    HStack(spacing: 7) {
                        HVIcon(kind: item.1, size: 20, color: on ? HV.ink : .white.opacity(0.78))
                        if on { Text(item.2.uppercased()).font(LF.mono(10)).tracking(1.2).foregroundStyle(HV.ink).fixedSize() }
                    }
                    .padding(.leading, on ? 13 : 12).padding(.trailing, on ? 16 : 12)
                    .frame(height: 44).frame(minWidth: 44)
                    .background {
                        if on {
                            Capsule().fill(HV.lime)
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.55), lineWidth: 1.5).mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.2))))
                                .shadow(color: Color(red: 140 / 255, green: 190 / 255, blue: 40 / 255).opacity(0.6), radius: 7, y: 6)
                                .matchedGeometryEffect(id: "mark", in: ns)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(HVPress(scale: 1.08))
                .accessibilityLabel("ページ、\(item.2)")
            }
        }
        .padding(.horizontal, selected == 0 ? 10 : 4).padding(.vertical, 4)
        .hvGlass(radius: 26, tint: 0.13)
        .shadow(color: .black.opacity(0.8), radius: 16, y: 16)
        .animation(.spring(response: 0.44, dampingFraction: 0.72), value: selected)
    }
}

// MARK: - ヘッダーの 部品

struct HVAvatar: View {
    let input: HomeV64Input
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                // 外側 7pt の 輪:今日 撮った 枚数 ÷ 3 だけ 緑
                Circle().stroke(Color.black.opacity(0.10), lineWidth: 2.5).frame(width: 60, height: 60)
                Circle().trim(from: 0, to: CGFloat(min(1, Double(input.shotsUsed) / Double(max(1, input.limit)))))
                    .stroke(HV.green, style: StrokeStyle(lineWidth: 2.5, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 60, height: 60)
                    .animation(.easeOut(duration: 0.6), value: input.shotsUsed)
                ZStack {
                    if let img = input.avatar { Image(uiImage: img).resizable().scaledToFill() }
                    else { HVDefaultAvatar() }
                }
                .frame(width: 46, height: 46).clipShape(Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                .overlay(Circle().strokeBorder(Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255).opacity(0.08), lineWidth: 1).padding(-3.5))
                .shadow(color: HV.green.opacity(0.55), radius: 11, y: 10)
                if input.avatarBadge {
                    Circle().fill(HV.red).overlay(Circle().strokeBorder(.white, lineWidth: 2)).frame(width: 13, height: 13).offset(x: 18, y: -20)
                }
            }
            .frame(width: 70, height: 70)
            .contentShape(Circle())
        }
        .buttonStyle(HVPress(scale: 0.94))
        .offset(x: -12, y: -12)   // 外へ 12pt ひろげた 押せる 範囲
        .accessibilityLabel("Profile")
    }
}

/// 初期の アバター(みどりの 顔)
struct HVDefaultAvatar: View {
    var body: some View {
        ZStack {
            Circle().fill(Color(hex: "5ED67A"))
            HStack(spacing: 9) { Circle().fill(HV.ink).frame(width: 5.5, height: 5.5); Circle().fill(HV.ink).frame(width: 5.5, height: 5.5) }.offset(y: -4)
            Capsule().fill(Color(hex: "F59BB8").opacity(0.9)).frame(width: 7, height: 5).offset(x: -13, y: 3)
            Capsule().fill(Color(hex: "F59BB8").opacity(0.9)).frame(width: 7, height: 5).offset(x: 13, y: 3)
            Circle().trim(from: 0.1, to: 0.4).stroke(HV.ink, style: StrokeStyle(lineWidth: 2.2, lineCap: .round)).frame(width: 14, height: 14).rotationEffect(.degrees(30)).offset(y: 3)
        }
    }
}

// MARK: - 月(今日を撮る)

struct HVMoon: View {
    let input: HomeV64Input
    let d: CGFloat
    let action: () -> Void
    @State private var pressing = false

    var body: some View {
        let title: String = { switch input.shotsUsed { case 0: return "今日を撮る"; case 1, 2: return "もう1枚 撮る"; default: return "9:00に、ひらきます" } }()
        let sub: String = input.done ? "あした 9:00 に ひらく" : "のこり \(input.remaining)こま"
        Button(action: action) {
            ZStack(alignment: .top) {
                Circle().fill(LinearGradient(stops: [.init(color: Color(hex: "1E6A33"), location: 0), .init(color: Color(hex: "0E3A1B"), location: 0.22), .init(color: Color(hex: "07190C"), location: 0.52), .init(color: Color(hex: "040A06"), location: 1)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color(red: 59 / 255, green: 211 / 255, blue: 90 / 255).opacity(0.35), radius: 30, y: -14)
                HV72DomeGlobe(d: d, pressing: pressing)
                Circle().strokeBorder(HV.lime.opacity(0.55), lineWidth: 1)
                HVRim(radius: d / 2, width: 1.2).opacity(0.6)
                VStack(spacing: 15) {
                    HStack(spacing: 9) {
                        if !input.done { HVCameraGlyph(width: 26, line: 1.8, color: .white, showsFlash: false) }
                        Text(title).font(LF.inter(800, 21)).tracking(-0.21).foregroundStyle(input.done ? .white.opacity(0.6) : .white).shadow(color: .black.opacity(0.75), radius: 7, y: 2)
                    }
                    .frame(height: 30)
                    HStack(spacing: 8) {
                        if !input.done {
                            HStack(spacing: 4) {
                                ForEach(0..<3, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 3).fill(i < input.remaining ? HV.lime : .white.opacity(0.2)).frame(width: 14, height: 6)
                                }
                            }
                        }
                        Text(sub).font(LF.mono(10.5)).tracking(1.47).foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(height: 16)
                }
                .padding(.top, 28)
                .offset(y: pressing ? -4 : 0)
            }
            .frame(width: d, height: d)
            .scaleEffect(pressing ? 1.015 : 1)
            .contentShape(Circle())
        }
        .buttonStyle(HVPress(scale: 1.0, onPress: { pressing = $0 }))
        .accessibilityLabel(title)
    }
}

struct HVHintBubble: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Color(hex: "25A93F")).frame(width: 8, height: 8)
            Text(text).font(LF.inter(800, 13.5)).tracking(-0.135).foregroundStyle(.white).fixedSize()
        }
        .padding(.leading, 12).padding(.trailing, 16).frame(height: 38)
        .background(Color(hex: "111111"), in: Capsule())
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(hex: "111111")).frame(width: 14, height: 14).clipShape(RoundedRectangle(cornerRadius: 3)).rotationEffect(.degrees(45)).offset(y: 7)
        }
        .shadow(color: .black.opacity(0.55), radius: 14, y: 12)
        .allowsHitTesting(false)
    }
}

// MARK: - スクロールの 位置 / 暗さ(ヘッダーの 配色)

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
