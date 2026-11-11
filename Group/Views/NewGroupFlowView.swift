import SwiftUI
import SwiftData
import UIKit

// MARK: - グループ作成(v22:デザインだけ 作りなおし)

// なまえ画面(友だちも えらべる)→ つくっている(演出)→ できた画面(リンク)。全面で ひらく。
// 見た目・アニメーション・バイブだけを 変えた。保存(GroupSharingService.createGroup)・
// リンク(GroupInviteService.link / makeLink)・招待文(InviteConfig.shareMessage)・
// 招待カード(FriendCloud.sendInvites)は、今までの 関数を そのまま 呼ぶ。
// 色・顔・人数の上限は ここでは 聞かない(あとで グループの 設定で 変えられる)。

// MARK: 名前の決めごと(画面を持たない)

enum GroupCreateName {
    static let maxLength = 14

    static let seeds = ["いつメン", "放課後クラブ", "部活", "2-B", "帰り道", "ひみつ基地", "推し活", "テスト前"]

    enum Status: Equatable {
        case empty
        /// 14文字をこえた(こえた文字数)
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

    /// もう使っている名前は出さない
    static func seeds(excluding names: [String]) -> [String] {
        let used = Set(names.map(finalize))
        return seeds.filter { !used.contains($0) }
    }

    static func initial(_ input: String) -> String {
        String(finalize(input).prefix(1))
    }

    /// 「つくる」ボタンの 文字(えらんだ 友だちの 数で かわる)
    static func createTitle(friends: Int, creating: Bool) -> String {
        if creating { return "つくっています…" }
        return friends == 0 ? "つくる" : "つくって \(friends)人に おくる"
    }

    /// 見出し右の「3人 えらびました」(0人は「あとでも OK」)
    static func pickedNote(_ count: Int) -> String {
        count == 0 ? "あとでも OK" : "\(count)人 えらびました"
    }

    /// リンクの カプセルに 出す 短い 形(icloud.com/share/xxxxx…)
    static func shortLink(_ url: URL?) -> String {
        guard let url else { return "" }
        var text = url.absoluteString
        for prefix in ["https://", "http://", "www."] where text.hasPrefix(prefix) { text.removeFirst(prefix.count) }
        let head = "icloud.com/share/"
        if text.hasPrefix(head) {
            let id = text.dropFirst(head.count)
            return id.count > 5 ? head + id.prefix(5) + "…" : text
        }
        return text.count > 24 ? String(text.prefix(23)) + "…" : text
    }
}

// MARK: 色(昼は うすい クリーム・夜は ほぼ黒。文字と背景のコントラスト比 4.5 以上)

struct GroupCreateColors {
    let night: Bool

    var bg: Color { night ? Color(hex: "0B0B0E") : Color(hex: "FBF6EC") }
    var ink: Color { night ? Color(hex: "F5F5F7") : Color(hex: "17151A") }
    var sub: Color { night ? Color(hex: "A9A9B1") : Color(hex: "5E5A63") }
    var field: Color { night ? Color(hex: "1C1C20").opacity(0.9) : Color.white.opacity(0.78) }
    var placeholder: Color { night ? Color(hex: "8E8E96") : Color(hex: "6B6670") }
    var line: Color { night ? Color(hex: "4A4A50") : Color(hex: "D8D0C2") }
    var primaryBg: Color { night ? Color(hex: "F5F5F7") : Color(hex: "17151A") }
    var primaryText: Color { night ? Color(hex: "17151A") : Color(hex: "FFFFFF") }
    var disabledBg: Color { night ? Color(hex: "2C2C30") : Color(hex: "E6E0D6") }
    var disabledText: Color { night ? Color(hex: "A9A9B1") : Color(hex: "5E5A63") }
    var accent: Color { night ? Color(hex: "FF8A3D") : Color(hex: "FF6A1A") }
    var warn: Color { night ? Color(hex: "FF7A66") : Color(hex: "D93A28") }
    var warnCard: Color { night ? Color(hex: "3A1712") : Color(hex: "FDE3DE") }

    static let lineWidth: CGFloat = 1.5
}

/// 背景の 色の玉(グループ名の 文字から ハッシュ → 8組の 2色ペア。未入力は オレンジ → ピンク)
enum GroupCreateBlobPalette {
    static let pairs: [[String]] = [
        ["FF8A3D", "FF5FA2"],
        ["6AA8FF", "7BE0C8"],
        ["FFD36E", "FF7A59"],
        ["9AE6B4", "4FB3BF"],
        ["C59BFF", "FF9ECF"],
        ["FF9C8A", "B23A62"],
        ["D7EC7A", "3E8E5A"],
        ["7CC8FF", "8A6CF0"],
    ]

    /// 名前の 文字(Unicode)の 和で えらぶ(端末・起動を またいでも 同じ)
    static func index(for name: String) -> Int {
        let trimmed = GroupCreateName.finalize(name)
        guard !trimmed.isEmpty else { return 0 }
        let sum = trimmed.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
        return sum % pairs.count
    }

    static func colors(for name: String) -> [Color] {
        pairs[index(for: name)].map { Color(hex: $0) }
    }
}

/// 友だちを えらんで 送った 招待カード(端末の中だけ。ホームの「招待中 N人」に 使う)。
/// 本人が「入る」を 押して メンバーに なるまでは、数に 入れない
enum GroupInviteSentStore {
    private static let key = "groupInviteSent.v1"

    static func ids(for groupID: UUID, defaults: UserDefaults = .standard) -> [String] {
        (defaults.dictionary(forKey: key) as? [String: [String]])?[groupID.uuidString] ?? []
    }

    static func add(_ ids: [String], to groupID: UUID, defaults: UserDefaults = .standard) {
        var all = defaults.dictionary(forKey: key) as? [String: [String]] ?? [:]
        var list = all[groupID.uuidString] ?? []
        for id in ids where !list.contains(id) { list.append(id) }
        all[groupID.uuidString] = list
        defaults.set(all, forKey: key)
    }

    /// まだ 入っていない 招待の 数(招待中)。だれも 招待して いなければ 0
    static func pendingCount(for group: LaterGroup, defaults: UserDefaults = .standard) -> Int {
        let joined = Set(group.members.compactMap(\.cloudKitUserRecordName))
        return ids(for: group.id, defaults: defaults).filter { !joined.contains($0) }.count
    }
}

/// 作成画面に 出す 友だち(HomeFriend から。id は CloudKit の ユーザー名 = 招待カードの あて先)
struct GroupCreateFriend: Identifiable, Equatable {
    let id: String
    let name: String
    let avatarData: Data?
    let seed: UUID

    var initial: String { String(name.trimmingCharacters(in: .whitespaces).prefix(1)) }
    var colors: [Color] { LayerAvatar.colors(seed) }
}

// MARK: - 本体

struct NewGroupFlowView: View {
    /// 最初から入れておくグループ名(空の GROUP 画面のステッカーから。nil なら空)
    var initialName: String? = nil
    /// えらべる 友だち(自分を のぞく)
    var friends: [GroupCreateFriend] = []
    /// 見た目の確認用(テスト):はじめの 場面
    var preview: Preview? = nil
    /// できた画面を とじた(ホームで「「{name}」を つくりました」)
    var onCreated: (String) -> Void = { _ in }
    let onClose: () -> Void

    enum Preview: Equatable {
        case name
        case creating
        case doneLink
        case doneFriends
        case failed
    }

    /// なまえ → つくっている → できた / うまく いかなかった
    enum Phase: Equatable {
        case name, creating, done, failed
    }

    /// 失敗の しゅるい(もういちど で やりなおす ところ)
    enum FailureKind: Equatable {
        /// グループの 保存(グループは 作られていない → なまえ画面へ)
        case save
        /// リンク(グループは 保存ずみ → リンクだけ つくりなおす)
        case link
        /// 招待カード(グループは 保存ずみ → カードだけ 送りなおす)
        case cards
    }

    struct Failure: Equatable {
        let kind: FailureKind
        /// 実際の エラー内容(CKError など。長押しで コピー)
        let detail: String
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.palette) private var palette
    @Query private var profiles: [UserProfile]

    @State private var phase: Phase = .name
    @State private var name = ""
    @State private var isComposing = false
    @State private var isNameFocused = false
    @State private var keyboardUp = false
    @State private var picked: [String] = []
    @State private var toast: String?

    // 演出
    @State private var bounce = 0
    @State private var flashSeat: Int?
    @State private var flashToken = 0
    @State private var gather: CGFloat = 0
    @State private var glow: Double = 0
    @State private var glowLoop = false
    @State private var confettiStart: Date?
    @State private var appearedAt = Date()
    /// 画面の 高さ(SE など 低い 画面では、まんなかを ちぢめる)
    @State private var screenHeight: CGFloat = 852

    // 作成
    @State private var isCreating = false
    @State private var failure: Failure?
    @State private var retrying = false
    @State private var createdGroup: LaterGroup?
    @State private var createdShareURL: URL?
    @State private var inviteLink: URL?
    @State private var passphrase: String?
    @State private var invited: [String] = []
    @State private var showingShare = false
    @State private var copied = false
    @State private var haptics = ExposureHaptics()

    private var colors: GroupCreateColors { GroupCreateColors(night: palette.isNight) }
    private var currentUser: UserProfile? { UserProfile.current(from: profiles) }
    private var finalName: String { GroupCreateName.finalize(name) }
    private var nameStatus: GroupCreateName.Status { GroupCreateName.status(name) }
    private var shownName: String { createdGroup?.name ?? finalName }
    private var myGroupNames: [String] { currentUser?.groups.filter { !$0.isPersonalSpace }.map(\.name) ?? [] }
    /// 10個のときは、つくらせない
    private var isFull: Bool { myGroupNames.count >= GroupMembershipPolicy.maxGroupsPerUser && createdGroup == nil }
    private var canCreate: Bool { nameStatus == .ok && !isCreating && !isFull }
    private var animates: Bool { !reduceMotion }

    /// できた画面で 使う リンク(今までと 同じ:CKShare の URL を later://join で つつむ)
    private var joinLink: URL? {
        guard let createdShareURL else { return nil }
        return GroupJoinLink.buildURL(shareURL: createdShareURL) ?? createdShareURL
    }

    /// 招待文(全文。今までと 同じ 文面)
    private var shareMessage: String {
        guard let joinLink else { return "" }
        return InviteConfig.shareMessage(groupName: shownName, url: joinLink)
    }

    var body: some View {
        ZStack {
            GroupCreateBackdrop(colors: GroupCreateBlobPalette.colors(for: name), bg: colors.bg, night: colors.night, animates: animates)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: 0) {
                        stage
                        content
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }
            // 「つくる」は 下に 固定(キーボードの すぐ上に ついてくる)
            .safeAreaInset(edge: .bottom) { bottomArea }

            if let confettiStart, animates {
                GroupConfetti(start: confettiStart)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }

            if let toast {
                Text(toast)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(colors.primaryText)
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(Capsule().fill(colors.primaryBg))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 64)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .allowsHitTesting(false)
            }
        }
        .background(GeometryReader { proxy in
            Color.clear
                .onAppear { screenHeight = proxy.size.height }
                .onChange(of: proxy.size.height) { _, h in if !keyboardUp { screenHeight = h } }
        })
        .preferredColorScheme(colors.night ? .dark : .light)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toast)
        .onAppear(perform: appear)
        .onDisappear { haptics.tearDown() }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardUp = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardUp = false }
        }
        .sheet(isPresented: $showingShare) {
            // 今までと 同じ:アイコンつきの 招待文(全文)を 渡す
            ShareSheet(activityItems: [
                ShareLinkItemSource(text: shareMessage, title: "「\(shownName)」に招待されました。")
            ]) { _ in showingShare = false }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: 上(×)

    private var topBar: some View {
        HStack {
            Button(action: closeTapped) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(colors.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(colors.field))
                    .overlay(Circle().strokeBorder(colors.line.opacity(0.6), lineWidth: 1))
            }
            .buttonStyle(PressScaleStyle())
            .opacity(isCreating ? 0.35 : 1)
            .disabled(isCreating)
            .accessibilityLabel("とじる")
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    // MARK: まんなか(アバター + 席)

    private var stage: some View {
        let compact = keyboardUp && phase == .name
        // 低い 画面(SE)では 0.8倍。キーボード中は さらに 小さく
        let scale: CGFloat = compact ? 0.62 : (screenHeight < 720 ? 0.8 : 1)
        return GroupCreateStage(
            initial: phase == .name || phase == .creating ? GroupCreateName.initial(name) : GroupCreateName.initial(shownName),
            avatarColors: GroupCreateBlobPalette.colors(for: name),
            seats: seats,
            flashSeat: flashSeat,
            flashToken: flashToken,
            bounce: bounce,
            gather: gather,
            glow: glow,
            glowLoop: glowLoop,
            animates: animates,
            ink: colors.ink,
            seatLine: colors.sub
        )
        .scaleEffect(scale)
        .frame(height: GroupCreateStage.box * scale)
        .padding(.top, compact ? 0 : 8)
        .accessibilityHidden(true)
    }

    /// 席(7つ)。なまえ画面では えらんだ 友だちが 順に 入る。できた画面では 1つ目が ホスト本人
    private var seats: [GroupCreateSeat] {
        let chosen = picked.compactMap { id in friends.first { $0.id == id } }
        switch phase {
        case .name, .creating, .failed:
            var list: [GroupCreateSeat] = chosen.map { .friend(initial: $0.initial, colors: $0.colors, pending: false) }
            while list.count < 7 { list.append(.empty) }
            return list
        case .done:
            let joined = Set(createdGroup?.members.compactMap(\.cloudKitUserRecordName) ?? [])
            var list: [GroupCreateSeat] = [.host(initial: GroupCreateName.initial(shownName), colors: GroupCreateBlobPalette.colors(for: name))]
            for id in invited {
                guard let friend = friends.first(where: { $0.id == id }) else { continue }
                list.append(.friend(initial: friend.initial, colors: friend.colors, pending: !joined.contains(id)))
            }
            while list.count < 7 { list.append(.empty) }
            return list
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .name, .creating: nameContent
        case .done: doneContent
        case .failed: failedContent
        }
    }

    // MARK: 1. なまえ画面

    private var nameContent: some View {
        VStack(spacing: 0) {
            Text("なまえを つけよう")
                .font(.system(size: keyboardUp ? 22 : 28, weight: .heavy))
                .tracking(-0.03 * 28)
                .foregroundStyle(colors.ink)
                .padding(.top, keyboardUp ? 2 : 14)
                .accessibilityAddTraits(.isHeader)

            nameField
                .padding(.horizontal, 24)
                .padding(.top, keyboardUp ? 10 : 16)

            seedChips
                .padding(.top, 14)

            friendsRow
                .padding(.top, 22)
        }
        // つくっている間は、上へ うすく 消える
        .opacity(phase == .creating ? 0 : 1)
        .offset(y: phase == .creating && animates ? -24 : 0)
        .allowsHitTesting(phase == .name)
    }

    private var nameField: some View {
        let over: Bool = { if case .over = nameStatus { return true } else { return false } }()
        let count = GroupCreateName.count(name)
        return VStack(spacing: 6) {
            GroupNameTextField(
                text: $name,
                isFocused: $isNameFocused,
                isComposing: $isComposing,
                placeholder: "グループの なまえ",
                textColor: UIColor(colors.ink),
                placeholderColor: UIColor(colors.placeholder),
                tintColor: UIColor(colors.accent),
                dark: colors.night,
                accessibilityValue: "\(count)文字、\(GroupCreateName.maxLength)文字まで",
                alignment: .center,
                fontSize: 30,
                returnKey: .done,
                onSubmit: submit
            )
            .frame(height: 48)
            Rectangle().fill(over ? colors.warn : colors.line).frame(height: 1.5)
            Text("\(count) / \(GroupCreateName.maxLength)")
                .font(.system(size: 12, weight: over ? .bold : .regular, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(over ? colors.warn : colors.sub)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onTapGesture { isNameFocused = true }
        .onChange(of: name) { old, value in
            let clean = GroupCreateName.clean(value)
            if clean != value { name = clean; return }
            typed(old: old, new: value)
        }
    }

    private var seedChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GroupCreateName.seeds(excluding: myGroupNames), id: \.self) { seed in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        name = seed
                    } label: {
                        Text(seed)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(colors.ink)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(Capsule().fill(colors.field))
                            .overlay(Capsule().strokeBorder(colors.line.opacity(0.7), lineWidth: 1))
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityLabel("なまえの 候補、\(seed)")
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var friendsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ともだちも よぶ")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(colors.ink)
                Spacer()
                Text(GroupCreateName.pickedNote(picked.count))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(colors.sub)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 24)
            if friends.isEmpty {
                Text("まだ ともだちが いません。あとで リンクで よべます")
                    .font(.system(size: 13))
                    .foregroundStyle(colors.sub)
                    .padding(.horizontal, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(friends) { friend in friendButton(friend) }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func friendButton(_ friend: GroupCreateFriend) -> some View {
        let on = picked.contains(friend.id)
        return Button { toggle(friend) } label: {
            VStack(spacing: 6) {
                LayerAvatar(data: friend.avatarData, seed: friend.seed, name: friend.name)
                    .frame(width: 52, height: 52)
                    .padding(3)
                    .overlay(Circle().strokeBorder(on ? colors.ink : Color.clear, lineWidth: 2.5))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(colors.primaryText)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(colors.primaryBg))
                            .scaleEffect(on ? 1 : 0.01)
                            .opacity(on ? 1 : 0)
                            .animation(animates ? .spring(response: 0.35, dampingFraction: 0.55) : nil, value: on)
                    }
                Text(friend.name)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(colors.ink)
                    .lineLimit(1)
                    .frame(width: 64)
            }
        }
        .buttonStyle(SquishButtonStyle())
        .accessibilityLabel(friend.name)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityHint(on ? "えらぶのを やめます" : "グループに よびます")
    }

    // MARK: 3. できた画面

    private var doneContent: some View {
        VStack(spacing: 0) {
            Text(invited.isEmpty ? "できました" : "おくりました")
                .font(.system(size: 34, weight: .heavy))
                .tracking(-0.03 * 34)
                .foregroundStyle(colors.ink)
                .padding(.top, 14)
                .accessibilityAddTraits(.isHeader)
            if !invited.isEmpty {
                Text("「入る」で なかまに なります")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colors.sub)
                    .padding(.top, 6)
                invitedTags
                    .padding(.top, 16)
            }
            linkCapsule
                .padding(.top, invited.isEmpty ? 18 : 16)
        }
        .transition(.opacity)
    }

    /// えらんだ 友だちの 札(「承認まち」。入ったら 消える)
    private var invitedTags: some View {
        let joined = Set(createdGroup?.members.compactMap(\.cloudKitUserRecordName) ?? [])
        return ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) {
            ForEach(invited, id: \.self) { id in
                let friend = friends.first { $0.id == id }
                let waiting = !joined.contains(id)
                HStack(spacing: 5) {
                    Circle().fill(LinearGradient(colors: friend?.colors ?? [colors.sub, colors.sub], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 14, height: 14)
                    Text(friend?.name ?? "ともだち").font(.system(size: 12, weight: .bold)).lineLimit(1)
                    Text(waiting ? "承認まち" : "入った").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(colors.sub)
                }
                .foregroundStyle(colors.ink)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(colors.field))
                .overlay(Capsule().strokeBorder(colors.line, style: StrokeStyle(lineWidth: 1, dash: waiting ? [3, 3] : [])))
                .accessibilityElement(children: .combine)
            }
          }
          .padding(.horizontal, 24)
          .padding(.vertical, 2)
        }
    }

    /// リンクは 1行の 小さな 丸い カプセル(短く 省略。招待文の 全文は 出さない)
    @ViewBuilder
    private var linkCapsule: some View {
        if joinLink != nil {
            HStack(spacing: 6) {
                Image(systemName: "link").font(.system(size: 11, weight: .bold))
                Text(GroupCreateName.shortLink(createdShareURL))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(1)
            }
            .foregroundStyle(colors.sub)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(colors.field))
            .overlay(Capsule().strokeBorder(colors.line.opacity(0.7), lineWidth: 1))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("招待リンク")
        }
    }

    // MARK: うまく いかなかった

    private var failedContent: some View {
        VStack(spacing: 0) {
            Text("うまく いきませんでした")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(colors.ink)
                .padding(.top, 14)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 6) {
                Text(failure?.kind == .cards ? "招待カードを おくれませんでした" : "リンクを つくれませんでした")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(colors.warn)
                if let detail = failure?.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(colors.ink.opacity(0.75))
                        .lineLimit(4)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(colors.warnCard))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(colors.warn.opacity(0.5), lineWidth: 1))
            .contextMenu {
                Button("エラーを コピー", systemImage: "doc.on.doc") { UIPasteboard.general.string = failure?.detail }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .accessibilityElement(children: .combine)
            .accessibilityHint("長押しで、エラーの 内容を コピー")
        }
        .transition(.opacity)
    }

    // MARK: 下の ボタン(キーボードの すぐ上)

    private var bottomArea: some View {
        VStack(spacing: 8) {
            switch phase {
            case .name, .creating:
                primaryButton(isFull ? "グループは、\(GroupMembershipPolicy.maxGroupsPerUser)個までです" : GroupCreateName.createTitle(friends: picked.count, creating: isCreating),
                              enabled: canCreate) { createTapped() }
                    .disabled(isCreating)
                    .accessibilityHint(nameStatus == .ok ? "グループを つくります" : "なまえを いれると 押せます")
            case .done:
                if joinLink != nil {
                    HStack(spacing: 10) {
                        primaryButton(invited.isEmpty ? "リンクを おくる" : "リンクでも よぶ", enabled: true) { sendTapped() }
                            .accessibilityHint("共有シートを ひらきます")
                        secondaryButton(copied ? "コピーした" : "コピー") { copyTapped() }
                            .frame(width: 112)
                            .accessibilityHint("招待リンクを コピーします")
                    }
                }
                laterButton
            case .failed:
                primaryButton(retrying ? "やりなおしています…" : "もういちど", enabled: !retrying) { retryTapped() }
                    .disabled(retrying)
                    .accessibilityHint(failure?.kind == .save ? "なまえ画面に もどります" : "もういちど ためします")
                if failure?.kind != .save { laterButton }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, keyboardUp ? 8 : 12)
        // 下の ボタンの うしろに、背景色を うすく しく(スクロールした 中身が 重ならない)
        .background(
            LinearGradient(colors: [colors.bg.opacity(0), colors.bg.opacity(0.92), colors.bg], startPoint: .top, endPoint: .init(x: 0.5, y: 0.35))
                .ignoresSafeArea()
        )
    }

    private var laterButton: some View {
        Button(action: closeTapped) {
            Text("あとで")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(colors.sub)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityHint("とじて、ホームへ もどります")
    }

    /// 押せないときは グレー(文字は 読める 色)
    private func primaryButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(enabled ? colors.primaryText : colors.disabledText)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Capsule().fill(enabled ? colors.primaryBg : colors.disabledBg))
                .contentTransition(.opacity)
        }
        .buttonStyle(PressScaleStyle(scale: 0.97))
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(colors.ink)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Capsule().fill(colors.field))
                .overlay(Capsule().strokeBorder(colors.line, lineWidth: GroupCreateColors.lineWidth))
                .contentTransition(.opacity)
        }
        .buttonStyle(PressScaleStyle(scale: 0.97))
    }

    // MARK: 動き

    private func appear() {
        haptics.prepare()
        appearedAt = Date()
        if let initialName, name.isEmpty { name = GroupCreateName.clean(initialName) }
        if let preview {
            applyPreview(preview)
            return
        }
        Haptics.play(.soft)
        // アニメが 落ち着いてから(0.7秒)キーボードを 出す
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            guard phase == .name, !UIAccessibility.isVoiceOverRunning else { return }
            isNameFocused = true
        }
    }

    /// 文字を 打った:アバターの 文字が ぽんっと 弾む(1.16倍)+ 席が 1つ ぴかっと 光る + ごく軽い バイブ
    private func typed(old: String, new: String) {
        guard phase == .name, GroupCreateName.finalize(old) != GroupCreateName.finalize(new) else { return }
        Haptics.play(.tick)
        guard animates else { return }
        bounce += 1
        flashSeat = (flashSeat.map { $0 + 3 } ?? Int.random(in: 0..<7)) % 7
        flashToken += 1
    }

    private func toggle(_ friend: GroupCreateFriend) {
        guard phase == .name else { return }
        if let index = picked.firstIndex(of: friend.id) {
            Haptics.play(.tick)
            withAnimation(animates ? .spring(response: 0.4, dampingFraction: 0.7) : nil) { _ = picked.remove(at: index) }
            return
        }
        // 自分を 入れて 8人まで
        guard picked.count < FriendRules.maxInvitees else {
            Haptics.play(.warn)
            show("グループは \(GroupMembershipPolicy.maxMembersPerGroup)人まで")
            return
        }
        Haptics.play(.pop)
        withAnimation(animates ? .spring(response: 0.45, dampingFraction: 0.55) : nil) { picked.append(friend.id) }
    }

    private func submit() {
        guard canCreate else {
            LayerHaptics.softDouble()
            return
        }
        createTapped()
    }

    private func closeTapped() {
        guard !isCreating else { return }
        Haptics.play(.tick)
        isNameFocused = false
        if createdGroup != nil {
            onCreated(shownName)
        }
        onClose()
    }

    private func copyTapped() {
        guard joinLink != nil else { return }
        Haptics.play(.click)
        UIPasteboard.general.string = shareMessage
        withAnimation(.easeOut(duration: 0.15)) { copied = true }
        show("招待リンクを コピーしました")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { withAnimation(.easeOut(duration: 0.2)) { copied = false } }
    }

    private func sendTapped() {
        guard joinLink != nil else { return }
        Haptics.play(.click)
        showingShare = true
    }

    private func show(_ text: String) {
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { if toast == text { toast = nil } }
    }

    // MARK: 2. つくっている 演出(約1.6秒。本物の 保存が おわるまで つづける)

    /// 演出の 最短の 長さ
    static let showMinimum: Double = 1.6

    private func createTapped() {
        guard canCreate, phase == .name else {
            if isFull { LayerHaptics.softDouble() }
            return
        }
        isNameFocused = false
        Haptics.play(.click)
        withAnimation(.easeOut(duration: 0.3)) { phase = .creating }
        playGather()
        create()
    }

    /// 席が アバターへ 吸いこまれる → アバターが ぽわっと 光る。この間 とても 軽い バイブを 3回(0.26秒おき)
    private func playGather() {
        for i in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.26) {
                guard phase == .creating else { return }
                Haptics.play(.tick)
            }
        }
        guard animates else { return }
        withAnimation(.easeIn(duration: 0.9)) { gather = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard phase == .creating else { return }
            withAnimation(.easeOut(duration: 0.35)) { glow = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard phase == .creating else { return }
                withAnimation(.easeIn(duration: 0.35)) { glow = 0.35 }
            }
        }
        // 1.6秒を すぎても 保存が おわらないときは、光を くりかえす
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.showMinimum) {
            if phase == .creating { glowLoop = true }
        }
    }

    /// できた:紙吹雪 + 成功の バイブ + 席が もどる(1つ目は ホスト本人)
    private func finishSuccess() {
        glowLoop = false
        Haptics.play(.success)
        if animates { confettiStart = Date() }
        withAnimation(animates ? .spring(response: 0.6, dampingFraction: 0.72) : .easeOut(duration: 0.25)) {
            phase = .done
            gather = 0
            glow = 0
        }
        if animates {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { confettiStart = nil }
        }
    }

    /// うまく いかなかった:席が ふたたび ひろがる + やわらかく 2回
    private func finishFailure(_ newFailure: Failure) {
        glowLoop = false
        LayerHaptics.softDouble()
        failure = newFailure
        withAnimation(animates ? .spring(response: 0.6, dampingFraction: 0.75) : .easeOut(duration: 0.25)) {
            phase = .failed
            gather = 0
            glow = 0
        }
    }

    /// 演出が 最後まで 見えるよう、押してから 1.6秒は 待つ
    private func waitForShow(since started: Date) async {
        let wait = max(0, Self.showMinimum - Date().timeIntervalSince(started))
        if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
    }

    private func retryTapped() {
        guard let failure, !retrying else { return }
        Haptics.play(.click)
        switch failure.kind {
        case .save:
            // なまえ画面へ(入力は のこす)
            self.failure = nil
            withAnimation(.easeOut(duration: 0.3)) { phase = .name }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isNameFocused = true }
        case .link:
            guard let group = createdGroup else { return }
            retrying = true
            Task { @MainActor in
                let madeLink = await Self.makeLink(for: group, context: modelContext)
                retrying = false
                guard let madeLink else {
                    LayerHaptics.softDouble()
                    self.failure = Failure(kind: .link, detail: NewGroupFlowView.lastLinkFailureReason ?? CloudDiagnostics.last ?? "")
                    return
                }
                inviteLink = madeLink
                createdShareURL = InviteConfig.shareURL(from: madeLink) ?? madeLink
                if picked.isEmpty || !invited.isEmpty {
                    finishSuccess()
                } else {
                    await sendCards(group: group, link: madeLink)
                }
            }
        case .cards:
            guard let group = createdGroup else { return }
            retrying = true
            Task { @MainActor in
                await sendCards(group: group, link: inviteLink)
                retrying = false
            }
        }
    }

    /// えらんだ 友だちに 招待カードを 送る(今までと 同じ FriendCloud.sendInvites)
    private func sendCards(group: LaterGroup, link: URL?) async {
        let ids = picked
        let ok = await FriendCloud.sendInvites(to: ids, groupName: group.name, memberCount: group.members.count, shareURL: link, myName: currentUser?.name ?? "")
        if ok {
            invited = ids
            GroupInviteSentStore.add(ids, to: group.id)
            finishSuccess()
        } else {
            CloudDiagnostics.step("招待カード:送れなかった")
            finishFailure(Failure(kind: .cards, detail: FriendError.network.message))
        }
    }

    // MARK: 作成(保存 → リンク → 招待カード。順番も 呼ぶ 関数も 今までと 同じ)

    private func create() {
        guard !isCreating, createdGroup == nil else { return }
        CloudDiagnostics.begin("グループを つくる:押した")
        let started = Date()
        guard let user = currentUser else {
            // 黙って もどらない(自分の プロフィールが まだ 読めていない)
            CloudDiagnostics.step("止まった:自分の プロフィール(UserProfile)が ない")
            Task { @MainActor in
                await waitForShow(since: started)
                finishFailure(Failure(kind: .save, detail: "UserProfile が まだ 読めていません"))
            }
            return
        }
        guard let cloudKitManager = CloudKitManager.current else {
            CloudDiagnostics.step("止まった:iCloud(CloudKitManager)が まだ 用意できていない")
            Task { @MainActor in
                await waitForShow(since: started)
                finishFailure(Failure(kind: .save, detail: "iCloud に まだ つながっていません(CloudKitManager なし)"))
            }
            return
        }
        if cloudKitManager.currentUserRecordName == nil {
            CloudDiagnostics.step("注意:iCloud の ユーザーが まだ わからない(サインイン・つながりを 確認)")
        }
        isCreating = true
        failure = nil

        let group = LaterGroup(name: finalName, host: user, autoGenerateMission: false, isPrivate: true)
        group.memberLimit = GroupMembershipPolicy.maxMembersPerGroup
        group.colorIndex = GroupPalette.index(forName: finalName)
        group.faceStyle = GroupFaceStyle.aura
        group.showsInitial = true
        group.joinedAt = Date()
        _ = group.addMember(user)
        modelContext.insert(group)

        Task { @MainActor in
            let sharingService = GroupSharingService(container: cloudKitManager.container, modelContext: modelContext, cloudKitManager: cloudKitManager)
            do {
                try await sharingService.createGroup(group, hostProfile: user)
            } catch GroupSharingError.quotaExceeded(groupCreatedWithoutImages: true) {
                // iCloud の容量不足で、写真だけ除いて作れた(グループは作成ずみ)
                CloudDiagnostics.step("注意:容量不足で 写真だけ のぞいて 作成")
            } catch {
                // 開発用の詳細(長押しで見る)。CKError は GroupSharingService が のこす。それ以外も ここで のこす
                if !(error is GroupSharingError) || CloudDiagnostics.last == nil {
                    CloudDiagnostics.record("グループを つくる", CloudDiagnostics.report(error))
                }
                if case GroupSharingError.zoneCreationFailed(let underlying) = error {
                    CloudDiagnostics.record("グループを つくる:ゾーン", CloudDiagnostics.report(underlying))
                }
                CloudDiagnostics.step("止まった:作成に 失敗(\(String(describing: error).prefix(160)))")
                // 保存に 失敗:グループは 一覧に 入れない
                modelContext.delete(group)
                try? modelContext.save()
                let reason = GroupCreateFailureText.reason(for: error)
                CloudDiagnostics.step("画面の文:\(reason)")
                await waitForShow(since: started)
                isCreating = false
                finishFailure(Failure(kind: .save, detail: "\(reason)\n\(CloudDiagnostics.report(error))"))
                return
            }
            createdGroup = group
            CloudDiagnostics.step("作成 OK")
            // 本物の リンク(CKShare の URL)を つくる
            var madeLink = await Self.makeLink(for: group, context: modelContext)
            if madeLink == nil {
                // リンクの 作成だけが 失敗:自動で 1回 やり直す(グループは もう 保存ずみ。だまって 止まらない)
                CloudDiagnostics.step("リンク:失敗。自動で 1回 やり直す")
                try? await Task.sleep(for: .seconds(1))
                madeLink = await Self.makeLink(for: group, context: modelContext)
            }
            inviteLink = madeLink
            createdShareURL = madeLink.flatMap { InviteConfig.shareURL(from: $0) } ?? madeLink
            CloudDiagnostics.step(madeLink == nil ? "リンク:できなかった(画面で もういちど)" : "リンク OK")
            // 合言葉は、画面には出さないが、これまでどおり作っておく(合言葉で入れるように・グループの設定で見られる)
            Task { @MainActor in passphrase = try? await GroupInviteService.passphrase(for: group, context: modelContext) }
            await waitForShow(since: started)
            isCreating = false
            guard let madeLink else {
                finishFailure(Failure(kind: .link, detail: NewGroupFlowView.lastLinkFailureReason ?? CloudDiagnostics.last ?? ""))
                return
            }
            if picked.isEmpty {
                finishSuccess()
            } else {
                await sendCards(group: group, link: madeLink)
            }
        }
    }

    // MARK: 見た目の 確認(テスト)

    private func applyPreview(_ preview: Preview) {
        switch preview {
        case .name:
            break
        case .creating:
            phase = .creating
            isCreating = true
            gather = 0.6
            glow = 0.8
        case .doneLink, .doneFriends:
            phase = .done
            createdShareURL = URL(string: "https://www.icloud.com/share/0aBcDeFgHiJkLmNoPq")
            if preview == .doneFriends { invited = Array(friends.prefix(3).map(\.id)) }
        case .failed:
            phase = .failed
            failure = Failure(kind: .link, detail: "CKError 15 serverRejectedRequest: Invalid Arguments")
        }
    }
}

// MARK: - 背景(ぼかした 色の玉が 3こ ゆっくり 動く)

private struct GroupCreateBackdrop: View {
    let colors: [Color]
    let bg: Color
    let night: Bool
    let animates: Bool

    var body: some View {
        TimelineView(.animation(paused: !animates)) { context in
            let t = animates ? context.date.timeIntervalSinceReferenceDate : 0
            GeometryReader { proxy in
                let w = proxy.size.width, h = proxy.size.height
                ZStack {
                    bg
                    blob(colors[0], size: w * 0.95, x: w * (0.22 + 0.06 * sin(t / 7)), y: h * (0.2 + 0.04 * cos(t / 9)))
                    blob(colors[1], size: w * 0.85, x: w * (0.82 + 0.05 * cos(t / 8)), y: h * (0.34 + 0.05 * sin(t / 6.5)))
                    blob(colors[0].opacity(0.8), size: w * 0.7, x: w * (0.5 + 0.07 * sin(t / 10)), y: h * (0.78 + 0.03 * cos(t / 7.5)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.8), value: colors)
    }

    private func blob(_ color: Color, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(color.opacity(night ? 0.34 : 0.42))
            .frame(width: size, height: size)
            .blur(radius: size * 0.28)
            .position(x: x, y: y)
    }
}

// MARK: - アバターと 7つの 席

enum GroupCreateSeat: Equatable {
    case empty
    case friend(initial: String, colors: [Color], pending: Bool)
    case host(initial: String, colors: [Color])
}

struct GroupCreateStage: View {
    let initial: String
    let avatarColors: [Color]
    let seats: [GroupCreateSeat]
    let flashSeat: Int?
    let flashToken: Int
    let bounce: Int
    /// 0(ひろがる)〜 1(アバターへ 吸いこまれた)
    let gather: CGFloat
    /// アバターの 光(0〜1)
    let glow: Double
    /// 保存を 待つ間、光を くりかえす
    let glowLoop: Bool
    let animates: Bool
    let ink: Color
    let seatLine: Color

    static let avatar: CGFloat = 128
    static let seat: CGFloat = 38
    static let radius: CGFloat = 110
    static var box: CGFloat { radius * 2 + seat + 8 }

    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(paused: !animates)) { context in
            let t = animates ? context.date.timeIntervalSince(start) : 0
            ZStack {
                ring(t)
                avatarFace(t)
                ForEach(Array(seats.enumerated()), id: \.offset) { index, seat in
                    seatView(seat, index: index)
                        .offset(seatOffset(index: index, count: seats.count, t: t))
                        .scaleEffect(1 - 0.6 * gather)
                        .opacity(Double(1 - gather))
                }
            }
            .frame(width: Self.box, height: Self.box)
        }
    }

    /// 虹色の リング(14秒で 1周)
    private func ring(_ t: Double) -> some View {
        Circle()
            .strokeBorder(
                AngularGradient(colors: [Color(hex: "FF6A5F"), Color(hex: "FFC24B"), Color(hex: "7BE07F"), Color(hex: "5FC8FF"), Color(hex: "9A7CFF"), Color(hex: "FF6FB5"), Color(hex: "FF6A5F")], center: .center),
                lineWidth: 4
            )
            .frame(width: Self.avatar + 16, height: Self.avatar + 16)
            .rotationEffect(.degrees(t / 14 * 360))
    }

    private func avatarFace(_ t: Double) -> some View {
        let loop = glowLoop ? 0.45 + 0.4 * (0.5 - 0.5 * cos(t * 2 * .pi / 1.1)) : 0
        let light = max(glow, loop)
        return ZStack {
            Circle()
                .fill(LinearGradient(colors: avatarColors, startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(initial.isEmpty ? "?" : initial)
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                .contentTransition(.opacity)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: bounce) { view, scale in
                    view.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        SpringKeyframe(1.16, duration: 0.12, spring: .snappy)
                        SpringKeyframe(1, duration: 0.3, spring: .bouncy)
                    }
                }
        }
        .frame(width: Self.avatar, height: Self.avatar)
        .overlay(Circle().fill(.white).opacity(light * 0.55).blendMode(.plusLighter))
        .shadow(color: avatarColors[0].opacity(0.35 + light * 0.5), radius: 18 + light * 30)
        .scaleEffect(1 + 0.06 * light)
    }

    /// 公転(80秒で 1周)+ ふわふわ 上下。吸いこまれる ほど 中心へ
    private func seatOffset(index: Int, count: Int, t: Double) -> CGSize {
        let angle = -Double.pi / 2 + Double(index) / Double(max(count, 1)) * 2 * .pi + t / 80 * 2 * .pi
        let r = Self.radius * (1 - gather)
        let bob = animates ? 3 * sin(t * 2 * .pi / 3.2 + Double(index)) : 0
        return CGSize(width: cos(angle) * r, height: sin(angle) * r + bob)
    }

    @ViewBuilder
    private func seatView(_ seat: GroupCreateSeat, index: Int) -> some View {
        switch seat {
        case .empty:
            ZStack {
                Circle().fill(Color.white.opacity(0.18))
                Circle().strokeBorder(seatLine.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                Image(systemName: "plus").font(.system(size: 13, weight: .bold)).foregroundStyle(seatLine)
            }
            .frame(width: Self.seat, height: Self.seat)
            .modifier(SeatFlash(on: flashSeat == index, token: flashToken, animates: animates))
        case let .friend(initial, colors, pending):
            seatFace(initial: initial, colors: colors)
                .overlay(Circle().strokeBorder(ink.opacity(0.75), style: StrokeStyle(lineWidth: 2, dash: pending ? [3, 3] : [])).padding(-3))
                .transition(.scale(scale: 0.2).combined(with: .opacity))
        case let .host(initial, colors):
            seatFace(initial: initial, colors: colors)
                .overlay(Circle().strokeBorder(ink.opacity(0.75), lineWidth: 2).padding(-3))
        }
    }

    private func seatFace(initial: String, colors: [Color]) -> some View {
        ZStack {
            Circle().fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(initial).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
        }
        .frame(width: Self.seat, height: Self.seat)
    }
}

/// 席が 1つ ぴかっと 光る(文字を 打つたび)
private struct SeatFlash: ViewModifier {
    let on: Bool
    let token: Int
    let animates: Bool

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: on ? token : -1) { view, light in
            view
                .overlay(Circle().fill(.white).opacity(light * 0.85).blendMode(.plusLighter))
                .shadow(color: .white.opacity(light), radius: 10 * light)
                .scaleEffect(1 + 0.12 * light)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(on && animates ? 1 : 0, duration: 0.08)
                LinearKeyframe(0, duration: 0.42)
            }
        }
    }
}

// MARK: - 紙吹雪(22こ、7色 + 白。アバターから 広がる)

private struct GroupConfetti: View {
    let start: Date

    static let colors: [Color] = ["FF6A5F", "FFC24B", "7BE07F", "5FC8FF", "9A7CFF", "FF6FB5", "FF8A3D", "FFFFFF"].map { Color(hex: $0) }
    static let count = 22

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
            GeometryReader { proxy in
                let origin = CGPoint(x: proxy.size.width / 2, y: proxy.safeAreaInsets.top + 62 + GroupCreateStage.box / 2)
                Canvas { canvas, _ in
                    for i in 0..<Self.count {
                        let seed = Double(i)
                        let angle = seed / Double(Self.count) * 2 * .pi + sin(seed * 12.9898) * 0.4
                        let speed = 260 + 140 * abs(sin(seed * 78.233))
                        let x = origin.x + cos(angle) * speed * t
                        let y = origin.y + sin(angle) * speed * t + 420 * t * t
                        let fade = max(0, 1 - t / 1.8)
                        guard fade > 0 else { continue }
                        var piece = canvas
                        piece.opacity = fade
                        piece.translateBy(x: x, y: y)
                        piece.rotate(by: .radians(t * (4 + seed.truncatingRemainder(dividingBy: 5))))
                        let rect = CGRect(x: -4, y: -6, width: 8, height: 12)
                        piece.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(Self.colors[i % Self.colors.count]))
                    }
                }
            }
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
/// 改行キーは「完了」(作成画面)。キーボードの色は画面にあわせる。
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
    var alignment: NSTextAlignment = .natural
    var fontSize: CGFloat = 25
    var returnKey: UIReturnKeyType = .next
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.font = .systemFont(ofSize: fontSize, weight: .bold)
        field.textAlignment = alignment
        field.returnKeyType = returnKey
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.enablesReturnKeyAutomatically = false
        field.accessibilityLabel = "グループの なまえ"
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
