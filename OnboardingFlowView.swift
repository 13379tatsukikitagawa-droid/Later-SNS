import SwiftUI
import AuthenticationServices
import PhotosUI
import SwiftData
import Foundation

// MARK: - Profile Image View (Local to OnboardingFlow)
private struct OnboardingProfileImageView: View {
    let data: Data?
    let size: CGFloat
    
    var body: some View {
        Group {
            if let data = data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundColor(.white.opacity(0.5))
                    )
            }
        }
    }
}

struct OnboardingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("appleUserID") private var appleUserID: String = ""
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("currentProfileID") private var currentProfileID: String = ""
    @AppStorage("isFirstLaunch") private var isFirstLaunch: Bool = true

    enum Step { case signIn, name, username, photo, finish }
    @State private var step: Step = .signIn

    // Temp profile fields
    @State private var name: String = ""
    @State private var username: String = "user_\(Int.random(in: 100...999))"
    @State private var imageData: Data?
    @State private var selectedItem: PhotosPickerItem?
    @State private var showGoogleNote: Bool = false

    @State private var isSaving: Bool = false
    @State private var saveErrorMessage: String?
    @State private var showSaveError: Bool = false

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedUsername: String { username.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isNameValid: Bool { !trimmedName.isEmpty }
    private var isUsernameValid: Bool {
        let pattern = "^[A-Za-z0-9._-]{4,24}$"
        return trimmedUsername.range(of: pattern, options: .regularExpression) != nil
    }

    private var usernameValidationMessage: String? {
        if trimmedUsername.isEmpty { return "ユーザー名を入力してください" }
        let pattern = "^[A-Za-z0-9._-]{4,24}$"
        if trimmedUsername.range(of: pattern, options: .regularExpression) == nil {
            return "ユーザー名は英数字と .-_ のみ、4〜24文字で入力してください"
        }
        return nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                switch step {
                case .signIn:
                    SignInStep(
                        onApple: handleAppleSignIn,
                        onGoogle: { showGoogleNote = true }
                    )
                case .name:
                    NameStep(name: $name, isValid: isNameValid, onNext: { step = .username }, onBack: { step = .signIn })
                case .username:
                    UsernameStep(username: $username, isValid: isUsernameValid, validationMessage: usernameValidationMessage, onNext: { step = .photo }, onBack: { step = .name })
                case .photo:
                    PhotoStep(imageData: $imageData, selectedItem: $selectedItem, onNext: { step = .finish }, onBack: { step = .username })
                case .finish:
                    FinishStep(name: trimmedName, username: trimmedUsername.lowercased(), imageData: imageData, isSaving: isSaving, isValid: isNameValid && isUsernameValid && imageData != nil) {
                        completeOnboarding()
                    } onBack: { step = .photo }
                }

                ProgressDots(current: stepIndex(step))
                    .padding(.top, 8)
            }
            .padding()
        }
        .alert("Googleサインインについて", isPresented: $showGoogleNote) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("GoogleログインにはGoogleSignIn SDKの導入が必要です。後日対応します。まずはAppleでサインイン、またはスキップで進めてください。")
        }
        .alert("保存エラー", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "不明なエラーが発生しました")
        }
    }

    private func stepIndex(_ s: Step) -> Int { switch s { case .signIn: 0; case .name: 1; case .username: 2; case .photo: 3; case .finish: 4 } }

    private func handleAppleSignIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleSignInCoordinator { result in
            switch result {
            case .success(let userID):
                self.appleUserID = userID
                self.isLoggedIn = true
                self.step = .name
            case .failure:
                break
            }
        }
        controller.delegate = delegate
        controller.presentationContextProvider = delegate
        controller.performRequests()
    }

    private func completeOnboarding() {
        // Start saving state
        isSaving = true
        defer { isSaving = false }

        // Validate inputs
        guard isNameValid else {
            saveErrorMessage = "名前を入力してください"
            showSaveError = true
            return
        }
        guard isUsernameValid else {
            saveErrorMessage = usernameValidationMessage ?? "ユーザー名が不正です"
            showSaveError = true
            return
        }

        // Uniqueness check for username (case-insensitive)
        do {
            let all = try context.fetch(FetchDescriptor<UserProfile>())
            if all.contains(where: { $0.username.caseInsensitiveCompare(trimmedUsername) == .orderedSame }) {
                saveErrorMessage = "そのユーザー名は既に使われています"
                showSaveError = true
                return
            }
        } catch {
            saveErrorMessage = "データの読み込みに失敗しました: \(error.localizedDescription)"
            showSaveError = true
            return
        }

        // Create and save profile
        let profile = UserProfile(name: trimmedName, username: trimmedUsername.lowercased())
        profile.profileImageData = imageData
        context.insert(profile)

        do {
            try context.save()
            currentProfileID = profile.id.uuidString
            hasCompletedOnboarding = true
            isFirstLaunch = false
            dismiss()
        } catch {
            saveErrorMessage = "保存に失敗しました: \(error.localizedDescription)"
            showSaveError = true
        }
    }
}

// MARK: - Steps
struct SignInStep: View {
    var onApple: () -> Void
    var onGoogle: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("アカウントを作成/ログイン")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn, onRequest: { _ in }, onCompletion: { _ in onApple() })
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button(action: onGoogle) {
                    HStack { Image(systemName: "g.circle"); Text("Sign in with Google") }
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.white.opacity(0.1))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}

struct NameStep: View {
    @Binding var name: String
    var isValid: Bool
    var onNext: () -> Void
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("あなたの名前")
                .font(.title.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("名前を入力", text: $name)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .padding(14)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundColor(.white)
            if !isValid {
                Text("名前を入力してください")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Button("戻る", action: onBack).foregroundStyle(.secondary)
                Spacer()
                Button("次へ") { onNext() }
                    .disabled(!isValid)
            }
        }
    }
}

struct UsernameStep: View {
    @Binding var username: String
    var isValid: Bool
    var validationMessage: String?
    var onNext: () -> Void
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("ユーザー名")
                .font(.title.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("ユーザー名を入力", text: $username)
                .textInputAutocapitalization(.none)
                .disableAutocorrection(true)
                .padding(14)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundColor(.white)
            if let message = validationMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("英数字と .-_ のみ、4〜24文字")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Button("戻る", action: onBack).foregroundStyle(.secondary)
                Spacer()
                Button("次へ") { onNext() }
                    .disabled(!isValid)
            }
        }
    }
}

struct PhotoStep: View {
    @Binding var imageData: Data?
    @Binding var selectedItem: PhotosPickerItem?
    var maxPhotos: Int = 1
    var onNext: () -> Void
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("プロフィール写真")
                .font(.title.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 16) {
                OnboardingProfileImageView(data: imageData, size: 70)
                let reachedLimit = (imageData != nil) && maxPhotos <= 1
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label(reachedLimit ? "写真はロックされています" : "写真を選択", systemImage: reachedLimit ? "lock.fill" : "photo")
                        .font(.headline)
                        .padding(10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(reachedLimit)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Button("戻る", action: onBack).foregroundStyle(.secondary)
                Spacer()
                Button("次へ", action: onNext)
                    .disabled(imageData == nil)
            }
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                // If we've reached the max (1 photo), skip reloading to lock the selection
                if imageData != nil && maxPhotos <= 1 { return }
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    await MainActor.run { imageData = data }
                }
            }
        }
    }
}

struct FinishStep: View {
    let name: String
    let username: String
    let imageData: Data?
    var isSaving: Bool
    var isValid: Bool
    var onFinish: () -> Void
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("この内容で作成します")
                .font(.title.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 12) {
                OnboardingProfileImageView(data: imageData, size: 60)
                VStack(alignment: .leading) {
                    Text(name.isEmpty ? "名称未設定" : name)
                        .foregroundStyle(.white)
                        .font(.headline)
                    Text("@\(username)")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            HStack {
                Button("戻る", action: onBack).foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .tint(.green)
                    }
                    Button("作成") { onFinish() }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(isSaving || !isValid)
                }
            }
        }
    }
}

struct ProgressDots: View {
    var total: Int = 5
    var current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.green : Color.white.opacity(0.25))
                    .frame(width: index == current ? 10 : 8, height: index == current ? 10 : 8)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: index == current ? 0 : 1)
                    )
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("Step \(current + 1) of \(total)")
    }
}

struct OnboardingGateView<Content: View>: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    let content: () -> Content

    var body: some View {
        content()
            .fullScreenCover(isPresented: Binding(get: { !hasCompletedOnboarding }, set: { _ in })) {
                OnboardingFlowView()
            }
    }
}

// MARK: - Helpers
final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let completion: (Result<String, Error>) -> Void
    init(completion: @escaping (Result<String, Error>) -> Void) { self.completion = completion }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor { 
        // Find the active window scene
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            // Return an existing key window if available
            if let key = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return key
            }
            // Create a window anchored to this scene
            return UIWindow(windowScene: windowScene)
        }
        
        // Fallback: pick any available windowScene
        if let anyScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            if let key = anyScene.windows.first(where: { $0.isKeyWindow }) {
                return key
            }
            return UIWindow(windowScene: anyScene)
        }
        
        // Try to find any existing window from any scene
        if let anyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first {
            return anyWindow
        }
        
        // Last resort: this should not normally happen
        fatalError("No window scene available for presentation anchor")
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            completion(.success(credential.user))
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) { completion(.failure(error)) }
}

#Preview {
    OnboardingFlowView()
}

