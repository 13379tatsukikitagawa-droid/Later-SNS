import SwiftUI
import SwiftData

/// 複数グループ対応の弧状ダイヤル付きギャラリー
struct MultiGroupGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LaterPhoto.captureDate, order: .reverse) private var allPhotos: [LaterPhoto]
    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]
    
    // Display mode toggle
    @State private var displayMode: DisplayMode = .personal
    
    // Group selection (for Group mode)
    @State private var selectedGroupIndex: Int = 0
    
    // Date selection (maintained across group switches)
    @State private var selectedDateIndex: Int = 0
    
    // Photo paging
    @State private var currentPhotoIndex: Int = 0
    
    // Loading state for smooth transitions
    @State private var isLoadingPhoto: Bool = false
    
    // Haptics
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    enum DisplayMode: String, CaseIterable {
        case personal = "Personal"
        case group = "Group"
    }
    
    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }

    // User's groups
    private var userGroups: [LaterGroup] {
        guard let user = currentUser else { return [] }
        return groups.filter { group in
            group.members.contains(where: { $0.id == user.id })
        }
    }
    
    // Currently selected group
    private var selectedGroup: LaterGroup? {
        guard displayMode == .group,
              !userGroups.isEmpty,
              selectedGroupIndex < userGroups.count else {
            return nil
        }
        return userGroups[selectedGroupIndex]
    }
    
    // Last 7 days
    private var last7Days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).map { calendar.date(byAdding: .day, value: -$0, to: today)! }
    }
    
    private var selectedDate: Date {
        last7Days[selectedDateIndex]
    }
    
    // Photos for selected date (Personal mode)
    private var selectedDayPhotos: [LaterPhoto] {
        guard let user = currentUser else { return [] }
        let calendar = Calendar.current
        
        return allPhotos.filter { photo in
            guard photo.owner?.id == user.id else { return false }
            guard photo.isUnlocked else { return false }
            return calendar.isDate(photo.captureDate, inSameDayAs: selectedDate)
        }
    }
    
    // Best shot for selected group and date (Group mode)
    private var selectedGroupBestShot: LaterPhoto? {
        guard let group = selectedGroup else { return nil }
        let calendar = Calendar.current
        
        return group.photos.first { photo in
            photo.isGroupBestShot && 
            photo.isUnlocked &&
            calendar.isDate(photo.captureDate, inSameDayAs: selectedDate)
        }
    }
    
    private var displayPhotos: [LaterPhoto] {
        switch displayMode {
        case .personal:
            return selectedDayPhotos
        case .group:
            if let bestShot = selectedGroupBestShot {
                return [bestShot]
            } else {
                return []
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Full black background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Navigation - Two-tier structure
                navigationHeader
                
                // Full-screen photo stage
                photoStage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Arc dial at bottom
                MultiGroupArcDial(
                    dates: last7Days,
                    selectedIndex: $selectedDateIndex,
                    onIndexChanged: { newIndex in
                        selectionFeedback.selectionChanged()
                        currentPhotoIndex = 0
                        // Trigger photo reload
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isLoadingPhoto = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isLoadingPhoto = false
                            }
                        }
                    }
                )
                .frame(height: 200)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            selectionFeedback.prepare()
            impactFeedback.prepare()
        }
    }
    
    // MARK: - Navigation Header (Two-tier)
    
    private var navigationHeader: some View {
        VStack(spacing: 0) {
            // Tier 1: Mode Switcher (Personal | Group)
            modeSwitcher
                .padding(.top, 16)
                .padding(.horizontal, 20)
            
            // Tier 2: Circle Selector (visible only in Group mode)
            if displayMode == .group {
                circleSelector
                    .padding(.top, 12)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .background(.ultraThinMaterial.opacity(0.3))
                .ignoresSafeArea(edges: .top)
        )
    }
    
    // MARK: - Mode Switcher
    
    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(DisplayMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        displayMode = mode
                        currentPhotoIndex = 0
                    }
                    impactFeedback.impactOccurred()
                    
                    // If switching to Group mode and no groups, show empty state
                    if mode == .group && userGroups.isEmpty {
                        // Handle empty state
                    }
                }) {
                    Text(mode.rawValue)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(displayMode == mode ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(displayMode == mode ? Color.brandGreen : Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    // MARK: - Circle Selector (LazyHStack for performance)
    
    private var circleSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(Array(userGroups.enumerated()), id: \.offset) { index, group in
                    groupChip(group: group, index: index)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 44)
    }
    
    private func groupChip(group: LaterGroup, index: Int) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedGroupIndex = index
                currentPhotoIndex = 0
                
                // Fade transition for photo
                isLoadingPhoto = true
            }
            
            selectionFeedback.selectionChanged()
            
            // Simulate photo load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isLoadingPhoto = false
                }
            }
        }) {
            Text(group.name)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(selectedGroupIndex == index ? .brandGreen : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    selectedGroupIndex == index ? 
                                        Color.brandGreen : Color.white.opacity(0.2),
                                    lineWidth: selectedGroupIndex == index ? 2 : 1
                                )
                        )
                        .shadow(
                            color: selectedGroupIndex == index ? 
                                Color.brandGreen.opacity(0.6) : .clear,
                            radius: selectedGroupIndex == index ? 12 : 0
                        )
                )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedGroupIndex)
    }
    
    // MARK: - Photo Stage
    
    private var photoStage: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = width * 2 / 3  // 3:2 aspect ratio
            
            ZStack {
                if isLoadingPhoto {
                    // Loading spinner
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .brandGreen))
                            .scaleEffect(1.5)
                        
                        Text("Loading...")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(.brandGreen)
                            .padding(.top, 12)
                    }
                } else if displayPhotos.isEmpty {
                    emptyStateView
                } else {
                    TabView(selection: $currentPhotoIndex) {
                        ForEach(Array(displayPhotos.enumerated()), id: \.offset) { index, photo in
                            photoCard(photo: photo, width: width, height: height)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onChange(of: currentPhotoIndex) { _, _ in
                        impactFeedback.impactOccurred()
                    }
                    .transition(.opacity)
                    
                    // Page indicator
                    if displayPhotos.count > 1 {
                        VStack {
                            Spacer()
                            
                            HStack(spacing: 8) {
                                ForEach(0..<displayPhotos.count, id: \.self) { index in
                                    Circle()
                                        .fill(currentPhotoIndex == index ? Color.brandGreen : Color.white.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                        .animation(.spring(response: 0.3), value: currentPhotoIndex)
                                }
                            }
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    private func photoCard(photo: LaterPhoto, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Photo
            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width - 40, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.brandGreen.opacity(0.3),
                                        Color.brandGreen.opacity(0.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            }
            
            // Caption
            if let caption = photo.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 24)
            }
            
            // Timestamp
            Text(photo.captureDate, style: .date)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            
            Spacer()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: displayMode == .group ? "person.3.slash" : "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            if displayMode == .group, let groupName = selectedGroup?.name {
                Text("No active photo for this day in \(groupName)")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                Text("この日の写真はまだありません")
                    .font(.system(size: 18, weight: .medium, design: .serif))
                    .foregroundStyle(.secondary)
                
                Text("カメラで撮影して、24時間後に解禁されます")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Arc Dial Component

struct MultiGroupArcDial: View {
    let dates: [Date]
    @Binding var selectedIndex: Int
    let onIndexChanged: (Int) -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    private let itemSpacing: CGFloat = 80
    private let arcRadius: CGFloat = 400
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let centerX = width / 2
            
            ZStack {
                // Background glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.brandGreen.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(y: 100)
                
                // Date items on arc
                ForEach(Array(dates.enumerated()), id: \.offset) { index, date in
                    dateItem(for: date, at: index, centerX: centerX)
                }
                
                // Center indicator line
                Rectangle()
                    .fill(Color.brandGreen)
                    .frame(width: 2, height: 40)
                    .offset(y: -80)
            }
            .frame(width: width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        dragOffset = value.translation.width
                        
                        // Calculate new index
                        let offsetIndex = Int(-dragOffset / itemSpacing)
                        let newIndex = max(0, min(dates.count - 1, selectedIndex + offsetIndex))
                        
                        if newIndex != selectedIndex {
                            selectedIndex = newIndex
                            onIndexChanged(newIndex)
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        dragOffset = 0
                    }
            )
        }
    }
    
    private func dateItem(for date: Date, at index: Int, centerX: CGFloat) -> some View {
        let offset = CGFloat(index - selectedIndex) * itemSpacing
        let totalOffset = offset + dragOffset
        
        // Calculate position on arc
        let angle = totalOffset / arcRadius
        let x = centerX + sin(angle) * arcRadius
        let y = arcRadius - cos(angle) * arcRadius - 50
        
        // Scale and opacity based on distance from center
        let distance = abs(totalOffset)
        let scale = max(0.5, 1.0 - distance / 300)
        let opacity = max(0.3, 1.0 - distance / 250)
        
        // Selected state
        let isSelected = index == selectedIndex
        
        return VStack(spacing: 8) {
            // Date number
            Text(dayNumber(from: date))
                .font(.system(size: isSelected ? 48 : 32, weight: .bold, design: .rounded))
                .foregroundStyle(
                    isSelected ?
                        Color.brandGreen :
                        Color.white.opacity(opacity)
                )
                .shadow(
                    color: isSelected ? Color.brandGreen.opacity(0.8) : .clear,
                    radius: isSelected ? 20 : 0
                )
            
            // Weekday
            Text(weekday(from: date))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(opacity * 0.7))
                .tracking(1)
        }
        .scaleEffect(scale)
        .rotation3DEffect(
            .degrees(Double(angle) * 30),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .position(x: x, y: y)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedIndex)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
    }
    
    private func dayNumber(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func weekday(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date).uppercased()
    }
}

// MARK: - Preview

#Preview {
    MultiGroupGalleryView()
        .modelContainer(for: [UserProfile.self, LaterPhoto.self, LaterGroup.self], inMemory: true)
}
