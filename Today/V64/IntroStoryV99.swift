import SwiftUI

// v99 / P42:はじめて ひらいた 時の 説明(Friends ・ Trip)。ストーリーの 形 ・ 4場面 × 3.6秒 ・ 文字は 1行だけ。
// 進み具合と 自動送りは 1つの TimelineView の 時間から 計算(場面ごとの タイマーは 作らない)。一時停止 = その 時計を 止める だけ。
// 場面の 動きは `IntroScenesV99.swift`(時間 t の 関数)。

enum IntroKind: String, CaseIterable, Identifiable {
    case friends, trip
    var id: String { rawValue }
    var seenKey: String { "introSeen.\(rawValue)" }
    var name: String { ["friends": "Friends", "trip": "Trip"][rawValue] ?? "" }
    var icon: HVIconKind { [IntroKind.friends: HVIconKind.friends, .trip: .trip][self] ?? .friends }

    struct Scene {
        let label: String
        let line: String
        var night = false
        let haptics: [(Double, Haptics.Kind)]
    }

    var scenes: [Scene] {
        switch self {
        case .friends: return [
            .init(label: "SHOOT", line: "友だちも、1日 3枚", haptics: [(0.55, .tick), (1.05, .tick), (1.55, .tick), (2.05, .tick), (2.3, .shutter)]),
            .init(label: "SLEEP", line: "夜は、ひみつ", night: true, haptics: [(0.3, .soft), (1.35, .click), (1.5, .click), (1.65, .click)]),
            .init(label: "OPEN", line: "9:00 に、みんなで ひらく", haptics: [(0.7, .success), (1.3, .pop), (1.5, .pop), (1.7, .pop), (2.4, .heart)]),
            .init(label: "CONNECT", line: "@ID で つながる", haptics: [(0.2, .tick), (0.35, .tick), (0.5, .tick), (0.65, .tick), (0.8, .tick), (0.95, .tick), (1.15, .pop), (2.0, .click), (2.7, .success)]),
        ]
        case .trip: return [
            .init(label: "PRINT", line: "旅の パスを つくる", haptics: [(0, .projector), (0.22, .tick), (0.43, .tick), (0.65, .tick), (0.87, .tick), (1.08, .tick), (1.3, .tick), (2.15, .thud), (2.5, .success)]),
            .init(label: "BOARD", line: "リンクで、なかまを のせる", haptics: [(0.15, .pop), (1.0, .pop), (1.34, .pop), (1.68, .pop), (2.02, .pop), (2.36, .pop), (2.6, .success)]),
            .init(label: "SHARE", line: "1日 23枚を、みんなで", haptics: [(0.9, .tick), (1.3, .tick), (1.7, .tick), (2.1, .tick), (2.5, .tick), (2.9, .tick)]),
            .init(label: "DEVELOP", line: "あした 9:00 に、まとめて 現像", haptics: [(0.2, .soft), (1.0, .land), (2.45, .thud), (2.6, .success)]),
        ]
        }
    }
}

/// 見た 記録(出した 時点で true)・ 出す きっかけ
enum IntroStore {
    static let requested = Notification.Name("introRequested")
    static let goCameraPage = Notification.Name("introGoCameraPage")
    static let dismissedOnce = "introHintShown"

    static func seen(_ k: IntroKind) -> Bool { UserDefaults.standard.bool(forKey: k.seenKey) }
    static func markSeen(_ k: IntroKind) { UserDefaults.standard.set(true, forKey: k.seenKey) }
    /// アカウントを 消した ・ 「説明 リセット」
    static func resetAll() { for k in IntroKind.allCases { UserDefaults.standard.removeObject(forKey: k.seenKey) }; UserDefaults.standard.removeObject(forKey: dismissedOnce) }
}

struct IntroRequest: Identifiable {
    let id = UUID()
    let kind: IntroKind
    /// 先に 説明を 見せた 入口の 続き(スキップ でも 最後の ボタン でも もとの 画面へ)
    var then: (() -> Void)? = nil
}

struct IntroStoryView: View {
    let kind: IntroKind
    var shotToday = false
    /// DEBUG:見本どり(秒)
    var startAt = 0.0
    /// finished = 最後の ボタンを 押した
    let onClose: (_ pressedAction: Bool) -> Void

    private static let titleDur = 0.9, sceneDur = 3.6
    private var total: Double { Self.titleDur + Self.sceneDur * 4 }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var accum = 0.0
    @State private var runStart: Date? = Date()
    @State private var paused = false
    @State private var holdTask: Task<Void, Never>?
    @State private var heldPause = false
    @State private var lastIdx = -1
    @State private var prevT = -1.0
    @State private var closing = false

    private func elapsed(_ now: Date) -> Double {
        min(total, accum + (runStart.map { now.timeIntervalSince($0) } ?? 0))
    }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / 390, geo.size.height / 844)
            TimelineView(.animation(paused: paused)) { ctx in
                let e = elapsed(ctx.date)
                stage(e)
                    .frame(width: 390, height: 844)
                    .scaleEffect(s)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .onChange(of: ctx.date) { _, now in tick(elapsed(now)) }
            }
            .background(Color(hex: "0B0B0C"))
            .overlay { gestureLayer(width: geo.size.width) }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear { IntroStore.markSeen(kind); accum = startAt; runStart = Date() }
        .onDisappear { holdTask?.cancel() }
        .accessibilityAction(named: "つぎへ") { go(by: 1) }
        .accessibilityAction(named: "スキップ") { close(false) }
    }

    // MARK: 時計

    private func index(_ e: Double) -> Int { e < Self.titleDur ? 0 : min(3, Int((e - Self.titleDur) / Self.sceneDur)) }
    private func sceneT(_ e: Double) -> Double { e - Self.titleDur - Double(index(e)) * Self.sceneDur }

    private func tick(_ e: Double) {
        let i = index(e), t = sceneT(e)
        if i != lastIdx { lastIdx = i; prevT = -0.001 }
        guard !reduceMotion || true else { return }
        for (time, kind) in kind.scenes[i].haptics where time > prevT && time <= t { Haptics.play(kind) }
        prevT = t
        if voiceOver, t < 0.05 { UIAccessibility.post(notification: .announcement, argument: "\(kind.scenes[i].label)。\(kind.scenes[i].line)") }
    }

    private func jump(to i: Int) {
        let target = Self.titleDur + Self.sceneDur * Double(i) + 0.0001
        accum = target
        runStart = paused ? nil : Date()
        lastIdx = -1
    }

    private func go(by d: Int) {
        let now = Date()
        let i = index(elapsed(now))
        Haptics.play(.sel)
        if d > 0 && i >= 3 { return }
        jump(to: max(0, min(3, i + d)))
    }

    private func setPaused(_ p: Bool) {
        guard p != paused else { return }
        let now = Date()
        if p { accum = elapsed(now); runStart = nil } else { runStart = now }
        paused = p
    }

    private func close(_ action: Bool) {
        guard !closing else { return }
        closing = true
        Haptics.play(action ? .pop : .soft)
        onClose(action)
    }

    // MARK: さわり方

    private func gestureLayer(width: CGFloat) -> some View {
        Color.clear.contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard holdTask == nil else { return }
                        holdTask = Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(240))
                            guard !Task.isCancelled else { return }
                            heldPause = true; setPaused(true)
                        }
                    }
                    .onEnded { v in
                        holdTask?.cancel(); holdTask = nil
                        if heldPause { heldPause = false; setPaused(false); return }
                        if v.translation.height > 80 { close(false); return }
                        if abs(v.translation.width) > 20 || abs(v.translation.height) > 20 { return }
                        go(by: v.location.x < width * 0.32 ? -1 : 1)
                    }
            )
            .padding(.top, 110).padding(.bottom, 120)   // ボタンの 上は さわらない
            .accessibilityHidden(true)
    }

    // MARK: 画面(390 × 844 の 座標)

    @ViewBuilder private func stage(_ e: Double) -> some View {
        let i = index(e)
        let sc = kind.scenes[i]
        let t = reduceMotion ? Self.sceneDur : max(0, sceneT(e))
        let intro = e < Self.titleDur && !reduceMotion
        ZStack(alignment: .topLeading) {
            Color(hex: "0B0B0C")
            Ellipse().fill(RadialGradient(colors: [Color(hex: "C8F25A").opacity(sc.night ? 0.035 : 0.14), .clear], center: .center, startRadius: 0, endRadius: 190))
                .frame(width: 351, height: 388).position(x: 195, y: 340)
            progress(e, i)
            topRow(i, shownName: !intro)
            IntroSceneView(kind: kind, index: i, t: t, reduce: reduceMotion)
                .frame(width: 390, height: 440).clipped().offset(y: 122)
                .opacity(intro ? 0 : 1)
            lineBlock(sc, t: t)
                .opacity(intro ? 0 : 1)
            bottom(e, i, t)
            if intro { titleFly(e) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.name) の 説明。\(sc.label)。\(sc.line)")
    }

    private func progress(_ e: Double, _ i: Int) -> some View {
        let w = (390.0 - 40 - 15) / 4
        return HStack(spacing: 5) {
            ForEach(0..<4, id: \.self) { n in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    Capsule().fill(Color(hex: "C8F25A")).frame(width: w * (n < i ? 1 : n == i ? max(0, min(1, sceneT(e) / Self.sceneDur)) : 0))
                }.frame(width: w, height: 3)
            }
        }.offset(x: 20, y: 54)
    }

    private func topRow(_ i: Int, shownName: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack { Circle().fill(Color(hex: "C8F25A")); HVIcon(kind: kind.icon, size: 16, color: .black) }.frame(width: 28, height: 28)
            Text(kind.name).font(LF.serif(25, italic: true)).foregroundStyle(.white).opacity(shownName ? 1 : 0)
            Spacer()
            Button { close(false) } label: {
                Text(i == 3 ? "とじる" : "スキップ ⇥").font(LF.inter(800, 12.5)).foregroundStyle(.white)
                    .padding(.horizontal, 14).frame(height: 32).background(Capsule().fill(.white.opacity(0.1)))
                    .frame(minWidth: 44, minHeight: 44)
            }.buttonStyle(.plain).accessibilityLabel(i == 3 ? "とじる" : "スキップ")
        }
        .frame(width: 350).offset(x: 20, y: 70)
    }

    private func lineBlock(_ sc: IntroKind.Scene, t: Double) -> some View {
        let p = reduceMotion ? 1 : IntroMath.ease(t, 0.15, 0.45)
        return VStack(spacing: 10) {
            Text(sc.label).font(LF.mono(10)).tracking(3).foregroundStyle(Color(hex: "C8F25A"))
            Text(sc.line).font(LF.inter(900, 27)).lineSpacing(27 * 0.28 - 4).multilineTextAlignment(.center).foregroundStyle(.white)
                .lineLimit(2).minimumScaleFactor(0.7).frame(width: 340)
        }
        .frame(width: 390).offset(y: 580 + CGFloat(1 - p) * 16).opacity(p)
    }

    private func bottom(_ e: Double, _ i: Int, _ t: Double) -> some View {
        Group {
            if i < 3 {
                tapHint(e).frame(width: 390).offset(y: 760)
            } else {
                VStack(spacing: 6) {
                    Button { close(true) } label: {
                        Text(actionTitle).font(LF.inter(900, 16.5)).foregroundStyle(Color(hex: "111111"))
                            .frame(maxWidth: .infinity).frame(height: 58).background(Capsule().fill(Color(hex: "C8F25A")))
                    }.buttonStyle(HVPress(scale: 0.97))
                    Button { Haptics.play(.sel); jump(to: 0); accum = 0.0; runStart = paused ? nil : Date() } label: {
                        Text("↺ もう一度").font(LF.inter(700, 12.5)).foregroundStyle(.white.opacity(0.6)).frame(minHeight: 44)
                    }.buttonStyle(.plain).opacity(t > 1.2 || reduceMotion ? 1 : 0)
                }.frame(width: 350).offset(x: 20, y: 700)
            }
        }
    }

    private var actionTitle: String {
        switch kind {
        case .friends: return "友だちを さがす"
        case .trip: return "Trip を つくる"
        }
    }

    /// タップの 合図(白い 点 12 + 広がる 輪 2つ)
    private func tapHint(_ e: Double) -> some View {
        ZStack {
            ForEach(0..<2, id: \.self) { n in
                let u = (e * 0.8 + Double(n) * 0.5).truncatingRemainder(dividingBy: 1)
                Circle().stroke(.white.opacity(0.5 * (1 - u)), lineWidth: 1.5).frame(width: 12, height: 12).scaleEffect(reduceMotion ? 1 : 1 + 2.6 * u)
            }
            Circle().fill(.white.opacity(0.85)).frame(width: 12, height: 12)
        }.frame(height: 44)
    }

    private func titleFly(_ e: Double) -> some View {
        let p = e / Self.titleDur
        let fly = IntroMath.clamp((p - 0.55) / 0.45)
        let ef = 1 - pow(1 - fly, 3)
        let sc = 96.0 + (25.0 - 96.0) * ef
        return Text(kind.name).font(LF.serif(96, italic: true)).foregroundStyle(Color(hex: "C8F25A"))
            .scaleEffect(sc / 96).fixedSize()
            .opacity(IntroMath.clamp(p / 0.25))
            .position(x: 195 + (20 + 38 + 40 - 195) * ef, y: 400 + (84 - 400) * ef)
    }
}

enum IntroMath {
    static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
    /// a 秒から d 秒かけて 0 → 1(easeOut)
    static func ease(_ t: Double, _ a: Double, _ d: Double = 0.4) -> Double { 1 - pow(1 - clamp((t - a) / d), 3) }
    /// 少し 行きすぎて 戻る(ポン)
    static func pop(_ t: Double, _ a: Double, _ d: Double = 0.45) -> Double {
        let x = clamp((t - a) / d); let c1 = 1.70158, c3 = c1 + 1
        return x <= 0 ? 0 : 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }
    static func lerp(_ a: Double, _ b: Double, _ p: Double) -> Double { a + (b - a) * p }
}
