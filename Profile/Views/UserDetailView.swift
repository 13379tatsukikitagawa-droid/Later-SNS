import SwiftUI
import SwiftData

/// 他のユーザーのプロフィール詳細画面(読み取り専用)。フォロー申請・チャット機能は
/// Laterの匿名・非フォロー型の世界観と矛盾するため撤去済み。検索・QRコード経由で
/// 見つけた相手のプロフィール(名前・ユーザー名・自己紹介・アイコン)を表示するだけの画面。
struct UserDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let user: UserProfile

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        // Profile image
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.brandGreen, Color.brandGreen.opacity(0.6)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .overlay(
                                Text(user.name.prefix(1))
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundStyle(.white)
                            )

                        VStack(spacing: 4) {
                            Text(user.name)
                                .font(.title2.bold())
                                .foregroundStyle(.white)

                            Text("@\(user.username)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if !user.bio.isEmpty {
                            Text(user.bio)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top, 40)
                }
                .padding(.bottom, 40)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                await refreshProfileFromDirectory()
            }
        }
    }

    /// Public DBの公開ディレクトリ(UserDirectoryService)から、相手の最新の名前・
    /// @ユーザー名・アイコンを取得してローカルのキャッシュを更新する。QR/プロフィール
    /// リンク経由の相手はuser.idがそのまま本人の公開ディレクトリキーと一致するため
    /// 解決できる(グループ共有経由で同期済みの相手はuser.idが端末ごとに異なるローカルIDの
    /// ため対象外になるが、その場合はグループの共有ゾーン経由で既に最新化されている)。
    private func refreshProfileFromDirectory() async {
        guard let directoryProfile = await UserDirectoryService.fetchProfile(id: user.id) else { return }
        if !directoryProfile.name.isEmpty { user.name = directoryProfile.name }
        if !directoryProfile.username.isEmpty { user.username = directoryProfile.username }
        if !directoryProfile.bio.isEmpty { user.bio = directoryProfile.bio }
        if let avatarData = directoryProfile.avatarData { user.profileImageData = avatarData }
        try? modelContext.save()
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: UserProfile.self,
        configurations: config
    )

    let user = UserProfile(name: "Alice", username: "alice")
    user.bio = "Photography enthusiast 📸"

    return UserDetailView(user: user)
        .modelContainer(container)
}
