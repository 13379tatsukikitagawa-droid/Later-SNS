import SwiftUI
import SwiftUI

// MARK: - Missing Components
/// このファイルには、他のファイルで参照されているが定義が見つからないコンポーネントを収めます

// MARK: - Enhanced Photo Item

struct EnhancedPhotoItem: Identifiable {
    let id: UUID
    let imageData: Data
    let capturedAt: Date
    let userName: String
    var revealProgress: Double
}

// MARK: - Photo Item (Simpler version for calendar, etc.)
// ⚠️ 他のファイルにPhotoItemの定義がある場合は、このセクションをコメントアウトしてください

// PhotoItemは実際のファイルに定義があるはずなので、無効化
/*
struct PhotoItem: Identifiable {
    let id: UUID
    let imageData: Data?
    let capturedAt: Date
    let userName: String?
    
    init(id: UUID = UUID(), imageData: Data? = nil, capturedAt: Date = Date(), userName: String? = nil) {
        self.id = id
        self.imageData = imageData
        self.capturedAt = capturedAt
        self.userName = userName
    }
}
*/

// MARK: - Enhanced Photo Card View

struct EnhancedPhotoCardView: View {
    let photo: EnhancedPhotoItem
    let index: Int
    let currentIndex: Int
    let offset: CGFloat
    let totalItems: Int
    
    private var scale: CGFloat {
        let distance = abs(currentIndex - index)
        return 1.0 - CGFloat(distance) * 0.1
    }
    
    private var opacity: Double {
        let distance = abs(currentIndex - index)
        return distance == 0 ? 1.0 : 0.5
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // ユーザー情報
            HStack {
                Circle()
                    .fill(.blue)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(photo.userName.prefix(1)))
                            .font(.headline)
                            .foregroundStyle(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(photo.userName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(timeAgoText(from: photo.capturedAt))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            // 写真
            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 500)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .developingProgress(photo.revealProgress)
            }
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .offset(x: index == currentIndex ? offset : 0)
    }
    
    private func timeAgoText(from date: Date) -> String {
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

// MARK: - Liquid Background View
// ⚠️ 他のファイルにLiquidBackgroundViewの定義がある場合は、このセクションをコメントアウトしてください

// LiquidBackgroundViewは実際のファイルに定義があるはずなので、無効化
/*
struct LiquidBackgroundView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let angle = CGFloat(now.truncatingRemainder(dividingBy: 10)) / 10 * 2 * .pi
                
                drawLiquidBackground(context: context, size: size, phase: angle)
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.05, blue: 0.2),
                    Color(red: 0.05, green: 0.05, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    private func drawLiquidBackground(context: GraphicsContext, size: CGSize, phase: CGFloat) {
        let numBlobs = 3
        
        for i in 0..<numBlobs {
            let progress = CGFloat(i) / CGFloat(numBlobs)
            let x = size.width * (0.3 + 0.4 * sin(phase + progress * .pi * 2))
            let y = size.height * (0.3 + 0.4 * cos(phase * 0.7 + progress * .pi * 2))
            let radius = min(size.width, size.height) * (0.3 + 0.2 * sin(phase * 1.3 + progress * .pi))
            
            let center = CGPoint(x: x, y: y)
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            
            let colors: [Color] = [.blue, .purple, .pink]
            let color = colors[i % colors.count]
            
            context.fill(
                Circle().path(in: rect),
                with: .color(color.opacity(0.15))
            )
        }
    }
}
*/
// #endif - コメントアウト済み

// MARK: - Pulsing Secret Icon

struct PulsingSecretIcon: View {
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .opacity(isPulsing ? 0.0 : 1.0)
            
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.5), .purple.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
            
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: false)
            ) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Global Reveal Notification Handler (Placeholder)
// ⚠️ 他のファイルに定義がある場合は、このセクションをコメントアウトしてください

// 実際のファイルに定義があるはずなので、無効化
/*
class GlobalRevealNotificationHandler {
    static let shared = GlobalRevealNotificationHandler()
    
    private init() {
        // 通知の設定を行う
    }
}

// MARK: - Global Reveal Background Sync Task (Placeholder)

class GlobalRevealBackgroundSyncTask {
    static let shared = GlobalRevealBackgroundSyncTask()
    
    private init() {}
    
    func registerBackgroundTask() {
        // バックグラウンドタスクの登録
    }
    
    func scheduleNextBackgroundSync() {
        // 次回の同期をスケジュール
    }
}
*/
// #endif - コメントアウト済み

// MARK: - Global Reveal Status Monitor View Modifier
// ⚠️ 他のファイルに定義がある場合は、このセクションをコメントアウトしてください

// 実際のファイルに定義があるはずなので、無効化
/*
struct GlobalRevealStatusMonitorModifier: ViewModifier {
    @State private var revealManager = GlobalSecretRevealManager.shared
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                // 必要に応じて解禁状態をチェック
            }
    }
}

extension View {
    func monitorGlobalRevealStatus() -> some View {
        modifier(GlobalRevealStatusMonitorModifier())
    }
}
*/
// #endif - コメントアウト済み

// MARK: - Placeholder Views (各ファイルで定義されているべきビューのプレースホルダー)

// これらのビューは実際のファイルが存在する場合は削除してください
// ⚠️ 注意: 実際のビューファイルが存在する場合、以下をコメントアウトしてください

#if DEBUG
/*
struct TodayView: View {
    var body: some View {
        Text("TodayView - Placeholder")
            .font(.title)
    }
}

struct ConnectionsView: View {
    var body: some View {
        Text("ConnectionsView - Placeholder")
            .font(.title)
    }
}

struct GalleryView: View {
    var body: some View {
        Text("GalleryView - Placeholder")
            .font(.title)
    }
}

struct ProfileView: View {
    var body: some View {
        Text("ProfileView - Placeholder")
            .font(.title)
    }
}

struct OnboardingView: View {
    @AppStorage("isSetupCompleted") private var isSetupCompleted: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Later")
                .font(.largeTitle.bold())
            
            Button("Complete Setup") {
                isSetupCompleted = true
            }
            .padding()
            .background(.blue)
            .foregroundStyle(.white)
            .cornerRadius(10)
        }
    }
}

struct ModernCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            AchievementCalendarView()
                .navigationTitle("カレンダー")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("閉じる") {
                            dismiss()
                        }
                    }
                }
        }
    }
}
*/

// SwiftData モデルのプレースホルダー
// 実際のモデルが定義されている場合は削除してください
// ⚠️ 注意: 実際のモデルファイルが存在する場合、以下をコメントアウトしてください

/*
import SwiftData

@Model
class LaterPhoto {
    var id: UUID
    var createdAt: Date
    
    init(id: UUID = UUID(), createdAt: Date = Date()) {
        self.id = id
        self.createdAt = createdAt
    }
}

@Model
class LaterGroup {
    var id: UUID
    var name: String
    
    init(id: UUID = UUID(), name: String = "") {
        self.id = id
        self.name = name
    }
}

@Model
class UserProfile {
    var id: UUID
    var username: String
    
    init(id: UUID = UUID(), username: String = "") {
        self.id = id
        self.username = username
    }
}
*/
#endif

// MARK: - Preview Helpers

// #Preview("Liquid Background") {
//     LiquidBackgroundView()
// }

#Preview("Pulsing Secret Icon") {
    ZStack {
        Color.black.ignoresSafeArea()
        PulsingSecretIcon()
    }
}
