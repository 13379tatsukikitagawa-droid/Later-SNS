import SwiftUI
import SwiftData
import AuthenticationServices
import AVFoundation

/// 初回設定 v2(6画面)。開幕 → ① はじめる → ② ニックネーム → ③ Laterの一日 → ④ 仕組みの問題
/// → ⑤ 最初の1枚 → ⑥ 預けました → ようこそ → Home。新規ユーザーだけが通る。
///
/// 全画面が同じ型:上に真珠の玉(まわりの6つの点が進み具合)、見出し(28pt)+ あれば補足(15pt)、
/// 画面ごとの中身、下にボタン。切り替えは「浮かんで入る」(パシャは⑤の撮影の1回だけ)。
struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.scenePhase) private var scenePhase

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
    /// ⑤を「あとで撮る」で通った(⑥の文言が変わる)
    @AppStorage("onboardingPhotoSkipped") private var photoSkipped = false

    @Query private var profiles: [UserProfile]

    // 場面
    @State private var step: OnboardingStep = .account
    @State private var hasStarted = false
    @State private var isOpening = false
    /// 開幕の絵を消しはじめた(①の中身はこのあいだに入ってくる)
    @State private var openingFading = false
    @State private var openingStart = Date()
    /// 中身の状態:浮かんで入る(shown)・上へ消える(leaving)・入る前(hidden)
    @State private var contentPhase: ContentPhase = .hidden
    @State private var isTransitioning = false

    // 玉・光
    @State private var isOrbVisible = false
    @State private var orbIsHero = true

    // パシャ(⑤の撮影だけ)
    @State private var isCurtainClosed = false
    @State private var flashOpacity = 0.0

    // 触覚・長押し
    @State private var haptics = ExposureHaptics()
    @State private var holdModel = OnboardingHoldModel()

    // 名前
    @State private var nameInput = ""
    @FocusState private var isNameFocused: Bool
    @State private var confirmedName = ""

    // ④ タグ
    @State private var selfTags: [String] = []
    /// 「＋ 自由に追加」で足したタグ(候補の末尾に並ぶ)
    @State private var customTags: [String] = []
    @State private var isAddingTag = false
    @State private var tagDraft = ""
    @FocusState private var isTagFocused: Bool

    // アカウント
    @State private var signInError: String?
    @State private var isCheckingAccount = false
    @State private var showingPolicy = false

    // メールで続ける
    @State private var emailInput = ""
    @FocusState private var isEmailFocused: Bool
    @State private var isEmailErrorShown = false
    @State private var hasShownEmailError = false
    @State private var emailShake = 0
    @State private var emailErrorTask: Task<Void, Never>?
    @State private var emailFailure: EmailSignInFailure = .network
    /// 失敗の内訳(開発中・TestFlightだけ画面に小さく出す)
    @State private var emailDebugText: String?
    @State private var sendingAttempt = 0
    @State private var resendRemaining = 0
    @State private var resendTask: Task<Void, Never>?
    @State private var sentAddress = ""

    // ⑤ プロフィール撮影
    @ObservedObject private var camera = FilmCameraController.shared
    @State private var cameraPosition: AVCaptureDevicePositionValue = .back

    // ④ 3つ目の人が灯る
    @State private var quietLit = false

    // ⑥ → ようこそ
    @State private var welcomeStart: Date?
    /// 通知の許可のあと・「ようこそ」の前に出す「ウィジェットを置きますか」
    @State private var showingWidgetSetup = false
    @State private var widgetSetupPressedAt = Date()
    /// 「ようこそ」の途中で、本当にバックグラウンドへ行ったか(許可のダイアログの inactive では立てない)
    @State private var welcomeWentBackground = false

    enum ContentPhase { case hidden, leaving, shown }

    private var orbScale: CGFloat { orbIsHero ? 1 : OnboardingMetrics.smallOrbScale }

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                let metrics = OnboardingMetrics(size: proxy.size)
                ZStack(alignment: .topLeading) {
                    // ようこその間は、背景をようこそ側(円でくり抜く)にまかせる。下に Home がある
                    if welcomeStart == nil {
                        OnboardingPalette.background
                        orbLayer(metrics)
                    }
                    if hasStarted && (!isOpening || openingFading) && welcomeStart == nil {
                        contentLayer(metrics)
                    }
                    if isOpening {
                        OnboardingOpeningView(start: openingStart, metrics: metrics)
                            .opacity(openingFading ? 0 : 1)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .ignoresSafeArea()

            if hasStarted && (!isOpening || openingFading) && welcomeStart == nil {
                actionsLayer
                    .padding(.horizontal, 28)
                    .padding(.bottom, step == .name ? 10 : 16)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }

            if welcomeStart == nil {
                FilmGrainOverlay(opacity: 0.05, blendMode: .normal)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            if showingWidgetSetup {
                WidgetSetupFlow(start: .intro) { _ in
                    withAnimation(.easeInOut(duration: 0.3)) { showingWidgetSetup = false }
                    beginWelcome(pressedAt: widgetSetupPressedAt)
                }
                .transition(.opacity)
                .zIndex(5)
            }

            if let welcomeStart {
                OnboardingWelcomeView(start: welcomeStart, haptics: haptics, onFinished: finishWelcome)
                    .ignoresSafeArea()
            }

            curtains
                .ignoresSafeArea()
        }
        .statusBarHidden()
        .onAppear(perform: startIfNeeded)
        .onChange(of: appleUserID) { _, _ in handleSignInChange() }
        .onChange(of: firebaseUID) { _, _ in handleSignInChange() }
        .onChange(of: step) { _, newStep in
            print("[PermPerf] step → \(newStep.rawValue) camera=\(AVCaptureDevice.authorizationStatus(for: .video).rawValue)")
            if newStep == .photo { camera.configure() } else { camera.stopSession() }
        }
        .onChange(of: contentPhase) { _, phase in
            print("[PermPerf] content → \(phase) step=\(step.rawValue) scene=\(scenePhase)")
        }
        .onChange(of: scenePhase) { old, phase in
            print("[PermPerf] scenePhase \(old) → \(phase) step=\(step.rawValue) content=\(contentPhase) transitioning=\(isTransitioning) welcome=\(welcomeStart != nil) orbVisible=\(isOrbVisible) opening=\(isOpening)")
            if phase == .active, step == .photo {
                print("[PermPerf] 前面にもどった(撮影)camera=\(AVCaptureDevice.authorizationStatus(for: .video).rawValue) running=\(camera.session.isRunning)")
                camera.resumeIfNeeded()
            }
            // ようこその途中でバックグラウンドへ行って戻った:最初から再生せず、Homeへ直接。
            // (許可のダイアログでは inactive → active になるだけなので、ここでは飛ばさない。
            //  以前は active だけで判定していて、「お知らせを受け取る」のあと「ようこそ」が飛ばされていた)
            if phase == .background, welcomeStart != nil { welcomeWentBackground = true }
            if phase == .active, welcomeStart != nil, welcomeWentBackground, !isSetupCompleted { finishWelcome() }
        }
        .overlay(alignment: .topLeading) { emailBackButton }
        .sheet(isPresented: $showingPolicy) { PrivacyPolicyView() }
        .onReceive(NotificationCenter.default.publisher(for: .emailSignInLinkOpened)) { _ in
            // メールのリンクからアプリに戻ってきた:確認中へ
            guard step.isEmailStep || step == .account else { return }
            go(to: .emailVerifying)
        }
        .onReceive(NotificationCenter.default.publisher(for: .emailSignInLinkFailed)) { note in
            guard step.isEmailStep || step == .account else { return }
            let failure = (note.object as? Error).map { EmailSignInFailure.from($0) } ?? .missingEmail
            showEmailFailure(failure)
        }
    }

    // MARK: - 玉・背景の光

    private func orbLayer(_ metrics: OnboardingMetrics) -> some View {
        let quiet = step.isQuiet
        return ZStack(alignment: .topLeading) {
            OnboardingSpotlight()
                .opacity(isOrbVisible && !quiet ? 1 : 0)
                .animation(.easeInOut(duration: 1.2), value: quiet)
            OnboardingOrb(
                litCount: step.litDots,
                isCycling: step == .emailSending && !reduceMotion,
                dotCount: OnboardingStep.dotCount,
                dotSize: orbIsHero ? 5 : 8
            )
            .scaleEffect(orbScale)
            .position(x: metrics.size.width / 2, y: metrics.y(orbIsHero ? OnboardingMetrics.orbCenterY : OnboardingMetrics.smallOrbCenterY))
            .opacity(isOrbVisible ? (quiet ? 0.1 : 1) : 0)
            .animation(.easeInOut(duration: 1.2), value: quiet)
        }
        .allowsHitTesting(false)
    }

    // MARK: - 中身(見出し・補足・画面ごとの中身)

    private func contentLayer(_ metrics: OnboardingMetrics) -> some View {
        ZStack(alignment: .topLeading) {
            headline
                .padding(.horizontal, 28)
                .frame(width: metrics.size.width, alignment: .leading)
                .offset(y: metrics.y(step.usesHeroOrb ? 372 : (step.isEmailStep ? 184 : 196)))

            stepContent(metrics)
        }
        .frame(width: metrics.size.width, height: metrics.size.height, alignment: .topLeading)
    }

    private var texts: (title: String, sub: String?) {
        switch step {
        case .account: return (OnboardingCopy.accountTitle, OnboardingCopy.accountSub)
        case .name: return (OnboardingCopy.nameTitle, OnboardingCopy.nameSub)
        case .day: return (OnboardingCopy.dayTitle, OnboardingCopy.daySub(name: confirmedName.isEmpty ? userName : confirmedName))
        case .tags:
            return isAddingTag
                ? (OnboardingCopy.tagAddTitle, OnboardingCopy.tagAddSub)
                : (OnboardingCopy.tagsTitle, OnboardingCopy.tagsSub)
        case .quiet: return (OnboardingCopy.quietTitle, nil)
        case .photo: return (OnboardingCopy.photoTitle, OnboardingCopy.photoSub)
        case .notify:
            return photoSkipped
                ? (OnboardingCopy.notifySkippedTitle, OnboardingCopy.notifySkippedSub)
                : (OnboardingCopy.notifyTitle, OnboardingCopy.notifySub)
        case .emailInput: return ("メールアドレスを\n教えてください。", nil)
        case .emailSending: return ("リンクを\n送っています…", nil)
        case .emailSent: return ("メールを\n送りました。", nil)
        case .emailVerifying: return ("リンクを\n確認しています…", nil)
        case .emailFailed: return (emailFailure.title, emailFailure.message)
        }
    }

    private var headline: some View {
        OnboardingHeadline(
            title: texts.title,
            sub: texts.sub,
            titleColor: step.isQuiet ? OnboardingPalette.quietText : OnboardingPalette.text,
            phase: contentPhase,
            reduceMotion: reduceMotion
        )
    }

    @ViewBuilder
    private func stepContent(_ metrics: OnboardingMetrics) -> some View {
        switch step {
        case .name:
            nameField
                .padding(.horizontal, 28)
                .frame(width: metrics.size.width)
                .offset(y: metrics.y(368))
                .floatIn(contentPhase, index: 2, reduceMotion: reduceMotion)
        case .day:
            LaterDayView(isActive: contentPhase == .shown && scenePhase == .active, onFinish: { go(to: .tags) }, onTapNext: buttonHaptic)
                .frame(width: metrics.size.width, height: metrics.size.height)
                .floatIn(contentPhase, index: 2, reduceMotion: reduceMotion)
        case .tags:
            tagsContent(metrics)
        case .quiet:
            quietCard
                .padding(.horizontal, 28)
                .frame(width: metrics.size.width)
                .offset(y: metrics.y(316))
                .floatIn(contentPhase, index: 2, reduceMotion: reduceMotion)
            Text(OnboardingCopy.quietAnswer)
                .font(.system(size: 18, weight: .bold))
                .tracking(-0.03 * 18)
                .lineSpacing(18 * 0.5 - 4)
                .foregroundStyle(OnboardingPalette.quietText)
                .padding(.horizontal, 28)
                .frame(width: metrics.size.width, alignment: .leading)
                .offset(y: metrics.y(620))
                .floatIn(contentPhase, index: 5, reduceMotion: reduceMotion)
        case .photo:
            viewfinder
                .padding(.horizontal, 28)
                .frame(width: metrics.size.width)
                .offset(y: metrics.y(356))
                .floatIn(contentPhase, index: 2, reduceMotion: reduceMotion)
        case .notify:
            NotificationCardSample()
                .padding(.horizontal, 28)
                .frame(width: metrics.size.width)
                .offset(y: metrics.y(376))
                .floatIn(contentPhase, index: 2, reduceMotion: reduceMotion)
            Text(OnboardingCopy.notifyNote)
                .font(.system(size: 13.5))
                .foregroundStyle(OnboardingPalette.note)
                .frame(width: metrics.size.width)
                .offset(y: metrics.y(478))
                .floatIn(contentPhase, index: 3, reduceMotion: reduceMotion)
        case .emailInput:
            emailField
                .padding(.horizontal, 28)
                .frame(width: metrics.size.width)
                .offset(y: metrics.y(300))
                .floatIn(contentPhase, index: 2, reduceMotion: reduceMotion)
        case .emailSent:
            emailSentInfo
                .padding(.horizontal, 28)
                .frame(width: metrics.size.width, alignment: .leading)
                .offset(y: metrics.y(300))
                .floatIn(contentPhase, index: 2, reduceMotion: reduceMotion)
        case .emailVerifying:
            VerifyingRing()
                .frame(width: metrics.size.width)
                .offset(y: metrics.y(340))
        default:
            EmptyView()
        }
    }

    // MARK: - ② ニックネーム

    private var nameField: some View {
        let validation = OnboardingRules.validateName(nameInput)
        return VStack(alignment: .trailing, spacing: 0) {
            TextField("", text: $nameInput, prompt: Text("ニックネーム").foregroundStyle(Color(hex: "3A3A3E")))
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.04 * 34)
                .foregroundStyle(.white)
                .tint(.white)
                .focused($isNameFocused)
                .submitLabel(.done)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { if validation.problem == nil { confirmName() } }
                .onChange(of: nameInput) { _, value in
                    if value.count > OnboardingRules.nameMaxLength + 4 { nameInput = String(value.prefix(OnboardingRules.nameMaxLength + 4)) }
                }
                .frame(height: 64)
                .accessibilityLabel("ニックネーム")
            Rectangle().fill(.white.opacity(0.35)).frame(height: 1.5)
            HStack {
                if validation.problem == .looksLikeContact {
                    Text("URLやメールアドレスは使えません。")
                        .font(.system(size: 12.5))
                        .foregroundStyle(OnboardingPalette.secondaryText)
                }
                Spacer()
                Text("\(validation.name.count) / \(OnboardingRules.nameMaxLength)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(validation.problem == .tooLong ? OnboardingPalette.subText : OnboardingPalette.note)
                    .monospacedDigit()
            }
            .padding(.top, 26 - 11)
        }
    }

    // MARK: - ④ タグ

    @ViewBuilder
    private func tagsContent(_ metrics: OnboardingMetrics) -> some View {
        if isAddingTag {
            OnboardingTagInputField(text: $tagDraft, focus: $isTagFocused, onSubmit: addCustomTag)
                .padding(.horizontal, 28)
                .frame(width: metrics.size.width)
                .offset(y: metrics.y(368))
                .transition(.opacity)
            // キーボードの上
            VStack(spacing: 6) {
                primaryButton("追加する", isEnabled: !tagDraft.isEmpty) { addCustomTag() }
                textButton("やめる") { closeTagInput() }
            }
            .padding(.horizontal, 28)
            .frame(width: metrics.size.width)
            .offset(y: metrics.y(478))
            .transition(.opacity)
        } else {
            OnboardingTagChips(
                candidates: OnboardingCopy.selfTagCandidates + customTags,
                selected: selfTags,
                onToggle: toggleTag,
                onAdd: openTagInput
            )
            .padding(.horizontal, 28)
            .frame(width: metrics.size.width)
            .offset(y: metrics.y(356))
            .floatIn(contentPhase, index: 2, reduceMotion: reduceMotion)
            .transition(.opacity)
            OnboardingTagCount(count: selfTags.count)
                .padding(.horizontal, 28)
                .frame(width: metrics.size.width)
                .offset(y: metrics.y(632))
                .floatIn(contentPhase, index: 3, reduceMotion: reduceMotion)
                .transition(.opacity)
        }
    }

    private func toggleTag(_ tag: String) {
        if let index = selfTags.firstIndex(of: tag) {
            selfTags.remove(at: index)
        } else if selfTags.count < OnboardingRules.maxSelfTags {
            selfTags.append(tag)
        } else {
            return
        }
        haptics.playTransient(intensity: OnboardingTuning.tagHaptic.intensity, sharpness: OnboardingTuning.tagHaptic.sharpness)
    }

    private func openTagInput() {
        guard selfTags.count < OnboardingRules.maxSelfTags else { return }
        tagDraft = ""
        withAnimation(.easeInOut(duration: 0.3)) { isAddingTag = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isTagFocused = true }
    }

    private func closeTagInput() {
        isTagFocused = false
        tagDraft = ""
        withAnimation(.easeInOut(duration: 0.3)) { isAddingTag = false }
    }

    /// 追加したタグは候補の末尾に加わり、自動で選ばれる(すでに3つなら、加えるだけ)
    private func addCustomTag() {
        guard let tag = OnboardingRules.normalizedTag(tagDraft) else { return }
        buttonHaptic()
        if !OnboardingCopy.selfTagCandidates.contains(tag), !customTags.contains(tag) {
            customTags.append(tag)
        }
        if !selfTags.contains(tag), selfTags.count < OnboardingRules.maxSelfTags {
            selfTags.append(tag)
        }
        closeTagInput()
    }

    /// 「つぎへ」で保存(プロフィールの「自分を表すタグ」)。「あとで選ぶ」は保存せずに進む
    private func confirmTags(save: Bool) {
        guard !isTransitioning else { return }
        if save, let profile = UserProfile.current(from: profiles) {
            profile.selfTags = selfTags
            profile.profileUpdatedAt = Date()
            try? modelContext.save()
            if let cloudKitManager = CloudKitManager.current {
                for group in profile.groups {
                    cloudKitManager.markForUpload(userProfile: profile, in: group)
                }
            }
        }
        go(to: .quiet, haptic: true)
    }

    // MARK: - ⑤ 数字のカード

    private var quietCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { index in
                    let lit = index == 2 && quietLit
                    Image(systemName: "person.fill")
                        .font(.system(size: 34))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(lit ? Color.white : Color(hex: "2E2E32"))
                        .shadow(color: lit ? .white.opacity(0.55) : .clear, radius: 10)
                }
            }
            .accessibilityHidden(true)
            Text(OnboardingCopy.quietStat)
                .font(.system(size: 40, weight: .bold))
                .tracking(-0.05 * 40)
                .foregroundStyle(OnboardingPalette.quietText)
                .padding(.top, 14)
            Text(OnboardingCopy.quietStatBody)
                .font(.system(size: 14.5))
                .lineSpacing(14.5 * 0.65 - 4)
                .foregroundStyle(OnboardingPalette.subText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1).padding(.top, 14)
            Text(OnboardingCopy.quietSource)
                .font(.system(size: 9.5, design: .monospaced))
                .tracking(0.06 * 9.5)
                .lineSpacing(9.5 * 0.7 - 2)
                .foregroundStyle(OnboardingPalette.note)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
        }
        .padding(.top, 22)
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.07), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    // MARK: - ⑤ ファインダー

    private var viewfinder: some View {
        TimelineView(.animation(paused: !holdModel.isMoving)) { context in
            let pressing = holdModel.progress(at: context.date) > 0
            ZStack(alignment: .topTrailing) {
                CameraPreviewRepresentable(session: camera.session)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(OnboardingPalette.surface))
                // 四隅のマーク:押している間に内側へ16pt縮む(ピントを合わせる)
                ViewfinderCorners(inset: pressing ? 30 : 14)
                    .animation(.easeOut(duration: 0.3), value: pressing)
                Button {
                    cameraPosition = cameraPosition == .back ? .front : .back
                    camera.setCameraPosition(cameraPosition.avPosition)
                } label: {
                    Text(cameraPosition == .back ? "背面カメラ" : "前面カメラ")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(OnboardingPalette.quietText)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(Capsule().fill(.black.opacity(0.4)).background(.ultraThinMaterial, in: Capsule()))
                }
                .buttonStyle(.plain)
                .padding(14)
                .accessibilityLabel(cameraPosition == .back ? "背面カメラ。前面に切り替える" : "前面カメラ。背面に切り替える")
            }
            .frame(height: 218)
        }
    }

    // MARK: - ボタン

    @ViewBuilder
    private var actionsLayer: some View {
        Group {
            switch step {
            case .account:
                accountButtons
            case .name:
                primaryButton("つぎへ", isEnabled: OnboardingRules.validateName(nameInput).problem == nil) { confirmName() }
            case .day:
                EmptyView() // ③のボタンは、場面の中(LaterDayView)にある
            case .tags:
                if !isAddingTag {
                    VStack(spacing: 6) {
                        primaryButton("つぎへ", isEnabled: !selfTags.isEmpty) { confirmTags(save: true) }
                        textButton("あとで選ぶ") { confirmTags(save: false) }
                    }
                }
            case .quiet:
                primaryButton("つぎへ") { go(to: .photo, haptic: false) }
            case .photo:
                VStack(spacing: 0) {
                    OnboardingHoldButton(
                        model: holdModel,
                        diameter: 88,
                        label: "長押しで、撮る",
                        sublabel: "プレビューなし",
                        accessibilityActionName: "撮る",
                        onBegin: { remaining in
                            haptics.beginHold(duration: remaining, intensity: OnboardingTuning.photoHoldIntensity, sharpness: OnboardingTuning.photoHoldSharpness)
                        },
                        onRelease: { haptics.cancelHold() },
                        onComplete: captureProfilePhoto
                    )
                    Spacer(minLength: 0)
                    textButton("あとで撮る") {
                        photoSkipped = true
                        go(to: .notify)
                    }
                    .padding(.bottom, 14)
                }
                .frame(height: 240)
            case .notify:
                VStack(spacing: 6) {
                    primaryButton("お知らせを受け取る") { startWelcome(requestNotifications: true) }
                    textButton("あとで") { startWelcome(requestNotifications: false) }
                }
            case .emailInput:
                primaryButton("リンクを送る", isEnabled: isEmailValid, disabledTextColor: Color(hex: "5A5A5E")) { sendEmailLink() }
            case .emailSent:
                emailSentActions
            case .emailFailed:
                VStack(spacing: 16) {
                    if FirebaseAuthService.showsDebugDetails, let emailDebugText {
                        Text(emailDebugText)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(OnboardingPalette.quietText)
                            .multilineTextAlignment(.center)
                            .textSelection(.enabled)
                    }
                    primaryButton("もう一度送る") { retryAfterFailure() }
                    appleButton(style: .black)
                        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                }
            case .emailSending, .emailVerifying:
                EmptyView()
            }
        }
        .floatIn(contentPhase, index: buttonIndex, reduceMotion: reduceMotion)
        .allowsHitTesting(contentPhase == .shown && !isTransitioning)
    }

    /// ボタンの浮かぶ順番(いちばん最後)
    private var buttonIndex: Int {
        switch step {
        case .quiet: return 6
        case .notify: return 4
        case .account: return 2
        default: return 3
        }
    }

    private var accountButtons: some View {
        VStack(spacing: 12) {
            if isCheckingAccount {
                ProgressView()
                    .tint(.white)
                    .frame(height: 56)
                    .accessibilityLabel("アカウントを確認しています")
            } else {
                appleButton(style: .white)
                Button {
                    buttonHaptic()
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
            // 続けると、利用規約とプライバシーポリシーに同意したことになります
            Text(Self.consentNote)
                .font(.system(size: 11.5))
                .lineSpacing(11.5 * 0.6 - 3)
                .multilineTextAlignment(.center)
                .foregroundStyle(OnboardingPalette.note)
                .tint(OnboardingPalette.note)
                .padding(.top, 2)
                .environment(\.openURL, OpenURLAction { _ in
                    showingPolicy = true
                    return .handled
                })
        }
    }

    private static let consentNote: AttributedString = {
        var text = AttributedString("続けると、")
        var terms = AttributedString("利用規約")
        terms.link = URL(string: "later-policy://terms")
        terms.underlineStyle = .single
        var and = AttributedString("と")
        var privacy = AttributedString("プライバシーポリシー")
        privacy.link = URL(string: "later-policy://privacy")
        privacy.underlineStyle = .single
        let rest = AttributedString("に\n同意したことになります。")
        text.append(terms)
        text.append(and)
        text.append(privacy)
        text.append(rest)
        return text
    }()

    /// 公式のSign in with Appleボタン(「Appleで続ける」)。高さ56pt・完全な丸み。
    /// キャンセル(1001)は何も表示しない。ほかの失敗は、静かに1行とやわらかい触覚2回。
    private func appleButton(style: SignInWithAppleButton.Style) -> some View {
        SignInWithAppleButton(.continue) { request in
            print("[AppleSignIn] onRequest: ボタンが押され、認証を要求します")
            SignInPerf.begin()
            signInError = nil
            buttonHaptic()
            request.requestedScopes = [.fullName]
        } onCompletion: { result in
            switch result {
            case .success:
                SignInPerf.mark("T2 Face ID が済み、結果が返った")
                print("[AppleSignIn] onCompletion: 成功")
                defer { SignInPerf.mark("T2b 結果を端末に保存した(appleUserID)") }
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

    private func playSoftDouble() {
        guard !step.isQuiet else { return }
        haptics.playTransient(intensity: 0.3, sharpness: 0.3)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            haptics.playTransient(intensity: 0.3, sharpness: 0.3)
        }
    }

    /// ボタン:くっきり軽く1回(④では鳴らさない)
    private func buttonHaptic() {
        guard !step.isQuiet else { return }
        haptics.playTransient(intensity: OnboardingTuning.buttonHaptic.intensity, sharpness: OnboardingTuning.buttonHaptic.sharpness)
    }

    private func primaryButton(_ title: String, isEnabled: Bool = true, disabledTextColor: Color = OnboardingPalette.secondaryText, action: @escaping () -> Void) -> some View {
        OnboardingPrimaryButton(title: title, isEnabled: isEnabled, action: action)
    }

    private func textButton(_ title: String, action: @escaping () -> Void) -> some View {
        OnboardingTextButton(title: title, action: action)
    }

    /// 左上の「<」(メールの入力・送りました)。ひとつ前の画面に戻る。
    @ViewBuilder
    private var emailBackButton: some View {
        if step == .emailInput || step == .emailSent {
            Button {
                go(to: step == .emailInput ? .account : .emailInput)
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

    // MARK: - パシャ(⑤の撮影の1回だけ)

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
        .allowsHitTesting(isCurtainClosed)
        .accessibilityHidden(true)
    }

    /// 幕が130msで閉じる → 120msで中身を入れ替え → フラッシュ(620ms)→ 70ms後に幕が230msで開く。音はなし
    private func pasha(swap: @escaping () -> Void) {
        isTransitioning = true
        withAnimation(.timingCurve(0.5, 0, 0.9, 0.4, duration: 0.13)) { isCurtainClosed = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.12))
            swap()
            withAnimation(.linear(duration: 0.05)) { flashOpacity = 0.92 }
            try? await Task.sleep(for: .seconds(0.05))
            withAnimation(.easeOut(duration: 0.57)) { flashOpacity = 0 }
            try? await Task.sleep(for: .seconds(0.07))
            withAnimation(.timingCurve(0.2, 0.7, 0.3, 1, duration: 0.23)) { isCurtainClosed = false }
            try? await Task.sleep(for: .seconds(0.24))
            isTransitioning = false
        }
    }

    // MARK: - 開始・再開

    private func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        haptics.prepare()
        confirmedName = UserProfile.current(from: profiles)?.name ?? userName

        // ようこその途中で閉じた:初回設定はやり直さず、Homeへ
        if onboardingCompleted {
            markOnboardingCompleted()
            return
        }
        if let resumed = resumeStep() {
            // 再開時は開幕を再生せず、いまの場面から
            step = resumed
            orbIsHero = resumed.usesHeroOrb
            isOrbVisible = true
            contentPhase = .hidden
            enter()
            if resumed == .account { handleSignInChange() }
            return
        }
        playOpening()
    }

    private func resumeStep() -> OnboardingStep? {
        let isSignedIn = !appleUserID.isEmpty || !firebaseUID.isEmpty
        guard let saved = OnboardingStep(rawValue: savedStep) else {
            // 古い版の場面で止まっていた:サインインずみなら②から(名前があれば③から)
            guard !savedStep.isEmpty else { return nil }
            if !isSignedIn { return .account }
            return confirmedName.isEmpty ? .name : .day
        }
        if saved.isEmailStep {
            if isSignedIn { return .name }
            // メールを送ったあとに閉じた時は「送りました」から(リンクを開けば、そのまま続く)
            if FirebaseAuthService.pendingEmail != nil {
                sentAddress = FirebaseAuthService.pendingEmail ?? ""
                return .emailSent
            }
            return .emailInput
        }
        // サインイン前の場面より先に保存されていても、未サインインならアカウントから
        if !isSignedIn, saved != .account { return .account }
        return saved
    }

    /// 開幕(約7秒、スキップなし)。絞りが縮みながら①の玉(y=240)へ着き、約1.5秒後に①の中身が浮かぶ
    private func playOpening() {
        isOpening = true
        openingStart = Date()
        step = .account
        orbIsHero = true
        let reveal = OnboardingOpeningView.orbRevealTime(reduceMotion: reduceMotion)
        let duration = OnboardingOpeningView.duration(reduceMotion: reduceMotion)
        Task { @MainActor in
            if !reduceMotion {
                try? await Task.sleep(for: .seconds(1.2))
                haptics.playRamp(from: 0, to: 0.3, sharpness: 0.2, duration: 1.6)
                try? await Task.sleep(for: .seconds(3.0))
                haptics.playTransient(intensity: OnboardingTuning.openingSettleHaptic.intensity, sharpness: OnboardingTuning.openingSettleHaptic.sharpness)
                try? await Task.sleep(for: .seconds(reveal - 4.2))
            } else {
                try? await Task.sleep(for: .seconds(reveal))
            }
            withAnimation(.easeInOut(duration: 1.2)) { isOrbVisible = true }
            if reduceMotion {
                try? await Task.sleep(for: .seconds(duration - reveal))
                isOpening = false
                savedStep = OnboardingStep.account.rawValue
                contentPhase = .hidden
                enter()
            } else {
                // 切り替え:玉に波紋が広がりはじめる頃(開幕の 7.15 秒)から①の中身が入り、開幕の絵は 0.4 秒で消える
                try? await Task.sleep(for: .seconds(OnboardingOpeningView.contentStartTime - reveal))
                savedStep = OnboardingStep.account.rawValue
                contentPhase = .hidden
                enter()
                withAnimation(.easeOut(duration: 0.4)) { openingFading = true }
                try? await Task.sleep(for: .seconds(0.4))
                isOpening = false
                openingFading = false
            }
        }
    }

    // MARK: - 切り替え(浮かんで入る)

    /// 出ていく中身:上へ10pt・ぼかし・0.25秒 → 玉と点を切り替え → 入ってくる中身:下から14pt・0.6秒(上から順に0.11秒ずつ)
    private func go(to target: OnboardingStep, haptic: Bool = false) {
        guard !isTransitioning, target != step else { return }
        isTransitioning = true
        isNameFocused = false
        isEmailFocused = false
        isTagFocused = false
        if haptic { buttonHaptic() }

        let movesOrb = target.usesHeroOrb != orbIsHero
        if reduceMotion || voiceOverEnabled {
            withAnimation(.easeInOut(duration: 0.25)) {
                contentPhase = .leaving
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.25))
                swap(to: target, movesOrb: movesOrb)
                withAnimation(.easeInOut(duration: 0.25)) { contentPhase = .shown }
                try? await Task.sleep(for: .seconds(0.25))
                isTransitioning = false
                afterEnter()
            }
            return
        }

        withAnimation(.easeIn(duration: 0.25)) { contentPhase = .leaving }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.24))
            swap(to: target, movesOrb: movesOrb)
            try? await Task.sleep(for: .seconds(movesOrb ? 0.38 : 0.12))
            enter()
        }
    }

    private func swap(to next: OnboardingStep, movesOrb: Bool) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { contentPhase = .hidden }
        holdModel.reset()
        step = next
        savedStep = next.rawValue
        quietLit = false
        if movesOrb {
            if reduceMotion {
                orbIsHero = next.usesHeroOrb
            } else {
                withAnimation(.timingCurve(0.6, 0, 0.2, 1, duration: 0.95)) { orbIsHero = next.usesHeroOrb }
            }
        }
        if next == .name { SignInPerf.end("T7 次の画面(名前)が出た") }
    }

    /// 入ってくる中身を浮かべる(各要素が自分の遅れで動く)
    private func enter() {
        withAnimation(nil) { contentPhase = .hidden }
        DispatchQueue.main.async {
            contentPhase = .shown
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.4))
                isTransitioning = false
            }
            afterEnter()
        }
    }

    private func afterEnter() {
        switch step {
        case .name:
            // 中身が浮かび終わってから、キーボードを出す
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.3 : 0.9)) { isNameFocused = true }
        case .emailInput:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { isEmailFocused = true }
        case .tags:
            // 途中から再開したとき:保存ずみのタグを選んだ状態にもどす
            if selfTags.isEmpty, let saved = UserProfile.current(from: profiles)?.selfTags, !saved.isEmpty {
                selfTags = saved
                customTags = saved.filter { !OnboardingCopy.selfTagCandidates.contains($0) }
            }
        case .quiet:
            // 入ってから1.5秒後に、3つ目の人が1秒かけて灯る
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard step == .quiet else { return }
                withAnimation(.easeInOut(duration: 1.0)) { quietLit = true }
            }
        default:
            break
        }
    }

    // MARK: - アカウント

    private func handleSignInChange() {
        guard step == .account || step.isEmailStep, !appleUserID.isEmpty || !firebaseUID.isEmpty, !isCheckingAccount else { return }
        // 端末に同じアカウントのプロフィールがあれば、サインイン処理側がisSetupCompletedを立てる
        if isSetupCompleted {
            completeAsExistingUser()
            return
        }
        // 最初の同期(以前のデータが多いと1分近くかかる)を待たずに、すぐ名前の画面へ。
        // 以前Laterを使っていたアカウントかどうかは、裏で確かめ、見つかったらHomeへ切りかえる。
        if let existing = existingProfileForSignedInAccount() {
            currentProfileID = existing.id.uuidString
            completeAsExistingUser()
            return
        }
        go(to: .name)
        checkExistingAccountInBackground()
    }

    /// 裏で、iCloud の同期が届くのを待って既存アカウントを確かめる(画面は止めない)。
    /// 見つかったら、初回設定の途中でも Home へ(名前・写真などの入力はしなくてよい)。
    private func checkExistingAccountInBackground() {
        guard !isCheckingAccount else { return }
        isCheckingAccount = true
        SignInPerf.mark("既存アカウントの確認を、裏で開始")
        Task { @MainActor in
            defer { isCheckingAccount = false }
            // iCloud の準備(CloudKitManager)ができるまで、少しずつ待つ(最大20秒)
            for _ in 0..<40 where CloudKitManager.current == nil {
                try? await Task.sleep(for: .seconds(0.5))
            }
            guard let cloudKitManager = CloudKitManager.current else { return }
            await cloudKitManager.fetchPrivateChangesNow()
            await cloudKitManager.fetchSharedChangesNow()
            SignInPerf.mark("裏の確認:同期が終わった")
            guard !isSetupCompleted, welcomeStart == nil, let existing = existingProfileForSignedInAccount() else { return }
            SignInPerf.mark("裏の確認:既存アカウントが見つかった → Home")
            currentProfileID = existing.id.uuidString
            completeAsExistingUser()
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

    /// 既存のアカウントだった:②〜⑥を飛ばし、既存のプロフィールのままHomeへ
    private func completeAsExistingUser() {
        markOnboardingCompleted()
    }

    // MARK: - ② 名前の保存(確認画面は作らない。名前は③の補足で呼ぶ)

    private func confirmName() {
        let validation = OnboardingRules.validateName(nameInput)
        guard validation.problem == nil, !isTransitioning else { return }
        let name = validation.name
        buttonHaptic()

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

        go(to: .day)
    }

    // MARK: - ⑤ 撮影

    /// 満ちたら強く1回 → 0.16秒後にパシャ → ⑥。画像は裏で保存し、待たせない(翌朝9:00に現像)
    private func captureProfilePhoto() {
        haptics.fireCapture(intensity: OnboardingTuning.photoCaptureHaptic.intensity, sharpness: OnboardingTuning.photoCaptureHaptic.sharpness)
        photoSkipped = false
        camera.capturePhoto { data in
            DispatchQueue.main.async {
                if let data, let profile = UserProfile.current(from: profiles) {
                    ProfilePhotoDevelopment.store(CapturedImageCompressor.compressedImageData(from: data), for: profile, context: modelContext)
                } else {
                    photoSkipped = true
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            pasha {
                swap(to: .notify, movesOrb: false)
                contentPhase = .shown
            }
        }
    }

    // MARK: - ⑥ → ようこそ → Home

    /// 「お知らせを受け取る」は許可のダイアログの答えが出てから、「あとで」はすぐに、ようこその演出へ。
    /// 演出を始める時点で onboardingCompleted を保存する(途中で閉じても、やり直させない)。
    private func startWelcome(requestNotifications: Bool) {
        guard welcomeStart == nil, !isTransitioning else { return }
        isTransitioning = true
        haptics.playTransient(intensity: OnboardingTuning.buttonHaptic.intensity, sharpness: OnboardingTuning.buttonHaptic.sharpness)
        let pressedAt = Date()
        print("[Welcome] W0 \(requestNotifications ? "「お知らせを受け取る」" : "「あとで」")を押した")
        // ダイアログが出ている間は、画面を何も変えない。結果が返った時刻(または「あとで」)を t = 0 にする
        Task { @MainActor in
            if requestNotifications {
                print(String(format: "[Welcome] W1 許可を求めた(ダイアログ) +%.2fs", Date().timeIntervalSince(pressedAt)))
                let result = await DailyOpenNotification.requestAuthorization(timeout: 10)
                print(String(format: "[Welcome] W2 ダイアログの結果:%@ +%.2fs scene=%@", result.rawValue, Date().timeIntervalSince(pressedAt), "\(scenePhase)"))
                // 通知の登録は演出と並行(待たない・失敗しても演出は止めない)
                Task {
                    let scheduled = await DailyOpenNotification.schedule()
                    print(String(format: "[Welcome] W3 通知の登録が終わった scheduled=%@ +%.2fs", "\(scheduled)", Date().timeIntervalSince(pressedAt)))
                }
            }
            // まだ見ていなければ、「ようこそ」の前に「ウィジェットを置きますか」(あとで → そのまま「ようこそ」へ)
            if !UserDefaults.standard.bool(forKey: WidgetSetupStorage.seenKey) {
                widgetSetupPressedAt = pressedAt
                withAnimation(.easeInOut(duration: 0.3)) { showingWidgetSetup = true }
                return
            }
            beginWelcome(pressedAt: pressedAt)
        }
    }

    /// 「ようこそ」の演出を始める(t = 0)
    private func beginWelcome(pressedAt: Date) {
        onboardingCompleted = true
        savedStep = ""
        welcomeWentBackground = false
        withAnimation(.easeOut(duration: 0.42)) { contentPhase = .leaving }
        welcomeStart = Date()
        print(String(format: "[Welcome] W4 「ようこそ」の演出を始めた(t = 0) +%.2fs", Date().timeIntervalSince(pressedAt)))
    }

    private func finishWelcome() {
        print("[Welcome] W6 Homeが出た(演出の t = \(welcomeStart.map { String(format: "%.2fs", Date().timeIntervalSince($0)) } ?? "-"))")
        markOnboardingCompleted()
    }

    private func markOnboardingCompleted() {
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

    // MARK: - メールで続ける

    /// 前後の空白を除き、全角を半角に直して(「＠」など)、小文字にしたアドレス
    private var normalizedEmail: String {
        emailInput.precomposedStringWithCompatibilityMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    /// 簡易な形の判定(「@」が1つ、前後が空でなく、「@」のあとに「.」を含む)。厳密にしすぎない。
    private var isEmailValid: Bool { Self.isValid(emailInput) }

    private static func isValid(_ raw: String) -> Bool {
        let value = raw.precomposedStringWithCompatibilityMapping.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil
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
        .modifier(ShakeEffect(animatableData: CGFloat(emailShake)))
        .animation(.easeOut(duration: 0.2), value: isEmailErrorShown)
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
    private func sendEmailLink() {
        print("[EmailSignIn] tapped")
        guard isEmailValid else {
            showEmailError()
            return
        }
        let address = normalizedEmail
        sentAddress = address
        isEmailFocused = false
        sendingAttempt += 1
        let attempt = sendingAttempt
        emailDebugText = nil
        go(to: .emailSending)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(10))
            guard attempt == sendingAttempt, step == .emailSending else { return }
            sendingAttempt += 1
            emailDebugText = "timeout: 10秒以内に応答なし"
            showEmailFailure(.network)
        }
        Task { @MainActor in
            do {
                try await FirebaseAuthService.sendSignInLink(to: address)
                guard attempt == sendingAttempt else { return }
                sendingAttempt += 1
                try? await Task.sleep(for: .seconds(0.6))
                haptics.playTransient(intensity: OnboardingTuning.tagHaptic.intensity, sharpness: OnboardingTuning.tagHaptic.sharpness)
                go(to: .emailSent)
                startResendCountdown()
                UIAccessibility.post(notification: .announcement, argument: "メールを送りました。届いたメールのサインインを開いてください")
            } catch {
                let label = FirebaseAuthService.debugLabel(for: error)
                print("[EmailSignIn] sendSignInLink failed: \(label)")
                print("[EmailSignIn] userInfo: \((error as NSError).userInfo)")
                guard attempt == sendingAttempt else { return }
                sendingAttempt += 1
                emailDebugText = label
                showEmailFailure(EmailSignInFailure.from(error))
            }
        }
    }

    private func showEmailFailure(_ failure: EmailSignInFailure) {
        emailFailure = failure
        if step == .emailFailed { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + (isTransitioning ? 0.6 : 0)) {
            go(to: .emailFailed)
            playSoftDouble()
            UIAccessibility.post(notification: .announcement, argument: failure.title + failure.message.replacingOccurrences(of: "\n", with: ""))
        }
    }

    /// 失敗のあと:期限切れ・別の端末で開いた時は入力へ。それ以外は、もう一度送る。
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
                Button("アドレスを変える") { go(to: .emailInput) }
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
}

// MARK: - 浮かんで入る

private struct FloatIn: ViewModifier {
    let phase: OnboardingFlowView.ContentPhase
    let index: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        let opacity: Double = phase == .shown ? 1 : 0
        let offset: CGFloat = reduceMotion ? 0 : (phase == .leaving ? -10 : (phase == .hidden ? 14 : 0))
        let blur: CGFloat = reduceMotion ? 0 : (phase == .shown ? 0 : 5)
        let animation: Animation? = {
            if reduceMotion { return .easeInOut(duration: 0.25) }
            switch phase {
            case .shown: return .timingCurve(0.2, 0.7, 0.2, 1, duration: 0.6).delay(0.15 + 0.11 * Double(index))
            case .leaving: return .easeIn(duration: 0.25)
            case .hidden: return nil
            }
        }()
        return content
            .opacity(opacity)
            .offset(y: offset)
            .blur(radius: blur)
            .animation(animation, value: phase)
    }
}

extension View {
    func floatIn(_ phase: OnboardingFlowView.ContentPhase, index: Int, reduceMotion: Bool) -> some View {
        modifier(FloatIn(phase: phase, index: index, reduceMotion: reduceMotion))
    }
}

// MARK: - カメラの向き(@Stateで扱える値)

enum AVCaptureDevicePositionValue {
    case back, front

    var avPosition: AVCaptureDevice.Position { self == .back ? .back : .front }
}

// MARK: - ⑤ ファインダーの四隅

private struct ViewfinderCorners: View {
    let inset: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            Path { path in
                let l: CGFloat = 26
                for (x, y, dx, dy) in [(inset, inset, 1.0, 1.0), (w - inset, inset, -1.0, 1.0), (inset, h - inset, 1.0, -1.0), (w - inset, h - inset, -1.0, -1.0)] {
                    path.move(to: CGPoint(x: x, y: y + l * dy))
                    path.addLine(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x + l * dx, y: y))
                }
            }
            .stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - ⑥ 通知の見本

/// 通知の見本カード(高さ84pt・角丸22pt)。本文は、実際に登録する通知と同じ定数を使う。
private struct NotificationCardSample: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.black)
                .frame(width: 44, height: 44)
                .overlay(OnboardingPearl(diameter: 22))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
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
                    .font(.system(size: 14))
                    .foregroundStyle(OnboardingPalette.quietText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 84)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 40 / 255, green: 40 / 255, blue: 44 / 255).opacity(0.72))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("通知の見本:\(OnboardingCopy.dailyNotificationBody)")
    }
}
