import SwiftUI

/// カスタムスタンプ作成・編集画面
struct CustomStampEditor: View {
    @AppStorage("userCustomStamp") private var userCustomStamp: String = "🔥"
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedStamp: String = "🔥"
    @State private var showSuccessFeedback = false
    
    private let emojiCategories: [String: [String]] = [
        "炎系": ["🔥", "💥", "⚡️", "✨", "💫", "⭐️"],
        "ハート系": ["❤️", "💖", "💕", "💗", "💓", "💝"],
        "絵文字": ["😎", "🤩", "😍", "🥳", "🤯", "😤"],
        "記号": ["💯", "👑", "🏆", "💎", "🎯", "🎨"],
        "自然": ["🌟", "🌈", "🌸", "🌺", "🍀", "🦋"],
        "その他": ["🚀", "🎪", "🎭", "🎬", "🎸", "🎮"]
    ]
    
    var body: some View {
        ZStack {
            // 背景
            Color(red: 0.15, green: 0.15, blue: 0.2)
                .ignoresSafeArea()
            
            // グリッド背景
            gridBackground
            
            VStack(spacing: 24) {
                // ヘッダー
                header
                
                ScrollView {
                    VStack(spacing: 24) {
                        // プレビュー
                        previewSection
                        
                        // スタンプ選択
                        ForEach(Array(emojiCategories.keys.sorted()), id: \.self) { category in
                            stampCategorySection(category: category)
                        }
                        
                        // 保存ボタン
                        saveButton
                    }
                    .padding()
                }
            }
            
            // 成功フィードバック
            if showSuccessFeedback {
                successOverlay
            }
        }
        .onAppear {
            selectedStamp = userCustomStamp
        }
    }
    
    // MARK: - Grid Background
    
    private var gridBackground: some View {
        GeometryReader { geo in
            let borderColor = Color(red: 0.2, green: 0.2, blue: 0.4)
            Path { path in
                let spacing: CGFloat = 30
                for i in stride(from: 0, to: geo.size.width, by: spacing) {
                    path.move(to: CGPoint(x: i, y: 0))
                    path.addLine(to: CGPoint(x: i, y: geo.size.height))
                }
                for i in stride(from: 0, to: geo.size.height, by: spacing) {
                    path.move(to: CGPoint(x: 0, y: i))
                    path.addLine(to: CGPoint(x: geo.size.width, y: i))
                }
            }
            .stroke(borderColor.opacity(0.3), lineWidth: 1)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 8) {
            closeButton
            headerTitle
            headerSubtitle
        }
        .padding(.top, 20)
    }
    
    private var closeButton: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private var headerTitle: some View {
        let goldColor = Color(red: 1.00, green: 0.84, blue: 0.00)
        let gradient = LinearGradient(
            colors: [goldColor, .orange],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        return Text("CUSTOM STAMP")
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundStyle(gradient)
            .shadow(color: goldColor.opacity(0.5), radius: 10, x: 0, y: 0)
    }
    
    private var headerSubtitle: some View {
        Text("オリジナルスタンプを作成")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.6))
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(spacing: 16) {
            Text("プレビュー")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            
            previewContent
        }
    }
    
    private var previewContent: some View {
        let goldColor = Color(red: 1.00, green: 0.84, blue: 0.00)
        let shadowColor = goldColor.opacity(0.5)
        
        return ZStack {
            // 背景
            previewGlowBackground
            
            // スタンプ
            Text(selectedStamp)
                .font(.system(size: 100))
                .shadow(color: shadowColor, radius: 20, x: 0, y: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(previewCardBackground)
    }
    
    private var previewGlowBackground: some View {
        let goldColor = Color(red: 1.00, green: 0.84, blue: 0.00)
        let gradient = RadialGradient(
            colors: [
                goldColor.opacity(0.3),
                goldColor.opacity(0.1),
                Color.clear
            ],
            center: .center,
            startRadius: 0,
            endRadius: 100
        )
        
        return Circle()
            .fill(gradient)
            .frame(width: 200, height: 200)
    }
    
    private var previewCardBackground: some View {
        let goldColor = Color(red: 1.00, green: 0.84, blue: 0.00)
        let orangeColor = Color.orange
        let borderGradient = LinearGradient(
            colors: [goldColor.opacity(0.6), orangeColor.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let bgColor = Color(red: 0.15, green: 0.15, blue: 0.2)
        
        return RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(bgColor)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(borderGradient, lineWidth: 3)
            )
    }
    
    // MARK: - Stamp Category Section
    
    private func stampCategorySection(category: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            categoryHeader(category: category)
            stampGrid(category: category)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }
    
    private func categoryHeader(category: String) -> some View {
        HStack {
            Text(category)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
            
            Spacer()
        }
    }
    
    private func stampGrid(category: String) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)
        let emojis = emojiCategories[category] ?? []
        
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(emojis, id: \.self) { emoji in
                stampButton(emoji: emoji)
            }
        }
    }
    
    private func stampButton(emoji: String) -> some View {
        let isSelected = selectedStamp == emoji
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                selectedStamp = emoji
            }
        } label: {
            stampButtonContent(emoji: emoji, isSelected: isSelected)
        }
    }
    
    private func stampButtonContent(emoji: String, isSelected: Bool) -> some View {
        Text(emoji)
            .font(.system(size: 32))
            .frame(width: 50, height: 50)
            .background(stampButtonBackground(isSelected: isSelected))
            .overlay(stampButtonBorder(isSelected: isSelected))
            .scaleEffect(isSelected ? 1.1 : 1.0)
    }
    
    private func stampButtonBackground(isSelected: Bool) -> some View {
        let goldColor = Color(red: 1.00, green: 0.84, blue: 0.00)
        let whiteColor = Color.white
        let fillColor: Color = isSelected ? goldColor.opacity(0.2) : whiteColor.opacity(0.05)
        
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(fillColor)
    }
    
    private func stampButtonBorder(isSelected: Bool) -> some View {
        let goldColor = Color(red: 1.00, green: 0.84, blue: 0.00)
        let whiteColor = Color.white
        let strokeColor: Color = isSelected ? goldColor : whiteColor.opacity(0.2)
        let lineWidth: CGFloat = isSelected ? 3 : 1
        
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(strokeColor, lineWidth: lineWidth)
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button {
            saveStamp()
        } label: {
            saveButtonContent
        }
        .padding(.bottom, 20)
    }
    
    private var saveButtonContent: some View {
        let goldColor = Color(red: 1.00, green: 0.84, blue: 0.00)
        let gradient = LinearGradient(
            colors: [goldColor, .orange],
            startPoint: .leading,
            endPoint: .trailing
        )
        let shadowColor = goldColor.opacity(0.5)
        
        return HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3.weight(.bold))
            
            Text("このスタンプに決定")
                .font(.system(size: 18, weight: .black, design: .rounded))
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: shadowColor, radius: 20, x: 0, y: 8)
    }
    
    // MARK: - Success Overlay
    
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            successCard
        }
    }
    
    private var successCard: some View {
        let goldColor = Color(red: 1.00, green: 0.84, blue: 0.00)
        
        return VStack(spacing: 20) {
            successStampPreview
            
            Text("スタンプを保存しました！")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(goldColor)
        }
        .padding(40)
        .background(successCardBackground)
        .scaleEffect(showSuccessFeedback ? 1.0 : 0.8)
        .opacity(showSuccessFeedback ? 1.0 : 0)
    }
    
    private var successStampPreview: some View {
        let goldColor = Color(red: 1.00, green: 0.84, blue: 0.00)
        let circleColor = goldColor.opacity(0.2)
        
        return ZStack {
            Circle()
                .fill(circleColor)
                .frame(width: 120, height: 120)
            
            Text(selectedStamp)
                .font(.system(size: 60))
        }
    }
    
    private var successCardBackground: some View {
        let goldColor = Color(red: 1.00, green: 0.84, blue: 0.00)
        let bgColor = Color(red: 0.15, green: 0.15, blue: 0.2)
        let shadowColor = goldColor.opacity(0.5)
        
        return RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(bgColor)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(goldColor, lineWidth: 3)
            )
            .shadow(color: shadowColor, radius: 30, x: 0, y: 10)
    }
    
    // MARK: - Actions
    
    private func saveStamp() {
        userCustomStamp = selectedStamp
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showSuccessFeedback = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showSuccessFeedback = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        }
    }
}

#Preview {
    CustomStampEditor()
}
