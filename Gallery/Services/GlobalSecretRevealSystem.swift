import Foundation
import SwiftUI
import UserNotifications

// MARK: - Global Secret Reveal System
/// 全ユーザー共通の一斉解禁システム
/// サーバー側で管理される解禁時刻を全ユーザーで共有し、同時に写真が解禁される

@Observable
final class GlobalSecretRevealManager {
    // MARK: - Singleton
    static let shared = GlobalSecretRevealManager()
    
    // MARK: - Global State
    /// 次回の解禁時刻（サーバーから取得、全ユーザー共通）
    private(set) var nextGlobalRevealTime: Date
    
    /// 現在グローバルに解禁されているか
    private(set) var isGloballyRevealed: Bool = false
    
    /// 解禁状態の履歴
    private(set) var revealHistory: [RevealEvent] = []
    
    // MARK: - Local User State
    /// 現在のユーザーが目標枚数を撮り終えたか
    var hasUserCompletedGoal: Bool {
        get { userDefaults.bool(forKey: userCompletedKey) }
        set { userDefaults.set(newValue, forKey: userCompletedKey) }
    }
    
    /// ユーザーのポリシー設定
    var viewPolicy: GlobalViewPolicy {
        get {
            guard let rawValue = userDefaults.string(forKey: viewPolicyKey),
                  let policy = GlobalViewPolicy(rawValue: rawValue) else {
                return .viewOthersEvenIfIncomplete
            }
            return policy
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: viewPolicyKey)
        }
    }
    
    // MARK: - Constants
    private let minRandomSpan: TimeInterval = 12 * 60 * 60  // 12時間
    private let maxRandomSpan: TimeInterval = 48 * 60 * 60  // 48時間
    private let nightStartHour = 22  // 22:00
    private let nightEndHour = 9     // 09:00
    
    // MARK: - Storage
    private let userDefaults = UserDefaults.standard
    private let globalRevealTimeKey = "globalSecretRevealTime"
    private let lastRevealEndTimeKey = "lastGlobalRevealEndTime"
    private let userCompletedKey = "userHasCompletedGoal"
    private let viewPolicyKey = "globalViewPolicy"
    private let revealHistoryKey = "globalRevealHistory"
    
    // MARK: - Timer
    private var checkTimer: Timer?
    
    // MARK: - Initialization
    private init() {
        // 保存された解禁時刻を読み込み、なければ新規生成
        if let savedTime = userDefaults.object(forKey: globalRevealTimeKey) as? TimeInterval {
            nextGlobalRevealTime = Date(timeIntervalSince1970: savedTime)
        } else {
            // 初回起動: 現在時刻から計算
            nextGlobalRevealTime = Self.calculateNextRevealTime(from: Date())
            saveGlobalRevealTime()
        }
        
        // 履歴を読み込み
        loadRevealHistory()
        
        // 即座に解禁状態をチェック
        checkGlobalRevealStatus()
        
        // 定期チェックタイマーを開始
        startPeriodicCheck()
    }
    
    deinit {
        checkTimer?.invalidate()
    }
    
    // MARK: - Public API
    
    /// ユーザーがフィードを閲覧できるかチェック
    func canViewFeed() -> Bool {
        // グローバル解禁されていない場合は誰も見れない
        guard isGloballyRevealed else {
            return false
        }
        
        // ポリシーに基づいて判定
        switch viewPolicy {
        case .viewOthersEvenIfIncomplete:
            // 自分が未達成でも他人の写真は見れる
            return true
            
        case .blockAllUntilSelfComplete:
            // 自分が達成するまで全て見れない
            return hasUserCompletedGoal
        }
    }
    
    /// 自分の写真が閲覧可能かチェック
    func canViewOwnPhotos() -> Bool {
        return isGloballyRevealed && hasUserCompletedGoal
    }
    
    /// 他人の写真が閲覧可能かチェック
    func canViewOthersPhotos() -> Bool {
        guard isGloballyRevealed else {
            return false
        }
        
        switch viewPolicy {
        case .viewOthersEvenIfIncomplete:
            return true
        case .blockAllUntilSelfComplete:
            return hasUserCompletedGoal
        }
    }
    
    /// 次回の解禁までの残り時間（秒）
    func secondsUntilNextReveal() -> Int? {
        guard !isGloballyRevealed else {
            return nil
        }
        
        let remaining = Int(nextGlobalRevealTime.timeIntervalSince(Date()))
        return max(0, remaining)
    }
    
    /// 手動で解禁状態をチェック（アプリ起動時やフォアグラウンド復帰時に呼ぶ）
    func checkGlobalRevealStatus() {
        let now = Date()
        
        if now >= nextGlobalRevealTime && !isGloballyRevealed {
            // 解禁時刻到達 → グローバル解禁
            performGlobalReveal()
        }
    }
    
    /// 次回の解禁スケジュールを設定（管理者用 / サーバー同期用）
    func scheduleNextReveal(at date: Date) {
        nextGlobalRevealTime = date
        isGloballyRevealed = false
        saveGlobalRevealTime()
        
        #if DEBUG
        print("[GlobalSecretReveal] Next reveal scheduled at: \(date)")
        #endif
        
        // プッシュ通知をスケジュール
        scheduleRevealNotification(at: date)
    }
    
    /// 解禁を手動で終了し、次回の解禁をスケジュール（テスト用 / サーバー同期用）
    func completeCurrentRevealAndScheduleNext(basedOn endTime: Date? = nil) {
        let baseTime = endTime ?? Date()
        
        // 現在の解禁を終了
        if isGloballyRevealed {
            isGloballyRevealed = false
            saveLastRevealEndTime(baseTime)
        }
        
        // 次回解禁をスケジュール
        let nextTime = Self.calculateNextRevealTime(from: baseTime)
        scheduleNextReveal(at: nextTime)
        
        // ユーザーの達成状態をリセット（新しいサイクル開始）
        hasUserCompletedGoal = false
    }
    
    /// 強制的に即座に解禁（テスト用）
    func forceRevealNow() {
        performGlobalReveal()
    }
    
    /// システムをリセット（テスト用）
    func resetSystem() {
        isGloballyRevealed = false
        hasUserCompletedGoal = false
        revealHistory.removeAll()
        saveRevealHistory()
        
        // 次回解禁を現在時刻から計算
        nextGlobalRevealTime = Self.calculateNextRevealTime(from: Date())
        saveGlobalRevealTime()
        
        #if DEBUG
        print("[GlobalSecretReveal] System reset")
        #endif
    }
    
    // MARK: - Private Methods
    
    /// グローバル解禁を実行
    private func performGlobalReveal() {
        isGloballyRevealed = true
        
        // イベントを記録
        let event = RevealEvent(
            revealTime: nextGlobalRevealTime,
            actualRevealTime: Date(),
            userWasReady: hasUserCompletedGoal
        )
        revealHistory.append(event)
        saveRevealHistory()
        
        #if DEBUG
        print("[GlobalSecretReveal] 🎉 Global reveal activated!")
        print("[GlobalSecretReveal] User was ready: \(hasUserCompletedGoal)")
        #endif
        
        // プッシュ通知を送信（アプリがバックグラウンドの場合）
        sendRevealNotification()
        
        // ハプティクフィードバック
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// 定期チェックタイマーを開始
    private func startPeriodicCheck() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.checkGlobalRevealStatus()
        }
    }
    
    /// 次回解禁時刻を計算（ランダムスパン + 夜間回避）
    static func calculateNextRevealTime(from baseTime: Date, seed: UInt64? = nil) -> Date {
        let minSpan: TimeInterval = 12 * 60 * 60  // 12時間
        let maxSpan: TimeInterval = 48 * 60 * 60  // 48時間
        
        // ランダムスパンを生成
        let randomSpan: TimeInterval
        if let seed = seed {
            var generator = SeededRandomGenerator(seed: seed)
            randomSpan = TimeInterval.random(in: minSpan...maxSpan, using: &generator)
        } else {
            randomSpan = TimeInterval.random(in: minSpan...maxSpan)
        }
        
        // 候補時刻を計算
        let candidateTime = baseTime.addingTimeInterval(randomSpan)
        
        // 夜間回避処理
        return adjustForNightHours(candidateTime)
    }
    
    /// 夜間(22:00-09:00)を避けるように調整
    static func adjustForNightHours(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        
        guard let hour = components.hour else {
            return date
        }
        
        // 22:00-23:59 または 00:00-08:59 の場合
        if hour >= 22 || hour < 9 {
            // 翌日（または当日）の 09:00-21:59 にランダム設定
            var targetDay = date
            
            // 22時台なら翌日に
            if hour >= 22 {
                targetDay = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            }
            
            // 09:00を取得
            guard let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: targetDay) else {
                return date
            }
            
            // 21:59を取得
            guard let end = calendar.date(bySettingHour: 21, minute: 59, second: 0, of: start) else {
                return date
            }
            
            // 09:00-21:59の間でランダム
            let range = end.timeIntervalSince(start)
            let randomOffset = TimeInterval.random(in: 0...range)
            
            return start.addingTimeInterval(randomOffset)
        }
        
        return date
    }
    
    /// グローバル解禁時刻を保存
    private func saveGlobalRevealTime() {
        userDefaults.set(nextGlobalRevealTime.timeIntervalSince1970, forKey: globalRevealTimeKey)
    }
    
    /// 前回の解禁終了時刻を保存
    private func saveLastRevealEndTime(_ time: Date) {
        userDefaults.set(time.timeIntervalSince1970, forKey: lastRevealEndTimeKey)
    }
    
    /// 解禁履歴を保存
    private func saveRevealHistory() {
        if let encoded = try? JSONEncoder().encode(revealHistory) {
            userDefaults.set(encoded, forKey: revealHistoryKey)
        }
    }
    
    /// 解禁履歴を読み込み
    private func loadRevealHistory() {
        if let data = userDefaults.data(forKey: revealHistoryKey),
           let decoded = try? JSONDecoder().decode([RevealEvent].self, from: data) {
            revealHistory = decoded
        }
    }
    
    /// プッシュ通知をスケジュール
    private func scheduleRevealNotification(at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "現像が完了しました！"
        content.body = "今すぐチェック！みんなの写真が一斉に解禁されました🎉"
        content.sound = .default
        content.badge = 1
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "globalSecretReveal",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                #if DEBUG
                print("[GlobalSecretReveal] Notification scheduling error: \(error)")
                #endif
            }
        }
    }
    
    /// 即座にプッシュ通知を送信
    private func sendRevealNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🎉 現像完了！"
        content.body = "みんなの写真が解禁されました！今すぐアプリを開いてチェックしよう！"
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "globalSecretRevealNow",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Supporting Types

/// グローバル閲覧ポリシー
enum GlobalViewPolicy: String, Codable {
    /// 自分が未完了でも他人の写真は見れる
    case viewOthersEvenIfIncomplete
    
    /// 自分が完了するまで全て見れない
    case blockAllUntilSelfComplete
}

/// 解禁イベントの記録
struct RevealEvent: Codable, Identifiable {
    let id = UUID()
    let revealTime: Date          // 予定された解禁時刻
    let actualRevealTime: Date    // 実際の解禁時刻
    let userWasReady: Bool        // ユーザーが準備完了していたか
    
    enum CodingKeys: String, CodingKey {
        case revealTime, actualRevealTime, userWasReady
    }
}

/// シード付き乱数生成器（テスト用）
struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        // xorshift64*
        var x = state
        x ^= x >> 12
        x ^= x << 25
        x ^= x >> 27
        state = x
        return x &* 2685821657736338717
    }
}

// MARK: - SwiftUI Integration

/// グローバル解禁状態を監視するビューモディファイア
struct GlobalRevealStatusModifier: ViewModifier {
    @State private var manager = GlobalSecretRevealManager.shared
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                manager.checkGlobalRevealStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                manager.checkGlobalRevealStatus()
            }
    }
}

extension View {
    /// グローバル解禁状態の監視を有効にする
    func monitorGlobalRevealStatus() -> some View {
        modifier(GlobalRevealStatusModifier())
    }
}
