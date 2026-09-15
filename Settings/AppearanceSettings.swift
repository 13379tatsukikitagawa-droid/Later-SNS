import SwiftUI
internal import Combine

// MARK: - アプリ設定マネージャー
@Observable
class AppearanceManager {
    // ダークモード設定
    var colorScheme: ColorSchemeMode = .system
    
    // フォント設定
    var fontStyle: FontStyle = .system
    
    // レイアウトパターン
    var layoutPattern: LayoutPattern = .default
    
    static let shared = AppearanceManager()
    
    enum ColorSchemeMode: String, CaseIterable {
        case light = "ライトモード"
        case dark = "ダークモード"
        case system = "システム設定"
        
        var systemColorScheme: ColorScheme? {
            switch self {
            case .light: return .light
            case .dark: return .dark
            case .system: return nil
            }
        }
    }
    
    enum FontStyle: String, CaseIterable {
        case system = "システムフォント"
        case rounded = "丸ゴシック"
        case serif = "明朝体"
        case monospaced = "等幅フォント"
        
        func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            switch self {
            case .system:
                return .system(size: size, weight: weight)
            case .rounded:
                return .system(size: size, weight: weight, design: .rounded)
            case .serif:
                return .system(size: size, weight: weight, design: .serif)
            case .monospaced:
                return .system(size: size, weight: weight, design: .monospaced)
            }
        }
    }
    
    enum LayoutPattern: String, CaseIterable {
        case `default` = "デフォルト"
        case compact = "コンパクト"
        case spacious = "広々"
        
        var headerPadding: CGFloat {
            switch self {
            case .default: return 40
            case .compact: return 20
            case .spacious: return 60
            }
        }
        
        var itemSpacing: CGFloat {
            switch self {
            case .default: return 12
            case .compact: return 8
            case .spacious: return 16
            }
        }
        
        var profileImageSize: CGFloat {
            switch self {
            case .default: return 110
            case .compact: return 90
            case .spacious: return 130
            }
        }
    }
}

// MARK: - カスタマイズ設定画面
struct AppearanceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var appearanceManager = AppearanceManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景：システムグレー（ごく薄いグレー）
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        colorSchemeSection
                        fontStyleSection
                        layoutPatternSection
                    }
                    .padding(20) // 画面端の余白を20ptに設定
                }
            }
            .navigationTitle("カスタマイズ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
    
    // MARK: - セクション
    
    private var colorSchemeSection: some View {
        SettingsSection(title: "表示モード", icon: "moon.stars.fill", color: .blue) {
            VStack(spacing: 12) {
                ForEach(AppearanceManager.ColorSchemeMode.allCases, id: \.self) { mode in
                    SettingOptionButton(
                        title: mode.rawValue,
                        isSelected: appearanceManager.colorScheme == mode
                    ) {
                        withAnimation {
                            appearanceManager.colorScheme = mode
                        }
                    }
                }
            }
        }
    }
    
    private var fontStyleSection: some View {
        SettingsSection(title: "フォントスタイル", icon: "textformat", color: .green) {
            VStack(spacing: 12) {
                ForEach(AppearanceManager.FontStyle.allCases, id: \.self) { fontStyle in
                    SettingOptionButton(
                        title: fontStyle.rawValue,
                        isSelected: appearanceManager.fontStyle == fontStyle,
                        font: fontStyle.font(size: 16, weight: .medium)
                    ) {
                        withAnimation {
                            appearanceManager.fontStyle = fontStyle
                        }
                    }
                }
            }
        }
    }
    
    private var layoutPatternSection: some View {
        SettingsSection(title: "レイアウト", icon: "square.grid.2x2", color: .purple) {
            VStack(spacing: 12) {
                ForEach(AppearanceManager.LayoutPattern.allCases, id: \.self) { pattern in
                    SettingOptionButton(
                        title: pattern.rawValue,
                        isSelected: appearanceManager.layoutPattern == pattern
                    ) {
                        withAnimation {
                            appearanceManager.layoutPattern = pattern
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 設定セクション
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader
            content
        }
    }
    
    private var sectionHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
            
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.white)
        }
    }
}

// MARK: - 設定オプションボタン
struct SettingOptionButton: View {
    let title: String
    let isSelected: Bool
    var font: Font = .system(size: 16, weight: .medium)
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            buttonContent
        }
        .buttonStyle(.plain)
    }
    
    private var buttonContent: some View {
        HStack {
            Text(title)
                .font(font)
                .foregroundStyle(.white)
            
            Spacer()
            
            if isSelected {
                checkmark
            }
        }
        .padding(16)
        .background(backgroundStyle)
        .overlay(borderStyle)
    }
    
    private var checkmark: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 22))
            .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.6))
    }
    
    private var backgroundStyle: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous) // 角丸を24ptに設定
            .fill(isSelected ? Color.white.opacity(0.1) : Color.white.opacity(0.04))
    }
    
    private var borderStyle: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(
                isSelected ? Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.5) : Color.white.opacity(0.1),
                lineWidth: isSelected ? 2 : 1
            )
    }
}
