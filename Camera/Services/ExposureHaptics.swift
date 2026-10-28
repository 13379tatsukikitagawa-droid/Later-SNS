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

    /// 長押しの開始と同時に呼ぶ。intensity・sharpnessを渡すと、その範囲でじわっと上げる
    /// (省略時は撮影の値)。
    func beginHold(
        duration: TimeInterval,
        intensity: ClosedRange<Float> = Tuning.holdIntensity,
        sharpness: ClosedRange<Float> = Tuning.holdSharpness
    ) {
        guard isEnabled, let engine else { return }
        startEngineIfNeeded()
        do {
            let player = try engine.makeAdvancedPlayer(with: Self.holdPattern(duration: duration, intensity: intensity, sharpness: sharpness))
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

    /// 起動アニメーション(morning):t=150〜1350msにContinuousでじわっと強く(0.08→0.45、鋭さ0.2)
    /// → t=1350ms(光の球ができる瞬間)にTransientで弱く1回(0.5、鋭さ0.4)。
    /// speed は低電力モードの倍速。cancelHold() ですぐ止まる。
    func playLaunchMorning(speed: Double = 1) {
        guard isEnabled, let engine else { return }
        startEngineIfNeeded()
        let begin = 0.15 / speed, end = 1.35 / speed
        let duration = end - begin
        let continuous = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
            ],
            relativeTime: begin,
            duration: duration
        )
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [.init(relativeTime: 0, value: 0.08), .init(relativeTime: duration, value: 0.45)],
            relativeTime: begin
        )
        do {
            let pattern = try CHHapticPattern(
                events: [continuous, Self.transientEvent(intensity: 0.5, sharpness: 0.4, at: end)],
                parameterCurves: [curve]
            )
            let player = try engine.makeAdvancedPlayer(with: pattern)
            holdPlayer = player
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[ExposureHaptics] 起動の振動を再生できませんでした: \(error)")
        }
    }

    /// ロック中の操作:やわらかく2回(強さ0.4・鋭さ0.2、間90ms)
    func playSoftDouble() {
        play(events: [
            Self.transientEvent(intensity: 0.4, sharpness: 0.2),
            Self.transientEvent(intensity: 0.4, sharpness: 0.2, at: 0.09),
        ], curves: [], label: "ロック")
    }

    /// 灯をともす:soft 0.45 → 50ms後 → medium 0.7(LampRules.placeHaptic)
    func playLampPlace() {
        play(events: LampRules.placeHaptic.map { Self.transientEvent(intensity: $0.intensity, sharpness: $0.sharpness, at: $0.at) }, curves: [], label: "灯")
    }

    /// 灯を取り消す:light 1回
    func playLampCancel() {
        play(events: LampRules.cancelHaptic.map { Self.transientEvent(intensity: $0.intensity, sharpness: $0.sharpness, at: $0.at) }, curves: [], label: "灯を消す")
    }

    /// Home v5 の触覚(HomeHapticPattern の「鳴らす長さ・あき」のならび)。単発のつなぎで鳴らす。
    func playPattern(_ pattern: [Int], sharpness: Float = 0.4) {
        let events = HomeHapticPattern.pulses(pattern).map {
            Self.transientEvent(intensity: $0.intensity, sharpness: sharpness, at: $0.time)
        }
        guard !events.isEmpty else { return }
        play(events: events, curves: [], label: "Home")
    }

    /// 鼓動1拍:「ドクン(強さ0.55)→ ドク(強さ0.3)」
    func playHeartbeat() {
        play(events: [
            Self.transientEvent(intensity: 0.55, sharpness: 0.25),
            Self.transientEvent(intensity: 0.3, sharpness: 0.2, at: 0.16),
        ], curves: [], label: "鼓動")
    }

    /// 現像の早送り:さらさらと弱く始まり、少し強く → 最後にトンと弱く1回
    func playDevelopRustle(duration: TimeInterval, peak: Float) {
        let grains = max(1, Int(duration / 0.06))
        var events: [CHHapticEvent] = []
        for i in 0..<grains {
            let u = Float(i) / Float(grains)
            events.append(Self.transientEvent(intensity: 0.08 + (peak - 0.08) * u * u, sharpness: 0.7, at: Double(i) * 0.06))
        }
        events.append(Self.transientEvent(intensity: 0.4, sharpness: 0.3, at: duration + 0.05))
        play(events: events, curves: [], label: "早送り")
    }

    private static func transientEvent(intensity: Float, sharpness: Float, at time: TimeInterval) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
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
    private static func holdPattern(
        duration: TimeInterval,
        intensity: ClosedRange<Float>,
        sharpness: ClosedRange<Float>
    ) throws -> CHHapticPattern {
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
            parameterID: .hapticIntensityControl, controlPoints: points(intensity), relativeTime: 0
        )
        let sharpnessCurve = CHHapticParameterCurve(
            parameterID: .hapticSharpnessControl, controlPoints: points(sharpness), relativeTime: 0
        )
        return try CHHapticPattern(events: [event], parameterCurves: [intensityCurve, sharpnessCurve])
    }
}

// MARK: - アプリ全体の触覚の ON/OFF

/// 設定の「触覚」。OFF のときは、撮る・ひらく・えらぶ も含めて、アプリ全体で鳴らさない。
enum AppHapticsSetting {
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: ExposureHaptics.enabledDefaultsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: ExposureHaptics.enabledDefaultsKey) }
    }
}

extension UIImpactFeedbackGenerator {
    /// 設定の「触覚」が ON のときだけ鳴らす
    func impactOccurredIfEnabled() {
        guard AppHapticsSetting.isEnabled else { return }
        impactOccurred()
    }
}

extension UINotificationFeedbackGenerator {
    /// 設定の「触覚」が ON のときだけ鳴らす
    func notificationOccurredIfEnabled(_ type: FeedbackType) {
        guard AppHapticsSetting.isEnabled else { return }
        notificationOccurred(type)
    }
}
