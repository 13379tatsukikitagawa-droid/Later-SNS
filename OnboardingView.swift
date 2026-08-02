import SwiftUI
import PhotosUI
import SwiftData
import Foundation

/// モダンで洗練されたプロフィール登録画面
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    
    // 🎯 共通の@AppStorageキー（ProfileViewと完全に同期）
    @AppStorage("isSetupCompleted") private var isSetupCompleted: Bool = false
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("userBio") private var userBio: String = ""
    @AppStorage("profileImageData") private var profileImageData: Data?
    
    // レガシー対応（既存のキー）
    @AppStorage("currentProfileID") private var currentProfileID: String = ""
    @AppStorage("isProfileSetupCompleted") private var isProfileSetupCompleted: Bool = false
    @AppStorage("appleUserID") private var appleUserID: String = ""
    @AppStorage("appleFullName") private var appleFullName: String = ""
    
    // 入力用の一時State
    @State private var inputName: String = ""
    @State private var inputUserID: String = ""
    @State private var inputBio: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var inputImageData: Data?
    
    // UI状態
    @State private var isSaving: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    // アニメーション用
    @State private var isNameFocused: Bool = false
    @State private var isUserIDFocused: Bool = false
    @State private var isBioFocused: Bool = false
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    // バリデーション
    private var isFormValid: Bool {
        let trimmedName = inputName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUserID = inputUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBio = inputBio.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return !trimmedName.isEmpty 
            && trimmedName.count >= 2
            && !trimmedUserID.isEmpty
            && trimmedUserID.count >= 3
            && isValidUserID(trimmedUserID)
            && !trimmedBio.isEmpty
            && inputImageData != nil
    }
    
    private func isValidUserID(_ id: String) -> Bool {
        let pattern = "^[a-zA-Z0-9_]+$"
        return id.range(of: pattern, options: .regularExpression) != nil
    }
    
    var body: some View {
        ZStack {
            enhancedBackgroundGradient
            
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    mainContentSection
                    Spacer(minLength: 100)
                }
            }
            
            VStack {
                Spacer()
                completeButtonSection
            }
        }
        .alert("エラー", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            inputImageData = data
                        }
                    }
                }
            }
        }
        .onAppear {
            // 既存のデータがあれば読み込む
            if !userName.isEmpty {
                inputName = userName
            } else if !appleFullName.isEmpty {
                // Sign in with Appleで取得した氏名を初期値にする
                inputName = appleFullName
            }
            if !userID.isEmpty {
                inputUserID = userID
            }
            if !userBio.isEmpty {
                inputBio = userBio
            }
            if let imageData = profileImageData {
                inputImageData = imageData
            }
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
    
    // MARK: - View Components
    
    private var enhancedBackgroundGradient: some View {
        ZStack {
            // ベースグラデーション
            LinearGradient(
                colors: [
                    Color.brandBlack,
                    Color.brandBlack.opacity(0.95),
                    Color.brandGreen.opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // アクセントグラデーション（ワクワク感演出）
            RadialGradient(
                colors: [
                    Color.brandGreen.opacity(0.2),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 600
            )
            
            RadialGradient(
                colors: [
                    Color.blue.opacity(0.15),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 500
            )
        }
        .ignoresSafeArea()
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("ようこそ")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("あなたのプロフィールを作成しましょう")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
        .padding(.bottom, 60)
        .scaleEffect(scale)
        .opacity(opacity)
    }
    
    private var mainContentSection: some View {
        VStack(spacing: 28) {
            profileImageSection
            
            VStack(spacing: 20) {
                userNameInputSection
                userIDInputSection
                bioInputSection
            }
        }
        .scaleEffect(scale)
        .opacity(opacity)
    }
    
    private var profileImageSection: some View {
        VStack(spacing: 20) {
            ZStack {
                profileImageBackground
                profileImageView
                profileImageEditButton
            }
            
            Text(inputImageData == nil ? "写真を追加" : "写真を変更")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    private var profileImageBackground: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.brandGreen.opacity(0.3),
                        Color.brandGreen.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 140, height: 140)
            .blur(radius: 20)
    }
    
    @ViewBuilder
    private var profileImageView: some View {
        if let imageData = inputImageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 130, height: 130)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.brandGreen, .brandGreen.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                )
                .shadow(color: .brandGreen.opacity(0.3), radius: 20, x: 0, y: 10)
        } else {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 130, height: 130)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.3))
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            Color.white.opacity(0.2),
                            style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                        )
                )
        }
    }
    
    private var profileImageEditButton: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            ZStack {
                Circle()
                    .fill(Color.brandGreen)
                    .frame(width: 40, height: 40)
                    .shadow(color: .brandGreen.opacity(0.5), radius: 8, x: 0, y: 4)
                
                Image(systemName: inputImageData == nil ? "camera.fill" : "pencil")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .offset(x: 45, y: 45)
    }
    
    private var userNameInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("名前（表示名）")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .padding(.leading, 4)
            
            userNameTextField
            
            if !inputName.isEmpty && inputName.count < 2 {
                validationError(message: "名前は2文字以上で入力してください")
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var userIDInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ユーザーID（@ID）")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .padding(.leading, 4)
            
            userIDTextField
            
            if !inputUserID.isEmpty && (inputUserID.count < 3 || !isValidUserID(inputUserID)) {
                validationError(message: "3文字以上の英数字・アンダースコアのみ使用可能")
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var bioInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("一言バイオ（自己紹介）")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .padding(.leading, 4)
            
            bioTextField
        }
        .padding(.horizontal, 24)
    }
    
    private var userNameTextField: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.brandGreen)
            
            TextField("例: 山田太郎", text: $inputName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .submitLabel(.next)
                .onChange(of: inputName) { oldValue, newValue in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isNameFocused = true
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isNameFocused ? Color.brandGreen.opacity(0.5) : Color.white.opacity(0.1),
                            lineWidth: 1.5
                        )
                )
        )
    }
    
    private var userIDTextField: some View {
        HStack(spacing: 12) {
            Text("@")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.brandGreen)
            
            TextField("例: yamada_taro", text: $inputUserID)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .keyboardType(.asciiCapable)
                .submitLabel(.next)
                .onChange(of: inputUserID) { oldValue, newValue in
                    // 英数字とアンダースコアのみ許可
                    inputUserID = newValue.filter { $0.isLetter || $0.isNumber || $0 == "_" }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isUserIDFocused = true
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isUserIDFocused ? Color.brandGreen.opacity(0.5) : Color.white.opacity(0.1),
                            lineWidth: 1.5
                        )
                )
        )
    }
    
    private var bioTextField: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "text.quote")
                .font(.system(size: 20))
                .foregroundColor(.brandGreen)
                .padding(.top, 2)
            
            TextField("今の気分は？", text: $inputBio, axis: .vertical)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(3...5)
                .submitLabel(.done)
                .onChange(of: inputBio) { oldValue, newValue in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isBioFocused = true
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isBioFocused ? Color.brandGreen.opacity(0.5) : Color.white.opacity(0.1),
                            lineWidth: 1.5
                        )
                )
        )
    }
    
    private func validationError(message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
            Text(message)
                .font(.system(size: 12))
        }
        .foregroundColor(.red.opacity(0.8))
        .padding(.leading, 4)
        .transition(.scale.combined(with: .opacity))
    }
    
    private var completeButtonSection: some View {
        VStack(spacing: 16) {
            completeButton
            
            Text("後で変更することもできます")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .scaleEffect(scale)
        .opacity(opacity)
    }
    
    private var completeButton: some View {
        Button {
            completeSetup()
        } label: {
            completeButtonLabel
        }
        .disabled(!isFormValid || isSaving)
        .scaleEffect(isFormValid ? 1.0 : 0.98)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFormValid)
    }
    
    private var completeButtonLabel: some View {
        HStack(spacing: 10) {
            if isSaving {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.9)
            }
            
            Text(isSaving ? "保存中..." : "完了")
                .font(.system(size: 18, weight: .bold))
            
            if !isSaving {
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(completeButtonBackground)
        .foregroundColor(isFormValid && !isSaving ? .white : .white.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(
            color: isFormValid && !isSaving ? Color.brandGreen.opacity(0.4) : .clear,
            radius: 20,
            x: 0,
            y: 10
        )
    }
    
    @ViewBuilder
    private var completeButtonBackground: some View {
        if isFormValid && !isSaving {
            LinearGradient(
                colors: [.brandGreen, .brandGreen.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.white.opacity(0.1)
        }
    }
    
    // MARK: - Helper Methods
    
    private func completeSetup() {
        guard isFormValid else { return }
        
        // 🎉 Hapticフィードバック（成功の振動）
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        let trimmedName = inputName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUserID = inputUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBio = inputBio.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedName.count >= 2 else {
            errorMessage = "名前は2文字以上で入力してください"
            showError = true
            return
        }
        
        guard trimmedUserID.count >= 3 && isValidUserID(trimmedUserID) else {
            errorMessage = "ユーザーIDは3文字以上の英数字・アンダースコアのみ使用できます"
            showError = true
            return
        }
        
        isSaving = true
        
        // 🎯 @AppStorageに保存（ProfileViewと自動同期）
        userName = trimmedName
        userID = trimmedUserID
        userBio = trimmedBio
        profileImageData = inputImageData
        
        // レガシーサポート: SwiftDataにも保存
        saveToSwiftData(name: trimmedName, username: trimmedUserID, bio: trimmedBio, imageData: inputImageData)
        
        // 少し待機してから完了
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 🎊 成功のHaptic
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
            
            // アニメーション付きで完了
            withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                isProfileSetupCompleted = true
                isSetupCompleted = true
            }
            
            isSaving = false
        }
    }
    
    private func saveToSwiftData(name: String, username: String, bio: String, imageData: Data?) {
        let profile: UserProfile

        if let existingID = UUID(uuidString: currentProfileID) {
            let descriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate<UserProfile> { userProfile in
                    userProfile.id == existingID
                }
            )

            if let existingProfile = try? context.fetch(descriptor).first {
                profile = existingProfile
            } else {
                profile = UserProfile(name: name, username: username)
                context.insert(profile)
            }
        } else {
            profile = UserProfile(name: name, username: username)
            context.insert(profile)
        }

        profile.name = name
        profile.username = username
        profile.bio = bio
        profile.profileImageData = imageData
        if !appleUserID.isEmpty {
            profile.appleUserID = appleUserID
        }

        do {
            try context.save()
            currentProfileID = profile.id.uuidString
        } catch {
            print("❌ SwiftData保存エラー: \(error)")
        }
    }
}

#Preview {
    // Preview without SwiftData dependency
    // If you need SwiftData preview, uncomment and ensure UserProfile is in scope
    OnboardingView()
    
    /*
    // SwiftData preview version:
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, configurations: config)
    OnboardingView()
        .modelContainer(container)
    */
}

