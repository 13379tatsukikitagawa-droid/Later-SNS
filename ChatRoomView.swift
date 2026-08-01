import SwiftUI
import SwiftData

/// 1対1チャット画面
struct ChatRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var allPhotos: [LaterPhoto]
    
    let otherUser: UserProfile
    let chatRoom: ChatRoom
    
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @State private var showingPhotoSelector = false
    @State private var isLoading = false
    @State private var scrollProxy: ScrollViewProxy?
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    private var myGalleryPhotos: [LaterPhoto] {
        guard let user = currentUser else { return [] }
        return allPhotos.filter { $0.owner?.id == user.id && $0.isUnlocked }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                isFromCurrentUser: message.senderID == currentUser?.id,
                                onReaction: {
                                    toggleReaction(for: message)
                                }
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .background(Color.black)
                .onAppear {
                    scrollProxy = proxy
                    scrollToBottom()
                }
                .onChange(of: messages.count) { _, _ in
                    scrollToBottom()
                }
            }
            
            // Input Field
            messageInputField
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            loadMessages()
            markMessagesAsRead()
        }
        .sheet(isPresented: $showingPhotoSelector) {
            PhotoSelectorView(photos: myGalleryPhotos) { selectedPhoto in
                sendPhoto(selectedPhoto)
            }
        }
    }
    
    // MARK: - Header
    
    private var chatHeader: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            
            // Profile image
            Circle()
                .fill(Color.brandGreen.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(otherUser.name.prefix(1))
                        .font(.headline)
                        .foregroundStyle(.brandGreen)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(otherUser.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("@\(otherUser.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.black)
    }
    
    // MARK: - Input Field
    
    private var messageInputField: some View {
        HStack(spacing: 12) {
            // Photo button
            Button(action: { showingPhotoSelector = true }) {
                Image(systemName: "photo.fill")
                    .font(.title3)
                    .foregroundStyle(.brandGreen)
            }
            
            // Text field
            TextField("メッセージを入力...", text: $messageText)
                .font(.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                )
            
            // Send button
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(messageText.isEmpty ? .gray : .brandGreen)
            }
            .disabled(messageText.isEmpty)
        }
        .padding()
        .background(Color.black)
    }
    
    // MARK: - Functions
    
    private func loadMessages() {
        // SwiftDataから該当チャットルームのメッセージを読み込み
        let roomID = chatRoom.id
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { message in
                message.chatRoomID == roomID
            },
            sortBy: [SortDescriptor(\ChatMessage.timestamp)]
        )
        
        do {
            messages = try modelContext.fetch(descriptor)
        } catch {
            print("Error loading messages: \(error)")
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let user = currentUser else { return }
        
        let message = ChatMessage(
            chatRoomID: chatRoom.id,
            senderID: user.id,
            senderName: user.name,
            content: messageText,
            messageType: .text
        )
        
        modelContext.insert(message)
        
        // Update chat room
        chatRoom.lastMessage = messageText
        chatRoom.lastMessageTimestamp = Date()
        
        do {
            try modelContext.save()
            messages.append(message)
            messageText = ""
            
            HapticsManager.tick()
            
            // TODO: Send push notification to other user via Firebase
        } catch {
            print("Error sending message: \(error)")
            HapticsManager.errorFeedback()
        }
    }
    
    private func sendPhoto(_ photo: LaterPhoto) {
        guard let user = currentUser else { return }
        
        let message = ChatMessage(
            chatRoomID: chatRoom.id,
            senderID: user.id,
            senderName: user.name,
            content: "[写真]",
            messageType: .photo,
            photoID: photo.id
        )
        
        modelContext.insert(message)
        
        chatRoom.lastMessage = "[写真]"
        chatRoom.lastMessageTimestamp = Date()
        
        do {
            try modelContext.save()
            messages.append(message)
            
            HapticsManager.shutterClick()
            
            // TODO: Send push notification
        } catch {
            print("Error sending photo: \(error)")
            HapticsManager.errorFeedback()
        }
    }
    
    private func toggleReaction(for message: ChatMessage) {
        message.hasReaction.toggle()
        
        do {
            try modelContext.save()
            HapticsManager.swipeFeedback()
            
            // リストを再読み込み
            loadMessages()
        } catch {
            print("Error toggling reaction: \(error)")
        }
    }
    
    private func markMessagesAsRead() {
        guard let user = currentUser else { return }
        
        for message in messages where message.senderID != user.id && !message.isRead {
            message.isRead = true
        }
        
        chatRoom.unreadCount = 0
        
        try? modelContext.save()
    }
    
    private func scrollToBottom() {
        guard let lastMessage = messages.last else { return }
        withAnimation {
            scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    let onReaction: () -> Void
    
    @Query private var allPhotos: [LaterPhoto]
    
    private var photo: LaterPhoto? {
        guard let photoID = message.photoID else { return nil }
        return allPhotos.first(where: { $0.id == photoID })
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Message content
                if message.messageType == .photo, let photo = photo {
                    // Photo message
                    if let uiImage = UIImage(data: photo.imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                } else {
                    // Text message
                    Text(message.content)
                        .font(.body)
                        .foregroundStyle(isFromCurrentUser ? .white : .brandGreen)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(isFromCurrentUser ? Color.brandGreen.opacity(0.8) : Color.white.opacity(0.1))
                        )
                }
                
                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
            }
            .onTapGesture {
                if !isFromCurrentUser {
                    onReaction()
                }
            }
            .overlay(alignment: isFromCurrentUser ? .bottomLeading : .bottomTrailing) {
                if message.hasReaction {
                    // Shutter Reaction
                    Image(systemName: "camera.aperture")
                        .font(.caption)
                        .foregroundStyle(.brandGreen)
                        .padding(4)
                        .background(
                            Circle()
                                .fill(Color.black)
                                .shadow(color: .brandGreen.opacity(0.5), radius: 4)
                        )
                        .offset(x: isFromCurrentUser ? -8 : 8, y: 8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: message.hasReaction)
    }
}

// MARK: - Photo Selector

struct PhotoSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    
    let photos: [LaterPhoto]
    let onSelect: (LaterPhoto) -> Void
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(photos) { photo in
                            if let uiImage = UIImage(data: photo.imageData) {
                                Button(action: {
                                    onSelect(photo)
                                    dismiss()
                                }) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipped()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("写真を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundStyle(.brandGreen)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: UserProfile.self, ChatMessage.self, ChatRoom.self, LaterPhoto.self,
        configurations: config
    )
    
    let user1 = UserProfile(name: "Alice", username: "alice")
    let user2 = UserProfile(name: "Bob", username: "bob")
    let chatRoom = ChatRoom(
        participant1ID: user1.id,
        participant1Name: user1.name,
        participant2ID: user2.id,
        participant2Name: user2.name
    )
    
    ChatRoomView(otherUser: user2, chatRoom: chatRoom)
        .modelContainer(container)
}
