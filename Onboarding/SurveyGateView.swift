import SwiftUI

/// 初回起動時、プロフィール設定画面(OnboardingView)より前に表示する、事前アンケート
/// 回答を促すゲート画面。実際の回答有無は検証せず、「回答したので次へ」ボタンの
/// タップだけを条件にUserDefaults["hasCompletedSurvey"]をtrueにする自己申告制。
/// この値はRootView側の@AppStorage("hasCompletedSurvey")と同じキーを見ているため、
/// ボタンをタップした瞬間にRootViewの画面分岐が自動的に切り替わり、この画面は閉じる。
struct SurveyGateView: View {
    private static let surveyURL = URL(string: "https://docs.google.com/forms/d/e/1FAIpQLSc-KZQO8ObuFulc_J2cz3r9QfrvzOOcn3D94fN29GM52Fmkmw/viewform?usp=dialog")!

    private static let backgroundColor = Color(red: 0.039, green: 0.039, blue: 0.039)   // #0a0a0a
    private static let themeGreen = Color.brandGreen        // #4ade6c
    private static let descriptionGray = Color(red: 0.604, green: 0.604, blue: 0.584)   // #9a9a95

    var body: some View {
        ZStack {
            Self.backgroundColor.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                iconBadge

                Text("アンケートにご協力ください")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                durationPill

                Text("このアプリの実験にあたり、事前アンケートへの回答をお願いしています。アプリ利用前後の自己肯定感の変化を調査し、結果は実験終了後にご共有します。")
                    .font(.system(size: 13))
                    .foregroundStyle(Self.descriptionGray)
                    .lineSpacing(13 * 0.75) // CSSのline-height: 1.75相当(フォントサイズ×0.75を行間として追加)
                    .multilineTextAlignment(.center)
                    .frame(width: 250)

                Spacer()

                VStack(spacing: 12) {
                    answerButton
                    nextButton
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(Self.themeGreen.opacity(0.15))
                .frame(width: 72, height: 72)
            Image(systemName: "list.clipboard.fill")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Self.themeGreen)
        }
    }

    private var durationPill: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock")
                .font(.system(size: 13))
            Text("3分で終わるアンケートです")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(Self.themeGreen)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(Self.themeGreen.opacity(0.1))
        )
    }

    private var answerButton: some View {
        Button {
            UIApplication.shared.open(Self.surveyURL)
        } label: {
            Text("アンケートに回答する")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Self.themeGreen)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var nextButton: some View {
        Button {
            UserDefaults.standard.set(true, forKey: "hasCompletedSurvey")
        } label: {
            Text("回答したので次へ")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1.5)
                )
        }
    }
}

#Preview {
    SurveyGateView()
}
