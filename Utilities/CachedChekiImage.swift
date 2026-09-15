import SwiftUI

/// ChekiColorGrade(5層のFilmEmulation処理)の結果をバックグラウンドで取得し、
/// 完了するまでは呼び出し側が渡すplaceholderを表示する。CachedPhotoImageと同じ形の
/// ラッパー(SwiftUIのbodyを一切ブロックしない)。
struct CachedChekiImage<Content: View, Placeholder: View>: View {
    let imageData: Data?
    /// アプリ再起動をまたいでも変わらない安定したキャッシュキー
    /// (例: "\(photo.id.uuidString)_\(photo.imageData.count)")。
    let cacheKey: String
    @ViewBuilder let content: (UIImage) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                content(image)
            } else {
                placeholder()
            }
        }
        .task(id: cacheKey) {
            guard let imageData, !imageData.isEmpty else {
                image = nil
                return
            }
            if let cached = ChekiColorGrade.cachedImage(forKey: cacheKey) {
                image = cached
                return
            }
            image = await ChekiColorGrade.image(data: imageData, cacheKey: cacheKey)
        }
    }
}
