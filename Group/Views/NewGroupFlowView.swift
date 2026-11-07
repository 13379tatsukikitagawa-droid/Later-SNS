import SwiftUI
import SwiftData
import UIKit

// MARK: - グループ作成(3ステップ・v12)

// ① 名前 → ② 顔 → ③ 呼ぶ。上に進みのバー。昼は白・夜は黒(ThemeClock の palette にしたがう)。
// グループが CloudKit に作られるのは、③の「つくって、リンクを送る」「あとで呼ぶ」を押した瞬間だけ。
// 合言葉・リンクは、つくったあとに決まる(重ならないものをサーバーに登録するため)。

// MARK: 名前の決めごと(画面を持たない)

enum GroupCreateName {
    static let maxLength = 12

    static let seeds = ["帰り道の4人", "朝活ぐみ", "しずかな会", "ゼミ", "部活", "クラス"]

    enum Status: Equatable {
        case empty
        /// 12文字をこえた(こえた文字数)
        case over(Int)
        case ok
    }

    /// 入力中:改行だけ取る。文字数では切らない(変換中の文字が消えるため)
    static func clean(_ input: String) -> String {
        input.filter { !$0.isNewline }
    }

    /// 確定:前後の空白(半角・全角)を取る
    static func finalize(_ input: String) -> String {
        clean(input).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 文字数は書記素で数える(絵文字も1文字)
    static func count(_ input: String) -> Int { finalize(input).count }

    static func status(_ input: String) -> Status {
        let n = count(input)
        if n == 0 { return .empty }
        if n > maxLength { return .over(n - maxLength) }
        return .ok
    }

    static func buttonTitle(_ status: Status) -> String {
        switch status {
        case .empty: return "名前を いれてね"
        case .over(let n): return "\(n)文字、へらしてね"
        case .ok: return "つぎへ"
        }
    }

    /// もう使っている名前は出さない
    static func seeds(excluding names: [String]) -> [String] {
        let used = Set(names.map(finalize))
        return seeds.filter { !used.contains($0) }
    }

    static func initial(_ input: String) -> String {
        String(finalize(input).prefix(1))
    }
}

// MARK: 色(昼は白・夜は黒。文字と背景のコントラスト比 4.5 以上)

struct GroupCreateColors {
    let night: Bool

    var bg: Color { night ? Color(hex: "000000") : Color(hex: "FFFFFF") }
    var ink: Color { night ? Color(hex: "FFFFFF") : Color(hex: "111114") }
    var sub: Color { night ? Color(hex: "A9A9B1") : Color(hex: "5F5F66") }
    var field: Color { night ? Color(hex: "1C1C1F") : Color(hex: "F3F3F6") }
    var placeholder: Color { night ? Color(hex: "8E8E96") : Color(hex: "6B6B73") }
    var line: Color { night ? Color(hex: "4A4A50") : Color(hex: "C9C9D1") }
    var primaryBg: Color { night ? Color(hex: "FFFFFF") : Color(hex: "111114") }
    var primaryText: Color { night ? Color(hex: "111114") : Color(hex: "FFFFFF") }
    var disabledBg: Color { night ? Color(hex: "2C2C30") : Color(hex: "E3E3E8") }
    var disabledText: Color { night ? Color(hex: "A9A9B1") : Color(hex: "5F5F66") }
    var accent: Color { night ? Color(hex: "FF8A3D") : Color(hex: "FF6A1A") }
    var warn: Color { night ? Color(hex: "FF7A66") : Color(hex: "D93A28") }

    static let lineWidth: CGFloat = 1.5
}

// MARK: - 本体

struct NewGroupFlowView: View {
    /// 最初から入れておくグループ名(空の GROUP 画面のステッカーから。nil なら空)
    var initialName: String? = nil
    /// 見た目の確認用:はじめのステップ(1・2。3 は「できました」)
    var startStep: Int = 1
    let onClose: () -> Void

    /// ① 名前 → ② 顔と人数(ここで「つくる」)→ できました(合言葉・リンク)。進みの棒は2本
    private enum Step: Int { case name = 1, face, done }
    private static let stepCount = 2

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.palette) private var palette
    @Query private var profiles: [UserProfile]

    @State private var step: Step = .name
    @State private var name = ""
    @State private var isComposing = false
    @State private var isNameFocused = false
    @State private var keyboardUp = false
    @State private var scrollHeight: CGFloat = 600
    @State private var fieldShake = 0
    @State private var buttonShake = 0
    @State private var wasOver = false
    @State private var discBump = false

    @State private var faceStyle = GroupFaceStyle.aura
    /// 手で選んだ色(nil なら名前から決める)
    @State private var chosenColor: Int?
    @State private var showsInitial = true
    @State private var memberLimit = GroupMembershipPolicy.maxMembersPerGroup

    @State private var isCreating = false
    /// 作成に 15秒 以上 かかっている
    @State private var slowCreating = false
    @State private var burst = false
    @State private var burstExpanded = false
    @State private var errorMessage: String?
    @State private var createdGroup: LaterGroup?
    /// 作ったあと:前の完了画面(GroupCreatedShareView)を出す
    @State private var showingCreatedShare = false
    @State private var createdShareURL: URL?
    /// iCloud の容量不足で、写真だけ除いて作れたときの注意文言
    @State private var createdWarning: String?
    @State private var passphrase: String?
    @State private var inviteLink: URL?
    @State private var shareItems: ShareItems?
    @State private var copied: String?
    @State private var doneAppeared = false
    @State private var haptics = ExposureHaptics()

    private struct ShareItems: Identifiable {
        let id = UUID()
        let items: [Any]
    }

    private var colors: GroupCreateColors { GroupCreateColors(night: palette.isNight) }
    private var currentUser: UserProfile? { UserProfile.current(from: profiles) }
    private var finalName: String { GroupCreateName.finalize(name) }
    private var nameStatus: GroupCreateName.Status { GroupCreateName.status(name) }
    private var colorIndex: Int { chosenColor ?? GroupPalette.index(forName: finalName) }
    private var shownInitial: String { showsInitial ? GroupCreateName.initial(name) : "" }
    private var myGroupNames: [String] { currentUser?.groups.filter { !$0.isPersonalSpace }.map(\.name) ?? [] }
    /// 10個のときは、つくらせない
    private var isFull: Bool { myGroupNames.count >= GroupMembershipPolicy.maxGroupsPerUser && createdGroup == nil }

    var body: some View {
        ZStack(alignment: .top) {
            colors.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                GeometryReader { proxy in
                    ScrollViewReader { reader in
                        ScrollView {
                            content
                                .id(step)
                                .transition(.opacity)
                                .padding(.bottom, 16)
                                .frame(maxWidth: .infinity)
                                .background {
                                    // 空いている所を押すと、キーボードを閉じる(たね・×では閉じない)
                                    Color.clear.contentShape(Rectangle()).onTapGesture { isNameFocused = false }
                                }
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .scrollBounceBehavior(.basedOnSize)
                        .onChange(of: keyboardUp) { _, up in
                            if up, step == .name {
                                withAnimation(.easeOut(duration: 0.25)) { reader.scrollTo("nameField", anchor: .center) }
                            }
                        }
                    }
                    .onAppear { scrollHeight = proxy.size.height }
                    .onChange(of: proxy.size.height) { _, h in scrollHeight = h }
                }
            }
            // 「つぎへ」はキーボードのすぐ上に固定(キーボードの高さは OS から)
            .safeAreaInset(edge: .bottom) { bottomArea }

            if burst {
                Circle()
                    .fill(RadialGradient(colors: [.white, Color(hex: "FFD2AE"), .clear], center: .center, startRadius: 0, endRadius: 40))
                    .frame(width: 80, height: 80)
                    .scaleEffect(burstExpanded ? 20 : 0.5)
                    .opacity(burstExpanded ? 0 : 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        // ステータスバー・キーボードも、画面の色にあわせる
        .preferredColorScheme(colors.night ? .dark : .light)
        .onAppear {
            haptics.prepare()
            if let initialName, name.isEmpty { name = GroupCreateName.clean(initialName) }
            if let first = Step(rawValue: startStep), first != .name { step = first }
        }
        .onDisappear { haptics.tearDown() }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardUp = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardUp = false }
        }
        .sheet(item: $shareItems) { share in
            ShareSheet(activityItems: share.items) { _ in shareItems = nil }
                .presentationDetents([.medium, .large])
        }
        // 作ったあとは、前の完了画面(招待リンクを送る / リンクをコピー / あとで送る)。閉じたら、作成の画面ごと閉じる
        .sheet(isPresented: $showingCreatedShare, onDismiss: onClose) {
            GroupCreatedShareView(groupName: createdGroup?.name ?? finalName, shareURL: createdShareURL, warningMessage: createdWarning,
                                  makeLink: createdGroup.map { group in
                                      { await Self.makeLink(for: group, context: modelContext).flatMap { InviteConfig.shareURL(from: $0) } }
                                  })
        }
    }

    // MARK: 上(× / ← ・「1 / 3」・進みのバー)

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack {
                switch step {
                case .name:
                    circleButton("xmark", label: "とじる", action: onClose)
                case .face:
                    if isCreating {
                        // つくっている間は、もどらない(連打・二重作成を防ぐ)
                        Color.clear.frame(width: 44, height: 44)
                    } else {
                        circleButton("arrow.left", label: "もどる") { go(to: .name) }
                    }
                case .done:
                    // もう作ってあるので「もどる」ではなく「閉じる」
                    circleButton("xmark", label: "とじる", action: onClose)
                }
                Spacer()
                if step != .done {
                    Text("\(step.rawValue) / \(Self.stepCount)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(colors.sub)
                        .accessibilityHidden(true)
                }
            }
            if step != .done {
                HStack(spacing: 6) {
                    ForEach(1...Self.stepCount, id: \.self) { index in
                        Capsule()
                            .fill(index <= step.rawValue ? colors.ink : colors.line)
                            .frame(height: 3)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("ステップ \(step.rawValue) / \(Self.stepCount)")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private func circleButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(colors.ink)
                .frame(width: 44, height: 44)
                .background(Circle().fill(colors.field))
                .overlay(Circle().strokeBorder(colors.line, lineWidth: GroupCreateColors.lineWidth))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .name: nameStep
        case .face: faceStep
        case .done: doneStep
        }
    }

    // MARK: ① 名前

    /// キーボード中で、高さが足りない(iPhone SE など)ときは、プレビューを消す
    private var hidesPreview: Bool { keyboardUp && scrollHeight < 300 }

    private var nameStep: some View {
        VStack(spacing: 0) {
            if !hidesPreview {
                GroupCircle(initial: GroupCreateName.initial(name), colorIndex: colorIndex, memberLimit: memberLimit, litCount: 1,
                            diameter: keyboardUp ? 76 : 200, rotates: !keyboardUp, discScale: discBump ? 1.04 : 1, ringInk: colors.ink)
                    .padding(.top, keyboardUp ? 4 : 14)
                    .accessibilityHidden(true)
            }
            Text(keyboardUp ? "グループに、名前をつけます。" : "グループに、\n名前をつけます。")
                .font(.system(size: keyboardUp ? 19 : 27, weight: .bold))
                .tracking(-0.04 * 27)
                .multilineTextAlignment(.center)
                .foregroundStyle(colors.ink)
                .lineLimit(keyboardUp ? 1 : 2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.top, keyboardUp ? 8 : 18)
                .accessibilityAddTraits(.isHeader)

            nameField
                .id("nameField")
                .padding(.horizontal, 20)
                .padding(.top, keyboardUp ? 10 : 20)

            seedsView
                .padding(.top, keyboardUp ? 10 : 18)

            if !keyboardUp {
                Text("みんなに見える名前です。実名や学校名は避けましょう。")
                    .font(.system(size: 12))
                    .foregroundStyle(colors.sub)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
            }
        }
    }

    private var nameField: some View {
        let over: Bool = { if case .over = nameStatus { return true } else { return false } }()
        let count = GroupCreateName.count(name)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("グループの名前")
                Spacer()
                Text("\(count) / \(GroupCreateName.maxLength)")
                    .monospacedDigit()
                    .foregroundStyle(over ? colors.warn : colors.sub)
                    .fontWeight(over ? .bold : .regular)
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(colors.sub)
            .accessibilityHidden(true)
            HStack(spacing: 8) {
                GroupNameTextField(
                    text: $name,
                    isFocused: $isNameFocused,
                    isComposing: $isComposing,
                    placeholder: "たとえば「帰り道の4人」",
                    textColor: UIColor(colors.ink),
                    placeholderColor: UIColor(colors.placeholder),
                    tintColor: UIColor(colors.accent),
                    dark: colors.night,
                    accessibilityValue: "\(count)文字、\(GroupCreateName.maxLength)文字まで",
                    onSubmit: submitName
                )
                .frame(height: 40)
                if !name.isEmpty {
                    Button {
                        LayerHaptics.light()
                        name = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(colors.sub)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("名前を消す")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(colors.field))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(over ? colors.warn : (isNameFocused ? colors.accent : colors.line), lineWidth: GroupCreateColors.lineWidth)
        )
        .modifier(GroupCreateShake(trigger: fieldShake, enabled: !reduceMotion))
        .contentShape(Rectangle())
        .onTapGesture { isNameFocused = true }
        .onChange(of: name) { _, value in
            let clean = GroupCreateName.clean(value)
            if clean != value { name = clean; return }
            bumpDisc()
            checkOver()
        }
        .onChange(of: isComposing) { _, _ in checkOver() }
    }

    private var seedsView: some View {
        let seeds = GroupCreateName.seeds(excluding: myGroupNames)
        return VStack(alignment: .leading, spacing: 8) {
            Text("思いつかないときは")
                .font(.system(size: 12))
                .foregroundStyle(colors.sub)
                .padding(.horizontal, 24)
            if keyboardUp {
                // キーボード中は1行(横にスクロール)にまとめる
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) { ForEach(seeds, id: \.self, content: seedChip) }
                        .padding(.horizontal, 20)
                }
            } else {
                OnboardingFlowLayout(spacing: 8) { ForEach(seeds, id: \.self, content: seedChip) }
                    .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func seedChip(_ seed: String) -> some View {
        Button {
            LayerHaptics.light()
            name = seed
        } label: {
            Text(seed)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(colors.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 38)
                .background(Capsule().fill(colors.field))
                .overlay(Capsule().strokeBorder(colors.line, lineWidth: GroupCreateColors.lineWidth))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel("名前のたね、\(seed)")
    }

    private func submitName() {
        // 変換を確定するだけの Enter では進まない(isComposing は入力欄が見る)
        guard nameStatus == .ok else {
            refuse()
            return
        }
        LayerHaptics.light()
        go(to: .face)
    }

    /// 12文字をこえた瞬間:やわらかく2回 + 入力欄がゆれる(変換中は待つ)
    private func checkOver() {
        let over: Bool = { if case .over = nameStatus { return true } else { return false } }()
        guard !isComposing else { return }
        if over && !wasOver {
            LayerHaptics.softDouble()
            fieldShake += 1
        }
        wasOver = over
    }

    /// 押せない「つぎへ」:やわらかく2回 + ボタンがゆれる + 入力欄にもどる
    private func refuse() {
        LayerHaptics.softDouble()
        buttonShake += 1
        isNameFocused = true
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: GroupCreateName.buttonTitle(nameStatus))
        }
    }

    // MARK: ② 顔

    private var faceStep: some View {
        VStack(spacing: 0) {
            GroupCircle(initial: shownInitial, colorIndex: colorIndex, memberLimit: memberLimit, litCount: 1,
                        diameter: 200, discScale: discBump ? 1.04 : 1, ringInk: colors.ink)
                .overlay(alignment: .bottomTrailing) {
                    if faceStyle == GroupFaceStyle.photo {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(colors.primaryText)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(colors.primaryBg))
                            .offset(x: -26, y: -26)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.top, 10)
                .accessibilityElement()
                .accessibilityLabel("グループの顔のプレビュー")

            Text("グループの、顔を決めます。")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(colors.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .accessibilityAddTraits(.isHeader)

            // しゅるい
            HStack(spacing: 8) {
                kindButton(GroupFaceStyle.aura, "色", "circle.lefthalf.filled")
                kindButton(GroupFaceStyle.photo, "みんなの写真", "photo.stack")
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            if faceStyle == GroupFaceStyle.photo {
                Text("みんなが撮った今日の写真が、グループの顔になります。まだ1枚もないときは、色が出ます。")
                    .font(.system(size: 13))
                    .foregroundStyle(colors.sub)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
            }

            card(title: faceStyle == GroupFaceStyle.photo ? "写真がない日の色" : "色") { swatches }
                .padding(.top, 14)

            card(title: nil) {
                Toggle(isOn: Binding(get: { showsInitial }, set: { value in
                    LayerHaptics.light()
                    withAnimation(.easeOut(duration: 0.2)) { showsInitial = value }
                })) {
                    Text("名前の1文字目を入れる")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(colors.ink)
                }
                .tint(colors.accent)
            }
            .padding(.top, 10)

            card(title: "人数の上限") { limitPicker }
                .padding(.top, 10)
        }
    }

    private func card<Inner: View>(title: String?, @ViewBuilder inner: () -> Inner) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(colors.sub)
            }
            inner()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(colors.field))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(colors.line, lineWidth: GroupCreateColors.lineWidth))
        .padding(.horizontal, 20)
    }

    private func kindButton(_ value: String, _ title: String, _ icon: String) -> some View {
        let selected = faceStyle == value
        return Button {
            guard !selected else { return }
            LayerHaptics.light()
            withAnimation(.easeOut(duration: 0.2)) { faceStyle = value }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                Text(title).font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(selected ? colors.primaryText : colors.ink)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(Capsule().fill(selected ? colors.primaryBg : colors.field))
            .overlay(Capsule().strokeBorder(selected ? Color.clear : colors.line, lineWidth: GroupCreateColors.lineWidth))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var swatches: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<GroupPalette.count, id: \.self) { index in
                let palette = GroupRingMath.auraPalettes[index]
                let selected = colorIndex == index
                Button {
                    LayerHaptics.light()
                    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6)) { chosenColor = index }
                    bumpDisc()
                } label: {
                    Circle()
                        .fill(LinearGradient(colors: [palette[0], palette[1]], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                        .overlay(Circle().strokeBorder(colors.ink, lineWidth: selected ? 2.5 : 0).padding(-5))
                        .scaleEffect(selected && !reduceMotion ? 1.12 : 1)
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("顔の色 \(index + 1)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var limitPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(Array(GroupMembershipPolicy.memberLimitRange), id: \.self) { value in
                    let selected = memberLimit == value
                    Button {
                        LayerHaptics.light()
                        withAnimation(.easeOut(duration: 0.2)) { memberLimit = value }
                    } label: {
                        Text("\(value)")
                            .font(.system(size: 17, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(selected ? colors.primaryText : colors.ink)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(Capsule().fill(selected ? colors.primaryBg : colors.bg))
                            .overlay(Capsule().strokeBorder(selected ? Color.clear : colors.line, lineWidth: GroupCreateColors.lineWidth))
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityLabel("\(value)人まで")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            Text("あとから変えられます")
                .font(.system(size: 12))
                .foregroundStyle(colors.sub)
        }
    }

    // MARK: できました(つくったあと):合言葉・リンク

    private var doneStep: some View {
        let members = max(1, createdGroup?.members.count ?? 1)
        return VStack(spacing: 0) {
            GroupCircle(image: nil, initial: shownInitial, colorIndex: colorIndex, memberLimit: memberLimit, litCount: members,
                        diameter: 150, discScale: discBump ? 1.04 : 1, ringInk: colors.ink)
                .padding(.top, 8)
                .accessibilityHidden(true)

            Text("できました。\nなかまを、呼びましょう。")
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.03 * 26)
                .foregroundStyle(colors.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .accessibilityAddTraits(.isHeader)
                .modifier(DoneStagger(index: 0, appeared: doneAppeared, reduceMotion: reduceMotion))

            VStack(spacing: 4) {
                Text(createdGroup?.name ?? finalName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(colors.ink)
                Text("\(memberLimit)人まで ・ いま \(members)人")
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(colors.sub)
            }
            .padding(.top, 10)
            .accessibilityElement(children: .combine)
            .modifier(DoneStagger(index: 1, appeared: doneAppeared, reduceMotion: reduceMotion))

            VStack(spacing: 10) {
                copyRow(title: "合言葉", value: passphrase, icon: "key")
                copyRow(title: "招待リンク", value: inviteLink?.absoluteString, icon: "link")
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .modifier(DoneStagger(index: 2, appeared: doneAppeared, reduceMotion: reduceMotion))

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colors.warn)
                    .cloudDiagnosticsOnLongPress()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .transition(.opacity)
            }
        }
        .onAppear { doneAppeared = true }
    }

    private func copyRow(title: String, value: String?, icon: String) -> some View {
        let ready = value != nil
        let pending = "用意しています…"
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(colors.sub)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(colors.sub)
                Text(value ?? pending)
                    .font(.system(size: ready ? 15 : 14, weight: ready ? .bold : .regular, design: ready ? .monospaced : .default))
                    .foregroundStyle(ready ? colors.ink : colors.sub)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Button {
                guard let value else { return }
                LayerHaptics.light()
                UIPasteboard.general.string = value
                withAnimation(.easeOut(duration: 0.2)) { copied = title }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { if copied == title { withAnimation { copied = nil } } }
            } label: {
                Text(copied == title ? "コピーしました" : "コピー")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ready ? colors.primaryText : colors.disabledText)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(Capsule().fill(ready ? colors.primaryBg : colors.disabledBg))
            }
            .buttonStyle(PressScaleStyle())
            .disabled(!ready)
            .accessibilityLabel("\(title)をコピー")
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 64)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(colors.field))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(colors.line, lineWidth: GroupCreateColors.lineWidth))
        .accessibilityElement(children: .contain)
    }

    // MARK: 下のボタン(キーボードのすぐ上)

    @ViewBuilder
    private var bottomArea: some View {
        VStack(spacing: 6) {
            switch step {
            case .name:
                primaryButton(GroupCreateName.buttonTitle(nameStatus), enabled: nameStatus == .ok) {
                    if nameStatus == .ok {
                        LayerHaptics.light()
                        go(to: .face)
                    } else {
                        refuse()
                    }
                }
                .modifier(GroupCreateShake(trigger: buttonShake, enabled: !reduceMotion))
            case .face:
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(colors.warn)
                        .cloudDiagnosticsOnLongPress()
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
                if slowCreating {
                    Text("時間が かかっています。つながりを たしかめています…")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(colors.sub)
                        .multilineTextAlignment(.center)
                        .cloudDiagnosticsOnLongPress()
                        .transition(.opacity)
                }
                // 押したら止める(連打しても1つだけ)。10個のときは、つくらせない
                primaryButton(createTitle, enabled: !isCreating && !isFull) {
                    guard !isCreating, !isFull else { if isFull { LayerHaptics.softDouble() }; return }
                    create()
                }
                .disabled(isCreating)
            case .done:
                primaryButton("リンクを送る", enabled: inviteLink != nil) { shareLink() }
                Button(action: onClose) {
                    Text("あとで呼ぶ")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(colors.ink)
                        .underline()
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityHint("閉じます。合言葉は、グループの設定からいつでも見られます")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, keyboardUp ? 8 : 12)
        .background(colors.bg.ignoresSafeArea())
    }

    /// 押せないときも、文字が読める色(薄くするのではなく、色をかえる)。押せないときも押せる(理由を伝える)
    private func primaryButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(enabled ? colors.primaryText : colors.disabledText)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Capsule().fill(enabled ? colors.primaryBg : colors.disabledBg))
        }
        .buttonStyle(PressScaleStyle(scale: 0.97))
        .accessibilityHint(enabled ? "" : "まだ押せません")
    }

    // MARK: 共通

    private func go(to next: Step) {
        isNameFocused = false
        errorMessage = nil
        withAnimation(.easeInOut(duration: reduceMotion ? 0.2 : 0.4)) { step = next }
    }

    /// 丸が 1.04 倍にぽんと跳ねて戻る(視差を減らすなら出さない)
    private func bumpDisc() {
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.13)) { discBump = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { withAnimation(.easeIn(duration: 0.13)) { discBump = false } }
    }

    private var createTitle: String {
        if isFull { return "グループは、\(GroupMembershipPolicy.maxGroupsPerUser)個までです" }
        return isCreating ? "つくっています…" : "つくる"
    }

    /// 共有シート:ただの文字ではなく、Later のアイコンつきのリンク(LPLinkMetadata)で渡す
    private func shareLink() {
        guard let inviteLink else { return }
        LayerHaptics.light()
        let name = createdGroup?.name ?? finalName
        shareItems = ShareItems(items: [GroupInviteItemSource(groupName: name, passphrase: passphrase, url: inviteLink)])
    }

    // MARK: 作成

    /// 「つくる」:押した瞬間に CloudKit への作成を始め(うしろで走らせる)、むかしの演出をそのまま出す
    /// (強く1回 → 中央から光が広がる 1.1秒 → 丸がぽんと跳ねる)。作成が終わったら「できました」へ
    /// (見出し → 名前 → 合言葉が、ぼかしから順に浮かぶ)。演出が終わっても作成がまだなら「つくっています…」のまま。
    /// 失敗したら、演出を止めて②にとどまり、入力した内容はのこす(グループは作られていない)。
    private func create() {
        guard !isCreating, createdGroup == nil else { return }
        CloudDiagnostics.begin("グループを つくる:押した")
        guard let user = currentUser else {
            // 黙って もどらない(自分の プロフィールが まだ 読めていない)
            CloudDiagnostics.step("止まった:自分の プロフィール(UserProfile)が ない")
            LayerHaptics.softDouble()
            withAnimation { errorMessage = "つくれませんでした。もういちど" }
            return
        }
        guard nameStatus == .ok else { go(to: .name); return }
        guard let cloudKitManager = CloudKitManager.current else {
            CloudDiagnostics.step("止まった:iCloud(CloudKitManager)が まだ 用意できていない")
            withAnimation { errorMessage = "iCloud に まだ つながっていません。少しあとで、もういちど" }
            return
        }
        if cloudKitManager.currentUserRecordName == nil {
            CloudDiagnostics.step("注意:iCloud の ユーザーが まだ わからない(サインイン・つながりを 確認)")
        }
        guard user.groups.filter({ !$0.isPersonalSpace }).count < GroupMembershipPolicy.maxGroupsPerUser else {
            withAnimation { errorMessage = "グループは、\(GroupMembershipPolicy.maxGroupsPerUser)個までです。" }
            return
        }
        isCreating = true
        slowCreating = false
        errorMessage = nil
        // 時間が かかっているときは、だまって 待たせない(長押しで 経過が 見られる)
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            if isCreating, createdGroup == nil {
                CloudDiagnostics.step("15秒たっても 作成が おわらない")
                withAnimation { slowCreating = true }
            }
        }
        haptics.playTransient(intensity: 1.0, sharpness: 0.7)
        if !reduceMotion {
            burstExpanded = false
            burst = true
            DispatchQueue.main.async { withAnimation(.easeOut(duration: 1.1)) { burstExpanded = true } }
            bumpDisc()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) { burst = false; burstExpanded = false }
        }

        let group = LaterGroup(name: finalName, host: user, autoGenerateMission: false, isPrivate: true)
        group.memberLimit = memberLimit
        group.colorIndex = colorIndex
        group.faceStyle = faceStyle
        group.showsInitial = showsInitial
        group.joinedAt = Date()
        _ = group.addMember(user)
        modelContext.insert(group)

        let started = Date()
        Task { @MainActor in
            let sharingService = GroupSharingService(container: cloudKitManager.container, modelContext: modelContext, cloudKitManager: cloudKitManager)
            do {
                try await sharingService.createGroup(group, hostProfile: user)
            } catch GroupSharingError.quotaExceeded(groupCreatedWithoutImages: true) {
                // iCloud の容量不足で、写真だけ除いて作れた(グループは作成ずみ)
                createdWarning = GroupSharingError.quotaExceeded(groupCreatedWithoutImages: true).errorDescription
            } catch {
                // 開発用の詳細(長押しで見る)。CKError は GroupSharingService が のこす。それ以外も ここで のこす
                if !(error is GroupSharingError) || CloudDiagnostics.last == nil {
                    CloudDiagnostics.record("グループを つくる", CloudDiagnostics.report(error))
                }
                if case GroupSharingError.zoneCreationFailed(let underlying) = error {
                    CloudDiagnostics.record("グループを つくる:ゾーン", CloudDiagnostics.report(underlying))
                }
                CloudDiagnostics.step("止まった:作成に 失敗(\(String(describing: error).prefix(160)))")
                slowCreating = false
                modelContext.delete(group)
                try? modelContext.save()
                // 演出を止めて、エラーを出す(名前・色・人数はそのまま)
                burst = false
                burstExpanded = false
                isCreating = false
                LayerHaptics.softDouble()
                // 理由を 日本語で 短く(iCloud に サインインしていない・通信できない・サーバー側の 設定が 足りない など)
                let reason = GroupCreateFailureText.reason(for: error)
                CloudDiagnostics.step("画面の文:\(reason)")
                withAnimation { errorMessage = reason }
                return
            }
            createdGroup = group
            slowCreating = false
            CloudDiagnostics.step("作成 OK")
            // むかしと同じ:光が広がりはじめてから 0.52秒は待ってから、つぎへ
            let wait = max(0, 0.52 - Date().timeIntervalSince(started))
            try? await Task.sleep(for: .seconds(wait))
            // 前の完了画面へ。リンクは、作ってできた本物(CKShare の URL)を出す
            var madeLink = await Self.makeLink(for: group, context: modelContext)
            if madeLink == nil {
                // リンクの 作成だけが 失敗:自動で 1回 やり直す(グループは もう 保存ずみ。だまって 止まらない)
                CloudDiagnostics.step("リンク:失敗。自動で 1回 やり直す")
                try? await Task.sleep(for: .seconds(1))
                madeLink = await Self.makeLink(for: group, context: modelContext)
            }
            isCreating = false
            inviteLink = madeLink
            createdShareURL = madeLink.flatMap { InviteConfig.shareURL(from: $0) } ?? madeLink
            CloudDiagnostics.step(madeLink == nil ? "リンク:できなかった(画面で もういちど)" : "リンク OK")
            showingCreatedShare = true
            CloudDiagnostics.step("リンクの 画面を 出した")
            // 合言葉は、画面には出さないが、これまでどおり作っておく(合言葉で入れるように・グループの設定で見られる)
            passphrase = try? await GroupInviteService.passphrase(for: group, context: modelContext)
        }
    }
}

extension NewGroupFlowView {
    /// 招待リンクを つくる。失敗は 黙らせない(開発用の詳細を のこす)
    @MainActor
    /// 最後に リンクを つくれなかった 理由(リンクの画面に 出す)
    static var lastLinkFailureReason: String?

    static func makeLink(for group: LaterGroup, context: ModelContext) async -> URL? {
        lastLinkFailureReason = nil
        do {
            return try await GroupInviteService.link(for: group, context: context)
        } catch {
            CloudDiagnostics.record("招待リンクを つくる", CloudDiagnostics.report(error) + "\n(\(String(describing: error)))")
            lastLinkFailureReason = GroupCreateFailureText.reason(for: error)
            return nil
        }
    }
}

/// できました:見出し → 名前 → 合言葉の順に、80msずつずらして、ぼかしから浮かぶ(0.7秒)。むかしの演出のまま
private struct DoneStagger: ViewModifier {
    let index: Int
    let appeared: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        let shown = appeared || reduceMotion
        return content
            .blur(radius: shown ? 0 : 10)
            .offset(y: shown ? 0 : 14)
            .opacity(shown ? 1 : 0)
            .animation(reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.7).delay(0.1 + Double(index) * 0.08), value: appeared)
    }
}

// MARK: - ゆれ(視差を減らすなら、ゆれない)

private struct GroupCreateShake: ViewModifier {
    let trigger: Int
    let enabled: Bool

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: CGFloat(0), trigger: trigger) { view, x in
            view.offset(x: enabled ? x : 0)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-8, duration: 0.06)
                LinearKeyframe(8, duration: 0.08)
                LinearKeyframe(-5, duration: 0.07)
                LinearKeyframe(4, duration: 0.07)
                LinearKeyframe(0, duration: 0.06)
            }
        }
    }
}

// MARK: - 名前の入力欄(日本語入力に強い UITextField)

/// 変換中(markedText)を見て、確定だけの Enter では進まない。文字数では切らない。
/// 改行キーは「次へ」。キーボードの色は画面にあわせる。
struct GroupNameTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    @Binding var isComposing: Bool
    let placeholder: String
    let textColor: UIColor
    let placeholderColor: UIColor
    let tintColor: UIColor
    let dark: Bool
    let accessibilityValue: String
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.font = .systemFont(ofSize: 25, weight: .bold)
        field.returnKeyType = .next
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.enablesReturnKeyAutomatically = false
        field.accessibilityLabel = "グループの名前"
        field.adjustsFontSizeToFitWidth = true
        field.minimumFontSize = 18
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        // 変換中は、外から文字を書きかえない(変換中の文字が消える)
        if field.markedTextRange == nil, field.text != text { field.text = text }
        field.textColor = textColor
        field.tintColor = tintColor
        field.keyboardAppearance = dark ? .dark : .light
        field.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: placeholderColor])
        field.accessibilityValue = accessibilityValue
        if isFocused, !field.isFirstResponder {
            DispatchQueue.main.async { field.becomeFirstResponder() }
        } else if !isFocused, field.isFirstResponder {
            DispatchQueue.main.async { field.resignFirstResponder() }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: GroupNameTextField

        init(_ parent: GroupNameTextField) { self.parent = parent }

        @objc func changed(_ field: UITextField) {
            let composing = field.markedTextRange != nil
            if parent.isComposing != composing { parent.isComposing = composing }
            parent.text = field.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.isFocused { parent.isFocused = true }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.isFocused { parent.isFocused = false }
            if parent.isComposing { parent.isComposing = false }
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            let composing = textField.markedTextRange != nil
            if parent.isComposing != composing { parent.isComposing = composing }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            // 変換を確定するだけの Enter では進まない
            guard textField.markedTextRange == nil else { return true }
            parent.onSubmit()
            return false
        }
    }
}
