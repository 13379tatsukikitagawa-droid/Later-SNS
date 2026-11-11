import SwiftUI
import UIKit

// v23:Home の 下の 区画(2日目から)。見本:later_v23.html の「きのうの 3こま」「7日の film」「WORLD」。
// - きのうの 3こま:ひらいた 自分の 写真を チェキで 重ねる。タップで めくる・長押し 0.7秒で ★ 1年 のこす
// - 7日の film:今日 → 6日前 の フィルム。古い日から きえる。こまを 長押しで ★ 1年 のこす(1日 1枚)
// - WORLD:いま 朝の 9:00 が きている 街。なぞると 時間が うごき、はなすと いまに もどる
// ★ は ME と 同じ MEPickStore(端末の 中だけ・1年)。解禁・投稿の 処理には ふれない。

// MARK: - 決めごと

enum V23Rules {
    /// きのうの こま(ひらいたものだけ。撮った順)
    static func yesterdayShots(_ days: [MEDay]) -> [MEShot] {
        guard let day = days.first(where: { $0.ago == 1 }) else { return [] }
        return day.shots.filter { $0.reveal.isOpen }
    }

    /// 7日の こまの 合計(ひらく前の 今日も 数える)
    static func weekTotal(_ days: [MEDay]) -> Int { days.reduce(0) { $0 + $1.shots.count } }

    /// 日の 下の 文字:今日 / あした きえる / あと N日
    static func dayLabel(ago: Int) -> String {
        if ago == 0 { return "今日" }
        let left = MERules.days - ago
        return left <= 1 ? "あした きえる" : "あと \(left)日"
    }

    /// 選んだ日の ひとこと
    static func caption(ago: Int, count: Int, hasStar: Bool) -> String {
        let left = MERules.days - ago
        if ago == 0 { return "今日の film ・ 9:00 に ひらく" }
        if left <= 1 {
            return hasStar ? "あした きえます ・ ★ の 1枚は 1年 のこる" : "あした きえます。のこす 1枚を ★ で えらんで"
        }
        return "あと \(left)日で きえる ・ \(count)こま"
    }

    // MARK: WORLD(世界の 9:00)

    struct City: Equatable {
        let ja: String
        let en: String
        /// UTC からの 時差(時間)
        let zone: Double
    }

    static let cities: [City] = [
        City(ja: "ホノルル", en: "Honolulu", zone: -10),
        City(ja: "ロサンゼルス", en: "LA", zone: -8),
        City(ja: "ニューヨーク", en: "NY", zone: -5),
        City(ja: "サンパウロ", en: "São Paulo", zone: -3),
        City(ja: "ロンドン", en: "London", zone: 0),
        City(ja: "パリ", en: "Paris", zone: 1),
        City(ja: "ドバイ", en: "Dubai", zone: 4),
        City(ja: "デリー", en: "Delhi", zone: 5.5),
        City(ja: "バンコク", en: "Bangkok", zone: 7),
        City(ja: "東京", en: "Tokyo", zone: 9),
        City(ja: "シドニー", en: "Sydney", zone: 11),
    ]

    struct Morning: Equatable {
        /// いま 9:00 の 時差(-12〜12)
        let zone: Double
        let city: City
        let next: City
        /// つぎの 街に 9:00 が くるまで(時間)
        let hoursToNext: Double
    }

    /// utcHours(0〜24 + ずらした 分)のとき、どこが 9:00 か
    static func morning(utcHours: Double) -> Morning {
        var z = 9 - utcHours
        z = ((z + 12).truncatingRemainder(dividingBy: 24) + 24).truncatingRemainder(dividingBy: 24) - 12
        if z < -11 { z += 24 }
        let city = cities.min { abs($0.zone - z) < abs($1.zone - z) } ?? cities[4]
        let west = cities.filter { $0.zone < city.zone }.max { $0.zone < $1.zone } ?? cities[cities.count - 1]
        let hours = ((z - west.zone).truncatingRemainder(dividingBy: 24) + 24).truncatingRemainder(dividingBy: 24)
        return Morning(zone: z, city: city, next: west, hoursToNext: hours)
    }

    /// 「2h 10m」
    static func hm(_ hours: Double) -> String {
        let total = Int((hours * 60).rounded())
        return "\(total / 60)h \(String(format: "%02d", total % 60))m"
    }

    static func utcHours(_ date: Date) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
    }
}

/// 写真の 読みこみ(ME と 同じ 小さな 画像)
private struct V23Thumb: View {
    let key: String
    let data: Data?

    @State private var image: UIImage?

    var body: some View {
        Color(hex: "26262B")
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipped()
            .task(id: key) {
                image = MEImageLoader.cached(key)
                guard image == nil, let data else { return }
                image = await MEImageLoader.load(key: key, data: data)
            }
    }
}

/// ★(黄色い 星。黒の ふち)
private struct V23Star: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addCurve(to: CGPoint(x: w, y: h * 0.5), control1: CGPoint(x: w * 0.54, y: h * 0.25), control2: CGPoint(x: w * 0.75, y: h * 0.42))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h), control1: CGPoint(x: w * 0.75, y: h * 0.58), control2: CGPoint(x: w * 0.54, y: h * 0.75))
        p.addCurve(to: CGPoint(x: 0, y: h * 0.5), control1: CGPoint(x: w * 0.46, y: h * 0.75), control2: CGPoint(x: w * 0.25, y: h * 0.58))
        p.addCurve(to: CGPoint(x: w * 0.5, y: 0), control1: CGPoint(x: w * 0.25, y: h * 0.42), control2: CGPoint(x: w * 0.46, y: h * 0.25))
        p.closeSubpath()
        return p
    }
}

// MARK: - きのうの 3こま

struct V23YesterdaySection: View {
    let day: MEDay
    let shots: [MEShot]
    let photos: [LaterPhoto]
    let ink: V17Ink
    /// はじめての 合図(keep)を 出してよい
    let hintEligible: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var top = 0
    @State private var kept: String? = nil
    @State private var holding = false
    @State private var hold: CGFloat = 0
    @State private var keepFlash = 0
    @State private var flip = 0

    private var count: Int { shots.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            V17SectionHeader(kicker: "OPENED AT 9:00 ・ \(MERules.dot(day.date))", title: "きのうの 3こま", number: "\(top + 1) / \(count)", ink: ink)
            ZStack {
                ForEach(Array(shots.enumerated()), id: \.element.id) { index, shot in
                    card(shot, index: index)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 330)
            .padding(.top, 10)
        }
        .onAppear { kept = MEPickStore.pick(day: day.key) }
    }

    private func order(_ index: Int) -> Int { (index - top + count) % count }

    private func card(_ shot: MEShot, index: Int) -> some View {
        let o = order(index)
        let isTop = o == 0
        let photo = photos.first { $0.id == shot.photoID }
        let rotations: [Double] = [-3, 4, 9]
        return VStack(spacing: 0) {
            V23Thumb(key: shot.id, data: photo?.imageData)
                .frame(width: 190, height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .overlay {
                    // 長押しの 輪(0.7秒で 1周)
                    if isTop && holding {
                        Circle().trim(from: 0, to: hold)
                            .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 70, height: 70)
                            .shadow(color: .black.opacity(0.4), radius: 6)
                            .offset(y: -20)
                    }
                }
                .overlay {
                    if isTop {
                        Text("1年 のこる")
                            .font(.system(size: 13, weight: .black))
                            .tracking(0.06 * 13)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 8)
                            .keyframeAnimator(initialValue: 0.0, trigger: keepFlash) { v, k in v.opacity(k).offset(y: -8 * k) } keyframes: { _ in
                                KeyframeTrack { LinearKeyframe(1, duration: 0.25); LinearKeyframe(1, duration: 0.8); LinearKeyframe(0, duration: 0.35) }
                            }
                    }
                }
            HStack {
                Text(photo?.tags.first.map { "#" + $0 } ?? "")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Color(hex: "111111"))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(TodayFilmRules.timeText(shot.takenAt))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(0.06 * 12)
                    .foregroundStyle(Color(hex: "FF7A1A"))
            }
            .padding(.horizontal, 2)
            .frame(height: 34)
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .frame(width: 210)
        .background(RoundedRectangle(cornerRadius: 4).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.black.opacity(0.05), lineWidth: 1))
        .shadow(color: Color(red: 0.24, green: 0.12, blue: 0.31).opacity(0.35), radius: 18, y: 18)
        .overlay(alignment: .topTrailing) {
            V23Star()
                .fill(Color(hex: "FFD60A"))
                .overlay(V23Star().stroke(Color(hex: "111111"), lineWidth: 2.2))
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(kept == shot.id ? -8 : -30))
                .scaleEffect(kept == shot.id ? 1 : 0.01)
                .opacity(kept == shot.id ? 1 : 0)
                .offset(x: 12, y: -14)
                .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.45), value: kept)
        }
        .scaleEffect(isTop && holding ? 0.97 : 1)
        .scaleEffect(1 - CGFloat(o) * 0.05)
        .rotationEffect(.degrees(rotations[min(o, 2)]))
        .offset(x: CGFloat(o) * 16, y: CGFloat(o) * 8)
        .zIndex(Double(3 - o))
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.62), value: top)
        .allowsHitTesting(isTop)
        .onTapGesture { flipNext() }
        .onLongPressGesture(minimumDuration: 0.7, maximumDistance: 12) {
            keep(shot, photo: photo)
        } onPressingChanged: { pressing in
            if pressing {
                holding = true
                hold = 0
                withAnimation(.linear(duration: 0.7)) { hold = 1 }
            } else {
                holding = false
                hold = 0
            }
        }
        .modifier(KeepHint(active: isTop, eligible: hintEligible))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("きのうの \(index + 1)こま目。\(TodayFilmRules.timeText(shot.takenAt))\(kept == shot.id ? "。1年 のこす 1枚" : "")")
        .accessibilityAction(named: "めくる") { flipNext() }
        .accessibilityAction(named: "1年 のこす") { keep(shot, photo: photo) }
    }

    private func flipNext() {
        guard count > 1 else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        HintCenter.shared.touched(.keep)
        top = (top + 1) % count
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { Haptics.play(.tick) }
    }

    /// ★ 1年 のこす(ME と 同じ。その日の 前の ★ は 移る)
    private func keep(_ shot: MEShot, photo: LaterPhoto?) {
        HintCenter.shared.touched(.keep)
        holding = false
        MEPickStore.set(day: day.key, shotID: shot.id, imageData: photo?.imageData, videoURL: photo.flatMap { LaterVideoStore.localURL(for: $0) })
        kept = shot.id
        keepFlash += 1
        Haptics.play(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { Haptics.play(.land) }
    }
}

/// いちばん上の チェキにだけ 合図(keep)を つける
private struct KeepHint: ViewModifier {
    let active: Bool
    let eligible: Bool

    func body(content: Content) -> some View {
        if active {
            content.firstHint(.keep, eligible: eligible, edge: .top, shape: .rounded(4), onDark: false, gap: 14)
        } else {
            content
        }
    }
}

// MARK: - 7日の film

struct V23WeekFilmSection: View {
    let days: [MEDay]
    let photos: [LaterPhoto]
    let ink: V17Ink
    var onToast: (String) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selected = 0
    @State private var stars: [String: String] = [:]
    @State private var holdingFrame: String?
    @State private var mid = 0
    @State private var thumb: (x: CGFloat, w: CGFloat) = (0.7, 0.3)
    @State private var countShown = 0

    static let cardWidth: CGFloat = 132

    /// 古い日が 左。今日が 右はし
    private var ordered: [MEDay] { days.sorted { $0.ago > $1.ago } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            V17SectionHeader(kicker: "7 DAYS", title: "7日の", accent: "film", ink: ink)
            HStack(alignment: .lastTextBaseline, spacing: 14) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(countShown)")
                        .font(.system(size: 46, weight: .black))
                        .tracking(-0.06 * 46)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("こま").font(.system(size: 13, weight: .heavy))
                }
                .foregroundStyle(ink.ink)
                Text("古い日から きえる")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ink.sub)
                    .padding(.bottom, 4)
            }
            strip
                .padding(.horizontal, -22)
            rail
            caption
                .padding(.top, 14)
        }
        .onAppear {
            stars = MEPickStore.picks
            let total = V23Rules.weekTotal(days)
            if reduceMotion { countShown = total } else {
                withAnimation(.easeOut(duration: 0.9)) { countShown = total }
            }
        }
    }

    private var strip: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { index, day in
                        dayCard(day, first: index == 0, last: index == ordered.count - 1)
                            .id(day.ago)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
            }
            .onAppear {
                DispatchQueue.main.async { reader.scrollTo(0, anchor: .trailing) }
            }
            .onScrollGeometryChange(for: CGRect.self) { geo in
                CGRect(x: geo.contentOffset.x, y: geo.containerSize.width, width: geo.contentSize.width, height: 0)
            } action: { _, g in
                let content = max(1, g.width)
                thumb = (g.minX / content, g.origin.y / content)
                let center = g.minX + g.origin.y / 2
                let index = max(0, min(ordered.count - 1, Int((center - 22) / Self.cardWidth)))
                if index != mid {
                    mid = index
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
        }
    }

    private var rail: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(ink.night ? Color.white.opacity(0.12) : Color(hex: "ECEBF0"))
                Capsule().fill(ink.ink)
                    .frame(width: max(12, proxy.size.width * min(1, thumb.w)))
                    .offset(x: proxy.size.width * max(0, thumb.x))
            }
        }
        .frame(height: 3)
        .padding(.top, 2)
        .accessibilityHidden(true)
    }

    private func dayCard(_ day: MEDay, first: Bool, last: Bool) -> some View {
        let left = MERules.days - day.ago
        let on = selected == day.ago
        let hot = left <= 2
        let star = stars[day.key]
        let ember = left <= 1 && star == nil && day.ago > 0
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { j in
                    frame(day, j: j, star: star)
                }
            }
            // 導火線(のこりの 日)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    Capsule().fill(hot ? Color(hex: "FF8A2A") : .white).frame(width: proxy.size.width * CGFloat(left) / CGFloat(MERules.days))
                }
            }
            .frame(height: 3)
            .padding(.top, 9)
            HStack {
                Text(MERules.dot(day.date))
                Spacer(minLength: 2)
                Text(V23Rules.dayLabel(ago: day.ago))
                    .foregroundStyle(day.ago == 0 ? .white : Color(hex: "FF8A2A"))
            }
            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
            .tracking(0.06 * 9.5)
            .foregroundStyle(Color(hex: "AEAEB2"))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.top, 7)
        }
        .padding(.horizontal, 8)
        .padding(.top, 22)
        .padding(.bottom, 30)
        .frame(width: Self.cardWidth)
        .background(sprockets)
        .background(Color(hex: "141416"))
        .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: first || on ? 12 : 0, bottomLeading: first || on ? 12 : 0, bottomTrailing: last || on ? 12 : 0, topTrailing: last || on ? 12 : 0)))
        .opacity(day.ago == 0 || on || mid == ordered.firstIndex(of: day) ? 1 : 1 - Double(day.ago) / 7 * 0.55)
        .opacity(ember ? 0.92 : 1)
        .shadow(color: .black.opacity(on ? 0.45 : 0), radius: 15, y: 16)
        .offset(y: on ? -6 : 0)
        .scaleEffect(on ? 1.04 : 1)
        .zIndex(on ? 2 : 0)
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.6), value: selected)
        .contentShape(Rectangle())
        .onTapGesture { pick(day) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(MERules.dot(day.date))、\(day.shots.count)こま、\(V23Rules.dayLabel(ago: day.ago))")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// フィルムの 穴(上と 下)
    private var sprockets: some View {
        VStack {
            holes.padding(.top, 7)
            Spacer()
            holes.padding(.bottom, 7)
        }
        .padding(.horizontal, 4)
    }

    private var holes: some View {
        HStack(spacing: 5) {
            ForEach(0..<8, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1).fill(Color(hex: "E8E6EC").opacity(0.75)).frame(width: 6, height: 7)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    @ViewBuilder
    private func frame(_ day: MEDay, j: Int, star: String?) -> some View {
        let shot = j < day.shots.count ? day.shots[j] : nil
        let isStar = shot != nil && shot?.id == star
        let saturation = 1 - Double(day.ago) / 7 * 0.6
        Group {
            if let shot {
                if day.ago == 0 || !shot.reveal.isOpen {
                    // 今日・まだ ひらいていない こまは ミルク色
                    LinearGradient(colors: [Color(hex: "E9EEEA"), Color(hex: "D3DAE5")], startPoint: .topLeading, endPoint: .bottomTrailing)
                } else {
                    V23Thumb(key: shot.id, data: photos.first { $0.id == shot.photoID }?.imageData)
                        .saturation(saturation)
                }
            } else {
                Color(hex: "26262B")
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color(hex: "FFD60A"), lineWidth: isStar ? 2 : 0).padding(-1))
        .overlay(alignment: .topTrailing) {
            if isStar {
                Text("★").font(.system(size: 12, weight: .black)).foregroundStyle(Color(hex: "FFD60A"))
                    .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                    .offset(x: 3, y: -6)
            }
        }
        .scaleEffect(holdingFrame == shot?.id && shot != nil ? 0.88 : 1)
        .brightness(holdingFrame == shot?.id && shot != nil ? 0.15 : 0)
        .animation(.easeOut(duration: 0.2), value: holdingFrame)
        .onLongPressGesture(minimumDuration: 0.52, maximumDistance: 8) {
            guard let shot, day.ago > 0, shot.reveal.isOpen else { return }
            keep(day, shot: shot)
        } onPressingChanged: { pressing in
            guard let shot, day.ago > 0, shot.reveal.isOpen else { return }
            if pressing { Haptics.play(.tick) }
            holdingFrame = pressing ? shot.id : nil
        }
    }

    private func pick(_ day: MEDay) {
        let left = MERules.days - day.ago
        if left <= 1, stars[day.key] == nil, day.ago > 0 {
            LayerHaptics.softDouble()
        } else {
            Haptics.play(.pop)
        }
        selected = day.ago
    }

    private func keep(_ day: MEDay, shot: MEShot) {
        holdingFrame = nil
        if stars[day.key] == shot.id {
            Haptics.play(.soft)
            onToast("この こまに ★ は ついています")
            return
        }
        let photo = photos.first { $0.id == shot.photoID }
        MEPickStore.set(day: day.key, shotID: shot.id, imageData: photo?.imageData, videoURL: photo.flatMap { LaterVideoStore.localURL(for: $0) })
        stars = MEPickStore.picks
        Haptics.play(.heart)
        selected = day.ago
    }

    /// 選んだ日の カード
    private var caption: some View {
        let day = days.first { $0.ago == selected } ?? days.first
        let ago = day?.ago ?? 0
        let left = MERules.days - ago
        let count = day?.shots.count ?? 0
        let hasStar = day.map { stars[$0.key] != nil } ?? false
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(day.map { MERules.dot($0.date) } ?? "")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .tracking(0.02 * 24)
                Text("\(count)こま").font(.system(size: 12, weight: .heavy))
                Spacer()
                Text(ago == 0 ? "今日" : "あと \(left)日")
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .tracking(0.08 * 10.5)
                    .foregroundStyle(ink.sub)
            }
            .foregroundStyle(ink.ink)
            HStack(spacing: 4) {
                ForEach(0..<MERules.days, id: \.self) { s in
                    Capsule()
                        .fill(s < left ? (left <= 2 ? Color(hex: "FF6A1A") : ink.ink) : (ink.night ? Color.white.opacity(0.14) : Color(hex: "DAD9DF")))
                        .frame(height: 6)
                }
            }
            Text(V23Rules.caption(ago: ago, count: count, hasStar: hasStar))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ink.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(ink.night ? Color.white.opacity(0.06) : Color(hex: "F4F3F7")))
        .id(selected)
        .transition(.opacity.combined(with: .offset(y: 6)))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: selected)
    }
}

// MARK: - WORLD(いま、朝が ひらいている街)

struct V23WorldSection: View {
    let ink: V17Ink

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offsetHours: Double = 0
    @State private var dragStart: Double?
    @State private var lastHour = 0
    @State private var lastCity = ""
    @State private var returning: Task<Void, Never>?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let morning = V23Rules.morning(utcHours: V23Rules.utcHours(context.date) + offsetHours)
            VStack(alignment: .leading, spacing: 0) {
                V17SectionHeader(kicker: "WORLD", title: "いま、朝が\nひらいている街", ink: ink)
                    .overlay(alignment: .bottomTrailing) {
                        // 右はしの 街の 名前(長い 名前は ちぢめる)
                        // 手書きの 字の 最後が 切れないよう、うしろに 細い 空白を 1つ
                        Text(morning.city.en + "\u{2009}")
                            .font(V17Font.hand(morning.city.en.count > 7 ? 22 : 28))
                            .foregroundStyle(V17Ink.orange)
                            .fixedSize()
                            .padding(.trailing, 2)
                            .padding(.bottom, 9)
                    }
                band(morning)
                    .padding(.top, 14)
                VStack(spacing: 3) {
                    Text("\(morning.city.ja) の あたりが いま 9:00")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(ink.ink)
                    Text("つぎ:\(morning.next.ja) まで \(V23Rules.hm(morning.hoursToNext))")
                        .font(.system(size: 10, design: .monospaced))
                        .tracking(0.08 * 10)
                        .foregroundStyle(ink.sub)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func band(_ morning: V23Rules.Morning) -> some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let x = Self.x(zone: morning.zone, width: w)
            let p = x / w
            ZStack(alignment: .topLeading) {
                LinearGradient(stops: [
                    .init(color: Color(hex: "0E0E18"), location: 0),
                    .init(color: Color(hex: "0E0E18"), location: max(0, p - 0.24)),
                    .init(color: Color(hex: "3A2A50"), location: max(0, p - 0.12)),
                    .init(color: Color(hex: "FF9A62"), location: p),
                    .init(color: Color(hex: "FFE7C8"), location: min(1, p + 0.07)),
                    .init(color: Color(hex: "FFF6E8"), location: min(1, p + 0.3)),
                    .init(color: Color(hex: "C9D6F0"), location: 1),
                ], startPoint: .leading, endPoint: .trailing)
                // 9:00 の 線と 太陽
                LinearGradient(colors: [Color(hex: "FFE7C8"), Color(hex: "FF8A2A")], startPoint: .top, endPoint: .bottom)
                    .frame(width: 2)
                    .shadow(color: Color(hex: "FF8A2A").opacity(0.55), radius: 9)
                    .offset(x: x - 1)
                Circle()
                    .fill(RadialGradient(colors: [.white, Color(hex: "FFD6A8"), Color(hex: "FF8A2A")], center: .center, startRadius: 0, endRadius: 11))
                    .frame(width: 22, height: 22)
                    .shadow(color: Color(red: 1, green: 0.67, blue: 0.35).opacity(0.7), radius: 11)
                    .offset(x: x - 11, y: 126 * 0.42 - 11)
                cities(morning, width: w)
            }
        }
        .frame(height: 126)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(Rectangle())
        .gesture(drag)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("世界の 朝の 9:00。いまは \(morning.city.ja) の あたり")
    }

    private func cities(_ morning: V23Rules.Morning, width: CGFloat) -> some View {
        let bestX = Self.x(zone: morning.city.zone, width: width)
        var lastX: CGFloat = -99
        let labels: [(V23Rules.City, CGFloat, Bool)] = V23Rules.cities.map { city in
            let x = Self.x(zone: city.zone, width: width)
            let show = city == morning.city || (x - lastX > 46 && abs(x - bestX) > 46)
            if show { lastX = x }
            return (city, x, show)
        }
        return ZStack(alignment: .topLeading) {
            ForEach(labels, id: \.0.en) { city, x, show in
                Circle().fill(.white.opacity(0.5)).frame(width: 4, height: 4)
                    .offset(x: x - 2, y: 126 - 28 - 4)
                if show {
                    Text(city.en)
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(0.08 * 8.5)
                        .foregroundStyle(city == morning.city ? .white : .white.opacity(0.55))
                        .fixedSize()
                        .frame(width: 80)
                        .offset(x: x - 40, y: 126 - 12 - 11)
                }
            }
        }
    }

    static func x(zone: Double, width: CGFloat) -> CGFloat {
        CGFloat((zone + 11) / 24) * width * 0.9 + 18 * width / 390
    }

    /// なぞると 時間が うごく。はなすと 0.6秒で いまに もどる
    private var drag: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragStart == nil {
                    returning?.cancel()
                    dragStart = offsetHours
                    lastHour = Int(offsetHours.rounded())
                    Haptics.play(.soft)
                }
                offsetHours = (dragStart ?? 0) - Double(value.translation.width) / 16
                let hour = Int(offsetHours.rounded())
                if hour != lastHour {
                    lastHour = hour
                    Haptics.play(.tick)
                }
                let city = V23Rules.morning(utcHours: V23Rules.utcHours(Date()) + offsetHours).city.en
                if city != lastCity {
                    if !lastCity.isEmpty { UISelectionFeedbackGenerator().selectionChanged() }
                    lastCity = city
                }
            }
            .onEnded { _ in
                dragStart = nil
                let from = offsetHours
                returning = Task { @MainActor in
                    let steps = reduceMotion ? 1 : 36
                    for i in 1...steps {
                        try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 16))
                        if Task.isCancelled { return }
                        let k = Double(i) / Double(steps)
                        offsetHours = from * (1 - (1 - pow(1 - k, 3)))
                    }
                    offsetHours = 0
                    lastCity = ""
                    Haptics.play(.soft)
                }
            }
    }
}
