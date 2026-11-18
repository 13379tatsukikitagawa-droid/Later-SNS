import SwiftUI

// P03:横スライドの 5ページ(Camera / Friends / Trip / Mondo / Yesterday)。仕様:PROMPT_v64 §9〜11、v65 §5、v66 §4、v67(Mondo)。
// 座標は spec/screens/H11〜H18.json(カードの 左上 = (10, 178))。ここでは カード内の 座標(= 絶対 − (10, 178))で 書く。

struct HomeV64Friend: Identifiable {
    let id: String
    var name: String
    var color: Color
    var image: UIImage? = nil
    /// 今日 撮った 枚数(0〜3)
    var shots: Int = 0
    /// 最後に 撮った 時刻("17:05")。わからない ときは nil
    var time: String? = nil
}

/// 友だちに なりたい 人(申請)
struct HomeV64Request: Identifiable {
    let id: String
    var name: String
    var handle: String
    var ago: String
    var color: Color
    var image: UIImage? = nil
}

struct HomeV64Thumb: Identifiable {
    let id: String
    var image: UIImage?
    var time: String
    var tag: String? = nil
    var tagColor: Color = .white
}

struct HomeV64TripInfo {
    var id: UUID? = nil
    var name: String
    var members: [HomeV64Face]
    /// 23こま:撮った 人の 番号(撮って いない = nil)
    var frames: [Int?]
    var cover: UIImage? = nil
    var sub = ""
    var dayText = ""
    var unread = 0
}

/// 23こまの フィルム(撮った こまは 撮った 人の 色 ・ 次の こまは 白い ふち)。T04 T09
struct HVTripFilm: View {
    let trip: HomeV64TripInfo
    var height: CGFloat = 40
    var numbers = true
    var body: some View {
        let shot = trip.frames.filter { $0 != nil }.count
        VStack(alignment: .leading, spacing: 4) {
            if numbers {
                HStack(spacing: 0) { ForEach([1, 5, 10, 15, 20], id: \.self) { n in Text(String(format: "%02d", n)).font(LF.mono(8.5)).foregroundStyle(Color(hex: "FF9F43")).frame(width: n == 1 ? 14.5 : 0, alignment: .leading).fixedSize().offset(x: CGFloat(n - 1) * 12.7 - (n == 1 ? 0 : 0)) } }.frame(height: 10)
            }
            HStack(spacing: 2.5) {
                ForEach(0..<23, id: \.self) { i in
                    let who = trip.frames.indices.contains(i) ? trip.frames[i] : nil
                    RoundedRectangle(cornerRadius: 3).fill(who.flatMap { trip.members[safe: $0]?.color } ?? Color.white.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(i == shot ? Color.white.opacity(0.85) : .clear, lineWidth: 1.5))
                        .frame(height: height - 8)
                }
            }.padding(.horizontal, 6).frame(height: height).background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct HomeV64MondoInfo {
    var tags: [String] = ["#夕焼け", "#放課後", "#帰り道"]
    var city = "SYDNEY"
    var nowText = "NOW 9:00"
    var photo: UIImage? = nil
}

enum HVPage: Int, CaseIterable {
    case camera, friends, trip, mondo, yesterday
    var title: String { ["Camera", "Friends", "Trip", "Mondo", "Yesterday"][rawValue] }
    var icon: HVIconKind { [HVIconKind.camera, .friends, .trip, .mondo, .yesterday][rawValue] }
}

// MARK: - ページの 型(背景・ヘッダー行・タイトル・CTA)

/// v68:ページの カードは 透明。うしろの 写真は Home の 全面の 層(`HV68Backdrop`)が ページ位置で 入れかえる。
struct HVPageBackdrop: View {
    let photo: UIImage?
    var body: some View { Color.clear }
}

/// 上の 行:丸い アイコン(40pt)+ `0N / 03` + 右に 状態
struct HVPageHeader: View {
    let page: HVPage
    let number: Int
    let status: String?
    let cardW: CGFloat
    var iconColor: Color = HV.lime
    var body: some View {
        ZStack(alignment: .topLeading) {
            ZStack {
                Circle().fill(Color.black).offset(y: 3)
                Circle().fill(iconColor)
                Circle().strokeBorder(Color.black, lineWidth: 2)
                HVIcon(kind: page.icon, size: 20, color: page == .mondo ? .black : .black)
            }
            .frame(width: 40, height: 40).offset(x: 22, y: 22)
            Text(String(format: "%02d / 03", number)).font(LF.mono(9)).tracking(1.62).foregroundStyle(Color(hex: "6C6C73")).fixedSize().offset(x: 72, y: 35.5)
            if let status {
                Text(status).font(LF.mono(9.5)).tracking(1.14).foregroundStyle(Color(hex: "7EE08F")).fixedSize()
                    .frame(width: 200, alignment: .trailing).offset(x: cardW - 22 - 200, y: 35)
            }
        }
    }
}

struct HVPageTitle: View {
    let text: String
    var body: some View { Text(text).font(LF.serif(44)).tracking(-0.88).foregroundStyle(.white).frame(height: 41.8, alignment: .leading).fixedSize() }
}

/// 下の ボタン(CTA):白い 丸ボタン + 右に 緑の 丸
struct HVCTA: View {
    let title: String
    var locked = false
    var width: CGFloat
    var circle: Color = Color(hex: "3BD35A")
    var icon: String = "arrow.right"
    var bg: Color = .white
    let action: () -> Void
    var body: some View {
        Button(action: { Haptics.play(.click); action() }) {
            HStack {
                Text(title).font(LF.inter(800, 17)).foregroundStyle(locked ? .white : HV.ink)
                Spacer(minLength: 0)
                ZStack {
                    Circle().fill(locked ? HV.lime : circle)
                    if locked { HVCameraGlyph(width: 26, line: 1.9, color: .black, showsFlash: false) }
                    else { Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(HV.ink) }
                }.frame(width: 42, height: 42)
            }
            .padding(.leading, 22).padding(.trailing, 7)
            .frame(width: width, height: 56)
            .background(locked ? Color.white.opacity(0.14) : bg, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(locked ? 0.34 : 0), lineWidth: 1))
        }
        .buttonStyle(HVPress(scale: 0.97))
    }
}

// MARK: - 1 Friends

struct HVFriendsPage: View {
    let input: HomeV64Input
    let cardW: CGFloat
    let actions: HomeV64Actions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let shotFriends = input.friends.filter { $0.shots > 0 }.count
        ZStack(alignment: .topLeading) {
            HVPageBackdrop(photo: input.friends.first(where: { $0.image != nil })?.image ?? input.backdrop.first)
            HVPageHeader(page: .friends, number: 1, status: shotFriends > 0 ? "● \(shotFriends)人 撮った" : nil, cardW: cardW)
            HVPageTitle(text: "Friends").offset(x: 22, y: 72)
            if input.friends.isEmpty { emptyBody } else { filledBody(shotFriends) }
            HVCTA(title: "Friends を ひらく", width: 334) { actions.openFriends() }.offset(x: 18, y: 386)
        }
        .frame(width: cardW, height: 508, alignment: .topLeading)
    }

    // MARK: 友だち 0人(あなたの アイコン + 点線の 輪 + おすすめの 人)

    private var emptyBody: some View {
        ZStack(alignment: .topLeading) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || scenePhase != .active)) { ctx in
                let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
                ZStack {
                    Circle().strokeBorder(.white.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, dash: [3, 6])).frame(width: 128, height: 128).rotationEffect(.degrees(t * 6))
                    Circle().strokeBorder(.white.opacity(0.14), style: StrokeStyle(lineWidth: 1.5, dash: [2, 7])).frame(width: 190, height: 190).rotationEffect(.degrees(-t * 4))
                    ForEach(0..<3, id: \.self) { k in
                        let a = Double(k) * 2.094 + 0.6
                        let bob = sin(t * 0.9 + Double(k) * 1.7) * 4
                        Circle().strokeBorder(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
                            .background(Circle().fill(.white.opacity(0.06)))
                            .overlay(Image(systemName: "person.fill").font(.system(size: 13)).foregroundStyle(.white.opacity(0.22)))
                            .frame(width: 34, height: 34)
                            .offset(x: CGFloat(cos(a)) * 95, y: CGFloat(sin(a)) * 95 + CGFloat(bob))
                    }
                    ZStack {
                        Circle().fill(Color(hex: "3A3A3C")).frame(width: 52, height: 52)
                        if let a = input.avatar { Image(uiImage: a).resizable().scaledToFill().frame(width: 52, height: 52).clipShape(Circle()) }
                        else { Text(String(input.avatarName.prefix(1))).font(LF.inter(800, 20)).foregroundStyle(.white) }
                    }
                    .overlay(Circle().strokeBorder(HV.lime, lineWidth: 2.5).padding(-3)).shadow(color: HV.lime.opacity(0.55), radius: 10)
                }
                .frame(width: cardW, height: 200)
            }
            .offset(y: 100)
            Text("友だちと、毎朝 9:00 に きのうを 見せあう").font(LF.inter(600, 12.5)).foregroundStyle(.white.opacity(0.65)).lineLimit(1).minimumScaleFactor(0.7)
                .frame(width: cardW - 36).offset(x: 18, y: 296)
            HStack(spacing: 8) {
                tile("qrcode", "QR", lime: true) { actions.showQR() }
                tile("viewfinder", "読む", lime: false) { actions.scanQR() }
                tile("at", "@ID", lime: false) { actions.searchByID() }
                tile("link", "リンク", lime: false) { actions.shareLink() }
            }.frame(width: cardW - 36).offset(x: 18, y: 324)
        }
    }

    private func tile(_ icon: String, _ t: String, lime: Bool, _ a: @escaping () -> Void) -> some View {
        Button { Haptics.play(.click); a() } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 17, weight: .bold))
                Text(t).font(LF.inter(800, 11.5))
            }
            .foregroundStyle(lime ? HV.ink : .white).frame(maxWidth: .infinity).frame(height: 50)
            .background(lime ? HV.lime : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }.buttonStyle(HVPress(scale: 0.95))
    }

    // MARK: 友だち あり(ストーリーの 列 ・ 3つの 数字 ・ 申請)

    private func filledBody(_ shotFriends: Int) -> some View {
        let total = input.friends.count
        let waiting = total - shotFriends
        return ZStack(alignment: .topLeading) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(input.friends) { fr in story(fr) }
                    Button { Haptics.play(.sel); actions.addFriends() } label: {
                        VStack(spacing: 6) {
                            ZStack { Circle().strokeBorder(HV.lime.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [5, 4])).frame(width: 64, height: 64); Image(systemName: "plus").font(.system(size: 20, weight: .bold)).foregroundStyle(HV.lime) }
                            Text("よぶ").font(LF.inter(700, 10.5)).foregroundStyle(HV.lime)
                        }
                    }.buttonStyle(HVPress(scale: 0.94))
                }.padding(.horizontal, 20)
            }
            .frame(width: cardW, height: 100).offset(y: 124)
            HStack(spacing: 8) {
                stat("\(shotFriends)/\(total)", "撮った")
                stat("\(waiting)", "まだ ・ つつける")
                stat("9:00", "ひらく")
            }.frame(width: cardW - 36).offset(x: 18, y: 236)
            if input.requestCount > 0 {
                Button { Haptics.play(.sel); actions.openRequests() } label: {
                    HStack(spacing: 8) {
                        HStack(spacing: -8) {
                            ForEach(Array(input.requestFaces.prefix(3).enumerated()), id: \.offset) { i, f in
                                Text(f.initial).font(LF.inter(800, 10)).foregroundStyle(.white).frame(width: 24, height: 24).background(f.color, in: Circle()).overlay(Circle().strokeBorder(Color(hex: "1C1C1F"), lineWidth: 2)).zIndex(Double(3 - i))
                            }
                        }
                        Text("友だち申請 \(input.requestCount)件").font(LF.inter(800, 13)).foregroundStyle(HV.ink)
                        Spacer()
                        Text("確認 ›").font(LF.inter(800, 12)).foregroundStyle(HV.ink)
                    }
                    .padding(.horizontal, 12).frame(width: cardW - 36, height: 44).background(HV.lime, in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(HVPress(scale: 0.98)).offset(x: 18, y: 316)
            }
        }
    }

    private func stat(_ big: String, _ small: String) -> some View {
        VStack(spacing: 3) {
            Text(big).font(LF.inter(900, 20)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
            Text(small).font(LF.inter(600, 10)).foregroundStyle(.white.opacity(0.5)).lineLimit(1).minimumScaleFactor(0.6)
        }.frame(maxWidth: .infinity).frame(height: 56).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// 64 の 丸 + 外に 3つに 分かれた 輪(撮った こま)
    private func story(_ fr: HomeV64Friend) -> some View {
        Button { Haptics.play(.sel); actions.openChat(fr.id, fr.name) } label: {
            VStack(spacing: 6) {
                ZStack {
                    ForEach(0..<3, id: \.self) { k in
                        Circle().trim(from: 0.012, to: 0.32).stroke(k < fr.shots ? HV.lime : Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90 + Double(k) * 120)).frame(width: 66, height: 66)
                    }
                    ZStack {
                        Circle().fill(fr.color)
                        if let img = fr.image { Image(uiImage: img).resizable().scaledToFill().clipShape(Circle()) }
                        else { Text(String(fr.name.prefix(1))).font(LF.inter(800, 18)).foregroundStyle(.white) }
                    }.frame(width: 54, height: 54).saturation(fr.shots > 0 ? 1 : 0.2)
                    if fr.shots == 0 {
                        Image(systemName: "hand.point.up.left.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 22, height: 22).background(Color(hex: "2A2A2D"), in: Circle()).overlay(Circle().strokeBorder(.black, lineWidth: 2))
                            .offset(x: 23, y: 23).onTapGesture { Haptics.play(.heart); actions.poke(fr.id) }
                    }
                }.frame(width: 68, height: 68)
                Text(fr.name).font(LF.inter(700, 10.5)).foregroundStyle(Color(hex: "C9C9CF")).lineLimit(1).frame(width: 68)
            }
        }.buttonStyle(HVPress(scale: 0.94))
    }
}

// MARK: - 2 Trip

struct HVTripPage: View {
    let input: HomeV64Input
    let cardW: CGFloat
    let actions: HomeV64Actions

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let trip = input.trip {
                ZStack {
                    Color(hex: "1A1614")
                    if let c = trip.cover { Image(uiImage: c).resizable().scaledToFill() }
                    LinearGradient(stops: [.init(color: .black.opacity(0.4), location: 0), .init(color: .black.opacity(0.1), location: 0.3), .init(color: .black.opacity(0.6), location: 0.65), .init(color: .black.opacity(0.9), location: 1)], startPoint: .top, endPoint: .bottom)
                }.frame(width: cardW, height: 508).clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            } else { HVPageBackdrop(photo: input.tripSamples[safe: 1] ?? input.backdrop.first) }
            if let trip = input.trip {
                tripActive(trip)
            } else {
                // 写真が 3枚 重なった 絵
                let imgs = input.tripSamples
                ZStack {
                    stackedPhoto(imgs[safe: 0]).frame(width: 118, height: 150).overlay(Color.black.opacity(0.25)).rotationEffect(.degrees(-8)).offset(x: -46, y: 10)
                    stackedPhoto(imgs[safe: 2]).frame(width: 118, height: 150).overlay(Color.black.opacity(0.25)).rotationEffect(.degrees(8)).offset(x: 46, y: 10)
                    stackedPhoto(imgs[safe: 1]).frame(width: 118, height: 150).offset(y: -2)
                }
                .frame(width: cardW, height: 200).offset(y: 25)
                Text("02 / 03 ・ TRIP").font(LF.mono(9)).tracking(1.8).foregroundStyle(Color(hex: "6C6C73")).fixedSize().offset(x: 24, y: 252)
                Text("Take a trip,").font(LF.serif(40)).foregroundStyle(.white).frame(height: 40, alignment: .leading).fixedSize().offset(x: 24, y: 273)
                Text("together.").font(LF.serif(40, italic: true)).foregroundStyle(HV.lime).frame(height: 40, alignment: .leading).fixedSize().offset(x: 24, y: 313)
                Text("旅行 ・ 合宿 ・ イベント。1日 23枚を、みんなで。").font(LF.inter(500, 12.5)).foregroundStyle(Color(hex: "8C8C93")).fixedSize().offset(x: 24, y: 366)
                HStack(spacing: 8) {
                    Button { Haptics.play(.click); actions.openTrip() } label: {
                        HStack { Text("New trip").font(LF.inter(800, 17)).foregroundStyle(HV.ink); Spacer()
                            Image(systemName: "plus").font(.system(size: 17, weight: .bold)).foregroundStyle(.white).frame(width: 42, height: 42).background(HV.ink, in: Circle()) }
                            .padding(.leading, 22).padding(.trailing, 7).frame(width: 270, height: 56).background(Color(hex: "F4F1EA"), in: Capsule())
                    }.buttonStyle(HVPress(scale: 0.97))
                    Button { Haptics.play(.sel); actions.scanQR() } label: {
                        Image(systemName: "viewfinder").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 56, height: 56).background(Color.white.opacity(0.10), in: Circle())
                    }.buttonStyle(HVPress(scale: 0.94)).accessibilityLabel("QR を よむ")
                }.offset(x: 18, y: 386)
            }
        }
        .frame(width: cardW, height: 508, alignment: .topLeading)
    }

    private func stackedPhoto(_ img: UIImage?) -> some View {
        ZStack {
            Rectangle().fill(Color(hex: "3A3A3C"))
            if let img { Image(uiImage: img).resizable().scaledToFill() }
        }
        .clipShape(RoundedRectangle(cornerRadius: 3)).shadow(color: .black.opacity(0.9), radius: 15, y: 18)
    }

    @ViewBuilder
    private func tripActive(_ trip: HomeV64TripInfo) -> some View {
        let shots = trip.frames.filter { $0 != nil }.count
        return ZStack(alignment: .topLeading) {
            Color.clear.frame(width: cardW, height: 508)
            Text("TRIP ・ \(trip.dayText)").font(LF.mono(11)).tracking(2.2).foregroundStyle(.white.opacity(0.85)).offset(x: 24, y: 30)
            HStack(spacing: 8) {
                tripRoundButton("qrcode") { actions.openTripHome(trip.id ?? UUID()) }
                tripRoundButton("ellipsis") { actions.openTripHome(trip.id ?? UUID()) }
            }.offset(x: cardW - 24 - 88 - 8, y: 20)
            Text(trip.name).font(LF.serif(60)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.5).frame(width: cardW - 48, alignment: .leading).offset(x: 24, y: 93)
            Text(trip.sub).font(LF.mono(13)).foregroundStyle(.white.opacity(0.7)).offset(x: 24, y: 170)
            ZStack { Circle().fill(Color(hex: "0A0A0B")).overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 2)); Text(String(format: "%02d", shots)).font(LF.mono(26)).fontWeight(.bold).foregroundStyle(.white) }.frame(width: 62, height: 62).offset(x: 14, y: 213)
            Text("SHOTS TODAY").font(LF.mono(10.5)).tracking(2).foregroundStyle(.white.opacity(0.5)).offset(x: 98, y: 214)
            HStack(alignment: .firstTextBaseline, spacing: 3) { Text("\(shots)").font(LF.serif(36, italic: true)).foregroundStyle(.white); Text("/23").font(LF.serif(20, italic: true)).foregroundStyle(.white.opacity(0.4)) }.offset(x: 98, y: 224)
            HStack(spacing: -7) { ForEach(Array(trip.members.prefix(4).enumerated()), id: \.offset) { i, m in
                ZStack { if let im = m.image { Image(uiImage: im).resizable().scaledToFill() } else { m.color; Text(m.initial).font(LF.inter(800, 11)).foregroundStyle(.white) } }.frame(width: 24, height: 24).clipShape(Circle()).overlay(Circle().strokeBorder(.black, lineWidth: 1.5)) } }.offset(x: 98, y: 266)
            HVTripFilm(trip: trip, height: 44).frame(width: cardW - 24).offset(x: 12, y: 283)
            Text("あした 9:00、みんなで 現像").font(LF.mono(11.5)).foregroundStyle(.white.opacity(0.6)).offset(x: 22, y: 352)
        }.frame(width: cardW, height: 508, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            HStack(spacing: 8) {
                Button { Haptics.play(.shutter); actions.shoot() } label: {
                    HStack(spacing: 10) { Image(systemName: "camera").font(.system(size: 19, weight: .semibold)); Text("Shoot for trip").font(LF.inter(800, 18)) }.foregroundStyle(HV.ink).frame(width: 270, height: 56).background(Color(hex: "F4F1EA"), in: Capsule())
                }.buttonStyle(HVPress(scale: 0.97))
                Button { Haptics.play(.sel); if let id = trip.id { actions.openTripHome(id) } } label: {
                    Image(systemName: "bubble.left").font(.system(size: 21, weight: .semibold)).foregroundStyle(.white).frame(width: 56, height: 56).background(Color.black.opacity(0.4), in: Circle()).background(.ultraThinMaterial, in: Circle())
                        .overlay(alignment: .topTrailing) { if trip.unread > 0 { Text("\(trip.unread)").font(LF.inter(800, 11)).foregroundStyle(.white).frame(width: 20, height: 20).background(Color(hex: "E02B2B"), in: Circle()).offset(x: 6, y: -6) } }
                }.buttonStyle(HVPress(scale: 0.94))
            }.offset(x: 18, y: 386)
        }
    }

    private func tripRoundButton(_ icon: String, _ a: @escaping () -> Void) -> some View {
        Button { Haptics.play(.tick); a() } label: { Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white).frame(width: 40, height: 40).background(.white.opacity(0.14), in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1)) }.buttonStyle(HVPress(scale: 0.92))
    }
}

// MARK: - 3 Mondo

struct HVMondoPage: View {
    let input: HomeV64Input
    let cardW: CGFloat
    let actions: HomeV64Actions

    var body: some View {
        let locked = input.locked
        ZStack(alignment: .topLeading) {
            ZStack {
                Color(hex: "030805")
                RadialGradient(colors: [Color(red: 0.1, green: 0.4, blue: 0.2).opacity(0.5), .clear], center: UnitPoint(x: 0.85, y: 0.62), startRadius: 0, endRadius: 220)
            }
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1))
            .shadow(color: .black.opacity(0.6), radius: 30, y: 30)
            HVGlobe().frame(width: 310, height: 310).scaleEffect(114 / 124).position(x: cardW - 113, y: 274)
            HVPageHeader(page: .mondo, number: 3, status: locked ? "LOCKED" : "TOP 3", cardW: cardW, iconColor: .white)
            HVPageTitle(text: "Mondo").offset(x: 22, y: 72)
            Text("the world, yesterday.").font(LF.serif(21, italic: true)).foregroundStyle(HV.lime.opacity(0.85)).fixedSize().offset(x: 22, y: 126)
            ForEach(0..<3, id: \.self) { i in
                let tag = input.mondo.tags[safe: i] ?? ""
                HStack(spacing: 0) {
                    Text(String(format: "%02d", i + 1)).font(LF.serif(26)).foregroundStyle(i == 0 ? HV.lime : .white.opacity(0.55)).frame(width: 46, alignment: .leading)
                    Text(tag).font(LF.inter(800, 15.5)).foregroundStyle(.white).blur(radius: locked ? 6 : 0)
                    Spacer()
                    HVBars(level: [4, 3, 2][i]).padding(.trailing, 10)
                }
                .padding(.leading, 12).frame(width: 182, height: 43)
                .background((i == 0 ? HV.lime.opacity(0.14) : Color.white.opacity(0.06)), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(i == 0 ? HV.lime.opacity(0.4) : .white.opacity(0.1), lineWidth: 1))
                .offset(x: 22, y: 174 + CGFloat(i) * 52)
            }
            if locked { Image(systemName: "lock.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(.white).frame(width: 34, height: 34).background(Color.black.opacity(0.6), in: Circle()).offset(x: 150, y: 220) }
            HStack(spacing: 8) {
                Circle().fill(HV.lime).frame(width: 7, height: 7)
                Text("\(input.mondo.nowText) ・ \(input.mondo.city)").font(LF.mono(10.5)).tracking(1.0).foregroundStyle(.white).fixedSize()
            }
            .padding(.horizontal, 14).frame(height: 30)
            .background(Color.black.opacity(0.4), in: Capsule()).overlay(Capsule().strokeBorder(HV.lime.opacity(0.35), lineWidth: 1))
            .offset(x: 22, y: 337)
            HVCTA(title: locked ? "Shoot first" : "Explore", locked: locked, width: 334) { locked ? actions.shoot() : actions.openMondo() }.offset(x: 18, y: 386)
        }
        .frame(width: cardW, height: 508, alignment: .topLeading)
    }
}

struct HVBars: View {
    let level: Int
    var body: some View {
        HStack(alignment: .bottom, spacing: 2.5) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5).fill(i < level ? HV.lime : HV.lime.opacity(0.2)).frame(width: 4, height: CGFloat(6 + i * 4))
            }
        }
    }
}

/// 点の 地球(本物の 海岸線の 点 = `MondoGeo.land`)。見えて いない ときは 止める。
struct HVGlobe: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: reduceMotion)) { ctx in
            let rot = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate * 0.0016 * 60 * 0.5
            Canvas { c, size in
                let R: CGFloat = 124, cx = size.width / 2, cy = size.height / 2, tilt = 0.38
                // 大気
                c.fill(Path(ellipseIn: CGRect(x: cx - R * 1.18, y: cy - R * 1.18, width: R * 2.36, height: R * 2.36)),
                       with: .radialGradient(Gradient(colors: [Color(red: 80 / 255, green: 220 / 255, blue: 120 / 255).opacity(0.42), .clear]), center: CGPoint(x: cx, y: cy), startRadius: R * 0.92, endRadius: R * 1.18))
                c.fill(Path(ellipseIn: CGRect(x: cx - R, y: cy - R, width: R * 2, height: R * 2)),
                       with: .radialGradient(Gradient(colors: [Color(hex: "13301F"), Color(hex: "050A07")]), center: CGPoint(x: cx - R * 0.35, y: cy - R * 0.4), startRadius: R * 0.1, endRadius: R))
                c.stroke(Path(ellipseIn: CGRect(x: cx - R, y: cy - R, width: R * 2, height: R * 2)), with: .color(Color(red: 126 / 255, green: 224 / 255, blue: 143 / 255).opacity(0.45)), lineWidth: 1)
                let sun = 0.2
                for p in MondoGeo.land {
                    let lat = p.lat * .pi / 180, lo = p.lon * .pi / 180 + rot
                    let X = cos(lat) * sin(lo), Y = sin(lat), Z = cos(lat) * cos(lo)
                    let Y2 = Y * cos(tilt) - Z * sin(tilt), Z2 = Y * sin(tilt) + Z * cos(tilt)
                    if Z2 < 0 { continue }
                    let day = cos(lo - sun) * cos(lat), e = 0.35 + Z2 * 0.65
                    let sx = cx + X * R, sy = cy - Y2 * R
                    c.fill(Path(CGRect(x: sx - 1.35, y: sy - 1.35, width: 2.7, height: 2.7)), with: .color(Color(red: 245 / 255, green: 243 / 255, blue: 236 / 255).opacity(day > 0 ? (0.35 + day * 0.6) * e : 0.13 * e)))
                }
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

// MARK: - ページャ(横スライド)

struct HVPager: View {
    let pages: [AnyView]
    @Binding var page: Int
    let width: CGFloat
    /// ページの 中身の はば(ふだんは width と 同じ。# の ページ だけ 画面の はばまで はみ出す)
    var contentWidth: CGFloat? = nil
    var onChange: (Int) -> Void = { _ in }
    var onDrag: (CGFloat) -> Void = { _ in }
    @State private var drag: CGFloat = 0
    @State private var settling = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let pos = CGFloat(page) - drag / width            // いまの 位置(ページ数)
        ZStack {
            // 近くの ページ(いまの ±1)だけ 作る。遠い ページの 動き(地球・粒子)は 止まる
            ForEach(pages.indices.filter { abs($0 - page) <= 1 }, id: \.self) { i in
                let d = CGFloat(i) - pos
                let a = min(1, abs(d))
                pages[i]
                    .frame(width: contentWidth ?? width)
                    .offset(x: d * width)
                    .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(-d) * 14), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                    .scaleEffect(reduceMotion ? 1 : 1 - 0.08 * a)
                    .opacity(1 - 0.45 * Double(a))
                    .opacity(i == page || drag != 0 || settling ? (abs(d) < 1.2 ? 1 : 0) : 0)
                    .allowsHitTesting(i == page && drag == 0)
                    .accessibilityHidden(i != page)
            }
        }
        .onChange(of: page) { _, _ in settling = true; DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { settling = false } }
        .frame(width: width, height: 508)
        .mask(Rectangle().frame(width: width, height: 700))   // 左右の ページは カードの 外へ はみ出さない
        .contentShape(Rectangle())
        .gesture(HorizontalPanV88(
            onChanged: { dx in
                var dx = dx
                if (page == 0 && dx > 0) || (page == pages.count - 1 && dx < 0) { dx *= 0.35 }   // 端は ゴムのように 重く
                drag = dx
                onDrag(dx)
            },
            onEnded: { dx, predicted in
                let projected = dx + (predicted - dx) * 0.5
                var next = Int((CGFloat(page) - projected / width).rounded())
                next = max(page - 1, min(page + 1, next))                 // 1回で 動けるのは ±1ページ
                next = max(0, min(pages.count - 1, next))
                if next == page && abs(dx) > 20 && (page == 0 || page == pages.count - 1) { Haptics.play(.soft) }
                let changed = next != page
                settling = true
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { page = next; drag = 0; onDrag(0) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { settling = false }
                if changed { onChange(next) }
            }))
    }
}

// MARK: - 「消灯まで」を おした パネル(H10 / M13)

/// 1けた の オドメーター(0〜9 を たてに ならべて、値の 位置へ ころがす)
struct OdometerDigit: View {
    let value: Int
    let size: CGFloat
    var color: Color = .white
    var trackingK: CGFloat = -0.05

    var body: some View {
        let h = size * 1.12
        VStack(spacing: 0) {
            ForEach(0..<10, id: \.self) { n in
                Text("\(n)").font(LF.inter(900, size)).monospacedDigit().foregroundStyle(color).frame(height: h)
            }
        }
        .offset(y: -CGFloat(value) * h)
        .frame(width: size * 0.62, height: h, alignment: .top)
        .clipped()
        .mask(LinearGradient(stops: [.init(color: .black.opacity(0.0), location: 0), .init(color: .black, location: 0.22), .init(color: .black, location: 0.78), .init(color: .black.opacity(0.0), location: 1)], startPoint: .top, endPoint: .bottom))
    }
}

/// 上から おりてくる 黒い パネル。LIVE ・ 時計 ・ 消灯まで ・ ひらくまで ・ 24時間の 線 ・ のこりこま + shoot。(v93:ライム + 動く 数字)
struct HVLivePanel: View {
    let input: HomeV64Input
    let onClose: () -> Void
    let onShoot: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var digits = [0, 0, 0, 0, 0, 0]      // 時 十 / 一 ・ 分 十 / 一 ・ 秒 十 / 一
    @State private var bigIn = false
    @State private var barP: CGFloat = 0
    @State private var opened = false
    @State private var dotPulse = false
    @State private var secPop = false
    @State private var sweep: CGFloat = -1
    @State private var tick = 0
    @State private var lastMinute: Int?
    @State private var clockText = ""
    @State private var toOpenText = ""
    @State private var secOfDayNow = 0
    @State private var wave = false

    private let lime = Color(hex: "C8F25A")

    private func clock() -> Date {
        input.debugClock ?? Date(timeIntervalSinceReferenceDate: Date().timeIntervalSinceReferenceDate + (input.now.timeIntervalSinceReferenceDate - Date().timeIntervalSinceReferenceDate))
    }
    private func snapshot() -> (sec: Int, h: Int, m: Int, s: Int, c: DateComponents) {
        let c = Calendar.current.dateComponents([.hour, .minute, .second], from: clock())
        let sec = (c.hour ?? 0) * 3600 + (c.minute ?? 0) * 60 + (c.second ?? 0)
        let left = max(0, 86400 - sec)
        return (sec, left / 3600, (left % 3600) / 60, left % 60, c)
    }

    var body: some View {
        let snap = snapshot()
        let frac = min(1, Double(secOfDayNow == 0 ? snap.sec : secOfDayNow) / Double(33 * 3600))
        let toOpen = max(0, 86400 + 9 * 3600 - (secOfDayNow == 0 ? snap.sec : secOfDayNow))
        let W: CGFloat = 330
        return ZStack(alignment: .top) {
            Color.black.opacity(0.18).ignoresSafeArea().onTapGesture { Haptics.play(.soft); onClose() }
            ZStack(alignment: .topLeading) {
                HStack(spacing: 6) {
                    ZStack { Circle().fill(lime.opacity(dotPulse ? 0 : 0.5)).frame(width: dotPulse ? 14 : 7, height: dotPulse ? 14 : 7); Circle().fill(lime).frame(width: 7, height: 7) }.frame(width: 14, height: 14)
                    Text("LIVE").font(LF.mono(11)).tracking(2.2).foregroundStyle(lime)
                }
                .padding(.horizontal, 10).frame(height: 22).background(lime.opacity(0.12), in: Capsule()).offset(x: 18, y: 19)
                Text(clockText).font(LF.mono(12)).foregroundStyle(Color(hex: "5A5A5F")).offset(x: 104, y: 22)
                Button { Haptics.play(.soft); onClose() } label: { Image(systemName: "chevron.up").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.7)).frame(width: 30, height: 30).background(Color(hex: "1C1C1E"), in: Circle()) }.buttonStyle(.plain).offset(x: 318, y: 15)
                Text("消灯まで").font(LF.inter(600, 13)).foregroundStyle(Color(hex: "8E8E93")).offset(x: 18, y: 56)
                // 大きな 時間(ころがる 数字)
                HStack(alignment: .bottom, spacing: 0) {
                    HStack(spacing: 0) { OdometerDigit(value: digits[0], size: 62); OdometerDigit(value: digits[1], size: 62) }
                    VStack(spacing: 12) { Circle().frame(width: 8, height: 8); Circle().frame(width: 8, height: 8) }.foregroundStyle(Color(hex: "5A5A5F")).opacity(snap.s % 2 == 0 ? 0.85 : 0.22).padding(.horizontal, 4).padding(.bottom, 24)
                    HStack(spacing: 0) { OdometerDigit(value: digits[2], size: 62); OdometerDigit(value: digits[3], size: 62) }
                    HStack(spacing: 0) { OdometerDigit(value: digits[4], size: 24, color: secPop ? .white : lime); OdometerDigit(value: digits[5], size: 24, color: secPop ? .white : lime) }
                        .scaleEffect(secPop ? 1.22 : 1, anchor: .bottomLeading).padding(.leading, 6).padding(.bottom, 12)
                }
                .overlay { GeometryReader { g in LinearGradient(colors: [.clear, lime.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing).frame(width: g.size.width * 0.5).offset(x: g.size.width * sweep).blendMode(.plusLighter).allowsHitTesting(false) }.clipped() }
                .offset(x: 18, y: bigIn || reduceMotion ? 78 : 92).opacity(bigIn || reduceMotion ? 1 : 0)
                HStack(spacing: 8) {
                    Text("ひらくまで").font(LF.inter(600, 13)).foregroundStyle(Color(hex: "8E8E93"))
                    Text("\(toOpen / 3600)h \(String(format: "%02d", (toOpen % 3600) / 60))m").font(LF.inter(700, 14)).foregroundStyle(.white.opacity(0.9)).contentTransition(.numericText(countsDown: true))
                }.offset(x: 18, y: 154)
                // バー
                ZStack(alignment: .leading) {
                    Capsule().fill(LinearGradient(colors: [Color(hex: "171B0C"), Color(hex: "27310F")], startPoint: .leading, endPoint: .trailing)).frame(width: W * 24 / 33, height: 8).frame(width: W, alignment: .leading)
                    Capsule().fill(Color.white.opacity(0.06)).frame(width: W, height: 8).mask(Rectangle().frame(width: W - W * 24 / 33).frame(width: W, alignment: .trailing))
                    Capsule().fill(LinearGradient(colors: [lime.opacity(0.18), lime.opacity(0.85)], startPoint: .leading, endPoint: .trailing)).frame(width: max(8, W * frac * barP), height: 8).shadow(color: lime.opacity(0.32), radius: 7)
                    if !reduceMotion {
                        TimelineView(.animation) { ctx in
                            let u = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4
                            LinearGradient(colors: [.clear, .white.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing).frame(width: W * 0.4, height: 8).offset(x: -W * 0.4 + (W * 1.4) * u)
                        }.frame(width: W, height: 8).clipShape(Capsule()).allowsHitTesting(false)
                    }
                    Rectangle().fill(Color(hex: "5A5A5F")).frame(width: 2, height: 14).offset(x: W * 9 / 33)
                    Rectangle().fill(Color(hex: "E0242C")).frame(width: 2, height: 14).offset(x: W * 24 / 33)
                    Circle().fill(.white).frame(width: 18, height: 18).overlay(Circle().strokeBorder(lime.opacity(0.22), lineWidth: 4)).shadow(color: lime.opacity(0.7), radius: 6)
                        .scaleEffect(dotPulse ? 1.35 : 1).offset(x: W * frac * barP - 9)
                }.frame(width: W, height: 20).offset(x: 18, y: 184)
                Group {
                    Text("0:00").foregroundStyle(Color(hex: "5A5A5F")).offset(x: 0)
                    Text("9:00").foregroundStyle(Color(hex: "5A5A5F")).offset(x: W * 9 / 33 - 12)
                    Text("24:00").foregroundStyle(Color(hex: "E0242C")).offset(x: W * 24 / 33 - 14)
                    Text("9:00 OPEN").foregroundStyle(lime).frame(width: W, alignment: .trailing)
                }.font(LF.mono(10)).frame(width: W, alignment: .leading).offset(x: 18, y: 208)
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.12), lineWidth: 1).frame(width: 40, height: 52)
                        .overlay(Image(systemName: i < input.shotsUsed ? "checkmark" : "plus").font(.system(size: 13, weight: .semibold)).foregroundStyle(i < input.shotsUsed ? lime : Color(hex: "5A5A5F")))
                        .offset(x: 18 + CGFloat(i) * 46, y: 243)
                }
                Button { Haptics.play(.click); onClose(); onShoot() } label: {
                    HStack(spacing: 12) {
                        HVCameraGlyph(width: 26, line: 2, color: HV.ink, showsFlash: false)
                        VStack(alignment: .leading, spacing: 2) { Text("shoot").font(LF.inter(800, 19)).foregroundStyle(HV.ink); Text("\(input.remaining) LEFT").font(LF.mono(9)).tracking(1.6).foregroundStyle(Color(hex: "8E8E93")) }
                    }.frame(width: 186, height: 54).background(Color.white, in: Capsule())
                }.buttonStyle(HVPress(scale: 0.97)).offset(x: 162, y: 242)
            }
            .frame(width: 366, height: 302, alignment: .topLeading)
            .background(Color(hex: "050505"), in: RoundedRectangle(cornerRadius: 40, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
            .padding(.top, 98)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
        .task { await run() }
    }

    private func targetDigits(_ h: Int, _ m: Int, _ s: Int) -> [Int] { [h / 10, h % 10, m / 10, m % 10, s / 10, s % 10] }
    private static let df: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f }()

    /// ひらく:数字が 0 から ころがる(0.18〜)→ そのあと 毎秒 更新(パネルが とじると タスクも 止まる)
    @MainActor private func run() async {
        let first = snapshot()
        clockText = Self.df.string(from: clock()); secOfDayNow = first.sec; lastMinute = first.m
        if reduceMotion {
            digits = targetDigits(first.h, first.m, first.s); bigIn = true; barP = 1; opened = true
        } else {
            let target = targetDigits(first.h, first.m, first.s)
            withAnimation(.timingCurve(0.3, 1.3, 0.5, 1, duration: 0.52).delay(0.16)) { bigIn = true }
            let delays = [0.18, 0.26, 0.36, 0.44, 0.52, 0.58]
            for (i, d) in delays.enumerated() { withAnimation(.timingCurve(0.16, 1.2, 0.3, 1, duration: 1.25).delay(d)) { digits[i] = target[i] } }
            withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 1.1).delay(0.28)) { barP = 1 }
            for t in [0.52, 0.64, 0.76, 0.88] { Task { try? await Task.sleep(for: .seconds(t)); Haptics.play(.tick) } }
            Task { try? await Task.sleep(for: .seconds(1.0)); Haptics.play(.sel) }
            try? await Task.sleep(for: .seconds(1.8))
            opened = true
        }
        Haptics.play(.pop)
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(1000 - Int(Date().timeIntervalSince1970 * 1000) % 1000 + 5))
            if Task.isCancelled { return }
            let s = snapshot()
            clockText = Self.df.string(from: clock()); secOfDayNow = s.sec
            let target = targetDigits(s.h, s.m, s.s)
            if reduceMotion { digits = target } else {
                withAnimation(.timingCurve(0.2, 1.35, 0.35, 1, duration: 0.7)) { digits = target }
                secPop = true
                withAnimation(.timingCurve(0.2, 1.35, 0.35, 1, duration: 0.52)) { secPop = false }
                dotPulse = true; withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) { dotPulse = false }
                if s.s == 0 { Haptics.play(.tick) }
                if let last = lastMinute, last != s.m, opened {
                    Haptics.play(.sel); sweep = -0.6
                    withAnimation(.easeInOut(duration: 0.9)) { sweep = 1.2 }
                }
            }
            lastMinute = s.m
        }
    }
}

/// 横にだけ 反応する パン(たてに 動き出したら すぐ 失敗 → たての ScrollView が そのまま 動く)。v88 D
struct HorizontalPanV88: UIGestureRecognizerRepresentable {
    var onChanged: (CGFloat) -> Void
    var onEnded: (CGFloat, CGFloat) -> Void

    final class Pan: UIPanGestureRecognizer {
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesMoved(touches, with: event)
            if state == .possible {
                let t = translation(in: view)
                if abs(t.y) > 8 && abs(t.y) > abs(t.x) * 0.5 { state = .failed }
            }
        }
    }
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }
    func makeUIGestureRecognizer(context: Context) -> Pan {
        let p = Pan(); p.maximumNumberOfTouches = 1; p.delegate = context.coordinator; return p
    }
    func handleUIGestureRecognizerAction(_ r: Pan, context: Context) {
        let t = r.translation(in: r.view).x
        switch r.state {
        case .changed: onChanged(t)
        case .ended: onEnded(t, t + r.velocity(in: r.view).x * 0.2)
        case .cancelled, .failed: onEnded(0, 0)
        default: break
        }
    }
}
