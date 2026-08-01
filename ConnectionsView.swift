import SwiftUI
import SwiftData
import UIKit
import PhotosUI
import CoreImage.CIFilterBuiltins

// MARK: - モックユーザーモデル
struct MockUser: Identifiable {
    let id: String
    let name: String
    let username: String
    let bio: String
    let profileImageName: String?
    let profileColor: Color
}

// MARK: - モックユーザーデータベース
class MockUserDatabase {
    static let shared = MockUserDatabase()
    
    private let users: [MockUser] = [
        MockUser(id: "user_001", name: "田中太郎", username: "tanaka_taro", bio: "写真が好きです📸", profileImageName: "camera.fill", profileColor: .blue),
        MockUser(id: "user_002", name: "佐藤花子", username: "sato_hanako", bio: "旅行と美味しいもの🌍", profileImageName: "airplane", profileColor: .purple),
        MockUser(id: "user_003", name: "鈴木一郎", username: "suzuki_ichiro", bio: "音楽とアート🎵", profileImageName: "music.note", profileColor: .orange),
        MockUser(id: "user_004", name: "高橋美咲", username: "takahashi_misaki", bio: "カフェ巡り☕️", profileImageName: "cup.and.saucer.fill", profileColor: .pink),
        MockUser(id: "user_005", name: "伊藤健太", username: "ito_kenta", bio: "スポーツ観戦が趣味⚽️", profileImageName: "sportscourt.fill", profileColor: Color(red: 0.2, green: 0.8, blue: 0.5)),
    ]
    
    func searchUsers(query: String) -> [MockUser] {
        if query.isEmpty { return users }
        return users.filter { user in
            user.name.localizedCaseInsensitiveContains(query) ||
            user.username.localizedCaseInsensitiveContains(query) ||
            user.bio.localizedCaseInsensitiveContains(query)
        }
    }
    
    func getRecommendedUsers(excludingIDs: [String], count: Int) -> [MockUser] {
        let filtered = users.filter { !excludingIDs.contains($0.id) }
        return Array(filtered.prefix(count))
    }
    
    func getUserByID(_ id: String) -> MockUser? {
        users.first { $0.id == id }
    }
}



// MARK: - QRスキャナービュー（プレースホルダー）
struct QRScannerView: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("QRコードスキャナー")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    Text("実際のカメラ機能は実装が必要です")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // テスト用ボタン
                    Button("テストユーザーをスキャン") {
                        onScan("laterapp://user?id=user_001&name=TanakaTaro")
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("QRスキャン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - ユーザープロフィール詳細ビュー（プレースホルダー）
struct UserProfileDetailView: View {
    let user: MockUser
    @Environment(\.dismiss) private var dismiss
    @State private var followingManager = FollowingManager.shared
    
    private var isFollowing: Bool {
        followingManager.isFollowing(userID: user.id)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // プロフィール画像
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [user.profileColor.opacity(0.6), user.profileColor.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                            
                            if let iconName = user.profileImageName {
                                Image(systemName: iconName)
                                    .font(.system(size: 48))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        .padding(.top, 40)
                        
                        // ユーザー情報
                        VStack(spacing: 8) {
                            Text(user.name)
                                .font(.title.bold())
                                .foregroundStyle(.white)
                            
                            Text("@\(user.username)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Text(user.bio)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                        }
                        
                        // フォローボタン
                        Button(action: {
                            followingManager.toggleFollow(userID: user.id)
                        }) {
                            Text(isFollowing ? "フォロー中" : "フォロー")
                                .font(.headline)
                                .foregroundStyle(isFollowing ? .white.opacity(0.9) : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(isFollowing ? Color.gray.opacity(0.4) : Color(red: 0.2, green: 0.8, blue: 0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("プロフィール")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - プレビュー用
// 注意: ConnectionsView, UserSearchResultRow, InviteBannerView, InviteFriendsSheet は
// ConnectionsView_Fixed.swift で定義されています



