import SwiftUI
import SwiftData
import AuthenticationServices
import AVFoundation

/// 初回設定(オンボーディング)。Opal風の「会話が流れる」体験として、質問に答えるうちに設定が進み、
/// 最後の長押しでHomeへ入る。新規ユーザーだけが通る(既存ユーザーはisSetupCompletedでスキップ)。
///
/// 全画面が同じ型:上に真珠の玉(まわりの8つの点が進み具合)、前の文がぼやけて上に残り、
/// 今の文がタイプライターで現れ、打ち終わってからボタンが浮かび上がる。場面は「パシャ」
/// (シャッター幕が閉じる → フラッシュ → 開く)で切り替わる。
struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    @AppStorage(OnboardingStorage.stepKey) private var savedStep: String = ""
    @AppStorage(OnboardingStorage.completedKey) private var onboardingCompleted = false
    @AppStorage("isSetupCompleted") private var isSetupCompleted = false
    @AppStorage("isProfileSetupCompleted") private var isProfileSetupCompleted = false
    @AppStorage("hasSeenWelcomeOnboarding") private var hasSeenWelcomeOnboarding = false
    @AppStorage("hasCompletedSurvey") private var hasCompletedSurvey = false
    @AppStorage("hasSeenAboutLaterIntro") private var hasSeenAboutLaterIntro = false
    @AppStorage("appleUserID") private var appleUserID: String = ""
    @AppStorage("firebaseUID") private var firebaseUID: String = ""
    @AppStorage("firebaseEmail") private var firebaseEmail: String = ""
    @AppStorage("currentProfileID") private var currentProfileID: String = ""
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userID") private var userID: String = ""

    @Query private var profiles: [UserProfile]

    @ScaledMetric(relativeTo: .title2) private var typeScale: CGFloat = 1

    // 場面と文
    @State private var step: OnboardingStep = .meet
    @State private var hasStarted = false
    @State private var isOpening = false
    @State private var openingStart = Date()
    @State private var history: [OnboardingLine]?
    @State private var schedule = TypewriterSchedule(text: "", reduceMotion: false)
    @State private var typingStart = Date()
    @State private var isTypingDone = false
    @State private var isTypingSkipped = false
    @State private var areActionsVisible = false
    @State private var typingTask: Task<Void, Never>?

    // 玉・光
    @State private var isOrbVisible = false
    @State private var litOverride: Int?
    @State private var pulseTrigger = 0

    // パシャ
    @State private var isTransitioning = false
    @State private var isCurtainClosed = false
    @State private var flashOpacity = 0.0

    // 触覚・長押し
    @State private var haptics = ExposureHaptics()
    @State private var holdModel = OnboardingHoldModel()

    // 名前
    @State private var nameInput = ""
    @FocusState private var isNameFocused: Bool
    @State private var confirmedName = ""

    // タグ
    @State private var selectedTags: [String] = []

    // 5-1の答え(保存しない)
    @State private var retakeAnswer: RetakeAnswer?

    // アカウント
    @State private var signInError: String?
    @State private var isCheckingAccount = false

    // メールで続ける
    @State private var emailInput = ""
    @FocusState private var isEmailFocused: Bool
    @State private var isEmailErrorShown = false
    @State private var hasShownEmailError = false
    @State private var emailShake = 0
    @State private var emailErrorTask: Task<Void, Never>?
    @State private var emailFailure: EmailSignInFailure = .network
    @State private var sendingAttempt = 0
    @State private var resendRemaining = 0
    @State private var resendTask: Task<Void, Never>?
    @State private var sentAddress = ""

    // プロフィール撮影
    @StateObject private var camera = FilmCameraController()
    @State private var cameraPosition: AVCaptureDevicePositionValue = .back
    @State private var photoNotice: (title: String, message: String)?

    private var scene: OnboardingScene { step.scene(name: confirmedName, emailFailure: emailFailure, retakes: retakeAnswer) }
    /// 玉を0.6倍に縮めて上へ寄せる(キーボードが出る入力の場面)
    private var isCompactOrb: Bool { isNameEditing || step == .emailInput }
    private var primaryTextColor: Color { step.isQuiet ? OnboardingPalette.quietText : OnboardingPalette.text }
    private var showsEverything: Bool { voiceOverEnabled || isTypingSkipped || isTypingDone }
    private var isNameEditing: Bool { step == .name && isNameFocused }
    private var fontScale: CGFloat { min(typeScale, 1.15) }

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                let metrics = OnboardingMetrics(size: proxy.size)
                ZStack(alignment: .topLeading) {
                    OnboardingPalette.background
                    orbLayer(metrics)
                    historyLayer(metrics)
                    visualLayer(metrics)
                    textLayer(metrics)
                    if isOpening {
                        OnboardingOpeningView(start: openingStart, metrics: metrics)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                // 画面をタップしてタイプ演出を飛ばすのは、文と玉の層だけにする。
                // 以前は画面全体(ボタンの層を含む)に付けていたため、中身がUIKitの
                // SignInWithAppleButtonまでタップが届かず、「Appleで続ける」が押せなかった。
                .contentShape(Rectangle())
                .onTapGesture { skipTyping() }
            }
            .ignoresSafeArea()

            actionsLayer
                .padding(.horizontal, 28)
                .padding(.bottom, 16)
                .frame(maxHeight: .infinity, alignment: .bottom)

            FilmGrainOverlay(opacity: 0.05, blendMode: .normal)
                .ignoresSafeArea()

            curtains
                .ignoresSafeArea()

            if let photoNotice {
                ZStack {
                    Color.black
                    ExposedNoticeView(title: photoNotice.title, message: photoNotice.message)
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear(perform: startIfNeeded)
        .onChange(of: appleUserID) { _, _ in handleSignInChange() }
        .onChange(of: firebaseUID) { _, _ in handleSignInChange() }
        .onChange(of: step) { _, newStep in
            if newStep == .profilePhoto {
                camera.configure()
            } else {
                camera.stopSession()
            }
        }
        .overlay(alignment: .topLeading) { emailBackButton }
        .onReceive(NotificationCenter.default.publisher(for: .emailSignInLinkOpened)) { _ in
            // メールのリンクからアプリに戻ってきた:確認中へ。
            guard step.isEmailStep || step == .account else { return }
            go(to: .emailVerifying, withHaptic: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .emailSignInLinkFailed)) { note in
            guard step.isEmailStep || step == .account else { return }
            let failure = (note.object as? Error).map { EmailSignInFailure.from($0) } ?? .missingEmail
            showEmailFailure(failure)
        }
    }

    /// 左上の「<」(メールの入力・送りました)。ひとつ前の画面に戻る。
    @ViewBuilder
    private var emailBackButton: some View {
        if step == .emailInput || step == .emailSent {
            Button {
                go(to: step == .emailInput ? .account : .emailInput, withHaptic: false)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(LinearGradient(colors: [.white.opacity(0.13), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom)))
                    .overlay(Circle().strokeBorder(.white.opacity(0.09), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.leading, 22)
            .padding(.top, 6)
            .accessibilityLabel("戻る")
            .transition(.opacity)
        }
    }

    // MARK: - 玉・背景の光

    private func orbLayer(_ metrics: OnboardingMetrics) -> some View {
        TimelineView(.animation(paused: !holdModel.isMoving)) { context in
            let progress = holdModel.progress(at: context.date)
            let isConsent = step == .lookismConsent && !isOrbVisible
            // 同意の長押し中だけ、押している間に玉と光が戻ってくる。
            let orbOpacity = isConsent ? (progress > 0 ? 0.15 + 0.85 * progress : 0) : (isOrbVisible ? 1 : 0)
            let spotOpacity = isConsent ? progress * 0.55 : (isOrbVisible ? 1 : 0)
            ZStack(alignment: .topLeading) {
                OnboardingSpotlight()
                    .opacity(spotOpacity)
                OnboardingOrb(
                    litCount: litOverride ?? step.litDots,
                    bloom: step == .finish ? progress : 0,
                    pulseTrigger: pulseTrigger,
                    isCycling: step == .emailSending && !reduceMotion
                )
                .scaleEffect(isCompactOrb ? 0.6 : 1)
                .position(x: metrics.size.width / 2, y: metrics.y(isCompactOrb ? (step == .emailInput ? 86 : 110) : OnboardingMetrics.orbCenterY))
                .opacity(orbOpacity)
            }
        }
        .animation(.easeOut(duration: 0.4), value: isCompactOrb)
    }

    // MARK: - 前の文

    @ViewBuilder
    private func historyLayer(_ metrics: OnboardingMetrics) -> some View {
        if let history, !isNameEditing {
            TypewriterText.text(history, fontSize: 27 * fontScale, primaryColor: .white.opacity(0.55))
                .lineSpacing(27 * fontScale * 0.42)
                .frame(width: metrics.size.width - 56, height: metrics.y(OnboardingMetrics.historyHeight), alignment: .bottomLeading)
                .clipped()
                .blur(radius: 5)
                .opacity(0.34)
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.55)], startPoint: .top, endPoint: .bottom))
                .offset(x: 28, y: metrics.y(OnboardingMetrics.historyTop))
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
    }

    // MARK: - 場面ごとの視覚要素(玉の下、y=262〜362)

    @ViewBuilder
    private func visualLayer(_ metrics: OnboardingMetrics) -> some View {
        Group {
            switch scene.visual {
            case .none:
                EmptyView()
            case .sealedFrame:
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.black)
                    .frame(width: 68, height: 86)
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.white.opacity(0.6), lineWidth: 0.75))
                    .overlay(Circle().fill(.white).frame(width: 5, height: 5).shadow(color: .white.opacity(0.8), radius: 4))
            case .nineAM:
                NineAMVisual()
            case .arriveRing:
                ArriveRingVisual()
            case .notificationCard:
                NotificationCardSample()
                    .padding(.horizontal, 28)
            case .verifyingRing:
                VerifyingRing()
            case .viewfinder:
                HStack(spacing: 14) {
                    CameraPreviewRepresentable(session: camera.session)
                        .frame(width: 78, height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.2), lineWidth: 1))
                        .accessibilityLabel("ファインダー")
                    Button {
                        cameraPosition = cameraPosition == .back ? .front : .back
                        camera.setCameraPosition(cameraPosition.avPosition)
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(OnboardingPalette.surface))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(cameraPosition == .back ? "前面カメラに切り替える" : "背面カメラに切り替える")
                }
                .padding(.leading, 54)
            }
        }
        .frame(width: metrics.size.width)
        .position(x: metrics.size.width / 2, y: metrics.y(OnboardingMetrics.visualCenterY))
        .opacity(isNameEditing ? 0 : 1)
    }

    // MARK: - 今の文と入力欄

    private func textLayer(_ metrics: OnboardingMetrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasStarted && !isOpening {
                TypewriterText(
                    lines: scene.lines,
                    fontSize: scene.fontSize * fontScale,
                    primaryColor: primaryTextColor,
                    schedule: schedule,
                    start: typingStart,
                    showsEverything: showsEverything
                )
                .id(step)

                if let countUp = scene.countUp {
                    RetakeCountUp(target: countUp, isRunning: isTypingDone || showsEverything)
                        .padding(.top, 6)
                }

                if let footnote = scene.footnote {
                    Text(footnote)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(OnboardingPalette.note)
                        .lineSpacing(3)
                        .padding(.top, 16)
                        .opacity(isTypingDone || showsEverything ? 1 : 0)
                }

                inputs
                    .opacity(areActionsVisible ? 1 : 0)
                    .offset(y: areActionsVisible || reduceMotion ? 0 : 10)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, metrics.y(isNameEditing ? 196 : (step == .emailInput ? 184 : OnboardingMetrics.textTop)))
        .frame(width: metrics.size.width, alignment: .leading)
        .animation(.easeOut(duration: 0.3), value: isCompactOrb)
    }

    @ViewBuilder
    private var inputs: some View {
        switch scene.actions {
        case .account:
            Text("はじめての方も、同じボタンです。")
                .font(.system(size: 12))
                .foregroundStyle(OnboardingPalette.note)
                .padding(.top, 18)
        case .nameInput:
            nameField
        case .emailInput:
            emailField
        case .emailSent:
            emailSentInfo
        case .emailFailed:
            Text(emailFailure.message)
                .font(.system(size: 14))
                .foregroundStyle(OnboardingPalette.subText)
                .lineSpacing(3)
                .padding(.top, 14)
        case .tags:
            tagChips
        case .profilePhoto:
            OnboardingFlowLayout(spacing: 8) {
                ForEach(OnboardingCopy.profilePhotoExamples, id: \.self) { example in
                    Text(example)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OnboardingPalette.subText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(OnboardingPalette.surface))
                }
            }
            .padding(.top, 18)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("例:\(OnboardingCopy.profilePhotoExamples.joined(separator: "、"))")
        default:
            EmptyView()
        }
    }

    private var nameField: some View {
        let validation = OnboardingRules.validateName(nameInput)
        return VStack(alignment: .leading, spacing: 10) {
            TextField("", text: $nameInput)
                .font(.system(size: 34, weight: .semibold))
                .tracking(-0.03 * 34)
                .foregroundStyle(.white)
                .tint(.white)
                .focused($isNameFocused)
                .submitLabel(.done)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit(confirmName)
                .accessibilityLabel("名前")
            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(height: 1)
            Text(validation.problem == .looksLikeContact
                 ? "URLやメールアドレスは使えません。"
                 : validation.problem == .tooLong
                    ? "12文字までにしてください。"
                    : "本名でなくて大丈夫です。あとから変えられます。")
                .font(.system(size: 12.5))
                .foregroundStyle(OnboardingPalette.secondaryText)
        }
        .padding(.top, 24)
    }

    private var tagChips: some View {
        SelfTagPicker(selectedTags: $selectedTags) {
            haptics.playTransient(intensity: OnboardingTuning.tagHaptic.intensity, sharpness: OnboardingTuning.tagHaptic.sharpness)
        }
        .padding(.top, 20)
    }

    // MARK: - ボタン

    @ViewBuilder
    private var actionsLayer: some View {
        Group {
            switch scene.actions {
            case .primary(let title):
                primaryButton(title) { advance() }
            case .choice(let yes, let no):
                VStack(spacing: 12) {
                    primaryButton(yes) { advance() }
                    secondaryButton(no) { advance() }
                }
            case .account:
                accountButtons
            case .nameInput:
                primaryButton("つづける", isEnabled: OnboardingRules.validateName(nameInput).problem == nil) { confirmName() }
            case .auto, .none:
                EmptyView()
            case .retakeChoice:
                retakeChoices
            case .emailInput:
                primaryButton("リンクを送る", isEnabled: isEmailValid, disabledTextColor: Color(hex: "5A5A5E")) { sendEmailLink() }
            case .emailSent:
                emailSentActions
            case .emailFailed:
                VStack(spacing: 16) {
                    primaryButton("もう一度送る") { retryAfterFailure() }
                    appleButton(style: .black)
                        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                }
            case .tags:
                VStack(spacing: 6) {
                    primaryButton("つづける", isEnabled: !selectedTags.isEmpty) { saveTagsAndAdvance() }
                    textButton("スキップ") { saveTagsAndAdvance() }
                }
            case .hold(let kind):
                holdButton(kind)
            case .profilePhoto:
                OnboardingHoldButton(
                    model: holdModel,
                    diameter: 96,
                    label: "長押しで、撮る",
                    sublabel: "プレビューなし ・ 翌朝の現像まで、あなたにも見えません",
                    accessibilityActionName: "撮る",
                    onBegin: { haptics.beginHold(duration: $0) },
                    onRelease: { haptics.cancelHold() },
                    onComplete: captureProfilePhoto
                )
                .frame(maxWidth: .infinity)
            case .notify:
                VStack(spacing: 6) {
                    primaryButton("はい") {
                        Task {
                            await DailyOpenNotification.requestAndSchedule()
                            advance()
                        }
                    }
                    textButton("あとで") { advance() }
                }
            }
        }
        .opacity(areActionsVisible ? 1 : 0)
        .offset(y: areActionsVisible || reduceMotion ? 0 : 10)
        .allowsHitTesting(areActionsVisible && !isTransitioning)
    }

    /// 5-1の選択肢。1列に並べ、タップするとそのまま次へ進む。
    private var retakeChoices: some View {
        HStack(spacing: 6) {
            ForEach(RetakeAnswer.allCases, id: \.self) { answer in
                Button {
                    retakeAnswer = answer
                    advance()
                } label: {
                    Text(answer.label)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Capsule().fill(OnboardingPalette.surface))
                }
                .buttonStyle(OnboardingPressStyle())
                .accessibilityLabel(answer == .zero ? "0回" : "\(answer.label)回")
            }
        }
    }

    private var accountButtons: some View {
        VStack(spacing: 16) {
            if isCheckingAccount {
                ProgressView()
                    .tint(.white)
                    .frame(height: 56)
                    .accessibilityLabel("アカウントを確認しています")
            } else {
                appleButton(style: .white)

                Button {
                    go(to: .emailInput)
                } label: {
                    Label("メールで続ける", systemImage: "envelope")
                        .font(.system(size: 17, weight: .semibold))
                        .tracking(-0.025 * 17)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Capsule().fill(OnboardingPalette.surface))
                }
                .buttonStyle(OnboardingPressStyle())
            }
            if let signInError {
                Text(signInError)
                    .font(.system(size: 13))
                    .foregroundStyle(OnboardingPalette.subText)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// 公式のSign in with Appleボタン(「Appleで続ける」)。高さ56pt・完全な丸み。
    /// キャンセル(1001)は何も表示しない。ほかの失敗は、静かに1行とやわらかい触覚2回。
    private func appleButton(style: SignInWithAppleButton.Style) -> some View {
        SignInWithAppleButton(.continue) { request in
            print("[AppleSignIn] onRequest: ボタンが押され、認証を要求します")
            signInError = nil
            request.requestedScopes = [.fullName]
        } onCompletion: { result in
            switch result {
            case .success:
                print("[AppleSignIn] onCompletion: 成功")
                if let message = AppleSignInView.applySignIn(result, modelContext: modelContext) {
                    print("[AppleSignIn] 結果の保存に失敗: \(message)")
                    showSignInError(OnboardingCopy.appleSignInFailed)
                }
            case .failure(let error):
                let code = (error as? ASAuthorizationError)?.code
                print("[AppleSignIn] onCompletion: 失敗 code=\(code.map { String($0.rawValue) } ?? "nil") error=\(error)")
                if code == .canceled { return }
                showSignInError(OnboardingCopy.appleSignInFailed)
            }
        }
        .signInWithAppleButtonStyle(style)
        .frame(height: 56)
        .clipShape(Capsule())
    }

    private func showSignInError(_ message: String) {
        signInError = message
        playSoftDouble()
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    /// やわらかく2回(断られた・失敗した時)
    private func playSoftDouble() {
        haptics.playTransient(intensity: 0.3, sharpness: 0.3)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            haptics.playTransient(intensity: 0.3, sharpness: 0.3)
        }
    }

    private func holdButton(_ kind: OnboardingHoldKind) -> some View {
        OnboardingHoldButton(
            model: holdModel,
            label: kind == .consent ? "長押しして、はじめる" : "長押しで、Homeへ",
            sublabel: "1.5秒",
            accessibilityActionName: kind == .consent ? "同意する" : "Homeへ進む",
            onBegin: { haptics.beginHold(duration: $0) },
            onRelease: { haptics.cancelHold() },
            onComplete: { completeHold(kind) }
        )
        .frame(maxWidth: .infinity)
    }

    private func primaryButton(_ title: String, isEnabled: Bool = true, disabledTextColor: Color = OnboardingPalette.secondaryText, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.025 * 17)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isEnabled ? .black : disabledTextColor)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Capsule().fill(isEnabled ? Color.white : OnboardingPalette.surface))
                .shadow(color: .white.opacity(isEnabled ? 0.16 : 0), radius: 14)
                .animation(.easeOut(duration: 0.25), value: isEnabled)
        }
        .buttonStyle(OnboardingPressStyle())
        .disabled(!isEnabled)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.025 * 17)
                .lineLimit(1)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Capsule().fill(OnboardingPalette.surface))
        }
        .buttonStyle(OnboardingPressStyle())
    }

    private func textButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OnboardingPalette.subText)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: - パシャ(シャッター幕・フラッシュ)

    private var curtains: some View {
        GeometryReader { proxy in
            let height = proxy.size.height * 0.51
            ZStack {
                Rectangle()
                    .fill(.black)
                    .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.28)).frame(height: 1) }
                    .frame(height: height)
                    .offset(y: isCurtainClosed ? 0 : -height - 2)
                    .frame(maxHeight: .infinity, alignment: .top)
                Rectangle()
                    .fill(.black)
                    .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.28)).frame(height: 1) }
                    .frame(height: height)
                    .offset(y: isCurtainClosed ? 0 : height + 2)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                Color.white.opacity(flashOpacity)
            }
        }
        .allowsHitTesting(isTransitioning)
        .accessibilityHidden(true)
    }

    // MARK: - 開始・再開

    private func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        haptics.prepare()
        selectedTags = UserProfile.current(from: profiles)?.selfTags ?? []
        confirmedName = UserProfile.current(from: profiles)?.name ?? userName

        if let resumed = resumeStep() {
            // 再開時は開幕を再生せず、現在の場面から続ける。
            step = resumed
            isOrbVisible = !resumed.isQuiet
            startTyping()
            if resumed == .account { handleSignInChange() }
            return
        }
        playOpening()
    }

    private func resumeStep() -> OnboardingStep? {
        // 以前のルッキズムのパート(11画面)の途中で保存されていた場合は、新しい5-1から。
        if OnboardingStep(rawValue: savedStep) == nil, savedStep.hasPrefix("lookism") {
            return .lookismRetakes
        }
        guard let saved = OnboardingStep(rawValue: savedStep) else { return nil }
        let isSignedIn = !appleUserID.isEmpty || !firebaseUID.isEmpty
        // 5-2・5-3は5-1の答えを保存しないため、5-1から。
        if saved == .lookismCount || saved == .lookismTime { return .lookismRetakes }
        if saved.isEmailStep {
            if isSignedIn { return .name }
            // メールを送ったあとに閉じた時は「送りました」から(リンクを開けば、そのまま続く)。
            if FirebaseAuthService.pendingEmail != nil {
                sentAddress = FirebaseAuthService.pendingEmail ?? ""
                return .emailSent
            }
            return .emailInput
        }
        let order = OnboardingStep.mainFlow
        // サインイン前の場面より先に保存されていても、未サインインならアカウントから。
        if !isSignedIn, let savedIndex = order.firstIndex(of: saved), let accountIndex = order.firstIndex(of: .account), savedIndex > accountIndex {
            return .account
        }
        // 名前の確定表示(自動で進む場面)の途中で閉じた時は、その次から。
        if saved == .nameConfirm { return .explainAsk }
        return saved
    }

    private func playOpening() {
        isOpening = true
        openingStart = Date()
        let reveal = OnboardingOpeningView.orbRevealTime(reduceMotion: reduceMotion)
        let duration = OnboardingOpeningView.duration(reduceMotion: reduceMotion)
        Task { @MainActor in
            if !reduceMotion {
                // 絞りが開く:ごく弱い連続(強さ0→0.3、鋭さ0.2、1.6秒で上昇)
                try? await Task.sleep(for: .seconds(1.2))
                haptics.playRamp(from: 0, to: 0.3, sharpness: 0.2, duration: 1.6)
                // 「Later」が定着:軽く1回
                try? await Task.sleep(for: .seconds(3.0))
                haptics.playTransient(intensity: OnboardingTuning.openingSettleHaptic.intensity, sharpness: OnboardingTuning.openingSettleHaptic.sharpness)
                try? await Task.sleep(for: .seconds(reveal - 4.2))
            } else {
                try? await Task.sleep(for: .seconds(reveal))
            }
            withAnimation(.easeInOut(duration: 1.2)) { isOrbVisible = true }
            try? await Task.sleep(for: .seconds(duration - reveal))
            isOpening = false
            step = .meet
            savedStep = OnboardingStep.meet.rawValue
            startTyping()
        }
    }

    // MARK: - タイプ

    private func startTyping() {
        typingTask?.cancel()
        isTypingDone = false
        isTypingSkipped = false
        areActionsVisible = false
        let text = scene.lines.map(\.text).joined()
        schedule = TypewriterSchedule(text: text, reduceMotion: reduceMotion)
        typingStart = Date()

        if voiceOverEnabled {
            finishTyping()
            return
        }
        let currentSchedule = schedule
        let start = typingStart
        let currentStep = step
        typingTask = Task { @MainActor in
            let every = OnboardingTuning.typingHapticEvery
            if every > 0, !currentStep.isQuiet, !reduceMotion {
                for (index, time) in currentSchedule.revealTimes.enumerated() where (index + 1) % every == 0 {
                    let wait = time - Date().timeIntervalSince(start)
                    if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
                    guard !Task.isCancelled else { return }
                    haptics.playTransient(intensity: OnboardingTuning.typingHaptic.intensity, sharpness: OnboardingTuning.typingHaptic.sharpness)
                }
            }
            let remaining = currentSchedule.finishTime - Date().timeIntervalSince(start)
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            guard !Task.isCancelled else { return }
            finishTyping()
        }
    }

    private func finishTyping() {
        isTypingDone = true
        withAnimation(.easeOut(duration: 0.5)) { areActionsVisible = true }
        switch scene.actions {
        case .auto(let delay):
            let currentStep = step
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                guard step == currentStep else { return }
                advance()
            }
        case .nameInput:
            isNameFocused = true
        case .emailInput:
            // 質問のタイプ演出が終わってから0.3秒後に、キーボードを自動で開く。
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if step == .emailInput { isEmailFocused = true }
            }
        default:
            break
        }
    }

    /// 画面をタップして、タイプをスキップする(ルッキズムのパートではスキップできない)。
    private func skipTyping() {
        guard !step.isQuiet, !isTypingDone, !isOpening, hasStarted else { return }
        typingTask?.cancel()
        isTypingSkipped = true
        finishTyping()
    }

    // MARK: - 次の場面へ(パシャ)

    /// - Parameter withHaptic: ボタンの触覚とシャッターの触覚は兼ねる(別々に2回鳴らさない)。
    ///   長押しが満ちた時は、満ちた時の触覚がすでに鳴っているためfalse。
    private func advance(withHaptic: Bool = true) {
        guard !isTransitioning else { return }
        guard let next = step.next else { return }
        transition(withHaptic: withHaptic) { swap(to: next) }
    }

    /// 本筋の順番によらず、指定の場面へ移る(メールの場面など)。
    private func go(to target: OnboardingStep, withHaptic: Bool = true) {
        guard !isTransitioning, target != step else { return }
        transition(withHaptic: withHaptic) { swap(to: target) }
    }

    private func transition(withHaptic: Bool, swap: @escaping () -> Void) {
        isTransitioning = true
        isNameFocused = false
        isEmailFocused = false
        if withHaptic && !step.isQuiet {
            haptics.playTransient(intensity: OnboardingTuning.shutterHaptic.intensity, sharpness: OnboardingTuning.shutterHaptic.sharpness)
        }

        if reduceMotion || voiceOverEnabled {
            withAnimation(.easeInOut(duration: 0.25)) { swap() }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.25))
                isTransitioning = false
            }
            return
        }

        withAnimation(.timingCurve(0.5, 0, 0.9, 0.4, duration: 0.13)) { isCurtainClosed = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.12))
            swap()
            withAnimation(.linear(duration: 0.037)) { flashOpacity = 0.92 }
            try? await Task.sleep(for: .seconds(0.037))
            withAnimation(.easeOut(duration: 0.42)) { flashOpacity = 0 }
            try? await Task.sleep(for: .seconds(0.033))
            withAnimation(.timingCurve(0.2, 0.7, 0.3, 1, duration: 0.23)) { isCurtainClosed = false }
            try? await Task.sleep(for: .seconds(0.24))
            isTransitioning = false
        }
    }

    private func swap(to next: OnboardingStep) {
        let previous = step
        history = scene.lines
        photoNotice = nil
        litOverride = nil
        holdModel.reset()
        step = next
        savedStep = next.rawValue

        if next.isQuiet && !previous.isQuiet {
            // ルッキズムに入る:玉・点・背景の光を消す(1.2秒)。
            withAnimation(.easeInOut(duration: 1.2)) { isOrbVisible = false }
        } else if !next.isQuiet && !isOrbVisible {
            withAnimation(.easeInOut(duration: 0.6)) { isOrbVisible = true }
        }
        if next == .nameConfirm {
            pulseTrigger += 1
        }
        startTyping()
    }

    // MARK: - アカウント

    private func handleSignInChange() {
        guard step == .account || step.isEmailStep, !appleUserID.isEmpty || !firebaseUID.isEmpty, !isCheckingAccount else { return }
        // 端末に同じアカウントのプロフィールがあれば、サインイン処理側がisSetupCompletedを立てる。
        if isSetupCompleted {
            completeAsExistingUser()
            return
        }
        isCheckingAccount = true
        Task { @MainActor in
            // 以前Laterを使っていたアカウントなら、CloudKitから自分のプロフィールが同期されてくる。
            // 少しだけ待って確認し、見つかれば初回設定を飛ばしてHomeへ。
            for _ in 0..<12 {
                if let existing = existingProfileForSignedInAccount() {
                    currentProfileID = existing.id.uuidString
                    completeAsExistingUser()
                    return
                }
                if let cloudKitManager = CloudKitManager.current {
                    await cloudKitManager.fetchPrivateChangesNow()
                    await cloudKitManager.fetchSharedChangesNow()
                }
                try? await Task.sleep(for: .seconds(0.5))
            }
            isCheckingAccount = false
            // はじめてのアカウント:パシャで、次の質問(名前)へ。
            go(to: .name)
        }
    }

    private func existingProfileForSignedInAccount() -> UserProfile? {
        let all = (try? modelContext.fetch(FetchDescriptor<UserProfile>())) ?? []
        let recordName = CloudKitManager.current?.currentUserRecordName
        return all.first { profile in
            if !appleUserID.isEmpty, profile.appleUserID == appleUserID { return true }
            if !firebaseUID.isEmpty, profile.firebaseUID == firebaseUID { return true }
            if let recordName, profile.cloudKitUserRecordName == recordName, !profile.name.isEmpty { return true }
            return false
        }
    }

    /// 既存のアカウントだった:2〜8をスキップし、既存のペルソナ名・プロフィールのままHomeへ。
    private func completeAsExistingUser() {
        markOnboardingCompleted()
    }

    // MARK: - 名前

    private func confirmName() {
        let validation = OnboardingRules.validateName(nameInput)
        guard validation.problem == nil, !isTransitioning else { return }
        let name = validation.name

        let profile: UserProfile
        if let existing = UserProfile.current(from: profiles) {
            profile = existing
        } else {
            profile = UserProfile(name: name, username: OnboardingRules.generatedUsername())
            modelContext.insert(profile)
        }
        profile.name = name
        if profile.username.isEmpty {
            profile.username = OnboardingRules.generatedUsername()
        }
        if !appleUserID.isEmpty { profile.appleUserID = appleUserID }
        if !firebaseUID.isEmpty {
            profile.firebaseUID = firebaseUID
            profile.firebaseEmail = firebaseEmail.isEmpty ? nil : firebaseEmail
        }
        profile.profileUpdatedAt = Date()
        LaterGroup.ensurePersonalSpace(for: profile, context: modelContext)
        do {
            try modelContext.save()
        } catch {
            print("[Onboarding] 名前の保存に失敗: \(error)")
        }
        currentProfileID = profile.id.uuidString
        userName = name
        userID = profile.username
        confirmedName = name
        Task { await UserDirectoryService.publish(profile) }

        advance()
    }

    // MARK: - メールで続ける

    /// 前後の空白を除き、全角を半角に直して(「＠」など)、小文字にしたアドレス
    private var normalizedEmail: String {
        emailInput.precomposedStringWithCompatibilityMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    /// 簡易な形の判定(「@」が1つ、前後が空でなく、「@」のあとに「.」を含む)。厳密にしすぎない。
    private var isEmailValid: Bool {
        normalizedEmail.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("", text: $emailInput, prompt: Text("メールアドレス").foregroundStyle(Color(hex: "4A4A4F")))
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .tint(.white)
                .lineLimit(1)
                .minimumScaleFactor(20 / 28)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.send)
                .focused($isEmailFocused)
                .onSubmit {
                    if isEmailValid { sendEmailLink() } else { showEmailError() }
                }
                .onChange(of: emailInput) { old, _ in emailInputChanged(wasValid: Self.isValid(old)) }
                .accessibilityLabel("メールアドレス")
                .dynamicTypeSize(.large)
            Rectangle()
                .fill(.white.opacity(isEmailErrorShown ? 0.9 : 0.3))
                .frame(height: 1)
                .animation(.easeOut(duration: 0.2), value: isEmailErrorShown)

            if isEmailErrorShown {
                HStack(alignment: .top, spacing: 8) {
                    Text("!")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 15, height: 15)
                        .background(Circle().fill(OnboardingPalette.subText))
                        .padding(.top, 1)
                    Text("メールアドレスの形が違うようです。「@」のあとも、確かめてください。")
                        .font(.system(size: 12.5))
                        .foregroundStyle(OnboardingPalette.subText)
                }
                .transition(.opacity)
            } else if isEmailValid {
                Text("サインイン用のリンクを送ります。パスワードは要りません。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(OnboardingPalette.secondaryText)
                    .transition(.opacity)
            }
        }
        .padding(.top, 34)
        .modifier(ShakeEffect(animatableData: CGFloat(emailShake)))
        .animation(.easeOut(duration: 0.2), value: isEmailErrorShown)
    }

    private static func isValid(_ raw: String) -> Bool {
        let value = raw.precomposedStringWithCompatibilityMapping.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil
    }

    /// 入力のたびに:エラーは消す。形が合った瞬間だけ軽く1回。止まって0.8秒たったら形を確かめる。
    private func emailInputChanged(wasValid: Bool) {
        emailErrorTask?.cancel()
        if isEmailErrorShown { isEmailErrorShown = false }
        if isEmailValid && !wasValid {
            haptics.playTransient(intensity: OnboardingTuning.tagHaptic.intensity, sharpness: OnboardingTuning.tagHaptic.sharpness)
        }
        guard !normalizedEmail.isEmpty, !isEmailValid else { return }
        emailErrorTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled, !isEmailValid, step == .emailInput else { return }
            showEmailError()
        }
    }

    /// 形が違う:赤くしない。「!」とやさしい言葉、線が白く強くなり、入力欄が左右に小さく揺れる。
    private func showEmailError() {
        guard !isEmailErrorShown else { return }
        isEmailErrorShown = true
        if !reduceMotion {
            withAnimation(.linear(duration: 0.3)) { emailShake += 1 }
        }
        if !hasShownEmailError {
            hasShownEmailError = true
            playSoftDouble()
        }
        UIAccessibility.post(notification: .announcement, argument: "メールアドレスの形が違うようです。「@」のあとも、確かめてください。")
    }

    /// リンクを送る:キーボードを閉じて「送っています…」へ。10秒たっても終わらなければ失敗へ。
    /// 送る前にアドレスを端末に保存する(FirebaseAuthService.sendSignInLinkが行う)。
    private func sendEmailLink() {
        guard isEmailValid else {
            showEmailError()
            return
        }
        let address = normalizedEmail
        sentAddress = address
        isEmailFocused = false
        sendingAttempt += 1
        let attempt = sendingAttempt
        go(to: .emailSending, withHaptic: false)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(10))
            guard attempt == sendingAttempt, step == .emailSending else { return }
            sendingAttempt += 1
            showEmailFailure(.network)
        }
        Task { @MainActor in
            do {
                try await FirebaseAuthService.sendSignInLink(to: address)
                guard attempt == sendingAttempt else { return }
                sendingAttempt += 1
                // 送信中の画面を一瞬で飛ばさないよう、少しだけ見せてから進む。
                try? await Task.sleep(for: .seconds(0.6))
                haptics.playTransient(intensity: OnboardingTuning.tagHaptic.intensity, sharpness: OnboardingTuning.tagHaptic.sharpness)
                go(to: .emailSent, withHaptic: false)
                startResendCountdown()
                UIAccessibility.post(notification: .announcement, argument: "メールを送りました。届いたメールのサインインを開いてください")
            } catch {
                print("[EmailSignIn] sendSignInLink failed: \(error)")
                guard attempt == sendingAttempt else { return }
                sendingAttempt += 1
                showEmailFailure(EmailSignInFailure.from(error))
            }
        }
    }

    private func showEmailFailure(_ failure: EmailSignInFailure) {
        emailFailure = failure
        if step == .emailFailed {
            return
        }
        // 送信中など、場面の切り替え中でも必ず失敗の画面に移す。
        DispatchQueue.main.asyncAfter(deadline: .now() + (isTransitioning ? 0.3 : 0)) {
            go(to: .emailFailed, withHaptic: false)
            playSoftDouble()
            UIAccessibility.post(notification: .announcement, argument: failure.title + failure.message.replacingOccurrences(of: "\n", with: ""))
        }
    }

    /// 失敗のあと:期限切れ・別の端末で開いた時は入力へ(アドレスを入れ直す)。それ以外は、もう一度送る。
    private func retryAfterFailure() {
        switch emailFailure {
        case .expiredLink, .missingEmail:
            go(to: .emailInput)
        case .network, .tooManyRequests:
            if isEmailValid { sendEmailLink() } else { go(to: .emailInput) }
        }
    }

    private var emailSentInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(sentAddress)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("届いたメールの「サインイン」を開くと、そのまま続きに進めます。")
                .font(.system(size: 14))
                .foregroundStyle(OnboardingPalette.subText)
                .lineSpacing(3)
            Text("届かないときは、迷惑メールも見てみてください。")
                .font(.system(size: 12.5))
                .foregroundStyle(OnboardingPalette.secondaryText)
        }
        .padding(.top, 24)
    }

    private var canOpenMailApp: Bool {
        URL(string: "message://").map { UIApplication.shared.canOpenURL($0) } ?? false
    }

    private var emailSentActions: some View {
        VStack(spacing: 18) {
            if canOpenMailApp {
                primaryButton("メールアプリを開く") {
                    if let url = URL(string: "message://") { UIApplication.shared.open(url) }
                }
            }
            HStack {
                Button("アドレスを変える") { go(to: .emailInput, withHaptic: false) }
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(OnboardingPalette.secondaryText)
                Spacer()
                if resendRemaining > 0 {
                    Text(String(format: "再送まで %d:%02d", resendRemaining / 60, resendRemaining % 60))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(OnboardingPalette.secondaryText)
                        .monospacedDigit()
                        .accessibilityLabel("再送まで あと\(resendRemaining)秒")
                } else {
                    Button("もう一度送る") { sendEmailLink() }
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    /// 再送までの30秒のカウントダウン。読み上げは毎秒ではなく10秒おき。
    private func startResendCountdown() {
        resendTask?.cancel()
        resendRemaining = OnboardingTuning.emailResendInterval
        resendTask = Task { @MainActor in
            while resendRemaining > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                resendRemaining -= 1
                if voiceOverEnabled, resendRemaining > 0, resendRemaining % 10 == 0, step == .emailSent {
                    UIAccessibility.post(notification: .announcement, argument: "再送まで あと\(resendRemaining)秒")
                }
            }
        }
    }

    // MARK: - タグ

    private func saveTagsAndAdvance() {
        if let profile = UserProfile.current(from: profiles) {
            profile.selfTags = selectedTags
            try? modelContext.save()
        }
        advance()
    }

    // MARK: - 長押し(同意・結び)

    private func completeHold(_ kind: OnboardingHoldKind) {
        switch kind {
        case .consent:
            // 満ちたらくっきり1回。玉・光・点を完全に戻し、点は5つ灯った状態から再開する。
            haptics.fireCapture()
            litOverride = 5
            withAnimation(.easeOut(duration: 0.4)) { isOrbVisible = true }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.42))
                advance(withHaptic: false)
            }
        case .finish:
            haptics.fireCapture(
                intensity: OnboardingTuning.finishHaptic.intensity,
                sharpness: OnboardingTuning.finishHaptic.sharpness,
                tail: OnboardingTuning.finishTail
            )
            Task { @MainActor in
                // 色づきを見せるため、結びだけ0.9秒待ってからパシャ。
                try? await Task.sleep(for: .seconds(0.9))
                guard !isTransitioning else { return }
                transition(withHaptic: false) { markOnboardingCompleted() }
            }
        }
    }

    // MARK: - プロフィール撮影

    private func captureProfilePhoto() {
        haptics.fireCapture()
        camera.capturePhoto(flashOn: false) { data in
            DispatchQueue.main.async {
                if let data, let profile = UserProfile.current(from: profiles) {
                    ProfilePhotoDevelopment.store(CapturedImageCompressor.compressedImageData(from: data), for: profile, context: modelContext)
                    showPhotoNotice(title: "預けました", message: "あなたの1枚は、\n次の 9:00 に現像されます。")
                } else {
                    showPhotoNotice(title: "撮れませんでした", message: "プロフィールの画像は、\nあとから設定できます。")
                }
            }
        }
    }

    private func showPhotoNotice(title: String, message: String) {
        withAnimation(.easeIn(duration: 0.3)) { photoNotice = (title, message) }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.4))
            advance(withHaptic: false)
        }
    }

    // MARK: - 完了

    private func markOnboardingCompleted() {
        typingTask?.cancel()
        savedStep = ""
        onboardingCompleted = true
        if UserDefaults.standard.object(forKey: "onboardingCompletedAt") == nil {
            UserDefaults.standard.set(Date(), forKey: "onboardingCompletedAt")
        }
        hasSeenWelcomeOnboarding = true
        hasCompletedSurvey = true
        hasSeenAboutLaterIntro = true
        isProfileSetupCompleted = true
        isSetupCompleted = true
    }
}

// MARK: - カメラの向き(@Stateで扱える値)

enum AVCaptureDevicePositionValue {
    case back, front

    var avPosition: AVCaptureDevice.Position { self == .back ? .back : .front }
}

// MARK: - ボタンを押した時の縮み

private struct OnboardingPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - 場面の視覚要素

/// 「09:00」(等幅、白く光る)と、その下で一斉に光る14個の点(全員が同時に)。
private struct NineAMVisual: View {
    @State private var isLit = false

    var body: some View {
        VStack(spacing: 16) {
            Text("09:00")
                .font(.system(size: 46, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.6), radius: 10)
            HStack(spacing: 9) {
                ForEach(0..<14, id: \.self) { _ in
                    Circle()
                        .fill(.white.opacity(isLit ? 1 : 0.16))
                        .frame(width: 5, height: 5)
                        .shadow(color: isLit ? .white.opacity(0.9) : .clear, radius: 4)
                }
            }
        }
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) { isLit = true }
        }
    }
}

/// 34個の小さな点の輪(直径96pt、オレンジ→青→黄)。
private struct ArriveRingVisual: View {
    var body: some View {
        ZStack {
            ForEach(0..<34, id: \.self) { index in
                let fraction = Double(index) / 34
                let angle = fraction * 2 * .pi - .pi / 2
                Circle()
                    .fill(HomePalette.ringColor(atFraction: fraction))
                    .frame(width: 4, height: 4)
                    .offset(x: cos(angle) * 48, y: sin(angle) * 48)
            }
        }
        .frame(width: 100, height: 100)
        .accessibilityHidden(true)
    }
}

/// 通知カードの見本(Laterのアイコン + 「9:00 になりました。今日を撮れます。」+「いま」)。
private struct NotificationCardSample: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.black)
                .frame(width: 38, height: 38)
                .overlay(Circle().fill(.white).frame(width: 6, height: 6).shadow(color: .white.opacity(0.8), radius: 4))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Later")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("いま")
                        .font(.system(size: 12))
                        .foregroundStyle(OnboardingPalette.secondaryText)
                }
                Text(OnboardingCopy.dailyNotificationBody)
                    .font(.system(size: 13.5))
                    .foregroundStyle(OnboardingPalette.subText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(OnboardingPalette.surface.opacity(0.92)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("通知の見本:\(OnboardingCopy.dailyNotificationBody)")
    }
}
