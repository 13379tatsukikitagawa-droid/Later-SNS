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
    var yesterdayThumbs: [HomeV64Thumb] = []
    var trip: HomeV64TripInfo? = nil
    var tripSamples: [UIImage] = []
    var mondo = HomeV64MondoInfo()
    var lower = HomeV64LowerData()
    var debugScroll: CGFloat = 0
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
    var openMondo: () -> Void = {}
    var openProfile: () -> Void = {}
    var openDevelop: () -> Void = {}
    var openLive: () -> Void = {}
    var addFriends: () -> Void = {}
    var scrollToToday: () -> Void = {}
    var scanQR: () -> Void = {}
    var openRequests: () -> Void = {}
    var openChat: (_ friendID: String, _ name: String) -> Void = { _, _ in }
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

    @State private var scrollY: CGFloat = 0

    var body: some View {
        GeometryReader { g in
            let f = HV.Frame(w: g.size.width, h: g.size.height)
            let dark = Double(min(1, max(0, (scrollY - 160) / 260)))
            ZStack(alignment: .topLeading) {
                HVL.bg
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        ZStack(alignment: .topLeading) {
                            VStack(spacing: 0) { Color.clear.frame(width: 1, height: input.debugScroll); Color.clear.frame(width: 1, height: 1).id("dbg"); Spacer(minLength: 0) }.frame(width: 1)
                            VStack(spacing: 0) {
                                HVBackground(f: f).frame(width: f.w, height: 1125 + 2 * f.mid)
                                HVLowerSections(input: input, data: input.lower, actions: actions)
                                    .frame(width: f.w).offset(y: -(1125 + 2 * f.mid - (810 + 2 * f.mid))).padding(.bottom, -(1125 + 2 * f.mid - (810 + 2 * f.mid)))
                            }
                        }
                    }
                    .onChange(of: wantsToday) { _, _ in withAnimation(.easeInOut(duration: 0.6)) { proxy.scrollTo("today", anchor: .top) } }
                    .onScrollGeometryChange(for: CGFloat.self) { max(0, $0.contentOffset.y + $0.contentInsets.top) } action: { _, new in scrollY = new }
                    .onAppear { if input.debugScroll > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { proxy.scrollTo("dbg", anchor: .top) } } }
                }
                // 上の ブロック(ページの 5まい)は 上へ ながれて うすく なる
                Group {
                    Group { card(f) }
                        .offset(y: -scrollY).opacity((1 - Double(min(1, scrollY / 420))) * (entered || reduceMotion ? 1 : 0))
                        .scaleEffect(entered || reduceMotion ? 1 : 1.06)
                        .allowsHitTesting(scrollY < 120)
                    header(f, dark: dark)
                }
                .blur(radius: input.spotlight || showLive ? 5 : 0).opacity(input.spotlight ? 0.55 : 1)
                .animation(.easeOut(duration: 0.35), value: input.spotlight)
                moon(f)
                if showLive { HVLivePanel(input: input, onClose: { withAnimation(.easeOut(duration: 0.25)) { showLive = false } }, onShoot: actions.shoot).zIndex(10) }
            }
            .frame(width: f.w, height: f.h, alignment: .topLeading)
            .environment(\.hvDark, dark)
        }
        .ignoresSafeArea()
        .onAppear {
            if !pageSeeded { page = input.page; pageSeeded = true; if input.openLiveAtStart { showLive = true } }
            if !entered { withAnimation(.timingCurve(0.2, 0.8, 0.3, 1, duration: 0.9)) { entered = true }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.64) { Haptics.play(.tick) } }
        }
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
            AnyView(cameraPage(f, cardW: cardW)),
            AnyView(HVFriendsPage(input: input, cardW: cardW, actions: actions)),
            AnyView(HVTripPage(input: input, cardW: cardW, actions: actions)),
            AnyView(HVMondoPage(input: input, cardW: cardW, actions: actions)),
            AnyView(HVYesterdayPage(input: input, cardW: cardW, actions: actions)),
        ]
        return ZStack(alignment: .topLeading) {
            HVPager(pages: views, page: $page, width: cardW, onChange: { _ in Haptics.play(.sel) })
                .frame(width: cardW, height: 508)
                .offset(x: 10, y: top)
            // 目次(ページに 重ねる)
            HVDock(selected: page) { i in goPage(i) }
                .position(x: f.cx, y: 650 + f.mid)
        }
    }

    /// ページ 0:カメラ(カード内の 座標 = 絶対 − (10, 178))
    private func pop(_ i: Int) -> some ViewModifier { HVCornerPop(entered: entered, index: i) }

    private func cameraPage(_ f: HV.Frame, cardW: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            HVCardBackdrop(images: input.backdrop, focus: pressing || input.pressedFocus, done: input.done, night: input.isNight)
                .frame(width: cardW, height: 508)
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 1))
                .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 1.5).mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.04))))
                .shadow(color: .black.opacity(0.35), radius: 40, y: 22)

            HVStar().offset(x: 14, y: 12)
            HVSquiggle().offset(x: cardW - 60.3, y: 26.4)

            HVLens(input: input, pressing: pressing, onPress: { p in
                pressing = p
                if p { Haptics.play(.click) }
            }, onTap: {
                if input.done { Haptics.play(.click); actions.openYesterday() } else { Haptics.play(.shutter); actions.shoot() }
            })
            .position(x: cardW / 2, y: 254)
            HVFlower().offset(x: cardW / 2 + 49 - 18, y: 140 - 18 + 18)

            HVChip(input: input, onTap: { Haptics.play(.sel); goPage(1) }, onAdd: { Haptics.play(.sel); actions.addFriends() })
                .position(x: cardW / 2, y: 36)

            HVCorner(kind: .yesterday, label: "YESTERDAY", locked: input.locked, badge: false) { goPage(4, delay: 0.12) }
                .modifier(pop(0)).position(x: 52, y: 108)
            HVCorner(kind: .trip, label: "TRIP", locked: false, badge: false) { goPage(2, delay: 0.12) }
                .modifier(pop(1)).position(x: cardW - 52, y: 108)
            HVCorner(kind: .mondo, label: "MONDO", locked: input.locked, badge: false) { goPage(3, delay: 0.12) }
                .modifier(pop(2)).position(x: 52, y: 382)
            HVCorner(kind: .friends, label: "FRIENDS", locked: false, badge: input.requestCount > 0) { goPage(1, delay: 0.12) }
                .modifier(pop(3)).position(x: cardW - 52, y: 382)

            HVPill(input: input) {
                if input.shotsUsed == 0 { Haptics.play(.sel); actions.scrollToToday(); wantsToday += 1 } else { Haptics.play(.pop); actions.openDevelop() }
            }
            .position(x: cardW / 2, y: 382)
        }
        .frame(width: cardW, height: 508, alignment: .topLeading)
    }

    // MARK: ヘッダー

    private func header(_ f: HV.Frame, dark: Double) -> some View {
        let bg = Color(red: 239 / 255 * (1 - dark) + 10 / 255 * dark, green: 239 / 255 * (1 - dark) + 10 / 255 * dark, blue: 234 / 255 * (1 - dark) + 11 / 255 * dark)
        return ZStack(alignment: .topLeading) {
            LinearGradient(stops: [.init(color: bg, location: 0.74), .init(color: bg.opacity(0), location: 1)], startPoint: .top, endPoint: .bottom)
                .frame(width: f.w, height: 150).allowsHitTesting(false)
            Text(Brand.name).font(LF.inter(900, 32)).tracking(-2.08).foregroundStyle(dark > 0.5 ? .white : HV.ink).offset(x: 22, y: 63 - 1)
            HVTodaySwitch(onYesterday: { Haptics.play(.sel); actions.openYesterday() }).offset(x: 121.6, y: 60)
            HVAvatar(input: input) { Haptics.play(.sel); actions.openProfile() }.offset(x: f.w - 68, y: 56)
            HVLivePill(input: input) { Haptics.play(.click); actions.openLive(); withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showLive = true } }.offset(x: 16, y: 106)
        }
        .frame(width: f.w, height: f.h, alignment: .topLeading)
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

struct HVBackground: View {
    let f: HV.Frame
    var body: some View {
        ZStack(alignment: .topLeading) {
            HV.bg
            glow(Color(red: 89 / 255, green: 219 / 255, blue: 115 / 255), a: 0.22, size: 392, x: f.xr(173.6), y: 100.7)
            glow(Color(red: 135 / 255, green: 229 / 255, blue: 154 / 255), a: 0.16, size: 407.5, x: f.x(-167.8), y: 428 + f.mid)
            // 下の 夕ぐれ(月の うしろ):うすい 白 → みどり → 黒
            LinearGradient(stops: [
                .init(color: HV.bg.opacity(0), location: 0), .init(color: Color(red: 227 / 255, green: 238 / 255, blue: 227 / 255), location: 0.12),
                .init(color: Color(red: 158 / 255, green: 214 / 255, blue: 165 / 255), location: 0.26), .init(color: Color(red: 36 / 255, green: 160 / 255, blue: 60 / 255), location: 0.40),
                .init(color: Color(red: 21 / 255, green: 100 / 255, blue: 40 / 255), location: 0.54), .init(color: Color(red: 11 / 255, green: 42 / 255, blue: 19 / 255), location: 0.68),
                .init(color: Color(hex: "060F08"), location: 0.82), .init(color: Color(hex: "0A0A0B"), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            .frame(width: f.w, height: 433.5).offset(y: 692 + 2 * f.mid)
        }
        .frame(width: f.w, height: f.h, alignment: .topLeading)
        .clipped()
        .allowsHitTesting(false)
    }

    private func glow(_ c: Color, a: Double, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        RadialGradient(colors: [c.opacity(a), c.opacity(0)], center: .center, startRadius: 0, endRadius: size * 0.34)
            .frame(width: size, height: size).offset(x: x, y: y)
    }
}

// MARK: - カードの うしろ(ぼかした 写真 + 光のもれ + かげ + 粒子)

struct HVCardBackdrop: View {
    let images: [UIImage]
    var focus: Bool
    var done: Bool
    var night: Bool

    var body: some View {
        ZStack {
            HV.cardBase
            if let img = images.first {
                // カードより 16% 大きく(ふちが 見えない ように)。押している 間は ぼかし 15 → 5・明るさ 0.66 → 0.76
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 520, height: 712)
                    .blur(radius: focus ? 5 : (done ? 9 : 15))
                    .saturation(1.35)
                    // 明るさ 0.66(押している 間 0.76・撮りおわり 0.62)= 黒を 重ねて 掛け算に
                    .overlay(Color.black.opacity(focus ? 0.24 : (done ? 0.38 : 0.34)))
                    .animation(.timingCurve(0.3, 0.7, 0.3, 1, duration: 0.55), value: focus)
            }
            // 光の もれ(右上)
            RadialGradient(colors: [Color(hex: "FFB070").opacity(0.5), Color(hex: "FFB070").opacity(0)], center: .center, startRadius: 0, endRadius: 170)
                .frame(width: 333, height: 386).offset(x: 110, y: -150).opacity(0.39).blendMode(.screen)
            // かげ(四すみ + 上下)
            RadialGradient(colors: [.clear, .clear, .black.opacity(0.5)], center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: 330)
            LinearGradient(stops: [.init(color: .black.opacity(0.38), location: 0), .init(color: .clear, location: 0.24), .init(color: .clear, location: 0.64), .init(color: .black.opacity(0.55), location: 1)], startPoint: .top, endPoint: .bottom)
            HVGrain().opacity(0.17).blendMode(.overlay)
        }
    }
}

/// フィルムの 粒子(0.9秒で 4コマ だけ ずらす)
struct HVGrain: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.225)) { ctx in
            let k = Int(ctx.date.timeIntervalSinceReferenceDate / 0.225) % 4
            Canvas { c, size in
                var seed = UInt64(k + 1) &* 0x9E3779B97F4A7C15
                func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double((seed >> 33) & 0xFFFF) / 65535 }
                for _ in 0..<2200 {
                    let x = rnd() * size.width, y = rnd() * size.height, a = rnd()
                    c.fill(Path(CGRect(x: x, y: y, width: 1.4, height: 1.4)), with: .color(Color.white.opacity(a * 0.9)))
                }
            }
            .drawingGroup()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - レンズ(ガラスの ボタン・目盛り・3本の 弧)

struct HVLens: View {
    let input: HomeV64Input
    let pressing: Bool
    let onPress: (Bool) -> Void
    let onTap: () -> Void
    private let D: CGFloat = 201.2

    var body: some View {
        ZStack {
            // ガラス
            Circle().fill(Color.white.opacity(0.10))
                .overlay(Circle().fill(Color.white.opacity(0.08)).blendMode(.plusLighter))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.55), lineWidth: 2.6))
                .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.32), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.08)), lineWidth: 4))
                .overlay(Circle().fill(RadialGradient(colors: [.clear, .black.opacity(0.22)], center: UnitPoint(x: 0.5, y: 0.1), startRadius: 60, endRadius: 150)).blendMode(.multiply))
                .shadow(color: .black.opacity(0.75), radius: 24, y: 28)
            HVRim(radius: D / 2, width: 2)
            // 目盛りと 弧
            HVLensDial(shotsUsed: input.shotsUsed, limit: input.limit, rotation: pressing ? 12 : 0)
            // まんなか:カメラの 絵 / 3枚 撮りおわり = きのうの 窓
            if input.done {
                ZStack {
                    Circle().fill(Color(hex: "1A1614"))
                    if let img = input.yesterdayPhoto { Image(uiImage: img).resizable().scaledToFill().clipShape(Circle()) }
                    Circle().fill(RadialGradient(colors: [.black.opacity(0.25), .black.opacity(0.55)], center: .center, startRadius: 0, endRadius: 72))
                    Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1.7)
                    HVStackGlyph(size: 54, color: .white, line: 3)
                }
                .frame(width: 143, height: 143)
            } else {
                HVCameraGlyph(width: 52, line: 3.3, aperture: pressing ? 0.45 : 1)
                    .shadow(color: .black.opacity(0.28), radius: 7, y: 4)
                    .animation(.timingCurve(0.3, 1.5, 0.5, 1, duration: 0.3), value: pressing)
            }
        }
        .frame(width: D, height: D)
        .scaleEffect(pressing ? 192 / 201 : 1)
        .animation(.timingCurve(0.3, 1.4, 0.5, 1, duration: 0.28), value: pressing)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { _ in if !pressing { onPress(true) } }.onEnded { v in
            onPress(false)
            if abs(v.translation.width) < 12 && abs(v.translation.height) < 12 { onTap() }
        })
        .accessibilityElement()
        .accessibilityLabel(input.done ? "Yesterday を ひらく" : "撮る。あと \(input.remaining) 枚")
        .accessibilityAddTraits(.isButton)
    }
}

struct HVLensDial: View {
    let shotsUsed: Int, limit: Int, rotation: Double
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            // 目盛り 60本(5本ごとに 長く)
            for i in 0..<60 {
                let a = Double(i) * .pi / 30 - .pi / 2 + rotation * .pi / 180
                let long = i % 5 == 0
                let r0: CGFloat = long ? 80.6 : 84.6, r1: CGFloat = 88
                var p = Path()
                p.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * r0, y: c.y + CGFloat(sin(a)) * r0))
                p.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * r1, y: c.y + CGFloat(sin(a)) * r1))
                ctx.stroke(p, with: .color(.white.opacity(long ? 0.75 : 0.34)), style: StrokeStyle(lineWidth: long ? 1.2 : 0.9, lineCap: .round))
            }
            // 3本の 弧(のこり = 白 + 光、使った = 白 22%)。上から 時計まわり・1本 = 92°(間 28°)
            for i in 0..<3 {
                let start = -76.0 + Double(i) * 120
                var p = Path()
                p.addArc(center: c, radius: 93.5, startAngle: .degrees(start), endAngle: .degrees(start + 92), clockwise: false)
                let used = i < shotsUsed
                if !used {
                    ctx.drawLayer { l in
                        l.addFilter(.shadow(color: .white.opacity(0.7), radius: 4))
                        l.stroke(p, with: .color(.white), style: StrokeStyle(lineWidth: 5.2, lineCap: .round))
                    }
                } else {
                    ctx.stroke(p, with: .color(.white.opacity(0.22)), style: StrokeStyle(lineWidth: 5.2, lineCap: .round))
                }
            }
        }
        .frame(width: 201.2, height: 201.2)
        .allowsHitTesting(false)
    }
}

// MARK: - 四すみ

struct HVCorner: View {
    let kind: HVIconKind
    let label: String
    let locked: Bool
    let badge: Bool
    let action: () -> Void
    @State private var pop = 1.0
    @State private var pressing = false

    var body: some View {
        Button {
            Haptics.play(.click)
            withAnimation(.timingCurve(0.3, 1.6, 0.4, 1, duration: 0.38)) { pop = 1.1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { action() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { withAnimation(.easeOut(duration: 0.2)) { pop = 1 } }
        } label: {
            ZStack {
                Circle().fill(locked ? Color.black.opacity(0.30) : Color.white.opacity(pressing ? 0.26 : 0.14))
                    .overlay(Circle().strokeBorder(Color.white.opacity(locked ? 0.2 : 0.5), lineWidth: 1.2))
                    .overlay(HVRim(radius: 31, width: 1.2))
                    .shadow(color: .black.opacity(0.75), radius: 14, y: 14)
                HVIcon(kind: kind, size: 26, color: .white.opacity(locked ? 0.5 : 1))
                    .scaleEffect(pop)
                if locked {
                    Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 22, height: 22).background(Color.black.opacity(0.82), in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1))
                        .offset(x: 24, y: 24)
                }
                if badge { HVBadge().offset(x: 25, y: -26) }
            }
            .frame(width: 62, height: 62)
            .overlay(alignment: .bottom) {
                Text(label).font(LF.mono(9.5)).tracking(1.52).foregroundStyle(.white.opacity(locked ? 0.6 : 1))
                    .shadow(color: .black.opacity(0.55), radius: 4).fixedSize().offset(y: 22)
            }
            .frame(width: 86, height: 86)
            .contentShape(Rectangle())
        }
        .buttonStyle(HVPress(scale: 0.9, onPress: { pressing = $0 }))
        .accessibilityLabel(label.capitalized)
    }
}

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

struct HVPill: View {
    let input: HomeV64Input
    let action: () -> Void
    var body: some View {
        let (title, small, arrowDown): (String, String?, Bool) = {
            switch input.shotsUsed {
            case 0: return ("tomorrow, 9:00", nil, true)
            case 1, 2: return ("developing", "\(input.remaining) LEFT", false)
            default: return ("see you at 9:00", "3 / 3", false)
            }
        }()
        Button(action: action) {
            HStack(spacing: 9) {
                HVLiveDot()
                Text(title).font(LF.serif(17.5, italic: true)).foregroundStyle(.white).tracking(0.0875).fixedSize()
                if let small { Text(small).font(LF.mono(9.5)).tracking(1.5).foregroundStyle(.white.opacity(0.7)).fixedSize() }
                Image(systemName: arrowDown ? "arrow.down" : "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
            }
            .padding(.leading, 12).padding(.trailing, 13)
            .frame(height: 36)
            .hvGlass(radius: 18, tint: 0.14)
            .shadow(color: .black.opacity(0.7), radius: 13, y: 12)
            .padding(.vertical, 6).padding(.horizontal, 4)
            .contentShape(Rectangle())
            .padding(.vertical, -6).padding(.horizontal, -4)
        }
        .buttonStyle(HVPress(scale: 0.95))
        .accessibilityLabel(input.shotsUsed == 0 ? "あした 9:00。下の Today へ" : "現像を ひらく")
    }
}

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

struct HVChip: View {
    let input: HomeV64Input
    let onTap: () -> Void
    let onAdd: () -> Void
    var body: some View {
        Button(action: input.friendCount == 0 ? onAdd : onTap) {
            HStack(spacing: 8) {
                if input.friendCount == 0 {
                    Text("友だちを よぶ").font(LF.inter(700, 13.5)).foregroundStyle(.white).tracking(-0.135)
                    Text("ADD ›").font(LF.mono(10)).tracking(1.2).foregroundStyle(.white.opacity(0.72))
                } else if input.faces.isEmpty {
                    Text("まだ だれも 撮って いない").font(LF.inter(700, 13.5)).foregroundStyle(.white)
                } else {
                    HStack(spacing: -9) {
                        ForEach(Array(input.faces.prefix(3).enumerated()), id: \.offset) { i, face in
                            ZStack {
                                Circle().fill(face.color)
                                if let img = face.image { Image(uiImage: img).resizable().scaledToFill().clipShape(Circle()) }
                                else { Text(face.initial).font(LF.inter(800, 11)).foregroundStyle(.white) }
                            }
                            .frame(width: 28, height: 28).overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 2)).zIndex(Double(3 - i))
                        }
                    }
                    Text(input.faces.count == 1 ? "\(input.faces[0].initial) が 撮った" : "\(input.faces.count)人 が 撮った").font(LF.inter(700, 13.5)).foregroundStyle(.white)
                    HVLiveDot()
                }
            }
            .padding(.leading, input.faces.isEmpty ? 14 : 6).padding(.trailing, 15)
            .frame(height: 40)
            .hvGlass(radius: 20, tint: 0.14)
            .shadow(color: .black.opacity(0.7), radius: 13, y: 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .padding(.vertical, -6)
        }
        .buttonStyle(HVPress(scale: 1.06))
        .accessibilityLabel(input.friendCount == 0 ? "友だちを よぶ" : "今日 撮った 友だち、\(input.faces.count)人。Friends を ひらく")
    }
}

// MARK: - 目次(ナビピル)

struct HVDock: View {
    let selected: Int
    let onSelect: (Int) -> Void
    @Namespace private var ns
    private let items: [(HVIconKind, String)] = [(.camera, "Camera"), (.friends, "Friends"), (.trip, "Trip"), (.mondo, "Mondo"), (.yesterday, "Yesterday")]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items.indices, id: \.self) { i in
                let on = i == selected
                Button { Haptics.play(.tick); onSelect(i) } label: {
                    HStack(spacing: 7) {
                        HVIcon(kind: items[i].0, size: 20, color: on ? HV.ink : .white.opacity(0.78))
                        if on { Text(items[i].1.uppercased()).font(LF.mono(10)).tracking(1.2).foregroundStyle(HV.ink).fixedSize() }
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
                .accessibilityLabel("ページ、\(i + 1) / 5、\(items[i].1)")
            }
        }
        .padding(4)
        .hvGlass(radius: 26, tint: 0.13)
        .shadow(color: .black.opacity(0.8), radius: 16, y: 16)
        .animation(.spring(response: 0.44, dampingFraction: 0.72), value: selected)
    }
}

// MARK: - ヘッダーの 部品

struct HVTodaySwitch: View {
    let onYesterday: () -> Void
    @Environment(\.hvDark) private var dark
    var body: some View {
        HStack(spacing: 0) {
            Text("today").font(LF.serif(16.5, italic: true)).foregroundStyle(dark > 0.5 ? .white : HV.ink)
                .padding(.horizontal, 12).frame(height: 32)
                .background(dark > 0.5 ? Color.white.opacity(0.18) : Color.white, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)
                .overlay(Capsule().strokeBorder(.black.opacity(0.06), lineWidth: 0.5))
            Button(action: onYesterday) {
                Text("yesterday").font(LF.serif(16.5, italic: true)).foregroundStyle(HV.gray).padding(.horizontal, 12).frame(height: 32)
            }.buttonStyle(.plain)
        }
        .padding(3)
        .background(dark > 0.5 ? Color.white.opacity(0.10) : Color.black.opacity(0.06), in: Capsule())
        .overlay(Capsule().strokeBorder(dark > 0.5 ? Color.white.opacity(0.10) : Color.black.opacity(0.05), lineWidth: 0.5))
        .accessibilityElement(children: .contain)
    }
}

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

struct HVLivePill: View {
    let input: HomeV64Input
    let action: () -> Void
    @Environment(\.hvDark) private var dark

    private var untilMidnight: (Int, Int) {
        let cal = Calendar.current
        let end = cal.startOfDay(for: input.now).addingTimeInterval(24 * 3600)
        let s = max(0, Int(end.timeIntervalSince(input.now)))
        return (s / 3600, (s % 3600) / 60)
    }

    var body: some View {
        let (h, m) = untilMidnight
        Button(action: action) {
            HStack(spacing: 0) {
                ZStack {
                    Circle().trim(from: 0.05, to: 0.92).stroke(HV.green, style: StrokeStyle(lineWidth: 2.4, lineCap: .round)).rotationEffect(.degrees(-80)).frame(width: 22, height: 22)
                    Circle().fill(HV.green).frame(width: 7, height: 7)
                }
                .frame(width: 24, height: 24).padding(.leading, 10)
                Text("消灯まで").font(LF.inter(600, 12)).tracking(0.24).foregroundStyle(dark > 0.5 ? Color(hex: "9A9AA0") : Color(hex: "6E6E73")).padding(.leading, 8)
                Text("\(h)h \(String(format: "%02d", m))m").font(LF.inter(700, 13.5)).tracking(-0.135).foregroundStyle(dark > 0.5 ? .white : HV.ink).monospacedDigit()
                    .contentTransition(.numericText()).padding(.leading, 8)
                Rectangle().fill(.black.opacity(0.12)).frame(width: 1, height: 16).padding(.horizontal, 8)
                HStack(spacing: 2.5) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2).fill(i < input.remaining ? HV.green : Color.black.opacity(0.10))
                            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color.black.opacity(i < input.remaining ? 0 : 0.18), lineWidth: 1))
                            .frame(width: 7, height: 12)
                            .shadow(color: HV.green.opacity(i < input.remaining ? 0.45 : 0), radius: 3)
                    }
                }
                Text("\(input.remaining)").font(LF.inter(700, 12.5)).tracking(0.25).foregroundStyle(dark > 0.5 ? .white : HV.ink).padding(.leading, 5)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold)).foregroundStyle(HV.ink)
                    .frame(width: 28, height: 28).background(Color.black.opacity(0.06), in: Circle()).padding(.trailing, 5)
            }
            .frame(width: 256.3, height: 38)
            .background(dark > 0.5 ? AnyShapeStyle(Color.black.opacity(0.6)) : AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.8), Color(red: 244 / 255, green: 244 / 255, blue: 246 / 255).opacity(0.56)], startPoint: .top, endPoint: .bottom)), in: Capsule())
            .overlay(Capsule().strokeBorder(dark > 0.5 ? Color.white.opacity(0.14) : Color.white.opacity(0.9), lineWidth: 0.8))
            .shadow(color: HV.ink.opacity(0.18), radius: 12, y: 10)
            .contentShape(Rectangle().inset(by: -4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("消灯まで \(h)時間 \(m)分。のこり \(input.remaining) こま")
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
                Circle().fill(Color(red: 14 / 255, green: 16 / 255, blue: 16 / 255).opacity(pressing ? 0.66 : 0.62))
                    .background(Circle().fill(.ultraThinMaterial))
                    .shadow(color: .black.opacity(0.45), radius: 23, y: -20)
                HVRim(radius: d / 2, width: 1.4)
                VStack(spacing: 15) {
                    HStack(spacing: 9) {
                        if !input.done { HVCameraGlyph(width: 26, line: 1.8, color: .white, showsFlash: false) }
                        Text(title).font(LF.inter(800, 21)).tracking(-0.21).foregroundStyle(input.done ? .white.opacity(0.6) : .white)
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
            Rectangle().fill(Color(hex: "111111")).frame(width: 14, height: 14).rotationEffect(.degrees(45)).offset(y: 12)
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
