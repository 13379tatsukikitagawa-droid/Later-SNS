import Foundation
import Combine
import SwiftUI

/// ⏰ 24時間フェーズ管理エンジン
/// 
/// アプリ全体のフェーズ状態を管理し、時間の経過に応じて自動的にフェーズを切り替える。
/// デバッグ用の時刻モック機能も搭載。
@MainActor
class TimeWindowEngine: ObservableObject {
    // MARK: - Singleton
    
    static let shared = TimeWindowEngine()
    
    // MARK: - Published Properties
    
    /// 現在のフェーズ
    @Published private(set) var currentPhase: TimeWindowPhase = .shooting
    
    /// 次のフェーズまでの残り時間（秒）
    @Published private(set) var timeUntilNextPhase: TimeInterval = 0
    
    /// デバッグモードが有効か
    @Published var isDebugModeEnabled: Bool = false {
        didSet {
            if !isDebugModeEnabled {
                // デバッグモード解除時はモック時刻をリセット
                mockCurrentDate = nil
                updatePhase()
            }
        }
    }
    
    /// デバッグ用のモック時刻（nilの場合は実際の時刻を使用）
    @Published var mockCurrentDate: Date? = nil {
        didSet {
            if mockCurrentDate != nil {
                updatePhase()
            }
        }
    }
    
    // MARK: - Private Properties
    
    /// 1秒ごとにフェーズを更新するタイマー
    private var phaseUpdateTimer: Timer?
    
    /// Combineのサブスクリプション保持用
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// 現在の時刻（デバッグモード時はモック時刻を返す）
    var effectiveCurrentDate: Date {
        if isDebugModeEnabled, let mock = mockCurrentDate {
            return mock
        }
        return Date()
    }
    
    // MARK: - Initialization
    
    private init() {
        updatePhase()
        startPhaseUpdateTimer()
        observeSignificantTimeChanges()
    }
    
    // MARK: - Public Methods
    
    /// フェーズを即座に更新
    func updatePhase() {
        let newPhase = TimeWindowPhase.current(at: effectiveCurrentDate)
        
        // フェーズが変更された場合のみ通知
        if newPhase != currentPhase {
            let previousPhase = currentPhase
            currentPhase = newPhase
            
            // フェーズ変更を通知
            NotificationCenter.default.post(
                name: .timeWindowPhaseDidChange,
                object: nil,
                userInfo: [
                    "previousPhase": previousPhase,
                    "currentPhase": currentPhase
                ]
            )
            
            // ハプティクスフィードバック
            triggerPhaseChangeHaptic()
            
            print("⏰ [TimeWindowEngine] フェーズ変更: \(previousPhase.rawValue) → \(currentPhase.rawValue)")
        }
        
        // 次のフェーズまでの残り時間を更新
        timeUntilNextPhase = currentPhase.timeUntilNextPhase(from: effectiveCurrentDate)
    }
    
    /// デバッグ用: 特定のフェーズに強制的に切り替える
    /// - Parameter phase: 切り替え先のフェーズ
    func forcePhase(_ phase: TimeWindowPhase) {
        guard isDebugModeEnabled else {
            print("⚠️ [TimeWindowEngine] デバッグモードが無効です。forcePhase() は動作しません。")
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        
        guard let today = calendar.date(from: components) else { return }
        
        // フェーズの開始時刻を設定
        let targetHour = phase.startHour
        mockCurrentDate = calendar.date(byAdding: .hour, value: targetHour, to: today)
        
        print("🐛 [Debug] フェーズを強制切り替え: \(phase.rawValue) (モック時刻: \(mockCurrentDate?.formatted() ?? "nil"))")
    }
    
    /// デバッグ用: 指定した時刻にジャンプ
    /// - Parameter date: ジャンプ先の時刻
    func jumpToDate(_ date: Date) {
        guard isDebugModeEnabled else {
            print("⚠️ [TimeWindowEngine] デバッグモードが無効です。jumpToDate() は動作しません。")
            return
        }
        
        mockCurrentDate = date
        print("🐛 [Debug] 時刻をジャンプ: \(date.formatted())")
    }
    
    /// カメラ機能が利用可能か
    var isCameraAvailable: Bool {
        currentPhase == .shooting
    }
    
    /// 投票機能が利用可能か
    var isVotingAvailable: Bool {
        currentPhase == .voting
    }
    
    /// 結果表示が利用可能か
    var isResultsAvailable: Bool {
        currentPhase == .results
    }
    
    // MARK: - Private Methods
    
    /// 1秒ごとにフェーズを更新するタイマーを開始
    private func startPhaseUpdateTimer() {
        // 既存のタイマーを停止
        phaseUpdateTimer?.invalidate()
        
        // 新しいタイマーを作成（1秒ごと）
        phaseUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePhase()
            }
        }
    }
    
    /// システムの重要な時刻変更（タイムゾーン変更、日付変更など）を監視
    private func observeSignificantTimeChanges() {
        // 日付が変更された時の通知
        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    print("📅 [TimeWindowEngine] 日付が変更されました")
                    self?.updatePhase()
                }
            }
            .store(in: &cancellables)
        
        // タイムゾーンが変更された時の通知
        NotificationCenter.default.publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    print("🌍 [TimeWindowEngine] タイムゾーンが変更されました")
                    self?.updatePhase()
                }
            }
            .store(in: &cancellables)
    }
    
    /// フェーズ変更時のハプティクスフィードバック
    private func triggerPhaseChangeHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    deinit {
        phaseUpdateTimer?.invalidate()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// フェーズが変更された時に発火する通知
    static let timeWindowPhaseDidChange = Notification.Name("timeWindowPhaseDidChange")
}
