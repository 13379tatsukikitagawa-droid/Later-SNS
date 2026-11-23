import SwiftUI
import UIKit

// P57 A(v129 1章):Trip の 部屋 = この 1つ だけ。見本:screens/v129_trip_room.png
// 上の バー(もどる ・ DAY の 札 ・ 設定)/ 表紙 330 / メンバー + 白い「よぶ」/ きょうの カード / Film / 下の チャットの バー 1本。

struct TripRoomData {
    struct Member: Identifiable { let id: String; var name: String; var avatar: UIImage? }
    struct Day: Identifiable { let id: String; var number: Int; var date: String; var opened: Int; var photos: [UIImage?]; var isToday = false; var isFuture = false }
    struct ChatLine { var name: String; var text: String; var face: Member? }
    var name: String
    var sub: String
    var dayNumber: Int
    var dayTotal: Int?
    var colorIndex = 0
    var cover: UIImage?
    var members: [Member]
    var shotsToday: Int
    var shooters: [Member] = []
    var perDay = 23
    var days: [Day] = []
    var chat: ChatLine? = nil
    var unread = 0
}

struct TripRoomView: View {
    var data: TripRoomData
    var onClose: () -> Void = {}
    var onShoot: () -> Void = {}
    var onChat: () -> Void = {}
    var onMore: () -> Void = {}
    var onInvite: () -> Void = {}
    var debugScrollY: CGFloat? = nil

    @State private var pos = ScrollPosition()
    @State private var scrollY: CGFloat = 0
    @State private var topInset: CGFloat = TripRoomView.windowTopInset()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color { PopColor.trip(data.colorIndex) }
    private var barH: CGFloat { max(108, topInset + 56) }
    private var barSolid: Bool { scrollY > 200 }

    static func windowTopInset() -> CGFloat {
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.safeAreaInsets.top ?? 59
    }

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .top) {
                Color(hex: "0A0A0B")
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        cover(w: g.size.width)
                        memberRow.padding(.horizontal, 16).padding(.top, 2)
                        todayCard.padding(.horizontal, 16).padding(.top, 18)
                        HStack(alignment: .firstTextBaseline) {
                            Text(verbatim: "Film").font(Typo.title(30)).foregroundStyle(.white)
                            Spacer()
                            Text("日ごとの 写真").font(Typo.ui(700, 12)).foregroundStyle(.white.opacity(0.45))
                        }
                        .padding(.horizontal, 16).padding(.top, 30)
                        ForEach(data.days) { day in dayBlock(day).padding(.top, 18) }
                        Color.clear.frame(height: 130)
                    }
                }
                .scrollPosition($pos)
                .onScrollGeometryChange(for: CGFloat.self) { max(0, $0.contentOffset.y + $0.contentInsets.top) } action: { _, v in
                    let was = barSolid
                    scrollY = v
                    if was != barSolid { Haptics.play(.tick) }
                }
                .onAppear { if let y = debugScrollY { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { pos.scrollTo(y: y) } } }
                topBar(w: g.size.width)
                chatBar.frame(width: g.size.width, height: g.size.height, alignment: .bottom)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }

    // MARK: 上の バー(押せる 物は 2つ だけ)

    private func topBar(w: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(barSolid ? 1 : 0).animation(.easeOut(duration: 0.25), value: barSolid)
            ZStack {
                HStack {
                    glassButton("chevron.left", "もどる") { onClose() }
                    Spacer()
                    glassButton("gearshape", "設定") { onMore() }
                }
                VStack(spacing: 1) {
                    if barSolid { Text(data.name).font(Typo.title(19)).foregroundStyle(.white).lineLimit(1).transition(.opacity) }
                    Text(dayText).font(Typo.ui(800, 11.5)).tracking(0.6).foregroundStyle(tint)
                        .padding(.horizontal, barSolid ? 0 : 12).padding(.vertical, barSolid ? 0 : 5)
                        .background { if !barSolid { Capsule().fill(.black.opacity(0.35)).background(.ultraThinMaterial, in: Capsule()) } }
                }
                .animation(.easeOut(duration: 0.25), value: barSolid)
                .padding(.horizontal, 70)
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, 14).frame(height: 44).padding(.bottom, 8)
        }
        .frame(width: w, height: barH)
    }

    private var dayText: String { data.dayTotal.map { "DAY \(data.dayNumber) / \($0)" } ?? "DAY \(data.dayNumber)" }

    private func glassButton(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button { Haptics.play(.tick); action() } label: {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44)
                .background(.black.opacity(0.3), in: Circle()).background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(HVPress(scale: 0.92)).accessibilityLabel(label)
    }

    // MARK: 表紙(字は 写真の 下の 暗い 所 だけ)

    private func cover(w: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            Color(hex: "2A2326").overlay { if let c = data.cover { Image(uiImage: c).resizable().scaledToFill() } }.frame(width: w, height: 330).clipped()
            LinearGradient(stops: [.init(color: .black.opacity(0.45), location: 0), .init(color: .clear, location: 0.3), .init(color: Color(hex: "0A0A0B").opacity(0.55), location: 0.66), .init(color: Color(hex: "0A0A0B"), location: 1)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text(data.name).font(Typo.title(54)).tracking(Typo.titleTracking(54)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.5)
                Text(data.sub).font(Typo.ui(700, 13)).foregroundStyle(.white.opacity(0.7)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
        }
        .frame(width: w, height: 330, alignment: .bottomLeading)
        .clipped()
    }

    // MARK: メンバー + 白い「よぶ」

    private var memberRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: -10) {
                ForEach(data.members.prefix(5)) { m in face(m, 34).overlay(Circle().strokeBorder(Color(hex: "0A0A0B"), lineWidth: 2)) }
            }
            Text("\(data.members.count)人").font(Typo.ui(800, 13)).foregroundStyle(.white.opacity(0.6))
            Spacer(minLength: 8)
            Button { Haptics.play(.pop); onInvite() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.plus").font(.system(size: 14, weight: .bold))
                    Text("よぶ").font(Typo.ui(800, 14))
                }
                .foregroundStyle(Color(hex: "111113")).padding(.horizontal, 16).frame(height: 44)
                .background(Color(hex: "FAFAF7"), in: Capsule())
            }
            .buttonStyle(HVPress(scale: 0.95)).accessibilityLabel("よぶ")
        }
    }

    private func face(_ m: TripRoomData.Member, _ s: CGFloat) -> some View {
        ZStack {
            if let a = m.avatar { Image(uiImage: a).resizable().scaledToFill() }
            else {
                Circle().fill(LinearGradient(colors: [Color(hex: "7FB0FF"), Color(hex: "61DD7A")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Text(String(m.name.prefix(1))).font(Typo.ui(900, s * 0.42)).foregroundStyle(.white))
            }
        }
        .frame(width: s, height: s).clipShape(Circle())
    }

    // MARK: きょうの カード(ライムは この 部屋で これ 1つ)

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("DAY \(data.dayNumber) ・ きょう").font(Typo.ui(800, 11.5)).foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text("あした 9:00 に 現像").font(Typo.ui(800, 12)).foregroundStyle(tint)
            }
            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(verbatim: "\(data.shotsToday)").font(Typo.title(52)).foregroundStyle(.white).contentTransition(.numericText())
                    Text(verbatim: "/\(data.perDay)").font(Typo.title(24)).foregroundStyle(.white.opacity(0.35))
                }
                Spacer()
                if !data.shooters.isEmpty {
                    HStack(spacing: 8) {
                        HStack(spacing: -8) { ForEach(data.shooters.prefix(3)) { m in face(m, 28).overlay(Circle().strokeBorder(Color(hex: "141517"), lineWidth: 2)) } }
                        Text("が 撮った").font(Typo.ui(700, 13)).foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .padding(.top, 2)
            HStack(spacing: 3) {
                ForEach(0..<data.perDay, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3).fill(i < data.shotsToday ? tint : Color.white.opacity(0.08)).frame(height: 24)
                }
            }
            .padding(.top, 12)
            (Text("みんなで ").foregroundColor(.white.opacity(0.5)) + Text("1日 \(data.perDay)枚").foregroundColor(.white).bold() + Text("。撮った 写真は あした 9:00 に いっしょに ひらく").foregroundColor(.white.opacity(0.5)))
                .font(Typo.ui(600, 13)).padding(.top, 12)
            Button { Haptics.play(.shutter); onShoot() } label: {
                HStack(spacing: 10) { Image(systemName: "camera").font(.system(size: 19, weight: .semibold)); Text("Trip で 撮る").font(Typo.ui(800, 19)) }
                    .foregroundStyle(HV.ink).frame(maxWidth: .infinity).frame(height: 58)
            }
            .buttonStyle(HVLedgePress(face: HV.lime, ledge: Color(hex: "97C235"), radius: 29, depth: 6))
            .padding(.top, 16)
        }
        .padding(18)
        .background(Color(hex: "141517"), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.07), lineWidth: 1))
    }

    // MARK: Film(DAY ごとに 4マス)

    private func dayBlock(_ day: TripRoomData.Day) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    Text("DAY \(day.number)").font(Typo.ui(900, 15)).foregroundStyle(.white.opacity(day.isFuture ? 0.4 : 1))
                    Text(day.date).font(Typo.ui(600, 13)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                if day.isToday { Text("あした 9:00 に ひらく").font(Typo.ui(800, 12)).foregroundStyle(tint) }
                else { Text(day.isFuture ? "まだ" : "\(day.opened)枚 ひらいた").font(Typo.ui(700, 12)).foregroundStyle(.white.opacity(0.4)) }
            }
            .padding(.horizontal, 16)
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { i in cell(day, i) }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder private func cell(_ day: TripRoomData.Day, _ i: Int) -> some View {
        let more = !day.isToday && !day.isFuture && i == 3 && day.opened > 4
        ZStack {
            Color(hex: day.isFuture ? "0F0F11" : "1C1C1E")
            if let p = day.photos[safe: i] ?? nil, !day.isFuture {
                // きょうの 分は 小さな 画像を 1回 だけ ぼかす(はっきり 出さない)
                Image(uiImage: day.isToday ? V64Images.blurred(key: "tr\(day.id)\(i)", source: p, maxPixel: 48, radius: 10, saturation: 1, brightness: 0.55) : p).resizable().scaledToFill()
            }
            if day.isToday { Image(systemName: "lock.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(.white.opacity(0.9)) }
            if more { Color.black.opacity(0.45); Text("+\(day.opened - 3)").font(Typo.ui(900, 19)).foregroundStyle(.white.opacity(0.9)) }
        }
        .frame(maxWidth: .infinity).aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay { if day.isFuture { RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1) } }
        .accessibilityHidden(true)
    }

    // MARK: 下の チャットの バー(1本 ・ いつも 見える)

    private var chatBar: some View {
        Button { Haptics.play(.click); onChat() } label: {
            HStack(spacing: 10) {
                if let f = data.chat?.face { face(f, 36) } else { Circle().fill(.white.opacity(0.12)).frame(width: 36, height: 36).overlay(Image(systemName: "bubble.left").font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.7))) }
                VStack(alignment: .leading, spacing: 1) {
                    Text(data.chat?.name ?? "チャット").font(Typo.ui(800, 12)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                    Text(data.chat?.text ?? "ここで はなそう").font(Typo.ui(700, 14)).foregroundStyle(.white).lineLimit(1)
                }
                Spacer(minLength: 6)
                if data.unread > 0 {
                    Text(verbatim: "\(min(99, data.unread))").font(Typo.ui(800, 12)).foregroundStyle(.white).frame(minWidth: 22, minHeight: 22)
                        .background(HVCardTint.badge, in: Capsule())
                }
                Image(systemName: "bubble.left.fill").font(.system(size: 17, weight: .bold)).foregroundStyle(Color(hex: "111113"))
                    .frame(width: 44, height: 44).background(tint, in: Circle())
            }
            .padding(.leading, 12).padding(.trailing, 10).frame(height: 64)
            .background(Color(hex: "1C1C1E").opacity(0.96), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
        }
        .buttonStyle(HVPress(scale: 0.98))
        .padding(.horizontal, 14).padding(.bottom, 26)
        .accessibilityLabel(data.unread > 0 ? "チャット ・ 未読 \(data.unread)" : "チャット")
    }
}
