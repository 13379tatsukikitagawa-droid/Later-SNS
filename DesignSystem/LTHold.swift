import SwiftUI

// v134 Phase 1:長押しで 決まる(Opal の Hold)と「現像」の 見た目。
// 撮る = 1.5秒 ・ はじめる = 1.6秒。押している 間:丸が ちぢむ ・ 輪が 満ちる ・ 振動が だんだん 強くなる。
// 途中で 離したら もとに もどる(振動は 止めるだけ。warning は 出さない)。

/// 長押しの 触感の 差しかえ。ふだんは 今までの `HapticRamp`(撮る ・ ひらく ・ はじめる)。レンズは 専用(`LensCharge`)。
struct HoldHaptics {
    var begin: @MainActor () -> Void
    var update: @MainActor (Double) -> Void
    var end: @MainActor () -> Void
    static let ramp = HoldHaptics(begin: { LTHaptics.beginHold() }, update: { LTHaptics.updateHold(progress: $0) }, end: { LTHaptics.endHold() })
    static let lens = HoldHaptics(begin: { LensCharge.begin() }, update: { _ in }, end: { LensCharge.end() })
}

struct HoldToConfirm: ViewModifier {
    let duration: Double
    @Binding var progress: Double
    var isEnabled = true
    var haptics: HoldHaptics = .ramp
    /// 指が この 距離より ずれたら 止める
    var maximumDistance: CGFloat = 60
    /// 無効の とき 押された 合図(warning)。使わない なら nil
    var onBlocked: (() -> Void)? = nil
    let onComplete: () -> Void

    @State private var task: Task<Void, Never>?
    @State private var completed = false

    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: duration, maximumDistance: maximumDistance) {
                guard isEnabled else { return }
                complete()
            } onPressingChanged: { pressing in
                guard isEnabled else {
                    if pressing { LTHaptics.play(.warning); onBlocked?() }
                    return
                }
                if pressing { begin() } else if !completed { cancel() }
            }
            .onDisappear { if !completed, task != nil { cancel() } }   // 押している 途中で 画面が きえた(中断)
    }

    private func begin() {
        completed = false
        haptics.begin()
        let start = Date()
        task?.cancel()
        task = Task { @MainActor in
            while !Task.isCancelled {
                let p = min(1, Date().timeIntervalSince(start) / duration)
                progress = p
                haptics.update(p)
                if p >= 1 { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func complete() {
        completed = true
        task?.cancel()
        haptics.end()
        progress = 1
        onComplete()            // 撮影なら ここで .shutter を 鳴らす
        // 次の 長押しの ために 少し 後に もどす
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { completed = false }
    }

    private func cancel() {
        task?.cancel()
        haptics.end()
        withAnimation(LTMotion.spring) { progress = 0 }
    }
}

extension View {
    func holdToConfirm(duration: Double, progress: Binding<Double>, isEnabled: Bool = true, haptics: HoldHaptics = .ramp, maximumDistance: CGFloat = 60,
                       onBlocked: (() -> Void)? = nil, onComplete: @escaping () -> Void) -> some View {
        modifier(HoldToConfirm(duration: duration, progress: progress, isEnabled: isEnabled, haptics: haptics, maximumDistance: maximumDistance, onBlocked: onBlocked, onComplete: onComplete))
    }
}

// MARK: - 現像の 見た目(ミルク色 → 写真)
// progress 0 → 1。ふつうは 9秒で ひらき、写真を おさえている 間は 1.4秒。1 になったら `LTHaptics.play(.opened)`。
// ぼかしは 14pt まで。毎フレーム 作りなおす 重い 物は 使わず、修飾子の 値だけ 変える。

struct FilmDevelop: ViewModifier {
    var progress: Double
    func body(content: Content) -> some View {
        let q = Self.smooth(max(0, min(1, (progress - 0.04) / 0.9)))
        content
            .blur(radius: (1 - q) * 14)
            .saturation(0.15 + 0.85 * q)
            .brightness(0.25 * (1 - q))
            .contrast(0.85 + 0.15 * q)
            .overlay(
                LinearGradient(colors: [LTColor.milkTop, LTColor.milkBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(1 - q)
            )
            .clipped()
    }
    static func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }
}

extension View {
    func filmDevelop(_ progress: Double) -> some View { modifier(FilmDevelop(progress: progress)) }
}
