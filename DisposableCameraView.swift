import SwiftUI
import SwiftData
import AVFoundation
internal import Combine

/// 「写ルンです」風のメカニカルカメラUI
struct DisposableCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    // ✅ AppStorageからも目標枚数を取得（両方のソースを確認）
    @AppStorage("dailyGoal") private var appStorageDailyGoal: Int = 3
    
    @StateObject private var cameraManager = DisposableCameraManager()
    @State private var remainingShots: Int = 3
    @State private var isCapturing = false
    @State private var flashAnimation = false
    @State private var counterRotation: Double = 0
    
    // ✅ キャプション入力フロー用の状態
    @State private var showCaptionInput = false
    @State private var capturedImageData: Data?
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    /// ✅ 正しい目標枚数を取得（UserProfileとAppStorageの両方をチェック）
    private var effectiveDailyGoal: Int {
        if let user = currentUser, user.dailyGoal > 0 {
            return user.dailyGoal
        }
        return appStorageDailyGoal > 0 ? appStorageDailyGoal : 3
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar - Close & Film Counter
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                Spacer()
                
                // Viewfinder (3:2 aspect ratio)
                viewfinderFrame
                    .padding(.horizontal, 24)
                
                Spacer()
                
                // Camera Controls
                cameraControls
                    .padding(.bottom, 40)
            }
            
            // Flash overlay
            if flashAnimation {
                Color.white
                    .ignoresSafeArea()
                    .opacity(flashAnimation ? 0.9 : 0)
                    .animation(.easeOut(duration: 0.15), value: flashAnimation)
            }
        }
        .fullScreenCover(isPresented: $showCaptionInput) {
            // ✅ キャプション入力画面（漆黒の背景）
            AlternativeCaptionInputView(
                onSave: { caption in
                    savePhotoWithCaption(caption: caption)
                },
                onSkip: {
                    savePhotoWithCaption(caption: nil)
                }
            )
        }
        .onAppear {
            cameraManager.checkPermissions()
            loadRemainingShots()
            syncDailyGoalToUserProfile() // ✅ 起動時に同期
        }
        .onChange(of: appStorageDailyGoal) { oldValue, newValue in
            // ✅ AppStorageが変更されたら残弾を再計算
            syncDailyGoalToUserProfile()
            loadRemainingShots()
        }
    }
    
    /// ✅ AppStorageの値をUserProfileに同期
    private func syncDailyGoalToUserProfile() {
        guard let user = currentUser else { return }
        
        if user.dailyGoal != appStorageDailyGoal {
            user.dailyGoal = appStorageDailyGoal
            try? modelContext.save()
            print("📸 [Sync] UserProfile.dailyGoal を \(appStorageDailyGoal) に更新しました")
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                    )
            }
            
            Spacer()
            
            // Film counter (mechanical style)
            filmCounter
        }
    }
    
    private var filmCounter: some View {
        HStack(spacing: 8) {
            // Counter label
            Text("FILM")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.brandGreen)
                .tracking(1)
            
            // Mechanical number wheel
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.brandGreen.opacity(0.3), lineWidth: 1)
                    )
                
                // Number display with rotation animation
                Text("\(remainingShots)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.brandGreen)
                    .shadow(color: .brandGreen.opacity(0.5), radius: 4)
                    .rotation3DEffect(
                        .degrees(counterRotation),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .center,
                        perspective: 0.5
                    )
            }
            
            // Notches (mechanical detail)
            VStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.brandGreen.opacity(0.3))
                        .frame(width: 3, height: 6)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.5))
                .shadow(color: .black.opacity(0.5), radius: 8)
        )
    }
    
    // MARK: - Viewfinder
    
    private var viewfinderFrame: some View {
        GeometryReader { geometry in
            let frameWidth = geometry.size.width
            let frameHeight = frameWidth * 2 / 3  // 3:2 aspect ratio
            
            VStack {
                Spacer()
                
                ZStack {
                    // Camera preview
                    if let previewLayer = cameraManager.previewLayer {
                        DisposableCameraPreviewView(previewLayer: previewLayer)
                            .frame(width: frameWidth, height: frameHeight)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                    } else {
                        // Placeholder
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: frameWidth, height: frameHeight)
                            .overlay(
                                VStack(spacing: 12) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 50))
                                        .foregroundStyle(.gray)
                                    
                                    Text("Camera Loading...")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                            )
                    }
                    
                    // Viewfinder frame overlay
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.brandGreen.opacity(0.6), lineWidth: 3)
                        .frame(width: frameWidth, height: frameHeight)
                        .shadow(color: .brandGreen.opacity(0.3), radius: 8, x: 0, y: 0)
                    
                    // Corner brackets (analog camera feel)
                    ForEach(0..<4, id: \.self) { index in
                        cornerBracket(for: index)
                            .frame(width: frameWidth, height: frameHeight)
                    }
                    
                    // Center focus mark
                    Circle()
                        .strokeBorder(Color.white.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 60, height: 60)
                }
                
                Spacer()
            }
        }
        .aspectRatio(3/2, contentMode: .fit)
    }
    
    private func cornerBracket(for position: Int) -> some View {
        let offset: CGFloat = 16
        
        return Group {
            Path { path in
                let length: CGFloat = 20
                
                switch position {
                case 0: // Top-left
                    path.move(to: CGPoint(x: 0, y: length))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: length, y: 0))
                case 1: // Top-right
                    path.move(to: CGPoint(x: -length, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: length))
                case 2: // Bottom-left
                    path.move(to: CGPoint(x: 0, y: -length))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: length, y: 0))
                case 3: // Bottom-right
                    path.move(to: CGPoint(x: -length, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: -length))
                default:
                    break
                }
            }
            .stroke(Color.white.opacity(0.6), lineWidth: 2)
            .offset(
                x: position == 1 || position == 3 ? offset : -offset,
                y: position == 2 || position == 3 ? offset : -offset
            )
        }
    }
    
    // MARK: - Camera Controls
    
    private var cameraControls: some View {
        HStack(spacing: 60) {
            Spacer()
            
            // Shutter button (large, mechanical)
            Button(action: capturePhoto) {
                ZStack {
                    // Outer ring
                    Circle()
                        .strokeBorder(Color.brandGreen, lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    // Inner button
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.brandGreen.opacity(isCapturing ? 0.5 : 0.8),
                                    Color.brandGreen
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(color: .brandGreen.opacity(0.5), radius: 12)
                        .scaleEffect(isCapturing ? 0.9 : 1.0)
                    
                    // Center dot
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                }
            }
            .disabled(remainingShots <= 0 || isCapturing)
            .sensoryFeedback(.impact(weight: .heavy, intensity: 1.0), trigger: isCapturing)
            
            Spacer()
        }
    }
    
    // MARK: - Functions
    
    private func loadRemainingShots() {
        // ✅ 有効な目標枚数を使用
        let targetGoal = effectiveDailyGoal
        
        guard let user = currentUser else {
            // ユーザーがいない場合でも目標枚数を表示
            remainingShots = targetGoal
            return
        }
        
        // Count today's photos
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let todayPhotoCount = user.photos.filter { photo in
            calendar.isDate(photo.captureDate, inSameDayAs: today)
        }.count
        
        // ✅ 目標枚数から今日撮影した枚数を引いた残り枚数を設定
        remainingShots = max(0, targetGoal - todayPhotoCount)
        
        print("📸 [DisposableCamera] 目標枚数: \(targetGoal), 今日撮影済み: \(todayPhotoCount), 残り: \(remainingShots)")
    }
    
    private func capturePhoto() {
        guard remainingShots > 0, !isCapturing else { return }
        
        isCapturing = true
        
        // Haptic feedback (heavy impact like mechanical shutter)
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred(intensity: 1.0)
        
        // Flash animation
        flashAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            flashAnimation = false
        }
        
        // Counter rotation animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            counterRotation += 180
        }
        
        // ✅ 撮影後、画像データを一時保存してキャプション入力画面を表示
        cameraManager.capturePhoto { [self] imageData in
            guard let data = imageData else {
                isCapturing = false
                
                // エラーハプティック
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.error)
                return
            }
            
            // 撮影成功：データを一時保存し、キャプション入力画面を表示
            capturedImageData = data
            isCapturing = false
            
            // ✅ カメラプレビューを即座に停止（写真を見せない）
            cameraManager.stopSession()
            
            // キャプション入力画面を表示
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showCaptionInput = true
            }
        }
    }
    
    // ✅ 新規メソッド：キャプションと一緒に写真を保存
    private func savePhotoWithCaption(caption: String?) {
        guard let imageData = capturedImageData,
              let user = currentUser else {
            // キャプチャデータがない場合は何もしない
            return
        }
        
        // LaterPhotoオブジェクトを作成（24時間ロック + キャプション）
        let unlockDate = Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date()
        let photo = LaterPhoto(
            imageData: imageData,
            captureDate: Date(),
            unlockDate: unlockDate,
            owner: user,
            caption: caption?.isEmpty == false ? caption : nil
        )
        
        modelContext.insert(photo)
        
        do {
            try modelContext.save()
            
            // ✅ 残弾を1減らす
            remainingShots -= 1
            
            // 成功ハプティック
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
            
            print("📸 [Save] Photo saved with caption: '\(caption ?? "nil")', remaining shots: \(remainingShots)")
            
            // ✅ 一時データをクリア
            capturedImageData = nil
            
            // ✅ カメラセッションを再開（次の撮影に備える）
            cameraManager.resumeSession()
            
            // ✅ フィルムが終了したら自動で閉じる
            if remainingShots == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    dismiss()
                }
            }
        } catch {
            print("❌ [Error] Failed to save photo: \(error)")
            
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
            
            // エラー時もカメラセッションを再開
            cameraManager.resumeSession()
        }
    }
}

// MARK: - Camera Manager

class DisposableCameraManager: NSObject, ObservableObject {
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    
    // ⚠️ AVCaptureSession は Sendable ではないため、nonisolated(unsafe) を使用
    nonisolated(unsafe) private let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var captureCompletion: ((Data?) -> Void)?
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                }
            }
        default:
            break
        }
    }
    
    private func setupCamera() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        
        // Add camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        // Add photo output
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        captureSession.commitConfiguration()
        
        // Create preview layer
        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill
        
        DispatchQueue.main.async {
            self.previewLayer = preview
        }
        
        // Start session
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func capturePhoto(completion: @escaping (Data?) -> Void) {
        self.captureCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // ✅ カメラセッションを停止（キャプション入力中は非表示）
    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
    
    // ✅ カメラセッションを再開（保存後に次の撮影に備える）
    func resumeSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
}

// MARK: - Photo Capture Delegate

extension DisposableCameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation() else {
            captureCompletion?(nil)
            return
        }
        
        captureCompletion?(imageData)
        captureCompletion = nil
    }
}

// MARK: - Camera Preview UIViewRepresentable

struct DisposableCameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            previewLayer.frame = uiView.bounds
        }
    }
}

// MARK: - Preview

#Preview {
    DisposableCameraView()
        .modelContainer(for: [UserProfile.self, LaterPhoto.self], inMemory: true)
}
