import SwiftUI

// v134 Phase 2:ともだちシート(見本 27)。リクエスト | ともだち | さがす。ふってつながる ・ QRを見せる ・ リンクで呼ぶ。
// 「ともだちの数は、どこにも出ません。」= 人数の 数字は 出さない(リクエストの 数だけ)。

struct FriendsSheetV134: View {
    var input: YesterdayV64Input
    var actions: YesterdayV64Actions
    var onClose: () -> Void
    @State private var seg = 0
    @State private var dismissed: Set<String> = []

    private var requests: [YesterdayV64Input.Request] { input.requestItems.filter { !dismissed.contains($0.id) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    DisplayTitle(text: "Friends", size: 52)
                    Spacer()
                    Button { LTHaptics.play(.tap); onClose() } label: {
                        Image(systemName: "xmark").font(.system(size: 17, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44).background(Color.white.opacity(0.1), in: Circle())
                    }.accessibilityLabel("閉じる")
                }.padding(.top, 22)
                segment.padding(.top, 16)
                HStack(spacing: 12) {
                    bigButton("iphone.radiowaves.left.and.right", "ふってつながる") { onClose(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { actions.openFriends() } }
                    bigButton("qrcode", "QRを見せる") { onClose(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { actions.showQR() } }
                    bigButton("link", "リンクで呼ぶ") { onClose(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { actions.shareLink() } }
                }.padding(.top, 16)
                Group {
                    switch seg {
                    case 0: requestList
                    case 1: friendList
                    default: searchPane
                    }
                }.padding(.top, 22)
                Text("ともだちの数は、どこにも出ません。").font(LTFont.ui(13)).foregroundStyle(LTColor.ink3).frame(maxWidth: .infinity).padding(.top, 34)
            }.padding(.horizontal, 18).padding(.bottom, 30)
        }
    }

    private var segment: some View {
        HStack(spacing: 0) {
            ForEach(Array(["リクエスト", "ともだち", "さがす"].enumerated()), id: \.offset) { i, t in
                Button { if seg != i { LTHaptics.play(.select); withAnimation(.easeOut(duration: 0.18)) { seg = i } } } label: {
                    HStack(spacing: 6) {
                        Text(t).font(LTFont.ui(16, weight: .heavy))
                        if i == 0, !requests.isEmpty { Text("\(requests.count)").font(LTFont.ui(12, weight: .heavy)).foregroundStyle(.white).padding(.horizontal, 7).frame(height: 20).background(LTColor.badge, in: Capsule()) }
                    }
                    .foregroundStyle(seg == i ? LTColor.limeInk : LTColor.ink2).frame(maxWidth: .infinity).frame(height: 44)
                    .background(seg == i ? Color.white : .clear, in: Capsule())
                }.buttonStyle(.plain).accessibilityAddTraits(seg == i ? [.isSelected] : [])
            }
        }.padding(4).background(LTColor.surface2, in: Capsule())
    }

    private func bigButton(_ icon: String, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button { LTHaptics.play(.tap); action() } label: {
            VStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 26, weight: .medium)).foregroundStyle(.white)
                Text(title).font(LTFont.ui(14, weight: .heavy)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
            }.frame(maxWidth: .infinity).frame(height: 96)
            .background(LTColor.surface1, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(LTColor.hairline2, lineWidth: 1))
        }.buttonStyle(HVPress(scale: 0.96))
    }

    private func row(name: String, sub: String, avatar: UIImage?, trailing: some View) -> some View {
        HStack(spacing: 12) {
            Group { if let a = avatar { Image(uiImage: a).resizable().scaledToFill() } else { Circle().fill(HomeV134Parts.color(name)).overlay(Text(String(name.prefix(1))).font(LTFont.ui(20, weight: .heavy)).foregroundStyle(.white)) } }
                .frame(width: 44, height: 44).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(LTFont.ui(17, weight: .heavy)).foregroundStyle(.white)
                if !sub.isEmpty { Text(sub).font(LTFont.ui(12.5)).foregroundStyle(LTColor.ink3).lineLimit(2) }
            }
            Spacer(minLength: 6)
            trailing
        }.padding(.vertical, 8)
    }

    private var requestList: some View {
        VStack(alignment: .leading, spacing: 4) {
            if requests.isEmpty {
                Text("いま、リクエストはありません").font(LTFont.ui(14)).foregroundStyle(LTColor.ink3).frame(maxWidth: .infinity).padding(.top, 12)
            } else {
                Text("リクエスト").font(LTFont.ui(14)).foregroundStyle(LTColor.ink3)
                ForEach(requests) { r in
                    row(name: r.name, sub: r.sub, avatar: nil, trailing: HStack(spacing: 10) {
                        Button { LTHaptics.play(.posted); actions.approve(r.id); dismissed.insert(r.id) } label: {
                            Text("承認").font(LTFont.ui(15, weight: .heavy)).foregroundStyle(LTColor.limeInk).padding(.horizontal, 20).frame(height: 44).background(LTColor.lime, in: Capsule())
                        }.buttonStyle(HVPress(scale: 0.95))
                        Button { LTHaptics.play(.tap); actions.dismissRequest(r.id); dismissed.insert(r.id) } label: {
                            Image(systemName: "xmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(LTColor.ink3).frame(width: 44, height: 44)
                        }.accessibilityLabel("\(r.name)のリクエストを消す")
                    })
                }
            }
        }
    }

    private var friendList: some View {
        VStack(alignment: .leading, spacing: 4) {
            if input.friendList.isEmpty {
                Text("まだ、ともだちがいません").font(LTFont.ui(14)).foregroundStyle(LTColor.ink3).frame(maxWidth: .infinity).padding(.top, 12)
            }
            ForEach(input.friendList) { f in
                Button { LTHaptics.play(.tap); onClose(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { actions.openChat(f.id, f.name) } } label: {
                    row(name: f.name, sub: "", avatar: f.avatar, trailing: Image(systemName: "bubble.left").font(.system(size: 15, weight: .semibold)).foregroundStyle(LTColor.ink3).frame(width: 44, height: 44))
                }.buttonStyle(.plain)
            }
        }
    }

    private var searchPane: some View {
        VStack(spacing: 14) {
            Text("IDで、ともだちをさがせます").font(LTFont.ui(14)).foregroundStyle(LTColor.ink3)
            Button { LTHaptics.play(.tap); onClose(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { actions.searchByID() } } label: {
                HStack(spacing: 8) { Image(systemName: "magnifyingglass"); Text("IDでさがす") }.font(LTFont.ui(16, weight: .heavy)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 56).background(LTColor.surface2, in: RoundedRectangle(cornerRadius: LTRadius.button, style: .continuous))
            }.buttonStyle(HVPress(scale: 0.97))
            Button { LTHaptics.play(.tap); onClose(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { actions.scanQR() } } label: {
                HStack(spacing: 8) { Image(systemName: "qrcode.viewfinder"); Text("QRを読む") }.font(LTFont.ui(16, weight: .heavy)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 56).background(LTColor.surface2, in: RoundedRectangle(cornerRadius: LTRadius.button, style: .continuous))
            }.buttonStyle(HVPress(scale: 0.97))
        }
    }
}
