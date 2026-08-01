import SwiftUI
import SwiftData

/// メッセージインボックス（チャットルーム一覧）
struct MessageInboxView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \ChatRoom.lastMessageTimestamp, order: .reverse) private var chatRooms: [ChatRoom]
    
    @State private var selectedChatRoom: ChatRoom?
    @State private var selectedUser: UserProfile?
    @State private var showingChat = false
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    private var myChatRooms: [ChatRoom] {
        guard let user = currentUser else { return [] }
        return chatRooms.filter { $0.participantIDs.contains(user.id) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if myChatRooms.isEmpty {
                    // Empty state
                    emptyStateView
                } else {
                    // Chat rooms list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(myChatRooms) { room in
                                ChatRoomRow(
                                    chatRoom: room,
                                    currentUser: currentUser
                                )
                                .onTapGesture {
                                    openChatRoom(room)
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationDestination(isPresented: $showingChat) {
                if let room = selectedChatRoom, let user = selectedUser {
                    ChatRoomView(otherUser: user, chatRoom: room)
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.open")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.brandGreen, .brandGreen.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("No Messages Yet")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("フォローしているユーザーに\nメッセージを送ってみましょう")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    // MARK: - Functions
    
    private func openChatRoom(_ room: ChatRoom) {
        guard let user = currentUser,
              let otherUserID = room.otherParticipantID(currentUserID: user.id) else { return }
        
        // Find other user profile
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.id == otherUserID }
        )
        
        do {
            let users = try modelContext.fetch(descriptor)
            if let otherUser = users.first {
                selectedChatRoom = room
                selectedUser = otherUser
                showingChat = true
                
                HapticsManager.tick()
            }
        } catch {
            print("Error finding user: \(error)")
        }
    }
}

// MARK: - Chat Room Row

struct ChatRoomRow: View {
    let chatRoom: ChatRoom
    let currentUser: UserProfile?
    
    private var otherUserName: String {
        guard let user = currentUser else { return "" }
        return chatRoom.otherParticipantName(currentUserID: user.id) ?? ""
    }
    
    private var hasUnread: Bool {
        chatRoom.unreadCount > 0
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile image
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color.brandGreen.opacity(0.3))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(otherUserName.prefix(1))
                            .font(.title3.bold())
                            .foregroundStyle(.brandGreen)
                    )
                
                // Unread badge
                if hasUnread {
                    Circle()
                        .fill(Color.brandGreen)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text("\(chatRoom.unreadCount)")
                                .font(.caption2.bold())
                                .foregroundStyle(.black)
                        )
                        .offset(x: 4, y: -4)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(otherUserName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Text(chatRoom.lastMessageTimestamp, style: .relative)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)
                }
                
                Text(chatRoom.lastMessage.isEmpty ? "新しい会話を始めましょう" : chatRoom.lastMessage)
                    .font(.subheadline)
                    .foregroundStyle(hasUnread ? .brandGreen : .secondary)
                    .lineLimit(1)
            }
        }
        .padding()
        .background(
            hasUnread ? Color.brandGreen.opacity(0.05) : Color.clear
        )
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: UserProfile.self, ChatRoom.self, ChatMessage.self,
        configurations: config
    )
    
    return MessageInboxView()
        .modelContainer(container)
}
