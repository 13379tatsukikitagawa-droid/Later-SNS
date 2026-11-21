import SwiftUI
import SwiftData

// P14(v70):Home 下の Friends カード(Instagram / BeReal 型・キャラクター なし・Shake なし)。
// 友だち あり = ストーリーの 丸 + 申請の 1行 / だれも いない = 横に すべる カード(申請して きた 人 + 招待の しかた)。

struct HVFriendsCard: View {
    let input: HomeV64Input
    let actions: HomeV64Actions
    @State private var appeared = false
    @State private var hidden: Set<String> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [UserProfile]

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
            if !input.friends.isEmpty { stories }
            requestRow
            bento
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
                Text("Friends").font(Typo.title(30)).foregroundStyle(.white).fixedSize()
                if tookCount > 0 {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "3BD35A")).frame(width: 6, height: 6)
                        Text("\(tookCount)人 撮った").font(Typo.ui(700, 11)).foregroundStyle(Color(hex: "7EE08F")).fixedSize()
                    }
                    .padding(.horizontal, 12).frame(height: 26).background(Color(red: 59 / 255, green: 211 / 255, blue: 90 / 255).opacity(0.12), in: Capsule())
                } else if input.friends.isEmpty {
                    Text("つながると 毎朝 9:00 に 見せあえる").font(Typo.ui(600, 11.5)).foregroundStyle(.white.opacity(0.55)).lineLimit(1).minimumScaleFactor(0.7)
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
            else { Text(String(name.prefix(1))).font(Typo.ui(800, size * 0.4)).foregroundStyle(HV.ink) }
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
                Text("ふやす").font(Typo.ui(600, 12)).foregroundStyle(.white.opacity(0.88)).lineLimit(1).frame(width: 68)
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
                        Text(t).font(Typo.label(8.5)).foregroundStyle(HV.lime).padding(.horizontal, 7).frame(height: 17)
                            .background(Color(hex: "111214"), in: Capsule()).offset(y: 29)
                    }
                }.frame(width: 68, height: 68)
                Text(f.name).font(Typo.ui(600, 12)).foregroundStyle(.white.opacity(0.88)).lineLimit(1).truncationMode(.tail).frame(width: 68)
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
                        Text(requests.count > 1 ? "\(first.name) ほか\(requests.count - 1)人" : first.name).font(Typo.ui(700, 14.5)).foregroundStyle(.white).lineLimit(1)
                        Text("友だちに なりたい").font(Typo.ui(600, 12)).foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer(minLength: 8)
                    Text("確認").font(Typo.ui(800, 13)).foregroundStyle(HV.ink).frame(width: 54, height: 36).background(.white, in: Capsule()).padding(.trailing, 10)
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

    // MARK: 4つの ボタン(それぞれ 別の 画面)

    private var myLinkText: String {
        let me = UserProfile.current(from: profiles)
        return FriendRules.shareLink(recordName: CloudKitManager.current?.currentUserRecordName ?? me?.cloudKitUserRecordName ?? me?.username ?? "").absoluteString
    }

    private var bento: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // リンクを 送る(大きく ・ 2段)
                Button { Haptics.play(.click); actions.shareLink() } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 22, weight: .bold)).foregroundStyle(HV.ink)
                        Spacer(minLength: 0)
                        Text("リンクを 送る").font(Typo.ui(800, 18)).foregroundStyle(HV.ink).lineLimit(1).minimumScaleFactor(0.7)
                        Text("LINE ・ AirDrop など").font(Typo.ui(600, 11.5)).foregroundStyle(HV.ink.opacity(0.6)).lineLimit(1).minimumScaleFactor(0.7).padding(.top, 2)
                    }
                    .padding(16).frame(maxWidth: .infinity, minHeight: 138, maxHeight: 138, alignment: .leading)
                    .background(HV.lime, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }.buttonStyle(HVPress(scale: 0.97)).modifier(HV68Rise(on: on))
                VStack(spacing: 10) {
                    Button { Haptics.play(.click); actions.showQR() } label: {
                        HStack(spacing: 10) {
                            Group { if let m = QRMatrix.make(myLinkText) { StyledQRView(matrix: m, side: 44) } else { Image(systemName: "qrcode").font(.system(size: 26)) } }
                                .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 6))
                            Text("QR を 見せる").font(Typo.ui(800, 13.5)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }.buttonStyle(HVPress(scale: 0.97)).modifier(HV68Rise(on: on))
                    Button { Haptics.play(.click); actions.scanQR() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "viewfinder").font(.system(size: 22, weight: .semibold)).foregroundStyle(HV.lime).frame(width: 44)
                            Text("QR を 読む").font(Typo.ui(800, 13.5)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }.buttonStyle(HVPress(scale: 0.97)).modifier(HV68Rise(on: on))
                }
            }
            Button { Haptics.play(.click); actions.searchByID() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.system(size: 15, weight: .bold)).foregroundStyle(.white.opacity(0.6))
                    Text("名前 か @ID で さがす").font(Typo.ui(600, 15)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16).frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
                .background(.white.opacity(0.08), in: Capsule())
            }.buttonStyle(HVPress(scale: 0.98)).modifier(HV68Rise(on: on))
        }
        .padding(.horizontal, 14).padding(.top, 18)
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
