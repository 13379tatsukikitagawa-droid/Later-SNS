import SwiftUI

/// v110 §3-1:ポップ 3色(ライムは `HV.lime`)。使う 所は ステッカー ・ タグ ・ Trip の 色 ・ 数の 丸 / リアクション だけ。
/// 面 ぜんぶを ぬらない ・ 字の 色に しない。
enum PopColor {
    static let pink = Color(hex: "FF7AB6")
    static let sky = Color(hex: "6EC8FF")
    static let sun = Color(hex: "FFD84D")
    static let lime = LattagPalette.lime
    /// ぷっくり ボタンの 下の 濃い 色
    static let limeDeep = Color(hex: "8FB23A")
    static let skyDeep = Color(hex: "3E93C4")
    /// 地(今の まま)
    static let ground = Color(hex: "0A0A0B")
    static let card = Color(hex: "151517")
    static let raised = Color(hex: "1D1D20")
    static let paper = Color(hex: "F7F5EF")

    /// Trip の 色:作った 順に pink → sky → sun → lime
    static let tripCycle: [Color] = [pink, sky, sun, lime]
    static func trip(_ index: Int) -> Color { tripCycle[((index % 4) + 4) % 4] }
}
