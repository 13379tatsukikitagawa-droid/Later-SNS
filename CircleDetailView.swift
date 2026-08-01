import SwiftUI
import SwiftData

/// Circle詳細画面 - グループの詳細情報と管理
struct CircleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let group: LaterGroup
    
    @State private var showingSettings = false
    @State private var showingInvite = false
    
    private var todayPhotos: [LaterPhoto] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return group.photos.filter { photo in
            calendar.isDate(photo.captureDate, inSameDayAs: today)
        }
    }
    
    private var isVotingActive: Bool {
        todayPhotos.contains(where: { $0.votingPhaseActive })
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Today's Status
                        statusSection
                        
                        // Photos Grid
                        if !todayPhotos.isEmpty {
                            photosSection
                        }
                        
                        // Members List
                        membersSection
                        
                        // Actions
                        actionsSection
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(group.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                CircleSettingsView(group: group)
            }
            .sheet(isPresented: $showingInvite) {
                InviteMembersView(group: group)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Group Icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.brandGreen.opacity(0.3),
                                Color.brandGreen.opacity(0.1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "person.3.fill")
                    .font(.system(size: 45))
                    .foregroundStyle(Color.brandGreen)
            }
            
            VStack(spacing: 8) {
                Text(group.name)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                
                HStack(spacing: 16) {
                    Label("\(group.members.count) members", systemImage: "person.2.fill")
                    
                    if let host = group.host {
                        Label("Host: \(host.name)", systemImage: "star.fill")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Today's Progress")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(todayPhotos.count)/\(group.members.count)")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.brandGreen)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.brandGreen)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 8)
            
            // Status text
            if isVotingActive {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    
                    Text("Voting in progress")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    
                    Spacer()
                }
            } else if todayPhotos.contains(where: { $0.isGroupBestShot }) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.brandGreen)
                        .frame(width: 8, height: 8)
                    
                    Text("Today's best selected!")
                        .font(.subheadline)
                        .foregroundStyle(Color.brandGreen)
                    
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.brandDarkGray)
        )
    }
    
    private var progress: CGFloat {
        guard group.members.count > 0 else { return 0 }
        return CGFloat(todayPhotos.count) / CGFloat(group.members.count)
    }
    
    // MARK: - Photos Section
    
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Photos")
                .font(.headline)
                .foregroundStyle(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(todayPhotos) { photo in
                    PhotoThumbnailView(photo: photo)
                }
            }
        }
    }
    
    // MARK: - Members Section
    
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Members")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button(action: {
                    showingInvite = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Invite")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.brandGreen)
                }
            }
            
            VStack(spacing: 12) {
                ForEach(group.members) { member in
                    MemberRowView(
                        member: member,
                        isHost: group.host?.id == member.id
                    )
                }
            }
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Leave Group
            Button(action: leaveGroup) {
                Text("Leave Group")
                    .font(.headline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.red.opacity(0.5), lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.red.opacity(0.1))
                            )
                    )
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Helpers
    
    private func leaveGroup() {
        // TODO: Implement leave group logic
        HapticsManager.swipeFeedback()
    }
}

// MARK: - Photo Thumbnail View

struct PhotoThumbnailView: View {
    let photo: LaterPhoto
    
    var body: some View {
        ZStack {
            if photo.isUnlocked, let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                // Locked photo
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.brandDarkGray)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "lock.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    )
            }
            
            // Best shot badge
            if photo.isGroupBestShot {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                            .padding(6)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                    Spacer()
                }
                .padding(6)
            }
            
            // Voting indicator
            if photo.votingPhaseActive {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 10))
                        Text("\(photo.voteCount)")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                    )
                }
                .padding(6)
            }
        }
    }
}

// MARK: - Member Row View

struct MemberRowView: View {
    let member: UserProfile
    let isHost: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.brandGreen.opacity(0.6), .brandGreen.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Text(member.name.prefix(1).uppercased())
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(member.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    
                    if isHost {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.brandGreen)
                    }
                }
                
                Text("@\(member.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.brandDarkGray)
        )
    }
}

// MARK: - Invite Members View

struct InviteMembersView: View {
    @Environment(\.dismiss) private var dismiss
    let group: LaterGroup
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Share this QR code to invite members")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 40)
                    
                    // QR Code
                    if let qrImage = generateQRCode() {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 250, height: 250)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .brandGreen.opacity(0.3), radius: 20)
                    }
                    
                    // Invite Code
                    VStack(spacing: 8) {
                        Text("Invite Code")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(group.inviteCode)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .fontDesign(.monospaced)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.brandDarkGray)
                            )
                    }
                    
                    Spacer()
                    
                    // Share button
                    Button(action: shareInvite) {
                        Label("Share Invite", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.brandGreen)
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Invite Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func generateQRCode() -> UIImage? {
        let qrData = QRCodeGenerator.createGroupQRData(
            groupID: group.id.uuidString,
            groupName: group.name
        )
        return QRCodeGenerator.generateStyledQRCode(from: qrData, size: 512)
    }
    
    private func shareInvite() {
        // TODO: Implement share sheet
        HapticsManager.swipeFeedback()
    }
}

// MARK: - Circle Settings View

struct CircleSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let group: LaterGroup
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                List {
                    Section {
                        Text("Settings coming soon...")
                            .foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Circle Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: LaterGroup.self, UserProfile.self, LaterPhoto.self, configurations: config)
    
    let user = UserProfile(name: "Test User", username: "testuser")
    let group = LaterGroup(name: "Test Group", host: user)
    group.members.append(user)
    
    container.mainContext.insert(user)
    container.mainContext.insert(group)
    
    return CircleDetailView(group: group)
        .modelContainer(container)
}
