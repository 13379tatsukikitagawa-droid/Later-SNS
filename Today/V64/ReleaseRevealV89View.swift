import SwiftUI

// v89 E:撮った あと = きのうの 写真が、レンズの しぼりから ひらく(モザイクは やめる)。見本 C10 C11 C19〜C22 ・ 動き M29。
// 0〜0.52 カードが 上がる ・ 0.6〜1.2 しぼり(7枚)が ひらく ・ 1.1〜2.6 光から 現像 ・ 2.65 シール + 時刻 ・ 3.2 ボタン。
// とちゅうで タップ = すぐ さいご。タップで 全画面(2回 タップで 2.2倍 ・ 下へ 110pt で とじる)。

struct ReleaseRevealV89View: View {
    let image: UIImage?
    let ordinal: Int
    let count: Int
    var tag: String?
    var time: String
    var place: String?
    var playsReveal: Bool
    var onFinish: (YesterdayRevealView.Outcome) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var skipped = false
    @State private var finished = false
    @State private var dragY: CGFloat = 0
    @State private var full = false
    @State private var zoomed = false
    @State private var fullDrag: CGFloat = 0
    @State private var toast: String?
    @State private var flying: Bool?    // true = 公開(上へ) / false = 自分だけ(下へ)
    @State private var scheduled: [DispatchWorkItem] = []

    private static let total = 3.2
    private let lime = HV.lime

    private func ease(_ x: Double, _ p: Double) -> Double { 1 - pow(1 - max(0, min(1, x)), p) }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()
                RadialGradient(colors: [Color(hex: "24A03C").opacity(0.4), .clear], center: UnitPoint(x: 0.5, y: 1.05), startRadius: 0, endRadius: proxy.size.height * 0.55).ignoresSafeArea()
                TimelineView(.animation(paused: finished)) { ctx in
                    let t = playsReveal && !reduceMotion ? (skipped ? Self.total : ctx.date.timeIntervalSince(start)) : Self.total
                    content(t: t, size: proxy.size)
                }
                if full { fullScreen(size: proxy.size) }
                if let toast {
                    Text(toast).font(LF.inter(700, 13)).foregroundStyle(HV.ink).padding(.horizontal, 16).frame(height: 38).background(.white, in: Capsule())
                        .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 130).transition(.opacity)
                }
            }
            .offset(y: max(0, dragY))
            .gesture(DragGesture(minimumDistance: 12).onChanged { if !full && $0.translation.height > 0 { dragY = $0.translation.height } }
                .onEnded { v in if !full { if v.translation.height > 140 { finish(.later) } else { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { dragY = 0 } } } })
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .onAppear(perform: begin)
        .onDisappear { scheduled.forEach { $0.cancel() } }
        .accessibilityAction(.escape) { finish(.later) }
    }

    // MARK: カード

    private func content(t: Double, size: CGSize) -> some View {
        let cw: CGFloat = 300, ch: CGFloat = 400
        let rise = ease(t / 0.52, 3)
        let done = t >= 2.65
        let dev = ease((t - 1.1) / 1.5, 2.2)
        return ZStack {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Text("YESTERDAY ・ \(Self.dateLabel)").font(LF.mono(11)).tracking(2).foregroundStyle(.white.opacity(0.7))
                    HStack(spacing: 4) { ForEach(0..<max(1, count), id: \.self) { i in Circle().fill(i < ordinal ? lime : .white.opacity(0.25)).frame(width: 6, height: 6) } }
                }.opacity(rise)
                ZStack {
                    photoLayer(t: t, dev: dev).frame(width: cw, height: ch)
                    if t < 1.5 { iris(t: t).frame(width: cw, height: ch) }
                    streak(t: t).frame(width: cw, height: ch)
                    if done { stickers.transition(.identity) }
                }
                .frame(width: cw, height: ch).clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
                .shadow(color: .black.opacity(0.6), radius: 24, y: 16)
                .offset(y: (1 - rise) * 30).opacity(rise)
                .opacity(flying == nil ? 1 : 0)
                .offset(y: flying == true ? -size.height : (flying == false ? 160 : 0))
                .animation(.easeIn(duration: 0.62), value: flying)
                .onTapGesture {
                    if t < Self.total - 0.5 { skipToEnd() } else { Haptics.play(.tick); openFull() }
                }
                Text("↗ タップで 大きく").font(LF.inter(600, 12)).foregroundStyle(.white.opacity(0.5)).opacity(done ? 1 : 0)
            }
            VStack(spacing: 10) {
                Spacer()
                Button { publish(true) } label: {
                    Text("友だちに 公開").font(LF.inter(800, 16)).foregroundStyle(HV.ink).frame(maxWidth: .infinity).frame(height: 56).background(lime, in: Capsule())
                }.buttonStyle(HVPress(scale: 0.97))
                Button { publish(false) } label: {
                    Text("自分だけ").font(LF.inter(800, 16)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 56).background(.white.opacity(0.1), in: Capsule())
                }.buttonStyle(HVPress(scale: 0.97))
            }.padding(.horizontal, 24).padding(.bottom, 30)
            .opacity(ease((t - 3.2) / 0.35, 3)).offset(y: (1 - ease((t - 3.2) / 0.35, 3)) * 30)
            .allowsHitTesting(t >= 3.2 && flying == nil && !finished)
        }
    }

    private static var dateLabel: String {
        let f = DateFormatter(); f.dateFormat = "MM/dd"
        return f.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
    }

    /// 現像:光(まっ白・ぼかし)→ くっきり
    private func photoLayer(t: Double, dev: Double) -> some View {
        ZStack {
            Color(hex: "1C1C1F")
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
                    .saturation(dev * 1.05).contrast(0.6 + 0.4 * dev)
                    .blur(radius: 16 * (1 - dev))
                    .scaleEffect(1.08 - 0.08 * dev)
                Color.white.opacity(1 - dev)
            }
        }.clipped()
    }

    /// しぼり(羽根 7枚):穴の 7角形が 0 → 168 ・ 43°ねじれる ・ そのあと 輪が 広がって 消える
    private func iris(t: Double) -> some View {
        Canvas { ctx, sz in
            let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
            let open = ease((t - 0.6) / 0.6, 3)
            let outer = ease((t - 1.15) / 0.3, 2)
            let r = 168 * open + 130 * outer
            let twist = 43.0 * open * .pi / 180
            let verts = (0..<7).map { i -> CGPoint in
                let a = twist + Double(i) * 2 * .pi / 7 - .pi / 2
                return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            }
            var shape = Path(CGRect(origin: .zero, size: sz))
            var hole = Path(); hole.addLines(verts); hole.closeSubpath()
            shape.addPath(hole)
            ctx.opacity = 1 - ease((t - 1.15) / 0.3, 1)
            ctx.fill(shape, with: .color(Color(hex: "0B0C0D")), style: FillStyle(eoFill: true))
            for i in 0..<7 {
                let a = verts[i], b = verts[(i + 1) % 7]
                let dx = b.x - a.x, dy = b.y - a.y, len = max(1, hypot(dx, dy))
                var line = Path(); line.move(to: a); line.addLine(to: CGPoint(x: a.x - dx / len * 400, y: a.y - dy / len * 400))
                ctx.stroke(line, with: .color(.white.opacity(0.16)), lineWidth: 1)
            }
            // 黄緑の 輪(半径 150 ・ 光る)→ 広がって 消える
            let ringR = 150 + (max(sz.width, sz.height) - 150) * outer
            ctx.opacity = (1 - outer) * (0.6 + 0.4 * (1 - open))
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - ringR, y: c.y - ringR, width: ringR * 2, height: ringR * 2)), with: .color(lime), lineWidth: 3)
        }.allowsHitTesting(false)
    }

    /// 光の すじ(オレンジ → 黄緑)が 左から 右へ 1.1秒(1.4〜2.5)
    private func streak(t: Double) -> some View {
        let u = (t - 1.4) / 1.1
        return GeometryReader { g in
            if u > 0 && u < 1 {
                LinearGradient(colors: [.clear, Color(hex: "FF9F43").opacity(0.55), lime.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: g.size.width * 0.5).offset(x: -g.size.width * 0.5 + g.size.width * 2 * CGFloat(u) * 0.75)
                    .blendMode(.plusLighter)
            }
        }.allowsHitTesting(false)
    }

    private var stickers: some View {
        ZStack {
            if let tag, !tag.isEmpty {
                Text("#\(tag)").font(LF.inter(900, 15)).foregroundStyle(HV.ink).padding(.horizontal, 12).frame(height: 32).background(lime, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .rotationEffect(.degrees(6)).shadow(color: .black.opacity(0.35), radius: 4, x: 2, y: 3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(16)
                    .transition(.scale(scale: 2.6).combined(with: .opacity))
            }
            Text(time).font(LF.mono(15)).foregroundStyle(lime).shadow(color: lime.opacity(0.8), radius: 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(16)
        }
    }

    // MARK: 全画面(カードから ズームで ひろがる)

    private func openFull() {
        withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) { full = true }
    }

    private func fullScreen(size: CGSize) -> some View {
        ZStack {
            Color.black.opacity(1 - Double(min(1, fullDrag / 300)) * 0.6).ignoresSafeArea()
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
                    .scaleEffect((zoomed ? 2.2 : 1) * (1 - min(0.3, fullDrag / 600)))
                    .offset(y: fullDrag)
                    .onTapGesture(count: 2) { Haptics.play(.tick); withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { zoomed.toggle() } }
                    .gesture(MagnifyGesture().onEnded { v in withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { zoomed = v.magnification > 1 } })
                    .simultaneousGesture(DragGesture(minimumDistance: 12).onChanged { if !zoomed && $0.translation.height > 0 { fullDrag = $0.translation.height } }
                        .onEnded { v in if v.translation.height > 110 { closeFull() } else { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { fullDrag = 0 } } })
            }
            VStack {
                HStack {
                    Button { Haptics.play(.tick); closeFull() } label: { Image(systemName: "xmark").font(.system(size: 15, weight: .black)).foregroundStyle(.white).frame(width: 44, height: 44).background(.white.opacity(0.12), in: Circle()) }.buttonStyle(.plain)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(time).font(LF.mono(15)).foregroundStyle(lime)
                        Text([place, "きのう"].compactMap { $0 }.joined(separator: " ・ ")).font(LF.inter(600, 11)).foregroundStyle(.white.opacity(0.6))
                    }
                }.padding(.horizontal, 16).padding(.top, 54)
                Spacer()
                HStack(spacing: 10) {
                    Button { closeFull(); publish(false) } label: { Text("自分だけ").font(LF.inter(800, 15)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 54).background(.white.opacity(0.12), in: Capsule()) }.buttonStyle(.plain)
                    Button { closeFull(); publish(true) } label: { Text("友だちに 公開").font(LF.inter(800, 15)).foregroundStyle(HV.ink).frame(maxWidth: .infinity).frame(height: 54).background(lime, in: Capsule()) }.buttonStyle(.plain)
                }.padding(.horizontal, 20).padding(.bottom, 34)
            }
        }
        .transition(.scale(scale: 0.78).combined(with: .opacity))
    }

    private func closeFull() { withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) { full = false; zoomed = false; fullDrag = 0 } }

    // MARK: 動き

    private func begin() {
        start = Date()
        guard playsReveal, !reduceMotion else { return }
        Haptics.play(.soft)
        at(0.6) { if !skipped { Haptics.play(.shutter) } }
        for i in 0..<6 { at(1.1 + 0.25 * Double(i)) { if !skipped { Haptics.play(.tick, gap: 0) } } }
        at(2.65) { if !skipped { Haptics.play(.heart) } }
        at(2.8) { if !skipped { Haptics.play(.pop) } }
    }

    private func skipToEnd() {
        guard !skipped else { return }
        skipped = true; scheduled.forEach { $0.cancel() }
        Haptics.play(.tick)
    }

    private func publish(_ friends: Bool) {
        guard flying == nil, !finished else { return }
        flying = friends
        if friends { Haptics.play(.success) } else { Haptics.play(.soft) }
        withAnimation { toast = friends ? "公開しました ・ 友だちの きのうに ならびます" : "自分だけ ・ ME に のこります" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { finish(friends ? .posted : .skipped) }
    }

    private func finish(_ o: YesterdayRevealView.Outcome) {
        guard !finished else { return }
        finished = true; scheduled.forEach { $0.cancel() }
        onFinish(o)
    }

    private func at(_ s: Double, _ work: @escaping () -> Void) {
        let item = DispatchWorkItem(block: work); scheduled.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + s, execute: item)
    }
}
