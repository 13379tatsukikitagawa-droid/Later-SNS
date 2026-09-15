import UIKit

public enum HapticsManager {
    /// Haptic Engineを事前に準備します
    @MainActor
    public static func prepare() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
    }
    
    /// スワイプ時の軽いフィードバック
    @MainActor
    public static func swipeFeedback() {
        impact(style: .light)
    }
    
    /// カード切り替え時のフィードバック
    @MainActor
    public static func cardChange() {
        impact(style: .medium)
    }
    
    /// アンロック成功時のフィードバック
    @MainActor
    public static func unlockSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    /// ハートビート（心拍）のようなリズミカルなフィードバック
    @MainActor
    public static func heartbeat() {
        let styles: [UIImpactFeedbackGenerator.FeedbackStyle] = [.heavy, .light]
        playImpacts(styles: styles, interval: 0.2)
    }
    
    /// 指定されたスタイルでインパクトフィードバックを発生させます。デフォルトは .heavy です。
    @MainActor
    public static func shutterClick(style: UIImpactFeedbackGenerator.FeedbackStyle = .heavy) {
        impact(style: style)
    }

    /// 錠のロックを模したエラーフィードバックと連続インパクトフィードバックを発生させます。
    @MainActor
    public static func vaultLock() {
        let notificationGenerator = UINotificationFeedbackGenerator()
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.error)

        let styles: [UIImpactFeedbackGenerator.FeedbackStyle] = [.heavy, .heavy, .heavy]
        // 使用可能であれば .rigid を含める (iOS 13+)
        if #available(iOS 13.0, *) {
            // 2回目と3回目は rigid にすることで強い感触を連続で与える
            let rigidStyles: [UIImpactFeedbackGenerator.FeedbackStyle] = [.heavy, .rigid, .rigid]
            playImpacts(styles: rigidStyles, interval: 0.04)
        } else {
            playImpacts(styles: styles, interval: 0.04)
        }
    }

    /// 星の数に応じて異なる強さのインパクトフィードバックを発生させます。星は1〜5にクランプされます。
    /// - Parameter stars: 評価の星数 (1〜5)
    @MainActor
    public static func stampRating(stars: Int) {
        let clampedStars = min(max(stars, 1), 5)
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch clampedStars {
        case 1...2:
            style = .light
        case 3...4:
            style = .medium
        default:
            style = .heavy
        }
        impact(style: style)
    }
    
    /// フィルム巻き上げのようなザラザラしたフィードバック
    @MainActor
    public static func filmWinding() {
        let styles: [UIImpactFeedbackGenerator.FeedbackStyle] = [
            .light, .light, .medium, .light, .light, .medium, .light
        ]
        playImpacts(styles: styles, interval: 0.05)
    }
    
    /// エラー発生時のフィードバック
    @MainActor
    public static func errorFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
    
    /// 軽いティック音のようなフィードバック（UI要素のタップ時）
    @MainActor
    public static func tick() {
        impact(style: .light)
    }

    @MainActor
    private static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    @MainActor
    private static func playImpacts(styles: [UIImpactFeedbackGenerator.FeedbackStyle], interval: Double) {
        var delay: Double = 0
        for style in styles {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                impact(style: style)
            }
            delay += interval
        }
    }
}
