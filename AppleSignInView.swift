import SwiftUI
import SwiftData
import AuthenticationServices

/// Sign in with Appleのみのシンプルなログインゲート。
/// 成功すると appleUserID を保存し、既存のUserProfileがあればそれを、
/// なければこの後のOnboardingView(プロフィール入力)で新規作成する。
struct AppleSignInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("appleUserID") private var appleUserID: String = ""
    @AppStorage("appleFullName") private var appleFullName: String = ""
    @AppStorage("currentProfileID") private var currentProfileID: String = ""
    @AppStorage("isSetupCompleted") private var isSetupCompleted: Bool = false

    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 64))
                Text("later")
                    .font(.system(size: 44, weight: .light))
                Text("撮影した写真は、決められた時刻に現像されます")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName]
            } onCompletion: { result in
                handle(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .padding(.horizontal, 40)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            #if DEBUG
            Button {
                appleUserID = "debug-user"
                appleFullName = "テストユーザー"
            } label: {
                Text("スキップ（テスト用）")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
            #endif

            Spacer()
        }
        .disabled(isLoading)
        .overlay {
            if isLoading { ProgressView() }
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Apple認証に失敗しました"
                return
            }

            isLoading = true
            defer { isLoading = false }

            let userID = credential.user
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            appleUserID = userID
            if !fullName.isEmpty {
                appleFullName = fullName
            }

            // 同じApple IDの既存プロフィールがあれば再利用し、そのままメイン画面へ進む。
            // なければ、この後 OnboardingView でプロフィール(名前・ユーザーID・写真)を入力してもらう。
            let descriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate<UserProfile> { $0.appleUserID == userID }
            )
            if let existing = try? modelContext.fetch(descriptor).first {
                currentProfileID = existing.id.uuidString
                isSetupCompleted = true
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
