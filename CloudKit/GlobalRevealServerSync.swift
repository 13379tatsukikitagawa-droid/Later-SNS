import Foundation
import SwiftUI

// MARK: - Server Sync Utilities for Global Secret Reveal System
/// サーバーとの同期を行うためのユーティリティ

// MARK: - Server Response Models

/// サーバーから返される次回解禁時刻の情報
struct GlobalRevealScheduleResponse: Codable {
    let nextRevealTime: Date
    let scheduledAt: Date
    let previousRevealTime: Date?
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case nextRevealTime = "next_reveal_time"
        case scheduledAt = "scheduled_at"
        case previousRevealTime = "previous_reveal_time"
        case isActive = "is_active"
    }
}

/// 解禁状態の確認レスポンス
struct GlobalRevealStatusResponse: Codable {
    let isCurrentlyRevealed: Bool
    let nextRevealTime: Date?
    let currentCycleStarted: Date?
    
    enum CodingKeys: String, CodingKey {
        case isCurrentlyRevealed = "is_currently_revealed"
        case nextRevealTime = "next_reveal_time"
        case currentCycleStarted = "current_cycle_started"
    }
}

/// ユーザーの目標達成状態をサーバーに送信
struct UserGoalStatusRequest: Codable {
    let userId: String
    let hasCompletedGoal: Bool
    let completedAt: Date?
    let photoCount: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case hasCompletedGoal = "has_completed_goal"
        case completedAt = "completed_at"
        case photoCount = "photo_count"
    }
}

// MARK: - Server Sync Manager

/// グローバル解禁システムのサーバー同期マネージャー
@Observable
final class GlobalRevealServerSyncManager {
    static let shared = GlobalRevealServerSyncManager()
    
    // MARK: - Configuration
    private let baseURL: String
    private let session: URLSession
    
    // MARK: - State
    private(set) var lastSyncTime: Date?
    private(set) var isSyncing: Bool = false
    private(set) var syncError: Error?
    
    // MARK: - Storage
    private let userDefaults = UserDefaults.standard
    private let lastSyncKey = "lastGlobalRevealSync"
    
    private init(baseURL: String = "https://api.yourapp.com/v1") {
        self.baseURL = baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        
        loadLastSyncTime()
    }
    
    // MARK: - Public API
    
    /// サーバーから最新の解禁スケジュールを取得
    func fetchLatestSchedule() async throws -> GlobalRevealScheduleResponse {
        isSyncing = true
        defer { isSyncing = false }
        
        let url = URL(string: "\(baseURL)/global-reveal/schedule")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addAuthHeader() // 認証ヘッダーを追加
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ServerSyncError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let schedule = try decoder.decode(GlobalRevealScheduleResponse.self, from: data)
        
        // ローカルマネージャーに反映
        syncToLocalManager(schedule: schedule)
        
        lastSyncTime = Date()
        saveLastSyncTime()
        
        return schedule
    }
    
    /// 現在の解禁状態を確認
    func checkRevealStatus() async throws -> GlobalRevealStatusResponse {
        isSyncing = true
        defer { isSyncing = false }
        
        let url = URL(string: "\(baseURL)/global-reveal/status")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addAuthHeader()
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ServerSyncError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(GlobalRevealStatusResponse.self, from: data)
    }
    
    /// ユーザーの目標達成状態をサーバーに送信
    func updateUserGoalStatus(
        userId: String,
        hasCompleted: Bool,
        photoCount: Int
    ) async throws {
        isSyncing = true
        defer { isSyncing = false }
        
        let url = URL(string: "\(baseURL)/users/\(userId)/goal-status")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addAuthHeader()
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = UserGoalStatusRequest(
            userId: userId,
            hasCompletedGoal: hasCompleted,
            completedAt: hasCompleted ? Date() : nil,
            photoCount: photoCount
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(payload)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ServerSyncError.invalidResponse
        }
    }
    
    /// 定期同期を実行（アプリ起動時やフォアグラウンド復帰時）
    func performPeriodicSync() async {
        do {
            let schedule = try await fetchLatestSchedule()
            let status = try await checkRevealStatus()
            
            #if DEBUG
            print("[ServerSync] Schedule synced: \(schedule.nextRevealTime)")
            print("[ServerSync] Current status: \(status.isCurrentlyRevealed ? "Revealed" : "Locked")")
            #endif
            
            syncError = nil
        } catch {
            syncError = error
            #if DEBUG
            print("[ServerSync] Error: \(error)")
            #endif
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func syncToLocalManager(schedule: GlobalRevealScheduleResponse) {
        let manager = GlobalSecretRevealManager.shared
        
        // サーバーの時刻でローカルをアップデート
        if schedule.nextRevealTime != manager.nextGlobalRevealTime {
            manager.scheduleNextReveal(at: schedule.nextRevealTime)
            
            #if DEBUG
            print("[ServerSync] Local schedule updated to: \(schedule.nextRevealTime)")
            #endif
        }
        
        // 即座に状態をチェック
        manager.checkGlobalRevealStatus()
    }
    
    private func loadLastSyncTime() {
        if let timestamp = userDefaults.object(forKey: lastSyncKey) as? TimeInterval {
            lastSyncTime = Date(timeIntervalSince1970: timestamp)
        }
    }
    
    private func saveLastSyncTime() {
        if let time = lastSyncTime {
            userDefaults.set(time.timeIntervalSince1970, forKey: lastSyncKey)
        }
    }
}

// MARK: - Server Sync Error

enum ServerSyncError: LocalizedError {
    case invalidResponse
    case networkError
    case decodingError
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "サーバーからの応答が不正です"
        case .networkError:
            return "ネットワークエラーが発生しました"
        case .decodingError:
            return "データの解析に失敗しました"
        case .unauthorized:
            return "認証エラーが発生しました"
        }
    }
}

// MARK: - URLRequest Extension (認証ヘッダー)

extension URLRequest {
    mutating func addAuthHeader() {
        // 実際のアプリでは、トークンやAPIキーを設定
        // 例: setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        #if DEBUG
        // デバッグ用のダミートークン
        setValue("Bearer debug_token", forHTTPHeaderField: "Authorization")
        #endif
    }
}

// MARK: - SwiftUI Integration

/// サーバー同期状態を表示するビューモディファイア
struct ServerSyncStatusModifier: ViewModifier {
    @State private var syncManager = GlobalRevealServerSyncManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if syncManager.isSyncing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("同期中...")
                            .font(.caption)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.top, 8)
                }
            }
            .task {
                await syncManager.performPeriodicSync()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task {
                    await syncManager.performPeriodicSync()
                }
            }
    }
}

extension View {
    /// サーバー同期の監視と自動同期を有効にする
    func monitorServerSync() -> some View {
        modifier(ServerSyncStatusModifier())
    }
}

// MARK: - Usage Example

/*
 ## サーバー側の実装例 (pseudo-code)
 
 ### 解禁スケジュール取得エンドポイント
 GET /v1/global-reveal/schedule
 
 Response:
 {
   "next_reveal_time": "2026-05-25T15:30:00Z",
   "scheduled_at": "2026-05-24T12:00:00Z",
   "previous_reveal_time": "2026-05-23T10:15:00Z",
   "is_active": true
 }
 
 ### 解禁状態確認エンドポイント
 GET /v1/global-reveal/status
 
 Response:
 {
   "is_currently_revealed": false,
   "next_reveal_time": "2026-05-25T15:30:00Z",
   "current_cycle_started": null
 }
 
 ### ユーザー目標状態更新エンドポイント
 PUT /v1/users/{userId}/goal-status
 
 Request Body:
 {
   "user_id": "user123",
   "has_completed_goal": true,
   "completed_at": "2026-05-24T14:30:00Z",
   "photo_count": 5
 }
 
 Response:
 {
   "success": true,
   "updated_at": "2026-05-24T14:30:00Z"
 }
 
 ## クライアント側の使用例
 
 ```swift
 // アプリ起動時
 Task {
     await GlobalRevealServerSyncManager.shared.performPeriodicSync()
 }
 
 // ユーザーが目標達成したとき
 Task {
     try await GlobalRevealServerSyncManager.shared.updateUserGoalStatus(
         userId: currentUserId,
         hasCompleted: true,
         photoCount: 5
     )
 }
 ```
 */
