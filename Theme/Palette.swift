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
