import SwiftUI

/// 長押しでひらく(Opalの「長押しでゲージがたまる」と同じ型)の決まり。
enum HoldToOpenRules {
    /// 長押しの長さ(撮影の1.5秒より少し短い)
    static let duration: TimeInterval = 1.2
    /// 押し始めの軽い1回
    static let pressHaptic: (intensity: Float, sharpness: Float) = (0.4, 0.5)
    /// たまり切ったときの強い1回
    static let completeHaptic: (intensity: Float, sharpness: Float) = (1.0, 0.9)
    /// 途中で離したときのやわらかい1回
    static let releaseHaptic: (intensity: Float, sharpness: Float) = (0.25, 0.3)
}

/// 長押しの進み具合。ボタンのゲージと、円の色づきが同じ値を読む。
/// 押している間は線形に1.2秒でたまり、離すとたまっていた量に応じて0.15〜0.4秒で戻る(イーズイン・アウト)。
@MainActor
@Observable
final class HoldGaugeModel {
    private(set) var pressStart: Date?
    private(set) var releaseFrom: (progress: Double, at: Date, duration: TimeInterval)?
    private(set) var isDone = false

    func progress(at date: Date) -> Double {
        if isDone { return 1 }
        if let pressStart {
            return min(1, max(0, date.timeIntervalSince(pressStart) / HoldToOpenRules.duration))
        }
        if let releaseFrom {
            let t = min(1, max(0, date.timeIntervalSince(releaseFrom.at) / releaseFrom.duration))
            let eased = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
            return releaseFrom.progress * (1 - eased)
        }
        return 0
    }

    var isMoving: Bool {
        if pressStart != nil { return true }
        if let releaseFrom { return Date().timeIntervalSince(releaseFrom.at) < releaseFrom.duration + 0.05 }
        return false
    }

    var isPressing: Bool { pressStart != nil }

    /// 戻りかけの位置から押し直した時は、そこから続ける。満ちるまでの残り秒数を返す。
    func begin(at date: Date = Date()) -> TimeInterval? {
        guard !isDone, pressStart == nil else { return nil }
        let current = progress(at: date)
        pressStart = date.addingTimeInterval(-current * HoldToOpenRules.duration)
        releaseFrom = nil
        return (1 - current) * HoldToOpenRules.duration
    }

    func release(at date: Date = Date()) {
        guard !isDone, pressStart != nil else { return }
        let current = progress(at: date)
        releaseFrom = (current, date, 0.15 + 0.25 * current)
        pressStart = nil
    }

    func complete() {
        isDone = true
        pressStart = nil
        releaseFrom = nil
    }

    func reset() {
        isDone = false
        pressStart = nil
        releaseFrom = nil
    }
}

/// 「現像された昨日を見る」の長押しボタン。押している間、左からゲージ(オレンジ→白)がたまり、
/// ゲージが覆った部分の文字は黒、覆っていない部分は白になる。1.2秒でたまり切るとひらく。
struct HoldToOpenButton: View {
    let model: HoldGaugeModel
    let haptics: ExposureHaptics
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .headline) private var titleSize: CGFloat = 17
    @State private var holdTask: Task<Void, Never>?

    static let height: CGFloat = 60

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { proxy in
                TimelineView(.animation(paused: !model.isMoving)) { context in
                    let p = model.progress(at: context.date)
                    button(width: proxy.size.width, progress: p, time: context.date)
                }
                .contentShape(Capsule())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let inside = CGRect(origin: .zero, size: proxy.size).insetBy(dx: -8, dy: -8).contains(value.location)
                            // 指がボタンの外に出たときも、離したのと同じ扱い(キャンセル)。
                            if inside { begin() } else { release() }
                        }
                        .onEnded { _ in release() }
                )
            }
            .frame(height: Self.height)
            .accessibilityElement()
            .accessibilityLabel("現像された昨日を見る")
            .accessibilityHint("長押しでひらきます")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "ひらく") { complete() }

            TimelineView(.animation(paused: !model.isMoving)) { context in
                Text(sublabel(progress: model.progress(at: context.date)))
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(0.14 * 10)
                    .foregroundStyle(.white.opacity(0.42))
                    .monospacedDigit()
            }
            .frame(height: 14)
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .accessibilityHidden(true)
        }
        .onDisappear { holdTask?.cancel() }
    }

    private func sublabel(progress p: Double) -> String {
        if model.isDone { return " " }
        if model.isPressing {
            let remaining = max(0, (1 - p) * HoldToOpenRules.duration)
            return String(format: "あと %.1f 秒", remaining)
        }
        return "長押しで、ひらく"
    }

    private func title(progress p: Double) -> String {
        if model.isDone { return "ひらきます" }
        return model.isPressing ? "そのまま、持っていて…" : "現像された昨日を見る"
    }

    private func button(width: CGFloat, progress p: Double, time: Date) -> some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        let gaugeWidth = width * p
        let title = title(progress: p)
        let showsIcon = !model.isPressing && !model.isDone
        return ZStack(alignment: .leading) {
            shape.fill(LinearGradient(colors: [Color(hex: "232326"), Color(hex: "171719")], startPoint: .top, endPoint: .bottom))

            // ゲージ(オレンジ → 白)
            LinearGradient(stops: [
                .init(color: Color(hex: "FF9A66"), location: 0),
                .init(color: Color(hex: "FFB38A"), location: 0.38),
                .init(color: Color(hex: "FFE3CC"), location: 0.82),
                .init(color: .white, location: 1),
            ], startPoint: .leading, endPoint: .trailing)
            .frame(width: width)
            .mask(alignment: .leading) { Capsule().frame(width: max(0, gaugeWidth)) }

            if p > 0.01 && p < 1 && !reduceMotion {
                // 先端のやわらかい光(文字が読めなくなるほど明るくしない)
                Ellipse()
                    .fill(RadialGradient(colors: [.white.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 35))
                    .frame(width: 70, height: Self.height)
                    .blur(radius: 5)
                    .offset(x: gaugeWidth - 35)
                    .allowsHitTesting(false)
                particles(gaugeWidth: gaugeWidth, time: time)
            }

            label(title: title, showsIcon: showsIcon, color: .white)
            label(title: title, showsIcon: showsIcon, color: .black)
                .mask(alignment: .leading) { Rectangle().frame(width: min(width, gaugeWidth + width * 0.09)) }
        }
        .frame(width: width, height: Self.height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.16), lineWidth: 1))
        .overlay(alignment: .top) { Capsule().fill(.white.opacity(0.12)).frame(height: 1).padding(.horizontal, 30) }
        .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
        .scaleEffect(1 - 0.018 * p)
    }

    private func label(title: String, showsIcon: Bool, color: Color) -> some View {
        HStack(spacing: 10) {
            if showsIcon {
                Circle()
                    .strokeBorder(color, lineWidth: 2)
                    .frame(width: 18, height: 18)
                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            }
            Text(title)
                .font(.system(size: titleSize, weight: .bold))
                .tracking(-0.03 * titleSize)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.15), value: title)
    }

    /// ゲージの中で、ゆっくりまたたく小さな粒(周期1.2秒、位相をずらす)。
    private func particles(gaugeWidth: CGFloat, time: Date) -> some View {
        let t = time.timeIntervalSinceReferenceDate
        return ZStack(alignment: .leading) {
            ForEach(0..<5, id: \.self) { index in
                let fraction = [0.18, 0.37, 0.55, 0.71, 0.88][index]
                let y = [16.0, 38.0, 24.0, 44.0, 30.0][index]
                let twinkle = 0.5 + 0.5 * sin(t * 2 * .pi / 1.2 + Double(index) * 1.3)
                Circle()
                    .fill(.white)
                    .frame(width: index.isMultiple(of: 2) ? 2 : 1.4, height: index.isMultiple(of: 2) ? 2 : 1.4)
                    .opacity(0.7 * twinkle)
                    .offset(x: gaugeWidth * fraction, y: y - Self.height / 2)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - 操作

    private func begin() {
        guard let remaining = model.begin() else { return }
        haptics.playTransient(intensity: HoldToOpenRules.pressHaptic.intensity, sharpness: HoldToOpenRules.pressHaptic.sharpness)
        // 連続の振動が、ゆっくり強くなる(強さ0.15→0.85、鋭さ0.2→0.55)。
        haptics.beginHold(duration: remaining)
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled, model.isPressing else { return }
            complete()
        }
    }

    private func release() {
        guard model.isPressing, !model.isDone else { return }
        holdTask?.cancel()
        model.release()
        haptics.cancelHold()
        haptics.playTransient(intensity: HoldToOpenRules.releaseHaptic.intensity, sharpness: HoldToOpenRules.releaseHaptic.sharpness)
    }

    private func complete() {
        guard !model.isDone else { return }
        holdTask?.cancel()
        model.complete()
        haptics.fireCapture(intensity: HoldToOpenRules.completeHaptic.intensity, sharpness: HoldToOpenRules.completeHaptic.sharpness)
        onComplete()
    }
}
