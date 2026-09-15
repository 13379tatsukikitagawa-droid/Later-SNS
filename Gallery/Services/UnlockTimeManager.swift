import Foundation
import SwiftUI

/// 毎日の解禁時間（9:00-18:00の間のランダムな時刻）と閲覧期限（6時間後）を管理
@Observable
class UnlockTimeManager {
    // MARK: - Singleton
    static let shared = UnlockTimeManager()
    
    // MARK: - Storage Keys
    private let unlockTimeKey = "dailyUnlockTime"
    private let unlockDateKey = "dailyUnlockDate"
    
    // MARK: - Properties
    private(set) var unlockTime: Date?
    private(set) var lockTime: Date? // 解禁時刻 + 6時間
    
    private init() {
        loadTodayUnlockTime()
    }
    
    // MARK: - Public Methods
    
    /// 現在フィードがアンロックされているかチェック
    func isFeedUnlocked(photosTaken: Int, dailyGoal: Int) -> Bool {
        // 目標未達成の場合は常にロック
        guard photosTaken >= dailyGoal else {
            return false
        }
        
        // 解禁時間前、または閲覧期限後の場合はロック
        guard let unlock = unlockTime, let lock = lockTime else {
            return false
        }
        
        let now = Date()
        return now >= unlock && now < lock
    }
    
    /// 今日の解禁時刻を取得（未設定なら生成）
    func ensureTodayUnlockTime() -> Date? {
        if isToday(unlockTime) {
            return unlockTime
        }
        generateTodayUnlockTime()
        return unlockTime
    }
    
    /// アンロック可能な投稿数（撮影枚数と同じ）
    func unlockedPostCount(photosTaken: Int, dailyGoal: Int) -> Int {
        guard isFeedUnlocked(photosTaken: photosTaken, dailyGoal: dailyGoal) else {
            return 0
        }
        return photosTaken
    }
    
    /// 解禁時刻までの残り時間（秒）
    func secondsUntilUnlock() -> Int? {
        guard let unlock = unlockTime else { return nil }
        let remaining = Int(unlock.timeIntervalSince(Date()))
        return max(0, remaining)
    }
    
    /// 閲覧期限までの残り時間（秒）
    func secondsUntilLock() -> Int? {
        guard let lock = lockTime else { return nil }
        let remaining = Int(lock.timeIntervalSince(Date()))
        return max(0, remaining)
    }
    
    // MARK: - Private Methods
    
    /// 今日の解禁時刻を新規生成（9:00-18:00のランダム）
    private func generateTodayUnlockTime() {
        let calendar = Calendar.current
        let now = Date()
        
        // 今日の9:00
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 9
        components.minute = 0
        components.second = 0
        
        guard let start = calendar.date(from: components) else { return }
        
        // 9:00から18:00までの9時間 = 32400秒
        let randomSeconds = Int.random(in: 0...32400)
        guard let randomUnlock = calendar.date(byAdding: .second, value: randomSeconds, to: start) else {
            return
        }
        
        // 6時間後をロック時刻に設定
        guard let randomLock = calendar.date(byAdding: .hour, value: 6, to: randomUnlock) else {
            return
        }
        
        unlockTime = randomUnlock
        lockTime = randomLock
        
        // 保存
        saveTodayUnlockTime(randomUnlock)
        
        #if DEBUG
        print("[UnlockTimeManager] Generated unlock time: \(randomUnlock)")
        print("[UnlockTimeManager] Lock time: \(randomLock)")
        #endif
    }
    
    /// 保存された解禁時刻を読み込み
    private func loadTodayUnlockTime() {
        let defaults = UserDefaults.standard
        
        guard let savedDateString = defaults.string(forKey: unlockDateKey),
              let savedTimeInterval = defaults.object(forKey: unlockTimeKey) as? TimeInterval else {
            // 保存データなし → 新規生成
            generateTodayUnlockTime()
            return
        }
        
        let savedDate = Date(timeIntervalSince1970: savedTimeInterval)
        
        // 今日のデータかチェック
        if savedDateString == todayKey() {
            unlockTime = savedDate
            lockTime = Calendar.current.date(byAdding: .hour, value: 6, to: savedDate)
        } else {
            // 別の日のデータ → 新規生成
            generateTodayUnlockTime()
        }
    }
    
    /// 解禁時刻を保存
    private func saveTodayUnlockTime(_ date: Date) {
        let defaults = UserDefaults.standard
        defaults.set(date.timeIntervalSince1970, forKey: unlockTimeKey)
        defaults.set(todayKey(), forKey: unlockDateKey)
    }
    
    /// 今日の日付キー (yyyy-MM-dd)
    private func todayKey() -> String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar.current
        fmt.locale = Locale.current
        fmt.timeZone = TimeZone.current
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }
    
    /// 指定日が今日かチェック
    private func isToday(_ date: Date?) -> Bool {
        guard let date = date else { return false }
        return Calendar.current.isDateInToday(date)
    }
}
