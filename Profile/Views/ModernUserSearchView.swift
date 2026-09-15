import SwiftUI
import SwiftData

// MARK: - Modern User Search View
/// ユーザー検索画面。Public DBのUserDirectoryService.search(usernamePrefix:)で実際のユーザーを
/// 検索し、タップすると既存のUserDetailView(読み取り専用のプロフィール表示)へ遷移する。
struct ModernUserSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var searchResults: [UserDirectoryService.DirectoryProfile] = []
    @State private var selectedUser: UserProfile?

    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }

    /// 自分自身は検索結果から除く。
    private var displayResults: [UserDirectoryService.DirectoryProfile] {
        guard let myCloudKitID = currentUser?.cloudKitUserRecordName else { return searchResults }
        return searchResults.filter { $0.cloudKitUserRecordName != myCloudKitID }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 検索バー
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 20)

                    // 検索結果
                    if searchText.isEmpty {
                        emptySearchView
                    } else if isSearching {
                        ProgressView().tint(.white)
                        Spacer()
                    } else if displayResults.isEmpty {
                        noResultsView
                    } else {
                        searchResultsList
                    }
                }
            }
            .navigationTitle("友達を検索")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedUser) { user in
                UserDetailView(user: user)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .task(id: searchText) {
                await performSearch()
            }
        }
    }

    // MARK: - サブビュー

    private var searchBar: some View {
        HStack(spacing: 12) {
            // 検索アイコン
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(searchText.isEmpty ? .white.opacity(0.4) : .brandGreen)

            // テキストフィールド
            TextField("ユーザー名(@なし)で検索", text: $searchText)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.search)

            // クリアボタン
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    HapticsManager.swipeFeedback()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            searchText.isEmpty ? Color.white.opacity(0.1) : Color.brandGreen.opacity(0.3),
                            lineWidth: 1.5
                        )
                )
        )
    }

    private var emptySearchView: some View {
        VStack(spacing: 24) {
            Spacer()

            // アイコン
            Image(systemName: "person.2.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))
                .symbolEffect(.pulse)

            // テキスト
            VStack(spacing: 12) {
                Text("友達を探しましょう")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("ユーザー名で検索して\n友達とつながりましょう")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 24) {
            Spacer()

            // アイコン
            Image(systemName: "person.slash.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))

            // テキスト
            VStack(spacing: 12) {
                Text("ユーザーが見つかりません")
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text("「\(searchText)」に一致するユーザーはいませんでした")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(displayResults) { profile in
                    SearchUserCard(profile: profile) {
                        selectedUser = findOrCreateLocalProfile(from: profile)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    // MARK: - メソッド

    /// searchTextの変化に応じて呼ばれる(.task(id:)はidが変わると前のタスクを自動キャンセルする
    /// ため、これ自体が簡易デバウンスになる)。連続入力中の余計なクエリを避けるため
    /// 少し待ってから検索する。
    private func performSearch() async {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else { return }
        searchResults = await UserDirectoryService.search(usernamePrefix: searchText)
        isSearching = false
    }

    /// タップされた検索結果に対応するローカルUserProfileを探すか、無ければ最小限の情報で
    /// プレースホルダーを作る。
    private func findOrCreateLocalProfile(from directoryProfile: UserDirectoryService.DirectoryProfile) -> UserProfile {
        if let cloudKitUserRecordName = directoryProfile.cloudKitUserRecordName,
           let existing = profiles.first(where: { $0.cloudKitUserRecordName == cloudKitUserRecordName }) {
            return existing
        }
        if let existing = profiles.first(where: { $0.id == directoryProfile.id }) {
            return existing
        }
        let placeholder = UserProfile(name: directoryProfile.name, username: directoryProfile.username)
        // idをuserdir_<uuid>のuuidに合わせておく(LaterApp.handleIncomingProfileLinkと
        // 同じ理由で、UserDirectoryService.fetchProfile(id:)による以後の解決に必須)。
        placeholder.id = directoryProfile.id
        placeholder.cloudKitUserRecordName = directoryProfile.cloudKitUserRecordName
        placeholder.profileImageData = directoryProfile.avatarData
        modelContext.insert(placeholder)
        try? modelContext.save()
        return placeholder
    }
}

// MARK: - Search User Card
/// 検索結果のユーザーカード。タップでUserDetailView(読み取り専用のプロフィール表示)へ
/// 遷移するだけ。
fileprivate struct SearchUserCard: View {
    let profile: UserDirectoryService.DirectoryProfile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                profileImage

                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("@\(profile.username)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))

                    if !profile.bio.isEmpty {
                        Text(profile.bio)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
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
        .buttonStyle(BounceButtonStyle())
    }

    private var profileImage: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.cyan.opacity(0.6), .purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 56, height: 56)
            .overlay {
                if let avatarData = profile.avatarData, let uiImage = UIImage(data: avatarData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else {
                    Text(String(profile.name.prefix(1)))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
    }
}

// MARK: - プレビュー
#Preview {
    ModernUserSearchView()
}
