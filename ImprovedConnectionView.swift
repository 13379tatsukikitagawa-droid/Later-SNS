import SwiftUI
import SwiftData

// MARK: - 🔗 Improved Connection View: QR + Friends + Circle Management
struct ImprovedConnectionView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]
    
    @State private var showQRScanner = false
    @State private var showMyQRCode = false
    @State private var showCircleManagement = false
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    private var myGroups: [LaterGroup] {
        guard let user = currentUser else { return [] }
        return groups.filter { $0.members.contains(where: { $0.id == user.id }) }
    }
    
    private var myFriends: [UserProfile] {
        currentUser?.following ?? []
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // My QR Code Card
                        myQRSection
                        
                        // Friends List
                        friendsSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationTitle("Connections")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // Circle Management Button
                        Button {
                            showCircleManagement = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(limeGreen.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "circle.hexagongrid.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(limeGreen)
                                
                                if !myGroups.isEmpty {
                                    Circle()
                                        .fill(limeGreen)
                                        .frame(width: 18, height: 18)
                                        .overlay(
                                            Text("\(min(myGroups.count, 9))")
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundStyle(.black)
                                        )
                                        .offset(x: 14, y: -14)
                                }
                            }
                        }
                        
                        // QR Scanner Button
                        Button {
                            showQRScanner = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showQRScanner) {
                ImprovedConnectionQRScannerView()
            }
            .sheet(isPresented: $showMyQRCode) {
                if let user = currentUser {
                    ImprovedConnectionMyQRCodeView(user: user)
                }
            }
            .sheet(isPresented: $showCircleManagement) {
                ImprovedConnectionCircleManagementView()
            }
        }
    }
    
    // MARK: - My QR Section
    
    private var myQRSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("MY QR CODE")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(2)
                Spacer()
            }
            
            Button {
                showMyQRCode = true
            } label: {
                HStack(spacing: 16) {
                    // QR Code icon placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "qrcode")
                            .font(.system(size: 40))
                            .foregroundStyle(.black)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(currentUser?.username ?? "User")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        
                        Text("INVITE CODE: \(currentUser?.inviteCode ?? "XXXXXX")")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(limeGreen)
                            .tracking(1)
                        
                        Text("Tap to view full QR code")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(limeGreen.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    // MARK: - Friends Section
    
    private var friendsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("FRIENDS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(2)
                
                Spacer()
                
                Text("\(myFriends.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(limeGreen)
            }
            
            if myFriends.isEmpty {
                emptyFriendsView
            } else {
                ForEach(myFriends) { friend in
                    FriendRowView(friend: friend)
                }
            }
        }
    }
    
    private var emptyFriendsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No friends yet")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
            
            Text("Scan a friend's QR code to connect")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var limeGreen: Color {
        Color(red: 0, green: 1, blue: 0.255)
    }
}

// MARK: - Friend Row View

struct FriendRowView: View {
    let friend: UserProfile
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile image placeholder
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(friend.name.prefix(1))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                
                Text("@\(friend.username)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Circle Management View (ImprovedConnectionView)

private struct ImprovedConnectionCircleManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]
    
    @State private var showCreateCircle = false
    @State private var showJoinCircle = false
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    private var myGroups: [LaterGroup] {
        guard let user = currentUser else { return [] }
        return groups.filter { $0.members.contains(where: { $0.id == user.id }) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Action buttons
                        actionButtons
                        
                        // My Circles
                        myCirclesSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationTitle("Circles")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showCreateCircle) {
                CreateCircleView()
            }
            .sheet(isPresented: $showJoinCircle) {
                JoinCircleView()
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                showCreateCircle = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Create")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0, green: 1, blue: 0.255))
                )
            }
            
            Button {
                showJoinCircle = true
            } label: {
                HStack {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Join")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private var myCirclesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("MY CIRCLES")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(2)
                
                Spacer()
                
                Text("\(myGroups.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0, green: 1, blue: 0.255))
            }
            
            if myGroups.isEmpty {
                emptyCirclesView
            } else {
                ForEach(myGroups) { group in
                    CircleRowView(group: group, currentUser: currentUser)
                }
            }
        }
    }
    
    private var emptyCirclesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "circle.hexagongrid")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No circles yet")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
            
            Text("Create or join a circle to share memories")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Circle Row View

struct CircleRowView: View {
    let group: LaterGroup
    let currentUser: UserProfile?
    
    var isHost: Bool {
        guard let user = currentUser else { return false }
        return group.host?.id == user.id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(group.name)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                
                Spacer()
                
                if isHost {
                    Text("HOST")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(red: 0, green: 1, blue: 0.255))
                        )
                }
            }
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                    Text("\(group.memberCount)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.6))
                
                HStack(spacing: 4) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 12))
                    Text("\(group.totalPhotos)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.6))
                
                Spacer()
                
                Text("CODE: \(group.inviteCode)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0, green: 1, blue: 0.255))
                    .tracking(1)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(red: 0, green: 1, blue: 0.255).opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Create Circle View

struct CreateCircleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    
    @State private var circleName = ""
    @State private var showShareSheet = false
    @State private var createdGroup: LaterGroup?
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Circle icon
                    Image(systemName: "circle.hexagongrid.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Color(red: 0, green: 1, blue: 0.255))
                    
                    // Input
                    VStack(spacing: 16) {
                        Text("CREATE A CIRCLE")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .tracking(2)
                        
                        TextField("", text: $circleName, prompt: Text("Circle name...").foregroundColor(.white.opacity(0.4)))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color(red: 0, green: 1, blue: 0.255).opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                    
                    // Create button
                    Button {
                        createCircle()
                    } label: {
                        Text("Create & Invite")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(red: 0, green: 1, blue: 0.255))
                            )
                    }
                    .disabled(circleName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(circleName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("New Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let group = createdGroup {
                    ShareInviteView(group: group)
                }
            }
        }
    }
    
    private func createCircle() {
        guard let user = currentUser else { return }
        
        let newGroup = LaterGroup(
            name: circleName.trimmingCharacters(in: .whitespaces),
            host: user,
            autoGenerateMission: false,
            isPrivate: true
        )
        
        // Add host as member
        _ = newGroup.addMember(user)
        
        // Save to context
        context.insert(newGroup)
        try? context.save()
        
        // Store reference and show share sheet
        createdGroup = newGroup
        showShareSheet = true
        
        // Dismiss after sharing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}

// MARK: - Share Invite View (using system share sheet)

struct ShareInviteView: UIViewControllerRepresentable {
    let group: LaterGroup
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let inviteMessage = """
        Join my Later circle: "\(group.name)"
        
        Invite Code: \(group.inviteCode)
        
        Download Later app and use this code to join!
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [inviteMessage],
            applicationActivities: nil
        )
        
        return activityVC
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Join Circle View

struct JoinCircleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]
    
    @State private var inviteCode = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Icon
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Color(red: 0, green: 1, blue: 0.255))
                    
                    // Input
                    VStack(spacing: 16) {
                        Text("JOIN A CIRCLE")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .tracking(2)
                        
                        TextField("", text: $inviteCode, prompt: Text("Invite code...").foregroundColor(.white.opacity(0.4)))
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(red: 0, green: 1, blue: 0.255))
                            .multilineTextAlignment(.center)
                            .textCase(.uppercase)
                            .tracking(4)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color(red: 0, green: 1, blue: 0.255).opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.horizontal, 32)
                    
                    if showError {
                        Text(errorMessage)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                    
                    // Join button
                    Button {
                        joinCircle()
                    } label: {
                        Text("Join Circle")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(red: 0, green: 1, blue: 0.255))
                            )
                    }
                    .disabled(inviteCode.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(inviteCode.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Join Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
    
    private func joinCircle() {
        guard let user = currentUser else { return }
        
        let code = inviteCode.trimmingCharacters(in: .whitespaces).uppercased()
        
        // Find group by invite code
        guard let group = groups.first(where: { $0.inviteCode == code }) else {
            showError = true
            errorMessage = "Invalid invite code"
            return
        }
        
        // Check if already member
        if group.isMember(userID: user.id) {
            showError = true
            errorMessage = "You're already a member"
            return
        }
        
        // Add member
        _ = group.addMember(user)
        try? context.save()
        
        dismiss()
    }
}

// MARK: - My QR Code View (ImprovedConnectionView)

private struct ImprovedConnectionMyQRCodeView: View {
    let user: UserProfile
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // QR Code placeholder (in real app, generate actual QR)
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 280, height: 280)
                        
                        Image(systemName: "qrcode")
                            .font(.system(size: 200))
                            .foregroundStyle(.black)
                    }
                    .shadow(color: Color(red: 0, green: 1, blue: 0.255).opacity(0.3), radius: 40, x: 0, y: 0)
                    
                    // User info
                    VStack(spacing: 12) {
                        Text(user.username)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        
                        Text("INVITE CODE: \(user.inviteCode)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 0, green: 1, blue: 0.255))
                            .tracking(2)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("My QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color(red: 0, green: 1, blue: 0.255))
                    }
                }
            }
        }
    }
}

// MARK: - QR Scanner View (ImprovedConnectionView)

private struct ImprovedConnectionQRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    Text("QR Scanner")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    
                    Text("QR scanning implementation goes here")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ImprovedConnectionView()
        .modelContainer(for: [UserProfile.self, LaterGroup.self], inMemory: true)
}
