import SwiftUI

/// v111 §4:Trip 0件。出発の 案内板 → うすい パス → 見出し → ボタン 2つ → 小さな ひとこと。
struct TripEmptyV111: View {
    var onNew: () -> Void
    var onJoinKey: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("tripEmptyFlapSeen") private var flapSeen = false
    @State private var float = false
    @State private var flap = false

    var body: some View {
        VStack(spacing: 14) {
            board.padding(.horizontal, 16)
            ghost.padding(.top, 10)
            Text("次の 旅を つくろう").font(.system(size: 26, weight: .black)).foregroundStyle(.white).padding(.top, 8)
            Text("旅の あいだ、みんなで 1日 23枚。\nあしたの 9:00 に みんなで ひらく")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.55)).multilineTextAlignment(.center).lineSpacing(3)
            HStack(spacing: 10) {
                PopButton(title: "＋ 新しい Trip", kind: .lime) { onNew() }
                PopButton(title: "KEY で 入る", kind: .ghost) { onJoinKey() }
            }.padding(.horizontal, 16).padding(.top, 6)
            Text("招待リンクを もらったら、タップする だけで 入れます")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.4)).multilineTextAlignment(.center).padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .loopWhileVisible(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: $float)
        .onAppear {
            guard !flapSeen, !reduceMotion else { return }
            flap = true
            flapSeen = true
        }
    }

    // MARK: 案内板

    private var board: some View {
        VStack(spacing: 7) {
            HStack {
                HStack(spacing: 6) { Image(systemName: "airplane").font(.system(size: 13, weight: .bold)); Text("DEPARTURES").font(LF.mono(11)).tracking(2.2) }
                Spacer(minLength: 0)
                TimelineView(.everyMinute) { ctx in
                    Text(ctx.date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))).font(LF.mono(11)).tracking(0.9).foregroundStyle(.white.opacity(0.5))
                }
            }.foregroundStyle(PopColor.lime).padding(.horizontal, 2).padding(.bottom, 4)
            row(time: "--:--", dest: "NEXT TRIP", status: AnyView(Text("OPEN").font(LF.mono(10)).foregroundStyle(Color(hex: "111113")).padding(.horizontal, 6).padding(.vertical, 3).background(PopColor.lime, in: RoundedRectangle(cornerRadius: 5)).modifier(BlinkWhileVisible())), hot: true)
            row(time: "--:--", dest: "-------", status: AnyView(Text("—").font(LF.mono(10)).foregroundStyle(Color(hex: "4A4A50"))), hot: false)
            row(time: "--:--", dest: "-------", status: AnyView(Text("—").font(LF.mono(10)).foregroundStyle(Color(hex: "4A4A50"))), hot: false)
        }
        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 12)
        .background(Color(hex: "0E0E10"), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .accessibilityElement(children: .ignore).accessibilityLabel("出発の 案内板 ・ 次の Trip")
    }

    private func row(time: String, dest: String, status: AnyView, hot: Bool) -> some View {
        let t = Array(time), d = Array(dest)
        return HStack(spacing: 8) {
            HStack(spacing: 2) { ForEach(0..<t.count, id: \.self) { i in FlapCell(final: t[i], color: hot ? .white : Color(hex: "5A5A62"), index: i, play: hot && flap, isLast: false) } }
            HStack(spacing: 2) {
                ForEach(0..<d.count, id: \.self) { i in FlapCell(final: d[i], color: hot ? PopColor.lime : Color(hex: "5A5A62"), index: t.count + i, play: hot && flap, isLast: i == d.count - 1) }
                Spacer(minLength: 0)
            }.frame(maxWidth: .infinity, alignment: .leading)
            status.frame(width: 46, alignment: .trailing)
        }
    }

    // MARK: うすい パス

    private var ghost: some View {
        Button { Haptics.play(.pop); onNew() } label: {
            ZStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRIP PASS").font(LF.mono(10.5)).tracking(2.1).foregroundStyle(PopColor.lime)
                    Text("どこへ いく?").font(.system(size: 28, weight: .black)).foregroundStyle(.white)
                    Text("FROM ・ TO ・ 23 SHOTS / DAY").font(LF.mono(10.5)).foregroundStyle(.white.opacity(0.5)).lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 30).padding(.trailing, 20).padding(.vertical, 20)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous).fill(PopColor.lime.opacity(0.04))
                        RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(PopColor.lime.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                    }
                )
                .overlay(alignment: .trailing) {
                    Rectangle().fill(.clear).frame(width: 2).overlay(Rectangle().stroke(.white.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [2, 4]))).padding(.vertical, 10).padding(.trailing, 62)
                }
            }
            .overlay(alignment: .topLeading) { PopSticker(shape: .star, color: PopColor.sun, size: 36, tilt: -14).offset(x: -12, y: -14) }
            .overlay(alignment: .bottomTrailing) { PopSticker(shape: .hash, color: PopColor.lime, size: 38, tilt: 12).offset(x: 10, y: 12) }
            .rotationEffect(.degrees(-3))
            .offset(y: float ? -6 : 0)
            .containerRelativeFrame(.horizontal) { w, _ in w * 0.86 }
        }
        .buttonStyle(PopPressStyle())
        .accessibilityLabel("新しい Trip を つくる")
    }
}

/// 案内板の 1字。はじめて 見た 時 だけ 70ms ごとに 字が 変わり、左から 順に 止まる(`index` が 大きい ほど 長く)。
private struct FlapCell: View {
    let final: Character
    let color: Color
    let index: Int
    let play: Bool
    let isLast: Bool
    @State private var shown: Character
    @State private var rot: Double = 0

    init(final: Character, color: Color, index: Int, play: Bool, isLast: Bool) {
        self.final = final; self.color = color; self.index = index; self.play = play; self.isLast = isLast
        _shown = State(initialValue: final)
    }

    var body: some View {
        Text(String(shown)).font(LF.mono(13)).foregroundStyle(color)
            .frame(width: 15, height: 24)
            .background(Color(hex: "1B1B1E"), in: RoundedRectangle(cornerRadius: 3))
            .overlay(Rectangle().fill(.black.opacity(0.7)).frame(height: 1))
            .rotation3DEffect(.degrees(rot), axis: (1, 0, 0), perspective: 0.6)
            .task(id: play) {
                guard play else { return }
                let pool = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
                let k = 6 + index
                for n in 1...k {
                    try? await Task.sleep(for: .milliseconds(70))
                    if Task.isCancelled { shown = final; return }
                    shown = n >= k ? final : (pool.randomElement() ?? final)
                    rot = -90
                    withAnimation(.linear(duration: 0.09)) { rot = 0 }
                }
                if isLast { Haptics.play(.notch) }
            }
    }
}

private struct BlinkWhileVisible: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content.opacity(on ? 0.35 : 1).loopWhileVisible(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: $on)
    }
}
