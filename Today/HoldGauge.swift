import SwiftUI

/// 長押しでひらく(Opalの「長押しでゲージがたまる」と同じ型)の決まり。
enum HoldToOpenRules {
    /// 長押しの長さ(撮影の1.5秒より少し短い)
    static let duration: TimeInterval = 1.2
    /// 押している間、じわっと強くなる(Continuous)
    static let holdIntensity: ClosedRange<Float> = 0.15...0.85
    static let holdSharpness: ClosedRange<Float> = 0.3...0.6
    /// たまり切ったときの強い1回
    static let completeHaptic: (intensity: Float, sharpness: Float) = (1.0, 0.7)
    /// 離したときに元にもどる時間
    static let releaseDuration: TimeInterval = 0.32
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
        releaseFrom = (current, date, HoldToOpenRules.releaseDuration)
        pressStart = nil
    }

    func complete() {
        isDone = true
        pressStart = nil
        releaseFrom = nil
    }

    func reset() {
        holdTask?.cancel()
        isDone = false
        pressStart = nil
        releaseFrom = nil
    }

    // MARK: - 押す・離す(触覚つき)

    @ObservationIgnored private var holdTask: Task<Void, Never>?

    /// 押している間、連続の振動がゆっくり強くなる(強さ0.15→0.85、鋭さ0.3→0.6)。
    /// たまり切ったら、強い1回とともにonCompleteを呼ぶ。
    func press(haptics: ExposureHaptics, onComplete: @escaping () -> Void) {
        guard let remaining = begin() else { return }
        haptics.beginHold(duration: remaining, intensity: HoldToOpenRules.holdIntensity, sharpness: HoldToOpenRules.holdSharpness)
        holdTask?.cancel()
        holdTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard let self, !Task.isCancelled, self.isPressing else { return }
            self.finish(haptics: haptics, onComplete: onComplete)
        }
    }

    /// 途中で離した(指が外に出た時も同じ):連続の振動をすぐ止める。ゲージは320msで戻る。
    func lift(haptics: ExposureHaptics) {
        guard isPressing, !isDone else { return }
        holdTask?.cancel()
        release()
        haptics.cancelHold()
    }

    /// たまり切った(VoiceOverの「ひらく」からは、長押しなしでここを呼ぶ)。
    func finish(haptics: ExposureHaptics, onComplete: @escaping () -> Void) {
        guard !isDone else { return }
        holdTask?.cancel()
        complete()
        haptics.fireCapture(intensity: HoldToOpenRules.completeHaptic.intensity, sharpness: HoldToOpenRules.completeHaptic.sharpness)
        onComplete()
    }
}
