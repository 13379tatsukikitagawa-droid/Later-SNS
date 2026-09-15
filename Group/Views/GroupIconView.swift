import SwiftUI

/// グループアイコン(円形)。iconImageDataがあれば写真を円形にトリミングして表示し、
/// 無ければグループ名の頭文字を表示するプレースホルダーに切り替える。
/// GroupDetailViewのヘッダー・Home画面(TodayShootingView)のグループ一覧行で共通に使う。
struct GroupIconView: View {
    let iconImageData: Data?
    let groupName: String
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let iconImageData, let uiImage = UIImage(data: iconImageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.brandGreen.opacity(0.12)
                    if let firstCharacter = groupName.trimmingCharacters(in: .whitespacesAndNewlines).first {
                        Text(String(firstCharacter))
                            .font(.system(size: size * 0.42, weight: .bold))
                            .foregroundStyle(Color.brandGreen)
                    } else {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundStyle(Color.brandGreen)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
