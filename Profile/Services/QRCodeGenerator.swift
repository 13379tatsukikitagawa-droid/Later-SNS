import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// QRコード生成とカスタマイズのユーティリティ
public enum QRCodeGenerator {
    
    // MARK: - QRコードデータ生成
    
    /// ユーザーIDからQRコードデータ文字列を生成
    public static func createUserQRData(userID: String, userName: String) -> String {
        return "laterapp://user?id=\(userID)&name=\(userName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? userName)"
    }
    
    /// グループIDからQRコードデータ文字列を生成
    public static func createGroupQRData(groupID: String, groupName: String) -> String {
        return "laterapp://group?id=\(groupID)&name=\(groupName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? groupName)"
    }
    
    // MARK: - QRコード画像生成
    
    /// 基本的なQRコード画像を生成
    public static func generateQRCode(from string: String, size: CGFloat = 512) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        guard let data = string.data(using: .utf8) else { return nil }
        filter.message = data
        filter.correctionLevel = "H" // 高い誤り訂正レベル（ロゴを追加するため）
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // スケール調整
        let scaleX = size / outputImage.extent.size.width
        let scaleY = size / outputImage.extent.size.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// ブランドカラーでカスタマイズされたQRコードを生成
    public static func generateStyledQRCode(
        from string: String,
        size: CGFloat = 512,
        foregroundColor: UIColor = UIColor(red: 0.2, green: 0.8, blue: 0.5, alpha: 1.0),
        backgroundColor: UIColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
    ) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        guard let data = string.data(using: .utf8) else { return nil }
        filter.message = data
        filter.correctionLevel = "H"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // カラーフィルター適用
        let colorFilter = CIFilter.falseColor()
        colorFilter.inputImage = outputImage
        colorFilter.color0 = CIColor(color: foregroundColor)
        colorFilter.color1 = CIColor(color: backgroundColor)
        
        guard let coloredImage = colorFilter.outputImage else { return nil }
        
        // スケール調整
        let scaleX = size / coloredImage.extent.size.width
        let scaleY = size / coloredImage.extent.size.height
        let transformedImage = coloredImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// 中央にロゴを配置したQRコードを生成
    public static func generateQRCodeWithLogo(
        from string: String,
        size: CGFloat = 512,
        logo: UIImage? = nil,
        logoSizeRatio: CGFloat = 0.2
    ) -> UIImage? {
        guard let qrImage = generateStyledQRCode(from: string, size: size) else {
            return nil
        }
        
        // ロゴがない場合はQRコードのみ返す
        guard let logoImage = logo else {
            return qrImage
        }
        
        // ロゴサイズを計算
        let logoSize = size * logoSizeRatio
        let logoRect = CGRect(
            x: (size - logoSize) / 2,
            y: (size - logoSize) / 2,
            width: logoSize,
            height: logoSize
        )
        
        // ロゴを丸くマスク
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            // QRコードを描画
            qrImage.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
            
            // 背景の白い円を描画（ロゴを見やすくする）
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fillEllipse(in: logoRect.insetBy(dx: -8, dy: -8))
            
            // ロゴを円形にクリップして描画
            context.cgContext.saveGState()
            context.cgContext.addEllipse(in: logoRect)
            context.cgContext.clip()
            logoImage.draw(in: logoRect)
            context.cgContext.restoreGState()
        }
    }
    
    /// 中央に角丸四角形の白いプレートを敷いた上でロゴ画像を重ねたQRコードを生成する。
    /// generateQRCodeWithLogoの円形クリップと異なり、ロゴの縦横比をそのまま活かして
    /// プレートの形を決めるため、「later」のような横長のワードマークでも欠けずに収まる。
    public static func generateQRCodeWithLogoPlate(
        from string: String,
        size: CGFloat = 512,
        logoImage: UIImage,
        plateSizeRatio: CGFloat = 0.24,
        foregroundColor: UIColor = UIColor(red: 0.2, green: 0.8, blue: 0.5, alpha: 1.0),
        backgroundColor: UIColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
    ) -> UIImage? {
        guard let qrImage = generateStyledQRCode(from: string, size: size, foregroundColor: foregroundColor, backgroundColor: backgroundColor) else {
            return nil
        }

        let plateWidth = size * plateSizeRatio
        let logoAspect = logoImage.size.width / max(logoImage.size.height, 1)
        let plateHeight = plateWidth / max(logoAspect, 1)
        let logoRect = CGRect(
            x: (size - plateWidth) / 2,
            y: (size - plateHeight) / 2,
            width: plateWidth,
            height: plateHeight
        )
        let plateRect = logoRect.insetBy(dx: -plateWidth * 0.12, dy: -plateHeight * 0.35)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            qrImage.draw(in: CGRect(x: 0, y: 0, width: size, height: size))

            let platePath = UIBezierPath(roundedRect: plateRect, cornerRadius: plateRect.height * 0.3)
            UIColor.white.setFill()
            platePath.fill()

            logoImage.draw(in: logoRect)
        }
    }

    // MARK: - QRコード解析
    
    /// QRコードデータ文字列を解析してユーザー情報を取得
    public static func parseUserQRData(_ string: String) -> (id: String, name: String)? {
        guard let url = URL(string: string),
              url.scheme == "laterapp",
              url.host == "user",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        
        var userID: String?
        var userName: String?
        
        for item in queryItems {
            switch item.name {
            case "id":
                userID = item.value
            case "name":
                userName = item.value?.removingPercentEncoding
            default:
                break
            }
        }
        
        guard let id = userID, let name = userName else {
            return nil
        }
        
        return (id, name)
    }
    
    /// QRコードデータ文字列を解析してグループ情報を取得
    public static func parseGroupQRData(_ string: String) -> (id: String, name: String)? {
        guard let url = URL(string: string),
              url.scheme == "laterapp",
              url.host == "group",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        
        var groupID: String?
        var groupName: String?
        
        for item in queryItems {
            switch item.name {
            case "id":
                groupID = item.value
            case "name":
                groupName = item.value?.removingPercentEncoding
            default:
                break
            }
        }
        
        guard let id = groupID, let name = groupName else {
            return nil
        }
        
        return (id, name)
    }
}

// MARK: - SwiftUI用のQRコードImageヘルパー

public extension Image {
    /// QRコード文字列からSwiftUI Imageを生成
    init?(qrCode string: String, size: CGFloat = 512) {
        guard let uiImage = QRCodeGenerator.generateStyledQRCode(from: string, size: size) else {
            return nil
        }
        self.init(uiImage: uiImage)
    }
}
