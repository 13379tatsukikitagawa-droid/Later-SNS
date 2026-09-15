import SwiftUI

// MARK: - 通知画面
struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notificationManager = NotificationManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                if notificationManager.notifications.isEmpty {
                    emptyStateView
                } else {
                    notificationsList
                }
            }
            .navigationTitle("通知")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            notificationManager.markAllAsRead()
                        } label: {
                            Label("すべて既読にする", systemImage: "checkmark.circle")
                        }
                        
                        Button(role: .destructive) {
                            notificationManager.notifications.removeAll()
                        } label: {
                            Label("すべて削除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("通知はありません")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            
            Text("新しい通知が届くとここに表示されます")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var notificationsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(notificationManager.notifications, id: \.id) { notification in
                    NotificationRow(notification: notification) {
                        notificationManager.markAsRead(notification)
                    } onDelete: {
                        withAnimation {
                            notificationManager.deleteNotification(notification)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - 通知行
struct NotificationRow: View {
    let notification: UserNotification
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // アイコン
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(iconColor)
                }
                
                // コンテンツ
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(notification.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        if !notification.isRead {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Text(notification.message)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                    
                    Text(timeAgoString(from: notification.timestamp))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(notification.isRead ? Color.white.opacity(0.04) : Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        notification.isRead ? Color.white.opacity(0.05) : Color.blue.opacity(0.3),
                        lineWidth: notification.isRead ? 1 : 2
                    )
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onTap()
            } label: {
                Label(notification.isRead ? "未読にする" : "既読にする", systemImage: "envelope")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }
    
    private var iconName: String {
        switch notification.type {
        case .follow: return "person.fill.badge.plus"
        case .like: return "heart.fill"
        case .comment: return "bubble.left.fill"
        case .mention: return "at"
        case .system: return "bell.fill"
        }
    }
    
    private var iconColor: Color {
        switch notification.type {
        case .follow: return .blue
        case .like: return .red
        case .comment: return .green
        case .mention: return .orange
        case .system: return .purple
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "たった今"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)時間前"
        } else {
            let days = Int(interval / 86400)
            return "\(days)日前"
        }
    }
}
