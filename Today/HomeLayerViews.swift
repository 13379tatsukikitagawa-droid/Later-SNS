import ImageIO
import SwiftUI
import UIKit

// 今日のホームの下に、ゆっくり続く「層」。いまのホームの1画面(光の玉・見出し・カード・グループ)は
// そのまま1ページ目として上にのせ、いっしょにスクロールする(1:1)。月は TodayView の上の層なので動かない。
// ヘッダーは上に固定し、130pt をこえると、すりガラスが出てくる(230pt で完全に出る)。

// MARK: - 動き(OUT = cubic-bezier(.2,.8,.2,1))

enum LayerMotion {
    static let out = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.7)
    /// すりガラスが出はじめる・出きる位置
    static let glassStart: CGFloat = 130
    static let glassEnd: CGFloat = 230
    /// これより下にスクロールしたら、玉のタップ(MONDO へ)は止める
    static let orbTapLimit: CGFloat = 40
    /// 起動して数秒後に、1回だけ見せる量
    static let peekDistance: CGFloat = 64
    static let peekDelay: Double = 3

    static func glassOpacity(offset: CGFloat) -> Double {
        Double(min(1, max(0, (offset - glassStart) / (glassEnd - glassStart))))
    }
}

/// 起動して1回だけ「ちらっと」見せたか(アプリを開いているあいだ)
@MainActor
private enum LayerPeekOnce {
    static var done = false
}

// MARK: - スクロールの器

/// 1ページ目(今のホーム)+ 層 を縦にスクロールする。ヘッダーは上に固定。
struct HomeScrollShell<Page: View, Layers: View, Header: View>: View {
    let pageHeight: CGFloat
    let width: CGFloat
    /// ヘッダーの上端(安全領域)
    let headerTop: CGFloat
    /// すりガラスの地の色
    let glassTint: Color
    /// 画面が見えていて、起動アニメーションが終わっている
    let canPeek: Bool
    /// false なら 1ページ目を画面の高さに広げない(v14 の今日のホーム:中身の高さのまま、つづけて流す)
    var fillsPage = true
    @Binding var offset: CGFloat
    @ViewBuilder let page: () -> Page
    @ViewBuilder let layers: () -> Layers
    @ViewBuilder let header: () -> Header

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position = ScrollPosition(edge: .top)
    @State private var touched = false
    @State private var atBottom = false
    @State private var atTop = true
    /// スクロールの器の高さ(1ページ目は、少なくともこの高さ = いまのホームの1画面)
    @State private var containerHeight: CGFloat = 0

    private struct Metrics: Equatable {
        var offset: CGFloat
        var maxOffset: CGFloat
        var container: CGFloat
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                page()
                    .frame(width: width, height: fillsPage ? max(pageHeight, containerHeight) : nil, alignment: .top)
                layers()
                    .frame(width: width)
            }
        }
        .scrollPosition($position)
        .scrollIndicators(.hidden)
        .ignoresSafeArea()
        .onScrollGeometryChange(for: Metrics.self) { geometry in
            let y = geometry.contentOffset.y + geometry.contentInsets.top
            let maxY = geometry.contentSize.height + geometry.contentInsets.top + geometry.contentInsets.bottom - geometry.containerSize.height
            return Metrics(offset: y, maxOffset: maxY, container: geometry.containerSize.height)
        } action: { _, metrics in
            if metrics.container != containerHeight { containerHeight = metrics.container }
            offset = metrics.offset
            // いちばん下・いちばん上についたとき、やわらかく1回だけ(はなれて戻ったら、また1回)
            let bottom = metrics.maxOffset > 0 && metrics.offset >= metrics.maxOffset - 2
            if bottom, !atBottom, touched { LayerHaptics.soft() }
            if bottom { atBottom = true } else if metrics.offset < metrics.maxOffset - 80 { atBottom = false }
            let top = metrics.offset <= 0
            if top, !atTop, touched { LayerHaptics.soft() }
            if top { atTop = true } else if metrics.offset > 80 { atTop = false }
        }
        .onScrollPhaseChange { _, phase in
            if phase == .interacting { touched = true }
        }
        .overlay(alignment: .top) {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(glassTint.opacity(0.55))
                    .overlay(alignment: .bottom) { Rectangle().fill(glassTint == .black ? Color.white.opacity(0.08) : Color.black.opacity(0.06)).frame(height: 0.5) }
                    .frame(height: headerTop + LaterHeader.height)
                    .opacity(LayerMotion.glassOpacity(offset: offset))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                header()
                    .frame(width: width, height: LaterHeader.height)
                    .padding(.top, headerTop)
            }
            .ignoresSafeArea()
        }
        .task(id: canPeek) { await peekIfNeeded() }
    }

    /// 起動して数秒したら、1回だけ下をちらっと 64pt 見せて、もどる(触ったら出さない・視差を減らすなら出さない)
    private func peekIfNeeded() async {
        guard canPeek, !LayerPeekOnce.done, !reduceMotion else { return }
        try? await Task.sleep(for: .seconds(LayerMotion.peekDelay))
        guard !Task.isCancelled, canPeek, !touched, !LayerPeekOnce.done, offset < 1 else { return }
        LayerPeekOnce.done = true
        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.6)) { position.scrollTo(y: LayerMotion.peekDistance) }
        try? await Task.sleep(for: .seconds(0.9))
        guard !touched else { return }
        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.7)) { position.scrollTo(y: 0) }
    }
}

// MARK: - 画面に入るとき、下からふわっと

private struct LayerReveal: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        let visible = shown || reduceMotion
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 24)
            .onScrollVisibilityChange(threshold: 0.12) { isVisible in
                guard isVisible, !shown else { return }
                if reduceMotion { shown = true } else { withAnimation(LayerMotion.out) { shown = true } }
            }
    }
}

extension View {
    fileprivate func layerReveal() -> some View { modifier(LayerReveal()) }

    /// 層の見出しが画面の上の 40% に入ったら onEnter(index)(縦スクロールのカチ)
    fileprivate func layerTick(_ index: Int, onEnter: @escaping (Int) -> Void) -> some View {
        onScrollVisibilityChange(threshold: 0.35) { visible in
            if visible { onEnter(index) }
        }
    }
}

/// 層の背景:1枚の続いた面。光(RadialGradient)を2つ重ね、上下を LinearGradient のマスクでとかす。
/// 地の色はぬらない(1ページ目の地がそのまま続く。色をぬると、境目に段差が出る)。
private struct LayerGlowBackground: View {
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            let w = proxy.size.width
            let warm = Color(hex: palette.isNight ? "FF8A3D" : "FFB347")
            let rose = Color(hex: palette.isNight ? "7A5CFF" : "FF5C8A")
            ZStack {
                RadialGradient(colors: [warm.opacity(palette.isNight ? 0.12 : 0.10), .clear], center: UnitPoint(x: 0.15, y: 0.22), startRadius: 0, endRadius: max(w, h * 0.35))
                RadialGradient(colors: [rose.opacity(palette.isNight ? 0.10 : 0.07), .clear], center: UnitPoint(x: 0.9, y: 0.62), startRadius: 0, endRadius: max(w, h * 0.35))
            }
            .mask(
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.12),
                    .init(color: .black, location: 0.82),
                    .init(color: .clear, location: 1),
                ], startPoint: .top, endPoint: .bottom)
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 層ぜんぶ

/// 上から:ともだち → 昨日のみんな → 昨日の世界のことば → じぶん → おわり
struct HomeLayerStack: View {
    let state: HomeState
    let now: Date
    let shotsToday: Int
    let data: HomeLayerData
    let actions: HomeLayerActions
    /// 画面が見えている(流れるタグを動かす)
    let isActive: Bool

    @Environment(\.palette) private var palette
    @State private var sheet: LayerSheet?
    @State private var layerTick = ScrollTickHaptics(minInterval: 0.14)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LayerFriendsBlock(state: state, data: data, actions: actions, onFriend: { open(.friend($0)) }, onInvite: { open(.invite) })
                .layerReveal()
                .layerTick(0, onEnter: enter)
                .padding(.top, 8)

            if HomeLayerRules.yesterdayMode(state) != .hidden, !data.yesterday.isEmpty {
                LayerYesterdayBlock(state: state, now: now, cards: data.yesterday, actions: actions)
                    .layerReveal()
                    .layerTick(1, onEnter: enter)
                    .padding(.top, LayerRhythm.section)
            }

            if !data.words.isEmpty {
                LayerWordsBlock(state: state, shotsToday: shotsToday, words: data.words, isActive: isActive, actions: actions)
                    .layerReveal()
                    .layerTick(2, onEnter: enter)
                    .padding(.top, LayerRhythm.section)
            }

            LayerSelfBlock(state: state, now: now, film: data.film, picks: data.picks, onFilm: { day in
                switch day.kind {
                case .photo: open(.film(day))
                case .developing:
                    // まだ開けないもの:やわらかく2回 + 短い一言(中は開かない)
                    LayerHaptics.softDouble()
                    actions.toast(PhotoDevelop.lockedNote)
                case .empty, .rest: break
                }
            }, onShoot: actions.shoot, onPick: { open(.pick($0)) }, onEmptyDay: {
                LayerHaptics.softDouble()
                actions.toast("グループの一枚に選ばれた日が、光ります")
            })
            .layerReveal()
            .layerTick(3, onEnter: enter)
            .padding(.top, LayerRhythm.section)

            LayerEndBlock(state: state)
                .layerReveal()
                .layerTick(4, onEnter: enter)
                .padding(.top, LayerRhythm.section)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 背景は1枚の続いた面:帯や四角をしかず、光を2つ重ねて、上下をマスクでとかす
        .background { LayerGlowBackground() }
        .sheet(item: $sheet, onDismiss: { LayerHaptics.soft() }) { sheet in
            LayerSheetContent(sheet: sheet, state: state, now: now, data: data, actions: actions, onClose: { self.sheet = nil })
                .environment(\.palette, palette)
        }
        .onAppear { LayerHaptics.prepare() }
    }

    /// つぎの層に入った:カチ1回(最短 140ms)
    private func enter(_ index: Int) {
        layerTick.step(index)
    }

    private func open(_ target: LayerSheet) {
        LayerHaptics.light()
        sheet = target
    }
}

/// 層からひらくシート
enum LayerSheet: Identifiable, Equatable {
    case friend(HomeFriend)
    case invite
    case film(HomeFilmDay)
    case pick(HomeCalendarPick)

    var id: String {
        switch self {
        case .friend(let f): return "friend-\(f.id)"
        case .invite: return "invite"
        case .film(let d): return "film-\(d.key)"
        case .pick(let p): return "pick-\(p.day)"
        }
    }
}

// MARK: - 見出し

private struct LayerHeading: View {
    @Environment(\.palette) private var palette
    let title: String
    var note: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 22, weight: .heavy))
                .tracking(-0.03 * 22)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            if let note {
                Text(note)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, LayerRhythm.side)
    }
}

/// 余白のリズム(v13 ⑤):セクションの間 32・見出しと中身の間 12・左右 22
enum LayerRhythm {
    static let section: CGFloat = 32
    static let headingGap: CGFloat = 12
    static let side: CGFloat = 22
    /// 横の列の上下に、影が消えない分の余白(レイアウトには入れない)
    static let shadowRoom: CGFloat = 18
}

// MARK: - 1. ともだち

/// ともだち(v13 ⑤)。撮った = 色の輪(黄→橙→ピンク)+「● 撮った」/ まだ(今日)= 点線の輪 +「ノック」
/// (小さな丸薬・1人1日1回。押したら「ノック済」)/ おやすみ(夜)= 点線の輪 +「おやすみ」/ よぶ = 夕やけの丸 + 白い「+」。
private struct LayerFriendsBlock: View {
    let state: HomeState
    let data: HomeLayerData
    let actions: HomeLayerActions
    let onFriend: (HomeFriend) -> Void
    let onInvite: () -> Void

    @State private var knocks = KnockStore.shared
    @State private var focusedID: String?
    @State private var tick = ScrollTickHaptics()

    private var people: [HomeFriend] {
        var list: [HomeFriend] = []
        if let me = data.me { list.append(me) }
        if HomeLayerRules.showsFriends(state) { list += data.friends }
        return list
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LayerRhythm.headingGap) {
            LayerHeading(title: HomeLayerRules.friendsTitle(state))
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(people) { person in
                        LayerFriendCell(
                            friend: person,
                            status: HomeLayerRules.friendStatus(state: state, friend: person, knockedToday: knocks.hasKnocked(person.id, window: data.windowKey)),
                            onOpen: { onFriend(person) },
                            onKnock: {
                                LayerHaptics.knock()
                                actions.knock(person)
                            }
                        )
                        .id(person.id)
                    }
                    Button {
                        LayerHaptics.light()
                        onInvite()
                    } label: { LayerInviteIcon() }
                        .buttonStyle(PressScaleStyle(scale: 0.94, duration: 0.15))
                        .accessibilityLabel("ともだちをよぶ")
                        .id("invite")
                }
                .scrollTargetLayout()
                .padding(.horizontal, LayerRhythm.side)
                .padding(.vertical, LayerRhythm.shadowRoom)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focusedID, anchor: .leading)
            .padding(.vertical, -LayerRhythm.shadowRoom)
            .onChange(of: focusedID) { _, id in tick.step(id) }
        }
    }
}

/// 1人ぶん:アバター(直径 70)・名前(12.5pt 太字)・状態(撮った / ノック / ノック済 / まだ / おやすみ)
private struct LayerFriendCell: View {
    @Environment(\.palette) private var palette
    let friend: HomeFriend
    let status: HomeLayerRules.FriendStatus
    let onOpen: () -> Void
    let onKnock: () -> Void

    static let avatar: CGFloat = 70

    var body: some View {
        VStack(spacing: 7) {
            Button {
                LayerHaptics.light()
                onOpen()
            } label: {
                VStack(spacing: 6) {
                    ZStack {
                        if status == .shot {
                            Circle()
                                .strokeBorder(AngularGradient(colors: LayerFriendColors.shotRing + [LayerFriendColors.shotRing[0]], center: .center), lineWidth: 3)
                        } else {
                            Circle()
                                .strokeBorder(palette.ink.opacity(palette.isNight ? 0.42 : 0.36), style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
                        }
                        LayerAvatar(data: friend.avatarData, seed: friend.seed, name: friend.name)
                            .frame(width: Self.avatar, height: Self.avatar)
                    }
                    .frame(width: Self.avatar + 10, height: Self.avatar + 10)
                    Text(friend.isMe ? "わたし" : friend.name)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                        .frame(width: Self.avatar + 14)
                }
            }
            .buttonStyle(PressScaleStyle(scale: 0.94, duration: 0.15))
            .accessibilityLabel(accessibility)
            .accessibilityHint("くわしく見る")

            statusView
                .frame(height: 26)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .shot:
            Text("● 撮った")
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(LayerFriendColors.shotText(night: palette.isNight))
        case .canKnock:
            Button(action: onKnock) {
                Text("ノック")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(palette.bg)
                    .padding(.horizontal, 12)
                    .frame(height: 26)
                    .background(Capsule().fill(palette.ink))
                    .contentShape(Capsule().inset(by: -8))
            }
            .buttonStyle(PressScaleStyle(scale: 0.92, duration: 0.12))
            .accessibilityLabel("\(friend.name)に、ノックする")
            .accessibilityHint("文字なしで、トントンと知らせます。1日に1回")
        case .knocked:
            Text("ノック済")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(palette.groupAdd.note)
        case .notYet:
            Text("まだ")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(palette.groupAdd.note)
        case .resting:
            Text("おやすみ")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(palette.groupAdd.note)
        }
    }

    private var accessibility: String {
        var text = friend.isMe ? "わたし" : friend.name
        switch status {
        case .shot: text += "、撮った"
        case .canKnock, .notYet: text += "、まだ"
        case .knocked: text += "、まだ、ノックずみ"
        case .resting: text += "、おやすみ"
        }
        return text
    }
}

/// ともだちの色(テストでコントラストを確かめる)
enum LayerFriendColors {
    /// 撮った人の輪:黄 → 橙 → ピンク
    static let shotRing: [Color] = [Color(hex: "FFD23F"), Color(hex: "FF8A3D"), Color(hex: "FF5C8A")]
    /// 「撮った」の文字:昼 #C2410C / 夜 #FFB074(どちらも 4.5 以上)
    static func shotText(night: Bool) -> Color { Color(hex: night ? "FFB074" : "C2410C") }
}

/// よぶ:夕やけの丸 + 白い「+」
private struct LayerInviteIcon: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(LinearGradient(colors: GroupAddColors.sunset, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Image(systemName: "plus").font(.system(size: 22, weight: .bold)).foregroundStyle(palette.groupAdd.plus))
                .frame(width: LayerFriendCell.avatar, height: LayerFriendCell.avatar)
                .frame(width: LayerFriendCell.avatar + 10, height: LayerFriendCell.avatar + 10)
            Text("よぶ")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(palette.ink)
                .frame(width: LayerFriendCell.avatar + 14)
        }
    }
}

/// 写真があれば写真、なければ名前の頭文字
struct LayerAvatar: View {
    let data: Data?
    let seed: UUID
    let name: String
    /// v52:プロフィール編集で えらんだ色(UserProfile.avatarColorIndex)。nil なら id から決める
    var colorOverride: Int? = nil

    var body: some View {
        if let image = LayerImageCache.avatar(data, key: seed.uuidString) {
            Image(uiImage: image).resizable().scaledToFill().clipShape(Circle())
        } else {
            Circle()
                .fill(LinearGradient(colors: Self.colors(seed, override: colorOverride), startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    Text(String(name.prefix(1)))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
    }

    static let palettes: [[String]] = [
        ["FF9A4D", "FF5D73"], ["5DA9FF", "7A5CFF"], ["4CD6A8", "2E9BFF"],
        ["FFC93D", "FF7A3D"], ["C77DFF", "FF6FB5"], ["5FE0C8", "3DBF8A"],
    ]

    static func colors(_ seed: UUID, override: Int? = nil) -> [Color] {
        let index = override ?? (Int(seed.uuid.0) % palettes.count)
        return palettes[index % palettes.count].map { Color(hex: $0) }
    }
}

// MARK: - 2. 昨日のみんな

private struct LayerYesterdayBlock: View {
    let state: HomeState
    let now: Date
    let cards: [HomeYesterdayCard]
    let actions: HomeLayerActions

    @State private var board = LampBoard.shared
    @State private var sparkle: String?

    private var mode: HomeLayerRules.YesterdayMode { HomeLayerRules.yesterdayMode(state) }
    private var chosen: String? { mode == .open ? HomeThumb.chosen(in: cards, board: board) : nil }

    private static let tilts: [Double] = [-3, 2.2, -1.6, 2.8]

    var body: some View {
        VStack(alignment: .leading, spacing: LayerRhythm.headingGap) {
            LayerHeading(title: "昨日のみんな", note: mode == .open ? "👍は1日1回。数は出ません。" : nil)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 22) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    cell(card, tilt: Self.tilts[index % Self.tilts.count])
                }
            }
            .padding(.horizontal, LayerRhythm.side)
        }
    }

    @ViewBuilder
    private func cell(_ card: HomeYesterdayCard, tilt: Double) -> some View {
        if mode == .open {
            let isChosen = chosen == card.photoRecordName
            VStack(spacing: 0) {
                Button { actions.openYesterdayPhoto(card.groupID, card.id) } label: {
                    LayerPolaroid(card: card, locked: false, caption: card.authorName, lockText: "")
                }
                .buttonStyle(PressScaleStyle(scale: 0.97, duration: 0.15))
                .accessibilityLabel("\(card.authorName)の昨日の1枚をひらく")
                thumbButton(card, isChosen: isChosen)
                    .padding(.top, -2)
            }
            .rotationEffect(.degrees(tilt))
            .opacity(chosen != nil && !isChosen ? 0.55 : 1)
            .animation(.easeOut(duration: 0.3), value: chosen)
        } else {
            Button {
                LayerHaptics.softDouble()
                actions.toast(HomeLayerRules.lockToast(state))
            } label: {
                LayerPolaroid(card: card, locked: true, caption: "???", lockText: HomeLayerRules.lockCaption(state, tag: card.tag))
            }
            .buttonStyle(PressScaleStyle(scale: 0.97, duration: 0.15))
            .rotationEffect(.degrees(tilt))
            .accessibilityLabel("まだ見られない1枚。\(HomeLayerRules.lockCaption(state, tag: card.tag))")
            .accessibilityHint(HomeLayerRules.lockToast(state))
        }
    }

    private func thumbButton(_ card: HomeYesterdayCard, isChosen: Bool) -> some View {
        Button {
            switch HomeThumb.choose(card, in: cards, board: board, now: now) {
            case .first:
                LayerHaptics.medium()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { sparkle = card.id }
                actions.toast("👍 を置きました")
            case .changed:
                LayerHaptics.light()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { sparkle = card.id }
            case .same:
                LayerHaptics.light()
            case .closed:
                LayerHaptics.softDouble()
                actions.toast("👍 は、24:00 までです")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { if sparkle == card.id { withAnimation(.easeOut(duration: 0.3)) { sparkle = nil } } }
            Task { await actions.flushThumbs() }
        } label: {
            Text("👍")
                .font(.system(size: 20))
                .frame(width: 46, height: 46)
                .background(Circle().fill(isChosen ? Color(hex: "FFE7C2") : Color.white.opacity(0.9)))
                .overlay(Circle().strokeBorder(isChosen ? Color(hex: "FF9A4D") : Color.black.opacity(0.08), lineWidth: isChosen ? 2 : 1))
                .shadow(color: isChosen ? Color(hex: "FF9A4D").opacity(0.55) : .clear, radius: 10)
                .overlay { if sparkle == card.id { LayerSparkle() } }
        }
        .buttonStyle(PressScaleStyle(scale: 0.9, duration: 0.12))
        .accessibilityLabel(isChosen ? "\(card.authorName)の1枚に、👍をえらんでいます" : "\(card.authorName)の1枚に👍")
        .accessibilityHint("1日に1回。ほかの写真を押すと、えらびなおせます")
    }
}

/// 押すと光る、小さなキラキラ
private struct LayerSparkle: View {
    @State private var spread = false

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(hex: "FFB347"))
                    .offset(y: spread ? -30 : -8)
                    .rotationEffect(.degrees(Double(i) * 60))
                    .opacity(spread ? 0 : 1)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.7)) { spread = true } }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// ポラロイド1枚(写真 or モザイク + 下の文字)
private struct LayerPolaroid: View {
    let card: HomeYesterdayCard
    let locked: Bool
    let caption: String
    let lockText: String

    var body: some View {
        VStack(spacing: 6) {
            Color.clear
                .aspectRatio(0.8, contentMode: .fit)
                .overlay {
                    if locked {
                        MosaicView(tiny: card.mosaicTiny, key: card.mosaicKey)
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(6)
                            }
                            .overlay(alignment: .bottomLeading) {
                                if !lockText.isEmpty {
                                    Text(lockText)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(.black.opacity(0.35)))
                                        .padding(6)
                                }
                            }
                    } else {
                        LayerPhoto(data: card.imageData, key: card.id, fallbackTiny: card.mosaicTiny)
                    }
                }
                .clipped()
            Text(caption)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: "3A3A3C"))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .chicPrint(side: 7, bottom: 10)
    }
}

/// 写真(縮めてから出す)。読めるまではモザイク
private struct LayerPhoto: View {
    let data: Data?
    let key: String
    let fallbackTiny: Data?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                MosaicView(tiny: fallbackTiny, key: key)
            }
        }
        .task(id: key) {
            guard let data else { return }
            image = await LayerImageCache.photo(data, key: key)
        }
    }
}

/// 層の画像の置き場(アイコン・写真を何度もデコードしない)
@MainActor
enum LayerImageCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func avatar(_ data: Data?, key: String) -> UIImage? {
        guard let data else { return nil }
        let k = "a-\(key)-\(data.count)" as NSString
        if let hit = cache.object(forKey: k) { return hit }
        guard let image = downsample(data, maxPixel: 180) else { return nil }
        cache.setObject(image, forKey: k)
        return image
    }

    static func photo(_ data: Data, key: String, maxPixel: CGFloat = 700) async -> UIImage? {
        let k = "p-\(key)-\(Int(maxPixel))" as NSString
        if let hit = cache.object(forKey: k) { return hit }
        let image = await Task.detached(priority: .userInitiated) { downsample(data, maxPixel: maxPixel) }.value
        if let image { cache.setObject(image, forKey: k) }
        return image
    }

    nonisolated static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - 3. 昨日の世界のことば

private struct LayerWordsBlock: View {
    let state: HomeState
    let shotsToday: Int
    let words: [String]
    let isActive: Bool
    let actions: HomeLayerActions

    @Environment(\.palette) private var palette

    private var top: [String] { Array(words.prefix(HomeLayerRules.topWordCount)) }
    private var rest: [String] { Array(words.dropFirst(HomeLayerRules.topWordCount)) }

    var body: some View {
        VStack(alignment: .leading, spacing: LayerRhythm.headingGap) {
            LayerHeading(title: "昨日の世界のことば")
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(top.enumerated()), id: \.offset) { index, word in
                    Button { tap(word) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(String(format: "%02d", index + 1))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(palette.sub)
                            Text("#\(word)")
                                .font(.system(size: Self.size(index), weight: index == 0 ? .heavy : .bold))
                                .tracking(-0.03 * Self.size(index))
                                .foregroundStyle(palette.ink)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressScaleStyle(scale: 0.98, duration: 0.12))
                    .accessibilityLabel("\(index + 1)番目のことば、\(word)")
                }
            }
            .padding(.horizontal, LayerRhythm.side)

            if !rest.isEmpty {
                let rows = MarqueeMath.rows(rest, rowCount: 2)
                VStack(spacing: 10) {
                    ForEach(0..<rows.count, id: \.self) { row in
                        LayerMarquee(words: rows[row], reversed: row == 1, seconds: row == 0 ? 42 : 36, isActive: isActive, onTap: tap)
                    }
                }
            }
        }
    }

    private static func size(_ index: Int) -> CGFloat {
        switch index {
        case 0: return 34
        case 1: return 24
        default: return 19
        }
    }

    private func tap(_ word: String) {
        LayerHaptics.light()
        if HomeLayerRules.wordsUnlocked(state: state, shotsToday: shotsToday) {
            actions.openWord(word)
        } else {
            actions.toast(HomeLayerRules.wordsLockedToast)
        }
    }
}

/// 流れるタグ1列。長押しのあいだ止まる。視差を減らすときは動かない。
private struct LayerMarquee: View {
    let words: [String]
    let reversed: Bool
    let seconds: Double
    let isActive: Bool
    let onTap: (String) -> Void

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var holding = false
    @State private var setWidth: CGFloat = 0
    @State private var pausedTotal: TimeInterval = 0
    @State private var pausedAt: Date?
    @State private var phase = Double.random(in: 0..<1)

    private var moving: Bool { isActive && !reduceMotion && !holding }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !moving)) { context in
            let date = pausedAt ?? context.date
            let x = moving || pausedAt != nil
                ? MarqueeMath.offset(time: date.timeIntervalSinceReferenceDate - pausedTotal, secondsPerLoop: seconds, phase: phase, setWidth: setWidth, reversed: reversed)
                : 0
            // 重ねて置く(流れる列の幅が、層の幅を押し広げないように)
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .overlay(alignment: .leading) {
                    HStack(spacing: 8) {
                        chips.onGeometryChange(for: CGFloat.self) { $0.size.width + 8 } action: { setWidth = $0 }
                        if !reduceMotion { chips.accessibilityHidden(true) }
                    }
                    .padding(.leading, reduceMotion ? 20 : 0)
                    .offset(x: reduceMotion ? 0 : x)
                }
        }
        .frame(height: 38)
        .clipped()
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.3)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .updating($holding) { value, state, _ in
                    if case .second(true, _) = value { state = true }
                }
        )
        .onChange(of: moving) { _, isMoving in
            if isMoving {
                if let pausedAt { pausedTotal += Date().timeIntervalSince(pausedAt) }
                pausedAt = nil
            } else if pausedAt == nil {
                pausedAt = Date()
            }
        }
    }

    private var chips: some View {
        HStack(spacing: 8) {
            ForEach(words, id: \.self) { word in
                Button { onTap(word) } label: {
                    Text("#\(word)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(Capsule().fill(palette.fill))
                        .overlay(Capsule().strokeBorder(palette.line, lineWidth: 1))
                }
                .buttonStyle(PressScaleStyle(scale: 0.95, duration: 0.12))
                .accessibilityLabel("ことば、\(word)")
            }
        }
        .fixedSize()
    }
}

// MARK: - 4. じぶん

private struct LayerSelfBlock: View {
    let state: HomeState
    let now: Date
    let film: [HomeFilmDay]
    let picks: [HomeCalendarPick]
    let onFilm: (HomeFilmDay) -> Void
    let onShoot: () -> Void
    let onPick: (HomeCalendarPick) -> Void
    let onEmptyDay: () -> Void

    @Environment(\.palette) private var palette
    @State private var showsMonth = false

    var body: some View {
        VStack(alignment: .leading, spacing: LayerRhythm.headingGap) {
            LayerHeading(title: "じぶん")
            HStack(spacing: 6) {
                segment("7日のフィルム", selected: !showsMonth) { showsMonth = false }
                segment("今月", selected: showsMonth) { showsMonth = true }
            }
            .padding(4)
            .background(Capsule().fill(palette.fill))
            .padding(.horizontal, LayerRhythm.side)

            if showsMonth {
                LayerMonthCalendar(now: now, picks: picks, onPick: onPick, onEmptyDay: onEmptyDay)
                    .padding(.horizontal, LayerRhythm.side)
                    .transition(.opacity)
            } else {
                LayerFilmStrip(film: film, onFilm: onFilm, onShoot: onShoot)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: showsMonth)
    }

    /// 丸薬型。選んでいるほうが黒(夜は白)のベタ
    private func segment(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard !selected else { return }
            LayerHaptics.selection()
            action()
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(selected ? palette.bg : palette.ink)
                .padding(.horizontal, 16)
                .frame(minHeight: 36)
                .background(Capsule().fill(selected ? palette.ink : Color.clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 7日のフィルム(v13 ⑥)。暗い帯(昼夜とも)の上下に、フィルムの穴(角丸の四角)の列。
/// コマ:幅 112 × 高さ 148、角丸 6。上に日付(橙・等幅)、下にラベル(きょう・きのう…)と「あと◯日」。
/// 古いコマほど少しずつうすく(1.0 → 0.5)。
private struct LayerFilmStrip: View {
    let film: [HomeFilmDay]
    let onFilm: (HomeFilmDay) -> Void
    let onShoot: () -> Void

    @State private var focusedID: String?
    @State private var tick = ScrollTickHaptics()

    static let frameSize = CGSize(width: 112, height: 148)
    static let band = Color(hex: "141417")
    static let stamp = Color(hex: "FF8A3D")
    static let text = Color(hex: "F4F4F6")
    static let note = Color(hex: "B4B4BC")

    var body: some View {
        VStack(spacing: 0) {
            Sprockets()
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(film) { day in
                        Button {
                            if day.kind == .empty {
                                LayerHaptics.light()
                                onShoot()
                            } else {
                                if case .photo = day.kind { LayerHaptics.light() }
                                onFilm(day)
                            }
                        } label: { frame(day) }
                            .buttonStyle(PressScaleStyle(scale: 0.96, duration: 0.12))
                            .disabled(day.kind == .rest)
                            .accessibilityLabel(label(day))
                            .id(day.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, LayerRhythm.side)
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focusedID, anchor: .leading)
            .onChange(of: focusedID) { _, id in tick.step(id) }
            Sprockets()
        }
        .background(Self.band)
    }

    private func frame(_ day: HomeFilmDay) -> some View {
        let fade = HomeLayerRules.filmOpacity(ago: day.ago)
        return ZStack {
            switch day.kind {
            case .photo(let data):
                if let data, let image = LayerImageCache.avatar(data, key: "film-\(day.key)") {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Color(hex: "3A2A22")
                }
            case .developing:
                DevelopingFrame(compact: true)
            case .rest:
                RestFrame()
            case .empty:
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Self.note.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    VStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 18, weight: .bold))
                        Text("きょう撮る").font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Self.text)
                }
            }
        }
        .frame(width: Self.frameSize.width, height: Self.frameSize.height)
        .overlay(alignment: .top) { caption(top: true, day: day) }
        .overlay(alignment: .bottom) { caption(top: false, day: day) }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .opacity(fade)
    }

    /// 上:日付「10.03」(橙・等幅)/ 下:ラベルと「あと◯日」。写真の上でも読めるよう、うすい影の帯
    @ViewBuilder
    private func caption(top: Bool, day: HomeFilmDay) -> some View {
        let onPhoto: Bool = { if case .photo = day.kind { return true } else { return false } }()
        let onMilk = day.kind == .developing
        let ink = onMilk ? DevelopingFrame.ink : Self.text
        Group {
            if top {
                Text(Self.stampText(day.date))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(onMilk ? Color(hex: "9A3A0A") : Self.stamp)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(HomeLayerRules.filmLabel(ago: day.ago))
                        .font(.system(size: 11, weight: .bold))
                    Spacer(minLength: 2)
                    if day.kind != .empty && day.kind != .rest {
                        Text("あと\(HomeLayerRules.filmDaysLeft(ago: day.ago))日")
                            .font(.system(size: 10, design: .monospaced))
                    }
                }
                .foregroundStyle(ink)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            if onPhoto {
                LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: top ? .top : .bottom, endPoint: top ? .bottom : .top)
            }
        }
        .accessibilityHidden(true)
    }

    private func label(_ day: HomeFilmDay) -> String {
        let date = HomeLayerRules.filmLabel(ago: day.ago)
        switch day.kind {
        case .photo: return "\(date)の1枚。あと\(HomeLayerRules.filmDaysLeft(ago: day.ago))日のこります"
        case .developing: return "\(date)。現像中。あしたの朝に、仕上がります"
        case .empty: return "\(date)。まだ撮っていません。押すと、撮ります"
        case .rest: return "\(date)。おやすみ"
        }
    }

    /// 「10.03」
    static func stampText(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.month, .day], from: date)
        return String(format: "%02d.%02d", c.month ?? 0, c.day ?? 0)
    }
}

/// フィルムの穴(角丸の四角)の列
private struct Sprockets: View {
    var body: some View {
        Canvas { context, size in
            let w: CGFloat = 9, h: CGFloat = 6, gap: CGFloat = 9
            var x: CGFloat = 6
            while x < size.width {
                let rect = CGRect(x: x, y: (size.height - h) / 2, width: w, height: h)
                context.fill(Path(roundedRect: rect, cornerRadius: 1.8), with: .color(Color.white.opacity(0.16)))
                x += w + gap
            }
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }
}

/// 撮らなかった日:うすい斜め線の面 + 月 +「おやすみ」(責めない言葉)
private struct RestFrame: View {
    var body: some View {
        ZStack {
            Color(hex: "1E1E23")
            Canvas { context, size in
                var path = Path()
                var x: CGFloat = -size.height
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    x += 9
                }
                context.stroke(path, with: .color(Color.white.opacity(0.05)), lineWidth: 1)
            }
            VStack(spacing: 6) {
                Image(systemName: "moon.fill").font(.system(size: 16, weight: .semibold))
                Text("おやすみ").font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(LayerFilmStrip.note)
        }
    }
}

/// 今月のカレンダー。グループの一枚に選ばれた日が光る(1年のこる)。‹ › で先月へ
private struct LayerMonthCalendar: View {
    let now: Date
    let picks: [HomeCalendarPick]
    let onPick: (HomeCalendarPick) -> Void
    let onEmptyDay: () -> Void

    @Environment(\.palette) private var palette
    @State private var monthsBack = 0
    private static let maxBack = 11

    private var calendar: Calendar { Calendar.current }

    private var month: Date {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        return calendar.date(byAdding: .month, value: -monthsBack, to: start) ?? start
    }

    var body: some View {
        let byDay = Dictionary(picks.map { ($0.day, $0) }, uniquingKeysWith: { a, _ in a })
        VStack(spacing: 12) {
            HStack {
                arrow("chevron.left", enabled: monthsBack < Self.maxBack, label: "前の月") { monthsBack += 1 }
                Spacer()
                Text(Self.title(month))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                arrow("chevron.right", enabled: monthsBack > 0, label: "次の月") { monthsBack -= 1 }
            }
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol).font(.system(size: 10, weight: .medium)).foregroundStyle(palette.sub)
                        .accessibilityHidden(true)
                }
                ForEach(cells, id: \.self) { date in
                    if let date {
                        dayCell(date, pick: byDay[ExposureDayStore.dayKey(for: date)])
                    } else {
                        Color.clear.frame(height: 38).accessibilityHidden(true)
                    }
                }
            }
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = ["日", "月", "火", "水", "木", "金", "土"]
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private var cells: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: month)
        let lead = (weekday - calendar.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: lead)
        for day in range {
            result.append(calendar.date(byAdding: .day, value: day - 1, to: month))
        }
        return result
    }

    private func dayCell(_ date: Date, pick: HomeCalendarPick?) -> some View {
        let day = calendar.component(.day, from: date)
        let isFuture = date > now
        return Button {
            if let pick { onPick(pick) } else if !isFuture { onEmptyDay() }
        } label: {
            Text("\(day)")
                .font(.system(size: 13, weight: pick == nil ? .regular : .bold, design: .rounded))
                .foregroundStyle(pick != nil ? Color(hex: "1A1A22") : palette.ink.opacity(isFuture ? 0.25 : 0.7))
                .frame(maxWidth: .infinity, minHeight: 38)
                .background {
                    if pick != nil {
                        Circle()
                            .fill(RadialGradient(colors: [Color(hex: "FFE2B0"), Color(hex: "FFB36B")], center: .center, startRadius: 0, endRadius: 20))
                            .shadow(color: Color(hex: "FFB36B").opacity(0.7), radius: 8)
                            .frame(width: 34, height: 34)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(pick != nil ? "\(day)日。グループの一枚に選ばれた日" : "\(day)日")
    }

    private func arrow(_ icon: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button {
            LayerHaptics.light()
            withAnimation(.easeOut(duration: 0.2)) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.ink.opacity(enabled ? 1 : 0.25))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private static func title(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: date)
        return "\(c.year ?? 0)年 \(c.month ?? 0)月"
    }
}

// MARK: - 現像中のコマ(Home のフィルム・Profile のチェキで共通)

/// 「現像中」のコマ:乳白色のもや(ゆっくり濃さが変わる)+ 砂時計 +「あしたの朝」。
/// 空白にしない。写真そのものは読みこまない(仕上がるまで、端末の画面に出さない)。
struct DevelopingFrame: View {
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let milk = Color(hex: "ECE6DC")
    static let ink = Color(hex: "4A3A2C")

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            // 5秒で、もやが濃く → うすく(視差を減らすときは止める)
            let breath = reduceMotion ? 0.5 : (1 - cos(t * 2 * .pi / 5)) / 2
            ZStack {
                Self.milk
                RadialGradient(colors: [Color.white.opacity(0.55 * breath), Color.white.opacity(0)], center: .init(x: 0.4, y: 0.35), startRadius: 0, endRadius: compact ? 90 : 180)
                RadialGradient(colors: [Color(hex: "D9CFC0").opacity(0.6 * (1 - breath)), .clear], center: .init(x: 0.7, y: 0.8), startRadius: 0, endRadius: compact ? 80 : 160)
                VStack(spacing: compact ? 6 : 12) {
                    Image(systemName: "hourglass")
                        .font(.system(size: compact ? 17 : 28, weight: .semibold))
                    Text("あしたの朝")
                        .font(.system(size: compact ? 11.5 : 15, weight: .bold))
                }
                .foregroundStyle(Self.ink)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("現像中。あしたの朝に、仕上がります")
    }
}

// MARK: - 5. おわり

private struct LayerEndBlock: View {
    let state: HomeState
    @Environment(\.palette) private var palette

    var body: some View {
        let lines = HomeLayerRules.endLines(state)
        VStack(spacing: 10) {
            Text(lines.title)
                .font(.system(size: 26, weight: .heavy))
                .tracking(-0.04 * 26)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(lines.body)
                .font(.system(size: 13))
                .foregroundStyle(palette.sub)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        // 月のぶんの余白(月は下に固定なので、その上で止まる)+ 月の光がとけるような白いグラデーション
        .padding(.bottom, MoonLayout.visibleHeight + 120)
        .background(alignment: .bottom) {
            LinearGradient(colors: [.clear, Color.white.opacity(palette.isNight ? 0.12 : 0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 260)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
