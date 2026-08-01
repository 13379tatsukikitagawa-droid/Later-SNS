import SwiftUI

// MARK: - Unified Color Palette (Single Source of Truth)

public extension Color {
    // MARK: - Neon Colors
    
    /// Vibrant neon green (#00ff41)
    static let neonGreen: Color = Color(red: 0.00, green: 1.00, blue: 0.255)
    
    /// Lime green (alias for neonGreen for compatibility)
    static let limeGreen: Color = Color(red: 0.00, green: 1.00, blue: 0.255)
    
    /// Vibrant gold neon color
    static let neonGold: Color = Color(red: 1.00, green: 0.84, blue: 0.00)
    
    /// Vibrant cyan neon color
    static let neonCyan: Color = Color(red: 0.00, green: 0.90, blue: 1.00)
    
    /// Vibrant purple neon color
    static let neonPurple: Color = Color(red: 0.70, green: 0.30, blue: 1.00)
    
    /// Vibrant pink neon color
    static let neonPink: Color = Color(red: 1.00, green: 0.20, blue: 0.60)
    
    /// Vibrant blue neon color
    static let neonBlue: Color = Color(red: 0.20, green: 0.60, blue: 1.00)
    
    // MARK: - Brand Colors
    
    /// Brand green color (alias for neonGreen)
    static var brandGreen: Color { neonGreen }
    
    /// Brand black color
    static var brandBlack: Color { Color(red: 0.05, green: 0.05, blue: 0.08) }
    
    /// Brand dark gray
    static var brandDarkGray: Color { Color(red: 0.1, green: 0.1, blue: 0.12) }
    
    /// Brand light green
    static let brandLightGreen: Color = Color(red: 0.2, green: 0.8, blue: 0.6)
    
    // MARK: - UI Colors
    
    /// Card background color
    static let cardBackground: Color = Color(red: 0.15, green: 0.15, blue: 0.2)
    
    /// Card border color
    static let cardBorder: Color = Color(red: 0.2, green: 0.2, blue: 0.4)
}
