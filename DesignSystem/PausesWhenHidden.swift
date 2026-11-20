import SwiftUI

/// v111 §11:くり返しの 動きは「見えて いる 時 だけ」動かす。
/// 止める 条件 = アプリが 前に ない(`scenePhase != .active`)・ 画面から 消えて いる(`onDisappear`)・ 視差を へらす 設定。
/// 使い方:
///  - 時計の 動き  →`PausableTimeline`(`TimelineView(.animation)` の かわり。間隔の 指定が ないと 60fps に なる)
///  - 呼吸 ・ 点滅 →`.loopWhileVisible(_:value:)`(`withAnimation(...repeatForever)` の かわり)
struct PausableTimeline<Content: View>: View {
    var minimumInterval: Double = 1.0 / 30
    /// 見えて いない 間も 1コマ だけは 出す(止めた 時の 見た目)
    @ViewBuilder var content: (Date) -> Content
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    var body: some View {
        TimelineView(.animation(minimumInterval: minimumInterval, paused: reduceMotion || scenePhase != .active || !visible)) { ctx in
            content(ctx.date)
        }
        .onAppear { visible = true }
        .onDisappear { visible = false }
    }
}

/// 見えて いる 間 だけ `repeatForever` を 流す。止める 時は 動きを 消して 元の 値に もどす
private struct LoopWhileVisible<V: Equatable>: ViewModifier {
    let animation: Animation
    @Binding var value: V
    let from: V
    let to: V
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    private var live: Bool { visible && scenePhase == .active && !reduceMotion }

    func body(content: Content) -> some View {
        content
            .onAppear { visible = true }
            .onDisappear { visible = false }
            .task(id: live) {
                if live {
                    value = from
                    withAnimation(animation) { value = to }
                } else {
                    var t = Transaction(); t.disablesAnimations = true
                    withTransaction(t) { value = from }
                }
            }
    }
}

extension View {
    /// 例:`.loopWhileVisible(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: $blink)`
    func loopWhileVisible(_ animation: Animation, value: Binding<Bool>) -> some View {
        modifier(LoopWhileVisible(animation: animation, value: value, from: false, to: true))
    }
    func loopWhileVisible(_ animation: Animation, value: Binding<Double>, from: Double = 0, to: Double = 1) -> some View {
        modifier(LoopWhileVisible(animation: animation, value: value, from: from, to: to))
    }
}
