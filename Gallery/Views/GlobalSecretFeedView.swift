import SwiftUI

// MARK: - Global Secret Feed View
/// グローバル解禁システムを統合したフィードビュー

struct GlobalSecretFeedView: View {
    @State private var manager = GlobalSecretRevealManager.shared
    @State private var showingDemo = false
    
    // サンプルデータ（実際のアプリではデータソースから取得）
    @State private var mockPhotos: [MockPhoto] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if manager.canViewFeed() {
                    // 解禁中: フィードを表示
                    revealedFeedContent
                } else {
                    // ロック中: 秘匿オーバーレイを表示
                    lockedFeedOverlay
                }
            }
            .navigationTitle("フィード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingDemo = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showingDemo) {
                GlobalSecretRevealDemoView()
            }
            .onAppear {
                manager.checkGlobalRevealStatus()
                generateMockPhotos()
            }
            .monitorGlobalRevealStatus()
        }
    }
    
    // MARK: - Revealed Feed Content
    
    private var revealedFeedContent: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // ステータスバナー
                revealStatusBanner
                
                // 写真グリッド
                ForEach(mockPhotos) { photo in
                    photoCard(photo)
                }
            }
            .padding()
        }
    }
    
    private var revealStatusBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "lock.open.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("解禁中！")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("全ユーザーの写真が閲覧可能です")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Spacer()
            }
            
            // 自分の状態表示
            if !manager.hasUserCompletedGoal {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.orange)
                    
                    Text("あなたはまだ目標未達成です。自分の写真は非表示になっています。")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.orange.opacity(0.2))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.green.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.green.opacity(0.4), lineWidth: 1)
                )
        )
    }
    
    private func photoCard(_ photo: MockPhoto) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // ユーザー情報
            HStack(spacing: 12) {
                Circle()
                    .fill(photo.userColor.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(photo.userName.prefix(1))
                            .font(.headline)
                            .foregroundStyle(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(photo.userName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(photo.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
            }
            
            // 写真
            if photo.isOwnPhoto && !manager.hasUserCompletedGoal {
                // 自分の写真で未達成 → 秘匿表示
                SecretPhotoCard(
                    status: .userNotReady,
                    size: CGSize(width: 350, height: 400)
                )
            } else if manager.canViewOthersPhotos() || (photo.isOwnPhoto && manager.canViewOwnPhotos()) {
                // 閲覧可能
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [photo.userColor.opacity(0.6), photo.userColor.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 400)
                    
                    VStack {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.6))
                        
                        Text(photo.caption)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.top, 8)
                    }
                }
            } else {
                // ポリシーにより非表示
                SecretPhotoCard(
                    status: .waitingForReveal,
                    size: CGSize(width: 350, height: 400)
                )
            }
            
            // アクション
            HStack(spacing: 24) {
                Button {
                    // いいね
                } label: {
                    Image(systemName: "heart")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                
                Button {
                    // コメント
                } label: {
                    Image(systemName: "bubble.right")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.05))
        )
    }
    
    // MARK: - Locked Feed Overlay
    
    private var lockedFeedOverlay: some View {
        VStack {
            if !manager.isGloballyRevealed {
                // グローバル未解禁
                FeedSecretOverlay(status: .waitingForReveal)
            } else if !manager.hasUserCompletedGoal && manager.viewPolicy == .blockAllUntilSelfComplete {
                // ユーザー未達成でポリシーによりブロック
                FeedSecretOverlay(status: .userNotReady)
            } else {
                // その他
                FeedSecretOverlay(status: .developing)
            }
        }
    }
    
    // MARK: - Mock Data
    
    private func generateMockPhotos() {
        let userNames = ["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank"]
        let colors: [Color] = [.blue, .purple, .pink, .orange, .green, .cyan]
        let captions = [
            "Beautiful sunset 🌅",
            "Coffee time ☕️",
            "Nature walk 🌲",
            "City lights 🌃",
            "Beach day 🏖",
            "Mountain view ⛰"
        ]
        
        mockPhotos = (0..<10).map { index in
            MockPhoto(
                id: UUID(),
                userName: userNames[index % userNames.count],
                userColor: colors[index % colors.count],
                caption: captions[index % captions.count],
                timestamp: Date().addingTimeInterval(-Double(index * 3600)),
                isOwnPhoto: index == 0 // 最初の1枚を自分の写真とする
            )
        }
    }
}

// MARK: - Mock Photo Model

struct MockPhoto: Identifiable {
    let id: UUID
    let userName: String
    let userColor: Color
    let caption: String
    let timestamp: Date
    let isOwnPhoto: Bool
}

// MARK: - Compact Feed Card (リスト表示用)

struct CompactSecretPhotoCard: View {
    let status: SecretStatus
    @State private var isShimmering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // サムネイル
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
                
                Image(systemName: status.icon)
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.6))
                    .symbolEffect(.pulse, options: .repeating)
            }
            
            // 情報
            VStack(alignment: .leading, spacing: 4) {
                Text(status.message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                
                Text(status.submessage)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            }
            
            Spacer()
            
            // ロックアイコン
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Integration Example (既存のフィードに組み込む例)

/// 既存のフィードビューに組み込む例
struct IntegratedFeedExample: View {
    @State private var manager = GlobalSecretRevealManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if manager.canViewFeed() {
                    // 通常のフィード
                    Text("フィードコンテンツ")
                        .foregroundStyle(.white)
                } else {
                    // ロック画面
                    determineOverlayStatus()
                }
            }
            .monitorGlobalRevealStatus()
        }
    }
    
    @ViewBuilder
    private func determineOverlayStatus() -> some View {
        if !manager.isGloballyRevealed {
            FeedSecretOverlay(status: .waitingForReveal)
        } else if manager.viewPolicy == .blockAllUntilSelfComplete && !manager.hasUserCompletedGoal {
            FeedSecretOverlay(status: .userNotReady)
        } else {
            FeedSecretOverlay(status: .developing)
        }
    }
}

// MARK: - Notification Handler

/// プッシュ通知をハンドリングするためのヘルパー
class GlobalRevealNotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = GlobalRevealNotificationHandler()
    
    private override init() {
        super.init()
        setupNotifications()
    }
    
    func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self
        requestAuthorization()
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            #if DEBUG
            print("[Notification] Authorization granted: \(granted)")
            if let error = error {
                print("[Notification] Error: \(error)")
            }
            #endif
        }
    }
    
    // フォアグラウンドでも通知を表示
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
        
        // 解禁状態をチェック
        GlobalSecretRevealManager.shared.checkGlobalRevealStatus()
    }
    
    // 通知タップ時の処理
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // 解禁状態をチェック
        GlobalSecretRevealManager.shared.checkGlobalRevealStatus()
        
        // フィード画面へ遷移（実装は各アプリに依存）
        NotificationCenter.default.post(name: .globalRevealActivated, object: nil)
        
        completionHandler()
    }
}

extension Notification.Name {
    static let globalRevealActivated = Notification.Name("globalRevealActivated")
}

// MARK: - App Integration Example

/// アプリのルートビューでの統合例
struct GlobalSecretAppIntegrationExample: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GlobalSecretFeedView()
                .tabItem {
                    Label("フィード", systemImage: "photo.stack")
                }
                .tag(0)
            
            Text("カメラ")
                .tabItem {
                    Label("撮影", systemImage: "camera")
                }
                .tag(1)
            
            GlobalSecretRevealDemoView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
                .tag(2)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // 通知ハンドラーを初期化
            _ = GlobalRevealNotificationHandler.shared
        }
        .onReceive(NotificationCenter.default.publisher(for: .globalRevealActivated)) { _ in
            // 通知タップでフィードタブへ移動
            selectedTab = 0
        }
    }
}

// MARK: - Previews

#Preview("Global Secret Feed") {
    GlobalSecretFeedView()
}

#Preview("Compact Secret Photo Card") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            CompactSecretPhotoCard(status: .developing)
            CompactSecretPhotoCard(status: .waitingForReveal)
            CompactSecretPhotoCard(status: .userNotReady)
        }
        .padding()
    }
}

#Preview("App Integration") {
    GlobalSecretAppIntegrationExample()
}
