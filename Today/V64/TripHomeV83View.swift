import SwiftUI

// P27(v83)B:Trip の ホーム(メイン)。見本:T12 T13。チャットは サブ(右下の 丸い ボタン)。
// 横スライドの Trip ページの カード ・ Home 下の Active ・ パスの Start は ぜんぶ ここへ ひらく。

struct TripHomeData {
    struct Member: Identifiable { let id: String; var name: String; var avatar: UIImage? }
    struct Day: Identifiable { let id: String; var label: String; var opened: Int; var photos: [UIImage?]; var isToday = false; var isFuture = false }
    var name: String
    var sub: String
    var dayNumber: Int
    var dayTotal: Int?
    var cover: UIImage?
    var members: [Member]
    var shotsToday: Int
    var shooters: [Member] = []
    var perDay = 23
    var days: [Day] = []
    var chatLine: (String, String)? = nil
    var unread = 0
}

struct TripHomeV83View: View {
    var data: TripHomeData
    var onClose: () -> Void = {}
    var onShoot: () -> Void = {}
    var onChat: () -> Void = {}
    var onQR: () -> Void = {}
    var onMore: () -> Void = {}
    var onInvite: () -> Void = {}
    var debugScrollY: CGFloat? = nil
    @State private var pos = ScrollPosition()
    @State private var pop = 0

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .topLeading) {
                Color(hex: "0A0A0B")
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        cover(w: g.size.width)
                        todayCard.padding(.horizontal, 16).padding(.top, 2)
                        Text("日ごとの フィルム").font(LF.inter(900, 20)).foregroundStyle(.white).padding(.horizontal, 16).padding(.top, 30)
                        ForEach(data.days) { day in dayBlock(day).padding(.top, 20) }
                        Color.clear.frame(height: 130)
                    }
                }
                .scrollPosition($pos)
                .onAppear { if let y = debugScrollY { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { pos.scrollTo(y: y) } } }
                chatSub.frame(width: g.size.width, height: g.size.height, alignment: .bottomTrailing).padding(.trailing, 0)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }

    private func cover(w: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Color(hex: "2A2326").overlay { if let c = data.cover { Image(uiImage: c).resizable().scaledToFill() } }.frame(width: w, height: 330).clipped()
            LinearGradient(stops: [.init(color: .black.opacity(0.45), location: 0), .init(color: .clear, location: 0.3), .init(color: Color(hex: "0A0A0B").opacity(0.2), location: 0.7), .init(color: Color(hex: "0A0A0B"), location: 1)], startPoint: .top, endPoint: .bottom).frame(width: w, height: 330)
            // v106 §4-1:もどる ・ TRIP の 字(せまい 時は 字を 小さく)・ 字つきの カプセル 2つ(招待 / 設定)。ボタンは 小さく しない
            HStack(spacing: 8) {
                glassButton("chevron.left", 44) { onClose() }
                Text(data.dayTotal.map { "TRIP ・ DAY \(data.dayNumber) / \($0)" } ?? "TRIP ・ DAY \(data.dayNumber)").font(LF.mono(12)).tracking(1.6).foregroundStyle(HV.lime)
                    .lineLimit(1).minimumScaleFactor(0.55).frame(maxWidth: .infinity)
                capsuleButton("qrcode", "招待") { onQR() }
                capsuleButton("gearshape", "設定") { onMore() }
            }.padding(.horizontal, 14).frame(width: w).offset(y: 50)
            VStack(alignment: .leading, spacing: 0) {
                Text(data.name).font(LF.serif(54)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.5)
                Text(data.sub).font(LF.mono(13)).foregroundStyle(.white.opacity(0.65)).padding(.top, 2)
                HStack(spacing: 10) {
                    HStack(spacing: -8) { ForEach(data.members.prefix(4)) { m in face(m, 30).overlay(Circle().strokeBorder(.black, lineWidth: 2)) } }
                    Button { Haptics.play(.tick); onInvite() } label: { Text("+ よぶ").font(LF.inter(700, 13)).foregroundStyle(.white.opacity(0.8)).padding(.horizontal, 12).frame(height: 30).background(.white.opacity(0.14), in: Capsule()) }.buttonStyle(.plain)
                }.padding(.top, 12)
            }.padding(.horizontal, 16).offset(y: 98)
        }.frame(width: w, height: 330, alignment: .topLeading)
    }

    private func capsuleButton(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button { Haptics.play(.tick); action() } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 14, weight: .bold))
                Text(label).font(LF.inter(800, 13))
            }.foregroundStyle(.white).padding(.leading, 12).padding(.trailing, 14).frame(height: 44)
                .background(.black.opacity(0.3), in: Capsule()).background(.ultraThinMaterial, in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
        }.buttonStyle(HVPress(scale: 0.94)).accessibilityLabel(label)
    }

    private func glassButton(_ icon: String, _ s: CGFloat, _ action: @escaping () -> Void) -> some View {
        Button { Haptics.play(.tick); action() } label: {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(.white).frame(width: s, height: s).background(.black.opacity(0.3), in: Circle()).background(.ultraThinMaterial, in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1))
        }.buttonStyle(HVPress(scale: 0.92))
    }

    private func face(_ m: TripHomeData.Member, _ s: CGFloat) -> some View {
        ZStack {
            if let a = m.avatar { Image(uiImage: a).resizable().scaledToFill() }
            else { Circle().fill(LinearGradient(colors: [Color(hex: "7FB0FF"), Color(hex: "61DD7A")], startPoint: .topLeading, endPoint: .bottomTrailing)).overlay(Text(String(m.name.prefix(1))).font(LF.inter(900, s * 0.42)).foregroundStyle(.white)) }
        }.frame(width: s, height: s).clipShape(Circle())
    }

    // 今日の カード
    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("TODAY ・ DAY \(data.dayNumber)").font(LF.mono(11)).tracking(2.2).foregroundStyle(.white.opacity(0.5))
                    HStack(alignment: .firstTextBaseline, spacing: 4) { Text("\(data.shotsToday)").font(LF.inter(900, 52)).foregroundStyle(.white); Text("/\(data.perDay)").font(LF.inter(800, 24)).foregroundStyle(.white.opacity(0.35)) }.padding(.top, 2)
                }
                Spacer()
                HStack(spacing: 10) {
                    HStack(spacing: -8) { ForEach(data.shooters.prefix(3)) { m in face(m, 32).overlay(Circle().strokeBorder(Color(hex: "141517"), lineWidth: 2)) } }
                    Text("が 撮った").font(LF.inter(700, 15)).foregroundStyle(.white.opacity(0.5))
                }.padding(.top, 36)
            }
            HStack(spacing: 3) {
                ForEach(0..<data.perDay, id: \.self) { i in
                    let on = i < data.shotsToday
                    RoundedRectangle(cornerRadius: 3).fill(on ? HV.lime : Color.white.opacity(0.08)).frame(height: 26).shadow(color: on ? HV.lime.opacity(0.45) : .clear, radius: 4)
                }
            }.padding(.top, 14)
            (Text("撮った 写真は ").foregroundColor(.white.opacity(0.5)) + Text("あした 9:00").foregroundColor(.white).bold() + Text(" に みんなで 現像").foregroundColor(.white.opacity(0.5))).font(LF.inter(600, 14)).padding(.top, 14)
            Button { Haptics.play(.shutter); onShoot() } label: {
                HStack(spacing: 12) { Image(systemName: "camera").font(.system(size: 20, weight: .semibold)); Text("Trip で 撮る").font(LF.inter(800, 20)) }
                    .foregroundStyle(HV.ink).frame(maxWidth: .infinity).frame(height: 58).background(HV.lime, in: Capsule())
            }.buttonStyle(HVPress(scale: 0.98)).padding(.top, 16)
        }
        .padding(18).background(Color(hex: "141517"), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.07), lineWidth: 1))
    }

    // 日ごとの フィルム
    private func dayBlock(_ day: TripHomeData.Day) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                let parts = day.label.components(separatedBy: " ・ ")
                HStack(spacing: 8) {
                    Text(parts[0]).font(LF.inter(900, 17)).foregroundStyle(.white.opacity(day.isFuture ? 0.4 : 1))
                    if parts.count > 1 { Text(parts[1]).font(LF.inter(600, 14)).foregroundStyle(.white.opacity(0.5)) }
                }
                Spacer()
                Text(day.isToday ? "あした 9:00 に ひらく" : (day.isFuture ? "まだ" : "\(day.opened)枚 ひらいた")).font(day.isToday ? LF.inter(800, 12.5) : LF.mono(12)).foregroundStyle(day.isToday ? HV.lime : .white.opacity(0.4))
            }.padding(.horizontal, 16)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(Array(day.photos.prefix(8).enumerated()), id: \.offset) { i, p in
                    ZStack {
                        Color(hex: "1C1C1E")
                        if day.isFuture { Stripes() }
                        else if i == 7 && day.opened > 8 { Color(hex: "1C1C1E") }
                        else if let p { Image(uiImage: day.isToday ? V64Images.blurred(key: "th\(day.id)\(i)", source: p, maxPixel: 48, radius: 10, saturation: 1, brightness: 0.55) : p).resizable().scaledToFill() }
                        if day.isToday { Image(systemName: "lock.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(.white) }
                        if i == 7 && day.opened > 8 { Text("+\(day.opened - 7)").font(LF.inter(900, 20)).foregroundStyle(.white.opacity(0.8)) }
                    }.aspectRatio(3 / 4, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }.padding(.horizontal, 16)
        }
    }

    // チャット(サブ)
    private var chatSub: some View {
        HStack(spacing: 10) {
            if let line = data.chatLine {
                (Text(line.0).bold().foregroundColor(.white) + Text(" " + line.1).foregroundColor(.white.opacity(0.85))).font(LF.inter(600, 14)).lineLimit(1)
                    .padding(.horizontal, 14).frame(height: 38).background(Color(hex: "1C1C1E"), in: Capsule())
            }
            Button { Haptics.play(.click); onChat() } label: {
                Image(systemName: "bubble.left").font(.system(size: 22, weight: .semibold)).foregroundStyle(.white).frame(width: 58, height: 58)
                    .background(.ultraThinMaterial, in: Circle()).background(Color(hex: "2A2A2C").opacity(0.7), in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1))
                    .overlay(alignment: .topTrailing) { if data.unread > 0 { Text("\(data.unread)").font(LF.inter(800, 12)).foregroundStyle(.white).frame(width: 22, height: 22).background(Color(hex: "FF3B30"), in: Circle()).offset(x: 4, y: -4) } }
            }.buttonStyle(HVPress(scale: 0.92)).accessibilityLabel("チャット")
        }.padding(.trailing, 16).padding(.bottom, 20)
    }
}

/// 斜めの しま(これから の こま)
private struct Stripes: View {
    var body: some View {
        Canvas { ctx, size in
            var x: CGFloat = -size.height
            while x < size.width { var p = Path(); p.move(to: CGPoint(x: x, y: size.height)); p.addLine(to: CGPoint(x: x + size.height, y: 0)); ctx.stroke(p, with: .color(.white.opacity(0.06)), lineWidth: 3); x += 10 }
        }
    }
}
