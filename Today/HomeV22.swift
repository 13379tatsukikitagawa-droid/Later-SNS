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
        }
    }

    /// まんなかの 大きい 字(英語のまま)
    var title: String {
        switch self {
        case .newGroup: "New group"
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
        }
    }

    /// まわりの 丸の 色(見本の OCOL)
    var tint: String {
        switch self {
        case .shoot: "FFD6C2"
        case .yesterday: "CDE4FF"
        case .chat: "FFC9DF"
        case .newGroup: "CFF3E5"
        case .mondo: "E3D4FF"
        case .friends: "FFF0B8"
        case .develop: "FFE2C4"
        case .join: "FFB27A"
        }
    }
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
    static func satellites(_ input: Input, center: HomeOrbAction) -> [HomeOrbAction] {
        var list: [HomeOrbAction] = []
        if input.remaining > 0 { list.append(.shoot) }
        if input.used > 0 { list.append(.develop) }
        list.append(.yesterday)
        if input.hasGroups { list.append(.chat) }
        list += [.newGroup, .mondo, .friends]
        return Array(list.filter { $0 != center }.prefix(4))
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

    /// 右上の 橙の 点(新しい メッセージ・グループが 0 の New group)
    static func hasDot(_ action: HomeOrbAction, input: Input) -> Bool {
        switch action {
        case .chat: input.hasUnread
        case .newGroup: !input.hasGroups
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

    /// まわりの 位置(中心から。左上・右上・左下・右下)
    static let satelliteOffsets: [CGSize] = [CGSize(width: -135, height: -74), CGSize(width: 135, height: -74),
                                             CGSize(width: -135, height: 74), CGSize(width: 135, height: 74)]

    /// まわりの 1つが しめる 場所(丸 50 + 影 + 下の 字。浮き沈み 4pt ぶん 広め)。文字の輪は ここでは 消える
    static func satelliteHole(_ action: HomeOrbAction, index i: Int) -> CGRect {
        let o = satelliteOffsets[min(max(i, 0), satelliteOffsets.count - 1)]
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.palette) private var palette
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var pressed = false
    @State private var shutter = 0
    @State private var bounce = 0
    @State private var swap = 0
    @State private var satPressed: HomeOrbAction?
    @State private var satBounce: [HomeOrbAction: Int] = [:]

    static let height: CGFloat = 300

    private var plan: HomeOrbRules.Plan { HomeOrbRules.plan(input) }
    private var running: Bool { isActive && !reduceMotion && !lowPower }
    private var intro: Bool { !reduceMotion && introStart.map { Date().timeIntervalSince($0) < 1.6 } ?? false }

    var body: some View {
        let plan = plan
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !running && !intro)) { context in
            let t = running ? context.date.timeIntervalSinceReferenceDate : 0
            let reveal = Self.reveal(now: context.date, start: reduceMotion ? nil : introStart)
            ZStack {
                // うしろの ふんわり光(桃〜藤)
                Circle()
                    .fill(RadialGradient(stops: [
                        .init(color: Color(red: 1, green: 0.78, blue: 0.67).opacity(0.38), location: 0),
                        .init(color: Color(red: 0.86, green: 0.78, blue: 1).opacity(0.26), location: 0.45),
                        .init(color: .clear, location: 0.7),
                    ], center: .center, startRadius: 0, endRadius: 150))
                    .frame(width: 300, height: 300)
                    .allowsHitTesting(false)
                // 6.4秒ごとの 波紋(2つ)
                ForEach(0..<2, id: \.self) { i in
                    let p = ((t + Double(i) * 3.2).truncatingRemainder(dividingBy: 6.4)) / 6.4
                    Circle().stroke(Color(red: 1, green: 0.59, blue: 0.43).opacity(0.35), lineWidth: 1.2)
                        .frame(width: 192, height: 192)
                        .scaleEffect(1 + 0.42 * p)
                        .opacity(running ? 0.9 * (1 - p) : 0)
                        .allowsHitTesting(false)
                }
                // 外の文字の輪(200秒で一周)
                // まわりの 4つの 下では 字を 消す(SE 幅で かさならない ように)
                HomeRingText(text: HomeOrbRules.ringText(now: Date()), radius: 128,
                             rotation: (t.truncatingRemainder(dividingBy: 200) / 200) * 2 * .pi,
                             holes: plan.satellites.enumerated().map { HomeOrbRules.satelliteHole($0.element, index: $0.offset) })
                    .opacity(reveal)
                // ガラスの球(ドットは うすい 光の粒)
                globe(t: t, reveal: reveal)
                // 3本の フィルムの 弧(のこり = 橙)
                HomeOrbFilmArcs(used: input.used)
                    .frame(width: 226, height: 226)
                    .opacity(reveal)
                // まんなかの ボタン
                centerButton(plan: plan, t: t, reveal: reveal)
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
                // 黒い ピル(橙の 点 + TAP / OPEN / JOIN)
                pill(plan: plan, t: t)
                    .offset(y: 92 + 14)
                    .opacity(reveal)
                    .allowsHitTesting(false)
                // ステッカー(星・波線・花・点)
                stickers(t: t, reveal: reveal)
                // まわりの 4つ
                ForEach(Array(plan.satellites.enumerated()), id: \.element) { i, action in
                    satellite(action, index: i, t: t)
                        .offset(HomeOrbRules.satelliteOffsets[i])
                        .opacity(reveal)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .frame(height: Self.height)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.72), value: plan)
        .onChange(of: plan) { _, _ in
            if !reduceMotion { swap += 1 }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    private struct FlashFrame { var opacity = 0.0; var scale = 1.0 }
    private struct BladeFrame { var angle = 0.0; var scale = 1.0 }

    static func reveal(now: Date, start: Date?) -> Double {
        guard let start else { return 1 }
        let k = min(1, max(0, now.timeIntervalSince(start) / 1.3))
        return 1 - pow(1 - k, 3)
    }

    private func globe(t: Double, reveal: Double) -> some View {
        ZStack {
            Circle().fill(RadialGradient(stops: [
                .init(color: .white, location: 0), .init(color: Color(hex: "FBFBFD"), location: 0.3),
                .init(color: Color(hex: "F1F1F5"), location: 0.72), .init(color: Color(hex: "E7E7EE"), location: 1),
            ], center: UnitPoint(x: 0.32, y: 0.24), startRadius: 0, endRadius: 120))
            HomeOrbDots(used: input.used, t: t, reveal: reveal)
                .saturation(1.3)
                .opacity(0.32)
            // 左上の つや
            Ellipse().fill(LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: 184 * 0.44, height: 184 * 0.16)
                .rotationEffect(.degrees(-16))
                .offset(x: -184 * 0.08, y: -184 * 0.34)
        }
        .frame(width: 184, height: 184)
        .overlay {
            // 虹色のふち(2pt・24秒で ゆっくり回る)
            Circle()
                .strokeBorder(AngularGradient(colors: [Color(hex: "FFB38A"), Color(hex: "F7A8D8"), Color(hex: "B9A4FF"), Color(hex: "8EC5FF"), Color(hex: "9EE6D0"), Color(hex: "FFE08A"), Color(hex: "FFB38A")], center: .center), lineWidth: 2)
                .rotationEffect(.degrees((t.truncatingRemainder(dividingBy: 24) / 24) * 360))
        }
        .shadow(color: Color(red: 0.47, green: 0.35, blue: 0.63).opacity(0.35), radius: 20, y: 18)
        .scaleEffect(0.7 + 0.3 * min(1, reveal * 1.4))
        .allowsHitTesting(false)
    }

    // MARK: まんなか

    private func centerButton(plan: HomeOrbRules.Plan, t: Double, reveal: Double) -> some View {
        let c = plan.center
        let photoMode = c == .yesterday && !plan.done && (yesterdayPhoto != nil || yesterdayImage != nil)
        let warm = c == .join || c == .chat
        return Button {
            tapCenter(plan.center)
        } label: {
            ZStack {
                Circle().fill(RadialGradient(stops: warm ? [
                    .init(color: .white, location: 0), .init(color: Color(hex: "FFE9DC"), location: 0.5), .init(color: Color(hex: "FFC9DF"), location: 1),
                ] : [
                    .init(color: .white, location: 0), .init(color: Color(hex: "FAF7F3"), location: 0.45), .init(color: Color(hex: "EFE9F3"), location: 1),
                ], center: UnitPoint(x: 0.34, y: 0.26), startRadius: 0, endRadius: 110))
                // 6まいの 絞りの 羽(40秒で 一周)
                HomeApertureBlades()
                    .frame(width: 104, height: 104)
                    .rotationEffect(.degrees((t.truncatingRemainder(dividingBy: 40) / 40) * 360 + (pressed ? 30 : 0)))
                    .scaleEffect(pressed ? 0.82 : 1)
                    .keyframeAnimator(initialValue: BladeFrame(), trigger: shutter) { content, f in
                        content.rotationEffect(.degrees(f.angle)).scaleEffect(f.scale)
                    } keyframes: { _ in
                        KeyframeTrack(\.angle) { CubicKeyframe(90, duration: 0.19); CubicKeyframe(120, duration: 0.23); LinearKeyframe(0, duration: 0.001) }
                        KeyframeTrack(\.scale) { CubicKeyframe(0.6, duration: 0.19); CubicKeyframe(1, duration: 0.23) }
                    }
                    .opacity(photoMode ? 0 : warm ? 0.35 : 0.95)
                if photoMode {
                    photo
                        .overlay(RadialGradient(stops: [.init(color: .black.opacity(0.42), location: 0), .init(color: .black.opacity(0.12), location: 0.7)], center: .center, startRadius: 0, endRadius: 66))
                        .clipShape(Circle())
                        .transition(.opacity)
                }
                // 左上の つや
                if !photoMode {
                    Ellipse().fill(LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 66, height: 24)
                        .rotationEffect(.degrees(-16))
                        .offset(x: -4, y: -42)
                }
                centerText(plan: plan, photoMode: photoMode)
            }
            .frame(width: 132, height: 132)
            .saturation(plan.done ? 0.4 : 1)
            .opacity(plan.done ? 0.82 : 1)
            .background(Circle().fill(.white.opacity(0.7)).padding(-6))
            .shadow(color: Color(red: 0.59, green: 0.35, blue: 0.55).opacity(0.45), radius: 15, y: 14)
            .scaleEffect(pressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: pressed)
            .keyframeAnimator(initialValue: 1.0, trigger: bounce &+ swap) { content, s in content.scaleEffect(s) } keyframes: { _ in
                CubicKeyframe(1.08, duration: 0.14); CubicKeyframe(1, duration: 0.18)
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

    /// はじめての 合図(ChicHomeView から)
    var hintEligible = false

    @ViewBuilder
    private var photo: some View {
        if let yesterdayImage {
            Image(uiImage: yesterdayImage).resizable().scaledToFill().frame(width: 132, height: 132)
        } else if let yesterdayPhoto {
            DarkThumb(photo: yesterdayPhoto, maxPixel: 400).frame(width: 132, height: 132)
        }
    }

    private func centerText(plan: HomeOrbRules.Plan, photoMode: Bool) -> some View {
        let c = plan.center
        let ink = photoMode ? Color.white : Color(hex: "111111")
        let title = plan.done ? String(localized: "home.orb.tomorrow") : c.title
        let font: Font = plan.done ? Darkroom.title(title, size: 24) : .custom("InstrumentSerif-Regular", size: photoMode ? 26 : 34)
        return VStack(spacing: 2) {
            Image(systemName: c.symbol)
                .font(.system(size: 19, weight: .semibold))
                .frame(width: 22, height: 22)
                .padding(.bottom, 2)
            Text(verbatim: title)
                .font(font)
                .tracking(-0.015 * 34)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .shadow(color: photoMode ? .black.opacity(0.4) : .white, radius: photoMode ? 5 : 7, y: photoMode ? 2 : 0)
            Text(verbatim: HomeOrbRules.sub(c, input: input, name: centerName, done: plan.done))
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .tracking(0.24 * 8.5)
                .foregroundStyle(photoMode ? Color(hex: "FFB27A") : Color(hex: "FF6A1A"))
                .shadow(color: photoMode ? .clear : .white, radius: 4)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 110)
                .padding(.top, 4)
        }
        .foregroundStyle(ink)
        .frame(width: 120)
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

    private func pill(plan: HomeOrbRules.Plan, t: Double) -> some View {
        let p = running ? (t.truncatingRemainder(dividingBy: 1.6)) / 1.6 : 1
        return HStack(spacing: 6) {
            Circle().fill(Color(hex: "FF6A1A")).frame(width: 6, height: 6)
                .background(Circle().fill(Color(hex: "FF6A1A").opacity(0.7 * (1 - p))).frame(width: 6 + 18 * p, height: 6 + 18 * p))
            Text(verbatim: HomeOrbRules.pill(plan.center))
                .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                .tracking(0.16 * 10.5)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(Capsule().fill(Color(hex: "111111")))
        .shadow(color: .black.opacity(0.4), radius: 7, y: 6)
    }

    // MARK: まわり

    private func satellite(_ action: HomeOrbAction, index i: Int, t: Double) -> some View {
        let locked = HomeOrbRules.isLocked(action, used: input.used)
        let dot = HomeOrbRules.hasDot(action, input: input)
        let line = locked ? Color(hex: "9C99A6") : Color(hex: "111111")
        let down = satPressed == action
        let float = running ? -4 * (1 - cos(2 * .pi * (t + 1.2 * Double(i)) / 5)) / 2 : 0
        return Button {
            if locked {
                LayerHaptics.softDouble()
                onLocked()
                return
            }
            Haptics.play(.pop)
            if reduceMotion { onSatellite(action); return }
            satBounce[action, default: 0] += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { onSatellite(action) }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Circle().fill(line).offset(y: down ? 1 : 3)
                    Circle().fill(locked ? Color(hex: "EEECF2") : Color(hex: action.tint))
                        .overlay(Circle().strokeBorder(line, lineWidth: 2.2))
                        .overlay {
                            Image(systemName: action.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(line)
                        }
                        .overlay(alignment: .topTrailing) {
                            if dot {
                                Circle().fill(Color(hex: "FF6A1A")).frame(width: 13, height: 13)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: 2.2))
                                    .offset(x: 2, y: -2)
                            }
                        }
                        .offset(y: down ? 2 : 0)
                }
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees((Double(i) - 1.5) * 5))
                .keyframeAnimator(initialValue: 1.0, trigger: satBounce[action, default: 0]) { content, s in content.scaleEffect(s) } keyframes: { _ in
                    CubicKeyframe(0.82, duration: 0.1); CubicKeyframe(1.08, duration: 0.14); CubicKeyframe(1, duration: 0.14)
                }
                Text(verbatim: action.label)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.14 * 8)
                    .foregroundStyle(locked ? Color(hex: "9C99A6") : Color(hex: "111111"))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.85)))
            }
            .frame(width: 70)
            .contentShape(Rectangle())
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: down)
        }
        .buttonStyle(HomeOrbPressStyle(pressed: Binding(get: { satPressed == action }, set: { satPressed = $0 ? action : (satPressed == action ? nil : satPressed) })))
        .offset(y: float + 4.5)
        .accessibilityLabel(Text(verbatim: action.title))
    }

    private func stickers(t: Double, reveal: Double) -> some View {
        let s = running ? sin(t * 2 * .pi / 5) : 0, s2 = running ? sin(t * 2 * .pi / 6) : 0
        // 見本 v32 の 位置(390 幅・高さ 300 の 中心から)。まわりの 4つと かさならない ように 角へ
        return ZStack {
            ChicDoodle(kind: .star, width: 36).rotationEffect(.degrees(10 * s)).offset(x: -157, y: -138 - 7 * s)
            ChicDoodle(kind: .wave, width: 50).rotationEffect(.degrees(-8 * s2)).offset(x: 152, y: -142 + 5 * s2)
            ChicDoodle(kind: .flower, width: 38).rotationEffect(.degrees(10 * s2)).offset(x: 142, y: 161 - 7 * s2)
            ChicDoodle(kind: .dots, width: 26).offset(x: -142, y: 133 + 5 * s)
        }
        .opacity(reveal)
        .allowsHitTesting(false)
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

/// 6まいの 絞りの 羽(見本の SVG:viewBox -50…50)。パステル 6色・白い 線
struct HomeApertureBlades: View {
    private static let colors = ["FFD6C2", "FFC9DF", "E3D4FF", "CDE4FF", "CFF3E5", "FFF0B8"]

    var body: some View {
        Canvas { ctx, size in
            let k = size.width / 100
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            for i in 0..<6 {
                let path = Self.blade(i, k: k)
                ctx.fill(path, with: .color(Color(hex: Self.colors[i])))
                ctx.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 1.4 * k, lineJoin: .round))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 内の 六角形(半径 20)から 外の 円(半径 48)へ
    static func blade(_ i: Int, k: CGFloat) -> Path {
        func pt(_ r: Double, _ deg: Double) -> CGPoint {
            let a = deg * .pi / 180
            return CGPoint(x: r * cos(a) * k, y: r * sin(a) * k)
        }
        let a0 = -90.0 + Double(i) * 60, a1 = a0 + 60
        // 見本:M(内 a0) L(内 a1) L(外 a1+…) A(外 a0+…)
        let outerEnd = a1 + 38, outerStart = a0 + 38
        var p = Path()
        p.move(to: pt(20, a0))
        p.addLine(to: pt(20, a1))
        p.addLine(to: pt(48, outerEnd))
        p.addArc(center: .zero, radius: 48 * k, startAngle: .degrees(outerEnd), endAngle: .degrees(outerStart), clockwise: true)
        p.closeSubpath()
        return p
    }
}

/// 3本の フィルムの 弧(のこり = 橙 + ほのかな 光 / 使った = うすい 灰)
struct HomeOrbFilmArcs: View {
    let used: Int

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = size.width / 2 * 46 / 50
            let k = size.width / 100
            for i in 0..<3 {
                var p = Path()
                let start = -132.0 + Double(i) * 120
                p.addArc(center: c, radius: r, startAngle: .degrees(start), endAngle: .degrees(start + 104), clockwise: false)
                let on = HomeOrbRules.arcIsRemaining(i, used: used)
                let style = StrokeStyle(lineWidth: 1.9 * k, lineCap: .round)
                if on {
                    var glow = ctx
                    glow.addFilter(.blur(radius: 3))
                    glow.stroke(p, with: .color(Color(hex: "FF6A1A").opacity(0.6)), style: style)
                    ctx.stroke(p, with: .color(Color(hex: "FF6A1A")), style: style)
                } else {
                    ctx.stroke(p, with: .color(Color(hex: "E4E1EA")), style: style)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 球の中の ドット(世界の光)と「あなたの光」(半径 58 の 橙の点線の輪。撮った数だけ ともる)
private struct HomeOrbDots: View {
    let used: Int
    let t: Double
    let reveal: Double

    private struct Dot { let r, a, w, s, tw, c: Double }

    private static let dots: [Dot] = {
        var rng = SeededRandom(seed: 22)
        func rand() -> Double { Double(rng.next() % 10_000) / 10_000 }
        let maxR = 86.0
        var list: [Dot] = []
        var ring = 0
        for r in stride(from: 14.0, through: maxR, by: 7.2) {
            let n = Int((2 * Double.pi * r / 7.6).rounded())
            let dir: Double = ring % 2 == 1 ? 1 : -1
            for i in 0..<n {
                list.append(Dot(r: r, a: Double(i) / Double(n) * 2 * .pi, w: dir * (0.00005 + (maxR - r) * 0.0000016) * 1000,
                                s: 0.5 + rand() * 0.9 + (r / maxR) * 0.5, tw: rand() * 6.3, c: rand()))
            }
            ring += 1
        }
        return list
    }()

    private static let palette: [Color] = [Color(red: 1, green: 0.54, blue: 0.16), Color(red: 1, green: 0.77, blue: 0.24), Color(red: 1, green: 0.47, blue: 0.63), Color(red: 0.43, green: 0.59, blue: 1), Color(red: 0.67, green: 0.51, blue: 1)]

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxR = 86.0
            // 光の波は ひかえめ(橙が 帯にならないように)
            let wave = (t.truncatingRemainder(dividingBy: 5.2) / 5.2) * (maxR + 30)
            var gray = Path(), ink = Path(), warm = Path()
            var colors = [Path](repeating: Path(), count: 5)
            for d in Self.dots where d.r <= reveal * (maxR + 2) {
                let an = d.a + t * d.w
                let x = c.x + cos(an) * d.r, y = c.y + sin(an) * d.r * 0.96
                let b = exp(-pow((d.r - wave) / 9, 2))
                var s = d.s * (1 + 0.55 * b)
                if used > 0 && d.c > 0.8 {
                    s *= 1.2
                    colors[Int(d.c * 50) % 5].addEllipse(in: CGRect(x: x - s, y: y - s, width: 2 * s, height: 2 * s))
                } else if d.c > 0.95 {
                    s *= 1.1
                    ink.addEllipse(in: CGRect(x: x - s, y: y - s, width: 2 * s, height: 2 * s))
                } else if b > 0.3 {
                    warm.addEllipse(in: CGRect(x: x - s, y: y - s, width: 2 * s, height: 2 * s))
                } else {
                    gray.addEllipse(in: CGRect(x: x - s, y: y - s, width: 2 * s, height: 2 * s))
                }
            }
            ctx.fill(gray, with: .color(Color(red: 0.55, green: 0.53, blue: 0.6).opacity(0.38)))
            ctx.fill(ink, with: .color(Color(red: 0.07, green: 0.07, blue: 0.08).opacity(0.5)))
            ctx.fill(warm, with: .color(Color(red: 1, green: 0.59, blue: 0.31).opacity(0.55)))
            for (i, path) in colors.enumerated() { ctx.fill(path, with: .color(Self.palette[i].opacity(0.8))) }

            // あなたの光
            let R = 58.0, rot = t * 0.18
            var ring = Path()
            ring.addEllipse(in: CGRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R))
            ctx.stroke(ring, with: .color(Color(red: 1, green: 0.42, blue: 0.1).opacity(0.35 * reveal)), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
            for i in 0..<3 {
                let an = rot - .pi / 2 + Double(i) * 2.0944
                let p = CGPoint(x: c.x + cos(an) * R, y: c.y + sin(an) * R)
                if i < used {
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 12, y: p.y - 12, width: 24, height: 24)),
                             with: .radialGradient(Gradient(stops: [
                                .init(color: Color(red: 1, green: 0.59, blue: 0.24).opacity(0.95), location: 0),
                                .init(color: Color(red: 1, green: 0.47, blue: 0.16).opacity(0.5), location: 0.35),
                                .init(color: .clear, location: 1),
                             ]), center: p, startRadius: 0, endRadius: 12))
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.2, y: p.y - 2.2, width: 4.4, height: 4.4)), with: .color(.white))
                } else {
                    let next = i == used
                    let r = next ? 4.2 : 3.2
                    let alpha = next ? 0.75 + 0.25 * sin(t * 4) : 0.4
                    ctx.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)),
                               with: .color(Color(red: 1, green: 0.42, blue: 0.1).opacity(alpha * reveal)), lineWidth: 1.3)
                }
            }
        }
        .frame(width: 184, height: 184)
        .clipShape(Circle())
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
                inner.draw(Text(String(ch)).font(.system(size: 8, design: .monospaced)).foregroundColor(Color(hex: "A9A6B0")), at: .zero)
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
