import SwiftUI

// P16(v72):オープニング B「アイコンが 横へ → Lattag + 9:00 → レンズから Home」。
// 正解:`Design/LattagKit/prompts/reference/PROMPT_v72.md` と `mock/opening_v72.html`(B)。時間は モックの ミリ秒を そのまま。
// 時間は 1本(TimelineView)。ぼかしは 使わない(光は 放射状の グラデーション)。見えない 間は 止まる。

// MARK: - cubic-bezier(CSS と 同じ)

struct OPBez {
    let a: Double, b: Double, c: Double, d: Double
    init(_ a: Double, _ b: Double, _ c: Double, _ d: Double) { self.a = a; self.b = b; self.c = c; self.d = d }
    private func x(_ u: Double) -> Double { 3 * (1 - u) * (1 - u) * u * a + 3 * (1 - u) * u * u * c + u * u * u }
    private func y(_ u: Double) -> Double { 3 * (1 - u) * (1 - u) * u * b + 3 * (1 - u) * u * u * d + u * u * u }
    func at(_ t: Double) -> Double {
        if t <= 0 { return 0 }
        if t >= 1 { return 1 }
        var lo = 0.0, hi = 1.0, u = t
        for _ in 0..<24 {
            let v = x(u)
            if abs(v - t) < 1e-5 { break }
            if v < t { lo = u } else { hi = u }
            u = (lo + hi) / 2
        }
        return y(u)
    }
}

/// キーフレーム(各 区間に 同じ 曲線を かける ・ WAAPI と 同じ)
func opKeys(_ t: Double, _ frames: [(Double, Double)], _ ease: OPBez) -> Double {
    guard let first = frames.first, let last = frames.last else { return 0 }
    if t <= first.0 { return first.1 }
    if t >= last.0 { return last.1 }
    for i in 0..<(frames.count - 1) {
        let (t0, v0) = frames[i], (t1, v1) = frames[i + 1]
        if t >= t0 && t <= t1 { return v0 + (v1 - v0) * ease.at((t - t0) / (t1 - t0)) }
    }
    return last.1
}

// MARK: - 時間割り(ミリ秒)

enum OP72 {
    // v105 S(強い 版 ・ 約 2.1秒)。動かすのは 位置 ・ 大きさ ・ 回転 ・ 透明度 だけ。光 ・ 輪 は 前もって 作った 画像(`OPImages`)
    static let chargeStart = 220.0, chargeEnd = 420.0          // ためる
    static let releaseAt = 420.0                              // はなつ
    static let slideStart = 720.0, slideOver = 1170.0, slideEnd = 1320.0
    static let textStart = 700.0, textStep = 45.0, textDur = 460.0
    static let nineStart = 1080.0, nineDur = 380.0
    static let blinkStart = 1300.0, blinkDur = 200.0
    static let diveStart = 1440.0, diveDur = 520.0            // レンズの 中へ 飛びこむ
    static let openStart = 1440.0                             // 「ひらく」の はじまり(とばす 時の ゆきさき ・ onReveal)
    static let homeStart = 1640.0, homeDur = 460.0            // Home が 1.25 → 1
    static let total = 2100.0
    /// 0.6秒 たったら タップで とばせる
    static let skipAfter = 600.0
    /// 通知 ・ リンク:この 時間の あと すぐ 「ひらく」へ
    static let shortCut = 220.0
    /// 組みの 寸法
    static let iconStart: CGFloat = 132, iconEnd: CGFloat = 78, gap: CGFloat = 18
    static let letterFont: CGFloat = 54, nineFont: CGFloat = 15
    static let homeFrom: CGFloat = 1.25
}

/// 光 ・ 輪 ・ うしろの 光:起動時に 1回だけ 作る 画像(動かす 時に ぼかし ・ 影の 半径を 変えない)
enum OPImages {
    private static func make(_ draw: (CGContext, CGSize) -> Void) -> UIImage {
        let sz = CGSize(width: 256, height: 256)
        return UIGraphicsImageRenderer(size: sz).image { draw($0.cgContext, sz) }
    }
    private static func radial(_ ctx: CGContext, _ sz: CGSize, _ color: UIColor, _ a: CGFloat) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let g = CGGradient(colorsSpace: cs, colors: [color.withAlphaComponent(a).cgColor, color.withAlphaComponent(a * 0.35).cgColor, color.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 0.4, 1])!
        ctx.drawRadialGradient(g, startCenter: CGPoint(x: sz.width / 2, y: sz.height / 2), startRadius: 0, endCenter: CGPoint(x: sz.width / 2, y: sz.height / 2), endRadius: sz.width / 2, options: [])
    }
    static let flash: UIImage = make { radial($0, $1, .white, 1) }
    static let glow: UIImage = make { radial($0, $1, UIColor(red: 0xC8 / 255, green: 0xF2 / 255, blue: 0x5A / 255, alpha: 1), 0.9) }
    static let ring: UIImage = make { ctx, sz in
        ctx.setStrokeColor(UIColor(red: 0xC8 / 255, green: 0xF2 / 255, blue: 0x5A / 255, alpha: 1).cgColor)
        ctx.setLineWidth(5)
        ctx.strokeEllipse(in: CGRect(x: 8, y: 8, width: sz.width - 16, height: sz.height - 16))
    }
}

// MARK: - アプリアイコンと 同じ 絵(ベクター。レンズだけ 倍率を 変えられる)

struct OPIcon: View {
    var size: CGFloat
    var lensScale: CGFloat = 1
    var body: some View {
        Canvas { ctx, sz in
            let k = sz.width / 1024
            ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .linearGradient(Gradient(colors: [Color(hex: "D6F76E"), Color(hex: "C8F25A")]), startPoint: .zero, endPoint: CGPoint(x: 0, y: sz.height)))
            let ink = Color(hex: "0B0C0D")
            for r in [CGRect(x: 196, y: 320, width: 632, height: 104), CGRect(x: 196, y: 600, width: 632, height: 104),
                      CGRect(x: 320, y: 196, width: 104, height: 632), CGRect(x: 600, y: 196, width: 104, height: 632)] {
                ctx.fill(Path(roundedRect: CGRect(x: r.minX * k, y: r.minY * k, width: r.width * k, height: r.height * k), cornerRadius: 52 * k), with: .color(ink))
            }
            var c = ctx
            c.translateBy(x: 512 * k, y: 512 * k); c.scaleBy(x: lensScale, y: lensScale); c.translateBy(x: -512 * k, y: -512 * k)
            func disc(_ r: CGFloat, _ shading: GraphicsContext.Shading) { c.fill(Path(ellipseIn: CGRect(x: (512 - r) * k, y: (512 - r) * k, width: 2 * r * k, height: 2 * r * k)), with: shading) }
            disc(116, .color(Color(hex: "C8F25A")))
            disc(104, .color(ink))
            disc(92, .color(Color(hex: "3A3A40")))
            disc(80, .radialGradient(Gradient(stops: [.init(color: Color(hex: "2A3A5A"), location: 0), .init(color: Color(hex: "05070A"), location: 0.6), .init(color: .black, location: 1)]),
                                     center: CGPoint(x: (512 - 80 + 160 * 0.4) * k, y: (512 - 80 + 160 * 0.35) * k), startRadius: 0, endRadius: 160 * 0.72 * k))
            c.stroke(Path(ellipseIn: CGRect(x: (512 - 44) * k, y: (512 - 44) * k, width: 88 * k, height: 88 * k)), with: .color(Color(red: 140 / 255, green: 170 / 255, blue: 1).opacity(0.35)), lineWidth: 3 * k)
            var g = c
            g.translateBy(x: 484 * k, y: 482 * k); g.rotate(by: .degrees(-30))
            g.fill(Path(ellipseIn: CGRect(x: -28 * k, y: -18 * k, width: 56 * k, height: 36 * k)), with: .color(.white.opacity(0.85)))
            c.fill(Path(ellipseIn: CGRect(x: (542 - 9) * k, y: (542 - 9) * k, width: 18 * k, height: 18 * k)), with: .color(Color(hex: "C8F25A").opacity(0.8)))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.224, style: .continuous))
    }
}

// MARK: - オープニング

struct OpeningV72View: View {
    let variant: OpeningVariant
    let start: Date
    /// はじめての 設定へ 進む 人は、丸く ひらく かわりに フェードで オンボーディングの 1枚目へ
    var fadeOut = false
    /// 「ひらく」が 始まった(1回だけ)
    var onReveal: () -> Void = {}
    /// Home の 1.06倍 → 1(ひらく 間 だけ 動く)
    var homeScale: Binding<CGFloat>? = nil
    let onFinish: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var skipAt: Double?          // タップで とばした 時刻(秒)
    @State private var letterW: CGFloat = 160
    @State private var nineW: CGFloat = 40
    @State private var finished = false
    @State private var hapticTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            let size = CGSize(width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
                              height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom)
            TimelineView(.animation(paused: scenePhase != .active)) { ctx in
                #if DEBUG
                let raw = OpeningDebug.frozenT ?? ctx.date.timeIntervalSince(start)
                #else
                let raw = ctx.date.timeIntervalSince(start)
                #endif
                let ms = effective(raw * 1000)
                scene(ms: ms, size: size)
                    .onChange(of: ms >= endMs) { _, done in if done { finish() } }
                    .onChange(of: ms >= OP72.openStart) { _, go in if go { reveal() } }
                    .onChange(of: Int(ms / 16)) { _, _ in
                        let hu = (ms - OP72.homeStart) / OP72.homeDur
                        homeScale?.wrappedValue = hu <= 0 ? OP72.homeFrom : OP72.homeFrom - (OP72.homeFrom - 1) * CGFloat(OPBez(0.16, 1, 0.3, 1).at(hu))
                    }
            }
            .frame(width: size.width, height: size.height)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { skip() }
        .onAppear(perform: scheduleHaptics)
        .onReceive(NotificationCenter.default.publisher(for: .photoNotificationTapped)) { _ in shortNow() }
        .onReceive(NotificationCenter.default.publisher(for: .chatNotificationTapped)) { _ in shortNow() }
        .onReceive(NotificationCenter.default.publisher(for: .openGroupRequested)) { _ in shortNow() }
        .onDisappear { hapticTask?.cancel() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lattag。タップで とばす")
        .accessibilityAddTraits(.isButton)
        .background(measure)
    }

    // 文字の 幅を はかる(見えない)
    private var measure: some View {
        ZStack {
            Text("Lattag").font(Typo.ui(900, OP72.letterFont)).tracking(-0.06 * OP72.letterFont).fixedSize()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { letterW = $0 }
            Text("9:00").font(Typo.ui(900, OP72.nineFont)).tracking(-0.02 * OP72.nineFont).fixedSize()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { nineW = $0 }
        }.opacity(0).allowsHitTesting(false)
    }

    // MARK: 時刻の 読みかえ

    private var endMs: Double { variant == .fade ? 1000 : OP72.total }

    /// とばした / 短い 版 を 1本の 時間に ならす(220ms の あと すぐ 「ひらく」= 1440ms へ)
    private func effective(_ ms: Double) -> Double {
        switch variant {
        case .fade: return ms
        case .short:
            return ms < OP72.shortCut ? ms : OP72.openStart + (ms - OP72.shortCut)
        case .full:
            if let skipAt, ms >= skipAt { return max(ms - skipAt, 0) + OP72.openStart }
            return ms
        }
    }

    /// 通知 ・ リンクが 来た:すぐ「ひらく」へ(文字 ・ 9:00 は 出さない)
    private func shortNow() {
        guard variant == .full, skipAt == nil else { return }
        let ms = Date().timeIntervalSince(start) * 1000
        guard ms < OP72.openStart else { return }
        skipAt = ms; hapticTask?.cancel(); Haptics.play(.land)
    }

    private func skip() {
        guard variant == .full, skipAt == nil else { return }
        let ms = Date().timeIntervalSince(start) * 1000
        guard ms >= OP72.skipAfter, ms < OP72.openStart else { return }
        skipAt = ms
        hapticTask?.cancel()
        Haptics.play(.land)
    }

    @State private var revealed = false
    private func reveal() {
        guard !revealed else { return }
        revealed = true
        onReveal()
    }

    private func finish() {
        reveal()
        guard !finished else { return }
        finished = true
        hapticTask?.cancel()
        onFinish()
    }

    private func scheduleHaptics() {
        guard variant != .fade else { return }
        let marks: [(Double, Haptics.Kind)] = variant == .short
            ? [(OP72.shortCut + (1700 - OP72.openStart), .land)]
            : [(220, .tick), (420, .shutter), (700, .soft), (1100, .pop), (1320, .click), (1700, .land)]
        hapticTask = Task { @MainActor in
            for (ms, h) in marks {
                let wait = ms / 1000 - Date().timeIntervalSince(start)
                if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
                if Task.isCancelled { return }
                Haptics.play(h)
            }
        }
    }

    // MARK: 1コマ

    private func scene(ms: Double, size: CGSize) -> some View {
        let W = size.width, H = size.height
        let cy = H / 2
        let fade = variant == .fade
        // .fade(はじめての 設定へ)は 組みあがった 形を そのまま フェード
        let t = fade ? 1400.0 : ms
        let tot = OP72.iconEnd + OP72.gap + letterW + 5 + nineW
        let x0 = (W - tot) / 2
        let lensX = x0 + OP72.iconEnd / 2
        func clamp(_ x: Double) -> Double { min(1, max(0, x)) }

        // --- アイコン:ためる → はなつ → 左へ(少し 行きすぎ)
        var pulse = 1.0
        var lens = 1.0
        if t < OP72.chargeStart { pulse = 1 }
        else if t < OP72.releaseAt {
            let e = OPBez(0.42, 0, 1, 1).at((t - OP72.chargeStart) / (OP72.releaseAt - OP72.chargeStart))
            pulse = 1 - 0.1 * e; lens = 1 - 0.22 * e
        } else if t < OP72.slideStart {
            pulse = opKeys(t, [(420, 0.9), (540, 1.12), (720, 1.0)], OPBez(0.2, 0.9, 0.3, 1))
            lens = opKeys(t, [(420, 1.06), (620, 1.0)], OPBez(0.2, 0.9, 0.3, 1))
        }
        // レンズの まばたき(1 → 0.8 → 1)
        if t >= OP72.blinkStart && t < OP72.blinkStart + OP72.blinkDur {
            lens *= opKeys(t, [(OP72.blinkStart, 1), (OP72.blinkStart + 100, 0.8), (OP72.blinkStart + 200, 1)], OPBez(0.4, 0, 0.6, 1))
        }
        let dist = max(1, W / 2 - lensX)
        var pp = 0.0, sizeNow = OP72.iconStart
        if t >= OP72.slideStart {
            if t < OP72.slideOver {
                let e = OPBez(0.3, 0, 0.2, 1).at((t - OP72.slideStart) / (OP72.slideOver - OP72.slideStart))
                pp = e * (1 + 5 / dist)
                sizeNow = OP72.iconStart + (OP72.iconEnd * 0.98 - OP72.iconStart) * CGFloat(e)
            } else {
                let e = OPBez(0.3, 0, 0.2, 1).at(clamp((t - OP72.slideOver) / (OP72.slideEnd - OP72.slideOver)))
                pp = (1 + 5 / dist) + (1 - (1 + 5 / dist)) * e
                sizeNow = OP72.iconEnd * 0.98 + (OP72.iconEnd - OP72.iconEnd * 0.98) * CGFloat(e)
            }
        }
        let iconK = sizeNow / OP72.iconStart * CGFloat(pulse)
        let iconX = W / 2 + (lensX - W / 2) * pp

        // --- 光 ・ 輪 ・ うしろの 光(画像)
        let fu = clamp((t - 420) / 380)
        let flashScale = opKeys(fu, [(0, 0.3), (0.5, 1), (1, 1.9)], OPBez(0.2, 0.8, 0.4, 1))
        let flashAlpha = opKeys(fu, [(0, 0), (0.5, 1), (1, 0)], OPBez(0.3, 0, 0.5, 1))
        let ru = OPBez(0.15, 0.7, 0.3, 1).at(clamp((t - 430) / 680))
        let ringScale = 0.7 + 2.7 * ru, ringAlpha = 0.95 * (1 - ru)
        let gu = clamp((t - 420) / 1100)
        let glowScale = opKeys(gu, [(0, 0.5), (0.45, 1.15), (1, 0.62)], OPBez(0.3, 0, 0.3, 1))
        let glowAlpha = opKeys(gu, [(0, 0), (0.45, 1), (1, 0.42)], OPBez(0.3, 0, 0.3, 1))

        // --- 文字(1字ずつ)・ 9:00
        let letters = Array("Lattag")
        let nu = OPBez(0.3, 1.4, 0.5, 1).at(clamp((t - OP72.nineStart) / OP72.nineDur))
        let nineRot = opKeys(nu, [(0, -14), (0.6, 5), (1, 0)], OPBez(0.3, 0, 0.3, 1))
        let nineScale = opKeys(nu, [(0, 0.3), (0.6, 1.2), (1, 1)], OPBez(0.3, 0, 0.3, 1))

        // --- 飛びこみ ・ Home
        let du = t - OP72.diveStart
        var diveScale = 1.0, diveAlpha = 1.0
        if du > 0 && !fade {
            let x = clamp(du / OP72.diveDur)
            diveScale = opKeys(x, [(0, 1), (0.4, 1.7), (0.7, 4.5), (1, 24)], OPBez(0.45, 0, 0.75, 0.4))
            diveAlpha = x < 0.85 ? 1 : 1 - (x - 0.85) / 0.15
        }
        let blackAlpha = fade ? 1 : 1 - OPBez(0.3, 0, 0.3, 1).at(clamp((t - OP72.homeStart) / 320))
        let fadeAlpha = fade ? 1 - OPBez(0.3, 0, 0.3, 1).at((ms - 600) / 400) : 1
        let lumpX = x0 + OP72.iconEnd + OP72.gap

        return ZStack {
            Color.black.opacity(blackAlpha)
            ZStack {
                Image(uiImage: OPImages.glow).resizable().frame(width: 300, height: 300)
                    .scaleEffect(glowScale).opacity(glowAlpha).position(x: iconX, y: cy)
                Image(uiImage: OPImages.flash).resizable().frame(width: 200, height: 200)
                    .scaleEffect(flashScale).opacity(flashAlpha).position(x: W / 2, y: cy)
                Image(uiImage: OPImages.ring).resizable().frame(width: 120, height: 120)
                    .scaleEffect(ringScale).opacity(ringAlpha).position(x: W / 2, y: cy)

                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        ForEach(0..<letters.count, id: \.self) { i in
                            let u = OPBez(0.3, 1.1, 0.4, 1).at(clamp((t - (OP72.textStart + OP72.textStep * Double(i))) / OP72.textDur))
                            Text(String(letters[i])).font(Typo.ui(900, OP72.letterFont)).tracking(-0.06 * OP72.letterFont).foregroundStyle(.white).fixedSize()
                                .offset(x: opKeys(u, [(0, -30), (0.6, 3), (1, 0)], OPBez(0.3, 0, 0.3, 1)))
                                .rotationEffect(.degrees(opKeys(u, [(0, -6), (0.6, 1), (1, 0)], OPBez(0.3, 0, 0.3, 1))))
                                .opacity(opKeys(u, [(0, 0), (0.4, 1), (1, 1)], OPBez(0.3, 0, 0.3, 1)))
                        }
                    }.frame(height: OP72.iconEnd)
                    Text("9:00").font(Typo.ui(900, OP72.nineFont)).tracking(-0.02 * OP72.nineFont).monospacedDigit()
                        .foregroundStyle(Color(hex: "C8F25A")).fixedSize()
                        .scaleEffect(nineScale, anchor: .bottomLeading).rotationEffect(.degrees(nineRot), anchor: .bottomLeading).opacity(min(1, max(0, nu * 2)))
                        .offset(x: letterW + 5, y: 19)
                }
                .frame(width: letterW + 5 + nineW, height: OP72.iconEnd, alignment: .topLeading)
                .position(x: lumpX + (letterW + 5 + nineW) / 2, y: cy)

                // アイコン(影は 132 の 大きさで 1枚の 絵に して 縮める)
                OPIcon(size: OP72.iconStart, lensScale: CGFloat(lens))
                    .shadow(color: Color(hex: "C8F25A").opacity(0.38), radius: 20 * OP72.iconStart / OP72.iconEnd, x: 0, y: 18 * OP72.iconStart / OP72.iconEnd)
                    .padding(90)
                    .drawingGroup()
                    .scaleEffect(iconK)
                    .position(x: iconX, y: cy)
            }
            .frame(width: W, height: H)
            .scaleEffect(diveScale, anchor: UnitPoint(x: lensX / max(1, W), y: 0.5))
            .opacity(diveAlpha)
        }
        .frame(width: W, height: H)
        .opacity(fadeAlpha)
        .drawingGroup()
    }
}

/// 地の 光:下から 緑 + アイコンの うしろの 黄緑(Home と 同じ 色)
private struct OPGlow: View {
    var amount: Double
    var body: some View {
        Canvas { ctx, size in
            guard amount > 0 else { return }
            func ellipse(_ rx: CGFloat, _ ry: CGFloat, _ cx: CGFloat, _ cy: CGFloat, _ stops: [Gradient.Stop]) {
                var c = ctx
                c.translateBy(x: cx, y: cy); c.scaleBy(x: rx, y: ry)
                c.fill(Path(CGRect(x: -3, y: -3, width: 6, height: 6)), with: .radialGradient(Gradient(stops: stops), center: .zero, startRadius: 0, endRadius: 1))
            }
            let g = Color(red: 36 / 255, green: 160 / 255, blue: 60 / 255), l = Color(hex: "C8F25A")
            ellipse(size.width * 1.30, size.height * 0.55, size.width * 0.5, size.height * 1.08,
                    [.init(color: g.opacity(0.62 * amount), location: 0), .init(color: g.opacity(0.18 * amount), location: 0.45), .init(color: g.opacity(0), location: 0.70)])
            ellipse(size.width * 0.55, size.height * 0.32, size.width * 0.5, size.height * 0.48,
                    [.init(color: l.opacity(0.10 * amount), location: 0), .init(color: l.opacity(0), location: 0.70)])
        }
        .allowsHitTesting(false)
    }
}
