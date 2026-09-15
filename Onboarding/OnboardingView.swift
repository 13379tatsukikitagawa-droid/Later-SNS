import SwiftUI
import SwiftData
import Foundation

/// プロフィール設定を2ステップのウィザード形式で行う画面。
/// ステップ1: ペルソナ確認(名前・アイコンをランダム割り当て、シャッフル可) →
/// ステップ2: ウェルカム(完了)。
///
/// 2026/9: 匿名性・ルッキズム対策のため、実名・実写を入力させる旧フロー
/// (名前自由入力+ユーザーID+アバター写真アップロード)を廃止した。ログインは
/// 実アカウント(Apple ID)で行うが、Later内で使う名前・アイコンはPersonaGeneratorが
/// 割り当てるLater内だけの別人格になる。保存先(@AppStorage/SwiftData)や
/// 公開ディレクトリへの発行ロジックは、以前の単一画面版からそのまま踏襲している。
struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    // 🎯 共通の@AppStorageキー(MyPageViewと完全に同期)
    @AppStorage("isSetupCompleted") private var isSetupCompleted: Bool = false
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("userBio") private var userBio: String = ""

    // レガシー対応(既存のキー)
    @AppStorage("currentProfileID") private var currentProfileID: String = ""
    @AppStorage("isProfileSetupCompleted") private var isProfileSetupCompleted: Bool = false
    @AppStorage("appleUserID") private var appleUserID: String = ""
    @AppStorage("appleFullName") private var appleFullName: String = ""
    @AppStorageData("profileImageData") private var profileImageData: Data?

    /// この端末で今回のオンボーディング中に割り当てられたペルソナ。
    @State private var persona: PersonaGenerator.Persona = PersonaGenerator.generate()
    @State private var personaIconData: Data?

    // ウィザードの進行状態
    private enum Step: Int, CaseIterable {
        case persona, welcome
    }
    @State private var step: Step = .persona

    // UI状態
    @State private var isSaving: Bool = false

    private static let accentGreen = Color.brandGreen

    var body: some View {
        ZStack {
            enhancedBackgroundGradient

            VStack(spacing: 0) {
                header

                Spacer(minLength: 0)

                Group {
                    switch step {
                    case .persona:
                        personaStep
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
            // 既に割り当て済みのペルソナがあれば(編集し直しの場合など)そのまま使う。
            if !userName.isEmpty, !userID.isEmpty {
                persona = PersonaGenerator.Persona(
                    name: userName,
                    shortID: "@\(userID)",
                    iconSymbol: persona.iconSymbol,
                    iconColor: persona.iconColor
                )
                personaIconData = profileImageData
            } else {
                regenerateIcon()
            }
        }
    }

    private func regenerateIcon() {
        personaIconData = PersonaGenerator.renderIconImageData(for: persona)
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
            if step != .persona {
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

    // MARK: - ステップ1: ペルソナ確認

    private var personaStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(spacing: 16) {
                ZStack {
                    if let personaIconData, let uiImage = UIImage(data: personaIconData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        persona.iconColor
                        Image(systemName: persona.iconSymbol)
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Self.accentGreen.opacity(0.4), lineWidth: 1.5))
                .shadow(color: Self.accentGreen.opacity(0.25), radius: 16, x: 0, y: 6)

                VStack(spacing: 4) {
                    Text(persona.name)
                        .font(.custom("Caveat-Bold", size: 30))
                        .foregroundStyle(.white)
                    Text(persona.shortID)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Button {
                    HapticsManager.tick()
                    persona = PersonaGenerator.generate()
                    regenerateIcon()
                } label: {
                    Label("シャッフルする", systemImage: "shuffle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                Text("これがあなたのペルソナです")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)

                Text("実際のあなたとは別の、Laterの中だけの名前とアイコンです。\nグループのメンバーにはこの名前で表示されます。")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer(minLength: 0)

            nextButton(isEnabled: true) {
                goToNextStepIfPossible()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
    }

    // MARK: - ステップ2: ウェルカム(完了)

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
        case .persona:
            HapticsManager.tick()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                step = .welcome
            }
        case .welcome:
            break
        }
    }

    private func goToPreviousStep() {
        HapticsManager.swipeFeedback()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            switch step {
            case .persona: break
            case .welcome: step = .persona
            }
        }
    }

    // MARK: - Helper Methods

    private func completeSetup() {
        // 🎉 成功のHaptic
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        isSaving = true

        let name = persona.name
        let username = String(persona.shortID.dropFirst()) // "@"を取り除く
        let iconData = personaIconData ?? PersonaGenerator.renderIconImageData(for: persona)

        // 🎯 @AppStorageに保存(MyPageViewと自動同期)
        userName = name
        userID = username
        profileImageData = iconData

        // レガシーサポート: SwiftDataにも保存
        saveToSwiftData(name: name, username: username, bio: "", imageData: iconData)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)

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
