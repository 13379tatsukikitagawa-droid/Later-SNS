import SwiftUI

// P02:Home(モック v64〜v66)の 部品。値は spec/screens/H01〜H10.json と PROMPT_v64 / v65 / v66 の 最終値。
// 座標は 幅 390pt の モックの まま(`HV.Frame` が 幅・高さの ちがいを 吸収)。

enum HV {
    static let bg = Color(red: 239 / 255, green: 239 / 255, blue: 234 / 255)          // #EFEFEA
    static let ink = Color(hex: "111111")
    static let green = Color(hex: "24A03C")
    static let lime = Color(hex: "C8F25A")
    static let red = Color(hex: "D8262C")
    static let gray = Color(hex: "8E8E93")
    static let cardBase = Color(hex: "0D0D0E")

    /// 画面の 大きさ。左右の はしに 合わせる 物は `left`/`right`、まんなかの 物は `mid` で 上下に ずらす
    struct Frame {
        let w: CGFloat, h: CGFloat
        var mid: CGFloat { (h - 844) / 2 }
        var cx: CGFloat { w / 2 }
        /// モックの x(390 基準)→ この 画面の x(中心から の 距離を 保つ)
        func x(_ mx: CGFloat) -> CGFloat { mx + (w - 390) / 2 }
        /// 右はしからの 距離を 保つ x
        func xr(_ mx: CGFloat) -> CGFloat { w - (390 - mx) }
    }
}

// MARK: - カメラの 絵(線画)

/// モックの `CMG`(viewBox -4 -2 72 54):角丸の 本体 + 上の 出っぱり
struct HVCameraBody: Shape {
    func path(in r: CGRect) -> Path {
        let sx = r.width / 72, sy = r.height / 54
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + (x + 4) * sx, y: r.minY + (y + 2) * sy) }
        var p = Path()
        p.move(to: P(10, 12))
        p.addLine(to: P(19, 12))
        p.addLine(to: P(23, 5.5))
        p.addQuadCurve(to: P(25.6, 4), control: P(24, 4.3))
        p.addLine(to: P(38.4, 4))
        p.addQuadCurve(to: P(41, 5.5), control: P(40, 4.3))
        p.addLine(to: P(45, 12))
        p.addLine(to: P(54, 12))
        p.addQuadCurve(to: P(60, 18), control: P(60, 12))
        p.addLine(to: P(60, 42))
        p.addQuadCurve(to: P(54, 48), control: P(60, 48))
        p.addLine(to: P(10, 48))
        p.addQuadCurve(to: P(4, 42), control: P(4, 48))
        p.addLine(to: P(4, 18))
        p.addQuadCurve(to: P(10, 12), control: P(4, 12))
        p.closeSubpath()
        return p
    }
}

/// カメラの 絵:本体 + レンズ + 絞り + ライムの 点(フラッシュ)。`aperture` = 絞りの 大きさ(押すと 0.45)
struct HVCameraGlyph: View {
    var width: CGFloat = 67
    var line: CGFloat = 3.2
    var color: Color = .white
    var aperture: CGFloat = 1
    var showsFlash = true

    var body: some View {
        let s = width / 72
        ZStack(alignment: .topLeading) {
            HVCameraBody().stroke(color, style: StrokeStyle(lineWidth: line, lineJoin: .round))
            Circle().stroke(color, lineWidth: line).frame(width: 23 * s, height: 23 * s).offset(x: (32 - 11.5 + 4) * s, y: (29 - 11.5 + 2) * s)
            Circle().fill(color).frame(width: 10.4 * s * aperture, height: 10.4 * s * aperture)
                .offset(x: (32 - 5.2 * aperture + 4) * s, y: (29 - 5.2 * aperture + 2) * s)
            if showsFlash {
                Circle().fill(HV.lime).frame(width: 4.8 * s, height: 4.8 * s).offset(x: (51.5 - 2.4 + 4) * s, y: (20 - 2.4 + 2) * s)
            }
        }
        .frame(width: width, height: width * 54 / 72, alignment: .topLeading)
    }
}

/// 写真が 重なった 絵(Yesterday)
struct HVStackGlyph: View {
    var size: CGFloat = 26
    var color: Color = .white
    var line: CGFloat = 2.2
    var body: some View {
        let u = size / 26
        ZStack {
            RoundedRectangle(cornerRadius: 5 * u).stroke(color, lineWidth: line).frame(width: 15 * u, height: 17 * u).offset(x: 3.5 * u, y: -3 * u)
            ZStack {
                RoundedRectangle(cornerRadius: 5 * u).fill(Color.black.opacity(0.0))
                RoundedRectangle(cornerRadius: 5 * u).stroke(color, lineWidth: line)
                Circle().stroke(color, lineWidth: line).frame(width: 6 * u, height: 6 * u)
            }.frame(width: 15 * u, height: 17 * u).offset(x: -2.5 * u, y: 2.5 * u)
        }.frame(width: size, height: size)
    }
}

/// 四すみ・目次の アイコン(線画)。`HVIcon.kind` で えらぶ
enum HVIconKind { case yesterday, trip, mondo, friends, camera }

struct HVIcon: View {
    let kind: HVIconKind
    var size: CGFloat = 26
    var color: Color = .white

    var body: some View {
        Group {
            switch kind {
            case .yesterday: HVStackGlyph(size: size * 0.9, color: color, line: size / 13)
            case .trip: Image(systemName: "briefcase").font(.system(size: size * 0.85, weight: .semibold))
            case .mondo: Image(systemName: "globe").font(.system(size: size * 0.9, weight: .medium))
            case .friends: Image(systemName: "person.2").font(.system(size: size * 0.85, weight: .semibold))
            case .camera: Image(systemName: "record.circle").font(.system(size: size * 0.95, weight: .medium))
            }
        }
        .foregroundStyle(color)
        .frame(width: size, height: size)
    }
}

// MARK: - ガラスの ふち(光の 向きで 動く)

struct HVRim: View {
    var radius: CGFloat
    var width: CGFloat = 1.2
    var body: some View { LGGlassEdge(radius: radius, width: width) }
}

/// すりガラス(旧 OS でも 同じ 見え方):白 + うしろを ぼかす + ふち
struct HVGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    var tint: Double = 0.14
    var blur: Bool = true
    var edge: CGFloat = 1.2
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(shape.fill(Color.white.opacity(tint)))
            .overlay(shape.strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
            .overlay(HVRim(radius: radius, width: edge))
    }
}

extension View {
    func hvGlass(radius: CGFloat, tint: Double = 0.14, edge: CGFloat = 1.2) -> some View {
        modifier(HVGlass(shape: RoundedRectangle(cornerRadius: radius, style: .continuous), tint: tint, edge: edge, radius: radius))
    }
}

// MARK: - 押した ときの ばね

struct HVPress: ButtonStyle {
    var scale: CGFloat = 0.9
    var onPress: ((Bool) -> Void)? = nil
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.timingCurve(0.3, 1.5, 0.5, 1, duration: 0.16), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, v in onPress?(v) }
    }
}

// MARK: - ステッカー(星・波線・花)

struct HVStar: View {
    var size: CGFloat = 34
    var body: some View {
        Canvas { ctx, sz in
            var p = Path()
            let c = CGPoint(x: sz.width / 2, y: sz.height / 2), r = sz.width / 2
            for i in 0..<4 {
                let a = Double(i) * .pi / 2 - .pi / 2
                let a2 = a + .pi / 4
                let tip = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
                let inner = CGPoint(x: c.x + CGFloat(cos(a2)) * r * 0.28, y: c.y + CGFloat(sin(a2)) * r * 0.28)
                if i == 0 { p.move(to: tip) } else { p.addLine(to: tip) }
                p.addLine(to: inner)
            }
            // 先は 丸く
            var q = Path()
            q.move(to: CGPoint(x: c.x, y: c.y - r))
            for i in 0..<4 {
                let a = Double(i) * .pi / 2 - .pi / 2
                let next = a + .pi / 2
                let tip2 = CGPoint(x: c.x + CGFloat(cos(next)) * r, y: c.y + CGFloat(sin(next)) * r)
                q.addQuadCurve(to: tip2, control: c)
            }
            q.closeSubpath()
            ctx.fill(q, with: .color(.white))
            ctx.stroke(q, with: .color(.black), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
    }
}

struct HVSquiggle: View {
    var body: some View {
        Canvas { ctx, sz in
            var p = Path()
            let n = 4, w = (sz.width - 4) / CGFloat(n)
            p.move(to: CGPoint(x: 2, y: sz.height * 0.8))
            for i in 0..<n {
                let x0 = 2 + CGFloat(i) * w
                p.addQuadCurve(to: CGPoint(x: x0 + w * 0.5, y: sz.height * 0.15), control: CGPoint(x: x0 + w * 0.15, y: sz.height * 0.15))
                p.addQuadCurve(to: CGPoint(x: x0 + w, y: sz.height * 0.8), control: CGPoint(x: x0 + w * 0.85, y: sz.height * 0.15))
            }
            ctx.stroke(p, with: .color(.white), style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 46, height: 18)
        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }
}

struct HVFlower: View {
    var size: CGFloat = 36
    var center: Color = HV.red
    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                Circle().fill(.white).overlay(Circle().stroke(.black, lineWidth: 2))
                    .frame(width: size * 0.42, height: size * 0.42)
                    .offset(y: -size * 0.27)
                    .rotationEffect(.degrees(Double(i) * 72))
            }
            Circle().fill(center).overlay(Circle().stroke(.black, lineWidth: 1.6)).frame(width: size * 0.3, height: size * 0.3)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.35), radius: 3, y: 4)
    }
}
