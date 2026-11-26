import UIKit
import CoreHaptics

// Lattag v133 の触感（参考実装）
// ルール
// ・大事な瞬間だけ。スクロールでは振動させない
// ・同じパターンを別の意味で使わない
// ・設定でオフにできる（UserDefaults "hapticsEnabled"）

@MainActor
final class LattagHaptics {
    static let shared = LattagHaptics()

    enum Moment {
        case select    // タグをえらぶ：コツ
        case tap       // ふつうのボタン：トン
        case react     // #で返す：ポン
        case shutter   // 撮れた：カシャッ
        case land      // フィルムに入った：トン
        case lightsOn  // 9:00 あかり：ふわ×3 → ふくらむ
        case opened    // ひらいた：トトトン
        case posted    // のせた：トトン
        case warning   // できない：トン、トン
        case enter     // はじめる：ブイッ
        case shake     // ふってつながる：ブルブル
    }

    private var engine: CHHapticEngine?
    private var holdPlayer: CHHapticAdvancedPatternPlayer?

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    private init() { prepareEngine() }

    private func prepareEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let e = try CHHapticEngine()
            e.isAutoShutdownEnabled = true
            e.resetHandler = { [weak e] in try? e?.start() }
            try e.start()
            engine = e
        } catch {
            engine = nil
        }
    }

    func play(_ m: Moment) {
        guard isEnabled else { return }
        switch m {
        case .select:
            UISelectionFeedbackGenerator().selectionChanged()
        case .tap:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .react:
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
        case .shutter:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
            }
        case .land:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .opened, .posted:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .lightsOn:
            playPattern { try Self.lightsOnPattern() }
        case .enter:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            playPattern { try Self.continuous(duration: 0.35, intensity: 1.0, sharpness: 0.2, at: 0.05) }
        case .shake:
            playPattern {
                try CHHapticPattern(events: [
                    Self.continuousEvent(duration: 0.5, intensity: 0.8, sharpness: 0.5, at: 0),
                    Self.continuousEvent(duration: 0.5, intensity: 0.8, sharpness: 0.5, at: 0.62)
                ], parameters: [])
            }
        }
    }

    // MARK: 長押し（Opal の Hold）：進み具合に合わせて、だんだん強く・鋭く
    // 撮る（1.5秒）・ひらく（おさえている間）・はじめる（1.6秒）で使う

    func beginHold() {
        guard isEnabled, let engine else { return }
        do {
            let pattern = try CHHapticPattern(events: [
                Self.continuousEvent(duration: 30, intensity: 1.0, sharpness: 0.5, at: 0)
            ], parameters: [])
            let p = try engine.makeAdvancedPlayer(with: pattern)
            try p.start(atTime: CHHapticTimeImmediate)
            holdPlayer = p
            updateHold(progress: 0)
        } catch {
            holdPlayer = nil
        }
    }

    /// progress: 0〜1
    func updateHold(progress: Double) {
        guard let holdPlayer else { return }
        let p = Float(max(0, min(1, progress)))
        try? holdPlayer.sendParameters([
            CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: 0.15 + 0.85 * p, relativeTime: 0),
            CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: 0.3 + 0.5 * p, relativeTime: 0)
        ], atTime: CHHapticTimeImmediate)
    }

    func endHold() {
        try? holdPlayer?.stop(atTime: CHHapticTimeImmediate)
        holdPlayer = nil
    }

    // MARK: パターン

    private func playPattern(_ make: () throws -> CHHapticPattern) {
        guard let engine else { return }
        do {
            let player = try engine.makePlayer(with: try make())
            try player.start(atTime: CHHapticTimeImmediate)
        } catch { }
    }

    /// 9:00 あかり：ふわ・ふわ・ふわ（0.12秒おき）→ 0.8秒かけてふくらんで消える
    private static func lightsOnPattern() throws -> CHHapticPattern {
        var events: [CHHapticEvent] = (0..<3).map { i in
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ], relativeTime: Double(i) * 0.12)
        }
        events.append(continuousEvent(duration: 0.8, intensity: 1.0, sharpness: 0.15, at: 0.42))
        let swell = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: 0.42, value: 0.2),
            .init(relativeTime: 0.90, value: 0.7),
            .init(relativeTime: 1.22, value: 0.0)
        ], relativeTime: 0)
        return try CHHapticPattern(events: events, parameterCurves: [swell])
    }

    private static func continuous(duration: Double, intensity: Float, sharpness: Float, at t: Double) throws -> CHHapticPattern {
        try CHHapticPattern(events: [continuousEvent(duration: duration, intensity: intensity, sharpness: sharpness, at: t)], parameters: [])
    }

    private static func continuousEvent(duration: Double, intensity: Float, sharpness: Float, at t: Double) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ], relativeTime: t, duration: duration)
    }
}
