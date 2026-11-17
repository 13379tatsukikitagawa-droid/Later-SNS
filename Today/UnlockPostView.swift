import SwiftUI
import UIKit

/// v34「現像の瞬間」(翌日、撮ったあとにきのうの1枚がひらく)。見本:later_v34.html の「現像(チェキ)」「現像(レアフィルム)」。
/// テーマは暗室:赤いセーフライトの部屋でチェキが排出口から出てきて、ふって(こすって)現像する。
/// 色が出るほど部屋の光も赤→あたたかい色へ。解禁の決まり・投稿する/しないの処理は今のまま
/// (Outcome・onDecide・onFinished の呼び方は変えない)。変えるのは画面・アニメーション・バイブだけ。
/// 閉じる・戻る操作は置かない(選ばないと進めない。アプリを閉じるのは自由)。
struct UnlockPostView: View {
    enum Outcome { case posted, skipped }

    /// 昨日の自分の1枚(9:00以降にしか、この画面は出ない)
    let image: UIImage?
    let capturedAt: Date
    /// 共有先(MEを除くグループ)
    let groups: [ProfileShareGroup]
    /// アカウントの「Mondo に出す」がオンか
    let showsMondo: Bool
    /// 昨日ぜんぶで何こま(「YESTERDAY · 1 / 3」の表示だけ。決めるのは今まで通りまとめて)
    let totalCount: Int
    /// タグの1つめ(右上のステッカー)
    let tag: String?
    /// falseなら現像のアニメーションをせず、ひらいたところから始める
    let playsUnlock: Bool
    let haptics: ExposureHaptics
    /// 選んだ瞬間に呼ぶ(データの処理)
    let onDecide: (Outcome) -> Void
    /// 結果を見せ終えた。Homeへもどす
    let onFinished: (Outcome) -> Void
    private let frozenProgress: Double?

    init(
        image: UIImage?,
        capturedAt: Date,
        groups: [ProfileShareGroup],
        showsMondo: Bool,
        totalCount: Int = 1,
        tag: String? = nil,
        playsUnlock: Bool,
        haptics: ExposureHaptics,
        onDecide: @escaping (Outcome) -> Void,
        onFinished: @escaping (Outcome) -> Void,
        frozenProgress: Double? = nil
    ) {
        self.image = image
        self.capturedAt = capturedAt
        self.groups = groups
        self.showsMondo = showsMondo
        self.totalCount = totalCount
        self.tag = tag
        self.playsUnlock = playsUnlock
        self.haptics = haptics
        self.onDecide = onDecide
        self.onFinished = onFinished
        self.frozenProgress = frozenProgress
        let initial: Phase = frozenProgress != nil ? .developing : (playsUnlock ? .intro : .opened)
        _phase = State(initialValue: initial)
        _developProgress = State(initialValue: frozenProgress ?? (initial == .opened ? 1 : 0))
        _clockLit = State(initialValue: initial == .opened)
        _stickerShown = State(initialValue: initial == .opened)
        _rareStampShown = State(initialValue: initial == .opened && Self.rareFilm(for: capturedAt))
        _buttonsShown = State(initialValue: initial == .opened)
    }

    private enum Phase { case intro, developing, opened }

    private enum Layout {
        static let print = DevelopSheet.Layout.print
        static let window = DevelopSheet.Layout.window
        static let windowOrigin = DevelopSheet.Layout.windowOrigin
        static let slotWidth: CGFloat = 196
    }

    /// 実機で調整する前提の初期値
    private enum Timing {
        static let slotAt: TimeInterval = 0.25
        static let ejectStart: TimeInterval = 0.6
        static let ejectEnd: TimeInterval = 2.0
        static let developDuration: TimeInterval = 6.4
        static let reducedDevelopDuration: TimeInterval = 1.5
        /// 向きが変わるたびに足す加速(レート倍率)。すぐ減衰する(時定数)
        static let shakeBoost: Double = 2.6
        static let shakeDecay: TimeInterval = 0.09
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AccessibilityFocusState private var isButtonFocused: Bool

    @State private var phase: Phase
    @State private var start = Date()
    @State private var developProgress: Double
    @State private var virtualElapsed: Double = 0
    @State private var rateBoost: Double = 0
    @State private var dragX: CGFloat = 0
    @State private var lastDragX: CGFloat = 0
    @State private var dragDirection: Int = 0
    @State private var hasShaken = false
    @State private var clockLit: Bool
    @State private var stickerShown: Bool
    @State private var rareStampShown: Bool
    @State private var buttonsShown: Bool
    @State private var wobbleTrigger = 0
    @State private var shineProgress: CGFloat = -1
    @State private var scheduled: [DispatchWorkItem] = []
    @State private var developTask: Task<Void, Never>?

    private var developDuration: TimeInterval { reduceMotion ? Timing.reducedDevelopDuration : Timing.developDuration }
    private var isOpen: Bool { phase == .opened }

    /// 7回に1回くらい(写真の撮影時刻から決める。同じ1枚はいつも同じ結果)
    private var isRareFilm: Bool { Self.rareFilm(for: capturedAt) }

    private static func rareFilm(for date: Date) -> Bool {
        let seed = Int(date.timeIntervalSince1970.rounded())
        return ((seed &* 2_654_435_761) & 0x7FFF_FFFF) % 7 == 0
    }

    private var headline: String {
        guard isOpen else { return "Developing" }
        return isRareFilm ? "Rare film" : "Opened"
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                room
                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 8)
                    cheki
                    Spacer(minLength: 8)
                    bottomArea
                        .padding(.horizontal, 26)
                        .padding(.bottom, max(22, proxy.safeAreaInsets.bottom + 14))
                }
                .padding(.top, proxy.safeAreaInsets.top + 14)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .onAppear(perform: begin)
        .onDisappear {
            scheduled.forEach { $0.cancel() }
            developTask?.cancel()
        }
    }

    // MARK: - 暗室の 部屋(赤いセーフライト → あたたかい色)

    private var room: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [Color(hex: "4A0E0A").opacity(0.5 * (1 - developProgress) + 0.07), .clear],
                center: UnitPoint(x: 0.5, y: 0.4), startRadius: 10, endRadius: 420
            )
            RadialGradient(
                colors: [Color(hex: "7A3A12").opacity(0.4 * developProgress), .clear],
                center: UnitPoint(x: 0.5, y: 0.44), startRadius: 10, endRadius: 440
            )
            GrainView(seed: 11).opacity(0.045).blendMode(.overlay)
        }
        .allowsHitTesting(false)
    }

    // MARK: - 上(YESTERDAY · 1/3・見出し・区切り線)

    private var header: some View {
        VStack(spacing: 8) {
            Text(verbatim: "YESTERDAY · 1 / \(max(1, totalCount))")
                .font(.system(size: 10.5, design: .monospaced))
                .tracking(0.22 * 10.5)
                .foregroundStyle(isOpen ? Darkroom.orange : Color(hex: "8E8E93"))
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
            Text(verbatim: headline)
                .font(Darkroom.title(headline, size: 32))
                .foregroundStyle(.white)
                .id(headline)
                .transition(.opacity)
            Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
                .padding(.horizontal, 26)
                .padding(.top, 8)
        }
        .animation(.easeOut(duration: 0.3), value: headline)
        .accessibilityElement(children: .combine)
    }

    // MARK: - チェキ(排出口・本体)

    @ViewBuilder
    private var cheki: some View {
        if phase == .intro, !reduceMotion {
            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSince(start)
                chekiBody(travel: Self.ejectTravel(elapsed), slotProgress: Self.smooth(min(1, max(0, (elapsed - Timing.slotAt) / 0.25))))
            }
        } else {
            chekiBody(travel: 1, slotProgress: 1)
        }
    }

    private func chekiBody(travel: Double, slotProgress: Double) -> some View {
        ZStack(alignment: .top) {
            Capsule()
                .fill(Color.black)
                .frame(width: Layout.slotWidth * (0.14 + 0.86 * slotProgress), height: 9)
                .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.8), radius: 6, y: 3)
                .opacity(slotProgress)

            chekiCard
                .padding(.top, 16)
                .mask(alignment: .top) {
                    Rectangle().frame(height: max(2, (Layout.print.height + 60) * travel))
                }
                .offset(y: -26 * (1 - travel))
                .opacity(travel > 0.02 ? 1 : 0)
        }
    }

    private var chekiCard: some View {
        let paper = RoundedRectangle(cornerRadius: 6, style: .continuous)
        let tiltX = min(70, max(-70, dragX))
        return ZStack(alignment: .topLeading) {
            paper.fill(LinearGradient(colors: [Color(hex: "F7F4EE"), Color(hex: "ECE8DF")], startPoint: .top, endPoint: .bottom))

            photoWindow
                .frame(width: Layout.window.width, height: Layout.window.height)
                .clipped()
                .offset(x: Layout.windowOrigin.x, y: Layout.windowOrigin.y)

            if stickerShown, let tag {
                let c = Darkroom.stickerColors(tag)
                Text(verbatim: "#\(tag)")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(c.1)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 12).fill(c.0))
                    .rotationEffect(.degrees(8))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 10).padding(.top, 10)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.2, anchor: .topTrailing).combined(with: .opacity))
            }

            if rareStampShown {
                rareStamp
                    .padding(.leading, 18)
                    .padding(.top, Layout.windowOrigin.y + Layout.window.height - 28)
                    .transition(reduceMotion ? .opacity : .scale(scale: 2.2).combined(with: .opacity))
            }

            caption
                .padding(.horizontal, 17)
                .padding(.bottom, 13)
                .frame(width: Layout.print.width, height: Layout.print.height, alignment: .bottom)
        }
        .frame(width: Layout.print.width, height: Layout.print.height)
        .clipShape(paper)
        .shadow(color: .black.opacity(0.65), radius: 22, y: 22)
        .shadow(color: Darkroom.orange.opacity(0.12 * developProgress), radius: 28)
        .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(tiltX) * 0.1), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .rotationEffect(.degrees(-2.2 + (reduceMotion ? 0 : Double(tiltX) * 0.02)))
        .keyframeAnimator(initialValue: 0.0, trigger: wobbleTrigger) { content, angle in
            content.rotationEffect(.degrees(angle))
        } keyframes: { _ in
            KeyframeTrack { CubicKeyframe(reduceMotion ? 0 : 5, duration: 0.12); SpringKeyframe(0, duration: 0.34) }
        }
        .animation(.easeOut(duration: 0.18), value: dragX)
        .contentShape(paper)
        .gesture(shakeGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAdjustableAction { direction in
            guard phase == .developing, direction == .increment else { return }
            bumpShake()
        }
    }

    // MARK: - 写真(ミルク色の膜・ぼかし・彩度・青緑・あたたかい色)

    private var photoWindow: some View {
        let look = DevelopLook.values(progress: developProgress)
        return ZStack {
            Color(hex: "E9EEEA")
            Color.clear.overlay {
                Group {
                    if let image {
                        ZStack {
                            Image(uiImage: image).resizable().scaledToFill()
                            Image(uiImage: image).resizable().scaledToFill()
                                .opacity(max(0, look.brightness - 1)).blendMode(.plusLighter)
                        }
                        .compositingGroup()
                    } else {
                        Color(hex: "B9B3A8")
                    }
                }
                .saturation(look.saturation)
                .contrast(0.9)
                .blur(radius: look.blur)
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
            if isRareFilm { lightLeak }
            if !reduceMotion { shineSweep }
        }
        .clipped()
    }

    /// レアフィルム:45%をすぎたら、左からオレンジ・右下からピンクの光もれ
    private var lightLeak: some View {
        let leak = max(0, min(1, (developProgress - 0.45) / 0.55))
        return ZStack {
            LinearGradient(colors: [Color(hex: "FF8A3D").opacity(0.55 * leak), .clear], startPoint: .leading, endPoint: .trailing)
                .blendMode(.screen)
            RadialGradient(colors: [Color(hex: "FF5FA8").opacity(0.5 * leak), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 220)
                .blendMode(.screen)
        }
        .allowsHitTesting(false)
    }

    /// つや:100%になった瞬間、光のすじが一度だけ横切る
    private var shineSweep: some View {
        GeometryReader { proxy in
            LinearGradient(stops: [
                .init(color: .white.opacity(0), location: 0.3),
                .init(color: .white.opacity(0.55), location: 0.5),
                .init(color: .white.opacity(0), location: 0.7),
            ], startPoint: .top, endPoint: .bottom)
            .frame(width: proxy.size.width * 0.55)
            .rotationEffect(.degrees(18))
            .offset(x: shineProgress * proxy.size.width * 1.3)
        }
        .allowsHitTesting(false)
    }

    private var rareStamp: some View {
        Text(verbatim: "RARE")
            .font(.system(size: 13, weight: .black, design: .monospaced))
            .tracking(2)
            .foregroundStyle(Color(hex: "FF3B30"))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex: "FF3B30"), lineWidth: 2))
            .rotationEffect(.degrees(-14))
            .opacity(0.92)
    }

    /// チェキの白い部分:日付スタンプ・7セグふうの時刻(ひらく前は 88:88)
    private var caption: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(verbatim: Self.filmDate(capturedAt))
                .font(.system(size: 9, design: .monospaced))
                .tracking(0.14 * 9)
                .foregroundStyle(Color(hex: "A09C91"))
            Spacer(minLength: 8)
            Text(verbatim: clockLit ? Darkroom.time(capturedAt) : "88:88")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(clockLit ? Darkroom.stamp : Color(hex: "C7C2B6"))
                .opacity(clockLit ? 1 : 0.5)
                .shadow(color: clockLit ? Darkroom.stamp.opacity(0.55) : .clear, radius: 4)
                .scaleEffect(clockLit ? 1 : 0.94)
        }
    }

    // MARK: - 下(進み線 / ボタン)

    @ViewBuilder
    private var bottomArea: some View {
        if isOpen {
            buttons
                .opacity(buttonsShown ? 1 : 0)
                .offset(y: buttonsShown ? 0 : 20)
        } else {
            progressRow
        }
    }

    private var progressRow: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: hasShaken ? "KEEP SHAKING" : "SHAKE TO DEVELOP")
                    .font(Darkroom.mono(10.5)).tracking(0.18 * 10.5)
                    .foregroundStyle(Darkroom.weak)
                Spacer()
                (Text(verbatim: "\(Int((developProgress * 100).rounded()))").font(.custom("InstrumentSerif-Italic", size: 21))
                 + Text(verbatim: "%").font(.custom("InstrumentSerif-Italic", size: 15)).foregroundColor(Darkroom.weak))
                    .foregroundStyle(.white)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1)).frame(height: 2)
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: "FF3B30"), Darkroom.orange, Color(hex: "FFE3BE")], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(2, proxy.size.width * developProgress), height: 2)
                }
            }
            .frame(height: 2)
        }
        .accessibilityHidden(true)
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            Button(action: post) {
                Text(verbatim: "Post to group")
                    .font(.system(size: 16.5, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(.white))
                    .shadow(color: .white.opacity(0.3), radius: 14)
            }
            .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
            .accessibilityFocused($isButtonFocused)
            .accessibilityLabel(Text("darkroom.post.a11y"))

            Button(action: keepPrivate) {
                Text(verbatim: "Keep it to me")
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(GlassFill(shape: Capsule(), opaque: reduceTransparency, tint: 0.08))
            }
            .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
            .accessibilityLabel(Text("darkroom.keep.a11y"))
        }
    }

    // MARK: - ふる / こする(DragGestureの横方向の向きが変わった回数で加速)

    private var shakeGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard phase == .developing, developProgress < 1 else { return }
                let dx = value.translation.width
                dragX = dx
                let delta = dx - lastDragX
                if abs(delta) > 1.2 {
                    let dir = delta > 0 ? 1 : -1
                    if dragDirection != 0, dir != dragDirection { bumpShake() }
                    dragDirection = dir
                }
                lastDragX = dx
            }
            .onEnded { _ in
                dragDirection = 0
                lastDragX = 0
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { dragX = 0 }
            }
    }

    private func bumpShake() {
        rateBoost = min(6, rateBoost + Timing.shakeBoost)
        hasShaken = true
        Haptics.play(.tick, gap: 0.04)
    }

    // MARK: - 動き

    private func begin() {
        start = Date()
        switch phase {
        case .intro:
            Haptics.play(.soft)
            UIAccessibility.post(notification: .announcement, argument: "きのうの1枚を、現像しています")
            if reduceMotion {
                phase = .developing
                developTask = Task { await runDevelopLoop() }
            } else {
                after(Timing.ejectStart) { Haptics.play(.rattle) }
                after(Timing.ejectEnd) {
                    Haptics.play(.land)
                    phase = .developing
                    developTask = Task { await runDevelopLoop() }
                }
            }
        case .developing:
            break // frozenProgress(見た目の確認用)はそのまま静止
        case .opened:
            isButtonFocused = true
        }
    }

    /// 0 → 1。ふる/こすると(向きが変わるたびに)レートが一時的に上がる
    private func runDevelopLoop() async {
        var last = Date()
        var lastTen = Int(developProgress * 10)
        while !Task.isCancelled {
            let now = Date()
            let dt = min(0.05, now.timeIntervalSince(last))
            last = now
            let rate = 1 + rateBoost
            virtualElapsed += dt * rate
            rateBoost *= exp(-dt / Timing.shakeDecay)
            developProgress = min(1, virtualElapsed / developDuration)
            let ten = Int(developProgress * 10)
            if ten != lastTen, ten > 0 {
                lastTen = ten
                haptics.playTransient(intensity: 0.12, sharpness: 0.25)
            }
            if developProgress >= 1 { break }
            try? await Task.sleep(for: .milliseconds(16))
        }
        guard !Task.isCancelled, phase == .developing else { return }
        openFinishedSequence()
    }

    /// 100%:つや → ぽよん → 見出し「Opened」/「Rare film」→ 時刻 → ステッカー(・RARE)→ ボタン
    private func openFinishedSequence() {
        phase = .opened
        developProgress = 1
        if !reduceMotion {
            wobbleTrigger += 1
            withAnimation(.easeInOut(duration: 0.7)) { shineProgress = 1 }
        }
        Haptics.play(.heart)
        after(0.14) { Haptics.play(.success) }
        UIAccessibility.post(notification: .announcement, argument: isRareFilm ? "レアフィルムです。ひらきました" : "昨日の1枚が、ひらきました")
        after(0.35) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { clockLit = true }
            Haptics.play(.click)
        }
        after(0.5) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { stickerShown = true }
            Haptics.play(.pop)
            if isRareFilm {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) { rareStampShown = true }
                Haptics.play(.thud)
            }
        }
        after(1.0) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { buttonsShown = true }
            isButtonFocused = true
        }
    }

    private func after(_ delay: TimeInterval, _ work: @escaping () -> Void) {
        let item = DispatchWorkItem(block: work)
        scheduled.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func post() {
        guard isOpen else { return }
        haptics.playTransient(intensity: 1.0, sharpness: 0.7)
        onDecide(.posted)
        finish(.posted)
    }

    private func keepPrivate() {
        guard isOpen else { return }
        haptics.playTransient(intensity: 0.3, sharpness: 0.35)
        onDecide(.skipped)
        finish(.skipped)
    }

    private func finish(_ outcome: Outcome) {
        withAnimation(.easeOut(duration: 0.25)) { buttonsShown = false }
        after(0.4) { onFinished(outcome) }
    }

    // MARK: - 進み(排出口から出てくる動き)

    private static func ejectTravel(_ elapsed: TimeInterval) -> Double {
        guard elapsed > Timing.ejectStart else { return 0 }
        let total = Timing.ejectEnd - Timing.ejectStart
        let u = min(1, (elapsed - Timing.ejectStart) / total)
        if u < 0.5 { return 0.58 * smooth(u / 0.5) }
        if u < 0.64 { return 0.58 }
        return 0.58 + 0.42 * smooth((u - 0.64) / 0.36)
    }

    private static func smooth(_ t: Double) -> Double {
        let c = min(1, max(0, t))
        return c * c * (3 - 2 * c)
    }

    // MARK: - 表記・読み上げ

    private var accessibilityText: String {
        if isOpen { return isRareFilm ? "レアフィルム。ひらきました" : "昨日の1枚、ひらきました" }
        return "現像中、\(Int((developProgress * 100).rounded()))パーセント。指でふると早まります"
    }

    private static func filmDate(_ date: Date) -> String {
        ProfileShot.filmStamp(for: date)
    }
}

/// ガラスのボタン。「透明度を下げる」では不透明な #1c1c20。
private struct GlassFill<S: InsettableShape>: View {
    let shape: S
    let opaque: Bool
    var tint: Double = 0.1

    var body: some View {
        if opaque {
            shape.fill(Color(hex: "1C1C20"))
                .overlay(shape.strokeBorder(.white.opacity(0.1), lineWidth: 1))
        } else {
            shape.fill(.ultraThinMaterial.opacity(0.6))
                .overlay(shape.fill(.white.opacity(tint)))
                .overlay(shape.strokeBorder(.white.opacity(0.1), lineWidth: 1))
        }
    }
}

// MARK: - 【D】撮ったあとの 現像の画面(前日の 自分の N枚目)と、1枚ずつの 投稿の 選択

/// 全画面・黒(昼も夜も)。前日の N枚目が モザイクから 本物の写真になり(約2.5秒)、下に「投稿する / 投稿しない」。
/// - 現像中は 画面の どこを タップしても、すぐ ひらききる(tick)
/// - 選ぶまで 閉じない。下へ スワイプで 閉じると「まだ 決めていない」のまま(月に「昨日の1枚を選ぶ」)
/// - 動きを減らす:モザイクを やめて、約1秒の フェード
struct YesterdayRevealView: View {
    enum Outcome { case posted, skipped, later }

    let image: UIImage?
    /// 22×48 の 小さな画像(モザイクの 元)
    let tiny: Data?
    let key: String
    /// きのうの 何こま目か(1〜3)
    let ordinal: Int
    /// false なら 現像の 動きを せず、選ぶ ところから(月の「昨日の1枚を選ぶ」から 来たとき)
    let playsReveal: Bool
    /// 1回だけ 呼ぶ
    let onFinish: (Outcome) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var revealed = false
    @State private var finished = false
    @State private var dragY: CGFloat = 0
    @State private var scheduled: [DispatchWorkItem] = []

    /// 現像の 時間割(秒)。L0 → L1 → L2 → 本物
    static let total: TimeInterval = 2.5
    static let stages: [TimeInterval] = [0.6, 1.2, 1.9]
    static let reducedTotal: TimeInterval = 1.0

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width - 72, 320)
            let height = width * 4 / 3
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 18) {
                    Spacer(minLength: 0)
                    TimelineView(.animation(paused: revealed || finished)) { context in
                        photo(elapsed: revealed ? Self.total : context.date.timeIntervalSince(start))
                            .frame(width: width, height: height)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .shadow(color: .black.opacity(0.6), radius: 24, y: 18)
                    }
                    Text("きのうの \(ordinal)こま目、ひらきました")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "C7C7CC"))
                        .opacity(revealed ? 1 : 0.0)
                    Spacer(minLength: 0)
                    buttons
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed ? 0 : 12)
                        .allowsHitTesting(revealed && !finished)
                        .padding(.horizontal, 24)
                        .padding(.bottom, max(24, proxy.safeAreaInsets.bottom + 8))
                }
                .frame(maxWidth: .infinity)
            }
            .offset(y: max(0, dragY))
            .contentShape(Rectangle())
            .onTapGesture {
                // 現像中:どこを タップしても すぐ ひらききる
                guard !revealed, !finished else { return }
                Haptics.play(.tick)
                finishReveal(skipped: true)
            }
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in if value.translation.height > 0 { dragY = value.translation.height } }
                    .onEnded { value in
                        if value.translation.height > 140 { finish(.later) } else { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { dragY = 0 } }
                    }
            )
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .animation(.easeOut(duration: 0.35), value: revealed)
        .onAppear(perform: begin)
        .onDisappear { scheduled.forEach { $0.cancel() } }
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape) { finish(.later) }
    }

    // MARK: 写真(モザイク → 本物)

    /// 枠の 大きさは 外で 決める(縦長の モザイクを 広げても、画面の 組み立てが ずれないように)
    private func photo(elapsed: TimeInterval) -> some View {
        Color.clear
            .overlay { photoContent(elapsed: elapsed) }
            .clipped()
    }

    @ViewBuilder
    private func photoContent(elapsed: TimeInterval) -> some View {
        if reduceMotion || tiny == nil {
            // フェードで 約1秒
            let k = revealed ? 1 : min(1, max(0, elapsed / Self.reducedTotal))
            ZStack {
                Color(hex: "1C1C1F")
                if let image { fill(Image(uiImage: image).resizable()).opacity(k) }
            }
        } else {
            let level: MosaicLevel = elapsed < Self.stages[0] ? .l0 : (elapsed < Self.stages[1] ? .l1 : (elapsed < Self.stages[2] ? .l2 : .l3))
            let real = revealed ? 1 : max(0, min(1, (elapsed - Self.stages[2]) / (Self.total - Self.stages[2])))
            ZStack {
                if real < 1, let tiny, let mosaic = MosaicRenderer.image(fromTiny: tiny, key: key, level: level == .l3 ? .l2 : level) {
                    fill(Image(uiImage: mosaic).resizable().interpolation(.none))
                }
                if let image { fill(Image(uiImage: image).resizable()).opacity(real) }
            }
        }
    }

    /// 枠いっぱいに 広げる(枠の 大きさは かえない)
    private func fill(_ image: Image) -> some View {
        Color.clear
            .overlay { image.scaledToFill() }
            .clipped()
    }

    // MARK: ボタン

    private var buttons: some View {
        VStack(spacing: 10) {
            Button {
                // 投稿する:rigid → 0.08秒後に soft
                Haptics.pulse(intensity: 1, sharpness: 0.9)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { Haptics.play(.soft, gap: 0) }
                finish(.posted)
            } label: {
                Text("投稿する").font(.system(size: 16, weight: .heavy)).foregroundStyle(Color(hex: "111111"))
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
            Button {
                Haptics.play(.soft)
                finish(.skipped)
            } label: {
                Text("投稿しない").font(.system(size: 15, weight: .bold)).foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Capsule().strokeBorder(.white.opacity(0.28), lineWidth: 1.2))
            }
            .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
            Text("投稿しないと、あなたの 端末にだけ 残ります")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(Color(hex: "A1A1A8"))
        }
    }

    // MARK: 動き

    private func begin() {
        start = Date()
        guard playsReveal else {
            revealed = true
            return
        }
        Haptics.play(.soft)   // 現像の 画面が 出た
        if reduceMotion || tiny == nil {
            schedule(Self.reducedTotal) { finishReveal(skipped: false) }
            return
        }
        // 段ごとに ごく軽い tick(3回)
        for stage in Self.stages { schedule(stage) { if !revealed { Haptics.play(.tick, gap: 0) } } }
        schedule(Self.total) { finishReveal(skipped: false) }
    }

    private func finishReveal(skipped: Bool) {
        guard !revealed else { return }
        scheduled.forEach { $0.cancel() }
        revealed = true
        if !skipped { Haptics.play(.success) }   // ひらききった
    }

    /// 閉じるのは 1回だけ
    private func finish(_ outcome: Outcome) {
        guard !finished else { return }
        finished = true
        scheduled.forEach { $0.cancel() }
        onFinish(outcome)
    }

    private func schedule(_ delay: TimeInterval, _ work: @escaping () -> Void) {
        let item = DispatchWorkItem(block: work)
        scheduled.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
}
