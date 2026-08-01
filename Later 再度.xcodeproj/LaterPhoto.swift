import Foundation
import SwiftData

// MARK: - 📸 LaterPhoto データモデル
/// 一括解禁システムに対応した写真データモデル

@Model
final class LaterPhoto {
    
    // MARK: - Properties
    
    /// 写真のユニークID
    var id: UUID
    
    /// 写真のバイナリデータ（JPEG形式）
    @Attribute(.externalStorage)
    var imageData: Data
    
    /// 撮影日時
    var captureDate: Date
    
    /// 解禁日時（個別の値だが、実際は一括解禁時刻で管理される）
    /// ※ この値は参考情報として保持されるが、実際の解禁判定は DailyPhotoSessionManager が行う
    var unlockDate: Date
    
    /// タグ（将来の拡張用）
    var tags: [String]
    
    /// お気に入りフラグ
    var isFavorite: Bool
    
    /// メモ（将来の拡張用）
    var memo: String?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        imageData: Data,
        captureDate: Date,
        unlockDate: Date,
        tags: [String] = [],
        isFavorite: Bool = false,
        memo: String? = nil
    ) {
        self.id = id
        self.imageData = imageData
        self.captureDate = captureDate
        self.unlockDate = unlockDate
        self.tags = tags
        self.isFavorite = isFavorite
        self.memo = memo
    }
    
    // MARK: - Computed Properties
    
    /// 撮影日（時刻を除いた日付）
    var captureDateOnly: Date {
        Calendar.current.startOfDay(for: captureDate)
    }
    
    /// 今日撮影された写真か
    var isToday: Bool {
        Calendar.current.isDateInToday(captureDate)
    }
    
    /// 解禁済みか（DailyPhotoSessionManagerで判定される）
    /// ※ このプロパティは廃止予定。DailyPhotoSessionManager.arePhotosUnlocked() を使用してください
    @available(*, deprecated, message: "Use DailyPhotoSessionManager.shared.arePhotosUnlocked() instead")
    var isUnlocked: Bool {
        Date() >= unlockDate
    }
}

// MARK: - LaterPhoto Extensions

extension LaterPhoto {
    
    /// UIImageに変換
    var uiImage: UIImage? {
        UIImage(data: imageData)
    }
    
    /// サムネイル画像を生成
    /// - Parameter size: サムネイルのサイズ
    /// - Returns: サムネイル画像
    func generateThumbnail(size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        guard let image = uiImage else { return nil }
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    /// ファイルサイズ（MB単位）
    var fileSizeMB: Double {
        Double(imageData.count) / 1_048_576.0 // 1MB = 1,048,576 bytes
    }
}

// MARK: - SwiftData Query Helpers

extension LaterPhoto {
    
    /// 今日撮影された写真のみをフィルタリングする述語
    static var todayPredicate: Predicate<LaterPhoto> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return #Predicate<LaterPhoto> { photo in
            photo.captureDate >= today && photo.captureDate < tomorrow
        }
    }
    
    /// 指定した日に撮影された写真をフィルタリングする述語
    /// - Parameter date: 対象日
    /// - Returns: 述語
    static func predicateForDate(_ date: Date) -> Predicate<LaterPhoto> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return #Predicate<LaterPhoto> { photo in
            photo.captureDate >= startOfDay && photo.captureDate < endOfDay
        }
    }
    
    /// お気に入りの写真のみをフィルタリングする述語
    static var favoritePredicate: Predicate<LaterPhoto> {
        #Predicate<LaterPhoto> { photo in
            photo.isFavorite == true
        }
    }
}

// MARK: - サンプルデータ生成（Preview用）

#if DEBUG
extension LaterPhoto {
    
    /// プレビュー用のサンプル写真を生成
    static var samplePhoto: LaterPhoto {
        // 1x1のダミー画像を生成
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            fatalError("Failed to create sample image data")
        }
        
        return LaterPhoto(
            imageData: imageData,
            captureDate: Date(),
            unlockDate: Date().addingTimeInterval(3600 * 24) // 24時間後
        )
    }
    
    /// 複数のサンプル写真を生成
    /// - Parameter count: 生成する写真の数
    /// - Returns: サンプル写真の配列
    static func samplePhotos(count: Int = 5) -> [LaterPhoto] {
        (0..<count).map { index in
            let size = CGSize(width: 100, height: 100)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { context in
                let colors: [UIColor] = [.red, .blue, .green, .orange, .purple]
                colors[index % colors.count].setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                fatalError("Failed to create sample image data")
            }
            
            return LaterPhoto(
                imageData: imageData,
                captureDate: Date().addingTimeInterval(-Double(index) * 3600), // 1時間ずつ過去
                unlockDate: Date().addingTimeInterval(3600 * 24) // 24時間後
            )
        }
    }
}
#endif
