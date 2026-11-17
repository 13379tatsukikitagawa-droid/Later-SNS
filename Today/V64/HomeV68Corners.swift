import SwiftUI

// P13 §2・§3 + P15 §2:四すみの ボタン(78 × 78 ・ 角丸 26)・ ボタンに 沿う かぎ ・ ファインダー(3分割 + AF の 枠)。

/// かぎ:ボタンの 外側の 角を なぞる 1/4 の 弧(30 × 30 の 箱 ・ 線 2.5)。ボタンの **子(overlay)** として 置く。
struct CornerBracket: Shape {
    enum Spot { case tl, tr, bl, br }
    var spot: Spot
    func path(in r: CGRect) -> Path {
        let n = min(r.width, r.height)
        let (c, a0): (CGPoint, Double) = {
            switch spot {
            case .tl: return (CGPoint(x: r.minX + n, y: r.minY + n), 180)
            case .tr: return (CGPoint(x: r.maxX - n, y: r.minY + n), 270)
            case .br: return (CGPoint(x: r.maxX - n, y: r.maxY - n), 0)
            case .bl: return (CGPoint(x: r.minX + n, y: r.maxY - n), 90)
            }
        }()
        var p = Path()
        for i in 0...24 {
            let a = (a0 + 90 * Double(i) / 24) * .pi / 180
            let pt = CGPoint(x: c.x + n * cos(a), y: c.y + n * sin(a))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}

struct HV68Corner: View {
    let spot: CornerBracket.Spot
    let kind: HVIconKind
    let label: String
    let locked: Bool
    let badge: Bool
    let entered: Bool
    let index: Int
    /// 自分の 中心 → レンズの 中心(入る とき ここから とび出す)
    let fromLens: CGSize
    let action: () -> Void
    @State private var pressing = false
    @State private var landed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var on: Bool { entered || reduceMotion }
    private var delay: Double { 0.42 + 0.07 * Double(index) }

    var body: some View {
        Button { Haptics.play(.click); action() } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(locked ? Color(red: 10 / 255, green: 10 / 255, blue: 12 / 255).opacity(0.3) : Color.white.opacity(pressing ? 0.2 : 0.09))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(locked ? 0.2 : 0.22), lineWidth: 1))
                    .overlay(HVRim(radius: 26, width: 1.2))
                    .shadow(color: .black.opacity(0.6), radius: 14, y: 14)
                HVIcon(kind: kind, size: 28, color: .white.opacity(locked ? 0.55 : 1)).offset(y: -8)
                Text(label).font(LF.mono(8.5)).tracking(1.19).foregroundStyle(.white.opacity(locked ? 0.55 : 0.92)).fixedSize().offset(y: 19.5)
            }
            .frame(width: 78, height: 78)
            .overlay(alignment: .topTrailing) {
                if locked {
                    Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 24, height: 24).background(Color.black.opacity(0.82), in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1)).offset(x: 6, y: -6)
                } else if badge {
                    HVBadge(size: 18).offset(x: 6, y: -6)
                }
            }
            .overlay(alignment: bracketAlignment) { bracket }
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(HVPress(scale: 0.92, onPress: { pressing = $0 }))
        .offset(on ? .zero : fromLens)
        .scaleEffect(on ? 1 : 0.28)
        .opacity(on ? 1 : 0)
        .animation(.timingCurve(0.3, 1.1, 0.4, 1, duration: 0.72).delay(delay), value: on)
        .task(id: on) {
            if on {
                try? await Task.sleep(nanoseconds: UInt64((delay + 0.38) * 1_000_000_000))
                withAnimation(.spring(response: 0.46, dampingFraction: 0.62)) { landed = true }
                Haptics.play(.tick)
            } else { landed = false }
        }
        .accessibilityLabel(label.capitalized)
    }

    private var bracketAlignment: Alignment {
        switch spot { case .tl: return .topLeading; case .tr: return .topTrailing; case .bl: return .bottomLeading; case .br: return .bottomTrailing }
    }

    /// ボタンの 外側の 角から 5pt 外。入る とき 外へ 14pt + 1.5倍 → ぴたっと 止まる(ピントが 合った 合図)
    private var bracket: some View {
        let sx: CGFloat = (spot == .tl || spot == .bl) ? -1 : 1
        let sy: CGFloat = (spot == .tl || spot == .tr) ? -1 : 1
        let out: CGFloat = 5 + (landed || reduceMotion ? 0 : 14)
        return CornerBracket(spot: spot)
            .stroke(.white.opacity(locked ? 0.4 : 0.92), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: 30, height: 30)
            .scaleEffect((landed || reduceMotion ? 1 : 1.5) * (pressing ? 0.8 : 1))
            .opacity(landed || reduceMotion ? 1 : 0)
            .offset(x: sx * out, y: sy * out)
            .allowsHitTesting(false)
    }
}

/// ファインダー:3分割の 線(ふだん 白 7% ・ 押す 間 20%)+ AF の 枠(黄緑の 角丸 ・ 250 → 230 に しまる)
struct HV68Finder: View {
    let cardW: CGFloat
    let pressing: Bool
    let afOn: Bool
    var body: some View {
        ZStack(alignment: .topLeading) {
            let w = cardW - 4, h: CGFloat = 432
            ZStack {
                ForEach(1..<3, id: \.self) { i in
                    Rectangle().fill(.white).frame(width: 1, height: h).offset(x: w * CGFloat(i) / 3 - w / 2)
                    Rectangle().fill(.white).frame(width: w, height: 1).offset(y: h * CGFloat(i) / 3 - h / 2)
                }
            }
            .frame(width: w, height: h)
            .opacity(pressing ? 0.2 : 0.07)
            .animation(.easeOut(duration: 0.25), value: pressing)
            .offset(x: 2, y: 2)

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(HV.lime.opacity(0.9), lineWidth: 1.5)
                .shadow(color: HV.lime.opacity(0.5), radius: 8)
                .frame(width: afOn ? 230 : 250, height: afOn ? 230 : 250)
                .opacity(afOn ? 1 : 0)
                .animation(.timingCurve(0.3, 1.1, 0.4, 1, duration: 0.32), value: afOn)
                .position(x: cardW / 2, y: 254)
        }
        .allowsHitTesting(false)
    }
}
