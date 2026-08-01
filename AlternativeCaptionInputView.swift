import SwiftUI
import UIKit

/// 撮影直後にキャプションを入力するビュー（コールバック形式）
struct AlternativeCaptionInputView: View {
    @Environment(\.dismiss) private var dismiss
    
    let onSave: (String?) -> Void
    let onSkip: () -> Void
    
    @State private var caption: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    @AppStorage("themeColor") private var themeColorName: String = "green"
    
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
    
    private var captionBinding: Binding<String> {
        Binding(
            get: { caption },
            set: { newValue in
                if newValue.count > 30 {
                    caption = String(newValue.prefix(30))
                } else {
                    caption = newValue
                }
            }
        )
    }
    
    var body: some View {
        ZStack {
            // 漆黒の背景
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // キャプション入力エリア
                captionInputSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
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
                TextField("", text: captionBinding)
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(.white)
                    .tint(themeColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .focused($isTextFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        handleSave()
                    }
            }
            .frame(height: 52)
            
            // アクションボタン
            HStack(spacing: 12) {
                // スキップボタン
                Button {
                    handleSkip()
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
                    handleSave()
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
    
    private func handleSave() {
        // ハプティクスフィードバック
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(trimmedCaption.isEmpty ? nil : trimmedCaption)
        
        dismiss()
    }
    
    private func handleSkip() {
        // ハプティクスフィードバック
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        onSkip()
        dismiss()
    }
}

// MARK: - プレビュー

#Preview("AlternativeCaptionInputView") {
    AlternativeCaptionInputView(
        onSave: { caption in
            print("保存: \(caption ?? "nil")")
        },
        onSkip: {
            print("スキップ")
        }
    )
}
