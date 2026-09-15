import Foundation

/// イージング計算だけを残したユーティリティ。以前は写真解禁の進行度計算
/// (calculateUnlockProgress/blurRadius等、撮影から解禁までの期間を使ったフェード演出)
/// も持っていたが、実際にはどこからも呼ばれておらず死コードだったため削除した
/// (現像中の視覚効果はCamera/Views/DevelopingProgressView.swiftの固定1時間アニメーションが
/// 別に担っている)。applyEasingだけがDevelopingProgressView/FilmEmulationから生きて
/// 呼ばれている。
enum PhotoUnlockUtilities {
    /// イージング関数を適用した進行度を計算(スムーズな変化)
    static func applyEasing(
        progress: Double,
        easingType: EasingType = .easeInOut
    ) -> Double {
        switch easingType {
        case .linear:
            return progress
        case .easeIn:
            return progress * progress
        case .easeOut:
            return 1 - (1 - progress) * (1 - progress)
        case .easeInOut:
            if progress < 0.5 {
                return 2 * progress * progress
            } else {
                return 1 - 2 * (1 - progress) * (1 - progress)
            }
        case .smoothStep:
            return progress * progress * (3 - 2 * progress)
        }
    }

    enum EasingType {
        case linear
        case easeIn
        case easeOut
        case easeInOut
        case smoothStep
    }
}
