import SwiftUI

/// v110 §3-2:タグ(Space Mono 11 太字 ・ 字間 0.06em ・ 角丸 8 ・ 白い ふち 2.5 ・ かたむき -4〜4°)
struct PopTag: View {
    var text: String
    var color: Color
    var tilt: Double = -2

    var body: some View {
        Text(text).font(Typo.label(11)).tracking(0.66).foregroundStyle(Color(hex: "111113"))
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white, lineWidth: 2.5))
            .rotationEffect(.degrees(max(-4, min(4, tilt))))
            .fixedSize()
    }
}

/// テープ(62 × 20 ・ 不透明度 0.88 ・ かたむき)
struct PopTape: View {
    var color: Color = PopColor.sun
    var tilt: Double = -6
    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous).fill(color.opacity(0.88))
            .overlay(Rectangle().fill(.white.opacity(0.18)).frame(height: 1).frame(maxHeight: .infinity, alignment: .top))
            .frame(width: 62, height: 20)
            .rotationEffect(.degrees(tilt))
            .accessibilityHidden(true)
    }
}

/// チェキの 紙(`#F7F5EF` ・ 角丸 6 ・ 余白 10 / 下 46 ・ 写真 4:5 ・ 下に 手書きの 字)。写真は v107 の 焼いた もの を そのまま(表示で フィルターを かけない)。
struct ChekiFrame<Photo: View>: View {
    var caption: String = ""
    var captionSize: CGFloat = 20
    var tilt: Double = 0
    @ViewBuilder var photo: () -> Photo

    var body: some View {
        VStack(spacing: 0) {
            photo().aspectRatio(4.0 / 5.0, contentMode: .fill).frame(maxWidth: .infinity).aspectRatio(4.0 / 5.0, contentMode: .fit).clipped()
            Text(caption).font(LF.hand(captionSize)).foregroundStyle(Color(hex: "3A3733")).lineLimit(1).minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: 46, alignment: .center)
        }
        .padding(.horizontal, 10).padding(.top, 10)
        .background(PopColor.paper, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
        .rotationEffect(.degrees(tilt))
    }
}

/// 押すと 0.93 へ 縮む(0.08秒)→ はなすと ばねで もどる(0.38 / 0.55)。Reduce Motion では 縮むだけ(跳ねない)。
struct PopPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(configuration.isPressed ? .easeOut(duration: 0.08) : (reduceMotion ? .easeOut(duration: 0.1) : .spring(response: 0.38, dampingFraction: 0.55)), value: configuration.isPressed)
    }
}

enum PopButtonKind { case lime, sky, ghost }

/// 高さ 50 ・ 角丸 25 ・ 太字 16。lime / sky は 下に 3pt の 濃い 色の かげ(ぷっくり)。ghost は `#1D1D20` + 白 8% の 線。
struct PopButton: View {
    var title: String
    var kind: PopButtonKind = .lime
    var small = false
    var action: () -> Void

    var body: some View {
        Button { Haptics.play(.pop); action() } label: {
            Text(title).font(Typo.ui(800, small ? 13 : 16))
                .foregroundStyle(kind == .ghost ? .white : Color(hex: "111113"))
                .frame(maxWidth: small ? nil : .infinity, minHeight: small ? 36 : 50)
                .padding(.horizontal, small ? 14 : 0)
                .background {
                    switch kind {
                    case .lime: Capsule().fill(PopColor.lime).shadow(color: PopColor.limeDeep, radius: 0, y: 3)
                    case .sky: Capsule().fill(PopColor.sky).shadow(color: PopColor.skyDeep, radius: 0, y: 3)
                    case .ghost: Capsule().fill(PopColor.raised).overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1))
                    }
                }
        }
        .buttonStyle(PopPressStyle())
        .frame(minHeight: 44)
    }
}
