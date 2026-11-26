import SwiftUI

// v134 Phase 2:あなたのきのう(カード)と 投稿(写真 + タグ + 返信)。

/// あなたのきのう:ぼかした サムネ 3枚の 重なり + 鍵 / 文言 / 右に ライムの「撮る」。ひらいた 写真は はっきり + ライムの 細い 輪。
struct YesterdayCardV134: View {
    var input: YesterdayV64Input
    var onShoot: () -> Void

    private var opened: Int { input.mine.filter(\.opened).count }
    private var card: HomeV134Rules.YesterdayCard {
        HomeV134Rules.yesterdayCard(opened: opened, total: input.mine.count, shots: input.shotsUsed, night: HomeV134Rules.isNight(input.now))
    }

    var body: some View {
        HStack(spacing: 14) {
            thumbs
            VStack(alignment: .leading, spacing: 4) {
                Text("あなたのきのう").font(LTFont.ui(18, weight: .heavy)).foregroundStyle(.white)
                Text(card.line1).font(LTFont.ui(13)).foregroundStyle(LTColor.ink2).lineLimit(2).minimumScaleFactor(0.85)
                if let l2 = card.line2 { Text(l2).font(LTFont.ui(12)).foregroundStyle(LTColor.ink3).lineLimit(2) }
            }
            Spacer(minLength: 4)
            button
        }
        .padding(12).frame(minHeight: 100)
        .background(LTColor.surface1, in: RoundedRectangle(cornerRadius: LTRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: LTRadius.card, style: .continuous).strokeBorder(LTColor.hairline, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    private var thumbs: some View {
        let items = Array(input.mine.prefix(3))
        return ZStack(alignment: .bottomTrailing) {
            ZStack(alignment: .leading) {
                if items.isEmpty {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.06)).frame(width: 56, height: 74)
                }
                ForEach(Array(items.enumerated()), id: \.element.id) { i, p in
                    thumb(p).offset(x: CGFloat(i) * 15).zIndex(Double(i))
                }
            }.frame(width: 56 + CGFloat(max(0, items.count - 1)) * 15, height: 76, alignment: .leading)
            if opened < max(1, input.mine.count) {
                Image(systemName: "lock.fill").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 24, height: 24).background(.black, in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
                    .offset(x: 4, y: 4)
            }
        }.accessibilityHidden(true)
    }

    private func thumb(_ p: YesterdayV64Input.Photo) -> some View {
        Group {
            if let img = p.image { Image(uiImage: img).resizable().scaledToFill().blur(radius: p.opened ? 0 : 7).saturation(p.opened ? 1 : 0.7) }
            else { Color(hex6: 0x2A2A2E) }
        }
        .frame(width: 56, height: 74).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(p.opened ? LTColor.lime : Color.black, lineWidth: p.opened ? 1.2 : 2))
    }

    @ViewBuilder private var button: some View {
        switch card.button {
        case .shoot:
            Button(action: onShoot) {
                Text("撮る").font(LTFont.ui(16, weight: .heavy)).foregroundStyle(LTColor.limeInk).frame(width: 78, height: 48)
                    .background(LTColor.lime, in: Capsule()).shadow(color: LTColor.lime.opacity(0.4), radius: 10, y: 5)
            }.buttonStyle(HVPress(scale: 0.95))
        case .tomorrow: grayButton("また明日")
        case .from9: grayButton("9:00から")
        }
    }

    private func grayButton(_ t: String) -> some View {
        Text(t).font(LTFont.ui(14, weight: .heavy)).foregroundStyle(LTColor.ink2).padding(.horizontal, 14).frame(height: 44)
            .background(Color.white.opacity(0.08), in: Capsule()).accessibilityAddTraits(.isStaticText)
    }
}

/// 投稿 1つ:アバター + 名前 + 「16:42に撮った」/ 写真(3:4 ・ 角丸 24)/ タグ / 返信
struct PostV134: View {
    var post: YesterdayV64Input.Post
    var onReply: () -> Void
    @State private var index = 0

    private var photo: YesterdayV64Input.Photo { post.photos[min(index, post.photos.count - 1)] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Group { if let a = post.avatar { Image(uiImage: a).resizable().scaledToFill() } else { Circle().fill(HomeV134Parts.color(post.name)).overlay(Text(String(post.name.prefix(1))).font(LTFont.ui(16, weight: .heavy)).foregroundStyle(.white)) } }
                    .frame(width: 36, height: 36).clipShape(Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(post.name).font(LTFont.ui(15.5, weight: .heavy)).foregroundStyle(.white)
                    if let c = photo.captured { Text("\(HomeV134Rules.clock(c))に撮った").font(LTFont.ui(12.5)).foregroundStyle(LTColor.ink3) }
                }
                Spacer()
            }.padding(.horizontal, 14)
            photoView.padding(.horizontal, 10).padding(.top, 10)
            chips.padding(.horizontal, 14).padding(.top, 12)
            if !post.friendID.isEmpty {
                Button { LTHaptics.play(.tap); onReply() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.left").font(.system(size: 13, weight: .semibold))
                        Text("\(post.name)に返信").font(LTFont.ui(15))
                        Spacer()
                    }.foregroundStyle(LTColor.ink3).padding(.horizontal, 16).frame(height: 48)
                    .background(LTColor.surface2, in: Capsule())
                }.buttonStyle(HVPress(scale: 0.98)).padding(.horizontal, 14).padding(.top, 10)
                    .accessibilityLabel("\(post.name)に返信")
            }
        }
        .id("post-\(post.id)")
        .padding(.bottom, 8)
    }

    private var photoView: some View {
        let p = photo
        return ZStack {
            Color(hex6: 0x1A1A1D)
            if let img = p.image { Image(uiImage: img).resizable().scaledToFill().blur(radius: p.opened ? 0 : 24).saturation(p.opened ? 1 : 0.6) }
            if !p.opened { Image(systemName: "lock.fill").font(.system(size: 22, weight: .semibold)).foregroundStyle(.white.opacity(0.85)) }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .overlay(alignment: .top) {
            if post.photos.count > 1 {
                HStack(spacing: 5) {
                    ForEach(0..<post.photos.count, id: \.self) { i in Capsule().fill(i <= index ? Color.white : Color.white.opacity(0.35)).frame(height: 3) }
                }.padding(.horizontal, 12).padding(.top, 10)
            }
        }
        .overlay(alignment: .topLeading) {
            if p.opened, let c = p.captured {
                Label("\(HomeV134Rules.waitedLabel(captured: c)) 待った", systemImage: "clock").font(LTFont.ui(13, weight: .heavy)).foregroundStyle(.white)
                    .padding(.horizontal, 12).frame(height: 30).lgGlass(radius: 15)
                    .padding(.leading, 12).padding(.top, post.photos.count > 1 ? 26 : 14)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if p.opened, let c = p.captured { DateStamp(text: HomeV134Rules.stamp(c)).padding(.trailing, 16).padding(.bottom, 14) }
        }
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.photo, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { location in
            // 左 ・ 右の タップで 前後の 写真
            guard post.photos.count > 1 else { return }
            let w = UIScreen.main.bounds.width - 20
            let next = location.x < w * 0.4 ? max(0, index - 1) : min(post.photos.count - 1, index + 1)
            if next != index { LTHaptics.play(.select); index = next }
        }
        .accessibilityLabel("\(post.name)の写真 \(min(index, post.photos.count - 1) + 1)/\(post.photos.count)")
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let t = photo.tag { TagChip(text: t, hashColor: HomeV134Parts.hashColor(t)) }
                if let m = photo.music {
                    HStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(LinearGradient(colors: [LTColor.tagPink, Color(hex6: 0x7F5BFF)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 22, height: 22)
                        Text(m.artist.isEmpty ? m.title : "\(m.title) — \(m.artist)").font(LTFont.ui(13)).foregroundStyle(LTColor.ink2).lineLimit(1)
                    }.padding(.horizontal, 8).frame(height: 32).background(Color.white.opacity(0.07), in: Capsule())
                }
            }
        }
    }
}

/// 今日の フィルム(シート)
struct TodaysFilmSheetV134: View {
    var shotTimes: [Date]
    var status: HomeV134Rules.FilmStatus
    var now: Date
    @Environment(\.dismiss) private var dismiss

    private var progress: Double {
        guard let first = shotTimes.min() else { return 0 }
        let total = status.target.timeIntervalSince(first)
        return total > 0 ? min(1, max(0.02, now.timeIntervalSince(first) / total)) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                DisplayTitle(text: "Today's Film", size: 46)
                Spacer()
                Button { LTHaptics.play(.tap); dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44).background(Color.white.opacity(0.1), in: Circle())
                }.accessibilityLabel("閉じる")
            }.padding(.top, 20)
            HStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { i in
                    let t = i < shotTimes.count ? shotTimes.sorted()[i] : nil
                    VStack {
                        Spacer(minLength: 0)
                        Text(t.map(HomeV134Rules.clock) ?? "–").font(LTFont.stamp(12)).foregroundStyle(t == nil ? LTColor.ink3 : Color(hex6: 0x7A766D)).padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity).aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .background {
                        if t != nil {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(LTColor.chekiFrame)
                                .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 6, style: .continuous).fill(LinearGradient(colors: [LTColor.milkTop, LTColor.milkBottom], startPoint: .topLeading, endPoint: .bottomTrailing)).padding(8).padding(.bottom, 26) }
                        } else { RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(hex6: 0x0B0B0D)).overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1.5)) }
                    }
                }
            }.padding(.top, 22).padding(.horizontal, 6)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(LTColor.lime).frame(width: max(6, g.size.width * progress))
                }
            }.frame(height: 6).padding(.top, 26)
            HStack {
                Text(shotTimes.min().map { "撮った \(HomeV134Rules.clock($0))" } ?? " ").font(LTFont.ui(13)).foregroundStyle(LTColor.ink3)
                Spacer()
                Text("あした 9:00").font(LTFont.ui(13)).foregroundStyle(LTColor.ink3)
            }.padding(.top, 8)
            Spacer(minLength: 0)
            HStack { Spacer(); Text(timerInterval: now...max(status.target, now.addingTimeInterval(1)), countsDown: true).font(LTFont.display(84)).monospacedDigit().foregroundStyle(LinearGradient(colors: [.white, LTColor.tagGray], startPoint: .top, endPoint: .bottom)); Spacer() }
            Text("中身は、あしたの9:00まで見えない").font(LTFont.ui(15)).foregroundStyle(LTColor.ink3).frame(maxWidth: .infinity).padding(.top, 6)
            Spacer(minLength: 0)
        }.padding(.horizontal, 18).padding(.bottom, 24)
    }
}
