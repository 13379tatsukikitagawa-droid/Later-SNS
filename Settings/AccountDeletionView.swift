import SwiftUI
import SwiftData

/// アカウント削除の確認画面(App Store審査ガイドライン5.1.1(v)対応)。
/// 「削除」と入力させることで誤操作を防ぐ。
struct AccountDeletionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @AppStorage("appleUserID") private var appleUserID: String = ""
    @AppStorage("appleFullName") private var appleFullName: String = ""
    @AppStorage("currentProfileID") private var currentProfileID: String = ""
    @AppStorage("isSetupCompleted") private var isSetupCompleted: Bool = false
    @AppStorage("hasCompletedSurvey") private var hasCompletedSurvey: Bool = false
    @AppStorage("hasSeenAboutLaterIntro") private var hasSeenAboutLaterIntro: Bool = false

    @State private var confirmationText = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private var isConfirmed: Bool { confirmationText == "削除" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.red)

                    Text("アカウントを削除しますか?")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 10) {
                        bulletRow("参加している全てのCircle・MEのデータ")
                        bulletRow("World Laterへの自分の投稿")
                        bulletRow("プロフィール・撮影履歴のすべて")
                    }
                    Text("これらは元に戻せません。")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.9))

                    Text("よろしければ、下の欄に「削除」と入力してください。")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 8)

                    TextField("削除", text: $confirmationText)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                    }

                    Button(role: .destructive) {
                        Task { await performDeletion() }
                    } label: {
                        if isDeleting {
                            ProgressView().tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("完全に削除する")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isConfirmed ? Color.red : Color.red.opacity(0.3))
                    )
                    .disabled(!isConfirmed || isDeleting)
                }
                .padding(20)
            }
            .background(Color.brandBlack.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("・")
            Text(text)
        }
        .font(.system(size: 14))
        .foregroundStyle(.white.opacity(0.8))
    }

    private func performDeletion() async {
        isDeleting = true
        errorMessage = nil
        do {
            try await AccountDeletionService.deleteAccount(modelContext: modelContext)
            appleUserID = ""
            appleFullName = ""
            currentProfileID = ""
            isSetupCompleted = false
            hasCompletedSurvey = false
            hasSeenAboutLaterIntro = false
            dismiss()
        } catch {
            isDeleting = false
            errorMessage = "削除に失敗しました。しばらくしてからもう一度お試しください。"
            print("[AccountDeletion] failed: \(error)")
        }
    }
}
