import SwiftUI
import SwiftData

/// 🏆 投票結果発表と「栄光の1枚」選出画面
struct VotingResultsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var groups: [LaterGroup]
    
    let targetDate: Date
    let bestShot: LaterPhoto?
    
    @State private var showWinner = false
    @State private var confettiActive = false
    
    private var currentGroup: LaterGroup? {
        groups.first
    }
    
    private var rankedPhotos: [LaterPhoto] {
        guard let group = currentGroup else { return [] }
        let calendar = Calendar.current
        
        return group.photos
            .filter { calendar.isDate($0.captureDate, inSameDayAs: targetDate) }
            .sorted { $0.voteCount > $1.voteCount }
    }
    
    var body: some View {
        ZStack {
            // 背景
            Color(red: 0.05, green: 0.05, blue: 0.08)
                .ignoresSafeArea()
            
            LiquidBackgroundView()
                .opacity(0.3)
            
            VStack(spacing: 0) {
                // ヘッダー
                header
                
                ScrollView {
                    VStack(spacing: 32) {
                        // 勝者発表
                        if let winner = bestShot, showWinner {
                            winnerCard(winner)
                                .transition(.scale.combined(with: .opacity))
                        }
                        
                        // ランキング
                        rankingSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            
            // 紙吹雪エフェクト
            if confettiActive {
                ConfettiView()
            }
        }
        .onAppear {
            startRevealAnimation()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.6))
                    )
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("🏆 投票結果発表")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(targetDate.formatted(.dateTime.month().day()))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Winner Card
    
    private func winnerCard(_ photo: LaterPhoto) -> some View {
        VStack(spacing: 16) {
            // 王冠アイコン
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.84, blue: 0.0),
                            Color(red: 0.85, green: 0.65, blue: 0.13)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5), radius: 20)
            
            Text("栄光の1枚")
                .font(.title.bold())
                .foregroundStyle(.white)
            
            // 写真
            CachedPhotoImage(imageData: photo.imageData, cacheKey: photo.imageCacheKey) { uiImage in
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.84, blue: 0.0),
                                        Color(red: 0.85, green: 0.65, blue: 0.13)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                    }
                    .shadow(
                        color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.3),
                        radius: 30,
                        y: 10
                    )
            }
            
            // 撮影者名（答え合わせ）
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                
                Text(photo.owner?.name ?? "Unknown")
                    .font(.title3.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.8))
            )
            
            // 得票数
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsup.fill")
                    Text("\(photo.voteCount)")
                        .font(.headline)
                        .monospacedDigit()
                }
                
                Divider()
                    .frame(height: 20)
                
                Text("得票数1位")
                    .font(.subheadline)
            }
            .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.2))
            )
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.6))
        )
    }
    
    // MARK: - Ranking Section
    
    private var rankingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("全結果")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            VStack(spacing: 12) {
                ForEach(Array(rankedPhotos.enumerated()), id: \.offset) { index, photo in
                    RankingRow(
                        rank: index + 1,
                        photo: photo,
                        isWinner: photo.id == bestShot?.id
                    )
                }
            }
        }
    }
    
    // MARK: - Animation
    
    private func startRevealAnimation() {
        // ドラムロール風のハプティクス
        HapticsManager.heartbeat()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            HapticsManager.heartbeat()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                showWinner = true
            }
            
            HapticsManager.unlockSuccess()
            
            // 紙吹雪
            confettiActive = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                confettiActive = false
            }
        }
    }
}

// MARK: - Ranking Row

struct RankingRow: View {
    let rank: Int
    let photo: LaterPhoto
    let isWinner: Bool
    
    private var medalIcon: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 順位
            Text(medalIcon)
                .font(.title2.bold())
                .frame(width: 40)
            
            // サムネイル
            CachedPhotoImage(imageData: photo.imageData, cacheKey: photo.imageCacheKey) { uiImage in
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        if isWinner {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    Color(red: 1.0, green: 0.84, blue: 0.0),
                                    lineWidth: 2
                                )
                        }
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(photo.owner?.name ?? "Unknown")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.caption)
                    Text("\(photo.voteCount)票")
                        .font(.subheadline)
                        .monospacedDigit()
                }
                .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
            
            if isWinner {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    isWinner
                        ? Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.15)
                        : Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.4)
                )
        )
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []
    @State private var canvasSize: CGSize = .zero
    
    struct ConfettiPiece: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var rotation: Double
        var color: Color
        var velocity: CGPoint
        var angularVelocity: Double
    }
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for piece in confettiPieces {
                    var path = Path()
                    path.addRect(CGRect(x: 0, y: 0, width: 10, height: 10))
                    
                    context.translateBy(x: piece.x, y: piece.y)
                    context.rotate(by: .degrees(piece.rotation))
                    
                    context.fill(path, with: .color(piece.color))
                }
            }
            .onAppear {
                canvasSize = geometry.size
                generateConfetti()
                animateConfetti()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    private func generateConfetti() {
        let width = canvasSize.width > 0 ? canvasSize.width : 400
        
        let colors: [Color] = [
            Color(red: 1.0, green: 0.84, blue: 0.0),
            Color(red: 0.2, green: 0.8, blue: 0.5),
            Color(red: 1.0, green: 0.3, blue: 0.3),
            Color(red: 0.3, green: 0.5, blue: 1.0)
        ]
        
        confettiPieces = (0..<100).map { _ in
            ConfettiPiece(
                x: CGFloat.random(in: 0...width),
                y: -50,
                rotation: Double.random(in: 0...360),
                color: colors.randomElement()!,
                velocity: CGPoint(
                    x: CGFloat.random(in: -2...2),
                    y: CGFloat.random(in: 3...8)
                ),
                angularVelocity: Double.random(in: -10...10)
            )
        }
    }
    
    private func animateConfetti() {
        let height = canvasSize.height > 0 ? canvasSize.height : 800
        
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            for i in confettiPieces.indices {
                confettiPieces[i].x += confettiPieces[i].velocity.x
                confettiPieces[i].y += confettiPieces[i].velocity.y
                confettiPieces[i].rotation += confettiPieces[i].angularVelocity
                confettiPieces[i].velocity.y += 0.2 // 重力
            }
            
            confettiPieces.removeAll { $0.y > height + 50 }
            
            if confettiPieces.isEmpty {
                timer.invalidate()
            }
        }
    }
}

#Preview {
    VotingResultsView(targetDate: Date(), bestShot: nil)
        .modelContainer(for: [LaterPhoto.self, UserProfile.self, LaterGroup.self])
}
