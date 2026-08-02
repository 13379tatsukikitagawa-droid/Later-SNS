import SwiftUI
import SwiftData
import PhotosUI
internal import Combine

// MARK: - Imports from other files
// AppStorageData - custom property wrapper for Data storage
// Color+Neon - brand color definitions (brandGreen, brandBlack)
// AppearanceSettings - AppearanceManager and AppearanceSettingsView
// ShareSheet - UIKit share sheet wrapper
// NotificationsView - notification display view
// SettingsMenuView - settings menu
// MyQRCodeView - QR code display
// ModernUserSearchView - user search functionality
// ButtonStyles - BounceButtonStyle
// NotificationModels - NotificationManager and UserNotification
// FollowingManager - follow/unfollow management
// HapticsManager - haptic feedback utilities

// MARK: - Fallback stubs to satisfy references when real implementations live elsewhere
#if canImport(SwiftUI)
// UserProfile stub removed - using the real UserProfile from LaterModels.swift
// AppearanceManager is imported from AppearanceSettings.swift
// ShareSheet is imported from ShareSheet.swift
// BounceButtonStyle is imported from ButtonStyles.swift
// NotificationManager and FollowingManager are now in separate files
// See: NotificationModels.swift and FollowingManager.swift

// Brand colors are defined in Color+Neon.swift - do not redeclare

// MARK: - Custom Color Extensions (moved to separate file to avoid redeclaration)
// extension Color {
//     static let brandGreen = Color(red: 0.2, green: 0.8, blue: 0.6)
//     static let brandBlack = Color(red: 0.1, green: 0.1, blue: 0.12)
// }

// MARK: - ShareSheet (moved to separate file to avoid redeclaration)
// struct ShareSheet: UIViewControllerRepresentable {
//     let activityItems: [Any]
//     var applicationActivities: [UIActivity]? = nil
//
//     func makeUIViewController(context: Context) -> UIActivityViewController {
//         let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
//         return controller
//     }
//
//     func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
// }

// MARK: - NotificationsView (moved to separate file to avoid redeclaration)
/*
struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notificationManager = NotificationManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        if notificationManager.notifications.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(notificationManager.notifications, id: \.id) { notification in
                                notificationRow(notification)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("通知")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("通知はありません")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(.top, 100)
    }
    
    private func notificationRow(_ notification: UserNotification) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName(for: notification.type))
                .font(.system(size: 20))
                .foregroundStyle(Color.brandGreen)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(notification.message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func iconName(for type: UserNotification.NotificationType) -> String {
        switch type {
        case .follow: return "person.badge.plus"
        case .like: return "heart.fill"
        case .comment: return "text.bubble.fill"
        case .mention: return "at"
        case .system: return "info.circle.fill"
        }
    }
}
*/

// MARK: - AppearanceSettingsView (moved to separate file to avoid redeclaration)
/*
struct AppearanceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var appearanceManager = AppearanceManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        colorSchemeSection
                        fontStyleSection
                        layoutPatternSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("カスタマイズ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    private var colorSchemeSection: some View {
        settingsSection(title: "表示モード", icon: "moon.stars.fill", color: .blue) {
            VStack(spacing: 12) {
                ForEach(AppearanceManager.ColorSchemeMode.allCases, id: \.self) { mode in
                    settingOptionButton(
                        title: mode.rawValue,
                        isSelected: appearanceManager.colorScheme == mode
                    ) {
                        withAnimation {
                            appearanceManager.colorScheme = mode
                        }
                    }
                }
            }
        }
    }
    
    private var fontStyleSection: some View {
        settingsSection(title: "フォントスタイル", icon: "textformat", color: .green) {
            VStack(spacing: 12) {
                ForEach(AppearanceManager.FontStyle.allCases, id: \.self) { fontStyle in
                    settingOptionButton(
                        title: fontStyle.rawValue,
                        isSelected: appearanceManager.fontStyle == fontStyle,
                        font: fontStyle.font(size: 16, weight: .medium)
                    ) {
                        withAnimation {
                            appearanceManager.fontStyle = fontStyle
                        }
                    }
                }
            }
        }
    }
    
    private var layoutPatternSection: some View {
        settingsSection(title: "レイアウト", icon: "square.grid.2x2", color: .purple) {
            VStack(spacing: 12) {
                ForEach(AppearanceManager.LayoutPattern.allCases, id: \.self) { pattern in
                    settingOptionButton(
                        title: pattern.rawValue,
                        isSelected: appearanceManager.layoutPattern == pattern
                    ) {
                        withAnimation {
                            appearanceManager.layoutPattern = pattern
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func settingsSection<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            content()
        }
    }
    
    private func settingOptionButton(title: String, isSelected: Bool, font: Font = .system(size: 16, weight: .medium), action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(font)
                    .foregroundStyle(.white)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.brandGreen)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.brandGreen.opacity(0.5) : Color.white.opacity(0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
*/

// MARK: - MyQRCodeView (moved to separate file to avoid redeclaration)
/*
struct MyQRCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("userName") private var userName: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("マイQRコード")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    Image(systemName: "qrcode")
                        .font(.system(size: 120))
                        .foregroundStyle(.white)
                    
                    Text("@\(userID.isEmpty ? "guest" : userID)")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}
*/

// MARK: - SettingsMenuView (moved to separate file to avoid redeclaration)
/*
struct SettingsMenuView: View {
    @Binding var isShowing: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Text("設定メニュー")
                            .font(.title.bold())
                            .foregroundStyle(.white)
                        
                        Text("設定項目はここに表示されます")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        isShowing = false
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}
*/

// MARK: - ModernUserSearchView (moved to separate file to avoid redeclaration)
/*
struct ModernUserSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                VStack {
                    SearchBar(text: $searchText)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            Text("ユーザー検索")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            
                            Text("検索機能は開発中です")
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("ユーザー検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}
*/

// MARK: - SearchBar Component (moved to separate file to avoid redeclaration)
/*
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.5))
            
            TextField("ユーザーを検索", text: $text)
                .foregroundStyle(.white)
        }
        .padding(12)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}
*/

// Main ProfileView starts here
struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    
    // 🎯 オンボーディングと共通の@AppStorageキー（完全同期）
    @AppStorage("isSetupCompleted") private var isSetupCompleted: Bool = false
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("userBio") private var userBio: String = ""
    @AppStorageData("profileImageData") private var profileImageData: Data?
    
    // レガシー対応
    @AppStorage("currentProfileID") private var currentProfileID: String = ""
    @AppStorage("isProfileSetupCompleted") private var isProfileSetupCompleted: Bool = false
    
    // テーマカラーのカスタマイズ
    @AppStorage("themeColor") private var themeColorName: String = "green"
    
    // 🎯 新規追加: 言語設定の@AppStorage（日本語か英語かを判別して初期設定）
    @AppStorage("selectedLanguage") private var selectedLanguage: String = Locale.preferredLanguages.first?.hasPrefix("ja") == true ? "ja" : "en"
    
    @State private var isShowingShare = false
    @State private var isShowingSetup = false
    @State private var isShowingNotifications = false
    @State private var isShowingAppearanceSettings = false
    @State private var isShowingMyQRCode = false
    @State private var isShowingUserSearch = false
    @State private var isShowingSettingsMenu = false // 新規追加
    
    // アニメーション用
    @State private var headerOpacity: Double = 0
    @State private var headerScale: CGFloat = 0.9
    
    // 統計情報のカウントアップアニメーション用
    @State private var animatedFriends: Int = 0
    @State private var animatedFollowers: Int = 0
    @State private var animatedFollowing: Int = 0
    
    // プルして更新
    @State private var isRefreshing = false
    
    // 通知マネージャー（シングルトン - @Stateは不要）
    private let notificationManager = NotificationManager.shared
    
    // カスタマイズマネージャー（@Observable対応）
    @State private var appearanceManager = AppearanceManager.shared
    
    // フォロー管理マネージャー（シングルトン - @Stateは不要）
    private let followingManager = FollowingManager.shared
    
    @State private var followStats: (friends: Int, followers: Int, following: Int) = (0, 0, 0)
    private static var statsCache: [UUID: (friends: Int, followers: Int, following: Int)] = [:]
    
    private var currentProfile: UserProfile? {
        if let id = UUID(uuidString: currentProfileID), let match = profiles.first(where: { $0.id == id }) { return match }
        return profiles.first
    }
    
    // 🎯 表示名（@AppStorageから直接取得、フォールバック対応）
    private var displayName: String {
        userName.isEmpty ? "ゲスト" : userName
    }
    
    // 🎯 表示用ユーザーID
    private var displayUserID: String {
        userID.isEmpty ? "guest" : userID
    }
    
    // 🎯 表示用バイオ
    private var displayBio: String? {
        userBio.isEmpty ? nil : userBio
    }
    
    // 🎯 プロフィール画像（@AppStorageから直接取得）
    private var displayProfileImage: UIImage? {
        guard let data = profileImageData else { return nil }
        return UIImage(data: data)
    }
    
    // テーマカラー
    private var themeColor: Color {
        switch themeColorName {
        case "green": return Color.brandGreen
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        default: return Color.brandGreen
        }
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Profile")
                .toolbar { toolbarContent }
                .sheet(isPresented: $isShowingShare) {
                    ShareSheet(activityItems: [createShareText()])
                }
                .sheet(isPresented: $isShowingSetup) {
                    ProfileEditView()
                }
                .sheet(isPresented: $isShowingNotifications) {
                    NotificationsView()
                }
                .sheet(isPresented: $isShowingAppearanceSettings) {
                    AppearanceSettingsView()
                }
                .sheet(isPresented: $isShowingMyQRCode) {
                    MyQRCodeView()
                }
                .sheet(isPresented: $isShowingUserSearch) {
                    ModernUserSearchView()
                }
                .fullScreenCover(isPresented: $isShowingSettingsMenu) {
                    SettingsMenuView(isShowing: $isShowingSettingsMenu)
                        .transition(.move(edge: .trailing))
                }
                .preferredColorScheme(appearanceManager.colorScheme.systemColorScheme)
                .onAppear(perform: handleOnAppear)
                .onChange(of: profiles) { oldValue, newValue in
                    handleProfilesChange(oldValue, newValue)
                }
                .onChange(of: userName) { oldValue, newValue in
                    handleUserNameChange(oldValue, newValue)
                }
                .onChange(of: profileImageData) { oldValue, newValue in
                    handleProfileImageChange(oldValue, newValue)
                }
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
            profileSettingsView
        }
    }
    
    // MARK: - Toolbar Content
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            notificationButton
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            menuButton
        }
    }
    
    private var notificationButton: some View {
        Button {
            isShowingNotifications = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                
                if notificationManager.unreadCount > 0 {
                    notificationBadge
                }
            }
        }
    }
    
    private var notificationBadge: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 16, height: 16)
            .overlay(
                Text("\(notificationManager.unreadCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            )
            .offset(x: 8, y: -8)
    }
    
    private var menuButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isShowingSettingsMenu = true
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleOnAppear() {
        if let profile = currentProfile {
            recalcFollowStats(for: profile)
            animateStats()
        }
        
        withAnimation(.easeOut(duration: 0.6)) {
            headerOpacity = 1.0
            headerScale = 1.0
        }
    }
    
    private func handleProfilesChange(_ oldValue: [UserProfile], _ newValue: [UserProfile]) {
        if let profile = currentProfile {
            recalcFollowStats(for: profile)
            animateStats()
        }
    }
    
    private func handleUserNameChange(_ oldValue: String, _ newValue: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            // UI will auto-update
        }
    }
    
    private func handleProfileImageChange(_ oldValue: Data?, _ newValue: Data?) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            // UI will auto-update
        }
    }
    
    
    // MARK: - Helper Methods
    
    private func createShareText() -> String {
        """
        Check out my Later profile!
        Name: \(displayName)
        Username: @\(displayUserID)
        """
    }
    
    // MARK: - 🎯 シンプルな設定画面（カレンダーUIなし）
    
    private var profileSettingsView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 🎯 リッチなプロフィールヘッダー（画像・名前・ID・バイオ・統計）
                modernProfileHeader
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    .opacity(headerOpacity)
                    .scaleEffect(headerScale)

                // Pins Section（将来の機能用）
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedStringKey("pins"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                    
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                        .frame(height: 120)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.secondary)
                                
                                Text("お気に入りの瞬間をピン留め")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        )
                        .foregroundStyle(.white.opacity(0.06))
                        .padding(.horizontal, 16)
                }
                .padding(.bottom, 32)
                

            }
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await refreshProfile()
        }
    }
    

    
    // MARK: - プルして更新
    @MainActor
    private func refreshProfile() async {
        isRefreshing = true
        
        // 統計情報を再計算
        if let profile = currentProfile {
            recalcFollowStats(for: profile)
            animateStats()
        }
        
        // リフレッシュ効果のため少し待機
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        isRefreshing = false
    }
    
    // MARK: - 🎯 リッチなユーザーヘッダー（@AppStorageから直接表示）
    private var modernProfileHeader: some View {
        VStack(spacing: 24) {
            // 🎯 プロフィール画像（@AppStorageから）
            profileImageCircle
            
            // 🎯 ユーザー名と@ID（@AppStorageから）
            userNameSection
            
            // 🎯 一言バイオ（@AppStorageから、設定されていれば表示）
            if let bio = displayBio {
                bioSection(bio: bio)
            }
            
            // フォロー中の人数表示
            followingCountSection
            
            // 統計情報（アニメーション付き）
            statsSection
            
            // アクションボタン
            actionButtons
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - 🎯 プロフィール画像（デフォルト画像対応）
    private var profileImageCircle: some View {
        Group {
            if let uiImage = displayProfileImage {
                // ✅ 登録された画像を表示
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 140)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.brandGreen.opacity(0.6), lineWidth: 3)
                    )
                    .shadow(color: Color.brandGreen.opacity(0.25), radius: 12, x: 0, y: 6)
            } else {
                // ✅ デフォルト画像（ゲスト用）
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 140, height: 140)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.3))
                    )
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.2), lineWidth: 2)
                    )
            }
        }
    }
    
    // MARK: - 🎯 ユーザー名と@ID（@AppStorageから）
    private var userNameSection: some View {
        VStack(spacing: 6) {
            // ✅ 名前（表示名）- @AppStorageから直接
            Text(displayName)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            
            // ✅ ユーザーID（@ID）- @AppStorageから直接
            Text("@\(displayUserID)")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
    
    // MARK: - 🎯 バイオセクション（@AppStorageから）
    private func bioSection(bio: String) -> some View {
        Text(bio)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(.white.opacity(0.8))
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
    
    // MARK: - フォロー中の人数表示セクション
    private var followingCountSection: some View {
        NavigationLink {
            FollowingUsersListView()
        } label: {
            HStack(spacing: 12) {
                // アイコン
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(themeColor)
                
                // テキスト
                HStack(spacing: 4) {
                    Text("フォロー中:")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    // リアルタイムで更新される人数
                    Text("\(followingManager.followingCount)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(themeColor)
                        .contentTransition(.numericText())
                    
                    Text("人")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                // 矢印アイコン
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(themeColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var statsSection: some View {
        HStack(spacing: 32) { // スペーシングを広げて見やすく
            AnimatedStatItem(value: animatedFriends, label: "Friends")
            AnimatedStatItem(value: animatedFollowers, label: "Followers")
            AnimatedStatItem(value: animatedFollowing, label: "Following")
        }
        .padding(.top, 12)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // QRコードボタン（新機能）
            qrCodeButton
            
            // シェアボタン
            shareButton
            
            // 編集ボタン（テーマカラー使用）
            editButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }
    
    private var shareButton: some View {
        Button {
            isShowingShare = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                Text("シェア")
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(.white)
        }
        .buttonStyle(BounceButtonStyle())
    }
    
    private var qrCodeButton: some View {
        Button {
            isShowingMyQRCode = true
        } label: {
            Image(systemName: "qrcode")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(
                        colors: [themeColor.opacity(0.3), themeColor.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(themeColor.opacity(0.4), lineWidth: 1.5)
                )
                .foregroundStyle(themeColor)
        }
        .buttonStyle(BounceButtonStyle())
    }
    
    private var editButton: some View {
        Button {
            isShowingSetup = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                Text("編集")
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                LinearGradient(
                    colors: [themeColor, themeColor.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(.white)
            .shadow(color: themeColor.opacity(0.3), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(BounceButtonStyle())
    }
    
    private func recalcFollowStats(for profile: UserProfile) {
        // Use cached value immediately if available
        if let cached = Self.statsCache[profile.id] {
            followStats = cached
        }
        // Recompute from current data
        let followingCount = profile.following.count
        
        // Calculate followers count
        let followersCount = profiles.filter { other in
            let isFollowing = other.following.contains { followingProfile in
                followingProfile.id == profile.id
            }
            return isFollowing
        }.count
        
        // Calculate friends count (mutual follows)
        let friendsCount = profiles.filter { other in
            guard other.id != profile.id else { return false }
            
            let isFollowingOther = profile.following.contains { followingProfile in
                followingProfile.id == other.id
            }
            let isFollowedByOther = other.following.contains { followingProfile in
                followingProfile.id == profile.id
            }
            
            return isFollowingOther && isFollowedByOther
        }.count
        
        let newStats = (friends: friendsCount, followers: followersCount, following: followingCount)
        followStats = newStats
        Self.statsCache[profile.id] = newStats
    }
    
    // MARK: - 統計情報のカウントアップアニメーション
    private func animateStats() {
        // 0からカウントアップするアニメーション
        animatedFriends = 0
        animatedFollowers = 0
        animatedFollowing = 0
        
        withAnimation(.easeOut(duration: 1.0)) {
            animatedFriends = followStats.friends
            animatedFollowers = followStats.followers
            animatedFollowing = followStats.following
        }
    }
    
    // MARK: - フォロー管理ヘルパーメソッド
    
    /// 指定したユーザーIDが既にフォロー中かどうかを判定
    /// - Parameter userID: チェックするユーザーID
    /// - Returns: フォロー中の場合はtrue、それ以外はfalse
    private func isFollowing(userID: String) -> Bool {
        followingManager.isFollowing(userID: userID)
    }
    
    /// ユーザーをフォロー/フォロー解除する
    /// - Parameter userID: 対象のユーザーID
    private func toggleFollow(userID: String) {
        let isNowFollowing = followingManager.toggleFollow(userID: userID)
        
        // フォロー状態が変更されたことをユーザーに通知（ハプティクスなど）
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // 統計情報を更新
        if let profile = currentProfile {
            recalcFollowStats(for: profile)
        }
        
        print(isNowFollowing ? "✅ フォローしました: \(userID)" : "❌ フォロー解除しました: \(userID)")
    }
    
    /// フォロー中のユーザー一覧を取得
    private var followingUserIDs: [String] {
        followingManager.allFollowingIDs
    }
    
    /// フォロー中のユーザー数を取得
    private var followingCount: Int {
        followingManager.followingCount
    }
}

// MARK: - 🎯 プロフィール編集画面（@AppStorageと完全同期）
struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    // 🎯 オンボーディングと共通の@AppStorageキー
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("userBio") private var userBio: String = ""
    @AppStorageData("profileImageData") private var profileImageData: Data?
    
    // 編集用の一時State
    @State private var inputName: String = ""
    @State private var inputUserID: String = ""
    @State private var inputBio: String = ""
    @State private var inputImageData: Data?
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // プロフィール画像セクション
                        profileImageSection
                        
                        // フォームセクション
                        formSection
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("プロフィール編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveProfile()
                    }
                    .foregroundStyle(Color.brandGreen)
                    .fontWeight(.semibold)
                    .disabled(!isFormValid)
                }
            }
            .onAppear {
                // 現在のデータを読み込む
                inputName = userName
                inputUserID = userID
                inputBio = userBio
                inputImageData = profileImageData
            }
            .onChange(of: selectedItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        inputImageData = data
                    }
                }
            }
        }
    }
    
    // MARK: - サブビュー
    
    private var profileImageSection: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                ZStack {
                    // プロフィール画像または placeholder
                    if let imageData = inputImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.brandGreen, Color.brandGreen.opacity(0.5)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 3
                                    )
                            )
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white.opacity(0.3))
                            )
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.2), lineWidth: 2)
                            )
                    }
                    
                    // 編集ボタン
                    ZStack {
                        Circle()
                            .fill(Color.brandGreen)
                            .frame(width: 36, height: 36)
                            .shadow(color: Color.brandGreen.opacity(0.5), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 42, y: 42)
                }
            }
            
            Text("写真をタップして変更")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
    
    private var formSection: some View {
        VStack(spacing: 20) {
            // 名前（表示名）
            FormField(
                label: "名前（表示名）",
                icon: "person.circle.fill",
                text: $inputName,
                placeholder: "例: 山田太郎"
            )
            
            // ユーザーID（@ID）
            FormField(
                label: "ユーザーID（@ID）",
                icon: "at",
                text: $inputUserID,
                placeholder: "例: yamada_taro",
                prefix: "@"
            )
            
            // 一言バイオ（自己紹介）
            FormFieldMultiline(
                label: "一言バイオ（自己紹介）",
                icon: "text.quote",
                text: $inputBio,
                placeholder: "今の気分は？"
            )
        }
    }
    
    // MARK: - バリデーション
    
    private var isFormValid: Bool {
        !inputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !inputUserID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        inputUserID.count >= 3
    }
    
    // MARK: - 保存処理
    
    private func saveProfile() {
        // 🎯 @AppStorageに保存（オンボーディングと自動同期）
        userName = inputName
        userID = inputUserID
        userBio = inputBio
        profileImageData = inputImageData

        // 実際のUserProfile(SwiftData)にも反映し、参加中の全グループへ再同期する。
        if let user = UserProfile.current(from: profiles) {
            user.name = inputName
            user.username = inputUserID
            user.bio = inputBio
            user.profileImageData = inputImageData
            try? modelContext.save()

            if let cloudKitManager = CloudKitManager.current {
                for group in user.groups {
                    cloudKitManager.markForUpload(userProfile: user, in: group)
                }
            }
        }

        // 成功のHaptic
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)

        dismiss()
    }
}



// MARK: - フォームフィールドコンポーネント
struct FormField: View {
    let label: String
    let icon: String
    @Binding var text: String
    let placeholder: String
    var prefix: String? = nil
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(label)
            } icon: {
                Image(systemName: icon)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white.opacity(0.8))
            
            HStack(spacing: 12) {
                if let prefix = prefix {
                    Text(prefix)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.brandGreen)
                }
                
                TextField(text: $text) {
                    Text(placeholder)
                }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .focused($isFocused)
                    .textInputAutocapitalization(prefix != nil ? .never : .words)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isFocused ? Color.brandGreen.opacity(0.5) : Color.white.opacity(0.1),
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - 複数行フォームフィールド
struct FormFieldMultiline: View {
    let label: String
    let icon: String
    @Binding var text: String
    let placeholder: String
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(label)
            } icon: {
                Image(systemName: icon)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white.opacity(0.8))
            
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.brandGreen)
                    .padding(.top, 2)
                
                TextField(text: $text, axis: .vertical) {
                    Text(placeholder)
                }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(3...5)
                    .focused($isFocused)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isFocused ? Color.brandGreen.opacity(0.5) : Color.white.opacity(0.1),
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .padding(.horizontal, 20)
    }
}

struct QRCodeDisplaySection: View {
    let uuidString: String
    private let context = CIContext()
    
    var body: some View {
        if let img = generateQRCode(from: uuidString) {
            VStack {
                Image(uiImage: img).interpolation(.none).resizable().frame(width: 150, height: 150)
                    .padding().background(Color.white).cornerRadius(12).shadow(radius: 5)
                Text("Scan to Follow").font(.caption).foregroundColor(.secondary)
            }
        }
    }
    private func generateQRCode(from string: String) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        
        if let output = filter.outputImage, let cg = context.createCGImage(output, from: output.extent) {
            return UIImage(cgImage: cg)
        }
        return nil
    }
}

// MARK: - 設定リストの行コンポーネント
struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // アイコン
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(iconColor)
                }
                
                // テキスト
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 矢印アイコン
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 統計情報アイテム（アニメーション付き）
struct AnimatedStatItem: View {
    let value: Int
    let label: String
    
    @State private var displayValue: Int = 0
    
    var body: some View {
        // ✨ 数字を太字、ラベルを小さめの薄いグレーで横並び
        HStack(spacing: 4) {
            // 数字（太字）
            Text("\(displayValue)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            
            // ラベル（小さめの薄いグレー）
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.gray)
        }
        .task(id: value) {
            await updateDisplayValue(to: value)
        }
        .onAppear {
            displayValue = value
        }
    }
    
    @MainActor
    private func updateDisplayValue(to newValue: Int) async {
        withAnimation(.easeOut(duration: 1.0)) {
            displayValue = newValue
        }
    }
}

// MARK: - テーマカラー設定行
struct ThemeColorSettingRow: View {
    let currentColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // アイコン
            iconView
            
            // テキスト
            textView
            
            Spacer()
            
            // 現在のカラーサンプル
            colorSample
            
            // 矢印アイコン
            chevron
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(currentColor.opacity(0.15))
                .frame(width: 44, height: 44)
            
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(currentColor)
        }
    }
    
    private var textView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("テーマカラー")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
            
            Text("アクセントカラーを変更")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var colorSample: some View {
        Circle()
            .fill(currentColor)
            .frame(width: 24, height: 24)
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
            )
    }
    
    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

// MARK: - カスタマイズ設定行
struct CustomizeSettingRow: View {
    var body: some View {
        HStack(spacing: 16) {
            // アイコン
            iconView
            
            // テキスト
            textView
            
            Spacer()
            
            // 矢印アイコン
            chevron
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.indigo.opacity(0.15))
                .frame(width: 44, height: 44)
            
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.indigo)
        }
    }
    
    private var textView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("カスタマイズ")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
            
            Text("表示モード、フォント、レイアウト")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

// MARK: - フォロー中ユーザー一覧画面
/// フォロー中のユーザー一覧を表示する画面（枠組み）
struct FollowingUsersListView: View {
    @Environment(\.dismiss) private var dismiss
    private let followingManager = FollowingManager.shared
    
    // サンプルユーザーデータ（実際のアプリではSwiftDataなどから取得）
    private let sampleUsers: [(id: String, name: String, bio: String)] = [
        ("user1", "田中太郎", "デザイナー | 東京在住"),
        ("user2", "佐藤花子", "フォトグラファー📸 | 旅行が大好き"),
        ("user3", "鈴木一郎", "エンジニア👨‍💻 | SwiftUIが好き"),
        ("user4", "高橋美咲", "イラストレーター🎨 | 猫好き🐱"),
        ("user5", "伊藤健太", "ライター✍️ | テクノロジーとライフスタイル"),
        ("user6", "山田大輔", "起業家 | スタートアップ経営"),
        ("user7", "中村愛美", "ヨガインストラクター🧘‍♀️"),
        ("user8", "小林翔太", "料理人🍳 | 和食専門"),
    ]
    
    // フォロー中のユーザーのみをフィルタリング
    private var followingUsers: [(id: String, name: String, bio: String)] {
        sampleUsers.filter { followingManager.isFollowing(userID: $0.id) }
    }
    
    var body: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
            
            if followingManager.followingCount == 0 {
                // 空の状態
                emptyStateView
            } else {
                // ユーザーリスト
                ScrollView {
                    VStack(spacing: 16) {
                        // ヘッダー
                        headerSection
                        
                        // ユーザーリスト
                        VStack(spacing: 12) {
                            ForEach(followingUsers, id: \.id) { user in
                                FollowingUserCard(
                                    userID: user.id,
                                    userName: user.name,
                                    userBio: user.bio
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationTitle(LocalizedStringKey("following_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    // MARK: - サブビュー
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.brandGreen)
                
                Text("\(followingManager.followingCount)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                
                Text("人")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Text("フォロー中のユーザー")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("まだ誰もフォローしていません")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            
            Text("興味のあるユーザーをフォローして\nつながりを広げましょう")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - フォロー中ユーザーカード
/// フォロー中のユーザー情報を表示するカード
struct FollowingUserCard: View {
    let userID: String
    let userName: String
    let userBio: String
    
    private let followingManager = FollowingManager.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // プロフィール画像
            profileImage
            
            // ユーザー情報
            VStack(alignment: .leading, spacing: 6) {
                Text(userName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text(userBio)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            }
            
            Spacer()
            
            // フォロー中バッジ
            followingBadge
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
                    colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.7))
            )
    }
    
    private var followingBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.brandGreen)
            
            Text("フォロー中")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.brandGreen.opacity(0.15))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.brandGreen.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview("Profile - Japanese") {
    ProfileView()
        .modelContainer(for: [UserProfile.self], inMemory: true)
        .environment(\.locale, Locale(identifier: "ja"))
}

#Preview("Profile - English") {
    ProfileView()
        .modelContainer(for: [UserProfile.self], inMemory: true)
        .environment(\.locale, Locale(identifier: "en"))
}

#endif

