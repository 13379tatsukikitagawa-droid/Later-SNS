import SwiftUI

// MARK: - Modern Photo App
/// 現像体験を中心としたモダンな写真アプリのメインエントリーポイント

@main
struct ModernPhotoApp: App {
    init() {
        setupApp()
    }
    
    var body: some Scene {
        WindowGroup {
            ModernMainContainerView()
                .preferredColorScheme(.dark)
                .monitorGlobalRevealStatus()
                .monitorHeartbeat()
        }
    }
    
    private func setupApp() {
        // 通知の設定
        _ = GlobalRevealNotificationHandler.shared
        
        // バックグラウンド同期
        GlobalRevealBackgroundSyncTask.shared.registerBackgroundTask()
        GlobalRevealBackgroundSyncTask.shared.scheduleNextBackgroundSync()
        
        // ハプティクスの準備
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
    }
}

// MARK: - Enhanced Home View with All Features
/// すべての機能を統合した拡張版ホームビュー

struct EnhancedModernHomeView: View {
    @State private var revealManager = GlobalSecretRevealManager.shared
    @State private var swipeHandler: SwipeGestureHandler
    @State private var showingCalendar = false
    @State private var todayPhotos: [EnhancedPhotoItem] = []
    
    init() {
        _swipeHandler = State(initialValue: SwipeGestureHandler(totalItems: 3))
    }
    
    var body: some View {
        ZStack {
            // 液体背景アニメーション
            LiquidBackgroundView()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ヘッダー
                headerSection
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // メインコンテンツ
                if revealManager.canViewFeed() {
                    enhancedPhotoCardsSection
                } else {
                    secretWaitingView
                }
                
                Spacer(minLength: 100)
            }
        }
        .sheet(isPresented: $showingCalendar) {
            ModernCalendarView()
        }
        .onAppear {
            loadEnhancedPhotos()
        }
        .onChange(of: revealManager.isGloballyRevealed) { _, isRevealed in
            if isRevealed {
                loadEnhancedPhotos()
                
                // 解禁時のハプティック
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingMessage)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                HStack(spacing: 8) {
                    if revealManager.isGloballyRevealed {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        
                        Text("解禁中")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    } else {
                        Circle()
                            .fill(.orange)
                            .frame(width: 8, height: 8)
                        
                        Text("次の解禁をお待ちください")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
            
            // カレンダーボタン
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                showingCalendar = true
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "calendar")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    private var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "おはようございます"
        case 12..<17: return "こんにちは"
        default: return "こんばんは"
        }
    }
    
    // MARK: - Enhanced Photo Cards
    
    private var enhancedPhotoCardsSection: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(todayPhotos.enumerated()), id: \.offset) { index, photo in
                    EnhancedPhotoCardView(
                        photo: photo,
                        index: index,
                        currentIndex: swipeHandler.currentIndex,
                        offset: swipeHandler.offset,
                        totalItems: todayPhotos.count
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                swipeHandler.handleDragChanged(value)
                            }
                            .onEnded { value in
                                swipeHandler.handleDragEnded(value)
                            }
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .overlay(alignment: .bottom) {
            if todayPhotos.count > 1 {
                customPageIndicator
                    .padding(.bottom, 120)
            }
        }
    }
    
    private var customPageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<todayPhotos.count, id: \.self) { index in
                Capsule()
                    .fill(index == swipeHandler.currentIndex ? .white : .white.opacity(0.3))
                    .frame(width: index == swipeHandler.currentIndex ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: swipeHandler.currentIndex)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Secret Waiting View
    
    private var secretWaitingView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            PulsingSecretIcon()
            
            VStack(spacing: 12) {
                Text("次の解禁をお楽しみに")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("全ユーザー共通のタイミングで\n写真が解禁されます")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                // 秘密のメッセージ
                Text("※ 解禁時刻は秘密です")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 8)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func loadEnhancedPhotos() {
        swipeHandler = SwipeGestureHandler(totalItems: 3)
        
        let now = Date()
        todayPhotos = [
            EnhancedPhotoItem(
                id: UUID(),
                imageData: createGradientImage(colors: [.blue, .purple]),
                capturedAt: now.addingTimeInterval(-7200),
                userName: "Alice",
                revealProgress: revealManager.isGloballyRevealed ? 1.0 : 0.0
            ),
            EnhancedPhotoItem(
                id: UUID(),
                imageData: createGradientImage(colors: [.orange, .pink]),
                capturedAt: now.addingTimeInterval(-3600),
                userName: "Bob",
                revealProgress: revealManager.isGloballyRevealed ? 1.0 : 0.0
            ),
            EnhancedPhotoItem(
                id: UUID(),
                imageData: createGradientImage(colors: [.green, .cyan]),
                capturedAt: now.addingTimeInterval(-1800),
                userName: "Charlie",
                revealProgress: revealManager.isGloballyRevealed ? 1.0 : 0.0
            )
        ]
    }
    
    private func createGradientImage(colors: [Color]) -> Data {
        let size = CGSize(width: 400, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cgColors = colors.map { UIColor($0).cgColor }
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: cgColors as CFArray,
                locations: nil
            )!
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }
        return image.pngData() ?? Data()
    }
}

// MARK: - Enhanced Photo Item

struct EnhancedPhotoItem: Identifiable {
    let id: UUID
    let imageData: Data
    let capturedAt: Date
    let userName: String
    var revealProgress: Double
}

// MARK: - Enhanced Photo Card View

struct EnhancedPhotoCardView: View {
    let photo: EnhancedPhotoItem
    let index: Int
    let currentIndex: Int
    let offset: CGFloat
    let totalItems: Int
    
    @State private var animatedProgress: Double = 0
    
    private var isVisible: Bool {
        abs(index - currentIndex) <= 1
    }
    
    private var cardOffset: CGFloat {
        let baseOffset = CGFloat(index - currentIndex) * UIScreen.main.bounds.width
        return baseOffset + (index == currentIndex ? offset : 0)
    }
    
    private var scale: CGFloat {
        if index == currentIndex {
            return 1.0 - abs(offset) / UIScreen.main.bounds.width * 0.1
        } else {
            return 0.9
        }
    }
    
    private var rotation: Double {
        if index == currentIndex {
            return Double(offset) * 0.05
        } else {
            return 0
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景カード
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.4), radius: 25, y: 12)
                
                // 写真
                if let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(
                            width: geometry.size.width - 40,
                            height: geometry.size.height - 100
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .developingProgress(animatedProgress)
                }
                
                // ユーザー情報
                if animatedProgress > 0.7 {
                    userInfoOverlay
                        .opacity((animatedProgress - 0.7) / 0.3)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .offset(x: cardOffset)
        .scaleEffect(scale)
        .rotation3DEffect(
            .degrees(rotation),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .opacity(isVisible ? 1.0 : 0)
        .onAppear {
            if photo.revealProgress > 0 {
                withAnimation(.easeOut(duration: 2.5).delay(Double(index) * 0.3)) {
                    animatedProgress = photo.revealProgress
                }
            }
        }
        .onChange(of: photo.revealProgress) { _, newProgress in
            if newProgress > 0 {
                withAnimation(.easeOut(duration: 2.5)) {
                    animatedProgress = newProgress
                }
            }
        }
    }
    
    private var userInfoOverlay: some View {
        VStack {
            Spacer()
            
            HStack {
                Circle()
                    .fill(.blue.opacity(0.3))
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
                    
                    Text(photo.capturedAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .padding()
        }
    }
}

// MARK: - Pulsing Secret Icon

struct PulsingSecretIcon: View {
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6
    
    var body: some View {
        ZStack {
            // 外側のパルスリング
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseScale + Double(index) * 0.2)
                    .opacity(pulseOpacity - Double(index) * 0.2)
            }
            
            // 内側のアイコン
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 100, height: 100)
            
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.pulse, options: .repeating)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.4
                pulseOpacity = 0.0
            }
        }
    }
}

// MARK: - Preview

#Preview("Enhanced Home View") {
    EnhancedModernHomeView()
}

#Preview("Modern Photo App") {
    ModernMainContainerView()
        .preferredColorScheme(.dark)
}
