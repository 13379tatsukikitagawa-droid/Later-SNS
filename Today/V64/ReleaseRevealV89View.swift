import SwiftUI

// v134 Phase 3:ひらく(撮った あと = きのうの 写真が ひらく)。見本 screens/34〜36。
// 上から 光(弱め)。「YESTERDAY ・ 11.25 ・ 17:12」+「1 / 3」(Barlow)。チェキ(白い 枠 ・ 下が 広い ・ 角丸 6)の 中で、
// 写真が ミルク色から 現像される(`filmDevelop`)。何もしなくても 9秒で ひらき、写真を おさえている 間は 1.4秒の 速さ。
// ひらいたら 触感「トトトン」→ 下から「あと2枚は、今日撮るたびにひらきます」+ ライム「のせる」/ グレー「自分だけ」。
// どの 写真が ひらくか ・ いくつ ひらくかは 今までの まま(呼ぶ 側が 決める)。結果は .posted(のせる)/ .skipped(自分だけ)/ .later(下へ 払う)。

struct ReleaseRevealV89View: View {
    let image: UIImage?
    let ordinal: Int
    let count: Int
    var tag: String?
    var time: String
    var place: String?
    var playsReveal: Bool
    var onFinish: (YesterdayRevealView.Outcome) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress = 0.0
    @State private var holding = false
    @State private var finished = false
    @State private var opened = false
    @State private var dragY: CGFloat = 0
    @State private var flying: Bool?    // true = のせる(上へ) / false = 自分だけ(下へ)
    @State private var task: Task<Void, Never>?

    static let autoSeconds = 9.0
    static let fastSeconds = 1.4

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LTColor.bg.ignoresSafeArea()
                RadialGradient(colors: [Color.white.opacity(0.22 * (1 - 0.4 * progress)), .clear], center: UnitPoint(x: 0.5, y: 0.0), startRadius: 0, endRadius: proxy.size.height * 0.42)
                    .ignoresSafeArea().allowsHitTesting(false)
                VStack(spacing: 0) {
                    VStack(spacing: 6) {
                        Text("YESTERDAY ・ \(Self.dateLabel) ・ \(time)").font(LTFont.ui(12, weight: .heavy)).tracking(1.6).foregroundStyle(LTColor.ink3)
                        Text("\(max(1, ordinal)) / \(max(1, count))").font(LTFont.display(54))
                            .foregroundStyle(LinearGradient(colors: [.white, LTColor.tagGray], startPoint: .top, endPoint: .bottom))
                    }.padding(.top, max(56, proxy.safeAreaInsets.top + 24))
                    cheki(width: min(300, proxy.size.width - 56))
                        .padding(.top, 22)
                        .opacity(flying == nil ? 1 : 0)
                        .offset(y: flying == true ? -proxy.size.height : (flying == false ? 160 : 0))
                        .animation(.easeIn(duration: 0.62), value: flying)
                    progressBar.padding(.top, 20).padding(.horizontal, 56)
                    Text(opened ? " " : "おさえると、はやくひらく").font(LTFont.ui(13)).foregroundStyle(LTColor.ink3).padding(.top, 10)
                    Spacer(minLength: 0)
                    bottom.padding(.horizontal, 16).padding(.bottom, max(proxy.safeAreaInsets.bottom, 12) + 6)
                        .opacity(opened ? 1 : 0).offset(y: opened ? 0 : 30)
                        .allowsHitTesting(opened && flying == nil && !finished)
                }
            }
            .offset(y: max(0, dragY))
            .gesture(DragGesture(minimumDistance: 14).onChanged { if !holding && $0.translation.height > 0 { dragY = $0.translation.height } }
                .onEnded { v in if v.translation.height > 140 { finish(.later) } else { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { dragY = 0 } } })
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .onAppear(perform: begin)
        .onDisappear { task?.cancel(); LTHaptics.endHold() }
        .accessibilityAction(.escape) { finish(.later) }
    }

    // MARK: チェキ

    private func cheki(width: CGFloat) -> some View {
        let photoW = width - 28
        let photoH = photoW * 4 / 3
        return VStack(spacing: 0) {
            ZStack {
                Color(hex6: 0x1C1C1F)
                if let image { Image(uiImage: image).resizable().scaledToFill() }
            }
            .frame(width: photoW, height: photoH).clipped()
            .filmDevelop(progress)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 60, maximumDistance: 400, perform: {}, onPressingChanged: { pressing in press(pressing) })
            .accessibilityLabel("きのうの写真。おさえるとはやくひらく")
            HStack {
                if let tag, !tag.isEmpty { Text("#\(tag)").font(LTFont.ui(14, weight: .heavy)).foregroundStyle(Color(hex6: 0x2A2A2E)).lineLimit(1) }
                Spacer(minLength: 8)
                DateStamp(text: Self.stamp, size: 13).opacity(opened ? 1 : 0.35)
            }.frame(width: photoW, height: 46)
        }
        .padding(.top, 14).padding(.horizontal, 14).padding(.bottom, 2)
        .background { RoundedRectangle(cornerRadius: 6, style: .continuous).fill(LTColor.chekiFrame).shadow(color: .black.opacity(0.6), radius: 24, y: 14) }
    }

    private var progressBar: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule().fill(opened ? LTColor.lime : Color.white.opacity(0.55)).frame(width: max(4, g.size.width * progress))
            }
        }.frame(height: 4).accessibilityHidden(true)
    }

    private var bottom: some View {
        VStack(spacing: 12) {
            Text(count - ordinal > 0 ? "あと\(count - ordinal)枚は、今日撮るたびにひらきます" : "きのうの写真は、これでぜんぶ").font(LTFont.ui(14)).foregroundStyle(LTColor.ink2)
            HStack(spacing: 10) {
                Button { publish(true) } label: {
                    Text("のせる").font(LTFont.ui(18, weight: .heavy)).foregroundStyle(LTColor.limeInk).frame(maxWidth: .infinity).frame(height: 56)
                        .background(LTColor.lime, in: RoundedRectangle(cornerRadius: LTRadius.button, style: .continuous))
                        .shadow(color: LTColor.lime.opacity(0.4), radius: 12, y: 7)
                }.buttonStyle(HVPress(scale: 0.97))
                Button { publish(false) } label: {
                    Text("自分だけ").font(LTFont.ui(18, weight: .heavy)).foregroundStyle(.white).frame(width: 130, height: 56)
                        .background(LTColor.surface3, in: RoundedRectangle(cornerRadius: LTRadius.button, style: .continuous))
                }.buttonStyle(HVPress(scale: 0.97))
            }
        }
    }

    // MARK: 動き

    private static var yesterday: Date { Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date() }
    private static var dateLabel: String { let f = DateFormatter(); f.dateFormat = "MM.dd"; return f.string(from: yesterday) }
    private static var stamp: String { HomeV134Rules.stamp(yesterday) }

    private func begin() {
        guard playsReveal else { progress = 1; opened = true; return }
        if reduceMotion { withAnimation(.easeOut(duration: 0.4)) { progress = 1 }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { complete(haptic: false) }; return }
        run()
    }

    /// 自然に 9秒 ・ おさえている 間は 1.4秒で ひらく(進みは 1つの 数だけ)
    private func run() {
        task?.cancel()
        task = Task { @MainActor in
            var last = Date()
            while !Task.isCancelled, progress < 1 {
                try? await Task.sleep(for: .milliseconds(16))
                let now = Date(); let dt = now.timeIntervalSince(last); last = now
                progress = min(1, progress + dt / (holding ? Self.fastSeconds : Self.autoSeconds))
                if holding { LTHaptics.updateHold(progress: progress) }
            }
            if progress >= 1 { complete(haptic: true) }
        }
    }

    private func press(_ pressing: Bool) {
        guard !opened, !finished else { return }
        holding = pressing
        if pressing { LTHaptics.beginHold() } else { LTHaptics.endHold() }
    }

    private func complete(haptic: Bool) {
        guard !opened else { return }
        holding = false
        LTHaptics.endHold()
        if haptic { LTHaptics.play(.opened) }
        withAnimation(.easeOut(duration: 0.4)) { opened = true }
    }

    private func publish(_ friends: Bool) {
        guard flying == nil, !finished else { return }
        flying = friends
        LTHaptics.play(friends ? .posted : .tap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { finish(friends ? .posted : .skipped) }
    }

    private func finish(_ o: YesterdayRevealView.Outcome) {
        guard !finished else { return }
        finished = true; task?.cancel(); LTHaptics.endHold()
        onFinish(o)
    }
}
