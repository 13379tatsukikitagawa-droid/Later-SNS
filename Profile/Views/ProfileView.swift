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
    @Query private var groups: [LaterGroup]

    /// nilなら自分のプロフィール(従来通り編集可能)、値があればその相手のプロフィールを
    /// 閲覧専用モードで表示する(Connection画面のフォロワー/フォロー中一覧などから遷移)。
    var viewedUser: UserProfile? = nil

    @State private var isShowingShare = false
    @State private var isShowingSetup = false
    @State private var isShowingMyQRCode = false
    @State private var isShowingSettingsMenu = false
    @State private var isShowingPinPicker = false
    /// タブバーからGalleryタブを削除した代わりに、このヘッダー行から
    /// 開く導線として持つ表示状態(MainTabView.swiftから移設)。
    @State private var isShowingGallery = false
    /// Connection画面にあった「グループ作成」ショートカットをここへ移動した表示状態。
    @State private var isShowingCreateGroup = false
    #if DEBUG
    /// FilmEmulation(チェキ風処理の新旧比較)の確認用。DEBUGビルドにのみ存在し、
    /// リリース/TestFlightビルドには一切含まれない。
    @State private var isShowingFilmEmulationDebug = false
    #endif
    /// プロフィールが1件も無い状態(オンボーディング未完了/デバッグでのApple ID偽装注入など)
    /// でも、この定数を光のにじみの種として使うことでチェキカード自体は必ず描画できる。
    private static let fallbackSeed = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var currentProfile: UserProfile? {
        UserProfile.current(from: profiles)
    }

    private var isOwnProfile: Bool { viewedUser == nil }

    /// 実際に画面へ表示するプロフィール。viewedUserがあればそれを優先する。
    private var displayedProfile: UserProfile? {
        viewedUser ?? currentProfile
    }


    /// Pinsエリアに表示する、ピン留め順のLaterPhoto一覧。pinnedPhotoIDsに残っていても
    /// 実体が消えている(端末に無い等)IDはcompactMapで自然に読み飛ばす。
    private var pinnedPhotos: [LaterPhoto] {
        guard let profile = displayedProfile else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: profile.photos.map { ($0.id, $0) })
        return profile.pinnedPhotoIDs.compactMap { byID[$0] }
    }

    /// ピン留め候補(解禁済みの自分の写真、新しい順)。
    private var unlockedPhotosForPinning: [LaterPhoto] {
        (displayedProfile?.photos ?? [])
            .filter(\.isUnlocked)
            .sorted { $0.captureDate > $1.captureDate }
    }

    private var remainingPinSlots: Int {
        max(0, UserProfile.maxPinnedPhotos - (displayedProfile?.pinnedPhotoIDs.count ?? 0))
    }

    private func addPins(_ newIDs: [UUID]) {
        guard let profile = displayedProfile else { return }
        var ids = profile.pinnedPhotoIDs
        for id in newIDs where !ids.contains(id) {
            ids.append(id)
        }
        profile.pinnedPhotoIDs = Array(ids.prefix(UserProfile.maxPinnedPhotos))
        try? context.save()
    }

    private func removePin(_ id: UUID) {
        guard let profile = displayedProfile else { return }
        profile.pinnedPhotoIDs.removeAll { $0 == id }
        try? context.save()
    }

    /// MEの記録は共同実績にカウントしない([[LaterGroup.isPersonalSpace]])ため、
    /// 連続選出の判定対象からもMEのgroupIDに紐づく写真を除外する。
    private var personalSpaceGroupIDs: Set<UUID> {
        Set(groups.filter(\.isPersonalSpace).map(\.id))
    }

    /// 「その日、自分が参加するいずれかの(ME以外の)グループで合計
    /// individualMinimumPhotoCount枚以上撮影できた日」を1日として、
    /// 直近(昨日を起点)から連続している日数を数える。
    private var streak: Int {
        guard let profile = displayedProfile else { return 0 }
        return profile.currentStreak(personalSpaceGroupIDs: personalSpaceGroupIDs)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    if isOwnProfile {
                        topBar
                    }

                    // プロフィールが1件も無くても、フォールバック値でカード自体は必ず描画する
                    // (以前はif let currentProfileで丸ごと非表示にしており、それが不具合の原因だった)。
                    ProfileChekiCard(
                        name: (displayedProfile?.name).flatMap { $0.isEmpty ? nil : $0 } ?? "ゲスト",
                        username: (displayedProfile?.username).flatMap { $0.isEmpty ? nil : $0 } ?? "guest",
                        bio: displayedProfile?.bio ?? "",
                        profileImageData: displayedProfile?.profileImageData,
                        streak: streak,
                        updatedAt: displayedProfile?.profileUpdatedAt,
                        seed: displayedProfile?.id ?? Self.fallbackSeed,
                        isEditable: isOwnProfile,
                        onQRCode: { isShowingMyQRCode = true },
                        onShare: { isShowingShare = true },
                        onEdit: { isShowingSetup = true }
                    )
                    .padding(.horizontal, 20)

                    if isOwnProfile {
                        pinsSection
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Color.brandBlack.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $isShowingShare) {
                ShareSheet(activityItems: shareActivityItems)
            }
            .sheet(isPresented: $isShowingSetup) {
                ProfileEditView()
            }
            .sheet(isPresented: $isShowingMyQRCode) {
                MyQRCodeView()
            }
            .fullScreenCover(isPresented: $isShowingSettingsMenu) {
                SettingsMenuView(isShowing: $isShowingSettingsMenu)
                    .transition(.move(edge: .trailing))
            }
            // 以前タブとして開いていたGalleryを、これまでと全く同じView
            // (中身・機能は無変更)のままfullScreenCoverで開く導線に変更した。
            .fullScreenCover(isPresented: $isShowingGallery) {
                MultiGroupGalleryView()
            }
            #if DEBUG
            .fullScreenCover(isPresented: $isShowingFilmEmulationDebug) {
                FilmEmulationDebugPreview()
            }
            #endif
            // グループ作成画面(CircleManagementView.swift内のCircleCreateGroupView)を
            // そのまま流用する。元々CircleManagementView側で.sheetとして使われていた
            // ものと同じ提示方法に合わせている。
            .sheet(isPresented: $isShowingCreateGroup) {
                CircleCreateGroupView()
            }
        }
    }

    // MARK: - 上部バー(ギャラリーへの導線+メニュー)

    /// タブバーを3項目(Home/撮影/プロフィール)に縮小したことに伴い、以前タブから
    /// 開いていたGalleryをこのヘッダー行のボタンから開く導線に変更した。
    /// 既存の設定ボタン(三本線)の機能・実体はそのまま、その左に追加しているだけ。
    private var topBar: some View {
        HStack(spacing: 14) {
            // 以前Connection画面にあった「グループ作成」導線(circle.hexagongrid.fillの
            // ボタン、CircleManagementView経由)をここへ移動した。中身はグループ作成時の
            // 画面(CircleCreateGroupView)をそのまま使う。
            headerNavButton(systemImage: "plus") {
                isShowingCreateGroup = true
            }

            Spacer()

            headerNavButton(systemImage: "square.grid.2x2") {
                isShowingGallery = true
            }

            #if DEBUG
            // FilmEmulation(新チェキ処理)の実機確認用。一時的なデバッグ導線であり、
            // DEBUGビルド以外には出現しない。
            headerNavButton(systemImage: "camera.filters") {
                isShowingFilmEmulationDebug = true
            }
            #endif

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isShowingSettingsMenu = true
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.white.opacity(0.08)))
                    .contentShape(Rectangle())
            }
            .buttonStyle(ProfileTopBarButtonStyle())
        }
        // 高さの異なるボタン(42→44x44 / 52x52)が混在するため、HStackの既定(中央揃え)に
        // 任せると行の実効高さが子要素ごとに変わり、意図せず狭いタップ判定になり得る。
        // 行全体の高さを最大の52で固定し、揃え方を明示的にする。
        .frame(height: 52)
        .padding(.horizontal, 20)
    }

    /// つながり/ギャラリーへの導線ボタン共通の見た目(円形44x44、背景rgba(255,255,255,0.06))。
    /// 既存の設定ボタンとスタイル言語は揃えつつ、一回り小さいサイズにしている。
    /// タップ判定はcontentShape(Circle())ではなくRectangleにしている
    /// (見た目は円でも、円の内接に収まらない四隅までタップを取りこぼさないようにするため。
    /// 「ボタンの下の方を押すと反応せず下のカードの編集タップに抜けてしまう」不具合の対策)。
    private func headerNavButton(systemImage: String, badgeCount: Int = 0, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.06)))
                .contentShape(Rectangle())
                .overlay(alignment: .topTrailing) {
                    if badgeCount > 0 {
                        Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, badgeCount > 9 ? 4 : 0)
                            .frame(minWidth: 14, minHeight: 14)
                            .background(Circle().fill(Color.red))
                            .offset(x: 4, y: -4)
                    }
                }
        }
        .buttonStyle(ProfileTopBarButtonStyle())
    }

    // MARK: - Pinsセクション

    private var pinsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("pins")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                if !pinnedPhotos.isEmpty && remainingPinSlots > 0 {
                    Button {
                        isShowingPinPicker = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 24)

            if pinnedPhotos.isEmpty {
                Button {
                    isShowingPinPicker = true
                } label: {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .foregroundStyle(.white.opacity(0.2))
                        .frame(height: 100)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .light))
                                .foregroundStyle(.white.opacity(0.3))
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(pinnedPhotos, id: \.id) { photo in
                            pinnedPhotoCard(photo)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .sheet(isPresented: $isShowingPinPicker) {
            PinPhotoPickerView(
                photos: unlockedPhotosForPinning,
                alreadyPinnedIDs: Set(displayedProfile?.pinnedPhotoIDs ?? []),
                remainingSlots: remainingPinSlots,
                onConfirm: { newIDs in addPins(newIDs) }
            )
        }
    }

    /// ピン留め済み写真1枚のカード。右上の×ボタン、または長押しのどちらでも解除できる。
    private func pinnedPhotoCard(_ photo: LaterPhoto) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.white.opacity(0.05)
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .onLongPressGesture {
                HapticsManager.tick()
                removePin(photo.id)
            }

            Button {
                removePin(photo.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.black.opacity(0.65)))
            }
            .offset(x: 6, y: -6)
        }
    }

    // MARK: - シェア

    /// 招待リンク+QRコードをシェアシートに渡す。リンクはMyQRCodeViewと同じ
    /// laterapp://user?id=...&name=... 形式(既存のQRCodeGeneratorをそのまま再利用)。
    private var shareActivityItems: [Any] {
        guard let profile = currentProfile else {
            return ["Later で今日の一枚を撮っています。"]
        }

        let qrDataString = QRCodeGenerator.createUserQRData(userID: profile.id.uuidString, userName: profile.name)
        guard let url = URL(string: qrDataString) else {
            return ["Later で今日の一枚を撮っています。"]
        }

        var items: [Any] = [
            ProfileShareItem(name: profile.name, username: profile.username, url: url)
        ]

        if let logo = MyQRCodeView.logoPlateImage,
           let qrImage = QRCodeGenerator.generateQRCodeWithLogoPlate(
               from: qrDataString,
               size: 512,
               logoImage: logo,
               foregroundColor: .black,
               backgroundColor: .white
           ) {
            items.append(qrImage)
        }

        return items
    }
}

/// 通知・設定ボタン(topBar)専用の押下フィードバック。不透明度の変化で
/// タップしたことが直感的に分かるようにする(軽いスケールも添える)。
private struct ProfileTopBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
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
    @State private var pendingCropImage: UIImage?
    @State private var showingCropEditor = false
    
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
                // 実際のUserProfile(SwiftData)から読み込む。以前は@AppStorageから
                // 読み込んでおり、オンボーディングを経由していない環境(デバッグ注入等)では
                // AppStorageが空のままUserProfileとズレて、保存ボタンが常時disabledに
                // なる/保存内容が食い違う原因になっていた。無ければAppStorage→空文字の順で
                // フォールバックする。
                if let user = UserProfile.current(from: profiles) {
                    inputName = user.name
                    inputUserID = user.username
                    inputBio = user.bio
                    inputImageData = user.profileImageData
                } else {
                    inputName = userName
                    inputUserID = userID
                    inputBio = userBio
                    inputImageData = profileImageData
                }
            }
            .onChange(of: selectedItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        // 選び直した写真はまず正方形クロップ編集を挟む(SquareImageCropView)。
                        // チェキ加工の焼き込みはクロップ確定後に行う。
                        pendingCropImage = uiImage
                        showingCropEditor = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCropEditor) {
                if let image = pendingCropImage {
                    SquareImageCropView(sourceImage: image) { croppedData in
                        showingCropEditor = false
                        Task {
                            // プロフィール画像は「解禁時に一度だけ焼き込む」写真とは異なり、
                            // 本人が選び直した瞬間にだけ発生する一回きりの操作のため、
                            // ここで焼き込んでおく(表示のたびに毎回加工していた以前の設計を
                            // 統一する)。
                            inputImageData = await ChekiColorGrade.bakedData(from: croppedData) ?? croppedData
                        }
                    } onCancel: {
                        showingCropEditor = false
                        pendingCropImage = nil
                        selectedItem = nil
                    }
                }
            }
        }
    }
    
    // MARK: - サブビュー
    
    /// チェキ(ProfileChekiCard/ChekiPhotoFrame)と全く同じ白フレーム色・比率でプレビューする。
    /// 編集時に見えていた構図とチェキの実際の表示結果がズレないよう、円形マスクはやめ、
    /// チェキ本体と同じ正方形(1:1)+7px内側パディング+角丸2pxの構造をそのまま踏襲する。
    private let chekiFrameColor = Color(red: 0.969, green: 0.961, blue: 0.933) // #f7f5ee

    /// 正方形プレビューの一辺の長さ(固定値なのでGeometryReader不要)。
    private static let previewPhotoSize: CGFloat = 126

    private var profileImageSection: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    photoPreviewArea
                        .padding(7)
                        .background(chekiFrameColor)
                        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)

                    editBadge
                        .offset(x: 8, y: 8)
                }
            }

            Text("写真をタップして変更(チェキと同じ比率で表示されます)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    /// .aspectRatio(1, .fit)だけに頼ると、高さが不定な文脈で縦長画像の
    /// 理想サイズが外側へ漏れて正方形化が崩れることがあるため、
    /// 幅・高さを両方明示した.frame(width:height:)を必ず併用する。
    @ViewBuilder
    private var photoPreviewArea: some View {
        ZStack {
            if let imageData = inputImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.white.opacity(0.08)
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .frame(width: Self.previewPhotoSize, height: Self.previewPhotoSize)
        .clipped()
    }

    private var editBadge: some View {
        ZStack {
            Circle()
                .fill(Color.brandGreen)
                .frame(width: 32, height: 32)
                .shadow(color: Color.brandGreen.opacity(0.5), radius: 8, x: 0, y: 4)

            Image(systemName: "camera.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
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
        // 1件も存在しない場合(オンボーディング未完了など)はここで新規作成する —
        // でないと「編集」から保存しても何も永続化されず、フォールバック表示のままになる。
        let user: UserProfile
        if let existing = UserProfile.current(from: profiles) {
            user = existing
        } else {
            user = UserProfile(name: inputName, username: inputUserID)
            modelContext.insert(user)
        }

        user.name = inputName
        user.username = inputUserID
        user.bio = inputBio
        user.profileImageData = inputImageData
        user.profileUpdatedAt = Date()
        try? modelContext.save()

        if let cloudKitManager = CloudKitManager.current {
            for group in user.groups {
                cloudKitManager.markForUpload(userProfile: user, in: group)
            }
        }

        // 公開ディレクトリ(laterapp://リンク/QRで共有した相手が引く用)も最新化する。
        Task { await UserDirectoryService.publish(user) }

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

