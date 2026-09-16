import SwiftUI
import SwiftData

/// アバターアイコン(ヘッダー右端)から開く「マイページ」。旧Profileタブ(ProfileView)を
/// 廃止し、setlog/BeReal的な「ペルソナ表示+設定リスト」構成に置き換えた新しい画面。
///
/// ここで表示される名前・アイコンは、ユーザーの実際の姿(実名・実写)ではなく、
/// PersonaGeneratorが割り当てたLater内だけの別人格。プロフィール写真アップロード
/// (旧SquareImageCropView等)は匿名性・ルッキズム対策のため今回廃止した。
struct MyPageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]

    @State private var showingNameEdit = false
    @State private var showingIconEdit = false
    @State private var showingNotifications = false
    @State private var showingBlockedList = false
    @State private var showingHelp = false
    @State private var showingCalendar = false
    @State private var showingGallery = false
    @State private var showingDevelopingProgress = false
    @State private var showingAccountDeletion = false
    @State private var showingSignOutConfirm = false

    @AppStorage("appleUserID") private var appleUserID: String = ""
    @AppStorage("appleFullName") private var appleFullName: String = ""
    @AppStorage("currentProfileID") private var currentProfileID: String = ""
    @AppStorage("isSetupCompleted") private var isSetupCompleted: Bool = false

    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }

    private var userGroups: [LaterGroup] {
        guard let user = currentUser else { return [] }
        return groups.filter { $0.members.contains(where: { $0.id == user.id }) }
    }

    /// 「現像中」導線の統合先。以前はHome画面ヘッダーの専用ボタンから開いていたが、
    /// MVP再設計でヘッダーから廃止したため、ここ(マイページ)に集約する。
    /// 単一グループに限らず、自分が撮影した未解禁の写真を全グループから集めて渡す。
    private var developingPhotos: [LaterPhoto] {
        guard let user = currentUser else { return [] }
        return userGroups.flatMap { group in
            group.photos.filter { $0.owner?.id == user.id && !$0.isUnlocked }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 28) {
                        personaHeader
                        contentLinksSection
                        settingsSection
                    }
                    .padding(.vertical, 28)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .sheet(isPresented: $showingNameEdit) {
                PersonaNameEditView()
            }
            .sheet(isPresented: $showingIconEdit) {
                PersonaIconEditView()
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationsView()
            }
            .sheet(isPresented: $showingBlockedList) {
                BlockedUsersListView()
            }
            .sheet(isPresented: $showingHelp) {
                HelpAndSupportView()
            }
            .sheet(isPresented: $showingCalendar) {
                TodaysLaterCalendarView()
            }
            .fullScreenCover(isPresented: $showingGallery) {
                MultiGroupGalleryView()
            }
            .sheet(isPresented: $showingDevelopingProgress) {
                DevelopingProgressView(photos: developingPhotos)
            }
            .fullScreenCover(isPresented: $showingAccountDeletion) {
                AccountDeletionView()
            }
            .alert("サインアウト", isPresented: $showingSignOutConfirm) {
                Button("キャンセル", role: .cancel) {}
                Button("サインアウト", role: .destructive) { signOut() }
            } message: {
                Text("サインアウトしてもよろしいですか?")
            }
        }
    }

    // MARK: - ペルソナ表示

    private var personaHeader: some View {
        VStack(spacing: 14) {
            Button {
                showingIconEdit = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    CachedPhotoImage(
                        imageData: currentUser?.profileImageData,
                        cacheKey: "avatar_mypage_\(currentUser?.id.uuidString ?? "me")"
                    ) { uiImage in
                        Image(uiImage: uiImage)
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ZStack {
                            Color.white.opacity(0.08)
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }
                    .frame(width: 108, height: 108)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.brandGreen.opacity(0.5), lineWidth: 2))

                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white, Color.brandGreen)
                        .background(Circle().fill(Color.brandBlack))
                }
            }
            .buttonStyle(.plain)

            Button {
                showingNameEdit = true
            } label: {
                VStack(spacing: 4) {
                    Text(currentUser?.name.isEmpty == false ? currentUser!.name : "名もなきキツネ")
                        .font(.custom("Caveat-Bold", size: 30))
                        .foregroundStyle(.white)
                    Text(currentUser?.username.isEmpty == false ? "@\(currentUser!.username)" : "@fox-0000")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .buttonStyle(.plain)

            Text("ここでの名前とアイコンは、普段のあなたとは別のもの。\nLaterの中だけの、もうひとつの姿です。")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .rotationEffect(.degrees(-1))
        }
        .padding(.top, 12)
    }

    // MARK: - コンテンツ導線(カレンダー・ギャラリー)

    private var contentLinksSection: some View {
        VStack(spacing: 12) {
            MenuRow(icon: "calendar", iconColor: .brandGreen, title: "カレンダー", subtitle: "今日のLaterの記録") {
                showingCalendar = true
            }
            MenuRow(icon: "photo.stack.fill", iconColor: .brandGreen, title: "ギャラリー", subtitle: "グループごとの解禁済み写真") {
                showingGallery = true
            }
            MenuRow(icon: "flask.fill", iconColor: .brandGreen, title: "現像中", subtitle: developingPhotos.isEmpty ? "現像中の写真はありません" : "\(developingPhotos.count)枚 現像中") {
                showingDevelopingProgress = true
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 設定リスト

    private var settingsSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                sectionTitle("ペルソナ・通知")
                MenuRow(icon: "textformat", iconColor: .blue, title: "名前を変える", subtitle: currentUser?.name ?? "") {
                    showingNameEdit = true
                }
                MenuRow(icon: "face.smiling.fill", iconColor: .purple, title: "アイコンを変える", subtitle: "プリセットから選ぶ") {
                    showingIconEdit = true
                }
                MenuRow(icon: "bell.fill", iconColor: .orange, title: "通知", subtitle: "解禁・招待などの通知") {
                    showingNotifications = true
                }
            }

            VStack(spacing: 12) {
                sectionTitle("アカウント")
                infoRow(icon: "apple.logo", iconColor: .white, title: "ログイン中のアカウント", value: "Appleでサインイン中")
                MenuRow(icon: "flag.fill", iconColor: .red, title: "通報・ブロックした人", subtitle: "ブロックリストの確認・解除") {
                    showingBlockedList = true
                }
                MenuRow(icon: "questionmark.circle.fill", iconColor: .cyan, title: "ヘルプ・このアプリについて", subtitle: "よくある質問") {
                    showingHelp = true
                }
                MenuRow(icon: "arrow.right.square", iconColor: .white, title: "サインアウト", subtitle: "") {
                    showingSignOutConfirm = true
                }
            }

            VStack(spacing: 12) {
                MenuRow(icon: "trash.fill", iconColor: .red, title: "アカウントを削除する", subtitle: "すべてのデータを完全に削除します") {
                    showingAccountDeletion = true
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.white.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private func infoRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.08)))
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func signOut() {
        appleUserID = ""
        appleFullName = ""
        currentProfileID = ""
        isSetupCompleted = false
        dismiss()
    }
}

// MARK: - 名前を変える(ペルソナ名の再生成)

private struct PersonaNameEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @AppStorage("userName") private var userNameStorage: String = ""
    @AppStorage("userID") private var userIDStorage: String = ""

    @State private var candidate = PersonaGenerator.generate()

    private var currentUser: UserProfile? { UserProfile.current(from: profiles) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer()
                    VStack(spacing: 6) {
                        Text(candidate.name)
                            .font(.custom("Caveat-Bold", size: 34))
                            .foregroundStyle(.white)
                        Text(candidate.shortID)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    Button {
                        candidate = PersonaGenerator.generate()
                    } label: {
                        Label("シャッフルする", systemImage: "shuffle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                    }

                    Spacer()

                    Button {
                        applyAndDismiss()
                    } label: {
                        Text("この名前にする")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.brandGreen))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("名前を変える")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private func applyAndDismiss() {
        let shortID = String(candidate.shortID.dropFirst()) // "@" を取り除いてusernameとして保存
        userNameStorage = candidate.name
        userIDStorage = shortID

        let user: UserProfile
        if let existing = currentUser {
            user = existing
        } else {
            user = UserProfile(name: candidate.name, username: shortID)
            modelContext.insert(user)
        }
        user.name = candidate.name
        user.username = shortID
        user.profileUpdatedAt = Date()
        try? modelContext.save()

        if let cloudKitManager = CloudKitManager.current {
            for group in user.groups {
                cloudKitManager.markForUpload(userProfile: user, in: group)
            }
        }
        Task { await UserDirectoryService.publish(user) }
        dismiss()
    }
}

// MARK: - アイコンを変える(プリセットから選択)

private struct PersonaIconEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @AppStorageData("profileImageData") private var profileImageDataStorage: Data?

    private let candidates: [PersonaGenerator.Persona] = (0..<8).map { _ in PersonaGenerator.generate() }
    @State private var selectedIndex: Int = 0

    private var currentUser: UserProfile? { UserProfile.current(from: profiles) }

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 16)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Array(candidates.enumerated()), id: \.offset) { index, persona in
                            Button {
                                selectedIndex = index
                            } label: {
                                ZStack {
                                    persona.iconColor
                                    Image(systemName: persona.iconSymbol)
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.95))
                                }
                                .frame(width: 76, height: 76)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().strokeBorder(selectedIndex == index ? Color.brandGreen : Color.clear, lineWidth: 3)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("アイコンを変える")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("決定") { applyAndDismiss() }
                }
            }
        }
    }

    private func applyAndDismiss() {
        guard let data = PersonaGenerator.renderIconImageData(for: candidates[selectedIndex]) else {
            dismiss()
            return
        }
        profileImageDataStorage = data

        let user: UserProfile
        if let existing = currentUser {
            user = existing
        } else {
            user = UserProfile(name: candidates[selectedIndex].name, username: String(candidates[selectedIndex].shortID.dropFirst()))
            modelContext.insert(user)
        }
        user.profileImageData = data
        user.profileUpdatedAt = Date()
        try? modelContext.save()

        if let cloudKitManager = CloudKitManager.current {
            for group in user.groups {
                cloudKitManager.markForUpload(userProfile: user, in: group)
            }
        }
        Task { await UserDirectoryService.publish(user) }
        dismiss()
    }
}

// MARK: - 通報・ブロックした人

private struct BlockedUsersListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BlockedUser.createdAt, order: .reverse) private var blockedUsers: [BlockedUser]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                if blockedUsers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "flag.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.25))
                        Text("ブロックした人はいません")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                } else {
                    List {
                        ForEach(blockedUsers) { blocked in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("ブロック済みユーザー")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white)
                                    Text(blocked.createdAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                Spacer()
                                Button("解除") {
                                    Task { await ModerationService.unblockUser(blocked, modelContext: modelContext) }
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.brandGreen)
                            }
                            .listRowBackground(Color.white.opacity(0.04))
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("通報・ブロックした人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
    }
}

#Preview {
    MyPageView()
        .modelContainer(for: [UserProfile.self, LaterGroup.self, LaterPhoto.self, BlockedUser.self], inMemory: true)
}
