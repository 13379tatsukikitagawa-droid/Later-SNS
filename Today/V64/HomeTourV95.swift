import SwiftUI

// v95-4:はじめての 説明(5つの ステップ)。スポットライト + 下 / 上の カード + 上の 進みの 線。1回 だけ。
// 設定 › ヘルプ から もう1回(`HomeTour.replayRequested`)。

enum HomeTour {
    static let seenKey = "homeTour.seen.v95"
    static let replayRequested = Notification.Name("homeTourReplayRequested")
    static var seen: Bool { UserDefaults.standard.bool(forKey: seenKey) }
    static func markSeen() { UserDefaults.standard.set(true, forKey: seenKey) }

    struct Step { let title: String, body: String, round: Bool }
    static let steps: [Step] = [
        .init(title: "1日 3こま、撮る", body: "ここを 押して 撮影へ。シャッターは 長押し。", round: false),
        .init(title: "24:00 で 消灯", body: "それまでに 撮る。のこりの こまは 右の 3本。", round: false),
        .init(title: "撮った 写真は 現像中", body: "すぐには 見られない。あしたの 9:00 まで ねかせる。", round: true),
        .init(title: "9:00 に 友だちと ひらく", body: "Friends ・ Trip ・ Mondo は 横に スワイプ。", round: false),
        .init(title: "あなたの アイコン", body: "1回 タップ = プロフィール ・ 2回 = きのう。", round: true),
    ]

    /// i 番目の 光る 場所(画面の 座標)
    static func hole(_ i: Int, _ f: HV.Frame) -> CGRect {
        switch i {
        case 0: return CGRect(x: f.cx - 140, y: 722 + 2 * f.mid, width: 280, height: 80)
        case 1: return CGRect(x: 14, y: 106, width: f.w - 28, height: 54)
        case 2: return CGRect(x: f.cx - 134, y: 392 + f.mid - 134, width: 268, height: 268)
        case 3: return CGRect(x: f.cx - 84, y: 622 + f.mid, width: 168, height: 56)
        default: return CGRect(x: f.w - 82, y: 44, width: 68, height: 68)
        }
    }
}

/// 穴の 位置が すべって 動く ように、4つの 値を まとめて 動かす
private struct SpotShape: Shape {
    var r: CGRect, corner: CGFloat
    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { .init(.init(r.minX, r.minY), .init(r.width, r.height)) }
        set { r = CGRect(x: newValue.first.first, y: newValue.first.second, width: newValue.second.first, height: newValue.second.second) }
    }
    func path(in rect: CGRect) -> Path {
        var p = Path(rect)
        p.addRoundedRect(in: r, cornerSize: CGSize(width: corner, height: corner))
        return p
    }
}

private struct SpotRing: Shape {
    var r: CGRect, corner: CGFloat
    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { .init(.init(r.minX, r.minY), .init(r.width, r.height)) }
        set { r = CGRect(x: newValue.first.first, y: newValue.first.second, width: newValue.second.first, height: newValue.second.second) }
    }
    func path(in rect: CGRect) -> Path { Path(roundedRect: r, cornerRadius: corner) }
}

struct HomeTourV95View: View {
    var start = 0
    let onDone: () -> Void
    var body: some View {
        GeometryReader { g in
            HomeTourInner(f: HV.Frame(w: g.size.width, h: g.size.height), start: start, onDone: onDone)
        }.ignoresSafeArea()
    }
}

private struct HomeTourInner: View {
    let f: HV.Frame
    var start = 0
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var i = 0
    @State private var fill: CGFloat = 0
    @State private var pulse = false
    @State private var rect: CGRect = .zero

    private var corner: CGFloat { HomeTour.steps[i].round ? min(rect.width, rect.height) / 2 : 22 }

    var body: some View {
        ZStack {
            SpotShape(r: rect, corner: corner)
                .fill(Color.black.opacity(0.74), style: FillStyle(eoFill: true))
                .contentShape(Rectangle())
                .onTapGesture { next() }
            SpotRing(r: rect, corner: corner)
                .stroke(HV.lime, lineWidth: 2)
                .shadow(color: HV.lime.opacity(0.6), radius: 10)
                .allowsHitTesting(false)
            SpotRing(r: rect.insetBy(dx: pulse ? -10 : 0, dy: pulse ? -10 : 0), corner: corner + (pulse ? 10 : 0))
                .stroke(HV.lime.opacity(pulse ? 0 : 0.6), lineWidth: 2)
                .allowsHitTesting(false)
            cardLayer
        }
        .ignoresSafeArea()
        .onAppear {
            i = min(max(start, 0), HomeTour.steps.count - 1)
            rect = HomeTour.hole(i, f)
            runFill()
            if !reduceMotion { withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true } }
        }
        .accessibilityAddTraits(.isModal)
    }

    private var cardLayer: some View {
        let below = rect.midY < f.h / 2
        let s = HomeTour.steps[i]
        let last = i == HomeTour.steps.count - 1
        return ZStack(alignment: below ? .top : .bottom) {
            Color.clear
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    ForEach(0..<HomeTour.steps.count, id: \.self) { k in
                        Capsule().fill(.white.opacity(0.18)).frame(height: 3)
                            .overlay(alignment: .leading) {
                                GeometryReader { g in Capsule().fill(HV.lime).frame(width: g.size.width * (k < i ? 1 : (k == i ? fill : 0))) }
                            }
                    }
                }
                Text(String(format: "%02d / %02d ・ TODAY", i + 1, HomeTour.steps.count)).font(LF.mono(11)).tracking(1.4).foregroundStyle(HV.lime).padding(.top, 14)
                Text(s.title).font(LF.inter(800, 21)).foregroundStyle(.white).padding(.top, 6)
                Text(s.body).font(LF.inter(500, 13.5)).foregroundStyle(.white.opacity(0.7)).fixedSize(horizontal: false, vertical: true).padding(.top, 6)
                HStack {
                    Button { Haptics.play(.tick); finish(silent: true) } label: { Text("スキップ").font(LF.inter(700, 13)).foregroundStyle(.white.opacity(0.55)).frame(minWidth: 64, minHeight: 44, alignment: .leading) }.buttonStyle(.plain)
                    Spacer()
                    Button { next() } label: {
                        Text(last ? "はじめる" : "つぎへ ›").font(LF.inter(800, 14)).foregroundStyle(HV.ink).padding(.horizontal, 20).frame(height: 44).background(HV.lime, in: Capsule())
                    }.buttonStyle(.plain)
                }.padding(.top, 8)
            }
            .padding(18)
            .background(Color(hex: "141416"), in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.white.opacity(0.08)))
            .overlay(alignment: below ? .top : .bottom) {
                // しっぽ(光る 所を 指す)
                Image(systemName: "triangle.fill").font(.system(size: 14)).foregroundStyle(Color(hex: "141416"))
                    .rotationEffect(.degrees(below ? 0 : 180))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, max(20, min(f.w - 32 - 40, rect.midX - 16 - 7)))
                    .padding(below ? .top : .bottom, -11)
            }
            .padding(.horizontal, 16)
            .padding(below ? .top : .bottom, below ? rect.maxY + 18 : f.h - rect.minY + 18)
            .id(i)
            .transition(.opacity)
        }
        .frame(width: f.w, height: f.h, alignment: below ? .top : .bottom)
        .animation(.easeOut(duration: 0.25), value: i)
    }

    private func runFill() {
        fill = 0
        withAnimation(.linear(duration: reduceMotion ? 0 : 0.5)) { fill = 1 }
    }

    private func next() {
        if i >= HomeTour.steps.count - 1 { finish(silent: false); return }
        Haptics.play(.sel)
        i += 1
        withAnimation(reduceMotion ? nil : .timingCurve(0.3, 1.1, 0.4, 1, duration: 0.5)) { rect = HomeTour.hole(i, f) }
        runFill()
    }

    private func finish(silent: Bool) {
        if !silent { Haptics.play(.success) }
        HomeTour.markSeen()
        onDone()
    }
}
