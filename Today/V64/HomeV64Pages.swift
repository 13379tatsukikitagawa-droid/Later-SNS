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
}

struct HomeV64Thumb: Identifiable {
    let id: String
    var image: UIImage?
    var time: String
    var tag: String? = nil
    var tagColor: Color = .white
}

struct HomeV64TripInfo {
    var name: String
    var members: [HomeV64Face]
    /// 23こま:撮った 人の 番号(撮って いない = nil)
    var frames: [Int?]
    var cover: UIImage? = nil
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

struct HVPageBackdrop: View {
    let photo: UIImage?
    var body: some View {
        ZStack {
            Color(hex: "0E0E0F")
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill().frame(width: 510, height: 700)
                    .blur(radius: 16).saturation(1.3).overlay(Color.black.opacity(0.6))
            }
            LinearGradient(stops: [.init(color: .black.opacity(0.25), location: 0), .init(color: .clear, location: 0.30), .init(color: .clear, location: 0.60), .init(color: .black.opacity(0.5), location: 1)], startPoint: .top, endPoint: .bottom)
            HVGrain().opacity(0.16).blendMode(.overlay)
        }
        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 30, y: 30)
    }
}

/// 上の 行:丸い アイコン(40pt)+ `0N / 04` + 右に 状態
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
            Text(String(format: "%02d / 04", number)).font(LF.mono(9)).tracking(1.62).foregroundStyle(Color(hex: "6C6C73")).fixedSize().offset(x: 72, y: 35.5)
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

    var body: some View {
        let shotFriends = input.friends.filter { $0.shots > 0 }.count
        ZStack(alignment: .topLeading) {
            HVPageBackdrop(photo: input.friends.first(where: { $0.image != nil })?.image ?? input.backdrop.first)
            HVPageHeader(page: .friends, number: 1, status: shotFriends > 0 ? "● \(shotFriends) shot today" : nil, cardW: cardW)
            HVPageTitle(text: "Friends").offset(x: 22, y: 72)
            if input.requestCount > 0 {
                Button { Haptics.play(.sel); actions.openFriends() } label: {
                    HStack(spacing: 0) {
                        HStack(spacing: -8) {
                            ForEach(Array(input.requestFaces.prefix(3).enumerated()), id: \.offset) { i, f in
                                Text(f.initial).font(LF.inter(800, 11)).foregroundStyle(.white)
                                    .frame(width: 28, height: 28).background(f.color, in: Circle())
                                    .overlay(Circle().strokeBorder(Color(hex: "1C1C1F"), lineWidth: 2)).zIndex(Double(3 - i))
                            }
                        }
                        Text("Requests").font(LF.serif(20)).foregroundStyle(.white).padding(.leading, 12)
                        Spacer()
                        Text("承認 ›").font(LF.mono(10)).tracking(0.8).foregroundStyle(HV.lime)
                    }
                    .padding(.horizontal, 8).frame(width: 326, height: 44)
                    .background(Color(hex: "1C1C1F"), in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(HV.lime.opacity(0.3), lineWidth: 1))
                }.buttonStyle(HVPress(scale: 0.98)).offset(x: 22, y: 125.8)
            }
            // 丸の 列(4列・先頭は Add)
            let rowY: CGFloat = 181.8
            ForEach(0..<4, id: \.self) { col in
                let x: CGFloat = 32 + CGFloat(col) * 80.5
                if col == 0 {
                    Button { Haptics.play(.sel); actions.addFriends() } label: {
                        VStack(spacing: 5) {
                            ZStack { Circle().fill(Color.black).offset(y: 3); Circle().fill(HV.lime); Circle().strokeBorder(.black, lineWidth: 2); Image(systemName: "plus").font(.system(size: 20, weight: .bold)).foregroundStyle(.black) }
                                .frame(width: 54, height: 54)
                            Text("Add").font(LF.inter(700, 10)).foregroundStyle(Color(hex: "C9C9CF"))
                        }.frame(width: 74.5)
                    }.buttonStyle(HVPress(scale: 0.94)).offset(x: x, y: rowY)
                } else if col - 1 < input.friends.count {
                    let fr = input.friends[col - 1]
                    Button { Haptics.play(.sel); actions.openFriends() } label: {
                        VStack(spacing: 5) {
                            ZStack {
                                Circle().stroke(Color(hex: "2A2A2C"), lineWidth: 3)
                                Circle().trim(from: 0, to: CGFloat(fr.shots) / 3).stroke(Color(hex: "3BD35A"), style: StrokeStyle(lineWidth: 3, lineCap: .butt)).rotationEffect(.degrees(-90))
                                ZStack {
                                    Circle().fill(fr.color)
                                    if let img = fr.image { Image(uiImage: img).resizable().scaledToFill().clipShape(Circle()) }
                                    else { Text(String(fr.name.prefix(1))).font(LF.inter(800, 16)).foregroundStyle(.white) }
                                }.frame(width: 48, height: 48).overlay(Circle().strokeBorder(Color(hex: "101010"), lineWidth: 2))
                            }.frame(width: 54, height: 54)
                            Text(fr.name).font(LF.inter(700, 10)).foregroundStyle(Color(hex: "C9C9CF")).lineLimit(1)
                        }.frame(width: 74.5)
                    }.buttonStyle(HVPress(scale: 0.94)).offset(x: x, y: rowY)
                }
            }
            // YESTERDAY の 並び(ロック中は ぼかし + 鍵)
            Text("YESTERDAY").font(LF.mono(8.5)).tracking(1.7).foregroundStyle(Color(hex: "6C6C73")).fixedSize().offset(x: 32, y: 266.8)
            ForEach(0..<4, id: \.self) { i in
                let x: CGFloat = 32 + CGFloat(i) * 80.5
                if i < max(input.yesterdayThumbs.count, input.locked ? 3 : 0) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1))
                        if i < input.yesterdayThumbs.count, let img = input.yesterdayThumbs[i].image {
                            Image(uiImage: img).resizable().scaledToFill().frame(width: 74.5, height: 58).clipped().blur(radius: input.locked ? 8 : 0).saturation(input.locked ? 0.5 : 1)
                        }
                    }
                    .frame(width: 74.5, height: 58).clipShape(RoundedRectangle(cornerRadius: 12)).offset(x: x, y: 285.8)
                }
            }
            if input.locked {
                Image(systemName: "lock.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 34, height: 34).background(Color.black.opacity(0.6), in: Circle()).offset(x: 173, y: 297.8)
            }
            HVCTA(title: "Open friends", width: 334) { actions.openFriends() }.offset(x: 18, y: 386)
        }
        .frame(width: cardW, height: 508, alignment: .topLeading)
    }
}

// MARK: - 2 Trip

struct HVTripPage: View {
    let input: HomeV64Input
    let cardW: CGFloat
    let actions: HomeV64Actions

    var body: some View {
        ZStack(alignment: .topLeading) {
            HVPageBackdrop(photo: input.trip?.cover ?? input.backdrop.first)
            if let trip = input.trip {
                tripActive(trip)
            } else {
                // 写真が 3枚 重なった 絵
                let imgs = input.tripSamples
                ZStack {
                    stackedPhoto(imgs[safe: 0]).frame(width: 118, height: 150).overlay(Color.black.opacity(0.25)).rotationEffect(.degrees(-8)).offset(x: -46, y: 10)
                    stackedPhoto(imgs[safe: 2]).frame(width: 118, height: 150).overlay(Color.black.opacity(0.25)).rotationEffect(.degrees(8)).offset(x: 46, y: 10)
                    stackedPhoto(imgs[safe: 1]).frame(width: 118, height: 150)
                }
                .frame(width: cardW, height: 200).offset(y: 25)
                Text("02 / 04 ・ TRIP").font(LF.mono(9)).tracking(1.8).foregroundStyle(Color(hex: "6C6C73")).fixedSize().offset(x: 24, y: 252)
                Text("Take a trip,").font(LF.serif(40)).foregroundStyle(.white).frame(height: 40, alignment: .leading).fixedSize().offset(x: 24, y: 273)
                Text("together.").font(LF.serif(40, italic: true)).foregroundStyle(HV.lime).frame(height: 40, alignment: .leading).fixedSize().offset(x: 24, y: 307)
                Text("旅行 ・ 合宿 ・ イベント。1日 23枚を、みんなで。").font(LF.inter(500, 12.5)).foregroundStyle(Color(hex: "8C8C93")).fixedSize().offset(x: 24, y: 361)
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
        HVPageHeader(page: .trip, number: 2, status: "● ACTIVE", cardW: cardW)
        HVPageTitle(text: trip.name).offset(x: 22, y: 72)
        // 23こま(撮った こまは 撮った 人の 色)
        let cols = 12
        ForEach(0..<trip.frames.count, id: \.self) { i in
            let who = trip.frames[i]
            RoundedRectangle(cornerRadius: 4).fill(who.flatMap { trip.members[safe: $0]?.color } ?? Color.white.opacity(0.12))
                .frame(width: 20, height: 20).offset(x: 24 + CGFloat(i % cols) * 24.5, y: 150 + CGFloat(i / cols) * 24.5)
        }
        HStack(spacing: -8) {
            ForEach(Array(trip.members.prefix(6).enumerated()), id: \.offset) { i, m in
                Text(m.initial).font(LF.inter(800, 12)).foregroundStyle(.white).frame(width: 34, height: 34).background(m.color, in: Circle())
                    .overlay(Circle().strokeBorder(Color(hex: "151517"), lineWidth: 2)).zIndex(Double(6 - i))
            }
        }.offset(x: 22, y: 220)
        Text("あした 9:00 に みんなで ひらく").font(LF.inter(500, 13)).foregroundStyle(Color(hex: "8C8C93")).fixedSize().offset(x: 22, y: 270)
        HStack(spacing: 8) {
            HVCTA(title: "Shoot", width: 190, bg: Color(hex: "F4F1EA")) { actions.shoot() }
            Button { Haptics.play(.sel); actions.openTrip() } label: {
                Text("Chat").font(LF.inter(800, 15)).foregroundStyle(.white).frame(width: 132, height: 56).background(Color.white.opacity(0.10), in: Capsule())
            }.buttonStyle(HVPress(scale: 0.97))
        }.offset(x: 18, y: 386)
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

// MARK: - 4 Yesterday

struct HVYesterdayPage: View {
    let input: HomeV64Input
    let cardW: CGFloat
    let actions: HomeV64Actions

    var body: some View {
        let locked = input.locked, firstDay = input.isFirstDay
        let thumbs = input.yesterdayThumbs
        ZStack(alignment: .topLeading) {
            HVPageBackdrop(photo: firstDay ? nil : (thumbs.first?.image ?? input.yesterdayPhoto))
            HVPageHeader(page: .yesterday, number: 4, status: firstDay ? "FROM TOMORROW" : (locked ? "LOCKED" : "\(max(1, thumbs.count)) OPENED"), cardW: cardW, iconColor: Color(hex: "C8A46A"))
            HVPageTitle(text: "Yesterday").offset(x: 22, y: 72)
            // チェキの 扇(3枚とも 128×170・−10° / 0° / +10°・横へ ±70・外側は 14pt 下)
            let times = ["18:42", "16:05", "21:13"]
            ForEach([0, 2, 1], id: \.self) { slot in
                let t = thumbs[safe: slot]
                let rot: Double = [-10, 0, 10][slot], dx: CGFloat = [-70, 0, 70][slot], dy: CGFloat = slot == 1 ? 0 : 14
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 4).fill(firstDay ? Color.clear : Color(hex: "F4F1EA"))
                    if firstDay {
                        RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                    } else {
                        ZStack { Rectangle().fill(Color(hex: "3A3A3C")); if let img = t?.image ?? input.yesterdayPhoto { Image(uiImage: img).resizable().scaledToFill() } }
                            .frame(width: 114, height: 137).clipped()
                            .blur(radius: locked ? 8 : 0).saturation(locked ? 0.4 : 1).offset(x: 7, y: 7)
                        Text(t?.time ?? times[slot]).font(LF.mono(9)).foregroundStyle(Color(hex: "FF9A3C")).fixedSize().offset(x: 92, y: 151)
                    }
                }
                .frame(width: 128, height: 170)
                .shadow(color: .black.opacity(firstDay ? 0 : 0.8), radius: 15, y: 16)
                .rotationEffect(.degrees(rot))
                .offset(x: (cardW - 128) / 2 + dx, y: 141.8 + dy)
            }
            if locked && !firstDay { Image(systemName: "lock.fill").font(.system(size: 17, weight: .bold)).foregroundStyle(.white).frame(width: 46, height: 46).background(Color.black, in: Circle()).offset(x: 162, y: 211.4) }
            if !firstDay {
                HStack(spacing: 8) {
                    chip("#夕焼け", bg: Color(hex: "9ED8FF"), fg: HV.ink); chip("#放課後", bg: Color(hex: "9B8CFF"), fg: .white); chip("#帰り道", bg: Color(hex: "EE5E9C"), fg: .white)
                }.frame(width: cardW).offset(y: 349)
            }
            HVCTA(title: firstDay ? "撮ると、あした ひらく" : (locked ? "Shoot first" : "Open"), locked: locked && !firstDay, width: 334) {
                if firstDay || locked { actions.shoot() } else { actions.openYesterday() }
            }.offset(x: 18, y: 386)
        }
        .frame(width: cardW, height: 508, alignment: .topLeading)
    }

    private func chip(_ t: String, bg: Color, fg: Color) -> some View {
        Text(t).font(LF.inter(900, 12)).foregroundStyle(fg).padding(.horizontal, 10).frame(height: 27).background(bg, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - ページャ(横スライド)

struct HVPager: View {
    let pages: [AnyView]
    @Binding var page: Int
    let width: CGFloat
    var onChange: (Int) -> Void = { _ in }
    @State private var drag: CGFloat = 0
    @State private var horizontal: Bool? = nil

    var body: some View {
        let pos = CGFloat(page) - drag / width            // いまの 位置(ページ数)
        ZStack {
            ForEach(pages.indices, id: \.self) { i in
                let d = CGFloat(i) - pos
                let a = min(1, abs(d))
                pages[i]
                    .frame(width: width)
                    .offset(x: d * width)
                    .rotation3DEffect(.degrees(Double(-d) * 14), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                    .scaleEffect(1 - 0.08 * a)
                    .opacity(1 - 0.45 * Double(a))
                    .opacity(abs(d) < 1.2 ? 1 : 0)
                    .allowsHitTesting(i == page && drag == 0)
                    .accessibilityHidden(i != page)
            }
        }
        .frame(width: width, height: 508)
        .mask(Rectangle().frame(width: width, height: 700))   // 左右の ページは カードの 外へ はみ出さない
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { v in
                    if horizontal == nil {
                        if abs(v.translation.width) > 8 && abs(v.translation.width) > 1.2 * abs(v.translation.height) { horizontal = true }
                        else if abs(v.translation.height) > 10 { horizontal = false }
                    }
                    guard horizontal == true else { return }
                    var dx = v.translation.width
                    if (page == 0 && dx > 0) || (page == pages.count - 1 && dx < 0) { dx *= 0.35 }   // 端は ゴムのように 重く
                    drag = dx
                }
                .onEnded { v in
                    defer { horizontal = nil }
                    guard horizontal == true else { drag = 0; return }
                    let projected = v.translation.width + (v.predictedEndTranslation.width - v.translation.width) * 0.5
                    var next = Int((CGFloat(page) - projected / width).rounded())
                    next = max(page - 1, min(page + 1, next))                 // 1回で 動けるのは ±1ページ
                    next = max(0, min(pages.count - 1, next))
                    if next == page && abs(v.translation.width) > 20 && (page == 0 || page == pages.count - 1) { Haptics.play(.soft) }
                    let changed = next != page
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { page = next; drag = 0 }
                    if changed { onChange(next) }
                }
        )
    }
}

// MARK: - 「消灯まで」を おした パネル(H10 / M13)

/// 上から おりてくる 黒い パネル。LIVE ・ 時計 ・ 消灯まで ・ ひらくまで ・ 24時間の 線 ・ のこりこま + shoot。
struct HVLivePanel: View {
    let input: HomeV64Input
    let onClose: () -> Void
    let onShoot: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let now = Date(timeIntervalSinceReferenceDate: ctx.date.timeIntervalSinceReferenceDate + (input.now.timeIntervalSinceReferenceDate - Date().timeIntervalSinceReferenceDate))
            panel(now: input.debugClock ?? now)
        }
    }

    private func panel(now: Date) -> some View {
        let cal = Calendar.current
        let c = cal.dateComponents([.hour, .minute, .second], from: now)
        let secOfDay = (c.hour ?? 0) * 3600 + (c.minute ?? 0) * 60 + (c.second ?? 0)
        let toLights = max(0, 86400 - secOfDay)
        let toOpen = max(0, 86400 + 9 * 3600 - secOfDay)
        let frac = min(1, Double(secOfDay) / Double(33 * 3600))
        let hh = toLights / 3600, mm = (toLights % 3600) / 60, ss = toLights % 60
        return ZStack(alignment: .top) {
            Rectangle().fill(.ultraThinMaterial).overlay(Color.black.opacity(0.25)).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "3BD35A")).frame(width: 7, height: 7)
                        Text("LIVE").font(LF.mono(11)).tracking(2.2).foregroundStyle(Color(hex: "4CD964"))
                    }
                    .padding(.horizontal, 10).frame(height: 22).background(Color(hex: "0F2A16"), in: Capsule())
                    Text(String(format: "%02d:%02d:%02d", c.hour ?? 0, c.minute ?? 0, c.second ?? 0)).font(LF.mono(12)).foregroundStyle(Color(hex: "5A5A5F")).padding(.leading, 6)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "chevron.up").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                            .frame(width: 30, height: 30).background(Color(hex: "1C1C1E"), in: Circle())
                    }.buttonStyle(.plain)
                }
                Text("消灯まで").font(LF.inter(600, 13)).foregroundStyle(Color(hex: "8E8E93")).padding(.top, 12)
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text(String(format: "%02d", hh)).font(LF.inter(900, 64)).tracking(-2.5).foregroundStyle(.white)
                    VStack(spacing: 14) { Circle().fill(Color(hex: "5A5A5F")).frame(width: 9, height: 9); Circle().fill(Color(hex: "5A5A5F")).frame(width: 9, height: 9) }.padding(.horizontal, 6).offset(y: -12)
                    Text(String(format: "%02d", mm)).font(LF.inter(900, 64)).tracking(-2.5).foregroundStyle(.white)
                    Text(String(format: "%02d", ss)).font(LF.inter(900, 26)).foregroundStyle(Color(hex: "3BD35A")).padding(.leading, 6).contentTransition(.numericText())
                }
                .frame(height: 58, alignment: .bottom)
                HStack(spacing: 8) {
                    Text("ひらくまで").font(LF.inter(600, 13)).foregroundStyle(Color(hex: "8E8E93"))
                    Text("\(toOpen / 3600)h \(String(format: "%02d", (toOpen % 3600) / 60))m").font(LF.inter(700, 15)).foregroundStyle(.white.opacity(0.9))
                }.padding(.top, 8)
                // 24時間の 線(0:00 〜 あしたの 9:00)
                GeometryReader { g in
                    let w = g.size.width
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.06)).frame(height: 8)
                        Capsule().fill(LinearGradient(colors: [Color(hex: "1F8A3A"), Color(hex: "3BD35A")], startPoint: .leading, endPoint: .trailing)).frame(width: w * frac, height: 8).shadow(color: Color(hex: "3BD35A").opacity(0.5), radius: 8)
                        Rectangle().fill(Color(hex: "5A5A5F")).frame(width: 2, height: 14).offset(x: w * 9 / 33)
                        Rectangle().fill(Color(hex: "E0242C")).frame(width: 2, height: 14).offset(x: w * 24 / 33)
                        Circle().fill(.white).frame(width: 20, height: 20).shadow(color: .white.opacity(0.6), radius: 8).offset(x: w * frac - 10)
                    }.frame(height: 20)
                }.frame(height: 20).padding(.top, 8)
                ZStack(alignment: .leading) {
                    Text("0:00").font(LF.mono(10)).foregroundStyle(Color(hex: "5A5A5F"))
                    Text("9:00").font(LF.mono(10)).foregroundStyle(Color(hex: "5A5A5F")).offset(x: 330 * 9 / 33 - 12)
                    Text("24:00").font(LF.mono(10)).foregroundStyle(Color(hex: "E0242C")).offset(x: 330 * 24 / 33 - 15)
                    Text("9:00 OPEN").font(LF.mono(10)).foregroundStyle(Color(hex: "7EE08F")).frame(width: 330, alignment: .trailing)
                }.padding(.top, 4)
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.12), lineWidth: 1).frame(width: 40, height: 52)
                            .overlay(Image(systemName: i < input.shotsUsed ? "checkmark" : "plus").font(.system(size: 13, weight: .semibold)).foregroundStyle(i < input.shotsUsed ? Color(hex: "3BD35A") : Color(hex: "5A5A5F")))
                    }
                    Spacer(minLength: 6)
                    Button { Haptics.play(.click); onClose(); onShoot() } label: {
                        HStack(spacing: 12) {
                            HVCameraGlyph(width: 26, line: 2, color: HV.ink, showsFlash: false)
                            VStack(alignment: .leading, spacing: 2) { Text("shoot").font(LF.inter(800, 19)).foregroundStyle(HV.ink); Text("\(input.remaining) LEFT").font(LF.mono(9)).tracking(1.6).foregroundStyle(Color(hex: "8E8E93")) }
                        }.frame(width: 186, height: 54).background(Color.white, in: Capsule())
                    }.buttonStyle(HVPress(scale: 0.97))
                }.padding(.top, 16)
            }
            .padding(18).frame(width: 366)
            .background(Color(hex: "050505"), in: RoundedRectangle(cornerRadius: 40, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
            .padding(.top, 98)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
