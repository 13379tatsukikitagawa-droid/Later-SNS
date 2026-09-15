import SwiftUI

/// プロフィール画像の正方形(1:1)範囲選択編集画面。ドラッグで位置を、ピンチで大きさを
/// 調整できる。確定すると、実際に画面に見えている範囲だけを切り出した正方形画像
/// (JPEGデータ)を返す。
struct SquareImageCropView: View {
    let sourceImage: UIImage
    let onConfirm: (Data) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private static let cropSize: CGFloat = 320

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("ドラッグで位置を、ピンチで大きさを調整できます")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)

                cropFrame(interactive: true)
                    .padding(.top, 12)

                Spacer()
            }
            .padding(.top, 30)
            .background(Color.brandBlack.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { onCancel() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { confirmCrop() }
                        .foregroundStyle(Color.brandGreen)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    /// interactive: trueなら編集用(ジェスチャー付き)、falseなら確定時のレンダリング専用
    /// (見た目はどちらも同じにする必要があるため、共通の構成にしている)。
    @ViewBuilder
    private func cropFrame(interactive: Bool) -> some View {
        let content = Image(uiImage: sourceImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: Self.cropSize, height: Self.cropSize)
            .scaleEffect(scale)
            .offset(offset)
            .frame(width: Self.cropSize, height: Self.cropSize)
            .clipShape(Rectangle())

        if interactive {
            content
                .overlay(
                    Rectangle().strokeBorder(Color.brandGreen, lineWidth: 2)
                )
                .contentShape(Rectangle())
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(1, lastScale * value)
                            }
                            .onEnded { _ in lastScale = scale },
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in lastOffset = offset }
                    )
                )
        } else {
            content
        }
    }

    @MainActor
    private func confirmCrop() {
        let renderer = ImageRenderer(content: cropFrame(interactive: false))
        renderer.scale = UIScreen.main.scale
        if let uiImage = renderer.uiImage, let data = uiImage.jpegData(compressionQuality: 0.92) {
            onConfirm(data)
        } else {
            // レンダリングに失敗した場合、無加工の元画像をそのまま使う
            // (クロップされないだけで、機能自体は失敗させない)。
            onConfirm(sourceImage.jpegData(compressionQuality: 0.92) ?? Data())
        }
    }
}
