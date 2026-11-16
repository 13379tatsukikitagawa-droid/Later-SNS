import SwiftUI

/// Design System の 色。値は `spec/TOKENS.md` の ものだけ(`LaterColor` と 同じ 値を 1か所から 呼べる ように)。
/// 新しい 色は 作らない。
enum LGColor {
    static let film = LaterColor.film
    static let filmLight = LaterColor.filmLight
    static let filmPale = LaterColor.filmPale
    static let liveGreen = LaterColor.liveGreen
    static let lime = LaterColor.lime
    static let body = LaterColor.body
    static let red = LaterColor.red
    /// 写真の 日付の 印字 だけ
    static let stamp = LaterColor.stamp
    static let gold = LaterColor.gold

    static let dayHomeBackground = LaterColor.Day.homeBackground
    static let dayInk = LaterColor.Day.ink
    static let nightBackground = Color(hex: "000000")
    static let nightCard = Color(hex: "161618")
    static let nightText = Color.white

    static let stickers = LaterColor.stickerColors
}
