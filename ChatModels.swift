import Foundation
import SwiftData

/// チャットメッセージモデル
@Model
final class ChatMessage {
    var id: UUID
    var chatRoomID: String
    var senderID: UUID
    var senderName: String
    var content: String
    var timestamp: Date
    var isRead: Bool
    var messageType: MessageType
    var photoID: UUID?  // Gallery内の写真ID（写真送信時）
    var hasReaction: Bool  // Shutter Reactionがついているか
    
    enum MessageType: Codable {
        case text
        case photo
        case system
    }
    
    init(
        chatRoomID: String,
        senderID: UUID,
        senderName: String,
        content: String,
        messageType: MessageType = .text,
        photoID: UUID? = nil
    ) {
        self.id = UUID()
        self.chatRoomID = chatRoomID
        self.senderID = senderID
        self.senderName = senderName
        self.content = content
        self.timestamp = Date()
        self.isRead = false
        self.messageType = messageType
        self.photoID = photoID
        self.hasReaction = false
    }
}

/// チャットルームモデル
@Model
final class ChatRoom {
    var id: String
    var participantIDs: [UUID]
    var participantNames: [String]
    var lastMessage: String
    var lastMessageTimestamp: Date
    var unreadCount: Int
    var createdAt: Date
    
    init(
        participant1ID: UUID,
        participant1Name: String,
        participant2ID: UUID,
        participant2Name: String
    ) {
        // IDは2人のユーザーIDをソートして結合（一意性を保証）
        let sortedIDs = [participant1ID.uuidString, participant2ID.uuidString].sorted()
        self.id = sortedIDs.joined(separator: "_")
        
        self.participantIDs = [participant1ID, participant2ID]
        self.participantNames = [participant1Name, participant2Name]
        self.lastMessage = ""
        self.lastMessageTimestamp = Date()
        self.unreadCount = 0
        self.createdAt = Date()
    }
    
    /// 相手のユーザーIDを取得
    func otherParticipantID(currentUserID: UUID) -> UUID? {
        participantIDs.first(where: { $0 != currentUserID })
    }
    
    /// 相手のユーザー名を取得
    func otherParticipantName(currentUserID: UUID) -> String? {
        if let index = participantIDs.firstIndex(of: currentUserID) {
            let otherIndex = (index + 1) % participantNames.count
            return participantNames[otherIndex]
        }
        return nil
    }
}
