import SwiftUI

/// 昼(day)と夜(night)。
nonisolated enum ThemeMode: Sendable, Equatable {
    case day, night
}

/// 色の定義(16進 RGB と不透明度)。テストで正確に比べられるよう、定数として公開する。
nonisolated struct PaletteHex: Sendable, Equatable {
    var rgb: UInt32
    var alpha: Double = 1

    var color: Color {
        Color(.sRGB,
              red: Double((rgb >> 16) & 0xFF) / 255,
              green: Double((rgb >> 8) & 0xFF) / 255,
              blue: Double(rgb & 0xFF) / 255,
              opacity: alpha)
    }
}

/// 昼夜ごとの色セット。`@Environment(\.palette)` で読む。
nonisolated struct Palette: Sendable, Equatable {
    let bgHex, fillHex, lineHex, inkHex, subHex, dimHex: PaletteHex
    let accentHex, accentTextHex, stampHex, paperHex: PaletteHex

    var bg: Color { bgHex.color }
    var fill: Color { fillHex.color }
    var line: Color { lineHex.color }
    var ink: Color { inkHex.color }
    var sub: Color { subHex.color }
    var dim: Color { dimHex.color }
    var accent: Color { accentHex.color }
    var accentText: Color { accentTextHex.color }
    var stamp: Color { stampHex.color }
    var paper: Color { paperHex.color }

    static let day = Palette(
        bgHex: PaletteHex(rgb: 0xFFFFFF),
        fillHex: PaletteHex(rgb: 0xF3F3F6),
        lineHex: PaletteHex(rgb: 0xE5E5EA),
        inkHex: PaletteHex(rgb: 0x111111),
        subHex: PaletteHex(rgb: 0x6E6E73),
        dimHex: PaletteHex(rgb: 0x8E8E93),
        accentHex: PaletteHex(rgb: 0xFF6A1A),
        accentTextHex: PaletteHex(rgb: 0xC2410C),
        stampHex: PaletteHex(rgb: 0xFF8A3D),
        paperHex: PaletteHex(rgb: 0xFFFDF8)
    )

    static let night = Palette(
        bgHex: PaletteHex(rgb: 0x09090B),
        fillHex: PaletteHex(rgb: 0xFFFFFF, alpha: 0.09),
        lineHex: PaletteHex(rgb: 0xFFFFFF, alpha: 0.10),
        inkHex: PaletteHex(rgb: 0xF4F4F6),
        subHex: PaletteHex(rgb: 0x9A9AA3),
        dimHex: PaletteHex(rgb: 0x6B6B72),
        accentHex: PaletteHex(rgb: 0xFF9E5E),
        accentTextHex: PaletteHex(rgb: 0xFF9E5E),
        stampHex: PaletteHex(rgb: 0xFF8A3D),
        paperHex: PaletteHex(rgb: 0xFFFDF8)
    )

    static func `for`(_ mode: ThemeMode) -> Palette {
        mode == .night ? night : day
    }
}

extension EnvironmentValues {
    @Entry var palette: Palette = .day
}

// MARK: - グループを追加(v13 ①)・Home の「+ 追加」カード

/// 「グループを追加」シートと、Home の「+ 追加」カードの色。昼 / 夜。
/// `.white` や `Color(white:)` を画面に直接書かない(シートだけ白・文字も白、で読めなくなっていた)。
nonisolated struct GroupAddColors: Sendable, Equatable {
    let isNight: Bool

    private func pick(_ day: UInt32, _ night: UInt32) -> Color { PaletteHex(rgb: isNight ? night : day).color }

    /// シートの背景:白 / #1C1C1F
    var sheet: Color { pick(0xFFFFFF, 0x1C1C1F) }
    /// 見出し
    var title: Color { pick(0x111114, 0xFFFFFF) }
    /// つくる(主役)
    var primaryBg: Color { pick(0x111114, 0xFFFFFF) }
    var primaryText: Color { pick(0xFFFFFF, 0x111114) }
    /// つくる の説明文(主役の面の上)
    var primaryNote: Color { pick(0xC9C9D1, 0x5F5F66) }
    /// 参加する(脇役):面・ふち 1.5pt・文字
    var secondaryBg: Color { pick(0xFFFFFF, 0x1C1C1F) }
    var secondaryLine: Color { pick(0xC9C9D1, 0x5A5A62) }
    var secondaryText: Color { pick(0x111114, 0xFFFFFF) }
    /// 参加する の左の丸・QR アイコン
    var secondaryIconBg: Color { pick(0xF3F3F6, 0x2C2C30) }
    var secondaryIcon: Color { pick(0x111114, 0xFFFFFF) }
    /// 説明文(2行目)・「あと◯個、入れます」
    var note: Color { pick(0x5F5F66, 0xB4B4BC) }
    /// 「+」の白(夕やけの丸の上。昼夜とも)
    var plus: Color { PaletteHex(rgb: 0xFFFFFF).color }

    /// 夕やけのグラデ(#FFB347 → #FF6A1A → #FF5C8A)
    static let sunset: [Color] = [PaletteHex(rgb: 0xFFB347).color, PaletteHex(rgb: 0xFF6A1A).color, PaletteHex(rgb: 0xFF5C8A).color]
}

extension Palette {
    var groupAdd: GroupAddColors { GroupAddColors(isNight: self == .night) }
}
