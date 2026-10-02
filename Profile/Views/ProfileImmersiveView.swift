import SwiftUI
import SwiftData
import UIKit

/// プロフィール(没入版)。「あなたの玉」と「あなたが預けてきた日々」を、静かに眺める場所。
/// 自分だけが見る画面で、いいね・フォロワー・連続日数は出さない。
///
/// 上から:編集・設定のガラスボタン → ガラスの球(プロフィール画像)→ 名前と「LATER ・ 08.14 から」
/// → 自分を表すタグ →(書いた時だけ)ひとこと → 預けた日々(1日1点の渦)。
/// 色は写真から取った色だけを使う。
struct ProfileImmersiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.selectedMainTabIndex) private var selectedMainTabIndex

    @Query private var profiles: [UserProfile]
    @Query(sort: \ExposureDay.captureDate, order: .reverse) private var exposureDays: [ExposureDay]

    @AppStorage("profileBallColorHex") private var cachedBallColorHex: String = ""
    @AppStorage("profileBallColorKey") private var cachedBallColorKey: String = ""

    @State private var isOnScreen = false
    @State private var tilt = GlassTilt()
    @State private var haptics = ExposureHaptics()
    @State private var editFocus: ProfileEditFocus?
    @State private var isShowingSettings = false
    @State private var ballFocus: Double = 1
    @State private var cloudEntranceStart: Date?
    /// 0 = 真珠、1 = 写真(初めて現像された瞬間の演出で0→1)
    @State private var revealProgress: Double = 1
    @State private var lastSelectionHaptic = Date.distantPast

    /// アプリを起動して最初にProfileを開いた時だけ登場演出を再生する。
    private static var hasPlayedEntrance = false
    private static let profileTabIndex = 1
    private static let thumbnailCache = NSCache<NSString, UIImage>()

    private var profile: UserProfile? { UserProfile.current(from: profiles) }

    private var isVisible: Bool {
        isOnScreen && scenePhase == .active && selectedMainTabIndex == Self.profileTabIndex
            && editFocus == nil && !isShowingSettings
    }

    private var profileImage: UIImage? {
        profile?.profileImageData.flatMap(UIImage.init(data:))
    }

    private var ballColor: Color? {
        guard profileImage != nil, !cachedBallColorHex.isEmpty else { return nil }
        return Color(hex: cachedBallColorHex)
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(1, proxy.size.height / 844)
            ZStack(alignment: .top) {
                Color.black

                backgroundGlow
                    .frame(height: 420)
                    .frame(maxHeight: .infinity, alignment: .top)

                header
                    .padding(.horizontal, 20)
                    .position(x: proxy.size.width / 2, y: 58 * scale + 22)

                GlassBall(
                    image: profileImage,
                    glowColor: ballColor,
                    tiltX: tilt.x,
                    tiltY: tilt.y,
                    revealProgress: revealProgress
                )
                .blur(radius: 14 * (1 - ballFocus))
                .opacity(ballFocus)
                .position(x: proxy.size.width / 2, y: 180 * scale)
                .onTapGesture { editFocus = .photo }
                .accessibilityElement()
                .accessibilityLabel("プロフィール画像")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { editFocus = .photo }

                nameBlock
                    .position(x: proxy.size.width / 2, y: 300 * scale)

                tagRow
                    .position(x: proxy.size.width / 2, y: 372 * scale + 18)

                if let bio = profile?.bio.trimmingCharacters(in: .whitespacesAndNewlines), !bio.isEmpty {
                    Text(String(bio.prefix(ProfileEditRules.bioMaxLength)))
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "BCBBC0"))
                        .lineLimit(1)
                        .padding(.horizontal, 32)
                        .position(x: proxy.size.width / 2, y: 422 * scale + 8)
                }

                daysSection(scale: scale, width: proxy.size.width)
                    .position(x: proxy.size.width / 2, y: 468 * scale + 132)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea(edges: .top)
        .overlay {
            FilmGrainOverlay(opacity: 0.05, blendMode: .normal)
                .ignoresSafeArea()
        }
        .onAppear {
            isOnScreen = true
            haptics.prepare()
            updateBallColorIfNeeded()
            playEntranceIfNeeded()
            playRevealIfNeeded()
        }
        .onDisappear { isOnScreen = false }
        .onChange(of: isVisible) { _, visible in
            updateMotion(visible: visible)
            if visible { playRevealIfNeeded() }
        }
        .onChange(of: profile?.profileImageData) { _, _ in
            updateBallColorIfNeeded()
            playRevealIfNeeded()
        }
        .sheet(item: $editFocus) { focus in
            ProfileEditSheet(initialFocus: focus)
        }
        .fullScreenCover(isPresented: $isShowingSettings) {
            SettingsMenuView(isShowing: $isShowingSettings)
        }
    }

    // MARK: - 背景の光(写真の中心の色、真珠の時は白)

    private var backgroundGlow: some View {
        GeometryReader { proxy in
            Ellipse()
                .fill(RadialGradient(
                    colors: [(ballColor ?? .white).opacity(ballColor == nil ? 0.16 : 0.22), .clear],
                    center: .center, startRadius: 0, endRadius: proxy.size.width * 0.7
                ))
                .frame(width: proxy.size.width * 1.5, height: 460)
                .position(x: proxy.size.width / 2, y: 0)
                .animation(.easeInOut(duration: 1.0), value: cachedBallColorHex)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - ヘッダー(編集・設定)

    private var header: some View {
        HStack {
            GlassCircleButton(systemImage: "pencil", label: "編集") { editFocus = ProfileEditFocus.none }
            Spacer()
            GlassCircleButton(systemImage: "slider.horizontal.3", label: "設定") { isShowingSettings = true }
        }
    }

    // MARK: - 名前と補足

    private var nameBlock: some View {
        VStack(spacing: 10) {
            Text(profile?.name.isEmpty == false ? profile!.name : "Later")
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.05 * 34)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 32)
                .onTapGesture { editFocus = .name }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("名前を編集します")

            Text("LATER ・ \(Self.sinceFormatter.string(from: sinceDate)) から")
                .font(.system(size: 10, design: .monospaced))
                .tracking(0.14 * 10)
                .foregroundStyle(.white.opacity(0.45))
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
        }
    }

    /// 最初に撮った日(なければ初回設定を終えた日)。
    private var sinceDate: Date {
        if let first = exposureDays.last?.captureDate { return first }
        if let completed = UserDefaults.standard.object(forKey: "onboardingCompletedAt") as? Date { return completed }
        return Date()
    }

    private static let sinceFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM.dd"
        return formatter
    }()

    // MARK: - タグ

    @ViewBuilder
    private var tagRow: some View {
        let tags = profile?.selfTags ?? []
        if tags.isEmpty {
            Button { editFocus = .tags } label: {
                Text("タグを足す")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "BCBBC0"))
                    .padding(.vertical, 9)
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 9)
                        .background(GlassCapsule())
                }
                if tags.count < OnboardingRules.maxSelfTags {
                    Text("+")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "BCBBC0"))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .overlay(Capsule().strokeBorder(Color(hex: "BCBBC0").opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                        .accessibilityLabel("タグを足す")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { editFocus = .tags }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("タグを編集します")
        }
    }

    // MARK: - 預けた日々

    private var dayPoints: [DayPoint] {
        let calendar = Calendar.current
        let photoCutoff = calendar.date(byAdding: .day, value: -DayCloudRules.photoVisibleDays, to: calendar.startOfDay(for: Date())) ?? .distantPast
        return exposureDays.enumerated().map { index, day in
            // その日より後に撮っていれば、その日の1枚はひらいている(最新の日だけ、まだひらいていない)。
            let opened = index > 0
            return DayPoint(
                id: day.dayKey,
                date: day.captureDate,
                opened: opened,
                color: opened ? day.colorHex.map { Color(hex: $0) } : nil,
                locationName: day.locationName,
                showsPhoto: opened && day.captureDate >= photoCutoff
            )
        }
    }

    private func daysSection(scale: CGFloat, width: CGFloat) -> some View {
        let points = dayPoints
        return VStack(spacing: 0) {
            HStack {
                Text("預けた日々")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(Color(hex: "BCBBC0"))
                Spacer()
                Text("\(points.count)日")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
            }
            .padding(.horizontal, 24)
            .accessibilityElement(children: .combine)

            Group {
                if points.isEmpty {
                    Color.clear
                } else {
                    DayCloudView(
                        points: points,
                        isAnimating: isVisible,
                        entranceStart: cloudEntranceStart,
                        thumbnailFor: thumbnail(for:),
                        onSelectionChange: selectionChanged,
                        onTapDay: { _ in
                            // その日の詳細を開く入口(別のStepで作る)。
                        }
                    )
                }
            }
            .frame(height: DayCloudView.height)
            .padding(.top, 8)

            Text(points.count <= 1 ? "ここに、預けた日々が積もっていきます" : "なぞると、その日が見える")
                .font(.system(size: 9.5, design: .monospaced))
                .tracking(0.12 * 9.5)
                .foregroundStyle(Color(hex: "5F5F64"))
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .padding(.top, 4)
                .accessibilityHidden(points.count > 1)
        }
        .frame(width: width)
    }

    private func thumbnail(for point: DayPoint) -> UIImage? {
        guard point.opened, point.showsPhoto else { return nil }
        let key = point.id as NSString
        if let cached = Self.thumbnailCache.object(forKey: key) { return cached }
        guard let data = exposureDays.first(where: { $0.dayKey == point.id })?.thumbnailData,
              let image = UIImage(data: data) else { return nil }
        Self.thumbnailCache.setObject(image, forKey: key)
        return image
    }

    /// 選択中の点が切り替わるたびに、ごく軽く1回(最短60ms間隔)。ひらいていない点は、ほんの少し弱く。
    private func selectionChanged(_ point: DayPoint?) {
        guard let point, ProfileTuning.tracingHapticEnabled else { return }
        let now = Date()
        guard now.timeIntervalSince(lastSelectionHaptic) >= ProfileTuning.tracingHapticMinInterval else { return }
        lastSelectionHaptic = now
        let value = point.opened ? ProfileTuning.tracingHaptic : ProfileTuning.tracingHapticUnopened
        haptics.playTransient(intensity: value.intensity, sharpness: value.sharpness)
    }

    // MARK: - 動き

    private func updateMotion(visible: Bool) {
        if visible && !reduceMotion {
            tilt.start()
        } else {
            tilt.stop()
        }
    }

    private func playEntranceIfNeeded() {
        guard !Self.hasPlayedEntrance else { return }
        Self.hasPlayedEntrance = true
        guard !reduceMotion else { return }
        ballFocus = 0
        withAnimation(.easeOut(duration: 0.8)) { ballFocus = 1 }
        cloudEntranceStart = Date()
    }

    /// 初めてプロフィール画像が現像された時に一度だけ:だんだん強く → 玉に写真が入る瞬間にくっきり1回。
    private func playRevealIfNeeded() {
        let defaults = UserDefaults.standard
        guard isOnScreen, profileImage != nil, defaults.bool(forKey: ProfilePhotoDevelopment.revealPendingKey) else { return }
        defaults.set(false, forKey: ProfilePhotoDevelopment.revealPendingKey)
        if reduceMotion {
            revealProgress = 0
            withAnimation(.easeInOut(duration: 0.25)) { revealProgress = 1 }
            return
        }
        revealProgress = 0
        haptics.playRamp(from: 0.15, to: 0.7, sharpness: 0.2, sharpnessTo: 0.5, duration: 1.0)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            haptics.fireCapture(intensity: 1.0, sharpness: 0.9)
            withAnimation(.easeOut(duration: 1.2)) { revealProgress = 1 }
        }
    }

    /// 写真の中心の色は、画像が変わった時に1度だけ計算して保存する。
    private func updateBallColorIfNeeded() {
        guard let profile, let data = profile.profileImageData else { return }
        let key = "\(data.count)-\(profile.profileUpdatedAt?.timeIntervalSince1970 ?? 0)"
        guard key != cachedBallColorKey else { return }
        Task.detached(priority: .utility) {
            let hex = UIImage(data: data).flatMap { PhotoColor.centerColorHex(of: $0) }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 1.0)) {
                    cachedBallColorHex = hex ?? ""
                }
                cachedBallColorKey = key
            }
        }
    }
}

/// 実機で調整するための数値(プロフィール)。
enum ProfileTuning {
    /// なぞって選択中の点が切り替わるたびの触覚。うるさければfalseにするか弱める。
    static let tracingHapticEnabled = true
    static let tracingHaptic: (intensity: Float, sharpness: Float) = (0.3, 0.6)
    static let tracingHapticUnopened: (intensity: Float, sharpness: Float) = (0.2, 0.4)
    static let tracingHapticMinInterval: TimeInterval = 0.06
}

// MARK: - ガラスの球

/// 中にプロフィール画像が入ったガラスの球(直径176pt)。傾けるとハイライトと底の光が動く。
/// プロフィール画像がまだ現像されていない時は、真珠 + 呼吸する白い点。
private struct GlassBall: View {
    let image: UIImage?
    let glowColor: Color?
    let tiltX: Double
    let tiltY: Double
    let revealProgress: Double

    static let diameter: CGFloat = 176

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false

    private var showsPearl: Bool { image == nil || revealProgress < 1 }

    var body: some View {
        let d = Self.diameter
        ZStack {
            // 1. 背後の光(写真の中心の色、34%)
            Circle()
                .fill(RadialGradient(colors: [(glowColor ?? .white).opacity(glowColor == nil ? 0.18 : 0.34), .clear], center: .center, startRadius: d * 0.3, endRadius: d / 2 + 70))
                .frame(width: d + 140, height: d + 140)

            ZStack {
                if showsPearl {
                    pearl
                        .opacity(image == nil ? 1 : 1 - revealProgress)
                }
                if let image {
                    // 2. 写真(わずかに大きく置いて、周辺をぼかす)
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: d * 1.06, height: d * 1.06)
                        .blur(radius: 0.6 + 14 * (1 - revealProgress))
                        .opacity(revealProgress)
                    // 3. 周辺減光
                    RadialGradient(stops: [.init(color: .clear, location: 0.52), .init(color: .black.opacity(0.55), location: 1)], center: .center, startRadius: 0, endRadius: d / 2)
                        .opacity(revealProgress)
                }
                // 4. 底の光(コースティクス)。ハイライトと逆方向に動く。
                Ellipse()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 170 / 255, blue: 110 / 255).opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 40))
                    .frame(width: 84, height: 30)
                    .offset(x: d * 0.02 - 9 * tiltX, y: d * 0.46 - 5 * tiltY)
                    .blendMode(.screen)
                // 5. 内側の影(下から黒、上から白)
                LinearGradient(stops: [.init(color: .white.opacity(0.1), location: 0), .init(color: .clear, location: 34 / d), .init(color: .clear, location: 1 - 44 / d), .init(color: .black.opacity(0.5), location: 1)], startPoint: .top, endPoint: .bottom)
                // 7. ハイライト(左上の白い楕円、-26度)
                Ellipse()
                    .fill(RadialGradient(colors: [.white.opacity(0.7), .white.opacity(0)], center: .center, startRadius: 0, endRadius: 46))
                    .frame(width: 92, height: 62)
                    .rotationEffect(.degrees(-26))
                    .offset(x: -d * 0.2 + 17 * tiltX, y: -d * 0.25 + 12 * tiltY)
            }
            .frame(width: d, height: d)
            .clipShape(Circle())
            // 6. 縁
            .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1.5))
        }
        .frame(width: d, height: d)
    }

    private var pearl: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: Color(hex: "E9ECF0"), location: 0.24),
                        .init(color: Color(hex: "9AA1AB"), location: 0.6),
                        .init(color: Color(hex: "2B2F35"), location: 1),
                    ],
                    center: UnitPoint(x: 0.34, y: 0.26), startRadius: 0, endRadius: Self.diameter
                ))
            Circle()
                .fill(.white)
                .frame(width: 12, height: 12)
                .shadow(color: .white.opacity(0.9), radius: 8)
                .scaleEffect(isBreathing ? 1.35 : 1)
                .opacity(isBreathing ? 0.7 : 1)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { isBreathing = true }
        }
    }
}

// MARK: - ガラスの部品

private struct GlassCircleButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(LinearGradient(colors: [.white.opacity(0.13), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                )
                .overlay(Circle().strokeBorder(.white.opacity(0.09), lineWidth: 1))
                .overlay(alignment: .top) {
                    Capsule().fill(.white.opacity(0.14)).frame(width: 18, height: 1).padding(.top, 1)
                }
                .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct GlassCapsule: View {
    var body: some View {
        Capsule()
            .fill(LinearGradient(colors: [.white.opacity(0.13), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom))
            .overlay(Capsule().strokeBorder(.white.opacity(0.09), lineWidth: 1))
    }
}

// MARK: - 編集シート

enum ProfileEditFocus: String, Identifiable {
    case none, photo, name, tags
    var id: String { rawValue }
}

enum ProfileEditRules {
    static let bioMaxLength = 30
}

/// 名前・自分を表すタグ・ひとことの編集と、プロフィール画像の撮り直し(1日1回まで)。
/// 詳しいデザインは別の機会。
private struct ProfileEditSheet: View {
    let initialFocus: ProfileEditFocus

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @AppStorage("userName") private var userName: String = ""

    @State private var name = ""
    @State private var tags: [String] = []
    @State private var bio = ""
    @State private var hasLoaded = false
    @State private var isShowingCamera = false
    @State private var canRetake = ProfilePhotoDevelopment.canRetake()
    @FocusState private var isNameFocused: Bool

    private var profile: UserProfile? { UserProfile.current(from: profiles) }
    private var nameValidation: (name: String, problem: OnboardingRules.NameProblem?) { OnboardingRules.validateName(name) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        section("プロフィール画像") {
                            photoSection
                        }
                        .id(ProfileEditFocus.photo)

                        section("名前") {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("名前", text: $name)
                                    .font(.system(size: 22, weight: .semibold))
                                    .focused($isNameFocused)
                                    .padding(14)
                                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: "1C1C1E")))
                                Text(nameHint)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(hex: "8E8E93"))
                            }
                        }
                        .id(ProfileEditFocus.name)

                        section("自分を表すタグ") {
                            SelfTagPicker(selectedTags: $tags)
                        }
                        .id(ProfileEditFocus.tags)

                        section("ひとこと") {
                            VStack(alignment: .trailing, spacing: 6) {
                                TextField("書いたときだけ、プロフィールに出ます", text: $bio)
                                    .font(.system(size: 15))
                                    .padding(14)
                                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: "1C1C1E")))
                                    .onChange(of: bio) { _, value in
                                        if value.count > ProfileEditRules.bioMaxLength {
                                            bio = String(value.prefix(ProfileEditRules.bioMaxLength))
                                        }
                                    }
                                Text("\(bio.count) / \(ProfileEditRules.bioMaxLength)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Color(hex: "8E8E93"))
                            }
                        }
                    }
                    .padding(20)
                }
                .onAppear {
                    load()
                    reader.scrollTo(initialFocus, anchor: .top)
                    if initialFocus == .name { isNameFocused = true }
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("プロフィール")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(nameValidation.problem != nil)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationBackground(.black)
        .fullScreenCover(isPresented: $isShowingCamera) {
            ExposureCameraView(
                hasShotToday: false,
                onCaptured: { data, start, _, _ in
                    guard let profile else { return false }
                    ProfilePhotoDevelopment.storeRetake(data, for: profile, takenAt: start, context: modelContext)
                    canRetake = ProfilePhotoDevelopment.canRetake()
                    return true
                },
                onFinished: { isShowingCamera = false },
                onClose: { isShowingCamera = false },
                purpose: .profilePhoto
            )
        }
    }

    private var nameHint: String {
        switch nameValidation.problem {
        case .looksLikeContact: return "URLやメールアドレスは使えません。"
        case .tooLong: return "12文字までにしてください。"
        case .empty: return "1〜12文字で入力してください。"
        case nil: return "本名でなくて大丈夫です。"
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isShowingCamera = true
            } label: {
                Label("撮り直す", systemImage: "camera.aperture")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(canRetake ? .black : Color(hex: "8E8E93"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Capsule().fill(canRetake ? Color.white : Color(hex: "1C1C1E")))
            }
            .buttonStyle(.plain)
            .disabled(!canRetake)
            Text(photoHint)
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "8E8E93"))
        }
    }

    private var photoHint: String {
        if profile?.pendingProfileImageData != nil {
            return "撮った1枚は、次の 9:00 に現像されます。それまで、あなたにも見えません。"
        }
        if !canRetake {
            return "撮り直しは、1日\(ProfilePhotoDevelopment.maxRetakesPerDay)回までです。"
        }
        return "プレビューなしで撮ります。次の 9:00 に現像されます。"
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(Color(hex: "BCBBC0"))
            content()
        }
    }

    private func load() {
        guard !hasLoaded, let profile else { return }
        hasLoaded = true
        name = profile.name
        tags = profile.selfTags
        bio = String(profile.bio.prefix(ProfileEditRules.bioMaxLength))
    }

    private func save() {
        guard let profile, nameValidation.problem == nil else { return }
        profile.name = nameValidation.name
        profile.selfTags = tags
        profile.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
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
}
