import SwiftUI

/// v110 §4:Friends(作りなおし)。今日の あなた → 友だちの 列 → きのうの 1枚(チェキ)→ まだ の 人 → さいご。
/// リアクション(すき ・ いいね ・ すごい)と「つつく」は 作らない(しくみが ない)。「まだ の 人」の ボタンは 1対1 チャットへ。
struct FriendsTabV110: View {
    let input: YesterdayV64Input
    let actions: YesterdayV64Actions
    let w: CGFloat
    var onViewPhoto: (YesterdayV64Input.Cell) -> Void = { _ in }
    var onOpenMine: (Int) -> Void = { _ in }
    var invite: () -> AnyView = { AnyView(EmptyView()) }
    var lockBand: () -> AnyView = { AnyView(EmptyView()) }
    @Binding var position: ScrollPosition
    var onScroll: (CGFloat) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wiggle: String?
    @State private var note: String?
    @State private var popToday = false

    private var published: [YesterdayV64Input.Post] { input.posts.filter(\.published) }
    private var pending: [YesterdayV64Input.Post] { input.posts.filter { !$0.published } }
    private var noFriends: Bool { input.friendCount == 0 && input.posts.isEmpty }
    private var hasMine: Bool { !input.mine.isEmpty }
    private static let stickers: [(PopShape, Color)] = [(.heart, PopColor.pink), (.star, PopColor.sun), (.spark, PopColor.sky), (.flower, PopColor.pink), (.hash, PopColor.lime)]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: 118)
                todayCard.padding(.horizontal, 16)
                if noFriends { invite().padding(.top, 26) }
                else { friendRow.padding(.top, 18) }
                if input.locked && hasMine { lockBand().padding(.horizontal, 16).padding(.top, 14) }
                if !noFriends || hasMine {
                    HStack(spacing: 10) {
                        Text("きのうの 1枚").font(Typo.ui(900, 22)).foregroundStyle(.white)
                        PopTag(text: "9:00 OPEN", color: PopColor.sun, tilt: -3)
                        Spacer(minLength: 0)
                    }.padding(.horizontal, 18).padding(.top, 22)
                    VStack(spacing: 22) {
                        if hasMine { mineCard }
                        ForEach(Array(published.enumerated()), id: \.element.id) { i, p in postCard(p, index: i + (hasMine ? 1 : 0)).id(p.id) }
                    }.padding(.top, 14)
                    if !pending.isEmpty { pendingCard.padding(.horizontal, 16).padding(.top, 26) }
                }
                if noFriends { FeedEndV106(empty: true, shotToday: input.shotsUsed > 0, onAdd: { actions.openFriends() }, onShoot: { actions.shoot() }) }
                else { FeedEndV110() }
                Color.clear.frame(height: 130)
            }
        }
        .scrollHaptics()
        .onScrollGeometryChange(for: CGFloat.self) { max(0, $0.contentOffset.y + $0.contentInsets.top) } action: { _, v in onScroll(v) }
        .scrollPosition($position)
        .background(Color.black)
        .overlay(alignment: .top) {
            if let note {
                Text(note).font(Typo.ui(800, 13)).foregroundStyle(Color(hex: "111113")).padding(.horizontal, 14).frame(height: 36)
                    .background(PopColor.sun, in: Capsule()).overlay(Capsule().strokeBorder(.white, lineWidth: 2)).padding(.top, 126).transition(.scale.combined(with: .opacity))
            }
        }
        .onChange(of: input.shotsUsed) { old, new in
            guard old == 0, new > 0, !reduceMotion else { return }
            popToday = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { popToday = false }
        }
    }

    // MARK: 4-1 今日の あなた

    private var limit: Int { FilmRoll.shotsPerDay }
    private var left: Int { max(0, limit - input.shotsUsed) }

    private var todayCard: some View {
        HStack(alignment: .center, spacing: 16) {
            todayCheki.frame(width: 118).padding(.leading, 6)
            VStack(alignment: .leading, spacing: 8) {
                Text("TODAY'S ROLL").font(Typo.label(10)).tracking(2).foregroundStyle(PopColor.lime)
                Text(input.shotsUsed == 0 ? "今日の 1枚を 撮ろう" : (left > 0 ? "あと \(left)枚 撮れる" : "今日の 3枚、撮りおわり")).font(Typo.ui(900, 21)).foregroundStyle(.white)
                    .lineLimit(2).minimumScaleFactor(0.8).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    ForEach(0..<limit, id: \.self) { i in
                        Circle().fill(i < input.shotsUsed ? PopColor.lime : .clear).overlay(Circle().strokeBorder(i < input.shotsUsed ? PopColor.lime : .white.opacity(0.3), lineWidth: 1.5)).frame(width: 12, height: 12)
                    }
                    Text("\(input.shotsUsed) / \(limit)").font(Typo.label(11)).foregroundStyle(.white.opacity(0.6)).padding(.leading, 4)
                }
                TimelineView(.periodic(from: .now, by: 60)) { ctx in
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold))
                        Text("9:00 に ひらく ・ あと \(Self.untilNine(ctx.date))").font(Typo.ui(600, 12)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                    }.foregroundStyle(.white.opacity(0.62))
                }
                if left > 0 {
                    PopButton(title: "撮る", kind: .lime, small: true) { actions.shoot() }.padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 18).padding(.trailing, 14)
        .background {
            ZStack {
                PopColor.card
                RadialGradient(colors: [PopColor.lime.opacity(0.16), .clear], center: .topLeading, startRadius: 0, endRadius: 220)
                RadialGradient(colors: [PopColor.pink.opacity(0.14), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 220)
            }.clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
    }

    private var todayCheki: some View {
        Button { Haptics.play(input.shotsUsed == 0 ? .click : .tick); if left > 0 { actions.shoot() } } label: {
            ChekiFrame(caption: input.shotsUsed == 0 ? "まだ 0枚" : "今日の 1枚", captionSize: 15, tilt: -6) {
                if input.shotsUsed == 0 {
                    ZStack { Color(hex: "ECE9E0"); Image(systemName: "camera").font(.system(size: 26, weight: .regular)).foregroundStyle(Color(hex: "9A968C")) }
                } else if let img = input.todayPhoto {
                    Image(uiImage: V64Images.blurred(key: "today110", source: img, maxPixel: 48, radius: 14, saturation: 1.1, brightness: 0.85)).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [Color(hex: "D9A27A"), Color(hex: "8A5E7A"), Color(hex: "3E3A5A")], startPoint: .top, endPoint: .bottom).blur(radius: 10).scaleEffect(1.3)
                }
            }
            .overlay(alignment: .top) { PopTape(color: PopColor.sun, tilt: -8).offset(y: -12) }
            .overlay(alignment: .topTrailing) { PopSticker(shape: .star, color: PopColor.pink, size: 26, tilt: 12).offset(x: 10, y: -12) }
        }
        .buttonStyle(PopPressStyle())
        .scaleEffect(popToday ? 0.7 : 1)
        .animation(popToday ? nil : .spring(response: 0.5, dampingFraction: 0.5), value: popToday)
        .accessibilityLabel(input.shotsUsed == 0 ? "今日の 1枚を 撮る" : "今日の 1枚")
    }

    private static func untilNine(_ now: Date) -> String {
        let next = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 9, minute: 0), matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)
        let m = max(0, Int(next.timeIntervalSince(now) / 60))
        return String(format: "%d:%02d", m / 60, m % 60)
    }

    // MARK: 4-2 友だちの 列

    private var friendRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                Button { Haptics.play(.sel); actions.openFriends() } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").font(.system(size: 19, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 60, height: 60).background(PopColor.raised, in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.08), lineWidth: 1))
                        Text("さがす").font(Typo.ui(700, 11)).foregroundStyle(.white.opacity(0.7))
                    }.frame(minWidth: 52)
                }.buttonStyle(PopPressStyle()).accessibilityLabel("友だちを さがす")
                ForEach(Array(input.posts.enumerated()), id: \.element.id) { i, p in
                    let color = PopColor.trip(i)
                    Button {
                        if p.published { Haptics.play(.pop); withAnimation(.easeInOut(duration: 0.4)) { position.scrollTo(id: p.id, anchor: .top) }; shake(p.id) }
                        else { Haptics.play(.warn); flash("まだ 撮って いません") }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack(alignment: .bottomTrailing) {
                                ZStack {
                                    if p.published { Circle().strokeBorder(color, lineWidth: 3) }
                                    else { Circle().strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [3, 4])) }
                                    PopAvatar(image: p.avatar, name: p.name, size: 52).opacity(p.published ? 1 : 0.45)
                                }.frame(width: 60, height: 60)
                                if p.published { PopSticker(shape: .hash, color: color, size: 14, tilt: 8).offset(x: 4, y: 4) }
                            }
                            Text(p.name).font(Typo.ui(p.published ? 700 : 600, 11)).foregroundStyle(.white.opacity(p.published ? 0.9 : 0.45)).lineLimit(1).frame(maxWidth: 60)
                        }.frame(minWidth: 52)
                    }.buttonStyle(PopPressStyle())
                }
            }.padding(.horizontal, 18)
        }
    }

    private func shake(_ id: String) {
        guard !reduceMotion else { return }
        wiggle = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { if wiggle == id { wiggle = nil } }
    }
    private func flash(_ t: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { note = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation(.easeOut(duration: 0.2)) { note = nil } }
    }

    // MARK: 4-3 きのうの 1枚

    private func cheki(_ img: UIImage?, hidden: Bool, key: String, caption: String, index: Int, wiggleID: String) -> some View {
        let tilt = (index % 2 == 0 ? -1.5 : 1.5)
        let s = Self.stickers[index % Self.stickers.count]
        return ChekiFrame(caption: caption, captionSize: 26, tilt: tilt) {
            ZStack {
                Color(hex: "1A1A1D")
                if let img {
                    if hidden {
                        Image(uiImage: V64Images.blurred(key: key, source: img, maxPixel: 48, radius: 14, saturation: 1.0, brightness: 0.7)).resizable().scaledToFill()
                        Image(systemName: "lock.fill").font(.system(size: 26, weight: .semibold)).foregroundStyle(.white).shadow(color: .black.opacity(0.4), radius: 6)
                    } else { Image(uiImage: img).resizable().scaledToFill() }
                } else if hidden {
                    Image(systemName: "lock.fill").font(.system(size: 26, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                } else { Shimmer() }
            }
        }
        .overlay(alignment: .topTrailing) { PopSticker(shape: s.0, color: s.1, size: 40, tilt: 10).offset(x: 10, y: -14) }
        .overlay(alignment: .topLeading) { if index == 0 { PopTape(color: PopColor.sky, tilt: -38).offset(x: -18, y: 4) } }
        .rotationEffect(.degrees(wiggle == wiggleID ? 2.5 : 0))
        .animation(wiggle == wiggleID ? .easeInOut(duration: 0.08).repeatCount(6, autoreverses: true) : .default, value: wiggle)
        .padding(.horizontal, 22)
    }

    private func postCard(_ post: YesterdayV64Input.Post, index: Int) -> some View {
        let big = post.photos.first
        let hidden = input.locked
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                PopAvatar(image: post.avatar, name: post.name, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(post.name).font(Typo.ui(800, 15)).foregroundStyle(.white)
                    Text(big?.time ?? "").font(Typo.label(10.5)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer(minLength: 0)
                Text("···").font(Typo.ui(900, 18)).foregroundStyle(.white).frame(width: 44, height: 44)
            }.padding(.horizontal, 18)
            cheki(big?.image, hidden: hidden, key: "y110\(post.id)", caption: hidden ? "" : (post.caption ?? ""), index: index, wiggleID: post.id)
                .onTapGesture {
                    guard !hidden, let big else { return }
                    Haptics.play(.tick)
                    onViewPhoto(.init(id: big.id, photo: big.image, name: post.name, time: big.time, tag: big.tag, music: big.music))
                }
            if !post.friendID.isEmpty {
                HStack { Spacer(); PopButton(title: "チャット", kind: .ghost, small: true) { actions.openChat(post.friendID, post.name) } }.padding(.horizontal, 22)
            }
        }
    }

    private var mineCard: some View {
        let main = input.mine.last ?? input.mine.first
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                PopAvatar(image: input.avatar, name: input.avatarName, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text("あなた").font(Typo.ui(800, 15)).foregroundStyle(.white)
                    Text(main?.time ?? "").font(Typo.label(10.5)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, 18)
            cheki(main?.image, hidden: false, key: "m110", caption: input.mineCaption ?? "", index: 0, wiggleID: "mine")
                .onTapGesture { Haptics.play(.pop); onOpenMine(max(0, input.mine.count - 1)) }
        }
    }

    // MARK: 4-4 まだ の 人

    private var pendingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("まだ の 人").font(Typo.ui(900, 18)).foregroundStyle(.white)
                Text("\(pending.count)人").font(Typo.ui(700, 11)).foregroundStyle(.white.opacity(0.6)).padding(.horizontal, 8).frame(height: 20).background(.white.opacity(0.08), in: Capsule())
            }
            ForEach(pending) { p in
                HStack(spacing: 12) {
                    PopAvatar(image: p.avatar, name: p.name, size: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.name).font(Typo.ui(800, 15)).foregroundStyle(.white).lineLimit(1)
                        Text("まだ 公開して いません").font(Typo.ui(500, 11.5)).foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer(minLength: 4)
                    if !p.friendID.isEmpty { PopButton(title: "チャット", kind: .sky, small: true) { actions.openChat(p.friendID, p.name) } }
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(PopColor.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

/// 写真の 丸(無ければ 名前の 1文字 + 色)。キャラクターは 使わない。
struct PopAvatar: View {
    var image: UIImage?
    var name: String
    var size: CGFloat
    var body: some View {
        ZStack {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Circle().fill(LinearGradient(colors: [Color(hex: "3A3A3F"), Color(hex: "26262A")], startPoint: .top, endPoint: .bottom)).overlay(Text(String(name.prefix(1))).font(Typo.ui(900, size * 0.4)).foregroundStyle(.white)) }
        }.frame(width: size, height: size).clipShape(Circle())
    }
}

/// v110 §4-5:さいご。4色の フィルムの コマが ゆっくり 上下 + ステッカー 2つ。
struct FeedEndV110: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || scenePhase != .active)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                HStack(spacing: 8) {
                    ForEach(Array(PopColor.tripCycle.enumerated()), id: \.offset) { i, c in
                        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(c).frame(width: 40, height: 32)
                            .offset(y: reduceMotion ? 0 : CGFloat(sin(t * (2 * .pi / 2.4) + Double(i) * 0.7)) * 3)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12).background(Color(hex: "1A1A1D"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topLeading) { PopSticker(shape: .spark, color: PopColor.sun, size: 22, tilt: -8).offset(x: -10, y: -14) }
                .overlay(alignment: .trailing) { PopSticker(shape: .flower, color: PopColor.pink, size: 24, tilt: 10).offset(x: 12, y: -6) }
            }
            Text("END OF ROLL").font(Typo.label(10)).tracking(2).foregroundStyle(PopColor.lime).padding(.top, 22)
            Text("きのうの フィルムは ここまで").font(Typo.ui(900, 20)).foregroundStyle(.white).multilineTextAlignment(.center).padding(.top, 8)
            Text("あした 9:00 に、また みんなの 1枚が ひらきます").font(Typo.ui(600, 12.5)).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center).padding(.top, 6)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 38)
    }
}
