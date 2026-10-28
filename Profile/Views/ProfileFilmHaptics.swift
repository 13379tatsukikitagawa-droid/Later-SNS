import UIKit

/// プロフィール(フィルム版)の触覚。設計表(§7)の分だけを鳴らす。
/// 設定の「触覚」がオフのときは、何も鳴らさない(AppHapticsSetting)。
@MainActor
final class ProfileFilmHaptics {
    enum Kind {
        /// コマを押した瞬間
        case press
        /// 日がひらく
        case deck
        /// ページが1枚決まる
        case tick
        /// フィルムの中央のコマが変わる
        case slide
        /// いちばん新しい日・古い日のはじ
        case edge
        /// 共有シートがひらく / スイッチ / とじる
        case light
        /// 空のコマ・現像中の今日を押した
        case nope
        /// 消えた
        case del
    }

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private var lastTick: Date?

    func prepare() {
        [light, medium, rigid, soft, heavy].forEach { $0.prepare() }
    }

    func play(_ kind: Kind) {
        guard AppHapticsSetting.isEnabled else { return }
        switch kind {
        case .press:
            light.impactOccurred(intensity: 0.5)
        case .deck:
            medium.impactOccurred(intensity: 0.7)
        case .tick:
            let now = Date()
            guard ProfileFilmMath.shouldTick(last: lastTick, now: now) else { return }
            lastTick = now
            rigid.impactOccurred(intensity: 0.4)
        case .slide:
            soft.impactOccurred(intensity: 0.3)
        case .edge:
            medium.impactOccurred(intensity: 0.8)
        case .light:
            light.impactOccurred(intensity: 0.5)
        case .nope:
            soft.impactOccurred(intensity: 0.5)
            Task {
                try? await Task.sleep(for: .milliseconds(90))
                soft.impactOccurred(intensity: 0.5)
            }
        case .del:
            heavy.impactOccurred(intensity: 1.0)
        }
    }
}
