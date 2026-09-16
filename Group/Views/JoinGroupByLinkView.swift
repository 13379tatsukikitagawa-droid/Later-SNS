import SwiftUI

/// Community(未参加)画面の「招待コードで参加する」から開く、招待リンク貼り付け画面。
///
/// 以前のセッションで「合言葉/QRコードでの参加は廃止し、共有リンクのタップのみで
/// 参加する」という設計判断がされているため、ここで新しい「コード検索→参加」の
/// バックエンドは作らない。代わりに、EmailSignInViewの「リンクのURLを貼り付け」と
/// 同じUXパターンで、招待リンク(later://join?shareUrl=...または素のCKShare URL)を
/// 手動で貼り付けてもらい、GroupJoinRequestStore経由でLaterApp(RootView)の既存の
/// handleGroupJoinLink(shareURL:)へそのまま渡す(CloudKit連携ロジックは完全に再利用)。
struct JoinGroupByLinkView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var linkText: String = ""

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 28) {
                        ZStack {
                            Circle()
                                .strokeBorder(Color.brandGreen.opacity(0.6), lineWidth: 1.5)
                                .frame(width: 72, height: 72)
                            Image(systemName: "link")
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(Color.brandGreen)
                        }

                        VStack(spacing: 8) {
                            Text("招待コードで参加")
                                .font(.custom("Caveat-Bold", size: 30))
                                .foregroundStyle(Color.corkboardTabActiveText)
                            Text("送られてきた招待リンクを貼り付けてください")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(Color.corkboardTabInactiveText)
                                .multilineTextAlignment(.center)
                        }

                        DarkFieldCard(label: "招待リンク") {
                            TextField("https://...", text: $linkText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundStyle(Color.corkboardTabActiveText)
                        }

                        Button {
                            join()
                        } label: {
                            Text("参加する")
                                .frame(maxWidth: .infinity)
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.brandGreen))
                        .disabled(linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 24)
                    .frame(minHeight: geometry.size.height, alignment: .center)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(
                ZStack {
                    Color.corkboardBackground
                    CorkboardDotTexture()
                }
                .ignoresSafeArea()
            )
            .navigationTitle("招待コードで参加する")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Color.brandGreen)
                }
            }
        }
    }

    private func join() {
        let trimmed = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return }
        GroupJoinRequestStore.shared.pendingURL = url
        dismiss()
    }
}

#Preview {
    JoinGroupByLinkView()
}
