import SwiftUI
import SwiftData

// DISABLED: This file contains duplicate type declarations
// The main implementation is in ConnectionView_Fixed.swift
// To re-enable, rename the types below (e.g., ConnectionView_Alt)

/// 🔗 Connection画面 - メインハブ
/// フレンド管理、QRコード表示、Circle管理へのアクセス
struct ConnectionView_Disabled: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]
    
    @State private var showingQRCode = false
    @State private var showingCircleManagement = false
    @State private var showingUserSearch = false
    @State private var searchText = ""
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    private var userGroups: [LaterGroup] {
        guard let user = currentUser else { return [] }
        return groups.filter { $0.members.contains(where: { $0.id == user.id }) }
    }
    
    var body: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    qrCodeSection
                    followingSection
                    Spacer(minLength: 100)
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Connection")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                circleButton
            }
        }
        .sheet(isPresented: $showingQRCode) {
            MyQRCodeView()
        }
        .sheet(isPresented: $showingCircleManagement) {
            CircleManagementView()
        }
        .sheet(isPresented: $showingUserSearch) {
            UserSearchView_Disabled()
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            if let user = currentUser {
                // プロフィール画像
                if let imageData = user.profileImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(Color.brandGreen, lineWidth: 3)
                        )
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 35))
                                .foregroundColor(.white.opacity(0.5))
                        )
                }
                
                // ユーザー名
                Text(user.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("@\(user.username)")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
                
                // フォロー数
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(user.following.count)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.brandGreen)
                        
                        Text("フォロー中")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    VStack(spacing: 4) {
                        Text("\(user.followers.count)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.brandGreen)
                        
                        Text("フォロワー")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.top, 20)
    }
    
    private var qrCodeSection: some View {
        VStack(spacing: 16) {
            Button {
                HapticsManager.tick()
                showingQRCode = true
            } label: {
                HStack {
                    Image(systemName: "qrcode")
                        .font(.system(size: 24))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("My QR")
                            .font(.system(size: 18, weight: .bold))
                        
                        Text("QRコードを表示してフレンドを追加")
                            .font(.system(size: 13))
                            .opacity(0.7)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.brandGreen.opacity(0.3),
                                    Color.brandGreen.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            }
            
            Button {
                HapticsManager.tick()
                showingUserSearch = true
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("友達を検索")
                            .font(.system(size: 18, weight: .bold))
                        
                        Text("ユーザー名やIDで友達を見つけよう")
                            .font(.system(size: 13))
                            .opacity(0.7)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
            }
        }
    }
    
    private var followingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("フォロー中")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if let user = currentUser {
                    Text("\(user.following.count)人")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.brandGreen)
                }
            }
            
            if let user = currentUser, !user.following.isEmpty {
                LazyVStack(spacing: 12) {
                    ForEach(user.following, id: \.id) { friend in
                        FriendCard(friend: friend)
                    }
                }
            } else {
                emptyFollowingView
            }
        }
    }
    
    private var emptyFollowingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.3))
            
            Text("まだフレンドがいません")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            
            Text("QRコードや検索からフレンドを追加しましょう")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var circleButton: some View {
        Button {
            HapticsManager.tick()
            showingCircleManagement = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.brandGreen.opacity(0.3),
                                Color.brandGreen.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.brandGreen)
                
                // グループ数バッジ
                if !userGroups.isEmpty {
                    Circle()
                        .fill(Color.brandGreen)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Text("\(min(userGroups.count, 9))")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 6, y: -6)
                }
            }
        }
    }
}

// MARK: - Friend Card

fileprivate struct FriendCard: View {
    let friend: UserProfile
    
    var body: some View {
        HStack(spacing: 12) {
            // プロフィール画像
            if let imageData = friend.profileImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.5))
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("@\(friend.username)")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Placeholder Views (これらは後で実装)

struct QRCodeView_Disabled: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("QR Code")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .frame(width: 250, height: 250)
                    .overlay(
                        Text("QRコード表示\n（実装予定）")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                    )
                
                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.brandGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
            }
        }
    }
}

fileprivate struct UserSearchView_Disabled: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("友達を検索")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("検索機能（実装予定）")
                    .foregroundColor(.white.opacity(0.7))
                
                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.brandGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
            }
            .padding()
        }
    }
}

struct CircleManagementView_Disabled: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Circle Management")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("グループ管理機能（実装予定）")
                    .foregroundColor(.white.opacity(0.7))
                
                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.brandGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
            }
            .padding()
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: UserProfile.self, LaterGroup.self,
        configurations: config
    )
    
    NavigationStack {
        ConnectionView_Disabled()
            .modelContainer(container)
    }
}
