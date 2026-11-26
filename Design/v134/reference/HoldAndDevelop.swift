import SwiftUI

// 長押し（撮る・はじめる）と「現像」の見た目 — 参考実装

// MARK: - 長押しで決まる（Opal の Hold）
// 撮る：1.5秒 / はじめての設定の最後：1.6秒
// 押している間：丸がちぢむ・まわりの輪が満ちる・振動がだんだん強くなる
// 途中で離したら：もとにもどる（振動は止めるだけ。warning は出さない）

struct HoldToConfirm: ViewModifier {
    let duration: Double
    @Binding var progress: Double
    var isEnabled: Bool = true
    let onComplete: () -> Void

    @State private var task: Task<Void, Never>?
    @State private var completed = false

    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: duration, maximumDistance: 60) {
                guard isEnabled else { return }
                complete()
            } onPressingChanged: { pressing in
                guard isEnabled else {
                    if pressing { LattagHaptics.shared.play(.warning) }
                    return
                }
                if pressing { begin() } else if !completed { cancel() }
            }
    }

    private func begin() {
        completed = false
        LattagHaptics.shared.beginHold()
        let start = Date()
        task?.cancel()
        task = Task { @MainActor in
            while !Task.isCancelled {
                let p = min(1, Date().timeIntervalSince(start) / duration)
                progress = p
                LattagHaptics.shared.updateHold(progress: p)
                if p >= 1 { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func complete() {
        completed = true
        task?.cancel()
        LattagHaptics.shared.endHold()
        progress = 1
        onComplete()            // 撮影なら、ここで .shutter を鳴らす
    }

    private func cancel() {
        task?.cancel()
        LattagHaptics.shared.endHold()
        withAnimation(LTMotion.spring) { progress = 0 }
    }
}

extension View {
    func holdToConfirm(duration: Double, progress: Binding<Double>, isEnabled: Bool = true,
                       onComplete: @escaping () -> Void) -> some View {
        modifier(HoldToConfirm(duration: duration, progress: progress, isEnabled: isEnabled, onComplete: onComplete))
    }
}

// 使い方の例（撮影ボタン）
//
// @State private var shutterProgress = 0.0
// ZStack {
//     Circle().strokeBorder(.white, lineWidth: 4).frame(width: 90, height: 90)
//     Circle().fill(.white).frame(width: 70, height: 70)
//         .scaleEffect(1 - 0.74 * shutterProgress)          // 押している間ちぢむ
//     Circle().trim(from: 0, to: shutterProgress)
//         .stroke(LTColor.lime, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
//         .rotationEffect(.degrees(-90)).frame(width: 104, height: 104)
// }
// .holdToConfirm(duration: 1.5, progress: $shutterProgress, isEnabled: shotsToday < 3) {
//     LattagHaptics.shared.play(.shutter)
//     capture()                                             // 既存の撮影処理をそのまま呼ぶ
// }

// MARK: - 現像の見た目（ミルク色 → 写真）
// progress 0→1。ふつうは 9秒で自然にひらき、写真をおさえている間は 1.4秒の速さでひらく。
// 1 になったら LattagHaptics.shared.play(.opened)

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
                LinearGradient(colors: [LTColor.milkTop, LTColor.milkBottom],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(1 - q)
            )
            .clipped()
    }

    private static func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }
}

extension View {
    func filmDevelop(_ progress: Double) -> some View { modifier(FilmDevelop(progress: progress)) }
}
