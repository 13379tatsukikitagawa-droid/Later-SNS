import SwiftUI

// P15(v71)§4 + v73:まんなかの 本物の カメラの レンズ。直径 312 の 座標で 作って 0.737倍(≈ 230pt)。押す 間 0.70倍。まんなかは 黄緑の シャッター。
// 全部 Shape と グラデーション(画像 ・ ぼかし なし)。動かない 部分は 1つの Canvas + drawingGroup。

/// しぼり羽根:6枚。`hole` = 羽根の 内側の 線が 中心から 何pt か(ふだん 104 ・ 押す 間 66 ・ シャッターで 0)
struct HV68Iris: Shape {
    var hole: CGFloat
    var twist: Double = -18
    var animatableData: CGFloat { get { hole } set { hole = newValue } }
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        var p = Path()
        let h = max(0.001, hole)
        let prog = Double(max(0, min(1, (104 - hole) / 104)))      // しまるほど 少し 回る
        let rot = twist * prog * .pi / 180
        let rv = h / cos(.pi / 6)                                   // 六角形の 頂点までの 半径
        for k in 0..<6 {
            let a0 = Double(k) * .pi / 3 + rot - .pi / 2
            let a1 = a0 + .pi / 3
            func pt(_ rad: CGFloat, _ a: Double) -> CGPoint { CGPoint(x: c.x + rad * CGFloat(cos(a)), y: c.y + rad * CGFloat(sin(a))) }
            // 内側の 辺 = 六角形の 1辺。外へは 半径 130 まで(円で 切る)
            p.move(to: pt(rv, a0))
            p.addLine(to: pt(rv, a1))
            p.addLine(to: pt(130, a1 + 0.35))
            p.addLine(to: pt(130, a0 - 0.1))
            p.closeSubpath()
        }
        return p
    }
}

/// 動かない 部分(ふち ・ 胴 ・ ギザギザ ・ 弧 ・ 刻印 ・ ガラス ・ 輪)
private struct HV68LensBody: View {
    let shotsUsed: Int

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            func disc(_ r: CGFloat) -> Path { Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)) }
            func hex(_ s: String) -> Color { Color(hex: s) }

            // 155 金属の ふち(左上が 光る クロム)
            ctx.fill(disc(155), with: .linearGradient(Gradient(stops: [
                .init(color: hex("F2F2F5"), location: 0), .init(color: hex("5B5B61"), location: 0.25), .init(color: hex("1C1C1F"), location: 0.5),
                .init(color: hex("7A7A80"), location: 0.75), .init(color: hex("26262A"), location: 1)]),
                startPoint: CGPoint(x: c.x - 110, y: c.y - 110), endPoint: CGPoint(x: c.x + 110, y: c.y + 110)))
            // 149 黒い 胴
            ctx.fill(disc(149), with: .radialGradient(Gradient(stops: [
                .init(color: hex("17171A"), location: 0.72), .init(color: hex("0C0C0E"), location: 0.90), .init(color: hex("202024"), location: 1)]),
                center: c, startRadius: 0, endRadius: 149))
            // 139〜151 ギザギザ(3° ごと 120本)
            for i in 0..<120 {
                let a = Double(i) * 3 * .pi / 180
                var l = Path()
                l.move(to: CGPoint(x: c.x + 139 * CGFloat(cos(a)), y: c.y + 139 * CGFloat(sin(a))))
                l.addLine(to: CGPoint(x: c.x + 151 * CGFloat(cos(a)), y: c.y + 151 * CGFloat(sin(a))))
                ctx.stroke(l, with: .color(.white.opacity(0.09)), lineWidth: 1.6)
            }
            // 137.5 字の 帯の 地
            ctx.fill(disc(137.5), with: .color(hex("0A0A0C")))
            ctx.stroke(disc(137.5), with: .color(hex("C8F25A").opacity(0.9)), lineWidth: 3)
            // 141〜149 撮影の 弧(のこり = 黄緑 + 光 ・ 使った = 白 16%)。上から 時計まわり ・ 1本 92°
            for i in 0..<3 {
                let start = -76.0 + Double(i) * 120
                var p = Path()
                p.addArc(center: c, radius: 145, startAngle: .degrees(start), endAngle: .degrees(start + 92), clockwise: false)
                if i < shotsUsed {
                    ctx.stroke(p, with: .color(.white.opacity(0.16)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                } else {
                    ctx.drawLayer { l in
                        l.addFilter(.shadow(color: Color(hex: "C8F25A").opacity(0.8), radius: 6))
                        l.stroke(p, with: .color(Color(hex: "C8F25A")), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    }
                }
            }
            // 121 ふちの 刻印(円に 沿った 字 ・ 円周に ぴったり 2回)
            let unit = "LATTAG ● 3 SHOTS A DAY ● OPENS 9:00 ● "
            let chars = Array(unit + unit)
            let lime = (unit as NSString).range(of: "3 SHOTS")
            for (i, ch) in chars.enumerated() {
                if ch == " " { continue }
                let idx = i % unit.count
                let isLime = idx >= lime.location && idx < lime.location + lime.length
                let a = Double(i) / Double(chars.count) * 2 * .pi
                var cc = ctx
                cc.translateBy(x: c.x, y: c.y)
                cc.rotate(by: .radians(a))
                cc.translateBy(x: 0, y: -121)
                cc.draw(Text(String(ch)).font(LF.mono(9.5)).foregroundStyle(isLime ? Color(hex: "C8F25A") : Color.white.opacity(0.62)), at: .zero, anchor: .center)
            }
            // 113 前の ガラス(いちばん 奥まで 黒い)
            let gc = CGPoint(x: c.x - 113 + 226 * 0.44, y: c.y - 113 + 226 * 0.38)
            ctx.fill(disc(113), with: .radialGradient(Gradient(stops: [
                .init(color: hex("1D2E16"), location: 0), .init(color: hex("070B06"), location: 0.45), .init(color: hex("020302"), location: 0.85), .init(color: hex("0C0F0B"), location: 1)]),
                center: gc, startRadius: 0, endRadius: 150))
            ctx.stroke(disc(113), with: .color(.black), lineWidth: 3)
            // 111 / 92 / 70 中の レンズの 輪
            ctx.stroke(disc(111), with: .color(.white.opacity(0.18)), lineWidth: 1)
            ctx.stroke(disc(92), with: .color(Color(hex: "3BD35A").opacity(0.16)), lineWidth: 1)
            ctx.stroke(disc(70), with: .color(Color(hex: "C8F25A").opacity(0.18)), lineWidth: 1)
        }
        .frame(width: 312, height: 312)
        .drawingGroup()
    }
}

/// ガラスの 反射(コーティングの 色)。ゆっくり 回る 色の 帯だけ 動く(16秒で 1回転 ・ 見えない ときは 止める)
private struct HV68LensGlass: View {
    var body: some View {
        ZStack {
            // 反射 1(左上):黄緑 34%(幅 144 ・ 高さ 112 ・ -18°)
            Ellipse().fill(RadialGradient(colors: [Color(hex: "C8F25A").opacity(0.34), .clear], center: .center, startRadius: 0, endRadius: 56))
                .frame(width: 144, height: 112).rotationEffect(.degrees(-18)).position(x: 138, y: 104)
            // 反射 2(右下):緑 34%
            Ellipse().fill(RadialGradient(colors: [Color(hex: "3BD35A").opacity(0.34), Color(red: 36 / 255, green: 160 / 255, blue: 60 / 255).opacity(0)], center: .center, startRadius: 0, endRadius: 30))
                .frame(width: 81, height: 59).position(x: 201, y: 204)
            // 回る 色の 帯(黄緑 ・ 緑 16%)
            // v111:16秒で 1回転と ゆっくり なので 12fps で 十分(60fps の 状態アニメは かえって 重い)
            PausableTimeline(minimumInterval: 1.0 / 12) { date in
                let a = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 16) / 16 * 360
                Circle().fill(AngularGradient(stops: [
                    .init(color: .clear, location: 0), .init(color: Color(hex: "C8F25A").opacity(0.16), location: 0.12),
                    .init(color: .clear, location: 0.2), .init(color: .clear, location: 0.55),
                    .init(color: Color(hex: "3BD35A").opacity(0.16), location: 0.68), .init(color: .clear, location: 0.78), .init(color: .clear, location: 1)],
                    center: .center))
                    .rotationEffect(.degrees(a))
            }
            // 白い ハイライト(やわらかい)
            Ellipse().fill(RadialGradient(colors: [.white.opacity(0.34), .clear], center: .center, startRadius: 0, endRadius: 52))
                .frame(width: 142, height: 126).position(x: 136, y: 106)
            // 小さな 光の 点
            Circle().fill(RadialGradient(colors: [.white.opacity(0.95), .clear], center: .center, startRadius: 0, endRadius: 6)).frame(width: 12, height: 12).position(x: 204, y: 103)
        }
        .frame(width: 312, height: 312)
        .clipShape(Circle().inset(by: 43))
        .allowsHitTesting(false)
    }
}

struct HV68Lens: View {
    let input: HomeV64Input
    let pressing: Bool
    let onPress: (Bool) -> Void
    let onTap: () -> Void
    @State private var hole: CGFloat = 104
    @State private var dialRot: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var tapped = false

    var body: some View {
        // たてに スクロール できる ように、DragGesture は 使わない。押している 間は Button の isPressed で とる
        Button {
            tapped = true
        } label: { lensBody }
        .buttonStyle(HVPress(scale: 1.0, onPress: { p in
            if p {
                onPress(true)
                withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.75)) { hole = 66 }
            } else {
                onPress(false)
                DispatchQueue.main.async {
                    if tapped {
                        tapped = false
                        if reduceMotion { withAnimation(.easeOut(duration: 0.4)) { hole = 104 } }
                        else {
                            withAnimation(.easeIn(duration: 0.09)) { hole = 0 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { withAnimation(.easeOut(duration: 0.16)) { hole = 104 } }
                        }
                        onTap()
                    } else { withAnimation(.easeOut(duration: 0.4)) { hole = 104 } }
                }
            }
        }))
        .accessibilityElement()
        .accessibilityLabel(input.done ? "Yesterday を ひらく" : "撮る。あと \(input.remaining) 枚")
        .accessibilityAddTraits(.isButton)
    }

    private var lensBody: some View {
        let k: CGFloat = pressing ? 0.70 : 0.737
        return ZStack {
            // 黒い 影(半径 26pt 外まで 55% → 0)
            Circle().fill(RadialGradient(colors: [.black.opacity(0.55), .clear], center: .center, startRadius: 155, endRadius: 181)).frame(width: 362, height: 362)
            HV68LensBody(shotsUsed: input.shotsUsed)
            // ふちの 刻印は 押す 間 -14° 回る(ピントを 合わせる 指)は 刻印を 含む 本体ごと 回さず、弧は そのまま
            HV68LensGlass()
            // しぼり羽根(半径 109 で 切る)
            HV68Iris(hole: hole)
                .fill(LinearGradient(colors: [Color(hex: "252B22"), Color(hex: "0A0D09")], startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.97))
                .overlay(HV68Iris(hole: hole).stroke(Color(hex: "C8F25A").opacity(0.22), lineWidth: 1))
                .frame(width: 312, height: 312)
                .clipShape(Circle().inset(by: 47))
                .allowsHitTesting(false)
            if input.done {
                ZStack {
                    Circle().fill(Color(hex: "1A1614"))
                    if let img = input.yesterdayPhoto { Image(uiImage: img).resizable().scaledToFill().clipShape(Circle()) }
                    Circle().fill(RadialGradient(colors: [.black.opacity(0.25), .black.opacity(0.55)], center: .center, startRadius: 0, endRadius: 100))
                    Circle().strokeBorder(.white.opacity(0.5), lineWidth: 2)
                    HVStackGlyph(size: 76, color: .white, line: 4)
                }.frame(width: 200, height: 200)
            }
        }
        .frame(width: 362, height: 362)
        .rotationEffect(.degrees(0))
        .scaleEffect(k)
        .frame(width: 230, height: 230)
        .overlay {
            if !input.done {
                HV72Shutter(pressing: pressing).scaleEffect(k)
            }
        }
        .animation(.timingCurve(0.3, 1.1, 0.4, 1, duration: 0.28), value: pressing)
        .contentShape(Circle())
    }
}
