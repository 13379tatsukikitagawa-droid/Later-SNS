import SwiftUI
import AVFoundation
import CoreLocation
internal import Combine

// MARK: - アップロード前の画像圧縮
//
// AVCapturePhotoOutputが返す生データ(フルサイズHEIC/JPEG、機種によっては
// 1枚あたり数MB〜十数MB)を無圧縮のままCKAssetとしてアップロードしていたため、
// 解禁後に他メンバーの端末へ画像が届くまでの送信が遅くなったり、モバイル回線等で
// 途中で失敗しやすくなったりする一因になっていた。長辺を上限まで縮小し、
// JPEG(quality 0.8)へ再エンコードしてからLaterPhoto.imageDataとして使う。
enum CapturedImageCompressor {
    private static let maxCapturedImageDimension: CGFloat = 1600

    static func compressedImageData(from data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let resized = resizedIfNeeded(image, maxDimension: maxCapturedImageDimension)
        return resized.jpegData(compressionQuality: 0.8) ?? data
    }

    private static func resizedIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension else { return image }
        let scale = maxDimension / longestSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - 現在地の地名取得(CoreLocation)
//
// 許可が無い場合・取得や逆ジオコーディングに失敗した場合はplaceNameがnilのまま
// なので、呼び出し側は地名なしで保存するだけでよい。

final class CameraLocationNameProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var placeName: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestPlaceName() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self, error == nil, let placemark = placemarks?.first else { return }
            self.placeName = placemark.locality ?? placemark.subLocality ?? placemark.name
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 取得失敗時はplaceNameをnilのままにし、タグを非表示にする。
    }
}

// MARK: - AVCaptureSession管理(UIKit、プレビューレイヤーとフラッシュ/撮影のみを担当)

final class FilmCameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var captureCompletion: ((Data?) -> Void)?

    /// 現在アクティブなカメラ(前面/背面)。switchCamera()で切り替わる。
    @Published private(set) var cameraPosition: AVCaptureDevice.Position = .back

    func configure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted { DispatchQueue.main.async { self?.setupSession() } }
            }
        default: break
        }
    }

    private func setupSession() {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        addInput(for: cameraPosition)
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    /// 前面(内カメラ/自撮り)と背面カメラを切り替える。既存の入力を外してから
    /// 新しいデバイスの入力に差し替えるだけで、出力(photoOutput)やプレビュー層は
    /// そのまま使い回せる(セッション自体の再起動は不要)。
    ///
    /// まだsetupSession()が完了していない場合は、実機のセッションを操作せず
    /// cameraPositionの値だけ更新する(setupSession()実行時にこの値が使われる)。
    func setCameraPosition(_ newPosition: AVCaptureDevice.Position) {
        guard cameraPosition != newPosition else { return }
        guard !session.inputs.isEmpty else {
            cameraPosition = newPosition
            return
        }
        session.beginConfiguration()
        for input in session.inputs {
            session.removeInput(input)
        }
        addInput(for: newPosition)
        session.commitConfiguration()
        cameraPosition = newPosition
    }

    private func addInput(for position: AVCaptureDevice.Position) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            print("FilmCameraController: カメラデバイスが見つかりません(position: \(position))")
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
        } catch {
            print("FilmCameraController: failed to configure session: \(error)")
        }
    }

    /// 撮影画面を閉じた時にセッションを止める。stopRunning()は完全に停止するまで
    /// ブロックするため、メインスレッドでは呼ばない。
    func stopSession() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.stopRunning()
        }
    }

    func capturePhoto(flashOn: Bool, completion: @escaping (Data?) -> Void) {
        captureCompletion = completion
        let settings = AVCapturePhotoSettings()
        // 前面カメラにはフラッシュが無いため、背面カメラの時だけフラッシュ設定を適用する。
        if cameraPosition == .back, photoOutput.supportedFlashModes.contains(flashOn ? .on : .off) {
            settings.flashMode = flashOn ? .on : .off
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension FilmCameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            print("[PhotoSave Error] AVCapturePhotoOutput処理失敗: \(error)")
        }
        guard error == nil, let data = photo.fileDataRepresentation() else {
            if error == nil {
                print("[PhotoSave Error] photo.fileDataRepresentation()がnilを返却(画像データ化に失敗)")
            }
            captureCompletion?(nil)
            captureCompletion = nil
            return
        }
        captureCompletion?(data)
        captureCompletion = nil
    }
}

// MARK: - プレビューレイヤーのホスト(UIViewのlayerClassをAVCaptureVideoPreviewLayerにする
// 標準的な手法。frameの手動同期が不要になり、回転・リサイズにも自動追従する)

struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
