import SwiftUI
import SwiftData

// MARK: - Connection View (繋がり画面)

/// 友人とのつながりを管理する画面
/// 検索機能とQRコードスキャナーを使って新しい友人を追加できます
struct ConnectionView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]
    
    @State private var showQRScanner = false
    @State private var showMyQRCode = false
    @State private var showUserSearch = false
    @State private var showAddConfirmation = false
    @State private var showCircleManagement = false
    @State private var scannedUserID: String?
    @State private var searchText: String = ""
    
    private let followingManager = FollowingManager.shared
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    private var userGroups: [LaterGroup] {
        guard let user = currentUser else { return [] }
        return groups.filter { $0.members.contains(where: { $0.id == user.id }) }
    }
    
    // フォロー中のユーザーIDリスト
    private var followingUserIDs: [String] {
        followingManager.allFollowingIDs
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color.brandBlack.ignoresSafeArea()
                
                // 液体アニメーション背景
                LiquidBackgroundView()
                    .opacity(0.3)
                
                // メインコンテンツ
                ScrollView {
                    VStack(spacing: 24) {
                        // 検索バーセクション（最上部）
                        searchBarSection
                        
                        // 友人リスト
                        if followingUserIDs.isEmpty {
                            emptyStateView
                        } else {
                            friendsListSection
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationTitle("繋がり")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // Circles ボタン（グループ管理画面へ）
                        Button {
                            HapticsManager.swipeFeedback()
                            showCircleManagement = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.brandGreen.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                
                                // 複数の円を表すアイコン
                                Image(systemName: "circle.hexagongrid.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.brandGreen)
                                
                                // 所属グループ数のバッジ
                                if !userGroups.isEmpty {
                                    Circle()
                                        .fill(Color.brandGreen)
                                        .frame(width: 18, height: 18)
                                        .overlay(
                                            Text("\(min(userGroups.count, 9))")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(Color.black)
                                        )
                                        .offset(x: 14, y: -14)
                                }
                            }
                        }
                        
                        // QRスキャナー起動ボタン
                        Button {
                            HapticsManager.swipeFeedback()
                            showQRScanner = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.brandGreen.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.title3)
                                    .foregroundStyle(Color.brandGreen)
                            }
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showCircleManagement) {
                CircleManagementView()
            }
            .fullScreenCover(isPresented: $showQRScanner) {
                // QRスキャナーに「My QR Code」ボタンを追加
                QRCodeScannerWithMyCode(
                    onScanSuccess: { scannedCode in
                        handleScannedCode(scannedCode)
                    },
                    onShowMyQRCode: {
                        showMyQRCode = true
                    }
                )
            }
            .sheet(isPresented: $showMyQRCode) {
                MyQRCodeView()
            }
            .sheet(isPresented: $showUserSearch) {
                ModernUserSearchView()
            }
            .alert("友達を追加", isPresented: $showAddConfirmation) {
                Button("追加", role: .none) {
                    if let userID = scannedUserID {
                        addFriend(userID: userID)
                    }
                }
                Button("キャンセル", role: .cancel) {
                    scannedUserID = nil
                }
            } message: {
                if let userID = scannedUserID {
                    Text("\(userID) さんを友達に追加しますか？")
                }
            }
        }
    }
    
    // MARK: - Search Bar Section
    
    /// 検索バーセクション（最上部に配置）
    private var searchBarSection: some View {
        VStack(spacing: 16) {
            // フレンド数表示
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.brandGreen)
                
                Text("\(followingUserIDs.count)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                
                Text("人の友達")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 検索バー（タップで詳細検索を開く）
            Button {
                HapticsManager.swipeFeedback()
                showUserSearch = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Text("ユーザー名またはIDで検索")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1.5)
                        )
                )
            }
            
            // アクションボタン（QRコードとMy QR Code）
            HStack(spacing: 12) {
                // My QR Code ボタン
                Button {
                    HapticsManager.swipeFeedback()
                    showMyQRCode = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("My QR")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.brandGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.brandGreen.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.brandGreen.opacity(0.3), lineWidth: 1.5)
                            )
                    )
                }
                
                // QRスキャンボタン
                Button {
                    HapticsManager.swipeFeedback()
                    showQRScanner = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("QRスキャン")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Color(red: 0.05, green: 0.05, blue: 0.05))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.brandGreen, Color.brandGreen.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.brandGreen.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 72))
                .foregroundStyle(Color.white.opacity(0.3))
                .symbolEffect(.pulse)
            
            VStack(spacing: 12) {
                Text("まだ友達がいません")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.white)
                
                Text("QRコードをスキャンして\n友達を追加しましょう")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            // QRスキャン方法の説明
            VStack(alignment: .leading, spacing: 16) {
                instructionStep(
                    number: 1,
                    icon: "qrcode.viewfinder",
                    text: "QRコードボタンをタップ"
                )
                
                instructionStep(
                    number: 2,
                    icon: "camera.viewfinder",
                    text: "友達のQRコードを読み取る"
                )
                
                instructionStep(
                    number: 3,
                    icon: "person.badge.plus",
                    text: "友達が追加されます"
                )
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .padding(.vertical, 40)
    }
    
    private func instructionStep(number: Int, icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            // 番号バッジ
            ZStack {
                Circle()
                    .fill(Color.brandGreen)
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.05, green: 0.05, blue: 0.05))
            }
            
            // アイコン
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.brandGreen)
                .frame(width: 32)
            
            // テキスト
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.white)
            
            Spacer()
        }
    }
    
    // MARK: - Friends List Section
    
    private var friendsListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // セクションヘッダー
            HStack {
                Text("友達リスト")
                    .font(.title3.bold())
                    .foregroundStyle(Color.white)
                
                Spacer()
                
                Text("\(followingUserIDs.count)人")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .padding(.horizontal, 4)
            
            // 友達カード
            LazyVStack(spacing: 12) {
                ForEach(followingUserIDs, id: \.self) { userID in
                    FriendCard(
                        userID: userID,
                        onRemove: {
                            removeFriend(userID: userID)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Methods
    
    /// QRコードスキャン結果を処理
    private func handleScannedCode(_ code: String) {
        scannedUserID = code
        showQRScanner = false
        
        // スキャン成功のハプティクス
        HapticsManager.unlockSuccess()
        
        // 確認ダイアログを表示
        showAddConfirmation = true
    }
    
    /// 友達を追加
    private func addFriend(userID: String) {
        // すでにフォロー済みかチェック
        guard !followingManager.isFollowing(userID: userID) else {
            print("⚠️ すでにフォロー済み: \(userID)")
            return
        }
        
        // フォロー追加
        followingManager.toggleFollow(userID: userID)
        
        // 成功のハプティクス
        HapticsManager.cardChange()
        
        print("✅ 友達を追加: \(userID)")
    }
    
    /// 友達を削除
    private func removeFriend(userID: String) {
        followingManager.toggleFollow(userID: userID)
        
        // 削除のハプティクス
        HapticsManager.swipeFeedback()
        
        print("🗑 友達を削除: \(userID)")
    }
}

// MARK: - Friend Card

/// 友達カード（個別の友達を表示）
fileprivate struct FriendCard: View {
    let userID: String
    let onRemove: () -> Void
    
    @State private var showRemoveConfirmation = false
    
    var body: some View {
        HStack(spacing: 16) {
            // プロフィール画像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.7),
                                Color.purple.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Text(String(userID.prefix(1).uppercased()))
                    .font(.title2.bold())
                    .foregroundStyle(Color.white)
            }
            
            // ユーザー情報
            VStack(alignment: .leading, spacing: 4) {
                Text(userID)
                    .font(.headline)
                    .foregroundStyle(Color.white)
                
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    
                    Text("フォロー中")
                        .font(.caption)
                }
                .foregroundStyle(Color.brandGreen)
            }
            
            Spacer()
            
            // 削除ボタン
            Button {
                showRemoveConfirmation = true
            } label: {
                Image(systemName: "person.fill.xmark")
                    .font(.body)
                    .foregroundStyle(Color.red.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.red.opacity(0.1))
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .confirmationDialog("友達を削除", isPresented: $showRemoveConfirmation) {
            Button("削除", role: .destructive) {
                onRemove()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(userID) さんを友達から削除しますか？")
        }
    }
}

#Preview("Connection View - With Friends") {
    let _ = {
        FollowingManager.shared.toggleFollow(userID: "user_001")
        FollowingManager.shared.toggleFollow(userID: "user_002")
        FollowingManager.shared.toggleFollow(userID: "tanaka_taro")
    }()
    
    ConnectionView()
        .modelContainer(for: [LaterPhoto.self, UserProfile.self, LaterGroup.self])
}

#Preview("Connection View - Empty") {
    let _ = {
        FollowingManager.shared.clearAll()
    }()
    
    ConnectionView()
        .modelContainer(for: [LaterPhoto.self, UserProfile.self, LaterGroup.self])
}
