import SwiftUI

/// アプリアイコン選択画面
struct AppIconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("themeColor") private var themeColorName: String = "green"
    
    @State private var selectedIcon: String? = nil
    @State private var showSuccessMessage = false
    
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
    
    // 利用可能なアイコン一覧
    private let availableIcons: [(name: String?, displayName: String)] = [
        (nil, "デフォルト"),
        ("AppIcon-Dark", "ダークモード"),
        ("AppIcon-Neon", "ネオン"),
        ("AppIcon-Minimal", "ミニマル"),
        ("AppIcon-Retro", "レトロ")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // ヘッダー説明
                        headerSection
                        
                        // アイコン一覧
                        iconGrid
                        
                        // 注意事項
                        noticeSection
                    }
                    .padding(.vertical, 24)
                }
                .scrollIndicators(.hidden)
                
                // 成功メッセージ
                if showSuccessMessage {
                    successMessageOverlay
                }
            }
            .navigationTitle("アプリアイコン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("完了")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(themeColor)
                    }
                }
            }
            .onAppear {
                // 現在のアイコンを取得
                if let currentIconName = UIApplication.shared.alternateIconName {
                    selectedIcon = currentIconName
                } else {
                    selectedIcon = nil
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "app.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [themeColor, themeColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("アプリアイコンを選択")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            
            Text("お好みのデザインに変更できます")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Icon Grid
    
    private var iconGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 20) {
            ForEach(availableIcons, id: \.name) { icon in
                IconOption(
                    iconName: icon.name,
                    displayName: icon.displayName,
                    isSelected: selectedIcon == icon.name,
                    themeColor: themeColor
                ) {
                    changeIcon(to: icon.name)
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Notice Section
    
    private var noticeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(themeColor)
                
                Text("ご注意")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            Text("• アイコン変更時に確認ダイアログが表示されます\n• 一部のアイコンは今後のアップデートで追加予定です\n• アイコンの変更は端末の設定から元に戻すことができます")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
                .lineSpacing(4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(themeColor.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - Success Message
    
    private var successMessageOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(themeColor)
            
            Text("アイコンを変更しました")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.brandBlack.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(themeColor.opacity(0.3), lineWidth: 2)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 30)
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Helper Functions
    
    private func changeIcon(to iconName: String?) {
        guard UIApplication.shared.supportsAlternateIcons else {
            print("⚠️ このデバイスはアイコン変更をサポートしていません")
            return
        }
        
        // ハプティクス
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                print("❌ アイコン変更エラー: \(error.localizedDescription)")
            } else {
                selectedIcon = iconName
                
                // 成功メッセージを表示
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showSuccessMessage = true
                }
                
                // 2秒後に自動で非表示
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        showSuccessMessage = false
                    }
                }
            }
        }
    }
}

// MARK: - Icon Option Component

private struct IconOption: View {
    let iconName: String?
    let displayName: String
    let isSelected: Bool
    let themeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // アイコンプレビュー
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    // アイコン画像のプレースホルダー
                    // 実際のアプリでは、Info.plistに登録されたアイコン名を使用
                    Image(systemName: iconImageName(for: iconName))
                        .font(.system(size: 48))
                        .foregroundStyle(themeColor)
                    
                    // 選択済みマーク
                    if isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(themeColor)
                                    .background(
                                        Circle()
                                            .fill(Color.brandBlack)
                                            .frame(width: 20, height: 20)
                                    )
                                    .padding(8)
                            }
                            Spacer()
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            isSelected ? themeColor : Color.white.opacity(0.2),
                            lineWidth: isSelected ? 3 : 1
                        )
                )
                
                // アイコン名
                Text(displayName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? themeColor : .white.opacity(0.8))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.08 : 0.03))
            )
        }
        .buttonStyle(.plain)
    }
    
    private func iconImageName(for iconName: String?) -> String {
        switch iconName {
        case nil:
            return "app.fill"
        case "AppIcon-Dark":
            return "moon.fill"
        case "AppIcon-Neon":
            return "bolt.fill"
        case "AppIcon-Minimal":
            return "square.fill"
        case "AppIcon-Retro":
            return "camera.fill"
        default:
            return "app.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    AppIconPickerView()
}
