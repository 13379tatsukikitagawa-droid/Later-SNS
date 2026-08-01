import SwiftUI
import SwiftData

// MARK: - 🎬 解禁後フィード画面（プレビュー専用デバッグモード）
/// このファイルは開発中の「写真解禁後のフィード画面」を即座に確認するためのプレビュー専用コードです。
/// 本番コードには一切影響を与えず、#Previewセクションでのみ動作します。

/// 解禁後のフィード画面（デバッグモード対応）
struct UnlockedFeedView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \LaterPhoto.captureDate, order: .reverse) private var allPhotos: [LaterPhoto]
    @Query private var profiles: [UserProfile]
    
    // デバッグモード専用の設定
    let debugMode: Bool
    let debugPhotosTaken: Int
    let debugDailyGoal: Int
    let debugUnlockTimeRemaining: TimeInterval // 残り時間（秒）
    
    // 通常モード用
    @AppStorage("photosTaken") private var photosTaken: Int = 0
    @AppStorage("dailyGoal") private var dailyGoal: Int = 3
    
    // フィード状態
    @State private var refreshID = UUID()
    @State private var selectedPhoto: LaterPhoto?
    @State private var showRatingView = false
    
    private var me: UserProfile? { profiles.first }
    
    // デバッグモードの値を使用
    private var effectivePhotosTaken: Int {
        debugMode ? debugPhotosTaken : photosTaken
    }
    
    private var effectiveDailyGoal: Int {
        debugMode ? debugDailyGoal : dailyGoal
    }
    
    // フィードに表示する写真をフィルタリング
    private var feedPhotos: [LaterPhoto] {
        guard let me else { return [] }
        
        // フォローしている人の写真のみ
        let followingIds = Set(me.following.map { $0.id })
        let followingPhotos = allPhotos.filter { photo in
            guard let owner = photo.owner else { return false }
            return followingIds.contains(owner.id) && owner.id != me.id
        }
        
        // デバッグモードの場合、全ての写真を解禁済みとして扱う
        if debugMode {
            return Array(followingPhotos.prefix(effectivePhotosTaken))
        }
        
        // 通常モード：解禁済みの写真のみ
        return followingPhotos.filter { $0.isUnlocked }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 📅 カウントダウンタイマー
                        if debugMode {
                            debugCountdownBanner
                        } else {
                            CountdownBanner()
                                .padding(.horizontal)
                        }
                        
                        // 🎯 目標達成バッジ
                        goalAchievedBanner
                        
                        // 📸 フィード投稿
                        if feedPhotos.isEmpty {
                            emptyFeedView
                        } else {
                            LazyVStack(spacing: 24) {
                                ForEach(feedPhotos) { photo in
                                    FeedPhotoCard(
                                        photo: photo,
                                        debugMode: debugMode
                                    ) {
                                        selectedPhoto = photo
                                        showRatingView = true
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Today's Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if debugMode {
                        debugBadge
                    }
                }
            }
            .sheet(isPresented: $showRatingView) {
                if let photo = selectedPhoto {
                    PhotoRatingView(
                        photoId: photo.id.uuidString,
                        raterId: me?.id.uuidString ?? "",
                        existingRating: nil
                    ) { rating in
                        print("📊 評価送信: \(rating)")
                    }
                }
            }
        }
    }
    
    // MARK: - デバッグ用カウントダウンバナー
    
    private var debugCountdownBanner: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.title3)
                    .foregroundStyle(.brandGreen)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("フィード公開中")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    
                    Text("残り時間: \(formattedDebugTime)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Spacer()
                
                // タイマー表示
                VStack(spacing: 2) {
                    Text(formattedDebugTime)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.brandGreen)
                        .monospacedDigit()
                    
                    Text("REMAINING")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.brandGreen.opacity(0.3), lineWidth: 2)
                    )
            )
            
            // プログレスバー
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.brandGreen, .brandGreen.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progressValue)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal)
    }
    
    private var formattedDebugTime: String {
        let hours = Int(debugUnlockTimeRemaining) / 3600
        let minutes = (Int(debugUnlockTimeRemaining) % 3600) / 60
        return String(format: "%d:%02d", hours, minutes)
    }
    
    private var progressValue: CGFloat {
        // 6時間 = 21600秒
        let totalSeconds: CGFloat = 21600
        let remaining = CGFloat(debugUnlockTimeRemaining)
        return max(0, min(1, remaining / totalSeconds))
    }
    
    // MARK: - 目標達成バッジ
    
    private var goalAchievedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(.brandGreen)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("目標達成！")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                
                Text("\(effectivePhotosTaken)枚の写真を撮影しました")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
            
            // 撮影枚数表示
            VStack(spacing: 2) {
                Text("\(effectivePhotosTaken)")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.brandGreen)
                    .monospacedDigit()
                
                Text("PHOTOS")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.brandGreen.opacity(0.15),
                            Color.brandGreen.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.brandGreen.opacity(0.3), lineWidth: 2)
                )
        )
        .padding(.horizontal)
    }
    
    // MARK: - 空のフィード表示
    
    private var emptyFeedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("フィードに写真がありません")
                .font(.headline)
                .foregroundStyle(.white)
            
            Text("フォローしている人の写真が\n解禁されると表示されます")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    // MARK: - デバッグバッジ
    
    private var debugBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "ladybug.fill")
                .font(.caption)
            Text("DEBUG")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.red)
        .clipShape(Capsule())
    }
}

// MARK: - フィード写真カード

struct FeedPhotoCard: View {
    let photo: LaterPhoto
    let debugMode: Bool
    let onTapRate: () -> Void
    
    @State private var isBlurred: Bool = true
    
    var body: some View {
        VStack(spacing: 12) {
            // 投稿者情報
            HStack(spacing: 12) {
                FeedProfileImageView(
                    data: photo.owner?.profileImageData,
                    size: 40
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(photo.owner?.name ?? "Unknown")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    
                    Text("@\(photo.owner?.username ?? "unknown")")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                // 解禁タイムスタンプ
                VStack(alignment: .trailing, spacing: 2) {
                    Text("UNLOCKED")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.brandGreen)
                    
                    Text(formattedUnlockTime)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            // 写真本体
            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .blur(radius: isBlurred ? 20 : 0)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isBlurred.toggle()
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if isBlurred {
                            blurIndicator
                        }
                    }
            }
            
            // アクションボタン
            HStack(spacing: 16) {
                // いいねボタン
                Button {
                    // TODO: いいね機能
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.title3)
                        Text("12")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white.opacity(0.7))
                }
                
                // 評価ボタン（カスタムスタンプ）
                Button {
                    onTapRate()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "seal.fill")
                            .font(.title3)
                        Text("評価する")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.brandGreen)
                    )
                }
                
                Spacer()
                
                // シェアボタン
                Button {
                    // TODO: シェア機能
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .onAppear {
            // デバッグモードの場合、解禁アニメーションを再生
            if debugMode {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        isBlurred = false
                    }
                }
            }
        }
    }
    
    private var blurIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "eye.slash.fill")
                .font(.caption)
            Text("タップで表示")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
                .blur(radius: 10)
        )
        .padding(12)
    }
    
    private var formattedUnlockTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: photo.unlockDate)
    }
}

// MARK: - フィード用プロフィール画像ビュー

struct FeedProfileImageView: View {
    let data: Data?
    let size: CGFloat
    
    var body: some View {
        Group {
            if let data = data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - 🎬 プレビュー（デバッグモード）

#Preview("解禁後フィード - デバッグモード") {
    // プレビュー専用のModelContainer
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: LaterPhoto.self, UserProfile.self, LaterGroup.self,
        configurations: config
    )
    let context = container.mainContext
    
    // 🎭 ダミーユーザーを作成
    let me = UserProfile(name: "あなた", username: "me")
    let friend1 = UserProfile(name: "田中太郎", username: "tanaka_taro")
    let friend2 = UserProfile(name: "鈴木花子", username: "suzuki_hanako")
    let friend3 = UserProfile(name: "佐藤次郎", username: "sato_jiro")
    
    // フォロー関係を設定
    me.following = [friend1, friend2, friend3]
    
    // ユーザーを挿入
    [me, friend1, friend2, friend3].forEach { context.insert($0) }
    
    // 🎭 ダミー写真を作成（解禁済み）
    let now = Date()
    let unlockDate1 = now.addingTimeInterval(-3600) // 1時間前に解禁
    let unlockDate2 = now.addingTimeInterval(-1800) // 30分前に解禁
    let unlockDate3 = now.addingTimeInterval(-900)  // 15分前に解禁
    
    // ダミー画像データ（グラデーション）
    let photo1Data = createDummyImageData(color: .blue)
    let photo2Data = createDummyImageData(color: .purple)
    let photo3Data = createDummyImageData(color: .orange)
    
    let photo1 = LaterPhoto(
        imageData: photo1Data,
        captureDate: now.addingTimeInterval(-86400),
        unlockDate: unlockDate1,
        owner: friend1
    )
    photo1.isUnlocked = true
    
    let photo2 = LaterPhoto(
        imageData: photo2Data,
        captureDate: now.addingTimeInterval(-86400),
        unlockDate: unlockDate2,
        owner: friend2
    )
    photo2.isUnlocked = true
    
    let photo3 = LaterPhoto(
        imageData: photo3Data,
        captureDate: now.addingTimeInterval(-86400),
        unlockDate: unlockDate3,
        owner: friend3
    )
    photo3.isUnlocked = true
    
    // 写真を挿入
    [photo1, photo2, photo3].forEach { context.insert($0) }
    
    try? context.save()
    
    // 🎬 デバッグモードで表示
    return UnlockedFeedView(
        debugMode: true,                    // ✅ デバッグモード有効
        debugPhotosTaken: 5,                // ✅ 5枚撮影済みと偽装
        debugDailyGoal: 3,                  // ✅ 目標3枚
        debugUnlockTimeRemaining: 18000     // ✅ 残り5時間 (18000秒)
    )
    .modelContainer(container)
}

#Preview("解禁後フィード - 通常モード") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: LaterPhoto.self, UserProfile.self, LaterGroup.self,
        configurations: config
    )
    
    // 通常モードで表示（本番と同じ動作）
    return UnlockedFeedView(
        debugMode: false,
        debugPhotosTaken: 0,
        debugDailyGoal: 3,
        debugUnlockTimeRemaining: 0
    )
    .modelContainer(container)
}

// MARK: - ヘルパー関数

/// ダミー画像データを生成
private func createDummyImageData(color: Color) -> Data {
    let size = CGSize(width: 400, height: 400)
    let renderer = UIGraphicsImageRenderer(size: size)
    
    let image = renderer.image { context in
        // グラデーション背景
        let colors = [
            UIColor(color),
            UIColor(color.opacity(0.6))
        ]
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors.map { $0.cgColor } as CFArray,
            locations: [0, 1]
        )!
        
        context.cgContext.drawLinearGradient(
            gradient,
            start: .zero,
            end: CGPoint(x: size.width, y: size.height),
            options: []
        )
        
        // テキスト
        let text = "DEBUG\nPHOTO"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 40),
            .foregroundColor: UIColor.white.withAlphaComponent(0.8)
        ]
        let textSize = text.size(withAttributes: attributes)
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attributes)
    }
    
    return image.jpegData(compressionQuality: 0.8) ?? Data()
}
