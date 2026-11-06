import SwiftUI
import UIKit

// MARK: - 編集のきまり(名前・ハッシュタグ)

/// プロフィールの編集シートのきまり。画面から切り離して、テストできるようにしておく。
/// ハッシュタグは、保存するときは `#` なし(既存の `UserProfile.selfTags` と同じ形)。表示のときに `#` をつける。
enum ProfileShelfEditRules {
    /// 名前は12文字まで(オンボーディングと同じ)
    static let nameMaxLength = OnboardingRules.nameMaxLength
    /// ハッシュタグは1つ16文字まで
    static let tagMaxLength = 16
    /// ハッシュタグは3つまで(オンボーディングと同じ)
    static let maxTags = OnboardingRules.maxSelfTags
    /// 名前が空のときの名前
    static let fallbackName = "ゲスト"

    /// 入力中の名前を、12文字までに切る
    static func clampName(_ raw: String) -> String {
        String(raw.prefix(nameMaxLength))
    }

    enum NameResult: Equatable {
        case ok(String)
        /// URL・メールアドレスらしい文字(本名・連絡先を入れさせない)
        case looksLikeContact
    }

    /// 保存する名前:前後の空白を削り、12文字まで。空なら「ゲスト」
    static func savedName(_ raw: String) -> NameResult {
        let trimmed = clampName(raw.trimmingCharacters(in: .whitespacesAndNewlines))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .ok(fallbackName) }
        if OnboardingRules.validateName(trimmed).problem == .looksLikeContact { return .looksLikeContact }
        return .ok(trimmed)
    }

    /// `#`(全角の `#` も)と空白(全角の空白・改行も)を取り除く。文字は切らない
    /// (切ると、日本語の変換中の文字がこわれる。長すぎるときは、ボタンの文言で知らせる)
    static func cleanTag(_ raw: String) -> String {
        let kept = raw.unicodeScalars.filter { scalar in
            scalar != "#" && scalar != "＃" && !CharacterSet.whitespacesAndNewlines.contains(scalar)
        }
        var text = ""
        text.unicodeScalars.append(contentsOf: kept)
        return text
    }

    enum AddResult: Equatable {
        case added([String])
        case empty
        case full
        case duplicate
        /// 何文字こえているか
        case tooLong(Int)

        /// 断ったときのトースト
        var message: String? {
            switch self {
            case .added: nil
            case .empty: "言葉を入れてください"
            case .full: "\(ProfileShelfEditRules.maxTags)つまでです"
            case .duplicate: "同じ言葉があります"
            case .tooLong(let over): "\(over)文字、へらしてください"
            }
        }
    }

    /// ハッシュタグを1つ足す。空・上限をこえる・長すぎる・同じ言葉(英字の大小は同じとみなす)は断る
    static func add(_ raw: String, to tags: [String]) -> AddResult {
        let tag = cleanTag(raw)
        guard !tag.isEmpty else { return .empty }
        guard tags.count < maxTags else { return .full }
        guard tag.count <= tagMaxLength else { return .tooLong(tag.count - tagMaxLength) }
        guard !tags.contains(where: { $0.lowercased() == tag.lowercased() }) else { return .duplicate }
        return .added(tags + [tag])
    }

    /// 「追加」ボタンの文言と、押せるか。上限・長さは、文字を切らずにここで知らせる
    static func addButton(input: String, tags: [String]) -> (title: String, enabled: Bool) {
        if tags.count >= maxTags { return ("\(maxTags)つまで", false) }
        let tag = cleanTag(input)
        if tag.count > tagMaxLength { return ("\(tag.count - tagMaxLength)文字へらす", false) }
        return ("追加", !tag.isEmpty)
    }

    /// 保存するタグ。全部外したまま保存したときは、前のタグを残す(モックと同じ)
    static func savedTags(draft: [String], previous: [String]) -> [String] {
        draft.isEmpty ? previous : Array(draft.prefix(maxTags))
    }
}

// MARK: - シートの色(Palette にない色だけ、ここに置く)

/// 設定シート・編集シート・トーストの色。昼 / 夜。
struct ProfileSheetColors {
    let palette: Palette

    var night: Bool { palette.isNight }
    /// シート:昼 #FFFFFF / 夜 #141416
    var sheet: Color { night ? Color(hex: "141416") : Color(hex: "FFFFFF") }
    /// 赤(通報・削除):昼 #E0453A / 夜 #FF8A8A
    var red: Color { night ? Color(hex: "FF8A8A") : Color(hex: "E0453A") }
    /// トグルのオフ:昼 黒16% / 夜 白20%
    var toggleOff: Color { night ? Color.white.opacity(0.20) : Color.black.opacity(0.16) }
    /// 背面の暗さ:昼 黒32% / 夜 黒60%
    var scrim: Color { Color.black.opacity(night ? 0.60 : 0.32) }
    /// つまみ・枠の線:昼 黒22% / 夜 白26%
    var grab: Color { night ? Color.white.opacity(0.26) : Color.black.opacity(0.22) }
    /// オレンジ(トグルのオン・入力欄のフチ):昼 #FF6A1A / 夜 #FF8A3D
    var ember: Color { night ? palette.stamp : palette.accent }
    /// 黒い丸薬(夜は白い丸薬)
    var chipBG: Color { palette.ink }
    var chipFG: Color { night ? Color(hex: "111113") : Color(hex: "FFFFFF") }
    /// トースト:昼 黒地に白 / 夜 白地に黒
    var toastBG: Color { palette.ink }
    var toastFG: Color { chipFG }
}

// MARK: - シートの枠(下から出る・背面タップで閉じる)

/// 角 32pt の上、上に細いつまみ。背面はうすく暗くして、タップで閉じる。
struct ProfileShelfSheetFrame<Content: View>: View {
    let colors: ProfileSheetColors
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    /// 中身の高さ。シートはこの高さまで(画面が足りないときだけ、中でスクロール)
    @State private var panelHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            colors.scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)
                .accessibilityLabel("とじる")
                .accessibilityAddTraits(.isButton)

            // ViewThatFits は使わない:キーボードが出て高さが足りなくなると ScrollView の版に切りかわり、
            // 入力欄が作りなおされてフォーカスが外れ、キーボードがすぐ閉じていた(ハッシュタグが書けない)。
            // いつも同じ ScrollView にのせ、高さだけを中身に合わせる。
            ScrollView(showsIndicators: false) {
                panel
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { panelHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .frame(maxHeight: panelHeight > 0 ? panelHeight : nil)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
                    .fill(colors.sheet)
                    .shadow(color: .black.opacity(0.22), radius: 25, y: -20)
                    .ignoresSafeArea(edges: .bottom)
            )
            .padding(.top, 60)
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(colors.grab)
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 14)
                .accessibilityHidden(true)
            content()
        }
        .foregroundStyle(colors.palette.ink)
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 見出し(Inter Black 24pt。フォントが入っていなければ、システムの太字)
private func sheetTitle(_ text: String) -> some View {
    Text(text)
        .font(ShelfFont.black(24))
        .tracking(-0.04 * 24)
        .padding(.bottom, 8)
        .accessibilityAddTraits(.isHeader)
}

// MARK: - トグル(オン=オレンジ / オフ=灰色)

struct ProfileShelfToggle: View {
    let isOn: Bool
    let colors: ProfileSheetColors

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule().fill(isOn ? colors.ember : colors.toggleOff)
            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
                .padding(3)
        }
        .frame(width: 44, height: 26)
        .animation(.easeOut(duration: 0.2), value: isOn)
        .accessibilityHidden(true)
    }
}

// MARK: - 設定シート(プロフィール専用の薄いシート)

/// 歯車で出る。細かい画面(お知らせの許可・通報・削除)は、既存のものへつなぐ。
struct ProfileShelfSettingsSheet: View {
    let colors: ProfileSheetColors
    /// 「ゲスト · 朝霧のレンズ #0417」
    let nameLine: String
    let onEdit: () -> Void
    let onReport: () -> Void
    let onDelete: () -> Void
    let onToast: (String) -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.scenePhase) private var scenePhase
    /// 新しく足すキーは、この1つだけ
    @AppStorage("profileCalmMotion") private var calmSetting = false

    @State private var haptics = ProfileFilmHaptics()
    /// 撮る時間のお知らせ:既存の設定画面と同じ(`DailyOpenNotification` の登録があるか)
    @State private var notifyOn = false
    @State private var showingNotificationDenied = false
    @State private var deleteArmed = false

    private var calmOn: Bool { calmSetting || systemReduceMotion }

    var body: some View {
        ProfileShelfSheetFrame(colors: colors, onDismiss: onDismiss) {
            sheetTitle("設定")

            row(title: "名前の表示", note: nameLine, action: onEdit) {
                value("変更 ›")
            }
            row(title: "ハッシュタグを変える", note: "自分を表す言葉・3つまで", action: onEdit) {
                value("›")
            }
            row(title: "撮る時間のお知らせ", note: "毎朝 9:00 に", action: toggleNotify) {
                ProfileShelfToggle(isOn: notifyOn, colors: colors)
            }
            .accessibilityValue(notifyOn ? "オン" : "オフ")
            .accessibilityAddTraits(.isToggle)
            row(title: "光もれと揺れを止める", note: "視差効果を減らす と同じ", action: toggleCalm) {
                ProfileShelfToggle(isOn: calmOn, colors: colors)
                    .opacity(systemReduceMotion ? 0.55 : 1)
            }
            .accessibilityValue(calmOn ? "オン" : "オフ")
            .accessibilityAddTraits(.isToggle)
            row(title: "写真は7日で消えます", note: "変えられないルールです", action: {
                onToast("写真は撮ってから7日で消えます。残す機能はありません")
            }) {
                value("説明 ›")
            }
            row(title: "通報・ブロック", tint: colors.red, action: onReport) {
                value("›", tint: colors.red)
            }
            row(title: deleteArmed ? "もう一度押すと、削除します" : "アカウントを削除", tint: colors.red, divider: false, action: tapDelete) {
                if !deleteArmed { value("›", tint: colors.red) }
            }
        }
        .onAppear {
            haptics.prepare()
            refreshNotify()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshNotify() }
        }
        .alert("お知らせが、オフになっています", isPresented: $showingNotificationDenied) {
            Button("設定をひらく") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button("とじる", role: .cancel) {}
        } message: {
            Text("iPhone の設定で、Later の通知を許可してください。")
        }
    }

    private func row<Trailing: View>(
        title: String,
        note: String? = nil,
        tint: Color? = nil,
        divider: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(tint ?? colors.palette.ink)
                    if let note {
                        Text(note)
                            .font(ShelfFont.mono(10))
                            .tracking(0.4)
                            .foregroundStyle(colors.palette.dim)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: 8)
                trailing()
            }
            .padding(.vertical, 15)
            .frame(minHeight: 44)
            .overlay(alignment: .bottom) {
                if divider { colors.palette.line.frame(height: 1) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func value(_ text: String, tint: Color? = nil) -> some View {
        Text(text)
            .font(ShelfFont.mono(12))
            .foregroundStyle(tint ?? colors.palette.sub)
            .accessibilityHidden(true)
    }

    // MARK: 動き

    private func refreshNotify() {
        Task { notifyOn = await DailyOpenNotification.isScheduled() }
    }

    /// 既存の設定画面(`SettingsMenuView.setNotification`)と同じ流れ:
    /// オン = 許可を求めて登録(許可がなければ OS の設定を案内)/ オフ = 登録を外す
    private func toggleNotify() {
        haptics.play(.light)
        let on = !notifyOn
        notifyOn = on
        Task {
            if on {
                let result = await DailyOpenNotification.requestAuthorization(timeout: 10)
                if result == .granted {
                    await DailyOpenNotification.schedule()
                    onToast("お知らせをオンにしました")
                } else {
                    notifyOn = false
                    showingNotificationDenied = true
                }
            } else {
                DailyOpenNotification.cancel()
                onToast("お知らせをオフにしました")
            }
        }
    }

    private func toggleCalm() {
        guard !systemReduceMotion else {
            haptics.play(.nope)
            onToast("「視差効果を減らす」がオンなので、止めたままです")
            return
        }
        haptics.play(.light)
        calmSetting.toggle()
        onToast(calmSetting ? "光もれと揺れを止めました" : "光もれと揺れを戻しました")
    }

    /// 1回目は「もう一度押すと、削除します」に変わるだけ。2回目で、既存の削除の流れ(長押し)へ
    private func tapDelete() {
        haptics.play(.light)
        if deleteArmed {
            deleteArmed = false
            onDelete()
        } else {
            deleteArmed = true
        }
    }
}

// MARK: - 編集シート

/// 名前(12文字まで)とハッシュタグ(3つまで・1つ16文字まで)。「保存する」で UserProfile に反映する。
struct ProfileShelfEditSheet: View {
    let colors: ProfileSheetColors
    let onSave: (_ name: String, _ tags: [String]) -> Void
    let onToast: (String) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var draftTags: [String]
    @State private var tagInput = ""
    @FocusState private var focus: Field?
    @State private var haptics = ProfileFilmHaptics()
    private let previousTags: [String]

    private enum Field { case name, tag }

    init(
        colors: ProfileSheetColors,
        name: String,
        tags: [String],
        onSave: @escaping (_ name: String, _ tags: [String]) -> Void,
        onToast: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.colors = colors
        self.onSave = onSave
        self.onToast = onToast
        self.onCancel = onCancel
        self.previousTags = tags
        _name = State(initialValue: ProfileShelfEditRules.clampName(name))
        _draftTags = State(initialValue: Array(tags.prefix(ProfileShelfEditRules.maxTags)))
    }

    private var palette: Palette { colors.palette }

    var body: some View {
        ProfileShelfSheetFrame(colors: colors, onDismiss: onCancel) {
            sheetTitle("プロフィールを編集")

            label("名前(Later の中だけの名前)")
            TextField("名前を入れてください", text: $name)
                .focused($focus, equals: .name)
                .submitLabel(.done)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.nickname)
                .onChange(of: name) { _, value in
                    let clamped = ProfileShelfEditRules.clampName(value)
                    if clamped != value { name = clamped }
                }
                .modifier(ShelfFieldStyle(colors: colors, focused: focus == .name))

            label("ハッシュタグ(\(ProfileShelfEditRules.maxTags)つまで・1つ\(ProfileShelfEditRules.tagMaxLength)文字まで)")
            let button = ProfileShelfEditRules.addButton(input: tagInput, tags: draftTags)
            HStack(spacing: 8) {
                // `#` は自動でつく(打たなくていい)。入力の文字は、ここでは切らない・変えない
                // (変換中に書きかえると、日本語の入力がこわれる)
                HStack(spacing: 2) {
                    Text("#")
                        .foregroundStyle(palette.dim)
                        .accessibilityHidden(true)
                    TextField("言葉を入れて追加", text: $tagInput)
                        .focused($focus, equals: .tag)
                        // Return =「追加」。変換を確定する Return では onSubmit は呼ばれない
                        .submitLabel(.next)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit(addTag)
                        .accessibilityLabel("ハッシュタグ")
                }
                .modifier(ShelfFieldStyle(colors: colors, focused: focus == .tag))
                .contentShape(Rectangle())
                .onTapGesture { focus = .tag }
                Button(action: addTag) {
                    Text(button.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(palette.ink.opacity(button.enabled ? 1 : 0.45))
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 18)
                        .frame(maxHeight: .infinity)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.fill))
                }
                .buttonStyle(ShelfPressStyle(scale: 0.96))
                .disabled(!button.enabled)
                .animation(.easeOut(duration: 0.15), value: button.title)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)

            chips
                .padding(.top, 10)

            Text("#は、打たなくても自動でつきます。")
                .font(.system(size: 11.5))
                .foregroundStyle(palette.dim)
                .padding(.top, 8)

            Button(action: save) {
                Text("保存する")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(colors.chipFG)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Capsule().fill(colors.chipBG))
            }
            .buttonStyle(ShelfPressStyle(scale: 0.97))
            .padding(.top, 22)

            Button(action: onCancel) {
                Text("やめる")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.sub)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .overlay(Capsule().strokeBorder(palette.line, lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(ShelfPressStyle(scale: 0.97))
            .padding(.top, 10)
        }
        .onAppear { haptics.prepare() }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(ShelfFont.mono(10))
            .tracking(1.4)
            .foregroundStyle(palette.dim)
            .padding(.top, 18)
            .padding(.bottom, 8)
    }

    /// 追加した言葉は、黒い丸薬(夜は白い丸薬)のチップ。右に ×
    private var chips: some View {
        HStack(spacing: 8) {
            ForEach(Array(draftTags.enumerated()), id: \.element) { index, tag in
                HStack(spacing: 8) {
                    Text("#\(tag)")
                        .font(.system(size: 13.5, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Button {
                        haptics.play(.light)
                        draftTags.remove(at: index)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.gray.opacity(0.3)))
                            .frame(width: 30, height: 30)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("#\(tag) を外す")
                }
                .foregroundStyle(colors.chipFG)
                .padding(.leading, 14)
                .padding(.trailing, 4)
                .frame(height: 38)
                .background(Capsule().fill(colors.chipBG))
            }
        }
        .frame(minHeight: draftTags.isEmpty ? 0 : 38)
    }

    // MARK: 動き

    private func addTag() {
        let result = ProfileShelfEditRules.add(tagInput, to: draftTags)
        if case .added(let tags) = result {
            haptics.play(.light)
            draftTags = tags
            tagInput = ""
            // 追加したら、入力欄は空になって、そのままもう1つ打てる(上限なら閉じる)
            if tags.count < ProfileShelfEditRules.maxTags {
                DispatchQueue.main.async { focus = .tag }
            } else {
                focus = nil
            }
        } else if case .empty = result, focus == .tag {
            // 空の Return は、なにもしない(キーボードは出したまま)
            DispatchQueue.main.async { focus = .tag }
        } else if let message = result.message {
            haptics.play(.nope)
            onToast(message)
        }
    }

    private func save() {
        // 入力欄に残っている言葉は、追加してから保存する(3つ目まで)
        var tags = draftTags
        if !ProfileShelfEditRules.cleanTag(tagInput).isEmpty,
           case .added(let added) = ProfileShelfEditRules.add(tagInput, to: tags) {
            tags = added
        }
        switch ProfileShelfEditRules.savedName(name) {
        case .looksLikeContact:
            haptics.play(.nope)
            onToast("名前に、URL やメールアドレスは入れられません")
        case .ok(let saved):
            haptics.play(.tick)
            focus = nil
            onSave(saved, ProfileShelfEditRules.savedTags(draft: tags, previous: previousTags))
        }
    }
}

/// 入力欄:`card` の面、角 16pt。入力中はオレンジのフチ
private struct ShelfFieldStyle: ViewModifier {
    let colors: ProfileSheetColors
    let focused: Bool

    func body(content: Content) -> some View {
        content
            .font(.system(size: 16))
            .foregroundStyle(colors.palette.ink)
            .tint(colors.ember)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(colors.palette.fill))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(focused ? colors.ember : .clear, lineWidth: 1)
            )
    }
}

// MARK: - トースト

/// 昼:黒い面・白い文字 / 夜:白い面・黒い文字
struct ProfileShelfToast: View {
    let message: String
    let colors: ProfileSheetColors

    var body: some View {
        Text(message)
            .font(.system(size: 13.5, weight: .medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(colors.toastFG)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(colors.toastBG))
            .padding(.horizontal, 24)
            .accessibilityAddTraits(.updatesFrequently)
    }
}
