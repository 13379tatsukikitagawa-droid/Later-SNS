import SwiftUI

// v134 Phase 2:Home(Friends | Trip)。見本 screens/20〜23, 28。
// 上:ともだち追加 ・ ロゴ ・ アバター。まんなか:あなたのきのう → ともだちの丸 → きのう(投稿)→ まだひらいていない → 最後の 一文。
// 下:ガラスの タブ(Friends | Trip)+ #レンズ + 今日の フィルム。スクロールで タブが 小さく なり、フィルムが タブと # の 間に 入る。
// データは `YesterdayV64Input`(Host が 作る)。中の 仕組みは 変えない。

struct HomeV134View: View {
    var input: YesterdayV64Input
    var actions = YesterdayV64Actions()
    var startTab = 0

    @State private var tab = 0
    @State private var scrollY: CGFloat = 0
    @State private var tripPos = ScrollPosition()
    @State private var feedPos = ScrollPosition()
    @State private var showFilm = false
    @State private var showFriends = false
    @State private var showMorning = false
    @State private var story: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var compact: Bool { scrollY > 80 }
    private var status: HomeV134Rules.FilmStatus { HomeV134Rules.filmStatus(shots: input.shotsUsed, now: input.now) }
    private var night: Bool { HomeV134Rules.isNight(input.now) }
    private var yesterdayTimes: [Date] { input.mine.compactMap(\.captured) }

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .top) {
                LTColor.bg.ignoresSafeArea()
                ZStack {
                    feed(width: g.size.width, safeTop: g.safeAreaInsets.top)
                        .opacity(tab == 0 ? 1 : 0).allowsHitTesting(tab == 0)
                    TripHubView(items: input.trips, now: input.now, onOpen: { actions.openTrip($0) }, onNew: { actions.newTrip() }, onJoinKey: { actions.joinKey() },
                                position: $tripPos, topInset: g.safeAreaInsets.top + 62, onScroll: { v in if tab == 1 { scrollY = v } })
                        .ignoresSafeArea(edges: .top)
                        .opacity(tab == 1 ? 1 : 0).allowsHitTesting(tab == 1)
                }
                .animation(.easeOut(duration: 0.18), value: tab)
                .blur(radius: night ? 26 : 0).brightness(night ? -0.5 : 0).allowsHitTesting(!night)
                if night { LightsOutV134(times: yesterdayTimes, target: status.target, now: input.now).transition(.opacity) }
                header(safeTop: g.safeAreaInsets.top, width: g.size.width)
                bottomBar(safeBottom: g.safeAreaInsets.bottom)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            tab = startTab
            if HomeV134Rules.shouldShowGoodMorning(now: input.now, lastShownDay: GoodMorningStore.lastShownDay, hasYesterday: !yesterdayTimes.isEmpty) || UserDefaults.standard.bool(forKey: "debugGM") {
                GoodMorningStore.markShown(now: input.now)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showMorning = true }
            }
            #if DEBUG
            switch UserDefaults.standard.string(forKey: "debugSheet") { case "film": showFilm = true; case "friends": showFriends = true; case "story": if !input.posts.isEmpty { story = 0 }; case "storyp": if !input.posts.isEmpty { story = input.posts.firstIndex { !$0.published || $0.photos.isEmpty } ?? 0 }; default: break }
            #endif
            if let y = input.debugScrollY { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { if tab == 0 { feedPos.scrollTo(y: y) } else { tripPos.scrollTo(y: y) } } }
        }
        .onChange(of: tab) { _, _ in scrollY = 0 }
        .fullScreenCover(isPresented: Binding(get: { story != nil && !input.posts.isEmpty }, set: { if !$0 { story = nil } })) {
            StoryV134View(people: input.posts, startIndex: story ?? 0, onClose: { story = nil }, onReply: { id, name in actions.openChat(id, name) })
        }
        .fullScreenCover(isPresented: $showMorning) {
            GoodMorningV134(times: yesterdayTimes, now: input.now, onShoot: { showMorning = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { actions.shoot() } }, onLater: { showMorning = false })
        }
        .sheet(isPresented: $showFilm) {
            TodaysFilmSheetV134(shotTimes: input.shotTimes, status: status, now: input.now)
                .presentationDetents([.height(560)]).presentationCornerRadius(LTRadius.sheet).presentationBackground(Color(hex6: 0x0B0B0D))
        }
        .sheet(isPresented: $showFriends) {
            FriendsSheetV134(input: input, actions: actions) { showFriends = false }
                .presentationDetents([.large]).presentationCornerRadius(LTRadius.sheet).presentationBackground(Color(hex6: 0x0B0B0D))
        }
    }

    // MARK: 上

    private func header(safeTop: CGFloat, width: CGFloat) -> some View {
        ZStack {
            LinearGradient(colors: [.black.opacity(0.92), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: safeTop + 84).frame(maxHeight: .infinity, alignment: .top).ignoresSafeArea().allowsHitTesting(false)
            HStack {
                Button { LTHaptics.play(.tap); showFriends = true } label: {
                    Image(systemName: "person.badge.plus").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 40, height: 40).background(Color.white.opacity(0.08), in: Circle())
                        .overlay(Circle().strokeBorder(LTColor.hairline2, lineWidth: 0.8))
                        .overlay(alignment: .topTrailing) {
                            if input.requestCount > 0 { countBadge(input.requestCount).offset(x: 6, y: -6) }
                        }
                        .frame(width: 48, height: 48).contentShape(Circle())
                }.buttonStyle(HVPress(scale: 0.92)).accessibilityLabel(input.requestCount > 0 ? "ともだち追加。リクエスト\(input.requestCount)件" : "ともだち追加")
                Spacer()
                Button { LTHaptics.play(.tap); actions.openProfile() } label: {
                    avatar.frame(width: 40, height: 40).clipShape(Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.28), lineWidth: 1.5))
                        .frame(width: 48, height: 48).contentShape(Circle())
                }.buttonStyle(HVPress(scale: 0.92)).accessibilityLabel("プロフィール")
            }
            .padding(.horizontal, 12)
            .overlay { Image("LattagWordmark").renderingMode(.template).resizable().scaledToFit().frame(height: 25).foregroundStyle(.white).allowsHitTesting(false) }
            .frame(maxHeight: .infinity, alignment: .top).padding(.top, 4)
        }
    }

    @ViewBuilder private var avatar: some View {
        if let a = input.avatar { Image(uiImage: a).resizable().scaledToFill() }
        else { Circle().fill(HomeV134Parts.color(input.avatarName)).overlay(Text(String(input.avatarName.prefix(1))).font(LTFont.ui(16, weight: .heavy)).foregroundStyle(LTColor.limeInk)) }
    }

    private func countBadge(_ n: Int) -> some View {
        Text(n > 9 ? "9+" : "\(n)").font(LTFont.ui(11, weight: .heavy)).foregroundStyle(.white)
            .padding(.horizontal, 5).frame(minWidth: 19, minHeight: 19).background(LTColor.badge, in: Capsule())
            .overlay(Capsule().strokeBorder(.black, lineWidth: 2))
    }

    // MARK: Friends

    private func feed(width: CGFloat, safeTop: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                YesterdayCardV134(input: input, onShoot: { shoot() })
                    .padding(.horizontal, 14).padding(.top, safeTop + 66)
                circles.padding(.top, 20)
                if !published.isEmpty {
                    feedHeader.padding(.horizontal, 20).padding(.top, 26)
                    ForEach(published) { p in
                        PostV134(post: p, onReply: { actions.openChat(p.friendID, p.name) }).padding(.top, 14)
                    }
                }
                if !pending.isEmpty { pendingSection.padding(.top, 34) }
                endMark.padding(.top, 40)
                Color.clear.frame(height: 170)
            }
        }
        .scrollPosition($feedPos)
        .scrollDisabled(night)
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, v in if tab == 0 { scrollY = v } }
        .ignoresSafeArea(edges: .top)
    }

    private var published: [YesterdayV64Input.Post] { input.posts.filter { $0.published && !$0.photos.isEmpty } }
    private var pending: [YesterdayV64Input.Post] { input.posts.filter { !$0.published || $0.photos.isEmpty } }

    private var circles: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(input.posts) { p in
                    Button {
                        LTHaptics.play(.select)
                        if let i = input.posts.firstIndex(where: { $0.id == p.id }) { story = i }
                    } label: { circle(p) }.buttonStyle(HVPress(scale: 0.94))
                }
                Button { LTHaptics.play(.tap); actions.shareLink() } label: {
                    VStack(spacing: 7) {
                        Image(systemName: "plus").font(.system(size: 20, weight: .bold)).foregroundStyle(LTColor.ink2)
                            .frame(width: 64, height: 64).background(Color.white.opacity(0.06), in: Circle())
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])))
                        Text("呼ぶ").font(LTFont.ui(12)).foregroundStyle(LTColor.ink2)
                    }
                }.buttonStyle(HVPress(scale: 0.94)).accessibilityLabel("ともだちを呼ぶ")
            }.padding(.horizontal, 18)
        }
    }

    private func circle(_ p: YesterdayV64Input.Post) -> some View {
        let on = p.published && !p.photos.isEmpty
        return VStack(spacing: 7) {
            ZStack {
                Group {
                    if let a = p.avatar { Image(uiImage: a).resizable().scaledToFill() }
                    else { Circle().fill(HomeV134Parts.color(p.name)).overlay(Text(String(p.name.prefix(1))).font(LTFont.ui(24, weight: .heavy)).foregroundStyle(.white)) }
                }
                .frame(width: 56, height: 56).clipShape(Circle()).opacity(on ? 1 : 0.5)
                Circle().strokeBorder(LTColor.lime, lineWidth: on ? 2.2 : 0).frame(width: 64, height: 64)
                if !on { Circle().strokeBorder(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])).frame(width: 64, height: 64) }
            }.frame(width: 64, height: 64)
            Text(p.name).font(LTFont.ui(12)).foregroundStyle(on ? LTColor.ink : LTColor.ink3).lineLimit(1).frame(width: 66)
        }
        .accessibilityElement(children: .ignore).accessibilityLabel(on ? "\(p.name)の投稿" : "\(p.name)。まだひらいていない")
    }

    private var feedHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("きのう").font(LTFont.ui(28, weight: .heavy)).foregroundStyle(.white)
            if let d = firstDate { Text(HomeV134Rules.dayLabel(d)).font(LTFont.display(20)).foregroundStyle(LTColor.ink3) }
            Spacer()
            Text("\(published.count)人がのせた").font(LTFont.ui(13)).foregroundStyle(LTColor.ink3)
        }
    }

    private var firstDate: Date? { published.first?.photos.first?.captured ?? input.mine.first?.captured }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("まだひらいていない").font(LTFont.ui(22, weight: .heavy)).foregroundStyle(.white); Spacer(); Text("\(pending.count)人").font(LTFont.ui(13)).foregroundStyle(LTColor.ink3) }
            ForEach(pending) { p in
                HStack(spacing: 12) {
                    Group { if let a = p.avatar { Image(uiImage: a).resizable().scaledToFill() } else { Circle().fill(HomeV134Parts.color(p.name)) } }
                        .frame(width: 44, height: 44).clipShape(Circle()).saturation(0.6)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) { Text(p.name).font(LTFont.ui(16, weight: .heavy)).foregroundStyle(.white); Text(p.when).font(LTFont.ui(12)).foregroundStyle(LTColor.ink3) }
                        if let t = p.photos.first?.tag { TagChip(text: t, hashColor: HomeV134Parts.hashColor(t)) }
                    }
                    Spacer()
                    // ひらく 前の 写真は 見せない(色の 板 + 鍵)
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LinearGradient(colors: [Color(hex6: 0x6E6660), Color(hex6: 0x2A2624)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 52, height: 68).overlay(Image(systemName: "lock.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.85)))
                }
                .padding(12).background(LTColor.surface1, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(LTColor.hairline, lineWidth: 1))
                .accessibilityElement(children: .combine).accessibilityLabel("\(p.name)。まだひらいていない")
            }
        }.padding(.horizontal, 14)
    }

    private var endMark: some View {
        VStack(spacing: 8) {
            HashLensView(size: 34, locked: false, glowing: false).accessibilityHidden(true)
            Text("きのうは、ここまで。").font(LTFont.ui(18, weight: .heavy)).foregroundStyle(.white).padding(.top, 10)
            Text("あしたの9:00に、また。").font(LTFont.ui(13)).foregroundStyle(LTColor.ink3)
        }.frame(maxWidth: .infinity)
    }

    // MARK: 下

    private func shoot() {
        if status.lensLocked { LTHaptics.play(.warning); actions.toast(status.night ? "9:00に、あかりがつく" : "今日は、ここまで"); return }
        LTHaptics.play(.tap); actions.shoot()
    }

    private func bottomBar(safeBottom: CGFloat) -> some View {
        let anim: Animation? = reduceMotion ? nil : LTMotion.spring
        return VStack(spacing: 10) {
            Spacer(minLength: 0)
            if !compact { accessory(compact: false) }
            HStack(spacing: 10) {
                if compact {
                    Button { LTHaptics.play(.select); withAnimation(anim) { tab = tab == 0 ? 1 : 0 } } label: {
                        Image(systemName: tab == 0 ? "person.2" : "ticket").font(.system(size: 21, weight: .semibold)).foregroundStyle(.white).frame(width: 56, height: 56)
                    }.lgGlass(radius: 28, interactive: true).accessibilityLabel(tab == 0 ? "Friends" : "Trip")
                    accessory(compact: true)
                } else {
                    tabs
                    Spacer(minLength: 0)
                }
                Button { shoot() } label: { HashLensView(size: 64, locked: status.lensLocked) }
                    .buttonStyle(HVPress(scale: 0.94)).accessibilityLabel(status.lensLocked ? "9:00から撮れます" : "撮る")
            }
        }
        .padding(.horizontal, 16).padding(.bottom, max(safeBottom, 10) + 2)
        .background(alignment: .bottom) { LinearGradient(colors: [.black.opacity(0), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom).frame(height: 190).ignoresSafeArea().allowsHitTesting(false) }
        .animation(anim, value: compact)
    }

    private var tabs: some View {
        HStack(spacing: 4) {
            tabButton("Friends", icon: "person.2", index: 0, badge: 0)
            tabButton("Trip", icon: "ticket", index: 1, badge: input.tripBadge)
        }
        .padding(4).lgGlass(radius: 32)
    }

    private func tabButton(_ title: String, icon: String, index: Int, badge: Int) -> some View {
        Button { if tab != index { LTHaptics.play(.select); tab = index } else { withAnimation(.easeOut(duration: 0.3)) { if index == 0 { feedPos.scrollTo(edge: .top) } else { tripPos.scrollTo(edge: .top) } } } } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold))
                Text(title).font(LTFont.ui(11.5, weight: .heavy))
            }
            .foregroundStyle(tab == index ? .white : Color.white.opacity(0.62)).frame(width: 92, height: 56)
            .background(tab == index ? Color.white.opacity(0.1) : .clear, in: Capsule())
            .overlay(alignment: .topTrailing) { if badge > 0 { countBadge(badge).offset(x: -16, y: 2) } }
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityAddTraits(tab == index ? [.isSelected] : [])
    }

    private func accessory(compact: Bool) -> some View {
        let s = status
        let range = input.now...max(s.target, input.now.addingTimeInterval(1))
        return Button { LTHaptics.play(.tap); showFilm = true } label: {
            HStack(spacing: compact ? 8 : 12) {
                filmFrames(small: compact)
                if compact {
                    Text(s.shortLabel).font(LTFont.ui(11.5, weight: .heavy)).foregroundStyle(LTColor.ink2).lineLimit(1)
                    Text(timerInterval: range, countsDown: true).font(LTFont.display(24)).monospacedDigit().foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                } else {
                    VStack(spacing: 2) {
                        Text(s.title).font(LTFont.ui(15.5, weight: .heavy)).foregroundStyle(.white)
                        Text(s.sub).font(LTFont.ui(11.5)).foregroundStyle(LTColor.ink2)
                    }.lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity)
                    Text(timerInterval: range, countsDown: true).font(LTFont.display(28)).monospacedDigit().foregroundStyle(.white).lineLimit(1)
                }
            }
            .padding(.horizontal, compact ? 12 : 14).frame(height: compact ? 56 : 64).frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain).lgGlass(radius: compact ? 28 : 32, interactive: true)
        .accessibilityLabel("\(s.title)。\(s.sub)")
    }

    private func filmFrames(small: Bool) -> some View {
        HStack(spacing: small ? 4 : 5) {
            ForEach(0..<3, id: \.self) { i in
                let used = i < min(3, input.shotsUsed)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(used ? AnyShapeStyle(LinearGradient(colors: [LTColor.milkTop, LTColor.milkBottom], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
                    .frame(width: small ? 15 : 20, height: small ? 21 : 28)
                    // 撮ったチェキが とんで 入る 先(`ShotFlightOverlay`)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { FilmLanding.shared.slotFrames[i] = $0 }
            }
        }.accessibilityHidden(true)
    }
}

enum HomeV134Parts {
    private static let palette = ["F27AA8", "6E9BFF", "9B7CFF", "C8A56A", "7FC8A9", "FFB26B", "5AC8FF"]
    static func color(_ name: String) -> Color {
        let n = name.unicodeScalars.reduce(0) { ($0 &+ Int($1.value)) & 0xFFFF }
        return Color(hex: palette[n % palette.count])
    }
    /// タグの「#」だけに 色(言葉ごとに 決まった 色)
    static func hashColor(_ tag: String) -> Color {
        let n = tag.unicodeScalars.reduce(0) { ($0 &+ Int($1.value)) & 0xFFFF }
        return [LTColor.tagPink, LTColor.tagSky, LTColor.tagYellow, LTColor.lime][n % 4]
    }
}
