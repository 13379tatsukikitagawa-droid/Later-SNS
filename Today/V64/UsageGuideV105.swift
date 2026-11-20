import SwiftUI

// v105 設定 > 使いかた。見たい ところを えらぶと、動く 説明(v99 `IntroStoryView`)が はじまる。
// 「ぜんぶ 見る」= Friends → Trip を つづけて。最後まで 見たら 使いかたには もどらない(とじる)。
// ウィジェット = v104 の「ウィジェット、置きますか?」(ボタンは「とじる」)。

struct UsageGuideV105Sheet: View {
    var onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var queue: [IntroKind] = []
    @State private var playing: IntroKind?
    @State private var showsWidgets = false

    private let lime = HV.lime
    private let items: [(IntroKind?, String, String, String)] = [
        (.friends, "Friends", "友だちと 1日 3枚 ・ 9:00 に ひらく", "4 場面"),
        (.trip, "Trip", "旅の あいだ みんなで 23枚", "4 場面"),
        (nil, "ウィジェット", "ホーム画面に 置く", ""),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("使いかた").font(LF.serif(34)).foregroundStyle(.white)
                Spacer()
                Button { Haptics.play(.tick); onClose() } label: { Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44).background(.white.opacity(0.1), in: Circle()) }.buttonStyle(.plain).accessibilityLabel("とじる")
            }.padding(.top, 14)
            Text("見たい ところを えらぶと、動く 説明が はじまります").font(LF.inter(600, 13)).foregroundStyle(.white.opacity(0.6)).padding(.top, 2)
            Button { Haptics.play(.click); play([.friends, .trip]) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill").font(.system(size: 14, weight: .black)).foregroundStyle(lime).frame(width: 36, height: 36).background(Color.black, in: Circle())
                    Text("ぜんぶ 見る").font(LF.inter(800, 17)).foregroundStyle(HV.ink)
                    Spacer()
                    Text("Friends → Trip").font(LF.mono(10, bold: false)).foregroundStyle(HV.ink.opacity(0.6))
                }
                .padding(.horizontal, 14).frame(height: 60).background(lime, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }.buttonStyle(HVPress(scale: 0.97)).padding(.top, 16)
            VStack(spacing: 8) {
                ForEach(items.indices, id: \.self) { i in row(i) }
            }.padding(.top, 12).padding(.bottom, 16)
        }
        .padding(.horizontal, 20)
        .sheetFitsContent()
        .background(Color(hex: "141516").ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .fullScreenCover(item: $playing) { kind in
            IntroStoryView(kind: kind) { finished in
                playing = nil
                if finished, let next = queue.first {
                    queue.removeFirst()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { playing = next }
                } else {
                    queue = []
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onClose() }   // 最後まで 見たら もどらず とじる
                }
            }
        }
        .sheet(isPresented: $showsWidgets) { WidgetGuideV96Sheet(firstTime: false) { showsWidgets = false } }
    }

    private func play(_ kinds: [IntroKind]) {
        queue = Array(kinds.dropFirst())
        playing = kinds.first
    }

    private func row(_ i: Int) -> some View {
        let it = items[i]
        return Button {
            Haptics.play(.sel)
            if let k = it.0 { play([k]) } else { showsWidgets = true }
        } label: {
            HStack(spacing: 12) {
                UsageThumb(index: i, reduceMotion: reduceMotion).frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(it.1).font(LF.inter(800, 16)).foregroundStyle(.white)
                    Text(it.2).font(LF.inter(500, 12)).foregroundStyle(.white.opacity(0.6)).lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 4)
                if !it.3.isEmpty { Text(it.3).font(LF.mono(10, bold: false)).foregroundStyle(.white.opacity(0.4)) }
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 12).frame(height: 68)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }.buttonStyle(HVPress(scale: 0.98)).accessibilityLabel("\(it.1)、\(it.2)")
    }
}

/// 小さな 動く 見本(transform と opacity だけ ・ 見えている 間 だけ ・ Reduce Motion で 止める)
private struct UsageThumb: View {
    let index: Int
    let reduceMotion: Bool
    private let lime = HV.lime

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { ctx in
            let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                Color(hex: "1C1C1E")
                switch index {
                case 0: // 3つの 点が 回る
                    ForEach(0..<3, id: \.self) { k in
                        Circle().fill(lime).frame(width: 9, height: 9)
                            .offset(x: 14 * cos(t * 2.2 + Double(k) * 2.094), y: 14 * sin(t * 2.2 + Double(k) * 2.094))
                    }
                case 1: // ライムの 23
                    Text("23").font(LF.inter(900, 22)).foregroundStyle(lime).scaleEffect(1 + 0.06 * sin(t * 3))
                case 2: // 地球の 線が 流れる
                    ForEach(0..<3, id: \.self) { k in
                        let q = (t / 3 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                        Ellipse().stroke(lime.opacity(0.7 * (1 - q)), lineWidth: 1.2).frame(width: 34 * (0.3 + q), height: 34).scaleEffect(1)
                    }
                default: // # が ぽんと 出る
                    let q = (t / 2.4).truncatingRemainder(dividingBy: 1)
                    let s = q < 0.25 ? q / 0.25 * 1.2 : (q < 0.4 ? 1.2 - (q - 0.25) / 0.15 * 0.2 : 1)
                    Text("#").font(LF.inter(900, 28)).foregroundStyle(lime).scaleEffect(reduceMotion ? 1 : max(0.01, s))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
