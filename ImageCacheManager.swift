import UIKit
import SwiftUI

// MARK: - 画像キャッシュマネージャー
class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // キャッシュディレクトリの設定
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ImageCache")
        
        // ディレクトリが存在しない場合は作成
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        // メモリキャッシュの制限設定（50MB）
        cache.totalCostLimit = 50 * 1024 * 1024
        cache.countLimit = 100
    }
    
    // MARK: - メモリキャッシュ
    
    func getImage(forKey key: String) -> UIImage? {
        // メモリキャッシュから取得
        if let cachedImage = cache.object(forKey: key as NSString) {
            return cachedImage
        }
        
        // ディスクキャッシュから取得
        if let diskImage = loadImageFromDisk(forKey: key) {
            // メモリキャッシュに保存
            cache.setObject(diskImage, forKey: key as NSString)
            return diskImage
        }
        
        return nil
    }
    
    func setImage(_ image: UIImage, forKey key: String) {
        // メモリキャッシュに保存
        cache.setObject(image, forKey: key as NSString)
        
        // ディスクキャッシュに保存（バックグラウンドで実行）
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.saveImageToDisk(image, forKey: key)
        }
    }
    
    func removeImage(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
        removeImageFromDisk(forKey: key)
    }
    
    func clearCache() {
        cache.removeAllObjects()
        clearDiskCache()
    }
    
    // MARK: - ディスクキャッシュ
    
    private func loadImageFromDisk(forKey key: String) -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256())
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    private func saveImageToDisk(_ image: UIImage, forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256())
        
        // JPEG形式で保存（圧縮率0.8）
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL)
        }
    }
    
    private func removeImageFromDisk(forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256())
        try? fileManager.removeItem(at: fileURL)
    }
    
    private func clearDiskCache() {
        guard let files = try? fileManager.contentsOfDirectory(atPath: cacheDirectory.path) else { return }
        
        for file in files {
            let fileURL = cacheDirectory.appendingPathComponent(file)
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
    // MARK: - キャッシュ情報
    
    func getCacheSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(atPath: cacheDirectory.path) else { return 0 }
        
        var totalSize: Int64 = 0
        for file in files {
            let fileURL = cacheDirectory.appendingPathComponent(file)
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }
        }
        
        return totalSize
    }
}

// MARK: - String Extension (SHA256)
extension String {
    func sha256() -> String {
        // 簡易的なハッシュ関数（実際のアプリではCryptoKitを使用することを推奨）
        return self.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? self
    }
}

// MARK: - キャッシュ付き画像ビュー
struct CachedAsyncImage: View {
    let data: Data?
    let size: CGFloat
    let cacheKey: String
    
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: size, height: size)
                    .overlay(
                        ProgressView()
                            .tint(.white)
                    )
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        // キャッシュから取得を試みる
        if let cachedImage = ImageCacheManager.shared.getImage(forKey: cacheKey) {
            image = cachedImage
            return
        }
        
        // データから画像を生成
        if let data = data, let uiImage = UIImage(data: data) {
            image = uiImage
            // キャッシュに保存
            ImageCacheManager.shared.setImage(uiImage, forKey: cacheKey)
        }
    }
}
