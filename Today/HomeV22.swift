import SwiftUI

// v22 B:Home は v17 の形のまま 仕上げる(見本:Docs/Mocks/later_v22.html の ホーム。390×844 の座標)。
// 上から:ヘッダー(〜150)→ 世界の光 = ガラスの球(高さ 254)→ 見出し(2行・30pt)→ 今日のカード(90)→ グループ(17pt + タイル 80)。
// 下の月は TodayView(上のふち 742)。スクロールした先は 今日の film → 使いかたガイド(初回だけ)。
// 数は ぜんぶ FilmCounter。

enum HomeV22Rules {
    struct Headline: Equatable {
        let first: String
        let second: String
        /// 2行目で 手書きの丸で かこむ言葉
        let circled: String?
        let sub: String
    }

    /// 状態ごとの見出し(v21 D-3 と同じ文)。initial = 初回(はじめての 9:00 まで)
    static func headline(used: Int, initial: Bool) -> Headline {
        switch min(3, max(0, used)) {
        case 0:
            return initial
                ? Headline(first: "はじめまして。", second: "今日を撮ってみよう。", circled: "撮って", sub: "あしたの朝に、今日の1枚がひらきます。")
                : Headline(first: "おはよう。", second: "今日も、撮ってみよう。", circled: "撮って", sub: "あしたの朝に、今日の1枚がひらきます。")
        case 1: return Headline(first: "1こま、撮りました。", second: "今日は、あと2こま。", circled: "2", sub: "あしたの朝 9:00 に、まとめてひらきます。")
        case 2: return Headline(first: "2こま、撮りました。", second: "今日は、あと1こま。", circled: "1", sub: "あしたの朝 9:00 に、まとめてひらきます。")
        default: return Headline(first: "3こま、撮りました。", second: "今日は、ここまで。", circled: nil, sub: "あしたの 9:00 に、ひらきます。")
        }
    }

    /// 今日のカードの文
    static func card(used: Int, initial: Bool) -> (title: String, sub: String) {
        switch min(3, max(0, used)) {
        case 0: return (initial ? "最初の1枚に、なります" : "今日の 1こま目", "0 / 3 ・ まだ からっぽ")
        case 3: return ("3こま、預けました", "あしたの 9:00 に、まとめて ひらきます")
        default: return ("今日の1枚を、預けました", "9:00 まで ひみつ")
        }
    }

    /// 9:00 までの時間「3:44」
    static func untilNine(now: Date, calendar: Calendar = .current) -> String {
        let next = PhotoDevelop.developDate(takenAt: now, calendar: calendar)
        let m = max(0, Int(next.timeIntervalSince(now) / 60))
        return "\(m / 60):\(String(format: "%02d", m % 60))"
    }
}

/// 初回(アプリを入れた日から、はじめての 9:00 まで)。端末に保存する
enum HomeFirstDay {
    private static let key = "home.firstOpenedAt"

    static func firstOpenedAt(now: Date = Date(), defaults: UserDefaults = .standard) -> Date {
        if let date = defaults.object(forKey: key) as? Date { return date }
        defaults.set(now, forKey: key)
        return now
    }

    /// はじめての 9:00 が まだ来ていない
    static func isInitial(now: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = .standard) -> Bool {
        let first = firstOpenedAt(now: now, defaults: defaults)
        return now < PhotoDevelop.developDate(takenAt: first, calendar: calendar)
    }
}

// MARK: - v32 まんなかの 丸 = 万能ボタン(見本:later_v32.html の .orb)
// まんなかに「いま いちばんの こと」を 1つ。ほかは まわりの 4つの ステッカーに。
// 見た目と 行き先だけ。保存・解禁・投稿・グループ・招待の 処理は 今の まま(ChicHomeView が つなぐ)。

/// まんなか・まわりに 出せる こと
enum HomeOrbAction: String, CaseIterable, Sendable {
    case join, shoot, chat, yesterday, develop, newGroup, mondo, friends
    /// v61:四すみ固定の4つめ(右上)。裏側は 既存の グループ作成/CKShare招待を そのまま 使う(見た目だけ)。
    case trip

    /// まわりの 小さい ラベル(英語のまま)
    var label: String {
        switch self {
        case .join: "JOIN"
        case .shoot: "SHOOT"
        case .chat: "CHAT"
        case .yesterday: "YESTERDAY"
        case .develop: "DEVELOP"
        case .newGroup: "NEW GROUP"
        case .mondo: "MONDO"
        case .friends: "FRIENDS"
        case .trip: "TRIP"
        }
    }

    /// まんなかの 大きい 字(英語のまま)
    var title: String {
        switch self {
        case .newGroup: "New group"
        case .trip: "Trip"
        default: label.prefix(1) + label.dropFirst().lowercased()
        }
    }

    var symbol: String {
        switch self {
        case .join: "arrow.right"
        case .shoot: "camera"
        case .chat: "bubble.left"
        case .yesterday: "photo.on.rectangle"
        case .develop: "clock"
        case .newGroup: "person.badge.plus"
        case .mondo: "globe"
        case .friends: "person.2"
        case .trip: "bag.fill"
        }
    }

    /// まわりの 丸の 色(v42:ぜんぶ クリーム。いま おすすめの 1つだけ 緑 ― satellite(_:index:) で 先頭だけ 上書き)
    var tint: String { "F5F0E8" }
}

enum HomeOrbRules {
    struct Input: Equatable {
        var hasInvite = false
        var used = 0
        var remaining = 3
        var hasUnread = false
        var hasGroups = false
        var openedYesterday = 0
    }

    struct Plan: Equatable {
        let center: HomeOrbAction
        let satellites: [HomeOrbAction]
        /// 3こま 撮りきって、きのうの 写真も ない(「また あした」・うすく)
        let done: Bool
    }

    /// まんなか:招待 → 今日 0枚 → 新しい メッセージ → きのう
    static func center(_ input: Input) -> HomeOrbAction {
        if input.hasInvite { return .join }
        if input.used == 0 { return .shoot }
        if input.hasUnread { return .chat }
        return .yesterday
    }

    /// まわり:撮る → 現像 → きのう → チャット → New group → Mondo → Friends(まんなか 以外の 先頭 4つ)
    /// v61 §8:四すみは 状況で 入れかえない。固定 4つ(左上 Yesterday・右上 Trip・左下 Mondo・右下 Friends)。
    /// Chat は Friends の 中から、グループを つくる 入口は Trip の「New trip」に 一本化(四すみからは 消す)。
    static func satellites(_ input: Input, center: HomeOrbAction) -> [HomeOrbAction] {
        [.yesterday, .trip, .mondo, .friends]
    }

    static func plan(_ input: Input) -> Plan {
        let c = center(input)
        return Plan(center: c, satellites: satellites(input, center: c),
                    done: c == .yesterday && input.remaining == 0 && input.openedYesterday == 0)
    }

    /// まだ ひらけない(今日 0枚 の きのう・Mondo)
    static func isLocked(_ action: HomeOrbAction, used: Int) -> Bool {
        used == 0 && (action == .yesterday || action == .mondo)
    }

    /// v61 §8:右上の 赤い 点(Friends に 申請が とどいて いる とき)。
    /// 注:まだ 専用の「申請 件数」が この Input に 無いので、既存の hasUnread を 近似として 流用している。
    static func hasDot(_ action: HomeOrbAction, input: Input) -> Bool {
        switch action {
        case .chat: input.hasUnread
        case .newGroup: !input.hasGroups
        case .friends: input.hasUnread
        default: false
        }
    }

    /// まんなかの 下の 小さい 字(名前は ChicHomeView から)
    static func sub(_ action: HomeOrbAction, input: Input, name: String?, done: Bool) -> String {
        if done { return "OPENS 9:00" }
        switch action {
        case .join, .chat: return (name ?? "").uppercased()
        case .shoot: return "\(input.remaining) LEFT"
        case .yesterday: return "\(input.openedYesterday) OPENED"
        default: return ""
        }
    }

    /// 下の 黒い ピル
    static func pill(_ action: HomeOrbAction) -> String {
        switch action {
        case .shoot: "TAP"
        case .join: "JOIN"
        default: "OPEN"
        }
    }

    /// まわりの 文字の 輪(2回 くりかえして 一周)
    static func ringText(now: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.month, .day], from: now)
        let date = String(format: "%02d.%02d", c.month ?? 1, c.day ?? 1)
        let once = "LATER — TODAY — YESTERDAY — 3 SHOTS A DAY — \(date) — "
        return once + once
    }

    /// 3本の フィルムの 弧:のこり = 橙(i >= used)
    static func arcIsRemaining(_ index: Int, used: Int) -> Bool { index >= min(3, max(0, used)) }

    /// まわりの 位置(中心から。左上・右上・左下・右下)。
    /// v61 §15:端に 寄せる ものは「端からの 距離」で 決める(横は 幅に 応じて 動く)。縦(y)は 見本 A01/A02 に あわせた 固定値。
    /// 既定の `width` 引数(390)は テスト・古い呼び出しの ための 後方互換。実機では 実際の 幅を 渡す。
    static func satelliteOffsets(width w: CGFloat = width) -> [CGSize] {
        let half = w / 2 - 62
        return [CGSize(width: -half, height: -232), CGSize(width: half, height: -232),
                CGSize(width: -half, height: 218), CGSize(width: half, height: 218)]
    }

    static let width: CGFloat = 390

    /// まわりの 1つが しめる 場所(丸 50 + 影 + 下の 字。浮き沈み 4pt ぶん 広め)。文字の輪は ここでは 消える
    static func satelliteHole(_ action: HomeOrbAction, index i: Int, width w: CGFloat = width) -> CGRect {
        let offsets = satelliteOffsets(width: w)
        let o = offsets[min(max(i, 0), offsets.count - 1)]
        let labelWidth = CGFloat(action.label.count) * (8 * 0.6 + 8 * 0.14) + 10
        let half = max(29, labelWidth / 2 + 2)
        // ボタンの 中心 = o.y + 4.5、丸の 上 = 中心 - 34.5、字の 下 = 中心 + 34.5
        return CGRect(x: o.width - half, y: o.height + 4.5 - 34.5 - 6, width: half * 2, height: 69 + 6 + 4)
    }
}

struct HomeGlassOrb: View {
    let input: HomeOrbRules.Input
    let dateText: String
    let isActive: Bool
    /// 招待・チャットの グループ名
    var centerName: String?
    /// きのうの 自分の 1枚(★ か 最初に ひらいた こま)
    var yesterdayPhoto: LaterPhoto?
    /// テスト用(画像を 直接)
    var yesterdayImage: UIImage?
    /// 登場の はじまり(nil = もう出ている)
    var introStart: Date?
    let onCenter: (HomeOrbAction) -> Void
    let onSatellite: (HomeOrbAction) -> Void
    var onLocked: () -> Void = {}
    /// v61:Trip ページの 中身(既存の グループ)。裏側は いまの CloudKit グループ作成/CKShare招待を そのまま 使う。
    var groupSummaries: [GroupSummary] = []
    var canCreateGroup = true
    var onCreateGroup: () -> Void = {}
    var onJoinGroup: () -> Void = {}
    var onSelectGroup: (UUID) -> Void = { _ in }
    /// v61:「じぶんの きのう」を ひらく(既存の YesterdayViewer(scope: .mine))。Mondo(= 世界の きのう)とは 別の 行き先。
    var onOpenYesterday: () -> Void = {}
    /// v35:主役(HomeOrbHero)の 中で 使う ときは、まわりの 丸を 少し 小さく(1.42倍の 中で 画面から はみ出しすぎない ように)
    var compactSatellites = false
    /// v35:四すみの ステッカーは HomeOrbHero が 持つので、ここでは 出さない
    var showsStickers = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.palette) private var palette
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var pressed = false
    @State private var shutter = 0
    @State private var bounce = 0
    @State private var swap = 0
    @State private var satPressed: HomeOrbAction?
    @State private var satBounce: [HomeOrbAction: Int] = [:]
    /// v61 §9:0 Camera / 1 Friends / 2 Trip / 3 Mondo / 4 Yesterday
    @State private var pageIndex = 0

    /// v54:写ルンですの 本体(見本 A01 / A02)。幅 390・高さ 560。
    static let height: CGFloat = 560
    static let width: CGFloat = 390

    private var plan: HomeOrbRules.Plan { HomeOrbRules.plan(input) }
    private var running: Bool { isActive && !reduceMotion && !lowPower }
    private var intro: Bool { !reduceMotion && introStart.map { Date().timeIntervalSince($0) < 1.6 } ?? false }
    /// はじめての 合図(ChicHomeView から)
    var hintEligible = false

    var body: some View {
        // v61 §15:実機の 幅(375 / 390 / 402 …)を 測って、端に 寄せる ものを そこから 計算する。
        // 中まんなかの もの(レンズ・リング)は 固定サイズの まま(w に よらない)。
        GeometryReader { geo in
            let w = geo.size.width
            TabView(selection: $pageIndex) {
                cameraPage(width: w).tag(0)
                secondaryPage(.friends, index: 1, width: w) { onSatellite(.friends) }
                    .tag(1)
                tripPage(width: w).tag(2)
                secondaryPage(.mondo, index: 3, width: w) { onSatellite(.mondo) }
                    .tag(3)
                secondaryPage(.yesterday, index: 4, width: w) { onOpenYesterday() }
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(width: w, height: Self.height)
            .onChange(of: pageIndex) { _, _ in Haptics.play(.sel) }
            // v61 §9:端(0・4)を こえて ひっぱると ゴム。ネイティブ TabView には ゴムの 物理が 無いので、
            // 代わりに 端で 大きく 引いた ドラッグを 横取りせず 観測して soft だけ 鳴らす(簡易版。実機で 要確認)。
            .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.2 else { return }
                if (pageIndex == 0 && value.translation.width > 40) || (pageIndex == 4 && value.translation.width < -40) {
                    Haptics.play(.soft)
                }
            })
            .overlay(alignment: .bottom) { pageDock.padding(.bottom, 8) }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
            .frame(width: w)
        }
        .frame(height: Self.height)
    }

    // MARK: ページ 0・カメラの カード(いままでの 中身。四すみの ボタンは ここだけに ある)

    private func cameraPage(width w: CGFloat) -> some View {
        let plan = plan
        return TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !running && !intro)) { context in
            let t = running ? context.date.timeIntervalSinceReferenceDate : 0
            let reveal = Self.reveal(now: context.date, start: reduceMotion ? nil : introStart)
            ZStack {
                cameraBody
                stripStripe
                aura(t: t)
                // 外の文字の輪(200秒で一周)。まわりの 4つの ところだけ 字を 消す
                HomeRingText(text: HomeOrbRules.ringText(now: Date()), radius: 172,
                             rotation: (t.truncatingRemainder(dividingBy: 200) / 200) * 2 * .pi,
                             holes: plan.satellites.enumerated().map { HomeOrbRules.satelliteHole($0.element, index: $0.offset, width: w) })
                    .opacity(reveal * 0.72)
                ripples(t: t)
                filmArcsAndDisc(plan: plan, t: t)
                lens(plan: plan, t: t, reveal: reveal)
                // シャッターの 白い光
                Circle()
                    .fill(RadialGradient(stops: [.init(color: .white, location: 0.3), .init(color: .white.opacity(0), location: 0.7)], center: .center, startRadius: 0, endRadius: 92))
                    .frame(width: 184, height: 184)
                    .keyframeAnimator(initialValue: FlashFrame(), trigger: shutter) { content, f in
                        content.opacity(f.opacity).scaleEffect(f.scale)
                    } keyframes: { _ in
                        KeyframeTrack(\.opacity) {
                            LinearKeyframe(0, duration: 0.001); LinearKeyframe(0.95, duration: 0.125); LinearKeyframe(0, duration: 0.295)
                        }
                        KeyframeTrack(\.scale) { LinearKeyframe(0.6, duration: 0.001); LinearKeyframe(1.6, duration: 0.42) }
                    }
                    .allowsHitTesting(false)
                // ステッカー(星・波線・花・点)
                if showsStickers { stickers(t: t, reveal: reveal) }
                // 四すみの ボタン(押すと その ページへ スライド。ロック中は スライドしない)
                ForEach(Array(plan.satellites.enumerated()), id: \.element) { i, action in
                    satellite(action, index: i, t: t)
                        .offset(HomeOrbRules.satelliteOffsets(width: w)[i])
                        .opacity(reveal)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
                // 下の「TODAY ↓」
                Text(verbatim: "TODAY ↓")
                    .font(LF.mono(9.5, bold: true)).tracking(2.85)
                    .foregroundStyle(Color(hex: "8A8A84"))
                    .opacity(reveal)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 10)
                    .allowsHitTesting(false)
            }
            .frame(width: w, height: Self.height)
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.72), value: plan)
            .onChange(of: plan) { _, _ in
                if !reduceMotion { swap += 1 }
            }
        }
    }

    private struct FlashFrame { var opacity = 0.0; var scale = 1.0 }

    static func reveal(now: Date, start: Date?) -> Double {
        guard let start else { return 1 }
        let k = min(1, max(0, now.timeIntervalSince(start) / 1.3))
        return 1 - pow(1 - k, 3)
    }

    // MARK: 本体(v61 §3:黒 / フジの緑の帯 / 黒。境目は はっきり)

    private var cameraBody: some View {
        GeometryReader { geo in
            LinearGradient(stops: [
                .init(color: Color(hex: "1B1B1B"), location: 0),
                .init(color: Color(hex: "101010"), location: 0.22),
                .init(color: Color(hex: "24A03C"), location: 0.22),
                .init(color: Color(hex: "28A842"), location: 0.5),
                .init(color: Color(hex: "1F9236"), location: 0.78),
                .init(color: Color(hex: "101010"), location: 0.78),
                .init(color: Color(hex: "0B0B0B"), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .overlay(alignment: .top) {
            VStack(spacing: 2) {
                Text(verbatim: "Lattag")
                    .font(LF.inter(900, 20)).italic().tracking(-0.4)
                    .foregroundStyle(.white)
                Text(verbatim: "FILM FOR TOMORROW")
                    .font(LF.mono(7.5, bold: true)).tracking(1.5)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.top, 20)
        }
    }

    /// v61 §4 StrapStripe:写ルンですの ストラップ(白 / 赤 / 白 / ベージュ)。緑の帯の 範囲に のる。
    private var stripStripe: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let greenTop = h * 0.22, greenH = h * 0.56
            VStack(spacing: 0) {
                Color.white.frame(height: greenH * 0.40)
                LaterColor.red.frame(height: greenH * 0.22)
                Color.white.frame(height: greenH * 0.08)
                LaterColor.gold.frame(height: greenH * 0.30)
            }
            .frame(width: 14, height: greenH)
            // v61 §15:端に 寄せる ものは「端からの 距離」(幅に よらず 左端から 53pt)。幅で のばさない。
            .position(x: 53, y: greenTop + greenH / 2)
        }
        .allowsHitTesting(false)
    }

    // MARK: v61 §7:白いリングと光(レンズのまわり)

    /// 息を する 緑の 光 ×2
    private func aura(t: Double) -> some View {
        let b1 = running ? sin(t * 2 * .pi / 6) : 0
        let b2 = running ? sin(-(t * 2 * .pi / 22) + 0.857) : 0
        return ZStack {
            Circle()
                .fill(RadialGradient(stops: [
                    .init(color: Color(hex: "25AC40").opacity(0.55), location: 0),
                    .init(color: Color(hex: "70E086").opacity(0.25), location: 0.45),
                    .init(color: .clear, location: 0.7),
                ], center: .center, startRadius: 0, endRadius: 260))
                .frame(width: 520, height: 520)
                .blur(radius: 40)
                .scaleEffect(1 + 0.04 * (1 + b1))
                .opacity(0.7 + 0.3 * (running ? cos(t * 2 * .pi / 6) : 1))
            Circle()
                .fill(RadialGradient(stops: [
                    .init(color: Color(hex: "C3F1CC").opacity(0.9), location: 0),
                    .init(color: .clear, location: 0.65),
                ], center: .center, startRadius: 0, endRadius: 170))
                .frame(width: 340, height: 340)
                .blur(radius: 50)
                .scaleEffect(1 + 0.032 * (1 + b2))
            Circle()
                .fill(RadialGradient(stops: [
                    .init(color: Color(hex: "61DD7A").opacity(0.32), location: 0),
                    .init(color: Color(hex: "96E8A7").opacity(0.18), location: 0.45),
                    .init(color: .clear, location: 0.7),
                ], center: .center, startRadius: 0, endRadius: 213))
                .frame(width: 426, height: 426)
                .opacity(0.9)
        }
        .allowsHitTesting(false)
    }

    /// 波紋 ×2(272 → 386、6.4秒。2本目は 3.2秒 遅れ)
    private func ripples(t: Double) -> some View {
        ZStack {
            ripple(t: t, delay: 0)
            ripple(t: t, delay: 3.2)
        }
        .allowsHitTesting(false)
    }

    private func ripple(t: Double, delay: Double) -> some View {
        let period = 6.4
        let phase = running ? ((t + delay).truncatingRemainder(dividingBy: period)) / period : 0
        let scale = 272.0 / 272.0 + (386.0 / 272.0 - 1) * phase
        let opacity = running ? 0.9 * (1 - phase) : 0
        return Circle()
            .strokeBorder(Color(hex: "24A03C").opacity(0.28), lineWidth: 1)
            .frame(width: 272, height: 272)
            .scaleEffect(scale)
            .opacity(opacity)
    }

    /// 白い 弧 ×3(今日の のこり フィルム)+ クリーム色の 円盤
    private func filmArcsAndDisc(plan: HomeOrbRules.Plan, t: Double) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(stops: [
                    .init(color: .white, location: 0),
                    .init(color: Color(hex: "CCE8D1").opacity(0.35), location: 0.6),
                    .init(color: Color(hex: "EFE7DA"), location: 1),
                ], center: .topLeading, startRadius: 0, endRadius: 185))
                .frame(width: 261, height: 261)
                .shadow(color: Color(hex: "5A3214").opacity(0.45), radius: 44, y: 20)
            Circle()
                .strokeBorder(
                    AngularGradient(
                        stops: (0...8).map { i in
                            .init(color: i % 2 == 0 ? Color(hex: "121212") : LaterColor.film, location: Double(i) / 8)
                        },
                        center: .center
                    ),
                    lineWidth: 2
                )
                .frame(width: 261, height: 261)
                .rotationEffect(.degrees(running ? (t.truncatingRemainder(dividingBy: 40) / 40) * 360 : 0))
                .drawingGroup()
            ForEach(0..<3, id: \.self) { i in
                let remaining = HomeOrbRules.arcIsRemaining(i, used: input.used)
                Circle()
                    .trim(from: CGFloat(i) * 0.333 + 0.012, to: CGFloat(i) * 0.333 + 0.333 - 0.012)
                    .stroke(remaining ? Color.white : Color(hex: "DCD2C4"),
                            style: StrokeStyle(lineWidth: 2.7, lineCap: .round))
                    .frame(width: 320, height: 320)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: remaining ? .white.opacity(0.6) : .clear, radius: 3)
                    .animation(.easeInOut(duration: 0.4), value: remaining)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: レンズ(まんなか)

    private func lens(plan: HomeOrbRules.Plan, t: Double, reveal: Double) -> some View {
        let c = plan.center
        let photoMode = c == .yesterday && !plan.done && (yesterdayPhoto != nil || yesterdayImage != nil)
        return Button {
            tapCenter(plan.center)
        } label: {
            ZStack {
                // 絞りの ふち(刻み・LATER · 28mm … の 文字)
                Circle().fill(Color(hex: "121212"))
                    .overlay(ApertureTicks().stroke(.white.opacity(0.14), lineWidth: 1))
                    .overlay {
                        HomeRingText(text: "LATER · 28mm 1:1.4 · ∞ 10 5 3 2 1.5 1 0.7m · ", radius: 70,
                                     textColor: Color(hex: "6E6E73"), fontSize: 8.4)
                    }
                // ガラスの 玉(暗い・左上の つや)
                Circle().fill(RadialGradient(stops: [
                    .init(color: Color(hex: "050506"), location: 0), .init(color: Color(hex: "1B1B1D"), location: 0.72),
                    .init(color: Color(hex: "0A0A0B"), location: 1),
                ], center: .center, startRadius: 0, endRadius: 70))
                    .frame(width: 139, height: 139)
                Circle().fill(RadialGradient(stops: [.init(color: Color(hex: "0D1016"), location: 0), .init(color: Color(hex: "020203"), location: 0.72)], center: .center, startRadius: 0, endRadius: 56))
                    .frame(width: 112, height: 112)
                    .overlay {
                        if photoMode { photo.clipShape(Circle()) }
                    }
                Ellipse().fill(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 42, height: 32)
                    .rotationEffect(.degrees(-24))
                    .offset(x: -18, y: -29)
                    .blur(radius: 1)
                    .allowsHitTesting(false)
                apertureBlades
                centerText(plan: plan, photoMode: photoMode)
                // のこりこまの 黒い 札
                if !plan.done, case .shoot = c {
                    filmBadge
                } else if !plan.done {
                    filmBadge
                }
            }
            .frame(width: 193, height: 193)
            .saturation(plan.done ? 0.5 : 1)
            .scaleEffect(pressed ? 0.965 : 1)
            .animation(.timingCurve(0.3, 1.3, 0.4, 1, duration: 0.45), value: pressed)
            .keyframeAnimator(initialValue: 1.0, trigger: bounce &+ swap) { content, s in content.scaleEffect(s) } keyframes: { _ in
                CubicKeyframe(1.05, duration: 0.14); CubicKeyframe(1, duration: 0.18)
            }
            .contentShape(Circle())
        }
        .buttonStyle(HomeOrbPressStyle(pressed: $pressed) { on in
            if on { Haptics.play(.click) }
        })
        .scaleEffect(0.7 + 0.3 * min(1, reveal * 1.4))
        .opacity(reveal)
        .accessibilityLabel(Text(verbatim: plan.done ? String(localized: "home.orb.tomorrow") : "\(plan.center.title), \(HomeOrbRules.sub(plan.center, input: input, name: centerName, done: false))"))
        .firstHint(.orb, eligible: hintEligible, edge: .bottom, shape: .circle, onDark: palette.isNight, gap: 58)
    }

    /// レンズ 右上の 黒い 札(のこりこま の 数字)
    private var filmBadge: some View {
        Text(verbatim: "\(input.remaining)")
            .font(LF.mono(16, bold: true))
            .foregroundStyle(.white)
            .frame(width: 24, height: 19)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color(hex: "0A0A0B")))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.white, lineWidth: 1.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 15).padding(.trailing, -1)
    }

    @ViewBuilder
    private var photo: some View {
        if let yesterdayImage {
            Image(uiImage: yesterdayImage).resizable().scaledToFill().frame(width: 112, height: 112)
        } else if let yesterdayPhoto {
            DarkThumb(photo: yesterdayPhoto, maxPixel: 400).frame(width: 112, height: 112)
        }
    }

    /// v61 §6:絞り羽根 ×6(112pt)。ふだんは 開いた まま。押すと 回って しまる。
    private var apertureBlades: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                ApertureBlade()
                    .fill(Color(hex: "151517"))
                    .rotationEffect(.degrees(Double(i) * 60))
            }
        }
        .frame(width: 112, height: 112)
        .opacity(0.5)
        .clipShape(Circle())
        .rotationEffect(.degrees(pressed ? 26 : 0))
        .scaleEffect(pressed ? 0.82 : 1)
        .animation(.timingCurve(0.3, 1.3, 0.4, 1, duration: 0.45), value: pressed)
        .keyframeAnimator(initialValue: BladeFrame(), trigger: shutter) { content, f in
            content.rotationEffect(.degrees(f.rotation)).scaleEffect(f.scale)
        } keyframes: { _ in
            KeyframeTrack(\.rotation) {
                CubicKeyframe(40, duration: 0.152)
                CubicKeyframe(0, duration: 0.228)
            }
            KeyframeTrack(\.scale) {
                CubicKeyframe(0.55, duration: 0.152)
                CubicKeyframe(1, duration: 0.228)
            }
        }
        .allowsHitTesting(false)
    }

    private struct BladeFrame { var rotation = 0.0; var scale = 1.0 }

    private func centerText(plan: HomeOrbRules.Plan, photoMode: Bool) -> some View {
        let c = plan.center
        let title = plan.done ? String(localized: "home.orb.tomorrow") : c.title
        let font: Font = plan.done ? LF.inter(900, 22) : LF.serif(photoMode ? 32 : 46)
        return VStack(spacing: 4) {
            if !photoMode {
                Image(systemName: c.symbol)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Text(verbatim: title)
                .font(font)
                .tracking(-0.015 * 46)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: photoMode ? 5 : 2, y: 2)
            Text(verbatim: HomeOrbRules.sub(c, input: input, name: centerName, done: plan.done))
                .font(LF.mono(10.5, bold: true))
                .tracking(0.24 * 10.5)
                .foregroundStyle(photoMode ? LaterColor.filmPale : .white)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 100)
        }
        .frame(width: 110)
    }

    private func tapCenter(_ action: HomeOrbAction) {
        if action == .shoot {
            Haptics.play(.shutter)
            if reduceMotion { onCenter(action); return }
            shutter += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { onCenter(action) }
        } else {
            Haptics.play(.pop)
            if reduceMotion { onCenter(action); return }
            bounce += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { onCenter(action) }
        }
    }

    // MARK: 四すみの ボタン(丸 65〜70pt・黒い縁・下に ラベル札)

    /// v61 §8:白い丸 直径62pt・黒ふち2.4pt・アイコン26pt。タップ域は+12ptずつ(86pt)。ラベルは丸の8pt下。
    private func satellite(_ action: HomeOrbAction, index i: Int, t: Double) -> some View {
        let locked = HomeOrbRules.isLocked(action, used: input.used)
        let dot = HomeOrbRules.hasDot(action, input: input)
        let down = satPressed == action
        let scale: CGFloat = compactSatellites ? 56.0 / 62.0 : 1
        let size: CGFloat = 62 * scale, hitSize: CGFloat = 86 * scale, iconSize: CGFloat = 26 * scale
        let fill: Color = locked ? Color(hex: "3A3A3C") : .white
        let iconColor: Color = locked ? Color(hex: "8E8E93") : Color(hex: "121212")
        return Button {
            if locked {
                // v61 §8:ロック中は スライドしない。やわらかく 2回(warn)+ ゆれる + トースト。
                Haptics.play(.warn)
                onLocked()
                return
            }
            if reduceMotion { pageIndex = Self.page(for: action); return }
            satBounce[action, default: 0] += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { pageIndex = Self.page(for: action) }
        } label: {
            VStack(spacing: 8 * scale) {
                ZStack {
                    Circle().fill(fill)
                        .overlay(Circle().strokeBorder(Color(hex: "121212"), lineWidth: 2.4))
                        .overlay {
                            Image(systemName: action.symbol)
                                .font(.system(size: iconSize, weight: .semibold))
                                .foregroundStyle(iconColor)
                        }
                        .frame(width: size, height: size)
                        .shadow(color: .black, radius: 0, y: down ? 0.5 : 4)
                        .shadow(color: locked ? .clear : .black.opacity(0.6), radius: down ? 9 : 18, x: 0, y: down ? 5 : 10)
                        .offset(y: down ? 3.5 : 0)
                        .keyframeAnimator(initialValue: 1.0, trigger: satBounce[action, default: 0]) { content, s in content.scaleEffect(s) } keyframes: { _ in
                            CubicKeyframe(0.84, duration: 0.19); CubicKeyframe(1.1, duration: 0.19); CubicKeyframe(1, duration: 0)
                        }
                    if locked {
                        // v61 §8:ロック中は 右下に 小さい 鍵(約22pt)
                        Circle().fill(Color(hex: "111111")).frame(width: 22 * scale, height: 22 * scale)
                            .overlay(Image(systemName: "lock.fill").font(.system(size: 10 * scale, weight: .semibold)).foregroundStyle(.white))
                            .offset(x: size * 0.36, y: size * 0.36)
                    }
                    if dot {
                        Circle().fill(LaterColor.red).frame(width: 15 * scale, height: 15 * scale)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2.4))
                            .overlay { notifyRing(t: t) }
                            .offset(x: size * 0.38, y: -size * 0.38)
                    }
                }
                .frame(width: hitSize, height: hitSize)
                .contentShape(Circle())
                Text(verbatim: action.label)
                    .font(LF.mono(7.5 * scale, bold: true)).tracking(0.16 * 7.5 * scale)
                    .foregroundStyle(locked ? Color(hex: "8E8E93") : .white)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 7 * scale).padding(.vertical, 3 * scale)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(locked ? Color(hex: "2A2A2C") : Color(hex: "121212")))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.white.opacity(0.10), lineWidth: 1))
            }
            .contentShape(Rectangle())
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: down)
        }
        .buttonStyle(HomeOrbPressStyle(pressed: Binding(get: { satPressed == action }, set: { satPressed = $0 ? action : (satPressed == action ? nil : satPressed) })) { on in
            // v61 §8:押した 瞬間に click(ロック中も ふくめて)。ページへの 切りかえは pageIndex が 変わった ときの sel が 別で 鳴る。
            if on { Haptics.play(.click) }
        })
        .accessibilityLabel(Text(verbatim: locked ? "\(action.title)、ロック中" : action.title))
    }

    /// v61 §8:通知の 赤い 点の まわりに、1.8秒ごとに 広がる 輪(0→9pt、不透明度 60%→0)
    private func notifyRing(t: Double) -> some View {
        let phase = running ? (t.truncatingRemainder(dividingBy: 1.8)) / 1.8 : 0
        return Circle()
            .strokeBorder(LaterColor.red.opacity(running ? 0.6 * (1 - phase) : 0), lineWidth: 1.5)
            .scaleEffect(1 + (9.0 / 15.0) * phase)
            .allowsHitTesting(false)
    }

    /// v61 §8:四すみの 行き先 → ページ 番号(0 Camera / 1 Friends / 2 Trip / 3 Mondo / 4 Yesterday)
    private static func page(for action: HomeOrbAction) -> Int {
        switch action {
        case .friends: 1
        case .trip: 2
        case .mondo: 3
        case .yesterday: 4
        default: 0
        }
    }

    private func stickers(t: Double, reveal: Double) -> some View {
        let s = running ? sin(t * 2 * .pi / 5) : 0, s2 = running ? sin(t * 2 * .pi / 6) : 0
        // 見本 A01/A02 の 位置(角に 1つずつ。まわりの 4つの ボタンと かさならない ように)
        return ZStack {
            // v54:まわりの ボタン(y ±198〜266)と かさならない すきま(レンズと ボタンの 間)に 置く
            ChicDoodle(kind: .star, width: 32).foregroundStyle(.white).rotationEffect(.degrees(10 * s)).offset(x: -144, y: -150 - 7 * s)
            ChicDoodle(kind: .wave, width: 44).foregroundStyle(.white).rotationEffect(.degrees(-8 * s2)).offset(x: 144, y: -150 + 5 * s2)
            ChicDoodle(kind: .flower, width: 30).rotationEffect(.degrees(10 * s2)).offset(x: 144, y: 150 - 7 * s2)
            ChicDoodle(kind: .dots, width: 24).foregroundStyle(.white).offset(x: -144, y: 150 + 5 * s)
        }
        .opacity(reveal)
        .allowsHitTesting(false)
    }

    // MARK: v61 §10 PageDock(ナビピル)

    private var pageDock: some View {
        HStack(spacing: 4) {
            dockButton(label: "CAMERA", symbol: "circle.fill", index: 0)
            dockButton(label: "FRIENDS", symbol: "person.2.fill", index: 1)
            dockButton(label: "TRIP", symbol: "bag.fill", index: 2)
            dockButton(label: "MONDO", symbol: "globe", index: 3)
            dockButton(label: "YESTERDAY", symbol: "photo.stack", index: 4)
        }
        .padding(4)
        .frame(height: 42)
        .background(Capsule().fill(.black.opacity(0.78)))
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.7), radius: 22, y: 10)
        .accessibilityElement(children: .contain)
    }

    private func dockButton(label: String, symbol: String, index: Int) -> some View {
        let selected = pageIndex == index
        return Button {
            pageIndex = index
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
                if selected {
                    Text(verbatim: label).font(LF.mono(8.5, bold: true)).tracking(0.14 * 8.5)
                }
            }
            .foregroundStyle(selected ? Color(hex: "111111") : Color(hex: "8E8E93"))
            .padding(.horizontal, selected ? 10 : 0)
            .frame(width: selected ? 84 : 36, height: 34)
            .background(Capsule().fill(selected ? LaterColor.lime : .clear))
            .animation(.easeInOut(duration: 0.35), value: selected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "ページ、\(index + 1) / 5、\(label.capitalized)"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: v61 §11-2 Trip ページ(裏側は 既存の グループ作成/CKShare招待 を そのまま 使う)

    private func tripPage(width w: CGFloat) -> some View {
        let trip = groupSummaries.first
        return secondaryPageShell(.trip, index: 2, statusText: trip == nil ? nil : "\(trip!.memberCount) / \(trip!.memberLimit)", width: w) {
            VStack(alignment: .leading, spacing: 14) {
                if let trip {
                    Text(verbatim: trip.name)
                        .font(LF.serif(32)).foregroundStyle(.white)
                    Text(verbatim: trip.invitingText ?? "みんなで、ひらく。")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                } else {
                    (Text("Take a trip,\n") + Text("together.").italic().foregroundStyle(LaterColor.lime))
                        .font(LF.serif(32))
                        .foregroundStyle(.white)
                        .lineSpacing(2)
                    Text(verbatim: "旅行・合宿・イベント。1日 23枚を、みんなで。")
                        .font(.system(size: 12.5, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                }
            }
        } cta: {
            if let trip {
                ctaButton(title: "Open", systemImage: "arrow.right") { onSelectGroup(trip.id) }
            } else {
                ctaButton(title: "New trip", systemImage: "plus") { onCreateGroup() }
            }
        }
    }

    // MARK: v61 §11 共通の 型(Friends / Mondo / Yesterday)

    /// Friends・Mondo・Yesterday は 同じ 型(ヘッダー行 + タイトル + CTA)。
    /// 注:まだ 友だちの 一覧・人気タグ・チェキの 実データが この コンポーネントに 来ていないので、
    /// いま ある 信号(input)だけで 正直に 組んでいる(プレースホルダーの 絵は 作らない)。
    private func secondaryPage(_ action: HomeOrbAction, index: Int, width w: CGFloat, onOpen: @escaping () -> Void) -> some View {
        let locked = HomeOrbRules.isLocked(action, used: input.used)
        return secondaryPageShell(action, index: index, statusText: locked ? "LOCKED" : nil, width: w) {
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: title(for: action))
                    .font(LF.serif(32)).foregroundStyle(.white)
                Text(verbatim: subtitle(for: action, locked: locked))
                    .font(.system(size: 12.5, weight: .medium)).foregroundStyle(.white.opacity(0.6))
            }
        } cta: {
            if locked {
                ctaButton(title: "Shoot first", systemImage: "camera.fill") { onCenter(.shoot) }
            } else {
                ctaButton(title: action == .friends ? "Open friends" : (action == .mondo ? "Explore" : "Open"), systemImage: "arrow.right", onOpen)
            }
        }
    }

    private func title(for action: HomeOrbAction) -> String {
        switch action {
        case .friends: "Friends"
        case .mondo: "The world,\nyesterday."
        case .yesterday: "Yesterday"
        default: action.title
        }
    }

    private func subtitle(for action: HomeOrbAction, locked: Bool) -> String {
        switch action {
        case .friends: input.hasUnread ? "申請が とどいています" : "友だちの きのうを、見にいく"
        case .mondo: locked ? "今日 1枚 撮ると、ひらきます" : "きのうの 世界を、のぞく"
        case .yesterday: locked ? "今日 1枚 撮ると、ひらきます" : "\(input.openedYesterday) OPENED"
        default: ""
        }
    }

    private func secondaryPageShell<Content: View, CTA: View>(
        _ action: HomeOrbAction, index: Int, statusText: String?, width w: CGFloat,
        @ViewBuilder content: () -> Content, @ViewBuilder cta: () -> CTA
    ) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(hex: "1B1B1B"), Color(hex: "101010"), Color(hex: "0B0B0C")], startPoint: .top, endPoint: .bottom)
            Capsule().fill(LaterColor.gold.opacity(0.34))
                .frame(width: 7)
                .padding(.vertical, 120)
                .padding(.leading, 16)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: action.symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: "121212"))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(.white))
                        .overlay(Circle().strokeBorder(.black, lineWidth: 2.2))
                        .accessibilityHidden(true)
                    Text(verbatim: "0\(index) / 04")
                        .font(LF.mono(9, bold: true)).tracking(0.18 * 9)
                        .foregroundStyle(Color(hex: "6C6C73"))
                        .accessibilityHidden(true)
                    Spacer()
                    if let statusText {
                        Text(verbatim: statusText)
                            .font(LF.mono(9.5, bold: true)).tracking(0.12 * 9.5)
                            .foregroundStyle(statusText == "LOCKED" ? Color(hex: "8E8E93") : LaterColor.liveGreen)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(verbatim: "ページ \(index) / 4\(statusText.map { "、\($0)" } ?? "")"))
                Spacer(minLength: 0)
                content()
                    .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
                cta()
            }
            .padding(.top, 22).padding(.horizontal, 22).padding(.bottom, 18)
        }
        .frame(width: w, height: Self.height)
        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).strokeBorder(.white.opacity(0.05), lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 60, y: 30)
        .accessibilityElement(children: .contain)
    }

    private func ctaButton(title: String, systemImage: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.play(.click)
            action()
        } label: {
            HStack {
                Text(verbatim: title).font(LF.inter(800, 17))
                Spacer()
                Circle().fill(LaterColor.filmLight).frame(width: 42, height: 42)
                    .overlay(Image(systemName: systemImage).font(.system(size: 16, weight: .bold)).foregroundStyle(.black))
            }
            .padding(.leading, 20).padding(.trailing, 6)
            .frame(height: 56)
            .background(Capsule().fill(.white))
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
        .foregroundStyle(Color(hex: "111111"))
    }
}

/// レンズの ふちの 刻み(等間隔の 細い 線・絞りの 目盛りふう)
private struct ApertureTicks: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let outer = rect.width / 2 - 2
        let inner = outer - 6
        for i in 0..<72 {
            let a = Double(i) / 72 * 2 * .pi
            path.move(to: CGPoint(x: c.x + cos(a) * inner, y: c.y + sin(a) * inner))
            path.addLine(to: CGPoint(x: c.x + cos(a) * outer, y: c.y + sin(a) * outer))
        }
        return path
    }
}

/// v61 §6:絞り羽根(6枚で 1つ)の 1枚。中心 寄りの 頂点 → 外周の 弧 → もどる、の 扇形。
private struct ApertureBlade: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = rect.width / 2
        var path = Path()
        path.move(to: c)
        path.addLine(to: CGPoint(x: c.x + cos(-0.08) * r, y: c.y + sin(-0.08) * r))
        path.addArc(center: c, radius: r, startAngle: .radians(-0.08), endAngle: .radians(1.02), clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - v35 まんなかの 丸を 画面いっぱいの 主役に(見本:later_v35.html)

/// v54:写ルンですの 本体を そのまま 使う(拡大しない・虹色の オーロラは 無い)。
/// スクロールしたら 小さく・うすく なる 動き(ChicHomeView 側)は 変えない。行き先・処理は HomeGlassOrb と 同じ
struct HomeOrbHero: View {
    let input: HomeOrbRules.Input
    let dateText: String
    let isActive: Bool
    var centerName: String?
    var yesterdayPhoto: LaterPhoto?
    var yesterdayImage: UIImage?
    var introStart: Date?
    let onCenter: (HomeOrbAction) -> Void
    let onSatellite: (HomeOrbAction) -> Void
    var onLocked: () -> Void = {}
    /// v61:Trip ページ(既存の グループ作成/CKShare招待を そのまま 使う。見た目だけ 新しい)
    var groupSummaries: [GroupSummary] = []
    var canCreateGroup = true
    var onCreateGroup: () -> Void = {}
    var onJoinGroup: () -> Void = {}
    var onSelectGroup: (UUID) -> Void = { _ in }
    /// v61:じぶんの きのう(既存の YesterdayViewer(scope: .mine))。Mondo とは 別の 行き先。
    var onOpenYesterday: () -> Void = {}
    var hintEligible = false

    static let height: CGFloat = HomeGlassOrb.height

    var body: some View {
        HomeGlassOrb(input: input, dateText: dateText, isActive: isActive, centerName: centerName,
                     yesterdayPhoto: yesterdayPhoto, yesterdayImage: yesterdayImage, introStart: introStart,
                     onCenter: onCenter, onSatellite: onSatellite, onLocked: onLocked,
                     groupSummaries: groupSummaries, canCreateGroup: canCreateGroup,
                     onCreateGroup: onCreateGroup, onJoinGroup: onJoinGroup, onSelectGroup: onSelectGroup,
                     onOpenYesterday: onOpenYesterday,
                     hintEligible: hintEligible)
    }
}

/// 押している 間を 知らせる(ScrollView の 中でも スクロールを じゃましない)
struct HomeOrbPressStyle: ButtonStyle {
    @Binding var pressed: Bool
    var onChange: (Bool) -> Void = { _ in }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, on in
                pressed = on
                onChange(on)
            }
    }
}

/// 円に沿った文字(等幅 8pt・灰)
struct HomeRingText: View {
    let text: String
    let radius: CGFloat
    /// 回転(ラジアン)
    var rotation: Double = 0
    /// 字を 消す 場所(中心から の 矩形)。ふちから 6pt で ふわっと 消える
    var holes: [CGRect] = []
    var textColor: Color = Color(hex: "A9A6B0")
    var fontSize: CGFloat = 8

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let chars = Array(text)
            let step = 2 * Double.pi / Double(chars.count)
            for (i, ch) in chars.enumerated() {
                let a = -Double.pi / 2 + Double(i) * step + rotation
                let fade = HomeRingText.visibility(at: CGPoint(x: cos(a) * radius, y: sin(a) * radius), holes: holes)
                if fade <= 0 { continue }
                var inner = ctx
                inner.opacity = fade
                inner.translateBy(x: c.x + cos(a) * radius, y: c.y + sin(a) * radius)
                inner.rotate(by: .radians(a + .pi / 2))
                inner.draw(Text(String(ch)).font(.system(size: fontSize, design: .monospaced)).foregroundColor(textColor), at: .zero)
            }
        }
        .frame(width: radius * 2 + 20, height: radius * 2 + 20)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 0 = 穴の中、1 = 穴から 6pt 以上 はなれている
    static func visibility(at p: CGPoint, holes: [CGRect]) -> Double {
        var v = 1.0
        for r in holes {
            let dx = max(r.minX - p.x, 0, p.x - r.maxX), dy = max(r.minY - p.y, 0, p.y - r.maxY)
            v = min(v, min(1, Double((dx * dx + dy * dy).squareRoot()) / 6))
        }
        return v
    }
}

// MARK: - 見出し(2行・Black 30pt・字間 -4.5%・手書きの丸は文字に ぴったり)

/// v22 ホームの 文字と 面の色(昼 / 夜)。夜(21:00〜9:00)は 背景が ほぼ黒なので、昼の色を そのまま 使わない。
/// 夜の目安:本文 4.5:1 以上・大きな見出し 3:1 以上・小さな説明も #A1A1A8 より 暗くしない
struct HomeV22Ink: Equatable {
    let night: Bool

    private func pick(_ day: String, _ night: String) -> Color { Color(hex: self.night ? night : day) }
    /// 見出し・タイトル
    var ink: Color { pick("111111", "F5F5F7") }
    /// 小さな説明
    var sub: Color { pick("8E8E93", "A1A1A8") }
    /// 数字(1 / 3 など)
    var meta: Color { pick("6E6E73", "B4B4BB") }
    var chevron: Color { pick("C7C7CC", "8E8E95") }
    /// 今日のカードの面
    var card: Color { pick("FFFFFF", "18181C") }
    /// うすい面(参加する・ガイドの カード)
    var soft: Color { night ? Color.white.opacity(0.07) : Color(hex: "F4F3F7") }
    var softLine: Color { night ? Color.white.opacity(0.14) : Color(hex: "E3E2E9") }
    var guideCard: Color { night ? Color.white.opacity(0.07) : Color(hex: "F6F5F8") }
    /// こま(撮った = 塗り・つぎ = ふち・まだ = 点線)
    var slot: Color { pick("111111", "F5F5F7") }
    var slotDash: Color { pick("C9C8CE", "6E6E76") }
    /// 目じるしの 文字
    var marker: Color { pick("3A3A3C", "D1D1D6") }
    var faint: Color { pick("AEAEB2", "A1A1A8") }
    /// 白い ボタンの 面
    var button: Color { night ? Color.white.opacity(0.1) : .white }
}

struct HomeV22Headline: View {
    let headline: HomeV22Rules.Headline
    /// 丸を描く進み 0〜1
    var circle: Double = 1
    var lineReveal: Double = 1
    let width: CGFloat

    @Environment(\.palette) private var palette
    private var colors: HomeV22Ink { HomeV22Ink(night: palette.isNight) }

    var body: some View {
        VStack(spacing: 0) {
            line(headline.first, circled: nil)
            line(headline.second, circled: headline.circled)
                .opacity(lineReveal)
            Text(headline.sub)
                .font(.system(size: 13, weight: .medium)).tracking(0.02 * 13)
                .foregroundStyle(colors.sub)
                .padding(.top, 7)
        }
        .frame(width: width)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(headline.first + headline.second + headline.sub)
    }

    private func line(_ text: String, circled: String?) -> some View {
        let size = min(30, (width - 32) / (CGFloat(text.count) * 0.96))
        let font = Font.system(size: size, weight: .black)
        let parts: (String, String?, String) = {
            guard let circled, let r = text.range(of: circled) else { return (text, nil, "") }
            return (String(text[..<r.lowerBound]), circled, String(text[r.upperBound...]))
        }()
        // 文字の ならびを そのまま はかって、丸の言葉の上に 丸を置く
        return HStack(spacing: 0) {
            if !parts.0.isEmpty { Text(parts.0) }
            if let hit = parts.1 {
                Text(hit).overlay {
                    HomeHandCircle()
                        .trim(from: 0, to: circle)
                        .stroke(Color(hex: "F26A1B"), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                        .padding(.horizontal, hit.count == 1 ? -12 : -8)
                        .padding(.vertical, -size * 0.12)
                }
            }
            if !parts.2.isEmpty { Text(parts.2) }
        }
        .font(font)
        .tracking(-0.045 * size)
        .foregroundStyle(colors.ink)
        .lineLimit(1)
        .fixedSize()
        .frame(height: size * 1.24)
    }
}

/// 手書きの丸(見本:M84 6C128 2 157 15 154 34 151 54 112 62 76 60 32 58 4 49 6 29 8 12 44 4 104 8 ・ 160×64)
struct HomeHandCircle: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 160, sy = rect.height / 64
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var path = Path()
        path.move(to: p(84, 6))
        path.addCurve(to: p(154, 34), control1: p(128, 2), control2: p(157, 15))
        path.addCurve(to: p(76, 60), control1: p(151, 54), control2: p(112, 62))
        path.addCurve(to: p(6, 29), control1: p(32, 58), control2: p(4, 49))
        path.addCurve(to: p(104, 8), control1: p(8, 12), control2: p(44, 4))
        return path
    }
}

// MARK: - 今日のカード(今日の film の入口)

struct HomeTodayCard: View {
    let used: Int
    let initial: Bool
    let now: Date
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.palette) private var palette
    @State private var bounce = 0
    private var landing: FilmLanding { FilmLanding.shared }
    private var colors: HomeV22Ink { HomeV22Ink(night: palette.isNight) }

    var body: some View {
        let text = HomeV22Rules.card(used: used, initial: initial)
        Button(action: onTap) {
            HStack(spacing: 14) {
                cheki
                VStack(alignment: .leading, spacing: 3) {
                    Text(text.title).font(.system(size: 15.5, weight: .black)).tracking(-0.02 * 15.5).foregroundStyle(colors.ink).lineLimit(1).minimumScaleFactor(0.8)
                    Text(text.sub).font(.system(size: 11.5, weight: .medium)).foregroundStyle(colors.sub).lineLimit(1).minimumScaleFactor(0.8)
                    HStack(spacing: 6) {
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in slot(i) }
                        }
                        Text("\(used) / 3").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(0.1 * 10).foregroundStyle(colors.meta)
                        Spacer(minLength: 0)
                        if used >= 3 {
                            Text("あと \(HomeV22Rules.untilNine(now: now))").font(.system(size: 10, design: .monospaced)).tracking(0.06 * 10).foregroundStyle(palette.accent)
                        }
                    }
                    .padding(.top, 4)
                }
                Text("›").font(.system(size: 22)).foregroundStyle(colors.chevron).padding(.trailing, 2)
            }
            .padding(.leading, 10).padding(.trailing, 12)
            .frame(height: 90)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(colors.card))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(LinearGradient(colors: [Color(hex: "FFCFB4"), Color(hex: "E8D6FF"), Color(hex: "CFE0FF"), Color(hex: "FFE7B8")], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5).opacity(palette.isNight ? 0.55 : 1))
            .shadow(color: Color(red: 0.47, green: 0.31, blue: 0.63).opacity(palette.isNight ? 0.2 : 0.35), radius: 15, y: 14)
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.98))
        .keyframeAnimator(initialValue: 1.0, trigger: bounce) { content, s in content.scaleEffect(s) } keyframes: { _ in
            KeyframeTrack { CubicKeyframe(1.04, duration: 0.12); SpringKeyframe(1, duration: 0.3) }
        }
        .onChange(of: landing.landedToken) { _, _ in bounce += 1 }
        .accessibilityLabel("\(text.title)。\(text.sub)。今日 \(used)こま。押すと 現像ビューへ")
    }

    private var cheki: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                window.clipShape(RoundedRectangle(cornerRadius: 2))
                Spacer(minLength: 0).frame(height: 12)
            }
            .padding(5)
            .frame(width: 64, height: 76)
            .background(RoundedRectangle(cornerRadius: 3).fill(.white))
            .shadow(color: .black.opacity(0.28), radius: 9, y: 10)
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.black.opacity(0.04), lineWidth: 1))
            V17Tape(width: 30, height: 13).rotationEffect(.degrees(-8)).offset(x: 4, y: -9)
        }
        .rotationEffect(.degrees(-4))
        .offset(y: -5)
        // 撮ったチェキが とんでくる先(画面の座標)。こまの番号は どれでも、この カードの 写真の所
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rect in
            for i in 0..<3 { landing.slotFrames[i] = rect }
        }
    }

    @ViewBuilder
    private var window: some View {
        if used == 0 {
            ZStack(alignment: .bottom) {
                Color(hex: "0E0E10")
                Circle().fill(.white).frame(width: 6, height: 6).shadow(color: .white, radius: 4).frame(maxHeight: .infinity)
                Text(HomeV17Rules.dotDate(now)).font(.system(size: 7.5, weight: .bold, design: .monospaced)).foregroundStyle(Color(hex: "FF7A1A")).padding(.bottom, 3)
            }
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
                let s = reduceMotion ? 0 : (sin(context.date.timeIntervalSinceReferenceDate * 2 * .pi / 2.2) + 1) / 2
                ZStack {
                    LinearGradient(colors: [Color(hex: "E9EEEA"), Color(hex: "D3DAE5")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().fill(Color(hex: "FF8A2A")).frame(width: 6, height: 6).shadow(color: Color(hex: "FF8A2A").opacity(0.8), radius: 4)
                        .scaleEffect(1 + 0.5 * s).opacity(1 - 0.4 * s)
                }
            }
        }
    }

    private func slot(_ i: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 3)
        return ZStack {
            if i < used {
                shape.fill(colors.slot)
                Circle().fill(Color(hex: "FF8A2A")).frame(width: 4, height: 4)
            } else if i == used {
                shape.strokeBorder(colors.slot, lineWidth: 1.6)
            } else {
                shape.strokeBorder(colors.slotDash, style: StrokeStyle(lineWidth: 1.4, dash: [2, 2]))
            }
        }
        .frame(width: 11, height: 14)
    }
}

// MARK: - グループ(17pt + 横長のタイル 80)

struct HomeV22Groups: View {
    let summaries: [GroupSummary]
    let canCreate: Bool
    let isFrontmost: Bool
    let shotsToday: Int
    let onSelect: (UUID) -> Void
    let onCreate: () -> Void
    let onJoin: () -> Void
    let onAdd: () -> Void
    /// はじめての 合図(grp)を「つくる」に 出してよい
    var createHintEligible = false

    @Environment(\.palette) private var palette
    private var colors: HomeV22Ink { HomeV22Ink(night: palette.isNight) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if summaries.isEmpty {
                Text("グループ").font(.system(size: 17, weight: .black)).tracking(-0.02 * 17).foregroundStyle(colors.ink).padding(.leading, 4)
                HStack(spacing: 10) {
                    tile(dark: true, icon: "plus", title: "つくる", note: "4〜8人の グループ", action: onCreate)
                        .firstHint(.grp, eligible: createHintEligible, edge: .top, shape: .rounded(22), onDark: palette.isNight)
                    tile(dark: false, icon: "qrcode", title: "参加する", note: "合言葉・QR・リンク", action: onJoin)
                }
            } else {
                HomeGroupStrip(summaries: summaries, canCreate: canCreate, isFrontmost: isFrontmost, entranceStart: nil,
                               onSelect: onSelect, onCreate: onCreate, onJoin: onJoin, onAdd: onAdd, arrivingID: nil, shotsToday: shotsToday)
                    .padding(.horizontal, -18)
            }
        }
        .padding(.horizontal, 18)
    }

    private func tile(dark: Bool, icon: String, title: String, note: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.play(.tick)
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 17, weight: .bold))
                    .foregroundStyle(dark ? .white : Color(hex: "111111"))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(dark ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "FFB05A"), Color(hex: "FF5A7A")], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.white)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 16, weight: .black)).tracking(-0.02 * 16).foregroundStyle(dark ? .white : colors.ink)
                    Text(note).font(.system(size: 10.5, weight: .medium)).foregroundStyle(dark ? Color(hex: "A7A7B2") : colors.sub).lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(dark
                ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "141418"), Color(hex: "2A2433")], startPoint: .topLeading, endPoint: .bottomTrailing))
                : AnyShapeStyle(colors.soft)))
            // 夜は 黒い タイルも 背景に とけないよう、うすい ふちを つける
            .overlay { if !dark || palette.isNight { RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(colors.softLine, lineWidth: dark ? 1 : 1.4) } }
            .shadow(color: dark ? Color(red: 0.12, green: 0.08, blue: 0.16).opacity(0.6) : .clear, radius: 13, y: 14)
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
        .accessibilityLabel("\(title)。\(note)")
    }
}
