import SwiftUI
import SwiftData

// MARK: - 📸 Enhanced Gallery View (Multiple Groups + Arc Dial)
/// 複数グループ対応 + 弧状日付ダイヤル + 3:2全画面表示

struct EnhancedGalleryView: View {
    @Query(sort: \LaterPhoto.captureDate, order: .reverse) private var allPhotos: [LaterPhoto]
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]
    
    // テーマカラー
    @AppStorage("themeColor") private var themeColorName: String = "green"
    
    // 日付選択（永続化）
    @AppStorage("gallerySelectedDayIndex") private var selectedDayIndex: Int = 0
    
    // 表示モード
    @State private var displayMode: DisplayMode = .personal
    
    // 選択中のグループ（Group Mode時）
    @State private var selectedGroupID: String?
    
    // 写真インデックス（横スワイプ用）
    @State private var currentPhotoIndex: Int = 0
    
    // ダイヤル操作中フラグ
    @State private var isDialActive: Bool = false
    
    // ハプティクス
    private let haptics = UISelectionFeedbackGenerator()
    
    enum DisplayMode: String, CaseIterable {
        case personal = "Personal"
        case group = "Group"
    }
    
    // テーマカラー
    private var themeColor: Color {
        switch themeColorName {
        case "green": return .brandGreen
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        default: return .brandGreen
        }
    }
    
    // 現在のユーザー
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    // 選択中のグループ
    private var selectedGroup: LaterGroup? {
        guard let id = selectedGroupID else { return groups.first }
        return groups.first(where: { $0.id == id })
    }
    
    // 直近7日間
    private var last7Days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).map { calendar.date(byAdding: .day, value: -$0, to: today)! }
    }
    
    // 選択中の日付
    private var selectedDate: Date {
        last7Days[selectedDayIndex]
    }
    
    // Personal: 選択日の写真（最大5枚）
    private var personalPhotos: [LaterPhoto] {
        guard let user = currentUser else { return [] }
        let calendar = Calendar.current
        
        return allPhotos.filter { photo in
            guard photo.owner?.id == user.id else { return false }
            return calendar.isDate(photo.captureDate, inSameDayAs: selectedDate)
        }.prefix(5).map { $0 }
    }
    
    // Group: 選択日のWinner写真（1枚）
    private var groupWinnerPhoto: LaterPhoto? {
        guard let group = selectedGroup else { return nil }
        let calendar = Calendar.current
        
        return group.photos.first { photo in
            photo.isGroupBestShot && calendar.isDate(photo.captureDate, inSameDayAs: selectedDate)
        }
    }
    
    // 表示する写真リスト
    private var displayedPhotos: [LaterPhoto] {
        switch displayMode {
        case .personal:
            return personalPhotos
        case .group:
            if let winner = groupWinnerPhoto {
                return [winner]
            }
            return []
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ヘッダー（モード切り替え + グループセレクター）
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                
                // 写真ステージ（3:2全画面）
                photoStage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // 弧状日付ダイヤル
                arcDateDial
                    .frame(height: 220)
                    .background(
                        Rectangle()
                            .fill(Color.black.opacity(0.8))
                            .ignoresSafeArea(edges: .bottom)
                    )
                
                // メタデータバー
                metadataBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            haptics.prepare()
            // 初回選択グループを設定
            if selectedGroupID == nil {
                selectedGroupID = groups.first?.id
            }
        }
    }
    
    // MARK: - Header
    private var header: some View {
        VStack(spacing: 12) {
            // 日付 + モード切り替え
            HStack {
                // 日付表示
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate(selectedDate))
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                    
                    Text(weekdayString(for: selectedDate))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(themeColor)
                        .textCase(.uppercase)
                }
                
                Spacer()
                
                // モード切り替え
                modeSwitcher
            }
            
            // グループセレクター（Group Mode時のみ）
            if displayMode == .group && !groups.isEmpty {
                groupSelector
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    // MARK: - Mode Switcher
    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(DisplayMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        displayMode = mode
                        currentPhotoIndex = 0
                    }
                    haptics.selectionChanged()
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(displayMode == mode ? .black : .white.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(displayMode == mode ? themeColor : Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
    
    // MARK: - Group Selector
    private var groupSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(groups, id: \.id) { group in
                    GroupChip(
                        group: group,
                        isSelected: selectedGroupID == group.id,
                        themeColor: themeColor
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedGroupID = group.id
                            currentPhotoIndex = 0
                        }
                        haptics.selectionChanged()
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Photo Stage
    private var photoStage: some View {
        let photos = displayedPhotos
        
        return ZStack {
            if photos.isEmpty {
                emptyStateView
            } else {
                TabView(selection: $currentPhotoIndex) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                        ZStack {
                            // 写真（3:2全画面）
                            if let imageData = photo.imageData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(3/2, contentMode: .fill)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipped()
                                    .blur(radius: isDialActive ? 8 : 0)  // ダイヤル操作中はぼかし
                            }
                            
                            // ビューファインダーオーバーレイ
                            viewfinderOverlay
                            
                            // 撮影データ
                            shootingDataOverlay
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: selectedDayIndex) { _, _ in
                    currentPhotoIndex = 0
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: displayMode == .personal ? "photo.badge.plus" : "photo.stack")
                .font(.system(size: 64))
                .foregroundStyle(themeColor.opacity(0.4))
            
            Text(displayMode == .personal ? "この日の写真はまだありません" : "この日のWinner写真はありません")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
    
    // MARK: - Viewfinder Overlay
    private var viewfinderOverlay: some View {
        GeometryReader { geo in
            let size = geo.size
            let corner: CGFloat = 28
            
            ZStack {
                // 左上
                Path { p in
                    p.move(to: CGPoint(x: 20, y: 20 + corner))
                    p.addLine(to: CGPoint(x: 20, y: 20))
                    p.addLine(to: CGPoint(x: 20 + corner, y: 20))
                }
                .stroke(themeColor, lineWidth: 2)
                
                // 右上
                Path { p in
                    p.move(to: CGPoint(x: size.width - 20 - corner, y: 20))
                    p.addLine(to: CGPoint(x: size.width - 20, y: 20))
                    p.addLine(to: CGPoint(x: size.width - 20, y: 20 + corner))
                }
                .stroke(themeColor, lineWidth: 2)
                
                // 左下
                Path { p in
                    p.move(to: CGPoint(x: 20, y: size.height - 20 - corner))
                    p.addLine(to: CGPoint(x: 20, y: size.height - 20))
                    p.addLine(to: CGPoint(x: 20 + corner, y: size.height - 20))
                }
                .stroke(themeColor, lineWidth: 2)
                
                // 右下
                Path { p in
                    p.move(to: CGPoint(x: size.width - 20 - corner, y: size.height - 20))
                    p.addLine(to: CGPoint(x: size.width - 20, y: size.height - 20))
                    p.addLine(to: CGPoint(x: size.width - 20, y: size.height - 20 - corner))
                }
                .stroke(themeColor, lineWidth: 2)
            }
        }
        .allowsHitTesting(false)
        .opacity(0.6)
    }
    
    // MARK: - Shooting Data Overlay
    private var shootingDataOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text("1/125s").foregroundStyle(themeColor)
                Text("ISO 200").foregroundStyle(.white.opacity(0.7))
                Text("35mm").foregroundStyle(.white.opacity(0.7))
            }
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.5))
            )
            .padding(.leading, 20)
            .padding(.top, 20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }
    
    // MARK: - Arc Date Dial
    private var arcDateDial: some View {
        ArcDateDial(
            dates: last7Days,
            selectedIndex: $selectedDayIndex,
            themeColor: themeColor,
            isDialActive: $isDialActive,
            onIndexChanged: {
                haptics.selectionChanged()
            }
        )
    }
    
    // MARK: - Metadata Bar
    private var metadataBar: some View {
        let photos = displayedPhotos
        let photo = (currentPhotoIndex < photos.count ? photos[currentPhotoIndex] : nil)
        
        return HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(themeColor.opacity(0.8))
            
            Text(photo?.caption ?? "")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
            
            Spacer()
        }
    }
    
    // MARK: - Helpers
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func weekdayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

// MARK: - Group Chip
struct GroupChip: View {
    let group: LaterGroup
    let isSelected: Bool
    let themeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // グループアイコン
                Circle()
                    .fill(isSelected ? themeColor : .white.opacity(0.3))
                    .frame(width: 8, height: 8)
                
                // グループ名
                Text(group.name)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isSelected ? themeColor : .white.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? themeColor.opacity(0.15) : Color.white.opacity(0.05))
                    .overlay(
                        Capsule()
                            .strokeBorder(isSelected ? themeColor.opacity(0.4) : .clear, lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Arc Date Dial
struct ArcDateDial: View {
    let dates: [Date]
    @Binding var selectedIndex: Int
    let themeColor: Color
    @Binding var isDialActive: Bool
    let onIndexChanged: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let centerX = width / 2
            let radius: CGFloat = 200
            
            ZStack {
                // 弧状のパス
                ForEach(Array(dates.enumerated()), id: \.offset) { index, date in
                    let angle = calculateAngle(for: index, total: dates.count)
                    let x = centerX + radius * cos(angle)
                    let y = radius * sin(angle) + 120
                    
                    DateNode(
                        date: date,
                        isSelected: index == selectedIndex,
                        themeColor: themeColor
                    )
                    .position(x: x, y: y)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDialActive = true
                        
                        let translation = value.translation.width
                        let sensitivity: CGFloat = 0.01
                        let indexChange = Int(translation * sensitivity)
                        
                        let newIndex = clamp(selectedIndex - indexChange, min: 0, max: dates.count - 1)
                        
                        if newIndex != selectedIndex {
                            selectedIndex = newIndex
                            onIndexChanged()
                        }
                    }
                    .onEnded { _ in
                        isDialActive = false
                    }
            )
        }
    }
    
    // 角度計算（左から右へ弧状に配置）
    private func calculateAngle(for index: Int, total: Int) -> CGFloat {
        let totalAngle: CGFloat = .pi  // 180度
        let startAngle: CGFloat = .pi  // 左端
        let step = totalAngle / CGFloat(total - 1)
        return startAngle - CGFloat(index) * step
    }
    
    private func clamp(_ value: Int, min: Int, max: Int) -> Int {
        Swift.min(Swift.max(value, min), max)
    }
}

// MARK: - Date Node
struct DateNode: View {
    let date: Date
    let isSelected: Bool
    let themeColor: Color
    
    var body: some View {
        VStack(spacing: 6) {
            // 日付
            Text(dayString)
                .font(.system(size: isSelected ? 24 : 16, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? themeColor : .white.opacity(0.5))
            
            // 曜日
            Text(weekdayString)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(isSelected ? themeColor.opacity(0.8) : .white.opacity(0.4))
                .textCase(.uppercase)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? themeColor.opacity(0.2) : .clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected ? themeColor : .white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                )
        )
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var weekdayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    EnhancedGalleryView()
        .modelContainer(for: [LaterPhoto.self, UserProfile.self, LaterGroup.self])
}
