import SwiftUI

/// v54:色は すべて `spec/TOKENS.md` の 名前の まま。画面の コードに 色の 数字を 直接 書かない。
/// `stamp`(オレンジ)は 写真の 日付の 印字だけに 使う。ほかは 緑 / 黒 / 白。
enum LaterColor {
    // MARK: - 写ルンですの 配色(昼夜 共通)

    /// カメラ本体の 緑・QR ボタン・Add ボタン・進行バー
    static let film = Color(hex: "24A03C")
    /// 光る 緑(リング・ドット・数字の アクセント)
    static let filmLight = Color(hex: "3BD35A")
    /// 薄い 緑(「のこり 3こま」の 文字・波紋)
    static let filmPale = Color(hex: "9ED6A5")
    /// 暗い 所の 緑の 文字(LIVE・9:00 OPEN)
    static let liveGreen = Color(hex: "7EE08F")
    /// 黄緑(テープ・week.・Oct 2026 など アクセント)
    static let lime = LattagPalette.lime
    /// カメラの 黒い 本体
    static let body = Color(hex: "121212")
    /// 24:00 の 線・赤い 点・帯の 赤
    static let red = Color(hex: "D8262C")
    /// 帯の 金・★(kept)
    static let gold = Color(hex: "C8A46A")
    /// 写真の 日付の 印字だけ(`'26 11 13` `17:42` `FRI` `ME · 7 DAYS`)。ほかに オレンジは 使わない。
    static let stamp = Color(hex: "FF9A3C")

    // MARK: - ハッシュタグの シール 6色(Profile・Friend の チェキ)

    static let stickerColors: [(background: Color, text: Color)] = [
        (LattagPalette.lime, Color(hex: "111111")),
        (Color(hex: "EE5E9C"), Color(hex: "FFFFFF")),
        (Color(hex: "9ED8FF"), Color(hex: "111111")),
        (Color(hex: "FFD60A"), Color(hex: "111111")),
        (Color(hex: "9B8CFF"), Color(hex: "FFFFFF")),
        (Color(hex: "61D278"), Color(hex: "111111")),
    ]

    /// 名前から 決まった色(タグ・シールなど。毎回 同じ言葉には 同じ色)
    static func sticker(for word: String) -> (background: Color, text: Color) {
        let hash = word.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
        return stickerColors[hash % stickerColors.count]
    }

    // MARK: - 昼(9:00〜21:00)

    enum Day {
        static let homeBackground = Color(hex: "EFEFEA")
        static let yesterdayBackground = Color.white
        static let ink = Color(hex: "111111")
        static let sub = Color(hex: "86868C")
        static let sub2 = Color(hex: "8E8E93")
        static let sub3 = Color(hex: "6E6E73")
    }

    // MARK: - 夜(21:00〜9:00)・暗い画面(Friend / ME / Profile / Recap / 暗室)

    enum Night {
        static let background = Color(hex: "000000")
        static let background2 = Color(hex: "050505")
        static let background3 = Color(hex: "0A0A0B")
        static let card = Color(hex: "161618")
        static let card2 = Color(hex: "121214")
        static let line = Color.white.opacity(0.14)
        static let ink = Color.white
        static let sub = Color(hex: "8C8C93")
        static let sub2 = Color(hex: "8E8E95")
        static let sub3 = Color(hex: "C9C9CF")
    }

    /// ガラスの ピル(昼):上 rgba(255,255,255,.80) → 下 rgba(244,244,246,.56)。ぼかし16・彩度1.8 は
    /// `.laterGlass(_:)` の 側で 掛ける。ここは グラデの 色だけ。
    static let dayGlassPill = LinearGradient(
        colors: [Color.white.opacity(0.80), Color(hex: "F4F4F6").opacity(0.56)],
        startPoint: .top, endPoint: .bottom
    )
}
