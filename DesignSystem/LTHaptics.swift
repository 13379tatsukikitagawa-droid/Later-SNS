import UIKit
import CoreHaptics

// v134 Phase 1:触感。新しい エンジンは 作らない。既存の `Haptics`(辞書)と `HapticRamp`(長押しの だんだん 強く)を 使い、
// 設定の「バイブ」(`AppHapticsSetting`)に 従う。大事な 瞬間 だけ。スクロールでは 鳴らさない。同じ パターンを 別の 意味で 使わない。

@MainActor
enum LTHaptics {
    enum Moment {
        case select     // タグを えらぶ・きりかえ:コツ
        case tap        // ふつうの ボタン:トン
        case shutter    // 撮れた:カシャッ
        case land       // フィルムに 入った:トン
        case lightsOn   // 9:00 あかり:ふわ×3 → ふくらむ
        case opened     // ひらいた:トトトン
        case posted     // のせた:トトン
        case warning    // できない:トン、トン
        case enter      // はじめる:ブイッ
        case lensPress  // v136 レンズを 押した:ふにっ(soft)
        case lensDone   // v136 レンズの 長押しが できた:パキッ(rigid)→ 0.08秒 あと success。`opened`(9:00 に ひらく)とは 別の 意味なので 別の case
    }

    static func play(_ m: Moment) {
        guard AppHapticsSetting.isEnabled else { return }
        switch m {
        case .select: Haptics.play(.sel)
        case .tap: Haptics.play(.tick)
        case .shutter: Haptics.play(.shutter)
        case .land: Haptics.play(.land)
        case .opened, .posted: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning: Haptics.play(.double)
        case .lightsOn: playPattern(lightsOnPattern)
        case .lensPress:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: LensChargeSpec.pressIntensity * CGFloat(AppHapticsSetting.scale))
        case .lensDone:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: CGFloat(AppHapticsSetting.scale))
            DispatchQueue.main.asyncAfter(deadline: .now() + LensChargeSpec.doneGap) { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        case .enter:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: CGFloat(AppHapticsSetting.scale))
            playPattern { try continuous(duration: 0.35, intensity: 1, sharpness: 0.2, at: 0.05) }
        }
    }

    // MARK: 長押し(撮る 1.5秒・ひらく おさえている 間・はじめる 1.6秒)

    private static let ramp = HapticRamp()
    static func beginHold() { ramp.start() }
    /// progress: 0〜1
    static func updateHold(progress: Double) { ramp.update(progress) }
    static func endHold() { ramp.stop() }

    // MARK: パターン

    private static func playPattern(_ make: () throws -> CHHapticPattern) {
        guard let engine = Haptics.sharedEngine(), let pattern = try? make() else { return }
        try? engine.start()
        if let player = try? engine.makePlayer(with: pattern) { try? player.start(atTime: CHHapticTimeImmediate) }
    }

    /// ふわ・ふわ・ふわ(0.12秒 おき)→ 0.8秒 かけて ふくらんで 消える
    private static func lightsOnPattern() throws -> CHHapticPattern {
        var events: [CHHapticEvent] = (0..<3).map { i in
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
            ], relativeTime: Double(i) * 0.12)
        }
        events.append(continuousEvent(duration: 0.8, intensity: 1, sharpness: 0.15, at: 0.42))
        let swell = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: 0.42, value: 0.2), .init(relativeTime: 0.90, value: 0.7), .init(relativeTime: 1.22, value: 0),
        ], relativeTime: 0)
        return try CHHapticPattern(events: events, parameterCurves: [swell])
    }

    private static func continuous(duration: Double, intensity: Float, sharpness: Float, at t: Double) throws -> CHHapticPattern {
        try CHHapticPattern(events: [continuousEvent(duration: duration, intensity: intensity, sharpness: sharpness, at: t)], parameters: [])
    }

    private static func continuousEvent(duration: Double, intensity: Float, sharpness: Float, at t: Double) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: t, duration: duration)
    }
}
