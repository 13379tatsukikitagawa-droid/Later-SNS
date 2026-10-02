import CoreHaptics
import UIKit

/// Laterの触覚(Core Haptics)。撮影画面で振動させるのは2か所だけ:
/// ① 長押し中 … 連続振動が1.5秒かけてだんだん強くなる
/// ② 撮れた瞬間 … くっきり1回だけ(単発)
/// それ以外(構えている間・途中で離した時)は一切振動させない。
/// 初回設定(オンボーディング)も同じエンジンを使い、単発・弱い上昇などを追加で鳴らす。
///
/// 触覚に対応していない端末(iPadなど)や、アプリ側で触覚をOFFにしている場合は
/// 何もしない(見た目だけで同じ流れになる)。強さ・鋭さは実機で触って決め直す前提の初期値。
@MainActor
final class ExposureHaptics {
    /// 実機で調整するための数値。
    enum Tuning {
        static let holdIntensity: ClosedRange<Float> = 0.15...0.85
        static let holdSharpness: ClosedRange<Float> = 0.2...0.55
        static let captureIntensity: Float = 1.0
        static let captureSharpness: Float = 0.9
        /// 長押し中の上がり方の曲線を何点で近似するか(点の間は直線補間される)。
        static let curveSteps = 8
    }

    /// アプリ側の触覚設定(UserDefaults)。未設定ならON。
    static let enabledDefaultsKey = "hapticsEnabled"

    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?
    private var holdPlayer: CHHapticAdvancedPatternPlayer?
    private var isEngineRunning = false
    private var foregroundObserver: NSObjectProtocol?

    private var isEnabled: Bool {
        supportsHaptics && (UserDefaults.standard.object(forKey: Self.enabledDefaultsKey) as? Bool ?? true)
    }

    /// 撮影画面を開いた時点で呼び、長押しの瞬間に起動待ちが発生しないようにする。
    func prepare() {
        guard isEnabled, engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = false
            engine.stoppedHandler = { [weak self] _ in
                Task { @MainActor in self?.isEngineRunning = false }
            }
            engine.resetHandler = { [weak self] in
                Task { @MainActor in
                    self?.isEngineRunning = false
                    self?.holdPlayer = nil
                    self?.startEngineIfNeeded()
                }
            }
            self.engine = engine
            startEngineIfNeeded()
        } catch {
            print("[ExposureHaptics] エンジンを作成できませんでした: \(error)")
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.startEngineIfNeeded() }
        }
    }

    func tearDown() {
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
        foregroundObserver = nil
        try? holdPlayer?.stop(atTime: CHHapticTimeImmediate)
        holdPlayer = nil
        engine?.stop()
        engine = nil
        isEngineRunning = false
    }

    /// 長押しの開始と同時に呼ぶ。
    func beginHold(duration: TimeInterval) {
        guard isEnabled, let engine else { return }
        startEngineIfNeeded()
        do {
            let player = try engine.makeAdvancedPlayer(with: Self.holdPattern(duration: duration))
            holdPlayer = player
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[ExposureHaptics] 長押しの振動を再生できませんでした: \(error)")
        }
    }

    /// 途中で離した時に呼ぶ。専用の振動は付けず、すっと止めるだけ。
    func cancelHold() {
        try? holdPlayer?.stop(atTime: CHHapticTimeImmediate)
        holdPlayer = nil
    }

    /// 撮影の瞬間に呼ぶ(撮影処理と同じタイミングで鳴らすため、呼び出し側は
    /// capturePhotoの直前に呼ぶ)。tailを渡すと、くっきり1回のあとに弱まっていく余韻を足す。
    func fireCapture(
        intensity: Float? = nil,
        sharpness: Float? = nil,
        tail: (intensity: Float, duration: TimeInterval)? = nil
    ) {
        cancelHold()
        var events = [Self.transientEvent(
            intensity: intensity ?? Tuning.captureIntensity,
            sharpness: sharpness ?? Tuning.captureSharpness
        )]
        var curves: [CHHapticParameterCurve] = []
        if let tail {
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: tail.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
                ],
                relativeTime: 0.02,
                duration: tail.duration
            ))
            curves.append(CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [.init(relativeTime: 0, value: 1), .init(relativeTime: tail.duration, value: 0)],
                relativeTime: 0.02
            ))
        }
        play(events: events, curves: curves, label: "撮影時")
    }

    /// 単発の軽い振動(初回設定のボタン・タグ選択・タイプなど)。
    func playTransient(intensity: Float, sharpness: Float) {
        play(events: [Self.transientEvent(intensity: intensity, sharpness: sharpness)], curves: [], label: "単発")
    }

    /// 弱い連続振動を、指定の強さまでゆっくり上げる(初回設定の開幕で絞りが開く時・プロフィール画像の現像)。
    /// sharpnessToを渡すと、鋭さもsharpnessからsharpnessToへ上げる。
    func playRamp(from start: Float, to end: Float, sharpness: Float, sharpnessTo: Float? = nil, duration: TimeInterval) {
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0,
            duration: duration
        )
        var curves = [CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [.init(relativeTime: 0, value: start), .init(relativeTime: duration, value: end)],
            relativeTime: 0
        )]
        if let sharpnessTo {
            curves.append(CHHapticParameterCurve(
                parameterID: .hapticSharpnessControl,
                controlPoints: [.init(relativeTime: 0, value: 0), .init(relativeTime: duration, value: sharpnessTo - sharpness)],
                relativeTime: 0
            ))
        }
        play(events: [event], curves: curves, label: "上昇")
    }

    private static func transientEvent(intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0
        )
    }

    private func play(events: [CHHapticEvent], curves: [CHHapticParameterCurve], label: String) {
        guard isEnabled, let engine else { return }
        startEngineIfNeeded()
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[ExposureHaptics] \(label)の振動を再生できませんでした: \(error)")
        }
    }

    private func startEngineIfNeeded() {
        guard let engine, !isEngineRunning else { return }
        do {
            try engine.start()
            isEngineRunning = true
        } catch {
            print("[ExposureHaptics] エンジンを起動できませんでした: \(error)")
        }
    }

    /// 連続振動(長さ=duration)の上に、強さ・鋭さをゆるやかに上げるカーブを重ねる。
    /// 強さ(hapticIntensityControl)はイベント側の強さ1.0への掛け算、鋭さ
    /// (hapticSharpnessControl)はイベント側の鋭さ0への足し算として効く。
    private static func holdPattern(duration: TimeInterval) throws -> CHHapticPattern {
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.0),
            ],
            relativeTime: 0,
            duration: duration
        )
        let steps = Tuning.curveSteps
        func points(_ range: ClosedRange<Float>) -> [CHHapticParameterCurve.ControlPoint] {
            (0...steps).map { index in
                let t = Float(index) / Float(steps)
                // ease-in-out(sin)で、急に強くならずゆるやかに上がる。
                let eased = (1 - cos(t * .pi)) / 2
                let value = range.lowerBound + (range.upperBound - range.lowerBound) * eased
                return .init(relativeTime: duration * TimeInterval(t), value: value)
            }
        }
        let intensityCurve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl, controlPoints: points(Tuning.holdIntensity), relativeTime: 0
        )
        let sharpnessCurve = CHHapticParameterCurve(
            parameterID: .hapticSharpnessControl, controlPoints: points(Tuning.holdSharpness), relativeTime: 0
        )
        return try CHHapticPattern(events: [event], parameterCurves: [intensityCurve, sharpnessCurve])
    }
}
