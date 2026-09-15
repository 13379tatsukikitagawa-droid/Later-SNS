import SwiftUI

/// UIImage(data:)の同期デコードをbodyから追い出すための共通ラッパー。PhotoImageCache
/// (ChekiColorGrade.image(data:cacheKey:)と同じNSCacheパターン)でキャッシュ済みなら
/// メインスレッドで即座に、未キャッシュならバックグラウンドでデコードしてからcontentに渡す。
/// 見た目・レイアウトは呼び出し側がcontentクロージャ内でこれまで通り自由に組み立てるため、
/// この置き換えによる表示上の差分は無い(未デコードの間だけplaceholderが挟まる)。
struct CachedPhotoImage<Content: View, Placeholder: View>: View {
    let imageData: Data?
    /// アプリ再起動をまたいでも変わらない安定したキャッシュキー
    /// (例: photo.ckRecordName ?? photo.id.uuidString)。
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
            if let cached = PhotoImageCache.cachedImage(forKey: cacheKey) {
                image = cached
            } else {
                // 調査項目1・2: キャッシュ未ヒット時のデコードがどれだけ時間がかかっているか
                // (かつメインスレッドを塞いでいないか)を計測する。
                let token = PerformanceSignpost.begin("CachedPhotoImage.decode", detail: "bytes=\(imageData.count)")
                image = await PhotoImageCache.image(data: imageData, cacheKey: cacheKey)
                PerformanceSignpost.end("CachedPhotoImage.decode", token)
            }
        }
    }
}

extension CachedPhotoImage where Placeholder == EmptyView {
    /// placeholder省略時は、未デコードの間は何も表示しない
    /// (元のif let uiImage = UIImage(data:) { ... }が失敗時に何も描画しなかったのと同じ)。
    init(imageData: Data?, cacheKey: String, @ViewBuilder content: @escaping (UIImage) -> Content) {
        self.imageData = imageData
        self.cacheKey = cacheKey
        self.content = content
        self.placeholder = { EmptyView() }
    }
}
