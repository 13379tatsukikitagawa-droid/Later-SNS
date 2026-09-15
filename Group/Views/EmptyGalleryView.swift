import SwiftUI

/// Gallery画面で、その日の写真が1枚も無い時に表示する洗練された空状態ビュー。
/// 写真と同じアスペクト比(3:4)の破線プレースホルダーカードの中央に、発光する
/// カメラアイコン・案内メッセージをまとめて表示する。
struct EmptyGalleryView: View {
    /// 破線カードの上に出す案内文。省略時は標準の「この日の写真はまだありません」。
    var message: String = "この日の写真はまだありません"

    private static let neonGreen = Color.brandGreen

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
            .foregroundStyle(Self.neonGreen.opacity(0.3))
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .frame(maxWidth: 260)
            .overlay {
                VStack(spacing: 14) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(Self.neonGreen)
                        .shadow(color: Self.neonGreen.opacity(0.7), radius: 12)

                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
