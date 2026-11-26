import SwiftUI
internal import Combine

// P03:横スライドの 5ページ(Camera / Friends / Trip / Mondo / Yesterday)。仕様:PROMPT_v64 §9〜11、v65 §5、v66 §4、v67(Mondo)。
// 座標は spec/screens/H11〜H18.json(カードの 左上 = (10, 178))。ここでは カード内の 座標(= 絶対 − (10, 178))で 書く。

struct HomeV64Friend: Identifiable {
    let id: String
    var name: String
    var color: Color
    var image: UIImage? = nil
    /// アイコン写真 だけ(今日の 写真の モザイクは 入れない。Home の 写真の カード 用)
    var avatar: UIImage? = nil
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
                HStack(spacing: 0) { ForEach([1, 5, 10, 15, 20], id: \.self) { n in Text(String(format: "%02d", n)).font(Typo.label(8.5)).foregroundStyle(Color(hex: "FF9F43")).frame(width: n == 1 ? 14.5 : 0, alignment: .leading).fixedSize().offset(x: CGFloat(n - 1) * 12.7 - (n == 1 ? 0 : 0)) } }.frame(height: 10)
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

enum HVPage: Int, CaseIterable {
    case camera, friends, trip, yesterday
    var title: String { ["Camera", "Friends", "Trip", "Yesterday"][rawValue] }
    var icon: HVIconKind { [HVIconKind.camera, .friends, .trip, .yesterday][rawValue] }
}

// MARK: - 1 Friends

/// v122:横スライドの Friends ページ(1ページ = やる こと 1つ)。上から VStack で 並べる(決めうちの 位置で 置かない)
struct HVFriendsPage: View {
    let input: HomeV64Input
    let cardW: CGFloat
    let actions: HomeV64Actions

    var body: some View {
        let took = input.friends.filter { $0.shots > 0 }.count
        let hasFriends = !input.friends.isEmpty
        let hasReq = input.requestCount > 0
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(verbatim: "Friends").font(Typo.title(50)).tracking(Typo.titleTracking(50)).foregroundStyle(HVCardTint.milk).lineLimit(1)
                Spacer(minLength: 0)
                Button {
                    Haptics.play(.tick)
                    NotificationCenter.default.post(name: IntroStore.requested, object: IntroRequest(kind: .friends))
                } label: {
                    Text(verbatim: "?").font(Typo.ui(800, 11)).foregroundStyle(.white.opacity(0.7))
                        .frame(width: 22, height: 22).background(Color.white.opacity(0.1), in: Circle())
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(HVPress(scale: 0.9))
                .accessibilityLabel("Friends の 説明を もう一度")
                .offset(x: 11, y: -4)
            }
            .frame(height: 52)
            statusLine(took: took, hasFriends: hasFriends).padding(.top, 13)
            if hasFriends {
                friendRow.padding(.top, 25)
                if hasReq { requestRow.padding(.top, 20) }
                HVLimeLedgeButton(title: "Friends を ひらく", icon: nil, trailing: "arrow.right") { actions.openFriends() }
                    .padding(.top, hasReq ? 16 : 29)
            } else {
                emptyArt(small: hasReq).frame(maxWidth: .infinity).padding(.top, hasReq ? 29 : 39)
                if hasReq { requestRow.padding(.top, 30) }
                HVLimeLedgeButton(title: "友だちを よぶ", icon: "person.badge.plus", trailing: nil) { actions.searchByID() }
                    .padding(.top, hasReq ? 16 : 37)
                Text("QR ・ リンク ・ @ID で つながる").font(Typo.ui(700, 12.5)).foregroundStyle(Color(hex: "8C8C93")).lineLimit(1)
                    .frame(maxWidth: .infinity).padding(.top, 14)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 22).padding(.horizontal, 14)
        .frame(width: cardW, height: 508, alignment: .topLeading)
    }

    @ViewBuilder private func statusLine(took: Int, hasFriends: Bool) -> some View {
        if !hasFriends {
            Text("毎朝 9:00 に、きのうを 見せあう").font(Typo.ui(700, 14)).foregroundStyle(Color(hex: "A9A9B0")).lineLimit(1).minimumScaleFactor(0.8)
        } else if took > 0 {
            HStack(spacing: 7) {
                Circle().fill(HV.lime).frame(width: 7, height: 7)
                Text("\(took)人 撮った ・ 9:00 に ひらく").font(Typo.ui(800, 14)).foregroundStyle(HV.lime).lineLimit(1).minimumScaleFactor(0.8)
            }
        } else {
            Text("きょうは まだ だれも 撮って いない").font(Typo.ui(700, 14)).foregroundStyle(Color(hex: "A9A9B0")).lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    /// 0人:まんなかに 自分の 丸い 写真(ライムの 輪)、左右に 点線の 空きの 丸(+)。動かさない
    private func emptyArt(small: Bool) -> some View {
        let me: CGFloat = small ? 100 : 112, gap: CGFloat = small ? 70 : 78
        return ZStack {
            HStack(spacing: me - 20) {
                ForEach(0..<2, id: \.self) { _ in
                    ZStack {
                        Circle().fill(Color(hex: "111113"))
                        Circle().strokeBorder(.white.opacity(0.28), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                        Image(systemName: "plus").font(.system(size: gap * 0.3, weight: .regular)).foregroundStyle(.white.opacity(0.4))
                    }
                    .frame(width: gap, height: gap)
                }
            }
            ZStack {
                Circle().fill(Color(hex: "3A3A3C"))
                if let a = input.avatar { Image(uiImage: a).resizable().scaledToFill().clipShape(Circle()) }
                else { Text(String(input.avatarName.prefix(1))).font(Typo.ui(800, me * 0.36)).foregroundStyle(.white) }
            }
            .frame(width: me - 8, height: me - 8)
            .overlay(Circle().strokeBorder(HV.lime, lineWidth: 3).padding(-4))
        }
        .frame(height: me)
        .accessibilityHidden(true)
    }

    /// 申請の 行(写真 ・ 名前 ・ ピンクの「確認」)
    private var requestRow: some View {
        let first = input.requests.first?.name
        let n = max(input.requestCount, input.requests.count)
        return Button { Haptics.play(.sel); actions.openRequests() } label: {
            HStack(spacing: 10) {
                HStack(spacing: -5) {
                    ForEach(Array(input.requestFaces.prefix(2).enumerated()), id: \.offset) { i, f in
                        HVCardFace(face: f).frame(width: 34, height: 34).overlay(Circle().strokeBorder(Color(hex: "0B0B0C"), lineWidth: 1.5).padding(-1.5)).zIndex(Double(3 - i))
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(first.map { n > 1 ? "\($0) ほか\(n - 1)人" : $0 } ?? "友だち申請 \(n)件").font(Typo.ui(800, 14.5)).foregroundStyle(Color(hex: "F4F1EA")).lineLimit(1)
                    Text("友だちに なりたい").font(Typo.ui(700, 11.5)).foregroundStyle(Color(hex: "8C8C93")).lineLimit(1)
                }
                Spacer(minLength: 4)
                Text("確認").font(Typo.ui(800, 13.5)).foregroundStyle(Color(hex: "111113"))
                    .frame(width: 63, height: 40).background(HVCardTint.friends, in: Capsule())
            }
            .padding(.leading, 10).padding(.trailing, 11)
            .frame(height: 62)
            .background(Color(hex: "141416"), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(HVPress(scale: 0.98))
    }

    /// 友だちの 丸の 列(輪 = 撮った 枚数)+ 最後に「よぶ」
    private var friendRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(input.friends) { fr in story(fr) }
                Button { Haptics.play(.sel); actions.searchByID() } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(Color(hex: "141416"))
                            Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1.5)
                            Image(systemName: "plus").font(.system(size: 17, weight: .bold)).foregroundStyle(HV.lime)
                        }.frame(width: 54, height: 54).frame(width: 68, height: 68)
                        Text("よぶ").font(Typo.ui(800, 11.5)).foregroundStyle(Color(hex: "E9E9EC"))
                    }
                }.buttonStyle(HVPress(scale: 0.94))
            }
        }
        .scrollClipDisabled()
    }

    private func story(_ fr: HomeV64Friend) -> some View {
        Button { Haptics.play(.sel); actions.openChat(fr.id, fr.name) } label: {
            VStack(spacing: 3) {
                ZStack {
                    ForEach(0..<3, id: \.self) { k in
                        Circle().trim(from: 0.012, to: 0.32).stroke(k < fr.shots ? HV.lime : Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90 + Double(k) * 120)).frame(width: 66, height: 66)
                    }
                    ZStack {
                        Circle().fill(fr.color)
                        if let img = fr.avatar ?? fr.image { Image(uiImage: img).resizable().scaledToFill().clipShape(Circle()) }
                        else { Text(String(fr.name.prefix(1))).font(Typo.ui(800, 18)).foregroundStyle(.white) }
                    }.frame(width: 54, height: 54)
                }.frame(width: 68, height: 68)
                Text(fr.name).font(Typo.ui(800, 11.5)).foregroundStyle(Color(hex: "E9E9EC")).lineLimit(1).frame(width: 68)
                Text(fr.shots > 0 ? "\(fr.shots)/3" : "まだ").font(Typo.ui(800, 9.5)).foregroundStyle(fr.shots > 0 ? HV.lime : Color(hex: "8C8C93"))
            }
        }.buttonStyle(HVPress(scale: 0.94))
    }
}

/// v122:ライムの 大きな ボタン(高さ 60 ・ 角丸 30 ・ 段 6pt #97C235 ・ 押すと 4pt しずむ)
struct HVLimeLedgeButton: View {
    let title: String
    var icon: String?
    var trailing: String?
    let action: () -> Void
    var body: some View {
        Button { Haptics.play(.click); action() } label: {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 17, weight: .bold)) }
                Text(title).font(Typo.ui(800, 17)).lineLimit(1)
                if let trailing { Image(systemName: trailing).font(.system(size: 16, weight: .bold)) }
            }
            .foregroundStyle(Color(hex: "111111"))
            .frame(maxWidth: .infinity).frame(height: 60)
        }
        .buttonStyle(HVLedgePress(face: HV.lime, ledge: Color(hex: "97C235"), radius: 30, depth: 6))
    }
}

/// 押せる 物の 下に 色の 段。押すと しずむ(段 6 → 2)
struct HVLedgePress: ButtonStyle {
    let face: Color
    let ledge: Color
    var radius: CGFloat = 30
    var depth: CGFloat = 6
    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed ? depth - 2 : 0
        return configuration.label
            .background(face, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .offset(y: down)
            .background { RoundedRectangle(cornerRadius: radius, style: .continuous).fill(ledge).offset(y: depth) }
            .padding(.bottom, depth)
            .animation(.timingCurve(0.3, 1.4, 0.5, 1, duration: 0.16), value: configuration.isPressed)
    }
}

// MARK: - 2 Trip(v110:一覧は TripHubView 1つ。きのうの Trip タブと 同じ もの)

struct HVTripPage: View {
    let input: HomeV64Input
    let cardW: CGFloat
    let actions: HomeV64Actions
    @State private var pos = ScrollPosition()

    var body: some View {
        TripHubView(items: input.tripItems, now: input.now, onOpen: { actions.openTripHome($0) }, onNew: { actions.openTrip() }, onJoinKey: { actions.joinKey() },
                    position: $pos, topInset: 10)
            .frame(width: cardW, height: 508)
            .background(Color.black.opacity(0.62))
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
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
    @State private var pastHalf = false
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
                // v100:半分を こえたら sel(「はなすと 次へ」)。もどって 半分を こえても sel
                let past = abs(dx) > width * 0.5
                if past != pastHalf { pastHalf = past; Haptics.play(.sel) }
            },
            onEnded: { dx, predicted in
                pastHalf = false
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
                Text("\(n)").font(Typo.ui(900, size)).monospacedDigit().foregroundStyle(color).frame(height: h)
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

    private let lime = LattagPalette.lime

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
                    Text("LIVE").font(Typo.label(11)).tracking(2.2).foregroundStyle(lime)
                }
                .padding(.horizontal, 10).frame(height: 22).background(lime.opacity(0.12), in: Capsule()).offset(x: 18, y: 19)
                Text(clockText).font(Typo.label(12)).foregroundStyle(Color(hex: "5A5A5F")).offset(x: 104, y: 22)
                Button { Haptics.play(.soft); onClose() } label: { Image(systemName: "chevron.up").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.7)).frame(width: 30, height: 30).background(Color(hex: "1C1C1E"), in: Circle()) }.buttonStyle(.plain).offset(x: 318, y: 15)
                Text("消灯まで").font(Typo.ui(600, 13)).foregroundStyle(Color(hex: "8E8E93")).offset(x: 18, y: 56)
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
                    Text("ひらくまで").font(Typo.ui(600, 13)).foregroundStyle(Color(hex: "8E8E93"))
                    Text("\(toOpen / 3600)h \(String(format: "%02d", (toOpen % 3600) / 60))m").font(Typo.ui(700, 14)).foregroundStyle(.white.opacity(0.9)).contentTransition(.numericText(countsDown: true))
                }.offset(x: 18, y: 154)
                // バー
                ZStack(alignment: .leading) {
                    Capsule().fill(LinearGradient(colors: [Color(hex: "171B0C"), Color(hex: "27310F")], startPoint: .leading, endPoint: .trailing)).frame(width: W * 24 / 33, height: 8).frame(width: W, alignment: .leading)
                    Capsule().fill(Color.white.opacity(0.06)).frame(width: W, height: 8).mask(Rectangle().frame(width: W - W * 24 / 33).frame(width: W, alignment: .trailing))
                    Capsule().fill(LinearGradient(colors: [lime.opacity(0.18), lime.opacity(0.85)], startPoint: .leading, endPoint: .trailing)).frame(width: max(8, W * frac * barP), height: 8).shadow(color: lime.opacity(0.32), radius: 7)
                    if !reduceMotion {
                        PausableTimeline(minimumInterval: 1.0 / 30) { date in   // v111:間隔 ・ 見えて いる 時だけ
                            let u = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4
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
                }.font(Typo.label(10)).frame(width: W, alignment: .leading).offset(x: 18, y: 208)
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.12), lineWidth: 1).frame(width: 40, height: 52)
                        .overlay(Image(systemName: i < input.shotsUsed ? "checkmark" : "plus").font(.system(size: 13, weight: .semibold)).foregroundStyle(i < input.shotsUsed ? lime : Color(hex: "5A5A5F")))
                        .offset(x: 18 + CGFloat(i) * 46, y: 243)
                }
                Button { Haptics.play(.click); onClose(); onShoot() } label: {
                    HStack(spacing: 12) {
                        HVCameraGlyph(width: 26, line: 2, color: HV.ink, showsFlash: false)
                        VStack(alignment: .leading, spacing: 2) { Text("shoot").font(Typo.ui(800, 19)).foregroundStyle(HV.ink); Text("\(input.remaining) LEFT").font(Typo.label(9)).tracking(1.6).foregroundStyle(Color(hex: "8E8E93")) }
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


/// v99:ページの 番号の 横の `?`(見た目 20pt ・ 押せる 所 44pt)。いつでも もう一度 見られる
struct IntroHelpButton: View {
    let kind: IntroKind
    @State private var pulse = 0
    var body: some View {
        Button {
            Haptics.play(.tick)
            NotificationCenter.default.post(name: IntroStore.requested, object: IntroRequest(kind: kind))
        } label: {
            Text("?").font(Typo.label(11)).foregroundStyle(.white.opacity(0.7))
                .frame(width: 20, height: 20).overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                .scaleEffect(pulse % 2 == 1 ? 1.5 : 1)
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kind.name) の 説明を 見る")
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("introClosedPulse"))) { _ in
            Task { @MainActor in
                for _ in 0..<2 {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { pulse += 1 }
                    try? await Task.sleep(for: .milliseconds(260))
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { pulse += 1 }
                    try? await Task.sleep(for: .milliseconds(260))
                }
            }
        }
    }
}
