import SwiftUI

// P20(v76)+ P22-B(v78)+ P23(v79)+ P24-B(v80)+ P25(v81):Lattag yesterday = 黒い 地 ・ Friends(BeReal の 形)・ Mondo ・ 通知 ・ あなたの きのう。
// タブは 標準の `TabView`(iOS 26 は 浮かぶ ガラス)。見本:Y01〜Y18。キャラクターは 使わない(人は 写真の 丸 / 名前の 1文字 + 色)。

struct YesterdayV64Input {
    struct Cell: Identifiable { let id: String; var photo: UIImage?; var name: String; var time: String?; var tag: String?; var music: MusicPick? = nil }
    /// 1枚(1日 3枚まで)
    struct Photo: Identifiable { let id: String; var image: UIImage?; var time: String; var tag: String?; var music: MusicPick? = nil
        /// v134:撮った 時刻(「待った」の 計算)と、ひらいて いるか(false の 間は ぼかし + 鍵)
        var captured: Date? = nil; var opened = true }
    /// 友だち 1人 = 1つの 投稿(大きな 1枚 + 小さな 2枚)。`published` が false =「まだ 公開して いません」
    struct Post: Identifiable {
        let id: String
        var name: String
        var avatar: UIImage?
        var place: String = ""
        var when: String = "きのう"
        var photos: [Photo] = []
        var caption: String?
        var reactors: [UIImage?] = []
        var published = true
        var friendID = ""
    }
    struct Notice: Identifiable {
        enum Kind { case person, lattag }
        let id: String
        var kind: Kind = .person
        var name: String
        var avatar: UIImage?
        var text: String
        var time: String
        var isNew = false
        var approveID: String? = nil
    }

    var shotsUsed = 0
    var cells: [Cell] = []
    var viewerOnly: [Cell] = []
    var requestFaces: [HomeV64Face] = []
    var requestCount = 0
    var inboxCount = 0
    var friendCount = 0
    var shotFriends = 0
    var trips: [TripHubItem] = []
    var todayPhoto: UIImage?
    var dateLabel = "NOV 15"
    var avatar: UIImage?
    var avatarName = ""
    var now = Date()
    var startTab = 0
    var startViewing: String? = nil
    var scrollToMe = false
    var locked: Bool { shotsUsed == 0 }
    // v76〜v82
    var mine: [Photo] = []
    var mineCaption: String?
    var posts: [Post] = []
    var notices: [Notice] = []
    var openNotices = false
    var openMine = false
    var mineIndex = 1
    var debugScrollY: CGFloat? = nil
    // v134
    struct Request: Identifiable { let id: String; var name: String; var sub: String }
    struct Friend: Identifiable { let id: String; var name: String; var avatar: UIImage? }
    var shotTimes: [Date] = []
    var tripBadge = 0
    var requestItems: [Request] = []
    var friendList: [Friend] = []

    var publishedCount: Int { posts.filter(\.published).count }
    var pendingCount: Int { posts.filter { !$0.published }.count }
    var hasNew: Bool { notices.contains(where: \.isNew) }
}

struct YesterdayV64Actions {
    var close: () -> Void = {}
    var openPhoto: (String) -> Void = { _ in }
    var addFriends: () -> Void = {}
    var openRequests: () -> Void = {}
    var openFriends: () -> Void = {}
    var shoot: () -> Void = {}
    var openProfile: () -> Void = {}
    var scanQR: () -> Void = {}
    var approve: (String) -> Void = { _ in }
    var openChat: (String, String) -> Void = { _, _ in }
    var openTrip: (UUID) -> Void = { _ in }
    var newTrip: () -> Void = {}
    var joinKey: () -> Void = {}
    // v134
    var dismissRequest: (String) -> Void = { _ in }
    var showQR: () -> Void = {}
    var shareLink: () -> Void = {}
    var searchByID: () -> Void = {}
    var toast: (String) -> Void = { _ in }
    // v136
    var openInviteCard: () -> Void = {}
}

struct YesterdayV64View: View {
    var input: YesterdayV64Input
    var actions = YesterdayV64Actions()
    @State private var tab = 0   // 0 = Friends ・ 1 = Trip
    @State private var tripPos = ScrollPosition()
    @State private var seeded = false
    @State private var viewing: YesterdayV64Input.Cell?
    @State private var scrollY: CGFloat = 0
    @State private var pos = ScrollPosition()
    @State private var notices = false
    @State private var mine = false
    @State private var mineIndex = 1
    @State private var swapped: [String: Int] = [:]
    @State private var tip = false
    @State private var lastTick = Date.distantPast

    private var compact: Bool { scrollY > 24 }

    private var hasMine: Bool { !input.mine.isEmpty }
    private var noFriends: Bool { input.friendCount == 0 && input.posts.isEmpty }
    /// 上の 題の 下:はじめて(両方 ない)= DAY 1 ・ 友だち 0人 = きのう
    private var friendsSubtitle: String {
        if !hasMine && noFriends { return "DAY 1" }
        if noFriends { return "きのう" }
        return "きのう ・ \(input.publishedCount)人が 公開 ・ \(input.pendingCount)人 まだ"
    }

    private func scrollNow(_ v: CGFloat, forTab t: Int) {
        guard t == tab else { return }
        let was = compact
        scrollY = v
        if (v > 24) != was, Date().timeIntervalSince(lastTick) > 0.3 { lastTick = Date(); Haptics.play(.tick) }
    }

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .top) {
                Color.black
                ZStack {
                    friendsTab(w: g.size.width).ignoresSafeArea(edges: .top)
                        .opacity(tab == 0 ? 1 : 0).allowsHitTesting(tab == 0)
                    TripHubView(items: input.trips, now: input.now, onOpen: { actions.openTrip($0) }, onNew: { actions.newTrip() }, onJoinKey: { actions.joinKey() },
                                position: $tripPos, topInset: 118, onScroll: { v in scrollNow(v, forTab: 1) })
                        .ignoresSafeArea(edges: .top)
                        .onAppear { if let y = input.debugScrollY, tab == 1 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { tripPos.scrollTo(y: y) } } }
                        .opacity(tab == 1 ? 1 : 0).allowsHitTesting(tab == 1)
                }
                .preferredColorScheme(.dark)
                .animation(.easeOut(duration: 0.18), value: tab)
                .onChange(of: tab) { _, _ in scrollY = 0 }
                VStack { Spacer(); PopTabBar(selection: $tab, onRepeat: { withAnimation(.easeOut(duration: 0.3)) { if tab == 0 { pos.scrollTo(edge: .top) } else { tripPos.scrollTo(edge: .top) } } }).padding(.bottom, 22) }
                    .zIndex(3).ignoresSafeArea(.keyboard)

                header(w: g.size.width)
                if notices { noticePanel(w: g.size.width).zIndex(5) }
                if mine { myYesterday(w: g.size.width).transition(.move(edge: .bottom)).zIndex(6) }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .ignoresSafeArea()
        .overlay { if let v = viewing { photoViewer(v).transition(.opacity) } }
        .onAppear {
            guard !seeded else { return }
            seeded = true; tab = input.startTab; notices = input.openNotices; mine = input.openMine; mineIndex = input.mineIndex
            if let id = input.startViewing { viewing = (input.cells + input.viewerOnly).first { $0.id == id } }
        }
    }

    // MARK: 上の 帯(Lattag の ロゴは 出さない)

    private func header(w: CGFloat) -> some View {
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(compact ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.clear)).overlay(Color.black.opacity(compact ? 0.78 : 0))
                .frame(width: w, height: compact ? 96 : 112)
                .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(compact ? 0.12 : 0)).frame(height: 0.5) }
                .background(alignment: .top) { LinearGradient(stops: [.init(color: .black, location: 0.7), .init(color: .black.opacity(0), location: 1)], startPoint: .top, endPoint: .bottom).frame(height: 112).opacity(compact ? 0 : 1) }
                .allowsHitTesting(false)
            // v133 3章:Home ・ Friends ・ Trip で 同じ 部品
            TopBar(title: tab == 0 ? "Friends" : "Trip", subtitle: tab == 0 ? friendsSubtitle : nil, width: w,
                   inboxCount: input.inboxCount, avatar: input.avatar, avatarName: input.avatarName, compact: compact, switchLabel: "今日へ",
                   onBell: { Haptics.play(.pop); withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) { notices = true } },
                   onProfile: { actions.openProfile() }, onSwitch: { actions.close() })
        }
        .frame(width: w, alignment: .topLeading)
        .animation(.timingCurve(0.3, 1.15, 0.4, 1, duration: 0.45), value: compact)
    }

    // MARK: Friends

    private func friendsTab(w: CGFloat) -> some View {
        FriendsTabV110(input: input, actions: actions, w: w,
                       onViewPhoto: { c in viewing = c },
                       onOpenMine: { i in mineIndex = i; withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { mine = true } },
                       invite: { AnyView(inviteBlock) },
                       lockBand: { AnyView(lockBand.padding(.top, 0)) },
                       position: $pos,
                       onScroll: { v in scrollNow(v, forTab: 0) })
            .onAppear { if let y = input.debugScrollY, tab == 0 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { pos.scrollTo(y: y) } } }
    }

    // ① はじめの 1枚(自分の きのう が ない 時)
    @State private var floatUp = false
    private var firstShot: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let mid = i == 1
                    RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(hex: "121315"))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(mid ? HV.lime : .white.opacity(0.14), lineWidth: mid ? 1.5 : 1))
                        .overlay { if mid {
                            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(HV.lime.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5, 5])).padding(10)
                            Image(systemName: "camera").font(.system(size: 36, weight: .regular)).foregroundStyle(HV.lime)
                        } }
                        .frame(width: 150, height: 200)
                        .rotationEffect(.degrees(i == 0 ? -11 : (i == 2 ? 11 : 0)))
                        .offset(x: i == 0 ? -78 : (i == 2 ? 78 : 0), y: mid ? (floatUp ? -7 : 0) : 12)
                        .zIndex(mid ? 1 : 0)
                }
            }.frame(height: 230).padding(.top, 8)
            .loopWhileVisible(.easeInOut(duration: 3.6).repeatForever(autoreverses: true), value: $floatUp)   // v111
            Text("最初の 1枚を 撮ろう").font(Typo.ui(900, 24)).foregroundStyle(.white).padding(.top, 18)
            Text("あした 9:00 に、ここで ひらきます").font(Typo.ui(600, 13)).foregroundStyle(.white.opacity(0.5)).padding(.top, 6)
            Button { Haptics.play(.click); actions.shoot() } label: {
                HStack(spacing: 10) { Image(systemName: "camera").font(.system(size: 19, weight: .semibold)); Text("撮る").font(Typo.ui(900, 17)) }.foregroundStyle(HV.ink).frame(maxWidth: .infinity).frame(height: 56).background(HV.lime, in: Capsule())
            }.buttonStyle(HVPress(scale: 0.98)).padding(.horizontal, 16).padding(.top, 20)
        }.frame(maxWidth: .infinity)
    }

    // ② 友だちを よぶ(友だちが 0人の 時)
    private var inviteBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            storyRowV95.padding(.bottom, 18)
            HStack(alignment: .firstTextBaseline) {
                Text("友だちを よぶ").font(Typo.ui(900, 19)).foregroundStyle(.white)
                Spacer()
                Text("0 FRIENDS").font(Typo.label(10.5)).tracking(1.5).foregroundStyle(.white.opacity(0.4))
            }.padding(.horizontal, 16)
            HStack(spacing: 8) {
                inviteTile("qrcode", "QR を 見せる", green: true) { actions.addFriends() }
                inviteTile("viewfinder", "QR を 読む", green: false) { actions.scanQR() }
                inviteTile("link", "リンク", green: false) { actions.openFriends() }
            }.padding(.horizontal, 16).padding(.top, 12)
            // 友だちを よぶ:名前 か @ID で さがす(押すと Friends の さがす 画面)
            Button { Haptics.play(.click); actions.openFriends() } label: {
                HStack(spacing: 10) { Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .bold)).foregroundStyle(HV.lime); Text("名前 か @ID で さがす").font(Typo.ui(600, 15)).foregroundStyle(.white.opacity(0.5)); Spacer() }
                    .padding(.horizontal, 18).frame(height: 52).background(Color(hex: "1C1C1F"), in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1))
            }.buttonStyle(HVPress(scale: 0.98)).padding(.horizontal, 16).padding(.top, 10)
            VStack(alignment: .leading, spacing: 4) {
                Text("FRIENDS 見本").font(Typo.label(10.5)).tracking(2).foregroundStyle(HV.lime)
                Text("友だちが できると、毎朝 9:00 に ここに ならぶ").font(Typo.ui(600, 13)).foregroundStyle(.white.opacity(0.55))
            }.padding(.horizontal, 16).padding(.top, 26)
            SamplePostV94().padding(.top, 12)
            VStack(spacing: 14) { ghostPost }.padding(.top, 14).mask(LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom))
        }
    }
    /// v95-11:いちばん 上の ストーリーの 列(あなた → おすすめ → よぶ)
    private var storyRowV95: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                Button { Haptics.play(.click); actions.shoot() } label: {
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottomTrailing) {
                            Circle().strokeBorder(HV.lime, lineWidth: 2.5).frame(width: 68, height: 68).shadow(color: HV.lime.opacity(0.45), radius: 6)
                            Group {
                                if let a = input.avatar { Image(uiImage: a).resizable().scaledToFill() }
                                else { Text(String(input.avatarName.prefix(1))).font(Typo.ui(800, 22)).foregroundStyle(.white) }
                            }.frame(width: 58, height: 58).background(Color(hex: "3A3A3C")).clipShape(Circle()).frame(width: 68, height: 68)
                            Image(systemName: "camera.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(HV.ink)
                                .frame(width: 24, height: 24).background(HV.lime, in: Circle()).overlay(Circle().strokeBorder(.black, lineWidth: 2.5))
                        }
                        Text("あなた").font(Typo.ui(700, 11.5)).foregroundStyle(.white.opacity(0.85))
                    }
                }.buttonStyle(HVPress(scale: 0.94)).accessibilityLabel("あなた ・ 撮る")
                ForEach(0..<3, id: \.self) { _ in
                    Button { Haptics.play(.sel); actions.openFriends() } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle().strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [3, 4])).frame(width: 68, height: 68)
                                Image(systemName: "person.fill").font(.system(size: 22)).foregroundStyle(.white.opacity(0.18))
                            }
                            Text("おすすめ").font(Typo.ui(600, 11.5)).foregroundStyle(.white.opacity(0.4))
                        }
                    }.buttonStyle(HVPress(scale: 0.94)).accessibilityLabel("おすすめの 人 ・ さがす")
                }
                Button { Haptics.play(.sel); actions.openFriends() } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().strokeBorder(HV.lime.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [5, 4])).frame(width: 68, height: 68)
                            Image(systemName: "plus").font(.system(size: 22, weight: .bold)).foregroundStyle(HV.lime)
                        }
                        Text("よぼう").font(Typo.ui(700, 11.5)).foregroundStyle(HV.lime)
                    }
                }.buttonStyle(HVPress(scale: 0.94)).accessibilityLabel("友だちを よぶ")
            }.padding(.horizontal, 16)
        }
    }
    private func inviteTile(_ icon: String, _ t: String, green: Bool, _ a: @escaping () -> Void) -> some View {
        Button { Haptics.play(.click); a() } label: {
            VStack(spacing: 10) { Image(systemName: icon).font(.system(size: 24, weight: .semibold)); Text(t).font(Typo.ui(800, 13)) }
                .foregroundStyle(green ? HV.ink : .white).frame(maxWidth: .infinity).frame(height: 96)
                .background(green ? HV.lime : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(green ? 0 : 0.14), lineWidth: 1))
        }.buttonStyle(HVPress(scale: 0.96))
    }
    private var ghostPost: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle().fill(.white.opacity(0.08)).frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 6) { Capsule().fill(.white.opacity(0.1)).frame(width: 90, height: 8); Capsule().fill(.white.opacity(0.07)).frame(width: 140, height: 7) }
            }.padding(.horizontal, 16)
            RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color(hex: "121315")).frame(height: 300).overlay(Shimmer().clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))).padding(.horizontal, 8)
        }
    }

    /// あなたの きのう(まんなかに 大きめ 1枚 + 「+2 more」+ キャプション + 丸い ボタン 3つ)
    private func myBlock(w: CGFloat) -> some View {
        let main = input.mine.last ?? input.mine.first
        let others = input.mine.filter { $0.id != main?.id }
        return VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Button { Haptics.play(.pop); mineIndex = max(0, input.mine.count - 1); withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { mine = true } } label: {
                    ZStack(alignment: .topLeading) {
                        photoFill(main?.image, tone: "2A2326").frame(width: 120, height: 160).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.6), radius: 10, y: 8)
                        if let t = main?.time { Text(t).font(Typo.label(9.5)).fontWeight(.bold).foregroundStyle(.white).padding(.horizontal, 8).frame(height: 20).background(.black.opacity(0.45), in: Capsule()).offset(x: 71, y: 6) }
                        if let tag = main?.tag { Text("#\(tag)").font(Typo.ui(800, 11)).foregroundStyle(HV.ink).padding(.horizontal, 8).frame(height: 22).background(HV.lime, in: Capsule()).offset(x: 6, y: 132) }
                    }.frame(width: 120, height: 160)
                }.buttonStyle(HVPress(scale: 0.97)).offset(x: (w - 120) / 2, y: 0)
                if input.mine.count > 1 {
                    Button { Haptics.play(.pop); mineIndex = 0; withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { mine = true } } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.black).overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.22), lineWidth: 1.5))
                            ForEach(Array(others.prefix(2).enumerated()), id: \.element.id) { i, p in
                                photoFill(p.image, tone: "2A2326").frame(width: 50, height: 62).clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                    .opacity(0.55).rotationEffect(.degrees(i == 0 ? -6 : 6)).offset(x: i == 0 ? -15 : 15, y: -36 + (i == 0 ? 0 : 4))
                            }
                            VStack(spacing: 2) { Text("+\(max(0, input.mine.count - 1))").font(Typo.ui(800, 22)).foregroundStyle(.white); Text("more").font(Typo.ui(600, 12)).foregroundStyle(.white.opacity(0.75)) }.offset(y: 27)
                        }.frame(width: 100, height: 136)
                    }.buttonStyle(HVPress(scale: 0.97)).offset(x: (w - 120) / 2 + 120 + 14, y: 12)
                }
            }.frame(width: w, height: 160, alignment: .topLeading)
            Text(input.mineCaption ?? "キャプションを 追加…").font(Typo.ui(600, 16)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 24).padding(.top, 16)
            HStack(spacing: 14) {
                circleButton { Image(systemName: "paperplane").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white) } action: { Haptics.play(.tick); actions.addFriends() }
                circleButton { Text("#").font(Typo.ui(900, 22)).foregroundStyle(HV.lime) } action: { Haptics.play(.pop) }
                circleButton { Image(systemName: "star").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white) } action: { Haptics.play(.pop) }
            }.frame(maxWidth: .infinity).padding(.top, 12)
        }
    }

    private func circleButton<C: View>(@ViewBuilder _ content: () -> C, action: @escaping () -> Void) -> some View {
        Button(action: action) { content().frame(width: 50, height: 50).background(Color(hex: "1C1C1E"), in: Circle()) }.buttonStyle(HVPress(scale: 0.92))
    }

    private var lockBand: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("今日 1枚 撮ると、きのうが ひらく").font(Typo.ui(800, 14)).foregroundStyle(.white)
                Text("友だちの 写真は ぼかしと ひとこと だけ").font(Typo.ui(600, 12)).foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
            Button { Haptics.play(.click); actions.shoot() } label: { Text("撮る").font(Typo.ui(800, 14)).foregroundStyle(HV.ink).padding(.horizontal, 18).frame(height: 36).background(HV.lime, in: Capsule()) }.buttonStyle(HVPress(scale: 0.95))
        }
        .padding(.horizontal, 16).padding(.vertical, 14).background(Color(hex: "121314"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: 投稿(1人 = 1つ)

    private var lockedLabel: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill").font(.system(size: 26, weight: .semibold)).foregroundStyle(.white)
            Text("あした 9:00 に ひらく").font(Typo.ui(800, 15)).foregroundStyle(.white)
        }.shadow(color: .black.opacity(0.4), radius: 6)
    }

    private func postView(_ post: YesterdayV64Input.Post, w: CGFloat) -> some View {
        let idx = min(swapped[post.id] ?? 0, max(0, post.photos.count - 1))
        let big = post.photos.indices.contains(idx) ? post.photos[idx] : nil
        let smalls = post.photos.enumerated().filter { $0.offset != idx }
        let hidden = !post.published || input.locked
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                avatarCircle(post.avatar, name: post.name, size: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.name).font(Typo.ui(700, 15)).foregroundStyle(.white)
                    Text(post.published ? [post.place, post.when].filter { !$0.isEmpty }.joined(separator: " ・ ") : "まだ 公開して いません").font(Typo.ui(500, 12.5)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer(minLength: 0)
                Text("···").font(Typo.ui(900, 18)).foregroundStyle(.white).frame(width: 36, height: 36)
            }.padding(.horizontal, 16).padding(.top, 2)
            // 写真
            ZStack(alignment: .topLeading) {
                ZStack {
                    Color(hex: "111111")
                    if let img = big?.image {
                        // ひらく まえ(ぼかした 写真 + 鍵)/ ひらいた(写真)
                        if hidden {
                            Image(uiImage: V64Images.blurred(key: "yb\(post.id)\(idx)", source: img, maxPixel: 48, radius: 14, saturation: 1.0, brightness: 0.6)).resizable().scaledToFill()
                            lockedLabel
                        } else { Image(uiImage: img).resizable().scaledToFill() }
                    } else if hidden {
                        // ひらく まえ(写真が まだ 無い):鍵 +「あした 9:00 に ひらく」。何も 出ない 面は 作らない(v106 §3-1)
                        LinearGradient(colors: [Color(hex: "1B1C1F"), Color(hex: "101012")], startPoint: .top, endPoint: .bottom)
                        lockedLabel
                    } else {
                        // 読みこみ中(光が 流れる)
                        Shimmer()
                    }
                }
                .frame(width: w - 16, height: (w - 16) * 4 / 3).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture { if !hidden, let big { viewing = .init(id: big.id, photo: big.image, name: post.name, time: big.time, tag: big.tag, music: big.music); Haptics.play(.tick) } }
                if post.published {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(smalls.prefix(2), id: \.element.id) { s in
                            Button { Haptics.play(.pop); withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { swapped[post.id] = s.offset } } label: {
                                ZStack {
                                    if let img = s.element.image {
                                        if hidden { Image(uiImage: V64Images.blurred(key: "yb\(post.id)\(s.offset)", source: img, maxPixel: 48, radius: 8, saturation: 1.0, brightness: 0.6)).resizable().scaledToFill() }
                                        else { Image(uiImage: img).resizable().scaledToFill() }
                                    } else { Color(hex: "222222") }
                                }.frame(width: 86, height: 112).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.black, lineWidth: 2))
                            }.buttonStyle(.plain)
                        }
                    }.padding(12)
                    if let t = big?.time {
                        Text(t).font(Typo.label(11)).fontWeight(.bold).foregroundStyle(.white).padding(.horizontal, 12).frame(height: 26).background(.black.opacity(0.45), in: Capsule())
                            .frame(width: w - 16, alignment: .trailing).padding(.top, 12).padding(.trailing, 12)
                    }
                    if !input.locked {
                        HStack(spacing: -10) {
                            ForEach(Array(post.reactors.prefix(3).enumerated()), id: \.offset) { _, r in
                                avatarCircle(r, name: "", size: 34).overlay(Circle().strokeBorder(.black, lineWidth: 2))
                            }
                        }
                        .frame(width: w - 16, height: (w - 16) * 4 / 3, alignment: .bottomLeading).padding(.leading, 12).padding(.bottom, 10)
                        Image(systemName: "face.smiling").font(.system(size: 22, weight: .regular)).foregroundStyle(.white).frame(width: 44, height: 44)
                            .background(.black.opacity(0.45), in: Circle())
                            .frame(width: w - 16, height: (w - 16) * 4 / 3, alignment: .bottomTrailing).padding(.trailing, 10).padding(.bottom, 8)
                    }
                }
            }.padding(.horizontal, 8).padding(.top, 10)
            // タグ(押すと その 1枚に 入れかわる)
            if post.published && !input.locked && post.photos.contains(where: { $0.tag != nil }) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(post.photos.enumerated()), id: \.element.id) { i, p in
                            if let tag = p.tag { tagPill(tag, on: i == idx) { Haptics.play(.pop); withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { swapped[post.id] = i } } }
                        }
                    }.padding(.horizontal, 16)
                }.padding(.top, 14)
            }
            if let cap = post.caption, !cap.isEmpty { Text(cap).font(Typo.ui(500, 14.5)).foregroundStyle(.white).padding(.horizontal, 16).padding(.top, 12) }
            if post.published && !input.locked { Text("コメントを 追加…").font(Typo.ui(500, 14.5)).foregroundStyle(.white.opacity(0.45)).padding(.horizontal, 16).padding(.top, 8) }
            Color.clear.frame(height: 22)
        }
    }

    private func tagPill(_ tag: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text("#").font(Typo.ui(900, 14)).foregroundStyle(on ? HV.lime : .white).frame(width: 24, height: 24).background(on ? Color.black : Color.white.opacity(0.14), in: Circle())
                Text(tag).font(Typo.ui(800, 13.5)).foregroundStyle(on ? HV.ink : .white.opacity(0.78))
            }
            .padding(.leading, 4).padding(.trailing, 14).frame(height: 32)
            .background(on ? HV.lime : Color.white.opacity(0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(on ? 0 : 0.12), lineWidth: 1))
        }.buttonStyle(HVPress(scale: 0.95))
    }

    func avatarCircle(_ img: UIImage?, name: String, size: CGFloat) -> some View {
        ZStack {
            if let img { Image(uiImage: img).resizable().scaledToFill() }
            else { Circle().fill(LinearGradient(colors: [Color(hex: "61D278"), Color(hex: "EE5E9C")], startPoint: .topLeading, endPoint: .bottomTrailing)).overlay(Text(String(name.prefix(1))).font(Typo.ui(900, size * 0.4)).foregroundStyle(.white)) }
        }.frame(width: size, height: size).clipShape(Circle())
    }

    private func photoFill(_ img: UIImage?, tone: String) -> some View {
        ZStack { Color(hex: tone); if let img { Image(uiImage: img).resizable().scaledToFill() } }
    }

    // MARK: 通知(上から ガラスの パネル)

    private func noticePanel(w: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { Haptics.play(.tick); withAnimation(.easeOut(duration: 0.25)) { notices = false } }
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("通知").font(Typo.ui(900, 24)).foregroundStyle(.white)
                    Spacer()
                    Button { Haptics.play(.tick); withAnimation(.easeOut(duration: 0.25)) { notices = false } } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(.white).frame(width: 40, height: 40).background(.white.opacity(0.12), in: Circle())
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 20).padding(.top, 16).frame(height: 70)
                VStack(spacing: 0) {
                    ForEach(Array(input.notices.enumerated()), id: \.element.id) { i, n in noticeRow(n).frame(height: 62) }
                }.padding(.horizontal, 20)
                Color.clear.frame(height: 14)
            }
            .frame(width: w - 16)
            .background(Color(hex: "141416").opacity(0.97), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
            .shadow(color: .black.opacity(0.6), radius: 30, y: 20)
            .padding(.top, 50)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func noticeRow(_ n: YesterdayV64Input.Notice) -> some View {
        HStack(spacing: 14) {
            switch n.kind {
            case .person: avatarCircle(n.avatar, name: n.name, size: 42)
            case .lattag: Text("#").font(Typo.ui(900, 22)).foregroundStyle(HV.ink).frame(width: 42, height: 42).background(HV.lime, in: Circle())
            }
            VStack(alignment: .leading, spacing: 4) {
                (Text(n.name).font(Typo.ui(800, 15)).foregroundColor(.white) + Text(" " + n.text).font(Typo.ui(600, 15)).foregroundColor(.white.opacity(0.88))).lineLimit(1).minimumScaleFactor(0.85)
                HStack(spacing: 5) {
                    if n.isNew { Circle().fill(HV.lime).frame(width: 5, height: 5) }
                    Text(n.time).font(Typo.ui(600, 12.5)).foregroundStyle(.white.opacity(0.5))
                }
            }
            Spacer(minLength: 0)
            if let id = n.approveID {
                Button { Haptics.play(.success); actions.approve(id) } label: { Text("承認").font(Typo.ui(800, 13)).foregroundStyle(HV.ink).padding(.horizontal, 16).frame(height: 32).background(HV.lime, in: Capsule()) }.buttonStyle(HVPress(scale: 0.94))
            }
        }
    }

    // MARK: あなたの きのう(下から 全画面)

    private func myYesterday(w: CGFloat) -> some View {
        let photos = input.mine
        let p = photos.indices.contains(mineIndex) ? photos[mineIndex] : photos.first
        return ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            Button { Haptics.play(.tick); withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { mine = false } } label: {
                Image(systemName: "xmark").font(.system(size: 17, weight: .black)).foregroundStyle(.white).frame(width: 44, height: 44).background(.white.opacity(0.12), in: Circle())
            }.buttonStyle(.plain).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 12).padding(.top, 56)
            Image(systemName: "ellipsis").font(.system(size: 17, weight: .black)).foregroundStyle(.white).frame(width: 44, height: 44).background(.white.opacity(0.12), in: Circle())
                .frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 12).padding(.top, 56)
            VStack(spacing: 4) {
                Text("あなたの きのう").font(Typo.ui(900, 22)).foregroundStyle(.white)
                Text("\(min(photos.count, mineIndex + 1)) / \(photos.count) ・ \(p?.time ?? "")").font(Typo.label(11)).foregroundStyle(.white.opacity(0.5))
            }.padding(.top, 58)
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .top) {
                    photoFill(p?.image, tone: "2A2326").frame(width: w - 16, height: (w - 16) * 4 / 3).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    HStack(spacing: 6) {
                        ForEach(photos.indices, id: \.self) { i in Capsule().fill(.white.opacity(i == mineIndex ? 0.95 : 0.45)).frame(width: 26, height: 3) }
                    }.padding(.top, 12)
                    HStack(spacing: 0) {
                        Color.clear.contentShape(Rectangle()).onTapGesture { Haptics.play(.tick); mineIndex = max(0, mineIndex - 1) }
                        Color.clear.contentShape(Rectangle()).onTapGesture { Haptics.play(.tick); mineIndex = min(photos.count - 1, mineIndex + 1) }
                    }
                }.padding(.horizontal, 8)
                HStack(spacing: 8) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { i, ph in if let tag = ph.tag { tagPill(tag, on: i == mineIndex) { Haptics.play(.pop); mineIndex = i } } }
                }.padding(.horizontal, 16).padding(.top, 12)
                Text(input.mineCaption ?? "キャプションを 追加…").font(Typo.ui(600, 16)).foregroundStyle(.white).padding(.horizontal, 16).padding(.top, 16)
                HStack(spacing: 8) {
                    Text("リアクション").font(Typo.ui(700, 14)).foregroundStyle(.white.opacity(0.5))
                    HStack(spacing: -12) { ForEach(Array((input.posts.first?.reactors ?? []).prefix(3).enumerated()), id: \.offset) { _, r in avatarCircle(r, name: "", size: 32).overlay(Circle().strokeBorder(.black, lineWidth: 2)) } }
                    Text("\(min(3, input.posts.first?.reactors.count ?? 0))").font(Typo.ui(800, 16)).foregroundStyle(.white)
                }.padding(.horizontal, 16).padding(.top, 14)
            }.padding(.top, 115)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: 1枚を ひらく(全画面)

    private func photoViewer(_ c: YesterdayV64Input.Cell) -> some View {
        ZStack(alignment: .topLeading) {
            Color(hex: "0A0A0B")
            VStack(spacing: 2) {
                Text(c.name).font(Typo.title(26)).foregroundStyle(.white)
                Text(c.time.map { "yesterday · \($0)" } ?? "today's one · picked by the world").font(Typo.ui(500, 12.5)).foregroundStyle(Color(hex: "8E8E93"))
            }.frame(width: 246).offset(x: 72, y: 55)
            Button { Haptics.play(.tick); withAnimation(.easeOut(duration: 0.25)) { viewing = nil } } label: {
                Image(systemName: "arrow.left").font(.system(size: 17, weight: .bold)).foregroundStyle(.white).frame(width: 48, height: 48).background(Color(hex: "161618"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }.buttonStyle(.plain).offset(x: 14, y: 54)
            ZStack { Color(hex: "2A2326"); if let img = c.photo { Image(uiImage: img).resizable().scaledToFill() } }
                .frame(width: 362, height: 560).clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous)).offset(x: 14, y: 118)
            if let tag = c.tag {
                Text(tag.hasPrefix("#") ? tag : "#\(tag)").font(Typo.ui(900, 15)).foregroundStyle(HV.ink).frame(width: 81, height: 36)
                    .background(Color(hex: "9ED8FF"), in: RoundedRectangle(cornerRadius: 12)).rotationEffect(.degrees(-6)).offset(x: 29, y: 628)
            }
            if let m = c.music { FriendMusicChip(pick: m).offset(x: 14, y: 690) }
            Button { Haptics.play(.pop); actions.openPhoto(c.id) } label: {
                Text("reply").font(Typo.ui(800, 15)).foregroundStyle(HV.ink).frame(width: 106, height: 56).background(.white, in: Capsule())
            }.buttonStyle(HVPress(scale: 0.96)).offset(x: 142, y: 732)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(Color(hex: "0A0A0B")).ignoresSafeArea()
    }
}


/// 光が 左から 右へ ながれる(2.4秒)。見えない / Reduce Motion では 止める
struct Shimmer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion || scenePhase != .active)) { ctx in
            GeometryReader { g in
                let u = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4
                LinearGradient(colors: [.clear, .white.opacity(0.07), .clear], startPoint: .leading, endPoint: .trailing).frame(width: g.size.width * 0.5).offset(x: CGFloat(u) * g.size.width * 1.6 - g.size.width * 0.5)
            }
        }.allowsHitTesting(false)
    }
}


/// 友だちの 写真に ついた 曲:チップを 押すと プレビューが 流れる(もう1回で 止まる)。曲の ID は リンクから 読む
struct FriendMusicChip: View {
    let pick: MusicPick
    private let playback = MusicPlayback.shared
    @State private var url: URL?
    private var key: String { "friend-" + (pick.link ?? pick.title) }

    var body: some View {
        Button { toggle() } label: {
            HStack(spacing: 8) {
                MusicDisc(artworkURL: pick.artworkURL, seed: pick.title, spinning: playback.isPlaying(key)).frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text(pick.title).font(Typo.ui(800, 12)).foregroundStyle(.white).lineLimit(1)
                    Text(pick.artist).font(Typo.ui(600, 10.5)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                }
                MusicEqualizer(animating: playback.isPlaying(key), lime: true)
            }.padding(.leading, 6).padding(.trailing, 12).frame(height: 44).background(.white.opacity(0.1), in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }.buttonStyle(HVPress(scale: 0.96)).onDisappear { if playback.isPlaying(key) { playback.stop() } }
    }

    private func toggle() {
        if playback.isPlaying(key) { Haptics.play(.soft); playback.stop(); return }
        Haptics.play(.tick)
        Task {
            var u = url
            if u == nil, let l = pick.link.flatMap(URL.init(string:)), let id = MusicLink.appleSongID(from: l) {
                u = await AppleMusicCatalog.previewURL(songID: id)
                url = u
            }
            if let u { playback.setVolume(0.9); playback.start(key: key, url: u) }
        }
    }
}


/// 見本の 投稿(友だちが できると 消える)。写真は 色の グラデーションの 見本(本物の 友だちの 写真は 使わない)
struct SamplePostV94: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    private let grads: [[Color]] = [[Color(hex: "F2B28C"), Color(hex: "C97A9E")], [Color(hex: "8EC5D6"), Color(hex: "5B7FB0")], [Color(hex: "E9D48A"), Color(hex: "D98C5F")]]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Circle().fill(LinearGradient(colors: [Color(hex: "61D278"), Color(hex: "EE5E9C")], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 40, height: 40).overlay(Text("あ").font(Typo.ui(900, 17)).foregroundStyle(.white))
                    VStack(alignment: .leading, spacing: 2) { Text("あや").font(Typo.ui(800, 16)).foregroundStyle(.white); Text("@aya_0612 ・ きのう 3こま").font(Typo.label(10)).foregroundStyle(.white.opacity(0.5)).lineLimit(1).minimumScaleFactor(0.7) }
                    Spacer()
                    Text("9:00 OPEN").font(Typo.label(9.5)).tracking(1).foregroundStyle(HV.lime).lineLimit(1).fixedSize().padding(.trailing, 70).padding(.top, 2)
                }.padding(.horizontal, 16).padding(.top, 16)
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color(hex: "F4F1EA"))
                            .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 2).fill(LinearGradient(colors: grads[i], startPoint: .top, endPoint: .bottom)).padding(.horizontal, 7).padding(.top, 7).frame(height: 138) }
                            .frame(width: 118, height: 160).shadow(color: .black.opacity(0.5), radius: 8, y: 6)
                            .rotationEffect(.degrees([-8.0, 2, 9][i])).offset(x: [-86, 0, 86][i] as CGFloat, y: shown || reduceMotion ? 0 : 40).opacity(shown || reduceMotion ? 1 : 0)
                            .animation(.timingCurve(0.2, 0.8, 0.3, 1, duration: 0.62).delay(0.09 * Double(i)), value: shown)
                    }
                    Text("#放課後").font(Typo.ui(900, 12)).foregroundStyle(HV.ink).padding(.horizontal, 9).frame(height: 26).background(HV.lime, in: RoundedRectangle(cornerRadius: 9)).rotationEffect(.degrees(-6)).offset(x: -96, y: -64)
                    Text("#カフェ").font(Typo.ui(900, 12)).foregroundStyle(.white).padding(.horizontal, 9).frame(height: 26).background(Color(hex: "EE5E9C"), in: RoundedRectangle(cornerRadius: 9)).rotationEffect(.degrees(5)).offset(x: 98, y: 62)
                }.frame(maxWidth: .infinity).frame(height: 210).padding(.top, 10)
                HStack(spacing: 8) {
                    Label("鎌倉市", systemImage: "mappin").font(Typo.ui(700, 11.5)).foregroundStyle(.white.opacity(0.7))
                    Label("夕焼けの 歌", systemImage: "music.note").font(Typo.ui(700, 11.5)).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                }.padding(.horizontal, 16).padding(.top, 4)
                HStack(spacing: 14) {
                    Image(systemName: "heart").font(.system(size: 19, weight: .semibold)); Image(systemName: "bubble.left").font(.system(size: 19, weight: .semibold))
                    Spacer()
                    Text("あや ・ ほか 2人が 見た").font(Typo.ui(600, 12)).foregroundStyle(.white.opacity(0.5))
                }.foregroundStyle(.white).padding(.horizontal, 16).padding(.vertical, 14)
            }
            Text("SAMPLE").font(Typo.label(10)).fontWeight(.bold).tracking(1.6).foregroundStyle(HV.ink).padding(.horizontal, 12).frame(height: 24).background(HV.lime, in: Capsule()).padding(14)
        }
        .background(Color(hex: "121315"), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .padding(.horizontal, 8)
        .offset(y: shown || reduceMotion ? 0 : 30).opacity(shown || reduceMotion ? 1 : 0)
        .animation(.timingCurve(0.2, 0.8, 0.3, 1, duration: 0.62), value: shown)
        .onAppear { shown = true }
        .accessibilityElement(children: .ignore).accessibilityLabel("見本の 投稿")
    }
}
