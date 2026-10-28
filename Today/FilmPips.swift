import SwiftUI

/// のこりフィルム。1日3こまを、小さなフィルムのこまで見せる(撮った・次に撮る・まだ・夜)。
/// 枚数の表示だけで、競争やあおりの文言は出さない。
struct FilmPips: View {
    /// 今日撮った枚数(0〜FilmRoll.shotsPerDay)
    let taken: Int
    /// 夜(あしたまで撮れない)。こまは、すべて暗い点線になる
    var isNight = false
    /// こまの大きさ(Home のカードは 13×17、大きい所では 22×30)
    var pipSize = CGSize(width: 13, height: 17)
    var spacing: CGFloat = 4
    /// 次に撮るこまの明滅(Reduce Motion のときは止める)
    var breathes = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathOn = false

    /// 「のこり 2こま」などの文言(撮影数と夜から決める)
    static func caption(taken: Int, isNight: Bool) -> String {
        if isNight { return "あしたの朝、あたらしい3こま" }
        let remaining = FilmRoll.shotsRemaining(shotsToday: taken)
        return remaining == 0 ? "今日は、ここまで" : "のこり \(remaining) こま"
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<FilmRoll.shotsPerDay, id: \.self) { index in
                pip(at: index)
            }
        }
        .accessibilityHidden(true)
        .onAppear {
            guard breathes, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { breathOn = true }
        }
    }

    @ViewBuilder
    private func pip(at index: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 3.5, style: .continuous)
        if !isNight && index < taken {
            // 撮った:橙の縁と、ほのかな光
            shape
                .fill(LinearGradient(colors: [Color(hex: "2A1D16"), Color(hex: "120C0A")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(shape.strokeBorder(Color(hex: "FF9E5E"), lineWidth: 1))
                .shadow(color: Color(hex: "FF9E5E").opacity(0.45), radius: 4)
                .frame(width: pipSize.width, height: pipSize.height)
        } else {
            let isNext = !isNight && index == taken
            let opacity: Double = isNight ? 0.14 : (isNext ? (reduceMotion || !breathes ? 0.75 : (breathOn ? 0.75 : 0.3)) : 0.28)
            shape
                .strokeBorder(Color.white.opacity(opacity), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .frame(width: pipSize.width, height: pipSize.height)
        }
    }
}
