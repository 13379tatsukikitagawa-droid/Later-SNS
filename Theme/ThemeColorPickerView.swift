import SwiftUI

/// テーマカラー選択画面
struct ThemeColorPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTheme: String
    
    @State private var showSuccessMessage = false
    
    private let themeOptions: [(name: String, color: Color, displayName: String)] = [
        ("green", .brandGreen, "ネオングリーン"),
        ("blue", .blue, "ブルー"),
        ("purple", .purple, "パープル"),
        ("orange", .orange, "オレンジ"),
        ("pink", .pink, "ピンク")
    ]
    
    private var currentThemeColor: Color {
        themeOptions.first { $0.name == selectedTheme }?.color ?? .brandGreen
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // ヘッダー
                        headerSection
                        
                        // カラーオプション
                        colorOptions
                        
                        // プレビュー
                        previewSection
                    }
                    .padding(.vertical, 24)
                }
                .scrollIndicators(.hidden)
                
                // 成功メッセージ
                if showSuccessMessage {
                    successMessageOverlay
                }
            }
            .navigationTitle("テーマカラー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("完了")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(currentThemeColor)
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [currentThemeColor, currentThemeColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("テーマカラーを選択")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            
            Text("お好みの色でアプリをカスタマイズ")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Color Options
    
    private var colorOptions: some View {
        VStack(spacing: 16) {
            ForEach(themeOptions, id: \.name) { option in
                ColorOption(
                    name: option.displayName,
                    color: option.color,
                    isSelected: selectedTheme == option.name
                ) {
                    selectTheme(option.name)
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("プレビュー")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            
            // プレビューカード
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(currentThemeColor)
                    
                    Text("Later")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Spacer()
                }
                
                HStack {
                    Text("ボタンのプレビュー")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(currentThemeColor)
                        )
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(currentThemeColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Success Message
    
    private var successMessageOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(currentThemeColor)
            
            Text("テーマカラーを変更しました")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.brandBlack.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(currentThemeColor.opacity(0.3), lineWidth: 2)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 30)
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Helper Functions
    
    private func selectTheme(_ themeName: String) {
        // ハプティクス
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        selectedTheme = themeName
        
        // 成功メッセージを表示
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showSuccessMessage = true
        }
        
        // 1.5秒後に自動で非表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showSuccessMessage = false
            }
        }
    }
}

// MARK: - Color Option Component

private struct ColorOption: View {
    let name: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // カラーサンプル
                Circle()
                    .fill(color)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: color.opacity(0.5), radius: 8)
                
                // カラー名
                Text(name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                // 選択マーク
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(color)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.1 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isSelected ? color.opacity(0.5) : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ThemeColorPickerView(selectedTheme: .constant("green"))
}
