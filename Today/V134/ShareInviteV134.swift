import SwiftUI

// v134 Phase 5:シェアカード(のせる → ストーリーにのせる)と 招待(INVITE)。見本 screens/40〜43。

// MARK: シェアカード

enum ShareCardKind: String, CaseIterable, Identifiable {
    case film = "Film", time = "Time", clean = "Clean"
    var id: String { rawValue }
}

/// 9:16 の カード(270×480 の 比で かいて、書き出す 時は 拡大)
struct ShareCardArt: View {
    var kind: ShareCardKind
    var image: UIImage?
    var captured: Date
    var tag: String?

    private var waited: String { HomeV134Rules.waitedBig(captured: captured) }
    private var opened: Date { HomeV134Rules.unlockTime(captured: captured) }

    var body: some View {
        ZStack {
            switch kind {
            case .film: film
            case .time: time
            case .clean: clean
            }
        }
        .frame(width: 270, height: 480)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func photo(_ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack { Color(hex6: 0x1C1C1F); if let image { Image(uiImage: image).resizable().scaledToFill() } }.frame(width: w, height: h).clipped()
    }

    private var film: some View {
        ZStack {
            Color(hex6: 0x0E0E10)
            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 0) {
                    photo(220, 270).clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    HStack { Spacer(); DateStamp(text: HomeV134Rules.stamp(captured), size: 9) }.frame(height: 26).padding(.horizontal, 4)
                }
                .padding(.top, 8).padding(.horizontal, 8).padding(.bottom, 0)
                .background(LTColor.chekiFrame, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .padding(.top, 28)
                Text("見ないで待った").font(LTFont.ui(10, weight: .heavy)).foregroundStyle(LTColor.ink3).padding(.top, 18)
                Text(waited).font(LTFont.display(54)).foregroundStyle(LinearGradient(colors: [.white, LTColor.tagGray], startPoint: .top, endPoint: .bottom)).lineLimit(1).minimumScaleFactor(0.6)
                HStack(spacing: 4) {
                    Text("SHOT \(HomeV134Rules.clock(captured))").font(LTFont.stamp(8)).foregroundStyle(LTColor.ink3)
                    Rectangle().fill(Color.white.opacity(0.18)).frame(height: 1)
                    Text("OPENED \(HomeV134Rules.clock(opened))").font(LTFont.stamp(8)).foregroundStyle(LTColor.ink3)
                }.padding(.top, 2)
                HStack(spacing: 6) {
                    Image("LattagWordmark").renderingMode(.template).resizable().scaledToFit().frame(height: 13).foregroundStyle(.white)
                    Spacer()
                    Text(HomeV134Rules.dayLabel(captured).prefix(5)).font(LTFont.display(15)).foregroundStyle(LTColor.ink3)
                }.padding(.top, 8)
                Spacer(minLength: 0)
            }.padding(.horizontal, 22)
        }
    }

    private var time: some View {
        ZStack {
            photo(270, 480)
            LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                Text(waited).font(LTFont.display(72)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                Text("見ないで待った1枚").font(LTFont.ui(13, weight: .heavy)).foregroundStyle(.white.opacity(0.85))
                HStack {
                    Image("LattagWordmark").renderingMode(.template).resizable().scaledToFit().frame(height: 12).foregroundStyle(.white)
                    Spacer()
                    DateStamp(text: HomeV134Rules.stamp(captured), size: 9)
                }.padding(.top, 14)
            }.padding(22)
        }
    }

    private var clean: some View {
        ZStack {
            Color(hex6: 0xF6F5F0)
            VStack(spacing: 0) {
                photo(226, 302).clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous)).padding(.top, 34)
                HStack {
                    if let tag, !tag.isEmpty { Text("#\(tag)").font(LTFont.ui(12, weight: .heavy)).foregroundStyle(Color(hex6: 0x2A2A2E)) }
                    Spacer()
                    DateStamp(text: HomeV134Rules.stamp(captured), size: 10)
                }.frame(width: 226).padding(.top, 12)
                Spacer()
                Image("LattagWordmark").renderingMode(.template).resizable().scaledToFit().frame(height: 16).foregroundStyle(Color(hex6: 0x0E0E10))
                Text("lattag.app").font(LTFont.ui(10, weight: .heavy)).foregroundStyle(Color(hex6: 0x66666E)).padding(.top, 4).padding(.bottom, 26)
            }
        }
    }
}

struct ShareCardScreenV134: View {
    var image: UIImage?
    var captured: Date
    var tag: String?
    var onClose: () -> Void
    @State private var kind: ShareCardKind = .film
    @State private var exported: UIImage?
    @State private var showShare = false
    @State private var toast: String?

    var body: some View {
        ZStack {
            LTColor.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                ZStack {
                    Text("ストーリーにのせる").font(LTFont.ui(17, weight: .heavy)).foregroundStyle(.white)
                    HStack {
                        Button { LTHaptics.play(.tap); onClose() } label: {
                            Image(systemName: "xmark").font(.system(size: 17, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44).background(LTColor.surface3, in: Circle())
                        }.accessibilityLabel("とじる")
                        Spacer()
                    }
                }.padding(.horizontal, 16).padding(.top, 8)
                ShareCardArt(kind: kind, image: image, captured: captured, tag: tag)
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 10).padding(.top, 22)
                    .id(kind).transition(.opacity)
                HStack(spacing: 4) {
                    ForEach(ShareCardKind.allCases) { k in
                        Button { if kind != k { LTHaptics.play(.select); withAnimation(.easeOut(duration: 0.18)) { kind = k } } } label: {
                            Text(k.rawValue).font(LTFont.ui(16, weight: .heavy)).foregroundStyle(kind == k ? LTColor.limeInk : LTColor.ink2)
                                .frame(maxWidth: .infinity).frame(height: 44).background(kind == k ? Color.white : .clear, in: Capsule())
                        }.buttonStyle(.plain).accessibilityAddTraits(kind == k ? [.isSelected] : [])
                    }
                }.padding(4).background(LTColor.surface2, in: Capsule()).padding(.horizontal, 40).padding(.top, 22)
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Button { post() } label: {
                        Label("ストーリーにのせる", systemImage: "square.and.arrow.up").font(LTFont.ui(18, weight: .heavy)).foregroundStyle(LTColor.limeInk)
                            .frame(maxWidth: .infinity).frame(height: 58).background(LTColor.lime, in: RoundedRectangle(cornerRadius: LTRadius.button, style: .continuous))
                            .shadow(color: LTColor.lime.opacity(0.4), radius: 12, y: 7)
                    }.buttonStyle(HVPress(scale: 0.97))
                    Button { save() } label: {
                        Image(systemName: "arrow.down.to.line").font(.system(size: 20, weight: .bold)).foregroundStyle(.white).frame(width: 58, height: 58)
                            .background(LTColor.surface3, in: RoundedRectangle(cornerRadius: LTRadius.button, style: .continuous))
                    }.buttonStyle(HVPress(scale: 0.95)).accessibilityLabel("保存")
                }.padding(.horizontal, 14).padding(.bottom, 14)
            }
            if let toast {
                Text(toast).font(LTFont.ui(14, weight: .heavy)).foregroundStyle(.white).padding(.horizontal, 18).frame(height: 40).lgGlass(radius: 20)
                    .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 100).transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showShare) { if let exported { ShareSheet(activityItems: [exported]) { _ in showShare = false }.presentationDetents([.medium, .large]) } }
    }

    /// 9:16(1080×1920)の 1枚に 書き出す。写真は チェキの 質感の まま
    @MainActor private func render() -> UIImage? {
        let r = ImageRenderer(content: ShareCardArt(kind: kind, image: image, captured: captured, tag: tag))
        r.scale = 4
        r.isOpaque = false
        return r.uiImage
    }

    private func post() { guard let img = render() else { return }; exported = img; LTHaptics.play(.posted); showShare = true }

    private func save() {
        guard let img = render() else { return }
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        LTHaptics.play(.posted)
        withAnimation { toast = "保存しました" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { toast = nil } }
    }
}

// MARK: 招待(INVITE)

struct InviteV134View: View {
    var name: String
    var photos: [UIImage?]
    var onSend: () -> Void
    var onCopy: () -> Void
    var onQR: () -> Void
    var onClose: () -> Void
    @State private var pick = 0
    @State private var copied = false

    /// 送る 文(文面だけ v134。リンクの 形は 今までの まま = `ShareTextV108.friend`)
    static func body(name: String) -> String { "\(name)の「きのう」が届いています。あなたも1枚撮ると、あしたの9:00にいっしょにひらきます。" }

    var body: some View {
        ZStack {
            LTColor.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { LTHaptics.play(.tap); onClose() } label: { Image(systemName: "xmark").font(.system(size: 17, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44).background(LTColor.surface3, in: Circle()) }.accessibilityLabel("とじる")
                    Spacer()
                    Button { LTHaptics.play(.tap); onQR() } label: { Image(systemName: "qrcode").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white).frame(width: 44, height: 44).background(LTColor.surface3, in: Circle()) }.accessibilityLabel("QRを見せる")
                }.padding(.horizontal, 16).padding(.top, 8)
                DisplayTitle(text: "Invite", size: 60).padding(.horizontal, 22).padding(.top, 14)
                Text("ぼかした1枚を送る。ひらくのは、いっしょに。").font(LTFont.ui(15, weight: .heavy)).foregroundStyle(LTColor.ink3).padding(.horizontal, 22).padding(.top, 4)
                if !photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(photos.prefix(4).enumerated()), id: \.offset) { i, p in
                                Button { LTHaptics.play(.select); pick = i } label: {
                                    Group { if let p { Image(uiImage: p).resizable().scaledToFill() } else { Color(hex6: 0x2A2A2E) } }
                                        .frame(width: 66, height: 88).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white, lineWidth: pick == i ? 2.5 : 0).padding(-3))
                                        .padding(3)
                                }.buttonStyle(.plain).accessibilityLabel("写真\(i + 1)").accessibilityAddTraits(pick == i ? [.isSelected] : [])
                            }
                        }.padding(.horizontal, 20).padding(.vertical, 6)
                    }.padding(.top, 20)
                }
                VStack(spacing: 10) {
                    Text("こう届きます").font(LTFont.ui(13, weight: .heavy)).foregroundStyle(LTColor.ink3)
                    HStack { Spacer(minLength: 40); bubble }
                    HStack { Spacer(); Text("既読 12:31").font(LTFont.ui(11, weight: .heavy)).foregroundStyle(LTColor.ink3) }
                }
                .padding(16).background(Color(hex6: 0x0F1712), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(LTColor.hairline, lineWidth: 1))
                .padding(.horizontal, 14).padding(.top, 20)
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Button { LTHaptics.play(.tap); onSend() } label: {
                        Label("リンクを送る", systemImage: "paperplane").font(LTFont.ui(18, weight: .heavy)).foregroundStyle(LTColor.limeInk)
                            .frame(maxWidth: .infinity).frame(height: 58).background(LTColor.lime, in: RoundedRectangle(cornerRadius: LTRadius.button, style: .continuous))
                            .shadow(color: LTColor.lime.opacity(0.4), radius: 12, y: 7)
                    }.buttonStyle(HVPress(scale: 0.97))
                    Button { LTHaptics.play(.posted); onCopy(); copied = true; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false } } label: {
                        Image(systemName: copied ? "checkmark" : "link").font(.system(size: 20, weight: .bold)).foregroundStyle(.white).frame(width: 58, height: 58)
                            .background(LTColor.surface3, in: RoundedRectangle(cornerRadius: LTRadius.button, style: .continuous))
                    }.buttonStyle(HVPress(scale: 0.95)).accessibilityLabel(copied ? "コピーしました" : "リンクをコピー")
                }.padding(.horizontal, 14).padding(.bottom, 14)
            }
        }
        .preferredColorScheme(.dark)
    }

    /// 見本(リンクプレビューの 画像は サーバー側が 要る ため、今回は 見本だけ)
    private var bubble: some View {
        VStack(spacing: 0) {
            Text(Self.body(name: name)).font(LTFont.ui(15, weight: .heavy)).foregroundStyle(.white).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color(hex6: 0x2FBF63))
            ZStack {
                if photos.indices.contains(pick), let p = photos[pick] { Image(uiImage: p).resizable().scaledToFill().blur(radius: 30).scaleEffect(1.3) } else { Color(hex6: 0x4A4D5C) }
                HashLensView(size: 52, glowing: false)
            }.frame(height: 130).clipped()
            VStack(alignment: .leading, spacing: 2) {
                Text("\(name)のきのう · Lattag").font(LTFont.ui(15, weight: .heavy)).foregroundStyle(.black)
                Text("lattag.app").font(LTFont.ui(12, weight: .heavy)).foregroundStyle(Color(hex6: 0x7A7A82))
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)).frame(maxWidth: 270)
    }
}
