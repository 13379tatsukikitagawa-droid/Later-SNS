import SwiftData
import SwiftUI

/// プロフィール編集(Profile のピルの「鉛筆」/ 設定の「自分のカード」から)。
/// フォームにしない:プロフィールそのものを、その場で直す(球 → 押して撮りなおす / 名前 → 押して打つ / タグ → 押して外す・足す)。
/// 「顔は要らない」「撮りなおし・プレビューなし」の約束は、撮る前に伝える。
struct ProfileEditScreen: View {
    let initialFocus: ProfileEditFocus

    private static let orange = Color(hex: "FFB26E")

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [UserProfile]
    @AppStorage("userName") private var userName: String = ""

    @State private var haptics = ExposureHaptics()
    @State private var hasLoaded = false
    @State private var originalName = ""
    @State private var originalTags: [String] = []
    @State private var name = ""
    @State private var tags: [String] = []
    /// この画面で撮って、入れかわり待ちにした
    @State private var tookPhotoHere = false
    @State private var isAddingTag = false
    @State private var tagDraft = ""
    @State private var showingRetakeSheet = false
    @State private var showingCamera = false
    @State private var showingDiscard = false
    @State private var ringStart = Date()
    @FocusState private var isNameFocused: Bool
    @FocusState private var isTagFocused: Bool

    private var profile: UserProfile? { UserProfile.current(from: profiles) }
    private var validation: (name: String, problem: OnboardingRules.NameProblem?) { OnboardingRules.validateName(name) }
    private var hasPendingPhoto: Bool { profile?.pendingProfileImageData != nil }
    private var isTyping: Bool { isNameFocused || isTagFocused }

    /// 変更の判定:名前が元と違う / タグの中身が元と違う / この画面で撮った写真が入れかわり待ち
    private var isDirty: Bool {
        validation.name != originalName || tags != originalTags || (tookPhotoHere && hasPendingPhoto)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            // 球のうしろに、橙の淡い光
            RadialGradient(colors: [Self.orange.opacity(0.16), .clear], center: .center, startRadius: 0, endRadius: 220)
                .frame(width: 440, height: 440)
                .offset(y: -40)
                .allowsHitTesting(false)
            FilmGrainOverlay(opacity: 0.04, blendMode: .normal)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 0) {
                    ball
                        .padding(.top, isTyping ? 56 : 54)
                    if hasPendingPhoto && !isTyping {
                        pendingLine.padding(.top, 14).transition(.opacity)
                    }
                    nameField.padding(.top, isTyping ? 18 : (hasPendingPhoto ? 18 : 40))
                    // 変えられない行
                    Text(LaterSince.text)
                        .font(.system(size: 10.5, design: .monospaced))
                        .tracking(0.1 * 10.5)
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.top, 12)
                    tagsSection.padding(.top, 34)
                    if !isTyping {
                        Text("名前とタグは、グループのみんなにも、すぐ新しく見えます。写真は、翌朝 9:00 に入れかわります。")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color(hex: "8E8E93"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                            .padding(.top, 34)
                            .transition(.opacity)
                    }
                }
                .padding(.top, 58)
                .padding(.bottom, 120)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            header
        }
        // 「保存する」はキーボードの上に付いてくる(キーボードの上端から 8pt)
        .safeAreaInset(edge: .bottom) { bottomBar.padding(.bottom, 8) }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.3), value: isTyping)
        .animation(.easeInOut(duration: 0.3), value: hasPendingPhoto)
        // 戻るジェスチャー(左端スワイプ)も「×」と同じ扱い
        .overlay(alignment: .leading) {
            Color.clear
                .frame(width: 20)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 20).onEnded { value in
                    if value.translation.width > 60 { requestClose() }
                })
                .ignoresSafeArea()
        }
        .onAppear(perform: load)
        .sheet(isPresented: $showingRetakeSheet) { retakeSheet }
        .sheet(isPresented: $showingDiscard) { discardSheet }
        .fullScreenCover(isPresented: $showingCamera) {
            ExposureCameraView(
                shotsToday: 0,
                onCaptured: { data, start, _, _ in
                    guard let profile else { return false }
                    // 入れかわり待ちは1つだけ(もう一度撮ると、待ちの写真が差しかわる)
                    ProfilePhotoDevelopment.storeRetake(data, for: profile, takenAt: start, context: modelContext)
                    tookPhotoHere = true
                    return true
                },
                onFinished: { showingCamera = false },
                onClose: { showingCamera = false },
                purpose: .profilePhoto
            )
        }
    }

    // MARK: 上

    private var header: some View {
        ZStack {
            Text("プロフィールを編集")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button(action: requestClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.white.opacity(0.1)).background(.ultraThinMaterial, in: Circle()))
                        .overlay(Circle().strokeBorder(.white.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("とじる")
                Spacer()
            }
            .padding(.horizontal, 22)
        }
        .frame(height: 44)
        .padding(.top, 4)
        .background(LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }

    // MARK: 球

    /// 172pt。周りに点線の輪(24秒で1周)=「押せる」の印。下に「撮りなおす」。入力中は 0.58 倍
    private var ball: some View {
        let scale: CGFloat = isTyping ? 0.58 : 1
        return ZStack {
            if !isTyping {
                TimelineView(.animation(paused: reduceMotion)) { context in
                    let angle = reduceMotion ? 0 : context.date.timeIntervalSince(ringStart) / 24 * 360
                    Circle()
                        .strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [3, 6]))
                        .frame(width: 196, height: 196)
                        .rotationEffect(.degrees(angle))
                }
                .accessibilityHidden(true)
                .transition(.opacity)
            }
            Button { openRetake() } label: {
                ProfileBall(profile: profile, diameter: 172)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("プロフィールの写真。押すと撮りなおします")

            // 入れかわり待ち:球に橙の点(ゆっくり脈打つ。3秒周期)
            if hasPendingPhoto {
                TimelineView(.animation(paused: reduceMotion)) { context in
                    let pulse = reduceMotion ? 1 : 0.6 + 0.4 * (0.5 + 0.5 * sin(context.date.timeIntervalSinceReferenceDate * 2 * .pi / 3))
                    Circle()
                        .fill(Self.orange)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.black, lineWidth: 3))
                        .shadow(color: Self.orange.opacity(0.8 * pulse), radius: 8 * pulse)
                        .opacity(0.5 + 0.5 * pulse)
                }
                .offset(x: 62, y: -62)
                .accessibilityHidden(true)
            }

            if !isTyping {
                Button { openRetake() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera").font(.system(size: 12, weight: .semibold))
                        Text("撮りなおす").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(Capsule().fill(.white.opacity(0.12)).background(.ultraThinMaterial, in: Capsule()))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .offset(y: 86)
                .transition(.opacity)
            }
        }
        .frame(width: 200, height: 196)
        .scaleEffect(scale)
        .frame(height: 196 * scale + (isTyping ? 0 : 16))
    }

    /// 写真が入れかわり待ちのときだけ:「あしたの朝 9:00 に、入れかわります」+「取り消す」
    private var pendingLine: some View {
        HStack(spacing: 10) {
            Text(pendingText)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Self.orange)
            Button("取り消す") { cancelPhoto() }
                .font(.system(size: 10.5, design: .monospaced))
                .underline()
                .foregroundStyle(Self.orange)
                .buttonStyle(.plain)
        }
    }

    private var pendingText: String {
        guard let revealAt = profile?.pendingProfileImageRevealAt else { return "あしたの朝 9:00 に、入れかわります" }
        return Calendar.current.isDateInToday(revealAt) ? "けさ 9:00 に、入れかわります" : "あしたの朝 9:00 に、入れかわります"
    }

    // MARK: 名前

    private var nameField: some View {
        VStack(spacing: 0) {
            TextField("", text: $name, prompt: Text("名前").foregroundStyle(Color(hex: "3A3A3E")))
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.05 * 32)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(22 / 32)
                .lineLimit(1)
                .foregroundStyle(.white)
                .tint(.white)
                .focused($isNameFocused)
                .submitLabel(.done)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { isNameFocused = false }
                .onChange(of: name) { _, value in
                    if value.count > OnboardingRules.nameMaxLength + 4 { name = String(value.prefix(OnboardingRules.nameMaxLength + 4)) }
                }
                .frame(height: 48)
                .accessibilityLabel("名前")
            Rectangle()
                .fill(.white.opacity(isNameFocused ? 0.9 : 0.3))
                .frame(height: 1.5)
                .shadow(color: .white.opacity(isNameFocused ? 0.6 : 0), radius: 6)
                .animation(.easeOut(duration: 0.3), value: isNameFocused)
            HStack {
                Text(nameNote)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(validation.problem == nil || validation.problem == .empty ? Color(hex: "6B6B70") : Self.orange)
                Spacer()
                Text("\(validation.name.count) / \(OnboardingRules.nameMaxLength)")
                    .font(.system(size: 10, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: "6B6B70"))
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 40)
    }

    private var nameNote: String {
        switch validation.problem {
        case .looksLikeContact: return "URL・メールアドレスは使えません"
        case .tooLong: return "12文字までです"
        case .empty, nil: return "名前 ・ 本名でなくて大丈夫です"
        }
    }

    // MARK: タグ

    private var tagsSection: some View {
        let isFull = tags.count >= OnboardingRules.maxSelfTags
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("自分を表すタグ")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(tags.count) / \(OnboardingRules.maxSelfTags)")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Color(hex: "8E8E93"))
            }
            OnboardingFlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    tagChip(tag)
                }
                // 3つのときの薄い「＋ 追加」は、入力中は隠す
                if !(isFull && isTyping) {
                    Button { openTagCandidates() } label: {
                        Text("＋ 追加")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "8E8E93"))
                            .padding(.horizontal, 15)
                            .frame(height: 40)
                            .overlay(Capsule().strokeBorder(Color(hex: "3A3A3E"), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                    }
                    .buttonStyle(.plain)
                    .disabled(isFull)
                    .opacity(isFull ? 0.35 : 1)
                    .accessibilityLabel("タグを追加")
                }
            }
            if isAddingTag && !isFull {
                candidatesPanel.transition(.opacity)
            }
        }
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.25), value: tags)
        .animation(.easeInOut(duration: 0.25), value: isAddingTag)
    }

    /// 変更したチップ(元になかった)は、橙の縁(1.5pt)で示す(保存するまで)
    private func tagChip(_ tag: String) -> some View {
        let changed = !originalTags.contains(tag)
        return Button { removeTag(tag) } label: {
            HStack(spacing: 6) {
                Text("#\(tag)").font(.system(size: 14, weight: .semibold))
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).opacity(0.6)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 15)
            .frame(height: 40)
            .background(Capsule().fill(.white.opacity(0.1)))
            .overlay(Capsule().strokeBorder(changed ? Self.orange : .white.opacity(0.12), lineWidth: changed ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tag)。押すと外します")
    }

    /// 「＋ 追加」:候補(固定の一覧・最大6つ)+ 自由入力。数字・順位・「人気」は出さない
    private var candidatesPanel: some View {
        let candidates = Array(OnboardingCopy.selfTagCandidates.filter { !tags.contains($0) }.prefix(6))
        return VStack(alignment: .leading, spacing: 10) {
            Text("候補")
                .font(.system(size: 9.5, design: .monospaced))
                .tracking(0.16 * 9.5)
                .foregroundStyle(Color(hex: "6B6B70"))
            OnboardingFlowLayout(spacing: 8) {
                ForEach(candidates, id: \.self) { tag in
                    Button { addTag(tag) } label: {
                        Text("#\(tag)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(OnboardingPalette.quietText)
                            .padding(.horizontal, 15)
                            .frame(height: 38)
                            .background(Capsule().fill(OnboardingPalette.surface))
                    }
                    .buttonStyle(PressScaleStyle(scale: 0.96))
                }
            }
            HStack(spacing: 4) {
                Text("#").foregroundStyle(Color(hex: "8E8E93"))
                TextField("", text: $tagDraft, prompt: Text("自由に書く").foregroundStyle(Color(hex: "4A4A50")))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .focused($isTagFocused)
                    .submitLabel(.done)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: tagDraft) { _, value in
                        let cleaned = String(value.filter { $0 != "#" && $0 != "＃" && !$0.isWhitespace }.prefix(OnboardingRules.tagMaxLength))
                        if cleaned != value { tagDraft = cleaned }
                    }
                    .onSubmit {
                        if let tag = OnboardingRules.normalizedTag(tagDraft) { addTag(tag) }
                        tagDraft = ""
                    }
                    .accessibilityLabel("タグ、入力欄")
            }
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
        }
        .padding(.top, 4)
    }

    // MARK: 下(保存)

    @ViewBuilder
    private var bottomBar: some View {
        if isDirty {
            Button(action: save) {
                Text("保存する")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Capsule().fill(.white))
                    .opacity(validation.problem == nil ? 1 : 0.35)
            }
            .buttonStyle(PressScaleStyle(scale: 0.97))
            .disabled(validation.problem != nil)
            .padding(.horizontal, 22)
            .transition(.opacity.combined(with: .offset(y: 12)))
        } else if !isTyping {
            Text("変えたいところを、押してください")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(hex: "6B6B70"))
                .frame(height: 58)
                .transition(.opacity)
        }
    }

    // MARK: シート

    private var retakeSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("プロフィールの写真を、撮りなおす")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 10) {
                sheetBullet("プレビューは出ません。撮りなおしもできません")
                sheetBullet("いまの写真は、あしたの朝 9:00 まで、そのまま")
                sheetBullet("顔である必要はありません。景色でも、手元でも。")
            }
            .padding(.top, 18)
            Button {
                showingRetakeSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showingCamera = true }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "circle.circle").font(.system(size: 16, weight: .semibold))
                    Text("カメラをひらく").font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Capsule().fill(.white))
            }
            .buttonStyle(PressScaleStyle(scale: 0.97))
            .padding(.top, 24)
            Button("やめる") { showingRetakeSheet = false }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .buttonStyle(.plain)
                .padding(.top, 6)
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 12)
        .presentationDetents([.height(380)])
        .presentationCornerRadius(34)
        .presentationBackground(.ultraThinMaterial)
    }

    private var discardSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("変更を、保存しますか?")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
            Text("保存しないと、変更はなくなります。")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "BCBBC0"))
                .padding(.top, 8)
            Button {
                showingDiscard = false
                save()
            } label: {
                Text("保存する")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(PressScaleStyle(scale: 0.97))
            .disabled(validation.problem != nil)
            .opacity(validation.problem == nil ? 1 : 0.35)
            .padding(.top, 22)
            Button {
                showingDiscard = false
                discardAndClose()
            } label: {
                Text("変更を捨てて、とじる")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "FF6B5E"))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Capsule().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .presentationDetents([.height(270)])
        .presentationCornerRadius(34)
        .presentationBackground(.ultraThinMaterial)
    }

    private func sheetBullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle().fill(.white.opacity(0.5)).frame(width: 4, height: 4).offset(y: -3)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: 動き

    private func load() {
        haptics.prepare()
        guard !hasLoaded, let profile else { return }
        hasLoaded = true
        originalName = profile.name
        originalTags = profile.selfTags
        name = profile.name
        tags = profile.selfTags
        switch initialFocus {
        case .photo: DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showingRetakeSheet = true }
        case .name: DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isNameFocused = true }
        case .tags: isAddingTag = tags.count < OnboardingRules.maxSelfTags
        case .none: break
        }
    }

    /// ごく軽く1回(えらぶ)
    private func choose() {
        haptics.playTransient(intensity: 0.3, sharpness: 0.5)
    }

    private func openRetake() {
        isNameFocused = false
        isTagFocused = false
        showingRetakeSheet = true
    }

    private func openTagCandidates() {
        guard tags.count < OnboardingRules.maxSelfTags else { return }
        isAddingTag.toggle()
    }

    private func addTag(_ tag: String) {
        guard !tags.contains(tag), tags.count < OnboardingRules.maxSelfTags else { return }
        choose()
        tags.append(tag)
        // 3つになったら、候補の段は閉じる
        if tags.count >= OnboardingRules.maxSelfTags {
            isAddingTag = false
            isTagFocused = false
        }
    }

    private func removeTag(_ tag: String) {
        choose()
        tags.removeAll { $0 == tag }
    }

    private func cancelPhoto() {
        guard let profile else { return }
        choose()
        ProfilePhotoDevelopment.cancelPending(for: profile, context: modelContext)
        tookPhotoHere = false
    }

    /// 名前・タグを保存して、とじる(写真は撮った時点で預けてある)。グループのみんなにも、すぐ同期
    private func save() {
        guard let profile, validation.problem == nil else { return }
        choose()
        profile.name = validation.name
        profile.selfTags = tags
        profile.profileUpdatedAt = Date()
        try? modelContext.save()
        userName = profile.name
        if let cloudKitManager = CloudKitManager.current {
            for group in profile.groups {
                cloudKitManager.markForUpload(userProfile: profile, in: group)
            }
        }
        Task { await UserDirectoryService.publish(profile) }
        dismiss()
    }

    private func requestClose() {
        isNameFocused = false
        isTagFocused = false
        if isDirty {
            showingDiscard = true
        } else {
            dismiss()
        }
    }

    /// 変更を捨てる:この画面で撮った写真も、入れかわり待ちから外す
    private func discardAndClose() {
        if tookPhotoHere, let profile {
            ProfilePhotoDevelopment.cancelPending(for: profile, context: modelContext)
        }
        dismiss()
    }
}
