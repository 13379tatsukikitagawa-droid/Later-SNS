// このファイルは重複のため無効化されました
// メインの実装は FollowingManager.swift を参照してください

/*
import Foundation
import SwiftUI

// MARK: - Following Manager

/// フォロー（友達）関係を管理するシングルトンマネージャー
@Observable
class FollowingManager {
    static let shared = FollowingManager()
    
    // フォロー中のユーザーIDセット
    private(set) var followingUserIDs: [String] = []
    
    private init() {
        loadFollowing()
    }
    
    // MARK: - Public Methods
    
    /// 指定したユーザーをフォロー中かチェック
    func isFollowing(userID: String) -> Bool {
        followingUserIDs.contains(userID)
    }
    
    /// フォロー/フォロー解除をトグル
    func toggleFollow(userID: String) {
        if isFollowing(userID: userID) {
            // フォロー解除
            followingUserIDs.removeAll { $0 == userID }
        } else {
            // フォロー追加
            followingUserIDs.append(userID)
        }
        saveFollowing()
    }
    
    /// フォロー中のユーザー数
    var followingCount: Int {
        followingUserIDs.count
    }
    
    /// すべてのフォローをクリア（デバッグ用）
    func clearAll() {
        followingUserIDs.removeAll()
        saveFollowing()
    }
    
    // MARK: - Private Methods (Persistence)
    
    private func saveFollowing() {
        UserDefaults.standard.set(followingUserIDs, forKey: "followingUserIDs")
    }
    
    private func loadFollowing() {
        if let saved = UserDefaults.standard.array(forKey: "followingUserIDs") as? [String] {
            followingUserIDs = saved
        }
    }
}
*/
