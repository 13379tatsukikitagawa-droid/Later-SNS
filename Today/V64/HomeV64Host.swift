import SwiftUI

/// 実際の アプリの 状態(TodayView が 決めて 渡す 値)を、V64 の 画面(HomeV64View)が 読む 形に うつす。
/// 友だちの 今日の 写真は 「ひらく 前は 小さな モザイク(mosaicTiny)だけ」。元の 写真は 使わない(PROMPT_v64 §3)。
struct HomeV64Host: View {
    let src: HomeViewSwitch
    @State private var sessionStart = Date()
    @State private var showYesterday = false
    @State private var showRequests = false
    @State private var showDevelop = false
    @State private var chatWith: (id: String, name: String)?
    @State private var incoming: [FriendRequests.Request] = []

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            HomeV64View(input: makeInput(now: ctx.date), actions: makeActions())
        }
        .accessibilityElement(children: .contain)
        .task { await refreshRequests() }
        .sheet(isPresented: $showRequests) { FriendRequestsView(myName: src.avatarName) { Task { await refreshRequests() } } }
        .sheet(isPresented: Binding(get: { chatWith != nil }, set: { if !$0 { chatWith = nil } })) { if let c = chatWith { DirectMessageView(friendID: c.id, friendName: c.name) } }
        .fullScreenCover(isPresented: $showDevelop) {
            DevelopV64View(count: max(1, src.shotsToday), times: { let f = DateFormatter(); f.dateFormat = "HH:mm"; return src.todayShots.map { f.string(from: $0.takenAt) } }(), now: Date()) { showDevelop = false }
        }
        .fullScreenCover(isPresented: $showYesterday) {
            YesterdayV64View(input: makeYesterdayInput(now: Date()), actions: makeYesterdayActions())
        }
    }

    /// 申請を とりにいく(承認された 返事が あれば こちら側の つながりも つくる)
    private func refreshRequests() async {
        await FriendRequests.syncAccepted(myName: src.avatarName)
        await FriendRequests.settleCrossed(myName: src.avatarName)
        incoming = await FriendRequests.incoming()
    }

    // MARK: Lattag yesterday(P06)

    private func makeYesterdayInput(now: Date) -> YesterdayV64Input {
        var y = YesterdayV64Input()
        let L = src.layerData
        let df = DateFormatter(); df.dateFormat = "HH:mm"
        y.shotsUsed = min(FilmRoll.shotsPerDay, src.shotsToday)
        y.now = now
        y.avatar = src.avatarImage
        y.cells = L.yesterday.map { c in
            .init(id: c.id, photo: image(c.imageData, "yd\(c.id)", max: 480) ?? image(c.mosaicTiny, "ym\(c.id)", max: 160), name: c.authorName, time: c.imageData == nil ? nil : df.string(from: c.captureDate), tag: c.tag)
        }
        y.friendCount = L.friends.filter { !$0.isMe }.count
        y.shotFriends = L.friends.filter { !$0.isMe && $0.hasShot }.count
        y.mondoPhoto = L.yesterday.first.flatMap { image($0.imageData, "yd\($0.id)", max: 640) ?? image($0.mosaicTiny, "ym\($0.id)", max: 160) }
        y.mondoTag = L.words.first.map { "#\($0)" } ?? "#夕焼け"
        if let first = L.yesterday.first { y.dateLabel = Self.dateLabel(first.captureDate, now: now) }
        return y
    }

    private func makeYesterdayActions() -> YesterdayV64Actions {
        var a = YesterdayV64Actions()
        let groups = Dictionary(src.layerData.yesterday.map { ($0.id, $0.groupID) }, uniquingKeysWith: { f, _ in f })
        a.close = { showYesterday = false }
        a.openPhoto = { id in if let g = groups[id] { showYesterday = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { src.layerActions.openYesterdayPhoto(g, id) } } }
        let friends = { showYesterday = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { src.layerActions.openFriends() } }
        a.addFriends = friends; a.openRequests = friends; a.openFriends = friends; a.scanQR = friends
        a.shoot = { showYesterday = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { CaptureRequestStore.shared.pendingRequestID = UUID() } }
        a.openProfile = { showYesterday = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { src.onOpenProfile() } }
        return a
    }

    private func image(_ data: Data?, _ key: String = "x", max: CGFloat = 640) -> UIImage? { V64Images.image(key: key, data: data, maxPixel: max) }

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
        input.requestCount = incoming.count
        input.requestFaces = incoming.prefix(3).map { r in HomeV64Face(id: r.id, initial: String((r.fromName.isEmpty ? "ね" : r.fromName).prefix(1)), color: Self.color(for: UUID(uuidString: r.fromUserID.padding(toLength: 36, withPad: "0", startingAt: 0)) ?? UUID())) }
        input.requests = incoming.map { r in
            let secs = max(0, Int(now.timeIntervalSince(r.createdAt)))
            let ago = secs >= 86400 ? "\(secs / 86400)d" : (secs >= 3600 ? "\(secs / 3600)h" : "\(max(1, secs / 60))m")
            return HomeV64Request(id: r.id, name: r.fromName.isEmpty ? "ともだち" : r.fromName, handle: r.fromUsername.isEmpty ? "" : "@\(r.fromUsername)", ago: ago, color: Self.color(for: UUID(uuidString: r.fromUserID.padding(toLength: 36, withPad: "0", startingAt: 0)) ?? UUID()))
        }
        input.friends = others.prefix(7).map { f in
            HomeV64Friend(id: f.id, name: f.name, color: Self.color(for: f.seed), image: image(f.avatarData, "av\(f.id)", max: 160) ?? image(f.mosaicTiny, "mt\(f.id)", max: 160), shots: f.hasShot ? 3 : 0)
        }
        input.faces = others.filter(\.hasShot).prefix(3).map { f in
            HomeV64Face(id: f.id, initial: String(f.name.prefix(1)), color: Self.color(for: f.seed), image: image(f.avatarData, "av\(f.id)", max: 96) ?? image(f.mosaicTiny, "mt\(f.id)", max: 96))
        }
        // うしろに ぼかして 敷く 写真:友だちが 今日 撮った モザイク → 自分の きのう → なし
        let mosaics = others.filter(\.hasShot).compactMap { image($0.mosaicTiny, "mt\($0.id)", max: 160) }
        let myYesterday = L.yesterday.compactMap { image($0.imageData, "yd\($0.id)", max: 640) }
        input.backdrop = mosaics.isEmpty ? Array(myYesterday.prefix(3)) : Array(mosaics.prefix(3))
        input.isFirstDay = L.yesterday.isEmpty
        input.yesterdayPhoto = myYesterday.first
        let df = DateFormatter(); df.dateFormat = "HH:mm"
        input.yesterdayThumbs = L.yesterday.prefix(3).map { c in
            HomeV64Thumb(id: c.id, image: image(c.imageData, "yd\(c.id)", max: 480) ?? image(c.mosaicTiny, "ym\(c.id)", max: 160), time: df.string(from: c.captureDate), tag: c.tag)
        }
        // 下の 区画
        var low = HomeV64LowerData()
        low.today = .init(thumbs: [], times: src.todayShots.map { df.string(from: $0.takenAt) })
        if let first = L.yesterday.first {
            low.hero = .init(photo: image(first.imageData) ?? image(first.mosaicTiny), tag: first.tag.map { "#\($0)" } ?? "#朝", tagColor: Color(hex: "9ED8FF"), dateLabel: Self.dateLabel(first.captureDate, now: now), moments: L.yesterday.count, people: Set(L.yesterday.map(\.authorName)).count, daysLeft: 6)
            low.tiles = L.yesterday.map { c in
                .init(photo: image(c.imageData, "yd\(c.id)", max: 480) ?? image(c.mosaicTiny, "ym\(c.id)", max: 160), name: c.authorName, time: c.imageData == nil ? nil : df.string(from: c.captureDate), own: false, kept: false)
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
        a.openYesterday = { showYesterday = true }
        a.openFriends = src.layerActions.openFriends
        a.addFriends = src.layerActions.openFriends
        a.openRequests = { showRequests = true }
        a.openChat = { id, name in chatWith = (id, name) }
        a.approve = { id in
            guard let r = incoming.first(where: { $0.id == id }) else { return }
            Task { _ = await FriendRequests.respond(to: r, accept: true, myName: src.avatarName); await refreshRequests() }
        }
        a.poke = { id in if let f = src.layerData.friends.first(where: { $0.id == id }) { src.layerActions.knock(f) } }
        a.shareLink = src.layerActions.openFriends
        a.showQR = src.layerActions.openFriends
        a.searchByID = src.layerActions.openFriends
        a.openProfile = src.onOpenProfile
        a.openDevelop = { showDevelop = true }
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
