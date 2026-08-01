#if canImport(SwiftUI)
import SwiftUI
import SwiftData

/// Profile画面のツールバーに追加するInboxボタンの拡張
extension ProfileView { // unique extension in this target
    var inboxButton: some View {
        Button(action: {
            // TODO: Show message inbox
        }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                
                // Unread badge
                if hasUnreadMessages {
                    Circle()
                        .fill(Color.brandGreen)
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -4)
                }
            }
        }
    }
    
    private var hasUnreadMessages: Bool {
        // TODO: Check for unread messages in SwiftData
        false
    }
}

/// フォロー中ユーザー一覧画面の改良版（チャット機能付き）
struct FollowingUsersListViewEnhanced: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    @State private var selectedUser: UserProfile?
    @State private var showingUserDetail = false
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    private var followingUsers: [UserProfile] {
        currentUser?.following ?? []
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if followingUsers.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            headerSection
                            
                            VStack(spacing: 12) {
                                ForEach(followingUsers) { user in
                                    FollowingUserCardEnhanced(user: user)
                                        .onTapGesture {
                                            selectedUser = user
                                            showingUserDetail = true
                                            HapticsManager.tick()
                                        }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("Following")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showingUserDetail) {
                if let user = selectedUser {
                    UserDetailView(user: user)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(.brandGreen)
                Text("\(followingUsers.count) Following")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            
            Text("タップしてメッセージを送る")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal, 16)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("まだ誰もフォローしていません")
                .font(.title3.bold())
                .foregroundStyle(.white)
            
            Text("興味のあるユーザーをフォローして\nつながりを広げましょう")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

/// フォロー中ユーザーカード（改良版）
struct FollowingUserCardEnhanced: View {
    let user: UserProfile
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile image
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.brandGreen, .brandGreen.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
                .overlay(
                    Text(user.name.prefix(1))
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                )
            
            // User info
            VStack(alignment: .leading, spacing: 6) {
                Text(user.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if !user.bio.isEmpty {
                    Text(user.bio)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Arrow icon
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.caption)
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
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: UserProfile.self,
        configurations: config
    )
    
    return FollowingUsersListViewEnhanced()
        .modelContainer(container)
}
#endif
