import SwiftUI
import SwiftData

// MARK: - Calendar Archive View

/// カレンダー形式で過去の写真を閲覧する画面
struct CalendarArchiveViewFixed: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \LaterPhoto.captureDate, order: .reverse) private var allPhotos: [LaterPhoto]
    
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // カレンダー
                        calendarView
                        
                        // 選択した日の写真
                        selectedDayPhotos
                    }
                    .padding()
                }
            }
            .navigationTitle("アーカイブ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
            }
        }
    }
    
    // MARK: - Calendar View
    
    private var calendarView: some View {
        VStack(spacing: 16) {
            // 月の選択
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Color.white)
                }
                
                Spacer()
                
                Text(monthYearString(from: currentMonth))
                    .font(.headline)
                    .foregroundStyle(Color.white)
                
                Spacer()
                
                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.white)
                }
            }
            .padding(.horizontal)
            
            // 曜日ヘッダー
            HStack(spacing: 0) {
                ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            }
            
            // カレンダーグリッド
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        dayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 50)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private func dayCell(for date: Date) -> some View {
        let photosCount = photosCount(for: date)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDateInToday(date)
        
        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.subheadline.weight(isSelected ? .bold : .regular))
                    .foregroundStyle(isToday ? Color.brandGreen : Color.white)
                
                if photosCount > 0 {
                    Circle()
                        .fill(Color.brandGreen)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.brandGreen.opacity(0.3) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isToday ? Color.brandGreen : Color.clear, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Selected Day Photos
    
    private var selectedDayPhotos: some View {
        let photos = photosForSelectedDay()
        
        return VStack(alignment: .leading, spacing: 16) {
            Text(dateString(from: selectedDate))
                .font(.headline)
                .foregroundStyle(Color.white)
            
            if photos.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.white.opacity(0.3))
                    
                    Text("この日の写真はありません")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(photos) { photo in
                        photoThumbnail(photo: photo)
                    }
                }
            }
        }
    }
    
    private func photoThumbnail(photo: LaterPhoto) -> some View {
        Group {
            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 150)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    private func daysInMonth() -> [Date?] {
        guard let range = Calendar.current.range(of: .day, in: .month, for: currentMonth),
              let firstDay = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: currentMonth)) else {
            return []
        }
        
        let firstWeekday = Calendar.current.component(.weekday, from: firstDay)
        let numberOfDays = range.count
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for day in 0..<numberOfDays {
            if let date = Calendar.current.date(byAdding: .day, value: day, to: firstDay) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func photosCount(for date: Date) -> Int {
        allPhotos.filter { photo in
            Calendar.current.isDate(photo.captureDate, inSameDayAs: date)
        }.count
    }
    
    private func photosForSelectedDay() -> [LaterPhoto] {
        allPhotos.filter { photo in
            Calendar.current.isDate(photo.captureDate, inSameDayAs: selectedDate)
        }
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日（E）"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

#Preview {
    CalendarArchiveViewFixed()
        .modelContainer(for: [LaterPhoto.self, UserProfile.self, LaterGroup.self])
}
