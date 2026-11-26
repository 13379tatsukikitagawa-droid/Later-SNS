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
                PausableTimeline(minimumInterval: 1.0 / 24) { date in   // v111:見えて いる 時 だけ
                    let u = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.8) / 2.8
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
                Circle().fill(RadialGradient(stops: [.init(color: Color(hex: "EEFFB0"), location: 0), .init(color: LattagPalette.lime, location: 0.38),
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
