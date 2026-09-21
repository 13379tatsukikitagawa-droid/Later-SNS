import SwiftUI

/// 撮影直後にキャプション（記憶の封印）を入力するビュー
struct CaptionInputView: View {
    @Environment(\.dismiss) private var dismiss
    let photo: LaterPhoto
    
    @State private var caption: String = ""
    @State private var showPlaceholder: Bool = true
    @FocusState private var isTextFieldFocused: Bool
    
    @AppStorage("themeColor") private var themeColorName: String = "green"
    
    private var themeColor: Color {
        switch themeColorName {
        case "green": return Color.brandGreen
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        default: return Color.brandGreen
        }
    }
    
    // プレースホルダーのバリエーション
    private let placeholders = [
        "今の気持ちをメモ...",
        "この瞬間の名前は？",
        "記憶に残したい言葉...",
        "一言、封印する...",
        "未来の自分へ..."
    ]
    
    private var randomPlaceholder: String {
        placeholders.randomElement() ?? placeholders[0]
    }
    
    var body: some View {
        ZStack {
            // 暗い背景
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    saveAndDismiss()
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                // キャプション入力エリア
                captionInputSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            caption = photo.caption ?? ""
            // 少し遅延してからフォーカス
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isTextFieldFocused = true
            }
        }
    }
    
    // MARK: - キャプション入力セクション
    
    private var captionInputSection: some View {
        VStack(spacing: 16) {
            // 見出し
            HStack {
                Image(systemName: "quote.opening")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeColor)
                
                Text("記憶を封印する")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                
                Spacer()
                
                // 文字数カウンター
                Text("\(caption.count)/30")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(caption.count > 30 ? .red : .white.opacity(0.5))
            }
            .padding(.horizontal, 4)
            
            // テキストフィールド
            ZStack(alignment: .leading) {
                // 背景
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isTextFieldFocused ? themeColor.opacity(0.5) : Color.white.opacity(0.15),
                                lineWidth: 2
                            )
                    )
                
                // プレースホルダー
                if caption.isEmpty {
                    Text(randomPlaceholder)
                        .font(.system(size: 17, design: .serif))
                        .foregroundStyle(.white.opacity(0.3))
                        .italic()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
                
                // 実際の入力フィールド
                TextField("", text: $caption)
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(.white)
                    .tint(themeColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .focused($isTextFieldFocused)
                    .onChange(of: caption) { oldValue, newValue in
                        // 30文字制限
                        if newValue.count > 30 {
                            caption = String(newValue.prefix(30))
                        }
                    }
                    .submitLabel(.done)
                    .onSubmit {
                        saveAndDismiss()
                    }
            }
            .frame(height: 52)
            
            // アクションボタン
            HStack(spacing: 12) {
                // スキップボタン
                Button {
                    caption = ""
                    saveAndDismiss()
                } label: {
                    Text("スキップ")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                }
                
                // 保存ボタン
                Button {
                    saveAndDismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("完了")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeColor,
                                        themeColor.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: themeColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    themeColor.opacity(0.3),
                                    themeColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
        )
    }
    
    // MARK: - ヘルパー
    
    private func saveAndDismiss() {
        // キャプションを保存（空文字列でもOK）
        photo.caption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // ハプティクスフィードバック
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        dismiss()
    }
}

// MARK: - プレビュー

#Preview("キャプション入力") {
    let dummyOwner = UserProfile(name: "Test User", username: "testuser")
    let dummyPhoto = createPreviewPhoto(owner: dummyOwner)
    
    CaptionInputView(photo: dummyPhoto)
}

private func createPreviewPhoto(owner: UserProfile) -> LaterPhoto {
    let size = CGSize(width: 400, height: 300)
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { context in
        UIColor.systemBlue.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
    
    return LaterPhoto(
        imageData: image.pngData() ?? Data(),
        captureDate: Date(),
        unlockDate: Date().addingTimeInterval(60 * 60),
        owner: owner
    )
}

