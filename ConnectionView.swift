// このファイルは重複のため無効化されました
// メインの実装は ConnectionView_Fixed.swift を参照してください

/*
import SwiftUI
import SwiftData

// MARK: - Connection View (繋がり画面)

/// 友人とのつながりを管理する画面
/// QRコードスキャナーを使って新しい友人を追加できます
struct ConnectionView_Disabled: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    
    @State private var showQRScanner = false
    @State private var showAddConfirmation = false
    @State private var scannedUserID: String?
    
    private let followingManager = FollowingManager.shared
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    // フォロー中のユーザーIDリスト
    private var followingUserIDs: [String] {
        followingManager.followingUserIDs
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
                        // ヘッダーセクション
                        headerSection
                        
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
                                .foregroundStyle(.brandGreen)
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showQRScanner) {
                QRCodeScannerView { scannedCode in
                    handleScannedCode(scannedCode)
                }
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
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // アイコン
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.brandGreen.opacity(0.3),
                                Color.blue.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "person.2.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }
            
            // タイトル
            VStack(spacing: 8) {
                Text("繋がり")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                
                Text("\(followingUserIDs.count) 人の友達")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            // QRスキャンボタン（大きめ）
            Button {
                HapticsManager.swipeFeedback()
                showQRScanner = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title3)
                    
                    Text("QRコードで友達追加")
                        .font(.headline)
                }
                .foregroundStyle(.brandBlack)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(.brandGreen)
                )
            }
        }
        .padding(.vertical, 32)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 72))
                .foregroundStyle(.white.opacity(0.3))
                .symbolEffect(.pulse)
            
            VStack(spacing: 12) {
                Text("まだ友達がいません")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white)
                
                Text("QRコードをスキャンして\n友達を追加しましょう")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
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
                    .fill(.brandGreen)
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(.headline)
                    .foregroundStyle(.brandBlack)
            }
            
            // アイコン
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.brandGreen)
                .frame(width: 32)
            
            // テキスト
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)
            
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
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(followingUserIDs.count)人")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
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
                                .blue.opacity(0.7),
                                .purple.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Text(String(userID.prefix(1).uppercased()))
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            
            // ユーザー情報
            VStack(alignment: .leading, spacing: 4) {
                Text(userID)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    
                    Text("フォロー中")
                        .font(.caption)
                }
                .foregroundStyle(.brandGreen)
            }
            
            Spacer()
            
            // 削除ボタン
            Button {
                showRemoveConfirmation = true
            } label: {
                Image(systemName: "person.fill.xmark")
                    .font(.body)
                    .foregroundStyle(.red.opacity(0.8))
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

// MARK: - Preview

#Preview("Connection View - With Friends") {
    // フォロー済みの状態でプレビュー
    let _ = {
        FollowingManager.shared.toggleFollow(userID: "user_001")
        FollowingManager.shared.toggleFollow(userID: "user_002")
        FollowingManager.shared.toggleFollow(userID: "tanaka_taro")
    }()
    
    ConnectionView()
        .modelContainer(for: [LaterPhoto.self, UserProfile.self, LaterGroup.self])
}

#Preview("Connection View - Empty") {
    // フォローなしの状態でプレビュー
    let _ = {
        FollowingManager.shared.clearAll()
    }()
    
    ConnectionView()
        .modelContainer(for: [LaterPhoto.self, UserProfile.self, LaterGroup.self])
}
*/
