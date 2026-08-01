import Foundation

// MARK: - LaterPhoto Extensions

extension LaterPhoto {
    
    /// 残り時間を人間が読める形式で取得
    var remainingTimeText: String {
        let remaining = unlockDate.timeIntervalSince(Date())
        
        guard remaining > 0 else {
            return "解禁済み"
        }
        
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%02d:%02d", minutes, seconds)
        } else {
            return String(format: "00:%02d", seconds)
        }
    }
    
    /// 解禁までの残り日数
    var daysUntilUnlock: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: unlockDate)
        return max(0, components.day ?? 0)
    }
    
    /// 解禁までの残り時間（秒）
    var secondsUntilUnlock: TimeInterval {
        max(0, unlockDate.timeIntervalSince(Date()))
    }
}
