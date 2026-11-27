import UIKit
import CoreHaptics

// v136:#レンズ(ともだち 0人の Home)の 長押し 専用の 触感。
// 他の 長押し(撮る ・ ひらく ・ はじめる)の `HapticRamp` とは 別の 値。この 形は レンズ 以外で 使わない。
// 押した 瞬間 = soft ・ 押している 間 = カチ ×8(間隔 0.22→0.10 秒 ・ 強さ 0.25→0.85 ・ 鋭さ 0.4→0.8)+ うしろに ひと続きの 振動(0.1→0.5)
// ・ できた = rigid → 0.08 秒 あと success(`LTHaptics.Moment.lensDone`) ・ 途中で 離す = 0.15 秒で すっと 0。

/// 数字だけ(テストできる)。
enum LensChargeSpec {
    static let duration = 1.4
    static let tickCount = 8
    static let gapStart = 0.22, gapEnd = 0.10
    static let intensityStart: Float = 0.25, intensityEnd: Float = 0.85
    static let sharpnessStart: Float = 0.4, sharpnessEnd: Float = 0.8
    static let bedStart: Float = 0.1, bedEnd: Float = 0.5
    static let releaseFade = 0.15
    static let pressIntensity: CGFloat = 0.6
    static let doneGap = 0.08

    private static func lerp(_ a: Double, _ b: Double, _ i: Int) -> Double { a + (b - a) * Double(i) / Double(tickCount - 1) }
    private static func lerp(_ a: Float, _ b: Float, _ i: Int) -> Float { a + (b - a) * Float(i) / Float(tickCount - 1) }

    /// i 番めの カチと 次の カチの 間(i = 0 … tickCount-2)
    static func gap(_ i: Int) -> Double { gapStart + (gapEnd - gapStart) * Double(i) / Double(tickCount - 2) }
    static func tickTimes() -> [Double] {
        var t = 0.0, out = [0.0]
        for i in 0..<(tickCount - 1) { t += gap(i); out.append(t) }
        return out
    }
    static func intensity(_ i: Int) -> Float { lerp(intensityStart, intensityEnd, i) }
    static func sharpness(_ i: Int) -> Float { lerp(sharpnessStart, sharpnessEnd, i) }
}

@MainActor
enum LensCharge {
    private static var player: CHHapticAdvancedPatternPlayer?

    /// 押した 瞬間(soft)+ カチ カチ…を はじめる
    static func begin() {
        guard AppHapticsSetting.isEnabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: LensChargeSpec.pressIntensity * CGFloat(AppHapticsSetting.scale))
        stopNow()
        guard let engine = Haptics.sharedEngine() else { return }
        let k = AppHapticsSetting.scale
        var events: [CHHapticEvent] = LensChargeSpec.tickTimes().enumerated().map { i, t in
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: min(1, LensChargeSpec.intensity(i) * k)),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: LensChargeSpec.sharpness(i)),
            ], relativeTime: t)
        }
        events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
        ], relativeTime: 0, duration: LensChargeSpec.duration))
        let bed = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: 0, value: LensChargeSpec.bedStart * k), .init(relativeTime: LensChargeSpec.duration, value: LensChargeSpec.bedEnd * k),
        ], relativeTime: 0)
        guard let pattern = try? CHHapticPattern(events: events, parameterCurves: [bed]) else { return }
        try? engine.start()
        player = try? engine.makeAdvancedPlayer(with: pattern)
        try? player?.start(atTime: CHHapticTimeImmediate)
    }

    /// 途中で 離した / 中断された:0.15 秒で すっと 0 にして 止める(完了の ときも 同じ)
    static func end() {
        guard let p = player else { return }
        player = nil
        let fade = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: 0, value: 1), .init(relativeTime: LensChargeSpec.releaseFade, value: 0),
        ], relativeTime: 0)
        try? p.scheduleParameterCurve(fade, atTime: CHHapticTimeImmediate)
        try? p.stop(atTime: CHHapticTimeImmediate + LensChargeSpec.releaseFade)
    }

    private static func stopNow() { try? player?.stop(atTime: CHHapticTimeImmediate); player = nil }
}
