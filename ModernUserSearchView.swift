import SwiftUI
import SwiftData

// MARK: - Modern User Search View
/// ユーザー検索画面（モダンなUIデザイン）
struct ModernUserSearchView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var searchResults: [SearchUserResult] = []
    @State private var followingManager = FollowingManager.shared
    
    // サンプルデータ（実際のアプリではAPIやSwiftDataから取得）
    private let sampleUsers: [SearchUserResult] = [
        SearchUserResult(id: "user1", userName: "田中太郎", userID: "tanaka_taro", bio: "デザイナー | 東京在住", isVerified: true),
        SearchUserResult(id: "user2", userName: "佐藤花子", userID: "sato_hanako", bio: "フォトグラファー📸 | 旅行が大好き", isVerified: false),
        SearchUserResult(id: "user3", userName: "鈴木一郎", userID: "suzuki_ichiro", bio: "エンジニア👨‍💻 | SwiftUIが好き", isVerified: true),
        SearchUserResult(id: "user4", userName: "高橋美咲", userID: "takahashi_misaki", bio: "イラストレーター🎨 | 猫好き🐱", isVerified: false),
        SearchUserResult(id: "user5", userName: "伊藤健太", userID: "ito_kenta", bio: "ライター✍️ | テクノロジーとライフスタイル", isVerified: false),
        SearchUserResult(id: "user6", userName: "山田大輔", userID: "yamada_daisuke", bio: "起業家 | スタートアップ経営", isVerified: true),
        SearchUserResult(id: "user7", userName: "中村愛美", userID: "nakamura_manami", bio: "ヨガインストラクター🧘‍♀️", isVerified: false),
        SearchUserResult(id: "user8", userName: "小林翔太", userID: "kobayashi_shota", bio: "料理人🍳 | 和食専門", isVerified: false),
    ]
    
    // フィルタリングされた検索結果
    private var filteredResults: [SearchUserResult] {
        if searchText.isEmpty {
            return []
        }
        
        let lowercasedSearch = searchText.lowercased()
        return sampleUsers.filter { user in
            user.userName.lowercased().contains(lowercasedSearch) ||
            user.userID.lowercased().contains(lowercasedSearch)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 検索バー
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    
                    // 検索結果
                    if searchText.isEmpty {
                        emptySearchView
                    } else if filteredResults.isEmpty {
                        noResultsView
                    } else {
                        searchResultsList
                    }
                }
            }
            .navigationTitle("友達を検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
    }
    
    // MARK: - サブビュー
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            // 検索アイコン
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(searchText.isEmpty ? .white.opacity(0.4) : .brandGreen)
            
            // テキストフィールド
            TextField("ユーザー名またはIDで検索", text: $searchText)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.search)
            
            // クリアボタン
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    HapticsManager.swipeFeedback()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            searchText.isEmpty ? Color.white.opacity(0.1) : Color.brandGreen.opacity(0.3),
                            lineWidth: 1.5
                        )
                )
        )
    }
    
    private var emptySearchView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // アイコン
            Image(systemName: "person.2.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))
                .symbolEffect(.pulse)
            
            // テキスト
            VStack(spacing: 12) {
                Text("友達を探しましょう")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("ユーザー名やIDで検索して\n友達とつながりましょう")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
    
    private var noResultsView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // アイコン
            Image(systemName: "person.slash.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))
            
            // テキスト
            VStack(spacing: 12) {
                Text("ユーザーが見つかりません")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                
                Text("「\(searchText)」に一致するユーザーはいませんでした")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
    
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredResults) { user in
                    SearchUserCard(
                        user: user,
                        isFollowing: followingManager.isFollowing(userID: user.id),
                        onFollowToggle: {
                            toggleFollow(userID: user.id)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - メソッド
    
    private func toggleFollow(userID: String) {
        let isNowFollowing = followingManager.toggleFollow(userID: userID)
        
        // ハプティクス
        HapticsManager.cardChange()
        
        print(isNowFollowing ? "✅ フォローしました: \(userID)" : "❌ フォロー解除しました: \(userID)")
    }
}

// MARK: - Search User Result
/// 検索結果のユーザー情報
struct SearchUserResult: Identifiable {
    let id: String
    let userName: String
    let userID: String
    let bio: String
    let isVerified: Bool
}

// MARK: - Search User Card
/// 検索結果のユーザーカード
fileprivate struct SearchUserCard: View {
    let user: SearchUserResult
    let isFollowing: Bool
    let onFollowToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // プロフィール画像
            profileImage
            
            // ユーザー情報
            VStack(alignment: .leading, spacing: 6) {
                // ユーザー名 + 認証バッジ
                HStack(spacing: 6) {
                    Text(user.userName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                    }
                }
                
                // ユーザーID
                Text("@\(user.userID)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                
                // バイオ
                if !user.bio.isEmpty {
                    Text(user.bio)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // フォローボタン
            followButton
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var profileImage: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.cyan.opacity(0.6), .purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 56, height: 56)
            .overlay(
                Text(String(user.userName.prefix(1)))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
    
    private var followButton: some View {
        Button(action: onFollowToggle) {
            HStack(spacing: 6) {
                Image(systemName: isFollowing ? "checkmark" : "person.badge.plus")
                    .font(.system(size: 13, weight: .semibold))
                
                Text(isFollowing ? "フォロー中" : "フォロー")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(isFollowing ? .white : Color(red: 0.05, green: 0.05, blue: 0.05))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isFollowing ? Color.white.opacity(0.15) : Color.brandGreen)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isFollowing ? Color.white.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - プレビュー
#Preview {
    ModernUserSearchView()
}
