import SwiftUI

// MARK: - Unified Color Palette (Single Source of Truth)
//
// アプリ全体のブランドカラーはここに一本化する。特に緑系(brandGreen/neonGreen/
// limeGreen)は、以前は#00ff41(ネオングリーン)と#4ade6c(確定デザインのグリーン)が
// 混在していたが、確定色である#4ade6cに統一した。neonGreen/limeGreenはbrandGreenの
// 別名として残している(呼び出し側の書き換えを最小限にするため)。

public extension Color {
    // MARK: - Brand Colors

    /// ブランドカラーのグリーン(#4ade6c、確定デザイン)
    static let brandGreen: Color = Color(hex: "4ade6c")

    /// ブランドカラーのブラック(ダーク背景)
    static let brandBlack: Color = Color(red: 0.05, green: 0.05, blue: 0.08)

    /// ブランドカラーのダークグレー
    static let brandDarkGray: Color = Color(red: 0.1, green: 0.1, blue: 0.12)

    /// ブランドカラーのライトグリーン(補助色)
    static let brandLightGreen: Color = Color(red: 0.2, green: 0.8, blue: 0.6)

    // MARK: - Neon Colors (brandGreen以外は装飾用の補助色)

    /// neonGreen: brandGreenの別名(過去の#00ff41から#4ade6cへ統一)
    static let neonGreen: Color = brandGreen

    /// limeGreen: brandGreenの別名(過去の#00ff41から#4ade6cへ統一)
    static let limeGreen: Color = brandGreen

    static let neonGold: Color = Color(red: 1.00, green: 0.84, blue: 0.00)
    static let neonCyan: Color = Color(red: 0.00, green: 0.90, blue: 1.00)
    static let neonPurple: Color = Color(red: 0.70, green: 0.30, blue: 1.00)
    static let neonPink: Color = Color(red: 1.00, green: 0.20, blue: 0.60)
    static let neonBlue: Color = Color(red: 0.20, green: 0.60, blue: 1.00)

    // MARK: - UI Colors

    static let cardBackground: Color = Color(red: 0.15, green: 0.15, blue: 0.2)
    static let cardBorder: Color = Color(red: 0.2, green: 0.2, blue: 0.4)

    // MARK: - Corkboard (Home画面専用)
    //
    // Home画面(World/Personal/Communityセレクター)専用の、暖色系の「コルクボードに
    // ポラロイドをピン留めした」配色。他画面のダーク背景(brandBlack系)とは意図的に
    // 別系統にしているため、Home画面以外では使わないこと。

    /// コルクボードの背景(暖色系ダークブラウン)
    static let corkboardBackground: Color = Color(hex: "17110c")
    /// 非選択タブの背景
    static let corkboardTabInactive: Color = Color(hex: "241a12")
    /// 非選択タブの文字色
    static let corkboardTabInactiveText: Color = Color(hex: "8a7c6a")
    /// 選択中タブ・コンテンツ面の背景
    static let corkboardTabActive: Color = Color(hex: "2c2116")
    /// 選択中タブの文字色
    static let corkboardTabActiveText: Color = Color(hex: "f2ece2")
    /// ポラロイドカード本体(クリーム色)
    static let corkboardCard: Color = Color(hex: "f4efe4")
    /// ポラロイドカード内の正方形写真エリア背景
    static let corkboardPhotoArea: Color = Color(hex: "e4dcc9")
    /// Personalタブ「今日のカード」の写真エリア背景(他のカードより少し濃く、目立たせる)
    static let corkboardTodayPhotoArea: Color = Color(hex: "c9c0a8")
    /// ポラロイドカードの見出しテキスト(濃い茶色)
    static let corkboardHeading: Color = Color(hex: "26210f")
    /// マスキングテープ風CTAボタンの文字色(濃い緑)
    static let corkboardCTAText: Color = Color(hex: "1f6b3a")
}
