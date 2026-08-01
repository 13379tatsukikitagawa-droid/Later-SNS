import SwiftUI
import AVFoundation
internal import Combine

/// カメラを使用したQRコードスキャナービュー（代替実装）
struct QRCodeScannerViewAlt: View {
    let onScan: (String) -> Void
    let onDismiss: () -> Void
    
    @StateObject private var viewModel = QRScannerViewModelAlt()
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // カメラプレビュー
            CameraPreviewViewAlt(session: viewModel.session)
                .ignoresSafeArea()
            
            // オーバーレイUI
            VStack {
                // ヘッダー
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4)
                    }
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
                
                // スキャンフレーム
                scanFrame
                
                Spacer()
                
                // インストラクション
                VStack(spacing: 12) {
                    Text("QRコードをフレーム内に収めてください")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                    
                    if viewModel.isScanning {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.brandGreen)
                            Text("スキャン中...")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            
            // エラー表示
            if showError {
                VStack {
                    Spacer()
                    errorBanner
                        .padding(.horizontal, 24)
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            viewModel.startScanning()
        }
        .onDisappear {
            viewModel.stopScanning()
        }
        .onChange(of: viewModel.scannedCode) { oldValue, newValue in
            if let code = newValue {
                handleScannedCode(code)
            }
        }
        .onChange(of: viewModel.errorMessage) { oldValue, newValue in
            if let error = newValue {
                errorMessage = error
                withAnimation(.spring(response: 0.3)) {
                    showError = true
                }
                
                // 3秒後にエラーを非表示
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.spring(response: 0.3)) {
                        showError = false
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var scanFrame: some View {
        GeometryReader { geometry in
            ZStack {
                // 暗いオーバーレイ（スキャンエリア以外）
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 300, height: 300)
                    .mask {
                        Rectangle()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .frame(width: 300, height: 300)
                                    .blendMode(.destinationOut)
                            }
                    }
                
                // スキャンフレーム（グリーンの枠）
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.brandGreen,
                                Color.brandGreen.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 300, height: 300)
                    .shadow(color: .brandGreen.opacity(0.5), radius: 10)
                
                // コーナーインジケーター
                scanCorners
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    private var scanCorners: some View {
        ZStack {
            ForEach(0..<4) { index in
                cornerIndicator
                    .rotationEffect(.degrees(Double(index) * 90))
                    .offset(x: index % 2 == 0 ? -145 : 145, y: index < 2 ? -145 : 145)
            }
        }
    }
    
    private var cornerIndicator: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.brandGreen)
                .frame(width: 4, height: 30)
            Rectangle()
                .fill(Color.brandGreen)
                .frame(width: 30, height: 4)
                .offset(y: -4)
        }
    }
    
    private var errorBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.red)
            
            Text(errorMessage)
                .font(.subheadline)
                .foregroundStyle(.white)
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.red.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.red.opacity(0.5), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Actions
    
    private func handleScannedCode(_ code: String) {
        // ハプティクスフィードバック
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // コードを処理
        onScan(code)
        
        // スキャンを一時停止
        viewModel.pauseScanning()
        
        // 1秒後に再開
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            viewModel.resumeScanning()
        }
    }
}

// MARK: - QRスキャナーViewModel

@MainActor
class QRScannerViewModelAlt: NSObject, ObservableObject {
    @Published var scannedCode: String?
    @Published var isScanning = false
    @Published var errorMessage: String?
    
    // ⚠️ AVCaptureSession は Sendable ではないため、nonisolated(unsafe) を使用
    nonisolated(unsafe) let session = AVCaptureSession()
    private var isSessionRunning = false
    private var videoDevice: AVCaptureDevice?
    
    override init() {
        super.init()
        checkPermissions()
    }
    
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
                } else {
                    DispatchQueue.main.async {
                        self?.errorMessage = "カメラへのアクセスが拒否されました"
                    }
                }
            }
        case .denied, .restricted:
            errorMessage = "カメラへのアクセスが必要です。設定から許可してください。"
        @unknown default:
            errorMessage = "カメラへのアクセスエラー"
        }
    }
    
    private func setupCamera() {
        session.beginConfiguration()
        
        // カメラデバイスを取得
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            errorMessage = "カメラデバイスが見つかりません"
            session.commitConfiguration()
            return
        }
        
        self.videoDevice = videoDevice
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            } else {
                errorMessage = "カメラ入力を追加できません"
                session.commitConfiguration()
                return
            }
            
            let metadataOutput = AVCaptureMetadataOutput()
            
            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            } else {
                errorMessage = "メタデータ出力を追加できません"
                session.commitConfiguration()
                return
            }
            
            session.commitConfiguration()
        } catch {
            errorMessage = "カメラのセットアップに失敗しました: \(error.localizedDescription)"
            session.commitConfiguration()
        }
    }
    
    func startScanning() {
        guard !isSessionRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = true
                self?.isScanning = true
            }
        }
    }
    
    func stopScanning() {
        guard isSessionRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = false
                self?.isScanning = false
            }
        }
    }
    
    func pauseScanning() {
        isScanning = false
    }
    
    func resumeScanning() {
        isScanning = true
        scannedCode = nil
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRScannerViewModelAlt: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else {
            return
        }
        
        Task { @MainActor in
            // スキャン中のみ処理
            guard self.isScanning else { return }
            
            // Later アプリのQRコードかチェック
            if stringValue.hasPrefix("laterapp://") {
                self.scannedCode = stringValue
            } else {
                self.errorMessage = "無効なQRコードです"
            }
        }
    }
}

// MARK: - カメラプレビューView

struct CameraPreviewViewAlt: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // レイヤーのサイズを更新
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

// MARK: - Preview

#Preview("QRスキャナー（代替）") {
    QRCodeScannerViewAlt(
        onScan: { code in
            print("Scanned: \(code)")
        },
        onDismiss: {}
    )
}
