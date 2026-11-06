import SwiftUI
import UIKit

// v14 ⓪「Later today」:いちばん長くいる画面。撮影しても黒くならない(黒は ThemeClock の 21:00〜9:00 だけ)。
// 上から:ヘッダー(固定)→ 今日のフィルム(チェキ枠3つ + 朝焼けアーチ)→ 今日のみんな(リング)→
// 友達カード(色のモザイク + タグだけ)→ ME カード →(下に月:TodayView の層)。

// MARK: - データ

/// 今日撮った1枚(本物の写真データは持たない。時刻と街だけ)
struct TodayShot: Identifiable, Equatable {
    let id: String
    let takenAt: Date
    let city: String?
}

enum TodayFilmRules {
    /// 1日のコマ数
    static var frameCount: Int { FilmRoll.shotsPerDay }

    enum Frame: Equatable, Identifiable {
        /// 撮った(index は 0 から)
        case shot(TodayShot, index: Int)
        /// 次に撮る枠(オレンジの点線「＋ 撮る」)
        case next(index: Int)
        /// その先の枠(白い点線「あとで」)
        case later(index: Int)

        var id: String {
            switch self {
            case .shot(let shot, _): return "shot-\(shot.id)"
            case .next(let i): return "next-\(i)"
            case .later(let i): return "later-\(i)"
            }
        }
    }

    /// 3つの枠。撮った分 → 次の1枠 → のこりは「あとで」。撮れない時間なら「次」はなし
    static func frames(shots: [TodayShot], canShoot: Bool) -> [Frame] {
        let taken = Array(shots.sorted { $0.takenAt < $1.takenAt }.prefix(frameCount))
        var result: [Frame] = taken.enumerated().map { .shot($1, index: $0) }
        for index in taken.count..<frameCount {
            result.append(index == taken.count && canShoot ? .next(index: index) : .later(index: index))
        }
        return result
    }

    /// 枠の傾き(-3° / 0° / +3°)
    static func tilt(index: Int) -> Double { [-3, 0, 3][min(max(index, 0), 2)] }

    /// つぎの 9:00(今日の写真がひらく時刻)
    static func nextRevealDate(after now: Date, calendar: Calendar = .current) -> Date {
        PhotoDevelop.developDate(takenAt: now, calendar: calendar)
    }

    /// 「あと 16時間 30分」(分は切り上げ:0分にならない)
    static func remaining(now: Date, calendar: Calendar = .current) -> (hours: Int, minutes: Int) {
        let seconds = max(0, nextRevealDate(after: now, calendar: calendar).timeIntervalSince(now))
        let minutes = Int((seconds / 60).rounded(.up))
        return (minutes / 60, minutes % 60)
    }

    static func remainingText(now: Date, calendar: Calendar = .current) -> String {
        let r = remaining(now: now, calendar: calendar)
        return r.hours > 0 ? "あと \(r.hours)時間 \(r.minutes)分" : "あと \(r.minutes)分"
    }

    /// 朝焼けアーチの太陽:最初に撮った時刻 → つぎの 9:00 までの進み(0〜1)。撮っていなければ nil
    static func archProgress(shots: [TodayShot], now: Date, calendar: Calendar = .current) -> Double? {
        guard let first = shots.map(\.takenAt).min() else { return nil }
        let reveal = PhotoDevelop.developDate(takenAt: first, calendar: calendar)
        let total = reveal.timeIntervalSince(first)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(first) / total))
    }

    /// 月のことば:0枚「今日を 撮る」/ 1〜2枚「もう 1枚 撮る」/ 3枚「今日は おしまい」
    static func moonTitle(shots: Int) -> String {
        switch shots {
        case ..<1: return "今日を 撮る"
        case frameCount...: return "今日は おしまい"
        default: return "もう 1枚 撮る"
        }
    }

    static func moonSubtitle(shots: Int) -> String {
        let left = max(0, frameCount - shots)
        return left == 0 ? "あしたの 9:00 に ひらく" : "のこり \(left)フレーム"
    }

    /// 撮った時刻「23:41」
    static func timeText(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}

// MARK: - スクロールで出てくる(v14:下から 34pt + 0.96倍 → spring 0.55 / 0.7。出るたび pop)

struct ScrollReveal: ViewModifier {
    /// 同時に出るものは 70ms ずつずらす
    var index: Int = 0
    /// これが変わると、もう一度出る(タブを開き直したとき)
    var token: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        let visible = shown || reduceMotion
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 34)
            .scaleEffect(visible ? 1 : 0.96)
            .onScrollVisibilityChange(threshold: 0.18) { isVisible in
                guard isVisible, !shown else { return }
                let delay = Double(index % 4) * 0.07
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    guard !shown else { return }
                    Haptics.play(.pop)
                    if reduceMotion { shown = true } else { withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { shown = true } }
                }
            }
            .onChange(of: token) { _, _ in shown = false }
    }
}

extension View {
    func scrollReveal(_ index: Int = 0, token: Int = 0) -> some View { modifier(ScrollReveal(index: index, token: token)) }
}

// MARK: - 今日のホーム(本体)

struct LaterTodayHome: View {
    let state: HomeState
    let now: Date
    let shots: [TodayShot]
    let data: HomeLayerData
    let actions: HomeLayerActions
    let isActive: Bool
    /// 撮った枠をタップ → 現像ページャーのその枚数目
    let onOpenShot: (Int) -> Void
    let onShoot: () -> Void
    let onOpenMe: () -> Void
    let onFriend: (HomeFriend) -> Void
    let onInvite: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            TodayFilmSection(state: state, now: now, shots: shots, isActive: isActive, onOpenShot: onOpenShot, onShoot: onShoot)
                .scrollReveal(0)
            TodayFriendsSection(state: state, data: data, actions: actions, onFriend: onFriend, onInvite: onInvite)
                .scrollReveal(1)
            if !data.friends.isEmpty {
                TodayFriendCards(friends: data.friends)
                    .scrollReveal(2)
            }
            MECard(caption: "これまでの 7日", film: data.film, isActive: isActive, onTap: onOpenMe)
                .padding(.horizontal, 22)
                .scrollReveal(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 今日のフィルム

/// 黒いフィルム帯(上下にスプロケット穴)+ チェキ枠3つ + 朝焼けアーチ
struct TodayFilmSection: View {
    let state: HomeState
    let now: Date
    let shots: [TodayShot]
    let isActive: Bool
    let onOpenShot: (Int) -> Void
    let onShoot: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 撮って戻ってきた1枚(上から落ちてくる)
    @State private var landingID: String?
    @State private var knownShotIDs: Set<String> = []
    @State private var toast: String?

    static let orange = Color(hex: "FF8A3D")
    static let band = Color(hex: "121215")

    private var frames: [TodayFilmRules.Frame] { TodayFilmRules.frames(shots: shots, canShoot: state.canShoot) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("今日のフィルム")
                    .font(.system(size: 22, weight: .heavy))
                    .tracking(-0.03 * 22)
                    .foregroundStyle(palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(min(shots.count, TodayFilmRules.frameCount)) / \(TodayFilmRules.frameCount)")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.isNight ? Color(hex: "FFB074") : Color(hex: "C2410C"))
                    .accessibilityLabel("\(shots.count)枚、\(TodayFilmRules.frameCount)枚まで")
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 12)

            VStack(spacing: 0) {
                FilmSprocketRow()
                HStack(spacing: 10) {
                    ForEach(frames) { frame in
                        frameView(frame)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                FilmSprocketRow()
            }
            .background(Self.band)
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(palette.bg)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(palette.ink))
                        .offset(y: 22)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }

            SunriseArch(progress: TodayFilmRules.archProgress(shots: shots, now: now), now: now, isActive: isActive)
                .padding(.top, 22)
                .padding(.horizontal, 22)
        }
        .onAppear { knownShotIDs = Set(shots.map(\.id)) }
        .onChange(of: shots.map(\.id)) { _, ids in
            // 撮影から戻ってきた:新しい1枚が上から落ちてきて、はね返って枠におさまる(0.9秒)。着地で thud
            let fresh = ids.first { !knownShotIDs.contains($0) }
            knownShotIDs = Set(ids)
            guard let fresh else { return }
            landingID = fresh
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.05 : 0.55)) { Haptics.play(.thud) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { if landingID == fresh { landingID = nil } }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toast)
    }

    @ViewBuilder
    private func frameView(_ frame: TodayFilmRules.Frame) -> some View {
        switch frame {
        case .shot(let shot, let index):
            Button {
                Haptics.play(.pop)
                onOpenShot(index)
            } label: {
                ChekiFrame(shot: shot, index: index)
            }
            .buttonStyle(SquishButtonStyle())
            .rotationEffect(.degrees(TodayFilmRules.tilt(index: index)))
            .modifier(DropIn(active: landingID == shot.id))
            .accessibilityLabel("\(index + 1)枚目、\(TodayFilmRules.timeText(shot.takenAt))\(shot.city.map { "、\($0)" } ?? "")。9:00 まで ひみつ")
            .accessibilityHint("現像中の1枚を見る")
        case .next(let index):
            Button {
                Haptics.play(.pop)
                onShoot()
            } label: {
                NextFrame(isActive: isActive)
            }
            .buttonStyle(SquishButtonStyle())
            .rotationEffect(.degrees(TodayFilmRules.tilt(index: index)))
            .accessibilityLabel("\(index + 1)枚目を撮る")
        case .later(let index):
            Button {
                Haptics.play(.warn)
                show(state.canShoot ? "つぎの 1枚から" : "あしたの 9:00 から")
            } label: {
                LaterFrame()
            }
            .buttonStyle(SquishButtonStyle())
            .rotationEffect(.degrees(TodayFilmRules.tilt(index: index)))
            .accessibilityLabel("\(index + 1)枚目。あとで")
        }
    }

    private func show(_ message: String) {
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { if toast == message { toast = nil } }
    }
}

/// 上から落ちてきて、少しはね返って枠におさまる(0.9秒の spring)
private struct DropIn: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var y: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: y)
            .onAppear { if active { drop() } }
            .onChange(of: active) { _, now in if now { drop() } }
    }

    private func drop() {
        guard !reduceMotion else { return }
        y = -420
        withAnimation(.spring(duration: 0.9, bounce: 0.35)) { y = 0 }
    }
}

/// 撮った枠:クリーム色のチェキ。中は ぼかし + もや + 鍵(9:00 まで ひみつ)。下に時刻と街。
/// 本物の写真データは使わない(色も形も、写真からは作らない)。
private struct ChekiFrame: View {
    let shot: TodayShot
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                LinearGradient(colors: Self.fog(index), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .blur(radius: 6)
                TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: reduceMotion)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let breath = reduceMotion ? 0.5 : (1 - cos(t * 2 * .pi / 4 + Double(index))) / 2
                    Color.white.opacity(0.35 + 0.2 * breath)
                }
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: "4A3A2C"))
            }
            .frame(height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            VStack(spacing: 1) {
                Text(TodayFilmRules.timeText(shot.takenAt))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                Text(shot.city ?? " ")
                    .font(.system(size: 9.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Color(hex: "3A2E24"))
        }
        .padding(7)
        .padding(.bottom, 2)
        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color(hex: "FFFBF2")))
        .shadow(color: .black.opacity(0.4), radius: 8, y: 6)
        .frame(maxWidth: .infinity)
    }

    /// もやの色(写真から作らない。枚数ごとに決まった朝焼けの色)
    static func fog(_ index: Int) -> [Color] {
        let sets: [[String]] = [["F6D7C3", "E9C9D8", "CFD6EA"], ["F2E3C8", "D8E6DA", "C9D6EC"], ["EBD4E4", "F3DCC6", "D2CDEB"]]
        return sets[index % sets.count].map { Color(hex: $0) }
    }
}

/// 次に撮る枠:オレンジの点線 +「＋ 撮る」が呼吸するように光る
private struct NextFrame: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion || !isActive)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let breath = reduceMotion ? 0.5 : (1 - cos(t * 2 * .pi / 2.6)) / 2
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(TodayFilmSection.orange.opacity(0.06 + 0.10 * breath))
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(TodayFilmSection.orange, style: StrokeStyle(lineWidth: 1.8, dash: [5, 4]))
                VStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 20, weight: .bold))
                    Text("撮る").font(.system(size: 13, weight: .heavy))
                }
                .foregroundStyle(TodayFilmSection.orange)
                .shadow(color: TodayFilmSection.orange.opacity(0.7 * breath), radius: 8)
            }
        }
        .frame(height: 158)
        .frame(maxWidth: .infinity)
    }
}

/// その先の枠:白い点線「あとで」
private struct LaterFrame: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Color.white.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            Text("あとで")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "B4B4BC"))
        }
        .frame(height: 158)
        .frame(maxWidth: .infinity)
    }
}

/// フィルムの穴の列(白い点線)
struct FilmSprocketRow: View {
    var body: some View {
        Canvas { context, size in
            let w: CGFloat = 9, h: CGFloat = 6, gap: CGFloat = 9
            var x: CGFloat = 6
            while x < size.width {
                let rect = CGRect(x: x, y: (size.height - h) / 2, width: w, height: h)
                context.fill(Path(roundedRect: rect, cornerRadius: 1.8), with: .color(Color.white.opacity(0.22)))
                x += w + gap
            }
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }
}

// MARK: - 朝焼けアーチ

/// 半円の線。撮った時刻 → あした 9:00 までの進みで、太陽の点が左から右へ動く。
/// 0枚のときは太陽を出さず「撮ったら / あしたの 9:00 に ひらく」。
struct SunriseArch: View {
    let progress: Double?
    let now: Date
    let isActive: Bool

    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let r = min(w / 2 - 6, 150)
            let center = CGPoint(x: w / 2, y: r + 8)
            ZStack {
                Path { p in p.addArc(center: center, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false) }
                    .stroke(LinearGradient(colors: GroupAddColors.sunset, startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: progress == nil ? [3, 6] : []))
                    .opacity(progress == nil ? 0.5 : 1)
                if let progress {
                    let angle = Double.pi + Double.pi * progress
                    let sun = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: "FFE08A"), Color(hex: "FF8A3D")], center: .center, startRadius: 0, endRadius: 10))
                        .frame(width: 18, height: 18)
                        .shadow(color: Color(hex: "FF8A3D").opacity(0.8), radius: 10)
                        .position(sun)
                }
                VStack(spacing: 4) {
                    if progress != nil {
                        Text("ひらくまで")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(palette.groupAdd.note)
                        Text(TodayFilmRules.remainingText(now: now))
                            .font(.system(size: 24, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(palette.ink)
                        Text("あした 9:00")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(palette.groupAdd.note)
                    } else {
                        Text("撮ったら")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(palette.groupAdd.note)
                        Text("あしたの 9:00 に ひらく")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(palette.ink)
                    }
                }
                .position(x: center.x, y: center.y - r * 0.38)
            }
        }
        .frame(height: 160)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progress == nil ? "撮ったら、あしたの 9:00 に ひらく" : "ひらくまで、\(TodayFilmRules.remainingText(now: now))。あした 9:00")
    }
}

// MARK: - 今日のみんな(リング)

struct TodayFriendsSection: View {
    let state: HomeState
    let data: HomeLayerData
    let actions: HomeLayerActions
    let onFriend: (HomeFriend) -> Void
    let onInvite: () -> Void

    @Environment(\.palette) private var palette
    @State private var knocks = KnockStore.shared
    @State private var focusedID: String?
    @State private var tick = ScrollTickHaptics()
    /// つよく つついた相手(リングがぐらっと揺れる)
    @State private var shaken: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("今日のみんな")
                    .font(.system(size: 22, weight: .heavy))
                    .tracking(-0.03 * 22)
                    .foregroundStyle(palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(data.friends.count) / \(FriendRules.maxFriends)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.groupAdd.note)
            }
            .padding(.horizontal, 22)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(data.friends) { friend in
                        TodayFriendRing(
                            friend: friend,
                            status: HomeLayerRules.friendStatus(state: state, friend: friend, knockedToday: knocks.hasKnocked(friend.id, window: data.windowKey)),
                            shaking: shaken == friend.id,
                            onOpen: { onFriend(friend) },
                            onKnock: { strong in
                                actions.knock(friend)
                                if strong {
                                    shaken = friend.id
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { if shaken == friend.id { shaken = nil } }
                                }
                            }
                        )
                        .id(friend.id)
                    }
                    Button {
                        Haptics.play(.pop)
                        onInvite()
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(LinearGradient(colors: GroupAddColors.sunset, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(Image(systemName: "plus").font(.system(size: 26, weight: .light)).foregroundStyle(.white))
                                .frame(width: 70, height: 70)
                            Text("呼ぶ").font(.system(size: 12.5, weight: .bold)).foregroundStyle(palette.ink)
                            Text("つながる").font(.system(size: 10.5, weight: .bold)).foregroundStyle(palette.groupAdd.note).frame(height: 24)
                        }
                        .frame(width: 76)
                    }
                    .buttonStyle(SquishButtonStyle())
                    .accessibilityLabel("ともだちを呼ぶ")
                }
                .scrollTargetLayout()
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focusedID, anchor: .leading)
            .padding(.vertical, -12)
            .onChange(of: focusedID) { _, id in tick.step(id) }
        }
    }
}

/// 1人ぶん:撮った人は朝焼けリング +「撮った」、まだの人は点線 +「つつく」(長押しで ためて つつく)
private struct TodayFriendRing: View {
    let friend: HomeFriend
    let status: HomeLayerRules.FriendStatus
    let shaking: Bool
    let onOpen: () -> Void
    let onKnock: (_ strong: Bool) -> Void

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 6) {
            Button(action: onOpen) {
                ZStack {
                    if status == .shot {
                        Circle().fill(AngularGradient(colors: [Color(hex: "FFD60A"), Color(hex: "FF6A1A"), Color(hex: "FF7AB6"), Color(hex: "FFD60A")], center: .center, startAngle: .degrees(200), endAngle: .degrees(560)))
                    } else {
                        Circle().strokeBorder(Color(hex: "A9A9B3"), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    }
                    LayerAvatar(data: friend.avatarData, seed: friend.seed, name: friend.name)
                        .frame(width: 60, height: 60)
                        .saturation(status == .shot ? 1 : 0.55)
                        .overlay(Circle().strokeBorder(palette.bg, lineWidth: 3))
                }
                .frame(width: 70, height: 70)
                .keyframeAnimator(initialValue: 0.0, trigger: shaking) { content, angle in
                    content.rotationEffect(.degrees(angle))
                } keyframes: { _ in
                    KeyframeTrack {
                        if shaking && !reduceMotion {
                            LinearKeyframe(-12, duration: 0.08)
                            LinearKeyframe(10, duration: 0.1)
                            LinearKeyframe(-7, duration: 0.1)
                            LinearKeyframe(4, duration: 0.1)
                            SpringKeyframe(0, duration: 0.25)
                        } else {
                            LinearKeyframe(0, duration: 0.01)
                        }
                    }
                }
            }
            .buttonStyle(SquishButtonStyle())
            .accessibilityLabel(friend.name + (status == .shot ? "、撮った" : "、まだ"))

            Text(friend.name)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(palette.ink)
                .lineLimit(1)
            Group {
                switch status {
                case .shot:
                    HStack(spacing: 5) {
                        Circle().fill(LinearGradient(colors: GroupAddColors.sunset, startPoint: .leading, endPoint: .trailing)).frame(width: 6, height: 6)
                        Text("撮った")
                    }
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(LayerFriendColors.shotText(night: palette.isNight))
                case .canKnock:
                    ChargeKnockButton(name: friend.name, onKnock: onKnock)
                case .knocked:
                    Text("つついた")
                        .font(.system(size: 10.5, weight: .heavy))
                        .foregroundStyle(palette.groupAdd.note)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(Capsule().fill(palette.fill))
                case .notYet:
                    Text("まだ").font(.system(size: 10.5, weight: .bold)).foregroundStyle(palette.groupAdd.note)
                case .resting:
                    Text("おやすみ").font(.system(size: 10.5, weight: .bold)).foregroundStyle(palette.groupAdd.note)
                }
            }
            .frame(height: 24)
        }
        .frame(width: 76)
    }
}

/// ためて つつく(v14 2-B ②・Buzz 風)。タップ = ふつうに つつく(heart 弱)。
/// 長押し:ボタンが震えながら強くなる(240ms ごとに tick → 0.9秒から thud)。0.9秒こえて離す = つよく(rumble)。
struct ChargeKnockButton: View {
    let name: String
    let onKnock: (_ strong: Bool) -> Void

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressStart: Date?
    @State private var beatTask: Task<Void, Never>?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: pressStart == nil)) { context in
            let charge = ChargeKnock.charge(since: pressStart, now: context.date)
            let wobble = reduceMotion || pressStart == nil ? 0 : sin(context.date.timeIntervalSinceReferenceDate * 60) * (0.6 + 2.4 * charge)
            Text(charge >= 1 ? "つよく!" : "つつく")
                .font(.system(size: 10.5, weight: .heavy))
                .foregroundStyle(palette.bg)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Capsule().fill(charge >= 1 ? Color(hex: "FF6A1A") : palette.ink))
                .scaleEffect(1 + 0.18 * charge)
                .offset(x: wobble)
        }
        .contentShape(Capsule().inset(by: -10))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if pressStart == nil { begin() } }
                .onEnded { _ in end() }
        )
        .accessibilityElement()
        .accessibilityLabel("\(name)を つつく")
        .accessibilityHint("長押しで、つよく つつく")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onKnock(false); Haptics.play(.heart, intensity: 0.6) }
        .accessibilityAction(named: "つよく つつく") { onKnock(true); Haptics.play(.rumble) }
    }

    private func begin() {
        pressStart = Date()
        Haptics.prepare(.tick)
        beatTask?.cancel()
        beatTask = Task { @MainActor in
            var beats = 0
            while !Task.isCancelled, let start = pressStart {
                try? await Task.sleep(for: .seconds(ChargeKnock.beatInterval))
                guard !Task.isCancelled, pressStart != nil else { return }
                beats += 1
                Haptics.play(Date().timeIntervalSince(start) >= ChargeKnock.strongAfter ? .thud : .tick, gap: 0)
            }
        }
    }

    private func end() {
        let strong = ChargeKnock.isStrong(since: pressStart, now: Date())
        beatTask?.cancel()
        beatTask = nil
        pressStart = nil
        if strong {
            Haptics.play(.rumble)
        } else {
            Haptics.play(.heart, intensity: 0.6)
        }
        onKnock(strong)
    }
}

/// ためて つつく の決まり(テストで確かめる)
enum ChargeKnock {
    /// これより長く押して離すと「つよく」
    static let strongAfter: TimeInterval = 0.9
    /// 長押し中の tick の間隔
    static let beatInterval: TimeInterval = 0.24

    static func charge(since start: Date?, now: Date) -> Double {
        guard let start else { return 0 }
        return min(1, max(0, now.timeIntervalSince(start) / strongAfter))
    }

    static func isStrong(since start: Date?, now: Date) -> Bool {
        guard let start else { return false }
        // 小数の誤差で 0.9秒ちょうどを取りこぼさない
        return now.timeIntervalSince(start) >= strongAfter - 0.0005
    }
}

// MARK: - 友達カード(色のモザイク 6×6 + タグだけ。写真は見せない)

struct TodayFriendCards: View {
    let friends: [HomeFriend]
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 10) {
            ForEach(friends.filter(\.hasShot).prefix(6)) { friend in
                HStack(spacing: 14) {
                    MosaicView(tiny: friend.mosaicTiny, key: "today-\(friend.mosaicKey)", level: .l0)
                        .frame(width: 66, height: 66)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(friend.name)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(palette.ink)
                        if let tag = friend.tag {
                            Text("#\(tag)")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .frame(height: 24)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Color(hex: "2F6BFF")))
                        }
                    }
                    Spacer(minLength: 6)
                    Text("9:00 ↗")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.groupAdd.note)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(palette.fill))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(friend.name)\(friend.tag.map { "、#\($0)" } ?? "")。9:00 に ひらく")
            }
        }
        .padding(.horizontal, 22)
    }
}

// MARK: - ME カード

/// 黒地に巨大な「ME」+ フィルム3枚がふわふわ浮く。タップで ME 画面(円形に広がる)。
/// ME 画面が広がりはじめる位置(最後に押した ME カードの中心。nil ならアバターのあたり)
@MainActor
enum MERevealOrigin {
    static var point: CGPoint?
}

struct MECard: View {
    @State private var frameCenter: CGPoint = .zero
    let caption: String
    let film: [HomeFilmDay]
    let isActive: Bool
    let onTap: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 浮かせる3枚(仕上がった写真だけ。なければ色の札)
    private var thumbs: [Data?] {
        let photos: [Data?] = film.compactMap { day in
            if case .photo(let data) = day.kind { return data }
            return nil
        }
        return Array((photos + [nil, nil, nil]).prefix(3))
    }

    var body: some View {
        Button {
            Haptics.play(.pop)
            MERevealOrigin.point = frameCenter
            onTap()
        } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 32, style: .continuous).fill(palette.ink)
                Text("ME")
                    .font(.system(size: 64, weight: .heavy))
                    .tracking(-0.07 * 64)
                    .foregroundStyle(palette.bg)
                    .padding(.leading, 22)
                    .padding(.top, 12)
                Text(caption)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(0.14 * 11)
                    .foregroundStyle(palette.bg.opacity(0.75))
                    .padding(.leading, 24)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 20)
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || !isActive)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(0..<3, id: \.self) { i in
                            let phase = reduceMotion ? 0 : sin((t + Double(i) * 1.5) / 4.5 * 2 * .pi)
                            METhumb(data: thumbs[i], index: i)
                                .frame(width: 66, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .shadow(color: .black.opacity(0.5), radius: 8, y: 6)
                                .offset(y: [0, 14, 4][i] - 3 * phase)
                                .rotationEffect(.degrees(phase))
                        }
                    }
                    .rotationEffect(.degrees(-7))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 18)
                .offset(x: 10)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(palette.bg)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(18)
            }
            .frame(height: 168)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 20, y: 14)
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
        .onGeometryChange(for: CGPoint.self) { proxy in
            let f = proxy.frame(in: .global)
            return CGPoint(x: f.midX, y: f.midY)
        } action: { frameCenter = $0 }
        .accessibilityLabel("ME。\(caption)")
        .accessibilityHint("自分の画面をひらく")
    }
}

private struct METhumb: View {
    let data: Data?
    let index: Int

    var body: some View {
        if let data, let image = LayerImageCache.avatar(data, key: "me-card-\(index)-\(data.count)") {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            LinearGradient(colors: ChekiFrameColors.placeholder(index), startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

enum ChekiFrameColors {
    static func placeholder(_ index: Int) -> [Color] {
        let sets: [[String]] = [["FFB27A", "FF6A8A", "6C5BA8"], ["9AD0E8", "E9F1E4", "F2B56B"], ["2C3E6B", "E6709A", "FFC27A"]]
        return sets[index % sets.count].map { Color(hex: $0) }
    }
}

// MARK: - ともだちの決まり

enum FriendRules {
    /// 友達の上限(v14 確定)
    static let maxFriends = 12
    static let fullMessage = "ともだちは \(maxFriends)人まで"

    /// つながれるか(自分・相手の、どちらかが 12人なら、つながれない)
    static func canConnect(myCount: Int, theirCount: Int) -> Bool {
        myCount < maxFriends && theirCount < maxFriends
    }
}
