import SwiftUI
import SwiftData

/// メールのマジックリンク(パスワードレス)ログイン画面。Sign in with Appleの代替手段。
/// AppleSignInViewから「メールでサインインする」ボタンでシートとして開く。
struct EmailSignInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @AppStorage("firebaseUID") private var firebaseUID: String = ""
    @AppStorage("firebaseEmail") private var firebaseEmailStorage: String = ""
    @AppStorage("currentProfileID") private var currentProfileID: String = ""
    @AppStorage("isSetupCompleted") private var isSetupCompleted: Bool = false

    @State private var email: String = ""
    @State private var pastedLink: String = ""
    @State private var isSending = false
    @State private var isCompleting = false
    @State private var didSendLink = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !FirebaseConfigurator.isConfigured {
                        notConfiguredNotice
                    } else if didSendLink {
                        linkSentSection
                    } else {
                        emailEntrySection
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            .background(Color.brandBlack.ignoresSafeArea())
            .navigationTitle("メールでサインイン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var notConfiguredNotice: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "hourglass")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.5))
            Text("メールログインは準備中です")
                .font(.headline)
                .foregroundStyle(.white)
            Text("しばらくしてからもう一度お試しください。それまでは「Sign in with Apple」をご利用いただけます。")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var emailEntrySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("メールアドレスにサインイン用のリンクを送ります。")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))

            TextField("メールアドレス", text: $email)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                Task { await sendLink() }
            } label: {
                if isSending {
                    ProgressView().tint(.black)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("リンクを送信")
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.brandGreen))
            .disabled(email.isEmpty || isSending)
        }
    }

    private var linkSentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.brandGreen)
            Text("\(email) にリンクを送りました")
                .font(.headline)
                .foregroundStyle(.white)
            Text("メール内のリンクをタップすると自動的にサインインします。もしアプリへ戻れない場合は、リンクのURLをコピーして下に貼り付けてください。")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))

            TextField("リンクのURLを貼り付け", text: $pastedLink)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                Task { await completeSignIn(withLink: pastedLink) }
            } label: {
                if isCompleting {
                    ProgressView().tint(.black)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("このリンクでサインイン")
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.brandGreen))
            .disabled(pastedLink.isEmpty || isCompleting)
        }
    }

    private func sendLink() async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            try await FirebaseAuthService.sendSignInLink(to: email)
            didSendLink = true
        } catch {
            // 原因の特定を早めるため、開発中は実際のエラー内容もそのまま表示する。
            errorMessage = "送信に失敗しました: \((error as NSError).domain) code=\((error as NSError).code) \(error.localizedDescription)"
            print("[EmailSignIn] sendSignInLink failed: \(error)")
        }
    }

    private func completeSignIn(withLink link: String) async {
        isCompleting = true
        errorMessage = nil
        defer { isCompleting = false }
        do {
            let result = try await FirebaseAuthService.completeSignIn(withLink: link, email: email)
            applySignInResult(uid: result.uid, email: result.email ?? email)
            dismiss()
        } catch {
            errorMessage = "サインインに失敗しました。リンクの有効期限が切れている可能性があります。"
            print("[EmailSignIn] completeSignIn failed: \(error)")
        }
    }

    /// Sign in with Apple(AppleSignInView.handle)と同じ方針: 同じfirebaseUIDの
    /// 既存プロフィールがあれば再利用し、無ければこの後のOnboardingViewで新規作成する。
    private func applySignInResult(uid: String, email: String) {
        firebaseUID = uid
        firebaseEmailStorage = email

        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate<UserProfile> { $0.firebaseUID == uid }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            currentProfileID = existing.id.uuidString
            isSetupCompleted = true
        }
    }
}
