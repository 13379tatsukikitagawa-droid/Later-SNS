import SwiftUI
import SwiftData

// DISABLED: This file contains duplicate type declarations
// The main implementation is in MultiGroupGalleryView.swift
// To re-enable, rename the types below (e.g., MultiGroupGalleryView_Alt)

/// 🖼️ Multi-Group Gallery View - 複数グループ対応のギャラリー
struct MultiGroupGalleryView_Disabled: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]
    @Query private var photos: [LaterPhoto]
    
    @State private var selectedGroupIndex: Int = 0
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    private var userGroups: [LaterGroup] {
        guard let user = currentUser else { return [] }
        return groups.filter { $0.members.contains(where: { $0.id == user.id }) }
    }
    
    private var selectedGroup: LaterGroup? {
        guard !userGroups.isEmpty, selectedGroupIndex < userGroups.count else {
            return nil
        }
        return userGroups[selectedGroupIndex]
    }
    
    private var groupPhotos: [LaterPhoto] {
        selectedGroup?.photos ?? []
    }
    
    var body: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
            
            if userGroups.isEmpty {
                emptyGroupsView
            } else {
                VStack(spacing: 0) {
                    headerSection
                    groupSelectorSection
                    photoGridSection
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Gallery")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            if let group = selectedGroup {
                Text(group.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.brandGreen)
            }
        }
        .padding(.top, 60)
        .padding(.bottom, 20)
    }
    
    private var groupSelectorSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(userGroups.enumerated()), id: \.element.id) { index, group in
                    GroupSelectorButton(
                        group: group,
                        isSelected: index == selectedGroupIndex
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedGroupIndex = index
                        }
                        HapticsManager.tick()
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 16)
    }
    
    private var photoGridSection: some View {
        ScrollView {
            if groupPhotos.isEmpty {
                emptyPhotosView
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(groupPhotos, id: \.id) { photo in
                        GalleryPhotoCard(photo: photo)
                    }
                }
                .padding()
            }
        }
    }
    
    private var emptyGroupsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack")
                .font(.system(size: 70))
                .foregroundColor(.white.opacity(0.3))
            
            Text("グループに参加していません")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            
            Text("Connectionからグループを作成または参加してください")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var emptyPhotosView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            
            Text("まだ写真がありません")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text("Todayから写真を撮影してみましょう")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.top, 60)
    }
}

// MARK: - Group Selector Button

struct GroupSelectorButton: View {
    let group: LaterGroup
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 18))
                
                Text(group.name)
                    .font(.system(size: 16, weight: .semibold))
                
                // メンバー数
                Text("(\(group.members.count))")
                    .font(.system(size: 14))
                    .opacity(0.7)
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [
                                    Color.brandGreen.opacity(0.5),
                                    Color.brandGreen.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.brandGreen.opacity(0.5) : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .scaleEffect(isSelected ? 1.0 : 0.95)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Gallery Photo Card

struct GalleryPhotoCard: View {
    let photo: LaterPhoto
    
    @State private var showDetail = false
    
    private var isLocked: Bool {
        !photo.isUnlocked && Date() < photo.unlockDate
    }
    
    var body: some View {
        Button {
            HapticsManager.tick()
            showDetail = true
        } label: {
            GeometryReader { geometry in
                ZStack {
                    // 写真
                    if let uiImage = UIImage(data: photo.imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(
                                width: geometry.size.width,
                                height: geometry.size.width
                            )
                            .clipped()
                            .blur(radius: isLocked ? 20 : 0)
                    } else {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                    }
                    
                    // ロックオーバーレイ
                    if isLocked {
                        VStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                            
                            Text(timeUntilUnlock(photo.unlockDate))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.6))
                        )
                    }
                    
                    // 投票バッジ
                    if photo.votingPhaseActive {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.red)
                                    .padding(8)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                                    .padding(8)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .sheet(isPresented: $showDetail) {
            PhotoDetailView(photo: photo)
        }
    }
    
    private func timeUntilUnlock(_ unlockDate: Date) -> String {
        let interval = unlockDate.timeIntervalSince(Date())
        
        if interval <= 0 {
            return "解禁済み"
        }
        
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Photo Detail View

struct PhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let photo: LaterPhoto
    
    private var isLocked: Bool {
        !photo.isUnlocked && Date() < photo.unlockDate
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // 閉じるボタン
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding()
                
                Spacer()
                
                // 写真
                if let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .blur(radius: isLocked ? 30 : 0)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                
                // 情報
                VStack(spacing: 12) {
                    if isLocked {
                        HStack {
                            Image(systemName: "lock.fill")
                            Text("ロック中")
                        }
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        
                        Text("解禁: \(photo.unlockDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        if let caption = photo.caption {
                            Text(caption)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Image(systemName: "heart.fill")
                            Text("\(photo.voteCount)")
                        }
                        .font(.system(size: 15))
                        .foregroundColor(.red)
                    }
                }
                .padding()
                
                Spacer()
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: UserProfile.self, LaterGroup.self, LaterPhoto.self,
        configurations: config
    )
    
    MultiGroupGalleryView_Disabled()
        .modelContainer(container)
}
