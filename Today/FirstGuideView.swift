import SwiftUI

/// はじめての説明(Home v5)。撮影後の Home をはじめて開いたとき、1回だけ文字で出す。
/// 「アイコンを、2回タップ」。「わかった」/ 画面のどこかをタップで閉じる。
/// 設定 →「撮影のしかた」から、何度でも見直せる。
struct FirstGuideView: View {
    let haptics: ExposureHaptics
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    private static let accent = Color(hex: "FF9E5E")

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 画面ぜんたいを暗く
                Color.black.opacity(0.72)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        TapConsumption.mark()
                        onDismiss()
                    }
                    .accessibilityHidden(true)

                card
                    .frame(width: min(340, max(0, geo.size.width - 56)))
                    .offset(y: isShown || reduceMotion ? 0 : 10)
                    .opacity(isShown ? 1 : 0)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .spring(duration: 0.7, bounce: 0.3)) { isShown = true }
        }
        .accessibilityAddTraits(.isModal)
    }

    private var card: some View {
        VStack(spacing: 0) {
            row(
                icon: AnyView(DoubleRingIcon()),
                title: "アイコンを、2回タップ",
                subtitle: "今日 ⇄ 昨日 のホームを切りかえ"
            )
            Button(action: onDismiss) {
                Text("わかった")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
        }
        .padding(20)
        .v5Glass(cornerRadius: 30, border: 0.16)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color.black.opacity(0.5)))
    }

    private func row(icon: AnyView, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            icon.frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "BCBBC0"))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 二重にひろがる輪
private struct DoubleRingIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.6) / 2.6
            ZStack {
                ring(progress: t)
                ring(progress: max(0, t - 0.12))
                Circle().fill(.white).frame(width: 5, height: 5)
            }
        }
        .accessibilityHidden(true)
    }

    private func ring(progress: Double) -> some View {
        let p = min(1, progress * 1.6)
        return Circle()
            .strokeBorder(Color(hex: "FFD9B8"), lineWidth: 1.5)
            .scaleEffect(0.2 + 0.8 * p)
            .opacity(reduceMotionOpacity(p))
    }

    private func reduceMotionOpacity(_ p: Double) -> Double {
        reduceMotion ? 0.6 : max(0, 0.9 * (1 - p))
    }
}

/// 設定 →「撮影のしかた」。同じ説明を、何度でも
struct ShootGuideReplayView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var haptics = ExposureHaptics()

    var body: some View {
        ZStack(alignment: .topLeading) {
            V5Backdrop()
            FirstGuideView(haptics: haptics, onDismiss: { dismiss() })
        }
        .onAppear { haptics.prepare() }
    }
}
