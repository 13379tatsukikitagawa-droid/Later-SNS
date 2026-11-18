import SwiftUI

// F05:友だちの カード(シート)。背景は 暗く ぼかす。チェキ + タグの シール + 名前 + 今日の こま(ぼかし + 時刻)+ Chat / つつく / Trip / more。
// 写真の 中身は 出さない(ロック中は ぼかしと 時刻だけ)。人の 絵は 使わない(写真が 無い 時は 名前の 1文字 + 色)。

struct FriendCardV82Sheet: View {
    let name: String
    var avatar: UIImage?
    var tag: String?
    var city: String?
    var times: [String]
    var mosaics: [UIImage?]
    var canPoke = true
    var onChat: () -> Void = {}
    var onPoke: () -> Void = {}
    var onTrip: () -> Void = {}
    var onMore: () -> Void = {}
    var onClose: () -> Void = {}

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.001).ignoresSafeArea().onTapGesture { onClose() }
            VStack(spacing: 0) {
                cheki.padding(.top, -150)
                Text([city, "ともだち"].compactMap { $0 }.joined(separator: " ・ ")).font(LF.mono(11)).tracking(1.5).foregroundStyle(.white.opacity(0.4)).padding(.top, 10)
                today.padding(.horizontal, 20).padding(.top, 18)
                HStack(spacing: 8) {
                    action("bubble.left", "Chat", style: 0, w: 109) { onChat() }
                    action("hand.point.up.left", "つつく", style: 1, w: 77) { onPoke() }.opacity(canPoke ? 1 : 0.4)
                    action("suitcase", "Trip", style: 2, w: 78) { onTrip() }
                    action("ellipsis", "more", style: 2, w: 62) { onMore() }
                }.padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity)
            .background(Color(hex: "0E0E0F"), in: UnevenRoundedRectangle(topLeadingRadius: 40, topTrailingRadius: 40))
            .overlay(alignment: .top) { UnevenRoundedRectangle(topLeadingRadius: 40, topTrailingRadius: 40).strokeBorder(.white.opacity(0.07), lineWidth: 1) }
        }
        .environment(\.colorScheme, .dark)
        .presentationBackground(.clear)
    }

    private var cheki: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    if let a = avatar { Image(uiImage: a).resizable().scaledToFill() }
                    else { LinearGradient(colors: [Color(hex: "7FB0FF"), Color(hex: "B28CFF")], startPoint: .top, endPoint: .bottom).overlay(Text(String(name.prefix(1))).font(LF.inter(900, 80)).foregroundStyle(.white.opacity(0.9))) }
                    Text("'26 11 17").font(LF.mono(10)).fontWeight(.bold).foregroundStyle(Color(hex: "FF9F43")).padding(8)
                }.frame(width: 188, height: 188).clipped().padding(.top, 10)
                Text(name).font(LGFont.mincho(30)).foregroundStyle(Color(hex: "0B0C0D")).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 18).padding(.top, 2)
                Spacer()
            }.frame(width: 210, height: 255).background(Color(hex: "F3F0EA"), in: RoundedRectangle(cornerRadius: 5)).shadow(color: .black.opacity(0.5), radius: 14, y: 10)
            Rectangle().fill(HV.lime.opacity(0.85)).frame(width: 78, height: 28).rotationEffect(.degrees(-2)).offset(x: 8, y: -12)
            if let tag {
                Text("#\(tag)").font(LF.inter(900, 15)).foregroundStyle(.white).padding(.horizontal, 14).frame(height: 34).background(Color(hex: "EE5E9C"), in: RoundedRectangle(cornerRadius: 12)).rotationEffect(.degrees(-9)).shadow(color: .black.opacity(0.35), radius: 4, x: 2, y: 3).offset(x: -108, y: 55)
            }
        }.rotationEffect(.degrees(2)).frame(height: 265)
    }

    private var today: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TODAY").font(LF.mono(11)).tracking(2).foregroundStyle(.white.opacity(0.4))
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { i in
                    ZStack(alignment: .bottomLeading) {
                        if times.indices.contains(i) {
                            if let m = mosaics[safe: i] ?? nil { Image(uiImage: m).resizable().scaledToFill().blur(radius: 10) } else { Color(hex: "2A2A2E") }
                            Text(times[i]).font(LF.mono(11)).fontWeight(.bold).foregroundStyle(Color(hex: "FF9F43")).padding(8)
                            Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(.white).frame(width: 26, height: 26).background(.black.opacity(0.5), in: Circle()).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(6)
                        } else { RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [4, 4])) }
                    }.frame(maxWidth: .infinity).frame(height: 64).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            Text("今日 1枚 撮ると、あした 見られる").font(LF.inter(600, 12)).foregroundStyle(.white.opacity(0.5))
        }.padding(16).background(Color(hex: "151517"), in: RoundedRectangle(cornerRadius: 26, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.07), lineWidth: 1))
    }

    private func action(_ icon: String, _ t: String, style: Int, w: CGFloat, _ a: @escaping () -> Void) -> some View {
        Button { Haptics.play(.tick); a() } label: {
            VStack(spacing: 8) { Image(systemName: icon).font(.system(size: 17, weight: .semibold)); Text(t).font(LF.inter(800, 13)) }
                .foregroundStyle(style == 0 ? Color(hex: "0B0C0D") : (style == 1 ? Color(hex: "0B0C0D") : .white)).frame(maxWidth: .infinity).frame(height: 64)
                .background(style == 0 ? Color(hex: "F4F1EA") : (style == 1 ? HV.lime : Color(hex: "1C1C1E")), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }.buttonStyle(HVPress(scale: 0.95)).frame(width: w)
    }
}
