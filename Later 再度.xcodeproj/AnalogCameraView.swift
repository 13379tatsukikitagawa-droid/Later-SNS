import SwiftUI
import AVFoundation

// MARK: - 📷 Analog Camera View (3:2 Viewfinder + Film Counter)
/// アナログカメラ仕様：3:2ビューファインダー、フィルムカウンター、暗室モード対応

struct AnalogCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var photoManager = PhotoManager.shared
    @State private var cameraController = CameraController()
    @State private var capturedImage: UIImage?
    @State private var isFlashing = false
    
    // 今日撮影した枚数（リアルタイム更新）
    @State private var photosTakenToday: Int = 0
    private let dailyGoal: Int = 5
    
    // 撮影完了フラグ
    private var isMissionComplete: Bool {
        photosTakenToday >= dailyGoal
    }
    
    // 残り枚数（05→00）
    private var remainingCount: Int {
        max(0, dailyGoal - photosTakenToday)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isMissionComplete {
                // 撮影完了 → 暗室モード
                DarkroomWaitingView()
            } else {
                // 撮影中 → アナログカメラUI
                analogCameraUI
            }
        }
        .onAppear {
            setupCamera()
            updatePhotoCount()
        }
    }
    
    // MARK: - Analog Camera UI
    private var analogCameraUI: some View {
        ZStack {
            // カメラプレビュー（3:2）
            CameraPreviewView(controller: cameraController)
                .aspectRatio(3/2, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(limeGreen, lineWidth: 2)
                )
                .overlay(alignment: .topTrailing) {
                    // フィルムカウンター（右上）
                    FilmCounterView(remainingCount: remainingCount)
                        .padding(16)
                }
                .overlay {
                    // レティクル（L字フレーム）
                    ReticleOverlay()
                }
            
            // フラッシュエフェクト
            if isFlashing {
                Rectangle()
                    .fill(limeGreen.opacity(0.8))
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            
            VStack {
                Spacer()
                
                // シャッターボタン
                shutterButton
                    .padding(.bottom, 40)
            }
            
            // 閉じるボタン
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(limeGreen)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(.black.opacity(0.6))
                            )
                    }
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Shutter Button
    private var shutterButton: some View {
        Button {
            capturePhoto()
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(limeGreen, lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .fill(limeGreen.opacity(0.3))
                    .frame(width: 68, height: 68)
                
                Text("\(remainingCount)")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(limeGreen)
            }
        }
        .disabled(isMissionComplete)
    }
    
    // MARK: - Lime Green Color
    private var limeGreen: Color {
        Color(red: 0, green: 1, blue: 0.255)  // #00ff41
    }
    
    // MARK: - Camera Setup
    private func setupCamera() {
        cameraController.setupSession()
        cameraController.startSession()
    }
    
    // MARK: - Capture Photo
    private func capturePhoto() {
        // フラッシュアニメーション
        withAnimation(.easeInOut(duration: 0.2)) {
            isFlashing = true
        }
        
        // ハプティクス
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // 写真をキャプチャ
        cameraController.capturePhoto { image in
            guard let image = image else { return }
            
            // 写真を保存
            savePhoto(image)
            
            // フラッシュを消す
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    isFlashing = false
                }
            }
            
            // カウント更新
            updatePhotoCount()
        }
    }
    
    // MARK: - Save Photo
    private func savePhoto(_ image: UIImage) {
        // LaterPhotoとして保存
        let photo = LaterPhoto(
            imageData: image.jpegData(compressionQuality: 0.8),
            captureDate: Date(),
            isDeveloped: false  // 未現像
        )
        
        modelContext.insert(photo)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save photo: \(error)")
        }
    }
    
    // MARK: - Update Photo Count
    private func updatePhotoCount() {
        // 今日撮影した写真をカウント
        let calendar = Calendar.current
        let today = Date()
        
        // TODO: allPhotosをクエリから取得
        // 暫定的に PhotoManager から取得
        photosTakenToday = photoManager.todayPhotoCount()
    }
}

// MARK: - Film Counter View
struct FilmCounterView: View {
    let remainingCount: Int
    
    var body: some View {
        VStack(spacing: 4) {
            // 窓
            ZStack {
                // 漆黒の背景
                RoundedRectangle(cornerRadius: 6)
                    .fill(.black)
                    .frame(width: 60, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(limeGreen, lineWidth: 2)
                    )
                
                // カウンター数字
                Text(String(format: "%02d", remainingCount))
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(limeGreen)
                    .shadow(color: limeGreen.opacity(0.8), radius: 8)
            }
            
            // ラベル
            Text("FILM")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(limeGreen.opacity(0.6))
                .tracking(1)
        }
    }
    
    private var limeGreen: Color {
        Color(red: 0, green: 1, blue: 0.255)
    }
}

// MARK: - Reticle Overlay (L字フレーム)
struct ReticleOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let cornerLength: CGFloat = 30
            let lineWidth: CGFloat = 2
            
            ZStack {
                // 左上
                Path { path in
                    path.move(to: CGPoint(x: 20, y: 20 + cornerLength))
                    path.addLine(to: CGPoint(x: 20, y: 20))
                    path.addLine(to: CGPoint(x: 20 + cornerLength, y: 20))
                }
                .stroke(limeGreen, lineWidth: lineWidth)
                
                // 右上
                Path { path in
                    path.move(to: CGPoint(x: size.width - 20 - cornerLength, y: 20))
                    path.addLine(to: CGPoint(x: size.width - 20, y: 20))
                    path.addLine(to: CGPoint(x: size.width - 20, y: 20 + cornerLength))
                }
                .stroke(limeGreen, lineWidth: lineWidth)
                
                // 左下
                Path { path in
                    path.move(to: CGPoint(x: 20, y: size.height - 20 - cornerLength))
                    path.addLine(to: CGPoint(x: 20, y: size.height - 20))
                    path.addLine(to: CGPoint(x: 20 + cornerLength, y: size.height - 20))
                }
                .stroke(limeGreen, lineWidth: lineWidth)
                
                // 右下
                Path { path in
                    path.move(to: CGPoint(x: size.width - 20 - cornerLength, y: size.height - 20))
                    path.addLine(to: CGPoint(x: size.width - 20, y: size.height - 20))
                    path.addLine(to: CGPoint(x: size.width - 20, y: size.height - 20 - cornerLength))
                }
                .stroke(limeGreen, lineWidth: lineWidth)
            }
        }
    }
    
    private var limeGreen: Color {
        Color(red: 0, green: 1, blue: 0.255)
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let controller: CameraController
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        guard let previewLayer = controller.previewLayer else {
            return view
        }
        
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = controller.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

// MARK: - Camera Controller
@Observable
class CameraController: NSObject {
    var session = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput = AVCapturePhotoOutput()
    private var captureCompletion: ((UIImage?) -> Void)?
    
    func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // カメラデバイス
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        // プレビューレイヤー
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspectFill
        
        session.commitConfiguration()
    }
    
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.captureCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            captureCompletion?(nil)
            return
        }
        
        captureCompletion?(image)
        captureCompletion = nil
    }
}

// MARK: - 🌙 Darkroom Waiting View (暗室モード)
struct DarkroomWaitingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LaterPhoto.captureDate, order: .forward) private var allPhotos: [LaterPhoto]
    
    @State private var nextToRevealPhoto: LaterPhoto?
    @State private var remainingTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // 暗室プレビュー（3:2フレーム）
                if let photo = nextToRevealPhoto {
                    darkroomPreview(photo: photo)
                        .aspectRatio(3/2, contentMode: .fit)
                        .padding(.horizontal, 32)
                } else {
                    // 次に現像される写真がない場合
                    noPhotoWaitingView
                }
                
                Spacer()
                
                // ステータスメッセージ
                VStack(spacing: 12) {
                    Text("WAITING FOR DEVELOPMENT")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(limeGreen.opacity(0.6))
                        .tracking(2)
                    
                    if remainingTime > 0 {
                        Text("DEVELOPS IN \(formatTime(remainingTime))")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(limeGreen)
                            .shadow(color: limeGreen.opacity(0.6), radius: 12)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            findNextToRevealPhoto()
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // MARK: - Darkroom Preview
    private func darkroomPreview(photo: LaterPhoto) -> some View {
        ZStack {
            // 写真（ぼかし + ノイズ）
            if let imageData = photo.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 40)  // 強いガウスぼかし
                    .overlay {
                        // 粒子ノイズ
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.8),
                                        Color.black.opacity(0.6),
                                        Color.black.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay {
                                // ノイズテクスチャ（簡易版）
                                Canvas { context, size in
                                    for _ in 0..<1000 {
                                        let x = CGFloat.random(in: 0...size.width)
                                        let y = CGFloat.random(in: 0...size.height)
                                        let rect = CGRect(x: x, y: y, width: 2, height: 2)
                                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.15)))
                                    }
                                }
                            }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(limeGreen.opacity(0.4), lineWidth: 2)
                    )
            }
        }
    }
    
    // MARK: - No Photo Waiting View
    private var noPhotoWaitingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.badge.clock")
                .font(.system(size: 64))
                .foregroundStyle(limeGreen.opacity(0.4))
            
            Text("NO PHOTOS DEVELOPING")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(limeGreen.opacity(0.6))
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(3/2, contentMode: .fit)
        .padding(.horizontal, 32)
    }
    
    // MARK: - Find Next-to-Reveal Photo
    private func findNextToRevealPhoto() {
        let now = Date()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        
        // 前日以前に撮影され、まだ現像されていない写真
        let undevelopedPhotos = allPhotos.filter { photo in
            !photo.isDeveloped && photo.captureDate < calendar.startOfDay(for: now)
        }
        
        // 現像時刻が最も近い1枚を選択
        nextToRevealPhoto = undevelopedPhotos.min(by: { photo1, photo2 in
            let reveal1 = photo1.revealTime ?? Date.distantFuture
            let reveal2 = photo2.revealTime ?? Date.distantFuture
            return reveal1 < reveal2
        })
        
        // 残り時間を計算
        if let photo = nextToRevealPhoto, let revealTime = photo.revealTime {
            remainingTime = max(0, revealTime.timeIntervalSince(now))
        }
    }
    
    // MARK: - Timer
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingTime > 0 {
                remainingTime -= 1
            } else {
                // 時間到達
                findNextToRevealPhoto()
            }
        }
    }
    
    // MARK: - Format Time
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
    
    // MARK: - Lime Green
    private var limeGreen: Color {
        Color(red: 0, green: 1, blue: 0.255)
    }
}

// MARK: - Preview
#Preview {
    AnalogCameraView()
        .modelContainer(for: [LaterPhoto.self, UserProfile.self])
}

#Preview("Darkroom Mode") {
    DarkroomWaitingView()
        .modelContainer(for: [LaterPhoto.self])
}
