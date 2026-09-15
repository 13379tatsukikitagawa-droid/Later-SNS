import SwiftUI

/// プロフィール設定完了(OnboardingViewの「Laterをはじめる」)の直後に一度だけ表示する、
/// Laterの紹介サイトへの導線画面。デザインはOnboardingViewのウェルカムステップと
/// 同じトーン(ダーク×グリーン、ApertureLogoView)に揃えている。
struct LaterAboutIntroView: View {
    /// このサイトを開く/スキップするいずれの操作でも、最終的にMainTabViewへ
    /// 進んでよいタイミングで呼ばれる。
    var onContinue: () -> Void

    @Environment(\.openURL) private var openURL

    private static let accentGreen = Color.brandGreen
    private static let aboutSiteURL = URL(string: "https://13379tatsukikitagawa-droid.github.io/APP-Later2/")!

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                ApertureLogoView(tint: Self.accentGreen, wordmarkColor: Self.accentGreen, wordmarkWeight: .heavy)

                VStack(spacing: 14) {
                    Text("Laterとは")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("グループでその日撮った写真をお互いに見せ合う、\n少し特別な仕組みのカメラアプリです。\n使い方やコンセプトをサイトで詳しく紹介しています。")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.top, 28)
                .padding(.horizontal, 28)

                Spacer(minLength: 0)

                VStack(spacing: 14) {
                    Button {
                        openURL(Self.aboutSiteURL)
                        onContinue()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "safari")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Laterについて詳しく見る")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Self.accentGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Self.accentGreen.opacity(0.35), radius: 16, x: 0, y: 8)
                    }

                    Button {
                        onContinue()
                    } label: {
                        Text("スキップ")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.brandBlack,
                    Color.brandBlack.opacity(0.95),
                    Self.accentGreen.opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Self.accentGreen.opacity(0.2), Color.clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 600
            )
            .blur(radius: 30)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    LaterAboutIntroView(onContinue: {})
}
