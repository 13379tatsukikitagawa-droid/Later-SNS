import SwiftUI
import SwiftData

/// メールのマジックリンク(パスワードレス)ログイン画面。Sign in with Appleの代替手段。
/// AppleSignInViewから「メールでサインインする」ボタンでシートとして開く。
///
/// 2026/9: レイアウトを画面縦中央寄せに変更し、見た目をLater共通のコルクボード風
/// ダーク×ドット柄・緑アクセント・手書き風見出しに統一した。あわせて、Firebaseの
/// 内部エラー文言(FIRAuthErrorDomain code=...)をそのまま表示していたのを、
/// FirebaseAuthService.friendlyErrorMessage(for:)経由の日本語メッセージに変更した
/// (code=17006は大抵、Firebase Console側で「メールリンク」プロバイダが無効になっている
/// ことが原因— アプリのコード側の問題ではない)。
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
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 28) {
                        if !FirebaseConfigurator.isConfigured {
                            notConfiguredNotice
                        } else if didSendLink {
                            linkSentSection
                        } else {
                            emailEntrySection
                        }

                        if let errorMessage {
                            errorPanel(errorMessage)
                        }
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
            .navigationTitle("メールでサインイン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Color.brandGreen)
                }
            }
        }
    }

    // MARK: - アイコン+見出し(共通)

    private var headerIcon: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.brandGreen.opacity(0.6), lineWidth: 1.5)
                .frame(width: 72, height: 72)
            Image(systemName: "envelope.fill")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Color.brandGreen)
        }
    }

    private var notConfiguredNotice: some View {
        VStack(spacing: 14) {
            headerIcon
            Text("メールログインは準備中です")
                .font(.custom("Caveat-Bold", size: 28))
                .foregroundStyle(Color.corkboardTabActiveText)
            Text("しばらくしてからもう一度お試しください。\nそれまでは「Sign in with Apple」をご利用いただけます。")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color.corkboardTabInactiveText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var emailEntrySection: some View {
        VStack(spacing: 20) {
            headerIcon

            VStack(spacing: 8) {
                Text("メールでサインイン")
                    .font(.custom("Caveat-Bold", size: 30))
                    .foregroundStyle(Color.corkboardTabActiveText)
                Text("メールアドレスにサインイン用のリンクを送ります")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.corkboardTabInactiveText)
                    .multilineTextAlignment(.center)
            }

            fieldCard(label: "メールアドレス") {
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Color.corkboardTabActiveText)
            }

            sendButton
        }
        .frame(maxWidth: .infinity)
    }

    private var sendButton: some View {
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
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.brandGreen))
        .disabled(email.isEmpty || isSending)
    }

    private var linkSentSection: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .strokeBorder(Color.brandGreen.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 72, height: 72)
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color.brandGreen)
            }

            VStack(spacing: 8) {
                Text("\(email) にリンクを送りました")
                    .font(.custom("Caveat-Bold", size: 26))
                    .foregroundStyle(Color.corkboardTabActiveText)
                    .multilineTextAlignment(.center)
                Text("メール内のリンクをタップすると自動的にサインインします。\nもしアプリへ戻れない場合は、リンクのURLをコピーして下に貼り付けてください。")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.corkboardTabInactiveText)
                    .multilineTextAlignment(.center)
            }

            fieldCard(label: "リンクのURL") {
                TextField("https://...", text: $pastedLink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Color.corkboardTabActiveText)
            }

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
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.brandGreen))
            .disabled(pastedLink.isEmpty || isCompleting)

            resendButton
        }
        .frame(maxWidth: .infinity)
    }

    /// メールが届かない場合に、同じアドレスへもう一度送信し直すためのボタン。
    private var resendButton: some View {
        Button {
            Task { await sendLink() }
        } label: {
            if isSending {
                ProgressView().tint(Color.brandGreen)
            } else {
                Text("リンクを再送する")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandGreen)
            }
        }
        .disabled(isSending)
    }

    // MARK: - 共通パーツ

    /// ダークパネル(#2c2116)カードの中にラベル+入力欄を配置し、下線を緑にする。
    private func fieldCard(label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.corkboardTabInactiveText)

            content()
                .font(.system(size: 16, weight: .medium))
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.brandGreen.opacity(0.7))
                        .frame(height: 1.5)
                }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.corkboardTabActive))
    }

    private func errorPanel(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15))
                .foregroundStyle(.red)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.red.opacity(0.15)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.red.opacity(0.4), lineWidth: 1))
    }

    // MARK: - 処理

    private func sendLink() async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            try await FirebaseAuthService.sendSignInLink(to: email)
            didSendLink = true
        } catch {
            errorMessage = FirebaseAuthService.friendlyErrorMessage(for: error)
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
            errorMessage = FirebaseAuthService.friendlyErrorMessage(for: error)
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

#Preview {
    EmailSignInView()
}
