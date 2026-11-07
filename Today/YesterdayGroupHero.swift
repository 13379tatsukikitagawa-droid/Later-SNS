import SwiftUI

// 昨日 → グループ タブの ヒーロー(グループが 0件のときだけ)。見本:later_v22.html の「昨日 → グループ」。
// 幅 350 × 高さ 300(中央よせ・せまい画面では 左右 16pt あけて ちぢめる)。
// まんなかに 自分(頭文字・虹色のリング・「あなた」)、まわりに 点線の席が 7つ、ハッシュタグの シールが 4枚。

enum YesterdayHeroLayout {
    static let size = CGSize(width: 350, height: 300)

    struct Seat { let x: CGFloat; let y: CGFloat; let color: Color }
    struct Sticker { let text: String; let x: CGFloat; let y: CGFloat; let angle: Double; let bg: Color; let fg: Color }

    /// 席(中央からの位置)。色は ピンク / ミント / オレンジ / 水色 / ライム / 紫 / 黄
    static let seats: [Seat] = [
        Seat(x: 0, y: -82, color: Color(hex: "EE6F9C")),
        Seat(x: -95, y: -52, color: Color(hex: "6EE0C0")),
        Seat(x: 96, y: -50, color: Color(hex: "F5A965")),
        Seat(x: -118, y: 14, color: Color(hex: "66C4F5")),
        Seat(x: 119, y: 18, color: Color(hex: "B5E85A")),
        Seat(x: -54, y: 70, color: Color(hex: "9A82F2")),
        Seat(x: 54, y: 72, color: Color(hex: "F5D84A")),
    ]

    static let stickers: [Sticker] = [
        Sticker(text: "#放課後", x: -112, y: -104, angle: -8, bg: Color(hex: "EE5E9C"), fg: .white),
        Sticker(text: "#いつメン", x: 104, y: -98, angle: 8, bg: Color(hex: "C8F25A"), fg: Color(hex: "111111")),
        Sticker(text: "#部活", x: -118, y: 102, angle: 7, bg: Color(hex: "9ED8FF"), fg: Color(hex: "111111")),
        Sticker(text: "#帰り道", x: 112, y: 106, angle: -6, bg: Color(hex: "F2A65A"), fg: Color(hex: "111111")),
    ]

    static let ringColors: [Color] = ["F5E26A", "8FE6A8", "6ECBF5", "9A82F2", "F27AB0", "F5A965", "F5E26A"].map { Color(hex: $0) }

    /// 画面の幅に入る 倍率(左右 16pt あける)。350 より せまいときだけ ちぢめる
    static func scale(forWidth width: CGFloat) -> CGFloat {
        min(1, max(0.7, (width - 32) / size.width))
    }
}

struct YesterdayGroupHero: View {
    @Environment(\.palette) private var palette
    let userName: String
    /// 席(+)を押した → つくる
    let onSeat: () -> Void

    private var initial: String { userName.first.map(String.init) ?? "あ" }

    var body: some View {
        let night = palette.isNight
        let center = CGPoint(x: YesterdayHeroLayout.size.width / 2, y: YesterdayHeroLayout.size.height / 2)
        ZStack {
            // 各席から まんなかへ、うすい灰の 点線
            Path { path in
                for seat in YesterdayHeroLayout.seats {
                    path.move(to: center)
                    path.addLine(to: CGPoint(x: center.x + seat.x, y: center.y + seat.y))
                }
            }
            .stroke(night ? Color(hex: "3A3A40") : Color(hex: "D9D8DE"), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [3, 5]))

            ForEach(Array(YesterdayHeroLayout.seats.enumerated()), id: \.offset) { _, seat in
                Button(action: onSeat) { seatView(seat, night: night) }
                    .buttonStyle(.plain)
                    .offset(x: seat.x, y: seat.y)
                    .accessibilityLabel("席。押すと グループを つくる")
            }

            ForEach(Array(YesterdayHeroLayout.stickers.enumerated()), id: \.offset) { _, sticker in
                stickerView(sticker, night: night)
                    .rotationEffect(.degrees(sticker.angle))
                    .offset(x: sticker.x, y: sticker.y)
            }

            core(night: night)
        }
        .frame(width: YesterdayHeroLayout.size.width, height: YesterdayHeroLayout.size.height)
    }

    private func seatView(_ seat: YesterdayHeroLayout.Seat, night: Bool) -> some View {
        Circle()
            .fill(seat.color.opacity(0.1))
            .overlay(Circle().strokeBorder(seat.color, style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
            .overlay(Text("+").font(.system(size: 30, weight: .light)).foregroundStyle(seat.color).offset(y: -1))
            .frame(width: 52, height: 52)
            .shadow(color: seat.color.opacity(night ? 0.5 : 0.28), radius: 11)
            .contentShape(Circle())
    }

    func stickerView(_ sticker: YesterdayHeroLayout.Sticker, night: Bool) -> some View {
        Text(sticker.text)
            .font(.system(size: 15, weight: .black))
            .tracking(-0.02 * 15)
            .foregroundStyle(sticker.fg)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(sticker.bg))
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(night ? Color.white.opacity(0.18) : Color(hex: "2A1D1D"))
                .offset(x: 3, y: 4))
            .fixedSize()
    }

    private func core(night: Bool) -> some View {
        ZStack {
            Circle().fill(AngularGradient(colors: YesterdayHeroLayout.ringColors, center: .center))
            Circle()
                .fill(RadialGradient(colors: [Color(hex: "F8B880"), Color(hex: "E2677F"), Color(hex: "9A4A7A")], center: UnitPoint(x: 0.35, y: 0.28), startRadius: 0, endRadius: 60))
                .padding(6)
            Text(initial).font(.system(size: 44, weight: .black)).foregroundStyle(.white)
        }
        .frame(width: 104, height: 104)
        .overlay(alignment: .bottom) {
            Text("あなた")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color(hex: "EE5E9C")))
                .background(Capsule().fill(night ? Color.white.opacity(0.18) : Color(hex: "2A1D1D")).offset(x: 2, y: 3))
                .fixedSize()
                .offset(y: 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("あなた")
    }
}

/// 見出し「なかまと、/ 昨日を見せあおう。」(「昨日」の下に 太い ピンクの マーカー)+ サブ
struct YesterdayGroupHeadline: View {
    @Environment(\.palette) private var palette
    /// マーカーの 引かれ具合 0〜1
    var marker: Double = 1

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 0) {
                Text("なかまと、")
                HStack(spacing: 0) {
                    Text("昨日")
                        .background(alignment: .bottomLeading) {
                            GeometryReader { proxy in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: "F28CB8"))
                                    .frame(width: proxy.size.width * marker, height: 34 * 0.34)
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                                    .padding(.bottom, 4)
                            }
                        }
                    Text("を見せあおう。")
                }
            }
            .font(.system(size: 34, weight: .black))
            .tracking(-0.04 * 34)
            .lineSpacing(6)
            .foregroundStyle(palette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("なかまと、昨日を見せあおう。")
            .accessibilityAddTraits(.isHeader)

            Text("4〜8人のグループ。\n1枚撮ると、みんなの写真が届きます。")
                .font(.system(size: 12.5, weight: .medium))
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.sub)
        }
        .frame(maxWidth: .infinity)
    }
}
