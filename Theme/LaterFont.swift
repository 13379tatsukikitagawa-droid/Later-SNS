import SwiftUI
import UIKit

/// v118(v115 ・ v54 を 上書き):字は `Typo` 1か所から 出す。
/// - 見出し(英語)= Instrument Serif(太字に しない)+ 日本語は うしろに Later Mincho(Noto Serif JP Black を 切った 物)を つなぐ
/// - 日本語の 見出し(名前 ・ Trip 名)= Later Mincho
/// - 本文 ・ ボタン ・ ラベル ・ 時計 = SF Pro + ヒラギノ角ゴ(システム)の 太字。Inter ・ Space Mono は 使わない
/// 大きさは 固定(Dynamic Type では 大きく しない)。字間は 呼び出し側で `.tracking()`(`Typo.em` で pt に)。
@MainActor
enum Typo {
    /// `Later Mincho` の PostScript 名(Fonts/LaterMincho-Black.otf)
    static let minchoName = "LaterMincho-Black"

    /// 見出し:Instrument Serif(Regular / Italic)+ Later Mincho。字間は `titleTracking`(-0.015em)
    static func title(_ size: CGFloat, italic: Bool = false) -> Font {
        Font(LF.cascaded(base: italic ? "InstrumentSerif-Italic" : "InstrumentSerif-Regular", fallback: minchoName, size: size))
    }
    static func titleTracking(_ size: CGFloat) -> CGFloat { em(size, -0.015) }

    /// 日本語の 見出し(名前 ・ Trip 名 ・「リンクを 送る」)
    static func mincho(_ size: CGFloat) -> Font { .custom(minchoName, fixedSize: size) }

    /// 本文 ・ ボタン(SF Pro + ヒラギノ角ゴ)。前の Inter の 太さ(500〜900)を そのまま 受けて、いちばん 近い 太字に
    static func ui(_ weight: Int, _ size: CGFloat) -> Font {
        .system(size: size, weight: uiWeight(weight))
    }
    static func uiWeight(_ weight: Int) -> Font.Weight {
        switch weight {
        case ..<600: return .semibold
        case 600..<750: return .bold
        case 750..<850: return .heavy
        default: return .black
        }
    }

    /// ラベル ・ 時刻 ・ 小さな 大文字(前の Space Mono の 場所)。数字の 幅を そろえる
    static func label(_ size: CGFloat, bold: Bool = true) -> Font {
        .system(size: size, weight: bold ? .heavy : .bold).monospacedDigit()
    }

    /// em → pt
    static func em(_ size: CGFloat, _ em: CGFloat) -> CGFloat { size * em }
}

/// 手書き(チェキの 字)と 日本語の つなぎ。ほかの 字は `Typo`。
@MainActor
enum LF {
    /// Caveat SemiBold(手書き)。日本語の 字(「ゆい」など)は うしろに つないだ Klee One SemiBold が 受けもつ。
    static func hand(_ size: CGFloat) -> Font {
        Font(Self.cascaded(base: "Caveat-SemiBold", fallback: "KleeOne-SemiBold", size: size))
    }

    // MARK: - 日本語の つなぎ(cascadeList)

    /// 英語の 書体には 日本語の 字が 無い。iOS は 足りない字を 勝手に ヒラギノ角ゴ に するので、
    /// `.cascadeList` で 指定の 日本語書体を うしろに つなぎ、モックと 同じ 見た目に する。
    static func cascaded(base: String, fallback: String, size: CGFloat) -> UIFont {
        let key = CacheKey(base: base, fallback: fallback, size: size)
        if let cached = cache[key] { return cached }
        let baseFont = UIFont(name: base, size: size) ?? .systemFont(ofSize: size)
        guard let fallbackFont = UIFont(name: fallback, size: size) else {
            cache[key] = baseFont
            return baseFont
        }
        let withCascade = baseFont.fontDescriptor.addingAttributes([.cascadeList: [fallbackFont.fontDescriptor]])
        let font = UIFont(descriptor: withCascade, size: size)
        cache[key] = font
        return font
    }

    private struct CacheKey: Hashable { let base: String; let fallback: String; let size: CGFloat }
    private static var cache: [CacheKey: UIFont] = [:]
}
