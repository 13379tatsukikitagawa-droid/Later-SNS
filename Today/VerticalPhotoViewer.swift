import ImageIO
import SwiftUI
import UIKit

// 写真を見る画面(v14 ⑥:チェキ フィード)。どこから開いても同じビューア。
// 1画面に1投稿・下スクロールだけ。同じ人の2〜3枚目だけ横スワイプ。
// いいね数・コメント・保存・共有は置かない(👍ハンコは1日1つ・数字なし)。

/// ビューアの1ページ
struct ViewerPage: Identifiable, Equatable {
    enum Source: Equatable {
        /// 端末にある写真(解禁ずみ)。データが空なら、モザイクで代用する
        case local(Data?)
        /// Mondo の公開写真(取りに行く)
        case mondo(MondoEntry)
    }

    enum Kind: Equatable {
        case photo
        /// 終わりのページ
        case end(title: String, body: String)
    }

    let id: String
    var kind: Kind = .photo
    var source: Source = .local(nil)
    var tags: [String] = []
    var capturedAt: Date?
    /// 撮った日(時刻がないとき:Mondo は「10.25」だけ)
    var dayText: String?
    /// グループの写真:撮った人の丸アイコン
    var authorSeed: UUID?
    var authorImage: Data?
    var showsAuthor = false
    /// 解禁前(鍵つきのモザイクのページ)
    var isLocked = false
    var tiny: Data?
    var tinyKey: String = ""
    /// 左上、‹ の右に出す名前(`#夕焼け` / グループ名)
    var label: String = ""
    /// 右上の「03 / 30」
    var counter: String = ""
    /// Mondo の写真:右上の ⋯(通報・ブロック・取り下げ)の対象
    var moreEntry: MondoEntry?
    /// 灯の置き場所(この場所・この日)。nil なら、灯に関わる表示を何も出さない
    var lamp: LampTarget?
    /// 発表ずみの一枚(押せない、ともったままの点灯アイコンを右下に静かに出す)
    var showsLitMark = false
    /// 世界の一枚:左下に地球のアイコン(丸、44pt)
    var showsGlobe = false
    /// 撮った人の名前(Mondo では出さない)
    var authorName: String?
    /// 街(区市町村まで)
    var city: String?
    /// 「···」の対象:撮った人(見えなくする)と、この写真(通報する)。自分の写真なら nil
    var authorRecordName: String?
    var photoRecordName: String?
}

/// ビューアのページが属する「灯の置き場所」
struct LampTarget: Equatable {
    /// 撮影日 yyyy-MM-dd
    let day: String
    /// `world` またはグループの recordName
    let scope: String
    /// ともす対象の写真。自分の写真・未解禁のときは nil(灯ボタンを出さない)
    let photoRecordName: String?
}

// MARK: - チェキ フィード(v14 ⑥ / v15)

// 1画面に1投稿。下スクロールだけ(viewAligned)。友達・グループ・Mondo で同じ部品。
// v14 以前の不具合:GeometryReader ごと .ignoresSafeArea() していたため proxy.safeAreaInsets.top が 0 になり、
// 上のバーが状態バー(ダイナミックアイランド)の位置に置かれていた。ここでは窓の安全領域を直接読む。

/// ハッシュタグの見せ方(基本は手書き。マステ・ステッカーは設定・イベント用)
enum TagStyle: String, CaseIterable, Sendable {
    case handwritten, tape, sticker
    static var current: TagStyle = .handwritten
}

enum ChekiFeedRules {
    /// 紙の色:昼 #FBF8F1 / 夜 #EFE9DC(夜でも紙は白っぽいまま)
    static func paper(night: Bool) -> Color { Color(hex: night ? "EFE9DC" : "FBF8F1") }
    /// 枠:上・左右 11 / 下 82(ここが余白)
    static let frameSide: CGFloat = 11
    static let frameBottom: CGFloat = 82
    static let sideInset: CGFloat = 18
    /// 横スワイプのしきい値
    static let swipeThreshold: CGFloat = 70
    /// 長押しで持ち上げるまで
    static let liftDelay: TimeInterval = 0.38
    /// オレンジの日付刻印
    static let stampColor = Color(hex: "FF8A2A")

    /// タグのペンの色(同じタグは いつも同じ色):青 / 赤 / 緑 / 紫 / オレンジ / ピンク
    static let penColors: [String] = ["1F4FD8", "D93A2B", "1E8A57", "7A3FD0", "E0761A", "C2187A"]

    static func penIndex(for tag: String) -> Int {
        var hash: UInt32 = 2166136261
        for unit in tag.unicodeScalars { hash = (hash ^ unit.value) &* 16777619 }
        return Int(hash % UInt32(penColors.count))
    }

    static func penColor(for tag: String) -> Color { Color(hex: penColors[penIndex(for: tag)]) }

    /// 写ルンです風の刻印「'26 11 02」
    static func stamp(_ date: Date) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents(in: .current, from: date)
        return String(format: "'%02d %02d %02d", (c.year ?? 0) % 100, c.month ?? 0, c.day ?? 0)
    }

    /// 区切りのラベル:「きょう ・ 9:00 に ひらく」「きのう ・ 11.02」「11.01」
    static func sectionLabel(capturedAt: Date?, dayText: String?, isLocked: Bool, now: Date, calendar: Calendar = .current) -> String {
        if isLocked { return "きょう ・ 9:00 に ひらく" }
        guard let capturedAt else { return dayText ?? "" }
        let c = calendar.dateComponents([.month, .day], from: capturedAt)
        let md = String(format: "%02d.%02d", c.month ?? 0, c.day ?? 0)
        let window = DailyWindow.yesterday(for: now, calendar: calendar)
        if capturedAt >= window.open && capturedAt < window.close { return "きのう ・ \(md)" }
        return md
    }

    /// 同じ人の同じ日の写真をまとめる(横スワイプで2〜3枚目)。Mondo・終わりのページはまとめない
    static func stacks(_ pages: [ViewerPage]) -> [[ViewerPage]] {
        var result: [[ViewerPage]] = []
        for page in pages {
            if let last = result.last?.last, canStack(last, page), result[result.count - 1].count < FilmRoll.shotsPerDay {
                result[result.count - 1].append(page)
            } else {
                result.append([page])
            }
        }
        return result
    }

    private static func canStack(_ a: ViewerPage, _ b: ViewerPage) -> Bool {
        guard a.kind == .photo, b.kind == .photo, a.showsAuthor, b.showsAuthor,
              let sa = a.authorSeed, let sb = b.authorSeed, sa == sb else { return false }
        let ka = a.capturedAt.map { ExposureDayStore.dayKey(for: $0) } ?? a.dayText
        let kb = b.capturedAt.map { ExposureDayStore.dayKey(for: $0) } ?? b.dayText
        return ka == kb && a.isLocked == b.isLocked
    }

    /// タグの文字の大きさ:22pt から、入りきらなければ最小 15pt まで
    static let tagMaxSize: CGFloat = 22
    static let tagMinScale: CGFloat = 15.0 / 22.0
}

/// 窓の安全領域(全画面の上で ignoresSafeArea されていても、本当の値を読む)
@MainActor
enum WindowInsets {
    static var current: UIEdgeInsets {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        return (windows.first(where: \.isKeyWindow) ?? windows.first)?.safeAreaInsets ?? UIEdgeInsets(top: 54, left: 0, bottom: 34, right: 0)
    }
}

struct VerticalPhotoViewer: View {
    let pages: [ViewerPage]
    let startIndex: Int
    let haptics: ExposureHaptics
    let onClose: () -> Void
    var onMore: ((MondoEntry) -> Void)?
    /// 👍(灯)の状態。nil ならハンコは出さない(カレンダーなど)
    var lampBoard: LampBoard?
    var now: Date = Date()
    /// true なら、自前の上のバーを出さない(NavigationStack の標準の戻るボタンに任せる)
    var usesNavigationChrome = false
    var onPageChange: ((ViewerPage) -> Void)?

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position: String?
    @State private var toast: String?
    @State private var reachedEnd = false
    @State private var tick = ScrollTickHaptics()
    /// 一度「現像」した投稿(初回だけ ぼかし → くっきり)
    @State private var developed: Set<String> = []

    init(pages: [ViewerPage], startIndex: Int, haptics: ExposureHaptics, onMore: ((MondoEntry) -> Void)? = nil, lampBoard: LampBoard? = nil, now: Date = Date(), onClose: @escaping () -> Void) {
        self.pages = pages
        self.startIndex = startIndex
        self.haptics = haptics
        self.onMore = onMore
        self.lampBoard = lampBoard
        self.now = now
        self.onClose = onClose
        let stacks = ChekiFeedRules.stacks(pages.filter { $0.kind == .photo })
        let startID = pages.indices.contains(startIndex) ? pages[startIndex].id : nil
        let stack = stacks.first { $0.contains { $0.id == startID } } ?? stacks.first
        _position = State(initialValue: stack?.first?.id)
    }

    func navigationChrome(onPageChange: @escaping (ViewerPage) -> Void) -> VerticalPhotoViewer {
        var copy = self
        copy.usesNavigationChrome = true
        copy.onPageChange = onPageChange
        return copy
    }

    private var stacks: [[ViewerPage]] { ChekiFeedRules.stacks(pages.filter { $0.kind == .photo }) }
    private var endPage: ViewerPage? { pages.first { if case .end = $0.kind { return true } else { return false } } }

    var body: some View {
        let insets = WindowInsets.current
        let headerHeight: CGFloat = usesNavigationChrome ? 0 : 52
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(Array(stacks.enumerated()), id: \.element.first!.id) { index, stack in
                    let first = stack[0]
                    let previous = index > 0 ? stacks[index - 1][0] : nil
                    let label = ChekiFeedRules.sectionLabel(capturedAt: first.capturedAt, dayText: first.dayText, isLocked: first.isLocked, now: now)
                    let previousLabel = previous.map { ChekiFeedRules.sectionLabel(capturedAt: $0.capturedAt, dayText: $0.dayText, isLocked: $0.isLocked, now: now) }
                    ChekiPost(
                        stack: stack,
                        sectionLabel: label != previousLabel ? label : nil,
                        lampBoard: lampBoard,
                        now: now,
                        firstDevelop: !developed.contains(first.id),
                        onDeveloped: { developed.insert(first.id) },
                        onMore: onMore,
                        onToast: show
                    )
                    .id(first.id)
                }
                FeedEnd(title: endTitle, message: endMessage)
                    .id("feed-end")
                    .onScrollVisibilityChange(threshold: 0.6) { visible in
                        guard visible, !reachedEnd else { return }
                        reachedEnd = true
                        Haptics.play(.success)
                    }
            }
            .scrollTargetLayout()
            .padding(.top, insets.top + headerHeight)
            .padding(.bottom, insets.bottom + 24)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $position, anchor: .top)
        .scrollIndicators(.hidden)
        .background(palette.bg.ignoresSafeArea())
        .overlay(alignment: .top) {
            if !usesNavigationChrome { header(top: insets.top) }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(palette.bg)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(palette.ink))
                    .padding(.bottom, insets.bottom + 40)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: toast)
        .ignoresSafeArea()
        .onAppear {
            Haptics.prepare()
            if let page = pages.first(where: { $0.id == position }) { onPageChange?(page) }
        }
        .onChange(of: position) { _, new in
            tick.step(new)
            if let page = pages.first(where: { $0.id == new }) { onPageChange?(page) }
        }
    }

    private var endTitle: String {
        if let endPage, case .end(let title, _) = endPage.kind { return title }
        return "ここまで。"
    }

    private var endMessage: String {
        if let endPage, case .end(_, let body) = endPage.kind { return body }
        return "また あしたの 9:00 に。"
    }

    private func show(_ message: String) {
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { if toast == message { toast = nil } }
    }

    /// すりガラスのヘッダー(安全領域の内側):戻る 38pt / 見出し / 枚数
    private func header(top: CGFloat) -> some View {
        let current = pages.first { $0.id == position }
        return HStack(spacing: 10) {
            Button {
                Haptics.play(.soft)
                onClose()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.ink)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(palette.fill))
                    .contentShape(Circle())
            }
            .buttonStyle(SquishButtonStyle(pressedScale: 0.88))
            .accessibilityLabel("戻る")
            Text(current?.label.isEmpty == false ? current!.label : "きのうの みんな")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(palette.ink)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .padding(.top, top)
        .background(.ultraThinMaterial)
        .background(palette.bg.opacity(0.55))
    }
}

// MARK: - 1投稿

private struct ChekiPost: View {
    let stack: [ViewerPage]
    let sectionLabel: String?
    let lampBoard: LampBoard?
    let now: Date
    let firstDevelop: Bool
    let onDeveloped: () -> Void
    let onMore: ((MondoEntry) -> Void)?
    let onToast: (String) -> Void

    @Environment(\.palette) private var palette
    @State private var index = 0
    @State private var drag: CGFloat = 0
    @State private var passed = false
    @State private var showsMenu = false
    @State private var confirmsHide = false
    @State private var showsReport = false
    @Environment(\.modelContext) private var modelContext

    private var page: ViewerPage { stack[min(index, stack.count - 1)] }
    private var isMondo: Bool { page.showsGlobe || page.moreEntry != nil }
    private var hasMenu: Bool { page.moreEntry != nil || page.authorRecordName != nil || page.photoRecordName != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let sectionLabel {
                Text(sectionLabel)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(0.12 * 11)
                    .foregroundStyle(palette.groupAdd.note)
                    .padding(.horizontal, ChekiFeedRules.sideInset)
                    .padding(.top, 6)
            }
            postHeader
            ZStack {
                // 後ろの束(右上に 7pt / 13pt ずらして少し傾ける)
                ForEach(Array(stack.indices.reversed()), id: \.self) { i in
                    let d = i - index
                    if d > 0 && d <= 2 {
                        ChekiPaper(page: stack[i], lampBoard: nil, now: now, develop: false, onDeveloped: {}, onToast: { _ in })
                            .offset(x: CGFloat(d) * (d == 1 ? 7 : 6.5), y: -CGFloat(d) * (d == 1 ? 7 : 6.5))
                            .rotationEffect(.degrees(Double(d) * 1.6))
                            .brightness(-0.04 * Double(d))
                            .allowsHitTesting(false)
                    }
                }
                ChekiPaper(page: page, lampBoard: lampBoard, now: now, develop: firstDevelop && index == 0, onDeveloped: onDeveloped, onToast: onToast)
                    .offset(x: drag)
                    .rotationEffect(.degrees(Double(drag / 22)))
                    .id(page.id)
                    .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
            }
            .padding(.horizontal, ChekiFeedRules.sideInset)
            .simultaneousGesture(stack.count > 1 ? swipe : nil)
        }
        .padding(.vertical, 12)
        .containerRelativeFrame(.vertical, alignment: .top) { length, _ in length }
        .accessibilityElement(children: .contain)
    }

    /// 投稿の頭(46pt):アイコン 34pt + 名前 +「街 ・ 時刻」/ 2枚以上なら 1 / 3 / ···
    private var postHeader: some View {
        HStack(spacing: 10) {
            if isMondo {
                Image(systemName: "globe.asia.australia.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(palette.ink)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(palette.fill))
            } else if let seed = page.authorSeed {
                AuthorDot(seed: seed, imageData: page.authorImage).frame(width: 34, height: 34)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    // Mondo は名前とアイコンを出さない
                    Text(isMondo ? "だれかの 1枚" : (page.authorName ?? page.label))
                        .font(.system(size: 14.5, weight: .heavy))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                    if !isMondo, page.authorName != nil, !page.label.isEmpty {
                        Text(page.label)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(palette.groupAdd.note)
                            .padding(.horizontal, 7)
                            .frame(height: 18)
                            .background(Capsule().fill(palette.fill))
                            .lineLimit(1)
                    }
                }
                Text(metaLine)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.groupAdd.note)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if stack.count > 1 {
                Text("\(index + 1) / \(stack.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.ink)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Capsule().fill(palette.fill))
                    .contentTransition(.numericText())
            }
            Button {
                Haptics.play(.pop)
                if let entry = page.moreEntry, let onMore { onMore(entry) } else { showsMenu = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.ink)
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("この写真について")
            // 自分の写真・鍵のページなど、対象がないときは出さない
            .opacity(hasMenu ? 1 : 0)
            .disabled(!hasMenu)
            .accessibilityHidden(!hasMenu)
            .confirmationDialog("この写真", isPresented: $showsMenu, titleVisibility: .hidden) {
                // App Store の審査に必要:見えなくする(ブロック)・通報する
                if page.authorRecordName != nil {
                    Button("この人の写真を 見えなくする", role: .destructive) { confirmsHide = true }
                        .accessibilityHint("\(page.authorName ?? "この人")の写真が、どこにも出なくなります")
                }
                if page.photoRecordName != nil {
                    Button("通報する", role: .destructive) { showsReport = true }
                }
                Button("やめる", role: .cancel) {}
            }
            .alert("\(page.authorName ?? "この人")の写真を、見えなくしますか?", isPresented: $confirmsHide) {
                Button("見えなくする", role: .destructive) { hideAuthor() }
                Button("やめる", role: .cancel) {}
            } message: {
                Text("相手には知らされません。設定の「見えなくした人」から、もどせます。")
            }
            .sheet(isPresented: $showsReport) {
                if let id = page.photoRecordName {
                    ReportSheet(targetType: .circlePhoto, targetID: id)
                }
            }
        }
        .frame(height: 46)
        .padding(.horizontal, ChekiFeedRules.sideInset)
    }

    /// 見えなくする:既存のブロック(ModerationService)を使う。相手には知らされない
    private func hideAuthor() {
        guard let author = page.authorRecordName else { return }
        let name = page.authorName
        Task { @MainActor in
            do {
                _ = try await ModerationService.blockUser(cloudKitUserRecordName: author, displayName: name, modelContext: modelContext)
                Haptics.play(.soft)
                onToast("見えなくしました")
            } catch {
                Haptics.play(.warn)
                onToast("できませんでした。つながってから、もう一度")
            }
        }
    }

    private var metaLine: String {
        var parts: [String] = []
        if let city = page.city { parts.append(city) }
        if let at = page.capturedAt { parts.append(TodayFilmRules.timeText(at)) } else if let day = page.dayText { parts.append(day) }
        return parts.joined(separator: " ・ ")
    }

    /// 横スワイプ:同じ人の 2〜3枚目へ(70pt で tick、1枚目に戻ると thud)
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                drag = value.translation.width
                let over = abs(drag) > ChekiFeedRules.swipeThreshold
                if over && !passed { Haptics.play(.tick) }
                passed = over
            }
            .onEnded { value in
                passed = false
                let next: Int
                if drag < -ChekiFeedRules.swipeThreshold { next = (index + 1) % stack.count }
                else if drag > ChekiFeedRules.swipeThreshold { next = max(0, index - 1) }
                else { next = index }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                    drag = 0
                    index = next
                }
                if next == 0 && abs(value.translation.width) > ChekiFeedRules.swipeThreshold { Haptics.play(.thud) }
            }
    }
}

// MARK: - チェキの紙

private struct ChekiPaper: View {
    let page: ViewerPage
    let lampBoard: LampBoard?
    let now: Date
    let develop: Bool
    let onDeveloped: () -> Void
    let onToast: (String) -> Void

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: UIImage?
    /// 0 = ぼやけ・もや / 1 = くっきり
    @State private var clarity: Double = 1
    @State private var lifted = false
    @State private var tilt: CGSize = .zero
    @State private var lastTiltCell = 0
    @State private var stampBurst = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photo
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipShape(Rectangle())
                .overlay(alignment: .bottomTrailing) {
                    if let at = page.capturedAt, !page.isLocked {
                        Text(ChekiFeedRules.stamp(at))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(ChekiFeedRules.stampColor)
                            .shadow(color: ChekiFeedRules.stampColor.opacity(0.85), radius: 3)
                            .padding(10)
                    }
                }
            margin
                .frame(height: ChekiFeedRules.frameBottom)
        }
        .padding([.top, .horizontal], ChekiFeedRules.frameSide)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(ChekiFeedRules.paper(night: palette.isNight))
                .overlay(PaperGrain().clipShape(RoundedRectangle(cornerRadius: 4)))
                .shadow(color: .black.opacity(lifted ? 0.38 : 0.2), radius: lifted ? 26 : 12, y: lifted ? 20 : 8)
        )
        .scaleEffect(lifted ? 1.035 : 1)
        .rotation3DEffect(.degrees(Double(tilt.width) * 8), axis: (x: 0, y: 1, z: 0))
        .rotation3DEffect(.degrees(Double(-tilt.height) * 8), axis: (x: 1, y: 0, z: 0))
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: lifted)
        .gesture(liftGesture)
        .task(id: page.id) { await load() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibility)
    }

    private var accessibility: String {
        var text = page.isLocked ? "9:00 に ひらく写真" : "写真"
        if !page.tags.isEmpty { text += "。" + page.tags.map { "#\($0)" }.joined(separator: " ") }
        return text
    }

    // MARK: 写真

    @ViewBuilder
    private var photo: some View {
        ZStack {
            MosaicView(tiny: page.tiny, key: page.tinyKey, level: .l0)
            if page.isLocked {
                // 9:00 前:色のモザイク + 鍵 +「9:00 に ひらく」(写真そのものは読まない)
                VStack(spacing: 8) {
                    Image(systemName: "lock.fill").font(.system(size: 22, weight: .bold))
                    Text("9:00 に ひらく").font(.system(size: 13, weight: .heavy))
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 4)
            } else if let image {
                // フィルムらしさ:コントラスト少し下げ・彩度 0.9・ほんのりセピア・周辺減光(GPU のかるい加工だけ。重い処理は焼き込み済み)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .contrast(0.94)
                    .saturation(0.9)
                    .colorMultiply(Color(hex: "FFF6E8"))
                    .blur(radius: 10 * (1 - clarity))
                    .overlay(Color.white.opacity(0.45 * (1 - clarity)))
                    .overlay(RadialGradient(colors: [.clear, .black.opacity(0.28)], center: .center, startRadius: 120, endRadius: 320))
            }
        }
    }

    // MARK: 余白(街・ハッシュタグ・👍ハンコ)

    private var margin: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                if let city = page.city {
                    Text(city)
                        .font(ChekiFont.hand(13))
                        .foregroundStyle(Color(hex: "8A8070"))
                        .lineLimit(1)
                }
                ChekiTags(tags: page.tags, style: TagStyle.current)
            }
            Spacer(minLength: 4)
            stampButton
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private var stampButton: some View {
        if !page.isLocked, let lampBoard, let target = page.lamp, let photo = target.photoRecordName, LampRules.isOpen(photoDay: target.day, now: now) {
            let lit = lampBoard.litPhoto(day: target.day, scope: target.scope) == photo
            Button {
                switch lampBoard.toggle(day: target.day, scope: target.scope, photoRecordName: photo, now: now) {
                case .placed:
                    stampBurst += 1
                    Haptics.play(.thud)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { Haptics.play(.success) }
                case .moved:
                    // 前のハンコは はがれて飛ぶ
                    stampBurst += 1
                    Haptics.play(.soft)
                    onToast("今日の 1枚は ひとつだけ")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { Haptics.play(.success) }
                case .cancelled:
                    Haptics.play(.soft)
                }
            } label: {
                StampMark(lit: lit, burst: stampBurst, day: target.day)
            }
            .buttonStyle(SquishButtonStyle(pressedScale: 0.86))
            .accessibilityLabel(lit ? "👍 をはがす" : "👍 を押す。1日に1つ")
        }
    }

    // MARK: 長押し:持ち上げて、指の位置で 3D に傾く

    private var liftGesture: some Gesture {
        LongPressGesture(minimumDuration: ChekiFeedRules.liftDelay)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onChanged { value in
                switch value {
                case .first(true):
                    break
                case .second(true, let drag):
                    if !lifted {
                        lifted = true
                        Haptics.play(.pop)
                    }
                    if let drag, !reduceMotion {
                        let t = CGSize(width: max(-1, min(1, drag.translation.width / 120)), height: max(-1, min(1, drag.translation.height / 160)))
                        tilt = t
                        let cell = Int((t.width * 4).rounded()) * 10 + Int((t.height * 4).rounded())
                        if cell != lastTiltCell {
                            lastTiltCell = cell
                            Haptics.play(.tick)
                        }
                    }
                default:
                    break
                }
            }
            .onEnded { _ in
                guard lifted else { return }
                Haptics.play(.soft)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    lifted = false
                    tilt = .zero
                }
            }
    }

    // MARK: 読みこみ(初回だけ ぼやけ・もや → くっきり 1.2秒 + 短い rumble)

    private func load() async {
        guard !page.isLocked, page.kind == .photo else { return }
        if develop && !reduceMotion { clarity = 0 }
        switch page.source {
        case .local(let data):
            if let data, !data.isEmpty {
                image = await Task.detached(priority: .userInitiated) { ChekiImageLoader.downsample(data, maxPixel: 1400) }.value
            }
        case .mondo(let entry):
            if let thumb = await MondoService.shared.thumbnail(for: entry) { image = thumb }
            if let full = await MondoService.shared.fullImage(for: entry) { image = full }
        }
        if develop && !reduceMotion && image != nil {
            Haptics.play(.rumble, intensity: 0.5)
            withAnimation(.easeOut(duration: 1.2)) { clarity = 1 }
        } else {
            clarity = 1
        }
        if develop { onDeveloped() }
    }
}

enum ChekiImageLoader {
    nonisolated static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map { UIImage(cgImage: $0) }
    }
}

/// 手書きの文字(Yusei Magic・アプリに同梱。サブセットにない字は、システムの文字で出る)
enum ChekiFont {
    static let handName = "YuseiMagic-Regular"
    static func hand(_ size: CGFloat) -> Font { .custom(handName, size: size) }
}

/// ハッシュタグ(必ず1行。22pt から最小 15pt まで小さくなる)
struct ChekiTags: View {
    let tags: [String]
    let style: TagStyle

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(tags.prefix(DailyExposureRules.maxTags).enumerated()), id: \.offset) { i, tag in
                tagView(tag, index: i)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(ChekiFeedRules.tagMinScale)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func tagView(_ tag: String, index: Int) -> some View {
        let color = ChekiFeedRules.penColor(for: tag)
        switch style {
        case .handwritten:
            Text("#\(tag)")
                .font(ChekiFont.hand(ChekiFeedRules.tagMaxSize))
                .foregroundStyle(color)
                .rotationEffect(.degrees(index.isMultiple(of: 2) ? -2.5 : 2))
                .background(alignment: .bottom) {
                    // マーカーのにじみ
                    Capsule().fill(color.opacity(0.14)).frame(height: 7).offset(y: -3)
                }
        case .tape:
            Text("#\(tag)")
                .font(ChekiFont.hand(17))
                .foregroundStyle(Color(hex: "3A2E24"))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Rectangle().fill(color.opacity(0.28)))
        case .sticker:
            Text("#\(tag)")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(color))
                .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
        }
    }
}

/// 👍ハンコ:上から赤いハンコが ドンッ と押される(赤い輪 + 👍 + 日付)。押す前は、うすい点線の丸
private struct StampMark: View {
    let lit: Bool
    let burst: Int
    let day: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if lit {
                Circle().strokeBorder(Color(hex: "D93A2B"), lineWidth: 2.5)
                VStack(spacing: 0) {
                    Text("👍").font(.system(size: 20))
                    Text(String(day.suffix(5)).replacingOccurrences(of: "-", with: "."))
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "D93A2B"))
                }
                .transition(.scale(scale: 2.2).combined(with: .opacity))
            } else {
                Circle().strokeBorder(Color(hex: "B9AE9C"), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                Text("👍").font(.system(size: 20)).opacity(0.45)
            }
        }
        .frame(width: 58, height: 58)
        .rotationEffect(.degrees(lit ? -8 : 0))
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 0.5), value: lit)
        .keyframeAnimator(initialValue: 1.0, trigger: burst) { content, s in
            content.scaleEffect(s)
        } keyframes: { _ in
            KeyframeTrack {
                if reduceMotion {
                    LinearKeyframe(1, duration: 0.01)
                } else {
                    LinearKeyframe(1.35, duration: 0.08)
                    SpringKeyframe(0.92, duration: 0.12)
                    SpringKeyframe(1, duration: 0.2)
                }
            }
        }
    }
}

/// 薄い紙の粒
private struct PaperGrain: View {
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 7
            func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(seed >> 33) / CGFloat(UInt32.max >> 1) }
            for _ in 0..<Int(size.width * size.height / 260) {
                let p = CGRect(x: rnd() * size.width, y: rnd() * size.height, width: 1, height: 1)
                context.fill(Path(p), with: .color(.black.opacity(0.05)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// フィードの最後:朝焼けのアーチ +「ここまで。また あしたの 9:00 に。」(無限スクロールにしない)
private struct FeedEnd: View {
    let title: String
    let message: String
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 10) {
            Path { p in p.addArc(center: CGPoint(x: 90, y: 70), radius: 70, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false) }
                .stroke(LinearGradient(colors: GroupAddColors.sunset, startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 180, height: 76)
            Text(title)
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(palette.ink)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(palette.groupAdd.note)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .accessibilityElement(children: .combine)
    }
}

/// 撮った人の丸アイコン(プロフィール画像があればそれ、なければペルソナ)
struct AuthorDot: View {
    let seed: UUID
    let imageData: Data?

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                PersonaIcon(seed: seed)
            }
        }
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.55), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.4), radius: 4)
    }
}
