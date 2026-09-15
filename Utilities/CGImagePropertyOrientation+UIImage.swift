import UIKit
import CoreImage

/// UIImage.OrientationとCGImagePropertyOrientationはケース名は対応するがrawValueの
/// 数値体系が異なるため、rawValueをそのまま渡す変換はできない(1件ずつ対応させる必要がある)。
/// CIImage(data:)はEXIFの回転情報をピクセルへ反映しない(内部プロパティとして保持するだけ)
/// ため、UIImage(data:)経由でEXIF Orientationを読み取り、.oriented(_:)でピクセル自体を
/// 正しい向きに焼き込んでからCore Imageフィルタにかける必要がある箇所すべてで使う
/// (ChekiColorGrade/DevelopingPreviewCache等)。
extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
