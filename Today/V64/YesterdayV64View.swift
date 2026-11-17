import SwiftUI

// P06:Lattag yesterday(白い ページ + 大きな 写真の カード + 下の ガラスの タブ「Mondo / Friends」)。見本:Y01〜Y06。
// 下の タブは Mondo / Friends(Friends が 先)。撮る まえは 写真が ぼかしで「shoot today to open」。

struct YesterdayV64Input {
    struct Cell: Identifiable { let id: String; var photo: UIImage?; var name: String; var time: String?; var tag: String? }
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
    var cities: [(String, String)] {
        let list: [(String, String)] = [("SEOUL", "Asia/Seoul"), ("BANGKOK", "Asia/Bangkok"), ("PARIS", "Europe/Paris"), ("NEW YORK", "America/New_York"), ("SYDNEY", "Australia/Sydney")]
        return list.map { name, tz in
            let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = TimeZone(identifier: tz)
            return (name, f.string(from: now))
        }
    }
    var dateLabel = "NOV 15"
    var avatar: UIImage?
    var now = Date()
    var startTab = 0
    var startViewing: String? = nil
    var scrollToMe = false
    var locked: Bool { shotsUsed == 0 }
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
}

struct YesterdayV64View: View {
    var input: YesterdayV64Input
    var actions = YesterdayV64Actions()
    @State private var tab = 0   // 0 = Friends(先)・ 1 = Mondo
    @State private var seeded = false
    @State private var viewing: YesterdayV64Input.Cell?

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .topLeading) {
                Color.white
                ScrollViewReader { proxy in ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 182)
                        if tab == 0 { friendsTab(w: g.size.width) } else { mondoTab(w: g.size.width) }
                        Color.clear.frame(height: 160)
                    }
                    .animation(.timingCurve(0.3, 1.2, 0.4, 1, duration: 0.4), value: tab)
                }
                .onAppear { if input.scrollToMe { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { proxy.scrollTo("me", anchor: UnitPoint(x: 0.5, y: 0.1)) } } } }
                header
                tabBar.frame(width: g.size.width).offset(y: g.size.height - 96)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .ignoresSafeArea()
        .overlay { if let v = viewing { photoViewer(v).transition(.opacity) } }
        .onAppear { if !seeded { tab = input.startTab; seeded = true; if let id = input.startViewing { viewing = (input.cells + input.viewerOnly).first { $0.id == id } } } }
    }

    // MARK: ヘッダー(白)

    private var header: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(stops: [.init(color: .white, location: 0.78), .init(color: .white.opacity(0), location: 1)], startPoint: .top, endPoint: .bottom).frame(height: 170)
            Text(Brand.name).font(LF.inter(900, 44)).tracking(-2.86).foregroundStyle(HV.ink).frame(height: 44, alignment: .leading).offset(x: 18, y: 58)
            HStack(spacing: 0) {
                Button { Haptics.play(.sel); actions.close() } label: { Text("today").font(LF.serif(19, italic: true)).foregroundStyle(HV.gray).frame(height: 44) }.buttonStyle(.plain)
                Text("/").font(LF.inter(300, 19)).foregroundStyle(HV.gray.opacity(0.5)).padding(.horizontal, 6)
                Text("yesterday").font(LF.serif(19, italic: true)).foregroundStyle(HV.ink)
            }.offset(x: 150, y: 67)
            Button { Haptics.play(.sel); actions.openProfile() } label: {
                ZStack {
                    if let a = input.avatar { Image(uiImage: a).resizable().scaledToFill() } else { Circle().fill(RadialGradient(colors: [Color(hex: "B1EFBE"), Color(hex: "67DE7F"), Color(hex: "8E88B0")], center: UnitPoint(x: 0.4, y: 0.3), startRadius: 0, endRadius: 40)) }
                }.frame(width: 52, height: 52).clipShape(Circle()).overlay(Circle().strokeBorder(HV.ink, lineWidth: 3)).overlay(alignment: .topTrailing) { Circle().fill(Color(hex: "24A03C")).frame(width: 13, height: 13).overlay(Circle().strokeBorder(.white, lineWidth: 2)) }
            }.buttonStyle(.plain).offset(x: 320, y: 50)
            livePill.offset(x: 18, y: 114)
        }
    }

    private var livePill: some View {
        let cal = Calendar.current
        let open = cal.date(bySettingHour: 9, minute: 0, second: 0, of: cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: input.now)) ?? input.now) ?? input.now
        let s = max(0, Int(open.timeIntervalSince(input.now)))
        return HStack(spacing: 8) {
            ZStack { Circle().trim(from: 0.05, to: 0.92).stroke(HV.green, style: StrokeStyle(lineWidth: 2.4, lineCap: .round)).rotationEffect(.degrees(-80)).frame(width: 22, height: 22); Circle().fill(HV.green).frame(width: 7, height: 7) }.frame(width: 28, height: 28)
            Text("ひらくまで").font(LF.inter(600, 12)).foregroundStyle(Color(hex: "6E6E73"))
            Text("\(s / 3600)h \(String(format: "%02d", (s % 3600) / 60))m").font(LF.inter(700, 14)).foregroundStyle(HV.ink).monospacedDigit()
            Rectangle().fill(.black.opacity(0.12)).frame(width: 1, height: 16)
            HStack(spacing: 2.5) { ForEach(0..<3, id: \.self) { i in RoundedRectangle(cornerRadius: 2).fill(i < max(0, 3 - input.shotsUsed) ? HV.green : Color.black.opacity(0.1)).frame(width: 7, height: 12) } }
            Text("\(max(0, 3 - input.shotsUsed))").font(LF.inter(700, 12.5)).foregroundStyle(HV.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8).frame(width: 255, height: 36)
        .background(.white, in: Capsule()).shadow(color: .black.opacity(0.12), radius: 12, y: 8)
    }

    // MARK: Friends タブ

    private var stat1: some View { VStack(spacing: 4) { Text("6d").font(LF.serif(31, italic: true)).frame(height: 31); Text("Left").font(LF.inter(500, 13)).opacity(0.8) }.foregroundStyle(.white) }

    private func friendsTab(w: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                collage(width: w - 36)
                LinearGradient(colors: [.black.opacity(0.35), .clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                Text("FRIENDS · \(input.dateLabel)").font(LF.mono(10)).tracking(3).foregroundStyle(.white.opacity(0.8)).frame(width: w - 36).offset(y: 22)
                VStack(spacing: -4) { Text("Yesterday,").lineLimit(1).fixedSize(); Text("friends.").lineLimit(1).fixedSize() }.font(LF.serif(46)).tracking(-0.9).foregroundStyle(.white).frame(width: 322, height: 90).offset(x: 16, y: 168)
                stat1.frame(width: 100).offset(x: 11, y: 310)
                VStack(spacing: 4) {
                    if input.shotFriends > 0 { Circle().fill(Color(hex: "3BD35A")).frame(width: 16, height: 16).frame(height: 31); Text("\(input.shotFriends) shot today").font(LF.inter(500, 13)).opacity(0.85) }
                    else { Text("—").font(LF.inter(400, 22)).frame(height: 31); Text("まだ").font(LF.inter(500, 13)).opacity(0.8) }
                }.foregroundStyle(.white).frame(width: 130).offset(x: 111, y: 310)
                VStack(spacing: 4) { Image(systemName: "chevron.right").font(.system(size: 16, weight: .bold)).frame(height: 31); Text("Friends").font(LF.inter(500, 13)).opacity(0.8) }.foregroundStyle(.white).frame(width: 100).offset(x: 235, y: 310)
                Button { Haptics.play(.click); actions.addFriends() } label: {
                    HStack(spacing: 8) { Image(systemName: "plus").font(.system(size: 16, weight: .bold)); Text("Add friends").font(LF.inter(800, 16)) }
                        .foregroundStyle(HV.ink).frame(width: 262, height: 56).background(.white, in: Capsule())
                }.buttonStyle(HVPress(scale: 0.97)).offset(x: 14, y: 400)
                Button { Haptics.play(.sel); actions.scanQR() } label: {
                    Image(systemName: "qrcode").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white).frame(width: 56, height: 56).background(Color.white.opacity(0.14), in: Circle())
                }.buttonStyle(HVPress(scale: 0.94)).offset(x: 284, y: 400)
            }
            .frame(width: w - 36, height: 470).clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .padding(.horizontal, 18)
            if input.requestCount > 0 {
                Button { Haptics.play(.sel); actions.openRequests() } label: {
                    HStack(spacing: 12) {
                        HStack(spacing: -8) { ForEach(Array(input.requestFaces.prefix(3).enumerated()), id: \.offset) { i, f in
                            Text(f.initial).font(LF.inter(800, 12)).foregroundStyle(.white).frame(width: 30, height: 30).background(f.color, in: Circle()).overlay(Circle().strokeBorder(.white, lineWidth: 2)).zIndex(Double(3 - i)) } }
                        Text("申請が とどいています").font(LF.inter(800, 16)).foregroundStyle(HV.ink)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(HV.ink)
                    }.padding(.horizontal, 16).frame(height: 54).background(Color(hex: "F2F2F7"), in: RoundedRectangle(cornerRadius: 27))
                }.buttonStyle(HVPress(scale: 0.98)).padding(.horizontal, 14)
            }
            // 友だちの きのうの 写真の 並び
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(input.cells) { c in
                    Button { Haptics.play(.pop); if !input.locked { withAnimation(.easeOut(duration: 0.25)) { viewing = c } } else { Haptics.play(.warn) } } label: {
                        ZStack(alignment: .bottomLeading) {
                            Rectangle().fill(Color(hex: "E8E8ED"))
                            if let img = c.photo { Image(uiImage: img).resizable().scaledToFill().blur(radius: input.locked ? 14 : 0) }
                            LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .center, endPoint: .bottom)
                            HStack { Text("\(c.name).").font(LF.serif(20, italic: true)).foregroundStyle(.white); Spacer()
                                if input.locked { Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.white) }
                                else if let t = c.time { Text(t).font(LF.mono(9.5)).foregroundStyle(Color(hex: "FF9A3C")) } }.padding(14)
                        }
                        .frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    }.buttonStyle(HVPress(scale: 0.97))
                }
            }.padding(.horizontal, 14)
            meCard.padding(.horizontal, 18).padding(.top, 12).id("me")
            friendStrip.padding(.horizontal, 18)
            tripsSection
            if input.cells.isEmpty {
                Text("友だちを ふやすと、ここに きのうが 並びます").font(LF.inter(600, 14)).foregroundStyle(HV.gray).frame(maxWidth: .infinity).padding(.top, 10)
            }
        }
    }

    private func collage(width: CGFloat) -> some View {
        let imgs = input.cells.compactMap(\.photo)
        return ZStack {
            Color(hex: "1A1618")
            if imgs.isEmpty { LinearGradient(colors: [Color(hex: "3A3036"), Color(hex: "151012")], startPoint: .top, endPoint: .bottom) }
            else {
                let n = min(4, imgs.count)
                let cols = n == 1 ? 1 : 2
                let rows = n <= 2 ? 1 : 2
                VStack(spacing: 2) { ForEach(0..<rows, id: \.self) { r in HStack(spacing: 2) { ForEach(0..<cols, id: \.self) { c in
                    let i = r * cols + c
                    Image(uiImage: imgs[i % imgs.count]).resizable().scaledToFill().frame(maxWidth: .infinity, maxHeight: .infinity).clipped().blur(radius: input.locked ? 18 : 0)
                } } } }
            }
        }
    }

    // MARK: Mondo タブ

    private func mondoTab(w: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 8) { Circle().fill(Color(hex: "3BD35A")).frame(width: 9, height: 9); Text("MONDO · \(input.dateLabel)").font(LF.mono(10)).tracking(2.4).foregroundStyle(HV.gray) }.offset(x: 20, y: 5)
            HStack(spacing: 0) {
                Text("The w").font(LF.serif(58)).tracking(-1.2)
                ZStack {
                    Circle().fill(Color(hex: "24A03C")).frame(width: 34, height: 34)
                    Circle().stroke(HV.ink, lineWidth: 2.6).frame(width: 34, height: 34)
                    Ellipse().stroke(HV.ink.opacity(0.85), lineWidth: 1.8).frame(width: 15, height: 34)
                    Rectangle().fill(HV.ink.opacity(0.85)).frame(width: 34, height: 1.8)
                    Circle().fill(Color(hex: "FFD60A")).frame(width: 8, height: 8).overlay(Circle().stroke(HV.ink, lineWidth: 1.4)).offset(x: 8, y: -12)
                }.padding(.horizontal, 2).offset(y: 5)
                Text("rld,").font(LF.serif(58)).tracking(-1.2)
            }.foregroundStyle(HV.ink).frame(height: 57, alignment: .leading).offset(x: 20, y: 30)
            Text("yesterday.").font(LF.serif(64, italic: true)).tracking(-1.2)
                .foregroundStyle(LinearGradient(colors: [Color(hex: "24A03C"), Color(hex: "7EE08F")], startPoint: .leading, endPoint: .trailing))
                .overlay(alignment: .bottomLeading) { Capsule().fill(Color(hex: "C8F25A")).frame(width: 226, height: 5).offset(y: 2) }
                .frame(height: 64, alignment: .leading).offset(x: 20, y: 87)
            // 都市の 時計(帯)
            ZStack(alignment: .leading) {
                Rectangle().fill(.black.opacity(0.08)).frame(height: 1).offset(y: -15)
                Rectangle().fill(.black.opacity(0.08)).frame(height: 1).offset(y: 15)
                HStack(spacing: 20) {
                    ForEach(Array(input.cities.enumerated()), id: \.offset) { _, c in
                        HStack(spacing: 6) { Circle().fill(Color(hex: "3BD35A")).frame(width: 5, height: 5); Text(c.0).font(LF.mono(10)).tracking(2).foregroundStyle(HV.gray); Text(c.1).font(LF.mono(10)).foregroundStyle(HV.ink) }.fixedSize()
                    }
                }.padding(.leading, 20)
            }.frame(width: w, height: 30).clipped().offset(y: 173)
            ZStack(alignment: .top) {
                Color(hex: "2A2326")
                if let img = input.mondoPhoto { Image(uiImage: img).resizable().scaledToFill().blur(radius: input.locked ? 20 : 0) }
                LinearGradient(colors: [.black.opacity(0.1), .clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                Text("TODAY'S ONE · 9:00").font(LF.mono(10)).tracking(3).foregroundStyle(Color(hex: "9BE8A8")).offset(y: 20)
                Text(input.mondoCity).font(LGFont.mincho(34)).foregroundStyle(.white).offset(y: 293)
                Text("picked by the world").font(LF.inter(500, 12)).foregroundStyle(.white.opacity(0.7)).offset(y: 355)
                Text(input.mondoTag).font(LF.inter(900, 15)).foregroundStyle(HV.ink).frame(width: 80, height: 41).background(Color(hex: "9ED8FF"), in: RoundedRectangle(cornerRadius: 11)).rotationEffect(.degrees(6)).offset(x: 129, y: 47)
            }
            .frame(width: 354, height: 400).clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous)).offset(x: 18, y: 213)
        }
        .frame(width: w, height: 640, alignment: .topLeading)
    }

    // MARK: 下へ(Y05):ME ・ Friend ・ TRIPS

    private var meCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 40, style: .continuous).fill(Color(hex: "F2F2F4"))
            HStack(spacing: -40) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(colors: [[Color(hex: "EE5E9C"), Color(hex: "9B8CFF")], [Color(hex: "BFEFD0"), Color(hex: "9ED8FF")], [Color(hex: "C060A0"), Color(hex: "F0A0C0")]][i], startPoint: .top, endPoint: .bottom))
                        .frame(width: 108, height: 160).rotationEffect(.degrees(Double(i) * 7 - 4)).offset(y: CGFloat(i) * 6)
                }
            }.frame(maxWidth: .infinity, alignment: .trailing).offset(x: 30, y: -30)
            Text("ME").font(LF.inter(900, 100)).tracking(-7).foregroundStyle(HV.ink).offset(x: 24, y: -60)
            Text("きのうの まい ・ 7日で きえる").font(LF.inter(700, 15)).foregroundStyle(HV.gray).padding(.leading, 28).padding(.bottom, 28)
            Image(systemName: "arrow.up.right").font(.system(size: 20, weight: .bold)).foregroundStyle(HV.ink).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(28)
        }.frame(height: 245).clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            .onTapGesture { Haptics.play(.pop); actions.openProfile() }
    }

    private var friendStrip: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 36, style: .continuous).fill(Color(hex: "F2F2F7")).overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
            (Text("F").font(LF.serif(44, italic: true)).foregroundColor(Color(hex: "24A03C")) + Text("riend").font(LF.serif(44)).foregroundColor(HV.ink)).padding(.leading, 26).padding(.top, 14)
            HStack(spacing: 14) {
                VStack(spacing: 8) {
                    Button { Haptics.play(.sel); actions.addFriends() } label: { Image(systemName: "plus").font(.system(size: 30, weight: .bold)).foregroundStyle(.white).frame(width: 52, height: 52).background(Color(hex: "24A03C"), in: Circle()).shadow(color: Color(hex: "24A03C").opacity(0.4), radius: 10, y: 8) }.buttonStyle(.plain)
                    Text("Add").font(LF.inter(800, 14)).foregroundStyle(Color(hex: "24A03C"))
                }
                ForEach(0..<3, id: \.self) { _ in Circle().strokeBorder(.black.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(width: 52, height: 52).offset(y: -9) }
            }.padding(.leading, 20).padding(.top, 64)
            Circle().fill(HV.ink).frame(width: 36, height: 36).overlay(Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)).frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 16).padding(.top, 16)
        }.frame(height: 146)
    }

    private var tripsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Rectangle().fill(HV.ink).frame(height: 1).padding(.horizontal, 22).padding(.top, 14)
            HStack { Text("TRIPS").font(LF.mono(11)).tracking(3).foregroundStyle(HV.gray); Spacer(); Text("1日 23枚 ・ みんなで").font(LF.inter(700, 13)).foregroundStyle(HV.gray) }.padding(.horizontal, 22)
            VStack(spacing: 8) {
                Image(systemName: "plus").font(.system(size: 26, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44).background(Color(hex: "24A03C"), in: Circle())
                Text("New trip").font(LF.serif(24)).foregroundStyle(HV.ink)
                Text("旅行 ・ 合宿 ・ イベント").font(LF.inter(600, 11)).foregroundStyle(HV.gray)
            }.frame(width: 124, height: 200).overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(.black.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))).padding(.leading, 20)
                .onTapGesture { Haptics.play(.tick); actions.shoot() }
        }
    }

    // MARK: 写真を ひらいた ところ(Y06)

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

    // MARK: 下の ガラスの タブ

    private var tabBar: some View {
        HStack(spacing: 4) {
            tabButton(1, "Mondo", "globe")
            tabButton(0, "Friends", "person.2.fill")
        }
        .padding(.horizontal, 5).padding(.vertical, 5).frame(width: 274, height: 66)
        .background(.ultraThinMaterial, in: Capsule()).background(Color(red: 40 / 255, green: 40 / 255, blue: 46 / 255).opacity(0.2), in: Capsule())
        .overlay(Capsule().strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 12)
    }

    private func tabButton(_ i: Int, _ title: String, _ icon: String) -> some View {
        Button { if tab != i { Haptics.play(.sel); withAnimation(.spring(response: 0.44, dampingFraction: 0.72)) { tab = i } } } label: {
            VStack(spacing: 3) { Image(systemName: icon).font(.system(size: 20, weight: .semibold)); Text(title).font(LF.inter(700, 12)) }
                .foregroundStyle(tab == i ? HV.ink : HV.gray).frame(maxWidth: .infinity).frame(height: 54)
                .background { if tab == i { Capsule().fill(Color.black.opacity(0.08)) } }
        }.buttonStyle(.plain).accessibilityLabel(title)
    }
}
