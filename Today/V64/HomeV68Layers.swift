import SwiftUI

// P12-A(v68):Home の うしろ = 全面の ぼかし写真(幅 390 × 高さ 1010)。
// 重さの 決まり(P11):ぼかし ・ 彩度 ・ 明るさは 小さな 画像に 1回だけ 焼きこんで、ひきのばす。毎フレーム 計算しない。

/// 下の つなぎ(`#dusk`):透明 → 深い 緑 → #0A0A0B。スクロールの 中身と いっしょに 動く(y = 692)
struct HV68Dusk: View {
    let width: CGFloat
    var body: some View {
        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: Color(red: 11 / 255, green: 30 / 255, blue: 16 / 255).opacity(0.85), location: 0.34),
                               .init(color: Color(hex: "0B120D"), location: 0.62), .init(color: Color(hex: "0A0A0B"), location: 1)], startPoint: .top, endPoint: .bottom)
            .frame(width: width, height: 434).allowsHitTesting(false)
    }
}
