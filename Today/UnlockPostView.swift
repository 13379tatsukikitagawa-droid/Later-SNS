import SwiftUI
import UIKit

/// 「撮る → 昨日の1枚が解禁 → 投稿するか選ぶ」の2つの画面。
/// 画面①(解禁・約4.2秒)のあと、同じ画面の上で画面②(投稿するか選ぶシート)が続く(画面遷移はしない)。
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
    /// falseなら解禁のアニメーションをせず、画面②(選ぶ)から始める
    let playsUnlock: Bool
    let haptics: ExposureHaptics
    /// 選んだ瞬間に呼ぶ(データの処理)
    let onDecide: (Outcome) -> Void
    /// 結果を見せ終えた(約1.7秒後)。Homeへもどす
    let onFinished: (Outcome) -> Void
    /// 見た目の確認用:解禁の進み具合をこの値で止める(0〜1)
    private let frozenProgress: Double?

    init(
        image: UIImage?,
        capturedAt: Date,
        groups: [ProfileShareGroup],
        showsMondo: Bool,
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
        self.playsUnlock = playsUnlock
        self.haptics = haptics
        self.onDecide = onDecide
        self.onFinished = onFinished
        self.frozenProgress = frozenProgress
        _phase = State(initialValue: playsUnlock ? .unlocking : .choosing)
        _isPrintShown = State(initialValue: !playsUnlock || frozenProgress != nil)
    }

    private enum Phase: Equatable {
        case unlocking
        case unlocked
        case choosing
        case confirming
        case result(Outcome)
    }

    private enum Timing {
        static let delay: TimeInterval = 0.55
        static let duration: TimeInterval = 4.2
        static let reducedDuration: TimeInterval = 1.0
        static let resultHold: TimeInterval = 1.7
    }

    private enum Layout {
        static let block = DevelopSheet.Layout.block
        static let dotFrame = DevelopSheet.Layout.dotFrame
        static let print = DevelopSheet.Layout.print
        static let printOrigin = DevelopSheet.Layout.printOrigin
        static let window = DevelopSheet.Layout.window
        static let windowOrigin = DevelopSheet.Layout.windowOrigin
    }

    private static let ease = Animation.timingCurve(0.22, 0.8, 0.24, 1, duration: 0.6)
    private static let sheetEase = Animation.timingCurve(0.22, 0.8, 0.24, 1, duration: 0.55)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AccessibilityFocusState private var isButtonFocused: Bool
    @State private var phase: Phase = .unlocking
    @State private var start: Date?
    @State private var isPrintShown = false
    @State private var flashStart: Date?
    @State private var resultBrightness: Double = 0
    @State private var fadeOut = false
    @State private var scheduled: [DispatchWorkItem] = []

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let extra = size.height - 844
            let blockScale = max(0.6, min(1, (Layout.block.height + extra) / Layout.block.height))
            let blockHeight = Layout.block.height * blockScale
            let titleTop = 96 + blockHeight + 24
            TimelineView(.animation(paused: !isAnimating)) { context in
                let p = progress(at: context.date)
                ZStack(alignment: .top) {
                    background(open: developAmount(p))

                    smallHeading(isOpen: isOpenText(p))
                        .padding(.top, 66)

                    printBlock(p: p, now: context.date)
                        .scaleEffect(blockScale, anchor: .top)
                        .frame(width: Layout.block.width * blockScale, height: blockHeight, alignment: .top)
                        .scaleEffect(isSheetShown ? 0.8 : 1, anchor: .top)
                        .offset(y: isSheetShown ? -6 : 0)
                        .padding(.top, 96)
                        .frame(maxWidth: .infinity)

                    if !isSheetShown {
                        headline(isOpen: isOpenText(p))
                            .padding(.top, titleTop)
                            .transition(.opacity)

                        if showsButton(p) {
                            decideButton
                                .frame(maxHeight: .infinity, alignment: .bottom)
                                .padding(.horizontal, 28)
                                .padding(.bottom, 44)
                                .transition(.opacity.combined(with: .offset(y: 10)))
                        }
                    }

                    if isSheetShown {
                        sheet
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .transition(.move(edge: .bottom))
                    }
                }
                .frame(width: size.width, height: size.height)
                .animation(.easeInOut(duration: 0.42), value: isOpenText(p))
                .animation(.easeOut(duration: 0.5), value: showsButton(p))
            }
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .onAppear(perform: begin)
        .onDisappear { scheduled.forEach { $0.cancel() } }
    }

    // MARK: - 進み具合

    private var isSheetShown: Bool {
        switch phase {
        case .choosing, .confirming, .result: return true
        default: return false
        }
    }

    private var isAnimating: Bool {
        phase == .unlocking || flashStart != nil
    }

    /// 0〜1(解禁が終わったあとは1)
    private func progress(at date: Date) -> Double {
        if let frozenProgress { return frozenProgress }
        guard phase == .unlocking else { return 1 }
        guard let start else { return 0 }
        let duration = reduceMotion ? Timing.reducedDuration : Timing.duration
        return min(1, max(0, (date.timeIntervalSince(start) - Timing.delay) / duration))
    }

    private static func segment(_ p: Double, _ from: Double, _ to: Double) -> Double {
        min(1, max(0, (p - from) / (to - from)))
    }

    private static func easeOut(_ u: Double) -> Double { 1 - pow(1 - u, 2.2) }

    /// 乳白色 → 色(0〜1)。背景の夜 → 朝もこれにそろえる
    private func developAmount(_ p: Double) -> Double {
        reduceMotion ? p : Self.easeOut(Self.segment(p, 0.58, 0.96))
    }

    private func isOpenText(_ p: Double) -> Bool {
        reduceMotion || p >= 0.66
    }

    private func showsButton(_ p: Double) -> Bool {
        phase == .unlocked || (phase == .unlocking && p >= 0.97)
    }

    // MARK: - 背景

    private func background(open: Double) -> some View {
        ZStack {
            Color.black
            LinearGradient(colors: [.clear, Color(red: 70 / 255, green: 80 / 255, blue: 170 / 255).opacity(0.34)], startPoint: .top, endPoint: .bottom)
                .opacity(1 - open)
            LinearGradient(
                colors: [Color(red: 1, green: 190 / 255, blue: 130 / 255).opacity(0.24), .clear, Color(red: 1, green: 130 / 255, blue: 150 / 255).opacity(0.4)],
                startPoint: .top, endPoint: .bottom
            )
            .opacity(open)
        }
        .allowsHitTesting(false)
    }

    // MARK: - 文字

    private var yesterdayLabel: String {
        "YESTERDAY ・ \(Self.dotDate.string(from: capturedAt))"
    }

    private func smallHeading(isOpen: Bool) -> some View {
        Text(yesterdayLabel)
            .font(.system(size: 10.5, design: .monospaced))
            .tracking(0.22 * 10.5)
            .foregroundStyle(isOpen ? Color(hex: "FF9E5E") : Color(hex: "8E8E93"))
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .accessibilityHidden(true)
    }

    private func headline(isOpen: Bool) -> some View {
        VStack(spacing: 0) {
            Text(isOpen ? "昨日の1枚が、\nひらきました。" : "昨日が、\nひらきます。")
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.05 * 28)
                .lineSpacing(28 * 0.3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .id(isOpen)
                .transition(.opacity)
            Text("\(Self.jaDate.string(from: capturedAt)) ・ \(isOpen ? "あなたの1枚" : "現像ずみの1枚")")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "BCBBC0"))
                .padding(.top, 14)
                .id("sub-\(isOpen)")
                .transition(.opacity)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }

    private var decideButton: some View {
        Button(action: openSheet) {
            Text("この1枚を、どうする?")
                .font(.system(size: 16.5, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(GlassFill(shape: Capsule(), opaque: reduceTransparency))
        }
        .buttonStyle(.plain)
        .accessibilityFocused($isButtonFocused)
    }

    // MARK: - 光の輪 + チェキ(現像シートと同じ部品)

    private func printBlock(p: Double, now: Date) -> some View {
        let lit = reduceMotion ? DevelopDensity.dotCount : Int((Self.easeOut(Self.segment(p, 0.06, 0.46)) * Double(DevelopDensity.dotCount)).rounded())
        let allLit = reduceMotion || p >= 0.5
        let flashes = ringFlashes(p: p, now: now)
        return ZStack(alignment: .topLeading) {
            SealDotFrame(lit: lit, isDeveloped: allLit, isAnimating: !reduceMotion && phase == .unlocking)
                .frame(width: Layout.dotFrame.width, height: Layout.dotFrame.height)
                .offset(x: (Layout.block.width - Layout.dotFrame.width) / 2, y: (Layout.block.height - Layout.dotFrame.height) / 2)

            ForEach(Array(flashes.enumerated()), id: \.offset) { _, b in
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color(red: 1, green: 206 / 255, blue: 160 / 255).opacity(0.95), lineWidth: 2)
                    .shadow(color: HomePalette.orange.opacity(0.8), radius: 8)
                    .frame(width: Layout.dotFrame.width, height: Layout.dotFrame.height)
                    .scaleEffect(1 + b.scale * b.amount)
                    .opacity((1 - b.amount) * 0.9)
                    .offset(x: (Layout.block.width - Layout.dotFrame.width) / 2, y: (Layout.block.height - Layout.dotFrame.height) / 2)
            }

            cheki(p: p)
                .frame(width: Layout.print.width, height: Layout.print.height)
                .rotationEffect(.degrees(-2.2), anchor: .bottom)
                .offset(x: Layout.printOrigin.x, y: Layout.printOrigin.y)
                .offset(y: isPrintShown || reduceMotion ? 0 : -70)
                .opacity(isPrintShown || reduceMotion ? 1 : 0)
        }
        .frame(width: Layout.block.width, height: Layout.block.height, alignment: .topLeading)
        .brightness(resultBrightness)
        .blur(radius: fadeOut ? 14 : 0)
        .opacity(fadeOut ? 0 : 1)
        .accessibilityHidden(true)
    }

    /// ふちの光(解禁の .50–.76 と、投稿したときの 0.9秒)。amount 0〜1、scale はひろがる量
    private func ringFlashes(p: Double, now: Date) -> [(amount: Double, scale: Double)] {
        var result: [(Double, Double)] = []
        if !reduceMotion, phase == .unlocking, p > 0.5, p < 0.76 {
            result.append((Self.segment(p, 0.5, 0.76), 0.12))
        }
        if let flashStart {
            let b = now.timeIntervalSince(flashStart) / 0.9
            if b >= 0, b < 1 { result.append((b, 0.16)) }
        }
        return result
    }

    private func cheki(p: Double) -> some View {
        let paper = RoundedRectangle(cornerRadius: 6, style: .continuous)
        let e = developAmount(p)
        let isOpen = isOpenText(p)
        return ZStack(alignment: .topLeading) {
            paper.fill(LinearGradient(colors: [Color(hex: "F7F4EE"), Color(hex: "ECE8DF")], startPoint: .top, endPoint: .bottom))

            ZStack {
                Group {
                    if let image {
                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color(hex: "B9B3A8")
                    }
                }
                .frame(width: Layout.window.width, height: Layout.window.height)
                .scaleEffect(1.12 - 0.12 * e)
                .blur(radius: 26 * (1 - e))
                .saturation(0.15 + 0.9 * e)
                .brightness(-0.45 * (1 - e))

                // 乳白色のもや
                Color(hex: "EDE8DE").opacity(0.92 * (1 - e))

                if !reduceMotion {
                    lock(p: p)
                }
            }
            .frame(width: Layout.window.width, height: Layout.window.height)
            .clipped()
            .offset(x: Layout.windowOrigin.x, y: Layout.windowOrigin.y)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .lastTextBaseline) {
                    Text(isOpen ? "OPEN" : "SEALED")
                        .font(.system(size: 27, design: .monospaced))
                        .tracking(0.06 * 27)
                        .foregroundStyle(isOpen ? Color(hex: "C8742F") : Color(hex: "A09C91"))
                    Spacer(minLength: 0)
                    Text("きのう")
                        .font(.system(size: 15).italic())
                        .foregroundStyle(Color(hex: "8A867B"))
                }
                Text("\(Self.filmDate(capturedAt)) ・ あなたの1枚")
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(0.14 * 9)
                    .foregroundStyle(Color(hex: "A09C91"))
            }
            .dynamicTypeSize(.large)
            .padding(.horizontal, 17)
            .padding(.bottom, 13)
            .frame(width: Layout.print.width, height: Layout.print.height, alignment: .bottom)
        }
        .clipShape(paper)
        .shadow(color: .black.opacity(0.65), radius: 22, y: 22)
        .shadow(color: HomePalette.orange.opacity(0.14), radius: 28)
    }

    /// 鍵:輪っかが上がって開き(.46–.60)、消える(.58–.72)
    private func lock(p: Double) -> some View {
        let open = Self.segment(p, 0.46, 0.60)
        let fade = Self.segment(p, 0.58, 0.72)
        return ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().fill(.white.opacity(0.12)))
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                .frame(width: 68, height: 68)
            ZStack {
                // 輪っか(右の脚を軸に、上がって開く)
                ShackleShape()
                    .stroke(.white, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                    .frame(width: 16, height: 12)
                    .rotationEffect(.degrees(-30 * open), anchor: .bottomTrailing)
                    .offset(y: -9 - 5 * open)
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(.white)
                    .frame(width: 22, height: 17)
                    .offset(y: 5)
            }
        }
        .scaleEffect(1 + 0.3 * fade)
        .opacity(1 - fade)
    }

    // MARK: - 画面② シート

    private var sheet: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.white.opacity(0.2))
                .frame(width: 40, height: 5)
                .padding(.bottom, 18)

            // 文字を大きくして入りきらない時だけ、スクロールできるようにする
            ViewThatFits(in: .vertical) {
                sheetContent
                ScrollView { sheetContent }
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
        .background(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "1D1D21"), Color(hex: "101012")], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .accessibilityAddTraits(.isModal)
    }

    private var sheetContent: some View {
        Group {
            switch phase {
            case .confirming: confirmContent
            case .result(let outcome): resultContent(outcome)
            default: chooseContent
            }
        }
        .transition(.opacity)
        .animation(.easeOut(duration: 0.25), value: phase)
    }

    private var shareText: String {
        let summary = ProfileShot.shareSummary(groups: groups, isOnMondo: showsMondo)
        return summary.isEmpty ? "グループに入ると、届けられます" : "\(summary) に届きます"
    }

    private var shareRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: -6) {
                if !groups.isEmpty { targetDot(DayFullScreenViewer.groupGradient) }
                if showsMondo { targetDot(DayFullScreenViewer.mondoGradient) }
            }
            Text(shareText)
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "BCBBC0"))
                .lineLimit(2)
        }
    }

    private func targetDot(_ colors: [Color]) -> some View {
        Circle()
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 18, height: 18)
            .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.2))
            .accessibilityHidden(true)
    }

    private var chooseContent: some View {
        VStack(spacing: 0) {
            Text("この1枚を、投稿する?")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.04 * 20)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            shareRow
                .padding(.top, 10)

            Button(action: post) {
                Text("投稿する")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 54)
                    .background(Capsule().fill(.white))
                    .shadow(color: .white.opacity(0.35), radius: 16)
            }
            .buttonStyle(.plain)
            .padding(.top, 22)

            Button(action: askSkip) {
                Text("投稿しない")
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(GlassFill(shape: Capsule(), opaque: reduceTransparency, tint: 0.09))
            }
            .buttonStyle(.plain)
            .padding(.top, 10)

            VStack(spacing: 0) {
                Text("投稿しない写真は、消えます。")
                Text("みんなの昨日は、このあとひらけます。")
            }
            .font(.system(size: 11.5))
            .lineSpacing(11.5 * 0.75)
            .foregroundStyle(Color(hex: "8E8E93"))
            .multilineTextAlignment(.center)
            .padding(.top, 13)
        }
        .frame(maxWidth: .infinity)
    }

    private var confirmContent: some View {
        VStack(spacing: 0) {
            Text("この写真を、消しますか?")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.04 * 20)
                .foregroundStyle(.white)
            Text("投稿せずに消えます。もとにもどせません。")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "BCBBC0"))
                .multilineTextAlignment(.center)
                .padding(.top, 10)

            Button(action: skip) {
                Text("消す")
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(Capsule().fill(Color(hex: "FF6B5E")))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("消す。もとにもどせません")
            .padding(.top, 22)

            Button {
                withAnimation(.easeOut(duration: 0.25)) { phase = .choosing }
            } label: {
                Text("やめる")
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(GlassFill(shape: Capsule(), opaque: reduceTransparency, tint: 0.09))
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
    }

    private func resultContent(_ outcome: Outcome) -> some View {
        VStack(spacing: 0) {
            Circle()
                .fill(.white.opacity(0.1))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: outcome == .posted ? "checkmark" : "minus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                )
            Text(outcome == .posted ? "投稿しました" : "消しました")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 14)
            Text(outcome == .posted ? shareText : "昨日の1枚は、もうありません")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "BCBBC0"))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 動き

    private func begin() {
        guard frozenProgress == nil else { return }
        guard playsUnlock else {
            phase = .choosing
            isPrintShown = true
            return
        }
        UIAccessibility.post(notification: .announcement, argument: "昨日の1枚が、ひらきます")
        let now = Date()
        start = now
        if reduceMotion {
            isPrintShown = true
        } else {
            after(Timing.delay) {
                withAnimation(.timingCurve(0.22, 0.8, 0.24, 1, duration: 0.8)) { isPrintShown = true }
            }
        }
        let duration = reduceMotion ? Timing.reducedDuration : Timing.duration
        if !reduceMotion {
            // 点が灯っていく(p .06 → .5):じわっと強くなる
            after(Timing.delay + 0.06 * duration) {
                haptics.playRamp(from: 0.15, to: 0.85, sharpness: 0.3, sharpnessTo: 0.6, duration: 0.44 * duration)
            }
        }
        // 鍵が開く(p .5):強く1回(「視差効果を減らす」でも残す)
        after(Timing.delay + (reduceMotion ? 0.5 : 0.5 * duration)) {
            haptics.playTransient(intensity: 1.0, sharpness: 0.7)
        }
        after(Timing.delay + duration) {
            phase = .unlocked
            UIAccessibility.post(notification: .announcement, argument: "ひらきました。この1枚を、どうする?")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { isButtonFocused = true }
        }
    }

    private func after(_ delay: TimeInterval, _ work: @escaping () -> Void) {
        let item = DispatchWorkItem(block: work)
        scheduled.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func openSheet() {
        withAnimation(Self.sheetEase) { phase = .choosing }
    }

    private func post() {
        guard phase == .choosing else { return }
        haptics.playTransient(intensity: 1.0, sharpness: 0.7)
        onDecide(.posted)
        withAnimation(.easeOut(duration: 0.25)) { phase = .result(.posted) }
        flashStart = Date()
        withAnimation(.easeOut(duration: 0.3)) { resultBrightness = 0.4 }
        after(0.3) { withAnimation(.easeIn(duration: 0.5)) { resultBrightness = 0 } }
        after(0.95) { flashStart = nil }
        finish(.posted)
    }

    private func askSkip() {
        haptics.playTransient(intensity: 0.25, sharpness: 0.4)
        withAnimation(.easeOut(duration: 0.25)) { phase = .confirming }
    }

    private func skip() {
        guard phase == .confirming else { return }
        haptics.playTransient(intensity: 0.25, sharpness: 0.4)
        onDecide(.skipped)
        withAnimation(.easeOut(duration: 0.25)) { phase = .result(.skipped) }
        withAnimation(.easeIn(duration: 1.0)) { fadeOut = true }
        finish(.skipped)
    }

    private func finish(_ outcome: Outcome) {
        after(Timing.resultHold) { onFinished(outcome) }
    }

    // MARK: - 書式

    private static let dotDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "MM.dd"
        return f
    }()

    private static let jaDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日"
        return f
    }()

    private static func filmDate(_ date: Date) -> String {
        ProfileShot.filmStamp(for: date)
    }
}

/// 鍵の輪っか(下がひらいたU字)
private struct ShackleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
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
