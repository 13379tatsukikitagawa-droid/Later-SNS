import SwiftUI
import SwiftData
import AVFoundation

// MARK: - 📷 一括解禁対応カメラビュー
/// 目標枚数達成後に全写真を一括解禁するシステムに対応したカメラ

struct SecretCameraView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("dailyGoal") private var dailyGoal: Int = 3
    
    @State private var sessionManager = DailyPhotoSessionManager.shared
    @State private var cameraService = CameraService()
    @State private var showingPreview = false
    @State private var capturedImage: UIImage?
    @State private var showingGoalAchieved = false
    
    // 今日撮影した写真の枚数（SwiftDataから取得）
    @Query private var allPhotos: [LaterPhoto]
    
    private var todayPhotoCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return allPhotos.filter { photo in
            calendar.isDate(photo.captureDate, inSameDayAs: today)
        }.count
    }
    
    // 残り撮影枚数
    private var remainingPhotos: Int {
        max(0, dailyGoal - todayPhotoCount)
    }
    
    // 目標達成済みか
    private var isGoalAchieved: Bool {
        todayPhotoCount >= dailyGoal
    }
    
    var body: some View {
        ZStack {
            // カメラプレビュー
            CameraPreviewView(cameraService: cameraService)
                .ignoresSafeArea()
            
            // UI オーバーレイ
            cameraOverlay
        }
        .onAppear {
            cameraService.startSession()
        }
        .onDisappear {
            cameraService.stopSession()
        }
        .sheet(isPresented: $showingPreview) {
            if let image = capturedImage {
                PhotoPreviewView(
                    image: image,
                    onSave: savePhoto,
                    onRetake: retakePhoto
                )
            }
        }
        .alert("目標達成！", isPresented: $showingGoalAchieved) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("今日の目標\(dailyGoal)枚を達成しました！\n撮影した写真は現像中です。お楽しみに！")
        }
    }
    
    // MARK: - カメラオーバーレイ
    
    private var cameraOverlay: some View {
        VStack {
            // 上部：閉じるボタンと進捗
            topBar
            
            Spacer()
            
            // 下部：シャッターボタンとカウンター
            bottomBar
        }
    }
    
    // 上部バー
    private var topBar: some View {
        HStack {
            // 閉じるボタン
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.8))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            
            Spacer()
            
            // 進捗バッジ
            progressBadge
        }
        .padding(20)
    }
    
    // 進捗バッジ
    private var progressBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: isGoalAchieved ? "checkmark.circle.fill" : "camera.fill")
                .font(.system(size: 16, weight: .semibold))
            
            Text("\(todayPhotoCount) / \(dailyGoal)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    isGoalAchieved ? Color.green : Color.white.opacity(0.3),
                    lineWidth: 2
                )
        )
    }
    
    // 下部バー
    private var bottomBar: some View {
        VStack(spacing: 20) {
            // 残り枚数メッセージ
            if !isGoalAchieved {
                remainingMessage
            } else {
                goalAchievedMessage
            }
            
            // シャッターボタン
            shutterButton
        }
        .padding(.bottom, 40)
    }
    
    // 残り枚数メッセージ
    private var remainingMessage: some View {
        VStack(spacing: 6) {
            Text("残り \(remainingPhotos) 枚")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            Text("目標まであと少し！")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.5))
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
        )
    }
    
    // 目標達成メッセージ
    private var goalAchievedMessage: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.green)
                
                Text("目標達成！")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            Text("今日の撮影は完了しました")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            Capsule()
                .fill(Color.green.opacity(0.2))
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
        )
    }
    
    // シャッターボタン
    private var shutterButton: some View {
        Button {
            capturePhoto()
        } label: {
            ZStack {
                // 外側のリング
                Circle()
                    .strokeBorder(Color.white, lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                // 内側のボタン
                Circle()
                    .fill(Color.white)
                    .frame(width: 68, height: 68)
            }
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        }
    }
    
    // MARK: - Actions
    
    private func capturePhoto() {
        cameraService.capturePhoto { image in
            capturedImage = image
            showingPreview = true
            
            // ハプティクスフィードバック
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
    
    private func savePhoto(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return
        }
        
        // 写真をSwiftDataに保存
        let newPhoto = LaterPhoto(
            imageData: imageData,
            captureDate: Date(),
            unlockDate: Date() // 仮の値（実際は一括解禁時刻で管理）
        )
        
        modelContext.insert(newPhoto)
        
        do {
            try modelContext.save()
            
            // セッションマネージャーに写真追加を通知
            sessionManager.addPhoto(dailyGoal: dailyGoal)
            
            // 目標達成チェック
            if sessionManager.isSessionLocked && !showingGoalAchieved {
                showingGoalAchieved = true
            }
            
            print("✅ 写真を保存しました")
        } catch {
            print("❌ 写真の保存に失敗: \(error)")
        }
        
        // プレビューを閉じる
        showingPreview = false
        capturedImage = nil
    }
    
    private func retakePhoto() {
        capturedImage = nil
        showingPreview = false
    }
}

// MARK: - カメラプレビュービュー

struct CameraPreviewView: UIViewRepresentable {
    let cameraService: CameraService
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        
        DispatchQueue.main.async {
            let previewLayer = cameraService.previewLayer
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

// MARK: - 写真プレビュービュー

struct PhotoPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    
    let image: UIImage
    let onSave: (UIImage) -> Void
    let onRetake: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 写真
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .ignoresSafeArea()
            
            // ボタン
            VStack {
                Spacer()
                
                HStack(spacing: 40) {
                    // 撮り直しボタン
                    Button {
                        onRetake()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 28))
                            
                            Text("撮り直す")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .frame(width: 100)
                    }
                    
                    // 保存ボタン
                    Button {
                        onSave(image)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36))
                            
                            Text("保存")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(.green)
                        .frame(width: 100)
                    }
                }
                .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - カメラサービス

@Observable
class CameraService: NSObject {
    private let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var completion: ((UIImage) -> Void)?
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        AVCaptureVideoPreviewLayer(session: captureSession)
    }
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        captureSession.beginConfiguration()
        
        // カメラデバイスを取得
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            print("❌ カメラデバイスの設定に失敗")
            return
        }
        
        captureSession.addInput(videoInput)
        
        // 写真出力を追加
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        captureSession.commitConfiguration()
    }
    
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        self.completion = completion
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("❌ 写真の処理に失敗")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.completion?(image)
        }
    }
}

// MARK: - プレビュー
#Preview {
    SecretCameraView()
}
