import SwiftUI
import SwiftData

/// 🎭 グループ内匿名投票フィード
struct AnonymousVotingFeedView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]
    
    let targetDate: Date
    @State private var votingManager = VotingManager.shared
    @State private var timeRemaining: TimeInterval = 0
    @State private var hasVoted = false
    @State private var selectedPhotoID: UUID?
    @State private var showConfetti = false
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    private var currentGroup: LaterGroup? {
        groups.first
    }
    
    private var session: VotingManager.VotingSession? {
        votingManager.activeVotingSession
    }
    
    // その日のグループ写真（匿名化）
    private var anonymousPhotos: [LaterPhoto] {
        guard let group = currentGroup else { return [] }
        let calendar = Calendar.current
        
        return group.photos.filter { photo in
            calendar.isDate(photo.captureDate, inSameDayAs: targetDate)
        }.shuffled() // シャッフルして順序から推測不可に
    }
    
    var body: some View {
        ZStack {
            // 背景
            Color(red: 0.05, green: 0.05, blue: 0.08)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ヘッダー
                header
                
                // タイマーバー
                if let session = session, !session.isClosed {
                    votingTimerBar
                }
                
                // フィード
                if anonymousPhotos.isEmpty {
                    emptyState
                } else {
                    photoFeed
                }
            }
            
            // 紙吹雪エフェクト
            if showConfetti {
                ParticleSystem()
            }
        }
        .task {
            startTimer()
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
                Text("🎭 匿名投票")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                if let session = session, session.isActive {
                    Text("投票受付中")
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.5))
                } else {
                    Text("投票終了")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            // プレースホルダー
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Timer Bar
    
    private var votingTimerBar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.5))
                
                Text("残り時間: \(formattedTime)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                
                Spacer()
                
                Text("\(anonymousPhotos.count)枚")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            // プログレスバー
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                    
                    // 進行状況
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.8, blue: 0.5),
                                    Color(red: 0.15, green: 0.6, blue: 0.4)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (session?.progressPercentage ?? 0))
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    private var formattedTime: String {
        let hours = Int(timeRemaining) / 3600
        let minutes = Int(timeRemaining) / 60 % 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // MARK: - Photo Feed
    
    private var photoFeed: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(anonymousPhotos, id: \.id) { photo in
                    AnonymousPhotoCard(
                        photo: photo,
                        isVotingActive: session?.isActive ?? false,
                        hasUserVoted: hasVoted,
                        isSelected: selectedPhotoID == photo.id,
                        onVote: {
                            castVote(for: photo)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.stack")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("まだ写真がありません")
                .font(.title3)
                .foregroundStyle(.white)
            
            Text("グループメンバーの写真が\n解禁されるとここに表示されます")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Actions
    
    private func castVote(for photo: LaterPhoto) {
        guard let user = currentUser else { return }
        guard !hasVoted else {
            HapticsManager.errorFeedback()
            return
        }
        
        let success = votingManager.castVote(
            photo: photo,
            voter: user,
            context: context
        )
        
        if success {
            hasVoted = true
            selectedPhotoID = photo.id
            
            // 紙吹雪演出
            withAnimation {
                showConfetti = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showConfetti = false
                }
            }
            
            HapticsManager.unlockSuccess()
        }
    }
    
    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if let session = session {
                timeRemaining = session.timeRemaining
                
                if session.isClosed {
                    timer.invalidate()
                }
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - Anonymous Photo Card

struct AnonymousPhotoCard: View {
    let photo: LaterPhoto
    let isVotingActive: Bool
    let hasUserVoted: Bool
    let isSelected: Bool
    let onVote: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 写真
            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    Color(red: 0.2, green: 0.8, blue: 0.5),
                                    lineWidth: 4
                                )
                        }
                    }
            }
            
            // 投票ボタン
            if isVotingActive {
                Button {
                    onVote()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "hand.thumbsup.fill")
                        Text(isSelected ? "投票完了" : "この写真に投票")
                    }
                    .font(.headline)
                    .foregroundStyle(
                        isSelected
                            ? Color(red: 0.05, green: 0.05, blue: 0.08)
                            : .white
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                isSelected
                                    ? Color(red: 0.2, green: 0.8, blue: 0.5)
                                    : Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.8)
                            )
                    )
                }
                .disabled(hasUserVoted)
                .opacity(hasUserVoted && !isSelected ? 0.5 : 1.0)
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .padding(.top, 12)
            } else {
                // 投票終了後の表示
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                    Text("\(photo.voteCount)票")
                        .font(.headline)
                        .monospacedDigit()
                }
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.6))
                )
                .padding(.top, 12)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.4))
        )
    }
}

#Preview {
    AnonymousVotingFeedView(targetDate: Date())
        .modelContainer(for: [LaterPhoto.self, UserProfile.self, LaterGroup.self, PhotoVote.self])
}
