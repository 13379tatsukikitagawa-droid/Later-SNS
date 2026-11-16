import SwiftUI
import UIKit

/// Design System の 書体。実体は `LF`(6書体・固定サイズ・日本語の つなぎ)。ここは 名前で 呼ぶ 入口。
@MainActor
enum LGFont {
    static func inter(_ weight: Int, _ size: CGFloat) -> Font { LF.inter(weight, size) }
    static func serif(_ size: CGFloat, italic: Bool = false) -> Font { LF.serif(size, italic: italic) }
    static func mono(_ size: CGFloat, bold: Bool = true) -> Font { LF.mono(size, bold: bold) }
    static func hand(_ size: CGFloat) -> Font { LF.hand(size) }
    /// Noto Serif JP Bold(日本語の 大きな 名前。モックの `Later Mincho`)
    static func mincho(_ size: CGFloat) -> Font { .custom("NotoSerifJP-Bold", fixedSize: size) }
    /// Klee One SemiBold(日本語の 手書き)
    static func klee(_ size: CGFloat) -> Font { .custom("KleeOne-SemiBold", fixedSize: size) }

    /// 6書体 それぞれの PostScript 名(Info.plist の UIAppFonts で 登録した もの)
    static let postScriptNames: [String] = [
        "Inter-Black", "InstrumentSerif-Regular", "InstrumentSerif-Italic",
        "SpaceMono-Bold", "Caveat-SemiBold", "NotoSerifJP-Bold", "KleeOne-SemiBold",
    ]

    /// 名前で 解決できない 書体の 一覧(空なら OK)
    static func missingFonts() -> [String] {
        postScriptNames.filter { UIFont(name: $0, size: 12) == nil }
    }
}
