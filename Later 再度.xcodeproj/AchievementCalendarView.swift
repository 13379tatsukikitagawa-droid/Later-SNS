import SwiftUI

// MARK: - Achievement Calendar View
/// 達成状況を視覚化したカレンダービュー

struct AchievementCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var achievementManager = PhotoAchievementManager.shared
    @State private var selectedDate: Date = Date()
    @State private var photosForSelectedDate: [PhotoItem] = []
    @State private var showingGallery = false
    @State private var currentMonth: Date = Date()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color(red: 0.05, green: 0.05, blue: 0.1)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 統計情報ヘッダー
                        statisticsHeader
                        
                        // カレンダーヘッダー
                        calendarNavigationHeader
                        
                        // カレンダーグリッド
                        achievementCalendarGrid
                        
                        // 凡例
                        legendSection
                        
                        // 選択日の詳細
                        selectedDateDetail
                    }
                    .padding()
                }
            }
            .navigationTitle("達成カレンダー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .sheet(isPresented: $showingGallery) {
                DayGalleryView(date: selectedDate, photos: photosForSelectedDate)
            }
        }
    }
    
    // MARK: - Statistics Header
    
    private var statisticsHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                // 今月の達成日数
                StatCard(
                    icon: "calendar.badge.checkmark",
                    title: "今月の達成",
                    value: "\(achievementManager.getMonthlyAchievementCount(for: currentMonth))",
                    color: .green
                )
                
                // 連続達成日数
                StatCard(
                    icon: "flame.fill",
                    title: "連続達成",
                    value: "\(achievementManager.getCurrentStreak())",
                    color: .orange
                )
            }
            
            // 目標設定
            goalSettingSection
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var goalSettingSection: some View {
        HStack {
            Text("1日の目標:")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            
            Stepper(value: $achievementManager.dailyGoal, in: 1...20) {
                Text("\(achievementManager.dailyGoal) 枚")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.05))
        )
    }
    
    // MARK: - Calendar Navigation Header
    
    private var calendarNavigationHeader: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
            
            Text(currentMonth.formatted(.dateTime.year().month(.wide)))
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Spacer()
            
            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Achievement Calendar Grid
    
    private var achievementCalendarGrid: some View {
        VStack(spacing: 12) {
            // 曜日ヘッダー
            weekdayHeader
            
            // 日付グリッド
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(getDaysInMonth(), id: \.self) { day in
                    if day > 0 {
                        achievementDayCell(day: day)
                    } else {
                        Color.clear
                            .frame(height: 50)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { day in
                Text(day)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 8)
    }
    
    private func achievementDayCell(day: Int) -> some View {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: currentMonth)
        let year = calendar.component(.year, from: currentMonth)
        
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        
        guard let date = calendar.date(from: components) else {
            return AnyView(EmptyView())
        }
        
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let isAchieved = achievementManager.hasAchievedGoal(for: date)
        let photoCount = achievementManager.getPhotoCount(for: date)
        let isFuture = date > Date()
        
        return AnyView(
            Button {
                if !isFuture {
                    withAnimation(.spring(response: 0.3)) {
                        selectedDate = date
                        loadPhotosForDate(date)
                    }
                    
                    // ハプティック
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            } label: {
                ZStack {
                    // 背景（達成状態に応じて色分け）
                    if isAchieved {
                        // 達成した日: ゴールドの円
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.8, blue: 0.2),
                                        Color(red: 1.0, green: 0.6, blue: 0.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .orange.opacity(0.5), radius: 5)
                    } else if photoCount > 0 {
                        // 一部撮影した日: 薄いオレンジ
                        Circle()
                            .fill(.orange.opacity(0.3))
                    } else if !isFuture {
                        // 未撮影の日: 薄いグレー
                        Circle()
                            .fill(.white.opacity(0.05))
                    }
                    
                    // 選択中の日
                    if isSelected {
                        Circle()
                            .strokeBorder(.blue, lineWidth: 3)
                    }
                    
                    // 今日
                    if isToday && !isSelected {
                        Circle()
                            .strokeBorder(.white, lineWidth: 2)
                    }
                    
                    // 日付
                    VStack(spacing: 2) {
                        Text("\(day)")
                            .font(.subheadline.weight(isAchieved ? .bold : .regular))
                            .foregroundStyle(
                                isAchieved ? .white :
                                isFuture ? .white.opacity(0.3) :
                                .white.opacity(0.8)
                            )
                        
                        // 達成マーカー（ドット）
                        if isAchieved {
                            Circle()
                                .fill(.white)
                                .frame(width: 4, height: 4)
                        } else if photoCount > 0 {
                            Text("\(photoCount)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                .frame(height: 50)
            }
            .disabled(isFuture)
        )
    }
    
    // MARK: - Legend Section
    
    private var legendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("凡例")
                .font(.headline)
                .foregroundStyle(.white)
            
            HStack(spacing: 20) {
                LegendItem(
                    color: LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.8, blue: 0.2),
                            Color(red: 1.0, green: 0.6, blue: 0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    label: "目標達成"
                )
                
                LegendItem(
                    color: LinearGradient(
                        colors: [.orange.opacity(0.3), .orange.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    label: "一部撮影"
                )
                
                LegendItem(
                    color: LinearGradient(
                        colors: [.white.opacity(0.05), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    label: "未撮影"
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.03))
        )
    }
    
    // MARK: - Selected Date Detail
    
    private var selectedDateDetail: some View {
        let photoCount = achievementManager.getPhotoCount(for: selectedDate)
        let isAchieved = achievementManager.hasAchievedGoal(for: selectedDate)
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedDate.formatted(date: .long, time: .omitted))
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 8) {
                        Text("\(photoCount) 枚撮影")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                        
                        if isAchieved {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("達成!")
                                    .foregroundStyle(.green)
                            }
                            .font(.subheadline.bold())
                        }
                    }
                }
                
                Spacer()
                
                if photoCount > 0 {
                    Button {
                        showingGallery = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("ギャラリー")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(.blue)
                        )
                    }
                }
            }
            
            // プログレスバー
            if photoCount > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.1))
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: isAchieved ? [.green, .green.opacity(0.8)] : [.orange, .orange.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * min(Double(photoCount) / Double(achievementManager.dailyGoal), 1.0),
                                height: 8
                            )
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Helper Methods
    
    private func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            withAnimation {
                currentMonth = newDate
            }
        }
    }
    
    private func getDaysInMonth() -> [Int] {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: currentMonth)
        let year = calendar.component(.year, from: currentMonth)
        
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        
        guard let firstDay = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else {
            return []
        }
        
        let weekday = calendar.component(.weekday, from: firstDay) - 1
        var days: [Int] = Array(repeating: 0, count: weekday)
        days.append(contentsOf: Array(1...range.count))
        
        return days
    }
    
    private func loadPhotosForDate(_ date: Date) {
        // 実際のアプリではデータソースから取得
        photosForSelectedDate = []
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title.bold())
                .foregroundStyle(.white)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.05))
        )
    }
}

// MARK: - Legend Item

struct LegendItem: View {
    let color: LinearGradient
    let label: String
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

// MARK: - Day Gallery View

struct DayGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let photos: [PhotoItem]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if photos.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.3))
                        
                        Text("この日の写真はありません")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3),
                            spacing: 2
                        ) {
                            ForEach(photos) { photo in
                                if let uiImage = UIImage(data: photo.imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipped()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(date.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Achievement Calendar") {
    AchievementCalendarView()
        .preferredColorScheme(.dark)
        .onAppear {
            // テストデータ
            let manager = PhotoAchievementManager.shared
            let calendar = Calendar.current
            
            // 過去30日間のランダムデータ
            for i in 0..<30 {
                if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                    let count = Int.random(in: 0...7)
                    manager.setPhotoCount(count, for: date)
                }
            }
        }
}
