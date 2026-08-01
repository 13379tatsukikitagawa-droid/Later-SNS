import SwiftUI

import SwiftUI

// MARK: - ユーザープロフィール詳細ビュー
/// QRスキャンや検索から遷移するユーザープロフィール詳細画面

struct UserProfileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("themeColor") private var themeColorName: String = "green"
    @State private var followingManager = FollowingManager.shared
    
    let user: MockUser
    
    // アニメーション用
    @State private var profileOpacity: Double = 0
    @State private var profileScale: CGFloat = 0.9
    
    // テーマカラー
    private var themeColor: Color {
        switch themeColorName {
        case "green": return .brandGreen
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        default: return .brandGreen
        }
    }
    
    // フォロー状態
    private var isFollowing: Bool {
        followingManager.isFollowing(userID: user.id)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // プロフィールヘッダー
                        profileHeader
                            .padding(.top, 20)
                            .opacity(profileOpacity)
                            .scaleEffect(profileScale)
                        
                        // バイオセクション
                        bioSection
                        
                        // 統計情報（ダミー）
                        statsSection
                        
                        // アクションボタン
                        actionButtons
                            .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("プロフィール")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .onAppear {
                // プロフィール表示アニメーション
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                    profileOpacity = 1.0
                    profileScale = 1.0
                }
            }
        }
    }
    
    // MARK: - プロフィールヘッダー
    
    private var profileHeader: some View {
        VStack(spacing: 24) {
            // プロフィール画像
            profileImage
            
            // ユーザー名とID
            VStack(spacing: 6) {
                Text(user.name)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("@\(user.username)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
    
    // プロフィール画像
    private var profileImage: some View {
        ZStack {
            // 背景のグラデーションサークル
            Circle()
                .fill(
                    LinearGradient(
                        colors: [user.profileColor.opacity(0.6), user.profileColor.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 140)
            
            // アイコン
            if let iconName = user.profileImageName {
                Image(systemName: iconName)
                    .font(.system(size: 60))
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .overlay(
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [user.profileColor, user.profileColor.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
        )
        .shadow(color: user.profileColor.opacity(0.4), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - バイオセクション
    
    private var bioSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "text.quote")
                    .font(.system(size: 16))
                    .foregroundStyle(themeColor)
                
                Text("自己紹介")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(user.bio)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }
    
    // MARK: - 統計情報セクション（ダミー）
    
    private var statsSection: some View {
        HStack(spacing: 32) {
            StatItem(value: Int.random(in: 10...100), label: "投稿")
            StatItem(value: Int.random(in: 50...500), label: "フォロワー")
            StatItem(value: Int.random(in: 20...200), label: "フォロー中")
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - アクションボタン
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // フォローボタン
            followButton
            
            // メッセージボタン（将来実装）
            messageButton
        }
    }
    
    private var followButton: some View {
        Button {
            toggleFollow()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isFollowing ? "checkmark.circle.fill" : "person.badge.plus.fill")
                    .font(.system(size: 16, weight: .semibold))
                
                Text(isFollowing ? "フォロー中" : "フォローする")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                Group {
                    if isFollowing {
                        // フォロー中の場合は灰色
                        Color.white.opacity(0.15)
                    } else {
                        // フォローしていない場合はテーマカラー
                        LinearGradient(
                            colors: [themeColor, themeColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(
                color: isFollowing ? .clear : themeColor.opacity(0.4),
                radius: 15,
                x: 0,
                y: 8
            )
        }
        .buttonStyle(BounceButtonStyle())
    }
    
    private var messageButton: some View {
        Button {
            // メッセージ機能（将来実装）
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "message.fill")
                    .font(.system(size: 16, weight: .semibold))
                
                Text("メッセージ")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.white.opacity(0.08))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(BounceButtonStyle())
    }
    
    // MARK: - アクション
    
    private func toggleFollow() {
        let isNowFollowing = followingManager.toggleFollow(userID: user.id)
        
        // ハプティクスフィードバック
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if isNowFollowing {
            print("✅ \(user.name) をフォローしました")
        } else {
            print("❌ \(user.name) のフォローを解除しました")
        }
    }
}

// MARK: - 統計アイテム
struct StatItem: View {
    let value: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.gray)
        }
    }
}

// MARK: - プレビュー
#Preview {
    UserProfileDetailView(
        user: MockUser(
            id: "user_001",
            name: "田中太郎",
            username: "tanaka_taro",
            bio: "デザイナー 🎨 | 東京在住 | 美しいUIを作ることが好き",
            profileImageName: "paintbrush.fill",
            profileColor: .purple
        )
    )
}
