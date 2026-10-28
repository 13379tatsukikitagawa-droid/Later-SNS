import SwiftUI
import SwiftData
import PhotosUI
import Foundation

/// プロフィール設定を3ステップのウィザード形式で行う画面。
/// ステップ1: 名前 → ステップ2: ユーザーID+自由記入(任意) → ステップ3: ウェルカム(完了)。
/// 保存先(@AppStorage/SwiftData)や公開ディレクトリへの発行ロジックは、以前の単一画面版から
/// そのまま踏襲している(写真設定だけは、この3ステップの仕様に含まれないため、
/// オンボーディングの必須項目からは外し、後からProfileView側で設定できるようにした)。
struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    // 🎯 共通の@AppStorageキー(ProfileViewと完全に同期)
    @AppStorage("isSetupCompleted") private var isSetupCompleted: Bool = false
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("userBio") private var userBio: String = ""

    // レガシー対応(既存のキー)
    @AppStorage("currentProfileID") private var currentProfileID: String = ""
    @AppStorage("isProfileSetupCompleted") private var isProfileSetupCompleted: Bool = false
    @AppStorage("appleUserID") private var appleUserID: String = ""
    @AppStorage("appleFullName") private var appleFullName: String = ""

    // 入力用の一時State(ステップをまたいで保持する)
    @State private var inputName: String = ""
    @State private var inputUserID: String = ""
    @State private var inputBio: String = ""
    @AppStorageData("profileImageData") private var profileImageData: Data?
    @State private var inputImageData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?

    // ウィザードの進行状態
    private enum Step: Int, CaseIterable {
        case name, userID, welcome
    }
    @State private var step: Step = .name

    private enum Field {
        case name, userID, bio
    }
    @FocusState private var focusedField: Field?

    // UI状態
    @State private var isSaving: Bool = false

    private static let accentGreen = Color.brandGreen

    // MARK: - バリデーション

    private var trimmedName: String {
        inputName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedUserID: String {
        inputUserID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isNameStepValid: Bool {
        !trimmedName.isEmpty
    }

    private var isUserIDStepValid: Bool {
        trimmedUserID.count >= 3 && isValidUserID(trimmedUserID)
    }

    private func isValidUserID(_ id: String) -> Bool {
        let pattern = "^[a-zA-Z0-9_]+$"
        return id.range(of: pattern, options: .regularExpression) != nil
    }

    var body: some View {
        ZStack {
            enhancedBackgroundGradient

            VStack(spacing: 0) {
                header

                Spacer(minLength: 0)

                Group {
                    switch step {
                    case .name:
                        nameStep
                    case .userID:
                        userIDStep
                    case .welcome:
                        welcomeStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            // 既存のデータがあれば読み込む(編集し直しの場合など)
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
            if let profileImageData {
                inputImageData = profileImageData
            }
            focusedField = .name
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    // プロフィール画像は選び直した瞬間にだけ発生する一回きりの操作のため、
                    // ここで焼き込んでおく(表示のたびに毎回加工していた以前の設計を統一する)。
                    let baked = await ChekiColorGrade.bakedData(from: data) ?? data
                    await MainActor.run {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            inputImageData = baked
                        }
                    }
                }
            }
        }
    }

    // MARK: - 背景

    private var enhancedBackgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.brandBlack,
                    Color.brandBlack.opacity(0.95),
                    Self.accentGreen.opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Self.accentGreen.opacity(0.2), Color.clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 600
            )
            .blur(radius: 30)

            RadialGradient(
                colors: [Color.blue.opacity(0.15), Color.clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 500
            )
            .blur(radius: 30)
        }
        .ignoresSafeArea()
    }

    // MARK: - ヘッダー(戻るボタン + ステップインジケーター)

    private var header: some View {
        HStack {
            if step != .name {
                Button {
                    goToPreviousStep()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
            } else {
                Color.clear.frame(width: 36, height: 36)
            }

            Spacer()

            if step != .welcome {
                stepIndicator
            }

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases.dropLast(), id: \.self) { indicatorStep in
                Capsule()
                    .fill(indicatorStep.rawValue <= step.rawValue ? Self.accentGreen : Color.white.opacity(0.15))
                    .frame(width: indicatorStep == step ? 22 : 8, height: 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: step)
            }
        }
    }

    // MARK: - ステップ1: 名前

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            avatarPicker
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                Text("名前を教えてください")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)

                Text("グループのメンバーに表示される名前です")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            stepTextField(
                icon: "person.circle.fill",
                placeholder: "例: 山田太郎",
                text: $inputName,
                prefix: nil,
                autocapitalization: .words,
                isFocused: focusedField == .name
            )
            .focused($focusedField, equals: .name)
            .submitLabel(.next)
            .onSubmit { goToNextStepIfPossible() }

            Spacer(minLength: 0)

            nextButton(isEnabled: isNameStepValid) {
                goToNextStepIfPossible()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
    }

    // MARK: - アバターアイコン設定(ステップ1のタイトル直上)

    private var avatarPicker: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                avatarImageContent
                    .frame(width: 84, height: 84)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(Self.accentGreen.opacity(0.4), lineWidth: 1.5)
                    )
                    .shadow(color: Self.accentGreen.opacity(0.25), radius: 16, x: 0, y: 6)

                ZStack {
                    Circle()
                        .fill(Self.accentGreen)
                        .frame(width: 28, height: 28)
                        .shadow(color: Self.accentGreen.opacity(0.5), radius: 6, x: 0, y: 2)

                    Image(systemName: inputImageData == nil ? "plus" : "camera.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                }
                .offset(x: 4, y: 4)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var avatarImageContent: some View {
        if let inputImageData, let uiImage = UIImage(data: inputImageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Circle().fill(Color.white.opacity(0.08))
                Image(systemName: "person.fill")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    // MARK: - ステップ2: ユーザーID + 自由記入(任意)

    private var userIDStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 10) {
                Text("ユーザーIDを設定してください")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)

                Text("英数字とアンダースコアのみ、3文字以上")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 8) {
                stepTextField(
                    icon: nil,
                    placeholder: "例: yamada_taro",
                    text: $inputUserID,
                    prefix: "@",
                    autocapitalization: .never,
                    isFocused: focusedField == .userID,
                    keyboardType: .asciiCapable
                )
                .focused($focusedField, equals: .userID)
                .submitLabel(.next)
                .onChange(of: inputUserID) { _, newValue in
                    inputUserID = newValue.filter { $0.isLetter || $0.isNumber || $0 == "_" }
                }
                .onSubmit { focusedField = .bio }

                if !inputUserID.isEmpty && !isUserIDStepValid {
                    Text("3文字以上の英数字・アンダースコアのみ使用可能です")
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(.leading, 4)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("自由記入")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.leading, 4)

                bioTextField
            }

            Spacer(minLength: 0)

            nextButton(isEnabled: isUserIDStepValid) {
                goToNextStepIfPossible()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
    }

    private var bioTextField: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "text.quote")
                .font(.system(size: 20))
                .foregroundStyle(Self.accentGreen)
                .padding(.top, 2)

            TextField("自由に書いてください(任意)", text: $inputBio, axis: .vertical)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(3...5)
                .submitLabel(.done)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            focusedField == .bio ? Self.accentGreen.opacity(0.5) : Color.white.opacity(0.1),
                            lineWidth: 1.5
                        )
                )
        )
        .focused($focusedField, equals: .bio)
    }

    // MARK: - ステップ3: ウェルカム(完了)

    private var welcomeStep: some View {
        VStack(spacing: 36) {
            Spacer(minLength: 0)

            ApertureLogoView(tint: Self.accentGreen, wordmarkColor: Self.accentGreen, wordmarkWeight: .heavy)

            Text("Laterへようこそ")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            nextButton(isEnabled: !isSaving, title: isSaving ? "保存中…" : "Laterをはじめる") {
                completeSetup()
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 共通パーツ

    private func stepTextField(
        icon: String?,
        placeholder: String,
        text: Binding<String>,
        prefix: String?,
        autocapitalization: TextInputAutocapitalization,
        isFocused: Bool,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Self.accentGreen)
            } else if let prefix {
                Text(prefix)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Self.accentGreen)
            }

            TextField(placeholder, text: text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .textInputAutocapitalization(autocapitalization)
                .disableAutocorrection(true)
                .keyboardType(keyboardType)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isFocused ? Self.accentGreen.opacity(0.5) : Color.white.opacity(0.1),
                            lineWidth: 1.5
                        )
                )
        )
    }

    private func nextButton(isEnabled: Bool, title: String = "次へ", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isSaving && title != "次へ" {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                }
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                if !isSaving {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Group {
                    if isEnabled {
                        LinearGradient(
                            colors: [Self.accentGreen, Self.accentGreen.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color.white.opacity(0.1)
                    }
                }
            )
            .foregroundStyle(isEnabled ? .white : .white.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(
                color: isEnabled ? Self.accentGreen.opacity(0.4) : .clear,
                radius: 20, x: 0, y: 10
            )
        }
        .disabled(!isEnabled)
    }

    // MARK: - ステップ遷移

    private func goToNextStepIfPossible() {
        switch step {
        case .name:
            guard isNameStepValid else { return }
            HapticsManager.tick()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                step = .userID
            }
            focusedField = .userID
        case .userID:
            guard isUserIDStepValid else { return }
            HapticsManager.tick()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                step = .welcome
            }
            focusedField = nil
        case .welcome:
            break
        }
    }

    private func goToPreviousStep() {
        HapticsManager.swipeFeedback()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            switch step {
            case .name: break
            case .userID: step = .name
            case .welcome: step = .userID
            }
        }
    }

    // MARK: - Helper Methods

    private func completeSetup() {
        guard isNameStepValid, isUserIDStepValid else { return }

        // 🎉 成功のHaptic
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurredIfEnabled()

        let bio = inputBio.trimmingCharacters(in: .whitespacesAndNewlines)

        isSaving = true

        // 🎯 @AppStorageに保存(ProfileViewと自動同期)
        userName = trimmedName
        userID = trimmedUserID
        userBio = bio
        profileImageData = inputImageData

        // レガシーサポート: SwiftDataにも保存
        saveToSwiftData(name: trimmedName, username: trimmedUserID, bio: bio, imageData: inputImageData)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurredIfEnabled(.success)

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
        profile.profileUpdatedAt = Date()
        if !appleUserID.isEmpty {
            profile.appleUserID = appleUserID
        }

        LaterGroup.ensurePersonalSpace(for: profile, context: context)

        do {
            try context.save()
            currentProfileID = profile.id.uuidString
            // 不特定の相手にプロフィール共有(laterapp://リンク/QR)された時に
            // ユーザー名・アイコンを引けるよう、公開ディレクトリにも発行しておく。
            Task { await UserDirectoryService.publish(profile) }
        } catch {
            print("❌ SwiftData保存エラー: \(error)")
        }
    }
}

#Preview {
    OnboardingView()
}
