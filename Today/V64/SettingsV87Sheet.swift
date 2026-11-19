import SwiftUI
import SwiftData

// P30-C(v87):設定シート(歯車)。見本:F20 F21 F22。地 #0F1011 ・ 上の 角丸 34。かたまり ごとに 角丸 22 の 箱。
// 動く もの:9:00 / 友だち / Recap の スイッチ ・ 言語(iOS の 設定へ)・ ブロックした 人 ・ 使いかた ・ 利用規約 ・ プライバシー ・ ログアウト ・ アカウントを 消す。

enum SupportContact {
    /// 問い合わせ先(メール)。空の 間は「問い合わせ」の 行を 出さない
    static let mail = ""
}

struct SettingsV87Sheet: View {
    var name: String
    var username: String
    var avatar: UIImage?
    var blockedCount: Int
    var groupCount: Int = 0
    var onEdit: () -> Void = {}
    var onPhoto: () -> Void = {}
    var onClose: () -> Void = {}
    var onLoggedOut: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @AppStorage("notify.friends") private var friendsOn = true
    @AppStorage("notify.recap") private var recapOn = true
    @AppStorage("notify.liveNight") private var liveNightOn = true
    @AppStorage("notify.liveMorning") private var liveMorningOn = true
    @AppStorage("appleUserID") private var appleUserID = ""
    @AppStorage("appleFullName") private var appleFullName = ""
    @AppStorage("firebaseUID") private var firebaseUID = ""
    @AppStorage("firebaseEmail") private var firebaseEmail = ""
    @AppStorage("currentProfileID") private var currentProfileID = ""
    @AppStorage("isSetupCompleted") private var isSetupCompleted = false
    @State private var dailyOn = false
    @AppStorage("privacy.discoverableByName") private var discoverable = true
    @Query private var profiles: [UserProfile]
    @State private var showsBlocked = false
    @State private var hapticLevel = AppHapticsSetting.level
    @State private var showsHandle = false
    @State private var showsHowTo = false
    @State private var legal: LegalLink?
    @State private var confirmLogout = false
    @State private var showsDelete = false
    @State private var deniedAlert = false

    private let box = Color(hex: "17181B"), ink = Color.white

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("設定").font(LF.inter(900, 26)).foregroundStyle(ink)
                    Spacer()
                    Button { Haptics.play(.tick); onClose() } label: { Image(systemName: "xmark").font(.system(size: 15, weight: .black)).foregroundStyle(.white).frame(width: 44, height: 44).background(.white.opacity(0.1), in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1)) }.buttonStyle(.plain)
                }.padding(.top, 14)
                account.padding(.top, 14)
                header("お知らせ")
                group {
                    toggleRow("9:00 に ひらく", "きのうの 写真が ひらいた 時", $dailyOn) { setDaily($0) }
                    divider
                    toggleRow("友だち", "申請 ・ リアクション ・ コメント", $friendsOn) { _ in Haptics.play(.click) }
                    divider
                    toggleRow("Recap", "月曜 9:00 に できた 時", $recapOn) { v in Haptics.play(.click); RecapNotifier.setEnabled(v) }
                    divider
                    toggleRow("ライブ アクティビティ ・ 夜", "23:00 から 消灯まで(のこりの こま)", $liveNightOn) { _ in Haptics.play(.click); LattagLive.sync(snapshot: WidgetSnapshot.load()) }
                    divider
                    toggleRow("ライブ アクティビティ ・ 朝", "8:30 から 9:00 まで", $liveMorningOn) { _ in Haptics.play(.click); LattagLive.sync(snapshot: WidgetSnapshot.load()) }
                }
                header("プライバシー")
                group {
                    toggleRow("名前で 見つかる", "オフでも ID が ぴったり 合えば 見つかります", $discoverable) { _ in
                        Haptics.play(.click)
                        if let me = UserProfile.current(from: profiles) { Task { await UserDirectoryService.publish(me) } }
                    }
                }
                header("表示")
                group {
                    HStack {
                        Text("言語").font(LF.inter(800, 17)).foregroundStyle(ink)
                        Spacer()
                        HStack(spacing: 0) {
                            seg("日本語", on: !AppLanguage.isEnglish); seg("English", on: AppLanguage.isEnglish)
                        }.padding(4).background(.white.opacity(0.07), in: Capsule())
                    }.padding(.horizontal, 16).frame(height: 64)
                    divider
                    HStack {
                        Text("バイブ").font(LF.inter(800, 17)).foregroundStyle(ink)
                        Spacer()
                        HStack(spacing: 0) {
                            ForEach(AppHapticsSetting.Level.allCases) { l in
                                Button {
                                    AppHapticsSetting.level = l; hapticLevel = l
                                    // 選んだ 時に 見本を 1回(ひかえめ は きざみを 鳴らさない = pop)
                                    if l != .off { Haptics.play(l == .strong ? .click : .pop) }
                                } label: {
                                    Text(l.title).font(LF.inter(800, 13)).foregroundStyle(hapticLevel == l ? Color(hex: "0B0C0D") : .white.opacity(0.7))
                                        .padding(.horizontal, 12).frame(height: 36).background(hapticLevel == l ? Color.white : .clear, in: Capsule())
                                }.buttonStyle(.plain)
                            }
                        }.padding(4).background(.white.opacity(0.07), in: Capsule())
                    }.padding(.horizontal, 16).frame(height: 64)
                }
                header("アカウント")
                group {
                    linkRow("アイコンの 写真") { onPhoto() }
                    divider
                    linkRow("ID", value: "@\(username)") { showsHandle = true }
                    divider
                    linkRow("ブロックした 人", value: "\(blockedCount)") { showsBlocked = true }
                }
                header("サポート")
                group {
                    linkRow("使いかた") { showsHowTo = true }
                    divider
                    linkRow("利用規約") { legal = .terms }
                    divider
                    linkRow("プライバシー") { legal = .privacy }
                    if !SupportContact.mail.isEmpty { divider; linkRow("問い合わせ") { if let u = URL(string: "mailto:\(SupportContact.mail)") { UIApplication.shared.open(u) } } }
                }
                group {
                    Button { Haptics.play(.warn); confirmLogout = true } label: { Text("ログアウト").font(LF.inter(800, 17)).foregroundStyle(Color(hex: "FF453A")).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).frame(height: 56) }.buttonStyle(.plain)
                }.padding(.top, 22)
                Button { Haptics.play(.tick); showsDelete = true } label: { Text("アカウントを 消す").font(LF.inter(600, 13)).foregroundStyle(.white.opacity(0.4)).frame(maxWidth: .infinity).frame(height: 44) }.buttonStyle(.plain).padding(.top, 8)
                Text("Lattag \(Self.version)").font(LF.mono(10)).foregroundStyle(.white.opacity(0.3)).frame(maxWidth: .infinity).padding(.top, 6).padding(.bottom, 50)
            }.padding(.horizontal, 16)
        }
        .scrollHaptics()
        .background(Color(hex: "0F1011").ignoresSafeArea()).environment(\.colorScheme, .dark)
        .task { dailyOn = await DailyOpenNotification.isScheduled() }
        .sheet(isPresented: $showsBlocked) { SettingsBlockedList() }
        .sheet(isPresented: $showsHandle) { HandleChangeHost { _ in showsHandle = false } }
        .sheet(isPresented: $showsHowTo) { UsageGuideV105Sheet { showsHowTo = false } }
        .legalSheet($legal)
        .sheet(isPresented: $showsDelete) { AccountDeletionView(groupCount: groupCount, onDeleted: { signOutState(); onLoggedOut() }) }
        .confirmationDialog("ログアウト しますか?", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("ログアウト", role: .destructive) { signOutState(); onLoggedOut() }
            Button("やめる", role: .cancel) {}
        } message: { Text("また サインインすれば、同じ アカウントに もどれます") }
        .alert("通知が オフです", isPresented: $deniedAlert) {
            Button("iPhone の 設定を ひらく") { AppLanguage.openSystemSettings() }
            Button("やめる", role: .cancel) {}
        } message: { Text("このアプリの 通知を iPhone の 設定で オンに して ください") }
    }

    private static var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private var account: some View {
        HStack(spacing: 14) {
            ZStack { if let a = avatar { Image(uiImage: a).resizable().scaledToFill() } else { Circle().fill(LinearGradient(colors: [Color(hex: "61D278"), Color(hex: "EE5E9C")], startPoint: .topLeading, endPoint: .bottomTrailing)).overlay(Text(String(name.prefix(1))).font(LF.inter(900, 22)).foregroundStyle(.white)) } }
                .frame(width: 54, height: 54).clipShape(Circle()).overlay(Circle().strokeBorder(HV.lime, lineWidth: 2).padding(-3))
            VStack(alignment: .leading, spacing: 3) { Text(name).font(LF.inter(900, 21)).foregroundStyle(.white).lineLimit(1); Text("@\(username)").font(LF.mono(12)).foregroundStyle(.white.opacity(0.45)) }
            Spacer(minLength: 0)
            Button { Haptics.play(.tick); onEdit() } label: { Text("編集").font(LF.inter(800, 14)).foregroundStyle(.white).padding(.horizontal, 18).frame(height: 36).background(.white.opacity(0.1), in: Capsule()) }.buttonStyle(.plain)
        }.padding(16).background(box, in: RoundedRectangle(cornerRadius: 22, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
    }

    private func header(_ t: String) -> some View { Text(t).font(LF.inter(700, 12.5)).foregroundStyle(.white.opacity(0.45)).padding(.leading, 12).padding(.top, 26).padding(.bottom, 8).hapticSection(t) }
    private func group<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(spacing: 0, content: c).background(box, in: RoundedRectangle(cornerRadius: 22, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
    }
    private var divider: some View { Rectangle().fill(.white.opacity(0.07)).frame(height: 1) }

    private func toggleRow(_ t: String, _ sub: String, _ on: Binding<Bool>, _ change: @escaping (Bool) -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) { Text(t).font(LF.inter(800, 17)).foregroundStyle(.white); Text(sub).font(LF.inter(600, 13)).foregroundStyle(.white.opacity(0.45)) }
            Spacer()
            Toggle("", isOn: Binding(get: { on.wrappedValue }, set: { on.wrappedValue = $0; change($0) })).labelsHidden().toggleStyle(V87Toggle())
        }.padding(.horizontal, 16).frame(minHeight: 64).padding(.vertical, 4)
    }
    private func linkRow(_ t: String, value: String? = nil, _ a: @escaping () -> Void) -> some View {
        Button { Haptics.play(.tick); a() } label: {
            HStack { Text(t).font(LF.inter(800, 17)).foregroundStyle(.white); Spacer(); if let value { Text(value).font(LF.inter(700, 15)).foregroundStyle(.white.opacity(0.45)) }; Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.4)) }.padding(.horizontal, 16).frame(height: 56)
        }.buttonStyle(.plain)
    }
    private func seg(_ t: String, on: Bool) -> some View {
        Button { Haptics.play(.sel); if !on { AppLanguage.openSystemSettings() } } label: {
            Text(t).font(LF.inter(800, 14)).foregroundStyle(on ? Color(hex: "0B0C0D") : .white.opacity(0.7)).padding(.horizontal, 18).frame(height: 36).background(on ? Color.white : .clear, in: Capsule())
        }.buttonStyle(.plain)
    }

    private func setDaily(_ on: Bool) {
        Haptics.play(.click)
        Task {
            if on {
                let r = await DailyOpenNotification.requestAuthorization(timeout: 10)
                if r == .granted { await DailyOpenNotification.schedule() } else { dailyOn = false; deniedAlert = true }
            } else { DailyOpenNotification.cancel() }
        }
    }

    private func signOutState() {
        appleUserID = ""; appleFullName = ""; firebaseUID = ""; firebaseEmail = ""; currentProfileID = ""; isSetupCompleted = false
    }
}

/// 黄緑の 地 + 黒い つまみ
struct V87Toggle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule().fill(configuration.isOn ? HV.lime : Color.white.opacity(0.14)).frame(width: 52, height: 32)
                Circle().fill(configuration.isOn ? Color(hex: "0B0C0D") : .white).frame(width: 26, height: 26).padding(3)
            }.animation(.spring(response: 0.3, dampingFraction: 0.75), value: configuration.isOn)
        }.buttonStyle(.plain).accessibilityAddTraits(.isToggle).accessibilityValue(configuration.isOn ? "オン" : "オフ")
    }
}
