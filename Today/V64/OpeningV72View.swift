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
    static let slideStart = 330.0, slideDur = 720.0
    static let blinkStart = 180.0, blinkDur = 360.0
    static let textStart = 470.0, textDur = 620.0, letterStep = 45.0, letterDur = 520.0
    static let nineStart = 1120.0, nineDur = 380.0
    static let shutterStart = 1520.0, shutterDur = 260.0
    static let flashStart = 1600.0, flashDur = 420.0
    static let openStart = 1760.0, openDur = 720.0
    static let total = 2480.0
    /// 0.6秒 たったら タップで とばせる
    static let skipAfter = 600.0
    /// 組みの 寸法
    static let iconStart: CGFloat = 132, iconEnd: CGFloat = 78, gap: CGFloat = 18
    static let letterFont: CGFloat = 54, nineFont: CGFloat = 15
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
                        let ou = (ms - OP72.openStart) / OP72.openDur
                        homeScale?.wrappedValue = ou <= 0 || variant == .fade || fadeOut ? 1.06 : CGFloat(opKeys(ou, [(0, 1.06), (0.35, 1.03), (1, 1)], OPBez(0.7, 0, 0.2, 1)))
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
            Text("Lattag").font(LF.inter(900, OP72.letterFont)).tracking(-0.06 * OP72.letterFont).fixedSize()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { letterW = $0 }
            Text("9:00").font(LF.inter(900, OP72.nineFont)).tracking(-0.02 * OP72.nineFont).fixedSize()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { nineW = $0 }
        }.opacity(0).allowsHitTesting(false)
    }

    // MARK: 時刻の 読みかえ

    private var endMs: Double { variant == .fade ? 1000 : OP72.total }

    /// とばした / 短い 版 / 視差を 減らす を 1本の 時間に ならす
    private func effective(_ ms: Double) -> Double {
        switch variant {
        case .fade: return ms
        case .short:
            // 0〜330ms の あと すぐ「ひらく」(文字 ・ 9:00 は 出さない)
            return ms < OP72.slideStart ? ms : OP72.openStart + (ms - OP72.slideStart)
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
            ? [(OP72.slideStart, .land)]
            : [(OP72.textStart, .soft), (OP72.textStart + 5 * OP72.letterStep + 360, .tick), (OP72.nineStart + 60, .pop), (OP72.flashStart, .shutter), (OP72.openStart, .land)]
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
        let tot = OP72.iconEnd + OP72.gap + letterW + 5 + nineW
        let x0 = (W - tot) / 2
        let lensX = x0 + OP72.iconEnd / 2
        let compact = variant == .short
        let fade = variant == .fade

        // 光の 層(0〜700ms)
        let glow = fade || compact ? (compact ? OPBez(0.3, 0, 0.3, 1).at(ms / 700) : 1) : OPBez(0.3, 0, 0.3, 1).at(ms / 700)

        // アイコン:まんなか 132 → 左 78
        let p = compact || fade ? (fade ? 1 : 0) : OPBez(0.34, 1.12, 0.42, 1).at((ms - OP72.slideStart) / OP72.slideDur)
        let iconSize = OP72.iconStart + (OP72.iconEnd - OP72.iconStart) * p
        let iconX = W / 2 + (lensX - W / 2) * p
        let blink = compact || fade ? 1 : opKeys(ms - OP72.blinkStart, [(0, 1), (OP72.blinkDur / 3, 0.86), (OP72.blinkDur * 2 / 3, 1.04), (OP72.blinkDur, 1)], OPBez(0.3, 1.4, 0.5, 1))
        let shutter = compact || fade ? 1 : opKeys(ms - OP72.shutterStart, [(0, 1), (OP72.shutterDur / 2, 0.82), (OP72.shutterDur, 1)], OPBez(0.6, 0, 0.3, 1))
        let kShadow = iconSize / OP72.iconEnd

        // 文字:印の うしろから 横へ
        let reveal = fade ? 1 : OPBez(0.25, 0.9, 0.3, 1).at((ms - OP72.textStart) / OP72.textDur)
        let textLeft = x0 + OP72.iconEnd + OP72.gap

        // フラッシュ
        let fu = (ms - OP72.flashStart) / OP72.flashDur
        let flashEase = OPBez(0.2, 0.7, 0.3, 1)
        let fo = fu < 0 || fu > 1 ? 0 : (fu < 0.35 ? 0.95 * flashEase.at(fu / 0.35) : 0.95 * (1 - flashEase.at((fu - 0.35) / 0.65)))
        let fs = fu < 0 ? 0.3 : (fu > 1 ? 1.5 : (fu < 0.35 ? 0.3 + 0.7 * flashEase.at(fu / 0.35) : 1 + 0.5 * flashEase.at((fu - 0.35) / 0.65)))

        // ひらく
        let ou = (ms - OP72.openStart) / OP72.openDur
        // Home の レンズの 中心(カード内 214 + 上 178 + 余白 = 画面の 高さ / 2 − 30)
        let homeC = CGPoint(x: W / 2, y: H / 2 - 30)
        let lens = CGPoint(x: lensX, y: cy)
        let holeR: Double, holeC: CGPoint
        if fade || fadeOut || ou <= 0 { holeR = 0; holeC = lens } else if ou < 0.35 {
            let e = OPBez(0.7, 0, 0.2, 1).at(ou / 0.35)
            holeR = 90 * e; holeC = CGPoint(x: lens.x + ((lens.x + homeC.x) / 2 - lens.x) * e, y: lens.y + ((lens.y + homeC.y) / 2 - lens.y) * e)
        } else {
            let e = OPBez(0.7, 0, 0.2, 1).at((ou - 0.35) / 0.65)
            let mid = CGPoint(x: (lens.x + homeC.x) / 2, y: (lens.y + homeC.y) / 2)
            holeR = 90 + (1000 - 90) * e; holeC = CGPoint(x: mid.x + (homeC.x - mid.x) * e, y: mid.y + (homeC.y - mid.y) * e)
        }
        let opScale = fadeOut ? 1 : opKeys(ou, [(0, 1), (0.6, 1.08), (1, 1.1)], OPBez(0.6, 0, 0.3, 1))
        let opAlpha = fadeOut ? 1 - OPBez(0.3, 0, 0.3, 1).at(ou) : opKeys(ou, [(0, 1), (0.6, 1), (1, 0)], OPBez(0.6, 0, 0.3, 1))
        let fadeAlpha = fade ? 1 - OPBez(0.3, 0, 0.3, 1).at((ms - 600) / 400) : 1

        return ZStack {
            Color(hex: "0B0C0D")
            OPGlow(amount: glow).frame(width: W, height: H)

            // 文字(アイコンの うしろ)
            if !compact {
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        ForEach(Array("Lattag".enumerated()), id: \.offset) { i, ch in
                            let u = fade ? 1 : (ms - (OP72.textStart + Double(i) * OP72.letterStep)) / OP72.letterDur
                            let off = fade ? 0 : opKeys(u, [(0, -34), (0.7, 3), (1, 0)], OPBez(0.3, 1.1, 0.4, 1))
                            let al = fade ? 1 : opKeys(u, [(0, 0), (0.7, 1), (1, 1)], OPBez(0.3, 1.1, 0.4, 1))
                            Text(String(ch)).font(LF.inter(900, OP72.letterFont)).tracking(-0.06 * OP72.letterFont)
                                .foregroundStyle(.white).offset(x: off).opacity(min(1, max(0, al)))
                        }
                    }
                    .frame(height: OP72.iconEnd)
                    let nu = fade ? 1 : (ms - OP72.nineStart) / OP72.nineDur
                    let ns = fade ? 1 : opKeys(nu, [(0, 0.4), (0.6, 1.12), (1, 1)], OPBez(0.3, 1.4, 0.5, 1))
                    let ny = fade ? 0 : opKeys(nu, [(0, 6), (0.6, -2), (1, 0)], OPBez(0.3, 1.4, 0.5, 1))
                    let na = fade ? 1 : opKeys(nu, [(0, 0), (0.6, 1), (1, 1)], OPBez(0.3, 1.4, 0.5, 1))
                    Text("9:00").font(LF.inter(900, OP72.nineFont)).tracking(-0.02 * OP72.nineFont).monospacedDigit()
                        .foregroundStyle(Color(hex: "C8F25A"))
                        .scaleEffect(max(0.01, ns), anchor: .bottomLeading).offset(y: ny).opacity(min(1, max(0, na)))
                        .offset(x: letterW + 5, y: 19)
                }
                .frame(width: letterW + 5 + nineW, height: OP72.iconEnd, alignment: .topLeading)
                .mask(alignment: .leading) {
                    Rectangle().frame(width: (letterW + 5 + nineW + 40) * max(0, min(1, reveal)) + 20).offset(x: -20)
                }
                .position(x: textLeft + (letterW + 5 + nineW) / 2, y: cy)
            }

            // アイコン
            OPIcon(size: iconSize, lensScale: blink * shutter)
                .shadow(color: Color(hex: "C8F25A").opacity(0.3), radius: 20 * kShadow * iconSize / iconSize, x: 0, y: 18 * kShadow)
                .position(x: iconX, y: cy)

            // レンズの 光
            Circle().fill(RadialGradient(stops: [.init(color: .white, location: 0.3), .init(color: Color(hex: "C8F25A").opacity(0.7), location: 0.62), .init(color: Color(hex: "C8F25A").opacity(0), location: 1)], center: .center, startRadius: 0, endRadius: OP72.iconEnd * 0.36))
                .frame(width: OP72.iconEnd * 0.72, height: OP72.iconEnd * 0.72)
                .scaleEffect(fs).opacity(fo)
                .position(x: lens.x, y: lens.y)
        }
        .frame(width: W, height: H)
        .scaleEffect(opScale)
        .opacity(opAlpha * fadeAlpha)
        .mask {
            // Home を 丸く ひらく:丸の 中は 透明(下の Home が 見える)
            Rectangle().fill(.white)
                .overlay { Circle().frame(width: max(0, holeR) * 2, height: max(0, holeR) * 2).position(holeC).blendMode(.destinationOut) }
                .compositingGroup()
        }
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
