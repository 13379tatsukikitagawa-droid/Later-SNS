import SwiftUI
import SwiftUI
import AVFoundation
import CoreImage
import AudioToolbox

// MARK: - QRコードスキャナービュー
/// QRコードをスキャンして他のユーザーと繋がるためのカメラビュー
struct QRCodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scannedCode: String?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var cameraPermission: CameraPermissionStatus = .notDetermined
    
    // スキャン成功時のコールバック
    let onScanSuccess: (String) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                switch cameraPermission {
                case .authorized:
                    // カメラビュー
                    cameraView
                    
                case .denied, .restricted:
                    // 権限が拒否された場合の画面
                    permissionDeniedView
                    
                case .notDetermined:
                    // 権限をチェック中
                    ProgressView("カメラを準備中...")
                        .tint(.white)
                        .foregroundStyle(.white)
                }
            }
            .navigationTitle("QRコードをスキャン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .alert("スキャン結果", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text(alertMessage)
            }
            .task {
                await checkCameraPermission()
            }
        }
    }
    
    // MARK: - サブビュー
    
    private var cameraView: some View {
        ZStack {
            // カメラプレビュー
            ScannerView(
                scannedCode: $scannedCode,
                shouldContinueScanning: Binding(
                    get: { scannedCode == nil },
                    set: { _ in }
                )
            )
            .ignoresSafeArea()
            
            // オーバーレイ
            scannerOverlay
        }
        .onChange(of: scannedCode) { oldValue, newValue in
            if let code = newValue {
                handleScannedCode(code)
            }
        }
    }
    
    private var scannerOverlay: some View {
        VStack {
            Spacer()
                .frame(height: 100)
            
            // スキャンエリアのフレーム
            VStack(spacing: 20) {
                // 角丸のフレーム
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white, lineWidth: 3)
                    .frame(width: 280, height: 280)
                    .overlay(
                        // コーナーのアクセント
                        ForEach(0..<4) { index in
                            CornerAccent(position: CornerPosition.allCases[index])
                        }
                    )
                
                // 説明テキスト
                VStack(spacing: 8) {
                    Text("QRコードをフレーム内に収めてください")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("友達のQRコードを読み取ってフォローできます")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 40)
                .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // ヒントカード
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("ヒント")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    Text("明るい場所でスキャンすると認識されやすくなります")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.1))
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            // アイコン
            Image(systemName: "camera.fill.badge.ellipsis")
                .font(.system(size: 64))
                .foregroundStyle(.gray)
                .symbolEffect(.pulse, options: .repeating)
            
            // メッセージ
            VStack(spacing: 12) {
                Text("カメラへのアクセスが必要です")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("QRコードをスキャンするには、カメラの使用を許可してください。")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // 設定画面へのボタン
            Button {
                openSettings()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gear")
                        .font(.body.weight(.semibold))
                    
                    Text("設定を開く")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .blue.opacity(0.4), radius: 12, x: 0, y: 4)
            }
            
            // 手動での説明
            VStack(alignment: .leading, spacing: 12) {
                Text("設定方法")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                VStack(alignment: .leading, spacing: 8) {
                    InstructionStep(number: 1, text: "設定アプリを開く")
                    InstructionStep(number: 2, text: "このアプリを選択")
                    InstructionStep(number: 3, text: "「カメラ」をオンにする")
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - メソッド
    
    /// カメラの権限をチェック
    private func checkCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            await MainActor.run {
                cameraPermission = .authorized
            }
            
        case .notDetermined:
            // 権限をリクエスト
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run {
                cameraPermission = granted ? .authorized : .denied
            }
            
        case .denied:
            await MainActor.run {
                cameraPermission = .denied
            }
            
        case .restricted:
            await MainActor.run {
                cameraPermission = .restricted
            }
            
        @unknown default:
            await MainActor.run {
                cameraPermission = .denied
            }
        }
    }
    
    /// スキャンされたコードを処理
    private func handleScannedCode(_ code: String) {
        // ハプティクフィードバック
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // コールバックを実行
        onScanSuccess(code)
        
        // アラートを表示
        alertMessage = "ユーザーID: \(code)\nをスキャンしました！"
        showingAlert = true
    }
    
    /// 設定画面を開く
    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - QRコードスキャナー With My QR Code（拡張版）
/// QRコードスキャナーに「My QR Code」ボタンを追加したバージョン
struct QRCodeScannerWithMyCode: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scannedCode: String?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var cameraPermission: CameraPermissionStatus = .notDetermined
    
    // スキャン成功時のコールバック
    let onScanSuccess: (String) -> Void
    let onShowMyQRCode: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                switch cameraPermission {
                case .authorized:
                    // カメラビュー
                    cameraView
                    
                case .denied, .restricted:
                    // 権限が拒否された場合の画面
                    permissionDeniedView
                    
                case .notDetermined:
                    // 権限をチェック中
                    ProgressView("カメラを準備中...")
                        .tint(.white)
                        .foregroundStyle(.white)
                }
            }
            .navigationTitle("QRコードをスキャン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                
                // 右上に「My QR」ボタンを追加
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticsManager.swipeFeedback()
                        dismiss()
                        // 少し遅延してから表示（dismissの完了を待つ）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onShowMyQRCode()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 16, weight: .semibold))
                            Text("My QR")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.brandGreen.opacity(0.3))
                        )
                    }
                }
            }
            .alert("スキャン結果", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text(alertMessage)
            }
            .task {
                await checkCameraPermission()
            }
        }
    }
    
    // MARK: - サブビュー
    
    private var cameraView: some View {
        ZStack {
            // カメラプレビュー
            ScannerView(
                scannedCode: $scannedCode,
                shouldContinueScanning: Binding(
                    get: { scannedCode == nil },
                    set: { _ in }
                )
            )
            .ignoresSafeArea()
            
            // オーバーレイ
            scannerOverlay
        }
        .onChange(of: scannedCode) { oldValue, newValue in
            if let code = newValue {
                handleScannedCode(code)
            }
        }
    }
    
    private var scannerOverlay: some View {
        VStack {
            Spacer()
                .frame(height: 100)
            
            // スキャンエリアのフレーム
            VStack(spacing: 20) {
                // 角丸のフレーム
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white, lineWidth: 3)
                    .frame(width: 280, height: 280)
                    .overlay(
                        // コーナーのアクセント
                        ForEach(0..<4) { index in
                            CornerAccent(position: CornerPosition.allCases[index])
                        }
                    )
                
                // 説明テキスト
                VStack(spacing: 8) {
                    Text("QRコードをフレーム内に収めてください")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("友達のQRコードを読み取ってフォローできます")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 40)
                .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // ヒントカード（「My QR Code」ボタンも統合）
            VStack(spacing: 12) {
                // ヒントカード
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.title3)
                        .foregroundStyle(.yellow)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ヒント")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        
                        Text("明るい場所でスキャンすると認識されやすくなります")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            // アイコン
            Image(systemName: "camera.fill.badge.ellipsis")
                .font(.system(size: 64))
                .foregroundStyle(.gray)
                .symbolEffect(.pulse, options: .repeating)
            
            // メッセージ
            VStack(spacing: 12) {
                Text("カメラへのアクセスが必要です")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("QRコードをスキャンするには、カメラの使用を許可してください。")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // 設定画面へのボタン
            Button {
                openSettings()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gear")
                        .font(.body.weight(.semibold))
                    
                    Text("設定を開く")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .blue.opacity(0.4), radius: 12, x: 0, y: 4)
            }
            
            // 手動での説明
            VStack(alignment: .leading, spacing: 12) {
                Text("設定方法")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                VStack(alignment: .leading, spacing: 8) {
                    InstructionStep(number: 1, text: "設定アプリを開く")
                    InstructionStep(number: 2, text: "このアプリを選択")
                    InstructionStep(number: 3, text: "「カメラ」をオンにする")
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - メソッド
    
    /// カメラの権限をチェック
    private func checkCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            await MainActor.run {
                cameraPermission = .authorized
            }
            
        case .notDetermined:
            // 権限をリクエスト
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run {
                cameraPermission = granted ? .authorized : .denied
            }
            
        case .denied:
            await MainActor.run {
                cameraPermission = .denied
            }
            
        case .restricted:
            await MainActor.run {
                cameraPermission = .restricted
            }
            
        @unknown default:
            await MainActor.run {
                cameraPermission = .denied
            }
        }
    }
    
    /// スキャンされたコードを処理
    private func handleScannedCode(_ code: String) {
        // ハプティクフィードバック
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // コールバックを実行
        onScanSuccess(code)
        
        // アラートを表示
        alertMessage = "ユーザーID: \(code)\nをスキャンしました！"
        showingAlert = true
    }
    
    /// 設定画面を開く
    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - カメラ権限のステータス
enum CameraPermissionStatus {
    case notDetermined
    case authorized
    case denied
    case restricted
}

// MARK: - スキャナービュー（UIViewControllerRepresentable）
struct ScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Binding var shouldContinueScanning: Bool
    
    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        if shouldContinueScanning {
            uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(scannedCode: $scannedCode)
    }
    
    class Coordinator: NSObject, ScannerViewControllerDelegate {
        @Binding var scannedCode: String?
        
        init(scannedCode: Binding<String?>) {
            self._scannedCode = scannedCode
        }
        
        func didFindCode(_ code: String) {
            scannedCode = code
        }
        
        func didSurfaceError(_ error: ScannerError) {
            print("❌ Scanner error: \(error.localizedDescription)")
        }
    }
}

// MARK: - スキャナーエラー
enum ScannerError: Error {
    case invalidDeviceInput
    case invalidScannedValue
    case cameraUnavailable
    
    var localizedDescription: String {
        switch self {
        case .invalidDeviceInput:
            return "カメラデバイスにアクセスできませんでした"
        case .invalidScannedValue:
            return "無効なQRコードです"
        case .cameraUnavailable:
            return "カメラが利用できません"
        }
    }
}

// MARK: - スキャナービューコントローラー
protocol ScannerViewControllerDelegate: AnyObject {
    func didFindCode(_ code: String)
    func didSurfaceError(_ error: ScannerError)
}

class ScannerViewController: UIViewController {
    weak var delegate: ScannerViewControllerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isScanning = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }
    
    // MARK: - セットアップ
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession else {
            delegate?.didSurfaceError(.cameraUnavailable)
            return
        }
        
        // カメラデバイスを取得
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.didSurfaceError(.cameraUnavailable)
            return
        }
        
        // 入力デバイスを設定
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            delegate?.didSurfaceError(.invalidDeviceInput)
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            delegate?.didSurfaceError(.invalidDeviceInput)
            return
        }
        
        // メタデータ出力を設定
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            delegate?.didSurfaceError(.invalidDeviceInput)
            return
        }
        
        // プレビューレイヤーを設定
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
    }
    
    // MARK: - スキャン制御
    
    func startScanning() {
        guard let captureSession = captureSession, !isScanning else { return }
        
        isScanning = true
        
        // バックグラウンドスレッドでセッションを開始
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
    }
    
    func stopScanning() {
        guard let captureSession = captureSession, isScanning else { return }
        
        isScanning = false
        
        // バックグラウンドスレッドでセッションを停止
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.stopRunning()
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension ScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        // スキャン中でない場合は無視
        guard isScanning else { return }
        
        // QRコードを検出
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           metadataObject.type == .qr,
           let stringValue = metadataObject.stringValue {
            
            // スキャンを一時停止
            isScanning = false
            
            // バイブレーション
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            
            // デリゲートに通知
            delegate?.didFindCode(stringValue)
        }
    }
}

// MARK: - コーナーアクセント
private struct CornerAccent: View {
    let position: CornerPosition
    
    var body: some View {
        GeometryReader { geometry in
            let length: CGFloat = 30
            let lineWidth: CGFloat = 4
            
            Path { path in
                switch position {
                case .topLeft:
                    // 左上
                    path.move(to: CGPoint(x: 0, y: length))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: length, y: 0))
                    
                case .topRight:
                    // 右上
                    path.move(to: CGPoint(x: geometry.size.width - length, y: 0))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: length))
                    
                case .bottomLeft:
                    // 左下
                    path.move(to: CGPoint(x: 0, y: geometry.size.height - length))
                    path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: length, y: geometry.size.height))
                    
                case .bottomRight:
                    // 右下
                    path.move(to: CGPoint(x: geometry.size.width - length, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height - length))
                }
            }
            .stroke(Color.green, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
    }
}

private enum CornerPosition: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight
}

// MARK: - 設定手順ステップ
private struct InstructionStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            // 番号バッジ
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color.blue)
                )
            
            // テキスト
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            
            Spacer()
        }
    }
}

// MARK: - プレビュー
#Preview("QR Code Scanner") {
    QRCodeScannerView { code in
        print("スキャンされたコード: \(code)")
    }
}

#Preview("Permission Denied State") {
    struct PermissionDeniedPreview: View {
        var body: some View {
            NavigationStack {
                ZStack {
                    Color.brandBlack.ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        Image(systemName: "camera.fill.badge.ellipsis")
                            .font(.system(size: 64))
                            .foregroundStyle(.gray)
                        
                        VStack(spacing: 12) {
                            Text("カメラへのアクセスが必要です")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            
                            Text("QRコードをスキャンするには、カメラの使用を許可してください。")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        
                        Button {
                            // 設定画面へ
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "gear")
                                Text("設定を開く")
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                        }
                    }
                }
                .navigationTitle("QRコードをスキャン")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    return PermissionDeniedPreview()
}
