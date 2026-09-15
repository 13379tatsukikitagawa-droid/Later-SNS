import SwiftUI

import SwiftUI

// MARK: - Photo Item Model (for ModernCalendarView)
/// カレンダービュー用の写真データモデル

fileprivate struct PhotoItem: Identifiable {
    let id: UUID
    let imageData: Data
    let capturedAt: Date
    let userName: String
    
    init(id: UUID = UUID(), imageData: Data, capturedAt: Date, userName: String) {
        self.id = id
        self.imageData = imageData
        self.capturedAt = capturedAt
        self.userName = userName
    }
}

// MARK: - Modern Calendar View (アーカイブ)
/// 過去の写真を日付ごとに表示するカレンダービュー

struct ModernCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date = Date()
    @State private var photosForSelectedDate: [PhotoItem] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color(red: 0.05, green: 0.05, blue: 0.1)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // カレンダーヘッダー
                        calendarHeader
                        
                        // 写真グリッド
                        if photosForSelectedDate.isEmpty {
                            emptyStateView
                        } else {
                            photoGrid
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("アーカイブ")
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
        }
        .onAppear {
            loadPhotosForDate(selectedDate)
        }
    }
    
    // MARK: - Calendar Header
    
    private var calendarHeader: some View {
        VStack(spacing: 16) {
            // 月選択
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                Text(selectedDate.formatted(.dateTime.year().month(.wide)))
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal)
            
            // 簡易カレンダーグリッド
            miniCalendarGrid
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var miniCalendarGrid: some View {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: selectedDate)
        let year = calendar.component(.year, from: selectedDate)
        
        return VStack(spacing: 8) {
            // 曜日ヘッダー
            HStack {
                ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { day in
                    Text(day)
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            }
            
            // 日付グリッド
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(getDaysInMonth(month: month, year: year), id: \.self) { day in
                    if day > 0 {
                        dayCell(day: day)
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
        }
    }
    
    private func dayCell(day: Int) -> some View {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: selectedDate)
        let year = calendar.component(.year, from: selectedDate)
        
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        
        guard let date = calendar.date(from: components) else {
            return AnyView(EmptyView())
        }
        
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        
        return AnyView(
            Button {
                withAnimation(.spring(response: 0.3)) {
                    selectedDate = date
                    loadPhotosForDate(date)
                }
            } label: {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else if isToday {
                        Circle()
                            .stroke(.blue, lineWidth: 2)
                    }
                    
                    Text("\(day)")
                        .font(.subheadline.weight(isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.8))
                }
                .frame(height: 40)
            }
        )
    }
    
    // MARK: - Photo Grid
    
    private var photoGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
            spacing: 12
        ) {
            ForEach(photosForSelectedDate) { photo in
                ArchivePhotoCard(photo: photo)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("この日の写真はありません")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
    
    // MARK: - Helper Methods
    
    private func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedDate) {
            withAnimation {
                selectedDate = newDate
            }
        }
    }
    
    private func getDaysInMonth(month: Int, year: Int) -> [Int] {
        let calendar = Calendar.current
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
        // ここではモックデータ
        photosForSelectedDate = []
    }
}

// MARK: - Archive Photo Card

fileprivate struct ArchivePhotoCard: View {
    let photo: PhotoItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 写真
            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            
            // 情報
            VStack(alignment: .leading, spacing: 4) {
                Text(photo.userName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                
                Text(photo.capturedAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.05))
        )
    }
}

// MARK: - Preview

#Preview {
    ModernCalendarView()
}
