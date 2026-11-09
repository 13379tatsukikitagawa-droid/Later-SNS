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
        UIFont(name: "Inter-Black", size: size) != nil
            ? .custom("Inter-Black", fixedSize: size)
            : .system(size: size, weight: .heavy, design: .rounded)
    }

    /// 小さな「you」と数字:Instrument Serif の斜体
    static func serifItalic(_ size: CGFloat) -> Font {
        UIFont(name: "InstrumentSerif-Italic", size: size) != nil
            ? .custom("InstrumentSerif-Italic", fixedSize: size)
            : .system(size: size, design: .serif).italic()
    }

    static func mono(_ size: CGFloat, bold: Bool = false) -> Font {
        let name = bold ? "SpaceMono-Bold" : "SpaceMono-Regular"
        return UIFont(name: name, size: size) != nil
            ? .custom(name, fixedSize: size)
            : .system(size: size, weight: bold ? .bold : .regular, design: .monospaced)
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

    private static let frameWidth: CGFloat = 92
    private static let frameSpacing: CGFloat = 10
    private static let stripInset: CGFloat = 16

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
    /// フィルムの穴
    private var perfColor: Color { night ? Color(hex: "34343A") : Color(hex: "D1D1D6") }

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

    private var personaText: String {
        guard let id = profile?.id else { return "PERSONA · —" }
        return "PERSONA · " + ProfilePersonaName.name(for: id)
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
    }

    private var shelf: some View {
        GeometryReader { proxy in
            let points = self.points
            let taken = takenKeys
            let safeTop = proxy.safeAreaInsets.top
            let safeBottom = proxy.safeAreaInsets.bottom
            let fullHeight = proxy.size.height + safeTop + safeBottom
            // 画面が低いとき(SE など)は、チェキの領域だけを縮めて、すべての部品を入れる
            let fixedBelow: CGFloat = 8 + 44 + 16 + 84 + 48 + 84 + 120 + 26 + 14
            let heroHeight = min(330, max(170, fullHeight - safeTop - max(safeBottom, 10) - fixedBelow))
            let heroScale = heroHeight / 330
            let isLocked = activeDay?.isToday == true && !taken.contains(todayKey)

            ZStack(alignment: .top) {
                background

                VStack(spacing: 0) {
                    topButtons
                        .padding(.top, safeTop + 8)

                    hero(points: points, taken: taken, isLocked: isLocked, width: proxy.size.width)
                        .scaleEffect(heroScale, anchor: .top)
                        .frame(height: heroHeight, alignment: .top)

                    caption
                        .padding(.top, 2)

                    who
                        .padding(.top, 6)

                    tagRow
                        .padding(.top, 14)

                    stats
                        .padding(.top, 14)

                    Spacer(minLength: 0)

                    filmStrip(points: points, taken: taken, width: proxy.size.width)

                    footer
                        .padding(.top, 12)
                        .padding(.bottom, max(safeBottom, 10) + 4)
                }
            }
            .frame(width: proxy.size.width, height: fullHeight)
            .ignoresSafeArea()
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
                    onEdit: { openSheet(.edit) },
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

    private var topButtons: some View {
        HStack {
            glassButton(systemName: "chevron.left", label: "戻る") { onBack?() }
            Spacer()
            glassButton(systemName: "gearshape.fill", label: "設定") { openSheet(.settings) }
        }
        .padding(.horizontal, 20)
        .frame(height: 44)
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

    // MARK: 主役:チェキと落書き

    private func hero(points: [String: WeekDayPoint], taken: Set<String>, isLocked: Bool, width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            if !night { doodles(locked: isLocked, width: width) }
            if let day = activeDay {
                if let point = points[day.key], !day.isGone {
                    chekiView(day: day, point: point)
                        .id(day.key)
                } else if day.isToday && !taken.contains(day.key) {
                    emptyFrame(
                        title: "今日の1枚を、\nまだ撮っていません",
                        note: "長押しで撮ると、ここで\n現像が始まります",
                        showsShoot: true
                    )
                } else if day.isGone {
                    emptyFrame(title: "この写真は\n消えました", note: "写真は撮ってから\n7日で消えます")
                } else if taken.contains(day.key) {
                    emptyFrame(title: "この写真は、\nここには出ません", note: "写真は撮ってから\n7日で消えます")
                } else {
                    emptyFrame(title: "この日は\n撮っていません", note: "写真は撮ってから\n7日で消えます")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 330, alignment: .top)
    }

    /// チェキのまわりの落書き(昼だけ。チェキと重ならない位置)。3.2秒でゆっくり上下(±3pt・±6°)。
    /// 今日がまだ撮れていないとき(ロック中)は、濃さ 50%。
    private func doodles(locked: Bool, width: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: calm)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = calm ? 0 : sin(t / 3.2 * 2 * .pi)   // -1 → 1
            ZStack(alignment: .topLeading) {
                doodle(.star, size: 34, x: 24, y: 40, rotation: -12, phase: phase)
                doodle(.wave, size: 46, x: width - 58, y: 74, rotation: 18, phase: phase)
                doodle(.dots, size: 26, x: 26, y: 262, rotation: 0, phase: phase)
                doodle(.flower, size: 30, x: width - 62, y: 262, rotation: 10, phase: phase)
            }
            .frame(width: width, height: 330, alignment: .topLeading)
        }
        .frame(width: width, height: 330)
        .opacity(locked ? 0.5 : 1)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func doodle(_ kind: ChicDoodleKind, size: CGFloat, x: CGFloat, y: CGFloat, rotation: Double, phase: Double) -> some View {
        ChicDoodle(kind: kind, width: size)
            .rotationEffect(.degrees(rotation + 6 * phase))
            .offset(x: x, y: y - 3 * phase)
    }

    private func chekiView(day: ProfileShelfDay, point: WeekDayPoint) -> some View {
        TimelineView(.animation(paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            // 7秒の往復:-2.2° ↔ -1.4°、6pt 上下(視差効果を減らすときは止める)
            let p = calm ? 0 : (1 - cos(t * 2 * .pi / 7)) / 2
            // 暗い・色がない・ぼかした状態から、2.6秒かけて色づく(視差効果を減らすときは、すぐ色を出す)
            let linear = calm ? 1 : min(1, max(0, context.date.timeIntervalSince(developStart) / 2.6))
            let develop = 1 - pow(1 - linear, 3)
            cheki(day: day, point: point, develop: point.opened ? develop : 1)
                .rotationEffect(.degrees(-2.2 + 0.8 * p))
                .offset(y: -6 * p)
        }
        .padding(.top, 14)
        // 仕上がる前は、押しても中は開かない(短く知らせるだけ)
        .onTapGesture {
            guard !point.opened else { return }
            LayerHaptics.softDouble()
            showToast(OwnReveal.status(takenAt: point.date, now: Date()).lockedText.map { $0.hasPrefix("あと") ? "今日 \($0) 撮ると、ひらきます" : PhotoDevelop.lockedNote } ?? PhotoDevelop.lockedNote)
        }
    }

    private func cheki(day: ProfileShelfDay, point: WeekDayPoint, develop: Double) -> some View {
        let width: CGFloat = 214
        let photoWidth = width - 20
        let photoHeight = photoWidth * 4 / 3
        return VStack(spacing: 0) {
            photoView(day: day, point: point, develop: develop)
                .frame(width: photoWidth, height: photoHeight)
                .overlay(alignment: .bottomTrailing) {
                    // 日付スタンプ(オレンジ・Space Mono Bold 12pt・光)
                    Text(ProfileShot.filmStamp(for: point.date))
                        .font(ShelfFont.mono(12, bold: true))
                        .foregroundStyle(palette.stamp)
                        .shadow(color: palette.stamp.opacity(0.8), radius: 4)
                        .padding(.trailing, 9)
                        .padding(.bottom, 8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                .padding(.top, 10)
                .padding(.horizontal, 10)

            HStack {
                Text(point.tags.first.map { "#\($0)" } ?? "")
                    .font(.system(size: 19, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 6)
                Text("PRINT")
                    .font(ShelfFont.mono(10))
                    .foregroundStyle(Color(hex: "7A726A"))
            }
            .foregroundStyle(Color(hex: "2A2A2E"))
            .padding(.horizontal, 14)
            .frame(height: 42)
        }
        .frame(width: width)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(palette.paper))
        .overlay(alignment: .top) { tape.offset(y: -14) }
        // 紙の影:昼はうすい茶色(Home と同じ)、夜はもっと深く
        .shadow(color: night ? .black.opacity(0.6) : ChicColor.instaxShadow.opacity(0.38), radius: 20, x: 0, y: 30)
        .shadow(color: .black.opacity(night ? 0.4 : 0.12), radius: 10, x: 0, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.isToday ? "今日" : "\(day.dayNumber)日")の1枚")
    }

    /// 上のマスキングテープ(黄色のしま・96×28pt・+4°。Home と同じ色)
    private var tape: some View {
        HStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { index in
                (index % 2 == 0 ? ChicColor.tape : ChicColor.tapeLight)
                    .opacity(0.85)
                    .frame(width: 20)
            }
        }
        .frame(width: 96, height: 28)
        .clipped()
        .rotationEffect(.degrees(4))
        .opacity(0.9)
        .accessibilityHidden(true)
    }

    /// 写真(ひらいていれば本物、なければ色のグラデ)。暗い中から、2.6秒かけて色づく。
    private func photoView(day: ProfileShelfDay, point: WeekDayPoint, develop: Double) -> some View {
        let fallback = point.color ?? Color(hex: "B9B8F5")
        return Color.clear
            .overlay {
                if !point.opened {
                    // 仕上がるまで(撮ったあとの最初の 9:00 まで)は、自分にも見せない
                    DevelopingFrame()
                } else if let image = fullImage(for: day, point: point) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [fallback.opacity(0.55), fallback, fallback.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                }
            }
            .colorMultiply(Color(white: 0.25 + 0.75 * develop))
            .saturation(0.2 + 0.8 * develop)
            .blur(radius: 2 * (1 - develop))
            .background(Color(hex: "222222"))
    }

    /// 7日をすぎた日は、写真を読みこまない。
    private func fullImage(for day: ProfileShelfDay, point: WeekDayPoint) -> UIImage? {
        // 仕上がる前の写真は、読みこまない(今日の分も例外にしない)
        guard !day.isGone, point.opened, point.showsPhoto else { return nil }
        let data = profile?.photos.first(where: { ExposureDayStore.dayKey(for: $0.captureDate) == day.key })?.imageData
        return ProfileFilmImages.image(key: "full_\(day.key)", data: data)
    }

    /// 点線の枠(今日がまだ・消えた日・撮っていない日)。角丸 22pt、左右 62pt(落書きとぶつからない幅)。
    private func emptyFrame(title: String, note: String, showsShoot: Bool = false) -> some View {
        VStack(spacing: 14) {
            Text(title)
                .font(.system(size: 20, weight: .heavy))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .foregroundStyle(palette.ink)
            Text(note)
                .font(ShelfFont.mono(10.5))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .foregroundStyle(palette.dim)
            if showsShoot {
                // 黒い丸薬(夜は白い丸薬)。Home の「つくる」ボタンと同じ
                Button {
                    onShoot?()
                } label: {
                    Text("撮る")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(palette.bg)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(palette.ink))
                }
                .buttonStyle(ShelfPressStyle(scale: 0.96))
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(night ? Color.white.opacity(0.26) : Color.black.opacity(0.22),
                              style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        )
        .padding(.horizontal, 62)
        .padding(.top, 30)
    }

    // MARK: 小さな文字・名前・タグ・数字

    private var caption: some View {
        Text(activeDay?.isToday == false ? "— 現像された日 —" : "— いま、現像中 —")
            .font(ShelfFont.mono(10))
            .tracking(2)
            .foregroundStyle(palette.dim)
    }

    /// 名前:Inter Black 44pt・字間 -5%。右上に小さな `you`(Instrument Serif の斜体 18pt)。下にオレンジの手描きの線。
    private var who: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 4) {
                    Text(displayName)
                        .font(ShelfFont.black(44))
                        .tracking(-0.05 * 44)
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("you")
                        .font(ShelfFont.serifItalic(18))
                        .foregroundStyle(palette.sub)
                        .padding(.top, 2)
                        .accessibilityHidden(true)
                }
                .fixedSize(horizontal: false, vertical: true)
                ShelfScribble()
                    .stroke(emberFill, style: StrokeStyle(lineWidth: 3.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 118, height: 8)
                    .accessibilityHidden(true)
                Text(personaText.uppercased())
                    .font(ShelfFont.mono(10.5))
                    .tracking(1.4)
                    .foregroundStyle(palette.sub)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 12)
            glassButton(systemName: "pencil", label: "編集") { openSheet(.edit) }
        }
        .padding(.horizontal, 24)
    }

    private var tagRow: some View {
        let tags = profile?.selfTags ?? []
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                    // タップで、その言葉の日を探す(今は仮:トーストだけ)
                    Button {
                        haptics.play(.light)
                        showToast("#\(tag) の日を探す(仮)")
                    } label: {
                        Text("#\(tag)")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(index == 0 ? emberText : palette.ink)
                            .padding(.horizontal, 13)
                            .frame(height: 34)
                            .background(Capsule().fill(card))
                    }
                    .buttonStyle(ShelfPressStyle(scale: 0.94))
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(height: 34)
        .opacity(tags.isEmpty ? 0 : 1)
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

    // MARK: フィルムの帯

    /// 角丸 26pt の `card` の面の中に入れる(左右 16pt の余白)
    private func filmStrip(points: [String: WeekDayPoint], taken: Set<String>, width: CGFloat) -> some View {
        let stripWidth = width - Self.stripInset * 2
        let margin = max(0, (stripWidth - Self.frameWidth) / 2)
        return ZStack {
            VStack {
                perforations(width: stripWidth)
                Spacer()
                perforations(width: stripWidth)
            }
            .padding(.vertical, 8)
            .allowsHitTesting(false)

            ScrollView(.horizontal, showsIndicators: false) {
                // 見えている分だけ描く(31コマぜんぶを一度に作らない)
                LazyHStack(spacing: Self.frameSpacing) {
                    ForEach(days) { day in
                        frameView(day: day, point: points[day.key], isTaken: taken.contains(day.key))
                            .id(day.key)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, margin, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $selectedKey, anchor: .center)
            .padding(.vertical, 22)
        }
        .frame(width: stripWidth, height: 120)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(card))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .frame(maxWidth: .infinity)
    }

    private func perforations(width: CGFloat) -> some View {
        HStack(spacing: 14) {
            ForEach(0..<Int(width / 24) + 1, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2).fill(perfColor).frame(width: 10, height: 6)
            }
        }
        .padding(.leading, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 8)
        .clipped()
    }

    private func frameView(day: ProfileShelfDay, point: WeekDayPoint?, isTaken: Bool) -> some View {
        let isSelected = day.key == activeKey
        return Button {
            withAnimation(.easeInOut(duration: calm ? 0.01 : 0.3)) { selectedKey = day.key }
        } label: {
            ZStack(alignment: .topLeading) {
                // コマ:昼は白、夜は暗い面
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(night ? Color.white.opacity(0.06) : palette.bg)

                if let thumb = thumbnail(for: day, point: point) {
                    Image(uiImage: thumb)
                        .resizable().scaledToFill()
                        .frame(width: Self.frameWidth - 16, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .padding(.leading, 8).padding(.top, 18)
                } else if point != nil, point?.opened == false, !day.isGone {
                    // まだひらいていない今日の1枚:暗い面(現像中)
                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: "222222"))
                        .frame(width: Self.frameWidth - 16, height: 36)
                        .padding(.leading, 8).padding(.top, 18)
                } else if let color = point?.color, !day.isGone {
                    RoundedRectangle(cornerRadius: 3).fill(color)
                        .frame(width: Self.frameWidth - 16, height: 36)
                        .padding(.leading, 8).padding(.top, 18)
                }

                Text(day.label)
                    .font(ShelfFont.mono(8.5))
                    .foregroundStyle(isSelected ? emberText : palette.dim)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 5).padding(.trailing, 8)

                Text("\(day.dayNumber)")
                    .font(ShelfFont.mono(11, bold: isSelected))
                    .foregroundStyle(isSelected ? emberText : palette.dim)
                    .frame(maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 8).padding(.bottom, 6)
            }
            .frame(width: Self.frameWidth, height: 76)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isSelected ? emberFill : palette.line,
                        style: isSelected ? StrokeStyle(lineWidth: 1.5) : StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
            // 選んだコマ:オレンジの枠 + やわらかい光(外側の薄い輪と、下の影)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(emberFill.opacity(0.14))
                        .padding(-3)
                        .shadow(color: emberFill.opacity(0.35), radius: 8, y: 4)
                }
            }
            .scaleEffect(isSelected ? 1.04 : 1)
            .opacity(day.isGone ? 0.45 : 1)
            .animation(calm ? nil : .easeInOut(duration: 0.35), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.dayNumber)日、\(day.label)\(isTaken ? "、撮った日" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 7日をすぎたコマは、写真を読みこまない。
    private func thumbnail(for day: ProfileShelfDay, point: WeekDayPoint?) -> UIImage? {
        guard !day.isGone, point?.opened == true else { return nil }
        let data = exposureDays.first(where: { $0.dayKey == day.key })?.thumbnailData
        return ProfileFilmImages.image(key: "thumb_\(day.key)", data: data)
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
