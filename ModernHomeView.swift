import SwiftUI

import SwiftUI

// MARK: - Modern Home View (メイン画面)
/// 写真の「現像・閲覧」を主役にしたモダンなホーム画面

struct ModernHomeView: View {
    @State private var revealManager = GlobalSecretRevealManager.shared
    @State private var selectedPhotoIndex = 0
    @State private var showingCalendar = false
    @State private var heartbeatTimer: Timer?
    
    // モックデータ（実際のアプリではデータソースから取得）
    @State private var todayPhotos: [PhotoItem] = []
    
    var body: some View {
        ZStack {
            // 背景: 液体が揺れるアニメーション
            LiquidBackgroundView()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ヘッダー
                headerSection
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // メインコンテンツ: 写真カードスワイプUI
                if revealManager.canViewFeed() {
                    photoCardsSection
                } else {
                    // 未解禁時の秘匿オーバーレイ
                    secretWaitingView
                }
                
                Spacer(minLength: 100)
            }
        }
        .onAppear {
            loadTodayPhotos()
            checkHeartbeatTrigger()
        }
        .onChange(of: revealManager.isGloballyRevealed) { _, newValue in
            if newValue {
                loadTodayPhotos()
            }
        }
        .sheet(isPresented: $showingCalendar) {
            ModernCalendarView()
        }
        .monitorGlobalRevealStatus()
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingMessage)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
            
            // カレンダーボタン
            Button {
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
    
    private var statusMessage: String {
        if revealManager.isGloballyRevealed {
            return "解禁中 · \(todayPhotos.count)枚の写真"
        } else {
            return "次の解禁をお待ちください..."
        }
    }
    
    // MARK: - Photo Cards Section
    
    private var photoCardsSection: some View {
        TabView(selection: $selectedPhotoIndex) {
            ForEach(Array(todayPhotos.enumerated()), id: \.offset) { index, photo in
                ModernPhotoCardView(photo: photo)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            // カスタムページインジケーター
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
                    .fill(index == selectedPhotoIndex ? .white : .white.opacity(0.3))
                    .frame(width: index == selectedPhotoIndex ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: selectedPhotoIndex)
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
            
            // 秘密のアイコン
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
                        .scaleEffect(1 + Double(index) * 0.3)
                        .opacity(0.6 - Double(index) * 0.2)
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
            
            VStack(spacing: 12) {
                Text("次の解禁をお楽しみに")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("全ユーザー共通のタイミングで\n写真が解禁されます")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func loadTodayPhotos() {
        // 実際のアプリではデータソースから取得
        // ここではモックデータを生成
        todayPhotos = generateMockPhotos()
    }
    
    private func generateMockPhotos() -> [PhotoItem] {
        let now = Date()
        return [
            PhotoItem(
                id: UUID(),
                imageData: createGradientImage(colors: [.blue, .purple]),
                capturedAt: now.addingTimeInterval(-7200),
                userName: "Alice",
                isRevealed: revealManager.isGloballyRevealed
            ),
            PhotoItem(
                id: UUID(),
                imageData: createGradientImage(colors: [.orange, .pink]),
                capturedAt: now.addingTimeInterval(-3600),
                userName: "Bob",
                isRevealed: revealManager.isGloballyRevealed
            ),
            PhotoItem(
                id: UUID(),
                imageData: createGradientImage(colors: [.green, .cyan]),
                capturedAt: now.addingTimeInterval(-1800),
                userName: "Charlie",
                isRevealed: revealManager.isGloballyRevealed
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
    
    private func checkHeartbeatTrigger() {
        // 解禁1時間前にハートビート開始
        // ここでは簡略化（実際には解禁時刻を確認）
        // startHeartbeatHaptics()
    }
}

// MARK: - Photo Item Model

fileprivate struct PhotoItem: Identifiable {
    let id: UUID
    let imageData: Data
    let capturedAt: Date
    let userName: String
    var isRevealed: Bool
}

// MARK: - Modern Photo Card View
// ModernHomeView専用のPhotoCardView（fileprivateで外部との競合を回避）

fileprivate struct ModernPhotoCardView: View {
    let photo: PhotoItem
    @State private var revealProgress: Double = 0
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景カード
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                
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
                        .modifier(
                            DevelopingEffectModifier(
                                isRevealed: photo.isRevealed,
                                progress: revealProgress
                            )
                        )
                }
                
                // ユーザー情報オーバーレイ
                if photo.isRevealed {
                    userInfoOverlay
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .onAppear {
            if photo.isRevealed {
                animateReveal()
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
    
    private func animateReveal() {
        withAnimation(.easeOut(duration: 2.0)) {
            revealProgress = 1.0
        }
    }
}

// MARK: - Developing Effect Modifier

fileprivate struct DevelopingEffectModifier: ViewModifier {
    let isRevealed: Bool
    let progress: Double
    
    func body(content: Content) -> some View {
        content
            .blur(radius: isRevealed ? 0 : (1.0 - progress) * 30)
            .grayscale(isRevealed ? 0 : (1.0 - progress))
            .overlay {
                if !isRevealed {
                    developingOverlay
                }
            }
    }
    
    private var developingOverlay: some View {
        ZStack {
            // 白いオーバーレイ
            Color.white.opacity((1.0 - progress) * 0.5)
            
            // 現像中アイコン
            if progress < 0.5 {
                VStack(spacing: 16) {
                    Image(systemName: "timer")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse, options: .repeating)
                    
                    Text("現像中...")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }
                .opacity((0.5 - progress) / 0.5)
            }
        }
    }
}

// MARK: - Liquid Background View
// ⚠️ LiquidBackgroundView.swiftで定義されているため、ここでは削除
// 外部ファイルのLiquidBackgroundViewを使用

// MARK: - Preview

#Preview("Modern Home View") {
    ModernHomeView()
}
