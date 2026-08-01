import SwiftUI
import Foundation
internal import Combine

// MARK: - フォロー管理マネージャー
/// ユーザーのフォロー情報を永続化して管理するクラス
@Observable
class FollowingManager {
    // シングルトンインスタンス
    static let shared = FollowingManager()
    
    // フォロー中のユーザーIDリスト（内部的に保持）
    private var followingIDs: [String] = []
    
    // AppStorageのキー
    private let storageKey = "followingUserIDs"
    
    // UserDefaultsインスタンス
    private let userDefaults = UserDefaults.standard
    
    // MARK: - 初期化
    private init() {
        loadFollowingIDs()
    }
    
    // MARK: - 公開プロパティ
    
    /// フォロー中のユーザーID配列（読み取り専用）
    var allFollowingIDs: [String] {
        followingIDs
    }
    
    /// フォロー中のユーザー数
    var followingCount: Int {
        followingIDs.count
    }
    
    // MARK: - フォロー判定
    
    /// 指定したユーザーIDが既にフォロー中かどうかを判定
    /// - Parameter userID: チェックするユーザーID
    /// - Returns: フォロー中の場合はtrue、それ以外はfalse
    func isFollowing(userID: String) -> Bool {
        followingIDs.contains(userID)
    }
    
    // MARK: - フォロー追加・削除
    
    /// ユーザーをフォローする
    /// - Parameter userID: フォローするユーザーID
    /// - Returns: 追加に成功した場合はtrue（既にフォロー中の場合はfalse）
    @discardableResult
    func follow(userID: String) -> Bool {
        // 既にフォロー中の場合は追加しない
        guard !isFollowing(userID: userID) else {
            return false
        }
        
        followingIDs.append(userID)
        saveFollowingIDs()
        return true
    }
    
    /// ユーザーのフォローを解除する
    /// - Parameter userID: フォロー解除するユーザーID
    /// - Returns: 削除に成功した場合はtrue（フォローしていない場合はfalse）
    @discardableResult
    func unfollow(userID: String) -> Bool {
        guard let index = followingIDs.firstIndex(of: userID) else {
            return false
        }
        
        followingIDs.remove(at: index)
        saveFollowingIDs()
        return true
    }
    
    /// フォロー状態をトグルする（フォロー中なら解除、未フォローならフォロー）
    /// - Parameter userID: トグルするユーザーID
    /// - Returns: トグル後のフォロー状態（true=フォロー中、false=未フォロー）
    @discardableResult
    func toggleFollow(userID: String) -> Bool {
        if isFollowing(userID: userID) {
            unfollow(userID: userID)
            return false
        } else {
            follow(userID: userID)
            return true
        }
    }
    
    // MARK: - 一括操作
    
    /// 複数のユーザーを一度にフォローする
    /// - Parameter userIDs: フォローするユーザーIDの配列
    func followMultiple(userIDs: [String]) {
        var hasChanges = false
        
        for userID in userIDs {
            if !isFollowing(userID: userID) {
                followingIDs.append(userID)
                hasChanges = true
            }
        }
        
        if hasChanges {
            saveFollowingIDs()
        }
    }
    
    /// すべてのフォローを解除する
    func unfollowAll() {
        followingIDs.removeAll()
        saveFollowingIDs()
    }
    
    /// すべてのフォローを解除する（別名）
    func clearAll() {
        unfollowAll()
    }
    
    // MARK: - データの永続化
    
    /// UserDefaultsからフォローリストを読み込む
    private func loadFollowingIDs() {
        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            followingIDs = decoded
        } else {
            followingIDs = []
        }
    }
    
    /// UserDefaultsにフォローリストを保存する
    private func saveFollowingIDs() {
        if let encoded = try? JSONEncoder().encode(followingIDs) {
            userDefaults.set(encoded, forKey: storageKey)
        }
    }
    
    // MARK: - デバッグ・開発用
    
    /// すべてのフォローデータをリセット（開発用）
    func resetAll() {
        followingIDs.removeAll()
        userDefaults.removeObject(forKey: storageKey)
    }
    
    /// 現在のフォローリストを出力（デバッグ用）
    func printFollowingList() {
        print("📋 Following IDs (\(followingCount)):")
        for (index, id) in followingIDs.enumerated() {
            print("  \(index + 1). \(id)")
        }
    }
}

// MARK: - AppStorage対応のラッパー（オプション）
/// @AppStorageと同様のプロパティラッパーとして使用できるバージョン
/// 使用例: @FollowingStorage var followingIDs: [String]
@propertyWrapper
struct FollowingStorage: DynamicProperty {
    @ObservedObject private var manager = ObservableFollowingManager.shared
    
    var wrappedValue: [String] {
        get { manager.followingIDs }
        nonmutating set { 
            // 直接設定はサポートしない（follow/unfollowメソッドを使用）
        }
    }
    
    var projectedValue: Binding<[String]> {
        Binding(
            get: { manager.followingIDs },
            set: { _ in }
        )
    }
}

/// ObservableObjectに準拠したFollowingManager（@ObservedObject用）
private class ObservableFollowingManager: ObservableObject {
    static let shared = ObservableFollowingManager()
    
    @Published var followingIDs: [String] = []
    private let storageKey = "followingUserIDs"
    
    private init() {
        loadFollowingIDs()
    }
    
    private func loadFollowingIDs() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            followingIDs = decoded
        }
    }
}

// MARK: - SwiftUI View拡張
extension View {
    /// フォロー状態に応じてビューを条件付きで表示する
    func ifFollowing(_ userID: String, apply modifier: (Self) -> some View) -> some View {
        if FollowingManager.shared.isFollowing(userID: userID) {
            return AnyView(modifier(self))
        } else {
            return AnyView(self)
        }
    }
}
