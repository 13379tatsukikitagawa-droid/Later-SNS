import UIKit
import CoreImage

// MARK: - QRコード生成ユーティリティ
/// CoreImageのCIQRCodeGeneratorを使用してQRコードを生成するユーティリティクラス

struct QRCodeGenerator {
    
    /// ユーザーIDからQRコード画像を生成する
    /// - Parameters:
    ///   - userID: QRコードに含めるユーザーID（UUIDなど）
    ///   - size: 生成するQRコードのサイズ（ピクセル）
    /// - Returns: 生成されたQRコードのUIImage、失敗した場合はnil
    static func generateQRCode(from userID: String, size: CGFloat = 200) -> UIImage? {
        // CIQRCodeGeneratorフィルタを作成
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            print("❌ QRコード生成エラー: CIQRCodeGeneratorフィルタが見つかりません")
            return nil
        }
        
        // 入力データをセット（ユーザーIDをUTF-8エンコード）
        let data = Data(userID.utf8)
        filter.setValue(data, forKey: "inputMessage")
        
        // エラー訂正レベルを設定（L, M, Q, H）
        // L = 7%, M = 15%, Q = 25%, H = 30% のエラー訂正能力
        filter.setValue("M", forKey: "inputCorrectionLevel")
        
        // 出力画像を取得
        guard let outputImage = filter.outputImage else {
            print("❌ QRコード生成エラー: 出力画像が生成できませんでした")
            return nil
        }
        
        // QRコードは小さいピクセル画像なので、スケールアップ
        let scaleX = size / outputImage.extent.size.width
        let scaleY = size / outputImage.extent.size.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        // CIImageからUIImageに変換
        let context = CIContext()
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            print("❌ QRコード生成エラー: CGImageへの変換に失敗しました")
            return nil
        }
        
        let qrImage = UIImage(cgImage: cgImage)
        print("✅ QRコード生成成功: サイズ \(size)x\(size)")
        return qrImage
    }
    
    /// ユーザー情報からQRコード用のデータ文字列を生成
    /// - Parameters:
    ///   - userID: ユーザーID
    ///   - userName: ユーザー名（オプション）
    /// - Returns: QRコードに埋め込む文字列（JSON形式）
    static func createQRData(userID: String, userName: String? = nil) -> String {
        // アプリ独自のスキーマを使用してQRコードデータを作成
        // 例: "laterapp://user?id=12345&name=TaroYamada"
        var components = URLComponents()
        components.scheme = "laterapp"
        components.host = "user"
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "id", value: userID)
        ]
        
        if let userName = userName, !userName.isEmpty {
            queryItems.append(URLQueryItem(name: "name", value: userName))
        }
        
        components.queryItems = queryItems
        
        return components.url?.absoluteString ?? userID
    }
}
