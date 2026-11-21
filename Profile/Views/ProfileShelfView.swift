import SwiftUI
import SwiftData
import UIKit

// MARK: - ペルソナ名(ユーザー ID から計算する。保存しない)

/// 「朝霧のレンズ #0417」のような、Later の中だけの呼び名。実名ではない。
/// 同じ ID からは、いつも同じ名前ができる(Swift の hashValue は起動のたびに変わるので使わず、FNV-1a で計算する)。
enum ProfilePersonaName {
    private static let adjectives = [
        "朝霧の", "夕凪の", "雨上がりの", "夜明けの", "静かな", "やわらかな",
        "遠い", "小さな", "淡い", "ひそやかな", "まどろみの", "木漏れ日の",
    ]
    private static let nouns = [
        "レンズ", "シャッター", "フィルム", "ポラロイド", "ひかり", "しおり",
        "窓辺", "ランプ", "ペンギン", "カメラ", "かげ", "ほし",
    ]

    /// 64bit の FNV-1a(固定の計算。環境や起動で変わらない)
    static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    static func name(for id: UUID) -> String {
        let hash = fnv1a(id.uuidString)
        let adjective = adjectives[Int(hash % UInt64(adjectives.count))]
        let noun = nouns[Int((hash / 16) % UInt64(nouns.count))]
        let number = Int((hash / 256) % 10_000)
        return "\(adjective)\(noun) #\(String(format: "%04d", number))"
    }
}

// MARK: - フォント(この画面の中にまとめる。色は Palette(昼夜)と ChicColor(Home と同じ値)から使う)

/// フォントが入っていなければ、システムの字にもどす(フォントのファイルは足さない)。
enum ShelfFont {
    /// 名前:Inter Black(Home の「Later」と同じ)
    static func black(_ size: CGFloat) -> Font {
        Typo.ui(900, size)
    }

    /// 小さな「you」と数字:Instrument Serif の斜体
    static func serifItalic(_ size: CGFloat) -> Font {
        UIFont(name: "InstrumentSerif-Italic", size: size) != nil
            ? .custom("InstrumentSerif-Italic", fixedSize: size)
            : .system(size: size, design: .serif).italic()
    }

    static func mono(_ size: CGFloat, bold: Bool = false) -> Font {
        Typo.label(size, bold: bold)
    }
}

// MARK: - 31日ぶんのコマ

/// 今日から過去31日(カレンダーの月ではない)の1コマ。
struct ProfileShelfDay: Identifiable, Equatable {
    static let count = 31
    /// 写真を見られる日数(これを過ぎたら、写真は読みこまない)
    static let retentionDays = DailyExposureRules.photoRetentionDays

    let key: String
    /// 今日からの日数(0が今日)
    let ago: Int
    let date: Date

    var id: String { key }
    var isToday: Bool { ago == 0 }
    var isGone: Bool { ago >= Self.retentionDays }

    /// コマの右上の文字
    var label: String {
        if isToday { return "今日" }
        return isGone ? "消えました" : "あと\(Self.retentionDays - ago)日"
    }

    var dayNumber: Int { Calendar.current.component(.day, from: date) }

    static func make(now: Date, calendar: Calendar = .current) -> [ProfileShelfDay] {
        let today = calendar.startOfDay(for: now)
        return (0..<count).map { ago in
            let date = calendar.date(byAdding: .day, value: -ago, to: today) ?? today
            return ProfileShelfDay(key: ExposureDayStore.dayKey(for: date, calendar: calendar), ago: ago, date: date)
        }
    }
}

// MARK: - 画面

/// プロフィールの上に出すシート(下から出る、プロフィール専用)
enum ProfileShelfSheet: Equatable {
    case settings, edit
}

/// v52:インライン編集で、いまフォーカスしている場所
enum ProfileShelfInlineField: Hashable {
    case name, tag
}

/// プロフィール:自分の「フィルムの棚」。昼(9:00〜)は白、夜(0:00〜)は黒。Home と同じ、白い面・太い文字・落書き・チェキ。
/// 主役は、選んだ日の1枚(チェキ)。自分だけが見る画面で、ランキング・他の人との比較は出さない。場所も出さない。
struct ProfileShelfView: View {
    /// Homeへ戻る(左上)
    var onBack: (() -> Void)?
    /// 「撮る」:撮影の流れ(タグ → 撮影)に入る
    var onShoot: (() -> Void)?
    /// 最初に選ぶ日(日付キー)。nil なら今日。画像の書き出し(テスト)で使う。
    var initialKey: String?
    /// 最初から開いておくシート。画像の書き出し(テスト)で使う。
    var initialSheet: ProfileShelfSheet?

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.modelContext) private var modelContext
    @AppStorage("profileCalmMotion") private var calmSetting = false
    /// 既存の編集画面と同じく、保存した名前をここにも入れる
    @AppStorage("userName") private var userName: String = ""

    @Query private var profiles: [UserProfile]
    @Query(sort: \ExposureDay.captureDate, order: .reverse) private var exposureDays: [ExposureDay]

    @State private var haptics = ProfileFilmHaptics()
    @State private var days: [ProfileShelfDay] = ProfileShelfDay.make(now: Date())
    /// 中央にいるコマ(日付キー)
    @State private var selectedKey: String?
    /// 現像の開始時刻。色づく進み具合は、ここからの経過時間で計算する(アニメーションの進み方に頼らない)
    @State private var developStart = Date()
    /// 設定シート / 編集シート(どちらか1つ)
    @State private var activeSheet: ProfileShelfSheet?
    /// 既存の「通報・ブロックした人」/ 既存の削除の流れ(長押し)
    @State private var isShowingReport = false
    @State private var isShowingDeletion = false
    @State private var toastMessage: String?
    @State private var toastToken = 0
    /// v51 やりなおし:自分の チェキ(タップで QR)・むかしの 日めくりは たたんで おく
    @State private var chekiFlipped = false
    /// v81:アイコン(プロフィール写真)を えらぶ シート
    @State private var showsIconPicker = false
    /// v52:インラインの編集(シートではなく、この画面の中で直接)
    @State private var isEditingInline = false
    @State private var editName = ""
    @State private var editTags: [String] = []
    @State private var editTagInput = ""
    @FocusState private var editFocus: ProfileShelfInlineField?
    /// v51:QR・共有・スキャン・Recap・1年のカレンダー
    @State private var showsQR = false
    @State private var showsScan = false
    @State private var showsRecap = false
    @State private var showsStarCalendar = false
    @State private var shareItems: [Any]?

    // MARK: 色(昼 / 夜)

    private var night: Bool { palette.isNight }
    /// オレンジ(面・枠・光):昼 #FF6A1A / 夜 #FF8A3D
    private var emberFill: Color { night ? palette.stamp : palette.accent }
    /// オレンジ(文字):昼 #C2410C / 夜 #FF8A3D
    private var emberText: Color { night ? palette.stamp : palette.accentText }
    /// 数字の面・帯・タグの面
    private var card: Color { palette.fill }
    /// 丸いボタンの面と線(昼は黒 6% + 10%、夜は白 12% + 16%)
    private var glassFill: Color { night ? Color.white.opacity(0.12) : Color.black.opacity(0.06) }
    private var glassLine: Color { night ? Color.white.opacity(0.16) : Color.black.opacity(0.10) }

    private var profile: UserProfile? { UserProfile.current(from: profiles) }
    /// 「光もれと揺れを止める」か、システムの「視差効果を減らす」のどちらかがオン
    private var calm: Bool { calmSetting || systemReduceMotion }
    private var todayKey: String { days.first?.key ?? "" }
    private var activeKey: String { selectedKey ?? todayKey }
    private var activeDay: ProfileShelfDay? { days.first { $0.key == activeKey } }

    private var displayName: String {
        guard let name = profile?.name, !name.isEmpty else { return "ゲスト" }
        return name
    }


    private var takenKeys: Set<String> { Set(exposureDays.map(\.dayKey)) }

    /// Profile に出してよい日(共有の有無・7日の期限・投稿の選択は、ProfileShot の判定に従う)
    private var points: [String: WeekDayPoint] {
        let shots = ProfileShot.shots(profile: profile, exposureDays: exposureDays, now: Date())
        return Dictionary(shots.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// 連続して撮った日数(今日がまだなら、きのうから数える)
    private var streak: Int {
        let taken = takenKeys
        var count = 0
        for (index, day) in days.enumerated() {
            if taken.contains(day.key) { count += 1 } else if index == 0 { continue } else { break }
        }
        return count
    }

    private var myRecordName: String? { CloudKitManager.current?.currentUserRecordName }

    /// v50/v51:Recap・1年カレンダーは、MEScreenV19 と同じ元データ(1日3枚まで・自分の写真だけ)を使う
    private var meDays: [MEDay] { MERules.days(photos: profile?.photos ?? [], now: Date()) }

    private func recapImage(for shot: MEShot) -> UIImage? {
        guard let data = profile?.photos.first(where: { $0.id == shot.photoID })?.imageData else { return nil }
        return UIImage(data: data)
    }

    // MARK: 本体

    var body: some View {
        ZStack {
            shelf
                // キーボードが出ても、うしろの棚は動かさない(シートだけが上がる)
                .ignoresSafeArea(.keyboard)
            sheetLayer
        }
        .onAppear {
            haptics.prepare()
            if selectedKey == nil { selectedKey = initialKey ?? todayKey }
            if let initialSheet, activeSheet == nil { activeSheet = initialSheet }
            replayDevelop()
        }
        .onChange(of: selectedKey) { old, new in
            guard old != nil, new != nil, old != new else { return }
            haptics.play(.slide)
            replayDevelop()
        }
        // 削除のシートの間、後ろを黒60%で暗く(既存の設定画面と同じ)
        .overlay {
            Color.black.opacity(isShowingDeletion ? 0.6 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.3), value: isShowingDeletion)
        }
        .sheet(isPresented: $isShowingReport) {
            SettingsBlockedList()
                .environment(\.colorScheme, .dark)
        }
        .sheet(isPresented: $isShowingDeletion) {
            AccountDeletionView(groupCount: sharedGroupCount) {
                activeSheet = nil
            }
            .environment(\.colorScheme, .dark)
        }
        // v51:QR・共有・スキャン・Recap・1年のカレンダー(どれも既存の処理をそのまま呼ぶだけ)
        .sheet(isPresented: $showsQR) {
            ProfileSelfQRSheet(name: displayName, recordName: myRecordName)
                .environment(\.colorScheme, .dark)
        }
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) {
            ShareSheet(activityItems: shareItems ?? []) { _ in shareItems = nil }
        }
        .fullScreenCover(isPresented: $showsScan) {
            // friendCount は上限の目安表示にだけ使う。ここでは数えていないので 0(満杯扱いにしない)。
            FriendQRScanView(myName: displayName, friendCount: 0) { showToast($0) }
        }
        .fullScreenCover(isPresented: $showsRecap) {
            RecapPlayerView(days: meDays, images: recapImage(for:), onClose: { showsRecap = false })
        }
        .sheet(isPresented: $showsStarCalendar) {
            MECalendarSheet(
                exposureDays: Array(exposureDays),
                picks: MEPickStore.picks,
                recentKeys: days.map(\.key),
                onJump: { index in
                    let keys = days.map(\.key)
                    if keys.indices.contains(index) { selectedKey = keys[index] }
                },
                onToast: showToast,
                onClose: { showsStarCalendar = false }
            )
            .environment(\.colorScheme, .dark)
        }
    }

    // MARK: v52:インライン編集

    private func beginInlineEdit() {
        haptics.play(.light)
        editName = ProfileShelfEditRules.clampName(displayName)
        editTags = Array((profile?.selfTags ?? []).prefix(ProfileShelfEditRules.maxTags))
        editTagInput = ""
        isEditingInline = true
        DispatchQueue.main.async { editFocus = .name }
    }

    private func cancelInlineEdit() {
        haptics.play(.light)
        editFocus = nil
        isEditingInline = false
    }

    private func saveInlineEdit() {
        editFocus = nil
        saveProfile(name: editName, tags: editTags)
        isEditingInline = false
    }

    /// v51 やりなおし:自分の チェキ + QR/編集/共有/スキャン + 1週間を 主役にしたので、
    /// 画面の 高さに むりに 合わせる(heroHeight を 縮める)仕組みは やめて、ふつうに 縦に スクロールする。
    private var shelf: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            let safeBottom = proxy.safeAreaInsets.bottom

            ZStack(alignment: .top) {
                background.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        topButtons
                            .padding(.top, safeTop + 8)

                        ZStack {
                            selfChekiHero
                            if !isEditingInline { stickerScatter }
                        }
                        .padding(.top, 18)

                        who
                            .padding(.top, 10)

                        if isEditingInline {
                            inlineTagEditor
                                .padding(.top, 14)
                        }

                        profileActionRow
                            .padding(.top, 14)

                        stats
                            .padding(.top, 14)

                        meStripHeader
                            .padding(.top, 18)

                        starCalendarRow
                            .padding(.top, 10)

                        footer
                            .padding(.top, 12)
                            .padding(.bottom, max(safeBottom, 10) + 24)
                    }
                }
                .ignoresSafeArea(.container, edges: .top)
            }
        }
    }

    // MARK: シートとトースト

    private var sheetColors: ProfileSheetColors { ProfileSheetColors(palette: palette) }

    private var sharedGroupCount: Int {
        (profile?.groups ?? []).filter { !$0.isPersonalSpace }.count
    }

    private var sheetTransition: AnyTransition {
        calm ? .opacity : .asymmetric(insertion: .opacity.combined(with: .offset(y: 40)), removal: .opacity)
    }

    private var sheetLayer: some View {
        ZStack(alignment: .bottom) {
            switch activeSheet {
            case .settings:
                ProfileShelfSettingsSheet(
                    colors: sheetColors,
                    nameLine: "\(displayName) · \(profile.map { ProfilePersonaName.name(for: $0.id) } ?? "—")",
                    // v52:編集は、別のシートではなく、この画面の中でそのまま(インライン)
                    onEdit: {
                        openSheet(nil)
                        beginInlineEdit()
                    },
                    onReport: { isShowingReport = true },
                    onDelete: { isShowingDeletion = true },
                    onToast: showToast,
                    onDismiss: { openSheet(nil) }
                )
                .transition(sheetTransition)
            case .edit:
                ProfileShelfEditSheet(
                    colors: sheetColors,
                    name: displayName,
                    tags: profile?.selfTags ?? [],
                    onSave: saveProfile,
                    onToast: showToast,
                    onCancel: { openSheet(nil) }
                )
                .transition(sheetTransition)
            case nil:
                EmptyView()
            }

            if let toastMessage {
                ProfileShelfToast(message: toastMessage, colors: sheetColors)
                    .padding(.bottom, 76)
                    .transition(.opacity.combined(with: .offset(y: 8)))
                    .allowsHitTesting(false)
                    .zIndex(10)
            }
        }
        .animation(calm ? nil : .easeOut(duration: 0.3), value: activeSheet)
        .animation(.easeOut(duration: 0.25), value: toastMessage)
    }

    private func openSheet(_ sheet: ProfileShelfSheet?) {
        if sheet != nil { haptics.play(.light) }
        activeSheet = sheet
    }

    /// 1.9秒で消える
    private func showToast(_ message: String) {
        toastToken += 1
        let token = toastToken
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            if token == toastToken { toastMessage = nil }
        }
    }

    /// 名前・タグを保存する(既存の編集画面 `ProfileEditScreen.save()` と同じ:SwiftData に保存し、グループのみんなにも同期)
    private func saveProfile(name: String, tags: [String]) {
        guard let profile else {
            openSheet(nil)
            return
        }
        profile.name = name
        profile.selfTags = tags
        profile.profileUpdatedAt = Date()
        try? modelContext.save()
        userName = name
        if let cloudKitManager = CloudKitManager.current {
            for group in profile.groups {
                cloudKitManager.markForUpload(userProfile: profile, in: group)
            }
        }
        Task { await UserDirectoryService.publish(profile) }
        openSheet(nil)
        showToast("プロフィールを保存しました")
    }

    // MARK: 背景

    /// 昼:白 + 下からピーチ → ラベンダーのやわらかい光(Home の下の月と同じ色)。夜:黒 + 下のごくうすいオレンジ + 右上の光もれ。
    /// 紙のような粒は、昼 7%・夜 5%(強くしない)。
    private var background: some View {
        ZStack {
            palette.bg
            if night {
                LinearGradient(
                    colors: [.clear, Color(hex: "FF8A3D").opacity(0.18)],
                    startPoint: UnitPoint(x: 0.5, y: 0.7), endPoint: .bottom
                )
                lightLeak
            } else {
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "E3B9FF").opacity(0), location: 0),
                        .init(color: Color(hex: "E3B9FF").opacity(0.38), location: 0.55),
                        .init(color: Color(hex: "FFC0A2").opacity(0.65), location: 1),
                    ],
                    startPoint: UnitPoint(x: 0.5, y: 0.74), endPoint: .bottom
                )
            }
            FilmGrainOverlay(opacity: night ? 0.05 : 0.07, blendMode: .overlay)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    /// 夜の、右上のオレンジの光もれ(9秒の往復)
    private var lightLeak: some View {
        TimelineView(.animation(paused: calm)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = calm ? 0.5 : (1 - cos(t * 2 * .pi / 18)) / 2
            RadialGradient(
                colors: [Color(red: 1, green: 0.59, blue: 0.27).opacity(0.30), .clear],
                center: .center, startRadius: 0, endRadius: 150
            )
            .frame(width: 300, height: 300)
            .blur(radius: 16)
            .offset(x: 90 + (phase - 0.5) * 24, y: -70 + (phase - 0.5) * 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .allowsHitTesting(false)
    }

    // MARK: 上のボタン

    /// v52:編集中は「やめる / 保存する」。ふだんは「戻る / 設定」。
    private var topButtons: some View {
        HStack {
            if isEditingInline {
                Button("やめる") { cancelInlineEdit() }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.sub)
                Spacer()
                Text("Edit").font(.system(size: 13, weight: .heavy)).foregroundStyle(palette.ink)
                Spacer()
                Button("保存する") { saveInlineEdit() }
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(emberText)
            } else {
                glassButton(systemName: "chevron.left", label: "戻る") { onBack?() }
                Spacer()
                glassButton(systemName: "gearshape.fill", label: "設定") { openSheet(.settings) }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 44)
        .animation(.easeOut(duration: 0.2), value: isEditingInline)
    }

    private func glassButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.ink)
                .frame(width: 44, height: 44)
                .background(Circle().fill(glassFill))
                .overlay(Circle().strokeBorder(glassLine, lineWidth: 1))
        }
        .buttonStyle(ShelfPressStyle())
        .accessibilityLabel(label)
    }

    // MARK: 主役:自分の チェキ(mock .pck:226×288・角丸6・タップで QR)
    // FriendScreenV48 の selfCheki と 同じ組み方(写真 or グラデーション+イニシャル・下の白い帯に 名前)。

    private var selfChekiHero: some View {
        let initial = String(displayName.prefix(1))
        return Button {
            haptics.play(.light)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { chekiFlipped.toggle() }
        } label: {
            ZStack {
                if chekiFlipped {
                    selfChekiQRBack.rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                } else {
                    selfChekiFront(initial)
                }
            }
            .frame(width: 226, height: 288)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.white))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .rotationEffect(.degrees(-2))
            .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
            .rotation3DEffect(.degrees(chekiFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("自分の チェキ。タップで QR")
        .overlay(alignment: .bottomTrailing) {
            if UIFlag.v64 && !chekiFlipped {
                Button { Haptics.play(.click); showsIconPicker = true } label: {
                    HStack(spacing: 5) { Image(systemName: "camera.fill").font(.system(size: 11, weight: .bold)); Text("写真").font(.system(size: 12, weight: .heavy)) }
                        .foregroundStyle(.white).padding(.horizontal, 10).frame(height: 28).background(.black.opacity(0.55), in: Capsule())
                }.buttonStyle(.plain).padding(.trailing, 52).padding(.bottom, 62).accessibilityLabel("アイコンの 写真を えらぶ")
            }
        }
        .sheet(isPresented: $showsIconPicker) {
            let cur = profile?.profileImageData.flatMap { UIImage(data: $0) }
            let recent = (profile?.photos ?? []).sorted { $0.captureDate > $1.captureDate }.prefix(8).map { p in
                (id: p.id.uuidString, image: V64Images.image(key: "ip\(p.id)", data: p.imageData, maxPixel: 240), label: Calendar.current.isDateInYesterday(p.captureDate) ? "きのう" : nil as String?)
            }
            IconPickerV81Sheet(name: displayName, current: cur, recent: Array(recent), onSave: { saveIcon($0) }, onClose: { showsIconPicker = false })
                .presentationDetents([.large]).presentationDragIndicator(.hidden).presentationBackground(Color(hex: "141516"))
        }
    }

    /// v81:アイコンを 変えたら その場で 全部の 場所が 変わる(保存 + 参加中の グループへ 再同期 + 公開ディレクトリ)
    private func saveIcon(_ data: Data?) {
        guard let user = profile else { return }
        user.profileImageData = data
        user.profileUpdatedAt = Date()
        try? modelContext.save()
        if let cloud = CloudKitManager.current { for g in user.groups { cloud.markForUpload(userProfile: user, in: g) } }
        Task { await UserDirectoryService.publish(user) }
    }

    private func selfChekiFront(_ initial: String) -> some View {
        ZStack(alignment: .bottom) {
            if let data = profile?.profileImageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                LinearGradient(colors: LayerAvatar.colors(profile?.id ?? UUID(), override: profile?.avatarColorIndex), startPoint: .top, endPoint: .bottom)
                Text(initial).font(.system(size: 60, weight: .heavy)).foregroundStyle(.white.opacity(0.9))
            }
            Rectangle().fill(.white).frame(height: 46)
                .overlay(
                    VStack(spacing: 2) {
                        Text(displayName).font(.custom("InstrumentSerif-Italic", size: 17)).foregroundStyle(.black)
                        Text(Self.stampFormatter.string(from: Date())).font(.system(size: 9, design: .monospaced)).foregroundStyle(.black.opacity(0.5))
                    }
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var selfChekiQRBack: some View {
        VStack(spacing: 10) {
            if let recordName = myRecordName, let qr = QRImage.make(FriendRules.shareLink(recordName: recordName).absoluteString) {
                Image(uiImage: qr).resizable().frame(width: 140, height: 140)
            }
            Text("SCAN TO ADD").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.black.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
    }

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "''yy MM dd"
        return formatter
    }()

    // MARK: 小さな文字・名前・タグ・数字

    /// 名前は もう 自分の チェキ(selfChekiHero)に 出ている。ここは 編集中の 名前フィールドだけ(v54:PERSONA 行は出さない)。
    private var who: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditingInline {
                TextField("名前を入れてください", text: $editName)
                    .focused($editFocus, equals: .name)
                    .font(ShelfFont.black(28))
                    .foregroundStyle(palette.ink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: editName) { _, value in
                        let clamped = ProfileShelfEditRules.clampName(value)
                        if clamped != value { editName = clamped }
                    }
                ShelfScribble()
                    .stroke(emberFill, style: StrokeStyle(lineWidth: 3.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 118, height: 8)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 24)
    }

    /// v54:見本 D01 の `.pst`(6つの ハッシュタグの シール)。チェキの まわりに 散らして、少し かたむける。
    private struct StickerSlot {
        let dx, dy: CGFloat
        let rotation: Double
        let bg: Color
        let ink: Color
        let opacity: Double
    }

    private static let stickerSlots: [StickerSlot] = [
        StickerSlot(dx: -113, dy: -112, rotation: -9, bg: Color(hex: "C8F25A"), ink: .black, opacity: 1),
        StickerSlot(dx: 113, dy: -85, rotation: 8, bg: Color(hex: "EE5E9C"), ink: .white, opacity: 1),
        StickerSlot(dx: -127, dy: 43, rotation: 6, bg: Color(hex: "9ED8FF"), ink: .black, opacity: 1),
        StickerSlot(dx: 122, dy: 61, rotation: -7, bg: Color(hex: "FFD60A"), ink: .black, opacity: 0.92),
        StickerSlot(dx: -94, dy: 159, rotation: -4, bg: Color(hex: "9B8CFF"), ink: .white, opacity: 0.92),
        StickerSlot(dx: 88, dy: 175, rotation: 10, bg: Color(hex: "61D278"), ink: .black, opacity: 0.92),
    ]

    /// タップで、その言葉の日を探す(今は仮:トーストだけ)。編集中は 出さない(inlineTagEditor が 代わり)。
    private var stickerScatter: some View {
        let tags = Array((profile?.selfTags ?? []).prefix(Self.stickerSlots.count))
        return ZStack {
            ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                let slot = Self.stickerSlots[index]
                Button {
                    haptics.play(.light)
                    showToast("#\(tag) の日を探す(仮)")
                } label: {
                    Text("#\(tag)")
                        .font(Typo.ui(900, 15))
                        .tracking(-0.3)
                        .foregroundStyle(slot.ink)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(slot.bg))
                        .shadow(color: .black.opacity(0.5), radius: 0, x: 3, y: 4)
                }
                .buttonStyle(ShelfPressStyle(scale: 0.92))
                .opacity(slot.opacity)
                .rotationEffect(.degrees(slot.rotation))
                .offset(x: slot.dx, y: slot.dy)
            }
        }
        .allowsHitTesting(true)
    }

    /// v52:タグの インライン編集(追加の入力欄 + 外せるチップ)
    private var inlineTagEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    Text("#").foregroundStyle(palette.dim)
                    TextField("言葉を入れて追加", text: $editTagInput)
                        .focused($editFocus, equals: .tag)
                        .submitLabel(.next)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit(addInlineTag)
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(Capsule().fill(glassFill))
                Button(action: addInlineTag) {
                    Text("追加").font(.system(size: 13, weight: .bold)).foregroundStyle(palette.ink)
                        .padding(.horizontal, 14).frame(height: 38)
                        .background(Capsule().fill(card))
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                ForEach(Array(editTags.enumerated()), id: \.offset) { index, tag in
                    let sticker = Darkroom.stickerColors(tag)
                    HStack(spacing: 6) {
                        Text("#\(tag)").font(.system(size: 12.5, weight: .black)).foregroundStyle(sticker.1)
                        Button { editTags.remove(at: index) } label: {
                            Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(sticker.1.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Capsule().fill(sticker.0))
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func addInlineTag() {
        let result = ProfileShelfEditRules.add(editTagInput, to: editTags)
        if case .added(let tags) = result {
            haptics.play(.light)
            editTags = tags
            editTagInput = ""
        }
    }

    /// v51:QR・編集・共有・スキャンの4つ(編集中は出さない。トップバーが Cancel/Done になる)
    @ViewBuilder
    private var profileActionRow: some View {
        if !isEditingInline {
            HStack(spacing: 8) {
                actionButton("qrcode", "QR") {
                    haptics.play(.light)
                    showsQR = true
                }
                actionButton("pencil", "Edit") { beginInlineEdit() }
                actionButton("square.and.arrow.up", "Share") {
                    haptics.play(.light)
                    if let recordName = myRecordName {
                        shareItems = [FriendRules.shareItem(myName: displayName, recordName: recordName)]
                    }
                }
                actionButton("qrcode.viewfinder", "Scan") {
                    haptics.play(.light)
                    showsScan = true
                }
            }
            .padding(.horizontal, 24)
        }
    }

    /// mock .pact button:82pt 高さ・22pt 角丸・アイコン24pt・文字は Instrument Serif 17pt
    private func actionButton(_ systemName: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemName).font(.system(size: 24, weight: .regular)).foregroundStyle(palette.ink)
                Text(label).font(.custom("InstrumentSerif-Regular", size: 17)).foregroundStyle(palette.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 82)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(glassFill))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(glassLine, lineWidth: 1))
        }
        .buttonStyle(ShelfPressStyle(scale: 0.95))
        .accessibilityLabel(label)
    }

    /// v51:「ME · 7 DAYS」のカード(mock .pme:幅いっぱい・高さ118・角丸24)+ Recap(v50)への入口
    @ViewBuilder
    private var meStripHeader: some View {
        if RecapSequence.hasAnyOpenShot(days: meDays) {
            Button {
                haptics.play(.light)
                showsRecap = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Color(hex: "0D0D0E")
                    Text("ME · 7 DAYS")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.6)
                        .foregroundStyle(Color(hex: "FF9A3C"))
                        .padding(.leading, 16).padding(.top, 13)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    meStrip
                        .padding(.leading, 12).padding(.bottom, 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    HStack(spacing: 7) {
                        Text("Recap").font(.system(size: 14, weight: .heavy))
                        Image(systemName: "play.fill").font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Capsule().fill(.white))
                    .padding(.trailing, 14).padding(.bottom, 14)
                }
            }
            .buttonStyle(ShelfPressStyle(scale: 0.98))
            .frame(height: 118)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.07), lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    /// `.pme .pmf`:62pt 高さの 写真の帯(右の Recap ボタンぶん 右を あける)
    private var meStrip: some View {
        let shots = meDays.sorted { $0.ago > $1.ago }.flatMap { day in day.shots.filter(\.reveal.isOpen).map { ($0, day) } }
        return HStack(spacing: 3) {
            ForEach(Array(shots.suffix(7).enumerated()), id: \.offset) { _, pair in
                let image = recapImage(for: pair.0)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        if let image { Image(uiImage: image).resizable().scaledToFill() }
                    }
                    .frame(width: 20, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
        }
        .frame(height: 62)
        .frame(maxWidth: 190, alignment: .leading)
    }

    /// v51:1年ぶんの「色だけ ずっと のこる」ドット(mock .pyr:パディング16・角丸24・帯の高さ62)
    /// MEScreenV19 と同じ MEMiniGrid / MECalendarSheet を 再利用する。
    private var starCalendarRow: some View {
        let keptCount = MEPickStore.picks.count
        return Button {
            haptics.play(.light)
            showsStarCalendar = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("1 YEAR · KEPT").font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.6).foregroundStyle(palette.dim)
                    Spacer()
                    Text("\(keptCount) KEPT").font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.1).foregroundStyle(Color(hex: "FFD60A"))
                }
                MEMiniGrid(exposureDays: exposureDays, picks: MEPickStore.picks)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 62)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(glassFill))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(glassLine, lineWidth: 1))
        }
        .buttonStyle(ShelfPressStyle(scale: 0.97))
        .padding(.horizontal, 16)
    }

    /// 角丸 22pt の `card` の面。数字は Instrument Serif の斜体 30pt、3つのあいだに縦線。
    private var stats: some View {
        let postedDays = Set((profile?.photos ?? []).filter(\.isPosted).map { ExposureDayStore.dayKey(for: $0.captureDate) }).count
        return HStack(spacing: 0) {
            stat(value: takenKeys.count, label: "撮った日")
            stat(value: postedDays, label: "今日の一枚", divider: true)
            stat(value: streak, label: "連続 · 日", divider: true)
        }
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(card))
        .padding(.horizontal, 24)
    }

    private func stat(value: Int, label: String, divider: Bool = false) -> some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(ShelfFont.serifItalic(30))
                .foregroundStyle(palette.ink)
            Text(label)
                .font(ShelfFont.mono(9.5))
                .tracking(1.1)
                .foregroundStyle(palette.dim)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .leading) {
            if divider { palette.line.frame(width: 1).padding(.vertical, 4) }
        }
    }

    // MARK: 下の一行

    private var footer: some View {
        HStack {
            (Text("写真は撮ってから ") + Text("7日").foregroundColor(palette.sub) + Text(" で消えます"))
            Spacer()
            Text(activeDay.map { Self.footerFormatter.string(from: $0.date) } ?? "")
        }
        .font(ShelfFont.mono(10.5))
        .tracking(0.6)
        .foregroundStyle(palette.dim)
        .padding(.horizontal, 24)
    }

    private static let footerFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM.dd"
        return formatter
    }()

    // MARK: 現像

    /// 選んだ日の写真を、暗い中から色づかせ直す
    private func replayDevelop() {
        developStart = Date()
    }
}

/// 名前の下の、手描きふうの線(ゆるく波うつ1本)
private struct ShelfScribble: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 2, y: rect.midY + 1))
        path.addCurve(
            to: CGPoint(x: rect.maxX - 2, y: rect.midY - 1),
            control1: CGPoint(x: rect.width * 0.3, y: rect.minY),
            control2: CGPoint(x: rect.width * 0.65, y: rect.maxY)
        )
        return path
    }
}

/// 押したときに少し縮む(すぐ戻る)
struct ShelfPressStyle: ButtonStyle {
    var scale: CGFloat = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// v51:自分の QR(ともだち追加と同じ、FriendRules.link を そのまま使う)
struct ProfileSelfQRSheet: View {
    let name: String
    let recordName: String?

    var body: some View {
        VStack(spacing: 20) {
            Capsule().fill(.white.opacity(0.25)).frame(width: 36, height: 5).padding(.top, 10)
            Text(name).font(.system(size: 18, weight: .heavy)).foregroundStyle(.white)
            if let recordName, let qr = QRImage.make(FriendRules.shareLink(recordName: recordName).absoluteString) {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 220, height: 220)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white))
            } else {
                Text("QR を作れませんでした").foregroundStyle(.white.opacity(0.6))
            }
            Text("この QR を 読みとると、ともだちに なれます").font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.55))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black.ignoresSafeArea())
        .presentationDetents([.medium])
    }
}
