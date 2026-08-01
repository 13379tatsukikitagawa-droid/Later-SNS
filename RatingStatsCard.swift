import SwiftUI

/// トレカ風のステータス表示カード - 平均スコア表示
struct RatingStatsCard: View {
    let stats: RatingStats
    let photoURL: String? // 写真のURL
    let animated: Bool = true
    
    @State private var showStats = false
    @State private var glowAnimation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // レアリティバッジ
            rarityBadge
            
            // メインカード
            ZStack {
                // 背景とボーダー
                cardBackground
                
                VStack(spacing: 16) {
                    // 写真プレビュー
                    if let url = photoURL {
                        photoPreview(url: url)
                    }
                    
                    // ステータス
                    statsContent
                    
                    // 受け取ったスタンプ
                    if !stats.customStamps.isEmpty {
                        receivedStampsView
                    }
                }
                .padding(20)
            }
        }
        .onAppear {
            if animated {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                    showStats = true
                }
                
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowAnimation = true
                }
            } else {
                showStats = true
            }
        }
    }
    
    // MARK: - Rarity Badge
    
    private var rarityBadge: some View {
        HStack {
            Spacer()
            
            Text(stats.rank)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(stats.rankColor)
                        .shadow(color: stats.rankColor.opacity(0.6), radius: 12, x: 0, y: 4)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                )
            
            Spacer()
        }
        .offset(y: 15)
        .zIndex(1)
    }
    
    // MARK: - Card Background
    
    private var cardBackground: some View {
        ZStack {
            // ベース
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cardBackground,
                            Color.cardBackground.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // ボーダーグロー
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            stats.rankColor.opacity(glowAnimation ? 0.8 : 0.4),
                            stats.rankColor.opacity(glowAnimation ? 0.4 : 0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .shadow(color: stats.rankColor.opacity(0.5), radius: glowAnimation ? 20 : 10, x: 0, y: 0)
            
            // ホログラム効果
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.clear,
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    // MARK: - Photo Preview
    
    private func photoPreview(url: String) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.gray.opacity(0.3))
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Image(systemName: "photo.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(stats.rankColor.opacity(0.5), lineWidth: 2)
            )
    }
    
    // MARK: - Stats Content
    
    private var statsContent: some View {
        VStack(spacing: 12) {
            // 総合スコア
            overallScoreView
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // 各項目スコア
            VStack(spacing: 10) {
                statRow(
                    icon: "sparkles",
                    title: "エモ度",
                    score: stats.averageEmo,
                    color: .neonPink
                )
                
                statRow(
                    icon: "camera.viewfinder",
                    title: "構図",
                    score: stats.averageComposition,
                    color: .neonBlue
                )
                
                statRow(
                    icon: "waveform",
                    title: "バイブス",
                    score: stats.averageVibes,
                    color: .neonPurple
                )
            }
            
            // 評価数
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                
                Text("\(stats.totalRatings)人が評価")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - Overall Score
    
    private var overallScoreView: some View {
        VStack(spacing: 8) {
            Text("総合スコア")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.7))
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.2f", stats.overallAverage))
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [stats.rankColor, stats.rankColor.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: stats.rankColor.opacity(0.5), radius: 10, x: 0, y: 0)
                    .monospacedDigit()
                    .opacity(showStats ? 1 : 0)
                    .scaleEffect(showStats ? 1 : 0.5)
                
                Text("/ 3.0")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .monospacedDigit()
            }
            
            // 星表示
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: Double(index) < stats.overallAverage ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(stats.rankColor)
                }
            }
        }
    }
    
    // MARK: - Stat Row
    
    private func statRow(icon: String, title: String, score: Double, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 80, alignment: .leading)
            
            // プログレスバー
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: showStats ? geo.size.width * (score / 3.0) : 0)
                        .shadow(color: color.opacity(0.5), radius: 4, x: 0, y: 0)
                }
            }
            .frame(height: 8)
            
            Text(String(format: "%.2f", score))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        }
    }
    
    // MARK: - Received Stamps
    
    private var receivedStampsView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "seal.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.neonGold)
                
                Text("受け取ったスタンプ")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(stats.customStamps.prefix(10), id: \.self) { stamp in
                        Text(stamp)
                            .font(.system(size: 28))
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.neonGold.opacity(0.1))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.neonGold.opacity(0.3), lineWidth: 2)
                                    )
                            )
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

#Preview("High Score") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        RatingStatsCard(
            stats: RatingStats(
                totalRatings: 12,
                averageEmo: 2.8,
                averageComposition: 2.9,
                averageVibes: 2.7,
                customStamps: ["🔥", "✨", "💯", "👑", "⚡️"]
            ),
            photoURL: nil
        )
        .padding()
    }
}

#Preview("Low Score") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        RatingStatsCard(
            stats: RatingStats(
                totalRatings: 3,
                averageEmo: 1.3,
                averageComposition: 1.7,
                averageVibes: 1.5,
                customStamps: ["🤔"]
            ),
            photoURL: nil
        )
        .padding()
    }
}
