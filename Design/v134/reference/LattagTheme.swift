import SwiftUI

// Lattag v133 のデザイントークン（参考実装）
// 既存の色定義（Color+Neon.swift など）があれば、そちらをこの値に置きかえて一本化すること。
//
// 守るルール
// ・土台は真っ黒。写真がいちばん目立つ
// ・ライム(#C8F25A)は「押せる物」だけ
// ・ガラスは「浮いている操作」だけ（タブ・アクセサリ・写真の上の小さいボタン）
// ・字は3つ：英語の大見出し=Barlow Condensed ExtraBold / UI=システム書体 / 日付スタンプ=Space Mono Bold

enum LTColor {
    static let bg        = Color(hex: 0x000000)   // 土台
    static let surface1  = Color(hex: 0x0E0E10)   // カード
    static let surface2  = Color(hex: 0x151517)   // 入力欄・小さいボタン
    static let surface3  = Color(hex: 0x1D1D20)
    static let hairline  = Color.white.opacity(0.08)
    static let hairline2 = Color.white.opacity(0.14)
    static let ink       = Color(hex: 0xF5F5F7)   // 文字
    static let ink2      = Color(hex: 0xA3A3AB)   // 弱い文字
    static let ink3      = Color(hex: 0x66666E)   // もっと弱い文字

    static let lime      = Color(hex: 0xC8F25A)   // 押せる物だけ
    static let limeInk   = Color(hex: 0x0B0D06)   // ライムの上の文字・#
    static let badge     = Color(hex: 0xFF4F98)   // 通知の数だけ
    static let stamp     = Color(hex: 0xFF9A3C)   // 写真の日付スタンプだけ

    // タグの「#」だけに色をつける（品のあるポップ）
    static let tagPink   = Color(hex: 0xFF7EB6)
    static let tagSky    = Color(hex: 0x6FC6FF)
    static let tagYellow = Color(hex: 0xFFD84D)
    static let tagGray   = Color(hex: 0x8C8C94)

    // 中身の見えないフィルム（ミルク色）とチェキの枠
    static let milkTop    = Color(hex: 0xECEAE3)
    static let milkBottom = Color(hex: 0xD2CEC3)
    static let chekiFrame = Color(hex: 0xF6F5F0)
}

enum LTFont {
    /// 英語の大見出し（GOOD MORNING / FRIENDS / TRIP / 時刻の大きい数字）
    static func display(_ size: CGFloat) -> Font { .custom("BarlowCondensed-ExtraBold", size: size) }
    /// 写真の日付スタンプ（'26 11 25）
    static func stamp(_ size: CGFloat) -> Font { .custom("SpaceMono-Bold", size: size) }
    /// それ以外はシステム書体（SF Pro＋ヒラギノ）
    static func ui(_ size: CGFloat, weight: Font.Weight = .bold) -> Font { .system(size: size, weight: weight) }
}

enum LTRadius {
    static let photo: CGFloat  = 24
    static let card: CGFloat   = 24
    static let button: CGFloat = 18
    static let sheet: CGFloat  = 34
}

enum LTMotion {
    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.82)
    static let out    = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.5)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue:  Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// 英語の大見出し：大文字・白→灰のグラデ。1画面に1つまで
struct DisplayTitle: View {
    let text: String
    var size: CGFloat = 52
    var body: some View {
        Text(text.uppercased())
            .font(LTFont.display(size))
            .foregroundStyle(
                LinearGradient(stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white, location: 0.36),
                    .init(color: Color(hex: 0x8C8C94), location: 1)
                ], startPoint: .top, endPoint: .bottom)
            )
    }
}

/// 写真の上の日付スタンプ（オレンジ・少しにじむ）
struct DateStamp: View {
    let text: String            // 例 "'26 11 25"
    var size: CGFloat = 12.5
    var body: some View {
        Text(text)
            .font(LTFont.stamp(size))
            .foregroundStyle(LTColor.stamp)
            .shadow(color: Color(hex: 0xFF821E).opacity(0.75), radius: 2.5)
    }
}

/// タグ（#だけに色）
struct TagChip: View {
    let text: String
    var hashColor: Color = LTColor.tagGray
    var body: some View {
        (Text("#").foregroundColor(hashColor) + Text(text).foregroundColor(LTColor.ink))
            .font(LTFont.ui(13, weight: .bold))
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(Color.white.opacity(0.07), in: Capsule())
    }
}

/// 大きいライムのボタン（のせる・つぎへ など）
struct LimeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LTFont.ui(16, weight: .heavy))
            .foregroundStyle(LTColor.limeInk)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(LTColor.lime, in: RoundedRectangle(cornerRadius: LTRadius.button, style: .continuous))
            .shadow(color: LTColor.lime.opacity(0.45), radius: 13, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(LTMotion.spring, value: configuration.isPressed)
    }
}

extension View {
    /// ガラスは「浮いている操作」だけに使う。iOS 26 は Liquid Glass、それより前はマテリアル
    @ViewBuilder
    func ltGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}
