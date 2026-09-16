import SwiftUI

/// コルクボードにピン留めされたポラロイド風の「促しカード」。空状態(グループが
/// まだ無い等)の見せ方として、World/Personal/Communityの各タブで使い回す前提の
/// 汎用コンポーネント。中身(見出し・キャプション・CTA文言・アクション)は呼び出し側が渡す。
struct PolaroidPromptCard: View {
    let heading: String
    let caption: String
    let ctaTitle: String
    var iconSystemName: String = "person.fill"
    /// 2026/9 Community(未参加)画面のMVP再設計向けに追加。true にすると、傾き無しの
    /// まっすぐな見た目・簡略化したプレースホルダー・質感アップグレード済みのCTAボタンに
    /// なる。false(既定)では既存の見た目(傾き・二重丸プレースホルダー)を完全に維持する
    /// (PersonalTodayViewの空状態など、他の呼び出し元に影響しない)。
    var isFlat: Bool = false
    /// 上端のコルクボードピンの直径。既定はisFlatと無関係に18のまま。
    var pinSize: CGFloat = 18
    /// 副導線(下線付きテキストリンク)。両方指定した場合のみ、CTAボタンの下に表示する。
    var secondaryLinkTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil
    let action: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            polaroid
                .rotationEffect(.degrees(isFlat ? 0 : -4))

            VStack(spacing: 14) {
                ctaTape
                    .rotationEffect(.degrees(isFlat ? 0 : 2))

                if let secondaryLinkTitle, let secondaryAction {
                    Button(action: secondaryAction) {
                        Text(secondaryLinkTitle)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color(hex: "8a7c6a"))
                            .underline(true, color: Color(hex: "6b5a2c"))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var polaroid: some View {
        VStack(spacing: 14) {
            photoAreaPlaceholder
                .frame(width: 160, height: 160)

            Text(heading)
                .font(.custom("Caveat-Bold", size: 26))
                .foregroundStyle(Color.corkboardHeading)

            Text(caption)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.corkboardTabInactiveText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 22)
        .padding(.bottom, 20)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    isFlat
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [Color.corkboardCard, Color.corkboardCard.opacity(0.94)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        : AnyShapeStyle(Color.corkboardCard)
                )
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
        )
        .overlay(alignment: .top) {
            CorkboardPin(size: pinSize)
                .offset(y: -pinSize * 0.67)
        }
    }

    @ViewBuilder
    private var photoAreaPlaceholder: some View {
        if isFlat {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.corkboardPhotoArea)
                .overlay {
                    Image(systemName: iconSystemName)
                        .font(.system(size: 40))
                        .foregroundStyle(Color.corkboardHeading.opacity(0.25))
                }
        } else {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.corkboardPhotoArea)
                .overlay {
                    Circle()
                        .strokeBorder(Color.corkboardHeading.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .padding(28)
                    Image(systemName: iconSystemName)
                        .font(.system(size: 40))
                        .foregroundStyle(Color.corkboardHeading.opacity(0.25))
                }
        }
    }

    private var ctaTape: some View {
        Button(action: action) {
            Text(ctaTitle)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.corkboardCTAText)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: isFlat ? 12 : 3, style: .continuous)
                        .fill(
                            isFlat
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "fffdf9"), Color(hex: "ece5d5")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                : AnyShapeStyle(Color.corkboardCard)
                        )
                        .shadow(color: .black.opacity(isFlat ? 0.15 : 0), radius: 2, x: 0, y: 1)
                        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        CorkboardBackground()
        VStack {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(["WORLD", "PERSONAL", "COMMUNITY"], id: \.self) { label in
                    let isActive = label == "COMMUNITY"
                    Text(label)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(isActive ? Color.corkboardTabActiveText : Color.corkboardTabInactiveText)
                        .frame(maxWidth: .infinity)
                        .padding(.top, isActive ? 10 : 14)
                        .padding(.bottom, 12)
                        .background(
                            UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 10, style: .continuous)
                                .fill(isActive ? Color.corkboardTabActive : Color.corkboardTabInactive)
                                .overlay(alignment: .top) {
                                    if isActive { Rectangle().fill(Color.brandGreen).frame(height: 3) }
                                }
                        )
                        .offset(y: isActive ? -4 : 0)
                }
            }
            .padding(.horizontal, 20)

            VStack {
                Spacer()
                PolaroidPromptCard(
                    heading: "誰かと一緒に、\n始めよう",
                    caption: "グループに入ると、みんなで撮った記録も残せます",
                    ctaTitle: "＋ グループを作る"
                ) {}
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.corkboardTabActive)
            .clipShape(.rect(topLeadingRadius: 0, bottomLeadingRadius: 18, bottomTrailingRadius: 18, topTrailingRadius: 0))
        }
        .padding(.top, 56)
    }
    .ignoresSafeArea()
}
