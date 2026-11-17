import SwiftUI

/// v47:いちばん下の「Later today」の虹のリングを消して、暗室の電気のひもに置きかえる。
/// 引くたびに セーフライト(赤い常夜灯)を オン・オフ。状態は @AppStorage で残る。
struct DarkroomSafelightString: View {
    @Binding var isOn: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// いま引いている長さ(0〜約70)
    @State private var pull: CGFloat = 0
    /// このドラッグで しきい値を こえたか(こえると カチッ・はなすと 切りかわる)
    @State private var armed = false

    private static let restLength: CGFloat = 60
    private static let clickThreshold: CGFloat = 46

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .top) {
                string
                bead
            }
            .frame(height: 26 + Self.restLength + 20)
            .contentShape(Rectangle())
            // mock:しきい値で「カチッ」・はなした時に 明かりが 切りかわる。つまむ=タップでも 切りかわる。
            .onTapGesture { tapToggle() }
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        let raw = max(0, value.translation.height)
                        let extended = min(raw, Self.restLength) + max(0, raw - Self.restLength) * 0.25
                        pull = extended
                        if !armed, extended >= Self.clickThreshold {
                            armed = true
                            Haptics.play(.click)
                        }
                    }
                    .onEnded { _ in
                        let fire = armed || pull < 6
                        armed = false
                        release()
                        if fire { toggle() }
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("セーフライト")
            .accessibilityValue(isOn ? "オン" : "オフ")
            .accessibilityHint("下に引くと切りかえます")
            .accessibilityAction { toggle(); release() }

            Text(verbatim: isOn ? "SAFELIGHT" : "PULL")
                .font(Darkroom.mono(9.5))
                .tracking(0.2 * 9.5)
                .foregroundStyle(isOn ? Color(hex: "FF6B5C") : Darkroom.faint)
                .contentTransition(.opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isOn)
        }
    }

    private var extension_: CGFloat { pull }

    private var string: some View {
        Rectangle()
            .fill(.white.opacity(0.22))
            .frame(width: 1.4, height: 26 + extension_)
    }

    private var bead: some View {
        let dotColor = isOn ? Color(hex: "FF3B30") : Color.white.opacity(0.3)
        let glow = isOn ? Color(hex: "FF3B30").opacity(0.9) : Color.clear
        return Circle()
            .fill(Color(hex: "2A2A2E"))
            .frame(width: 20, height: 20)
            .overlay(
                Circle().fill(dotColor).frame(width: 7, height: 7)
                    .shadow(color: glow, radius: 5)
            )
            .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
            .offset(y: 26 + extension_)
            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
    }

    /// つまむ(タップ):ひもが ぴょこっと 動いてから 明かりが 切りかわる。
    private func tapToggle() {
        Haptics.play(.click)
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.14)) { pull = 30 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.interpolatingSpring(stiffness: 220, damping: 12)) { pull = 0 }
            }
        }
        toggle()
    }

    private func toggle() {
        isOn.toggle()
        let on = isOn
        // mock:明かりが 切りかわる 手ごたえは 少し おくれて(約120ms)。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            Haptics.play(on ? .thud : .soft)
        }
    }

    private func release() {
        if reduceMotion {
            pull = 0
            return
        }
        withAnimation(.interpolatingSpring(stiffness: 220, damping: 12)) { pull = 0 }
    }
}
