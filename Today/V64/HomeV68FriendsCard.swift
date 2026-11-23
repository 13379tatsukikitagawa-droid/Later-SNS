import SwiftUI
import SwiftData

// v119 3章 + v121 3章:Home 下の Friends の かたまり。見出し + 申請の 行 + マイカード 1枚(v133:QR の チェキ ・ 自分 ・ 読む / さがす ・ リンクを 送る)。

/// かたまりの 見出し(v119 ⑥:タイトル 38pt セリフ + 説明 1行 + 右に 丸い →)
struct HVBlockHeader<Line: View>: View {
    let title: String
    let action: () -> Void
    @ViewBuilder let line: () -> Line
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: title).font(Typo.title(38)).tracking(Typo.titleTracking(38)).foregroundStyle(HVCardTint.milk).lineLimit(1)
                line()
            }
            Spacer(minLength: 0)
            Button { Haptics.play(.sel); action() } label: {
                Image(systemName: "arrow.right").font(.system(size: 15, weight: .bold)).foregroundStyle(HVCardTint.milk)
                    .frame(width: 44, height: 44).background(Color(hex: "1F1F23"), in: Circle())
            }
            .buttonStyle(HVPress(scale: 0.92))
            .accessibilityLabel(title)
        }
    }
}

struct HVBlockLine: View {
    let text: String
    var body: some View { Text(text).font(Typo.ui(700, 12.5)).foregroundStyle(Color(hex: "8C8C93")).lineLimit(1).truncationMode(.tail) }
}

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
            HVBlockHeader(title: "Friends", action: actions.openFriends) {
                if tookCount > 0 {
                    HStack(spacing: 6) {
                        Circle().fill(HV.lime).frame(width: 6, height: 6)
                        Text("\(tookCount)人 撮った ・ 9:00 に ひらく").font(Typo.ui(700, 12.5)).foregroundStyle(HV.lime).lineLimit(1)
                    }
                } else {
                    HVBlockLine(text: "つながると 毎朝 9:00 に 見せあえる")
                }
            }
            .padding(.horizontal, 22)
            requestRow.modifier(HV68Rise(on: on, index: 0))
            myCard.padding(.top, 14).padding(.horizontal, 16).modifier(HV68Rise(on: on, index: 1))
        }
        .padding(.top, 20).padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "111113"), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(.white.opacity(0.07), lineWidth: 1))
        .padding(.horizontal, 14)
    }

    private func photo(_ image: UIImage?, name: String, color: Color, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(color)
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Text(String(name.prefix(1))).font(Typo.ui(800, size * 0.4)).foregroundStyle(HV.ink) }
        }.frame(width: size, height: size).clipShape(Circle())
    }

    // MARK: 申請の 行(ある ときだけ ・ 高さ 60 ・ 角丸 22 ・ #1A1A1D ・ ピンクの「確認」)

    @ViewBuilder private var requestRow: some View {
        if let first = requests.first {
            Button { Haptics.play(.sel); actions.openRequests() } label: {
                HStack(spacing: 12) {
                    HStack(spacing: -5) {
                        ForEach(Array(requests.prefix(2).enumerated()), id: \.element.id) { k, r in
                            photo(r.image, name: r.name, color: r.color, size: 34).overlay(Circle().strokeBorder(Color(hex: "0B0B0C"), lineWidth: 1.5).padding(-1.5)).zIndex(Double(3 - k))
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(requests.count > 1 ? "\(first.name) ほか\(requests.count - 1)人" : first.name).font(Typo.ui(800, 14.5)).foregroundStyle(Color(hex: "F4F1EA")).lineLimit(1)
                        Text("友だちに なりたい").font(Typo.ui(700, 11.5)).foregroundStyle(Color(hex: "8C8C93")).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text("確認").font(Typo.ui(800, 13.5)).foregroundStyle(Color(hex: "111113")).frame(width: 63, height: 40).background(HVCardTint.friends, in: Capsule())
                }
                .padding(.leading, 12).padding(.trailing, 10)
                .frame(height: 60)
                .background(Color(hex: "1A1A1D"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.07), lineWidth: 1))
            }
            .buttonStyle(HVPress(scale: 0.97))
            .padding(.horizontal, 16).padding(.top, 16)
            .accessibilityLabel("友だち申請 \(requests.count)件")
        }
    }

    // MARK: マイカード(左 = QR の チェキ ・ 右 = 自分 + リンクを 送る)

    private var me: UserProfile? { UserProfile.current(from: profiles) }

    private var myLinkText: String {
        FriendRules.shareLink(recordName: CloudKitManager.current?.currentUserRecordName ?? me?.cloudKitUserRecordName ?? me?.username ?? "").absoluteString
    }

    private var myCard: some View {
        let name = input.avatarName.isEmpty ? (me?.name ?? "") : input.avatarName
        let handle = (me?.username).map { $0.isEmpty ? "" : "@\($0)" } ?? ""
        return VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Button { Haptics.play(.click); actions.showQR() } label: { qrCheki }
                    .buttonStyle(HVPress(scale: 0.96))
                    .accessibilityLabel("QR を 見せる")
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        photo(input.avatar, name: name, color: Color(hex: "3A3A3C"), size: 44)
                            .overlay(Circle().strokeBorder(HVCardTint.milk, lineWidth: 2))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name).font(Typo.ui(800, 17)).foregroundStyle(HVCardTint.milk).lineLimit(1).truncationMode(.tail)
                            if !handle.isEmpty { Text(handle).font(Typo.ui(700, 12.5)).foregroundStyle(Color(hex: "8E8E95")).lineLimit(1).truncationMode(.tail) }
                        }
                    }
                    HStack(spacing: 8) {
                        smallButton("viewfinder", "読む") { actions.scanQR() }
                        smallButton("magnifyingglass", "さがす") { actions.searchByID() }
                    }
                }
            }
            Button { Haptics.play(.click); actions.shareLink() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 20, weight: .bold))
                    Text("リンクを 送る").font(Typo.ui(900, 15.5)).lineLimit(1).minimumScaleFactor(0.8)
                }
                .foregroundStyle(Color(hex: "111113"))
                .frame(maxWidth: .infinity).frame(height: 54)
            }
            .buttonStyle(HVLedgePress(face: HV.lime, ledge: Color(hex: "97C235"), radius: 18, depth: 4))
            .padding(.bottom, 4)
        }
        .padding(16)
        .background(Color(hex: "111113"), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white.opacity(0.07), lineWidth: 1))
    }

    /// QR の チェキ(幅 112 ・ -4° ・ 上に ピンクの テープ ・ 下に「タップで 大きく」)
    private var qrCheki: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.white
                if let m = QRMatrix.make(myLinkText) { StyledQRView(matrix: m, side: 98) } else { Image(systemName: "qrcode").font(.system(size: 56)).foregroundStyle(.black) }
            }
            .frame(width: 98, height: 98)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .padding(.top, 7)
            Text("タップで 大きく").font(Typo.ui(800, 10.5)).foregroundStyle(Color(hex: "6E6E75")).lineLimit(1).minimumScaleFactor(0.8)
                .frame(height: 24)
        }
        .frame(width: 112)
        .background(Color(hex: "F4F1EA"), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(alignment: .top) {
            Rectangle().fill(HVCardTint.friends.opacity(0.92)).frame(width: 56, height: 18).rotationEffect(.degrees(3)).offset(y: -9)
        }
        .rotationEffect(.degrees(-4))
        .shadow(color: .black.opacity(0.6), radius: 10, y: 8)
        .padding(.top, 8).padding(.leading, 2)
    }

    private func smallButton(_ icon: String, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button { Haptics.play(.click); action() } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 18, weight: .bold))
                Text(title).font(Typo.ui(800, 11.5))
            }
            .foregroundStyle(Color(hex: "F4F1EA"))
            .frame(maxWidth: .infinity).frame(height: 58)
            .background(Color(hex: "1D1D20"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(HVPress(scale: 0.96))
    }
}

// MARK: 入る 動き(1回 だけ)

private struct HV68Rise: ViewModifier {
    let on: Bool
    var index = 0
    /// v119:はじめて 出る 時 下から 14pt + ふわっと(60ms ずつ)
    func body(content: Content) -> some View {
        content.offset(y: on ? 0 : 14).opacity(on ? 1 : 0).animation(.easeOut(duration: 0.45).delay(0.06 * Double(index)), value: on)
    }
}

