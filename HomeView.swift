import SwiftUI
import SwiftData
import AVFoundation
internal import Combine

// MARK: - App Phase Enum（24時間フェーズシステム）

/// アプリの現在のフェーズを表す列挙型
enum AppPhase: String, CaseIterable {
    case shooting = "撮影フェーズ"    // 00:00 - 18:00
    case voting = "投票フェーズ"      // 18:00 - 20:00
    case results = "結果発表フェーズ" // 20:00 - 24:00
    
    /// 現在時刻から現在のフェーズを判定
    static func current(from date: Date = Date()) -> AppPhase {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        
        switch hour {
        case 0..<18:
            return .shooting
        case 18..<20:
            return .voting
        default: // 20..<24
            return .results
        }
    }
    
    /// 次のフェーズ切り替え時刻を取得
    func nextPhaseDate(from date: Date = Date()) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        
        switch self {
        case .shooting:
            // 18:00まで
            return calendar.date(byAdding: .hour, value: 18, to: today) ?? date
        case .voting:
            // 20:00まで
            return calendar.date(byAdding: .hour, value: 20, to: today) ?? date
        case .results:
            // 翌0:00まで
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? date
            return tomorrow
        }
    }
    
    /// アイコン名
    var iconName: String {
        switch self {
        case .shooting: return "camera.fill"
        case .voting: return "hand.thumbsup.fill"
        case .results: return "trophy.fill"
        }
    }
    
    /// テーマカラー
    var themeColor: Color {
        switch self {
        case .shooting: return Color(hex: "#00ff41")
        case .voting: return Color(hex: "#FF6B6B")
        case .results: return Color(hex: "#FFD93D")
        }
    }
}

// MARK: - Dummy Data Models

/// グループ構造体（ダミーデータ用）
struct PhotoGroup: Identifiable, Hashable {
    let id: String
    let name: String
    
    static let samples: [PhotoGroup] = [
        PhotoGroup(id: "group1", name: "地元の友達"),
        PhotoGroup(id: "group2", name: "大学のゼミ"),
        PhotoGroup(id: "group3", name: "サークル"),
        PhotoGroup(id: "group4", name: "バイト仲間")
    ]
}

/// 投稿写真構造体（ダミーデータ用）
struct Post: Identifiable {
    let id: String
    let imageSystemName: String // ダミー画像（SF Symbolsを使用）
    let authorName: String
    let groupId: String
    var voteCount: Int
    
    static let samples: [Post] = [
        Post(id: "post1", imageSystemName: "photo.fill", authorName: "田中太郎", groupId: "group1", voteCount: 12),
        Post(id: "post2", imageSystemName: "photo.fill.on.rectangle.fill", authorName: "佐藤花子", groupId: "group1", voteCount: 8),
        Post(id: "post3", imageSystemName: "photo.stack.fill", authorName: "鈴木一郎", groupId: "group2", voteCount: 15),
        Post(id: "post4", imageSystemName: "rectangle.on.rectangle", authorName: "高橋美咲", groupId: "group2", voteCount: 20),
        Post(id: "post5", imageSystemName: "square.grid.2x2.fill", authorName: "伊藤健太", groupId: "group3", voteCount: 5),
        Post(id: "post6", imageSystemName: "square.fill.on.square.fill", authorName: "山田大輔", groupId: "group3", voteCount: 18),
        Post(id: "post7", imageSystemName: "rectangle.stack.fill", authorName: "中村愛美", groupId: "group4", voteCount: 9),
        Post(id: "post8", imageSystemName: "photo.on.rectangle", authorName: "小林翔太", groupId: "group4", voteCount: 25),
    ]
}

/// メインホーム画面 - 24時間フェーズ制（時間連動UI）
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \LaterPhoto.captureDate, order: .reverse) private var allPhotos: [LaterPhoto]
    @Query private var profiles: [UserProfile]
    @State private var currentIndex = 0
    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    @State private var showCalendar = false
    @State private var currentTime = Date()
    @State private var heartbeatTimer: Timer?
    @State private var showCamera = false
    private let photoManager = PhotoManager.shared
    private let votingManager = VotingManager.shared
    @State private var showUnlockCelebration = false
    @State private var showVotingFeed = false
    @State private var unlockedPhotoCount = 0
    
    // 🎯 フェーズ管理
    @State private var currentPhase: AppPhase = .shooting
    @State private var phaseCheckTimer: Timer?
    
    // 🎯 グループ選択機能（投票フェーズ用）
    @State private var selectedGroupId: String = PhotoGroup.samples.first?.id ?? ""
    @State private var samplePosts: [Post] = Post.samples
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    private var dailyGoal: Int {
        photoManager.dailyLimit
    }
    
    // 今日撮影した自分の写真のみ
    private var todayPhotos: [LaterPhoto] {
        let calendar = Calendar.current
        let _ = Date()
        let userID = currentUser?.id
        
        return allPhotos.filter { photo in
            let isMine = photo.owner?.id == userID
            let isToday = calendar.isDateInToday(photo.captureDate)
            return isMine && isToday
        }
    }
    
    private var currentPhoto: LaterPhoto? {
        guard currentIndex < todayPhotos.count else { return nil }
        return todayPhotos[currentIndex]
    }
    
    // 🎯 選択されたグループの投稿をフィルタリング
    private var filteredPosts: [Post] {
        samplePosts.filter { $0.groupId == selectedGroupId }
    }
    
    // 🎯 結果発表：最も投票数が多い投稿（今日の一枚）
    private var topPost: Post? {
        samplePosts.max(by: { $0.voteCount < $1.voteCount })
    }
    
    var body: some View {
        ZStack {
            // 背景
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            // 液体アニメーション背景
            LiquidBackgroundView()
            
            // 🎯 フェーズ別のメインコンテンツ
            Group {
                switch currentPhase {
                case .shooting:
                    shootingPhaseView
                case .voting:
                    votingPhaseView
                case .results:
                    resultsPhaseView
                }
            }
        }
        .sheet(isPresented: $showCalendar) {
            CalendarArchiveView()
        }
        .fullScreenCover(isPresented: $showCamera) {
            EnhancedCameraView()
        }
        .fullScreenCover(isPresented: $showUnlockCelebration) {
            PhotoUnlockCelebration(
                photoCount: unlockedPhotoCount,
                isPresented: $showUnlockCelebration
            )
            .onDisappear {
                // 解禁後、投票フィードを表示
                showVotingFeed = true
            }
        }
        .sheet(isPresented: $showVotingFeed) {
            if votingManager.activeVotingSession != nil {
                AnonymousVotingFeedView(targetDate: Date().addingTimeInterval(-86400))
            }
        }
        .task {
            // PhotoManagerの初期化と同期
            photoManager.syncDailyLimit(from: currentUser)
            photoManager.resetIfNewDay()
            
            startTimeUpdater()
            startPhaseMonitoring()
            checkUnlockStatus()
            startHeartbeatIfNeeded()
        }
        .onDisappear {
            stopHeartbeat()
            stopPhaseMonitoring()
        }
        .onAppear {
            HapticsManager.prepare()
            // 現在のフェーズを初期化
            currentPhase = AppPhase.current(from: currentTime)
        }
    }
    
    // MARK: - 🎯 Phase 1: 撮影フェーズ（00:00 - 18:00）
    
    private var shootingPhaseView: some View {
        VStack(spacing: 0) {
            // ヘッダー
            shootingPhaseHeader
            
            Spacer()
            
            // メインコンテンツ
            if todayPhotos.isEmpty {
                emptyStateView
            } else {
                cardSwipeView
            }
            
            Spacer()
            
            // フッター（撮影状況）
            footer
        }
    }
    
    private var shootingPhaseHeader: some View {
        HStack {
            // 左上のボタン
            leftTopButton
            
            Spacer()
            
            // 🎯 フェーズインジケーター
            PhaseIndicator(currentPhase: currentPhase, nextPhaseDate: currentPhase.nextPhaseDate(from: currentTime), currentTime: currentTime)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
    
    // MARK: - 🎯 Phase 2: 投票・解禁フェーズ（18:00 - 20:00）
    
    private var votingPhaseView: some View {
        VStack(spacing: 0) {
            // ヘッダー
            votingPhaseHeader
            
            // グループ切り替えタブ
            groupSelectorTabs
                .padding(.horizontal, 24)
                .padding(.top, 16)
            
            ScrollView {
                VStack(spacing: 24) {
                    // 🎯 自分が今日撮った写真の解禁セクション
                    myPhotosUnlockedSection
                    
                    // 🎯 他のメンバーの写真（投票可能）
                    votingSection
                }
                .padding(.vertical, 20)
            }
        }
    }
    
    private var votingPhaseHeader: some View {
        HStack {
            // 左上のボタン
            leftTopButton
            
            Spacer()
            
            // フェーズインジケーター
            PhaseIndicator(currentPhase: currentPhase, nextPhaseDate: currentPhase.nextPhaseDate(from: currentTime), currentTime: currentTime)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
    
    private var groupSelectorTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(PhotoGroup.samples) { group in
                    GroupChip(
                        group: group,
                        isSelected: selectedGroupId == group.id,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedGroupId = group.id
                            }
                            HapticsManager.swipeFeedback()
                        }
                    )
                }
            }
        }
    }
    
    private var myPhotosUnlockedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(currentPhase.themeColor)
                
                Text("今日の写真が解禁されました！")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            
            if todayPhotos.isEmpty {
                Text("今日は写真を撮影していません")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(todayPhotos, id: \.id) { photo in
                            UnlockedPhotoCard(photo: photo)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
    
    private var votingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(currentPhase.themeColor)
                
                Text("\(PhotoGroup.samples.first(where: { $0.id == selectedGroupId })?.name ?? "グループ")の投稿")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            
            if filteredPosts.isEmpty {
                Text("まだ投稿がありません")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(filteredPosts) { post in
                            VotablePostCard(post: post) {
                                voteForPost(post)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
    
    // MARK: - 🎯 Phase 3: 結果発表フェーズ（20:00 - 24:00）
    
    private var resultsPhaseView: some View {
        VStack(spacing: 0) {
            // ヘッダー
            resultsPhaseHeader
            
            Spacer()
            
            // 🏆 今日の一枚（最も投票を集めた写真）
            if let top = topPost {
                WinnerPostView(post: top, themeColor: currentPhase.themeColor)
                    .padding(.horizontal, 24)
            } else {
                Text("今日の投稿はありませんでした")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            // 次の日への切り替え情報
            nextDayCountdown
        }
    }
    
    private var resultsPhaseHeader: some View {
        HStack {
            // 左上のボタン
            leftTopButton
            
            Spacer()
            
            // フェーズインジケーター
            PhaseIndicator(currentPhase: currentPhase, nextPhaseDate: currentPhase.nextPhaseDate(from: currentTime), currentTime: currentTime)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
    
    private var nextDayCountdown: some View {
        VStack(spacing: 12) {
            Text("次の撮影まで")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            
            let timeRemaining = currentPhase.nextPhaseDate(from: currentTime).timeIntervalSince(currentTime)
            let hours = Int(timeRemaining) / 3600
            let minutes = (Int(timeRemaining) % 3600) / 60
            let seconds = Int(timeRemaining) % 60
            
            Text(String(format: "%02d:%02d:%02d", hours, minutes, seconds))
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(currentPhase.themeColor)
                .monospacedDigit()
        }
        .padding(.vertical, 24)
    }
    
    // MARK: - フェーズ監視
    
    private func startPhaseMonitoring() {
        phaseCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let newPhase = AppPhase.current(from: currentTime)
            if newPhase != currentPhase {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    currentPhase = newPhase
                }
                HapticsManager.cardChange()
            }
        }
    }
    
    private func stopPhaseMonitoring() {
        phaseCheckTimer?.invalidate()
        phaseCheckTimer = nil
    }
    
    // MARK: - 投票処理
    
    private func voteForPost(_ post: Post) {
        if let index = samplePosts.firstIndex(where: { $0.id == post.id }) {
            samplePosts[index].voteCount += 1
            HapticsManager.unlockSuccess()
        }
    }
    
    // MARK: - Header（共通コンポーネント - 既存のまま維持）
    
    private var header: some View {
        HStack {
            // 左上のボタン
            leftTopButton
            
            Spacer()
            
            // 🎯 Next Reveal Widget（右上） - 撮影フェーズのみ表示
            if currentPhase == .shooting {
                NextRevealWidget(allPhotos: allPhotos)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
    
    // MARK: - Left Top Button
    
    private var leftTopButton: some View {
        Button {
            print("Left top button tapped")
            HapticsManager.swipeFeedback()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color(hex: "#00ff41"))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color(hex: "#00ff41").opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 72))
                .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.5))
                .symbolEffect(.pulse)
            
            Text("まだ今日の写真を\n撮影していません")
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white)
            
            Button {
                HapticsManager.swipeFeedback()
                showCamera = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                    Text("撮影を始める")
                }
                .font(.headline)
                .foregroundStyle(Color(red: 0.05, green: 0.05, blue: 0.05))
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Color(red: 0.2, green: 0.8, blue: 0.5))
                )
            }
        }
    }
    
    // MARK: - Card Swipe View
    
    private var cardSwipeView: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(todayPhotos.enumerated()), id: \.offset) { index, photo in
                    if index >= currentIndex - 1 && index <= currentIndex + 1 {
                        PhotoCardView(photo: photo, currentTime: currentTime)
                            .frame(width: geometry.size.width * 0.85)
                            .offset(x: calculateOffset(for: index, in: geometry))
                            .scaleEffect(calculateScale(for: index))
                            .opacity(calculateOpacity(for: index))
                            .zIndex(Double(todayPhotos.count - index))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            HapticsManager.swipeFeedback()
                        }
                        offset = value.translation.width
                    }
                    .onEnded { value in
                        isDragging = false
                        let threshold: CGFloat = 100
                        
                        if value.translation.width > threshold && currentIndex > 0 {
                            // 左にスワイプ（前のカードへ）
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                currentIndex -= 1
                                offset = 0
                            }
                            HapticsManager.cardChange()
                        } else if value.translation.width < -threshold && currentIndex < todayPhotos.count - 1 {
                            // 右にスワイプ（次のカードへ）
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                currentIndex += 1
                                offset = 0
                            }
                            HapticsManager.cardChange()
                        } else {
                            // スワイプ不十分、元に戻す
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                offset = 0
                            }
                        }
                    }
            )
        }
        .frame(height: 500)
    }
    
    private func calculateOffset(for index: Int, in geometry: GeometryProxy) -> CGFloat {
        let cardWidth = geometry.size.width * 0.85
        let spacing: CGFloat = 20
        let baseOffset = CGFloat(index - currentIndex) * (cardWidth + spacing)
        
        if index == currentIndex {
            return baseOffset + offset
        } else {
            return baseOffset
        }
    }
    
    private func calculateScale(for index: Int) -> CGFloat {
        if index == currentIndex {
            return 1.0
        } else if index == currentIndex + 1 || index == currentIndex - 1 {
            return 0.9
        } else {
            return 0.8
        }
    }
    
    private func calculateOpacity(for index: Int) -> Double {
        if index == currentIndex {
            return 1.0
        } else if index == currentIndex + 1 || index == currentIndex - 1 {
            return 0.5
        } else {
            return 0.2
        }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        VStack(spacing: 12) {
            // ページインジケーター
            if todayPhotos.count > 1 {
                HStack(spacing: 8) {
                    ForEach(0..<todayPhotos.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? Color(red: 0.2, green: 0.8, blue: 0.5) : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            
            // 撮影状況（統合されたPhotoManagerから取得）
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("\(photoManager.todayPhotoCount)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.5))
                        .contentTransition(.numericText())
                    Text("撮影済み")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                
                Divider()
                    .frame(height: 40)
                    .background(Color.white.opacity(0.2))
                
                VStack(spacing: 4) {
                    Text("\(dailyGoal)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))
                    Text("目標")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                
                Divider()
                    .frame(height: 40)
                    .background(Color.white.opacity(0.2))
                
                VStack(spacing: 4) {
                    Text("\(photoManager.remainingPhotos)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(photoManager.isGoalAchieved ? Color(red: 0.2, green: 0.8, blue: 0.5) : Color.white.opacity(0.5))
                        .contentTransition(.numericText())
                    Text("残り")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 32)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.6))
            )
        }
        .padding(.bottom, 32)
    }
    
    // MARK: - Helpers
    
    private func startTimeUpdater() {
        Task {
            while !Task.isCancelled {
                currentTime = Date()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
    
    private func checkUnlockStatus() {
        let now = Date()
        var newlyUnlocked: [LaterPhoto] = []
        
        for photo in allPhotos where photo.unlockDate <= now && !photo.isUnlocked {
            photo.isUnlocked = true
            photo.votingPhaseActive = true // 投票フェーズ開始
            newlyUnlocked.append(photo)
        }
        
        if !newlyUnlocked.isEmpty {
            unlockedPhotoCount = newlyUnlocked.count
            
            // 解禁演出を表示
            withAnimation {
                showUnlockCelebration = true
            }
            
            // 投票セッションを開始
            if let firstPhoto = newlyUnlocked.first {
                votingManager.startVotingSession(
                    for: firstPhoto.captureDate,
                    unlockDate: firstPhoto.unlockDate
                )
            }
            
            HapticsManager.unlockSuccess()
        }
        
        try? context.save()
    }
    
    private func startHeartbeatIfNeeded() {
        // グローバル解禁時刻の1時間前からハートビート開始
        // この実装は簡略版（実際にはGlobalUnlockManagerと連携）
        guard let nextUnlock = allPhotos.first?.unlockDate else { return }
        let oneHourBefore = nextUnlock.addingTimeInterval(-3600)
        
        if Date() >= oneHourBefore && Date() < nextUnlock {
            startHeartbeat()
        }
    }
    
    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                HapticsManager.heartbeat()
            }
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
}

// MARK: - Photo Card View
// HomeView専用のPhotoCardView（fileprivateで外部との競合を回避）

fileprivate struct PhotoCardView: View {
    let photo: LaterPhoto
    let currentTime: Date
    
    @State private var updateTrigger = false
    
    private var progress: Double {
        PhotoUnlockUtilities.calculateUnlockProgress(
            captureDate: photo.captureDate,
            unlockDate: photo.unlockDate,
            currentDate: currentTime
        )
    }
    
    private var smoothProgress: Double {
        PhotoUnlockUtilities.applyEasing(
            progress: progress,
            easingType: .smoothStep
        )
    }
    
    var body: some View {
        ZStack {
            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 500)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    // エフェクト適用
                    .grayscale(progress < 1.0 ? 1.0 - smoothProgress : 0.0)
                    .blur(radius: (1.0 - smoothProgress) * 20)
                    .overlay {
                        if progress < 1.0 {
                            developingOverlay
                        }
                    }
            } else {
                placeholderCard
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
    
    private var developingOverlay: some View {
        ZStack {
            // 白色オーバーレイ
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .opacity((1.0 - smoothProgress) * 0.4)
            
            // 液体アニメーション（薄く）
            LiquidBackgroundView()
                .opacity((1.0 - smoothProgress) * 0.3)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            
            // 中央のバッジ
            if progress < 0.8 {
                VStack(spacing: 16) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.white)
                        .symbolEffect(.pulse)
                    
                    Text("現像中...")
                        .font(.title3.bold())
                        .foregroundStyle(Color.white)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.black.opacity(0.7))
                        .blur(radius: 10)
                )
                .opacity(max(0, (0.8 - progress) / 0.8))
            }
        }
        .allowsHitTesting(false)
    }
    
    private var placeholderCard: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.5))
            .frame(height: 500)
            .overlay {
                VStack(spacing: 16) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.5))
                        .symbolEffect(.pulse)
                    
                    Text("現像中...")
                        .font(.title3.bold())
                        .foregroundStyle(Color.white)
                }
            }
    }
}

// MARK: - Retro Camera View

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    
    @StateObject private var camera = CameraController()
    private let photoManager = PhotoManager.shared
    @State private var showFlash = false
    @State private var showBlackout = false
    @State private var showLimitReached = false
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    // 残り撮影可能枚数
    private var remainingShots: Int {
        photoManager.remainingPhotos
    }
    
    var body: some View {
        ZStack {
            // 漆黒の背景
            Color.black.ignoresSafeArea()
            
            // カメラプレビュー
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()
            
            // フィルムグレインオーバーレイ
            FilmGrainOverlay()
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
            // ビューファインダーマスク
            ViewfinderMask()
                .allowsHitTesting(false)
            
            // UI要素
            VStack {
                // トップバー
                topBar
                
                Spacer()
                
                // ボトムコントロール
                bottomControls
            }
            
            // シャッターフラッシュ
            if showFlash {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            
            // ブラックアウト演出
            if showBlackout {
                Color.black
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            
            // 上限到達メッセージ
            if showLimitReached {
                limitReachedOverlay
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            camera.checkPermissions()
            camera.setupCamera()
        }
        .onDisappear {
            camera.stopSession()
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            // 閉じるボタン
            Button {
                HapticsManager.swipeFeedback()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundStyle(Color(red: 1.0, green: 0.7, blue: 0.3))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                Circle()
                                    .stroke(Color(red: 1.0, green: 0.7, blue: 0.3).opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            
            Spacer()
            
            // フィルムカウンター（残り枚数表示）
            FilmCounter(
                count: photoManager.todayPhotoCount,
                remaining: remainingShots
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 32) {
            // シャッターボタン
            RetroShutterButton(isEnabled: photoManager.canTakePhoto) {
                capturePhoto()
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Limit Reached Overlay
    
    private var limitReachedOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.5))
                
                Text("本日の撮影完了")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                
                Text("1日\(photoManager.dailyLimit)枚の制限に達しました\n解禁までお楽しみに...")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                
                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.2, green: 0.8, blue: 0.5))
                        )
                }
                .padding(.top, 16)
            }
            .padding()
        }
        .transition(.opacity)
    }
    
    // MARK: - Capture Logic
    
    private func capturePhoto() {
        // 撮影可能かチェック
        guard photoManager.canTakePhoto else {
            withAnimation {
                showLimitReached = true
            }
            return
        }
        
        // フラッシュ演出
        withAnimation(.easeOut(duration: 0.1)) {
            showFlash = true
        }
        
        HapticsManager.shutterClick()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeIn(duration: 0.1)) {
                showFlash = false
            }
            
            // ブラックアウト演出
            withAnimation(.easeOut(duration: 0.15)) {
                showBlackout = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeIn(duration: 0.15)) {
                    showBlackout = false
                }
                
                // フィルム巻き上げハプティクス
                HapticsManager.filmWinding()
                
                // 実際の撮影処理
                camera.capturePhoto { imageData in
                    guard let data = imageData, let user = currentUser else { return }
                    
                    let captureDate = Date()
                    let unlockDate = Calendar.current.date(byAdding: .hour, value: 24, to: captureDate) ?? captureDate.addingTimeInterval(86400)
                    
                    let photo = LaterPhoto(
                        imageData: data,
                        captureDate: captureDate,
                        unlockDate: unlockDate,
                        owner: user
                    )
                    
                    context.insert(photo)
                    try? context.save()
                    
                    // PhotoManagerのカウントを更新
                    photoManager.incrementPhotoCount()
                    
                    // 上限に達した場合は自動的にカメラを閉じる
                    if !photoManager.canTakePhoto {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Camera Controller

@MainActor
class CameraController: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var captureCompletion: ((Data?) -> Void)?
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { _ in }
        default:
            break
        }
    }
    
    func setupCamera() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        session.commitConfiguration()
        
        Task {
            session.startRunning()
        }
    }
    
    func stopSession() {
        if session.isRunning {
            session.stopRunning()
        }
    }
    
    func capturePhoto(completion: @escaping (Data?) -> Void) {
        captureCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else {
            Task { @MainActor in
                captureCompletion?(nil)
            }
            return
        }
        
        Task { @MainActor in
            captureCompletion?(data)
            captureCompletion = nil
        }
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Film Grain Overlay

struct FilmGrainOverlay: View {
    var body: some View {
        Canvas { context, size in
            // フィルムグレイン用のドットパターンを描画
            for _ in 0..<1000 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let opacity = Double.random(in: 0.02...0.08)
                
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                    with: .color(.white.opacity(opacity))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Viewfinder Mask

struct ViewfinderMask: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 外側の黒マスク
                Rectangle()
                    .fill(Color.black.opacity(0.85))
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .frame(
                                        width: geometry.size.width * 0.85,
                                        height: geometry.size.width * 0.85
                                    )
                                    .blendMode(.destinationOut)
                            )
                    )
                
                // ビューファインダーフレーム
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(red: 1.0, green: 0.7, blue: 0.3).opacity(0.4), lineWidth: 2)
                    .frame(
                        width: geometry.size.width * 0.85,
                        height: geometry.size.width * 0.85
                    )
                
                // L字型ガイドライン
                ViewfinderGuides()
                    .stroke(Color(red: 1.0, green: 0.7, blue: 0.3).opacity(0.6), lineWidth: 2)
                    .frame(
                        width: geometry.size.width * 0.85,
                        height: geometry.size.width * 0.85
                    )
            }
        }
    }
}

// MARK: - Viewfinder Guides (L-shapes)

struct ViewfinderGuides: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerLength: CGFloat = 20
        let inset: CGFloat = 10
        
        // 左上
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + inset + cornerLength))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.minX + inset + cornerLength, y: rect.minY + inset))
        
        // 右上
        path.move(to: CGPoint(x: rect.maxX - inset - cornerLength, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY + inset + cornerLength))
        
        // 左下
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.maxY - inset - cornerLength))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.minX + inset + cornerLength, y: rect.maxY - inset))
        
        // 右下
        path.move(to: CGPoint(x: rect.maxX - inset - cornerLength, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset - cornerLength))
        
        return path
    }
}

// MARK: - Film Counter (7-Segment Style)

struct FilmCounter: View {
    let count: Int
    let remaining: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Text("FILM")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 1.0, green: 0.5, blue: 0.2).opacity(0.6))
                .tracking(2)
            
            HStack(spacing: 8) {
                Text("\(count)")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(
                        Color(red: 1.0, green: 0.4, blue: 0.1)
                    )
                    .shadow(color: Color(red: 1.0, green: 0.4, blue: 0.1), radius: 8)
                
                Text("/")
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.5, blue: 0.2).opacity(0.5))
                
                Text("\(remaining)")
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.5, blue: 0.2).opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.4, blue: 0.1).opacity(0.3),
                                    Color(red: 1.0, green: 0.4, blue: 0.1).opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Retro Shutter Button

struct RetroShutterButton: View {
    let isEnabled: Bool
    let action: () -> Void
    @State private var isPressed = false
    
    init(isEnabled: Bool = true, action: @escaping () -> Void) {
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                // 外側のメタルリング
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isEnabled ? [
                                Color(white: 0.3),
                                Color(white: 0.2),
                                Color(white: 0.1)
                            ] : [
                                Color(white: 0.2),
                                Color(white: 0.15),
                                Color(white: 0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 4)
                
                // 内側のリング（凹み表現）
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.15),
                                Color(white: 0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 82, height: 82)
                
                // 赤いボタン本体（ロック時はグレー）
                Circle()
                    .fill(
                        RadialGradient(
                            colors: isEnabled ? [
                                Color(red: 0.9, green: 0.2, blue: 0.15),
                                Color(red: 0.7, green: 0.1, blue: 0.1)
                            ] : [
                                Color(white: 0.4),
                                Color(white: 0.3)
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 35
                        )
                    )
                    .frame(width: 70, height: 70)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isEnabled ? 0.4 : 0.2),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            )
                            .frame(width: 70, height: 70)
                            .blur(radius: 2)
                    )
                    .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                
                // ロックアイコン
                if !isEnabled {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                // テクスチャ（プラスチック感）
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.clear,
                                Color.black.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 70, height: 70)
            }
        }
        .disabled(!isEnabled)
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = newValue
                }
            }
    }
}

// MARK: - Decorative Later Logo

fileprivate struct DecorativeLaterLogo: View {
    @State private var particlesAnimating = false
    @State private var filmRotation1: Double = 0
    @State private var filmRotation2: Double = 0
    @State private var filmRotation3: Double = 0
    
    var body: some View {
        ZStack {
            // 背景の装飾要素
            decorativeElements
            
            // メインロゴ
            VStack(alignment: .leading, spacing: 2) {
                // 3D風のLaterテキスト
                Text("Later")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.9),
                                Color(red: 0.2, green: 0.8, blue: 0.5),
                                Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.3), radius: 10, x: 0, y: 5)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 2, y: 2)
                
                // サブタイトル
                Text("シークレット現像")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.8))
                    .tracking(1)
            }
        }
        .frame(width: 140, height: 80)
        .onAppear {
            startAnimations()
        }
    }
    
    private var decorativeElements: some View {
        ZStack {
            // パーティクル（ドット）
            ForEach(0..<20, id: \.self) { index in
                Circle()
                    .fill(Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.6))
                    .frame(width: CGFloat.random(in: 2...4))
                    .offset(
                        x: CGFloat.random(in: -60...60),
                        y: CGFloat.random(in: -35...35)
                    )
                    .opacity(particlesAnimating ? 0.8 : 0.2)
                    .scaleEffect(particlesAnimating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: Double.random(in: 1.5...2.5))
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: particlesAnimating
                    )
            }
            
            // 三角形
            ForEach(0..<6, id: \.self) { index in
                Triangle()
                    .fill(Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.4))
                    .frame(width: CGFloat.random(in: 6...12), height: CGFloat.random(in: 6...12))
                    .rotationEffect(.degrees(Double.random(in: 0...360)))
                    .offset(
                        x: CGFloat.random(in: -65...65),
                        y: CGFloat.random(in: -40...40)
                    )
                    .opacity(particlesAnimating ? 0.7 : 0.3)
                    .animation(
                        .easeInOut(duration: Double.random(in: 2...3))
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: particlesAnimating
                    )
            }
            
            // フィルムストリップ（小）
            FilmStrip()
                .stroke(Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.3), lineWidth: 1.5)
                .frame(width: 25, height: 15)
                .rotationEffect(.degrees(filmRotation1))
                .offset(x: -50, y: -25)
            
            FilmStrip()
                .stroke(Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.3), lineWidth: 1.5)
                .frame(width: 25, height: 15)
                .rotationEffect(.degrees(filmRotation2))
                .offset(x: 45, y: 20)
            
            FilmStrip()
                .stroke(Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.3), lineWidth: 1.5)
                .frame(width: 20, height: 12)
                .rotationEffect(.degrees(filmRotation3))
                .offset(x: 30, y: -30)
            
            // カメラアイコン（小）
            Image(systemName: "camera.aperture")
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.4))
                .offset(x: -55, y: 25)
            
            // 鍵アイコン（小）
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.4))
                .offset(x: 50, y: -20)
        }
    }
    
    private func startAnimations() {
        particlesAnimating = true
        
        // フィルムストリップの回転アニメーション
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            filmRotation1 = 360
        }
        withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
            filmRotation2 = -360
        }
        withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
            filmRotation3 = 360
        }
    }
}

// MARK: - Supporting Shapes

fileprivate struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

fileprivate struct FilmStrip: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // 外枠
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: 2, height: 2))
        
        // 穴（上下）
        let holeCount = 4
        let holeWidth = rect.width / CGFloat(holeCount * 2)
        let holeHeight = rect.height * 0.15
        
        for i in 0..<holeCount {
            let x = CGFloat(i) * (rect.width / CGFloat(holeCount)) + holeWidth / 2
            // 上の穴
            path.addRect(CGRect(x: x, y: 2, width: holeWidth, height: holeHeight))
            // 下の穴
            path.addRect(CGRect(x: x, y: rect.height - holeHeight - 2, width: holeWidth, height: holeHeight))
        }
        
        return path
    }
}

// MARK: - 🎯 Next Reveal Widget（Home画面右上）

struct NextRevealWidget: View {
    let allPhotos: [LaterPhoto]
    @State private var currentTime = Date()
    @State private var timer: Timer?
    @State private var showDetailView = false
    
    // 🎨 カラー定義
    private let neonGreen = Color(hex: "#00ff41")
    private let votingRed = Color(hex: "#FF6B6B")
    private let resultsGold = Color(hex: "#FFD93D")
    
    // フェーズの定義
    private enum TimePhase {
        case shooting   // 0:00 - 8:00
        case voting     // 8:00 - 9:00
        case results    // 9:00 - 23:59
    }
    
    // 前日以前に撮影した、最も解禁が近い未現像写真
    private var nextRevealPhoto: LaterPhoto? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        
        return allPhotos
            .filter { photo in
                !photo.isUnlocked && photo.captureDate <= yesterday
            }
            .sorted { $0.unlockDate < $1.unlockDate }
            .first
    }
    
    // 現在のフェーズを判定
    private var currentPhase: TimePhase {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        
        if hour >= 0 && hour < 8 {
            return .shooting
        } else if hour >= 8 && hour < 9 {
            return .voting
        } else {
            return .results
        }
    }
    
    // ✅ 次のフェーズまでの残り時間を計算
    private var timeUntilNextPhase: TimeInterval {
        let calendar = Calendar.current
        let now = currentTime
        let currentHour = calendar.component(.hour, from: now)
        
        let today = calendar.startOfDay(for: now)
        var targetDate: Date?
        
        // 現在時刻に応じて次のフェーズの開始時刻を計算
        if currentHour < 8 {
            // 0:00-7:59 → 8:00（投票開始）まで
            targetDate = calendar.date(byAdding: .hour, value: 8, to: today)
        } else if currentHour < 9 {
            // 8:00-8:59 → 9:00（結果発表）まで
            targetDate = calendar.date(byAdding: .hour, value: 9, to: today)
        } else {
            // 9:00-23:59 → 明日の0:00（撮影開始）まで
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)
            targetDate = tomorrow
        }
        
        guard let target = targetDate else { return 0 }
        return max(0, target.timeIntervalSince(now))
    }
    
    // ✅ 残り時間を HH:MM:SS 形式でフォーマット（等幅数字で表示）
    private var timeRemainingString: String {
        let hours = Int(timeUntilNextPhase) / 3600
        let minutes = (Int(timeUntilNextPhase) % 3600) / 60
        let seconds = Int(timeUntilNextPhase) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // ✅ フェーズに応じた表示テキスト
    private var phaseLabel: String {
        switch currentPhase {
        case .shooting:
            return "SHOOTING ENDS IN"
        case .voting:
            return "VOTING TIME"
        case .results:
            return "NEXT SHOOT AT"
        }
    }
    
    // ✅ フェーズに応じた色
    private var phaseColor: Color {
        switch currentPhase {
        case .shooting:
            return neonGreen
        case .voting:
            return votingRed
        case .results:
            return resultsGold.opacity(0.8)
        }
    }
    
    // 🎯 現像進行度（0.0 = 撮影直後、1.0 = 完全解禁）
    private var revealProgress: Double {
        guard let photo = nextRevealPhoto else { return 0 }
        return PhotoUnlockUtilities.calculateUnlockProgress(
            captureDate: photo.captureDate,
            unlockDate: photo.unlockDate,
            currentDate: currentTime
        )
    }
    
    // 🎨 Latency Engine パラメータ
    private var blurRadius: CGFloat {
        // 最大30 → 最小0（解禁が近づくほどクリアに）
        let maxBlur: CGFloat = 30.0
        return maxBlur * CGFloat(1.0 - revealProgress)
    }
    
    private var saturation: Double {
        // 0.0（モノクロ） → 1.0（フルカラー）
        return revealProgress
    }
    
    private var contrast: Double {
        // 0.5（低コントラスト） → 1.2（高コントラスト）
        return 0.5 + (0.7 * revealProgress)
    }
    
    private var overlayOpacity: Double {
        // 0.6（暗い） → 0.0（オーバーレイなし）
        return 0.6 * (1.0 - revealProgress)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // 次の解禁写真のサムネイル（ある場合のみ表示）
            if let photo = nextRevealPhoto,
               let uiImage = UIImage(data: photo.imageData) {
                Button {
                    HapticsManager.swipeFeedback()
                    showDetailView = true
                } label: {
                    let borderOpacity = 0.3 + (0.4 * revealProgress)
                    
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 64, height: 64)
                        .clipped()
                        // 🎨 Latency Engine エフェクト適用
                        .saturation(saturation)
                        .contrast(contrast)
                        .blur(radius: blurRadius)
                        .overlay(
                            Rectangle()
                                .fill(Color.black.opacity(overlayOpacity))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(phaseColor.opacity(borderOpacity), lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
            
            // ⏱️ カウントダウンタイマー（フェーズベース・常に表示）
            VStack(spacing: 2) {
                Text(phaseLabel)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(phaseColor.opacity(0.7))
                    .tracking(1)
                
                Text(timeRemainingString)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .monospacedDigit() // ✅ 等幅数字でガタつき防止
                    .foregroundStyle(phaseColor)
                    .shadow(color: phaseColor.opacity(0.5), radius: 6)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(phaseColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .sheet(isPresented: $showDetailView) {
            if let photo = nextRevealPhoto {
                NextRevealDetailView(photo: photo, currentTime: currentTime)
            }
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }
}

// MARK: - Next Reveal Detail View（タップ時の詳細表示）

fileprivate struct NextRevealDetailView: View {
    let photo: LaterPhoto
    let currentTime: Date
    @Environment(\.dismiss) private var dismiss
    
    private let neonGreen = Color(hex: "#00ff41")
    
    private var revealProgress: Double {
        PhotoUnlockUtilities.calculateUnlockProgress(
            captureDate: photo.captureDate,
            unlockDate: photo.unlockDate,
            currentDate: currentTime
        )
    }
    
    private var blurRadius: CGFloat {
        let maxBlur: CGFloat = 50.0
        return maxBlur * CGFloat(1.0 - revealProgress)
    }
    
    private var saturation: Double {
        return revealProgress
    }
    
    private var contrast: Double {
        return 0.5 + (0.7 * revealProgress)
    }
    
    private var overlayOpacity: Double {
        return 0.7 * (1.0 - revealProgress)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                // ヘッダー
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    
                    Spacer()
                    
                    Text("NEXT REVEAL")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(neonGreen)
                        .tracking(2)
                    
                    Spacer()
                    
                    // バランス用
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer()
                
                // 大きなプレビュー
                if let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(height: 400)
                        .saturation(saturation)
                        .contrast(contrast)
                        .blur(radius: blurRadius)
                        .overlay(
                            Rectangle()
                                .fill(Color.black.opacity(overlayOpacity))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    neonGreen.opacity(0.3 + (0.5 * revealProgress)),
                                    lineWidth: 2
                                )
                        )
                        .padding(.horizontal, 24)
                }
                
                // 進行度インジケーター
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Text("現像進行度")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                        
                        Spacer()
                        
                        Text("\(Int(revealProgress * 100))%")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(neonGreen)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // 背景
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.1))
                            
                            // 進行バー
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [neonGreen.opacity(0.8), neonGreen],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * revealProgress)
                                .shadow(color: neonGreen.opacity(0.6), radius: 8)
                        }
                    }
                    .frame(height: 12)
                    
                    // 解禁時刻
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("解禁予定")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                            
                            Text(photo.unlockDate, style: .date)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                            
                            Text(photo.unlockDate, style: .time)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("残り時間")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                            
                            Text(photo.remainingTimeText)
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(neonGreen)
                        }
                    }
                }
                .padding(20)
                .background(cardBackground)
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(neonGreen.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - 🎯 フェーズインジケーター（ヘッダー右上）

struct PhaseIndicator: View {
    let currentPhase: AppPhase
    let nextPhaseDate: Date
    let currentTime: Date
    
    private var timeRemaining: TimeInterval {
        max(0, nextPhaseDate.timeIntervalSince(currentTime))
    }
    
    private var timeRemainingString: String {
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: currentPhase.iconName)
                    .font(.system(size: 12))
                    .foregroundStyle(currentPhase.themeColor)
                
                Text(currentPhase.rawValue)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(currentPhase.themeColor)
            }
            
            Text(timeRemainingString)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(currentPhase.themeColor.opacity(0.4), lineWidth: 1.5)
                )
        )
    }
}

// MARK: - 🎯 グループチップ（投票フェーズのタブ）

struct GroupChip: View {
    let group: PhotoGroup
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(group.name)
                .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? .black : .white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? Color(hex: "#FF6B6B") : Color.white.opacity(0.1))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? Color.clear : Color.white.opacity(0.2),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 🎯 解禁された自分の写真カード

struct UnlockedPhotoCard: View {
    let photo: LaterPhoto
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color(hex: "#FF6B6B").opacity(0.4), lineWidth: 2)
                    )
                    .shadow(color: Color(hex: "#FF6B6B").opacity(0.3), radius: 12, x: 0, y: 6)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("撮影時刻")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                
                Text(photo.captureDate, style: .time)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - 🎯 投票可能な投稿カード

struct VotablePostCard: View {
    let post: Post
    let onVote: () -> Void
    
    @State private var hasVoted = false
    
    var body: some View {
        VStack(spacing: 16) {
            // ダミー画像（SF Symbols）
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#667eea").opacity(0.6),
                                Color(hex: "#764ba2").opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 280)
                
                Image(systemName: post.imageSystemName)
                    .font(.system(size: 80))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(hex: "#FF6B6B").opacity(0.3), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
            
            // 投稿者情報
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.authorName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: "#FF6B6B"))
                        
                        Text("\(post.voteCount)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // 投票ボタン
                Button {
                    onVote()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        hasVoted = true
                    }
                } label: {
                    Image(systemName: hasVoted ? "heart.fill" : "heart")
                        .font(.system(size: 24))
                        .foregroundStyle(hasVoted ? Color(hex: "#FF6B6B") : .white.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(hasVoted ? Color(hex: "#FF6B6B").opacity(0.2) : Color.white.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .disabled(hasVoted)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - 🎯 優勝投稿ビュー（結果発表フェーズ）

struct WinnerPostView: View {
    let post: Post
    let themeColor: Color
    
    @State private var animateConfetti = false
    @State private var animateScale = false
    
    var body: some View {
        ZStack {
            // 背景の装飾パーティクル
            if animateConfetti {
                ForEach(0..<30, id: \.self) { index in
                    Circle()
                        .fill(themeColor.opacity(Double.random(in: 0.4...0.8)))
                        .frame(width: CGFloat.random(in: 4...12))
                        .offset(
                            x: CGFloat.random(in: -150...150),
                            y: CGFloat.random(in: -300...300)
                        )
                        .animation(
                            .easeOut(duration: Double.random(in: 1.0...2.0))
                                .delay(Double(index) * 0.05),
                            value: animateConfetti
                        )
                }
            }
            
            VStack(spacing: 24) {
                // トロフィーアイコン
                Image(systemName: "trophy.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [themeColor, themeColor.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: themeColor.opacity(0.5), radius: 20)
                
                Text("🎉 今日の一枚 🎉")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                
                // 優勝写真（大きく表示）
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#667eea"),
                                    Color(hex: "#764ba2")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 320, height: 400)
                    
                    Image(systemName: post.imageSystemName)
                        .font(.system(size: 120))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [themeColor, themeColor.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                )
                .shadow(color: themeColor.opacity(0.4), radius: 30, x: 0, y: 15)
                .scaleEffect(animateScale ? 1.0 : 0.8)
                
                // 投稿者情報
                VStack(spacing: 8) {
                    Text(post.authorName)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.title3)
                            .foregroundStyle(themeColor)
                        
                        Text("\(post.voteCount) votes")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 32)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            Capsule()
                                .strokeBorder(themeColor.opacity(0.3), lineWidth: 2)
                        )
                )
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animateScale = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                animateConfetti = true
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [LaterPhoto.self, UserProfile.self, LaterGroup.self])
}


