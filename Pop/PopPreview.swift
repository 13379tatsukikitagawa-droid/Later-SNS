#if DEBUG
import SwiftUI

/// DEBUG:ポップの 部品を 1画面に ならべる(`lattag://debug/pop`)
struct PopPreview: View {
    @State private var n = 0
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("POP PARTS").font(Typo.label(11)).tracking(2).foregroundStyle(PopColor.lime)
                HStack(spacing: 14) {
                    PopSticker(shape: .heart, color: PopColor.pink, tilt: -10)
                    PopSticker(shape: .star, color: PopColor.sun, tilt: 8)
                    PopSticker(shape: .spark, color: PopColor.sky, tilt: -6)
                    PopSticker(shape: .flower, color: PopColor.pink, tilt: 12)
                    PopSticker(shape: .hash, color: PopColor.lime, tilt: -12)
                }
                HStack(spacing: 14) {
                    PopTag(text: "9:00 OPEN", color: PopColor.sun, tilt: -3)
                    PopTag(text: "DAY 2 / 3", color: PopColor.pink, tilt: 2)
                    PopTag(text: "あと 4日", color: PopColor.sky, tilt: -2)
                    PopTape(color: PopColor.sun)
                }
                HStack(alignment: .top, spacing: 18) {
                    ChekiFrame(caption: "今日の 1枚", tilt: -2) {
                        LinearGradient(colors: [Color(hex: "C98A7A"), Color(hex: "5A4A6A")], startPoint: .top, endPoint: .bottom)
                    }.frame(width: 150)
                    .overlay(alignment: .top) { PopTape(color: PopColor.sun).offset(y: -10) }
                    .overlay(alignment: .topTrailing) { PopSticker(shape: .star, color: PopColor.pink, size: 30, tilt: 10).offset(x: 12, y: -12) }
                    VStack(spacing: 12) {
                        PopButton(title: "撮る", kind: .lime) {}
                        PopButton(title: "つつく", kind: .sky) {}
                        PopButton(title: "KEY で 入る", kind: .ghost) {}
                        HStack { PopButton(title: "確認", kind: .sky, small: true) {}; PopButton(title: "あとで", kind: .ghost, small: true) {} }
                    }
                }
                HStack(spacing: 24) {
                    ForEach(Array(PopColor.tripCycle.enumerated()), id: \.offset) { i, c in Circle().fill(c).frame(width: 34, height: 34).overlay(Text("\(i + 1)").font(Typo.label(11)).foregroundStyle(Color(hex: "111113"))) }
                    Button { n += 1; Haptics.play(.heart) } label: { PopSticker(shape: .heart, color: PopColor.pink, size: 30, tilt: 0).frame(width: 60, height: 60).overlay { PopFlyingSticker(shape: .heart, color: PopColor.pink, trigger: n) } }.buttonStyle(PopPressStyle())
                }
                Text("ステッカーを 押すと 飛ぶ ・ ボタンは 押すと ぷにっ").font(Typo.ui(500, 12)).foregroundStyle(.gray)
            }.padding(20)
        }
        .background(PopColor.ground.ignoresSafeArea()).preferredColorScheme(.dark)
    }
}
#endif
