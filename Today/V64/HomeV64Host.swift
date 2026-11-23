import SwiftUI
import SwiftData

/// 実際の アプリの 状態(TodayView が 決めて 渡す 値)を、V64 の 画面(HomeV64View)が 読む 形に うつす。
/// 友だちの 今日の 写真は 「ひらく 前は 小さな モザイク(mosaicTiny)だけ」。元の 写真は 使わない(PROMPT_v64 §3)。
struct HomeV64Host: View {
    let src: HomeViewSwitch
    @State private var sessionStart = Date()
    @State private var showYesterday = false
    @State private var showProfileOverYesterday = false
    @State private var showRequests = false
    @State private var showInbox = false
    @State private var tripInviteCount = 0
    @State private var showDevelop = false
    @State private var chatWith: (id: String, name: String)?
    @State private var incoming: [FriendRequests.Request] = []
    // v95-9:4つの ボタンは それぞれ 別の 画面
    @State private var showShare = false
    @State private var showSelfQR = false
    @State private var showScan = false
    /// v96:ウィジェットから 来た 行き先
    @State private var widgetRoute = WidgetRouteStore.shared
    @Query private var profiles: [UserProfile]
    @Query private var blockedUsers: [BlockedUser]
    /// v108 §5-2:LINE などへ 送る 文(友だち)。ID が 無い 時は 今までの リンク
    private var myShare: [Any] {
        let me = UserProfile.current(from: profiles)
        let h = HandleRules.normalize(me?.username ?? "")
        guard !h.isEmpty, let text = ShareTextV108.friend(name: me?.name ?? "", handle: h) else { return [LattagShareItem(text: myLink.absoluteString, title: "Lattag の 友だち申請", url: myLink)] }
        return [LattagShareItem.friend(text: text, name: me?.name ?? "")]
    }
    private var myLink: URL {
        let me = UserProfile.current(from: profiles)
        return FriendRules.shareLink(recordName: CloudKitManager.current?.currentUserRecordName ?? me?.cloudKitUserRecordName ?? me?.username ?? "")
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            HomeV64View(input: makeInput(now: ctx.date), actions: makeActions())
        }
        .accessibilityElement(children: .contain)
        .task { await refreshRequests() }
        .onAppear { openWidgetRoute(); if TripLinkInbox.pending != nil { showInbox = true } }
        .onReceive(NotificationCenter.default.publisher(for: .tripLinkOpened)) { _ in showInbox = true }
        .onChange(of: widgetRoute.pending) { _, _ in openWidgetRoute() }
        .fullScreenCover(isPresented: $showInbox) {
            InboxV108View(myName: src.avatarName, onChanged: { Task { await refreshRequests() } }, onShareLink: { showShare = true },
                          onOpenChat: { id, name in chatWith = (id, name) })
        }
        .sheet(isPresented: $showRequests) { FriendRequestsView(myName: src.avatarName) { Task { await refreshRequests() } } }
        .sheet(isPresented: Binding(get: { chatWith != nil }, set: { if !$0 { chatWith = nil } })) { if let c = chatWith { DirectMessageView(friendID: c.id, friendName: c.name) } }
        .sheet(isPresented: $showShare) { ShareSheet(activityItems: myShare) { _ in showShare = false }.presentationDetents([.medium, .large]) }
        .fullScreenCover(isPresented: $showSelfQR) { SelfQRChekiHost(onScan: { showSelfQR = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showScan = true } }, onClose: { showSelfQR = false }) }
        .fullScreenCover(isPresented: $showScan) {
            FriendQRScanView(myName: src.avatarName, friendCount: src.layerData.friends.filter { !$0.isMe }.count, friendIDs: Set(src.layerData.friends.map(\.id)), myUsername: UserProfile.current(from: profiles)?.username ?? "", onSearchID: { openSearch() }) { src.layerActions.toast($0) }
        }
        .fullScreenCover(isPresented: $showDevelop) {
            DevelopV64View(count: max(1, src.shotsToday), times: { let f = DateFormatter(); f.dateFormat = "HH:mm"; return src.todayShots.map { f.string(from: $0.takenAt) } }(), now: Date(), onShoot: { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { CaptureRequestStore.shared.pendingRequestID = UUID() } }) { showDevelop = false }
        }
        .fullScreenCover(isPresented: $showYesterday) {
            YesterdayV64View(input: makeYesterdayInput(now: Date()), actions: makeYesterdayActions())
                .fullScreenCover(isPresented: $showProfileOverYesterday) {
                    ProfileV82Host(onBack: { showProfileOverYesterday = false }, onShoot: { showProfileOverYesterday = false; showYesterday = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { CaptureRequestStore.shared.pendingRequestID = UUID() } }, onMe: { showProfileOverYesterday = false; showYesterday = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { src.onOpenProfile() } })
                }
        }
    }

    /// 申請を とりにいく(承認された 返事が あれば こちら側の つながりも つくる)
    private func refreshRequests() async {
        await FriendRequests.syncAccepted(myName: src.avatarName)
        incoming = await FriendRequests.incoming()
        if !incoming.isEmpty { NotifAskCenter.post(.friend) }   // v111 §8-1:はじめて 申請を 受けた 時
        tripInviteCount = await FriendCloud.inbox().filter { $0.status == .pending }.count
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
        y.todayPhoto = UserProfile.current(from: profiles).flatMap { u in u.photos.filter { Calendar.current.isDateInToday($0.captureDate) }.max(by: { $0.captureDate < $1.captureDate }) }.flatMap { image($0.imageData, "tp\($0.id)", max: 240) }
        y.friendCount = L.friends.filter { !$0.isMe }.count
        y.shotFriends = L.friends.filter { !$0.isMe && $0.hasShot }.count
        y.avatarName = src.avatarName
        y.trips = TripHubRules.items(from: src.groups, now: now)
        if let first = L.yesterday.first { y.dateLabel = Self.dateLabel(first.captureDate, now: now) }
        // v76:友だち 1人 = 1つの 投稿(大きな 1枚 + 小さな 2枚)。自分の 3枚は「あなたの きのう」
        func photo(_ c: HomeYesterdayCard) -> YesterdayV64Input.Photo { .init(id: c.id, image: image(c.imageData, "yd\(c.id)", max: 640) ?? image(c.mosaicTiny, "ym\(c.id)", max: 160), time: c.imageData == nil ? "" : df.string(from: c.captureDate), tag: c.tag, music: c.musicTitle.map { MusicPick(title: $0, artist: c.musicArtist ?? "", artworkURL: c.musicArtworkURL, link: c.musicLink, service: .apple) }) }
        let mine = L.yesterday.filter { $0.authorName == src.avatarName }
        y.mine = mine.sorted { $0.captureDate < $1.captureDate }.map(photo)
        var order: [String] = []
        var byAuthor: [String: [HomeYesterdayCard]] = [:]
        for c in L.yesterday where c.authorName != src.avatarName { if byAuthor[c.authorName] == nil { order.append(c.authorName) }; byAuthor[c.authorName, default: []].append(c) }
        let others = L.friends.filter { !$0.isMe }
        y.posts = order.map { name in
            let cs = (byAuthor[name] ?? []).sorted { $0.captureDate > $1.captureDate }
            let f = others.first { $0.name == name }
            let last = cs.first?.captureDate
            return .init(id: name, name: name, avatar: f.flatMap { image($0.avatarData, "av\($0.id)", max: 96) ?? image($0.mosaicTiny, "mt\($0.id)", max: 96) },
                         place: f?.city ?? "", when: last.map { "きのう \(df.string(from: $0))" } ?? "きのう", photos: cs.prefix(3).map(photo), caption: nil, reactors: [], published: true, friendID: f?.id ?? "")
        } + others.filter { f in !order.contains(f.name) }.map { f in
            YesterdayV64Input.Post(id: f.id, name: f.name, avatar: image(f.avatarData, "av\(f.id)", max: 96) ?? image(f.mosaicTiny, "mt\(f.id)", max: 96), photos: [], caption: nil, published: false, friendID: f.id)
        }
        // 通知:来て いる 友だち申請 + きのうが ひらいた 合図(リアクション ・ コメントの 通知は データが できたら 足す)
        y.notices = incoming.prefix(5).map { r in
            let secs = max(0, Int(now.timeIntervalSince(r.createdAt)))
            let ago = secs >= 86400 ? "\(secs / 86400)日" : (secs >= 3600 ? "\(secs / 3600)時間" : "\(max(1, secs / 60))分")
            return .init(id: r.id, name: r.fromName.isEmpty ? "ともだち" : r.fromName, avatar: nil, text: "友だち申請が とどきました", time: ago, isNew: true, approveID: r.id)
        }
        if !L.yesterday.isEmpty { y.notices.append(.init(id: "opened", kind: .lattag, name: "Lattag", avatar: nil, text: "きのうの \(mine.count)枚が ひらきました", time: "9:00")) }
        y.requestCount = incoming.count
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
        a.openProfile = { showProfileOverYesterday = true }
        a.openChat = { id, name in showYesterday = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { chatWith = (id, name) } }
        a.openTrip = { id in showYesterday = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { src.onOpenChat(id) } }
        a.newTrip = { showYesterday = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { src.onCreateGroup() } }
        a.joinKey = { showYesterday = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { NotificationCenter.default.post(name: .joinFlowRequested, object: JoinFlowStart.passphrase) } }
        a.approve = { id in Task { if let r = incoming.first(where: { $0.id == id }) { _ = await FriendRequests.respond(to: r, accept: true, myName: src.avatarName); await refreshRequests() } } }
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
        input.inboxCount = incoming.count + tripInviteCount
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
            HomeV64Friend(id: f.id, name: f.name, color: Self.color(for: f.seed), image: image(f.avatarData, "av\(f.id)", max: 160) ?? image(f.mosaicTiny, "mt\(f.id)", max: 160), avatar: image(f.avatarData, "av\(f.id)", max: 160), shots: f.hasShot ? 3 : 0)
        }
        input.friendsCardPhoto = others.lazy.compactMap { image($0.avatarData, "avc\($0.id)", max: 240) }.first
        input.faces = others.filter(\.hasShot).prefix(3).map { f in
            HomeV64Face(id: f.id, initial: String(f.name.prefix(1)), color: Self.color(for: f.seed), image: image(f.avatarData, "av\(f.id)", max: 96) ?? image(f.mosaicTiny, "mt\(f.id)", max: 96))
        }
        // うしろに ぼかして 敷く 写真:友だちが 今日 撮った モザイク → 自分の きのう → なし
        let mosaics = others.filter(\.hasShot).compactMap { image($0.mosaicTiny, "mt\($0.id)", max: 160) }
        let myYesterday = L.yesterday.compactMap { image($0.imageData, "yd\($0.id)", max: 640) }
        input.backdrop = mosaics.isEmpty ? Array(myYesterday.prefix(3)) : Array(mosaics.prefix(3))
        // Trip(今ある グループの うち いちばん 新しい 1つ)
        if let g = src.groups.filter({ !$0.isPersonalSpace }).sorted(by: { $0.creationDate > $1.creationDate }).first {
            let cal = Calendar.current
            let mem = g.members.map { m in HomeV64Face(id: m.id.uuidString, initial: String(m.name.prefix(1)), color: Self.color(for: m.id), image: m.profileImageData.flatMap { UIImage(data: $0) }) }
            var frames = [Int?](repeating: nil, count: 23)
            let todays = g.photos.filter { cal.isDate($0.captureDate, inSameDayAs: now) }
            for (i, p) in todays.prefix(23).enumerated() { frames[i] = g.members.firstIndex { $0.id == p.owner?.id } ?? 0 }
            let n = (cal.dateComponents([.day], from: cal.startOfDay(for: g.creationDate), to: cal.startOfDay(for: now)).day ?? 0) + 1
            let sd = DateFormatter(); sd.dateFormat = "MM.dd"
            input.trip = HomeV64TripInfo(id: g.id, name: g.name, members: mem, frames: frames, cover: g.iconImageData.flatMap { UIImage(data: $0) }, sub: "\(sd.string(from: g.creationDate)) ・ \(mem.count)人", dayText: "DAY \(n)")
        }
        input.tripItems = TripHubRules.items(from: src.groups, now: now)
        input.isFirstDay = L.yesterday.isEmpty
        input.yesterdayPhoto = myYesterday.first
        let df = DateFormatter(); df.dateFormat = "HH:mm"
        input.yesterdayThumbs = L.yesterday.prefix(3).map { c in
            HomeV64Thumb(id: c.id, image: image(c.imageData, "yd\(c.id)", max: 480) ?? image(c.mosaicTiny, "ym\(c.id)", max: 160), time: df.string(from: c.captureDate), tag: c.tag)
        }
        // 下の 区画
        var low = HomeV64LowerData()
        low.trips = src.groups.filter { !$0.isPersonalSpace }.sorted { $0.creationDate > $1.creationDate }.map { g in
            let n = (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: g.creationDate), to: Calendar.current.startOfDay(for: now)).day ?? 0) + 1
            return (id: g.id as UUID?, name: g.name, sub: "DAY \(n) ・ \(g.members.count)人", cover: g.iconImageData.flatMap { UIImage(data: $0) }, day: "DAY \(n)",
                        // v129:未読 = 自分の lastReadAt より 後の 相手の メッセージ(部屋の 下の バーと 同じ 数)
                        unread: TripReadStore.shared.unread(g.id, me: CloudKitManager.current?.currentUserRecordName, messages: GroupChatStore.shared.visible(g.id, blocked: Set(blockedUsers.map(\.blockedCloudKitUserRecordName)))))
        }
        low.today = .init(thumbs: [], times: src.todayShots.map { df.string(from: $0.takenAt) }, dates: src.todayShots.map(\.takenAt))
        if let first = L.yesterday.first {
            low.hero = .init(photo: image(first.imageData) ?? image(first.mosaicTiny), tag: first.tag.map { "#\($0)" } ?? "#朝", tagColor: Color(hex: "9ED8FF"), dateLabel: Self.dateLabel(first.captureDate, now: now), moments: L.yesterday.count, people: Set(L.yesterday.map(\.authorName)).count, daysLeft: 6)
            low.tiles = L.yesterday.map { c in
                .init(photo: image(c.imageData, "yd\(c.id)", max: 480) ?? image(c.mosaicTiny, "ym\(c.id)", max: 160), name: c.authorName, time: c.imageData == nil ? nil : df.string(from: c.captureDate), own: false, kept: false)
            }
        }
        low.albums = L.film.prefix(7).enumerated().map { i, d in
            let left = HVL.albumLeft(daysLeft: max(0, 7 - d.ago), date: d.date)
            return .init(label: Self.dayLabel(d.date), left: left.text, tiles: [Self.filmImage(d)], more: 0, hot: left.hot)
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
        a.openRequests = { showInbox = true }; a.openInbox = { showInbox = true }
        a.openChat = { id, name in chatWith = (id, name) }
        a.approve = { id in
            guard let r = incoming.first(where: { $0.id == id }) else { return }
            Task { _ = await FriendRequests.respond(to: r, accept: true, myName: src.avatarName); await refreshRequests() }
        }
        a.shareLink = { showShare = true }
        a.showQR = { showSelfQR = true }
        a.scanQR = { showScan = true }
        a.searchByID = { openSearch() }
        a.openProfile = src.onOpenProfile
        a.openDevelop = { showDevelop = true }
        a.openTrip = src.onCreateGroup
        a.openTripHome = { id in src.onOpenChat(id) }
        a.joinKey = { NotificationCenter.default.post(name: .joinFlowRequested, object: JoinFlowStart.passphrase) }
        return a
    }

    /// v96:ウィジェットの 行き先を ひらく(lattag://develop ・ friends ・ yesterday ・ trip/<id>)
    private func openWidgetRoute() {
        guard let route = widgetRoute.take() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            switch route {
            case .shoot: makeActions().shoot()
            case .develop: if src.shotsToday > 0 { showDevelop = true } else { makeActions().shoot() }
            case .friends: src.layerActions.openFriends()
            case .yesterday: showYesterday = true
            case .trip(let id): if let uuid = UUID(uuidString: id) { src.onOpenChat(uuid) }
            }
        }
    }

    /// Friends を ひらいて、検索欄に フォーカス
    private func openSearch() {
        src.layerActions.openFriends()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { NotificationCenter.default.post(name: .friendsSearchFocus, object: nil) }
    }

    // MARK: 小物

    private static func color(for seed: UUID) -> Color {
        let palette = ["61DD7A", "7FB0FF", "EE5E9C", "C8F25A", "B28CFF", "5AC8FF", "FFD25A"]
        let i = abs(seed.hashValue) % palette.count
        return Color(hex: palette[i])
    }

    private static func dateLabel(_ d: Date, now: Date) -> String {
        // v119:小さな 日付は 11/20
        let f = DateFormatter(); f.dateFormat = "M/d"
        return f.string(from: d)
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
