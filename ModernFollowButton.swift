import SwiftUI

// MARK: - モダンフォローボタン
/// 他のユーザーをフォロー/フォロー解除するためのモダンなボタン
struct ModernFollowButton: View {
    let userID: String
    let userName: String // オプション：ハプティクスやログ用
    
    @State private var isAnimating = false
    @State private var showCheckmark = false
    
    // フォロー状態を取得
    private var isFollowing: Bool {
        FollowingManager.shared.isFollowing(userID: userID)
    }
    
    var body: some View {
        Button {
            handleFollowAction()
        } label: {
            HStack(spacing: 8) {
                // チェックマークアイコン（フォロー中のみ）
                if isFollowing && showCheckmark {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .transition(.scale.combined(with: .opacity))
                }
                
                // ボタンテキスト
                Text(isFollowing ? "フォロー中" : "フォローする")
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(textColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(minWidth: 140)
            .background(backgroundGradient)
            .clipShape(Capsule())
            .shadow(color: shadowColor, radius: isAnimating ? 12 : 8, x: 0, y: 4)
            .overlay(
                Capsule()
                    .strokeBorder(borderColor, lineWidth: isFollowing ? 1.5 : 0)
            )
            .scaleEffect(isAnimating ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFollowing)
        }
        .buttonStyle(BouncyButtonStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: isFollowing)
    }
    
    // MARK: - スタイル計算プロパティ
    
    /// テキストの色
    private var textColor: Color {
        isFollowing ? .white.opacity(0.8) : .white
    }
    
    /// 背景のグラデーション
    private var backgroundGradient: LinearGradient {
        if isFollowing {
            // フォロー中：グレーのグラデーション
            return LinearGradient(
                colors: [
                    Color(red: 0.4, green: 0.4, blue: 0.4),
                    Color(red: 0.3, green: 0.3, blue: 0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // 未フォロー：青のグラデーション
            return LinearGradient(
                colors: [
                    Color.blue.opacity(0.9),
                    Color.blue.opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    /// シャドウの色
    private var shadowColor: Color {
        isFollowing ? Color.black.opacity(0.3) : Color.blue.opacity(0.4)
    }
    
    /// ボーダーの色
    private var borderColor: Color {
        isFollowing ? Color.white.opacity(0.2) : Color.clear
    }
    
    // MARK: - アクション
    
    /// フォローボタンが押されたときの処理
    private func handleFollowAction() {
        // アニメーション開始
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            isAnimating = true
        }
        
        // フォロー状態をトグル
        let newFollowState = FollowingManager.shared.toggleFollow(userID: userID)
        
        // チェックマーク表示（フォローした場合のみ）
        if newFollowState {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.1)) {
                showCheckmark = true
            }
        } else {
            showCheckmark = false
        }
        
        // ハプティクフィードバック
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // アニメーション終了
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isAnimating = false
            }
        }
        
        // ログ出力（デバッグ用）
        print(newFollowState ? "✅ \(userName)さんをフォローしました" : "❌ \(userName)さんのフォローを解除しました")
    }
}

// MARK: - バウンシーボタンスタイル
/// ボタンを押したときにバウンスするスタイル
private struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - コンパクトフォローボタン（小さいバージョン）
/// リストや小さいスペースに適したコンパクトなフォローボタン
struct CompactFollowButton: View {
    let userID: String
    
    @State private var isAnimating = false
    
    private var isFollowing: Bool {
        FollowingManager.shared.isFollowing(userID: userID)
    }
    
    var body: some View {
        Button {
            handleFollowAction()
        } label: {
            HStack(spacing: 6) {
                if isFollowing {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }
                
                Text(isFollowing ? "フォロー中" : "フォロー")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(isFollowing ? .white.opacity(0.8) : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isFollowing ? Color.gray.opacity(0.6) : Color.blue)
            )
            .scaleEffect(isAnimating ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
    }
    
    private func handleFollowAction() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isAnimating = true
        }
        
        FollowingManager.shared.toggleFollow(userID: userID)
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isAnimating = false
            }
        }
    }
}

// MARK: - 他のユーザーのプロフィール画面例
/// フォローボタンを含む他のユーザーのプロフィール画面のサンプル
struct OtherUserProfileView: View {
    let userID: String
    let userName: String
    let userBio: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // ヘッダー部分
                        profileHeader
                        
                        // バイオグラフィー
                        biographySection
                        
                        // 統計情報（フォロー数など）
                        statsSection
                        
                        // 投稿一覧など
                        postsSection
                    }
                    .padding()
                }
            }
            .navigationTitle(userName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる", systemImage: "xmark") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
    
    // MARK: - サブビュー
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // プロフィール画像
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.7), .purple.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white.opacity(0.8))
                )
                .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)
            
            // ユーザー名
            Text(userName)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            // フォローボタン
            ModernFollowButton(userID: userID, userName: userName)
        }
        .padding(.top, 20)
    }
    
    private var biographySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自己紹介")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
            
            Text(userBio)
                .font(.body)
                .foregroundStyle(.white)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
        }
    }
    
    private var statsSection: some View {
        HStack(spacing: 32) {
            StatItem(value: "42", label: "投稿")
            StatItem(value: "1.2K", label: "フォロワー")
            StatItem(value: "324", label: "フォロー中")
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("投稿")
                .font(.title3.bold())
                .foregroundStyle(.white)
            
            // 投稿のグリッド表示など
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(0..<9, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.white.opacity(0.3))
                        )
                }
            }
        }
    }
}

// MARK: - 統計情報アイテム
private struct StatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

// MARK: - ユーザーリストアイテム（更新版）
/// フォローボタンを含むユーザーリストのアイテム
struct ModernUserListItem: View {
    let userID: String
    let userName: String
    let userImage: Image?
    
    var body: some View {
        HStack(spacing: 16) {
            // プロフィール画像
            if let image = userImage {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(.white.opacity(0.7))
                    )
            }
            
            // ユーザー情報
            VStack(alignment: .leading, spacing: 4) {
                Text(userName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text("@\(userID)")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            
            // コンパクトフォローボタン
            CompactFollowButton(userID: userID)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - プレビュー
#if DEBUG
struct ModernFollowButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("フォローボタンのデモ")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                
                ModernFollowButton(userID: "user1", userName: "田中太郎")
                ModernFollowButton(userID: "user2", userName: "佐藤花子")
                
                Divider()
                    .background(Color.white.opacity(0.2))
                    .padding(.vertical)
                
                Text("コンパクト版")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                HStack(spacing: 20) {
                    CompactFollowButton(userID: "user3")
                    CompactFollowButton(userID: "user4")
                }
            }
            .padding()
        }
        .previewDisplayName("Modern Follow Button")
    }
}

struct OtherUserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        OtherUserProfileView(
            userID: "user1",
            userName: "田中太郎",
            userBio: "デザイナー | 東京在住 | 日々の発見をシェアしています✨"
        )
        .previewDisplayName("Other User Profile View")
    }
}

struct ModernUserListItem_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
            
            VStack(spacing: 12) {
                ModernUserListItem(
                    userID: "user1",
                    userName: "田中太郎",
                    userImage: nil
                )
                
                ModernUserListItem(
                    userID: "user2",
                    userName: "佐藤花子",
                    userImage: nil
                )
            }
            .padding()
        }
        .previewDisplayName("Modern User List Item")
    }
}
#endif
