import Foundation
import SwiftData

// MARK: - 通知データモデル
@Model
final class UserNotification {
    var id: UUID
    var type: NotificationType
    var title: String
    var message: String
    var timestamp: Date
    var isRead: Bool
    var relatedUserID: UUID?
    
    enum NotificationType: String, Codable {
        case follow = "follow"
        case like = "like"
        case comment = "comment"
        case mention = "mention"
        case system = "system"
    }
    
    init(type: NotificationType, title: String, message: String, relatedUserID: UUID? = nil) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.message = message
        self.timestamp = Date()
        self.isRead = false
        self.relatedUserID = relatedUserID
    }
}

// MARK: - 通知マネージャー
@Observable
class NotificationManager {
    var notifications: [UserNotification] = []
    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }
    
    static let shared = NotificationManager()
    
    private init() {
        // デモ用の通知を生成
        generateDemoNotifications()
    }
    
    func addNotification(type: UserNotification.NotificationType, title: String, message: String, relatedUserID: UUID? = nil) {
        let notification = UserNotification(type: type, title: title, message: message, relatedUserID: relatedUserID)
        notifications.insert(notification, at: 0)
    }
    
    func markAsRead(_ notification: UserNotification) {
        notification.isRead = true
    }
    
    func markAllAsRead() {
        notifications.forEach { $0.isRead = true }
    }
    
    func deleteNotification(_ notification: UserNotification) {
        notifications.removeAll { $0.id == notification.id }
    }
    
    private func generateDemoNotifications() {
        // デモ用の通知
        addNotification(type: .follow, title: "新しいフォロワー", message: "Taroさんがあなたをフォローしました")
        addNotification(type: .like, title: "いいね", message: "Hanakoさんがあなたの写真にいいねしました")
        addNotification(type: .comment, title: "コメント", message: "Jiroさんがコメントしました：「素敵な写真ですね！」")
        addNotification(type: .system, title: "システム通知", message: "新機能が追加されました！テーマカラーをカスタマイズできます")
    }
}
