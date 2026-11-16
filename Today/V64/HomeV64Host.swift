import SwiftUI

/// 実際の アプリの 状態(TodayView が 決めて 渡す 値)を、V64 の 画面(HomeV64View)が 読む 形に うつす。
/// 友だちの 今日の 写真は 「ひらく 前は 小さな モザイク(mosaicTiny)だけ」。元の 写真は 使わない(PROMPT_v64 §3)。
struct HomeV64Host: View {
    let src: HomeViewSwitch
    @State private var sessionStart = Date()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            HomeV64View(input: makeInput(now: ctx.date), actions: makeActions())
        }
        .accessibilityElement(children: .contain)
    }

    private func image(_ data: Data?) -> UIImage? { data.flatMap(UIImage.init(data:)) }

    private func makeInput(now: Date) -> HomeV64Input {
        var input = HomeV64Input()
        input.shotsUsed = min(FilmRoll.shotsPerDay, src.shotsToday)
        input.limit = FilmRoll.shotsPerDay
        input.now = now
        input.avatar = src.avatarImage
        input.avatarName = src.avatarName
        input.avatarBadge = src.showsAvatarBadge
        let L = src.layerData
        let others = L.friends.filter { !$0.isMe }
        input.friendCount = others.count
        input.friends = others.prefix(7).map { f in
            HomeV64Friend(id: f.id, name: f.name, color: Self.color(for: f.seed), image: image(f.avatarData) ?? image(f.mosaicTiny), shots: f.hasShot ? 3 : 0)
        }
        input.faces = others.filter(\.hasShot).prefix(3).map { f in
            HomeV64Face(id: f.id, initial: String(f.name.prefix(1)), color: Self.color(for: f.seed), image: image(f.avatarData) ?? image(f.mosaicTiny))
        }
        // うしろに ぼかして 敷く 写真:友だちが 今日 撮った モザイク → 自分の きのう → なし
        let mosaics = others.filter(\.hasShot).compactMap { image($0.mosaicTiny) }
        let myYesterday = L.yesterday.compactMap { image($0.imageData) }
        input.backdrop = mosaics.isEmpty ? Array(myYesterday.prefix(3)) : Array(mosaics.prefix(3))
        input.isFirstDay = L.yesterday.isEmpty
        input.yesterdayPhoto = myYesterday.first
        let df = DateFormatter(); df.dateFormat = "HH:mm"
        input.yesterdayThumbs = L.yesterday.prefix(3).map { c in
            HomeV64Thumb(id: c.id, image: image(c.imageData) ?? image(c.mosaicTiny), time: df.string(from: c.captureDate), tag: c.tag)
        }
        // 下の 区画
        var low = HomeV64LowerData()
        low.today = .init(thumbs: [], times: src.todayShots.map { df.string(from: $0.takenAt) })
        if let first = L.yesterday.first {
            low.hero = .init(photo: image(first.imageData) ?? image(first.mosaicTiny), tag: first.tag.map { "#\($0)" } ?? "#朝", tagColor: Color(hex: "9ED8FF"), dateLabel: Self.dateLabel(first.captureDate, now: now), moments: L.yesterday.count, people: Set(L.yesterday.map(\.authorName)).count, daysLeft: 6)
            low.tiles = L.yesterday.map { c in
                .init(photo: image(c.imageData) ?? image(c.mosaicTiny), name: c.authorName, time: c.imageData == nil ? nil : df.string(from: c.captureDate), own: false, kept: false)
            }
        }
        low.mondo = L.words.prefix(3).map { (tag: "#\($0)", photo: nil) }
        input.mondo.tags = L.words.prefix(3).map { "#\($0)" }
        low.albums = L.film.prefix(7).enumerated().map { i, d in
            .init(label: Self.dayLabel(d.date), left: "\(max(0, 7 - d.ago))D LEFT", tiles: [Self.filmImage(d)], more: 0)
        }
        input.lower = low
        return input
    }

    private func makeActions() -> HomeV64Actions {
        var a = HomeV64Actions()
        a.shoot = {
            // 撮る:のこりが なければ ひらかない(触覚 + 「今日は、ここまで」)。あれば 撮影の 入口(これまでの 通知 / ウィジェットと 同じ)
            if FilmCounter.shared.remaining == 0 { Haptics.play(.warn); src.layerActions.toast("今日は、ここまで") }
            else { CaptureRequestStore.shared.pendingRequestID = UUID() }
        }
        a.openYesterday = src.onOpenYesterday
        a.openFriends = src.layerActions.openFriends
        a.addFriends = src.layerActions.openFriends
        a.openProfile = src.onOpenProfile
        a.openDevelop = src.onDevelopTap
        a.openTrip = src.onCreateGroup
        a.openMondo = src.v17Actions.openMondo
        return a
    }

    // MARK: 小物

    private static func color(for seed: UUID) -> Color {
        let palette = ["61DD7A", "7FB0FF", "EE5E9C", "C8F25A", "B28CFF", "5AC8FF", "FFD25A"]
        let i = abs(seed.hashValue) % palette.count
        return Color(hex: palette[i])
    }

    private static func dateLabel(_ d: Date, now: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "MMM d"
        return f.string(from: d).uppercased()
    }

    private static func dayLabel(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "MMM d"
        return f.string(from: d)
    }

    private static func filmImage(_ d: HomeFilmDay) -> UIImage? {
        if case .photo(let data) = d.kind { return data.flatMap(UIImage.init(data:)) }
        return nil
    }
}
