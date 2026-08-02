import SwiftUI
import SwiftData

/// メインタブナビゲーション - Home / Connection / Gallery / Profile の4タブ構成
struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var groups: [LaterGroup]
    @Query private var profiles: [UserProfile]
    
    @State private var selectedTab = 0
    @State private var circleNotificationCount = 0
    
    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }

    private var userGroups: [LaterGroup] {
        guard let user = currentUser else { return [] }
        return groups.filter { $0.members.contains(where: { $0.id == user.id }) }
    }
    
    var body: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Tab Content
                TabView(selection: $selectedTab) {
                    // Home Tab - カメラと今日の撮影状況
                    TodayView()
                        .tag(0)
                    
                    // Connection Tab - フォローとグループ
                    ConnectionView()
                        .tag(1)
                    
                    // Gallery Tab - 複数グループ対応の弧状ダイヤル付きギャラリー
                    MultiGroupGalleryView()
                        .tag(2)
                    
                    // Profile Tab - 設定画面
                    ProfileView()
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Custom Tab Bar
                customTabBar
            }
        }
        .onAppear {
            updateNotificationBadge()
        }
        .onChange(of: selectedTab) { _, _ in
            HapticsManager.swipeFeedback()
        }
    }
    
    // MARK: - Custom Tab Bar
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            // Home Tab
            TabBarButton(
                icon: "house.fill",
                title: "Home",
                isSelected: selectedTab == 0,
                badgeCount: nil
            ) {
                selectedTab = 0
            }
            
            // Connection Tab
            TabBarButton(
                icon: "person.2.fill",
                title: "Connection",
                isSelected: selectedTab == 1,
                badgeCount: circleNotificationCount > 0 ? circleNotificationCount : nil
            ) {
                selectedTab = 1
            }
            
            // Gallery Tab
            TabBarButton(
                icon: "photo.stack.fill",
                title: "Gallery",
                isSelected: selectedTab == 2,
                badgeCount: nil
            ) {
                selectedTab = 2
            }
            
            // Profile Tab
            TabBarButton(
                icon: "person.fill",
                title: "Profile",
                isSelected: selectedTab == 3,
                badgeCount: nil
            ) {
                selectedTab = 3
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color.brandDarkGray)
                .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
        )
        .overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.brandGreen.opacity(0.0),
                            Color.brandGreen.opacity(0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 1),
            alignment: .top
        )
    }
    
    // MARK: - Helpers
    
    private func updateNotificationBadge() {
        // Count unread notifications from all groups
        var count = 0
        
        for group in userGroups {
            let todayPhotos = getTodayPhotos(for: group)
            
            // Check for active voting
            if todayPhotos.contains(where: { $0.votingPhaseActive }) {
                count += 1
            }
            
            // Check for newly unlocked photos
            if todayPhotos.contains(where: { $0.isUnlocked && !$0.votingPhaseActive }) {
                count += 1
            }
        }
        
        circleNotificationCount = count
    }
    
    private func getTodayPhotos(for group: LaterGroup) -> [LaterPhoto] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return group.photos.filter { photo in
            calendar.isDate(photo.captureDate, inSameDayAs: today)
        }
    }
}

// MARK: - Tab Bar Button

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let badgeCount: Int?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(
                            isSelected
                                ? LinearGradient(
                                    colors: [.brandGreen, .brandGreen.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [.gray, .gray],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .symbolEffect(.bounce, value: isSelected)
                    
                    // Notification Badge
                    if let count = badgeCount {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text("\(min(count, 9))")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .offset(x: 8, y: -4)
                    }
                }
                
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .brandGreen : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.brandGreen.opacity(0.15) : Color.clear)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .modelContainer(for: [UserProfile.self, LaterGroup.self, LaterPhoto.self], inMemory: true)
}
