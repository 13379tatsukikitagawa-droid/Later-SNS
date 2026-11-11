import SwiftUI

// v30「現像中の 画面」(Home の 今日の こまを おすと 開く)。見本:later_v30.html の #dvx。
// 暗室の 黒 + チェキの 現像:自分の 写真の 上に ミルク色の 膜。進むほど 膜が うすく、青緑が 出て → 色へ。
// 9:00 まで 膜は 完全には 消えない(中身は ひみつの まま)。本当の 現像は 今まで どおり「ひらく」画面だけ。
// 横スワイプで 1日 3こままで。開いたとき・着いたとき 0% →「いまの濃さ」まで 自動で再生。
// 下の 進み線で 撮った → いま を つまんで動かせる。いまより さきは 点線(warn)。
// 写真は 本人の 端末で 本人の 写真だけ(ほかの人の 写真は ここに 出さない)。

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

    /// 「15H 09M」(1時間 未満は「42M」)
    static func opensIn(_ seconds: TimeInterval) -> String {
        let m = max(0, Int(seconds / 60))
        return m >= 60 ? String(format: "%dH %02dM", m / 60, m % 60) : "\(m)M"
    }

    static func ordinal(_ n: Int) -> String {
        switch n {
        case 1: "1ST"
        case 2: "2ND"
        case 3: "3RD"
        default: "\(n)TH"
        }
    }
}

/// チェキの 現像の 見え方(進み 0〜1 → 膜・ぼかし・彩度・明るさ・青緑)。現像ビューと Home の 今日の こまで 共通
struct DevelopLook: Equatable {
    /// ミルク色の 膜の 濃さ(0.97 → 0.47。9:00 まで 消えない)
    let film: Double
    /// ぼかし(pt):16 → 5
    let blur: Double
    /// 彩度:0.08 → 0.93
    let saturation: Double
    /// 明るさ(かけ算):1.55 → 1.10
    let brightness: Double
    /// 青緑(#8FD0C6・乗算)の 濃さ:0 → 途中で 0.6 → 0
    let tealTint: Double

    static let teal = Color(hex: "8FD0C6")

    static func values(progress: Double) -> DevelopLook {
        let p = min(1, max(0, progress))
        // 見本と 同じ:はじめは はやく、あとは ゆっくり
        let v = pow(p, 0.6)
        return DevelopLook(
            film: 0.97 - 0.5 * v,
            blur: 16 - 11 * v,
            saturation: 0.08 + 0.85 * v,
            brightness: 1.55 - 0.45 * v,
            tealTint: max(0, sin(Double.pi * min(1, v * 1.15)) * 0.6)
        )
    }
}

/// 自分の 写真 + チェキの 膜(ミルク色・青緑・光の すじ)
// TODO(v30): チェキ用の 色の LUT(cheki_lut33.bin)を 写真に かける。ファイルが まだ 無いので 今は かけていない
struct DevelopFilmPhoto: View {
    let photo: LaterPhoto?
    let progress: Double
    var tones: [Color] = []
    /// 小さい こまでは ぼかしを 小さく(同じ 式の 小さい 版)
    var blurScale: Double = 1
    var shineDelay: Double = 0
    var shinePeriod: Double = 3.6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: UIImage?

    var body: some View {
        let look = DevelopLook.values(progress: progress)
        ZStack {
            Color(hex: "E9EEEA")
            // 写真の 大きさに ひっぱられない ように(わくの 大きさで 切る)
            Color.clear.overlay {
                Group {
                    if let image {
                        ZStack {
                            Image(uiImage: image).resizable().scaledToFill()
                            // 明るさの かけ算(c × b = c + c × (b − 1))
                            Image(uiImage: image).resizable().scaledToFill()
                                .opacity(max(0, look.brightness - 1)).blendMode(.plusLighter)
                        }
                        .compositingGroup()
                    } else if !tones.isEmpty {
                        LinearGradient(colors: tones, startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
                .saturation(look.saturation)
                .contrast(0.9)
                .blur(radius: look.blur * blurScale)
                .scaleEffect(1.06)
            }
            .clipped()
            DevelopLook.teal.blendMode(.multiply).opacity(look.tealTint)
            LinearGradient(stops: [
                .init(color: Color(hex: "EEF3EE"), location: 0),
                .init(color: Color(hex: "DCE6E3"), location: 0.6),
                .init(color: Color(hex: "E4E9E6"), location: 1),
            ], startPoint: UnitPoint(x: 0.37, y: 0), endPoint: UnitPoint(x: 0.63, y: 1))
            .opacity(look.film)
            if !reduceMotion {
                DevelopShine(delay: shineDelay, period: shinePeriod)
            }
        }
        .clipped()
        .task(id: photo?.id) {
            guard let photo, !photo.imageData.isEmpty else { image = nil; return }
            image = await MEImageLoader.load(key: "develop-\(photo.id.uuidString)", data: photo.imageData)
        }
    }
}

/// 光の すじ:しばらく 止まって → 横に 流れる(見本の obsh)
private struct DevelopShine: View {
    let delay: Double
    let period: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            GeometryReader { proxy in
                let t = (context.date.timeIntervalSinceReferenceDate - delay).truncatingRemainder(dividingBy: period) / period
                let phase = t < 0 ? t + 1 : t
                let q = max(0, (phase - 0.55) / 0.45)
                let e = q * q * (3 - 2 * q)
                LinearGradient(stops: [
                    .init(color: .white.opacity(0), location: 0.32),
                    .init(color: .white.opacity(0.5), location: 0.5),
                    .init(color: .white.opacity(0), location: 0.68),
                ], startPoint: UnitPoint(x: 0, y: 0.32), endPoint: UnitPoint(x: 1, y: 0.68))
                .offset(x: (-1 + 2 * e) * proxy.size.width)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct HomeDevelopViewer: View {
    /// 今日 撮った時刻(順番どおり)。保存が まだのこまは、ここに なくても used で数える
    let shots: [Date]
    let videoDurations: [Date: Double]
    let used: Int
    let tones: [Color]
    let now: Date
    /// 自分の 写真(shots と 同じ 順番。まだ 無い こまは nil)
    var photos: [LaterPhoto?] = []
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
    private func photo(_ i: Int) -> LaterPhoto? { i < photos.count ? photos[i] : nil }

    var body: some View {
        GeometryReader { proxy in
            // 下の 操作ぶんを のこして、カードは 最大 470(見本は 452。大きい 画面で 下が あきすぎない ように)
            let cardHeight = min(470, max(240, proxy.size.height - 336))
            VStack(spacing: 0) {
                header
                pager(height: cardHeight).frame(height: cardHeight + 10)
                dots.padding(.top, 12)
                controls.padding(.horizontal, 18).padding(.top, 16)
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(.white)
        .background(Darkroom.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
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
        HStack(spacing: 10) {
            Button(action: close) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Darkroom.card))
            }
            .buttonStyle(SquishButtonStyle(pressedScale: 0.92))
            .accessibilityLabel(Text("develop.a11y.back"))
            VStack(spacing: 3) {
                Text(verbatim: "Developing").font(Darkroom.title("Developing", size: 26))
                Text(verbatim: "\(current + 1) / 3").font(.system(size: 12.5, weight: .medium)).foregroundStyle(Darkroom.weak)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            Color.clear.frame(width: 48, height: 48)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: カード(横スワイプ・スナップ)

    private func pager(height: CGFloat) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
                    card(i, height: height)
                        .padding(.horizontal, 14)
                        .containerRelativeFrame(.horizontal)
                        .scrollTransition(axis: .horizontal) { content, phase in
                            content.opacity(1 - 0.45 * min(1, abs(phase.value)))
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

    private func card(_ i: Int, height: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        return Group {
            if i < taken {
                DevelopFilmPhoto(photo: photo(i), progress: densities[i], tones: tones)
                    .overlay(alignment: .topTrailing) {
                        Text(verbatim: "\(Int((densities[i] * 100).rounded()))%")
                            .font(.custom("InstrumentSerif-Italic", size: 24)).foregroundStyle(Color(hex: "3A362F").opacity(0.85))
                            .padding(.trailing, 18).padding(.top, 14)
                    }
                    .overlay(alignment: .bottom) {
                        HStack(alignment: .lastTextBaseline) {
                            Text(verbatim: DevelopViewerRules.hm(takenAt(i)))
                                .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(0.06 * 11)
                                .foregroundStyle(Color(hex: "E0481A"))
                                .shadow(color: Color(red: 1, green: 0.47, blue: 0.16).opacity(0.5), radius: 3)
                            Spacer()
                            Text(verbatim: videoDurations[takenAt(i)] != nil ? "MOVIE" : "PHOTO")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(0.2 * 9.5)
                                .foregroundStyle(Color(hex: "5F5A52"))
                        }
                        .padding(.horizontal, 18).padding(.bottom, 18)
                    }
            } else if i == taken {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                        .padding(10)
                    VStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 30, weight: .medium))
                        Text(verbatim: "shoot").font(.custom("InstrumentSerif-Regular", size: 30))
                        Text(verbatim: "\(DevelopViewerRules.ordinal(i + 1)) SHOT")
                            .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(0.2 * 10).foregroundStyle(Darkroom.weak)
                    }
                }
                .overlay(shape.strokeBorder(.white.opacity(0.18), lineWidth: 1.5))
            } else {
                VStack(spacing: 8) {
                    Text(verbatim: "later").font(.custom("InstrumentSerif-Regular", size: 30)).foregroundStyle(Darkroom.faint)
                    Text(verbatim: "ONE BY ONE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(0.2 * 10).foregroundStyle(Darkroom.weak)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(shape.strokeBorder(.white.opacity(0.07), lineWidth: 1.5))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(shape)
        .contentShape(shape)
        .shadow(color: .black.opacity(i < taken ? 0.7 : 0), radius: 30, y: 26)
        .keyframeAnimator(initialValue: 1.0, trigger: i == current ? bump : 0) { content, s in content.scaleEffect(s) } keyframes: { _ in
            KeyframeTrack { CubicKeyframe(1.03, duration: 0.14); SpringKeyframe(1, duration: 0.32) }
        }
        .onTapGesture {
            if i == taken { shootNext() } else if i > taken { Haptics.play(.warn) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(i < taken
            ? String(format: String(localized: "develop.a11y.frame"), i + 1, Int((densities[i] * 100).rounded()))
            : (i == taken ? String(format: String(localized: "develop.a11y.shoot"), i + 1) : String(localized: "develop.a11y.later")))
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { i in
                Capsule().fill(i == current ? Color.white : Color(hex: "2A2A2E"))
                    .frame(width: i == current ? 22 : 7, height: 7)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: current)
        .accessibilityHidden(true)
    }

    // MARK: 下(% ・ 進み線 ・ 見るボタン)

    private var note: some View {
        Text(verbatim: current < taken
             ? "OPENS IN \(DevelopViewerRules.opensIn(PhotoDevelop.developDate(takenAt: now).timeIntervalSince(now)))"
             : (current == taken ? "SHOOT TO START DEVELOPING" : "ONE BY ONE"))
            .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(0.18 * 10)
            .foregroundStyle(Color(hex: "6E6E75"))
    }

    @ViewBuilder
    private var controls: some View {
        let i = current
        VStack(spacing: 10) {
            if i < taken {
                let k = target(i), d = densities[i]
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(verbatim: "\(Int((d * 100).rounded()))").font(.custom("InstrumentSerif-Italic", size: 46)).monospacedDigit()
                    Text(verbatim: "%").font(.custom("InstrumentSerif-Italic", size: 22)).foregroundStyle(Darkroom.weak)
                    Spacer()
                    Text(verbatim: d >= k - 0.004 ? "NOW" : (playing ? "DEVELOPING…" : "REPLAY"))
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced)).tracking(0.2 * 10.5).foregroundStyle(Darkroom.stamp)
                }
                .frame(height: 46)
                timeBar(k: k, d: d)
                    .modifier(ShakeEffect(animatableData: CGFloat(barShake)))
                    .animation(.linear(duration: 0.28), value: barShake)
                HStack {
                    Text(verbatim: "\(DevelopViewerRules.hm(takenAt(i))) SHOT")
                    Spacer()
                    Text(verbatim: "9:00 OPENS")
                }
                .font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(0.18 * 9.5).foregroundStyle(Color(hex: "6E6E75"))
                .padding(.top, -4)
                Button(action: replay) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill").font(.system(size: 14))
                        Text(verbatim: playing ? "developing…" : (seen.contains(i) ? "watch again" : "watch it develop"))
                            .font(.system(size: 15, weight: .heavy))
                    }
                    .foregroundStyle(Color(hex: "111111"))
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(Capsule().fill(.white))
                }
                .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
                .padding(.top, 4)
                note
            } else {
                note.padding(.top, 8)
            }
        }
    }

    private func timeBar(k: Double, d: Double) -> some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12)).frame(height: 3)
                // いまより さき:点線(ロック)
                Path { p in
                    p.move(to: CGPoint(x: w * k, y: 15))
                    p.addLine(to: CGPoint(x: w, y: 15))
                }
                .stroke(.white.opacity(0.18), style: StrokeStyle(lineWidth: 3, dash: [3, 4]))
                Capsule().fill(LinearGradient(colors: [Color(hex: "FFB27A"), Darkroom.orange], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(3, w * d), height: 3)
                RoundedRectangle(cornerRadius: 1).fill(.white.opacity(0.5)).frame(width: 2, height: 15).offset(x: w * k - 1)
                Circle().fill(Darkroom.orange)
                    .frame(width: 13, height: 13)
                    .background(Circle().fill(Darkroom.orange.opacity(0.22)).padding(-5))
                    .shadow(color: Darkroom.orange, radius: 7)
                    .scaleEffect(dragging ? 1.25 : 1)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: dragging)
                    .offset(x: w * d - 6.5)
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
        .accessibilityLabel(Text("develop.a11y.bar"))
        .accessibilityValue(Text(verbatim: "\(Int((d * 100).rounded()))%"))
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

    /// 進み線を つまむ:soft、5%ごとに tick、いまより さきは warn で とまる
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
