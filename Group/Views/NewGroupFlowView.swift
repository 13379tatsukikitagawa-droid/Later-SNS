import PhotosUI
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
    /// v58 §5:TRIP SETTINGS モード(nil なら ふつうの New trip)。既存の Trip を 渡すと、
    /// なまえ・表紙・メンバーを 初期値に 入れ、下のボタンが「Save changes」+「Trip をおわる / ぬける」になる。
    var existingGroup: LaterGroup? = nil
    /// 「ぬける」を 押した(本物の 処理は 呼び出し側の 既存フロー(leaveSnapshot など)に まかせる。ここでは 何も しない)
    var onLeaveRequested: () -> Void = {}
    /// 「Trip をおわる」(作成者だけ)を 押した。同上、本物の 処理は 呼び出し側に まかせる
    var onEndTripRequested: () -> Void = {}

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

    // v58 §3:New trip ウィザード(Cover / Where / When / Who)。見た目だけ。
    enum WizardStep: Int, CaseIterable { case cover, whereStep, when, who }
    @State private var wizardStep: WizardStep = .cover
    @State private var coverPickerItem: PhotosPickerItem?
    /// v58 §3 Cover:選んだ 表紙(大きさ・位置・色あいを かけたあと)。create() で 実在の `group.iconImageData` に
    /// そのまま 入れる(新しい フィールドは 作らない)
    @State private var coverImageData: Data?
    /// v58 §3 Cover クロップ:GroupSettingsView(旧 設定画面)の FaceImageRenderer/FaceTone を そのまま 再利用。
    /// 選んだ もとの 写真(切り出し まえ)
    @State private var coverSourceImage: UIImage?
    @State private var coverFaceScale: CGFloat = 1
    @State private var coverFaceOffset: CGSize = .zero
    @State private var coverDragBase: CGSize?
    @State private var coverTone: FaceTone = .original
    /// v58 §3 When:12日ぶんの 候補の うち、はじまり・おわりの index。表示だけ(保存する フィールドが 無いので、今は その場 限り)
    @State private var tripStartDay: Int?
    @State private var tripEndDay: Int?
    /// v58 §5:「Trip をおわる」は 2回押しで 確定(1回目から 2.4秒 以内)
    @State private var endConfirmArmed = false

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
    @State private var haptics = ExposureHaptics()
    // v43:できた画面から ともだちを 追加で 招待する
    @State private var showingAddFriends = false
    @State private var addSending = false

    private var colors: GroupCreateColors { GroupCreateColors(night: palette.isNight) }
    private var currentUser: UserProfile? { UserProfile.current(from: profiles) }
    private var finalName: String { GroupCreateName.finalize(name) }
    private var nameStatus: GroupCreateName.Status { GroupCreateName.status(name) }
    private var shownName: String { createdGroup?.name ?? finalName }
    private var myGroupNames: [String] { currentUser?.groups.filter { !$0.isPersonalSpace }.map(\.name) ?? [] }
    /// 10個のときは、つくらせない
    private var isFull: Bool { myGroupNames.count >= GroupMembershipPolicy.maxGroupsPerUser && createdGroup == nil }
    private var canCreate: Bool { nameStatus == .ok && !isCreating && !isFull }
    /// v58 §5:TRIP SETTINGS の 保存。既存の グループの 編集なので、グループ数の 上限(isFull)は 関係ない
    private var canSaveSettings: Bool { nameStatus == .ok && !isCreating }
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
            Color(hex: "0B0B0C").ignoresSafeArea()

            switch phase {
            case .name, .creating:
                wizardBody
                    .transition(.opacity)
            case .done:
                doneBody
                    .transition(.opacity)
            case .failed:
                failedBody
                    .transition(.opacity)
            }

            if let toast {
                Text(toast)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(Capsule().fill(.black.opacity(0.85)))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 64)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .allowsHitTesting(false)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toast)
        .animation(.easeInOut(duration: 0.3), value: phase)
        .onAppear(perform: appear)
        .onDisappear { haptics.tearDown() }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardUp = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardUp = false }
        }
        .onChange(of: coverPickerItem) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
                coverSourceImage = image
                coverFaceScale = 1
                coverFaceOffset = .zero
                coverTone = .original
                renderCoverPreview()
            }
        }
        .sheet(isPresented: $showingShare) {
            // 今までと 同じ:アイコンつきの 招待文(全文)を 渡す
            ShareSheet(activityItems: [
                ShareLinkItemSource(text: shareMessage, title: "「\(shownName)」に招待されました。")
            ]) { _ in showingShare = false }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingAddFriends) {
            // v43:できた あとから ともだちを よぶ(今の GroupInviteCard の 流れを そのまま 使う)
            GroupAddFriendsSheet(
                friends: friends.filter { !invited.contains($0.id) },
                sending: addSending,
                onSend: { ids in Task { await sendAdditionalInvites(ids) } },
                onClose: { showingAddFriends = false }
            )
        }
    }

    /// v58 §3:0.5秒で 下から 出る New trip ウィザード(Cover → Where → When → Who)
    private var wizardBody: some View {
        VStack(spacing: 0) {
            wizardHeader
            stepDots
            TabView(selection: $wizardStep) {
                coverStep.tag(WizardStep.cover)
                whereStepView.tag(WizardStep.whereStep)
                whenStepView.tag(WizardStep.when)
                whoStepView.tag(WizardStep.who)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: wizardStep)
        }
        .safeAreaInset(edge: .bottom) { wizardBottomBar }
        .opacity(phase == .creating ? 0.3 : 1)
        .overlay {
            if phase == .creating { creatingOverlay }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: 上(✕・NEW TRIP / TRIP SETTINGS)

    private var wizardHeader: some View {
        HStack {
            Button(action: closeTapped) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(PressScaleStyle())
            .opacity(isCreating ? 0.35 : 1)
            .disabled(isCreating)
            .accessibilityLabel("とじる")
            Spacer()
            Text(verbatim: existingGroup == nil ? "NEW TRIP" : "TRIP SETTINGS")
                .font(Darkroom.mono(11)).tracking(0.2 * 11)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    /// 4ステップの 小さい 点(Cover・Where・When・Who)
    private var stepDots: some View {
        HStack(spacing: 7) {
            ForEach(WizardStep.allCases, id: \.self) { s in
                Capsule().fill(s == wizardStep ? LaterColor.lime : .white.opacity(0.2))
                    .frame(width: s == wizardStep ? 18 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.25), value: wizardStep)
            }
        }
        .padding(.top, 14)
        .accessibilityHidden(true)
    }

    // MARK: v58 §3 Cover:写真(62×80)を 横に 並べる。選んだ 写真は 紙色の 輪で 浮く

    private var coverStep: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            Text(verbatim: "Cover").font(LF.serif(26)).foregroundStyle(.white)
            PhotosPicker(selection: $coverPickerItem, matching: .images) {
                ZStack {
                    if let coverImageData, let uiImage = UIImage(data: coverImageData) {
                        Image(uiImage: uiImage).resizable().scaledToFill()
                    } else {
                        Color(hex: "1B1B1B")
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 26, weight: .regular))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .frame(width: 124, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(coverImageData == nil ? .white.opacity(0.14) : Color(hex: "F5F0E8"), lineWidth: coverImageData == nil ? 1 : 3)
                )
                .shadow(color: .black.opacity(coverImageData == nil ? 0 : 0.4), radius: 10, y: 6)
                .gesture(coverSourceImage == nil ? nil : coverDragGesture)
            }
            .buttonStyle(PressScaleStyle())
            .onChange(of: coverPickerItem) { _, _ in Haptics.play(.sel) }
            Text(verbatim: coverSourceImage == nil ? "カメラロールから えらぶ" : "ドラッグで 位置を 調整できます")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.5))
            // v58 §3 Cover の クロップ・色あい(旧 設定画面の FaceImageRenderer/FaceTone を そのまま 再利用)
            if coverSourceImage != nil {
                HStack(spacing: 12) {
                    Text(verbatim: "大きさ").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(.white)
                    Slider(value: $coverFaceScale, in: FaceImageRenderer.scaleRange).tint(.white)
                        .onChange(of: coverFaceScale) { _, _ in
                            coverFaceOffset = FaceImageRenderer.clampOffset(coverFaceOffset, scale: coverFaceScale)
                            renderCoverPreview()
                        }
                }
                .padding(.horizontal, 24)
                HStack(spacing: 8) {
                    ForEach(FaceTone.allCases) { value in
                        Button {
                            Haptics.play(.sel)
                            coverTone = value
                            renderCoverPreview()
                        } label: {
                            Text(value.label)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(coverTone == value ? Color(hex: "111111") : .white)
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .background(Capsule().fill(coverTone == value ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.white.opacity(0.08))))
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
                .padding(.horizontal, 24)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: v58 §3 Where:行き先(前の ラウンドで 作った チップを 再利用)

    private var whereStepView: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            Text(verbatim: "Where").font(LF.serif(26)).foregroundStyle(.white)
            nameField
            destinationChips
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    // MARK: v58 §3 When:12日ぶんの 候補(6列×2段)。はじまり → おわりの 順に 押す

    private var whenStepView: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            HStack {
                Text(verbatim: "When").font(LF.serif(26)).foregroundStyle(.white)
                Spacer()
                if let days = tripDays {
                    Text(verbatim: "\(days) DAYS")
                        .font(Darkroom.mono(10)).tracking(0.15 * 10)
                        .foregroundStyle(LaterColor.lime)
                }
            }
            .padding(.horizontal, 24)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(0..<12, id: \.self) { i in dayCell(i) }
            }
            .padding(.horizontal, 24)
            Text(verbatim: tripRangeText ?? "はじまりの日 → おわりの日 の 順に おしてください")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer(minLength: 0)
        }
    }

    private var tripDays: Int? {
        guard let s = tripStartDay, let e = tripEndDay else { return nil }
        return e - s + 1
    }

    private var tripRangeText: String? {
        guard let s = tripStartDay, let e = tripEndDay else { return nil }
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: s, to: Date()) ?? Date()
        let end = cal.date(byAdding: .day, value: e, to: Date()) ?? Date()
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return "FROM \(f.string(from: start)) → TO \(f.string(from: end))"
    }

    private func dayCell(_ i: Int) -> some View {
        let date = Calendar.current.date(byAdding: .day, value: i, to: Date()) ?? Date()
        let f = DateFormatter()
        f.dateFormat = "d"
        let inRange = tripStartDay != nil && tripEndDay != nil && i >= tripStartDay! && i <= tripEndDay!
        let isEnd = i == tripStartDay || i == tripEndDay
        return Button {
            if tripStartDay == nil || (tripStartDay != nil && tripEndDay != nil) {
                Haptics.play(.tick)
                tripStartDay = i
                tripEndDay = nil
            } else if i >= tripStartDay! {
                Haptics.play(.click)
                tripEndDay = i
            } else {
                Haptics.play(.tick)
                tripStartDay = i
            }
        } label: {
            Text(verbatim: f.string(from: date))
                .font(.system(size: 14, weight: isEnd ? .bold : .medium, design: .monospaced))
                .foregroundStyle(isEnd ? Color(hex: "111111") : (inRange ? Color(hex: "111111") : .white.opacity(0.8)))
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isEnd ? LaterColor.lime : (inRange ? LaterColor.lime.opacity(0.35) : .white.opacity(0.08)))
                )
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(Text(verbatim: f.string(from: date)))
    }

    // MARK: v58 §3 Who:既存の 友だち選び(friendsRow)を そのまま 再利用

    private var whoStepView: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            Text(verbatim: "Who").font(LF.serif(26)).foregroundStyle(.white)
            friendsRow
            Spacer(minLength: 0)
        }
    }

    // MARK: 下に 固定の Create trip →

    private var wizardBottomBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if wizardStep != .cover {
                    Button {
                        Haptics.play(.tick)
                        withAnimation { wizardStep = WizardStep(rawValue: wizardStep.rawValue - 1) ?? .cover }
                    } label: {
                        Image(systemName: "chevron.left").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 58, height: 58)
                            .background(Circle().fill(.white.opacity(0.08)))
                    }
                    .buttonStyle(PressScaleStyle())
                }
                if wizardStep != .who {
                    Button {
                        Haptics.play(.sel)
                        withAnimation { wizardStep = WizardStep(rawValue: wizardStep.rawValue + 1) ?? .who }
                    } label: {
                        Text(verbatim: "Next →")
                            .font(LF.inter(800, 17))
                            .foregroundStyle(Color(hex: "111111"))
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(Capsule().fill(Color(hex: "F5F0E8")))
                    }
                    .buttonStyle(PressScaleStyle())
                } else if existingGroup != nil {
                    Button(action: saveChanges) {
                        Text(verbatim: "Save changes")
                            .font(LF.inter(800, 17))
                            .foregroundStyle(canSaveSettings ? Color(hex: "111111") : .white.opacity(0.4))
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(Capsule().fill(canSaveSettings ? Color(hex: "F5F0E8") : Color(hex: "1E1E1F")))
                    }
                    .buttonStyle(PressScaleStyle())
                    .disabled(!canSaveSettings)
                } else {
                    Button(action: submit) {
                        Text(verbatim: "Create trip →")
                            .font(LF.inter(800, 17))
                            .foregroundStyle(canCreate ? Color(hex: "111111") : .white.opacity(0.4))
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(Capsule().fill(canCreate ? Color(hex: "F5F0E8") : Color(hex: "1E1E1F")))
                    }
                    .buttonStyle(PressScaleStyle())
                    .disabled(!canCreate)
                }
            }
            if existingGroup != nil { endOrLeaveRow }
        }
        .padding(.horizontal, 18).padding(.bottom, 10).padding(.top, 8)
        .background(.ultraThinMaterial)
    }

    /// v58 §5:作成者だけ「Trip をおわる」(赤・2回押しで確定)、それ以外は「ぬける」だけ。
    /// 本物の 削除/離脱処理は 持たない。既存の 呼び出し側(leaveSnapshot など)に まかせる。
    private var isHost: Bool {
        guard let existingGroup else { return false }
        return GroupLeaveService.isHost(existingGroup, currentUserRecordName: CloudKitManager.current?.currentUserRecordName)
    }

    private var endOrLeaveRow: some View {
        Group {
            if isHost {
                Button {
                    if endConfirmArmed {
                        Haptics.play(.warn)
                        onEndTripRequested()
                    } else {
                        Haptics.play(.click)
                        endConfirmArmed = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { endConfirmArmed = false }
                    }
                } label: {
                    Text(verbatim: endConfirmArmed ? "もういちど押すと おわります" : "Trip をおわる")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LaterColor.red)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().strokeBorder(LaterColor.red.opacity(endConfirmArmed ? 0.9 : 0.4), lineWidth: 1.5))
                }
                .buttonStyle(PressScaleStyle())
                .animation(.easeInOut(duration: 0.2), value: endConfirmArmed)
            } else {
                Button {
                    Haptics.play(.click)
                    onLeaveRequested()
                } label: {
                    Text(verbatim: "ぬける")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LaterColor.red)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().strokeBorder(LaterColor.red.opacity(0.4), lineWidth: 1.5))
                }
                .buttonStyle(PressScaleStyle())
            }
        }
    }

    /// v58 §5:Save changes。裏側は 既存の GroupSettingsService.save(なまえ・表紙)を 呼ぶだけ
    /// v58 §3 Cover:旧 設定画面(GroupSettingsView)と 同じ ドラッグの 式(円板の 大きさに 対する 割合)。
    /// 円の 直径ぶんの 定数(176 × 0.74)の かわりに、Cover の 表示幅(124)を 使う。
    private var coverDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if coverDragBase == nil { coverDragBase = coverFaceOffset }
                guard let base = coverDragBase else { return }
                let disc = 124 * coverFaceScale
                coverFaceOffset = FaceImageRenderer.clampOffset(
                    CGSize(width: base.width + value.translation.width / disc, height: base.height + value.translation.height / disc),
                    scale: coverFaceScale)
                renderCoverPreview()
            }
            .onEnded { _ in coverDragBase = nil }
    }

    private func renderCoverPreview() {
        guard let coverSourceImage else { return }
        coverImageData = FaceImageRenderer.render(coverSourceImage, scale: coverFaceScale, offset: coverFaceOffset, tone: coverTone)?.jpegData(compressionQuality: 0.85)
    }

    private func saveChanges() {
        guard let existingGroup, canSaveSettings else { return }
        Haptics.play(.click)
        isCreating = true
        Task { @MainActor in
            do {
                try await GroupSettingsService.save(group: existingGroup, name: finalName, iconData: coverImageData, colorIndex: nil, context: modelContext)
                isCreating = false
                onCreated(finalName)
                onClose()
            } catch {
                isCreating = false
                finishFailure(Failure(kind: .save, detail: "\(error)"))
            }
        }
    }

    /// つくっている間:パスが 沈んで 浮く(印刷の 感じ)
    private var creatingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView().tint(.white).scaleEffect(1.3)
            Text(verbatim: "Printing your pass…")
                .font(Darkroom.mono(10)).tracking(0.12 * 10)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    /// v58 §4:できた → QR パス(前の ラウンドで 作った InviteQROverlay を そのまま 使う)
    @ViewBuilder
    private var doneBody: some View {
        if let createdGroup, let url = createdShareURL {
            InviteQROverlay(group: createdGroup, url: url, auraIndex: createdGroup.colorIndex, memberCount: picked.count + 1, onClose: closeTapped)
        } else {
            // 保険:リンクが まだ ない(通常は ここに 来ない。create() が .failed に 回す)
            ProgressView().tint(.white)
        }
    }

    /// うまく いかなかった:かんたんな やりなおし画面(見た目は この ラウンドの 対象外)
    private var failedBody: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 30)).foregroundStyle(.white.opacity(0.6))
            Text(verbatim: "うまく つくれませんでした")
                .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
            if let failure {
                Text(verbatim: failure.detail).font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center).padding(.horizontal, 30).lineLimit(3)
            }
            Button(action: retryTapped) {
                Text(verbatim: "もういちど")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(hex: "111111"))
                    .frame(width: 180, height: 50)
                    .background(Capsule().fill(Color(hex: "F5F0E8")))
            }
            .buttonStyle(PressScaleStyle())
            Button(action: closeTapped) {
                Text(verbatim: "とじる").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 4)
        }
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
            // v33/v43:できた画面は いつも 黒 × フジの緑(昼夜に よらない)
            isDone: phase == .done,
            ink: phase == .done ? .white : colors.ink,
            seatLine: phase == .done ? .white : colors.sub
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
            var list: [GroupCreateSeat] = [.me]
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

            // v58 §3「Where」の近似:旅さきの定番候補(押すと その場で なまえ欄に 入る)
            if !keyboardUp || isNameFocused {
                destinationChips
                    .padding(.top, 10)
            }

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

    /// v58 §3「Where」の近似:定番の 旅さき 6つ。押すと なまえ欄に 入る(裏の 保存処理は 今の まま)
    /// v58 §3「Where」:押すと 英語名(Kyoto など)が パスに 入る(チップ自体は 日本語の まま)
    private static let destinations: [(ja: String, en: String)] = [
        ("京都", "Kyoto"), ("沖縄", "Okinawa"), ("修学旅行", "School Trip"),
        ("卒業旅行", "Grad Trip"), ("合宿", "Camp"), ("ライブ遠征", "Live Trip"),
    ]

    private var destinationChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.destinations, id: \.ja) { place in
                    Button {
                        Haptics.play(.sel)
                        name = place.en
                    } label: {
                        Text(verbatim: place.ja)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(name == place.en ? Color(hex: "111111") : colors.ink)
                            .padding(.horizontal, 13)
                            .frame(minHeight: 32)
                            .background(Capsule().fill(name == place.en ? LaterColor.lime : colors.field))
                            .overlay(Capsule().strokeBorder(colors.line.opacity(0.7), lineWidth: name == place.en ? 0 : 1))
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityLabel("行き先の候補、\(place.ja)")
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

    /// v33/v43/v44/v45/v46:できた画面(黒 × フジの緑。KEY が 主役)
    private var doneContent: some View {
        VStack(spacing: 0) {
            Text(verbatim: invited.isEmpty ? "CREATED" : "SENT")
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .tracking(0.24 * 10.5)
                .foregroundStyle(Darkroom.orange)
                .padding(.top, 10)
            Text(invited.isEmpty ? shownName : "おくりました")
                .font(Darkroom.title(invited.isEmpty ? shownName : "おくりました", size: 38))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(.top, 8)
                .padding(.horizontal, 24)
                .accessibilityAddTraits(.isHeader)
            if !invited.isEmpty {
                Text("「入る」で なかまに なります")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 6)
                invitedTags
                    .padding(.top, 16)
            }
            keySection
                .padding(.top, 26)
            GroupActionTiles(friendsEmpty: friends.isEmpty, onAdd: addTapped, onLink: sendTapped, onCopy: copyKeyTapped)
                .padding(.top, 22)
                .padding(.horizontal, 20)
        }
        .transition(.opacity)
    }

    /// 合言葉(通信ずみなら KEY、まだなら 小さく 待つ)
    @ViewBuilder
    private var keySection: some View {
        if let code = passphrase {
            GroupKeyReveal(code: code, onCopy: copyKeyTapped)
        } else {
            ProgressView().tint(.white.opacity(0.6)).padding(.vertical, 24)
        }
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
                    Circle().fill(LinearGradient(colors: friend?.colors ?? [Darkroom.weak, Darkroom.weak], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 14, height: 14)
                    Text(friend?.name ?? "ともだち").font(.system(size: 12, weight: .bold)).lineLimit(1)
                    Text(waiting ? "承認まち" : "入った").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(Darkroom.card))
                .overlay(Capsule().strokeBorder(.white.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: waiting ? [3, 3] : [])))
                .accessibilityElement(children: .combine)
            }
          }
          .padding(.horizontal, 24)
          .padding(.vertical, 2)
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
                // v43:「リンクをおくる」「コピー」は Add / Link / Copy の タイルに 統合ずみ
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
            LinearGradient(colors: [bottomBg.opacity(0), bottomBg.opacity(0.92), bottomBg], startPoint: .top, endPoint: .init(x: 0.5, y: 0.35))
                .ignoresSafeArea()
        )
    }

    /// できた画面は 黒、それ以外は 昼夜の 背景
    private var bottomBg: Color { phase == .done ? Color(hex: "0A0A0B") : colors.bg }

    private var laterButton: some View {
        Button(action: closeTapped) {
            Text("あとで")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(phase == .done ? .white.opacity(0.6) : colors.sub)
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

    // MARK: 動き

    private func appear() {
        haptics.prepare()
        appearedAt = Date()
        if let initialName, name.isEmpty { name = GroupCreateName.clean(initialName) }
        if let existingGroup {
            // v58 §5:TRIP SETTINGS。今の 値を 初期値に 入れる(メンバーは 見た目の プレフィルだけ。
            // この画面に メンバーを 入れかえる 保存先は 無いので、Who ステップの 選び なおしは 保存されない)。
            name = existingGroup.name
            coverImageData = existingGroup.iconImageData
            if let iconData = existingGroup.iconImageData { coverSourceImage = UIImage(data: iconData) }
            let memberIDs = Set(existingGroup.members.compactMap(\.cloudKitUserRecordName))
            picked = friends.filter { memberIDs.contains($0.id) }.map(\.id)
        }
        if let preview {
            applyPreview(preview)
            return
        }
        Haptics.play(.soft)
        // アニメが 落ち着いてから(0.7秒)キーボードを 出す(TRIP SETTINGS では 自動で 出さない)
        guard existingGroup == nil else { return }
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

    /// v43/v44:Copy・KEY の タップ → KEY だけ(「#peach408」)を コピー
    private func copyKeyTapped() {
        guard let code = passphrase else { return }
        Haptics.play(.click)
        UIPasteboard.general.string = "#\(code)"
        show("合言葉を コピーしました")
    }

    private func sendTapped() {
        guard joinLink != nil else { return }
        Haptics.play(.click)
        showingShare = true
    }

    private func addTapped() {
        Haptics.play(.pop)
        showingAddFriends = true
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

    /// v43:できた あとから「Add」で ともだちを よぶ(今の GroupInviteCard の 流れを そのまま 使う)
    @MainActor
    private func sendAdditionalInvites(_ ids: [String]) async {
        guard let group = createdGroup, !ids.isEmpty, !addSending else { return }
        addSending = true
        let ok = await FriendCloud.sendInvites(to: ids, groupName: group.name, memberCount: group.members.count, shareURL: inviteLink, myName: currentUser?.name ?? "")
        addSending = false
        if ok {
            invited += ids.filter { !invited.contains($0) }
            GroupInviteSentStore.add(ids, to: group.id)
            Haptics.play(.success)
            showingAddFriends = false
            show("\(ids.count)人に 招待カードを おくりました")
        } else {
            Haptics.play(.warn)
            show("招待カードを おくれませんでした")
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
        // v58 §3 Cover:選んだ 表紙(既存の iconImageData フィールド。新しい保存先は 作らない)
        if let coverImageData { group.iconImageData = coverImageData }
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
            // v58 §4:doneBody は createdGroup を 読むので、見た目の 確認用に 作っておく(本物の 作成は しない)
            createdGroup = LaterGroup(name: finalName.isEmpty ? "Kyoto" : finalName)
            createdShareURL = URL(string: "https://www.icloud.com/share/0aBcDeFgHiJkLmNoPq")
            passphrase = "peach408"
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
    /// v33/v43:ホスト本人の席(名前の1文字ではなく、白い丸にイタリック「you」+ 緑の輪)
    case me
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
    /// v33/v43:できた画面(黒 × フジの緑 × 白赤金の3本線)
    var isDone: Bool = false
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

    /// 虹色の リング(14秒で 1周)。できた画面は 白・赤・白・金の 3本線
    private func ring(_ t: Double) -> some View {
        Group {
            if isDone {
                Circle()
                    .strokeBorder(
                        AngularGradient(colors: [.white, Color(hex: "D8262C"), .white, Color(hex: "C8A46A"), .white], center: .center),
                        lineWidth: 4
                    )
            } else {
                Circle()
                    .strokeBorder(
                        AngularGradient(colors: [Color(hex: "FF6A5F"), Color(hex: "FFC24B"), Color(hex: "7BE07F"), Color(hex: "5FC8FF"), Color(hex: "9A7CFF"), Color(hex: "FF6FB5"), Color(hex: "FF6A5F")], center: .center),
                        lineWidth: 4
                    )
            }
        }
        .frame(width: Self.avatar + 16, height: Self.avatar + 16)
        .rotationEffect(.degrees(t / 14 * 360))
    }

    private func avatarFace(_ t: Double) -> some View {
        let loop = glowLoop ? 0.45 + 0.4 * (0.5 - 0.5 * cos(t * 2 * .pi / 1.1)) : 0
        let light = max(glow, loop)
        let faceColors = isDone ? [Darkroom.orange, Color(hex: "1F9236")] : avatarColors
        return ZStack {
            Circle()
                .fill(LinearGradient(colors: faceColors, startPoint: .topLeading, endPoint: .bottomTrailing))
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
        .shadow(color: faceColors[0].opacity(0.35 + light * 0.5), radius: 18 + light * 30)
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
        case .me:
            ZStack {
                Circle().fill(.white)
                Text(verbatim: "you")
                    .font(.custom("InstrumentSerif-Italic", size: 12))
                    .foregroundStyle(Color(hex: "111111"))
            }
            .frame(width: Self.seat, height: Self.seat)
            .overlay(Circle().strokeBorder(isDone ? Darkroom.orange : ink.opacity(0.75), lineWidth: 2).padding(-3))
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

// MARK: - v44/v45/v46 KEY(文字だけが 暗やみに 浮かぶ。1文字ずつ 現像されるように)

/// 合言葉の 見せ方。code は「peach408」のような 英語+数字(ハイフンなし)。
/// 古い 形(hikari-2741)が 渡された ときは、そのまま 表示する(作り方は 変えない)
private struct GroupKeyReveal: View {
    let code: String
    let onCopy: () -> Void

    @State private var revealedCount = 0
    @State private var flashCopied = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var characters: [Character] { Array(code) }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Rectangle().fill(.white.opacity(0.15)).frame(width: 22, height: 1)
                Text(verbatim: "— K E Y —")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.2 * 10)
                    .foregroundStyle(Color(hex: "6E6E75"))
                Rectangle().fill(.white.opacity(0.15)).frame(width: 22, height: 1)
            }
            ZStack {
                Ellipse()
                    .fill(RadialGradient(colors: [Darkroom.paleGreen.opacity(0.32), .clear], center: .center, startRadius: 0, endRadius: 130))
                    .frame(width: 260, height: 110)
                    .allowsHitTesting(false)
                HStack(spacing: 1) {
                    Text(verbatim: "#")
                        .font(.custom("InstrumentSerif-Italic", size: 32))
                        .foregroundStyle(Darkroom.orange)
                        .opacity(revealedCount > 0 ? 1 : 0)
                        .blur(radius: revealedCount > 0 ? 0 : 6)
                    ForEach(Array(characters.enumerated()), id: \.offset) { index, ch in
                        Text(String(ch))
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(ch.isNumber ? Darkroom.paleGreen : .white)
                            .opacity(revealedCount > index + 1 ? 1 : 0)
                            .blur(radius: revealedCount > index + 1 ? 0 : 6)
                    }
                }
                .tracking(1)
                .opacity(flashCopied ? 0.55 : 1)
            }
            Text(verbatim: flashCopied ? "COPIED" : "TAP TO COPY")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.18 * 10)
                .foregroundStyle(flashCopied ? Darkroom.orange : Color(hex: "6E6E75"))
                .contentTransition(.opacity)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard revealedCount > characters.count else { return }
            Haptics.play(.click)
            onCopy()
            withAnimation(.easeOut(duration: 0.2)) { flashCopied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation(.easeOut(duration: 0.2)) { flashCopied = false } }
        }
        .onAppear { reveal() }
        .onChange(of: code) { _, _ in revealedCount = 0; reveal() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("合言葉")
        .accessibilityValue("ハッシュタグ #\(code)")
        .accessibilityHint("タップで コピー")
        .accessibilityAddTraits(.isButton)
    }

    /// 1文字ずつ ぼかし → くっきり(110msおき)。そのたびに ごく軽い バイブ
    private func reveal() {
        guard revealedCount == 0 else { return }
        if reduceMotion { revealedCount = characters.count + 1; return }
        for i in 0...characters.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.11) {
                revealedCount = i + 1
                Haptics.play(.tick, gap: 0.05)
            }
        }
    }
}

// MARK: - v43 Add / Link / Copy(3つの タイル)

private struct GroupActionTiles: View {
    let friendsEmpty: Bool
    let onAdd: () -> Void
    let onLink: () -> Void
    let onCopy: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                tile(icon: "person.badge.plus", title: "Add", subtitle: "ともだち", primary: false, action: onAdd)
                tile(icon: "square.and.arrow.up", title: "Link", subtitle: "共有する", primary: true, action: onLink)
                tile(icon: "doc.on.doc", title: copied ? "Copied" : "Copy", subtitle: "KEY だけ", primary: false) {
                    onCopy()
                    withAnimation(.easeOut(duration: 0.15)) { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation(.easeOut(duration: 0.2)) { copied = false } }
                }
            }
            if friendsEmpty {
                Text("まだ ともだちが いません ・ Link で よべます")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func tile(icon: String, title: String, subtitle: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(verbatim: title)
                    .font(.custom("InstrumentSerif-Regular", size: 17))
                    .contentTransition(.opacity)
                Text(verbatim: subtitle)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(primary ? .white.opacity(0.85) : Color(hex: "8E8E93"))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 92)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(primary ? Darkroom.orange : Darkroom.card))
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.96))
        .accessibilityLabel("\(title)。\(subtitle)")
    }
}

// MARK: - v43 Add(できた あとから ともだちを えらんで 招待カードを おくる。GroupInviteCard の 流れを そのまま 使う)

private struct GroupAddFriendsSheet: View {
    let friends: [GroupCreateFriend]
    let sending: Bool
    let onSend: ([String]) -> Void
    let onClose: () -> Void

    @State private var picked: Set<String> = []
    @Environment(\.palette) private var palette
    private var colors: GroupCreateColors { GroupCreateColors(night: palette.isNight) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if friends.isEmpty {
                    Spacer()
                    Text("まだ ともだちが いません。あとで Link で よべます")
                        .font(.system(size: 14))
                        .foregroundStyle(colors.sub)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76))], spacing: 16) {
                            ForEach(friends) { friend in friendCell(friend) }
                        }
                        .padding(20)
                    }
                    Button {
                        Haptics.play(.click)
                        onSend(Array(picked))
                    } label: {
                        Text(picked.isEmpty ? "えらんで おくる" : "\(picked.count)人に おくる")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(picked.isEmpty ? colors.disabledText : colors.primaryText)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Capsule().fill(picked.isEmpty ? colors.disabledBg : colors.primaryBg))
                    }
                    .buttonStyle(PressScaleStyle(scale: 0.97))
                    .disabled(picked.isEmpty || sending)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
            }
            .background(colors.bg.ignoresSafeArea())
            .navigationTitle("ともだちを よぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("とじる", action: onClose)
                }
            }
        }
        .preferredColorScheme(colors.night ? .dark : .light)
        .interactiveDismissDisabled(sending)
    }

    private func friendCell(_ friend: GroupCreateFriend) -> some View {
        let on = picked.contains(friend.id)
        return Button {
            if on {
                Haptics.play(.tick)
                picked.remove(friend.id)
            } else {
                Haptics.play(.pop)
                picked.insert(friend.id)
            }
        } label: {
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
                            .animation(.spring(response: 0.35, dampingFraction: 0.55), value: on)
                    }
                Text(friend.name)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(colors.ink)
                    .lineLimit(1)
            }
        }
        .buttonStyle(SquishButtonStyle())
        .accessibilityLabel(friend.name)
        .accessibilityAddTraits(on ? .isSelected : [])
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
