import SwiftUI

/// 初回起動・ウェルカムオンボーディング画面(2026/9 新デザイン仕様)。アプリの一番最初、
/// 事前アンケート(SurveyGateView)より前に一度だけ表示する導入スライド。
/// 「はじめる」タップでRootView(LaterApp)側の@AppStorage("hasSeenWelcomeOnboarding")と
/// 同じキーをtrueにし、その先の既存フロー(SurveyGateView→AppleSignInView→
/// OnboardingView→...)へそのまま進む。SurveyGateViewと同じ「自己申告でフラグを
/// 立てるだけ」の自己完結パターンを踏襲する。
///
/// ページインジケーターは3ドットで用意しているが、現時点ではスライドは1枚のみの
/// 実装にとどめている(複数枚化は今後の拡張)。
struct WelcomeOnboardingView: View {
    @AppStorage("hasSeenWelcomeOnboarding") private var hasSeenWelcomeOnboarding: Bool = false
    /// フッターの「すでにアカウントをお持ちの方はこちら」。このアプリの既存フローでは
    /// 新規/既存ユーザーとも同じSign in with Apple/メール導線(AppleSignInView)に
    /// 合流するため、CTAと同じくウェルカム画面を閉じるだけでよい。
    private static let accent = Color.laterAccent

    var body: some View {
        ZStack {
            Color.laterBackground.ignoresSafeArea()

            RadialGradient(
                colors: [Self.accent.opacity(0.14), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 210
            )
            .frame(height: 420)
            .frame(maxWidth: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 28) {
                Spacer(minLength: 12)

                chekiStack
                    .frame(width: 220, height: 240)

                wordmark

                VStack(spacing: 14) {
                    Text("今日という日を、\n現像する。")
                        .font(.system(size: 21, weight: .heavy))
                        .foregroundStyle(Color.laterText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(21 * 0.45)

                    Text("フォロワーの数も、いいねの数もありません。\nあるのは、今日というたった1枚だけ。")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.laterTextMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(13 * 0.7)
                }

                pageIndicator

                Spacer(minLength: 12)

                VStack(spacing: 16) {
                    startButton
                    loginFooterLink
                }
                .padding(.horizontal, 28)
            }
            .padding(.top, 40)
            .padding(.bottom, 24)
        }
        .statusBarHidden()
    }

    // MARK: - ②チェキ写真スタック

    private var chekiStack: some View {
        ZStack {
            chekiCard(
                rotation: 9,
                gradient: [Color(hex: "C9682B"), Color(hex: "6B3A1A")],
                dateLabel: "'26.9.15",
                isFront: false
            )
            .offset(y: 6)

            chekiCard(
                rotation: -7,
                gradient: [Color(hex: "2E6E73"), Color(hex: "14283F")],
                dateLabel: "'26.9.18",
                isFront: false
            )
            .offset(y: 2)

            chekiCard(
                rotation: -1,
                gradient: [Color(hex: "1F5A3A"), Color(hex: "0E2E1F")],
                dateLabel: "'26.9.21・今日",
                isFront: true
            )
        }
    }

    private func chekiCard(rotation: Double, gradient: [Color], dateLabel: String, isFront: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)

                if isFront {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))

            Text(dateLabel)
                .font(.custom("Courier New", size: 11).weight(isFront ? .bold : .regular))
                .foregroundStyle(Color(hex: isFront ? "4a3c22" : "8a7550"))
        }
        .padding(10)
        .frame(width: 170)
        .background(Color(hex: "F3ECD9"))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .shadow(color: .black.opacity(isFront ? 0.45 : 0.3), radius: isFront ? 16 : 10, x: 0, y: isFront ? 10 : 6)
        .rotationEffect(.degrees(rotation))
    }

    // MARK: - ③ワードマーク

    private var wordmark: some View {
        HStack(spacing: 8) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Self.accent)
            Text("Later")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Self.accent)
        }
    }

    // MARK: - ⑥ページインジケーター

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            Capsule().fill(Self.accent).frame(width: 18, height: 5)
            Circle().fill(Color.white.opacity(0.18)).frame(width: 5, height: 5)
            Circle().fill(Color.white.opacity(0.18)).frame(width: 5, height: 5)
        }
    }

    // MARK: - ⑦CTA

    private var startButton: some View {
        Button {
            hasSeenWelcomeOnboarding = true
        } label: {
            Text("はじめる")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Color.laterBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Capsule().fill(Self.accent))
                .shadow(color: Self.accent.opacity(0.35), radius: 24, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - ⑧フッターリンク

    private var loginFooterLink: some View {
        Button {
            hasSeenWelcomeOnboarding = true
        } label: {
            Text("すでにアカウントをお持ちの方はこちら")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "7FA88E"))
                .underline()
        }
        .buttonStyle(.plain)
    }
}
