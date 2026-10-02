import SwiftUI

/// グループアイコン(円形)。iconImageDataがあれば写真を円形にトリミングして表示し、
/// 無ければグループ名の頭文字を表示するプレースホルダーに切り替える。
/// GroupDetailViewのヘッダー・Home画面(TodayShootingView)のグループ一覧行で共通に使う。
struct GroupIconView: View {
    let iconImageData: Data?
    let groupName: String
    var size: CGFloat = 40
    /// グループ作成時にカラーステッカーで選んだアクセント色(LaterGroup.accentColorHex)。
    /// 指定があればプレースホルダーの塗り・文字色、および外周のリングに使う。
    var ringColor: Color? = nil

    private var tint: Color { ringColor ?? Color.brandGreen }

    var body: some View {
        Group {
            if let iconImageData, let uiImage = UIImage(data: iconImageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    tint.opacity(0.12)
                    if let firstCharacter = groupName.trimmingCharacters(in: .whitespacesAndNewlines).first {
                        Text(String(firstCharacter))
                            .font(.system(size: size * 0.42, weight: .bold))
                            .foregroundStyle(tint)
                    } else {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundStyle(tint)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(ringColor ?? Color.clear, lineWidth: ringColor != nil ? 2 : 0)
        )
    }
}
