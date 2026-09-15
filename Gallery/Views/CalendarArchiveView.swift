import SwiftUI
import SwiftData

/// カレンダーアーカイブビュー - 二層構造（Personal/Group）
struct CalendarArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \LaterPhoto.captureDate, order: .reverse) private var photos: [LaterPhoto]
    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]
    
    @State private var selectedDate: Date = Date()
    @State private var selectedTab: ArchiveTab = .personal
    
    enum ArchiveTab: String, CaseIterable {
        case personal = "個人"
        case group = "グループ"
    }
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    private var currentGroup: LaterGroup? {
        groups.first
    }
    
    private var dailyGoal: Int {
        currentUser?.dailyGoal ?? 3
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // タブ切り替え
                    tabPicker
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // カレンダー with 達成マーカー
                            achievementCalendar
                            
                            // 選択された日の写真
                            if selectedTab == .personal {
                                personalPhotosSection
                            } else {
                                groupBestShotSection
                            }
                        }
                        .padding()
                    }
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
                            .foregroundStyle(Color.white.opacity(0.7))
                            .font(.title3)
                    }
                }
            }
        }
    }
    
    // MARK: - Tab Picker
    
    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(ArchiveTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = tab
                    }
                    HapticsManager.swipeFeedback()
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: tab == .personal ? "person.fill" : "person.3.fill")
                                .font(.subheadline)
                            
                            Text(tab.rawValue)
                                .font(.headline)
                        }
                        .foregroundStyle(
                            selectedTab == tab
                                ? Color.brandGreen
                                : Color.white.opacity(0.5)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        
                        // アンダーライン
                        Rectangle()
                            .fill(Color.brandGreen)
                            .frame(height: 3)
                            .opacity(selectedTab == tab ? 1 : 0)
                    }
                }
            }
        }
        .background(Color.brandDarkGray.opacity(0.3))
    }
    
    // MARK: - カレンダー with 達成マーカー
    
    private var achievementCalendar: some View {
        VStack(spacing: 16) {
            Text("達成カレンダー")
                .font(.headline)
                .foregroundStyle(Color.white)
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
                        .fill(Color.brandGreen)
                        .frame(width: 12, height: 12)
                    Text("目標達成")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 12, height: 12)
                    Text("未達成")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Personal Photos Section
    
    private var personalPhotosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(formattedSelectedDate)
                    .font(.headline)
                    .foregroundStyle(Color.white)
                
                Spacer()
                
                let dayPhotos = photosForSelectedDay
                let achievementStatus = dayPhotos.count >= dailyGoal
                
                HStack(spacing: 4) {
                    Image(systemName: achievementStatus ? "checkmark.seal.fill" : "camera.fill")
                        .foregroundStyle(achievementStatus ? Color.brandGreen : Color.white.opacity(0.5))
                    Text("\(dayPhotos.count)/\(dailyGoal)")
                        .font(.subheadline.bold())
                        .foregroundStyle(achievementStatus ? Color.brandGreen : Color.white.opacity(0.5))
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
                        ZStack(alignment: .topTrailing) {
                            if photo.isUnlocked, let uiImage = UIImage(data: photo.imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                
                                // ベストショットバッジ
                                if photo.isGroupBestShot {
                                    Image(systemName: "crown.fill")
                                        .font(.title3)
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
                                        .padding(8)
                                        .background(
                                            Circle()
                                                .fill(Color.black.opacity(0.6))
                                        )
                                        .padding(8)
                                }
                            } else {
                                CalendarArchiveDevelopingPhotoView(photo: photo)
                                    .frame(height: 180)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Group Best Shot Section
    
    private var groupBestShotSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(formattedSelectedDate)
                    .font(.headline)
                    .foregroundStyle(Color.white)
                
                Spacer()
                
                if groupBestShotForDay != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))
                        Text("栄光の1枚")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))
                    }
                }
            }
            
            if let bestShot = groupBestShotForDay {
                VStack(spacing: 16) {
                    // ベストショット画像
                    if let uiImage = UIImage(data: bestShot.imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 400)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
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
                                radius: 20,
                                y: 10
                            )
                    }
                    
                    // 撮影者情報と得票数
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "person.circle.fill")
                            Text(bestShot.owner?.name ?? "Unknown")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "hand.thumbsup.fill")
                            Text("\(bestShot.voteCount)")
                                .font(.headline)
                                .monospacedDigit()
                        }
                        .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.brandDarkGray.opacity(0.6))
                    )
                }
            } else {
                emptyGroupDayView
            }
        }
    }
    
    private var emptyDayView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(Color.white.opacity(0.3))
            
            Text("この日に撮影した写真はありません")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(Color.brandDarkGray.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private var emptyGroupDayView: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown")
                .font(.system(size: 48))
                .foregroundStyle(Color.white.opacity(0.3))
            
            Text("この日のベストショットはまだ選出されていません")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
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
    
    private var groupBestShotForDay: LaterPhoto? {
        guard let group = currentGroup else { return nil }
        return group.photos.first { photo in
            let isSameDay = Calendar.current.isDate(photo.captureDate, inSameDayAs: selectedDate)
            return isSameDay && photo.isGroupBestShot
        }
    }
    
    private var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日 (E)"
        return formatter.string(from: selectedDate)
    }
}

// MARK: - Developing Photo View (CalendarArchiveView)

private struct CalendarArchiveDevelopingPhotoView: View {
    let photo: LaterPhoto
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.brandDarkGray)
            
            VStack(spacing: 12) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.brandGreen.opacity(0.5))
                    .symbolEffect(.pulse)
                
                Text("現像中...")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        }
    }
}

#Preview {
    CalendarArchiveView()
        .modelContainer(for: [LaterPhoto.self, UserProfile.self, LaterGroup.self])
}
