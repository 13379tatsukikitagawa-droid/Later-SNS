import SwiftUI

/// v110 §2:下の タブ(Friends | Trip)。ガラスの 台に ライムの つまみ(108 × 58 ・ 角丸 29)が ばねで すべる。
/// えらんだ 方の 字と 絵は 黒 `#111113`。いま えらんで いる タブを もう一度 押す → `onRepeat`(いちばん 上へ)。
struct PopTabBar: View {
    @Binding var selection: Int
    var onRepeat: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let items: [(String, Int)] = [("Friends", 0), ("Trip", 1)]
    private static let ink = Color(hex: "111113")

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 29, style: .continuous).fill(HV.lime)
                .overlay(RoundedRectangle(cornerRadius: 29, style: .continuous).strokeBorder(.white.opacity(0.5), lineWidth: 1).mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)))
                .frame(width: 108, height: 58)
                .offset(x: CGFloat(selection) * 108)
                .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.46, dampingFraction: 0.62), value: selection)
            HStack(spacing: 0) {
                ForEach(items, id: \.1) { item in
                    let on = selection == item.1
                    Button {
                        if on { Haptics.play(.tick); onRepeat() }
                        else { Haptics.play(.sel); selection = item.1 }
                    } label: {
                        HStack(spacing: 7) {
                            if item.1 == 0 { Image(systemName: "person.2.fill").font(.system(size: 17, weight: .semibold)) }
                            else { PopTicketIcon().frame(width: 22, height: 16) }
                            Text(item.0).font(Typo.ui(800, 15))
                        }
                        .foregroundStyle(on ? Self.ink : .white.opacity(0.78))
                        .frame(width: 108, height: 58)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.0)
                    .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
                }
            }
        }
        .padding(4)
        .background { Capsule().fill(Color(hex: "1A1A1D").opacity(0.55)) }
        .lgGlass(radius: 33, interactive: true)
        .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
    }
}

/// チケットの 絵(ミシン目 つき)。地球の 絵は 使わない。
struct PopTicketIcon: View {
    var body: some View {
        ZStack {
            TicketShape().fill(style: FillStyle(eoFill: true))
            Rectangle().fill(Color(hex: "111113").opacity(0.0001)).hidden()
            GeometryReader { g in
                Path { p in
                    let x = g.size.width * 0.66
                    var y: CGFloat = 2
                    while y < g.size.height - 2 { p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x, y: y + 1.6)); y += 3.4 }
                }.stroke(Color.black.opacity(0.55), lineWidth: 1)
            }
        }
    }
}

struct TicketShape: Shape {
    func path(in r: CGRect) -> Path {
        let n = r.height * 0.22, c = r.height * 0.18
        var p = Path()
        p.addRoundedRect(in: r, cornerSize: CGSize(width: c, height: c), style: .continuous)
        var cut = Path()
        cut.addEllipse(in: CGRect(x: r.minX - n, y: r.midY - n, width: n * 2, height: n * 2))
        cut.addEllipse(in: CGRect(x: r.maxX - n, y: r.midY - n, width: n * 2, height: n * 2))
        return p.subtracting(cut)
    }
}
