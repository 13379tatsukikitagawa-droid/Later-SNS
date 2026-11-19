import SwiftUI

// v105 F05:友だちの カード。左右 下 8pt あけた「うく カード」(角丸 40 ・ ふち 白 7%)。
// 背景は `#111113` の 単色 1枚だけ(material を 使わない)。うしろの 暗さは 黒 62%(ぼかし なし)。
// チェキは カードの 中(負の offset / padding を 使わない)。高さ = 中身。
// 出し方:`FriendCardOverlay`(呼ぶ 画面の ZStack に 重ねる)。動きは transform と opacity だけ。

struct FriendCardV82Sheet: View {
    let name: String
    var avatar: UIImage?
    var tag: String?
    var city: String?
    /// `@id`(なければ 出さない)
    var username: String?
    /// `since Oct 16`(なければ 出さない)
    var since: String?
    /// 共通の 友だち(いなければ 出さない)
    var mutualCount: Int = 0
    var times: [String]
    var mosaics: [UIImage?]
    var onChat: () -> Void = {}
    var onTrip: () -> Void = {}
    var onMore: () -> Void = {}
    var onClose: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var shot: Bool { !times.isEmpty }
    private let cream = Color(hex: "F4F1EA")

    var body: some View {
        VStack(spacing: 0) {
            topRow.padding(.top, 18).stagger(appeared, 0, reduceMotion)
            HStack(alignment: .center, spacing: 14) {
                cheki
                VStack(alignment: .leading, spacing: 0) {
                    Text(name).font(LF.serif(34)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                    if let username { Text("@\(username)").font(LF.mono(12)).foregroundStyle(.white.opacity(0.55)).lineLimit(1).padding(.top, 2) }
                    if let since { Text("since \(since)").font(LF.mono(11, bold: false)).foregroundStyle(.white.opacity(0.4)).padding(.top, 2) }
                    if let tag { sticker("#\(tag)", Color(hex: "EE5E9C"), -7, delay: 0.42).padding(.top, 10) }
                    if let city { sticker(city, Color(hex: "3A6EA5"), 4, delay: 0.53).padding(.top, 6) }
                    if mutualCount > 0 { mutual.padding(.top, 10) }
                }
                .stagger(appeared, 1, reduceMotion)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20).padding(.top, 8)
            today.padding(.horizontal, 16).padding(.top, 14).stagger(appeared, 2, reduceMotion)
            HStack(spacing: 8) {
                action("bubble.left", "Chat", cream, Color(hex: "0B0C0D"), flex: true) { onChat() }
                action("suitcase", "Trip", Color(hex: "1C1C1E"), .white, flex: false) { onTrip() }
                action("ellipsis", "more", Color(hex: "1C1C1E"), .white, flex: false) { onMore() }
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 16).stagger(appeared, 3, reduceMotion)
        }
        .background(Color(hex: "111113"), in: RoundedRectangle(cornerRadius: 40, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).strokeBorder(.white.opacity(0.07), lineWidth: 1))
        .environment(\.colorScheme, .dark)
        .onAppear {
            Haptics.play(.pop)
            appeared = true
        }
    }

    // MARK: 上の 行

    private var topRow: some View {
        HStack(spacing: 10) {
            Text("FRIEND").font(LF.mono(10)).tracking(2).foregroundStyle(.white.opacity(0.45))
            HStack(spacing: 6) {
                if shot {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { ctx in
                        let q = reduceMotion ? 1 : 0.35 + 0.65 * (0.5 + 0.5 * sin(ctx.date.timeIntervalSinceReferenceDate / 1.6 * 2 * .pi))
                        Circle().fill(HV.lime).frame(width: 6, height: 6).opacity(q)
                    }
                    Text("今日 \(times.count)枚").font(LF.inter(800, 11.5)).foregroundStyle(HV.lime)
                } else {
                    Text("まだ 撮って いない").font(LF.inter(700, 11.5)).foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 10).frame(height: 26)
            .background(shot ? HV.lime.opacity(0.14) : Color.white.opacity(0.08), in: Capsule())
            Spacer()
            Button { Haptics.play(.tick); onClose() } label: {
                Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white).frame(width: 40, height: 40).background(.white.opacity(0.1), in: Circle())
            }.buttonStyle(.plain).frame(width: 44, height: 44).contentShape(Rectangle()).accessibilityLabel("とじる")
        }.padding(.horizontal, 20)
    }

    // MARK: チェキ(幅 138 ・ -4°)

    private var cheki: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                if let a = avatar { Image(uiImage: a).resizable().scaledToFill() }
                else { LinearGradient(colors: [Color(hex: "7FB0FF"), Color(hex: "B28CFF")], startPoint: .top, endPoint: .bottom).overlay(Text(String(name.prefix(1))).font(LF.inter(900, 52)).foregroundStyle(.white.opacity(0.9))) }
                Text("'\(DateFormatter.chekiStamp.string(from: Date()))").font(LF.mono(8)).foregroundStyle(Color(hex: "FF9F43")).padding(5)
            }.frame(width: 122, height: 122).clipped().padding(.top, 8)
            Text(name).font(LF.hand(20)).foregroundStyle(Color(hex: "0B0C0D")).lineLimit(1).minimumScaleFactor(0.6).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 10).padding(.top, 2)
            Spacer(minLength: 0)
        }
        .frame(width: 138, height: 168).background(Color(hex: "F3F0EA"), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(alignment: .top) { Rectangle().fill(HV.lime.opacity(0.85)).frame(width: 54, height: 18).rotationEffect(.degrees(-2)).offset(y: -8) }
        .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
        .rotationEffect(.degrees(appeared || reduceMotion ? -4 : 10))
        .scaleEffect(appeared || reduceMotion ? 1 : 0.7).offset(y: appeared || reduceMotion ? 0 : 60).opacity(appeared || reduceMotion ? 1 : 0)
        .animation(reduceMotion ? nil : .timingCurve(0.3, 1.3, 0.5, 1, duration: 0.62).delay(0.12), value: appeared)
        .padding(10)
        .accessibilityHidden(true)
    }

    private func sticker(_ t: String, _ c: Color, _ angle: Double, delay: Double) -> some View {
        StickerPop(text: t, color: c, angle: angle, delay: delay, appeared: appeared, reduceMotion: reduceMotion)
    }

    private var mutual: some View {
        HStack(spacing: 6) {
            ZStack { Circle().fill(Color(hex: "3A3A3F")); Circle().fill(Color(hex: "EE5E9C")).padding(3) }.frame(width: 20, height: 20)
            Text("共通の 友だち \(mutualCount)人").font(LF.inter(600, 11.5)).foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: TODAY

    private var today: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TODAY").font(LF.mono(10)).tracking(2).foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text("\(times.count) / 3").font(LF.mono(11)).foregroundStyle(HV.lime)
            }
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Color.clear.aspectRatio(4.0 / 3.0, contentMode: .fit).frame(maxWidth: .infinity).overlay {
                        ZStack(alignment: .bottomLeading) {
                            if times.indices.contains(i) {
                                if let m = mosaics[safe: i] ?? nil { Image(uiImage: m).resizable().scaledToFill().blur(radius: 10) } else { Color(hex: "2A2A2E") }
                                if !times[i].isEmpty { Text(times[i]).font(LF.mono(10)).foregroundStyle(Color(hex: "FF9F43")).padding(6) }
                                Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(.white).frame(width: 22, height: 22).background(.black.opacity(0.5), in: Circle()).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(5)
                            } else { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [4, 4])) }
                        }
                    }.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            Text("今日 1枚 撮ると、あした 見られる").font(LF.inter(600, 12)).foregroundStyle(.white.opacity(0.5))
        }
        .padding(14).background(Color(hex: "19191C"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func action(_ icon: String, _ t: String, _ bg: Color, _ fg: Color, flex: Bool, _ a: @escaping () -> Void) -> some View {
        Button { Haptics.play(.tick); a() } label: {
            VStack(spacing: 6) { Image(systemName: icon).font(.system(size: 17, weight: .semibold)); Text(t).font(LF.inter(800, 13)) }
                .foregroundStyle(fg).frame(maxWidth: flex ? .infinity : 78).frame(height: 62)
                .background(bg, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }.buttonStyle(HVPress(scale: 0.95))
    }
}

private extension DateFormatter {
    static let chekiStamp: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yy MM dd"; return f }()
}

/// タグの シール:0 → 1.2 → 1倍(0.42秒)+ `tick`
private struct StickerPop: View {
    let text: String; let color: Color; let angle: Double; let delay: Double; let appeared: Bool; let reduceMotion: Bool
    @State private var popped = false
    var body: some View {
        Text(text).font(LF.inter(900, 13)).foregroundStyle(.white).lineLimit(1).padding(.horizontal, 12).frame(height: 30)
            .background(color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 3, x: 1, y: 2)
            .rotationEffect(.degrees(angle))
            .scaleEffect(popped || reduceMotion ? 1 : 0.001)
            .animation(reduceMotion ? nil : .timingCurve(0.3, 1.5, 0.5, 1, duration: 0.42), value: popped)
            .onChange(of: appeared) { _, a in
                guard a, !reduceMotion else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { popped = true; Haptics.play(.tick) }
            }
    }
}

private extension View {
    /// 下から 12pt + 不透明(0.42秒 ・ 40ms ずつ)
    func stagger(_ on: Bool, _ i: Int, _ reduce: Bool) -> some View {
        self.opacity(on || reduce ? 1 : 0).offset(y: on || reduce ? 0 : 12)
            .animation(reduce ? nil : .timingCurve(0.2, 0.9, 0.25, 1, duration: 0.42).delay(0.2 + 0.04 * Double(i)), value: on)
    }
}

/// 呼ぶ 画面の ZStack に 重ねる:黒 62% + うく カード(下から 0.5秒)。
struct FriendCardOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder var content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            if isPresented {
                Color.black.opacity(0.62).ignoresSafeArea().onTapGesture { close() }.transition(.opacity)
                content()
                    .padding(.horizontal, 8).padding(.bottom, 8)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom))
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .timingCurve(0.2, 0.9, 0.25, 1, duration: 0.5), value: isPresented)
    }
    private func close() { isPresented = false }
}
