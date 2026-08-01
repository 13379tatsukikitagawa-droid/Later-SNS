import SwiftUI

/// This file is a placeholder for AppearanceSettingsView to avoid redeclaration.
/// The full implementation lives in AppearanceSettings.swift.

/// 外観設定画面
struct AppearanceSettingsPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("themeColor") private var themeColorName: String = "green"
    @AppStorage("darkModePreference") private var darkModePreference: String = "system"
    
    private var themeColor: Color {
        switch themeColorName {
        case "green": return .brandGreen
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        default: return .brandGreen
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Text("外観設定")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.top, 24)
                        
                        Text("開発中...")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .foregroundStyle(themeColor)
                }
            }
        }
    }
}
