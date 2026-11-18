import SwiftUI

// v94 A:撮影ボタン = Lattag の アイコン。押す まえ = # と レンズの 線だけ(息を する 輪)・ 長押しで ライムが 下から たまる ・ 100% で 完成 → 撮る。
// 見本 C23 C24 ・ 動き M35。大きさ 84(押せる 範囲は 外の 104)。

struct HashOutlineShape: Shape {
    func path(in r: CGRect) -> Path {
        let k = r.width / 1024
        var p = Path()
        for b in [CGRect(x: 196, y: 320, width: 632, height: 104), CGRect(x: 196, y: 600, width: 632, height: 104),
                  CGRect(x: 320, y: 196, width: 104, height: 632), CGRect(x: 600, y: 196, width: 104, height: 632)] {
            p.addRoundedRect(in: CGRect(x: r.minX + b.minX * k, y: r.minY + b.minY * k, width: b.width * k, height: b.height * k), cornerSize: CGSize(width: 52 * k, height: 52 * k))
        }
        p.addEllipse(in: CGRect(x: r.minX + 396 * k, y: r.minY + 396 * k, width: 232 * k, height: 232 * k))
        return p
    }
}

/// 下から たまる 波(上の ふちが 横に 流れる)
struct WaveFillShape: Shape {
    var level: Double
    var phase: Double
    var animatableData: AnimatablePair<Double, Double> { get { .init(level, phase) } set { level = newValue.first; phase = newValue.second } }
    func path(in r: CGRect) -> Path {
        var p = Path()
        let y0 = r.maxY - r.height * CGFloat(max(0, min(1, level)))
        guard level > 0 else { return p }
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: y0))
        let amp: CGFloat = level >= 1 ? 0 : 2.6
        var x = r.minX
        while x <= r.maxX { p.addLine(to: CGPoint(x: x, y: y0 + amp * sin((x / r.width) * 2 * .pi * 1.5 + CGFloat(phase)))); x += 2 }
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.closeSubpath()
        return p
    }
}

struct ShutterIconV94: View {
    var progress: Double            // 長押しの 進み 0 → 1
    var holding: Bool
    var video: Bool
    var recording: Bool
    var dead: Bool
    var late: Bool
    var snapToken: Int
    var recordingProgress: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownK = 0.0
    private let s: CGFloat = 84
    private let lime = Color(hex: "C8F25A")

    var body: some View {
        let k = max(shownK, 0)
        ZStack {
            // 合図:ライムの 輪が ゆっくり 息を する(押す まえ だけ)
            if !holding && !dead && !recording {
                TimelineView(.animation(paused: reduceMotion)) { ctx in
                    let u = reduceMotion ? 0.5 : (sin(ctx.date.timeIntervalSinceReferenceDate / 2.6 * 2 * .pi) + 1) / 2
                    RoundedRectangle(cornerRadius: (s + 16) * 0.245, style: .continuous).strokeBorder(lime.opacity(reduceMotion ? 0.6 : u), lineWidth: 1.8)
                        .frame(width: s + 16, height: s + 16).scaleEffect(0.96 + 0.06 * u)
                }
            }
            ZStack {
                RoundedRectangle(cornerRadius: s * 0.224, style: .continuous).fill(Color(hex: "151517"))
                HashOutlineShape().stroke(lime.opacity(0.6 - 0.4 * k), lineWidth: 1.5).padding(0)
                // 本物の アイコン(下から たまる)
                OPIcon(size: s, lensScale: 1)
                    .mask(TimelineView(.animation(paused: !holding || reduceMotion)) { ctx in
                        WaveFillShape(level: k, phase: reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate * 6).frame(width: s, height: s)
                    })
                if video { Circle().fill(Color(hex: "FF453A")).frame(width: s * 0.075, height: s * 0.075).opacity(0.95) }
                if dead { RoundedRectangle(cornerRadius: s * 0.224, style: .continuous).fill(Color.black.opacity(0.55)) }
                RoundedRectangle(cornerRadius: s * 0.224, style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 1)
            }
            .frame(width: s, height: s)
            .shadow(color: .black.opacity(0.55), radius: 11, y: 12)
            .saturation(dead ? 0 : 1)
            // 外に 角丸の ライムの 線が 1周(k と 同じ)
            RoundedRectangle(cornerRadius: (s + 10) * 0.245, style: .continuous)
                .trim(from: 0, to: recording ? recordingProgress : k)
                .stroke(late ? Color(hex: "FF3B30") : lime, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                .shadow(color: lime.opacity(0.7), radius: 5)
                .frame(width: s + 10, height: s + 10)
                .rotationEffect(.degrees(0))
                .opacity(k > 0 || recording ? 1 : 0)
        }
        .scaleEffect(holding ? 0.93 + 0.09 * k : 1)
        .keyframeAnimator(initialValue: 1.0, trigger: snapToken) { c, v in c.scaleEffect(v) } keyframes: { _ in
            KeyframeTrack { CubicKeyframe(0.86, duration: 0.12); CubicKeyframe(1.08, duration: 0.18); CubicKeyframe(1, duration: 0.12) }
        }
        .overlay {
            // 完成の フラッシュ
            RoundedRectangle(cornerRadius: s * 0.224, style: .continuous).fill(.white).frame(width: s, height: s)
                .keyframeAnimator(initialValue: 0.0, trigger: snapToken) { c, v in c.opacity(v) } keyframes: { _ in
                    KeyframeTrack { LinearKeyframe(0.9, duration: 0.05); CubicKeyframe(0, duration: 0.46) }
                }.allowsHitTesting(false)
        }
        .onChange(of: progress) { old, new in
            if holding || new >= old { shownK = new }
            else { withAnimation(.easeOut(duration: 0.35)) { shownK = new } }   // はなすと 下へ 抜けて いく
        }
        .onChange(of: holding) { _, h in if !h { withAnimation(.easeOut(duration: 0.35)) { shownK = 0 } } }
        .onAppear { shownK = progress }
    }
}
