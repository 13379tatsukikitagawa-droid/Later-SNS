import SwiftUI

// v100 B:スクロールの バイブ(どの 画面でも 同じ しくみ)。
// 区切りの 上の はしが 画面の 35% の 線を こえた = notch(かぎ付き = knock)/ はじに 当たった(0.45pt/ms 以上)= edge /
// はじを こえて ひっぱる = 30 ・ 60 ・ 90pt で stretch(3回まで)→ はなすと soft。
// はやい スクロール(2400pt/秒 より 上)では notch を 鳴らさない(止まりぎわに また 鳴る)。

struct ScrollHapticsSnap: Equatable {
    var offset: CGFloat      // 0 = いちばん 上
    var maxOffset: CGFloat
    var viewport: CGFloat
}

@MainActor
@Observable
final class ScrollHapticsModel {
    @ObservationIgnored private var secs: [AnyHashable: CGFloat] = [:]
    @ObservationIgnored private(set) var viewport: CGFloat = 800
    @ObservationIgnored private(set) var velocity: CGFloat = 0     // pt/秒(平滑)
    @ObservationIgnored private var lastOffset: CGFloat?
    @ObservationIgnored private var lastTime = Date()
    @ObservationIgnored private var armedTop = true
    @ObservationIgnored private var armedBottom = true
    @ObservationIgnored private var stretchLevel = 0

    static let maxNotchSpeed: CGFloat = 2400
    static let edgeSpeed: CGFloat = 450          // 0.45pt/ms
    static let rearm: CGFloat = 24
    static let stretchSteps: [CGFloat] = [30, 60, 90]
    static let line: CGFloat = 0.35

    /// 区切りの 位置(スクロールの 枠の 中の 上のはし)
    func report(_ id: AnyHashable, y: CGFloat, locked: Bool) {
        defer { secs[id] = y }
        guard let prev = secs[id], prev != y else { return }
        let line = viewport * Self.line
        guard (prev - line) * (y - line) < 0 else { return }      // 線を こえた
        guard abs(velocity) < Self.maxNotchSpeed else { return }  // はやい 時は 静か
        Haptics.play(locked ? .knock : .notch)
    }

    func scroll(_ s: ScrollHapticsSnap, now: Date = Date()) {
        viewport = s.viewport
        let dt = now.timeIntervalSince(lastTime)
        if let lastOffset, dt > 0.001 {
            let v = (s.offset - lastOffset) / CGFloat(dt)
            velocity = velocity * 0.5 + v * 0.5
        }
        let prev = lastOffset
        lastOffset = s.offset; lastTime = now
        guard let prev, s.maxOffset > 0 else { return }

        // ひっぱる(はじを こえた 量)
        let pull = s.offset < 0 ? -s.offset : max(0, s.offset - s.maxOffset)
        let level = Self.stretchSteps.filter { pull >= $0 }.count
        if level > stretchLevel { for _ in stretchLevel..<level { Haptics.play(.stretch, gap: 0.0) } }
        if level == 0, stretchLevel > 0 { Haptics.play(.soft) }
        stretchLevel = level

        // はじに 当たった
        if s.offset > Self.rearm { armedTop = true }
        if s.offset < s.maxOffset - Self.rearm { armedBottom = true }
        if armedTop, prev > 0.5, s.offset <= 0.5, abs(velocity) >= Self.edgeSpeed { armedTop = false; Haptics.play(.edge) }
        if armedBottom, prev < s.maxOffset - 0.5, s.offset >= s.maxOffset - 0.5, abs(velocity) >= Self.edgeSpeed { armedBottom = false; Haptics.play(.edge) }
    }
}

private struct ScrollHapticsKey: EnvironmentKey { static let defaultValue: ScrollHapticsModel? = nil }
extension EnvironmentValues { var scrollHaptics: ScrollHapticsModel? { get { self[ScrollHapticsKey.self] } set { self[ScrollHapticsKey.self] = newValue } } }

private struct ScrollHapticsModifier: ViewModifier {
    @State private var model = ScrollHapticsModel()
    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: "lgHapticScroll")
            .environment(\.scrollHaptics, model)
            .onScrollGeometryChange(for: ScrollHapticsSnap.self) { g in
                let top = g.contentInsets.top
                return ScrollHapticsSnap(offset: g.contentOffset.y + top,
                                         maxOffset: max(0, g.contentSize.height + top + g.contentInsets.bottom - g.containerSize.height),
                                         viewport: g.containerSize.height)
            } action: { _, new in model.scroll(new) }
    }
}

private struct HapticSectionModifier: ViewModifier {
    let id: AnyHashable
    let locked: Bool
    @Environment(\.scrollHaptics) private var model
    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("lgHapticScroll")).minY } action: { y in
            model?.report(id, y: y, locked: locked)
        }
    }
}

extension View {
    /// `ScrollView` に つける(縦)。中の 区切りに `.hapticSection(...)`
    func scrollHaptics() -> some View { modifier(ScrollHapticsModifier()) }
    /// 区切り(セクション ・ 友だち ・ 行)。`locked` = かぎ付き(knock)
    func hapticSection(_ id: some Hashable, locked: Bool = false) -> some View { modifier(HapticSectionModifier(id: AnyHashable(id), locked: locked)) }
    /// v100 §8:バイブが 書かれて いない ボタンの 手ごたえ(押した 時に tick)。自分で 鳴らす ボタンには つけない
    func lgTap() -> some View { buttonStyle(LGButtonStyle()) }
}

/// 押した 時に tick を 鳴らす ボタンの 型(自分で 鳴らす ボタンには 使わない)
struct LGButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .onChange(of: configuration.isPressed) { _, pressed in if pressed { Haptics.play(.tick) } }
    }
}
