import SwiftUI
import SwiftData

// MARK: - 📸 一括解禁対応ギャラリービュー
/// 1日の撮影セッションで撮った全写真を一括で表示・解禁するビュー

struct SecretPhotoGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LaterPhoto.captureDate, order: .reverse) private var allPhotos: [LaterPhoto]
    
    @State private var sessionManager = DailyPhotoSessionManager.shared
    @State private var currentDate = Date()
    
    // タイマーで定期的に更新
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // 今日のセッションの写真のみをフィルタリング
    private var todayPhotos: [LaterPhoto] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return allPhotos.filter { photo in
            calendar.isDate(photo.captureDate, inSameDayAs: today)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                if todayPhotos.isEmpty {
                    emptyStateView
                } else {
                    photoGridView
                }
            }
            .navigationTitle("今日の写真")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    sessionStatusBadge
                }
            }
            .onReceive(timer) { _ in
                currentDate = Date()
            }
        }
    }
    
    // MARK: - 空の状態
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("まだ写真がありません")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            
            Text("カメラで写真を撮影してください")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    // MARK: - 写真グリッド
    
    private var photoGridView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // セッション情報カード
                sessionInfoCard
                
                // 写真グリッド
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(todayPhotos) { photo in
                        PhotoGridItem(
                            photo: photo,
                            isUnlocked: sessionManager.arePhotosUnlocked()
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .padding(.top, 20)
        }
    }
    
    // MARK: - セッション情報カード
    
    private var sessionInfoCard: some View {
        VStack(spacing: 16) {
            // ステータスアイコンとメッセージ
            HStack(spacing: 12) {
                Image(systemName: sessionManager.statusIcon)
                    .font(.system(size: 32))
                    .foregroundStyle(sessionManager.statusColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(sessionManager.statusMessage)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    
                    if sessionManager.isSessionLocked && !sessionManager.arePhotosUnlocked() {
                        Text(sessionManager.developmentMessage)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // 写真枚数バッジ
                VStack(spacing: 4) {
                    Text("\(todayPhotos.count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("枚")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            
            // 進行度バー（現像中のみ表示）
            if sessionManager.isSessionLocked && !sessionManager.arePhotosUnlocked() {
                developmentProgressBar
            }
            
            // 解禁済みの場合のメッセージ
            if sessionManager.arePhotosUnlocked() {
                unlockedMessage
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(sessionManager.statusColor.opacity(0.3), lineWidth: 1.5)
        )
        .padding(.horizontal, 16)
    }
    
    // 現像進行度バー
    private var developmentProgressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    // 進行バー
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [sessionManager.statusColor, sessionManager.statusColor.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * sessionManager.unlockProgress(),
                            height: 8
                        )
                        .animation(.linear(duration: 1.0), value: sessionManager.unlockProgress())
                }
            }
            .frame(height: 8)
            
            // 進行度パーセンテージ（抽象的）
            HStack {
                Image(systemName: "hourglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                Text("現像処理中")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // 進行度を3段階で表示（具体的な数値は隠す）
                let progress = sessionManager.unlockProgress()
                let stage = progress < 0.33 ? "初期" : progress < 0.66 ? "中期" : "後期"
                
                Text(stage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(sessionManager.statusColor)
            }
        }
    }
    
    // 解禁済みメッセージ
    private var unlockedMessage: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.green)
            
            Text("すべての写真が閲覧可能になりました")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.green.opacity(0.15))
        )
    }
    
    // MARK: - セッションステータスバッジ
    
    private var sessionStatusBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: sessionManager.statusIcon)
                .font(.system(size: 14, weight: .semibold))
            
            Text("\(todayPhotos.count)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
        }
        .foregroundStyle(sessionManager.statusColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(sessionManager.statusColor.opacity(0.15))
        )
        .overlay(
            Capsule()
                .strokeBorder(sessionManager.statusColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 写真グリッドアイテム

struct PhotoGridItem: View {
    let photo: LaterPhoto
    let isUnlocked: Bool
    
    @State private var showFullScreen = false
    
    var body: some View {
        Button {
            if isUnlocked {
                showFullScreen = true
            }
        } label: {
            photoThumbnail
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showFullScreen) {
            if isUnlocked {
                FullScreenPhotoView(photo: photo)
            }
        }
    }
    
    private var photoThumbnail: some View {
        GeometryReader { geometry in
            ZStack {
                // 写真
                if let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.width
                        )
                        .clipped()
                        .blur(radius: isUnlocked ? 0 : 12)
                        .grayscale(isUnlocked ? 0 : 0.8)
                        .overlay(
                            Rectangle()
                                .fill(Color.white.opacity(isUnlocked ? 0 : 0.4))
                        )
                }
                
                // ロック中のオーバーレイ
                if !isUnlocked {
                    lockOverlay
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isUnlocked ? Color.clear : Color.white.opacity(0.2),
                        lineWidth: 1
                    )
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private var lockOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.8))
            
            Text("現像中")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.5))
                .background(.ultraThinMaterial)
        )
    }
}

// MARK: - フルスクリーン写真ビュー

struct FullScreenPhotoView: View {
    @Environment(\.dismiss) private var dismiss
    let photo: LaterPhoto
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            }
            
            // 閉じるボタン
            VStack {
                HStack {
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(20)
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - プレビュー
#Preview {
    SecretPhotoGalleryView()
}
