import SwiftUI

// #レンズ（Opal の宝石にあたる、Lattag だけの立体ボタン）— 参考実装
// 使う場所：タブ右の撮るボタン(64pt)・9:00画面(84pt)・はじめての設定の最後(176pt)・Live Activity(34pt)
// v134 Phase 1:Media.xcassets に HashGlyph(Template ・ Preserve Vector)を 追加ずみ。
// 必要なアセット：assets/HashGlyph.svg を Assets に "HashGlyph" として追加
//   （Render As: Template Image、Preserve Vector Data: ON）

struct HashLensView: View {
    var size: CGFloat = 64
    /// 0:00〜9:00 の消灯中、または今日の3枚を撮りきったとき
    var locked: Bool = false
    var glowing: Bool = true

    var body: some View {
        ZStack {
            if locked {
                Circle().fill(Color.white.opacity(0.06))
                Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1.2)
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.3, weight: .semibold))
                    .foregroundStyle(LTColor.ink2)
            } else {
                Circle().fill(
                    RadialGradient(stops: [
                        .init(color: Color(hex6: 0xF6FFD2), location: 0),
                        .init(color: Color(hex6: 0xDDFB7D), location: 0.26),
                        .init(color: LTColor.lime,         location: 0.52),
                        .init(color: Color(hex6: 0xA2CF35), location: 0.86),
                        .init(color: Color(hex6: 0x8DB928), location: 1)
                    ], center: UnitPoint(x: 0.3, y: 0.18), startRadius: 0, endRadius: size * 0.8)
                )
                // 上の光（ガラス玉の反射）
                Ellipse()
                    .fill(LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .frame(width: size * 0.6, height: size * 0.34)
                    .offset(x: -size * 0.08, y: -size * 0.26)
                    .blendMode(.screen)
                Circle().strokeBorder(Color.black.opacity(0.18), lineWidth: 0.8)

                Image("HashGlyph")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LTColor.limeInk)
                    .frame(width: size * 0.52)

                // # のまんなかのレンズ（# の幅の約37%）
                LensDot(diameter: size * 0.52 * 0.369)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: (!locked && glowing) ? LTColor.lime.opacity(0.55) : .clear, radius: size * 0.2, y: size * 0.12)
        .contentShape(Circle())
        .accessibilityLabel(locked ? "9:00から撮れます" : "撮る")
    }
}

private struct LensDot: View {
    let diameter: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(LTColor.limeInk)
            Circle()
                .fill(RadialGradient(colors: [Color(hex6: 0x3B4A1C), Color(hex6: 0x121608), .black],
                                     center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: diameter * 0.4))
                .frame(width: diameter * 0.78)
            Circle()
                .strokeBorder(LTColor.lime.opacity(0.55), lineWidth: max(0.5, diameter * 0.036))
                .frame(width: diameter * 0.78)
            Ellipse()
                .fill(Color.white.opacity(0.78))
                .frame(width: diameter * 0.25, height: diameter * 0.18)
                .rotationEffect(.degrees(-30))
                .offset(x: -diameter * 0.11, y: -diameter * 0.11)
        }
        .frame(width: diameter, height: diameter)
    }
}
