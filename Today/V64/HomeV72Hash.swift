import SwiftUI

// P17(v73)+ P22-A(v78):Home の 主役 = アプリアイコンと 同じ 大きな「#」+ 黄緑の シャッターボタン。
// 正解:`prompts/reference/PROMPT_v73.md` §1 ・ `PROMPT_v78.md` A。座標は カードの 中(= 画面の y − 178)。動かない ので `drawingGroup`。

/// アプリアイコンの #(4本の 角丸の 棒)。`rect` いっぱいに(アイコンの 632 × 632 の 比で)
struct HV72HashShape: Shape {
    func path(in r: CGRect) -> Path {
        let k = r.width / 632
        var p = Path()
        for b in [CGRect(x: 0, y: 124, width: 632, height: 104), CGRect(x: 0, y: 404, width: 632, height: 104),
                  CGRect(x: 124, y: 0, width: 104, height: 632), CGRect(x: 404, y: 0, width: 104, height: 632)] {
            p.addRoundedRect(in: CGRect(x: r.minX + b.minX * k, y: r.minY + b.minY * k, width: b.width * k, height: b.height * k),
                             cornerSize: CGSize(width: 52 * k, height: 52 * k))
        }
        return p
    }
}

/// 大きな #(横の 棒は 画面の 左右の はしまで ・ レンズの まわりは 半径 126 を 黒で 切る)
struct HV72Hash: View {
    let width: CGFloat
    /// レンズの 中心(この View の 中の y)
    let cy: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let g = GraphicsContext.Shading.linearGradient(Gradient(colors: [Color(hex: "D4F870"), Color(hex: "B9E84A")]),
                                                           startPoint: CGPoint(x: 0, y: cy - 213), endPoint: CGPoint(x: 0, y: cy + 201))
            let t: CGFloat = 74, r: CGFloat = 37
            // よこ(左右は 画面の 外まで)
            for y in [cy - 130, cy + 130] {
                ctx.fill(Path(roundedRect: CGRect(x: -40, y: y - t / 2, width: size.width + 80, height: t), cornerRadius: r), with: g)
            }
            // たて(上は 上の 棒の 上 46 ・ 下は 下の 棒の 下 34)
            for x in [cx - 130, cx + 130] {
                ctx.fill(Path(roundedRect: CGRect(x: x - t / 2, y: cy - 213, width: t, height: 414), cornerRadius: r), with: g)
            }
            // レンズの まわり:半径 126 を 黒で
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 126, y: cy - 126, width: 252, height: 252)), with: .color(.black))
        }
        .frame(width: width, height: 440)
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

/// レンズの まんなか:黄緑の シャッターボタン(撮れる とき)。座標は レンズの 312 の 座標。
struct HV72Shutter: View {
    let pressing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            // 外へ 広がる 波(呼吸):2.8秒 ・ 70% で 消えて 待つ
            if !pressing && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: scenePhase != .active)) { ctx in
                    let u = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.8) / 2.8
                    let p = min(1, u / 0.7)
                    let e = OPBez(0.3, 0, 0.3, 1).at(p)
                    Circle().stroke(HV.lime, lineWidth: 2).frame(width: 100, height: 100)
                        .scaleEffect(1 + 0.32 * e).opacity(u >= 0.7 ? 0 : 0.55 * (1 - e))
                }
            }
            // 外の 輪(半径 50 ・ 線 5)
            Circle().stroke(HV.lime, lineWidth: 5).frame(width: 100, height: 100)
                .shadow(color: HV.lime.opacity(0.7), radius: 7)
                .scaleEffect(pressing ? 1.08 : 1).opacity(pressing ? 0.6 : 1)
            // ボタン
            ZStack {
                Circle().fill(RadialGradient(colors: [.black.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 46)).frame(width: 92, height: 92).offset(y: 5)
                Circle().fill(RadialGradient(stops: [.init(color: Color(hex: "EEFFB0"), location: 0), .init(color: Color(hex: "C8F25A"), location: 0.38),
                                                     .init(color: Color(hex: "8FCB2E"), location: 0.85), .init(color: Color(hex: "6FA622"), location: 1)],
                                             center: UnitPoint(x: 0.36, y: 0.30), startRadius: 0, endRadius: 56))
                    .frame(width: 80, height: 80)
                    .overlay(Circle().strokeBorder(.white.opacity(0.55), lineWidth: 1.2))
                HV72HashShape().fill(Color(hex: "0B0C0D")).frame(width: 37, height: 37)
                Ellipse().fill(.white.opacity(0.55)).frame(width: 30, height: 14).rotationEffect(.degrees(-28)).offset(x: -15, y: -21)
            }
            .scaleEffect(pressing ? 0.88 : 1)
        }
        .animation(.timingCurve(0.3, 1.5, 0.5, 1, duration: 0.22), value: pressing)
        .frame(width: 130, height: 130)
        .allowsHitTesting(false)
    }
}


/// 「今日を撮る」の 地球儀(中身の つまった 球)。経線 ・ 緯線が ゆっくり 回り、まちの あかりが 光る。押すと 回る 速さが 上がる。
struct HV72DomeGlobe: View {
    let d: CGFloat
    let pressing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var speed: Double = 3.6
    @State private var angle: Double = 0
    @State private var last = Date()

    private let lights: [(Double, Double)] = [(62, 20), (70, 95), (55, 160), (68, 230), (50, 300), (75, 340), (58, 55)]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || scenePhase != .active)) { ctx in
            Canvas { c, size in
                let r = Double(d / 2), cx = Double(size.width / 2), cy = Double(d / 2)
                let tilt = 22.0 * .pi / 180
                func proj(_ lat: Double, _ lon: Double) -> (x: Double, y: Double, z: Double) {
                    let la = lat * .pi / 180, lo = (lon + angle) * .pi / 180
                    let x = cos(la) * sin(lo), y0 = sin(la), z0 = cos(la) * cos(lo)
                    return (x, y0 * cos(tilt) - z0 * sin(tilt), y0 * sin(tilt) + z0 * cos(tilt))
                }
                let visible = 150.0
                let gain = pressing ? 1.0 : 0.7
                func seg(_ pts: [(Double, Double)]) {
                    var prev: CGPoint?; var prevA = 0.0
                    for (la, lo) in pts {
                        let q = proj(la, lo)
                        guard q.z > 0 else { prev = nil; continue }
                        let p = CGPoint(x: cx + q.x * r, y: cy - q.y * r)
                        let t = max(0, min(1, (Double(p.y) - (cy - r)) / visible))
                        let a = 0.34 * (1 - 0.88 * t) * gain
                        if let pr = prev, p.y < cy - r + visible + 20 { var path = Path(); path.move(to: pr); path.addLine(to: p); c.stroke(path, with: .color(Color(hex: "C8F25A").opacity((a + prevA) / 2)), lineWidth: 0.9) }
                        prev = p; prevA = a
                    }
                }
                for lat in stride(from: 20.0, through: 80.0, by: 10.0) { seg(stride(from: 0.0, through: 360.0, by: 6.0).map { (lat, $0) }) }
                for lon in stride(from: 0.0, to: 360.0, by: 15.0) { seg(stride(from: 5.0, through: 85.0, by: 5.0).map { ($0, lon) }) }
                for (la, lo) in lights {
                    let q = proj(la, lo)
                    guard q.z > 0.05 else { continue }
                    let p = CGPoint(x: cx + q.x * r, y: cy - q.y * r)
                    guard Double(p.y) < cy - r + visible else { continue }
                    c.fill(Path(ellipseIn: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14)), with: .color(Color(hex: "C8F25A").opacity(0.22)))
                    c.fill(Path(ellipseIn: CGRect(x: p.x - 1.1, y: p.y - 1.1, width: 2.2, height: 2.2)), with: .color(Color(hex: "F4FFC8")))
                }
            }
            .onChange(of: ctx.date) { _, now in
                let dt = min(0.1, now.timeIntervalSince(last)); last = now
                speed += ((pressing ? 97 : 3.6) - speed) * min(1, dt * (pressing ? 8 : 1.6))
                angle += speed * dt
            }
        }
        .frame(width: d, height: d).clipShape(Circle()).allowsHitTesting(false)
    }
}
