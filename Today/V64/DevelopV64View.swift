import SwiftUI
import SwiftData
import CoreHaptics

// v93-3:現像画面の 作りなおし(フリーズ 対策)。見本 L11 L13 L14 ・ 動き M34。
// ・ぼかした 写真は 1回 だけ 作って キャッシュ(V64Images.blurred)。動かすのは 不透明度 だけ
// ・進み具合 d は 1つの Double を withAnimation 1回で 動かす(Animatable な 部品の 中 だけ が 毎コマ 再描画)
// ・自動 再生は しない(押すまで 待つ)・横に めくったら 止める
// ・バイブは CHHapticEngine の パターンを 1回 作って 1回 再生
// ・ぜんぶ VStack で 上から 並べる(決めうちの offset で 置かない)

struct DevelopV64View: View {
    var count = 3
    var index = 0
    var times: [String] = []
    var now = Date()
    var photos: [UIImage?] = []
    var onShoot: () -> Void = {}
    var onClose: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var d: Double = 0
    @State private var playing = false
    @State private var done = false
    @State private var flash = false
    @State private var pulse = false
    @State private var bump = false
    @State private var blurred: [UIImage?] = []
    @State private var tasks: [Task<Void, Never>] = []
    @State private var haptics = DevelopHaptics()
    @State private var scrollID: Int? = 0
    @State private var shakeX: CGFloat = 0
    @State private var warned = false

    private let lime = HV.lime
    private let milk = Color(hex: "0B0B0C")

    /// k:今の 時間で 決まる 濃さ(9:00 まで の のこりから)
    private var k: Double {
        let cal = Calendar.current
        let open = cal.date(bySettingHour: 9, minute: 0, second: 0, of: cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now) ?? now
        return min(1, max(0, 1 - Double(max(0, Int(open.timeIntervalSince(now)))) / 86400))
    }
    private var remain: Int {
        let cal = Calendar.current
        let open = cal.date(bySettingHour: 9, minute: 0, second: 0, of: cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now) ?? now
        return max(0, Int(open.timeIntervalSince(now)))
    }
    private var shot: Bool { page < times.count }

    var body: some View {
        GeometryReader { g in
            let small = g.size.height < 720
            VStack(spacing: 0) {
                topBar.padding(.top, 52 - g.safeAreaInsets.top + (g.safeAreaInsets.top > 0 ? 0 : 0))
                pager(small: small)
                    .frame(height: small ? 360 : 446).padding(.top, 10)
                dots.padding(.top, 8)
                DevelopFooter(d: d, k: k, playing: playing, done: done, shot: shot, time: times.first ?? "--:--", remain: remain, onTap: tap, onScrub: scrub)
                    .offset(x: shakeX)
                    .padding(.horizontal, 20).padding(.top, 14)
                Spacer(minLength: 0)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .background(milk.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .task { await loadBlurred() }
        .onDisappear { stopAll() }
    }

    // MARK: 上

    private var topBar: some View {
        HStack {
            Button { Haptics.play(.tick); stopAll(); onClose() } label: {
                Image(systemName: "chevron.left").font(.system(size: 17, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44)
                    .background(Color(hex: "17171A"), in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.08), lineWidth: 1))
            }.buttonStyle(.plain).accessibilityLabel("もどる")
            Spacer()
            VStack(spacing: 2) {
                Text("Developing").font(Typo.title(24)).foregroundStyle(.white)
                Text("\(page + 1) / \(count)").font(Typo.label(10)).tracking(2).foregroundStyle(Color(hex: "6E6E75"))
            }
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }.padding(.horizontal, 16).frame(height: 56)
    }

    // MARK: チェキ(横に めくる)

    private func pager(small: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(0..<max(1, count), id: \.self) { i in
                    cheki(i, small: small)
                        .id(i)
                        .scrollTransition(axis: .horizontal) { c, ph in c.scaleEffect(ph.isIdentity ? 1 : 0.9).opacity(ph.isIdentity ? 1 : 0.5) }
                }
            }.scrollTargetLayout().padding(.horizontal, 46)
        }
        .scrollTargetBehavior(.viewAligned).scrollPosition(id: $scrollID).scrollClipDisabled()
        .onChange(of: scrollID) { _, new in
            guard let new, new != page else { return }
            Haptics.play(.sel); stopAll(); page = new; d = 0; done = false
        }
    }

    private func cheki(_ i: Int, small: Bool) -> some View {
        let tilt = [-2.0, 1.6, -1.2][i % 3]
        let scale: CGFloat = small ? 0.8 : 1
        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(hex: "F4F1EA"))
            VStack(spacing: 0) {
                DevelopWindow(d: i == page ? d : 0, blurred: blurred[safe: i] ?? nil, playing: i == page && playing, reduce: reduceMotion, flash: i == page && flash)
                    .frame(width: 274, height: 360).clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous)).padding(.top, 12)
                HStack {
                    Text(times[safe: i] ?? "--:--").font(Typo.label(11)).fontWeight(.bold).foregroundStyle(Color(hex: "E0481A")).shadow(color: Color(hex: "E0481A").opacity(0.5), radius: 3)
                    Spacer()
                    HStack(spacing: 4) { Image(systemName: "lock.fill").font(.system(size: 10)); Text("9:00").font(.custom("Caveat-Bold", size: 19)) }.foregroundStyle(Color(hex: "3A362F"))
                    Spacer()
                    Text("PHOTO").font(Typo.label(9)).tracking(1.8).foregroundStyle(Color(hex: "8A857B"))
                }.padding(.horizontal, 16).frame(maxHeight: .infinity)
            }
        }
        .frame(width: 298, height: 430)
        .shadow(color: .black.opacity(0.95), radius: 30, y: 28)
        .scaleEffect(scale * (i == page ? (bump ? 1.035 : (pulse ? 1.012 : 1)) : 1))
        .rotationEffect(.degrees(tilt))
        .frame(width: 298 * scale, height: 446 * scale)
    }

    private var dots: some View {
        HStack(spacing: 7) { ForEach(0..<max(1, count), id: \.self) { i in Capsule().fill(i == page ? lime : .white.opacity(0.22)).frame(width: i == page ? 22 : 7, height: 7) } }
            .animation(.easeOut(duration: 0.25), value: page)
    }

    // MARK: 現像

    private func tap() {
        guard shot else { Haptics.play(.click); stopAll(); onClose(); onShoot(); return }
        if playing { Haptics.play(.warn); return }
        let target = k
        guard target > 0.005 else { Haptics.play(.warn); return }
        Haptics.play(.click)
        done = false; d = 0; playing = true
        let T = 1.7 + 2.3 * target
        if !reduceMotion { haptics.play(duration: T) }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.6) : .easeInOut(duration: T), completionCriteria: .logicallyComplete) { d = target } completion: { finish() }
        guard !reduceMotion else { return }
        // 10% ごとに チェキが ポン
        let bez = OPBez(0.42, 0, 0.58, 1)
        for n in 1...max(1, Int(target * 10)) where Double(n) / 10 < target {
            var lo = 0.0, hi = 1.0
            for _ in 0..<24 { let mid = (lo + hi) / 2; if bez.at(mid) * target < Double(n) / 10 { lo = mid } else { hi = mid } }
            let t = Task { try? await Task.sleep(for: .seconds(hi * T)); if Task.isCancelled { return }; await MainActor.run { withAnimation(.easeOut(duration: 0.11)) { pulse = true }; withAnimation(.easeOut(duration: 0.22).delay(0.11)) { pulse = false } } }
            tasks.append(t)
        }
    }

    /// バーの つまみを 指で 動かす(k より 右へは 行けない:warn + 小さく ゆれる)
    private func scrub(_ r: Double) {
        guard shot, !playing else { return }
        let t = k
        var tr = Transaction(); tr.animation = nil
        if r > t {
            if !warned {
                warned = true; Haptics.play(.warn)
                tasks.append(Task { for x: CGFloat in [-6, 6, -4, 4, 0] { await MainActor.run { withAnimation(.easeOut(duration: 0.05)) { shakeX = x } }; try? await Task.sleep(for: .milliseconds(55)) } })
            }
            withTransaction(tr) { d = t }
        } else {
            warned = false
            withTransaction(tr) { d = max(0, r) }
        }
        done = false
    }

    private func finish() {
        guard playing else { return }
        playing = false; done = true
        haptics.stop()
        Haptics.play(.heart)
        tasks.append(Task { try? await Task.sleep(for: .seconds(0.16)); if !Task.isCancelled { await MainActor.run { Haptics.play(.success) } } })
        guard !reduceMotion else { return }
        withAnimation(.timingCurve(0.3, 1.5, 0.5, 1, duration: 0.24)) { bump = true }
        withAnimation(.timingCurve(0.3, 1.5, 0.5, 1, duration: 0.24).delay(0.24)) { bump = false }
        withAnimation(.easeOut(duration: 0.12)) { flash = true }
        withAnimation(.easeOut(duration: 0.62).delay(0.12)) { flash = false }
    }

    private func stopAll() {
        tasks.forEach { $0.cancel() }; tasks = []
        haptics.stop()
        playing = false; pulse = false; bump = false; flash = false
        withTransaction(Transaction(animation: nil)) { d = d }
    }

    // ぼかした 写真(1回 だけ ・ main の 外)
    private func loadBlurred() async {
        if !photos.isEmpty { blurred = photos.enumerated().map { i, p in p.map { V64Images.blurred(key: "dv\(i)", source: $0, maxPixel: 64, radius: 14, saturation: 1.1) } }; return }
        let start = Calendar.current.startOfDay(for: now)
        var fd = FetchDescriptor<LaterPhoto>(predicate: #Predicate { $0.captureDate >= start }, sortBy: [SortDescriptor(\.captureDate)])
        fd.fetchLimit = 30
        let items = (try? context.fetch(fd)) ?? []
        var seen = Set<Int>(), datas: [(Int, Data)] = []
        for p in items { let s = Int(p.captureDate.timeIntervalSinceReferenceDate); if seen.insert(s).inserted { datas.append((s, p.imageData)) } }
        let out: [UIImage?] = await Task.detached(priority: .utility) {
            datas.prefix(max(1, count)).map { s, data in
                guard let small = V64Images.image(key: "dvsrc\(s)", data: data, maxPixel: 96) else { return nil }
                return V64Images.blurred(key: "dv\(s)", source: small, maxPixel: 64, radius: 14, saturation: 1.1)
            }
        }.value
        blurred = out
    }
}

// MARK: - 写真の 窓(d だけ で 決まる 層 ・ Animatable)

struct DevelopWindow: View, Animatable {
    var d: Double
    var blurred: UIImage?
    var playing: Bool
    var reduce: Bool
    var flash: Bool
    var animatableData: Double { get { d } set { d = newValue } }

    private static let grain: UIImage = {
        let size = CGSize(width: 120, height: 120)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            var seed: UInt64 = 0xA24BAED4963EE407
            func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double((seed >> 33) & 0xFFFF) / 65535 }
            for _ in 0..<900 { UIColor.black.withAlphaComponent(rnd() * 0.7).setFill(); ctx.cgContext.fill(CGRect(x: rnd() * 120, y: rnd() * 120, width: 1.2, height: 1.2)) }
        }
    }()

    var body: some View {
        let v = pow(max(0, min(1, d)), 0.35)
        ZStack {
            Color(hex: "E4E8DF")
            if let blurred { Image(uiImage: blurred).resizable().scaledToFill().scaleEffect(1.12).opacity(0.08 + 0.92 * v) }
            LinearGradient(colors: [Color(hex: "5E8F86"), Color(hex: "2E4F57")], startPoint: .top, endPoint: .bottom).blendMode(.multiply).opacity(sin(.pi * min(1, 1.2 * v)) * 0.55)
            LinearGradient(colors: [.clear, Color(hex: "E8A55A")], startPoint: .top, endPoint: .bottom).blendMode(.softLight).opacity(0.7 * v)
            LinearGradient(colors: [Color(hex: "F1F3EC"), Color(hex: "DCE3DA"), Color(hex: "E6E9E1")], startPoint: .top, endPoint: .bottom).opacity(1 - 0.84 * v)
            Image(uiImage: Self.grain).resizable(resizingMode: .tile).blendMode(.multiply).opacity(0.22)
            if playing && !reduce {
                TimelineView(.animation) { ctx in
                    let u = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.15) / 1.15
                    GeometryReader { g in
                        LinearGradient(colors: [.clear, HV.lime.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom).frame(height: g.size.height * 0.6).offset(y: -g.size.height * 0.6 + g.size.height * 1.6 * u)
                    }
                }.allowsHitTesting(false)
            }
            if flash { HV.lime.opacity(0.55).blendMode(.overlay) }
        }.drawingGroup(opaque: true)
    }
}

// MARK: - 下の かたまり(% ・ バー ・ ボタン)

struct DevelopFooter: View, Animatable {
    var d: Double
    var k: Double
    var playing: Bool
    var done: Bool
    var shot: Bool
    var time: String
    var remain: Int
    var onTap: () -> Void
    var onScrub: (Double) -> Void = { _ in }
    var animatableData: Double { get { d } set { d = newValue } }
    private let lime = HV.lime

    var body: some View {
        let pct = Int((d * 100).rounded())
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                (Text("\(pct)").font(Typo.title(46, italic: true)) + Text("%").font(Typo.title(22, italic: true)).foregroundColor(Color(hex: "6E6E75"))).foregroundStyle(.white).monospacedDigit()
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    Circle().fill(lime).frame(width: 5, height: 5)
                    Text(playing ? "DEVELOPING" : (done ? "NOW" : (d > 0.001 ? "REPLAY" : "TAP TO DEVELOP"))).font(Typo.label(9.5)).tracking(1.7).foregroundStyle(lime).lineLimit(1).minimumScaleFactor(0.7)
                }.padding(.horizontal, 10).frame(height: 26).background(lime.opacity(0.10), in: Capsule())
            }
            bar.padding(.top, 8)
            HStack {
                Text("\(time) SHOT").font(Typo.label(9)).tracking(1.6).foregroundStyle(Color(hex: "5D5D63"))
                Spacer()
                Text("9:00 OPENS").font(Typo.label(9)).tracking(1.6).foregroundStyle(lime)
            }.padding(.top, 4)
            button.padding(.top, 16)
            Text("OPENS IN \(remain / 3600)H \((remain % 3600) / 60)M").font(Typo.label(9.5)).tracking(1.4).foregroundStyle(Color(hex: "5D5D63")).frame(maxWidth: .infinity).padding(.top, 12)
        }
    }

    private var bar: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: "1C1C1F")).frame(height: 4)
                Capsule().strokeBorder(.white.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(width: max(0, w * (1 - k)), height: 4).frame(width: w, alignment: .trailing)
                Capsule().fill(LinearGradient(colors: [lime.opacity(0.25), lime], startPoint: .leading, endPoint: .trailing)).frame(width: max(4, w * k), height: 4).shadow(color: lime.opacity(0.4), radius: 5)
                Rectangle().fill(lime.opacity(0.7)).frame(width: 2, height: 16).offset(x: w * k - 1)
                Circle().fill(lime).frame(width: 16, height: 16).overlay(Circle().strokeBorder(lime.opacity(0.16), lineWidth: 5)).shadow(color: lime.opacity(0.6), radius: 6).offset(x: w * min(d, k) - 8)
            }.frame(height: 20).contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in onScrub(max(0, min(1, v.location.x / max(1, w)))) })
        }.frame(height: 20)
    }

    private var button: some View {
        Button(action: onTap) {
            ZStack {
                if playing {
                    GeometryReader { g in
                        Capsule().fill(lime).frame(width: g.size.width * (k > 0 ? min(1, d / k) : 0)).overlay(alignment: .trailing) { Rectangle().fill(.white.opacity(0.6)).frame(width: 3).blur(radius: 2) }.clipShape(Capsule())
                    }
                }
                HStack(spacing: 8) {
                    if !done { Image(systemName: shot ? "play.fill" : "camera.fill").font(.system(size: 14)) }
                    VStack(spacing: 1) {
                        Text(!shot ? "撮る" : (playing ? "現像中" : (done ? "もう一度 見る" : "現像する"))).font(Typo.ui(800, 19))
                        if shot && !playing && !done { Text("\(Int(k * 100))% まで").font(Typo.label(9.5)).opacity(0.55) }
                        if playing { Text("\(Int((d * 100).rounded()))%").font(Typo.label(9.5)).monospacedDigit().opacity(0.7) }
                    }
                }.foregroundStyle(playing ? lime : (done ? .white : HV.ink)).blendMode(.normal)
            }
            .frame(maxWidth: .infinity).frame(height: 58)
            .background(playing ? Color(hex: "141416") : (done ? Color(hex: "1A1A1D") : lime), in: Capsule())
            .overlay(Capsule().strokeBorder(playing ? lime.opacity(0.35) : (done ? .white.opacity(0.1) : .clear), lineWidth: 1))
            .clipShape(Capsule())
        }.buttonStyle(HVPress(scale: 0.96))
    }
}

// MARK: - バイブ(パターンを 1つ 作って 1回 再生。だんだん 細かく 強く)

final class DevelopHaptics {
    private var engine: CHHapticEngine?
    private var player: CHHapticAdvancedPatternPlayer?
    private var fallback: UIImpactFeedbackGenerator?

    func play(duration T: Double) {
        stop()
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            let g = UIImpactFeedbackGenerator(style: .light); g.prepare(); g.impactOccurred(); fallback = g; return
        }
        do {
            let e = try CHHapticEngine()
            try e.start()
            var events: [CHHapticEvent] = [CHHapticEvent(eventType: .hapticContinuous, parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.75), CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)], relativeTime: 0, duration: T)]
            var t = 0.0
            while t < T {
                let u = t / T
                let gap = 0.23 - (0.23 - 0.06) * u
                events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(0.35 + 0.45 * u)), CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(0.3 + 0.4 * u))], relativeTime: t))
                t += gap
            }
            let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [.init(relativeTime: 0, value: 0.2), .init(relativeTime: T, value: 1.0)], relativeTime: 0)
            let sharp = CHHapticParameterCurve(parameterID: .hapticSharpnessControl, controlPoints: [.init(relativeTime: 0, value: 0.5), .init(relativeTime: T, value: 1.0)], relativeTime: 0)
            let pattern = try CHHapticPattern(events: events, parameterCurves: [curve, sharp])
            let p = try e.makeAdvancedPlayer(with: pattern)
            try p.start(atTime: CHHapticTimeImmediate)
            engine = e; player = p
        } catch {
            let g = UIImpactFeedbackGenerator(style: .light); g.prepare(); g.impactOccurred(); fallback = g
        }
    }

    func stop() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        engine?.stop(completionHandler: nil)
        player = nil; engine = nil
    }
}
