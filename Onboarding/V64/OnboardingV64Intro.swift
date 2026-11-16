import SwiftUI

// P01:はじめての設定の 入口(モック v64 `obIntro`):スロットから チェキが 出てきて、大きな「Lattag」が 落ちてくる。時間は モックの 秒どおり(4.3秒でおわり)。
// 写真(PH)は 実機に 作らない ので、チェキの 絵は 色の 面(現像で 色が のる)。

struct OBIntroView: View {
    let start: Date
    let onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var finished = false

    static let duration = 4.3

    var body: some View {
        GeometryReader { g in
            TimelineView(.animation) { ctx in
                #if DEBUG
                let t = OnboardingDebug.introT ?? ctx.date.timeIntervalSince(start)
                #else
                let t = ctx.date.timeIntervalSince(start)
                #endif
                frame(t: reduceMotion ? 99 : t, size: g.size)
                    .onChange(of: t >= (reduceMotion ? 1.6 : Self.duration)) { _, done in if done { end() } }
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { Haptics.play(.tick, gap: 0); end() }
        .onAppear(perform: schedule)
        .accessibilityHidden(true)
    }

    private func p(_ t: Double, _ s: Double, _ d: Double) -> Double { min(1, max(0, (t - s) / d)) }

    private func frame(t: Double, size: CGSize) -> some View {
        let yOff = (size.height - 844) / 2
        // スロット(0.15s から 0.42s で ひらく)
        let slit = OpeningEase.bezier(0.3, 1, 0.4, 1, p(t, 0.15, 0.42))
        // チェキが でてくる(0.52s から 1.3秒・linear)
        let rise = p(t, 0.52, 1.3)
        let ty: CGFloat = {
            let seg: [(Double, Double)] = [(0, -1.02), (0.3, -0.70), (0.42, -0.66), (0.78, -0.20), (1, 0)]
            for i in 1..<seg.count where rise <= seg[i].0 {
                let a = seg[i - 1], b = seg[i]
                return CGFloat(a.1 + (b.1 - a.1) * (rise - a.0) / (b.0 - a.0))
            }
            return 0
        }()
        let develop = p(t, 1.9, 2.6)
        let milk: Double = develop < 0.3 ? 1 - 0.15 * develop / 0.3 : 0.85 * (1 - (develop - 0.3) / 0.7)
        let logo = OpeningEase.bezier(0.2, 0.8, 0.3, 1, p(t, 2.25, 0.62))
        let logoScale: CGFloat = logo < 0.55 ? 1.5 - 0.53 * CGFloat(logo / 0.55) : 0.97 + 0.03 * CGFloat((logo - 0.55) / 0.45)
        let ckW: CGFloat = 214, ckH: CGFloat = 265
        return ZStack(alignment: .topLeading) {
            Color.black
            // oplk:右上の 緑と 左下の 赤
            ZStack {
                glow(Color(red: 36 / 255, green: 160 / 255, blue: 60 / 255).opacity(0.55), w: 520, h: 680, cx: size.width * 1.08, cy: size.height * 0.08)
                glow(Color(red: 1, green: 60 / 255, blue: 120 / 255).opacity(0.28), w: 400, h: 520, cx: -size.width * 0.1, cy: size.height * 0.96)
            }
            .opacity({ let q = p(t, 1.7, 2.4); return t < 1.7 ? 0 : (q < 0.4 ? q / 0.4 : 1 - (q - 0.4) / 0.6 * 0.45) }())
            // スロットの すきま
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: "111111"))
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(.white.opacity(0.08), lineWidth: 1))
                .frame(width: 262, height: 3).scaleEffect(x: slit, y: 1)
                .position(x: size.width / 2, y: 196 + 1.5 + yOff)
            // チェキ(スロットの 下だけ 見える)
            ZStack(alignment: .topLeading) {
                UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4).fill(OB.paper)
                    .shadow(color: .black.opacity(0.9), radius: 25, y: 26)
                ZStack {
                    LinearGradient(colors: [Color(hex: "E7ECE8"), Color(hex: "E7ECE8")], startPoint: .top, endPoint: .bottom)
                    LinearGradient(colors: [Color(hex: "7F9C8A"), Color(hex: "C28A9E")], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .saturation(0.1 + 0.9 * develop).brightness(0.6 * (1 - develop))
                    LinearGradient(colors: [Color(hex: "EAF1EC"), Color(hex: "DCE6E6")], startPoint: UnitPoint(x: 0.3, y: 0), endPoint: UnitPoint(x: 0.7, y: 1)).opacity(milk)
                }
                .frame(width: 192, height: 206).clipShape(RoundedRectangle(cornerRadius: 2)).offset(x: 11, y: 11)
                Text(OpeningStyle.shortDate(Date(), apostrophe: true)).font(LF.mono(10)).tracking(0.6)
                    .foregroundStyle(Color(hex: "E0481A")).opacity(0.9).fixedSize()
                    .offset(x: 14, y: ckH - 15 - 15)
                SevenSegmentText(text: "9:00", height: 16.7, color: t >= 1.88 ? OB.stamp : Color(hex: "3A2010"))
                    .frame(width: 42, height: 20).offset(x: ckW - 12 - 42, y: ckH - 11 - 20)
            }
            .frame(width: ckW, height: ckH)
            .offset(y: ckH * ty)
            .frame(width: ckW, height: 300 - 2, alignment: .top)
            .clipped()
            .position(x: size.width / 2, y: 198 + (300 - 2) / 2 + yOff)
            // 大きな Lattag(104pt・印刷ズレつき)
            Text(Brand.name).font(LF.inter(900, 104)).tracking(-0.075 * 104)
                .foregroundStyle(.white)
                .fixedSize()
                .scaleEffect(logoScale).blur(radius: 10 * (1 - logo)).opacity(logo)
                .position(x: size.width / 2, y: 510.7 + 63 + yOff)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private func glow(_ c: Color, w: CGFloat, h: CGFloat, cx: CGFloat, cy: CGFloat) -> some View {
        EllipticalGradient(stops: [.init(color: c, location: 0), .init(color: c.opacity(0), location: 0.7)], center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
            .frame(width: w, height: h).position(x: cx, y: cy)
    }

    /// バイブ:tick → カタカタ(チェキ)→ click(日付)→ thud(Lattag)
    private func schedule() {
        func at(_ s: Double, _ work: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + s) { if !finished { work() } }
        }
        Haptics.play(.soft)   // はじまる(モック openOb)
        if reduceMotion { return }
        at(0.18) { Haptics.play(.tick, gap: 0) }
        for (k, t) in [0.56, 0.76, 0.98, 1.2, 1.42, 1.64].enumerated() {
            at(t) { Haptics.play(k % 2 == 1 ? .tick : .projector, gap: 0) }
        }
        at(1.88) { Haptics.play(.click) }
        at(2.56) { Haptics.play(.thud) }
    }

    private func end() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}

#if DEBUG
/// DEBUG:入口の 時間を 止めて 撮る
enum OnboardingDebug {
    nonisolated(unsafe) static var introT: Double?
}
#endif
