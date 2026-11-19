// 参考(形の 見本)・ そのまま コピー しない。PROMPT_v100.md が 正解。名前は 今の プロジェクトに 合わせる。
import CoreHaptics
import SwiftUI
import QuartzCore

enum HapticKind: String, CaseIterable {
    case tick, sel, pop, click, soft, thud, warn, success, shutter, land, heart, projector, buzz, rumble, vui   // v42〜
    case notch, edge, stretch, knock, sig                                                                   // v100
    /// 「ひかえめ」で 鳴らさない(さわる 段)
    var isTouchLevel: Bool { [.tick, .soft, .notch, .edge, .stretch, .knock].contains(self) }
    /// 種類ごとの 最小の 間(秒)
    var minGap: CFTimeInterval { self == .notch ? 0.055 : (self == .knock ? 0.12 : 0) }
}

enum HapticLevel: String { case full, low, off }

@MainActor
final class Haptics {
    static let shared = Haptics()
    private var engine: CHHapticEngine?
    private var players: [HapticKind: CHHapticPatternPlayer] = [:]
    private var lastAny: CFTimeInterval = 0
    private var last: [HapticKind: CFTimeInterval] = [:]
    var isRecordingVideo = false                       // 録画中は 鳴らさない(マイクに 入る)

    var level: HapticLevel {
        get { HapticLevel(rawValue: UserDefaults.standard.string(forKey: "hapticLevel") ?? "") ?? .full }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "hapticLevel") }
    }

    static func play(_ k: HapticKind) { shared.play(k) }

    func prepare() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let e = try CHHapticEngine()
            e.playsHapticsOnly = true
            e.isAutoShutdownEnabled = true
            e.resetHandler = { [weak self] in Task { @MainActor in try? self?.engine?.start(); self?.players = [:] } }
            try e.start()
            engine = e
        } catch { engine = nil }
    }

    func play(_ k: HapticKind) {
        guard level != .off, !(level == .low && k.isTouchLevel), !isRecordingVideo, let engine else { return }
        let now = CACurrentMediaTime()
        if now - lastAny < 0.04 { return }                               // 全体で 40ms に 1回
        if let t = last[k], now - t < k.minGap { return }
        lastAny = now; last[k] = now
        do {
            let p = try players[k] ?? engine.makePlayer(with: try Self.pattern(k))
            players[k] = p
            try p.start(atTime: CHHapticTimeImmediate)
        } catch { }
    }

    // ---- パターン(spec/HAPTICS.md ・ spec/HAPTICS_patterns.png と 同じ 値)----
    private static func T(_ t: TimeInterval, _ i: Float, _ s: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient,
                      parameters: [.init(parameterID: .hapticIntensity, value: i), .init(parameterID: .hapticSharpness, value: s)],
                      relativeTime: t)
    }
    private static func C(_ t: TimeInterval, _ d: TimeInterval, _ i: Float, _ s: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous,
                      parameters: [.init(parameterID: .hapticIntensity, value: i), .init(parameterID: .hapticSharpness, value: s)],
                      relativeTime: t, duration: d)
    }
    static func pattern(_ k: HapticKind) throws -> CHHapticPattern {
        switch k {
        case .tick:      return try .init(events: [T(0, 0.35, 0.6)], parameters: [])
        case .sel:       return try .init(events: [T(0, 0.5, 0.7)], parameters: [])
        case .pop:       return try .init(events: [T(0, 0.7, 0.35)], parameters: [])
        case .click:     return try .init(events: [T(0, 0.65, 0.9)], parameters: [])
        case .soft:      return try .init(events: [T(0, 0.3, 0.2)], parameters: [])
        case .thud:      return try .init(events: [T(0, 1.0, 0.3)], parameters: [])
        case .warn:      return try .init(events: [T(0, 0.8, 0.4), T(0.09, 0.8, 0.4)], parameters: [])
        case .success:   return try .init(events: [T(0, 0.9, 0.5), T(0.08, 0.9, 0.5), T(0.16, 1.0, 0.4)], parameters: [])
        case .shutter:   return try .init(events: [T(0, 1.0, 0.9), T(0.07, 0.8, 0.5)], parameters: [])
        case .land:      return try .init(events: [T(0, 0.85, 0.4)], parameters: [])
        case .heart:     return try .init(events: [T(0, 0.9, 0.3), T(0.1, 0.55, 0.3)], parameters: [])
        case .projector: return try .init(events: (0..<4).map { T(Double($0) * 0.046, 0.45, 0.8) }, parameters: [])
        case .buzz:      return try .init(events: [C(0, 0.12, 0.75, 0.5)], parameters: [])
        case .rumble:    return try .init(events: [C(0, 0.2, 1.0, 0.4)] + (0..<6).map { T(Double($0) * 0.035, 0.9, 0.6) }, parameters: [])
        case .vui:
            let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl,
                                               controlPoints: [.init(relativeTime: 0, value: 0.3), .init(relativeTime: 0.32, value: 1.0)],
                                               relativeTime: 0)
            return try .init(events: [T(0, 1.0, 0.7), C(0, 0.32, 1.0, 0.5)], parameterCurves: [curve])
        case .notch:     return try .init(events: [T(0, 0.22, 0.9)], parameters: [])
        case .edge:      return try .init(events: [T(0, 0.45, 0.1)], parameters: [])
        case .stretch:   return try .init(events: [T(0, 0.3, 0.2)], parameters: [])
        case .knock:     return try .init(events: [T(0, 0.4, 0.8), T(0.07, 0.4, 0.8)], parameters: [])
        case .sig:       return try .init(events: [T(0, 0.7, 0.35), T(0.11, 0.5, 0.8), T(0.18, 0.8, 0.3)], parameters: [])
        }
    }
}

// ---- スクロールの きざみ(iOS 18 の 形 ・ 17 は PreferenceKey で 同じ ことを する)----
struct HapticSection: Equatable { var minY: CGFloat; var locked: Bool }

struct ScrollHaptics: ViewModifier {
    var sections: [HapticSection]                 // コンテンツ 座標の 上の はし(onGeometryChange で 集める)
    @State private var index = -1
    @State private var lastLine: CGFloat = 0
    @State private var lastTime = CACurrentMediaTime()
    @State private var atEdge = true
    @State private var stretchStep = 0

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: ScrollGeometry.self, of: { $0 }) { _, g in
            let y = g.contentOffset.y + g.contentInsets.top
            let line = y + g.containerSize.height * 0.35
            let now = CACurrentMediaTime()
            let speed = abs(line - lastLine) / max(0.001, now - lastTime)     // pt/秒
            lastLine = line; lastTime = now
            // 1. 区切り
            let i = sections.lastIndex { $0.minY <= line } ?? -1
            if i != index {
                let crossed = sections[safe: max(i, index)]
                index = i
                if speed < 2400, let c = crossed { Haptics.play(c.locked ? .knock : .notch) }
            }
            // 2. はじ と ひっぱり
            let maxY = g.contentSize.height - g.containerSize.height + g.contentInsets.top + g.contentInsets.bottom
            let over = y < 0 ? -y : (y > maxY ? y - maxY : 0)
            let step = min(3, Int(over / 30))
            if step > stretchStep { Haptics.play(.stretch) }
            if step == 0 && stretchStep > 0 { Haptics.play(.soft) }
            stretchStep = step
            let edge = y <= 0 || y >= maxY - 1
            if edge && !atEdge && speed > 450 { Haptics.play(.edge) }
            if y > 24 && y < maxY - 24 { atEdge = false } else if edge { atEdge = true }
        }
    }
}
private extension Array { subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil } }
extension View { func scrollHaptics(_ s: [HapticSection]) -> some View { modifier(ScrollHaptics(sections: s)) } }
