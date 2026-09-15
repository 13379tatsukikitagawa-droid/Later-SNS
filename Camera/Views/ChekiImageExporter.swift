import SwiftUI

/// ChekiPhotoFrame(白フレーム・日付印字・位置情報込みのチェキ表示)を、保存/共有用に
/// 1枚のUIImageへオフスクリーンでレンダリングする。単なる元画像(photo.imageData)の
/// 保存/共有ではなく、アプリ内で見えているのと同じチェキの見た目を書き出すために使う。
@MainActor
enum ChekiImageExporter {
    private static let renderWidth: CGFloat = 320

    static func renderImage(for photo: LaterPhoto) -> UIImage? {
        let content = ChekiPhotoFrame(photo: photo)
            .frame(width: renderWidth)
        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
