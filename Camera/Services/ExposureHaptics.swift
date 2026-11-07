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
        // 画面を とじる途中で メインを ふさがないよう、止めるのは 非同期で
        engine?.stop(completionHandler: { _ in })
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
                CHHapticEventParameter(parameterID: .hapticIntensity, value: min(1, intensity * AppHapticsSetting.scale)),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
    }

    private static func transientEvent(intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: min(1, intensity * AppHapticsSetting.scale)),
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
/// 設定の「バイブ」:つよめ(標準)/ ふつう / オフ。
/// 古い「触覚 ON/OFF」(hapticsEnabled)とも同じ値を書き、古い読み手(ExposureHaptics など)も止まるようにする。
enum AppHapticsSetting {
    enum Level: String, CaseIterable, Identifiable {
        case strong, normal, off
        var id: String { rawValue }
        var title: String {
            switch self {
            case .strong: return "つよめ"
            case .normal: return "ふつう"
            case .off: return "オフ"
            }
        }
        /// 強さの倍率
        var scale: Float {
            switch self {
            case .strong: return 1
            case .normal: return 0.65
            case .off: return 0
            }
        }
    }

    static let levelDefaultsKey = "hapticsLevel"

    static var level: Level {
        get {
            if let raw = UserDefaults.standard.string(forKey: levelDefaultsKey), let level = Level(rawValue: raw) { return level }
            // 古い設定で OFF にしていた人は、オフのまま
            let oldOn = UserDefaults.standard.object(forKey: ExposureHaptics.enabledDefaultsKey) as? Bool ?? true
            return oldOn ? .strong : .off
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: levelDefaultsKey)
            UserDefaults.standard.set(newValue != .off, forKey: ExposureHaptics.enabledDefaultsKey)
        }
    }

    static var scale: Float { level.scale }

    static var isEnabled: Bool {
        get { level != .off }
        set { level = newValue ? .strong : .off }
    }
}

extension UIImpactFeedbackGenerator {
    /// 設定の「触覚」が ON のときだけ鳴らす
    func impactOccurredIfEnabled() {
        guard AppHapticsSetting.isEnabled else { return }
        impactOccurred()
    }
}

extension UISelectionFeedbackGenerator {
    /// 設定の「触覚」が ON のときだけ鳴らす
    func selectionChangedIfEnabled() {
        guard AppHapticsSetting.isEnabled else { return }
        selectionChanged()
    }
}

extension UINotificationFeedbackGenerator {
    /// 設定の「触覚」が ON のときだけ鳴らす
    func notificationOccurredIfEnabled(_ type: FeedbackType) {
        guard AppHapticsSetting.isEnabled else { return }
        notificationOccurred(type)
    }
}

// MARK: - Haptics(v14:アプリ全体の触覚の辞書)

/// 画面側は名前だけ呼ぶ(`Haptics.play(.pop)`)。強さ・間隔は Tuning にまとめる(あとで調整する)。
/// 設定の「触覚」が OFF なら全部止める。CoreHaptics が使えない端末は、UIKit の Generator に自動で落とす。
@MainActor
enum Haptics {
    enum Kind: String, CaseIterable, Sendable {
        /// カリッ(つまみの1時間・ふる途中・タブ・リール・ページめくり)0.45 / 0.9
        case tick
        /// コツッ(やくそくを1枚めくる)0.6 / 0.75
        case detent
        /// ポンッ(チェキ・顔・つまむ・カードが出た)0.75 / 0.45
        case pop
        /// カチッ(「撮る」・21:00 をこえる・Mondo へ)0.8 / 0.65
        case click
        /// ドンッ(9:00 をこえる・タグ3つ目・月が変わる)1.0 / 0.25
        case thud
        /// ふわっ(はなした・もどる)0.35 / 0.3
        case soft
        /// トトッ(まだできないこと)0.6 × 2・0.07秒あけて
        case double
        /// どくん…(つつく・24:00 消灯)0.9 → 0.6
        case heart
        /// バンッ…(写真がひらく・つよく つつく)1.0 → 0 を 0.3秒で
        case burst
        /// ぐらぐら(小刻みに)
        case rumble
        /// パシャ(重 → 軽 → 余韻:0 / 40 / 80ms)
        case shutter
        /// ぽぽんっ(BUMP!・招待OK)0.6, 0.6, 1.0
        case success
        /// トン(チェキが物干しにとまる)0.85 / 0.3
        case land
        /// カタカタ(上映のはじまり)0.45 / 0.85、4回・46ms ごと
        case projector
        /// ブッ(タグ4つ目・13人目)
        case warn
    }

    /// 強さ・間隔の定数(実機で調整する)
    enum Tuning {
        typealias Beat = (time: TimeInterval, intensity: Float, sharpness: Float)
        /// 最短の間(秒)。これより早い2回目は鳴らさない
        static let gaps: [Kind: TimeInterval] = [.land: 0.1, .projector: 0.2, .tick: 0.055, .detent: 0.08, .pop: 0.09, .click: 0.1, .thud: 0.12, .soft: 0.08, .double: 0.2, .heart: 0.15, .burst: 0.25, .success: 0.25, .warn: 0.25]
        /// スクロールで鳴らす tick の最短の間
        static let scrollGap: TimeInterval = 0.07
        /// 長押し中の heart の間隔:520ms → 190ms
        static let heartIntervalRange: ClosedRange<TimeInterval> = 0.19...0.52

        /// v17 の表(強さ / するどさ)
        static func beats(_ kind: Kind) -> [Beat] {
            switch kind {
            case .tick: return [(0, 0.45, 0.9)]
            case .detent: return [(0, 0.6, 0.75)]
            case .pop: return [(0, 0.75, 0.45)]
            case .click: return [(0, 0.8, 0.65)]
            case .thud: return [(0, 1.0, 0.25)]
            case .soft: return [(0, 0.35, 0.3)]
            case .double: return [(0, 0.6, 0.5), (0.07, 0.6, 0.5)]
            case .heart: return [(0, 0.9, 0.35), (0.13, 0.6, 0.25)]
            case .burst: return [(0, 1.0, 0.6), (0.06, 0.75, 0.5), (0.13, 0.5, 0.4), (0.2, 0.28, 0.3), (0.3, 0.08, 0.2)]
            case .rumble: return [(0, 0.7, 0.6), (0.03, 0.6, 0.6), (0.06, 0.7, 0.6), (0.09, 0.55, 0.6), (0.12, 0.65, 0.6)]
            // 撮れた瞬間:1.0 / 0.9 → 0.7 / 0.5(0.07秒あけて)
            case .shutter: return [(0, 1.0, 0.9), (0.07, 0.7, 0.5)]
            case .land: return [(0, 0.85, 0.3)]
            case .projector: return [(0, 0.45, 0.85), (0.046, 0.45, 0.85), (0.092, 0.45, 0.85), (0.138, 0.45, 0.85)]
            case .success: return [(0, 0.6, 0.5), (0.1, 0.6, 0.5), (0.22, 1.0, 0.6)]
            case .warn: return [(0, 0.8, 0.55), (0.09, 0.8, 0.55)]
            }
        }

        /// 長押しでためる(連続):強さ 0.15 → 1.0 / するどさ 0.3 → 0.8
        static let rampIntensity: ClosedRange<Float> = 0.15...1.0
        static let rampSharpness: ClosedRange<Float> = 0.3...0.8
    }

    static var isEnabled: Bool { AppHapticsSetting.isEnabled }

    private static var last: [Kind: Date] = [:]
    private static let selection = UISelectionFeedbackGenerator()
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let softGen = UIImpactFeedbackGenerator(style: .soft)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notify = UINotificationFeedbackGenerator()
    private static let supportsCore = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private static var engine: CHHapticEngine?

    /// 操作の直前に呼ぶ(最初の1回が遅れないように)
    static func prepare(_ kind: Kind? = nil) {
        guard isEnabled else { return }
        startEngine()
        if !supportsCore { selection.prepare(); light.prepare(); softGen.prepare(); rigid.prepare() }
    }

    /// 鳴らす。gap を渡すと、その間隔で間引く(省略時は Tuning.gaps)。intensity は表の強さへの倍率
    static func play(_ kind: Kind, gap: TimeInterval? = nil, intensity: Float = 1) {
        guard isEnabled else { return }
        let now = Date()
        if let gap = gap ?? Tuning.gaps[kind], let previous = last[kind], now.timeIntervalSince(previous) < gap { return }
        last[kind] = now
        let scale = intensity * AppHapticsSetting.scale
        if playCore(Tuning.beats(kind), scale: scale) { return }
        fallback(kind, scale: scale)
    }

    /// 1回だけの 短い脈(強さ・鋭さを 指定)。動画の 録画中の 脈・「ピッ」に 使う
    static func pulse(intensity: Float, sharpness: Float) {
        guard isEnabled else { return }
        let scale = AppHapticsSetting.scale
        if playCore([(0, intensity, sharpness)], scale: scale) { return }
        let k = CGFloat(min(1, intensity * scale))
        if sharpness >= 0.7 { rigid.impactOccurred(intensity: k); rigid.prepare() } else { softGen.impactOccurred(intensity: k); softGen.prepare() }
    }

    /// 長押しの強さ(0〜1)から、つぎの heart までの間隔(520ms → 190ms)
    nonisolated static func heartInterval(progress: Double) -> TimeInterval {
        let p = min(1, max(0, progress))
        return Tuning.heartIntervalRange.upperBound - (Tuning.heartIntervalRange.upperBound - Tuning.heartIntervalRange.lowerBound) * p
    }

    /// 間引きの記録を消す(テスト用)
    static func resetForTesting() { last = [:] }

    fileprivate static func sharedEngine() -> CHHapticEngine? {
        startEngine()
        return engine
    }

    private static func startEngine() {
        guard supportsCore, engine == nil else { return }
        do {
            let made = try CHHapticEngine()
            made.isAutoShutdownEnabled = true
            made.resetHandler = { Task { @MainActor in try? Haptics.engine?.start() } }
            try made.start()
            engine = made
        } catch {
            engine = nil
        }
    }

    /// CoreHaptics で鳴らす。鳴らせたら true
    private static func playCore(_ beats: [Tuning.Beat], scale: Float) -> Bool {
        startEngine()
        guard let engine else { return false }
        let events = beats.map { beat in
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: min(1, beat.intensity * scale)),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: beat.sharpness),
            ], relativeTime: beat.time)
        }
        guard let pattern = try? CHHapticPattern(events: events, parameters: []),
              let player = try? engine.makePlayer(with: pattern) else { return false }
        try? engine.start()
        return (try? player.start(atTime: CHHapticTimeImmediate)) != nil
    }

    /// CoreHaptics が使えないとき:UIKit の Generator で近いものを
    private static func fallback(_ kind: Kind, scale: Float) {
        let k = CGFloat(scale)
        switch kind {
        case .tick, .detent: selection.selectionChanged(); selection.prepare()
        case .pop: light.impactOccurred(intensity: k); light.prepare()
        case .click: medium.impactOccurred(intensity: k); medium.prepare()
        case .thud: rigid.impactOccurred(intensity: k); rigid.prepare()
        case .soft: softGen.impactOccurred(intensity: k); softGen.prepare()
        case .success: notify.notificationOccurred(.success); notify.prepare()
        case .warn: notify.notificationOccurred(.warning); notify.prepare()
        default:
            for beat in Tuning.beats(kind) {
                let value = CGFloat(min(1, beat.intensity * scale))
                if beat.time == 0 { heavy.impactOccurred(intensity: value) }
                else { DispatchQueue.main.asyncAfter(deadline: .now() + beat.time) { heavy.impactOccurred(intensity: value) } }
            }
        }
    }
}

/// 長押しでためるあいだの、連続した振動(ramp)。level(0〜1)に合わせて強さ・するどさが上がる。
/// CoreHaptics が使えない端末では、間をつめながら UIKit の Generator を鳴らす。
@MainActor
final class HapticRamp {
    private var player: CHHapticAdvancedPatternPlayer?
    private var fallbackTimer: Timer?
    private var level: Float = 0
    private let generator = UIImpactFeedbackGenerator(style: .medium)

    nonisolated init() {}

    var isRunning: Bool { player != nil || fallbackTimer != nil }

    func start() {
        stop()
        guard Haptics.isEnabled else { return }
        level = 0
        if let engine = Haptics.sharedEngine() {
            let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
            ], relativeTime: 0, duration: 30)
            if let pattern = try? CHHapticPattern(events: [event], parameters: []),
               let made = try? engine.makeAdvancedPlayer(with: pattern) {
                try? engine.start()
                if (try? made.start(atTime: CHHapticTimeImmediate)) != nil {
                    player = made
                    update(0)
                    return
                }
            }
        }
        generator.prepare()
        scheduleFallback()
    }

    /// 0〜1
    func update(_ value: Double) {
        level = Float(min(1, max(0, value)))
        guard let player else { return }
        let i = Haptics.Tuning.rampIntensity, s = Haptics.Tuning.rampSharpness
        let intensity = (i.lowerBound + (i.upperBound - i.lowerBound) * level) * AppHapticsSetting.scale
        let sharpness = s.lowerBound + (s.upperBound - s.lowerBound) * level
        try? player.sendParameters([
            CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: intensity, relativeTime: 0),
            CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: sharpness, relativeTime: 0),
        ], atTime: CHHapticTimeImmediate)
    }

    func stop() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }

    private func scheduleFallback() {
        let interval = 0.2 - 0.13 * Double(level)
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.fallbackTimer != nil else { return }
                let i = Haptics.Tuning.rampIntensity
                self.generator.impactOccurred(intensity: CGFloat((i.lowerBound + (i.upperBound - i.lowerBound) * self.level) * AppHapticsSetting.scale))
                self.scheduleFallback()
            }
        }
    }
}
