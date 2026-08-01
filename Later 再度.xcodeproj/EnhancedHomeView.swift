import SwiftUI
import Combine

// MARK: - Photo Achievement Data Manager
/// 撮影記録と達成状況を管理するマネージャー

@Observable
class PhotoAchievementManager {
    static let shared = PhotoAchievementManager()
    
    // MARK: - Storage
    private let userDefaults = UserDefaults.standard
    private let achievementKey = "photoAchievementRecords"
    
    // MARK: - Properties
    var dailyGoal: Int = 5
    var achievementRecords: [String: Int] = [:] // "yyyy-MM-dd": photoCount
    
    private init() {
        loadAchievementRecords()
    }
    
    // MARK: - Public Methods
    
    /// 指定日の撮影枚数を取得
    func getPhotoCount(for date: Date) -> Int {
        let key = dateKey(from: date)
        return achievementRecords[key] ?? 0
    }
    
    /// 指定日の撮影枚数を設定
    func setPhotoCount(_ count: Int, for date: Date) {
        let key = dateKey(from: date)
        achievementRecords[key] = count
        saveAchievementRecords()
    }
    
    /// 指定日の撮影枚数を増やす
    func incrementPhotoCount(for date: Date = Date()) {
        let key = dateKey(from: date)
        let current = achievementRecords[key] ?? 0
        achievementRecords[key] = current + 1
        saveAchievementRecords()
    }
    
    /// 指定日が目標達成しているかチェック
    func hasAchievedGoal(for date: Date) -> Bool {
        return getPhotoCount(for: date) >= dailyGoal
    }
    
    /// 連続達成日数を取得（ストリーク）
    func getCurrentStreak() -> Int {
        var streak = 0
        var checkDate = Date()
        let calendar = Calendar.current
        
        while hasAchievedGoal(for: checkDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                break
            }
            checkDate = previousDay
        }
        
        return streak
    }
    
    /// 月間の達成日数を取得
    func getMonthlyAchievementCount(for date: Date) -> Int {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        
        guard let range = calendar.range(of: .day, in: .month, for: date) else {
            return 0
        }
        
        var count = 0
        for day in range {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            
            if let checkDate = calendar.date(from: components),
               hasAchievedGoal(for: checkDate) {
                count += 1
            }
        }
        
        return count
    }
    
    // MARK: - Private Methods
    
    private func dateKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar.current
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    private func loadAchievementRecords() {
        if let data = userDefaults.data(forKey: achievementKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            achievementRecords = decoded
        }
    }
    
    private func saveAchievementRecords() {
        if let encoded = try? JSONEncoder().encode(achievementRecords) {
            userDefaults.set(encoded, forKey: achievementKey)
        }
    }
}

// MARK: - Enhanced Modern Home View
/// 達成状況とカレンダー連動を強化したホーム画面

struct EnhancedHomeView: View {
    @State private var revealManager = GlobalSecretRevealManager.shared
    @State private var achievementManager = PhotoAchievementManager.shared
    @State private var swipeHandler: SwipeGestureHandler
    @State private var showingCalendar = false
    @State private var todayPhotos: [EnhancedPhotoItem] = []
    @State private var currentStreak: Int = 0
    
    init() {
        _swipeHandler = State(initialValue: SwipeGestureHandler(totalItems: 3))
    }
    
    var body: some View {
        ZStack {
            // 液体背景アニメーション
            LiquidBackgroundView()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ヘッダー（達成状況を含む）
                enhancedHeaderSection
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // ストリーク表示
                if currentStreak > 0 {
                    streakBanner
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                
                // メインコンテンツ
                if revealManager.canViewFeed() {
                    enhancedPhotoCardsSection
                } else {
                    secretWaitingView
                }
                
                Spacer(minLength: 100)
            }
        }
        .sheet(isPresented: $showingCalendar) {
            AchievementCalendarView()
        }
        .onAppear {
            loadEnhancedPhotos()
            updateStreak()
        }
        .onChange(of: revealManager.isGloballyRevealed) { _, isRevealed in
            if isRevealed {
                loadEnhancedPhotos()
            }
        }
    }
    
    // MARK: - Enhanced Header
    
    private var enhancedHeaderSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                // 挨拶
                Text(greetingMessage)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                // ステータス
                HStack(spacing: 8) {
                    if revealManager.isGloballyRevealed {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        
                        Text("解禁中")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    } else {
                        Circle()
                            .fill(.orange)
                            .frame(width: 8, height: 8)
                        
                        Text("次の解禁をお待ちください")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
                
                // 今日の達成状況
                todayAchievementStatus
            }
            
            Spacer()
            
            // カレンダーボタン（達成マーカー付き）
            calendarButton
        }
    }
    
    private var todayAchievementStatus: some View {
        let todayCount = achievementManager.getPhotoCount(for: Date())
        let isAchieved = todayCount >= achievementManager.dailyGoal
        
        return HStack(spacing: 6) {
            Image(systemName: isAchieved ? "checkmark.circle.fill" : "camera.fill")
                .font(.caption)
                .foregroundStyle(isAchieved ? .green : .white.opacity(0.6))
            
            Text("\(todayCount) / \(achievementManager.dailyGoal) 枚")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
            
            if isAchieved {
                Text("達成!")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isAchieved ? .green.opacity(0.2) : .white.opacity(0.1))
        )
    }
    
    private var calendarButton: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            showingCalendar = true
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundStyle(.white)
                
                // 達成マーカー（今日達成していたら表示）
                if achievementManager.hasAchievedGoal(for: Date()) {
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(.green)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 2)
                                )
                        }
                        Spacer()
                    }
                    .frame(width: 44, height: 44)
                }
            }
        }
    }
    
    // MARK: - Streak Banner
    
    private var streakBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(currentStreak) 日連続達成中!")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                
                Text("素晴らしい！この調子で続けましょう")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.orange.opacity(0.3), .red.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
        )
    }
    
    // MARK: - Photo Cards Section
    
    private var enhancedPhotoCardsSection: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(todayPhotos.enumerated()), id: \.offset) { index, photo in
                    EnhancedPhotoCardView(
                        photo: photo,
                        index: index,
                        currentIndex: swipeHandler.currentIndex,
                        offset: swipeHandler.offset,
                        totalItems: todayPhotos.count
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                swipeHandler.handleDragChanged(value)
                            }
                            .onEnded { value in
                                swipeHandler.handleDragEnded(value)
                            }
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .overlay(alignment: .bottom) {
            if todayPhotos.count > 1 {
                customPageIndicator
                    .padding(.bottom, 120)
            }
        }
    }
    
    private var customPageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<todayPhotos.count, id: \.self) { index in
                Capsule()
                    .fill(index == swipeHandler.currentIndex ? .white : .white.opacity(0.3))
                    .frame(width: index == swipeHandler.currentIndex ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: swipeHandler.currentIndex)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Secret Waiting View
    
    private var secretWaitingView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            PulsingSecretIcon()
            
            VStack(spacing: 12) {
                Text("次の解禁をお楽しみに")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("全ユーザー共通のタイミングで\n写真が解禁されます")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "おはようございます"
        case 12..<17: return "こんにちは"
        default: return "こんばんは"
        }
    }
    
    private func loadEnhancedPhotos() {
        let now = Date()
        todayPhotos = [
            EnhancedPhotoItem(
                id: UUID(),
                imageData: createGradientImage(colors: [.blue, .purple]),
                capturedAt: now.addingTimeInterval(-7200),
                userName: "Alice",
                revealProgress: revealManager.isGloballyRevealed ? 1.0 : 0.0
            ),
            EnhancedPhotoItem(
                id: UUID(),
                imageData: createGradientImage(colors: [.orange, .pink]),
                capturedAt: now.addingTimeInterval(-3600),
                userName: "Bob",
                revealProgress: revealManager.isGloballyRevealed ? 1.0 : 0.0
            ),
            EnhancedPhotoItem(
                id: UUID(),
                imageData: createGradientImage(colors: [.green, .cyan]),
                capturedAt: now.addingTimeInterval(-1800),
                userName: "Charlie",
                revealProgress: revealManager.isGloballyRevealed ? 1.0 : 0.0
            )
        ]
    }
    
    private func updateStreak() {
        currentStreak = achievementManager.getCurrentStreak()
    }
    
    private func createGradientImage(colors: [Color]) -> Data {
        let size = CGSize(width: 400, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cgColors = colors.map { UIColor($0).cgColor }
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: cgColors as CFArray,
                locations: nil
            )!
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }
        return image.pngData() ?? Data()
    }
}

// MARK: - Preview

#Preview("Enhanced Home View") {
    EnhancedHomeView()
        .preferredColorScheme(.dark)
}
