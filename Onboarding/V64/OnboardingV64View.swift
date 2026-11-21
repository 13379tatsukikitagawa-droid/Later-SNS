import SwiftUI
import SwiftData
import AuthenticationServices
import PhotosUI

/// P01:はじめての設定(モック v64:in → mail → sent → name → tag → fr → nt → go)。
/// 見た目と 流れだけ モックに 合わせ、保存・認証・通知の しくみは これまでの OnboardingFlowView と 同じ もの(UserProfile ・ FirebaseAuthService ・ DailyOpenNotification)を 使う。
struct OnboardingV64View: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

    @Query private var profiles: [UserProfile]

    // 場面
    @State private var step: OBStep = .signin
    @State private var handle = ""
    @State private var handleState: HandleService.Availability = .unknown
    @State private var started = false
    @State private var introStart: Date?
    @State private var entered = true
    @State private var slideY: CGFloat = 0
    @State private var slideOpacity = 1.0
    @State private var transitioning = false

    // 入力
    @State private var name = ""
    /// v81:アイコン(プロフィール写真)。とばしても よい(1文字 + 色)
    @State private var iconData: Data?
    @State private var showsIcon = false
    @State private var tags: [String] = []          // 「#」なしで 保存(TagRules と 同じ)
    @State private var customDraft = ""
    @State private var addingTag = false
    @State private var photo: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var email = ""
    @State private var sentAddress = ""
    @State private var invitedBy: String?
    @State private var requestedInvite = false
    @State private var invitedRecord: String?
    @FocusState private var focus: Field?
    enum Field { case name, mail, tag }

    // 状態
    @State private var busy = false
    @State private var toast: String?
    @State private var legalLink: LegalLink?
    @AppStorage("hideEmailOnApple") private var hideEmail = true
    @State private var appleError = false
    @State private var appleGlow = false
    @State private var showingShare = false
    @State private var isCheckingAccount = false
    @State private var holdLevel = 0.0
    @State private var finishStart: Date?
    @State private var sparks: [Spark] = []
    /// キーボードの 上の はし(画面の y)。出ていない ときは 無限大
    @State private var kbTop: CGFloat = .greatestFiniteMagnitude

    struct Spark: Identifiable { let id = UUID(); let angle: Double; let radius: Double; let born = Date() }

    /// 名前を 書くと ハッシュで 決まり、色の 丸で えらびなおせる(モックの OB.col)
    @State private var col = 0
    private var colors: (Color, Color) { OB.palette[col] }
    private var initial: String { name.first.map(String.init) ?? "" }
    /// 入力欄の 下の 位置(モックの y)。キーボードで 下の ボタンが 上がった とき、ここが 隠れない ように 押し上げる
    private func contentBottom(_ s: OBStep) -> CGFloat { s == .name ? 684 : (s == .mail ? 604 : (s == .tag ? 716 : 0)) }
    private func lift(mid: CGFloat) -> CGFloat {
        let b = contentBottom(step)
        guard b > 0, kbTop < .greatestFiniteMagnitude, !editing else { return 0 }
        // 下の ボタンは キーボードの 上に のる(下の すきま 34pt)。入力欄の 下は その ボタンより 上に
        let groupHeight: CGFloat = (step == .mail) ? 106 : 60
        let buttonTop = kbTop - 34 - groupHeight
        return max(0, b + mid + 14 - buttonTop)
    }
    /// v95-1: 名前 / ID を 打って いる 間(キーボードが 出て いる)。チェキを 小さく 上へ、入力欄を その すぐ 下へ
    private var editing: Bool { (step == .name || step == .id) && kbTop < .greatestFiniteMagnitude }
    private var validName: Bool { OnboardingRules.validateName(name).problem == nil }

    var body: some View {
        ZStack {
            stage.ignoresSafeArea()
            bottomLayer.ignoresSafeArea(.container)
            if let introStart {
                OBIntroView(start: introStart) { finishIntro() }.transition(.opacity)
            }
            if let finishStart {
                OBFinishView(start: finishStart, onDone: completeFinish).ignoresSafeArea()
            }
            if let toast {
                Text(toast).font(Typo.ui(700, 13)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .lgGlass(radius: 18)
                    .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 190)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .allowsHitTesting(false)
            }
        }
        .background(OB.bg.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let end = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
            kbTop = end.minY >= UIScreen.main.bounds.height - 1 ? .greatestFiniteMagnitude : end.minY
        }
        .statusBarHidden()
        .preferredColorScheme(.dark)
        .onAppear(perform: start)
        .onChange(of: appleUserID) { _, _ in handleSignInChange() }
        .onChange(of: firebaseUID) { _, _ in handleSignInChange() }
        .onChange(of: photoItem) { _, item in loadPhoto(item) }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .legalSheet($legalLink)
        .sheet(isPresented: $showsIcon) {
            IconPickerV81Sheet(name: name, current: iconData.flatMap { UIImage(data: $0) }, recent: [], onSave: { iconData = $0 }, onClose: { showsIcon = false })
                .presentationDetents([.large]).presentationBackground(Color(hex: "141516"))
        }
        .sheet(isPresented: $showingShare) { ShareSheet(activityItems: shareItems) { _ in } }
    }

    // MARK: - 画面(上から 下まで・キーボードで ずれない)

    private var stage: some View {
        GeometryReader { g in
            let W = g.size.width, H = g.size.height
            let mid = (H - 844) / 2
            let up = lift(mid: mid)
            ZStack(alignment: .topLeading) {
                OB.bg
                OBGlow(c1: colors.0, c2: colors.1, opacity: step == .signin ? 0.16 : 0.26)
                OBWall(opacity: step.wallOpacity).frame(width: W, height: H).clipped()
                    .opacity(entered ? 1 : 0)
                // 「Lattag today」(サインイン・メール)
                brandHeader.frame(width: W).offset(y: 64)
                    .opacity(step.showsBrand && entered ? 1 : 0).animation(.easeOut(duration: 0.4), value: step)
                // ページの 目印「01 / 04  YOU」
                if let n = step.page { pageMark(n).frame(width: W).offset(y: 66).transition(.opacity) }
                // チェキ
                OBCheki(step: step, initial: initial, colors: colors, photo: photo, tags: tags,
                        friendInitials: requestedInvite ? [(invitedBy.map { String($0.prefix(1)) } ?? "", colors.0)] : [])
                    .scaleEffect(editing ? 0.4 : step.chekiScale)
                    .rotationEffect(.degrees(step.chekiRotation))
                    .position(x: W / 2, y: editing ? 100 + 108 * 0.4 : step.chekiTop + mid + 108)
                    .offset(y: entered ? 0 : -300)
                    .rotationEffect(.degrees(entered ? 0 : -14))
                    .opacity(entered ? 1 - min(1, up / 60) : 0)
                    .animation(.timingCurve(0.3, 1.2, 0.4, 1, duration: 0.6), value: step)
                    .animation(.timingCurve(0.3, 1.1, 0.4, 1, duration: 0.38), value: editing)
                    .onTapGesture { if step == .tag { Haptics.play(.pop); showPhotoPicker = true } }
                if step == .nt { OBNoticeCard().frame(width: W).offset(y: 104).transition(.opacity.combined(with: .offset(y: -20))) }
                // 戻る
                if step.back != nil {
                    Button { Haptics.play(.tick); go(step.back!, back: true) } label: {
                        Image(systemName: "chevron.left").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 44, height: 44).background(OB.line, in: Circle())
                    }
                    .buttonStyle(.plain).offset(x: 16, y: 52).accessibilityLabel("もどる")
                }
                // 見出し・入力・チップ
                content(step, W: W, mid: mid)
                    .offset(y: slideY - up).opacity(slideOpacity)
                    .animation(.easeOut(duration: 0.25), value: up)
                    .animation(.timingCurve(0.3, 1.1, 0.4, 1, duration: 0.38), value: editing)
                // ながおしの 光
                if step == .go {
                    RadialGradient(colors: [OB.stamp.opacity(0.8 * holdLevel), .clear], center: UnitPoint(x: 0.5, y: 0.66), startRadius: 0, endRadius: max(W, H) * (0.18 + holdLevel * 0.62))
                        .allowsHitTesting(false)
                }
                ForEach(sparks) { s in OBSparkView(spark: s, center: CGPoint(x: W / 2, y: 560 + mid), strength: holdLevel) }
            }
            .frame(width: W, height: H, alignment: .topLeading)
            .contentShape(Rectangle())
            .onTapGesture { focus = nil }
        }
    }

    private var brandHeader: some View {
        HStack(alignment: .top, spacing: 3) {
            Text(Brand.name).font(Typo.ui(900, 34)).tracking(-0.065 * 34).foregroundStyle(.white).frame(height: 34)
            Text("today").font(Typo.title(15, italic: true)).foregroundStyle(OB.sub)
        }
        .frame(maxWidth: .infinity)
    }

    private func pageMark(_ n: Int) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                Text(String(format: "%02d", n)).font(Typo.label(13)).tracking(0.78).foregroundStyle(.white)
                Text(" / 04").font(Typo.label(11)).tracking(1.54).foregroundStyle(OB.sub)
            }
            Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 18)
            Text(step.pageLabel).font(Typo.label(11)).tracking(1.54).foregroundStyle(OB.stamp)
        }
        .frame(maxWidth: .infinity).frame(height: 20)
    }

    // MARK: - 中身(場面ごと・モックの y を そのまま)

    @ViewBuilder
    private func content(_ s: OBStep, W: CGFloat, mid: CGFloat) -> some View {
        let w = W - 48
        switch s {
        case .signin:
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Circle().fill(OB.stamp).frame(width: 6, height: 6).shadow(color: OB.stamp, radius: 4)
                    Text("FILM FOR TOMORROW").font(Typo.label(10)).tracking(2.4).foregroundStyle(OB.kicker)
                }
                VStack(spacing: 0) {
                    Text("昨日を").foregroundColor(.white).frame(height: 50)
                    (Text("共有する ").foregroundColor(.white) + Text("SNS").foregroundColor(HV.lime)).frame(height: 50)
                }
                .font(LGFont.mincho(46)).lineLimit(1).minimumScaleFactor(0.7).padding(.top, 14)
                .accessibilityElement(children: .ignore).accessibilityLabel("昨日を 共有する SNS")
            }
            .frame(width: W).offset(y: 372 + mid)
        case .mail, .sent: EmptyView()   // v104:メールの リンクは やめた
        case .name:
            VStack(spacing: 0) {
                Text("Name").font(Typo.title(editing ? 38 : 64, italic: true)).tracking(editing ? -0.76 : -1.28).foregroundStyle(.white).frame(height: editing ? 38 : 64)
                if !editing { Text("\(Brand.name) で よばれる なまえ").font(Typo.ui(500, 12.5)).tracking(0.25).foregroundStyle(OB.sub).padding(.top, 8) }
            }
            .frame(width: W).offset(y: editing ? 222 : 453 + mid)
            VStack(alignment: .leading, spacing: 0) {
                TextField("", text: $name, prompt: Text("なまえ").foregroundColor(OB.sub.opacity(0.5)))
                    .font(Typo.ui(900, 27)).tracking(-0.54).foregroundStyle(.white).tint(OB.accent).multilineTextAlignment(.center)
                    .submitLabel(.next).focused($focus, equals: .name)
                    .onSubmit { if validName { next() } }
                    .onChange(of: name) { _, v in
                        if v.count > OnboardingRules.nameMaxLength { name = String(v.prefix(OnboardingRules.nameMaxLength)) }
                        Haptics.play(.tick, gap: 0.04)
                        col = v.isEmpty ? 0 : OB.colorIndex(for: v)
                    }
                    .frame(height: editing ? 50 : 58)
                Rectangle().fill(focus == .name ? OB.accent : .white).frame(height: 2.5)
                // v106 §2:字数は 線の 下 ・ 右(上から 4pt)。線の 中には 置かない
                Text("\(name.count) / 12").font(Typo.label(11)).foregroundStyle(.white.opacity(0.4)).frame(maxWidth: .infinity, alignment: .trailing).padding(.top, 4).allowsHitTesting(false)
            }
            .frame(width: w).offset(x: 24, y: editing ? 268 : 691 + mid)
            Button { Haptics.play(.click); showsIcon = true } label: {
                HStack(spacing: 14) {
                    ZStack(alignment: .bottomTrailing) {
                        ZStack {
                            Circle().fill(LinearGradient(colors: [Color(hex: "61D278"), Color(hex: "EE5E9C")], startPoint: .topLeading, endPoint: .bottomTrailing))
                            if let d = iconData, let i = UIImage(data: d) { Image(uiImage: i).resizable().scaledToFill() }
                            else { Text(String(name.prefix(1))).font(Typo.ui(900, 28)).foregroundStyle(.white) }
                        }.frame(width: editing ? 60 : 76, height: editing ? 60 : 76).clipShape(Circle()).overlay(Circle().strokeBorder(OB.accent, lineWidth: 3).padding(-3))
                        Image(systemName: "plus").font(.system(size: 13, weight: .black)).foregroundStyle(HV.ink).frame(width: 28, height: 28).background(OB.accent, in: Circle()).overlay(Circle().strokeBorder(.black, lineWidth: 2)).offset(x: 4, y: 4)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("アイコンの 写真").font(Typo.ui(800, 16)).foregroundStyle(.white)
                        Text("タップして えらぶ ・ あとで かえられます").font(Typo.ui(600, 13)).foregroundStyle(OB.sub).lineLimit(1).minimumScaleFactor(0.75)
                    }
                    Spacer()
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }.buttonStyle(.plain).frame(width: w).offset(x: 24, y: editing ? 340 : 592 + mid)
        case .id:
            VStack(spacing: 0) {
                Text("ID").font(Typo.title(editing ? 44 : 64, italic: true)).tracking(editing ? -0.88 : -1.28).foregroundStyle(.white).frame(height: editing ? 44 : 64)
                if !editing { Text("友だちが さがす ときに つかう ・ あとで かえられる").font(Typo.ui(500, 12.5)).tracking(0.25).foregroundStyle(OB.sub).padding(.top, 8) }
            }
            .frame(width: W).offset(y: editing ? 214 : 453 + mid)
            HandleField(text: $handle, ownerKey: UserProfile.current(from: profiles)?.id.uuidString ?? currentProfileID, suggestions: HandleRules.suggestions(fromName: name), autofocus: true) { handleState = $0 }
                .frame(width: w).offset(x: 24, y: editing ? 266 : 560 + mid)
        case .tag:
            heading([("じぶんを、", false), ("タグ", true), ("で。", false)]).offset(y: 424 + mid)
            swatches.frame(width: W).offset(y: 488 + mid)
            OBFlow(spacing: 8, rowSpacing: 8) { chips }.frame(width: w).offset(x: 24, y: 539 + mid)
        case .fr:
            heading([("ともだちを さがす", false)]).offset(y: 424 + mid)
            VStack(spacing: 8) {
                if let invitedBy { inviteRow(invitedBy) }
                Button { Haptics.play(.click); say("連絡先の 許可は このあと 友だちの 画面で") } label: {
                    HStack(spacing: 8) { Image(systemName: "person.badge.plus").font(.system(size: 16, weight: .bold)); Text("連絡先から さがす") }
                        .font(Typo.ui(800, 15)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 56)
                        .background(OB.line, in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(.plain)
                HStack(spacing: 12) {
                    Button { Haptics.play(.pop); showingShare = true } label: { Text("リンクを おくる").frame(height: 44).padding(.horizontal, 12) }
                }
                .font(Typo.ui(700, 13)).foregroundStyle(OB.sub).buttonStyle(.plain).padding(.top, 2)
            }
            .frame(width: w).offset(x: 24, y: 489 + mid)
        case .nt:
            VStack(spacing: 9) {
                (Text("9:00").font(Typo.title(36, italic: true)).foregroundColor(OB.stamp) + Text(" に、しらせる。").font(LGFont.mincho(29)).foregroundColor(.white))
                    .lineSpacing(0)
                Text("朝の 1回と、なかまの ことだけ").font(Typo.ui(500, 13)).foregroundStyle(OB.sub)
            }
            .frame(width: W).offset(y: 492 + mid)
        case .go:
            heading([("ようこそ、\n\(name.isEmpty ? "あなた" : name)。", false)], size: 31).offset(y: 487.7 + mid)
        }
    }

    private func heading(_ parts: [(String, Bool)], size: CGFloat = 29) -> some View {
        OBHeading(parts: parts, size: size).frame(maxWidth: .infinity)
    }

    private var swatches: some View {
        HStack(spacing: 0) {
            ForEach(0..<OB.palette.count, id: \.self) { i in
                let on = photo == nil && col == i
                Button { Haptics.play(.sel); pickColor(i) } label: {
                    Circle().fill(LinearGradient(colors: [OB.palette[i].0, OB.palette[i].1], startPoint: UnitPoint(x: 0.15, y: 0), endPoint: UnitPoint(x: 0.85, y: 1)))
                        .frame(width: 34, height: 34)
                        .overlay(Circle().stroke(OB.bg, lineWidth: on ? 2.5 : 0).padding(on ? -2.5 : 0))
                        .overlay(Circle().stroke(.white, lineWidth: on ? 2.5 : 0).padding(on ? -5 : 0))
                        .scaleEffect(on ? 1.08 : 1)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel("色 \(i + 1)")
            }
            Button { Haptics.play(.pop); showPhotoPicker = true } label: {
                Image(systemName: "camera").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 34, height: 34).background(OB.line, in: Circle())
                    .overlay(Circle().stroke(OB.bg, lineWidth: photo != nil ? 2.5 : 0).padding(photo != nil ? -2.5 : 0))
                    .overlay(Circle().stroke(.white, lineWidth: photo != nil ? 2.5 : 0).padding(photo != nil ? -5 : 0))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel("写真を えらぶ")
        }
        .frame(maxWidth: .infinity)
        .animation(.timingCurve(0.3, 1.6, 0.4, 1, duration: 0.3), value: col)
        .padding(.top, -5)
    }

    @ViewBuilder
    private var chips: some View {
        let custom = tags.map { "#" + $0 }.filter { !OB.tags.contains($0) }
        ForEach(OB.tags + custom, id: \.self) { t in
            let on = tags.contains(String(t.dropFirst()))
            Button { toggleTag(String(t.dropFirst())) } label: {
                Text(t).font(Typo.ui(700, 14)).foregroundStyle(on ? Color(hex: "111111") : .white)
                    .padding(.horizontal, 14).frame(height: 38)
                    .background(on ? Color.white : OB.line, in: Capsule())
            }
            .buttonStyle(OBChipPress())
        }
        if addingTag {
            ZStack(alignment: .leading) {
                if customDraft.isEmpty { Text("#じぶんで").font(Typo.ui(700, 14)).foregroundStyle(OB.sub.opacity(0.5)) }
                TextField("", text: $customDraft)
                    .font(Typo.ui(700, 14)).foregroundStyle(.white).tint(OB.accent)
                    .focused($focus, equals: .tag).submitLabel(.done).onSubmit(commitCustomTag)
            }
            .padding(.horizontal, 14).frame(width: 120, height: 38)
                .overlay(Capsule().strokeBorder(OB.accent, lineWidth: 1.5))
        } else {
            Button { Haptics.play(.sel); addingTag = true; focus = .tag } label: {
                Text("+ じぶんで").font(Typo.ui(700, 14)).foregroundStyle(.white).padding(.horizontal, 14).frame(height: 38)
                    .background(OB.line, in: Capsule())
            }
            .buttonStyle(OBChipPress())
        }
    }

    private func inviteRow(_ n: String) -> some View {
        HStack(spacing: 12) {
            Text(String(n.prefix(1))).font(Typo.ui(800, 15)).foregroundStyle(.white)
                .frame(width: 40, height: 40).background(LinearGradient(colors: [colors.0, colors.1], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(n).font(Typo.ui(800, 15)).foregroundStyle(.white)
                Text("招待してくれた").font(Typo.ui(500, 11)).foregroundStyle(OB.sub)
            }
            Spacer(minLength: 0)
            Button {
                requestedInvite.toggle(); Haptics.play(requestedInvite ? .pop : .tick)
            } label: {
                Text(requestedInvite ? "申請した" : "申請").font(Typo.ui(900, 13))
                    .foregroundStyle(requestedInvite ? OB.sub : Color(hex: "111111")).padding(.horizontal, 16).frame(height: 36)
                    .background(requestedInvite ? Color.clear : Color.white, in: Capsule())
                    .overlay(Capsule().strokeBorder(requestedInvite ? OB.line : .clear, lineWidth: 1.2))
            }.buttonStyle(.plain)
        }
        .padding(10).frame(height: 60)
        .background(Color(red: 0.137, green: 0.62, blue: 0.235).opacity(0.16), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(red: 0.137, green: 0.62, blue: 0.235).opacity(0.55), lineWidth: 1.2))
    }

    // MARK: - 下の ボタン(キーボードの 上に のる)

    private var bottomLayer: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Group {
                switch step {
                case .signin:
                    VStack(spacing: 0) {
                        OBAppleCircle(busy: busy, glow: appleGlow, reduceMotion: reduceMotion) { startApple() }
                        Text("Apple で つづける").font(Typo.ui(800, 16)).foregroundStyle(.white).padding(.top, 10)
                        HStack(spacing: 10) {
                            Image(systemName: "eye.slash").font(.system(size: 15, weight: .semibold)).foregroundStyle(HV.lime)
                            Text("メールは かくす").font(Typo.ui(800, 13)).foregroundStyle(.white)
                            Toggle("", isOn: $hideEmail).labelsHidden().tint(HV.lime).scaleEffect(0.85)
                                .onChange(of: hideEmail) { _, _ in Haptics.play(.sel) }
                        }
                        .padding(.leading, 16).padding(.trailing, 8).frame(height: 44)
                        .background(HV.lime.opacity(0.08), in: Capsule())
                        .overlay(Capsule().strokeBorder(HV.lime.opacity(0.3), lineWidth: 1))
                        .padding(.top, 14)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("メールは かくす").accessibilityValue(hideEmail ? "オン" : "オフ")
                        .accessibilityAddTraits(.isButton).accessibilityAction { hideEmail.toggle() }
                        Text(appleError ? "サインインできませんでした。もう一度 どうぞ" : (hideEmail ? "Lattag は メールアドレスを うけとりません" : "Apple の 画面で メールの あつかいを えらべます"))
                            .font(Typo.ui(500, 11.5)).foregroundStyle(appleError ? Color(hex: "FF453A") : OB.sub).multilineTextAlignment(.center).padding(.top, 10).frame(minHeight: 16)
                        HStack(spacing: 0) {
                            Text("つづけると ")
                            Button { legalLink = .terms } label: { Text("利用規約").underline().frame(minHeight: 44).contentShape(Rectangle()) }
                                .accessibilityAddTraits(.isLink).accessibilityLabel("利用規約")
                            Text(" ・ ")
                            Button { legalLink = .privacy } label: { Text("プライバシー").underline().frame(minHeight: 44).contentShape(Rectangle()) }
                                .accessibilityAddTraits(.isLink).accessibilityLabel("プライバシー")
                            Text(" に 同意(13歳以上)")
                        }
                        .font(Typo.ui(500, 10)).foregroundStyle(OB.sub).buttonStyle(.plain).frame(height: 44).padding(.vertical, -10)
                    }
                    .padding(.bottom, 28)
                case .mail, .sent: EmptyView()
                case .name:
                    Button { next() } label: { Text("つぎへ") }.buttonStyle(OBButtonStyle()).disabled(!validName).padding(.bottom, editing ? 10 : 34)
                case .id:
                    Button { next() } label: { Text("つぎへ") }.buttonStyle(OBButtonStyle()).disabled(!(handleState == .ok || handleState == .mine) || busy).padding(.bottom, editing ? 10 : 34)
                case .tag:
                    Button { next() } label: { Text("つぎへ") }.buttonStyle(OBButtonStyle()).padding(.bottom, 34)
                case .fr:
                    Button { next() } label: { Text(requestedInvite ? "つぎへ" : "あとで") }.buttonStyle(OBButtonStyle()).padding(.bottom, 34)
                case .nt:
                    VStack(spacing: 10) {
                        Button { allowNotifications() } label: { Text("通知を うけとる") }.buttonStyle(OBButtonStyle())
                        Button { Haptics.play(.soft); go(.go) } label: { Text("あとで") }.buttonStyle(OBButtonStyle(kind: .plain))
                    }.padding(.bottom, 34)
                case .go:
                    VStack(spacing: 0) {
                        OBHoldButton(onProgress: { level in
                            holdLevel = level
                            if level > 0.05 { spawnSpark() }
                        }, onFinish: beginFinish)
                        Text("HOLD").font(Typo.label(10)).tracking(2.6).foregroundStyle(OB.sub).padding(.top, 27)
                        Text("ながおしで はじめる").font(Typo.ui(500, 11.5)).tracking(0.23).foregroundStyle(OB.sub).padding(.top, 6)
                    }.padding(.bottom, 44)
                }
            }
            .padding(.horizontal, 24)
            .offset(y: slideY).opacity(slideOpacity)
            .opacity(entered ? 1 : 0)
            .animation(.timingCurve(0.3, 1.1, 0.4, 1, duration: 0.38), value: editing)
        }
    }

    // MARK: - 遷移

    /// 出る(-14pt・0.17秒)→ 入る(+22pt から・0.44秒・`cubic-bezier(.3,1.3,.5,1)`)
    private func go(_ s: OBStep, back: Bool = false) {
        guard !transitioning, s != step else { return }
        focus = nil
        if reduceMotion { step = s; savedStep = s.rawValue; arrive(s); return }
        transitioning = true
        let d: CGFloat = back ? -1 : 1
        withAnimation(.easeIn(duration: 0.17)) { slideY = -14 * d; slideOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            step = s; savedStep = s.rawValue
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { slideY = 22 * d }
            withAnimation(.timingCurve(0.3, 1.3, 0.5, 1, duration: 0.44)) { slideY = 0; slideOpacity = 1 }
            arrive(s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) { transitioning = false }
        }
    }

    private func arrive(_ s: OBStep) {
        if s == .nt { Haptics.play(.soft) }
        if s == .fr { loadInviter() }
        if s == .go { Haptics.play(.success) }
        if s == .name || s == .mail {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { if step == s { focus = (s == .name ? .name : .mail) } }
        }
    }

    /// 「つぎへ」
    private func next() {
        Haptics.play(.click)
        switch step {
        case .name: confirmName(); handle = HandleRules.suggestions(fromName: name).first ?? ""; go(.id)
        case .id: confirmHandle()
        case .tag: confirmTags(); go(.fr)
        case .fr: sendFriendRequest(); go(.nt)
        default: break
        }
    }

    // MARK: - 開始・再開

    private func start() {
        guard !started else { return }
        started = true
        name = UserProfile.current(from: profiles)?.name ?? userName
        if onboardingCompleted { markCompleted(); return }
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "debugOnbStep") {
            UserDefaults.standard.removeObject(forKey: "debugOnbStep")   // 1回だけ(起動引数の ときは 残る)
            if let inv = UserDefaults.standard.string(forKey: "debugInvite") { invitedBy = inv }
            if let n = UserDefaults.standard.string(forKey: "debugName") { name = n }
            if UserDefaults.standard.object(forKey: "debugT") != nil { OnboardingDebug.introT = UserDefaults.standard.double(forKey: "debugT") }
            if raw == "intro" { entered = false; introStart = Date(); return }
            if raw == "finish" { if UserDefaults.standard.object(forKey: "debugT") != nil { OnboardingDebug.finishT = UserDefaults.standard.double(forKey: "debugT") }; finishStart = Date(); return }
            if let s = OBStep(rawValue: raw) { step = s; arrive(s); return }
        }
        #endif
        if let resumed = resumeStep() { step = resumed; arrive(resumed); if resumed == .signin { handleSignInChange() }; return }
        entered = false
        introStart = Date()
    }

    private func resumeStep() -> OBStep? {
        let signedIn = !appleUserID.isEmpty || !firebaseUID.isEmpty
        return OnboardingRouter.resume(saved: savedStep, signedIn: signedIn)
    }

    /// 入口が おわった:チェキが 落ちてきて、ほかが 浮かんで 入る(`obIntroEnd`)
    private func finishIntro() {
        withAnimation(.easeOut(duration: 0.7)) { introStart = nil }
        if reduceMotion { entered = true; return }
        withAnimation(.timingCurve(0.3, 1.2, 0.4, 1, duration: 0.9).delay(0.12)) { entered = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.02) { Haptics.play(.land, gap: 0) }
    }

    // MARK: - サインイン(しくみは これまでと 同じ)

    private func appleDone(_ result: Result<ASAuthorization, Error>, nonce: String) {
        switch result {
        case .success(let authorization):
            // P47 A:Firebase にも のせる(失敗しても 入れる。あとで「つなぎなおす」で 直る)
            if let cred = authorization.credential as? ASAuthorizationAppleIDCredential {
                Task { @MainActor in
                    do { firebaseUID = try await AppleFirebaseAuth.signIn(cred, rawNonce: nonce) }
                    catch { print("[AppleFirebase] failed: \(FirebaseAuthService.debugLabel(for: error))") }
                }
            }
            if let message = AppleSignInView.applySignIn(result, modelContext: modelContext) {
                print("[AppleSignIn] 結果の保存に失敗: \(message)")
                Haptics.play(.warn); say(OnboardingCopy.appleSignInFailed)
            } else { Haptics.play(.success); withAnimation(.easeOut(duration: 0.46)) { appleGlow = true } }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { Haptics.play(.soft); return }
            Haptics.play(.warn); appleError = true
            #if DEBUG
            print("[AppleSignIn] failed: \((error as NSError).domain) \((error as NSError).code)")
            #endif
        }
    }

    /// 「Apple で つづける」:自前の ボタンから 公式の 認証画面を 出す(しくみは AppleSignInView.applySignIn のまま)
    private func startApple() {
        guard !busy else { return }
        Haptics.play(.click)
        appleError = false
        busy = true
        let c = OBAppleCoordinator(hideEmail: hideEmail) { result, nonce in busy = false; appleDone(result, nonce: nonce); apple = nil }
        apple = c
        c.start()
    }
    @State private var apple: OBAppleCoordinator?

    /// サインインが 済んだ:名前の 画面へ。おかえり の 判定は 公開 ディレクトリの `onboardedAt`(v106)。
    /// 端末に のこった プロフィールが あるだけでは Home に 行かない(途中の 人を つづきの ページへ)。
    private func handleSignInChange() {
        guard step == .signin || step == .mail || step == .sent, !appleUserID.isEmpty || !firebaseUID.isEmpty, !isCheckingAccount else { return }
        if isSetupCompleted { markCompleted(); return }
        go(.name)
        checkExistingAccountInBackground()
    }

    private func checkExistingAccountInBackground() {
        guard !isCheckingAccount else { return }
        isCheckingAccount = true
        Task { @MainActor in
            defer { isCheckingAccount = false }
            for _ in 0..<40 where CloudKitManager.current?.currentUserRecordName == nil { try? await Task.sleep(for: .seconds(0.5)) }
            guard let manager = CloudKitManager.current, let rn = manager.currentUserRecordName else { return }
            let dir = await UserDirectoryService.fetchProfile(cloudKitUserRecordName: rn)
            let gate = OnboardingRouter.gate(name: dir?.name ?? "", onboardedAt: dir?.onboardedAt, recordCreatedAt: dir?.createdAt)
            guard gate != .resume else { return }
            await manager.fetchPrivateChangesNow()
            await manager.fetchSharedChangesNow()
            guard !isSetupCompleted, finishStart == nil, let existing = existingProfile() else { return }
            currentProfileID = existing.id.uuidString
            markCompleted()   // isSetupCompleted が 立つと 前から いる 人の `onboardedAt` は 次の 書きこみで 入る
        }
    }

    private func existingProfile() -> UserProfile? {
        let all = (try? modelContext.fetch(FetchDescriptor<UserProfile>())) ?? []
        let recordName = CloudKitManager.current?.currentUserRecordName
        return all.first { p in
            if !appleUserID.isEmpty, p.appleUserID == appleUserID { return true }
            if !firebaseUID.isEmpty, p.firebaseUID == firebaseUID { return true }
            if let recordName, p.cloudKitUserRecordName == recordName, !p.name.isEmpty { return true }
            return false
        }
    }

    // MARK: - 保存(これまでと 同じ)

    private func confirmName() {
        let validation = OnboardingRules.validateName(name)
        guard validation.problem == nil else { return }
        let n = validation.name
        let profile: UserProfile
        if let existing = UserProfile.current(from: profiles) { profile = existing }
        else { profile = UserProfile(name: n, username: OnboardingRules.generatedUsername()); modelContext.insert(profile) }
        profile.name = n
        if profile.username.isEmpty { profile.username = OnboardingRules.generatedUsername() }
        if !appleUserID.isEmpty { profile.appleUserID = appleUserID }
        if !firebaseUID.isEmpty { profile.firebaseUID = firebaseUID; profile.firebaseEmail = firebaseEmail.isEmpty ? nil : firebaseEmail }
        if let iconData { profile.profileImageData = iconData; UserDefaults.standard.set(iconData, forKey: "profileImageData") }
        profile.profileUpdatedAt = Date()
        LaterGroup.ensurePersonalSpace(for: profile, context: modelContext)
        do { try modelContext.save() } catch { print("[Onboarding] 名前の保存に失敗: \(error)") }
        currentProfileID = profile.id.uuidString
        userName = n
        userID = profile.username
        // v106:ここでは 公開 ディレクトリに 書かない(さいごの ながおしが 終わった あとに だけ)
    }

    /// ID を とって 保存(同じ ID は だめ)。とれたら 次へ
    private func confirmHandle() {
        guard let profile = UserProfile.current(from: profiles), !busy else { return }
        busy = true
        let h = HandleRules.normalize(handle)
        Task { @MainActor in
            let r = await HandleService.claim(h, ownerKey: profile.id.uuidString, previous: nil)
            busy = false
            if r == .mine || r == .ok {
                profile.username = h; profile.profileUpdatedAt = Date(); try? modelContext.save(); userID = h
                go(.tag)
            } else { Haptics.play(.warn); handleState = r }
        }
    }

    private func confirmTags() {
        guard let profile = UserProfile.current(from: profiles) else { return }
        profile.selfTags = tags
        profile.profileUpdatedAt = Date()
        try? modelContext.save()
        if let manager = CloudKitManager.current { for group in profile.groups { manager.markForUpload(userProfile: profile, in: group) } }
    }

    // MARK: - 友だち(O09)

    /// 開いた 友だちリンクの 相手を 申請の 行に 出す(名前は 公開ディレクトリから)
    private func loadInviter() {
        guard invitedBy == nil, let rn = UserDefaults.standard.string(forKey: "pendingFriendRecordName") else { return }
        invitedRecord = rn
        Task { @MainActor in
            let profile = await UserDirectoryService.fetchProfile(cloudKitUserRecordName: rn)
            invitedBy = (profile?.name.isEmpty == false) ? profile!.name : "ともだち"
        }
    }

    /// 「申請」を 押した まま 次へ 進んだ:つながる(相手も 押すと 相互)。通信が まだ なら 控えを 残して あとで
    private func sendFriendRequest() {
        guard requestedInvite, let rn = invitedRecord else { return }
        let myName = name
        Task { @MainActor in
            if await FriendRequests.send(to: rn, toName: invitedBy ?? "", myName: myName) {
                UserDefaults.standard.removeObject(forKey: "pendingFriendRecordName")
            }
        }
    }

    // MARK: - タグ・色・写真

    private func pickColor(_ i: Int) { photo = nil; col = i }

    private func toggleTag(_ t: String) {
        if let i = tags.firstIndex(of: t) { tags.remove(at: i); Haptics.play(.tick); return }
        guard tags.count < 3 else { Haptics.play(.warn); say("タグは 3つまで"); return }
        tags.append(t); Haptics.play(.pop)
    }

    private func commitCustomTag() {
        addingTag = false
        guard let t = OnboardingRules.normalizedTag(customDraft) else { customDraft = ""; return }
        customDraft = ""
        if !tags.contains(t) { toggleTag(t) }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task { @MainActor in
            guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
            photo = image
            Haptics.play(.pop)
            if let profile = UserProfile.current(from: profiles) {
                ProfilePhotoDevelopment.store(CapturedImageCompressor.compressedImageData(from: data), for: profile, context: modelContext)
            }
        }
    }

    // MARK: - 通知 → はじまる

    private func allowNotifications() {
        guard !busy else { return }
        busy = true
        Haptics.play(.success)
        Task { @MainActor in
            defer { busy = false }
            _ = await DailyOpenNotification.requestAuthorization(timeout: 10)
            Task { _ = await DailyOpenNotification.schedule() }
            go(.go)
        }
    }

    private func spawnSpark() {
        guard !reduceMotion, sparks.count < 24 else { return }
        sparks.append(Spark(angle: .random(in: 0..<(2 * .pi)), radius: 170 + .random(in: 0..<90)))
        let cutoff = Date().addingTimeInterval(-0.6)
        sparks.removeAll { $0.born < cutoff }
    }

    private func beginFinish() {
        // v106:完了の 印は ながおしの 演出が 終わった 時に だけ(ここでは 立てない)。うしろの Home だけ 用意する
        OnboardingRuntime.shared.finishing = true
        sparks = []
        finishStart = Date()
    }

    /// 演出が おわった:Home へ
    private func completeFinish() {
        #if DEBUG
        // 見た目の 確認用:完了に しないで もどす(-debugNoComplete 1)
        if UserDefaults.standard.bool(forKey: "debugNoComplete") { finishStart = nil; OnboardingRuntime.shared.finishing = false; return }
        #endif
        markCompleted()
        if let p = UserProfile.current(from: profiles) { Task { await UserDirectoryService.publish(p, finishingOnboarding: true) } }
    }

    private func markCompleted() {
        savedStep = ""
        OnboardingRuntime.shared.finishing = false
        onboardingCompleted = true
        if UserDefaults.standard.object(forKey: "onboardingCompletedAt") == nil { UserDefaults.standard.set(Date(), forKey: "onboardingCompletedAt") }
        hasSeenWelcomeOnboarding = true; hasCompletedSurvey = true; hasSeenAboutLaterIntro = true
        isProfileSetupCompleted = true
        isSetupCompleted = true
    }

    // MARK: - 小物

    private func say(_ text: String) {
        withAnimation(.easeOut(duration: 0.2)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { if toast == text { withAnimation(.easeIn(duration: 0.2)) { toast = nil } } }
    }

    private var shareItems: [Any] {
        guard let rn = CloudKitManager.current?.currentUserRecordName else { return [LattagShareItem(text: "\(Brand.name) で ともだちに なろう", title: "Lattag の 友だち申請")] }
        return [FriendRules.shareItem(myName: "", recordName: rn)]
    }
}

// MARK: - 小さな 部品


private struct OBPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.timingCurve(0.3, 1.6, 0.4, 1, duration: 0.25), value: configuration.isPressed)
    }
}

/// Sign in with Apple を コードから 出す(名前だけ もらう)
final class OBAppleCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let done: (Result<ASAuthorization, Error>, String) -> Void
    private let hideEmail: Bool
    private let nonce = AppleFirebaseAuth.Nonce.make()
    init(hideEmail: Bool = true, done: @escaping (Result<ASAuthorization, Error>, String) -> Void) { self.hideEmail = hideEmail; self.done = done }

    @MainActor func start() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        // メールを かくす = 何も もらわない(名前は つぎの 画面で 自分で 書く)/ オフ = 本人が Apple の 画面で えらぶ
        request.requestedScopes = hideEmail ? [] : [.email]
        request.nonce = nonce.hashed   // v104:Firebase に のせる ための nonce
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) { done(.success(authorization), nonce.raw) }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) { done(.failure(error), nonce.raw) }
    @MainActor func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? ASPresentationAnchor()
    }
}

private struct OBChipPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.timingCurve(0.3, 1.6, 0.4, 1, duration: 0.2), value: configuration.isPressed)
    }
}

/// 中央そろえで 折り返す(チップ)
struct OBFlow: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(in: proposal.width ?? 390, subviews: subviews)
        let h = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * rowSpacing
        return CGSize(width: proposal.width ?? 390, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(in: bounds.width, subviews: subviews) {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for i in row.indices {
                let s = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func rows(in width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let s = subviews[i].sizeThatFits(.unspecified)
            let add = (rows[rows.count - 1].indices.isEmpty ? 0 : spacing) + s.width
            if rows[rows.count - 1].width + add > width, !rows[rows.count - 1].indices.isEmpty { rows.append(Row()) }
            let k = rows.count - 1
            rows[k].width += (rows[k].indices.isEmpty ? 0 : spacing) + s.width
            rows[k].height = max(rows[k].height, s.height)
            rows[k].indices.append(i)
        }
        return rows
    }
}

/// ながおしの 火花(外から 中心へ すいこまれる)
private struct OBSparkView: View {
    let spark: OnboardingV64View.Spark
    let center: CGPoint
    let strength: Double

    var body: some View {
        TimelineView(.animation) { ctx in
            let k = min(1, ctx.date.timeIntervalSince(spark.born) / (0.52 - strength * 0.2))
            let r = spark.radius * (1 - k)
            Circle().fill(Color(hex: "86E499")).frame(width: 4, height: 4)
                .shadow(color: OB.stamp, radius: 4)
                .scaleEffect(1 - 0.6 * k).opacity(k < 0.2 ? k / 0.2 : 1 - (k - 0.2) / 0.8)
                .position(x: center.x + cos(spark.angle) * r, y: center.y + sin(spark.angle) * r)
        }
        .allowsHitTesting(false)
    }
}

/// はじまりの 演出(`obFinish`):まっ白 → 「Lattag」が どんと → ブイッ → 白い 円が ひろがって Home へ(2.4秒)
struct OBFinishView: View {
    let start: Date
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var done = false

    var body: some View {
        GeometryReader { g in
            TimelineView(.animation) { ctx in
                #if DEBUG
                let t = OnboardingDebug.finishT ?? ctx.date.timeIntervalSince(start)
                #else
                let t = ctx.date.timeIntervalSince(start)
                #endif
                let end = reduceMotion ? 1.4 : 2.4
                content(t: t, size: g.size)
                    .onChange(of: t >= end) { _, d in if d { finish() } }
            }
        }
        .onAppear(perform: schedule)
        .allowsHitTesting(true)
    }

    private func p(_ t: Double, _ s: Double, _ d: Double) -> Double { min(1, max(0, (t - s) / d)) }

    private func content(t: Double, size: CGSize) -> some View {
        let flash: Double = reduceMotion ? 0 : { let q = p(t, 0, 0.62); return q < 0.25 ? 1 : 1 - (q - 0.25) / 0.75 }()
        let k = OpeningEase.bezier(0.2, 0.8, 0.3, 1, p(t, 0.16, 0.64))
        let scale: CGFloat = reduceMotion ? 1 : (k < 0.6 ? 3.2 - 2.28 * CGFloat(k / 0.6) : (k < 0.8 ? 0.92 + 0.11 * CGFloat((k - 0.6) / 0.2) : 1.03 - 0.03 * CGFloat((k - 0.8) / 0.2)))
        let iris = OpeningEase.bezier(0.6, 0, 0.2, 1, p(t, 1.7, 0.76))
        // 0.52s から 0.32秒:画面が ぶるっと ゆれる
        let sh = p(t, 0.52, 0.32)
        let dx: CGFloat = reduceMotion || sh <= 0 || sh >= 1 ? 0 : [-6, 5, -3, 0][min(3, Int(sh * 4))]
        let dy: CGFloat = reduceMotion || sh <= 0 || sh >= 1 ? 0 : [3, -4, 2, 0][min(3, Int(sh * 4))]
        return ZStack {
            Color.black
            Text(Brand.name).font(Typo.ui(900, 112)).tracking(-0.075 * 112).foregroundStyle(.white).fixedSize()
                .scaleEffect(scale).blur(radius: reduceMotion ? 0 : 16 * (1 - k)).opacity(reduceMotion ? 1 : k)
                .offset(x: dx, y: dy)
            Color.white.opacity(flash)
            Circle().fill(.white).frame(width: 600, height: 600)
                .scaleEffect(reduceMotion ? 0 : 3.4 * iris)
                .position(x: size.width / 2, y: size.height)
        }
        .frame(width: size.width, height: size.height)
    }

    private func schedule() {
        Haptics.play(.shutter)
        func at(_ s: Double, _ work: @escaping () -> Void) { DispatchQueue.main.asyncAfter(deadline: .now() + s) { if !done { work() } } }
        at(0.52) { Haptics.play(.vui) }
        at(1.7) { Haptics.play(.soft) }
    }

    private func finish() {
        guard !done else { return }
        done = true
        onDone()
    }
}


// MARK: - v104 O04:Apple の 丸い ボタン(丸の 中は かえない ・ 動きは 丸の 外だけ)

struct OBAppleCircle: View {
    var busy: Bool
    var glow: Bool
    var reduceMotion: Bool
    var action: () -> Void
    @State private var entered = false
    @State private var spin = 0.0
    @State private var spinStart = Date()

    var body: some View {
        Button(action: action) {
            ZStack {
                // 丸の 外:点線の 輪 ・ 波紋(`transform` と `opacity` だけ)
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    ZStack {
                        if !reduceMotion {
                            ForEach(0..<2, id: \.self) { k in
                                let q = (t / 2.8 + Double(k) * 0.5).truncatingRemainder(dividingBy: 1)
                                Circle().strokeBorder(HV.lime.opacity(0.55 * (1 - q)), lineWidth: 1.5).frame(width: 88, height: 88).scaleEffect(1 + 0.62 * q)
                            }
                        }
                        Circle().strokeBorder(HV.lime.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [3, 4])).frame(width: 106, height: 106)
                            .rotationEffect(.degrees(reduceMotion ? 0 : t / (busy ? 1.1 : 14) * 360))
                        if busy {
                            Circle().trim(from: 0, to: 0.22).stroke(HV.lime, style: StrokeStyle(lineWidth: 3, lineCap: .round)).frame(width: 106, height: 106)
                                .rotationEffect(.degrees(t / 0.9 * 360))
                        }
                    }
                }
                if glow { Circle().strokeBorder(HV.lime, lineWidth: 4).frame(width: 96, height: 96).blur(radius: 3).transition(.opacity) }
                // 丸の 中:白い 面 + 黒い ロゴ(かえない)
                Circle().fill(Color.white).frame(width: 88, height: 88)
                Image(systemName: "apple.logo").font(.system(size: 42)).foregroundStyle(Color.black).opacity(busy ? 0.35 : 1)
            }
            .frame(width: 112, height: 112)
            .scaleEffect(entered || reduceMotion ? 1 : 0.6).opacity(entered || reduceMotion ? 1 : 0)
        }
        .buttonStyle(OBApplePress())
        .disabled(busy)
        .accessibilityLabel("Apple で つづける").accessibilityAddTraits(.isButton)
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) { entered = true } }
    }
}

private struct OBApplePress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.93 : 1).animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
