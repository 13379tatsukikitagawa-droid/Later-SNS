import SwiftUI

// v14 ⑧ 現像ページャー:今日撮った枚数ぶん(1〜3枚)を、横スワイプでめくる(重なったポラロイドの束)。
// 以前の現像シートは 1枚(いちばん新しい撮影時刻)にしか結びついていなかった。
// 本物の写真データは 9:00 まで使わない。中身は「見せかけ」のもや・ぼかしだけ(色は枚数ごとに決めた朝焼け色)。

enum DevelopPagerRules {
    /// めくる しきい値(pt)
    static let threshold: CGFloat = 70
    /// 1〜3枚目の ぼかし・色の薄さ・もや
    static let blur: [CGFloat] = [6, 8, 10]
    static let saturation: [Double] = [0.55, 0.5, 0.45]
    static let fog: [Double] = [0.5, 0.58, 0.66]
    /// のぞきの上限(ここまでしか色づかない。完全には見せない)
    static let peekLimit = (blur: CGFloat(3), saturation: 0.85, fog: 0.22)
    /// 押しっぱなしで上限まで(秒)
    static let peekDuration: TimeInterval = 1.8

    static func look(index: Int, peek: Double) -> (blur: CGFloat, saturation: Double, fog: Double) {
        let i = min(max(index, 0), 2)
        let p = min(1, max(0, peek))
        return (blur[i] - (blur[i] - peekLimit.blur) * p,
                saturation[i] + (peekLimit.saturation - saturation[i]) * p,
                fog[i] - (fog[i] - peekLimit.fog) * p)
    }

    /// つぎのページ(端ならそのまま。thud を鳴らすかも返す)
    static func page(after current: Int, drag: CGFloat, count: Int) -> (page: Int, hitEnd: Bool) {
        if drag < -threshold {
            return current + 1 < count ? (current + 1, false) : (current, true)
        }
        if drag > threshold {
            return current > 0 ? (current - 1, false) : (current, true)
        }
        return (current, false)
    }

    /// 撮影時刻 → 次の 9:00 の進み(0〜1)
    static func progress(takenAt: Date, now: Date) -> Double {
        let reveal = PhotoDevelop.developDate(takenAt: takenAt)
        let total = reveal.timeIntervalSince(takenAt)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(takenAt) / total))
    }

    static let notes = ["9:00 に 色が ひらくよ", "となりも まだ ねむってる", "さいごの 1まい"]
}

struct DevelopPager: View {
    let shots: [TodayShot]
    let now: Date
    let startIndex: Int
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var drag: CGFloat = 0
    @State private var passedThreshold = false
    /// のぞき(0〜1)
    @State private var peek: Double = 0
    @State private var peekTask: Task<Void, Never>?

    private var count: Int { max(1, shots.count) }

    var body: some View {
        VStack(spacing: 0) {
            Text("現像中 … \(shots.count)まい")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "A9A9B1"))
                .padding(.top, 8)

            ZStack {
                ForEach(Array(shots.enumerated()).reversed(), id: \.element.id) { index, shot in
                    polaroid(shot, index: index)
                }
            }
            .frame(height: 430)
            .padding(.top, 20)
            .contentShape(Rectangle())
            .gesture(swipe)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(page + 1)枚目、\(shots.count)枚のうち。9:00 まで ひみつ")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: go(page + 1)
                case .decrement: go(page - 1)
                @unknown default: break
                }
            }

            HStack(spacing: 8) {
                ForEach(0..<count, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Color(hex: "FFB074") : Color(hex: "55555C"))
                        .frame(width: i == page ? 26 : 8, height: 8)
                        .onTapGesture { go(i) }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: page)
            .padding(.top, 6)

            VStack(spacing: 6) {
                Text("\(page + 1) / \(shots.count) まいめ")
                    .font(.system(size: 22, weight: .heavy))
                Text(page == shots.count - 1 && shots.count > 1 ? DevelopPagerRules.notes[2] : DevelopPagerRules.notes[min(page, 1)])
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "A9A9B1"))
            }
            .foregroundStyle(Color(hex: "F5F5F7"))
            .padding(.top, 14)

            progressBar
                .padding(.horizontal, 36)
                .padding(.top, 18)

            peekButton
                .padding(.top, 22)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            page = min(max(startIndex, 0), count - 1)
            Haptics.prepare(.tick)
        }
        .onDisappear { peekTask?.cancel() }
    }

    // MARK: ポラロイド

    private func polaroid(_ shot: TodayShot, index: Int) -> some View {
        let d = index - page
        let look = DevelopPagerRules.look(index: index, peek: d == 0 ? peek : 0)
        return VStack(alignment: .leading, spacing: 0) {
            ZStack {
                LinearGradient(colors: Self.colors(index), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .saturation(look.saturation)
                    .blur(radius: look.blur)
                    .padding(-14)
                LinearGradient(colors: [Color(hex: "D3E0D8"), Color(hex: "BFD0E0")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(look.fog)
            }
            .frame(height: 276)
            .clipped()
            HStack(alignment: .firstTextBaseline) {
                Text(TodayFilmRules.timeText(shot.takenAt))
                    .font(.system(size: 34, design: .monospaced))
                Spacer()
                Text(shot.city ?? "")
                    .font(.system(size: 17, design: .serif).italic())
                    .foregroundStyle(Color(hex: "777777"))
            }
            .foregroundStyle(Color(hex: "2A2A2E"))
            .padding(.top, 12)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .frame(width: 250, height: 384, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: "F2EDE2")))
        .shadow(color: .black.opacity(0.7), radius: 25, y: 18)
        .brightness(d > 0 ? -0.2 * Double(d) : 0)
        .scaleEffect(d > 0 ? 1 - CGFloat(d) * 0.07 : 1, anchor: UnitPoint(x: 0.5, y: 0.9))
        .rotationEffect(.degrees(d > 0 ? Double(d) * 2.5 : (d == 0 ? Double(drag / 18) : -18)), anchor: UnitPoint(x: 0.5, y: 0.9))
        .offset(x: d > 0 ? CGFloat(d) * 10 : (d == 0 ? drag : -460), y: d > 0 ? -CGFloat(d) * 18 : 0)
        .opacity(d < 0 ? 0 : 1 - Double(max(0, d)) * 0.15)
        .zIndex(Double(10 - abs(d)))
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.6, dampingFraction: 0.72), value: page)
    }

    static func colors(_ index: Int) -> [Color] {
        let sets: [[String]] = [["FFB27A", "FF6A8A", "6C5BA8"], ["9AD0E8", "E9F1E4", "F2B56B"], ["2C3E6B", "E6709A", "FFC27A"]]
        return sets[index % sets.count].map { Color(hex: $0) }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                drag = value.translation.width
                let over = abs(drag) > DevelopPagerRules.threshold
                if over && !passedThreshold { Haptics.play(.tick) }
                passedThreshold = over
            }
            .onEnded { value in
                let result = DevelopPagerRules.page(after: page, drag: value.translation.width, count: count)
                passedThreshold = false
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.75)) {
                    drag = 0
                    page = result.page
                }
                if result.hitEnd {
                    Haptics.play(.thud)
                } else if abs(value.translation.width) > 10 && result.page == page && !result.hitEnd && abs(value.translation.width) <= DevelopPagerRules.threshold {
                    Haptics.play(.soft)
                }
            }
    }

    private func go(_ next: Int) {
        guard next >= 0, next < count else { Haptics.play(.thud); return }
        guard next != page else { return }
        Haptics.play(.tick)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { page = next }
    }

    // MARK: 進み具合

    private var progressBar: some View {
        let taken = shots.indices.contains(page) ? shots[page].takenAt : now
        let p = DevelopPagerRules.progress(takenAt: taken, now: now)
        return VStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "46464C")).frame(height: 4)
                    Capsule().fill(Color(hex: "FFB074")).frame(width: proxy.size.width * p, height: 4)
                    Circle().fill(Color(hex: "FFB074")).frame(width: 14, height: 14)
                        .shadow(color: Color(hex: "FFB074"), radius: 7)
                        .offset(x: proxy.size.width * p - 7)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 14)
            HStack {
                Text("いま \(TodayFilmRules.timeText(now))")
                Spacer()
                Text("9:00")
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color(hex: "A9A9B1"))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("いま \(TodayFilmRules.timeText(now))。9:00 に ひらく")
    }

    // MARK: おしながら 現像を のぞく

    private var peekButton: some View {
        Text(peek >= 1 ? "ここまで。9:00 を まってね" : "おしながら 現像を のぞく")
            .font(.system(size: 14, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .frame(height: 50)
            .background(
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: "323237"))
                        Rectangle().fill(Color(hex: "FFB074").opacity(0.35)).frame(width: proxy.size.width * peek)
                    }
                    .clipShape(Capsule())
                }
            )
            .overlay(Capsule().strokeBorder(Color(hex: "4A4A50"), lineWidth: 1))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if peekTask == nil { startPeek() } }
                    .onEnded { _ in stopPeek() }
            )
            .accessibilityElement()
            .accessibilityLabel("おしながら 現像を のぞく")
            .accessibilityHint("少しだけ色づきます。9:00 まで、ぜんぶは 見えません")
            .accessibilityAddTraits(.isButton)
    }

    /// 押している間:いまの1枚だけ少し色づく(上限まで)。heart がだんだん速く(520ms → 190ms)、上限で thud
    private func startPeek() {
        Haptics.prepare(.heart)
        let from = peek
        let start = Date()
        peekTask = Task { @MainActor in
            var lastBeat = Date.distantPast
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(start)
                let value = min(1, from + elapsed / DevelopPagerRules.peekDuration)
                peek = reduceMotion ? 1 : value
                if Date().timeIntervalSince(lastBeat) >= Haptics.heartInterval(progress: value) {
                    lastBeat = Date()
                    Haptics.play(.heart, gap: 0, intensity: Float(0.5 + 0.5 * value))
                }
                if value >= 1 {
                    Haptics.play(.thud)
                    return
                }
                try? await Task.sleep(for: .milliseconds(30))
            }
        }
    }

    /// 離すと元に戻る(soft)
    private func stopPeek() {
        peekTask?.cancel()
        peekTask = nil
        Haptics.play(.soft)
        withAnimation(.easeOut(duration: reduceMotion ? 0.1 : 0.6)) { peek = 0 }
    }
}
