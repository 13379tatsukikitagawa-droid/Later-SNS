import SwiftUI
import SwiftData

/// 他のユーザーのプロフィール詳細画面
struct UserDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var chatRooms: [ChatRoom]
    
    let user: UserProfile
    
    @State private var showingChat = false
    @State private var chatRoom: ChatRoom?
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    private var isFollowing: Bool {
        guard let current = currentUser else { return false }
        return current.following.contains(where: { $0.id == user.id })
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        // Profile image
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.brandGreen, Color.brandGreen.opacity(0.6)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .overlay(
                                Text(user.name.prefix(1))
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                        
                        VStack(spacing: 4) {
                            Text(user.name)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            
                            Text("@\(user.username)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        if !user.bio.isEmpty {
                            Text(user.bio)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top, 40)
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        // Follow button
                        Button(action: toggleFollow) {
                            Label(
                                isFollowing ? "Following" : "Follow",
                                systemImage: isFollowing ? "checkmark" : "plus"
                            )
                            .font(.headline)
                            .foregroundStyle(isFollowing ? Color.brandGreen : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isFollowing ? Color.brandGreen.opacity(0.2) : Color.brandGreen)
                            )
                        }
                        
                        // Message button
                        Button(action: openChat) {
                            Label("Message", systemImage: "message.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.brandGreen, lineWidth: 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.brandGreen.opacity(0.1))
                                        )
                                )
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.vertical, 20)
                    
                    // Stats
                    HStack(spacing: 40) {
                        StatView(
                            value: user.following.count,
                            label: "Following"
                        )
                        
                        StatView(
                            value: user.followers.count,
                            label: "Followers"
                        )
                        
                        StatView(
                            value: 0, // TODO: Count user's photos
                            label: "Photos"
                        )
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationDestination(isPresented: $showingChat) {
                if let room = chatRoom {
                    ChatRoomView(otherUser: user, chatRoom: room)
                }
            }
        }
    }
    
    // MARK: - Functions
    
    private func toggleFollow() {
        guard let current = currentUser else { return }
        
        if isFollowing {
            // Unfollow
            current.following.removeAll(where: { $0.id == user.id })
            user.followers.removeAll(where: { $0.id == current.id })
        } else {
            // Follow
            current.following.append(user)
            user.followers.append(current)
        }
        
        try? modelContext.save()
        HapticsManager.swipeFeedback()
    }
    
    private func openChat() {
        guard let current = currentUser else { return }
        
        // Check if chat room already exists
        let existingRoom = chatRooms.first { room in
            room.participantIDs.contains(current.id) && room.participantIDs.contains(user.id)
        }
        
        if let room = existingRoom {
            chatRoom = room
        } else {
            // Create new chat room
            let newRoom = ChatRoom(
                participant1ID: current.id,
                participant1Name: current.name,
                participant2ID: user.id,
                participant2Name: user.name
            )
            modelContext.insert(newRoom)
            
            do {
                try modelContext.save()
                chatRoom = newRoom
            } catch {
                print("Error creating chat room: \(error)")
                HapticsManager.errorFeedback()
                return
            }
        }
        
        showingChat = true
        HapticsManager.swipeFeedback()
    }
}

// MARK: - Stat View

struct StatView: View {
    let value: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: UserProfile.self, ChatRoom.self,
        configurations: config
    )
    
    let user = UserProfile(name: "Alice", username: "alice")
    user.bio = "Photography enthusiast 📸"
    
    return UserDetailView(user: user)
        .modelContainer(container)
}
