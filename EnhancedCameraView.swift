import SwiftUI
import AVFoundation
import SwiftData
import UIKit
internal import Combine

// MARK: - 📷 Enhanced Camera View: 3:2 Aspect + Film Counter + Next Reveal
struct EnhancedCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(sort: \LaterPhoto.unlockDate) private var allPhotos: [LaterPhoto]
    
    // ✅ AppStorageからも目標枚数を取得（両方のソースを確認）
    @AppStorage("dailyGoal") private var appStorageDailyGoal: Int = 3
    
    @StateObject private var camera = CameraManager()
    @State private var flashMode: AVCaptureDevice.FlashMode = .off
    @State private var showCaptureAnimation = false
    @State private var capturedImage: UIImage?
    @State private var showPreview = false
    @State private var showCaptionInput = false
    @State private var savedPhoto: LaterPhoto?
    @State private var caption = ""
    @State private var currentTime = Date()
    @State private var timer: Timer?
    
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
    
    // Film counter (today's photos count)
    private var filmCounter: String {
        let count = todayPhotosCount
        let max = effectiveDailyGoal
        return String(format: "%02d-%02d", count, max)
    }
    
    private var todayPhotosCount: Int {
        guard let user = currentUser else { return 0 }
        let calendar = Calendar.current
        return allPhotos.filter { photo in
            photo.owner?.id == user.id && calendar.isDateInToday(photo.captureDate)
        }.count
    }
    
    /// ✅ 今日の撮影可能枚数が残っているか確認
    private var canTakeMorePhotos: Bool {
        return todayPhotosCount < effectiveDailyGoal
    }
    
    // Next Reveal: 最も近い未現像写真
    private var nextRevealPhoto: LaterPhoto? {
        let now = Date()
        return allPhotos.first { photo in
            !photo.isUnlocked && photo.unlockDate > now
        }
    }
    
    private var timeUntilNextReveal: TimeInterval {
        guard let photo = nextRevealPhoto else { return 0 }
        return photo.unlockDate.timeIntervalSince(currentTime)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Top bar with film counter and Next Reveal
                    topBar
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    
                    Spacer()
                    
                    // 3:2 Aspect Ratio Viewfinder
                    viewfinderArea(geometry: geometry)
                    
                    Spacer()
                    
                    // Bottom controls
                    bottomControls
                        .padding(.bottom, 40)
                }
            }
            
            // Capture flash animation
            if showCaptureAnimation {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showPreview) {
            if let image = capturedImage {
                CapturePreviewView(
                    image: image,
                    caption: $caption,
                    onSave: savePhoto,
                    onRetake: retakePhoto
                )
            }
        }
        .sheet(isPresented: $showCaptionInput) {
            if let photo = savedPhoto {
                CaptionInputView(photo: photo)
            }
        }
        .onAppear {
            camera.checkPermissions()
            startTimeUpdater()
            syncDailyGoalToUserProfile() // ✅ 起動時に同期
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: appStorageDailyGoal) { oldValue, newValue in
            // ✅ AppStorageが変更されたらUserProfileにも反映
            syncDailyGoalToUserProfile()
        }
    }
    
    /// ✅ AppStorageの値をUserProfileに同期
    private func syncDailyGoalToUserProfile() {
        guard let user = currentUser else { return }
        
        if user.dailyGoal != appStorageDailyGoal {
            user.dailyGoal = appStorageDailyGoal
            try? context.save()
            print("📸 [Sync] UserProfile.dailyGoal を \(appStorageDailyGoal) に更新しました")
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack(alignment: .top, spacing: 16) {
            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Film Counter (mechanical window)
            filmCounterWindow
            
            Spacer().frame(width: 16)
            
            // Next Reveal Preview
            if nextRevealPhoto != nil {
                nextRevealWindow
            }
        }
    }
    
    private var filmCounterWindow: some View {
        VStack(spacing: 2) {
            Text("FILM")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
            
            Text(filmCounter)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(limeGreen)
                .tracking(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(limeGreen.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: limeGreen.opacity(0.3), radius: 8, x: 0, y: 0)
        }
    }
    
    private var nextRevealWindow: some View {
        VStack(spacing: 4) {
            Text("NEXT REVEAL")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .tracking(1)
            
            if let photo = nextRevealPhoto {
                ZStack {
                    // Blurred preview
                    if let uiImage = UIImage(data: photo.imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .blur(radius: 20)
                            .overlay(
                                // Film grain noise
                                Rectangle()
                                    .fill(
                                        ImagePaint(
                                            image: Image(systemName: "camera.metering.matrix"),
                                            scale: 0.1
                                        )
                                    )
                                    .opacity(0.3)
                                    .blendMode(.overlay)
                            )
                            .brightness(-0.4) // Darkroom effect
                            .saturation(0.5)
                    }
                    
                    // Countdown timer
                    VStack(spacing: 2) {
                        Text(timeRemainingString)
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(limeGreen)
                            .shadow(color: .black, radius: 2, x: 0, y: 0)
                        
                        Text("REVEAL IN")
                            .font(.system(size: 6, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                            .tracking(1)
                    }
                }
                .frame(width: 80, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(limeGreen.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: limeGreen.opacity(0.2), radius: 8, x: 0, y: 0)
            }
        }
    }
    
    private var timeRemainingString: String {
        let interval = timeUntilNextReveal
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private var limeGreen: Color {
        Color(red: 0, green: 1, blue: 0.255)
    }
    
    // MARK: - Viewfinder Area
    
    private func viewfinderArea(geometry: GeometryProxy) -> some View {
        let screenWidth = geometry.size.width
        let viewfinderHeight = screenWidth * 2 / 3 // 3:2 aspect ratio
        
        return ZStack {
            // Camera preview (3:2 crop)
            EnhancedCameraPreviewView(session: camera.session)
                .frame(width: screenWidth, height: viewfinderHeight)
                .clipShape(Rectangle())
            
            // Viewfinder corners (3:2 frame)
            viewfinderCorners
                .frame(width: screenWidth, height: viewfinderHeight)
            
            // Grid lines (rule of thirds)
            gridOverlay
                .frame(width: screenWidth, height: viewfinderHeight)
                .opacity(0.3)
        }
        .background(Color.black)
        .overlay(
            // Matte black bars (top and bottom)
            VStack(spacing: 0) {
                matteBlackBar
                Spacer()
                matteBlackBar
            }
            .allowsHitTesting(false)
        )
    }
    
    private var viewfinderCorners: some View {
        GeometryReader { geo in
            let size = geo.size
            let cornerLength: CGFloat = 30
            
            ZStack {
                // Top-left
                Path { path in
                    path.move(to: CGPoint(x: 20, y: 20 + cornerLength))
                    path.addLine(to: CGPoint(x: 20, y: 20))
                    path.addLine(to: CGPoint(x: 20 + cornerLength, y: 20))
                }
                .stroke(limeGreen, lineWidth: 2)
                
                // Top-right
                Path { path in
                    path.move(to: CGPoint(x: size.width - 20 - cornerLength, y: 20))
                    path.addLine(to: CGPoint(x: size.width - 20, y: 20))
                    path.addLine(to: CGPoint(x: size.width - 20, y: 20 + cornerLength))
                }
                .stroke(limeGreen, lineWidth: 2)
                
                // Bottom-left
                Path { path in
                    path.move(to: CGPoint(x: 20, y: size.height - 20 - cornerLength))
                    path.addLine(to: CGPoint(x: 20, y: size.height - 20))
                    path.addLine(to: CGPoint(x: 20 + cornerLength, y: size.height - 20))
                }
                .stroke(limeGreen, lineWidth: 2)
                
                // Bottom-right
                Path { path in
                    path.move(to: CGPoint(x: size.width - 20 - cornerLength, y: size.height - 20))
                    path.addLine(to: CGPoint(x: size.width - 20, y: size.height - 20))
                    path.addLine(to: CGPoint(x: size.width - 20, y: size.height - 20 - cornerLength))
                }
                .stroke(limeGreen, lineWidth: 2)
            }
        }
    }
    
    private var gridOverlay: some View {
        GeometryReader { geo in
            let size = geo.size
            
            ZStack {
                // Vertical lines
                Path { path in
                    path.move(to: CGPoint(x: size.width / 3, y: 0))
                    path.addLine(to: CGPoint(x: size.width / 3, y: size.height))
                    path.move(to: CGPoint(x: size.width * 2 / 3, y: 0))
                    path.addLine(to: CGPoint(x: size.width * 2 / 3, y: size.height))
                }
                .stroke(.white.opacity(0.5), lineWidth: 1)
                
                // Horizontal lines
                Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height / 3))
                    path.addLine(to: CGPoint(x: size.width, y: size.height / 3))
                    path.move(to: CGPoint(x: 0, y: size.height * 2 / 3))
                    path.addLine(to: CGPoint(x: size.width, y: size.height * 2 / 3))
                }
                .stroke(.white.opacity(0.5), lineWidth: 1)
            }
        }
    }
    
    private var matteBlackBar: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.95),
                        Color.black.opacity(0.8),
                        Color.black.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 60)
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        HStack(spacing: 60) {
            // Flash toggle
            Button {
                toggleFlash()
            } label: {
                Image(systemName: flashMode == .off ? "bolt.slash" : "bolt.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(flashMode == .off ? .white.opacity(0.6) : limeGreen)
                    .frame(width: 50, height: 50)
            }
            
            // Capture button
            Button {
                capturePhoto()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .fill(canTakeMorePhotos ? .white : .white.opacity(0.3))
                        .frame(width: 68, height: 68)
                    
                    // ✅ 撮影上限に達した場合は✗マークを表示
                    if !canTakeMorePhotos {
                        Image(systemName: "xmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.red)
                    }
                }
            }
            .disabled(!canTakeMorePhotos) // ✅ 上限に達したら無効化
            
            // Flip camera
            Button {
                camera.flipCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 50, height: 50)
            }
        }
    }
    
    // MARK: - Camera Actions
    
    private func capturePhoto() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Flash animation
        withAnimation(.easeInOut(duration: 0.15)) {
            showCaptureAnimation = true
        }
        
        // Capture and hide flash
        camera.capturePhoto { image in
            capturedImage = image
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation {
                    showCaptureAnimation = false
                }
                showPreview = true
            }
        }
    }
    
    private func toggleFlash() {
        flashMode = flashMode == .off ? .on : .off
        camera.setFlashMode(flashMode)
    }
    
    private func savePhoto() {
        guard let image = capturedImage, let user = currentUser else { return }
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        let unlockDate = Calendar.current.date(byAdding: .hour, value: 12, to: Date()) ?? Date()
        
        let photo = LaterPhoto(
            imageData: imageData,
            captureDate: Date(),
            unlockDate: unlockDate,
            owner: user,
            caption: caption.isEmpty ? nil : caption
        )
        
        context.insert(photo)
        try? context.save()
        
        // 保存した写真を保持してキャプション入力画面を表示
        savedPhoto = photo
        showPreview = false
        
        // 少し遅延してからキャプション入力を表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showCaptionInput = true
        }
    }
    
    private func retakePhoto() {
        capturedImage = nil
        caption = ""
    }
    
    // MARK: - Time Updater
    
    private func startTimeUpdater() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }
}

// MARK: - Camera Manager

@MainActor
class CameraManager: NSObject, ObservableObject {
    // ✅ iOS 26対応: AVCaptureSessionはMainActorで管理
    @Published var session = AVCaptureSession()
    @Published var isAuthorized = false
    
    private var photoOutput = AVCapturePhotoOutput()
    private var currentCamera: AVCaptureDevice.Position = .back
    private var captureCompletion: ((UIImage) -> Void)?
    
    override init() {
        super.init()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    Task { @MainActor [weak self] in
                        self?.setupCamera()
                    }
                }
            }
        default:
            break
        }
    }
    
    private func setupCamera() {
        session.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCamera),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        session.commitConfiguration()
        
        Task {
            session.startRunning()
            isAuthorized = true
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        captureCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func flipCamera() {
        currentCamera = currentCamera == .back ? .front : .back
        
        session.beginConfiguration()
        
        // Remove existing inputs
        session.inputs.forEach { session.removeInput($0) }
        
        // Add new input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCamera),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        session.commitConfiguration()
    }
    
    func setFlashMode(_ mode: AVCaptureDevice.FlashMode) {
        // Flash mode will be set in photo settings during capture
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        
        captureCompletion?(image)
    }
}

// MARK: - Camera Preview View (EnhancedCameraView)

private struct EnhancedCameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Capture Preview View

struct CapturePreviewView: View {
    let image: UIImage
    @Binding var caption: String
    let onSave: () -> Void
    let onRetake: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isCaptionFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Preview image (3:2 aspect)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(3/2, contentMode: .fit)
                
                Spacer()
                
                // Caption input
                VStack(spacing: 16) {
                    Text("Add a caption (optional)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    TextField("", text: $caption, prompt: Text("Your memory...").foregroundColor(.white.opacity(0.4)))
                        .font(.system(size: 16, design: .serif))
                        .foregroundStyle(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color(red: 0, green: 1, blue: 0.255).opacity(0.3), lineWidth: 1)
                                )
                        )
                        .focused($isCaptionFocused)
                        .submitLabel(.done)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                
                // Action buttons
                HStack(spacing: 20) {
                    Button {
                        onRetake()
                        dismiss()
                    } label: {
                        Text("Retake")
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.15))
                            )
                    }
                    
                    Button {
                        onSave()
                    } label: {
                        Text("Save")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(red: 0, green: 1, blue: 0.255))
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EnhancedCameraView()
        .modelContainer(for: [UserProfile.self, LaterPhoto.self], inMemory: true)
}

