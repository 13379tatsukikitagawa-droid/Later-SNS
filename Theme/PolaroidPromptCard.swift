import SwiftUI

/// コルクボードにピン留めされたポラロイド風の「促しカード」。空状態(グループが
/// まだ無い等)の見せ方として、World/Personal/Communityの各タブで使い回す前提の
/// 汎用コンポーネント。中身(見出し・キャプション・CTA文言・アクション)は呼び出し側が渡す。
struct PolaroidPromptCard: View {
    let heading: String
    let caption: String
    let ctaTitle: String
    var iconSystemName: String = "person.fill"
    let action: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            polaroid
                .rotationEffect(.degrees(-4))

            ctaTape
                .rotationEffect(.degrees(2))
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
                .fill(Color.corkboardCard)
                .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
        )
        .overlay(alignment: .top) {
            CorkboardPin()
                .offset(y: -12)
        }
    }

    private var photoAreaPlaceholder: some View {
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

    private var ctaTape: some View {
        Button(action: action) {
            Text(ctaTitle)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.corkboardCTAText)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.corkboardCard)
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
