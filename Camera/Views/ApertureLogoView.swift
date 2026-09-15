import SwiftUI

/// アパーチャーアイコン+「Later」ロゴの共通コンポーネント。AppleSignInView(ログイン画面)と
/// MinimalSplashView(スプラッシュ画面)で見た目を統一するために切り出した。
/// tint/wordmarkColorを変えるだけで、画面ごとの色味(ログインはオレンジ、スプラッシュは
/// ブランドグリーン)に対応できる。
struct ApertureLogoView: View {
    var tint: Color = Color(red: 1.0, green: 0.62, blue: 0.32)
    var wordmarkColor: Color? = nil
    var wordmarkWeight: Font.Weight = .light
    var isAnimated: Bool = true

    @State private var isPulsing = false

    private var resolvedWordmarkColor: Color { wordmarkColor ?? tint }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [tint.opacity(0.35), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(isPulsing ? 1.08 : 0.94)

                Circle()
                    .strokeBorder(tint.opacity(0.5), lineWidth: 2)
                    .frame(width: 92, height: 92)

                Image(systemName: "camera.aperture")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(tint)
                    .scaleEffect(isPulsing ? 1.06 : 0.96)
            }
            .animation(
                isAnimated ? .easeInOut(duration: 2.6).repeatForever(autoreverses: true) : .default,
                value: isPulsing
            )
            .onAppear {
                if isAnimated { isPulsing = true }
            }

            Text("Later")
                .font(.system(size: 44, weight: wordmarkWeight))
                .foregroundStyle(resolvedWordmarkColor)
        }
    }
}
