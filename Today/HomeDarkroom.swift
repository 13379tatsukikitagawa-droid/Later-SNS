import SwiftData
import SwiftUI
import UIKit

// v28 / v29 Once × Later:Home の 下 =「暗室」(2日目から)。見本:later_v29.html
// 地球の 下から 夕暮れで 暗くなり(今日の 現像カード)、暗室に 入る:
//   ACTIVE(グループ・招待・New group)→ YESTERDAY(ヒーロー + 2列の タイル)→ MONDO → ALBUMS(7日)→ FRIENDS → SEE YOU AT 9:00
// 見た目だけ。保存・解禁・投稿・グループ・招待の 処理には ふれない(★ は MEPickStore、入る は 今の 招待の 流れ)。

// MARK: - トークン

enum Darkroom {
    static let bg = Color(hex: "0A0A0B")
    static let card = Color(hex: "161618")
    static let card2 = Color(hex: "232326")
    static let line = Color(hex: "1E1E21")
    static let weak = Color(hex: "8C8C93")
    static let faint = Color(hex: "55555B")
    /// v42:フジの緑(主役の色。もとは オレンジ #FF6A1A だった場所ぜんぶ)
    static let orange = Color(hex: "24A03C")
    static let paleGreen = Color(hex: "9ED6A5")
    /// 例外:チェキの 日付スタンプ と 7セグの 時刻 だけ(v42で オレンジの まま のこす)
    static let stamp = Color(hex: "E0481A")
    static let star = Color(hex: "FFD60A")

    /// 見出し:英字は Instrument Serif、日本語が 入れば ヒラギノ明朝 W6
    static func title(_ text: String, size: CGFloat) -> Font {
        let japanese = text.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value) }
        return japanese ? Typo.mincho(size * 0.82) : .custom("InstrumentSerif-Regular", size: size)
    }

    /// 数字・名前:Instrument Serif イタリック(日本語は 明朝)
    static func italic(_ text: String, size: CGFloat) -> Font {
        let japanese = text.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value) }
        return japanese ? Typo.mincho(size * 0.8) : .custom("InstrumentSerif-Italic", size: size)
    }

    /// ラベル(大文字・字間 広め)
    static func mono(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .monospaced) }

    /// タグの ステッカーの 色(名前から)
    static func stickerColors(_ tag: String) -> (Color, Color) {
        let table: [(String, String)] = [("EE5E9C", "FFFFFF"), ("C8F25A", "111111"), ("9ED8FF", "111111"), ("FFD60A", "111111"), ("9B8CFF", "FFFFFF")]
        let hash = tag.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
        let pair = table[hash % table.count]
        return (Color(hex: pair.0), Color(hex: pair.1))
    }

    /// 「Nov 10」(英語の 月。どちらの 言語でも 同じ 形)
    static func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    static func weekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    /// 「09:12」
    static func time(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    /// 「15h 24m」
    static func span(_ seconds: TimeInterval) -> String {
        let m = max(0, Int(seconds / 60))
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }
}

// MARK: - Liquid Glass(iOS 26)。v36/v37:ナビ・ヒーローの 四角いボタン・ロックのピル。
// iOS 26 未満は ultraThinMaterial + 上のふちに 白い線で 代用

extension View {
    @ViewBuilder func laterGlass<S: InsettableShape>(_ shape: S, interactive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .clear], startPoint: .top, endPoint: .center), lineWidth: 1))
        }
    }
}

// MARK: - データ(今の データから 組みたてる)

struct DarkroomPhoto: Identifiable, Equatable {
    let id: String
    let photo: LaterPhoto
    let name: String
    let isMine: Bool
    /// 見られない(今日 まだ 撮っていない・自分の まだ ひらいて いない こま)
    let locked: Bool
    let lockedText: String
    let tag: String?
    /// 自分の こま:★ に 使う 日と こまの id
    let dayKey: String?
    let shotID: String?
    let groupID: UUID?

    static func == (a: DarkroomPhoto, b: DarkroomPhoto) -> Bool { a.id == b.id && a.locked == b.locked }
}

struct DarkroomData {
    var todayShots: [(date: Date, photo: LaterPhoto?)] = []
    var yesterdayDate = Date()
    var hero: DarkroomPhoto?
    var tiles: [DarkroomPhoto] = []
    var moments = 0
    var people = 0
    var daysLeft = 6
    var albums: [(day: MEDay, others: [LaterPhoto])] = []
    /// 自分の 写真(ALBUMS の こまを さがす)
    var mine: [LaterPhoto] = []

    @MainActor
    static func make(me: UserProfile?, groups: [LaterGroup], blocked: Set<String>, now: Date, calendar: Calendar = .current) -> DarkroomData {
        var data = DarkroomData()
        let mine = me?.photos ?? []
        data.mine = mine
        let days = MERules.days(photos: mine, now: now, calendar: calendar)
        let myID = CloudKitManager.current?.currentUserRecordName
        let locked = FilmCounter.shared.used == 0
        if let today = days.first(where: { $0.ago == 0 }) {
            data.todayShots = today.shots.map { shot in (shot.takenAt, mine.first { $0.id == shot.photoID }) }
        }
        // きのう(グループに 投稿された 写真)
        let window = DailyWindow.yesterday(for: now, calendar: calendar)
        data.yesterdayDate = window.open
        var seen = Set<String>()
        var authors = Set<String>()
        var friends: [DarkroomPhoto] = []
        for group in groups {
            for photo in group.photos where photo.isPosted && photo.captureDate >= window.open && photo.captureDate < window.close {
                let author = photo.authorCloudKitUserRecordName ?? ""
                guard !blocked.contains(author), seen.insert(photo.dedupeKey).inserted else { continue }
                authors.insert(author.isEmpty ? photo.dedupeKey : author)
                guard author != myID, !photo.imageData.isEmpty else { continue }
                let name = group.members.first { $0.cloudKitUserRecordName == author }?.name ?? String(localized: "darkroom.someone")
                friends.append(DarkroomPhoto(id: "f-\(photo.dedupeKey)", photo: photo, name: name, isMine: false, locked: locked,
                                             lockedText: String(localized: "darkroom.locked.shootToday"), tag: photo.tags.first,
                                             dayKey: nil, shotID: nil, groupID: group.id))
            }
        }
        data.moments = seen.count
        data.people = authors.count
        data.daysLeft = max(1, MERules.days - 1)
        // 自分の きのう(撮った 数だけ 古い 順に ひらく)
        var own: [DarkroomPhoto] = []
        if let day = days.first(where: { $0.ago == 1 }) {
            for shot in day.shots {
                guard let photo = mine.first(where: { $0.id == shot.photoID }) else { continue }
                own.append(DarkroomPhoto(id: "o-\(shot.id)", photo: photo, name: "you", isMine: true, locked: !shot.reveal.isOpen,
                                         lockedText: String(localized: "darkroom.locked.oneMore"), tag: photo.tags.first,
                                         dayKey: day.key, shotID: shot.id, groupID: photo.groupID))
            }
        }
        // ともだち と 自分 を かわりばんこに
        var tiles: [DarkroomPhoto] = []
        for i in 0..<max(friends.count, own.count) {
            if i < friends.count { tiles.append(friends[i]) }
            if i < own.count { tiles.append(own[i]) }
        }
        data.tiles = tiles
        // ヒーロー:★ に した 自分の 1枚 → ともだちの 1枚 → 自分の ひらいた 1枚
        let keptID = own.first.flatMap { $0.dayKey }.flatMap { MEPickStore.pick(day: $0) }
        data.hero = own.first { $0.shotID == keptID && !$0.locked } ?? friends.first ?? own.first { !$0.locked } ?? own.first
        // 7日(きのう → 6日前)と、その日の ほかの 人の 写真
        for ago in 1..<MERules.days {
            guard let day = days.first(where: { $0.ago == ago }) else { continue }
            let others = groups.flatMap { $0.photos }
                .filter { $0.isPosted && $0.authorCloudKitUserRecordName != myID && ExposureDayStore.dayKey(for: $0.captureDate, calendar: calendar) == day.key }
                .filter { !blocked.contains($0.authorCloudKitUserRecordName ?? "") }
            var keys = Set<String>()
            data.albums.append((day, others.filter { keys.insert($0.dedupeKey).inserted }))
        }
        return data
    }
}

/// 写真の 小さな 画像(今の 画像キャッシュ。ぼかしは 小さい 画像に かける)
struct DarkThumb: View {
    let photo: LaterPhoto
    var maxPixel = 600
    var blur: CGFloat = 0

    @State private var image: UIImage?

    var body: some View {
        Darkroom.card
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .blur(radius: blur)
                        .scaleEffect(blur > 0 ? 1.12 : 1)
                }
            }
            .clipped()
            .task(id: photo.id) {
                let key = "dark-\(photo.id.uuidString)-\(blur > 0 ? 180 : maxPixel)"
                if let hit = MEImageLoader.cached(key) { image = hit; return }
                let data = photo.imageData
                guard !data.isEmpty else { return }
                // ぼかす ときは 小さい サムネイルで(軽く)
                image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                    MEImageLoader.downscale(data, maxPixel: blur > 0 ? 180 : maxPixel).map { UIImage(cgImage: $0) }
                }.value
            }
    }
}

/// ミルク色(まだ 見えない):強く ぼかす + うすい 白緑の 膜 + 黒い 丸の カギ
private struct MilkLock: View {
    var showsLock = true

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.92, green: 0.95, blue: 0.93).opacity(0.36), Color(red: 0.86, green: 0.9, blue: 0.9).opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
            if showsLock {
                Image(systemName: "lock.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color(hex: "0A0A0B").opacity(0.75)))
            }
        }
    }
}

/// 区切り線の 上の ラベル
/// 区切り線の 上の ラベル(Home の 暗室・Later yesterday の Mondo で 共通)
struct DarkLabel: View {
    let text: String
    var trailing: String?
    var doodle: Bool = false
    /// trailing を 押せる ボタンに する(例:「ALL ×」)
    var onTrailingTap: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: text).font(Darkroom.mono(10.5)).tracking(0.24 * 10.5).foregroundStyle(Darkroom.weak)
            if doodle {
                ChicDoodle(kind: .wave, width: 34).padding(.leading, 6).offset(y: 3)
            }
            Spacer()
            if let trailing {
                if let onTrailingTap {
                    Button(action: onTrailingTap) {
                        Text(verbatim: trailing).font(Darkroom.mono(10.5)).tracking(0.14 * 10.5).foregroundStyle(Darkroom.orange)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(verbatim: trailing).font(Darkroom.mono(10.5)).tracking(0.14 * 10.5).foregroundStyle(Darkroom.faint)
                }
            }
        }
        .padding(.top, 14)
        .overlay(alignment: .top) { Rectangle().fill(Darkroom.line).frame(height: 1) }
        .padding(.horizontal, 18)
        .padding(.top, 30)
        .padding(.bottom, 12)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - 夕暮れ + 今日の 現像カード

struct DuskTodaySection: View {
    let shots: [(date: Date, photo: LaterPhoto?)]
    let now: Date
    let night: Bool
    let onShoot: () -> Void
    let onOpenDevelop: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TodayDevelopCard(shots: shots, now: now, onShoot: onShoot, onOpenDevelop: onOpenDevelop)
            .padding(.horizontal, 14)
            .padding(.top, 118)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
            .background { backdrop }
            .overlay(alignment: .top) { FloatingDoodles(reduceMotion: reduceMotion) }
    }

    /// 透明 → #FFF1E8 → … → 暗室。右に オレンジ、左に うすい 紫の にじみ(夜は 黒の まま)
    @ViewBuilder
    private var backdrop: some View {
        if night {
            Darkroom.bg
        } else {
            ZStack {
                LinearGradient(stops: [
                    .init(color: Color.white.opacity(0), location: 0),
                    .init(color: Color(hex: "FFF1E8"), location: 0.12),
                    .init(color: Color(hex: "FFD9C9"), location: 0.24),
                    .init(color: Color(hex: "F3A9B8"), location: 0.38),
                    .init(color: Color(hex: "8E5A86"), location: 0.54),
                    .init(color: Color(hex: "3A2436"), location: 0.68),
                    .init(color: Color(hex: "161015"), location: 0.82),
                    .init(color: Darkroom.bg, location: 1),
                ], startPoint: .top, endPoint: .bottom)
                GeometryReader { proxy in
                    ZStack {
                        Ellipse().fill(Color(red: 1, green: 0.59, blue: 0.31).opacity(0.35)).frame(width: 260, height: 120).blur(radius: 40)
                            .position(x: proxy.size.width * 0.78, y: proxy.size.height * 0.46)
                        Ellipse().fill(Color(red: 0.61, green: 0.55, blue: 1).opacity(0.25)).frame(width: 220, height: 140).blur(radius: 40)
                            .position(x: proxy.size.width * 0.14, y: proxy.size.height * 0.6)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

/// 夕暮れの 中の 落書き(星・花)。ゆっくり 浮く
private struct FloatingDoodles: View {
    let reduceMotion: Bool
    @State private var up = false

    var body: some View {
        ZStack(alignment: .top) {
            ChicDoodle(kind: .star, width: 30).offset(y: up ? -6 : 0)
                .frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 34).padding(.top, 78)
            ChicDoodle(kind: .flower, width: 30).offset(y: up ? 0 : -6)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 30).padding(.top, 64)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { up = true }
        }
    }
}

/// 黒い すりガラスの カード:Today 1/3・DEVELOPING・3つの こま・進み線
struct TodayDevelopCard: View {
    let shots: [(date: Date, photo: LaterPhoto?)]
    let now: Date
    let onShoot: () -> Void
    let onOpenDevelop: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounce = 0
    @State private var pulse = false
    private var landing: FilmLanding { FilmLanding.shared }
    private var used: Int { max(shots.count, FilmCounter.shared.used) }

    /// 現像の 進み(撮った 時刻 → つぎの 9:00)
    static func progress(shot: Date, now: Date) -> Double {
        let open = PhotoDevelop.developDate(takenAt: shot)
        let total = open.timeIntervalSince(shot)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(shot) / total))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text(verbatim: "Today").font(Darkroom.title("Today", size: 34))
                Spacer()
                (Text(verbatim: "\(used)").font(.custom("InstrumentSerif-Italic", size: 30))
                 + Text(verbatim: "/3").font(.custom("InstrumentSerif-Italic", size: 20)).foregroundColor(Color(hex: "6E6E75")))
            }
            HStack(spacing: 7) {
                Circle().fill(Darkroom.orange).frame(width: 6, height: 6)
                    .shadow(color: Darkroom.orange, radius: 4)
                    .background(Circle().fill(Darkroom.orange.opacity(0.4)).scaleEffect(pulse ? 2.6 : 1).opacity(pulse ? 0 : 1))
                Text(verbatim: "\(used > 0 ? "DEVELOPING" : "EMPTY FILM") · \(Darkroom.dayLabel(now).uppercased())")
                    .font(Darkroom.mono(10)).tracking(0.2 * 10).foregroundStyle(Darkroom.weak)
            }
            .padding(.top, 6)
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { i in frame(i) }
            }
            .padding(.top, 16)
            progressLine.padding(.top, 16)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color(red: 0.07, green: 0.06, blue: 0.08).opacity(0.86))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        )
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(.white.opacity(0.07), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 30, y: 24)
        .environment(\.colorScheme, .dark)
        .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .onTapGesture {
            Haptics.play(.pop)
            used == 0 ? onShoot() : onOpenDevelop()
        }
        .keyframeAnimator(initialValue: 1.0, trigger: bounce) { content, s in content.scaleEffect(s) } keyframes: { _ in
            KeyframeTrack { CubicKeyframe(1.03, duration: 0.12); SpringKeyframe(1, duration: 0.3) }
        }
        .onChange(of: landing.landedToken) { _, _ in bounce += 1 }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: String(localized: "darkroom.today.a11y"), used))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func frame(_ i: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Group {
            if i < shots.count {
                let p = Self.progress(shot: shots[i].date, now: now)
                ZStack(alignment: .topTrailing) {
                    // v30:現像ビューと 同じ 式(DevelopLook)の 小さい 版
                    DevelopFilmPhoto(photo: shots[i].photo, progress: p, blurScale: 0.5, shineDelay: Double(i) * 0.5, shinePeriod: 3.4)
                    Text(verbatim: "\(Int((p * 100).rounded()))%").font(.custom("InstrumentSerif-Italic", size: 17)).foregroundStyle(Color(hex: "3A362F"))
                        .padding(.trailing, 9).padding(.top, 7)
                }
                .overlay(alignment: .bottomLeading) {
                    Text(verbatim: Darkroom.time(shots[i].date)).font(Darkroom.mono(9)).tracking(0.04 * 9).foregroundStyle(Color(hex: "E0481A"))
                        .padding(.leading, 9).padding(.bottom, 8)
                }
                .onTapGesture {
                    Haptics.play(.pop)
                    onOpenDevelop()
                }
            } else if i == shots.count {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])).padding(7)
                    VStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 20, weight: .bold))
                        Text(verbatim: "SHOOT").font(Darkroom.mono(9.5)).tracking(0.16 * 9.5).foregroundStyle(Darkroom.weak)
                    }
                }
                .overlay(shape.strokeBorder(.white.opacity(0.22), lineWidth: 1.5))
                .contentShape(shape)
                .onTapGesture {
                    Haptics.play(.pop)
                    onShoot()
                }
            } else {
                shape.strokeBorder(.white.opacity(0.08), lineWidth: 1.5)
            }
        }
        .aspectRatio(0.8, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(shape)
        // 撮った チェキが とんでくる 先(この こま)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rect in landing.slotFrames[i] = rect }
    }

    private var progressLine: some View {
        let first = shots.first?.date
        let p = first.map { Self.progress(shot: $0, now: now) } ?? 0
        let lightsOut = DailyExposureRules.window(for: now).close
        return VStack(spacing: 9) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule().fill(LinearGradient(colors: [Color(hex: "FFB27A"), Darkroom.orange], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, proxy.size.width * p))
                    Circle().fill(Darkroom.orange).frame(width: 11, height: 11)
                        .shadow(color: Darkroom.orange, radius: 6)
                        .offset(x: max(0, proxy.size.width * p - 5.5))
                }
            }
            .frame(height: 3)
            HStack {
                if let first {
                    (Text(verbatim: Darkroom.time(first)).foregroundColor(.white) + Text(verbatim: " shot"))
                } else {
                    (Text(verbatim: "9:00").foregroundColor(.white) + Text(verbatim: " start"))
                }
                Spacer()
                Text(verbatim: first != nil
                     ? "opens 9:00 · \(Darkroom.span(PhotoDevelop.developDate(takenAt: first!).timeIntervalSince(now)))"
                     : "lights out · \(Darkroom.span(lightsOut.timeIntervalSince(now)))")
                    .foregroundStyle(Darkroom.stamp)
            }
            .font(Darkroom.mono(10)).tracking(0.1 * 10).foregroundStyle(Darkroom.weak)
        }
    }
}

// MARK: - 暗室

struct DarkroomSection: View {
    let data: DarkroomData
    let groups: [LaterGroup]
    let summaries: [GroupSummary]
    let invites: [FriendInviteCard]
    let words: [WorldWordsStore.Word]
    let friends: [HomeFriend]
    let now: Date
    let onOpenChat: (UUID) -> Void
    let onCreateGroup: () -> Void
    let onJoin: (FriendInviteCard) -> Void
    let onOpenMondo: () -> Void
    /// v47:ことばのカード → そのことばで しぼって Mondo へ
    var onOpenWord: (String) -> Void = { _ in }
    let onOpenFriends: () -> Void
    let onOpenPhoto: (DarkroomPhoto) -> Void
    let onToast: (String) -> Void
    /// はじめての 合図(keep)を 出してよい
    var keepHintEligible = false
    /// v47:「People ›」→ 昨日のホームへ
    var onOpenYesterday: () -> Void = {}
    /// v54:ALBUMS の 見出し → ME 画面(別の 入口。右上の 丸は Profile)
    var onOpenMe: () -> Void = {}

    @State private var keptRefresh = 0
    private var locked: Bool { FilmCounter.shared.used == 0 }
    private var me: String? { CloudKitManager.current?.currentUserRecordName }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DarkLabel(text: "ACTIVE")
            active
            DarkLabel(text: "YESTERDAY", trailing: Darkroom.weekday(data.yesterdayDate))
            hero.padding(.horizontal, 14)
            grid.padding(.horizontal, 14).padding(.top, 9)
            DarkLabel(text: "MONDO", trailing: "TOP 5", doodle: true)
            mondo
            DarkLabel(text: "ALBUMS", trailing: "7 DAYS", onTrailingTap: onOpenMe)
            albums
            OnThisDaySection(now: now)
            FriendsClockCard(friends: friends.filter { !$0.isMe }, onOpenFriend: onOpenFriends)
                .padding(.horizontal, 14)
        }
        .foregroundStyle(.white)
        .padding(.bottom, 10)
        .background(Darkroom.bg)
        .id(keptRefresh)
    }

    // MARK: ACTIVE

    private var active: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(invites.filter { $0.status == .pending }) { card in ActiveInviteCard(card: card, onJoin: onJoin) }
                ForEach(groups) { group in
                    ActiveGroupCard(group: group, hasUnread: summaries.first { $0.id == group.id }?.chatUnread == true,
                                     locked: locked, me: me, now: now, onOpenChat: onOpenChat)
                }
                ActiveNewGroupCard(onCreateGroup: onCreateGroup)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 4)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
    }

    // MARK: YESTERDAY

    private var hero: some View {
        ZStack(alignment: .top) {
            if let photo = data.hero?.photo {
                DarkThumb(photo: photo, maxPixel: 900, blur: locked ? 18 : 0)
                    .saturation(locked ? 0.4 : 1)
            } else {
                Darkroom.card
            }
            LinearGradient(stops: [.init(color: .black.opacity(0.05), location: 0), .init(color: .clear, location: 0.3),
                                   .init(color: .black.opacity(0.45), location: 0.58), .init(color: Darkroom.bg.opacity(0.96), location: 1)],
                           startPoint: .top, endPoint: .bottom)
            if locked {
                Button {
                    Haptics.play(.tick)
                    CaptureRequestStore.shared.pendingRequestID = UUID()
                } label: {
                    Label { Text("darkroom.locked.pill") } icon: { Image(systemName: "lock.fill") }
                        .font(.system(size: 13, weight: .heavy)).foregroundStyle(Color(hex: "111111"))
                        .padding(.horizontal, 16).frame(height: 38)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(.plain)
                .padding(.top, 150)
            } else if let tag = data.hero?.tag {
                let c = Darkroom.stickerColors(tag)
                Text(verbatim: "#\(tag)").font(.system(size: 15, weight: .black)).foregroundStyle(c.1)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 12).fill(c.0))
                    .rotationEffect(.degrees(8))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 18).padding(.top, 22)
            }
            VStack(spacing: 8) {
                Text(verbatim: "Yesterday").font(Darkroom.title("Yesterday", size: 54))
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
                Text(verbatim: Darkroom.dayLabel(data.yesterdayDate).uppercased()).font(Darkroom.mono(10.5)).tracking(0.24 * 10.5).foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 206)
            stats.padding(.top, 312)
            heroButtons
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(16)
        }
        .frame(height: 452)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var stats: some View {
        HStack {
            stat(value: "\(data.moments)", label: "Moments")
            ZStack {
                stat(value: "\(data.daysLeft)d", label: "Left")
                HandCircle().stroke(Darkroom.orange, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                    .frame(width: 74, height: 50).offset(y: -12)
                    .allowsHitTesting(false)
            }
            Button {
                Haptics.play(.pop)
                onOpenYesterday()
            } label: {
                stat(value: "\(data.people)", label: "People ›")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(verbatim: value).font(.custom("InstrumentSerif-Italic", size: 31))
            Text(verbatim: label).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var heroButtons: some View {
        HStack(spacing: 8) {
            Button {
                if locked {
                    Haptics.play(.tick)
                    CaptureRequestStore.shared.pendingRequestID = UUID()
                    return
                }
                Haptics.play(.pop)
                onOpenMondo()
            } label: {
                Label { Text(verbatim: "Mondo") } icon: { Image(systemName: "globe") }
                    .font(.system(size: 15, weight: .heavy)).foregroundStyle(Color(hex: "111111"))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(SquishButtonStyle(pressedScale: 0.95))
            Button {
                Haptics.play(.pop)
                if let group = groups.first(where: { $0.members.count > 1 }) ?? groups.first { onOpenChat(group.id) } else { onCreateGroup() }
            } label: {
                Image(systemName: "bubble.left").font(.system(size: 19, weight: .bold))
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(.white.opacity(0.12)))
            }
            .buttonStyle(SquishButtonStyle(pressedScale: 0.95))
            .accessibilityLabel(String(localized: "darkroom.chat.a11y"))
        }
    }

    // 2列の タイル(高さ 212 / 236 を 交互に)
    private var grid: some View {
        let left = data.tiles.enumerated().filter { $0.offset % 2 == 0 }.map(\.element)
        let right = data.tiles.enumerated().filter { $0.offset % 2 == 1 }.map(\.element)
        return HStack(alignment: .top, spacing: 9) {
            VStack(spacing: 9) {
                ForEach(Array(left.enumerated()), id: \.element.id) { i, item in tile(item, height: i % 2 == 0 ? 212 : 236) }
            }
            VStack(spacing: 9) {
                ForEach(Array(right.enumerated()), id: \.element.id) { i, item in tile(item, height: i % 2 == 0 ? 236 : 212) }
            }
        }
    }

    private func tile(_ item: DarkroomPhoto, height: CGFloat) -> some View {
        let firstKeep = data.tiles.first { $0.isMine && !$0.locked }?.id == item.id
        return DarkTile(item: item, height: height, kept: item.shotID != nil && item.dayKey.flatMap { MEPickStore.pick(day: $0) } == item.shotID,
                 onTap: {
                     if item.locked {
                         Haptics.play(.tick)
                         CaptureRequestStore.shared.pendingRequestID = UUID()
                     } else {
                         Haptics.play(.pop)
                         onOpenPhoto(item)
                     }
                 },
                 onKeep: item.isMine && !item.locked ? { keep(item) } : nil)
            // はじめての 合図「長押しで、1年 のこす」:ひらいた 自分の 最初の 1枚
            .modifier(KeepHintOn(active: firstKeep, eligible: keepHintEligible))
    }

    private func keep(_ item: DarkroomPhoto) {
        guard let day = item.dayKey, let shot = item.shotID else { return }
        MEPickStore.set(day: day, shotID: shot, imageData: item.photo.imageData, videoURL: LaterVideoStore.localURL(for: item.photo), tags: item.tag.map { [$0] } ?? [])
        Haptics.play(.heart)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { Haptics.play(.success) }
        onToast(String(localized: "darkroom.kept.toast"))
        keptRefresh += 1
    }

    // MARK: MONDO

    private var mondo: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(Array(words.prefix(5).enumerated()), id: \.element.id) { i, word in
                    Button {
                        if locked {
                            Haptics.play(.tick)
                            CaptureRequestStore.shared.pendingRequestID = UUID()
                            return
                        }
                        Haptics.play(.pop)
                        onOpenWord(word.tag)
                    } label: {
                        ZStack(alignment: .topLeading) {
                            LinearGradient(colors: word.tones.isEmpty ? [Darkroom.card, Darkroom.card2] : word.tones.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing)
                                .saturation(locked ? 0.3 : 1)
                                .blur(radius: locked ? 9 : 0)
                            LinearGradient(stops: [.init(color: .black.opacity(0.35), location: 0), .init(color: .clear, location: 0.38), .init(color: .black.opacity(0.65), location: 1)], startPoint: .top, endPoint: .bottom)
                            Text(verbatim: String(format: "%02d", i + 1)).font(.custom("InstrumentSerif-Italic", size: 30)).padding(.leading, 12).padding(.top, 10)
                            Text(verbatim: "#\(word.tag)").font(Typo.mincho(17)).lineLimit(2)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                .padding(.leading, 12).padding(.trailing, 10).padding(.bottom, 13)
                        }
                        .frame(width: 142, height: 188)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(SquishButtonStyle(pressedScale: 0.96))
                }
                if words.isEmpty {
                    Text("darkroom.mondo.empty").font(.system(size: 13)).foregroundStyle(Darkroom.weak).frame(height: 60)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 4)
        }
    }

    // MARK: ALBUMS

    private var albums: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(Array(data.albums.enumerated()), id: \.element.day.id) { index, entry in
                albumRow(entry.day, others: entry.others).opacity(1 - Double(index) * 0.07)
            }
        }
    }

    private func albumRow(_ day: MEDay, others: [LaterPhoto]) -> some View {
        let left = MERules.days - day.ago
        let goes = left <= 1
        let kept = MEPickStore.pick(day: day.key)
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: Darkroom.dayLabel(day.date)).font(Darkroom.title("Nov", size: 25))
                if goes {
                    Circle().fill(Darkroom.orange).frame(width: 7, height: 7)
                        .background(Circle().fill(Darkroom.orange.opacity(0.18)).frame(width: 15, height: 15))
                        .padding(.leading, 6).offset(y: -5)
                }
                Spacer()
                Text(verbatim: goes ? "GOES TOMORROW" : "\(left)D LEFT · \(Darkroom.weekday(day.date))")
                    .font(Darkroom.mono(9.5)).tracking(0.14 * 9.5)
                    .foregroundStyle(left <= 2 ? Darkroom.orange : Darkroom.faint)
            }
            .padding(.horizontal, 18)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { j in
                        if j < day.shots.count {
                            albumTile(day, shot: day.shots[j], kept: kept == day.shots[j].id)
                        } else {
                            RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Darkroom.card2, lineWidth: 1.3)
                                .frame(width: 84, height: 112)
                        }
                    }
                    if let first = others.first {
                        Button {
                            Haptics.play(.pop)
                            onOpenMondo()
                        } label: {
                            DarkThumb(photo: first, maxPixel: 200, blur: 7)
                                .brightness(-0.2)
                                .overlay(Text(verbatim: "+\(others.count)").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white))
                                .frame(width: 84, height: 112)
                                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }
                        .buttonStyle(SquishButtonStyle(pressedScale: 0.95))
                    }
                }
                .padding(.horizontal, 14)
            }
        }
    }

    private func albumTile(_ day: MEDay, shot: MEShot, kept: Bool) -> some View {
        let photo = data.mine.first { $0.id == shot.photoID }
        let item = photo.map {
            DarkroomPhoto(id: "a-\(shot.id)", photo: $0, name: "you", isMine: true, locked: !shot.reveal.isOpen,
                          lockedText: String(localized: "darkroom.locked.oneMore"), tag: $0.tags.first, dayKey: day.key, shotID: shot.id, groupID: $0.groupID)
        }
        return Group {
            if let item {
                DarkTile(item: item, height: 112, width: 84, radius: 15, kept: kept, compact: true,
                         onTap: {
                             if item.locked { Haptics.play(.tick); CaptureRequestStore.shared.pendingRequestID = UUID() } else { Haptics.play(.pop); onOpenPhoto(item) }
                         },
                         onKeep: item.locked ? nil : { keep(item) })
            } else {
                RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Darkroom.card).frame(width: 84, height: 112)
            }
        }
    }

    // MARK: FRIENDS(v47:12の席の時計盤は FriendsClockCard.swift)
}

// MARK: - ACTIVE カード(Home の 暗室と、Later yesterday の ACTIVE で 共通。たてカード 196×248)

func activeCardChrome<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    ZStack(alignment: .topLeading) {
        content()
        LinearGradient(stops: [.init(color: .black.opacity(0.55), location: 0), .init(color: .clear, location: 0.46),
                               .init(color: .clear, location: 0.62), .init(color: .black.opacity(0.5), location: 1)], startPoint: .top, endPoint: .bottom)
    }
    .frame(width: 196, height: 248)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
}

/// その グループの いちばん 新しい「見られる」1枚(投稿ずみ)
func activeLatestPhoto(of group: LaterGroup) -> LaterPhoto? {
    group.photos.filter { $0.isPosted && !$0.imageData.isEmpty }.max { $0.captureDate < $1.captureDate }
}

struct ActiveInviteCard: View {
    let card: FriendInviteCard
    let onJoin: (FriendInviteCard) -> Void

    var body: some View {
        Button {
            Haptics.play(.success)
            onJoin(card)
        } label: {
            ZStack(alignment: .topLeading) {
                activeCardChrome { Darkroom.card }
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: card.groupName).font(Darkroom.title(card.groupName, size: 28)).lineLimit(2)
                    Label { Text(verbatim: "from \(card.fromName)") } icon: { Image(systemName: "clock") }
                        .font(.system(size: 12.5, weight: .medium)).foregroundStyle(.white.opacity(0.88))
                }
                .padding(16)
                Text(verbatim: "join").font(.system(size: 12.5, weight: .bold))
                    .padding(.horizontal, 16).frame(height: 36)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Darkroom.orange))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 14)
            }
            .frame(width: 196, height: 248)
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Darkroom.orange, lineWidth: 2))
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
        .accessibilityLabel("\(card.groupName)。\(card.fromName)。join")
    }
}

struct ActiveGroupCard: View {
    let group: LaterGroup
    /// 新しいメッセージが あるか(右上の 赤い点)
    let hasUnread: Bool
    let locked: Bool
    let me: String?
    let now: Date
    let onOpenChat: (UUID) -> Void

    /// v59 §2:「DAY n」(つくった日からの 日数)。実データ(creationDate)から 出す。予定日数(n/m)は 持っていないので nだけ。
    private var day: Int {
        max(1, (Calendar.current.dateComponents([.day], from: group.creationDate, to: now).day ?? 0) + 1)
    }

    /// v59 §2:23こまの フィルム。実の「1日23枚」予約は 無いので、このグループが 今まで ポストした 枚数(capされた 近似)を 使う。
    private var frames: Int { min(23, group.photos.filter(\.isPosted).count) }

    var body: some View {
        let members = GroupTogether.members(of: group, me: me, myShots: FilmCounter.shared.used, now: now)
        let pending = members.count <= 1
        let left = GroupTogether.remaining(members)
        let status = pending ? "pending" : (left == 0 ? "all in" : String(format: String(localized: "darkroom.group.toGo"), left))
        let photo = activeLatestPhoto(of: group)
        return Button {
            Haptics.play(.pop)
            onOpenChat(group.id)
        } label: {
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    if let photo, !pending {
                        DarkThumb(photo: photo, maxPixel: 500, blur: locked ? 7 : 0)
                            .saturation(locked ? 0.3 : 1)
                    } else {
                        Darkroom.card
                    }
                    // v59 §2:上45%→0→下92%の 黒(行き先・フィルムを 読みやすく)
                    LinearGradient(stops: [
                        .init(color: .black.opacity(0.45), location: 0), .init(color: .clear, location: 0.3),
                        .init(color: .clear, location: 0.42), .init(color: .black.opacity(0.92), location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                }
                .frame(width: 196, height: 248)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                // 上段: DAY n + (未読なら)赤い点
                HStack {
                    Text(verbatim: "DAY \(day)")
                        .font(Darkroom.mono(8.5)).tracking(0.1 * 8.5)
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    if hasUnread {
                        Circle().fill(LaterColor.red).frame(width: 9, height: 9)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                    }
                }
                .padding(.horizontal, 14).padding(.top, 12)

                // 下段: 行き先(グループ名)・状態・フィルム・N/23
                VStack(alignment: .leading, spacing: 6) {
                    Spacer(minLength: 0)
                    Text(verbatim: group.name)
                        .font(Typo.title(36)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.5)
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
                    Label { Text(verbatim: status) } icon: { Image(systemName: "clock") }
                        .font(Darkroom.mono(9)).foregroundStyle(.white.opacity(0.8))
                    HStack(spacing: 8) {
                        activeFilmStrip
                        Text(verbatim: "\(frames)/23").font(Typo.title(22)).foregroundStyle(.white)
                    }
                    .padding(.top, 2)
                    HStack {
                        Image(systemName: "bubble.left.fill").font(.system(size: 13))
                            .frame(minWidth: 40, minHeight: 28)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(left == 0 && !pending ? LaterColor.filmLight : Color(hex: "0E0E10").opacity(0.82)))
                            .foregroundStyle(left == 0 && !pending ? Color(hex: "111111") : .white)
                        Spacer(minLength: 0)
                        activeAvatars(members)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 14).padding(.bottom, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .frame(width: 196, height: 248)
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
        .accessibilityLabel("\(group.name)。DAY \(day)。\(status)。\(frames) / 23")
    }

    /// 23こまの フィルム(高さ18・番号なし)。撮った ぶんだけ 緑。横いっぱいに 収まるよう 細く 並べる
    private var activeFilmStrip: some View {
        HStack(spacing: 1.4) {
            ForEach(0..<23, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < frames ? LaterColor.filmLight : .white.opacity(0.16))
            }
        }
        .frame(height: 18)
    }

    private func activeAvatars(_ members: [GroupTogether.Member]) -> some View {
        HStack(spacing: -8) {
            ForEach(members.prefix(3)) { member in
                Group {
                    if member.isMe {
                        Circle().fill(RadialGradient(colors: [Color(hex: "FFE2C4"), Color(hex: "FF9A62"), Color(hex: "EE5E9C")], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 14))
                            .overlay(Circle().strokeBorder(AngularGradient(colors: [Color(hex: "9B8CFF"), Color(hex: "5AC8FF"), Color(hex: "5AD6B0"), LattagPalette.lime, Color(hex: "F2A65A"), Color(hex: "EE5E9C"), Color(hex: "9B8CFF")], center: .center), lineWidth: 2.5).padding(-3.5))
                    } else {
                        LayerAvatar(data: member.avatarData, seed: member.seed, name: member.name)
                    }
                }
                .frame(width: 24, height: 24)
                .overlay(Circle().strokeBorder(Color(hex: "111111"), lineWidth: 2))
            }
        }
    }
}

/// v59 §2:New trip カード。幅170・#0E0E0F・細い線。中に 旅の 写真3枚を チェキの扇に、下に 紙色の丸い+。
struct ActiveNewGroupCard: View {
    let onCreateGroup: () -> Void

    var body: some View {
        Button {
            Haptics.play(.tick)
            onCreateGroup()
        } label: {
            VStack(spacing: 14) {
                Spacer(minLength: 0)
                chekiFan
                Circle().fill(Color(hex: "F5F0E8"))
                    .overlay(Image(systemName: "plus").font(.system(size: 20, weight: .bold)).foregroundStyle(Color(hex: "111111")))
                    .frame(width: 48, height: 48)
                VStack(spacing: 3) {
                    Text(verbatim: "New trip").font(Typo.title(24)).foregroundStyle(.white)
                    Text(verbatim: "旅行 ・ 合宿 ・ イベント").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer(minLength: 0)
            }
            .frame(width: 170, height: 248)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(hex: "0E0E0F")))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(hex: "2A2A2E"), lineWidth: 1.5))
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
        .accessibilityLabel(Text(verbatim: "New trip。旅行・合宿・イベント"))
    }

    private var chekiFan: some View {
        ZStack {
            ForEach(Array([(-10.0, -18.0, -10.0), (0.0, 0.0, 0.0), (10.0, 18.0, 10.0)].enumerated()), id: \.offset) { _, v in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(.white)
                    .frame(width: 46, height: 56)
                    .overlay(RoundedRectangle(cornerRadius: 3).fill(Color(hex: "D8D4C8")).padding(4).padding(.bottom, 10))
                    .rotationEffect(.degrees(v.2))
                    .offset(x: v.0, y: v.1 / 6)
            }
        }
        .frame(width: 70, height: 60)
    }
}

/// 手書きの 丸(「6d / Left」を かこむ)
private struct HandCircle: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 74, sy = rect.height / 50
        var p = Path()
        p.move(to: CGPoint(x: 40 * sx, y: 4 * sy))
        p.addCurve(to: CGPoint(x: 5 * sx, y: 26 * sy), control1: CGPoint(x: 18 * sx, y: 2 * sy), control2: CGPoint(x: 3 * sx, y: 12 * sy))
        p.addCurve(to: CGPoint(x: 51 * sx, y: 43 * sy), control1: CGPoint(x: 7 * sx, y: 40 * sy), control2: CGPoint(x: 31 * sx, y: 47 * sy))
        p.addCurve(to: CGPoint(x: 68 * sx, y: 18 * sy), control1: CGPoint(x: 68 * sx, y: 40 * sy), control2: CGPoint(x: 73 * sx, y: 28 * sy))
        p.addCurve(to: CGPoint(x: 30 * sx, y: 6 * sy), control1: CGPoint(x: 63 * sx, y: 8 * sy), control2: CGPoint(x: 48 * sx, y: 3 * sy))
        return p
    }
}

/// 写真の タイル(なまえ「あや.」・時刻・ミルク色の カギ・★・長押しで 1年 のこす)
private struct DarkTile: View {
    let item: DarkroomPhoto
    let height: CGFloat
    var width: CGFloat? = nil
    var radius: CGFloat = 20
    let kept: Bool
    var compact = false
    let onTap: () -> Void
    let onKeep: (() -> Void)?

    @State private var holding = false
    @State private var ring: CGFloat = 0
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack(alignment: .bottomLeading) {
            DarkThumb(photo: item.photo, maxPixel: compact ? 260 : 500, blur: item.locked ? 10 : 0)
                .saturation(item.locked ? 0.25 : 1)
            if item.locked {
                MilkLock(showsLock: true)
            } else if !compact {
                LinearGradient(stops: [.init(color: .clear, location: 0.62), .init(color: .black.opacity(0.55), location: 1)], startPoint: .top, endPoint: .bottom)
            }
            if !compact {
                Text(verbatim: "\(item.name).").font(Darkroom.italic(item.name, size: 21))
                    .shadow(color: .black.opacity(0.5), radius: 5, y: 2)
                    .padding(.leading, 13).padding(.bottom, 10)
                if !item.locked {
                    Text(verbatim: Darkroom.time(item.photo.captureDate)).font(Darkroom.mono(9.5)).tracking(0.06 * 9.5)
                        .foregroundStyle(Darkroom.stamp).shadow(color: Darkroom.stamp.opacity(0.6), radius: 3)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 12).padding(.bottom, 12)
                }
            }
            // 長押しの 黄色い 輪
            if holding {
                RoundedRectangle(cornerRadius: radius, style: .continuous).trim(from: 0, to: ring)
                    .stroke(Darkroom.star, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .padding(2)
            }
        }
        .frame(width: width, height: height)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .clipShape(shape)
        .overlay(alignment: .topTrailing) {
            KeepStar()
                .frame(width: compact ? 24 : 30, height: compact ? 24 : 30)
                .rotationEffect(.degrees(-12))
                .scaleEffect(kept ? 1 : 0.01)
                .opacity(kept ? 1 : 0)
                .padding(compact ? 6 : 10)
                .animation(.spring(response: 0.4, dampingFraction: 0.45), value: kept)
        }
        .scaleEffect(holding ? 0.96 : 1)
        .animation(.easeOut(duration: 0.2), value: holding)
        .contentShape(shape)
        .onTapGesture(perform: onTap)
        .onLongPressGesture(minimumDuration: 0.68, maximumDistance: 9) {
            finishHold()
        } onPressingChanged: { pressing in
            guard onKeep != nil else { return }
            holdTask?.cancel()
            if pressing {
                // 0.16秒で コツ → 0.52秒 ためる
                holdTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.16))
                    guard !Task.isCancelled else { return }
                    holding = true
                    ring = 0
                    Haptics.play(.tick)
                    withAnimation(.linear(duration: 0.52)) { ring = 1 }
                }
            } else {
                holding = false
                ring = 0
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.locked ? "\(item.name)。\(item.lockedText)" : "\(item.name)。\(Darkroom.time(item.photo.captureDate))\(kept ? "。★" : "")")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: String(localized: "darkroom.keep.action")) { onKeep?() }
    }

    private func finishHold() {
        holdTask?.cancel()
        holding = false
        ring = 0
        onKeep?()
    }
}

/// 黄色い ★ ステッカー(黒の ふち)
struct KeepStar: View {
    var body: some View {
        StarShape().fill(Darkroom.star).overlay(StarShape().stroke(Color(hex: "111111"), style: StrokeStyle(lineWidth: 2.2, lineJoin: .round)))
            .shadow(color: .black.opacity(0.4), radius: 3, y: 3)
    }

    private struct StarShape: Shape {
        func path(in rect: CGRect) -> Path {
            let w = rect.width, h = rect.height
            var p = Path()
            p.move(to: CGPoint(x: w * 0.5, y: h * 0.075))
            p.addCurve(to: CGPoint(x: w * 0.925, y: h * 0.5), control1: CGPoint(x: w * 0.535, y: h * 0.3), control2: CGPoint(x: w * 0.675, y: h * 0.44))
            p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.925), control1: CGPoint(x: w * 0.675, y: h * 0.56), control2: CGPoint(x: w * 0.535, y: h * 0.7))
            p.addCurve(to: CGPoint(x: w * 0.075, y: h * 0.5), control1: CGPoint(x: w * 0.465, y: h * 0.7), control2: CGPoint(x: w * 0.325, y: h * 0.56))
            p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.075), control1: CGPoint(x: w * 0.325, y: h * 0.44), control2: CGPoint(x: w * 0.465, y: h * 0.3))
            p.closeSubpath()
            return p
        }
    }
}

// MARK: - ビューア(Once の 撮影画面の 形)

struct DarkroomViewer: View {
    let item: DarkroomPhoto
    let onClose: () -> Void
    let onReply: (DarkroomPhoto) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var kept = false
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    Haptics.play(.tick)
                    onClose()
                } label: {
                    Image(systemName: "chevron.left").font(.system(size: 19, weight: .bold))
                        .frame(width: 48, height: 48)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Darkroom.card))
                }
                .accessibilityLabel(String(localized: "common.back"))
                VStack(spacing: 3) {
                    Text(verbatim: item.name).font(Darkroom.title(item.name, size: 26)).lineLimit(1)
                    Text(verbatim: "yesterday · \(Darkroom.time(item.photo.captureDate))").font(.system(size: 12.5, weight: .medium)).foregroundStyle(Darkroom.weak)
                }
                .frame(maxWidth: .infinity)
                Button(action: keep) {
                    Image(systemName: kept ? "star.fill" : "star").font(.system(size: 19, weight: .bold))
                        .foregroundStyle(kept ? Darkroom.star : .white)
                        .frame(width: 48, height: 48)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Darkroom.card))
                }
                .opacity(item.isMine ? 1 : 0)
                .disabled(!item.isMine)
                .accessibilityLabel(String(localized: "darkroom.keep.action"))
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            DarkThumb(photo: item.photo, maxPixel: 1400)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    if let tag = item.tag {
                        let c = Darkroom.stickerColors(tag)
                        Text(verbatim: "#\(tag)").font(.system(size: 15, weight: .black)).foregroundStyle(c.1)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 12).fill(c.0))
                            .rotationEffect(.degrees(-5))
                            .padding(16)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.9)
                .opacity(appeared || reduceMotion ? 1 : 0)

            Button {
                if item.isMine { keep() } else { Haptics.play(.click); onReply(item) }
            } label: {
                Text(verbatim: item.isMine ? (kept ? "kept · 1 year" : "keep for a year") : "reply")
                    .font(.system(size: 15, weight: .heavy)).foregroundStyle(Color(hex: "111111"))
                    .padding(.horizontal, 34).frame(height: 56)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(SquishButtonStyle(pressedScale: 0.95))
            .padding(.vertical, 24)
        }
        .foregroundStyle(.white)
        .background(Darkroom.bg.ignoresSafeArea())
        .onAppear {
            Haptics.play(.pop)
            kept = item.dayKey.flatMap { MEPickStore.pick(day: $0) } == item.shotID && item.shotID != nil
            withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) { appeared = true }
        }
    }

    private func keep() {
        guard item.isMine, let day = item.dayKey, let shot = item.shotID else { return }
        if kept {
            Haptics.play(.soft)
            return
        }
        MEPickStore.set(day: day, shotID: shot, imageData: item.photo.imageData, videoURL: LaterVideoStore.localURL(for: item.photo), tags: item.tag.map { [$0] } ?? [])
        Haptics.play(.heart)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { Haptics.play(.success) }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { kept = true }
    }
}

/// 合図(keep)を 1枚にだけ つける
private struct KeepHintOn: ViewModifier {
    let active: Bool
    let eligible: Bool

    func body(content: Content) -> some View {
        if active {
            content.firstHint(.keep, eligible: eligible, edge: .top, shape: .rounded(20), onDark: true, gap: 10)
        } else {
            content
        }
    }
}
