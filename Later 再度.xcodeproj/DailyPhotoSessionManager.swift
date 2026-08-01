import Foundation
import SwiftUI

// MARK: - 📸 一括写真解禁マネージャー
/// 1日の撮影セッションで撮った全写真を一括で管理し、共通の解禁時刻で同時解禁する

@Observable
class DailyPhotoSessionManager {
    
    // MARK: - Singleton
    static let shared = DailyPhotoSessionManager()
    
    // MARK: - Storage Keys
    private let sessionDateKey = "photoSessionDate"              // セッション日付
    private let sessionLockTimeKey = "photoSessionLockTime"      // ロックされた時刻
    private let sessionUnlockTimeKey = "photoSessionUnlockTime"  // 一括解禁時刻
    private let photoCountKey = "photoSessionPhotoCount"         // 撮影枚数
    private let isLockedKey = "photoSessionIsLocked"             // ロック状態
    
    // MARK: - Properties
    
    /// セッションの日付（yyyy-MM-dd形式）
    private(set) var sessionDate: String?
    
    /// セッションがロックされた時刻
    private(set) var sessionLockTime: Date?
    
    /// 一括解禁時刻（全写真が同時に解禁される時刻）
    private(set) var targetUnlockTime: Date?
    
    /// セッション内の撮影枚数
    private(set) var photoCount: Int = 0
    
    /// セッションがロック済みか（目標達成後の状態）
    private(set) var isSessionLocked: Bool = false
    
    // MARK: - Initialization
    
    private init() {
        loadSession()
    }
    
    // MARK: - Public API
    
    /// 新しい写真を追加（撮影時に呼ばれる）
    /// - Parameter dailyGoal: その日の目標枚数（1〜5枚）
    func addPhoto(dailyGoal: Int) {
        let today = todayKey()
        
        // 新しい日の場合、セッションをリセット
        if sessionDate != today {
            resetSession(newDate: today)
        }
        
        // 写真を追加
        photoCount += 1
        
        // 目標達成でロック（一括解禁時刻を決定）
        if photoCount >= dailyGoal && !isSessionLocked {
            lockSessionAndGenerateUnlockTime()
        }
        
        saveSession()
        
        print("📸 写真追加: \(photoCount)/\(dailyGoal) 枚")
    }
    
    /// 現在のセッションの全写真が解禁されているか判定
    func arePhotosUnlocked() -> Bool {
        guard isSessionLocked,
              let unlockTime = targetUnlockTime else {
            // セッションがロックされていない、または解禁時刻が未設定の場合は未解禁
            return false
        }
        
        // 現在時刻が解禁時刻を過ぎているか
        return Date() >= unlockTime
    }
    
    /// セッションの状態をリセット（デバッグ・テスト用）
    func resetSessionForTesting() {
        resetSession(newDate: todayKey())
        saveSession()
        print("🔄 セッションをリセットしました")
    }
    
    /// 解禁までの残り時間（秒）
    func secondsUntilUnlock() -> TimeInterval? {
        guard let unlockTime = targetUnlockTime else {
            return nil
        }
        
        let remaining = unlockTime.timeIntervalSince(Date())
        return max(0, remaining)
    }
    
    /// 解禁進行度（0.0 〜 1.0）
    func unlockProgress() -> Double {
        guard let lockTime = sessionLockTime,
              let unlockTime = targetUnlockTime else {
            return 0.0
        }
        
        let totalDuration = unlockTime.timeIntervalSince(lockTime)
        guard totalDuration > 0 else {
            return 1.0
        }
        
        let elapsed = Date().timeIntervalSince(lockTime)
        let progress = elapsed / totalDuration
        
        return min(max(progress, 0.0), 1.0)
    }
    
    // MARK: - Private Methods
    
    /// セッションをロックし、一括解禁時刻を生成
    private func lockSessionAndGenerateUnlockTime() {
        let now = Date()
        
        // ロック時刻を記録
        sessionLockTime = now
        isSessionLocked = true
        
        // 🎲 12時間後 〜 48時間後のランダムな時間を計算
        let minSeconds: TimeInterval = 12 * 3600  // 12時間 = 43,200秒
        let maxSeconds: TimeInterval = 48 * 3600  // 48時間 = 172,800秒
        let randomDelay = TimeInterval.random(in: minSeconds...maxSeconds)
        
        // 仮の解禁時刻
        var proposedUnlockTime = now.addingTimeInterval(randomDelay)
        
        // 🌙 夜22:00〜朝9:00の制約チェック
        proposedUnlockTime = adjustUnlockTimeToActiveWindow(proposedUnlockTime)
        
        // 一括解禁時刻を設定
        targetUnlockTime = proposedUnlockTime
        
        saveSession()
        
        #if DEBUG
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        print("🔒 セッションをロック")
        print("📅 ロック時刻: \(formatter.string(from: now))")
        print("🎯 解禁時刻: \(formatter.string(from: proposedUnlockTime))")
        print("⏱ 残り時間: \(formatTimeInterval(randomDelay))")
        #endif
    }
    
    /// 解禁時刻が夜22:00〜朝9:00の間の場合、翌朝9:00以降にスライド
    /// - Parameter date: 調整前の解禁時刻
    /// - Returns: 調整後の解禁時刻
    private func adjustUnlockTimeToActiveWindow(_ date: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        
        // 夜22:00〜朝9:00の間かチェック（22, 23, 0, 1, 2, 3, 4, 5, 6, 7, 8）
        let isInRestrictedWindow = hour >= 22 || hour < 9
        
        if isInRestrictedWindow {
            // 翌朝9:00を基準にする
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            
            // 深夜の場合（0:00〜8:59）は同じ日の9:00
            // 夜の場合（22:00〜23:59）は翌日の9:00
            if hour >= 22 {
                // 翌日に進める
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: date) {
                    components = calendar.dateComponents([.year, .month, .day], from: nextDay)
                }
            }
            
            // 朝9:00に設定
            components.hour = 9
            components.minute = 0
            components.second = 0
            
            guard let morningNine = calendar.date(from: components) else {
                return date // 失敗時は元の時刻を返す
            }
            
            // 9:00からランダムな時間を追加（0〜3時間のランダム）
            let randomSeconds = Int.random(in: 0...(3 * 3600))
            let adjustedTime = morningNine.addingTimeInterval(TimeInterval(randomSeconds))
            
            #if DEBUG
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            print("🌙 制限時間帯を検出: \(formatter.string(from: date)) → \(formatter.string(from: adjustedTime))")
            #endif
            
            return adjustedTime
        }
        
        return date
    }
    
    /// セッションをリセット
    private func resetSession(newDate: String) {
        sessionDate = newDate
        sessionLockTime = nil
        targetUnlockTime = nil
        photoCount = 0
        isSessionLocked = false
        
        print("🆕 新しいセッション開始: \(newDate)")
    }
    
    /// セッションを保存
    private func saveSession() {
        let defaults = UserDefaults.standard
        
        defaults.set(sessionDate, forKey: sessionDateKey)
        defaults.set(photoCount, forKey: photoCountKey)
        defaults.set(isSessionLocked, forKey: isLockedKey)
        
        if let lockTime = sessionLockTime {
            defaults.set(lockTime.timeIntervalSince1970, forKey: sessionLockTimeKey)
        } else {
            defaults.removeObject(forKey: sessionLockTimeKey)
        }
        
        if let unlockTime = targetUnlockTime {
            defaults.set(unlockTime.timeIntervalSince1970, forKey: sessionUnlockTimeKey)
        } else {
            defaults.removeObject(forKey: sessionUnlockTimeKey)
        }
    }
    
    /// セッションを読み込み
    private func loadSession() {
        let defaults = UserDefaults.standard
        
        sessionDate = defaults.string(forKey: sessionDateKey)
        photoCount = defaults.integer(forKey: photoCountKey)
        isSessionLocked = defaults.bool(forKey: isLockedKey)
        
        if let lockTimeInterval = defaults.object(forKey: sessionLockTimeKey) as? TimeInterval {
            sessionLockTime = Date(timeIntervalSince1970: lockTimeInterval)
        }
        
        if let unlockTimeInterval = defaults.object(forKey: sessionUnlockTimeKey) as? TimeInterval {
            targetUnlockTime = Date(timeIntervalSince1970: unlockTimeInterval)
        }
        
        // 日付が変わっている場合はリセット
        let today = todayKey()
        if let savedDate = sessionDate, savedDate != today {
            resetSession(newDate: today)
            saveSession()
        }
        
        #if DEBUG
        if let unlockTime = targetUnlockTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            print("📂 セッション読み込み")
            print("📅 セッション日付: \(sessionDate ?? "なし")")
            print("📸 撮影枚数: \(photoCount)")
            print("🔒 ロック状態: \(isSessionLocked)")
            print("🎯 解禁時刻: \(formatter.string(from: unlockTime))")
        }
        #endif
    }
    
    /// 今日の日付キー (yyyy-MM-dd)
    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    /// 時間間隔を人間が読める形式にフォーマット
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)日\(remainingHours)時間"
        } else if hours > 0 {
            return "\(hours)時間\(minutes)分"
        } else {
            return "\(minutes)分"
        }
    }
}

// MARK: - 秘匿化されたUI用ヘルパー

extension DailyPhotoSessionManager {
    
    /// ユーザーに表示する抽象的なステータスメッセージ
    var statusMessage: String {
        if !isSessionLocked {
            return "撮影中"
        } else if arePhotosUnlocked() {
            return "現像完了"
        } else {
            return "現像中..."
        }
    }
    
    /// 解禁状態のアイコン名
    var statusIcon: String {
        if !isSessionLocked {
            return "camera.fill"
        } else if arePhotosUnlocked() {
            return "checkmark.circle.fill"
        } else {
            return "clock.fill"
        }
    }
    
    /// 解禁状態の色
    var statusColor: Color {
        if !isSessionLocked {
            return .blue
        } else if arePhotosUnlocked() {
            return .green
        } else {
            return .orange
        }
    }
    
    /// 進行度に応じた抽象的なメッセージ
    var developmentMessage: String {
        guard isSessionLocked && !arePhotosUnlocked() else {
            return statusMessage
        }
        
        let progress = unlockProgress()
        
        switch progress {
        case 0..<0.25:
            return "現像準備中..."
        case 0.25..<0.5:
            return "現像処理中..."
        case 0.5..<0.75:
            return "仕上げ中..."
        case 0.75..<1.0:
            return "最終確認中..."
        default:
            return "現像完了"
        }
    }
}
