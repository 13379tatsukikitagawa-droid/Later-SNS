import SwiftUI

struct DevelopingPhotoView: View {
    let photo: LaterPhoto
    
    @State private var currentTime = Date()
    
    // エフェクトパラメータ
    private let maxBlur: CGFloat = 20.0
    private let maxOverlayOpacity: Double = 0.5
    private let maxNoiseOpacity: Double = 0.3
    
    // 進行度の計算プロパティ（内部計算用のみ - UI層には露出しない）
    private var progress: Double {
        PhotoUnlockUtilities.calculateUnlockProgress(
            captureDate: photo.captureDate,
            unlockDate: photo.unlockDate,
            currentDate: currentTime
        )
    }
    
    private var smoothProgress: Double {
        PhotoUnlockUtilities.applyEasing(
            progress: progress,
            easingType: .smoothStep
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 写真エリア
            Group {
                if let uiImage = UIImage(data: photo.imageData) {
                    imageWithEffects(uiImage: uiImage)
                } else {
                    placeholderView
                }
            }
            .padding(8)
            .background(Color.brandBlack.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // キャプション表示エリア（現像中でも読める）
            if let caption = photo.caption, !caption.isEmpty {
                captionView(caption)
                    .padding(.top, 12)
            }
        }
        .task {
            // Swift Concurrencyを使用したタイマー（エフェクト更新のみ）
            while !Task.isCancelled {
                currentTime = Date()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
    
    // MARK: - メイン画像とエフェクト
    
    @ViewBuilder
    private func imageWithEffects(uiImage: UIImage) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(height: 200)
            .clipped()
            .saturation(smoothProgress)
            .blur(radius: (1.0 - smoothProgress) * maxBlur)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                effectsOverlay
            }
            .overlay(alignment: .topLeading) {
                if progress < 1.0 {
                    developingBadge
                }
            }
    }
    
    @ViewBuilder
    private var effectsOverlay: some View {
        // 白色オーバーレイ
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.white)
            .opacity((1.0 - smoothProgress) * maxOverlayOpacity)
            .allowsHitTesting(false)
        
        // 砂嵐ノイズエフェクト
        if progress < 1.0 {
            noiseOverlay
        }
        
        // ロック中アイコン（中央）
        if progress < 0.8 {
            lockIcon
        }
    }
    
    private var noiseOverlay: some View {
        Canvas { context, size in
            let dotSize: CGFloat = 2.0
            let columns = Int(size.width / dotSize)
            let rows = Int(size.height / dotSize)
            let seed = Int(currentTime.timeIntervalSince1970 * 10) % 1000
            
            for row in 0..<rows {
                for col in 0..<columns {
                    let randomValue = Double((seed + row * columns + col) % 100) / 100.0
                    
                    if randomValue > 0.7 {
                        let x = CGFloat(col) * dotSize
                        let y = CGFloat(row) * dotSize
                        let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                        
                        context.fill(
                            Path(rect),
                            with: .color(.white.opacity(randomValue))
                        )
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity((1.0 - smoothProgress) * maxNoiseOpacity)
        .allowsHitTesting(false)
    }
    
    private var lockIcon: some View {
        let opacity = max(0, (0.8 - progress) / 0.8)
        
        return ZStack {
            Circle()
                .fill(.black.opacity(0.3))
                .frame(width: 80, height: 80)
                .blur(radius: 10)
            
            Image(systemName: "lock.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(.white)
        }
        .opacity(opacity)
        .scaleEffect(0.8 + (1.0 - opacity) * 0.2)
        .allowsHitTesting(false)
    }
    
    // MARK: - UI要素
    
    private var developingBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "camera.aperture")
                .font(.caption.bold())
            Text("現像中...")
                .font(.caption.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.black.opacity(0.7))
                .blur(radius: 5)
        )
        .padding(10)
        .opacity(1.0 - smoothProgress)
    }
    
    private var placeholderView: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 32))
                        .foregroundStyle(.brandGreen)
                        .symbolEffect(.pulse)
                    
                    Text("現像中...")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
    }
    
    // MARK: - キャプション表示
    
    @ViewBuilder
    private func captionView(_ caption: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.brandGreen.opacity(0.7))
            
            Text(caption)
                .font(.system(size: 15, design: .serif))
                .italic()
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
            
            Spacer()
            
            Image(systemName: "quote.closing")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.brandGreen.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - プレビュー

#Preview("現像中の写真") {
    let now = Date()
    
    // Create a dummy owner
    let dummyOwner = UserProfile(name: "Test User", username: "testuser")
    
    let testPhotos = [
        createTestPhoto(
            captureDate: now.addingTimeInterval(-5 * 60),
            unlockDate: now.addingTimeInterval(10 * 60),
            owner: dummyOwner
        ),
        createTestPhoto(
            captureDate: now.addingTimeInterval(-30 * 60),
            unlockDate: now.addingTimeInterval(30 * 60),
            owner: dummyOwner
        ),
        createTestPhoto(
            captureDate: now.addingTimeInterval(-55 * 60),
            unlockDate: now.addingTimeInterval(5 * 60),
            owner: dummyOwner
        ),
        createTestPhoto(
            captureDate: now.addingTimeInterval(-2 * 60 * 60),
            unlockDate: now.addingTimeInterval(-10 * 60),
            owner: dummyOwner
        )
    ]
    
    ScrollView {
        VStack(spacing: 16) {
            ForEach(Array(testPhotos.enumerated()), id: \.offset) { _, photo in
                DevelopingPhotoView(photo: photo)
            }
        }
        .padding()
    }
    .background(.black)
}

private func createTestPhoto(captureDate: Date, unlockDate: Date, owner: UserProfile) -> LaterPhoto {
    let size = CGSize(width: 400, height: 300)
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { context in
        let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray,
            locations: nil
        )!
        context.cgContext.drawLinearGradient(
            gradient,
            start: .zero,
            end: CGPoint(x: size.width, y: size.height),
            options: []
        )
    }
    
    return LaterPhoto(
        imageData: image.pngData() ?? Data(),
        captureDate: captureDate,
        unlockDate: unlockDate,
        owner: owner
    )
}

