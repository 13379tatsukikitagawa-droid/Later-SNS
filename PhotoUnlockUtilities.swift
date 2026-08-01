import Foundation
import SwiftData

// MARK: - 写真解禁ユーティリティ
/// 写真の解禁進行度を計算するためのユーティリティ
enum PhotoUnlockUtilities {
    
    // MARK: - 進行度計算
    
    /// 写真の解禁進行度を計算する
    /// - Parameters:
    ///   - captureDate: 撮影日時
    ///   - unlockDate: 解禁日時
    ///   - currentDate: 現在日時（デフォルトは現在時刻）
    /// - Returns: 0.0（撮影直後）から 1.0（解禁完了）までの進行度
    static func calculateUnlockProgress(
        captureDate: Date,
        unlockDate: Date,
        currentDate: Date = Date()
    ) -> Double {
        // 撮影から解禁までの総時間（秒）
        let totalDuration = unlockDate.timeIntervalSince(captureDate)
        
        // 総時間が0以下の場合は即座に解禁
        guard totalDuration > 0 else {
            return 1.0
        }
        
        // 撮影から現在までの経過時間（秒）
        let elapsedTime = currentDate.timeIntervalSince(captureDate)
        
        // 進行度を計算（0.0 〜 1.0の範囲にクランプ）
        let progress = elapsedTime / totalDuration
        return min(max(progress, 0.0), 1.0)
    }
    
    /// 写真が完全に解禁されているかを判定
    /// - Parameters:
    ///   - unlockDate: 解禁日時
    ///   - currentDate: 現在日時（デフォルトは現在時刻）
    /// - Returns: 完全に解禁されている場合は true
    static func isFullyUnlocked(
        unlockDate: Date,
        currentDate: Date = Date()
    ) -> Bool {
        return currentDate >= unlockDate
    }
    
    /// 解禁までの残り時間を計算
    /// - Parameters:
    ///   - unlockDate: 解禁日時
    ///   - currentDate: 現在日時（デフォルトは現在時刻）
    /// - Returns: 残り時間（秒）。既に解禁されている場合は0
    static func timeUntilUnlock(
        unlockDate: Date,
        currentDate: Date = Date()
    ) -> TimeInterval {
        let remaining = unlockDate.timeIntervalSince(currentDate)
        return max(remaining, 0)
    }
    
    // MARK: - エフェクト計算
    
    /// 進行度に基づいたブラー強度を計算
    /// - Parameters:
    ///   - progress: 解禁進行度（0.0 〜 1.0）
    ///   - maxBlur: 最大ブラー強度（デフォルトは 10.0）
    /// - Returns: 適用すべきブラー強度
    static func calculateBlurRadius(
        progress: Double,
        maxBlur: CGFloat = 10.0
    ) -> CGFloat {
        // 進行度が上がるにつれてブラーが減少
        return maxBlur * CGFloat(1.0 - progress)
    }
    
    /// 進行度に基づいた彩度を計算
    /// - Parameters:
    ///   - progress: 解禁進行度（0.0 〜 1.0）
    /// - Returns: 適用すべき彩度（0.0 〜 1.0）
    static func calculateSaturation(progress: Double) -> Double {
        // 進行度が上がるにつれて彩度が増加
        return progress
    }
    
    /// 進行度に基づいたグレースケール度を計算
    /// - Parameters:
    ///   - progress: 解禁進行度（0.0 〜 1.0）
    /// - Returns: 適用すべきグレースケール度（0.0 〜 1.0）
    static func calculateGrayscale(progress: Double) -> Double {
        // 進行度が上がるにつれてグレースケールが減少
        return 1.0 - progress
    }
    
    /// 進行度に基づいた白色オーバーレイの不透明度を計算
    /// - Parameters:
    ///   - progress: 解禁進行度（0.0 〜 1.0）
    ///   - maxOpacity: 最大不透明度（デフォルトは 0.35）
    /// - Returns: 適用すべき不透明度
    static func calculateOverlayOpacity(
        progress: Double,
        maxOpacity: Double = 0.35
    ) -> Double {
        // 進行度が上がるにつれてオーバーレイが薄くなる
        return maxOpacity * (1.0 - progress)
    }
    
    // MARK: - 時間フォーマット
    
    /// 残り時間を人間が読みやすい形式にフォーマット
    /// - Parameter timeInterval: 残り時間（秒）
    /// - Returns: フォーマットされた文字列（例: "2日 5時間", "3時間 20分", "45分"）
    static func formatRemainingTime(_ timeInterval: TimeInterval) -> String {
        guard timeInterval > 0 else {
            return "解禁済み"
        }
        
        let totalSeconds = Int(timeInterval)
        let days = totalSeconds / 86400 // 86400秒 = 1日
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if days > 0 {
            if hours > 0 {
                return "\(days)日 \(hours)時間"
            } else {
                return "\(days)日"
            }
        } else if hours > 0 {
            if minutes > 0 {
                return "\(hours)時間 \(minutes)分"
            } else {
                return "\(hours)時間"
            }
        } else if minutes > 0 {
            return "\(minutes)分"
        } else {
            return "まもなく"
        }
    }
    
    /// 残り時間を短い形式でフォーマット
    /// - Parameter timeInterval: 残り時間（秒）
    /// - Returns: フォーマットされた文字列（例: "2d 5h", "3h 20m", "45m"）
    static func formatRemainingTimeShort(_ timeInterval: TimeInterval) -> String {
        guard timeInterval > 0 else {
            return "解禁"
        }
        
        let totalSeconds = Int(timeInterval)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }
    
    // MARK: - アニメーション用
    
    /// イージング関数を適用した進行度を計算（スムーズな変化）
    /// - Parameters:
    ///   - progress: 元の進行度（0.0 〜 1.0）
    ///   - easingType: イージングの種類
    /// - Returns: イージングを適用した進行度
    static func applyEasing(
        progress: Double,
        easingType: EasingType = .easeInOut
    ) -> Double {
        switch easingType {
        case .linear:
            return progress
            
        case .easeIn:
            // 開始がゆっくり、終わりが速い
            return progress * progress
            
        case .easeOut:
            // 開始が速く、終わりがゆっくり
            return 1 - (1 - progress) * (1 - progress)
            
        case .easeInOut:
            // 開始と終わりがゆっくり、中間が速い
            if progress < 0.5 {
                return 2 * progress * progress
            } else {
                return 1 - 2 * (1 - progress) * (1 - progress)
            }
            
        case .smoothStep:
            // 非常にスムーズな変化
            return progress * progress * (3 - 2 * progress)
        }
    }
    
    /// イージングの種類
    enum EasingType {
        case linear      // 線形（変化が一定）
        case easeIn      // 徐々に加速
        case easeOut     // 徐々に減速
        case easeInOut   // 加速してから減速
        case smoothStep  // 最もスムーズ
    }
}

// MARK: - LaterPhoto拡張
extension LaterPhoto {
    
    /// 現在の解禁進行度を取得
    var unlockProgress: Double {
        PhotoUnlockUtilities.calculateUnlockProgress(
            captureDate: captureDate,
            unlockDate: unlockDate
        )
    }
    
    /// 完全に解禁されているか
    var isFullyUnlocked: Bool {
        PhotoUnlockUtilities.isFullyUnlocked(unlockDate: unlockDate)
    }
    
    /// 解禁までの残り時間
    var timeUntilUnlock: TimeInterval {
        PhotoUnlockUtilities.timeUntilUnlock(unlockDate: unlockDate)
    }
    
    /// 残り時間の短い文字列表現
    var remainingTimeShortText: String {
        PhotoUnlockUtilities.formatRemainingTimeShort(timeUntilUnlock)
    }
    
    // MARK: - エフェクト用プロパティ
    
    /// 現在適用すべきブラー強度
    func blurRadius(maxBlur: CGFloat = 10.0) -> CGFloat {
        PhotoUnlockUtilities.calculateBlurRadius(
            progress: unlockProgress,
            maxBlur: maxBlur
        )
    }
    
    /// 現在適用すべき彩度
    var saturation: Double {
        PhotoUnlockUtilities.calculateSaturation(progress: unlockProgress)
    }
    
    /// 現在適用すべきグレースケール度
    var grayscale: Double {
        PhotoUnlockUtilities.calculateGrayscale(progress: unlockProgress)
    }
    
    /// 現在適用すべきオーバーレイ不透明度
    func overlayOpacity(maxOpacity: Double = 0.35) -> Double {
        PhotoUnlockUtilities.calculateOverlayOpacity(
            progress: unlockProgress,
            maxOpacity: maxOpacity
        )
    }
}
