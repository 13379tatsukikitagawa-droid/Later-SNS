import SwiftUI
import SwiftData
import Observation

/// 📸 アプリ全体で撮影枚数と制限を一元管理するマネージャー
@MainActor
@Observable
class PhotoManager {
    // MARK: - Singleton
    
    static let shared = PhotoManager()
    
    // MARK: - Properties
    
    /// 今日撮影した枚数（リアルタイム）
    private(set) var todayPhotoCount: Int = 0
    
    /// 1日の撮影上限（デフォルト5枚、ユーザー設定から読み込み）
    var dailyLimit: Int = 5 {
        didSet {
            // AppStorageにも保存
            UserDefaults.standard.set(dailyLimit, forKey: "dailyGoal")
        }
    }
    
    /// 今日の撮影が完了してロックされているか
    private(set) var isLockedToday: Bool = false
    
    // UserDefaultsのキー
    private let lastCountDateKey = "lastPhotoCountDate"
    private let persistedCountKey = "todayPhotoCount"
    private let persistedLockKey = "isDailyLimitLocked"
    
    /// 最後にカウントを更新した日付
    private var lastCountDate: String {
        get { UserDefaults.standard.string(forKey: lastCountDateKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: lastCountDateKey) }
    }
    
    /// 永続化された今日の撮影枚数
    private var persistedCount: Int {
        get { UserDefaults.standard.integer(forKey: persistedCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: persistedCountKey) }
    }
    
    /// 永続化されたロック状態
    private var persistedLock: Bool {
        get { UserDefaults.standard.bool(forKey: persistedLockKey) }
        set { UserDefaults.standard.set(newValue, forKey: persistedLockKey) }
    }
    
    // MARK: - Initialization
    
    private init() {
        // AppStorageから目標枚数を読み込む
        if let savedGoal = UserDefaults.standard.object(forKey: "dailyGoal") as? Int {
            dailyLimit = savedGoal
        }
        resetIfNewDay()
        loadPersistedState()
    }
    
    // MARK: - Public Methods
    
    /// 撮影枚数を1増やす（上限に達したらロック＆ハプティクス）
    func incrementPhotoCount() {
        guard !isLockedToday else {
            // すでにロック済みの場合はエラーハプティクス
            HapticsManager.vaultLock()
            return
        }
        
        todayPhotoCount += 1
        persistedCount = todayPhotoCount
        
        print("📸 Photo count: \(todayPhotoCount)/\(dailyLimit)")
        
        // 上限に達したらロック
        if todayPhotoCount >= dailyLimit {
            lockForToday()
        }
    }
    
    /// 今日のカウントとロックをリセット（新しい日になった場合）
    func resetIfNewDay() {
        let today = todayKey()
        
        if lastCountDate != today {
            print("🔄 New day detected: \(today)")
            todayPhotoCount = 0
            persistedCount = 0
            isLockedToday = false
            persistedLock = false
            lastCountDate = today
        }
    }
    
    /// UserProfileから目標枚数を同期
    func syncDailyLimit(from profile: UserProfile?) {
        if let profile = profile {
            // UserProfileのdailyGoalを上限として使用
            dailyLimit = profile.dailyGoal
            print("🎯 Daily limit synced from profile: \(dailyLimit)")
        } else {
            // プロファイルがない場合はAppStorageから読み込む
            if let savedGoal = UserDefaults.standard.object(forKey: "dailyGoal") as? Int {
                dailyLimit = savedGoal
                print("🎯 Daily limit loaded from AppStorage: \(dailyLimit)")
            } else {
                dailyLimit = 5
                print("🎯 Daily limit set to default: 5")
            }
        }
    }
    
    /// 撮影可能かどうかを判定
    var canTakePhoto: Bool {
        !isLockedToday && todayPhotoCount < dailyLimit
    }
    
    /// 残り撮影可能枚数
    var remainingPhotos: Int {
        max(0, dailyLimit - todayPhotoCount)
    }
    
    /// 進捗率（0.0〜1.0）
    var progress: Double {
        guard dailyLimit > 0 else { return 0 }
        return Double(todayPhotoCount) / Double(dailyLimit)
    }
    
    /// 目標達成済みかどうか
    var isGoalAchieved: Bool {
        todayPhotoCount >= dailyLimit
    }
    
    // MARK: - Private Methods
    
    /// 今日の撮影を完了してロック
    private func lockForToday() {
        isLockedToday = true
        persistedLock = true
        
        // 🔒 重厚なハプティクス（上限到達の瞬間）
        HapticsManager.vaultLock()
        
        print("🔒 Daily limit reached! Locked for today.")
    }
    
    /// 永続化された状態を読み込む
    private func loadPersistedState() {
        todayPhotoCount = persistedCount
        isLockedToday = persistedLock
        
        print("💾 Loaded state - Count: \(todayPhotoCount), Locked: \(isLockedToday)")
    }
    
    /// 今日の日付キー（yyyy-MM-dd形式）
    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
