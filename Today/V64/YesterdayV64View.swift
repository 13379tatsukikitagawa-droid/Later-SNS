import SwiftUI

// P20(v76)+ P22-B(v78)+ P23(v79)+ P24-B(v80)+ P25(v81):Lattag yesterday = 黒い 地 ・ Friends(BeReal の 形)・ Mondo ・ 通知 ・ あなたの きのう。
// タブは 標準の `TabView`(iOS 26 は 浮かぶ ガラス)。見本:Y01〜Y18。キャラクターは 使わない(人は 写真の 丸 / 名前の 1文字 + 色)。

struct YesterdayV64Input {
    struct Cell: Identifiable { let id: String; var photo: UIImage?; var name: String; var time: String?; var tag: String? }
    /// 1枚(1日 3枚まで)
    struct Photo: Identifiable { let id: String; var image: UIImage?; var time: String; var tag: String? }
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
    }
    struct Notice: Identifiable {
        enum Kind { case person, lattag, mondo }
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
    var friendCount = 0
    var shotFriends = 0
    var mondoPhoto: UIImage?
    var mondoTag = "#夕焼け"
    var mondoCity = "鎌倉市"
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
    var mondo = YesterdayMondoInput()

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
}

struct YesterdayV64View: View {
    var input: YesterdayV64Input
    var actions = YesterdayV64Actions()
    @State private var tab = 0   // 0 = Friends ・ 1 = Mondo
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
                TabView(selection: $tab) {
                    Tab("Friends", systemImage: "person.2", value: 0) { friendsTab(w: g.size.width).symbolVariant(.none).ignoresSafeArea(edges: .top) }
                    Tab("Mondo", systemImage: "globe", value: 1) { YesterdayMondoView(input: input, actions: actions, active: tab == 1, locked: input.locked, onScroll: { v in scrollNow(v, forTab: 1) }).ignoresSafeArea(edges: .top) }
                }
                .tint(HV.lime)
                .preferredColorScheme(.dark)
                .onChange(of: tab) { _, _ in Haptics.play(.sel); scrollY = 0 }

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
        let k: CGFloat = compact ? 0.8 : 1
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(compact ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.clear)).overlay(Color.black.opacity(compact ? 0.78 : 0))
                .frame(width: w, height: compact ? 96 : 112)
                .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(compact ? 0.12 : 0)).frame(height: 0.5) }
                .background(alignment: .top) { LinearGradient(stops: [.init(color: .black, location: 0.7), .init(color: .black.opacity(0), location: 1)], startPoint: .top, endPoint: .bottom).frame(height: 112).opacity(compact ? 0 : 1) }
                .allowsHitTesting(false)
            // 通知
            Button { Haptics.play(.pop); withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) { notices = true } } label: {
                Image(systemName: "bell").font(.system(size: 19, weight: .semibold)).foregroundStyle(.white).frame(width: 44, height: 44)
                    .background(.white.opacity(0.10), in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.1), lineWidth: 0.8))
                    .overlay(alignment: .topTrailing) { if input.hasNew || input.requestCount > 0 { Circle().fill(Color(hex: "FF3B30")).frame(width: 9, height: 9).offset(x: -6, y: 9) } }
            }.buttonStyle(HVPress(scale: 0.92)).scaleEffect(k).offset(x: 12 + (compact ? 4 : 0), y: compact ? 50 : 52)
            .accessibilityLabel("通知")
            // タブの 名前
            VStack(spacing: 1) {
                Text(tab == 0 ? "Friends" : "Mondo").font(LF.inter(900, compact ? 17 : 24)).tracking(compact ? -0.7 : -0.96).foregroundStyle(.white).frame(height: compact ? 22 : 30)
                if !compact {
                    Text(tab == 0 ? friendsSubtitle : "THE WORLD, YESTERDAY")
                        .font(tab == 0 ? LF.inter(600, 11.5) : LF.inter(700, 11.5)).foregroundStyle(.white.opacity(0.5)).frame(height: 16)
                }
            }.frame(width: 250).offset(x: (w - 250) / 2, y: compact ? 58 : 52)
            // 右上 = 自分の アイコン(1回 → プロフィール ・ 2回 → 今日)
            Button { } label: { avatar }.buttonStyle(HVPress(scale: 0.92)).scaleEffect(k)
                .onTapGesture(count: 2) { Haptics.play(.pop); actions.close() }
                .onTapGesture { Haptics.play(.sel); actions.openProfile() }
                .offset(x: w - 56 - (compact ? 4 : 0), y: compact ? 50 : 52)
                .accessibilityLabel("プロフィール。2回 タップで 今日へ")
        }
        .frame(width: w, alignment: .topLeading)
        .animation(.timingCurve(0.3, 1.15, 0.4, 1, duration: 0.45), value: compact)
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(Color.black).frame(width: 44, height: 44)
            Group {
                if let a = input.avatar { Image(uiImage: a).resizable().scaledToFill() }
                else { Circle().fill(LinearGradient(colors: [Color(hex: "61D278"), Color(hex: "EE5E9C")], startPoint: .topLeading, endPoint: .bottomTrailing)).overlay(Text(String(input.avatarName.prefix(1))).font(LF.inter(900, 16)).foregroundStyle(.white)) }
            }.frame(width: 40, height: 40).clipShape(Circle())
            Circle().strokeBorder(HV.lime, lineWidth: compact ? 1 : 1.5).frame(width: 44, height: 44)
        }.frame(width: 44, height: 44)
    }

    // MARK: Friends

    private func friendsTab(w: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: 120)
                if hasMine { myBlock(w: w) } else { firstShot }
                if noFriends { inviteBlock.padding(.top, hasMine ? 30 : 34) }
                if input.locked && hasMine { lockBand.padding(.horizontal, 16).padding(.top, 14) }
                VStack(spacing: 0) {
                    ForEach(input.posts) { post in postView(post, w: w) }
                }.padding(.top, input.locked ? 14 : 22)
                Color.clear.frame(height: 150)
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { max(0, $0.contentOffset.y + $0.contentInsets.top) } action: { _, v in scrollNow(v, forTab: 0) }
        .scrollPosition($pos)
        .onAppear { if let y = input.debugScrollY, tab == 0 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { pos.scrollTo(y: y) } } }
        .background(Color.black)
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
            .onAppear { withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) { floatUp = true } }
            Text("最初の 1枚を 撮ろう").font(LF.inter(900, 24)).foregroundStyle(.white).padding(.top, 18)
            Text("あした 9:00 に、ここで ひらきます").font(LF.inter(600, 13)).foregroundStyle(.white.opacity(0.5)).padding(.top, 6)
            Button { Haptics.play(.click); actions.shoot() } label: {
                HStack(spacing: 10) { Image(systemName: "camera").font(.system(size: 19, weight: .semibold)); Text("撮る").font(LF.inter(900, 17)) }.foregroundStyle(HV.ink).frame(maxWidth: .infinity).frame(height: 56).background(HV.lime, in: Capsule())
            }.buttonStyle(HVPress(scale: 0.98)).padding(.horizontal, 16).padding(.top, 20)
        }.frame(maxWidth: .infinity)
    }

    // ② 友だちを よぶ(友だちが 0人の 時)
    private var inviteBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("友だちを よぶ").font(LF.inter(900, 19)).foregroundStyle(.white)
                Spacer()
                Text("0 FRIENDS").font(LF.mono(10.5)).tracking(1.5).foregroundStyle(.white.opacity(0.4))
            }.padding(.horizontal, 16)
            HStack(spacing: 8) {
                inviteTile("qrcode", "QR を 見せる", green: true) { actions.addFriends() }
                inviteTile("viewfinder", "QR を 読む", green: false) { actions.scanQR() }
                inviteTile("link", "リンク", green: false) { actions.openFriends() }
            }.padding(.horizontal, 16).padding(.top, 12)
            VStack(spacing: 14) { ghostPost; ghostPost }.padding(.top, 22)
                .mask(LinearGradient(colors: [.black, .black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
        }
    }
    private func inviteTile(_ icon: String, _ t: String, green: Bool, _ a: @escaping () -> Void) -> some View {
        Button { Haptics.play(.click); a() } label: {
            VStack(spacing: 10) { Image(systemName: icon).font(.system(size: 24, weight: .semibold)); Text(t).font(LF.inter(800, 13)) }
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
                        if let t = main?.time { Text(t).font(LF.mono(9.5)).fontWeight(.bold).foregroundStyle(.white).padding(.horizontal, 8).frame(height: 20).background(.black.opacity(0.45), in: Capsule()).offset(x: 71, y: 6) }
                        if let tag = main?.tag { Text("#\(tag)").font(LF.inter(800, 11)).foregroundStyle(HV.ink).padding(.horizontal, 8).frame(height: 22).background(HV.lime, in: Capsule()).offset(x: 6, y: 132) }
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
                            VStack(spacing: 2) { Text("+\(max(0, input.mine.count - 1))").font(LF.inter(800, 22)).foregroundStyle(.white); Text("more").font(LF.inter(600, 12)).foregroundStyle(.white.opacity(0.75)) }.offset(y: 27)
                        }.frame(width: 100, height: 136)
                    }.buttonStyle(HVPress(scale: 0.97)).offset(x: (w - 120) / 2 + 120 + 14, y: 12)
                }
            }.frame(width: w, height: 160, alignment: .topLeading)
            Text(input.mineCaption ?? "キャプションを 追加…").font(LF.inter(600, 16)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 24).padding(.top, 16)
            HStack(spacing: 14) {
                circleButton { Image(systemName: "paperplane").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white) } action: { Haptics.play(.tick); actions.addFriends() }
                circleButton { Text("#").font(LF.inter(900, 22)).foregroundStyle(HV.lime) } action: { Haptics.play(.pop) }
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
                Text("今日 1枚 撮ると、きのうが ひらく").font(LF.inter(800, 14)).foregroundStyle(.white)
                Text("友だちの 写真は ぼかしと ひとこと だけ").font(LF.inter(600, 12)).foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
            Button { Haptics.play(.click); actions.shoot() } label: { Text("撮る").font(LF.inter(800, 14)).foregroundStyle(HV.ink).padding(.horizontal, 18).frame(height: 36).background(HV.lime, in: Capsule()) }.buttonStyle(HVPress(scale: 0.95))
        }
        .padding(.horizontal, 16).padding(.vertical, 14).background(Color(hex: "121314"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: 投稿(1人 = 1つ)

    private func postView(_ post: YesterdayV64Input.Post, w: CGFloat) -> some View {
        let idx = min(swapped[post.id] ?? 0, max(0, post.photos.count - 1))
        let big = post.photos.indices.contains(idx) ? post.photos[idx] : nil
        let smalls = post.photos.enumerated().filter { $0.offset != idx }
        let hidden = !post.published || input.locked
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                avatarCircle(post.avatar, name: post.name, size: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.name).font(LF.inter(700, 15)).foregroundStyle(.white)
                    Text(post.published ? [post.place, post.when].filter { !$0.isEmpty }.joined(separator: " ・ ") : "まだ 公開して いません").font(LF.inter(500, 12.5)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer(minLength: 0)
                Text("···").font(LF.inter(900, 18)).foregroundStyle(.white).frame(width: 36, height: 36)
            }.padding(.horizontal, 16).padding(.top, 2)
            // 写真
            ZStack(alignment: .topLeading) {
                ZStack {
                    Color(hex: "111111")
                    if let img = big?.image {
                        if hidden { Image(uiImage: V64Images.blurred(key: "yb\(post.id)\(idx)", source: img, maxPixel: 48, radius: 14, saturation: 1.0, brightness: 0.6)).resizable().scaledToFill() }
                        else { Image(uiImage: img).resizable().scaledToFill() }
                    }
                }
                .frame(width: w - 16, height: (w - 16) * 4 / 3).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture { if !hidden, let big { viewing = .init(id: big.id, photo: big.image, name: post.name, time: big.time, tag: big.tag); Haptics.play(.tick) } }
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
                        Text(t).font(LF.mono(11)).fontWeight(.bold).foregroundStyle(.white).padding(.horizontal, 12).frame(height: 26).background(.black.opacity(0.45), in: Capsule())
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
            if let cap = post.caption, !cap.isEmpty { Text(cap).font(LF.inter(500, 14.5)).foregroundStyle(.white).padding(.horizontal, 16).padding(.top, 12) }
            if post.published && !input.locked { Text("コメントを 追加…").font(LF.inter(500, 14.5)).foregroundStyle(.white.opacity(0.45)).padding(.horizontal, 16).padding(.top, 8) }
            Color.clear.frame(height: 22)
        }
    }

    private func tagPill(_ tag: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text("#").font(LF.inter(900, 14)).foregroundStyle(on ? HV.lime : .white).frame(width: 24, height: 24).background(on ? Color.black : Color.white.opacity(0.14), in: Circle())
                Text(tag).font(LF.inter(800, 13.5)).foregroundStyle(on ? HV.ink : .white.opacity(0.78))
            }
            .padding(.leading, 4).padding(.trailing, 14).frame(height: 32)
            .background(on ? HV.lime : Color.white.opacity(0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(on ? 0 : 0.12), lineWidth: 1))
        }.buttonStyle(HVPress(scale: 0.95))
    }

    func avatarCircle(_ img: UIImage?, name: String, size: CGFloat) -> some View {
        ZStack {
            if let img { Image(uiImage: img).resizable().scaledToFill() }
            else { Circle().fill(LinearGradient(colors: [Color(hex: "61D278"), Color(hex: "EE5E9C")], startPoint: .topLeading, endPoint: .bottomTrailing)).overlay(Text(String(name.prefix(1))).font(LF.inter(900, size * 0.4)).foregroundStyle(.white)) }
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
                    Text("通知").font(LF.inter(900, 24)).foregroundStyle(.white)
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
            case .lattag: Text("#").font(LF.inter(900, 22)).foregroundStyle(HV.ink).frame(width: 42, height: 42).background(HV.lime, in: Circle())
            case .mondo: Image(systemName: "globe").font(.system(size: 20, weight: .semibold)).foregroundStyle(HV.ink).frame(width: 42, height: 42).background(HV.lime, in: Circle())
            }
            VStack(alignment: .leading, spacing: 4) {
                (Text(n.name).font(LF.inter(800, 15)).foregroundColor(.white) + Text(" " + n.text).font(LF.inter(600, 15)).foregroundColor(.white.opacity(0.88))).lineLimit(1).minimumScaleFactor(0.85)
                HStack(spacing: 5) {
                    if n.isNew { Circle().fill(HV.lime).frame(width: 5, height: 5) }
                    Text(n.time).font(LF.inter(600, 12.5)).foregroundStyle(.white.opacity(0.5))
                }
            }
            Spacer(minLength: 0)
            if let id = n.approveID {
                Button { Haptics.play(.success); actions.approve(id) } label: { Text("承認").font(LF.inter(800, 13)).foregroundStyle(HV.ink).padding(.horizontal, 16).frame(height: 32).background(HV.lime, in: Capsule()) }.buttonStyle(HVPress(scale: 0.94))
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
                Text("あなたの きのう").font(LF.inter(900, 22)).foregroundStyle(.white)
                Text("\(min(photos.count, mineIndex + 1)) / \(photos.count) ・ \(p?.time ?? "")").font(LF.mono(11)).foregroundStyle(.white.opacity(0.5))
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
                Text(input.mineCaption ?? "キャプションを 追加…").font(LF.inter(600, 16)).foregroundStyle(.white).padding(.horizontal, 16).padding(.top, 16)
                HStack(spacing: 8) {
                    Text("リアクション").font(LF.inter(700, 14)).foregroundStyle(.white.opacity(0.5))
                    HStack(spacing: -12) { ForEach(Array((input.posts.first?.reactors ?? []).prefix(3).enumerated()), id: \.offset) { _, r in avatarCircle(r, name: "", size: 32).overlay(Circle().strokeBorder(.black, lineWidth: 2)) } }
                    Text("\(min(3, input.posts.first?.reactors.count ?? 0))").font(LF.inter(800, 16)).foregroundStyle(.white)
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
                Text(c.name).font(LF.serif(26)).foregroundStyle(.white)
                Text(c.time.map { "yesterday · \($0)" } ?? "today's one · picked by the world").font(LF.inter(500, 12.5)).foregroundStyle(Color(hex: "8E8E93"))
            }.frame(width: 246).offset(x: 72, y: 55)
            Button { Haptics.play(.tick); withAnimation(.easeOut(duration: 0.25)) { viewing = nil } } label: {
                Image(systemName: "arrow.left").font(.system(size: 17, weight: .bold)).foregroundStyle(.white).frame(width: 48, height: 48).background(Color(hex: "161618"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }.buttonStyle(.plain).offset(x: 14, y: 54)
            ZStack { Color(hex: "2A2326"); if let img = c.photo { Image(uiImage: img).resizable().scaledToFill() } }
                .frame(width: 362, height: 560).clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous)).offset(x: 14, y: 118)
            if let tag = c.tag {
                Text(tag.hasPrefix("#") ? tag : "#\(tag)").font(LF.inter(900, 15)).foregroundStyle(HV.ink).frame(width: 81, height: 36)
                    .background(Color(hex: "9ED8FF"), in: RoundedRectangle(cornerRadius: 12)).rotationEffect(.degrees(-6)).offset(x: 29, y: 628)
            }
            Button { Haptics.play(.pop); actions.openPhoto(c.id) } label: {
                Text("reply").font(LF.inter(800, 15)).foregroundStyle(HV.ink).frame(width: 106, height: 56).background(.white, in: Capsule())
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
