import SwiftUI
import UIKit

/// Design System の 書体。実体は `Typo`(v118)。ここは 名前で 呼ぶ 入口。
@MainActor
enum LGFont {
    static func inter(_ weight: Int, _ size: CGFloat) -> Font { Typo.ui(weight, size) }
    static func serif(_ size: CGFloat, italic: Bool = false) -> Font { Typo.title(size, italic: italic) }
    static func mono(_ size: CGFloat, bold: Bool = true) -> Font { Typo.label(size, bold: bold) }
    static func hand(_ size: CGFloat) -> Font { LF.hand(size) }
    /// Later Mincho(Noto Serif JP Black を 切った 物。日本語の 大きな 名前)
    static func mincho(_ size: CGFloat) -> Font { Typo.mincho(size) }
    /// Klee One SemiBold(日本語の 手書き)
    static func klee(_ size: CGFloat) -> Font { .custom("KleeOne-SemiBold", fixedSize: size) }

    /// 入れて いる 書体の PostScript 名(Info.plist の UIAppFonts で 登録した もの)
    static let postScriptNames: [String] = [
        "InstrumentSerif-Regular", "InstrumentSerif-Italic",
        "Caveat-SemiBold", "Caveat-Bold", Typo.minchoName, "KleeOne-SemiBold",
    ]

    /// 名前で 解決できない 書体の 一覧(空なら OK)
    static func missingFonts() -> [String] {
        postScriptNames.filter { UIFont(name: $0, size: 12) == nil }
    }
}
