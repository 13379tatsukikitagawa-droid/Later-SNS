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
        // グループへの位置の共有用:取った時点で約500mの格子に丸める(正確な位置は持たない)
        let coordinate = location.coordinate
        Task { @MainActor in ApproxLocationCache.set(latitude: coordinate.latitude, longitude: coordinate.longitude) }
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self, error == nil, let placemark = placemarks?.first else { return }
            self.placeName = placemark.locality ?? placemark.subLocality ?? placemark.name
            // Mondo 用:国コード+地域(都道府県レベル)だけ。座標は保存も送信もしない。
            let place = MondoPlace(placemark: placemark)
            Task { @MainActor in MondoPlaceCache.latest = place }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 取得失敗時はplaceNameをnilのままにし、タグを非表示にする。
    }
}

// MARK: - AVCaptureSession管理(UIKit、プレビューレイヤーとフラッシュ/撮影のみを担当)

/// 録れた動画(撮影画面が受け取る)。duration は録画の実際の長さ(秒)。
struct RecordedClip {
    let url: URL
    let duration: TimeInterval
}

nonisolated final class FilmCameraController: NSObject, ObservableObject, @unchecked Sendable {
    /// アプリで1つだけのセッション(開くたびに作り直さない)
    static let shared = FilmCameraController()

    let session = AVCaptureSession()
    /// AVCaptureSession に触る処理は、すべてこの1本のシリアルキューで行う(メインスレッドでは触らない)。
    private let sessionQueue = DispatchQueue(label: "later.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var captureCompletion: ((Data?) -> Void)?
    private var recordingFinished: ((RecordedClip?) -> Void)?
    private var recordingStartedAt: Date?

    // --- セッションキューだけが読み書きする ---
    private var isConfigured = false
    private var queuePosition: AVCaptureDevice.Position = .back

    // --- メインスレッドだけが読み書きする ---
    /// 動かしたい状態(configure で true、stopSession で false)。許可の返事を待つ間に閉じられた時の取りこぼし防止。
    private var wantsRunning = false
    /// 許可のダイアログを出している最中か(二重に求めない)
    private var isRequestingAccess = false

    /// 動画を録れるか(動画の出力が session につながったか)。false のときは写真だけになる
    @Published private(set) var canRecordVideo = false
    /// セッションが動いている(最初の映像が流れ始めた)か。幕を開ける合図に使う。
    @Published private(set) var isRunning = false
    /// カメラの許可がない(拒否・制限)
    @Published private(set) var isAccessDenied = false
    /// 現在アクティブなカメラ(前面/背面)。switchCamera()で切り替わる。
    @Published private(set) var cameraPosition: AVCaptureDevice.Position = .back

    override init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(sessionWasInterrupted),
                           name: AVCaptureSession.wasInterruptedNotification, object: session)
        center.addObserver(forName: AVCaptureSession.didStartRunningNotification, object: session, queue: .main) { [weak self] _ in
            self?.isRunning = true
        }
        center.addObserver(forName: AVCaptureSession.didStopRunningNotification, object: session, queue: .main) { [weak self] _ in
            self?.isRunning = false
        }
    }

    /// 準備(タグ画面が開いた時・撮影画面が開いた時)。ブロックせず、仕事をキューに積むだけ。何度呼んでもよい。
    func configure() {
        wantsRunning = true
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAccessDenied = false
            startAfterMicrophoneDecision()
        case .notDetermined:
            guard !isRequestingAccess else { return }
            isRequestingAccess = true
            print("[PermPerf] カメラの許可を求める(前)")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    print("[PermPerf] カメラの許可の結果 granted=\(granted)")
                    self.isRequestingAccess = false
                    self.isAccessDenied = !granted
                    if granted { self.startAfterMicrophoneDecision() }
                }
            }
        default:
            isAccessDenied = true
        }
    }

    /// 録音の許可は、まだなら求めてから(待たずに)セッションを動かす。拒否されても、撮影は音なしで続く。
    private func startAfterMicrophoneDecision() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                DispatchQueue.main.async { self?.enqueueStart() }
            }
        } else {
            enqueueStart()
        }
    }

    /// 許可のダイアログから戻ったとき・画面に戻ったとき:許可ずみなのにカメラが止まっていたら動かす
    func resumeIfNeeded() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        wantsRunning = true
        enqueueStart()
    }

    /// セッションキューで、組み立て(1回だけ)と startRunning を行う。
    private func enqueueStart() {
        guard wantsRunning else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.setupSessionIfNeeded()
            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    /// セッションキューの上でだけ呼ぶ。
    private func setupSessionIfNeeded() {
        guard !isConfigured else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        addInput(for: queuePosition)
        addMicrophoneInputIfAuthorized()
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            movieOutput.maxRecordedDuration = CMTime(seconds: VideoExposureRules.maxDuration, preferredTimescale: 600)
            if let connection = movieOutput.connection(with: .video), connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .standard
            }
        }
        let canRecord = movieOutput.connection(with: .video) != nil
        session.commitConfiguration()
        // 映像の入力がつながった時だけ「組み立て済み」にする(つながらなければ次の機会にやり直す)
        isConfigured = session.inputs.contains { ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.video) == true }
        DispatchQueue.main.async { [weak self] in self?.canRecordVideo = canRecord }
    }

    /// 前面(内カメラ/自撮り)と背面カメラを切り替える(オンボーディングの撮影だけが使う)。
    /// 組み立て前なら、位置だけ覚えて、組み立て時に使う。
    func setCameraPosition(_ newPosition: AVCaptureDevice.Position) {
        guard cameraPosition != newPosition else { return }
        cameraPosition = newPosition
        sessionQueue.async { [weak self] in
            guard let self, self.queuePosition != newPosition else { return }
            self.queuePosition = newPosition
            guard self.isConfigured else { return }
            self.session.beginConfiguration()
            for input in self.session.inputs where (input as? AVCaptureDeviceInput)?.device.hasMediaType(.video) == true {
                self.session.removeInput(input)
            }
            self.addInput(for: newPosition)
            self.session.commitConfiguration()
        }
    }

    /// 撮影画面は背面カメラだけ。前面のままなら背面にもどす。
    func useBackCameraIfNeeded() {
        setCameraPosition(.back)
    }

    /// セッションキューの上でだけ呼ぶ。
    private func addMicrophoneInputIfAuthorized() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
              let microphone = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: microphone),
              session.canAddInput(input)
        else { return }
        session.addInput(input)
    }

    /// セッションキューの上でだけ呼ぶ。
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

    /// セッションを止める(撮らずにホームへ戻った時・撮影を終えて閉じた時)。キューに積むだけで、ブロックしない。
    func stopSession() {
        wantsRunning = false
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    /// 動画の録画を始める。録音中もバイブが鳴るように、オーディオセッションを設定する。
    /// 結果(録れた動画・失敗時は nil)は、止めた時・15秒で終わった時・中断された時に、必ず1回届く。
    func startVideoRecording(onFinished: @escaping (RecordedClip?) -> Void) {
        guard canRecordVideo, !movieOutput.isRecording else {
            onFinished(nil)
            return
        }
        let audio = AVAudioSession.sharedInstance()
        try? audio.setCategory(.playAndRecord, mode: .videoRecording, options: [.mixWithOthers, .defaultToSpeaker])
        // 録音中は既定でバイブが止まる。撮影の「トン・ふわ・スーッ」を鳴らすために必要
        try? audio.setAllowHapticsAndSystemSoundsDuringRecording(true)
        try? audio.setActive(true)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("exposure-\(UUID().uuidString).mov")
        recordingFinished = onFinished
        recordingStartedAt = Date()
        movieOutput.startRecording(to: url, recordingDelegate: self)
    }

    /// 録画を止める。結果は startVideoRecording の onFinished で届く。
    func stopVideoRecording() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }

    var isRecording: Bool { movieOutput.isRecording }

    /// 電話などで中断されたら、そこまでで止める(判定は撮影画面がする)
    @objc private func sessionWasInterrupted() {
        DispatchQueue.main.async { [weak self] in self?.stopVideoRecording() }
    }

    /// 撮影。フラッシュは、対応していれば自動(.auto)だけ。出力への指示はセッションキューで行う。
    func capturePhoto(completion: @escaping (Data?) -> Void) {
        captureCompletion = completion
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let settings = AVCapturePhotoSettings()
            if self.queuePosition == .back, self.photoOutput.supportedFlashModes.contains(.auto) {
                settings.flashMode = .auto
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension FilmCameraController: AVCapturePhotoCaptureDelegate {
    /// AVFoundation は、この返事をメインスレッド以外で呼ぶ。画像データだけここで作り、
    /// 画面に関わる続き(captureCompletion)はメインスレッドへ戻してから呼ぶ。
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            print("[PhotoSave Error] AVCapturePhotoOutput処理失敗: \(error)")
        }
        let data = error == nil ? photo.fileDataRepresentation() : nil
        if error == nil, data == nil {
            print("[PhotoSave Error] photo.fileDataRepresentation()がnilを返却(画像データ化に失敗)")
        }
        Task { @MainActor in
            self.captureCompletion?(data)
            self.captureCompletion = nil
        }
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

extension FilmCameraController: AVCaptureFileOutputRecordingDelegate {
    /// 15秒の上限に達したときは、ふつうの終わり方として扱う。それ以外の失敗は捨てる。
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        let reachedLimit = (error as? AVError)?.code == .maximumDurationReached
        let usable = error == nil || reachedLimit
        DispatchQueue.main.async { [weak self] in
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            guard let self else {
                try? FileManager.default.removeItem(at: outputFileURL)
                return
            }
            let finished = self.recordingFinished
            let started = self.recordingStartedAt
            self.recordingFinished = nil
            self.recordingStartedAt = nil
            guard usable, let started else {
                print("[Video] 録画が失敗しました: \(String(describing: error))")
                try? FileManager.default.removeItem(at: outputFileURL)
                finished?(nil)
                return
            }
            finished?(RecordedClip(url: outputFileURL, duration: Date().timeIntervalSince(started)))
        }
    }
}
