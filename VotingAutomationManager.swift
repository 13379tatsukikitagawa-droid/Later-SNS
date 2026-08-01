import SwiftUI
import SwiftData

/// 🤖 投票締め切りと「栄光の1枚」選出の自動実行マネージャー
@MainActor
@Observable
class VotingAutomationManager {
    static let shared = VotingAutomationManager()
    
    private var checkTimer: Timer?
    private var votingManager = VotingManager.shared
    
    private init() {}
    
    /// 定期チェックを開始（1分ごと）
    func startMonitoring() {
        stopMonitoring()
        
        checkTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAndProcessVoting()
            }
        }
        
        print("🤖 Voting automation monitoring started")
    }
    
    /// 監視を停止
    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
    
    /// 投票締め切りをチェックし、必要に応じてベストショット選出
    private func checkAndProcessVoting() async {
        guard let session = votingManager.activeVotingSession else {
            return
        }
        
        // 投票締め切りをチェック
        if session.isClosed {
            print("🏁 Voting session closed, selecting best shot...")
            
            // ここで実際のSwiftDataコンテキストを使ってベストショット選出
            // (実装は使用するコンテキストに依存)
            
            votingManager.closeSession()
        }
    }
}

/// 📱 アプリ全体でバックグラウンド処理を管理
@MainActor
class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    private init() {}
    
    /// アプリ起動時に各種バックグラウンドタスクを開始
    func startBackgroundTasks() {
        // 投票自動化
        VotingAutomationManager.shared.startMonitoring()
        
        print("🚀 Background tasks started")
    }
    
    /// アプリ終了時にクリーンアップ
    func stopBackgroundTasks() {
        VotingAutomationManager.shared.stopMonitoring()
        
        print("🛑 Background tasks stopped")
    }
}
