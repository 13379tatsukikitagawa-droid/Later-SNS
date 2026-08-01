import SwiftUI
import SwiftData
import UIKit
import PhotosUI

// MARK: - ConnectionsView（完全版・修正済み）
/// ユーザー検索、QRスキャン、フォロー管理を統合したビュー

struct ConnectionsView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(sort: \LaterGroup.creationDate, order: .reverse) private var groups: [LaterGroup]
    
    @AppStorage("currentProfileID") private var currentProfileID: String = ""
    @AppStorage("themeColor") private var themeColorName: String = "green"
    @State private var followingManager = FollowingManager.shared
    
    // UI状態
    @State private var searchText: String = ""
    @State private var showingInviteSheet = false
    @State private var showingQRScanner = false
    @State private var selectedUser: MockUser?
    @State private var showingUserProfile = false
    
    // モックデータベース
    private let mockDB = MockUserDatabase.shared
    
    // テーマカラー
    private var themeColor: Color {
        switch themeColorName {
        case "green": return Color.brandGreen
        case "blue": return Color.blue
        case "purple": return Color.purple
        case "orange": return Color.orange
        case "pink": return Color.pink
        default: return Color.brandGreen
        }
    }
    
    private var meProfile: UserProfile? {
        if let id = UUID(uuidString: currentProfileID) {
            return profiles.first(where: { $0.id == id })
        } else {
            return profiles.first
        }
    }
    
    // 検索結果（モックユーザー）
    private var searchResults: [MockUser] {
        if searchText.isEmpty {
            // 検索クエリが空の場合はおすすめユーザーを表示
            return mockDB.getRecommendedUsers(
                excludingIDs: followingManager.allFollowingIDs,
                count: 10
            )
        } else {
            // 検索クエリに基づいてフィルタリング
            return mockDB.searchUsers(query: searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // QRスキャンバナー
                        qrScanBanner
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        
                        // 招待バナー
                        InviteBannerView(action: { showingInviteSheet = true })
                            .padding(.horizontal, 16)
                        
                        // 検索結果セクション
                        searchResultsSection
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Connections")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "ユーザー名または名前で検索"
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        // Show message inbox
                        // TODO: Navigate to MessageInboxView
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(themeColor)
                            
                            // Unread badge (TODO: connect to actual unread count)
                            Circle()
                                .fill(Color.brandGreen)
                                .frame(width: 8, height: 8)
                                .offset(x: 4, y: -4)
                                .opacity(0) // Hidden until we have actual unread messages
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showingQRScanner = true
                    }) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(themeColor)
                    }
                }
            }
            .sheet(isPresented: $showingInviteSheet) {
                InviteFriendsSheet()
            }
            .sheet(isPresented: $showingQRScanner) {
                QRScannerView { scannedCode in
                    handleQRCodeScanned(scannedCode)
                }
            }
            .sheet(isPresented: $showingUserProfile) {
                if let user = selectedUser {
                    UserProfileDetailView(user: user)
                }
            }
        }
    }
    
    // MARK: - QRスキャンバナー
    
    private var qrScanBanner: some View {
        Button(action: {
            showingQRScanner = true
        }) {
            HStack(spacing: 16) {
                // アイコン
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(themeColor.opacity(0.2))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 28))
                        .foregroundStyle(themeColor)
                }
                
                // テキスト
                VStack(alignment: .leading, spacing: 4) {
                    Text("QRコードでフォロー")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text("カメラでQRコードをスキャン")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(themeColor.opacity(0.2), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 検索結果セクション
    
    private var searchResultsSection: some View {
        VStack(spacing: 12) {
            // セクションヘッダー
            HStack {
                Text(searchText.isEmpty ? "おすすめユーザー" : "検索結果")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !searchText.isEmpty {
                    Text("\(searchResults.count)人")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            
            // ユーザーリスト
            if searchResults.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(searchResults) { user in
                        UserSearchResultRow(user: user) {
                            // タップ時にプロフィール詳細を表示
                            selectedUser = user
                            showingUserProfile = true
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
    
    // 空の状態ビュー
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            Text("ユーザーが見つかりませんでした")
                .font(.headline)
                .foregroundStyle(.white)
            
            Text("別のキーワードで検索してみてください")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - QRコード処理
    
    private func handleQRCodeScanned(_ code: String) {
        print("📱 QRコードをスキャンしました: \(code)")
        
        // QRコードからユーザーIDを抽出
        // 例: "laterapp://user?id=user_001&name=TanakaTaro"
        if let url = URL(string: code),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let userID = queryItems.first(where: { $0.name == "id" })?.value {
            
            // モックデータベースからユーザーを検索
            if let user = mockDB.getUserByID(userID) {
                // プロフィール詳細画面へ遷移
                selectedUser = user
                showingUserProfile = true
                
                print("✅ ユーザーを見つけました: \(user.name)")
            } else {
                print("❌ ユーザーが見つかりませんでした: \(userID)")
            }
        } else {
            print("❌ QRコードの形式が不正です")
        }
    }
}

// MARK: - ユーザー検索結果行
/// 検索結果に表示されるユーザーカード

struct UserSearchResultRow: View {
    @AppStorage("themeColor") private var themeColorName: String = "green"
    @State private var followingManager = FollowingManager.shared
    
    let user: MockUser
    let onTap: () -> Void
    
    // テーマカラー
    private var themeColor: Color {
        switch themeColorName {
        case "green": return Color.brandGreen
        case "blue": return Color.blue
        case "purple": return Color.purple
        case "orange": return Color.orange
        case "pink": return Color.pink
        default: return Color.brandGreen
        }
    }
    
    // フォロー状態
    private var isFollowing: Bool {
        followingManager.isFollowing(userID: user.id)
    }
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            HStack(spacing: 14) {
                // プロフィール画像
                profileImage
                
                // ユーザー情報
                VStack(alignment: .leading, spacing: 6) {
                    // ユーザー名
                    Text(user.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    // ユーザーID
                    Text("@\(user.username)")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                    
                    // バイオ（1行のみ）
                    Text(user.bio)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                
                Spacer(minLength: 8)
                
                // フォローボタン
                followButton
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // プロフィール画像
    private var profileImage: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [user.profileColor.opacity(0.6), user.profileColor.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
            
            if let iconName = user.profileImageName {
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }
    
    // フォローボタン
    private var followButton: some View {
        Button(action: {
            toggleFollow()
        }) {
            Text(isFollowing ? "フォロー中" : "フォロー")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isFollowing ? .white.opacity(0.9) : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isFollowing {
                            Color.white.opacity(0.15)
                        } else {
                            themeColor
                        }
                    }
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    // フォロー切り替え
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

// MARK: - 既存のサブビュー（互換性維持）

struct FollowButton: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    let target: UserProfile

    private var me: UserProfile? { profiles.first }

    var body: some View {
        let isFollowing = me?.following.contains(where: { $0.id == target.id }) ?? false
        Button(isFollowing ? "Following" : "Follow") {
            guard let me else { return }
            if isFollowing {
                me.following.removeAll { $0.id == target.id }
            } else {
                if target.id != me.id {
                    me.following.append(target)
                }
            }
            try? context.save()
        }
        .buttonStyle(.borderedProminent)
        .tint(isFollowing ? Color.gray : Color.brandGreen)
        .disabled(target.id == me?.id)
    }
}

struct InviteFriendsSheet: View {
    @Query private var profiles: [UserProfile]
    @AppStorage("currentProfileID") private var currentProfileID: String = ""
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userID") private var userID: String = ""
    @Environment(\.dismiss) private var dismiss
    @State private var showShare = false

    private var me: UserProfile? {
        if let id = UUID(uuidString: currentProfileID) {
            return profiles.first(where: { $0.id == id })
        } else {
            return profiles.first
        }
    }
    
    // QRコード用データ（@AppStorageから）
    private var qrData: String {
        QRCodeGenerator.createUserQRData(
            userID: userID.isEmpty ? "guest" : userID,
            userName: userName.isEmpty ? "ゲスト" : userName
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // タイトル
                        Text("あなたのプロフィールを招待")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .padding(.top, 20)
                        
                        // QRコード表示
                        if let qrImage = QRCodeGenerator.generateQRCode(from: qrData, size: 300) {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 240, height: 240)
                                .padding(20)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .shadow(color: Color.brandGreen.opacity(0.3), radius: 20, x: 0, y: 10)
                        }
                        
                        // ユーザーID表示
                        HStack(spacing: 8) {
                            Text("User ID: \(userID.isEmpty ? "guest" : userID)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                            
                            Button(action: {
                                UIPasteboard.general.string = userID
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.caption)
                                    .foregroundStyle(Color.brandGreen)
                            }
                        }
                        
                        // シェアボタン
                        Button(action: {
                            showShare = true
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .semibold))
                                
                                Text("リンクを共有")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.brandGreen, Color.brandGreen.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Color.brandGreen.opacity(0.4), radius: 12, x: 0, y: 6)
                        }
                        .padding(.horizontal, 32)
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("友達を招待")
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
        .sheet(isPresented: $showShare) {
            if let me = me {
                ShareSheet(activityItems: ["https://later.app/invite/\(me.inviteCode)"])
            }
        }
    }
}

struct SearchBarView: View {
    @Binding var text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Add or search friends", text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct InviteBannerView: View {
    var action: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.brandGreen.opacity(0.2)).frame(width: 40, height: 40)
                Image(systemName: "person.2.wave.2.fill").foregroundStyle(Color.brandGreen)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Invite friends on Later").font(.subheadline.bold()).foregroundStyle(Color.brandGreen)
                Text("later.app/invite").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: action) {
                Text("Invite")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SectionHeaderWithShowAll: View {
    let title: String
    var actionTitle: String = "Show all"
    var action: () -> Void
    var body: some View {
        HStack {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Spacer()
            Button(actionTitle) { action() }
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - プロフィール画像ビュー
struct ProfileImageView: View {
    let data: Data?
    let size: CGFloat
    
    var body: some View {
        if let data = data, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundStyle(.white.opacity(0.6))
                        .font(.system(size: size * 0.4))
                )
        }
    }
}

struct RecommendedFriendRow: View {
    @Environment(\.modelContext) private var context
    @Query private var allProfiles: [UserProfile]
    let profile: UserProfile

    // NOTE: ダミーの相互友人数やリクエスト状態を表現（必要に応じて実データに差し替え）
    private var mutualCount: Int { Int.random(in: 1...12) }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                ProfileImageView(data: profile.profileImageData, size: 48)
                Text("\(mutualCount)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(Color.brandGreen)
                    .clipShape(Circle())
                    .offset(x: 6, y: 6)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name.isEmpty ? "名称未設定" : profile.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text("@\(profile.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(mutualCount) mutual friends")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            ConnectActionButton(target: profile)

            Button(action: {
                // dismiss suggestion
                // TODO: persist dismissal if needed
            }) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ConnectActionButton: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    let target: UserProfile

    private var me: UserProfile? { profiles.first }

    var body: some View {
        let isFollowing = me?.following.contains(where: { $0.id == target.id }) ?? false
        Button(action: {
            guard let me else { return }
            if isFollowing {
                me.following.removeAll { $0.id == target.id }
            } else {
                if target.id != me.id {
                    me.following.append(target)
                }
            }
            try? context.save()
        }) {
            Text(isFollowing ? "Following" : "Add")
                .font(.subheadline.bold())
                .foregroundStyle(isFollowing ? .white.opacity(0.9) : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isFollowing ? Color.gray.opacity(0.4) : Color.brandGreen)
                .clipShape(Capsule())
        }
        .disabled(target.id == me?.id)
    }
}
