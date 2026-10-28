import SwiftData
import SwiftUI
import UserNotifications

/// 設定(Profile のピルの「設定」から)。黒×白のガラス。並びは よく触る順:
/// 毎日 → みんなと → 安全 → Later について → アカウント。行は増やさない(新しい項目は先に確認する)。
struct SettingsMenuView: View {
    @Binding var isShowing: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]
    @Query private var blocked: [BlockedUser]

    @AppStorage("appleUserID") private var appleUserID: String = ""
    @AppStorage("appleFullName") private var appleFullName: String = ""
    @AppStorage("firebaseUID") private var firebaseUID: String = ""
    @AppStorage("firebaseEmail") private var firebaseEmail: String = ""
    @AppStorage("currentProfileID") private var currentProfileID: String = ""
    @AppStorage("isSetupCompleted") private var isSetupCompleted: Bool = false

    @State private var haptics = ExposureHaptics()
    @State private var notificationOn = false
    @State private var hapticsOn = AppHapticsSetting.isEnabled
    @State private var mondoOn = MondoService.isPublic
    @State private var showingNotificationDenied = false
    @State private var showingSignOutConfirm = false
    @State private var showingDeletion = false
    @State private var showingEdit = false
    @State private var showingGroups = false
    @State private var showingBlocked = false
    @State private var showingPromise = false
    @State private var showingHowTo = false
    @State private var showingShootGuide = false
    @State private var showingPrivacy = false
    @State private var showingWidgetSetup = false

    private var profile: UserProfile? { UserProfile.current(from: profiles) }
    private var sharedGroups: [LaterGroup] {
        guard let profile else { return [] }
        return profile.groups.filter { !$0.isPersonalSpace }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            // 上端に、白の淡い放射グラデを1枚だけ
            RadialGradient(colors: [.white.opacity(0.10), .clear], center: .top, startRadius: 0, endRadius: 420)
                .frame(height: 420)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    myCard
                        .padding(.top, 60)
                    sections
                    Text("写真は、撮ってから7日で消えます")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color(hex: "5F5F64"))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)
                        .padding(.bottom, 40)

                    #if DEBUG
                    LaunchDebugSection { info in
                        close()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            NotificationCenter.default.post(name: .replayLaunchAnimation, object: nil, userInfo: info)
                        }
                    }
                    .padding(.bottom, 40)
                    ThemeDebugSection()
                        .padding(.bottom, 40)
                    #endif
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            // 上の112ptは、黒から透明へのフェードで、スクロールした行を静かに隠す
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: 112)
                    Color.black
                }
                .ignoresSafeArea()
            )

            header
        }
        .onAppear {
            haptics.prepare()
            Task { notificationOn = await DailyOpenNotification.isScheduled() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { notificationOn = await DailyOpenNotification.isScheduled() } }
        }
        .alert("お知らせが、オフになっています", isPresented: $showingNotificationDenied) {
            Button("設定をひらく") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button("とじる", role: .cancel) {}
        } message: {
            Text("iPhone の設定で、Later の通知を許可してください。")
        }
        .alert("ログアウトしますか?", isPresented: $showingSignOutConfirm) {
            Button("ログアウト", role: .destructive) { signOut() }
            Button("やめる", role: .cancel) {}
        }
        // 削除のシートの間、後ろを黒60%で暗く
        .overlay {
            Color.black.opacity(showingDeletion ? 0.6 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.3), value: showingDeletion)
        }
        .sheet(isPresented: $showingDeletion) {
            AccountDeletionView(groupCount: sharedGroups.count, onDeleted: close)
        }
        .fullScreenCover(isPresented: $showingEdit) { ProfileEditScreen(initialFocus: .none) }
        .sheet(isPresented: $showingGroups) { SettingsGroupsList(groups: sharedGroups, onOpen: openGroup) }
        .sheet(isPresented: $showingBlocked) { SettingsBlockedList() }
        .sheet(isPresented: $showingPromise) { LaterPromiseView() }
        .fullScreenCover(isPresented: $showingHowTo) { HowToReplayView() }
        .fullScreenCover(isPresented: $showingShootGuide) { ShootGuideReplayView() }
        .sheet(isPresented: $showingPrivacy) { PrivacyPolicyView() }
        .fullScreenCover(isPresented: $showingWidgetSetup) {
            WidgetSetupFlow(start: .chooser) { _ in showingWidgetSetup = false }
        }
    }

    // MARK: 上

    private var header: some View {
        ZStack {
            Text("設定")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button(action: close) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.white.opacity(0.1)).background(.ultraThinMaterial, in: Circle()))
                        .overlay(Circle().strokeBorder(.white.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("もどる")
                Spacer()
            }
            .padding(.horizontal, 22)
        }
        .frame(height: 44)
        .padding(.top, 4)
    }

    /// 自分のカード:小さな球 + 名前 + 「LATER ・ 08.14 から」+「編集 ›」。タップで編集画面へ
    private var myCard: some View {
        Button { showingEdit = true } label: {
            HStack(spacing: 14) {
                ProfileBall(profile: profile, diameter: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile?.name ?? "")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(LaterSince.text)
                        .font(.system(size: 10, design: .monospaced))
                        .tracking(0.1 * 10)
                        .foregroundStyle(Color(hex: "8E8E93"))
                }
                Spacer(minLength: 8)
                Text("編集 ›")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "BCBBC0"))
            }
            .padding(16)
            .background(SettingsGlass(cornerRadius: 28))
            .contentShape(RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(SettingsPressStyle(cornerRadius: 28))
        .accessibilityLabel("\(profile?.name ?? "")。プロフィールを編集")
    }

    // MARK: セクション

    @ViewBuilder
    private var sections: some View {
        SettingsSection(title: "毎日") {
            SettingsRow(icon: "bell", title: "9:00 のお知らせ", note: "毎朝、撮影のスタートを知らせます") {
                Toggle("9:00 のお知らせ", isOn: Binding(get: { notificationOn }, set: setNotification))
                    .toggleStyle(MonoToggleStyle())
                    .accessibilityLabel("9:00 のお知らせ")
            }
            SettingsDivider()
            SettingsRow(icon: "hand.tap", title: "触覚", note: "撮る・ひらく・えらぶ のときだけ") {
                Toggle("触覚", isOn: Binding(get: { hapticsOn }, set: setHaptics))
                    .toggleStyle(MonoToggleStyle())
                    .accessibilityLabel("触覚")
            }
            SettingsDivider()
            SettingsRow(icon: "square.grid.2x2", title: "ウィジェットの置き方", action: { showingWidgetSetup = true }) {
                SettingsValue("", chevron: true)
            }
        }
        SettingsSection(title: "みんなと") {
            SettingsRow(icon: "circle.grid.2x2", title: "グループ", action: { showingGroups = true }) {
                SettingsValue("\(sharedGroups.count) / \(GroupMembershipPolicy.maxGroupsPerUser)", chevron: true)
            }
            SettingsDivider()
            SettingsRow(icon: "globe", title: "Mondo に写真を出す", note: "世界の昨日に、1枚が並びます") {
                Toggle("Mondo に写真を出す", isOn: Binding(get: { mondoOn }, set: setMondo))
                    .toggleStyle(MonoToggleStyle())
                    .accessibilityLabel("Mondo に写真を出す")
            }
        }
        SettingsSection(title: "安全") {
            SettingsRow(icon: "hand.raised", title: "通報・ブロックした人", action: { showingBlocked = true }) {
                SettingsValue("\(blocked.count)", chevron: true)
            }
        }
        SettingsSection(title: "Later について") {
            SettingsRow(icon: "heart.slash", title: "Later の約束", note: "いいねも、フォロワー数も、ありません", action: { showingPromise = true }) {
                SettingsValue("", chevron: true)
            }
            SettingsDivider()
            SettingsRow(icon: "sun.horizon", title: "使い方を、もういちど", action: { showingHowTo = true }) {
                SettingsValue("", chevron: true)
            }
            SettingsDivider()
            SettingsRow(icon: "camera", title: "撮影のしかた", action: { showingShootGuide = true }) {
                SettingsValue("", chevron: true)
            }
            SettingsDivider()
            SettingsRow(icon: "doc.text", title: "利用規約・プライバシー", action: { showingPrivacy = true }) {
                SettingsValue("", chevron: true)
            }
            SettingsDivider()
            SettingsRow(icon: "info.circle", title: "バージョン") {
                SettingsValue(Self.version, chevron: false)
            }
        }
        SettingsSection(title: "アカウント") {
            SettingsRow(icon: "person.crop.circle", title: "ログイン中") {
                SettingsValue(loginLabel, chevron: false)
            }
            SettingsDivider()
            SettingsRow(icon: "rectangle.portrait.and.arrow.right", title: "ログアウト", action: { showingSignOutConfirm = true }) {
                EmptyView()
            }
            SettingsDivider()
            SettingsRow(icon: "trash", title: "アカウントを削除する", tint: Color(hex: "FF6B5E"), action: { showingDeletion = true }) {
                EmptyView()
            }
        }
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    /// 「Apple」か、メールアドレスの一部(先頭2文字 + ••• + @以降)
    private var loginLabel: String {
        if !appleUserID.isEmpty { return "Apple" }
        guard let at = firebaseEmail.firstIndex(of: "@") else { return firebaseEmail.isEmpty ? "—" : firebaseEmail }
        return String(firebaseEmail[..<at].prefix(2)) + "•••" + String(firebaseEmail[at...])
    }

    // MARK: 動き

    /// トグル:ごく軽く1回(えらぶ)
    private func choose() {
        haptics.playTransient(intensity: 0.3, sharpness: 0.5)
    }

    private func setNotification(_ on: Bool) {
        choose()
        notificationOn = on
        Task {
            if on {
                let result = await DailyOpenNotification.requestAuthorization(timeout: 10)
                if result == .granted {
                    await DailyOpenNotification.schedule()
                } else {
                    // OS の許可がない:OS の設定を案内
                    notificationOn = false
                    showingNotificationDenied = true
                }
            } else {
                DailyOpenNotification.cancel()
            }
        }
    }

    private func setHaptics(_ on: Bool) {
        // ON にしたときは、鳴らしてから知らせる。OFF のあとは、アプリ全体で鳴らさない
        AppHapticsSetting.isEnabled = on
        hapticsOn = on
        if on {
            haptics.prepare()
            choose()
        }
    }

    private func setMondo(_ on: Bool) {
        choose()
        mondoOn = on
        MondoService.isPublic = on
        if !on { Task { await MondoService.shared.withdrawAll() } }
    }

    private func openGroup(_ id: UUID) {
        showingGroups = false
        close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            NotificationCenter.default.post(name: .openGroupRequested, object: id)
        }
    }

    private func signOut() {
        appleUserID = ""
        appleFullName = ""
        firebaseUID = ""
        firebaseEmail = ""
        currentProfileID = ""
        isSetupCompleted = false
        close()
    }

    private func close() {
        isShowing = false
        dismiss()
    }
}

// MARK: - 「LATER ・ 08.14 から」

enum LaterSince {
    /// 初回設定を終えた日(端末に保存)。なければ「LATER」だけ
    static var text: String {
        guard let date = UserDefaults.standard.object(forKey: "onboardingCompletedAt") as? Date else { return "LATER" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "MM.dd"
        return "LATER ・ \(formatter.string(from: date)) から"
    }
}

// MARK: - 部品(ガラス・行・トグル)

/// 面:白 8.5%→3.5% の縦グラデ + 内側 1pt の白 7%
struct SettingsGlass: View {
    var cornerRadius: CGFloat = 26

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(LinearGradient(colors: [.white.opacity(0.085), .white.opacity(0.035)], startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(.white.opacity(0.07), lineWidth: 1))
    }
}

/// 押している間、背景が薄く光る
struct SettingsPressStyle: ButtonStyle {
    var cornerRadius: CGFloat = 0

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(configuration.isPressed ? 0.06 : 0))
            )
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 9.5, design: .monospaced))
                .tracking(0.16 * 9.5)
                .foregroundStyle(Color(hex: "6B6B70"))
                .padding(.leading, 6)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) { content() }
                .background(SettingsGlass(cornerRadius: 26))
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .padding(.top, 28)
    }
}

/// 行:高さ60以上・左右16・アイコン22(線)・タイトル15.5・補足12
struct SettingsRow<Trailing: View>: View {
    let icon: String
    let title: String
    var note: String? = nil
    var tint: Color = .white
    var action: (() -> Void)? = nil
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        if let action {
            Button(action: action) { content }
                .buttonStyle(SettingsPressStyle())
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(tint == .white ? Color(hex: "D6D6DA") : tint)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15.5, weight: .medium))
                    .foregroundStyle(tint)
                if let note {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "8E8E93"))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }
}

/// 行と行の間:アイコンの右から 1pt の区切り(白 7%)
struct SettingsDivider: View {
    var body: some View {
        Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.leading, 16 + 22 + 14)
    }
}

struct SettingsValue: View {
    let text: String
    let chevron: Bool

    init(_ text: String, chevron: Bool) {
        self.text = text
        self.chevron = chevron
    }

    var body: some View {
        HStack(spacing: 6) {
            if !text.isEmpty {
                Text(text)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .lineLimit(1)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
                    .accessibilityHidden(true)
            }
        }
    }
}

/// トグル:51×31。ON = 白い軌道+黒いつまみ / OFF = 白14% の軌道+白いつまみ(iOS 標準の緑にしない)
struct MonoToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule().fill(configuration.isOn ? Color.white : Color.white.opacity(0.14))
                Circle()
                    .fill(configuration.isOn ? Color.black : Color.white)
                    .frame(width: 27, height: 27)
                    .padding(2)
            }
            .frame(width: 51, height: 31)
            .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "オン" : "オフ")
    }
}

/// プロフィールの球(写真か、ペルソナのアイコン)
struct ProfileBall: View {
    let profile: UserProfile?
    let diameter: CGFloat

    var body: some View {
        Group {
            if let data = profile?.profileImageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let id = profile?.id {
                PersonaIcon(seed: id)
            } else {
                Circle().fill(Color(hex: "1C1C1E"))
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
        .accessibilityHidden(true)
    }
}

// MARK: - グループ・ブロック・約束・使い方

struct SettingsGroupsList: View {
    let groups: [LaterGroup]
    let onOpen: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SettingsSubpage(title: "グループ", dismiss: dismiss) {
            if groups.isEmpty {
                Text("入っているグループは、ありません")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .padding(.top, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                        if index > 0 { SettingsDivider() }
                        SettingsRow(icon: "circle.dashed", title: group.name, action: { onOpen(group.id) }) {
                            SettingsValue("\(group.members.count)人", chevron: true)
                        }
                    }
                }
                .background(SettingsGlass())
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
        }
    }
}

struct SettingsBlockedList: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var blocked: [BlockedUser]

    var body: some View {
        SettingsSubpage(title: "通報・ブロックした人", dismiss: dismiss) {
            if blocked.isEmpty {
                Text("ブロックした人は、いません")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .padding(.top, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(blocked.enumerated()), id: \.element.id) { index, user in
                        if index > 0 { SettingsDivider() }
                        SettingsRow(icon: "person.crop.circle.badge.xmark", title: user.displayName ?? "だれか") {
                            Button("ブロックを解除") {
                                Task { await ModerationService.unblockUser(user, modelContext: modelContext) }
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                        }
                    }
                }
                .background(SettingsGlass())
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
        }
    }
}

/// Later の約束(4つ)を読み返す
struct LaterPromiseView: View {
    @Environment(\.dismiss) private var dismiss
    static let promises: [(String, String)] = [
        ("いいね・フォロワー・ランキングは、ありません", "数で比べる仕組みを、つくりません。"),
        ("名前は、本名でなくて大丈夫です", "ニックネームだけで使えます。"),
        ("顔は、要りません", "景色でも、手元でも。"),
        ("撮りなおし・プレビューは、ありません", "1日1枚。撮ったら、翌朝まで見えません。"),
    ]

    var body: some View {
        SettingsSubpage(title: "Later の約束", dismiss: dismiss) {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(Array(Self.promises.enumerated()), id: \.offset) { index, promise in
                    HStack(alignment: .top, spacing: 14) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color(hex: "8E8E93"))
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(promise.0).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                            Text(promise.1).font(.system(size: 13)).foregroundStyle(Color(hex: "BCBBC0"))
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SettingsGlass())
        }
    }
}

/// 使い方を、もういちど(初回設定の「Laterの一日」を再生)
struct HowToReplayView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            LaterDayView(isActive: scenePhase == .active, onFinish: { dismiss() }, onTapNext: {})
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .padding(.leading, 22)
            .accessibilityLabel("とじる")
        }
    }
}

/// サブ画面の共通の形(上に「とじる」とタイトル)
struct SettingsSubpage<Content: View>: View {
    let title: String
    let dismiss: DismissAction
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("とじる")
                    Spacer()
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            ScrollView {
                content()
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}

#if DEBUG
/// デバッグ:起動アニメーションを再生する(種類・ゆっくり0.4倍速・時刻を指定して止める)。
private struct LaunchDebugSection: View {
    let onReplay: ([String: Any]) -> Void
    @State private var kind: LaunchKind = .morning
    @State private var slow = false
    @State private var frozenIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("デバッグ・起動アニメーション")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
            Picker("種類", selection: $kind) {
                ForEach(LaunchKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("ゆっくり(0.4倍速)", isOn: $slow).foregroundStyle(.white)
            Picker("止める時刻", selection: $frozenIndex) {
                Text("止めない").tag(0)
                ForEach(Array(LaunchSpec.debugTimes(kind).enumerated()), id: \.offset) { i, t in Text("t = \(Int(t))").tag(i + 1) }
            }
            .foregroundStyle(.white)
            Button("再生する") {
                var info: [String: Any] = ["kind": kind.rawValue, "speed": slow ? 0.4 : 1.0]
                let times = LaunchSpec.debugTimes(kind)
                if frozenIndex > 0, frozenIndex - 1 < times.count { info["frozenT"] = times[frozenIndex - 1] }
                onReplay(info)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.06)))
    }
}
#endif

#if DEBUG
/// デバッグ:昼夜を手動で切り替える(自動 / 昼 / 夜)。
private struct ThemeDebugSection: View {
    @Environment(ThemeClock.self) private var themeClock
    @State private var selection: ThemeOverride = .automatic

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("テーマ(開発用)")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
            Picker("テーマ", selection: $selection) {
                Text("自動").tag(ThemeOverride.automatic)
                Text("昼").tag(ThemeOverride.day)
                Text("夜").tag(ThemeOverride.night)
            }
            .pickerStyle(.segmented)
        }
        .onAppear { selection = themeClock.debugOverride }
        .onChange(of: selection) { _, new in themeClock.forceMode(new) }
    }
}
#endif
