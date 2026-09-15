import SwiftUI

/// トレカ風の写真評価UI - 星3段階評価
struct PhotoRatingView: View {
    let photoId: String
    let raterId: String
    let existingRating: PhotoRating?
    let onRate: (PhotoRating) -> Void
    
    @State private var emoScore: Int = 0
    @State private var compositionScore: Int = 0
    @State private var vibesScore: Int = 0
    @State private var selectedStamp: String? = nil
    @State private var showStampPicker = false
    
    @AppStorage("userCustomStamp") private var userCustomStamp: String = "🔥"
    
    @Environment(\.dismiss) private var dismiss
    
    // グラデーションを計算プロパティとして分離
    private var titleGradient: LinearGradient {
        LinearGradient(
            colors: [.neonCyan, .neonPurple],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var submitButtonGradient: LinearGradient {
        LinearGradient(
            colors: [.neonCyan, .neonPurple],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private let categories = [
        ("エモ度", "sparkles", Color.neonPink),
        ("構図", "camera.viewfinder", Color.neonBlue),
        ("バイブス", "waveform", Color.neonPurple)
    ]
    
    var body: some View {
        ZStack {
            // 背景
            Color.cardBackground
                .ignoresSafeArea()
            
            // グリッド背景
            GeometryReader { geo in
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
                .stroke(Color.cardBorder.opacity(0.3), lineWidth: 1)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // ヘッダー
                headerView
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 評価項目
                        ratingCard(
                            title: "エモ度",
                            icon: "sparkles",
                            color: .neonPink,
                            score: $emoScore
                        )
                        
                        ratingCard(
                            title: "構図",
                            icon: "camera.viewfinder",
                            color: .neonBlue,
                            score: $compositionScore
                        )
                        
                        ratingCard(
                            title: "バイブス",
                            icon: "waveform",
                            color: .neonPurple,
                            score: $vibesScore
                        )
                        
                        // カスタムスタンプセクション
                        customStampSection
                        
                        // 送信ボタン
                        submitButton
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            loadExistingRating()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 8) {
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
            
            Text("RATE THIS PHOTO")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(titleGradient)
                .shadow(color: .neonCyan.opacity(0.5), radius: 10, x: 0, y: 0)
            
            Text("トレカステータス評価")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.top, 20)
    }
    
    // MARK: - Rating Card
    
    private func ratingCard(title: String, icon: String, color: Color, score: Binding<Int>) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(color)
                    .shadow(color: color.opacity(0.8), radius: 8, x: 0, y: 0)
                
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Spacer()
                
                // 現在のスコア表示
                Text("\(score.wrappedValue)/3")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(color)
                    .monospacedDigit()
            }
            
            // 星評価
            HStack(spacing: 20) {
                ForEach(1...3, id: \.self) { star in
                    starButton(star: star, score: score, color: color)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(cardBackground(color: color))
    }
    
    private func starButton(star: Int, score: Binding<Int>, color: Color) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                score.wrappedValue = star
            }
        } label: {
            Image(systemName: star <= score.wrappedValue ? "star.fill" : "star")
                .font(.system(size: 40))
                .foregroundStyle(
                    star <= score.wrappedValue
                    ? color
                    : Color.white.opacity(0.2)
                )
                .shadow(
                    color: star <= score.wrappedValue ? color.opacity(0.6) : .clear,
                    radius: 12,
                    x: 0,
                    y: 0
                )
                .scaleEffect(star <= score.wrappedValue ? 1.1 : 1.0)
        }
    }
    
    private func cardBackground(color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.cardBackground)
            
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(cardBorderGradient(color: color), lineWidth: 2)
                .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
    private func cardBorderGradient(color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.6), color.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Custom Stamp Section
    
    private var customStampSection: some View {
        VStack(spacing: 12) {
            stampSectionHeader
            stampButton
        }
        .padding(20)
        .background(stampSectionBackground)
    }
    
    private var stampSectionHeader: some View {
        HStack {
            Image(systemName: "seal.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.neonGold)
            
            Text("カスタムスタンプを送る")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            Spacer()
        }
    }
    
    private var stampButton: some View {
        Button {
            withAnimation {
                if selectedStamp == nil {
                    selectedStamp = userCustomStamp
                } else {
                    selectedStamp = nil
                }
            }
        } label: {
            stampButtonLabel
        }
    }
    
    private var stampButtonLabel: some View {
        HStack(spacing: 12) {
            Text(userCustomStamp)
                .font(.system(size: 40))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("マイスタンプ")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                
                Text(selectedStamp != nil ? "選択中" : "タップして送信")
                    .font(.caption2)
                    .foregroundStyle(selectedStamp != nil ? Color.neonGold : .white.opacity(0.6))
            }
            
            Spacer()
            
            if selectedStamp != nil {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.neonGold)
            }
        }
        .padding(16)
        .background(stampButtonBackgroundFill)
        .overlay(stampButtonBorder)
    }
    
    private var stampButtonBackgroundFill: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(selectedStamp != nil ? Color.neonGold.opacity(0.1) : Color.white.opacity(0.05))
    }
    
    private var stampButtonBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(selectedStamp != nil ? Color.neonGold : Color.white.opacity(0.2), lineWidth: 2)
    }
    
    private var stampSectionBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.neonGold.opacity(0.3), lineWidth: 2)
            )
    }
    
    // MARK: - Submit Button
    
    private var submitButton: some View {
        Button {
            submitRating()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "paperplane.fill")
                    .font(.title3.weight(.bold))
                
                Text("評価を送信")
                    .font(.system(size: 18, weight: .black, design: .rounded))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(submitButtonGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .neonCyan.opacity(0.5), radius: 20, x: 0, y: 8)
        }
        .disabled(!isValidRating)
        .opacity(isValidRating ? 1.0 : 0.5)
        .padding(.bottom, 20)
    }
    
    // MARK: - Helper Methods
    
    private var isValidRating: Bool {
        emoScore > 0 && compositionScore > 0 && vibesScore > 0
    }
    
    private func loadExistingRating() {
        if let existing = existingRating {
            emoScore = existing.emoScore
            compositionScore = existing.compositionScore
            vibesScore = existing.vibesScore
            selectedStamp = existing.customStamp
        }
    }
    
    private func submitRating() {
        let rating = PhotoRating(
            photoId: photoId,
            raterId: raterId,
            emoScore: emoScore,
            compositionScore: compositionScore,
            vibesScore: vibesScore,
            customStamp: selectedStamp
        )
        
        onRate(rating)
        dismiss()
    }
}

#Preview {
    PhotoRatingView(
        photoId: "photo123",
        raterId: "user456",
        existingRating: nil
    ) { rating in
        print("Rating submitted: \(rating)")
    }
}
