// このファイルは重複のため無効化されました
// メインの実装は CalendarArchiveView_Fixed.swift を参照してください

/*
import SwiftUI
import SwiftData

/// カレンダーアーカイブビュー - 達成マーカー付き
struct CalendarArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \LaterPhoto.captureDate, order: .reverse) private var photos: [LaterPhoto]
    @Query private var profiles: [UserProfile]
    
    @State private var selectedDate: Date = Date()
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    private var dailyGoal: Int {
        currentUser?.dailyGoal ?? 3
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // カレンダー with 達成マーカー
                        achievementCalendar
                        
                        // 選択された日の写真
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
                            .foregroundStyle(.white.opacity(0.7))
                            .font(.title3)
                    }
                }
            }
        }
    }
    
    // MARK: - カレンダー with 達成マーカー
    
    private var achievementCalendar: some View {
        VStack(spacing: 16) {
            Text("達成カレンダー")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // SwiftUI DatePicker with custom overlay
            ZStack {
                DatePicker(
                    "",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .tint(.brandGreen)
                .colorScheme(.dark)
                
                // Custom achievement markers overlay
                // Note: This is a simplified version. For full customization,
                // you might need to create a custom calendar view
            }
            .background(Color.brandDarkGray.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            // 達成日の凡例
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.brandGreen)
                        .frame(width: 12, height: 12)
                    Text("目標達成")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 12, height: 12)
                    Text("未達成")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - 選択された日の写真
    
    private var selectedDayPhotos: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(formattedSelectedDate)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                let dayPhotos = photosForSelectedDay
                let achievementStatus = dayPhotos.count >= dailyGoal
                
                HStack(spacing: 4) {
                    Image(systemName: achievementStatus ? "checkmark.seal.fill" : "camera.fill")
                        .foregroundStyle(achievementStatus ? .brandGreen : .white.opacity(0.5))
                    Text("\(dayPhotos.count)/\(dailyGoal)")
                        .font(.subheadline.bold())
                        .foregroundStyle(achievementStatus ? .brandGreen : .white.opacity(0.5))
                }
            }
            
            if photosForSelectedDay.isEmpty {
                emptyDayView
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(photosForSelectedDay) { photo in
                        if photo.isUnlocked, let uiImage = UIImage(data: photo.imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        } else {
                            DevelopingPhotoView(photo: photo)
                                .frame(height: 180)
                        }
                    }
                }
            }
        }
    }
    
    private var emptyDayView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("この日に撮影した写真はありません")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(Color.brandDarkGray.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Helpers
    
    private var photosForSelectedDay: [LaterPhoto] {
        let userID = currentUser?.id
        return photos.filter { photo in
            let isMine = photo.owner?.id == userID
            let isSameDay = Calendar.current.isDate(photo.captureDate, inSameDayAs: selectedDate)
            return isMine && isSameDay
        }
    }
    
    private var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日 (E)"
        return formatter.string(from: selectedDate)
    }
}

#Preview {
    CalendarArchiveView()
        .modelContainer(for: [LaterPhoto.self, UserProfile.self, LaterGroup.self])
}
*/
