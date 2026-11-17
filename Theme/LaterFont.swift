import SwiftUI
import UIKit

/// v54:書体は 6つだけ(すべて SIL OFL・Google Fonts から 入手)。
/// Inter(本文・ボタン・ロゴ)/ Instrument Serif(英語の 見出し)/ Space Mono(ラベル・時刻)/
/// Caveat(手書き)/ Noto Serif JP Bold(日本語の 見出し)/ Klee One SemiBold(日本語の 手書き)。
///
/// 大きさは 固定(`fixedSize`)。モックの pt を そのまま 使い、Dynamic Type では 大きくしない
/// (画面ごとに くずれるため)。字間は 呼び出し側で `.tracking()` に `MEASURED_SPEC.md` の 値を 入れる。
@MainActor
enum LF {
    /// Inter 500 / 700 / 800 / 900(いちばん近い 太さに まとめる)
    static func inter(_ weight: Int, _ size: CGFloat) -> Font {
        let name: String
        switch weight {
        case ..<600: name = "Inter-Medium"
        case 600..<750: name = "Inter-Bold"
        case 750..<850: name = "Inter-ExtraBold"
        default: name = "Inter-Black"
        }
        return .custom(name, fixedSize: size)
    }

    /// Instrument Serif(Regular / Italic)。日本語の 字が 混じっても 崩れないよう、
    /// うしろに Noto Serif JP Bold を `.cascadeList` で つないだ 書体を 返す。
    static func serif(_ size: CGFloat, italic: Bool = false) -> Font {
        Font(Self.cascaded(base: italic ? "InstrumentSerif-Italic" : "InstrumentSerif-Regular", fallback: "NotoSerifJP-Bold", size: size))
    }

    /// Space Mono(Regular / Bold)。ラベル・時刻・小さな大文字の文字に使う。
    static func mono(_ size: CGFloat, bold: Bool = true) -> Font {
        .custom(bold ? "SpaceMono-Bold" : "SpaceMono-Regular", fixedSize: size)
    }

    /// Caveat SemiBold(手書き)。日本語の 字(「ゆい」など)は うしろに つないだ Klee One SemiBold が 受けもつ。
    static func hand(_ size: CGFloat) -> Font {
        Font(Self.cascaded(base: "Caveat-SemiBold", fallback: "KleeOne-SemiBold", size: size))
    }

    // MARK: - 日本語の つなぎ(cascadeList)

    /// 英語の 書体には 日本語の 字が 無い。iOS は 足りない字を 勝手に ヒラギノ角ゴ に するので、
    /// `.cascadeList` で 指定の 日本語書体を うしろに つなぎ、モックと 同じ 見た目に する。
    private static func cascaded(base: String, fallback: String, size: CGFloat) -> UIFont {
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
