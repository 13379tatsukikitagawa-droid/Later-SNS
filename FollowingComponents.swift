import SwiftUI

// MARK: - フォローボタンコンポーネント
/// 他のユーザーをフォロー/フォロー解除するためのボタン
struct SimpleFollowButton: View {
    let userID: String
    
    // アニメーション用
    @State private var isAnimating = false
    
    private let followingManager = FollowingManager.shared
    
    private var isFollowing: Bool {
        followingManager.isFollowing(userID: userID)
    }
    
    var body: some View {
        Button {
            handleFollowToggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isFollowing ? "checkmark" : "plus")
                    .font(.system(size: 14, weight: .semibold))
                
                Text(isFollowing ? "フォロー中" : "フォロー")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(isFollowing ? Color.white : Color.brandBlack)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isFollowing ? Color.white.opacity(0.2) : Color.brandGreen)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isFollowing ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isAnimating ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
    }
    
    private func handleFollowToggle() {
        // ハプティクフィードバック
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // アニメーション
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isAnimating = true
        }
        
        // フォロー状態をトグル
        followingManager.toggleFollow(userID: userID)
        
        // アニメーションを元に戻す
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isAnimating = false
            }
        }
    }
}

// MARK: - フォロー状態インジケーター
/// フォロー中かどうかを示すバッジ
struct FollowingBadge: View {
    let userID: String
    
    private let followingManager = FollowingManager.shared
    
    private var isFollowing: Bool {
        followingManager.isFollowing(userID: userID)
    }
    
    var body: some View {
        if isFollowing {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                
                Text("フォロー中")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Color.brandGreen)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.brandGreen.opacity(0.15))
            )
        }
    }
}

// MARK: - ユーザーリストアイテム（使用例）
/// フォローボタンを含むユーザーリストのアイテム例
struct UserListItem: View {
    let userID: String
    let userName: String
    let userImage: Image?
    
    var body: some View {
        HStack(spacing: 12) {
            // プロフィール画像
            if let image = userImage {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color.gray)
                    )
            }
            
            // ユーザー情報
            VStack(alignment: .leading, spacing: 4) {
                Text(userName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
                
                FollowingBadge(userID: userID)
            }
            
            Spacer()
            
            // フォローボタン
            SimpleFollowButton(userID: userID)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - フォロー中ユーザー一覧画面（使用例）
struct FollowingListView: View {
    private let followingManager = FollowingManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // サンプルユーザーデータ（実際のアプリではSwiftDataなどから取得）
    private let sampleUsers: [(id: String, name: String)] = [
        ("user1", "田中太郎"),
        ("user2", "佐藤花子"),
        ("user3", "鈴木一郎"),
        ("user4", "高橋美咲"),
        ("user5", "伊藤健太"),
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 12) {
                        if followingManager.followingCount == 0 {
                            emptyStateView
                        } else {
                            followingListContent
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("フォロー中")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .foregroundStyle(Color.white)
                }
            }
        }
    }
    
    // MARK: - サブビュー
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundStyle(Color.secondary)
            
            Text("まだ誰もフォローしていません")
                .font(.headline)
                .foregroundStyle(Color.white)
            
            Text("興味のあるユーザーをフォローして、つながりを広げましょう")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private var followingListContent: some View {
        VStack(spacing: 12) {
            // フォロー中のユーザーのみを表示
            ForEach(sampleUsers.filter { followingManager.isFollowing(userID: $0.id) }, id: \.id) { user in
                UserListItem(
                    userID: user.id,
                    userName: user.name,
                    userImage: nil
                )
            }
            
            // フォロー数の表示
            footerView
        }
    }
    
    private var footerView: some View {
        VStack(spacing: 8) {
            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical, 16)
            
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(Color.brandGreen)
                
                Text("合計 \(followingManager.followingCount) 人のユーザーをフォロー中")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(.top, 16)
    }
}

// MARK: - ユーザー検索画面（使用例）
struct UserSearchView: View {
    @State private var searchText = ""
    private let followingManager = FollowingManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // サンプルユーザーデータ
    private let allUsers: [(id: String, name: String)] = [
        ("user1", "田中太郎"),
        ("user2", "佐藤花子"),
        ("user3", "鈴木一郎"),
        ("user4", "高橋美咲"),
        ("user5", "伊藤健太"),
        ("user6", "山田大輔"),
        ("user7", "中村愛美"),
        ("user8", "小林翔太"),
    ]
    
    private var filteredUsers: [(id: String, name: String)] {
        if searchText.isEmpty {
            return allUsers
        } else {
            return allUsers.filter { $0.name.contains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 検索バー
                    searchBar
                    
                    // ユーザーリスト
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(filteredUsers, id: \.id) { user in
                                UserListItem(
                                    userID: user.id,
                                    userName: user.name,
                                    userImage: nil
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("ユーザーを検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .foregroundStyle(Color.white)
                }
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.secondary)
            
            TextField("ユーザー名で検索", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.white)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
        .padding()
    }
}

// MARK: - プレビュー

#if DEBUG
struct SimpleFollowButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
            
            VStack(spacing: 20) {
                SimpleFollowButton(userID: "user1")
                SimpleFollowButton(userID: "user2")
                SimpleFollowButton(userID: "user3")
            }
        }
        .previewDisplayName("Simple Follow Button")
    }
}

struct UserListItem_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
            
            VStack {
                UserListItem(
                    userID: "user1",
                    userName: "田中太郎",
                    userImage: nil
                )
                .padding()
            }
        }
        .previewDisplayName("User List Item")
    }
}

struct FollowingListView_Previews: PreviewProvider {
    static var previews: some View {
        FollowingListView()
            .previewDisplayName("Following List View")
    }
}

struct UserSearchView_Previews: PreviewProvider {
    static var previews: some View {
        UserSearchView()
            .previewDisplayName("User Search View")
    }
}
#endif
