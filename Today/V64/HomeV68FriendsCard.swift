import SwiftUI

// P14(v70):Home 下の Friends カード(Instagram / BeReal 型・キャラクター なし・Shake なし)。
// 友だち あり = ストーリーの 丸 + 申請の 1行 / だれも いない = 横に すべる カード(申請して きた 人 + 招待の しかた)。

struct HVFriendsCard: View {
    let input: HomeV64Input
    let actions: HomeV64Actions
    @State private var appeared = false
    @State private var hidden: Set<String> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var requests: [HomeV64Request] { input.requests.filter { !hidden.contains($0.id) } }
    private var tookCount: Int { input.friends.filter { $0.shots > 0 }.count }
    private var on: Bool { appeared || reduceMotion }

    var body: some View {
        VStack(spacing: 0) { HVAnchor(id: "sec-friends"); card }
            .onScrollVisibilityChange(threshold: 0.25) { visible in if visible && !appeared { appeared = true } }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if input.friends.isEmpty { empty } else { stories; requestRow }
        }
        .padding(.top, 18).padding(.bottom, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "111214"), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .padding(.horizontal, 14)
    }

    // MARK: 見出し(Friends は 1つの Text。見出しの どこを 押しても Friends 画面へ)

    private var header: some View {
        Button { Haptics.play(.sel); actions.openFriends() } label: {
            HStack(spacing: 10) {
                Text("Friends").font(LF.serif(32)).foregroundStyle(.white).fixedSize()
                if tookCount > 0 {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "3BD35A")).frame(width: 6, height: 6)
                        Text("\(tookCount) SHOT TODAY").font(LF.mono(9.5)).tracking(1.4).foregroundStyle(Color(hex: "7EE08F")).fixedSize()
                    }
                    .padding(.horizontal, 12).frame(height: 26).background(Color(red: 59 / 255, green: 211 / 255, blue: 90 / 255).opacity(0.12), in: Capsule())
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 40, height: 40).background(.white.opacity(0.08), in: Circle())
            }
            .padding(.horizontal, 20).frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Friends")
    }

    // MARK: 友だち あり:ストーリーの 丸

    private var stories: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 14) {
                me
                let ordered = input.friends.sorted { ($0.shots > 0 ? 0 : 1) < ($1.shots > 0 ? 0 : 1) }
                ForEach(Array(ordered.enumerated()), id: \.element.id) { i, f in friend(f, index: i + 1) }
            }
            .padding(.horizontal, 20)
        }
        .scrollTargetBehavior(.viewAligned)
        .frame(height: 92).padding(.top, 16)
    }

    private func photo(_ image: UIImage?, name: String, color: Color, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(color)
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Text(String(name.prefix(1))).font(LF.inter(800, size * 0.4)).foregroundStyle(HV.ink) }
        }.frame(width: size, height: size).clipShape(Circle())
    }

    private func pop(_ i: Int) -> some ViewModifier { HV68Pop(on: on, index: i) }

    private var me: some View {
        Button { Haptics.play(.sel); actions.showQR() } label: {
            VStack(spacing: 7) {
                ZStack {
                    Circle().strokeBorder(.white.opacity(0.18), lineWidth: 2.5).frame(width: 68, height: 68)
                    photo(input.avatar, name: input.avatarName, color: Color(hex: "3A3A3C"), size: 58)
                    Image(systemName: "plus").font(.system(size: 12, weight: .heavy)).foregroundStyle(HV.ink)
                        .frame(width: 24, height: 24).background(HV.lime, in: Circle())
                        .overlay(Circle().strokeBorder(Color(hex: "111214"), lineWidth: 3))
                        .offset(x: 23, y: 23)
                }.frame(width: 68, height: 68)
                Text("ふやす").font(LF.inter(600, 12)).foregroundStyle(.white.opacity(0.88)).lineLimit(1).frame(width: 68)
            }
        }
        .buttonStyle(HVPress(scale: 0.94)).modifier(pop(0)).accessibilityLabel("友だちを ふやす")
    }

    private func friend(_ f: HomeV64Friend, index: Int) -> some View {
        let took = f.shots > 0
        return Button { Haptics.play(.sel); actions.openFriends() } label: {
            VStack(spacing: 7) {
                ZStack {
                    if took {
                        Circle().strokeBorder(AngularGradient(colors: [Color(hex: "C8F25A"), Color(hex: "3BD35A"), Color(hex: "24A03C"), Color(hex: "C8F25A")], center: .center, angle: .degrees(210)), lineWidth: 2.5)
                            .frame(width: 68, height: 68)
                    } else {
                        Circle().strokeBorder(.white.opacity(0.18), lineWidth: 2.5).frame(width: 68, height: 68)
                    }
                    photo(f.image, name: f.name, color: f.color, size: 58)
                    if took, let t = f.time {
                        Text(t).font(LF.mono(8.5)).foregroundStyle(HV.lime).padding(.horizontal, 7).frame(height: 17)
                            .background(Color(hex: "111214"), in: Capsule()).offset(y: 29)
                    }
                    if !took {
                        Image(systemName: "hand.point.up.left.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 24, height: 24).background(Color(hex: "2A2A2D"), in: Circle())
                            .overlay(Circle().strokeBorder(Color(hex: "111214"), lineWidth: 3))
                            .offset(x: 23, y: 23)
                            .onTapGesture { Haptics.play(.heart); actions.poke(f.id) }
                    }
                }.frame(width: 68, height: 68)
                Text(f.name).font(LF.inter(600, 12)).foregroundStyle(.white.opacity(0.88)).lineLimit(1).truncationMode(.tail).frame(width: 68)
            }
        }
        .buttonStyle(HVPress(scale: 0.94)).modifier(pop(index))
        .accessibilityLabel(took ? "\(f.name)(今日 撮った)" : "\(f.name)(まだ)")
    }

    // MARK: 申請の 1行(ある ときだけ)

    @ViewBuilder private var requestRow: some View {
        if let first = requests.first {
            Button { Haptics.play(.sel); actions.openRequests() } label: {
                HStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        HStack(spacing: -12) {
                            ForEach(Array(requests.prefix(3).enumerated()), id: \.element.id) { _, r in
                                photo(r.image, name: r.name, color: r.color, size: 34).overlay(Circle().strokeBorder(Color(hex: "1B1C1F"), lineWidth: 2))
                            }
                        }
                        Circle().fill(Color(hex: "FF3B30")).frame(width: 9, height: 9).offset(x: 32, y: -2)
                    }
                    .padding(.leading, 12).padding(.trailing, 14)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(requests.count > 1 ? "\(first.name) ほか\(requests.count - 1)人" : first.name).font(LF.inter(700, 14.5)).foregroundStyle(.white).lineLimit(1)
                        Text("友だちに なりたい").font(LF.inter(600, 12)).foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer(minLength: 8)
                    Text("確認").font(LF.inter(800, 13)).foregroundStyle(HV.ink).frame(width: 54, height: 36).background(.white, in: Capsule()).padding(.trailing, 10)
                }
                .frame(height: 60)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 14)
            }
            .buttonStyle(HVPress(scale: 0.98)).padding(.top, 18)
            .modifier(HV68Rise(on: on))
            .accessibilityLabel("友だち申請 \(requests.count)件")
        }
    }

    // MARK: だれも いない:横に すべる カード

    private var empty: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(requests.isEmpty ? "つながると、毎朝 9:00 に きのうを 見せあえます。" : "友だちに なりたい 人が います。")
                .font(LF.inter(600, 13)).foregroundStyle(.white.opacity(0.6)).padding(.horizontal, 20).padding(.top, 17)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 10) {
                    ForEach(Array(requests.enumerated()), id: \.element.id) { i, r in requestCard(r, index: i) }
                    inviteCard(0, icon: "square.and.arrow.up", title: "リンクを 送る", sub: "LINE ・ AirDrop など", button: "送る", white: true) { actions.shareLink() }
                    inviteCard(1, icon: "qrcode", title: "QR を 見せる", sub: "となりの 友だちに", button: "ひらく", white: false) { actions.showQR() }
                    inviteCard(2, icon: "at", title: "ID で さがす", sub: "@ID を 知って いる", button: "さがす", white: false) { actions.searchByID() }
                }
                .padding(.horizontal, 20)
            }
            .scrollTargetBehavior(.viewAligned)
            .frame(height: 221).padding(.top, 30)
        }
    }

    private func requestCard(_ r: HomeV64Request, index: Int) -> some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().strokeBorder(HV.lime, lineWidth: 2.5).frame(width: 88, height: 88)
                    Circle().strokeBorder(Color(hex: "111214"), lineWidth: 3).frame(width: 83, height: 83)
                    photo(r.image, name: r.name, color: r.color, size: 78)
                }.frame(width: 88, height: 88).padding(.top, 11)
                Text(r.name).font(LF.inter(700, 15)).foregroundStyle(.white).lineLimit(1).padding(.top, 6)
                if !r.handle.isEmpty { Text(r.handle).font(LF.inter(600, 11.5)).foregroundStyle(.white.opacity(0.5)).lineLimit(1).padding(.top, 3) }
                Text("\(r.ago) ・ 申請").font(LF.mono(9)).foregroundStyle(Color(hex: "7EE08F")).padding(.top, 5)
                Spacer(minLength: 0)
                Button { Haptics.play(.click); withAnimation(.easeOut(duration: 0.42)) { hidden.insert(r.id) }; actions.approve(r.id) } label: {
                    Text("承認").font(LF.inter(800, 14)).foregroundStyle(HV.ink).frame(width: 124, height: 38).background(HV.lime, in: Capsule())
                }.buttonStyle(HVPress(scale: 0.96)).padding(.bottom, 12)
            }
            HStack { Spacer(); Button { Haptics.play(.soft); withAnimation(.easeOut(duration: 0.3)) { hidden.insert(r.id) }; actions.dismissRequest(r.id) } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white.opacity(0.55)).frame(width: 32, height: 32)
            }.buttonStyle(.plain).accessibilityLabel("あとで") }.padding(.top, 6).padding(.trailing, 4)
        }
        .frame(width: 148, height: 221)
        .background(Color(hex: "1B1C1F"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .modifier(HV68Slide(on: on, index: index))
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    private func inviteCard(_ i: Int, icon: String, title: String, sub: String, button: String, white: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Image(systemName: icon).font(.system(size: 30, weight: .semibold)).foregroundStyle(HV.ink)
                .frame(width: 78, height: 78).background(HV.lime, in: Circle()).padding(.top, 16)
            Text(title).font(LF.inter(700, 15)).foregroundStyle(.white).lineLimit(1).padding(.top, 10)
            Text(sub).font(LF.inter(600, 11.5)).foregroundStyle(.white.opacity(0.5)).lineLimit(1).padding(.top, 3)
            Spacer(minLength: 0)
            Button { Haptics.play(.click); action() } label: {
                Text(button).font(LF.inter(800, 14)).foregroundStyle(white ? HV.ink : .white).frame(width: 124, height: 38)
                    .background(white ? AnyShapeStyle(.white) : AnyShapeStyle(Color.white.opacity(0.12)), in: Capsule())
            }.buttonStyle(HVPress(scale: 0.96)).padding(.bottom, 12)
        }
        .frame(width: 148, height: 221)
        .background(Color(hex: "1B1C1F"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .modifier(HV68Slide(on: on, index: requests.count + i))
    }
}

// MARK: 入る 動き(1回 だけ)

private struct HV68Pop: ViewModifier {
    let on: Bool; let index: Int
    func body(content: Content) -> some View {
        content.scaleEffect(on ? 1 : 0.4).opacity(on ? 1 : 0)
            .animation(.timingCurve(0.3, 1.2, 0.4, 1, duration: 0.52).delay(0.06 * Double(index)), value: on)
            .task(id: on) { if on, index < 5 { try? await Task.sleep(nanoseconds: UInt64(0.06 * Double(index) * 1e9)); Haptics.play(.tick) } }
    }
}
private struct HV68Slide: ViewModifier {
    let on: Bool; let index: Int
    func body(content: Content) -> some View {
        content.offset(x: on ? 0 : 40).opacity(on ? 1 : 0)
            .animation(.timingCurve(0.2, 0.8, 0.3, 1, duration: 0.5).delay(0.07 * Double(index)), value: on)
    }
}
private struct HV68Rise: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        content.offset(y: on ? 0 : 14).opacity(on ? 1 : 0).animation(.easeOut(duration: 0.45).delay(0.3), value: on)
    }
}
