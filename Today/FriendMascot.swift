import SwiftUI

/// v48b:「BUMP」の文字を やめて、まるい キャラで「ともだち」を 伝える。
/// 丸い頭の縦長のキャラ。黒いふち・点の目・にっこり口・ピンクのほっぺ・白い細い腕。
struct FriendMascot: View {
    var color: Color
    /// スマホを かかげている(まんなかの子)
    var armsUp: Bool = false
    /// 手を ふっている(はしの子)
    var waving: Bool = false
    var size: CGFloat = 54

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sway = false

    var body: some View {
        let w = size, h = size * 1.3
        ZStack {
            // 白い細い腕
            if armsUp {
                Capsule().fill(.white).frame(width: w * 0.1, height: h * 0.4)
                    .rotationEffect(.degrees(-28)).offset(x: -w * 0.32, y: -h * 0.08)
                Capsule().fill(.white).frame(width: w * 0.1, height: h * 0.4)
                    .rotationEffect(.degrees(28)).offset(x: w * 0.32, y: -h * 0.08)
            } else {
                Capsule().fill(.white).frame(width: w * 0.1, height: h * 0.32)
                    .rotationEffect(.degrees(waving ? -50 : 14)).offset(x: -w * 0.34, y: h * 0.02)
                Capsule().fill(.white).frame(width: w * 0.1, height: h * 0.32)
                    .rotationEffect(.degrees(waving ? 50 : -14)).offset(x: w * 0.34, y: h * 0.02)
            }
            // 頭+からだ(縦長の丸)
            RoundedRectangle(cornerRadius: w * 0.5, style: .continuous)
                .fill(color)
                .frame(width: w, height: h)
                .overlay(
                    RoundedRectangle(cornerRadius: w * 0.5, style: .continuous)
                        .strokeBorder(.black.opacity(0.82), lineWidth: 2.6)
                )
            // ほっぺ
            HStack(spacing: w * 0.32) {
                Circle().fill(Color(hex: "FF9FB0")).frame(width: w * 0.16, height: w * 0.1)
                Circle().fill(Color(hex: "FF9FB0")).frame(width: w * 0.16, height: w * 0.1)
            }
            .offset(y: h * 0.04)
            // 目+にっこり口
            VStack(spacing: h * 0.06) {
                HStack(spacing: w * 0.18) {
                    Circle().fill(.black).frame(width: w * 0.09, height: w * 0.09)
                    Circle().fill(.black).frame(width: w * 0.09, height: w * 0.09)
                }
                Capsule().fill(.black).frame(width: w * 0.22, height: w * 0.045)
            }
            .offset(y: -h * 0.04)
        }
        .frame(width: w, height: h)
        .offset(y: reduceMotion ? 0 : (sway ? -3 : 3))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { sway = true }
        }
        .accessibilityHidden(true)
    }
}

/// なかまが あつまってくる(0〜5体)。まんなかの子が スマホを かかげ、はしの子が 手を ふる。
struct FriendGatheringGroup: View {
    var colors: [Color]
    /// 長押し中(=ふっている)は、小きざみに ゆれる
    var shaking: Bool = false
    var seatSize: CGFloat = 40

    var body: some View {
        let list = colors.isEmpty ? [Color.white.opacity(0.5)] : colors
        let mid = (list.count - 1) / 2
        let shakeAnimation: Animation? = shaking ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true) : .easeOut(duration: 0.2)
        HStack(spacing: -seatSize * 0.22) {
            ForEach(Array(list.enumerated()), id: \.offset) { index, color in
                FriendMascot(color: color, armsUp: index == mid, waving: index == 0 || index == list.count - 1, size: seatSize)
                    .zIndex(index == mid ? 1 : 0)
                    .scaleEffect(shaking ? 1.03 : 1)
                    .animation(shakeAnimation, value: shaking)
            }
        }
    }
}
