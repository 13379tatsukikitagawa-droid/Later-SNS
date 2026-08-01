import SwiftUI
import SwiftUI
import AVFoundation

// MARK: - ⚠️ 重要: Info.plistへの追加が必要
// このQRスキャナーを使用する前に、Info.plistに以下のキーを追加してください：
// Key: Privacy - Camera Usage Description (NSCameraUsageDescription)
// Value: QRコードをスキャンして友達を追加するためにカメラを使用します

// MARK: - QRスキャナービュー
/// AVFoundationを使用してQRコードをスキャンするビュー

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("themeColor") private var themeColorName: String = "green"
    
    // スキャン結果のコールバック
    let onScanComplete: (String) -> Void
    
    // カメラの状態管理
    @State private var cameraPermission: CameraPermission = .notDetermined
    @State private var scannedCode: String?
    @State private var showScannedAlert = false
    @State private var isScanning = true
    
    // テーマカラー
    private var themeColor: Color {
        switch themeColorName {
        case "green": return .brandGreen
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        default: return .brandGreen
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color.black.ignoresSafeArea()
                
                // カメラ権限に応じてビューを切り替え
                switch cameraPermission {
                case .authorized:
                    // カメラビュー
                    cameraView
                    
                case .denied:
                    // 権限が拒否された場合
                    permissionDeniedView
                    
                case .notDetermined:
                    // 権限がまだ確認されていない場合
                    ProgressView()
                        .tint(.white)
                }
            }
            .navigationTitle("QRコードスキャン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                            Text("閉じる")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundStyle(.white)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // トーチ（フラッシュライト）の切り替え
                        toggleTorch()
                    } label: {
                        Image(systemName: "flashlight.on.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .onAppear {
                checkCameraPermission()
            }
            .alert("QRコード検出", isPresented: $showScannedAlert) {
                Button("OK") {
                    if let code = scannedCode {
                        onScanComplete(code)
                        dismiss()
                    }
                }
                Button("再スキャン", role: .cancel) {
                    isScanning = true
                    scannedCode = nil
                }
            } message: {
                if let code = scannedCode {
                    Text("QRコードを検出しました:\n\(code)")
                }
            }
        }
    }
    
    // MARK: - カメラビュー
    
    private var cameraView: some View {
        ZStack {
            // カメラプレビュー
            QRCodeCameraView(
                isScanning: $isScanning,
                scannedCode: $scannedCode,
                onCodeScanned: handleCodeScanned
            )
            .ignoresSafeArea()
            
            // スキャンガイドのオーバーレイ
            scanGuideOverlay
            
            // 下部の説明テキスト
            VStack {
                Spacer()
                
                instructionText
                    .padding(.bottom, 60)
            }
        }
    }
    
    // スキャンガイドのオーバーレイ
    private var scanGuideOverlay: some View {
        ZStack {
            // 暗いオーバーレイ（中央を除く）
            GeometryReader { geometry in
                let squareSize: CGFloat = min(geometry.size.width, geometry.size.height) * 0.7
                let cornerRadius: CGFloat = 24
                
                // 全体を暗くするオーバーレイ
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .frame(width: squareSize, height: squareSize)
                                    .blendMode(.destinationOut)
                            )
                    )
                
                // スキャンエリアのフレーム
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        // 角のインジケーター付きフレーム
                        ZStack {
                            // 角のインジケーター
                            CornerIndicators(
                                size: squareSize,
                                cornerLength: 30,
                                cornerWidth: 4,
                                color: themeColor
                            )
                            
                            // スキャンライン（アニメーション）
                            if isScanning {
                                ScanningLine(color: themeColor)
                                    .frame(width: squareSize - 40, height: 2)
                            }
                        }
                        .frame(width: squareSize, height: squareSize)
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    // 説明テキスト
    private var instructionText: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 20))
                    .foregroundStyle(themeColor)
                
                Text("QRコードをフレーム内に合わせてください")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
            
            Text("自動的にスキャンされます")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
        )
    }
    
    // MARK: - 権限が拒否された場合のビュー
    
    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill.badge.ellipsis")
                .font(.system(size: 80))
                .foregroundStyle(.white.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("カメラへのアクセスが必要です")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("QRコードをスキャンするには、\nカメラへのアクセスを許可してください")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Button {
                openAppSettings()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gear")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("設定を開く")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [themeColor, themeColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: themeColor.opacity(0.4), radius: 15, x: 0, y: 8)
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
    
    // MARK: - アクション
    
    // カメラ権限をチェック
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermission = .authorized
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermission = granted ? .authorized : .denied
                }
            }
            
        case .denied, .restricted:
            cameraPermission = .denied
            
        @unknown default:
            cameraPermission = .denied
        }
    }
    
    // QRコードがスキャンされた時の処理
    private func handleCodeScanned(_ code: String) {
        // スキャンを一時停止
        isScanning = false
        scannedCode = code
        
        // ハプティクスフィードバック
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // アラートを表示
        showScannedAlert = true
        
        print("✅ QRコードをスキャンしました: \(code)")
    }
    
    // トーチ（フラッシュライト）を切り替え
    private func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else {
            return
        }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = device.torchMode == .on ? .off : .on
            device.unlockForConfiguration()
        } catch {
            print("❌ トーチの切り替えに失敗: \(error.localizedDescription)")
        }
    }
    
    // アプリの設定画面を開く
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - カメラ権限の状態
enum CameraPermission {
    case authorized
    case denied
    case notDetermined
}

// MARK: - QRコードカメラビュー（UIViewRepresentable）
struct QRCodeCameraView: UIViewRepresentable {
    @Binding var isScanning: Bool
    @Binding var scannedCode: String?
    let onCodeScanned: (String) -> Void
    
    func makeUIView(context: Context) -> QRCodeCameraPreviewView {
        let view = QRCodeCameraPreviewView()
        view.delegate = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: QRCodeCameraPreviewView, context: Context) {
        if isScanning {
            uiView.startScanning()
        } else {
            uiView.stopScanning()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let parent: QRCodeCameraView
        
        init(parent: QRCodeCameraView) {
            self.parent = parent
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            // スキャン中でなければ無視
            guard parent.isScanning else { return }
            
            // QRコードを検出
            if let metadataObject = metadataObjects.first,
               let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
               let stringValue = readableObject.stringValue {
                
                // メインスレッドで処理
                DispatchQueue.main.async {
                    self.parent.scannedCode = stringValue
                    self.parent.onCodeScanned(stringValue)
                }
            }
        }
    }
}

// MARK: - カメラプレビュービュー（UIView）
class QRCodeCameraPreviewView: UIView {
    weak var delegate: AVCaptureMetadataOutputObjectsDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCamera()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCamera()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    // カメラのセットアップ
    private func setupCamera() {
        let session = AVCaptureSession()
        
        // カメラデバイスを取得
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("❌ カメラデバイスが見つかりません")
            return
        }
        
        // 入力を設定
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            print("❌ カメラ入力の作成に失敗しました")
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            print("❌ カメラ入力を追加できません")
            return
        }
        
        // メタデータ出力を設定
        let metadataOutput = AVCaptureMetadataOutput()
        
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            
            // QRコードのみを検出
            metadataOutput.metadataObjectTypes = [.qr]
            
            // デリゲートを設定
            metadataOutput.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
        } else {
            print("❌ メタデータ出力を追加できません")
            return
        }
        
        // プレビューレイヤーを設定
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = bounds
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
        
        self.captureSession = session
        self.previewLayer = previewLayer
    }
    
    // スキャンを開始
    func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    // スキャンを停止
    func stopScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
}

// MARK: - スキャンエリアの角のインジケーター
struct CornerIndicators: View {
    let size: CGFloat
    let cornerLength: CGFloat
    let cornerWidth: CGFloat
    let color: Color
    
    var body: some View {
        ZStack {
            // 左上
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: cornerWidth / 2)
                        .fill(color)
                        .frame(width: cornerLength, height: cornerWidth)
                    Spacer()
                }
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: cornerWidth / 2)
                        .fill(color)
                        .frame(width: cornerWidth, height: cornerLength)
                    Spacer()
                }
                Spacer()
            }
            
            // 右上
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer()
                    RoundedRectangle(cornerRadius: cornerWidth / 2)
                        .fill(color)
                        .frame(width: cornerLength, height: cornerWidth)
                }
                HStack(spacing: 0) {
                    Spacer()
                    RoundedRectangle(cornerRadius: cornerWidth / 2)
                        .fill(color)
                        .frame(width: cornerWidth, height: cornerLength)
                }
                Spacer()
            }
            
            // 左下
            VStack(spacing: 0) {
                Spacer()
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: cornerWidth / 2)
                        .fill(color)
                        .frame(width: cornerWidth, height: cornerLength)
                    Spacer()
                }
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: cornerWidth / 2)
                        .fill(color)
                        .frame(width: cornerLength, height: cornerWidth)
                    Spacer()
                }
            }
            
            // 右下
            VStack(spacing: 0) {
                Spacer()
                HStack(spacing: 0) {
                    Spacer()
                    RoundedRectangle(cornerRadius: cornerWidth / 2)
                        .fill(color)
                        .frame(width: cornerWidth, height: cornerLength)
                }
                HStack(spacing: 0) {
                    Spacer()
                    RoundedRectangle(cornerRadius: cornerWidth / 2)
                        .fill(color)
                        .frame(width: cornerLength, height: cornerWidth)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - スキャンライン（アニメーション）
struct ScanningLine: View {
    let color: Color
    @State private var offset: CGFloat = -150
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [color.opacity(0), color, color.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .offset(y: offset)
            .onAppear {
                withAnimation(
                    .linear(duration: 2.0)
                    .repeatForever(autoreverses: false)
                ) {
                    offset = 150
                }
            }
    }
}

// MARK: - プレビュー
#Preview {
    QRScannerView { code in
        print("Scanned: \(code)")
    }
}
