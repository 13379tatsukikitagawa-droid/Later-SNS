import SwiftUI

// v22 G:現像ビュー(Home の 今日のカードを おすと、下から せり上がる)。見本:later_v22.html の「現像ビュー」。
// 撮ったこまは「色のもや」が だんだん 濃くなる。写真の中身は ぜったいに 出さない
// (ChekiDevelopImage に texture を渡さず、代表色の もやだけで描く)。
// 横スワイプで 1日 3こままで。開いたとき・着いたとき 0% →「いまの濃さ」まで 自動で再生。
// 下の時間バーで 撮った → いま を つまんで動かせる。いまより さきは しましま(warn)。

enum DevelopViewerRules {
    /// いまの濃さ(0〜1)。撮った時刻 → 次の 9:00
    static func density(takenAt: Date, now: Date) -> Double {
        DevelopDensity.density(DevelopDensity.fraction(capturedAt: takenAt, now: now))
    }

    /// 再生の長さ:2.6〜5秒(濃いほど長く)
    static func playDuration(_ k: Double) -> Double { 2.6 + 2.4 * min(1, max(0, k)) }

    static func hm(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}

struct HomeDevelopViewer: View {
    /// 今日 撮った時刻(順番どおり)。保存が まだのこまは、ここに なくても used で数える
    let shots: [Date]
    let videoDurations: [Date: Double]
    let used: Int
    let tones: [Color]
    let now: Date
    let onClose: () -> Void
    let onShoot: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index: Int?
    @State private var densities: [Double] = [0, 0, 0]
    @State private var seen: Set<Int> = []
    @State private var playing = false
    @State private var playToken = 0
    @State private var ramp = HapticRamp()
    @State private var dragging = false
    @State private var overNow = false
    @State private var lastStep = -1
    @State private var barShake = 0
    @State private var bump = 0
    @State private var entered = false

    private var current: Int { index ?? 0 }
    private var taken: Int { min(3, max(used, shots.count)) }

    private func takenAt(_ i: Int) -> Date { i < shots.count ? shots[i] : now }
    private func target(_ i: Int) -> Double { i < taken ? DevelopViewerRules.density(takenAt: takenAt(i), now: now) : 0 }

    var body: some View {
        VStack(spacing: 0) {
            header
            pager.frame(height: 410)
            dots.padding(.top, 10)
            controls.padding(.horizontal, 22).padding(.top, 20)
            Spacer(minLength: 0)
        }
        .background {
            ZStack {
                Color.white
                RadialGradient(colors: [Color(hex: "FFF0E6"), .white.opacity(0)], center: .top, startRadius: 0, endRadius: 360)
                    .scaleEffect(x: 1.8, y: 1, anchor: .top)
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.light)
        .onAppear(perform: appear)
        .onDisappear(perform: stop)
        .onChange(of: index) { old, new in
            guard old != nil, let new, entered else { return }
            stop()
            Haptics.play(.detent)
            if new < taken && !seen.contains(new) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                    if index == new && !seen.contains(new) && !playing { play(new) }
                }
            }
        }
    }

    // MARK: 上

    private var header: some View {
        HStack(alignment: .lastTextBaseline, spacing: 12) {
            Button(action: close) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(hex: "111111"))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color(hex: "F4F3F7")))
            }
            .buttonStyle(SquishButtonStyle(pressedScale: 0.92))
            .accessibilityLabel("もどる")
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("developing").font(.system(size: 40, design: .serif).italic()).foregroundStyle(Color(hex: "111111"))
                Text("\(current + 1) / 3").font(.system(size: 12, design: .monospaced)).tracking(0.08 * 12).foregroundStyle(Color(hex: "FF6A1A"))
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    // MARK: カード(横スワイプ・スナップ・となりは すこし小さく うすく)

    private var pager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
                    card(i)
                        .containerRelativeFrame(.horizontal)
                        .scrollTransition(axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(1 - 0.12 * min(1, abs(phase.value)))
                                .opacity(1 - 0.45 * min(1, abs(phase.value)))
                                .offset(x: -14 * phase.value)
                        }
                        .offset(y: entered || reduceMotion ? 0 : 46)
                        .opacity(entered || reduceMotion ? 1 : 0)
                        .animation(.spring(response: 0.62, dampingFraction: 0.72).delay(0.16 + Double(i) * 0.07), value: entered)
                        .id(i)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollClipDisabled()
        .scrollPosition(id: $index)
        .scrollIndicators(.hidden)
    }

    private func card(_ i: Int) -> some View {
        let tilt = [-2.5, 2.0, -1.5][i]
        return VStack(spacing: 0) {
            window(i).frame(height: 300).clipShape(RoundedRectangle(cornerRadius: 3))
            HStack {
                if i < taken {
                    Text(videoDurations[takenAt(i)] != nil ? "MOVIE" : "PHOTO")
                        .font(.system(size: 10, design: .monospaced)).tracking(0.16 * 10).foregroundStyle(Color(hex: "8E8E93"))
                    Spacer()
                    Text(DevelopViewerRules.hm(takenAt(i))).font(.custom("Caveat-Bold", size: 21)).foregroundStyle(Color(hex: "3A3A3C"))
                } else {
                    Spacer()
                }
            }
            .frame(height: 42)
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, 12).padding(.top, 12)
        .frame(width: 250)
        .background(RoundedRectangle(cornerRadius: 6).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.black.opacity(0.05), lineWidth: 1))
        .shadow(color: Color(red: 0.24, green: 0.12, blue: 0.31).opacity(0.45), radius: 20, y: 22)
        .rotationEffect(.degrees(tilt))
        .keyframeAnimator(initialValue: 1.0, trigger: i == current ? bump : 0) { content, s in content.scaleEffect(s) } keyframes: { _ in
            KeyframeTrack { CubicKeyframe(1.04, duration: 0.14); SpringKeyframe(1, duration: 0.32) }
        }
        .onTapGesture {
            if i == taken { shootNext() } else if i > taken { Haptics.play(.warn) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(i < taken ? "\(i + 1)こま目。現像 \(Int((densities[i] * 100).rounded()))%。中身は 9:00 まで ひみつ" : (i == taken ? "\(i + 1)こま目を 撮る" : "あとで"))
    }

    @ViewBuilder
    private func window(_ i: Int) -> some View {
        if i < taken {
            ZStack {
                // 色のもやだけ(写真の中身は 渡さない)
                ChekiDevelopImage(texture: nil, tones: tones, density: densities[i], isSheet: true, blurScale: 2.4, isAnimating: !reduceMotion)
                DevelopBubbles(running: !reduceMotion)
                Text("DEVELOPING")
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(0.24 * 10)
                    .foregroundStyle(Color(red: 0.16, green: 0.16, blue: 0.2).opacity(0.5))
                    .opacity(max(0, 1 - densities[i] * 1.6))
            }
        } else if i == taken {
            VStack(spacing: 8) {
                Image(systemName: "plus").font(.system(size: 26, weight: .bold))
                Text("\(i + 1)こま目を 撮る").font(.system(size: 15, weight: .heavy))
                Text("撮ると ここで 濃くなっていきます").font(.system(size: 11, weight: .medium)).foregroundStyle(Color(hex: "8E8E93"))
            }
            .foregroundStyle(Color(hex: "111111"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color(hex: "111111"), style: StrokeStyle(lineWidth: 1.6, dash: [5, 4])))
        } else {
            VStack(spacing: 8) {
                Text("あとで").font(.system(size: 14, weight: .semibold))
                Text("1こま ずつ 順番に").font(.system(size: 11, weight: .medium)).foregroundStyle(Color(hex: "8E8E93"))
            }
            .foregroundStyle(Color(hex: "B9B6C0"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "FBF9F4"))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color(hex: "D0CDD6"), style: StrokeStyle(lineWidth: 1.4, dash: [5, 4])))
        }
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { i in
                Capsule().fill(i == current ? Color(hex: "111111") : Color(hex: "D9D8DE"))
                    .frame(width: i == current ? 22 : 7, height: 7)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: current)
        .accessibilityHidden(true)
    }

    // MARK: 下(% ・ 時間バー ・ 見るボタン)

    @ViewBuilder
    private var controls: some View {
        let i = current
        VStack(spacing: 12) {
            if i < taken {
                let k = target(i), d = densities[i]
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int((d * 100).rounded()))").font(.system(size: 44, weight: .black)).tracking(-0.06 * 44).monospacedDigit()
                    Text("%").font(.system(size: 15, weight: .heavy))
                    Spacer()
                    Text(d >= k - 0.004 ? "いま ここ" : (playing ? "濃くなっていく…" : "とちゅう"))
                        .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(0.1 * 11).foregroundStyle(Color(hex: "FF6A1A"))
                }
                .foregroundStyle(Color(hex: "111111"))
                timeBar(k: k, d: d)
                    .modifier(ShakeEffect(animatableData: CGFloat(barShake)))
                    .animation(.linear(duration: 0.28), value: barShake)
                HStack {
                    Text("\(DevelopViewerRules.hm(takenAt(i))) 撮った")
                    Spacer()
                    Text("9:00 ひらく")
                }
                .font(.system(size: 10, design: .monospaced)).tracking(0.12 * 10).foregroundStyle(Color(hex: "8E8E93"))
                .padding(.top, -4)
                Button(action: replay) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill").font(.system(size: 14))
                        Text(playing ? "濃くなっている…" : (seen.contains(i) ? "もういちど 見る" : "濃くなるところを 見る")).font(.system(size: 15, weight: .heavy))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "111111")))
                }
                .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
                Text("9:00 まで \(HomeV22Rules.untilNine(now: now)) ・ 中身は ひみつ。9:00 に ひらきます")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(Color(hex: "8E8E93"))
            } else {
                Text(i == taken ? "撮ると、この 1こまが 9:00 まで ゆっくり 濃くなります" : "1こま ずつ、順番に 撮れます")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(Color(hex: "8E8E93"))
                    .padding(.top, 70)
            }
        }
        .multilineTextAlignment(.center)
    }

    private func timeBar(k: Double, d: Double) -> some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: "EEEDF2")).frame(height: 6)
                // いまより さき:しましま(ロック)
                StripeShape().fill(Color(hex: "DAD9DF"))
                    .frame(width: max(0, w * (1 - k)), height: 6)
                    .clipShape(Capsule())
                    .offset(x: w * k)
                Capsule().fill(LinearGradient(colors: [Color(hex: "D9DFE8"), Color(hex: "FFB38A"), Color(hex: "FF6A1A")], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, w * d), height: 6)
                RoundedRectangle(cornerRadius: 1).fill(Color(hex: "111111")).frame(width: 2, height: 18).offset(x: w * k - 1)
                Circle().fill(.white)
                    .overlay(Circle().strokeBorder(Color(hex: "111111"), lineWidth: 2))
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 4)
                    .scaleEffect(dragging ? 1.25 : 1)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: dragging)
                    .offset(x: w * d - 10)
            }
            .frame(height: 30)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in scrub(to: value.location.x / max(1, w), k: k) }
                    .onEnded { _ in endScrub(k: k) }
            )
        }
        .frame(height: 30)
        .accessibilityElement()
        .accessibilityLabel("時間のバー")
        .accessibilityValue("\(Int((d * 100).rounded()))%")
        .accessibilityAdjustableAction { direction in
            let i = current
            densities[i] = direction == .increment ? min(k, densities[i] + 0.05) : max(0, densities[i] - 0.05)
        }
    }

    // MARK: 動き

    private func appear() {
        let start = min(2, max(0, taken == 0 ? 0 : taken - 1))
        densities = (0..<3).map { target($0) }
        index = start
        Haptics.play(.land)
        DispatchQueue.main.async { entered = true }
        if start < taken {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.76) {
                if index == start && !seen.contains(start) { play(start) }
            }
        }
    }

    /// 0% →「いまの濃さ」まで(なめらか)。再生中は 連続の ふるえが だんだん 強く + 10%ごとに sel、おわりに heart
    private func play(_ i: Int) {
        guard i < taken else { return }
        seen.insert(i)
        let k = target(i)
        if reduceMotion {
            densities[i] = k
            Haptics.play(.heart)
            return
        }
        playToken += 1
        let token = playToken
        playing = true
        densities[i] = 0
        ramp.start()
        let duration = DevelopViewerRules.playDuration(k)
        let begin = Date()
        var lastTen = 0
        Task { @MainActor in
            while token == playToken {
                let p = min(1, Date().timeIntervalSince(begin) / duration)
                let e = p * p * (3 - 2 * p)
                densities[i] = k * e
                ramp.update(0.05 + 0.5 * p)
                let ten = Int(densities[i] * 10)
                if ten != lastTen && ten > 0 {
                    lastTen = ten
                    Haptics.play(.detent)
                }
                if p >= 1 { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
            guard token == playToken else { return }
            ramp.stop()
            playing = false
            Haptics.play(.heart)
            bump += 1
        }
    }

    private func stop() {
        playToken += 1
        playing = false
        ramp.stop()
    }

    private func replay() {
        let i = current
        if playing {
            Haptics.play(.warn)
            return
        }
        Haptics.play(.click)
        play(i)
    }

    /// 時間バーを つまむ:soft、5%ごとに tick、いまより さきは warn で とまる
    private func scrub(to raw: Double, k: Double) {
        let i = current
        guard i < taken else { return }
        if !dragging {
            stop()
            seen.insert(i)
            dragging = true
            overNow = false
            lastStep = -1
            Haptics.play(.soft)
        }
        var d = min(1, max(0, raw))
        if d > k {
            d = k
            if !overNow {
                overNow = true
                Haptics.play(.warn)
                barShake += 1
            }
        } else {
            overNow = false
        }
        densities[i] = d
        let step = Int(d * 20)
        if step != lastStep {
            lastStep = step
            Haptics.play(.tick)
        }
    }

    private func endScrub(k: Double) {
        guard dragging else { return }
        dragging = false
        Haptics.play(densities[current] >= k - 0.004 ? .pop : .soft)
    }

    private func shootNext() {
        Haptics.play(.click)
        stop()
        onClose()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { onShoot() }
    }

    private func close() {
        Haptics.play(.soft)
        stop()
        onClose()
    }
}

/// もやの中を のぼる 小さな泡
private struct DevelopBubbles: View {
    let running: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !running)) { context in
            let t = running ? context.date.timeIntervalSinceReferenceDate : 0
            Canvas { ctx, size in
                for j in 0..<7 {
                    let dur = 3.4 + Double(j % 3) * 0.8
                    let p = ((t + Double(j) * 0.7).truncatingRemainder(dividingBy: dur)) / dur
                    let x = size.width * (0.08 + Double(j) * 0.14)
                    let y = size.height + 10 - (size.height + 20) * p
                    let a = p < 0.15 ? p / 0.15 : (p > 0.8 ? (1 - p) / 0.2 : 1)
                    let r = 3.5 * (0.6 + 0.4 * p)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(.white.opacity(0.9 * a)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// 斜めの しましま
private struct StripeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX - rect.height
        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            path.addLine(to: CGPoint(x: x + rect.height + 3, y: rect.minY))
            path.addLine(to: CGPoint(x: x + 3, y: rect.maxY))
            path.closeSubpath()
            x += 6
        }
        return path
    }
}
