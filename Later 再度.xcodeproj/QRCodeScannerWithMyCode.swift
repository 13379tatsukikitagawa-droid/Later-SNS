import SwiftUI
import AVFoundation

// MARK: - QR Code Scanner with My Code Button
/// QRコードスキャナー画面（My QR Codeボタン付き）

struct QRCodeScannerWithMyCode: View {
    @Environment(\.dismiss) private var dismiss
    let onScanSuccess: (String) -> Void
    let onShowMyQRCode: () -> Void
    
    @State private var isScanning = true
    @State private var scannedCode: String?
    
    var body: some View {
        ZStack {
            // カメラプレビュー
            QRCameraScannerView(isScanning: $isScanning) { code in
                scannedCode = code
                onScanSuccess(code)
                dismiss()
            }
            .ignoresSafeArea()
            
            // オーバーレイ
            VStack {
                // 閉じるボタン
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
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
                
                // スキャンフレーム
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.brandGreen, lineWidth: 4)
                        .frame(width: 280, height: 280)
                    
                    // コーナーマーク
                    ForEach(0..<4, id: \.self) { index in
                        CornerMark()
                            .rotationEffect(.degrees(Double(index) * 90))
                            .frame(width: 280, height: 280)
                    }
                }
                
                Spacer()
                
                // 説明テキスト + My QR Code ボタン
                VStack(spacing: 20) {
                    Text("QRコードをフレーム内に合わせてください")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                    
                    // My QR Code ボタン
                    Button {
                        onShowMyQRCode()
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("My QR Code")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.brandGreen, Color.brandGreen.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.brandGreen.opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Corner Mark
struct CornerMark: View {
    var body: some View {
        VStack {
            HStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 30))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 30, y: 0))
                }
                .stroke(Color.brandGreen, lineWidth: 6)
                .frame(width: 30, height: 30)
                
                Spacer()
            }
            
            Spacer()
        }
    }
}

// MARK: - QR Camera Scanner View
struct QRCameraScannerView: UIViewControllerRepresentable {
    @Binding var isScanning: Bool
    let onCodeScanned: (String) -> Void
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        if isScanning {
            uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned)
    }
    
    class Coordinator: NSObject, QRScannerDelegate {
        let onCodeScanned: (String) -> Void
        
        init(onCodeScanned: @escaping (String) -> Void) {
            self.onCodeScanned = onCodeScanned
        }
        
        func didScanCode(_ code: String) {
            onCodeScanned(code)
        }
    }
}

// MARK: - QR Scanner Delegate
protocol QRScannerDelegate: AnyObject {
    func didScanCode(_ code: String)
}

// MARK: - QR Scanner View Controller
class QRScannerViewController: UIViewController {
    weak var delegate: QRScannerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    private func setupCaptureSession() {
        guard let captureDevice = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: captureDevice) else {
            return
        }
        
        let session = AVCaptureSession()
        session.addInput(input)
        
        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        self.captureSession = session
        self.previewLayer = previewLayer
    }
    
    func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func stopScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
}

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              metadataObject.type == .qr,
              let stringValue = metadataObject.stringValue else {
            return
        }
        
        // スキャン成功
        delegate?.didScanCode(stringValue)
        stopScanning()
    }
}

// MARK: - Preview
#Preview {
    QRCodeScannerWithMyCode(
        onScanSuccess: { code in
            print("Scanned: \(code)")
        },
        onShowMyQRCode: {
            print("Show My QR Code")
        }
    )
}
