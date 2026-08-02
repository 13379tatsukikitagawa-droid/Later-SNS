import SwiftUI

/// 📱 右側からスライド表示される設定メニュー
struct SettingsMenuView: View {
    @Binding var isShowing: Bool
    @Environment(\.dismiss) private var dismiss
    
    // 各設定画面の表示状態
    @State private var showingAppearanceSettings = false
    @State private var showingAppIconPicker = false
    @State private var showingDataManagement = false
    @State private var showingHelp = false
    @State private var showingPrivacy = false
    @State private var showingThemeColorPicker = false
    @State private var showingSignOutConfirm = false

    // テーマカラー
    @AppStorage("themeColor") private var themeColorName: String = "green"

    // サインアウト用
    @AppStorage("appleUserID") private var appleUserID: String = ""
    @AppStorage("appleFullName") private var appleFullName: String = ""
    @AppStorage("currentProfileID") private var currentProfileID: String = ""
    @AppStorage("isSetupCompleted") private var isSetupCompleted: Bool = false
    
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
                        // ヘッダー
                        menuHeader
                        
                        // 設定項目セクション
                        settingsSection
                        
                        // アプリ情報セクション
                        appInfoSection
                    }
                    .padding(.vertical, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isShowing = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                            Text("閉じる")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showingAppearanceSettings) {
                AppearanceSettingsView()
            }
            .sheet(isPresented: $showingAppIconPicker) {
                AppIconPickerView()
            }
            .sheet(isPresented: $showingDataManagement) {
                DataManagementPlaceholderView()
            }
            .sheet(isPresented: $showingHelp) {
                HelpAndSupportView()
            }
            .sheet(isPresented: $showingPrivacy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showingThemeColorPicker) {
                ThemeColorPickerView(selectedTheme: $themeColorName)
            }
        }
    }
    
    // MARK: - Menu Header
    
    private var menuHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [themeColor, themeColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: themeColor.opacity(0.3), radius: 10, x: 0, y: 5)
            
            Text("設定")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            Text("アプリのカスタマイズと管理")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.top, 20)
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(spacing: 16) {
            // セクションタイトル
            sectionTitle("カスタマイズ")
            
            VStack(spacing: 12) {
                // カスタマイズ（外観設定）
                MenuRow(
                    icon: "paintbrush.fill",
                    iconColor: .purple,
                    title: "カスタマイズ",
                    subtitle: "ダークモード、表示設定"
                ) {
                    showingAppearanceSettings = true
                }
                
                // テーマカラー
                MenuRow(
                    icon: "paintpalette.fill",
                    iconColor: themeColor,
                    title: "テーマカラー",
                    subtitle: "アプリのアクセントカラー"
                ) {
                    showingThemeColorPicker = true
                }
                
                // アプリアイコン
                MenuRow(
                    icon: "app.fill",
                    iconColor: .pink,
                    title: "アプリアイコン",
                    subtitle: "ホーム画面のアイコンを変更"
                ) {
                    showingAppIconPicker = true
                }
            }
            
            // データ管理セクション
            VStack(spacing: 12) {
                sectionTitle("データ管理")
                
                MenuRow(
                    icon: "internaldrive.fill",
                    iconColor: .blue,
                    title: "データと保存容量",
                    subtitle: "使用容量の確認と管理"
                ) {
                    showingDataManagement = true
                }
            }
            .padding(.top, 8)
            
            // サポートセクション
            VStack(spacing: 12) {
                sectionTitle("サポート")
                
                MenuRow(
                    icon: "questionmark.circle.fill",
                    iconColor: .cyan,
                    title: "ヘルプとサポート",
                    subtitle: "よくある質問とお問い合わせ"
                ) {
                    showingHelp = true
                }
                
    MenuRow(
                    icon: "lock.shield.fill",
                    iconColor: .green,
                    title: "プライバシーとポリシー",
                    subtitle: "利用規約と個人情報保護方針"
                ) {
                    showingPrivacy = true
                }
            }
            .padding(.top, 8)

            // アカウントセクション
            VStack(spacing: 12) {
                sectionTitle("アカウント")

                MenuRow(
                    icon: "apple.logo",
                    iconColor: .white,
                    title: "サインアウト",
                    subtitle: "Apple IDでサインイン中"
                ) {
                    showingSignOutConfirm = true
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .alert("サインアウト", isPresented: $showingSignOutConfirm) {
            Button("キャンセル", role: .cancel) {}
            Button("サインアウト", role: .destructive) {
                signOut()
            }
        } message: {
            Text("サインアウトしてもよろしいですか？")
        }
    }

    private func signOut() {
        appleUserID = ""
        appleFullName = ""
        currentProfileID = ""
        isSetupCompleted = false
        dismiss()
        isShowing = false
    }
    
    // MARK: - App Info Section
    
    private var appInfoSection: some View {
        VStack(spacing: 16) {
            sectionTitle("アプリ情報")
            
            VStack(spacing: 12) {
                // バージョン情報
                infoRow(
                    icon: "info.circle.fill",
                    iconColor: .gray,
                    title: "バージョン",
                    value: "1.0.0"
                )
                
                // ビルド番号
                infoRow(
                    icon: "hammer.fill",
                    iconColor: .orange,
                    title: "ビルド",
                    value: "2024.05"
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
    
    // MARK: - Helper Views
    
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.white.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
    
    private func infoRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 16) {
            // アイコン
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
            
            // タイトル
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
            
            Spacer()
            
            // 値
            Text(value)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Menu Row Component

struct MenuRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // アイコン
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                
                // テキスト
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
                
                // 矢印
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Placeholder Views
// Note: BounceButtonStyle is defined in ButtonStyles.swift
// Note: AppIconPickerView is defined in AppIconPickerView.swift

struct DataManagementPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                VStack {
                    Text("データと保存容量")
                        .font(.title)
                        .foregroundStyle(.white)
                    
                    Text("（実装予定）")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("データ管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}



#Preview {
    SettingsMenuView(isShowing: .constant(true))
}

