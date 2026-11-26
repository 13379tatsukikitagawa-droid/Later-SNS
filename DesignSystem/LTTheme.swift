import SwiftUI

// v134 Phase 1:デザインの 決まり(トークン)。色の 数字は ここと `LattagPalette`(Shared)だけに 書く。
// 守る こと:土台は 真っ黒 ・ ライムは 押せる 物だけ ・ ガラスは 浮いている 操作だけ(`lgGlass`)・
// 字は 3つ(Barlow Condensed = 英語の 大見出し ・ システム書体 = UI ・ Space Mono Bold = 日付スタンプ)。

enum LTColor {
    static let bg        = Color(hex6: 0x000000)
    static let surface1  = Color(hex6: 0x0E0E10)
    static let surface2  = Color(hex6: 0x151517)
    static let surface3  = Color(hex6: 0x1D1D20)
    static let hairline  = Color.white.opacity(0.08)
    static let hairline2 = Color.white.opacity(0.14)
    static let ink       = Color(hex6: 0xF5F5F7)
    static let ink2      = Color(hex6: 0xA3A3AB)
    static let ink3      = Color(hex6: 0x66666E)

    static let lime      = LattagPalette.lime          // 押せる 物だけ(定義は 1か所)
    static let limeInk   = Color(hex6: 0x0B0D06)
    static let badge     = Color(hex6: 0xFF4F98)       // 通知の 数だけ
    static let stamp     = Color(hex6: 0xFF9A3C)       // 写真の 日付スタンプだけ

    static let tagPink   = Color(hex6: 0xFF7EB6)
    static let tagSky    = Color(hex6: 0x6FC6FF)
    static let tagYellow = Color(hex6: 0xFFD84D)
    static let tagGray   = Color(hex6: 0x8C8C94)

    static let milkTop    = Color(hex6: 0xECEAE3)
    static let milkBottom = Color(hex6: 0xD2CEC3)
    static let chekiFrame = Color(hex6: 0xF6F5F0)
}

enum LTFont {
    /// 英語の 大見出し(GOOD MORNING / FRIENDS / TRIP / 時刻の 大きい 数字)
    static func display(_ size: CGFloat) -> Font { .custom("BarlowCondensed-ExtraBold", size: size) }
    /// 写真の 日付スタンプ('26 11 25)
    static func stamp(_ size: CGFloat) -> Font { .custom("SpaceMono-Bold", size: size) }
    /// それ以外は システム書体
    static func ui(_ size: CGFloat, weight: Font.Weight = .bold) -> Font { .system(size: size, weight: weight) }
}

enum LTRadius {
    static let photo: CGFloat = 24
    static let card: CGFloat = 24
    static let button: CGFloat = 18
    static let sheet: CGFloat = 34
}

enum LTMotion {
    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.82)
    static let out = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.5)
}

/// 英語の 大見出し:大文字 ・ 白 → 灰の グラデ。1画面に 1つまで
struct DisplayTitle: View {
    let text: String
    var size: CGFloat = 52
    var body: some View {
        Text(text.uppercased())
            .font(LTFont.display(size))
            .foregroundStyle(LinearGradient(stops: [
                .init(color: .white, location: 0),
                .init(color: .white, location: 0.36),
                .init(color: LTColor.tagGray, location: 1),
            ], startPoint: .top, endPoint: .bottom))
            .accessibilityAddTraits(.isHeader)
    }
}

/// 写真の 上の 日付スタンプ(オレンジ ・ 少し にじむ)
struct DateStamp: View {
    let text: String            // 例 "'26 11 25"
    var size: CGFloat = 12.5
    var body: some View {
        Text(text)
            .font(LTFont.stamp(size))
            .foregroundStyle(LTColor.stamp)
            .shadow(color: Color(hex6: 0xFF821E, opacity: 0.75), radius: 2.5)
    }
}

/// タグ(# だけに 色)
struct TagChip: View {
    let text: String
    var hashColor: Color = LTColor.tagGray
    var body: some View {
        (Text("#").foregroundColor(hashColor) + Text(text).foregroundColor(LTColor.ink))
            .font(LTFont.ui(13))
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(Color.white.opacity(0.07), in: Capsule())
    }
}

/// 大きい ライムの ボタン(のせる ・ つぎへ)
struct LimeButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LTFont.ui(16, weight: .heavy))
            .foregroundStyle(LTColor.limeInk)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(LTColor.lime, in: RoundedRectangle(cornerRadius: LTRadius.button, style: .continuous))
            .shadow(color: LTColor.lime.opacity(0.45), radius: 13, y: 8)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(LTMotion.spring, value: configuration.isPressed)
    }
}
