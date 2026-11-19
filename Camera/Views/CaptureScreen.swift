// CaptureScreen.swift
// 撮影画面(7章)と、カメラの中身(7-5)。いつも黒い画面。外カメラだけ。
//
// 固まらないための決めごと(3章)
// - セッションの設定・startRunning・stopRunning は、すべて sessionQueue(直列)で行う。メインでは呼ばない
// - 起動は1度だけ(wantsRunning)。古い起動の完了は UUID トークンで無視する
// - 権限の確認が終わるまで映像は出さない。3秒たっても動かなければ「カメラを開けませんでした」
// - 割り込み(電話など)・バックグラウンドからの復帰で再開する
// - takePhoto は二重呼び出しを止め、デリゲートは撮り終わるまで保持し、5秒で時間切れ(UUIDトークン)
// - 画面を閉じたら、かならず stop()(緑の点が消える)
//
// 注意:Info の NSCameraUsageDescription は pbxproj の INFOPLIST_KEY で設定済み。

import SwiftUI
internal import Combine
import AVFoundation
import AVKit
import UIKit
import CoreImage

// MARK: - 映像を出す View

final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        fatalError("storyboard は使いません")
    }
}

/// (GroupCircleViews.swift の CameraPreview と名前が重なるため、CaptureCameraPreview にしている)
/// 音量ボタン(v18.2):AVCaptureEventInteraction をこの View に付ける(撮影画面のなかだけ)。0.5秒以内の2回押しで写真。VolumeButtonMonitor は使わない。
struct CaptureCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var volumeEnabled = true
    var onVolumePress: () -> Void = {}
    var onVolumeRelease: () -> Void = {}

    final class Coordinator {
        var onPress: () -> Void = {}
        var onRelease: () -> Void = {}
        var interaction: AVCaptureEventInteraction?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        // セッションを渡すだけ(起動は待たない)
        view.previewLayer.session = session
        let coordinator = context.coordinator
        let interaction = AVCaptureEventInteraction { event in
            switch event.phase {
            case .began: coordinator.onPress()
            case .ended, .cancelled: coordinator.onRelease()
            @unknown default: coordinator.onRelease()
            }
        }
        view.addInteraction(interaction)
        coordinator.interaction = interaction
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        context.coordinator.onPress = onVolumePress
        context.coordinator.onRelease = onVolumeRelease
        context.coordinator.interaction?.isEnabled = volumeEnabled
    }

    static func dismantleUIView(_ uiView: CameraPreviewUIView, coordinator: Coordinator) {
        if let interaction = coordinator.interaction { uiView.removeInteraction(interaction) }
        coordinator.interaction = nil
        uiView.previewLayer.session = nil
    }
}

// MARK: - カメラの処理

nonisolated final class CaptureCameraModel: NSObject, ObservableObject, @unchecked Sendable {
    enum Status: Equatable {
        case idle        // まだ起動していない・準備中
        case ready       // 映像が出ている
        case denied      // 許可されていない
        case failed      // 起動できなかった
    }

    /// 外カメラ(背面)だけを使う。切りかえはない
    /// v87:内カメラ。sessionQueue の 中だけで 読み書き
    private var position: AVCaptureDevice.Position = .back
    @Published private(set) var cameraPosition: AVCaptureDevice.Position = .back
    /// 起動してから、これだけ待っても動かなければ「開けませんでした」
    static let startTimeout: TimeInterval = 3
    /// 撮影の時間切れ
    static let captureTimeout: TimeInterval = 5

    // ここから下の @Published と状態は、メインスレッドでだけ触る
    @Published private(set) var status: Status = .idle
    @Published private(set) var isCapturing = false
    private var wantsRunning = false
    private var startToken = UUID()
    private var pendingCompletion: ((CapturedShot?) -> Void)?
    /// 撮影が終わったら止める(撮影後の演出が終わったが、写真がまだ返っていない)
    private var stopsWhenIdle = false
    private var currentCaptureID: UUID?
    /// 撮り終わるまで保持するデリゲート
    private var inFlight: [UUID: PhotoDelegate] = [:]
    private var observers: [NSObjectProtocol] = []

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "later.capture.session")
    private let photoOutput = AVCapturePhotoOutput()
    /// 凍結した絵(長押し完了の1フレーム)を取るための、映像の最新フレーム。
    /// AVCaptureVideoPreviewLayer の snapshotView は黒くなることがあるので使わない
    private let videoOutput = AVCaptureVideoDataOutput()
    /// v20:動画モード(RETRO-8 の加工・録画)。カメラのフレームを、ここへも渡す
    let recorder = RetroRecorder()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let audioQueue = DispatchQueue(label: "later.capture.audio", qos: .userInitiated)
    /// sessionQueue でだけ触る
    private var audioConfigured = false
    private let frameQueue = DispatchQueue(label: "later.capture.frames", qos: .userInteractive)
    private let frameLock = NSLock()
    /// frameLock の中でだけ触る
    private var latestFrame: CVPixelBuffer?
    private lazy var ciContext = CIContext(options: [.cacheIntermediates: false])
    /// sessionQueue でだけ触る
    private var configured = false

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    // MARK: 起動と停止(メインから呼ぶ)

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !wantsRunning else { return }   // 二重に起動しない
        wantsRunning = true
        installObserversIfNeeded()
        let token = UUID()
        startToken = token
        if status != .ready { status = .idle }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run(token: token)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self, self.wantsRunning, self.startToken == token else { return }
                    if granted { self.run(token: token) } else { self.status = .denied }
                }
            }
        default:
            status = .denied
        }
    }

    /// 撮影の途中なら、写真が返る(または5秒の時間切れ)まで待ってから止める。そうでなければ、すぐ止める
    func stopWhenIdle() {
        dispatchPrecondition(condition: .onQueue(.main))
        if isCapturing {
            stopsWhenIdle = true
        } else {
            stop()
        }
    }

    /// 止める(stopRunning は sessionQueue で。メインでは 待たない)。onStopped は 止まりきったとき(sessionQueue)
    func stop(onStopped: (@Sendable () -> Void)? = nil) {
        dispatchPrecondition(condition: .onQueue(.main))
        stopsWhenIdle = false
        wantsRunning = false
        startToken = UUID()
        if status == .ready || status == .failed { status = .idle }
        // 撮影の途中で閉じたら、完了を待たずに終わらせる(フラグを必ず戻す)
        if let id = currentCaptureID { finishCapture(id: id, image: nil) }
        sessionQueue.async { [weak self, session] in
            if session.isRunning { session.stopRunning() }
            // マイクを 使っていたら、ほかのアプリの 音を もどす
            if self?.audioConfigured == true {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
            onStopped?()
        }
    }

    /// 動画の録音中も バイブを 鳴らせる オーディオセッション(sessionQueue で 呼ぶ)
    nonisolated static func configureRecordingAudio() {
        let audio = AVAudioSession.sharedInstance()
        do {
            try audio.setCategory(.playAndRecord, mode: .videoRecording, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothA2DP])
            try audio.setAllowHapticsAndSystemSoundsDuringRecording(true)
            try audio.setActive(true)
        } catch {
            print("[Capture] オーディオセッションの 設定に 失敗: \(error)")
        }
    }

    /// 「もう一度」
    func retry() {
        stop()
        start()
    }

    private func run(token: UUID) {
        // 3秒たっても動かなければ、失敗として「もう一度」を出す
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.startTimeout) { [weak self] in
            guard let self, self.wantsRunning, self.startToken == token, self.status == .idle else { return }
            self.status = .failed
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                guard self.buildSession() else {
                    DispatchQueue.main.async {
                        guard self.startToken == token else { return }
                        self.status = .failed
                    }
                    return
                }
                self.configured = true
            }
            // 前に マイクを つないでいたら、録音中も バイブが 鳴る 設定に もどしてから 動かす
            if self.audioConfigured { Self.configureRecordingAudio() }
            if !self.session.isRunning { self.session.startRunning() }
            let running = self.session.isRunning
            DispatchQueue.main.async {
                guard self.wantsRunning, self.startToken == token else {
                    // 起動の途中で閉じられた:止めなおす
                    if !self.wantsRunning { self.sessionQueue.async { if self.session.isRunning { self.session.stopRunning() } } }
                    return
                }
                self.status = running ? .ready : .failed
            }
        }
    }

    /// sessionQueue の中で呼ぶ
    private func buildSession() -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input),
            session.canAddOutput(photoOutput)
        else { return false }
        session.addInput(input)
        session.addOutput(photoOutput)
        if let connection = photoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90   // 縦向きの写真
        }
        // 凍結した絵のための映像(足せない機種では足さない。そのときは、凍結の絵の代わりに白い紙)
        if session.canAddOutput(videoOutput) {
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
            session.addOutput(videoOutput)
            if let connection = videoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90   // 写真と同じ向き
            }
        }
        return true
    }

    // MARK: 凍結した絵

    /// 最新のフレームを、写真と同じ切りとり(縦3:4・中央)の UIImage にする。重い処理はメインの外。完了はメインで返す
    /// v20:マイクをつなぐ(許可があるときだけ。動画モードに切りかえたとき)。断られていたら、音なしで録る
    func enableAudio(completion: @escaping @Sendable (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { completion(false); return }
            if self.audioConfigured { Self.configureRecordingAudio(); completion(true); return }
            guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
                  let mic = AVCaptureDevice.default(for: .audio),
                  let input = try? AVCaptureDeviceInput(device: mic) else { completion(false); return }
            // マイクを つなぐ前に、オーディオセッションを 自分で 決める。
            // カメラに 任せる(automaticallyConfiguresApplicationAudioSession = true)と、録音の間 iOS が バイブを 止める
            self.session.automaticallyConfiguresApplicationAudioSession = false
            Self.configureRecordingAudio()
            self.session.beginConfiguration()
            if self.session.canAddInput(input) { self.session.addInput(input) }
            if self.session.canAddOutput(self.audioOutput) {
                self.audioOutput.setSampleBufferDelegate(self, queue: self.audioQueue)
                self.session.addOutput(self.audioOutput)
                self.audioConfigured = true
            }
            self.session.commitConfiguration()
            completion(self.audioConfigured)
        }
    }

    /// 外カメ ⇄ 内カメ(sessionQueue の 上で 入れかえる。メインでは 待たない)。撮影画面を ひらく たびに 外カメから
    func setCameraPosition(_ new: AVCaptureDevice.Position) {
        DispatchQueue.main.async { [weak self] in if self?.cameraPosition != new { self?.cameraPosition = new } }
        sessionQueue.async { [weak self] in
            guard let self, self.position != new else { return }
            self.position = new
            guard self.configured || self.session.inputs.contains(where: { ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.video) == true }) else { return }
            self.session.beginConfiguration()
            for input in self.session.inputs where (input as? AVCaptureDeviceInput)?.device.hasMediaType(.video) == true { self.session.removeInput(input) }
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: new), let input = try? AVCaptureDeviceInput(device: device), self.session.canAddInput(input) { self.session.addInput(input) }
            for out in [self.photoOutput as AVCaptureOutput, self.videoOutput] {
                if let c = out.connection(with: .video) { if c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }; if c.isVideoMirroringSupported { c.automaticallyAdjustsVideoMirroring = false; c.isVideoMirrored = (new == .front) } }
            }
            self.session.commitConfiguration()
        }
    }

    func useBackCameraIfNeeded() { setCameraPosition(.back) }

    func snapshotLatestFrame(completion: @escaping (UIImage?) -> Void) {
        frameQueue.async { [weak self] in
            guard let self else { return }
            self.frameLock.lock()
            let buffer = self.latestFrame
            self.frameLock.unlock()
            var result: UIImage?
            if let buffer {
                var image = CIImage(cvPixelBuffer: buffer)
                let crop = CapturedShot.centeredCropRect(width: image.extent.width, height: image.extent.height, aspect: CapturedShot.displayAspect)
                image = image.cropped(to: crop.integral.offsetBy(dx: image.extent.minX, dy: image.extent.minY))
                let longest = max(image.extent.width, image.extent.height)
                let scale = min(1, CapturedShot.displayMaxPixel / max(1, longest))
                if scale < 1 { image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) }
                if let cg = self.ciContext.createCGImage(image, from: image.extent) {
                    let ui = UIImage(cgImage: cg)
                    result = ui.preparingForDisplay() ?? ui
                }
            }
            CaptureSignpost.mark("frozenFrame", result == nil ? "none" : "ok")
            DispatchQueue.main.async { completion(result) }
        }
    }

    /// 割り込み・バックグラウンドからの復帰で再開する
    private func installObserversIfNeeded() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        let resume: (Notification) -> Void = { [weak self] _ in
            guard let self, self.wantsRunning else { return }
            self.sessionQueue.async {
                guard self.configured, !self.session.isRunning else { return }
                self.session.startRunning()
                let running = self.session.isRunning
                DispatchQueue.main.async {
                    guard self.wantsRunning else { return }
                    if running { self.status = .ready }
                }
            }
        }
        observers.append(center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: .main, using: resume))
        observers.append(center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: .main, using: resume))
        observers.append(center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main, using: resume))
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            if let id = self.currentCaptureID { self.finishCapture(id: id, image: nil) }
            self.sessionQueue.async { if self.session.isRunning { self.session.stopRunning() } }
        })
    }

    // MARK: 撮影

    /// 待たない。完了は completion で受け取る(失敗・時間切れのときは nil)。メインで返す。
    /// 画面用の画像(切りとり・デコード済み)は、デリゲートの中(メインの外)で作る
    func takePhoto(completion: @escaping (CapturedShot?) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard status == .ready, !isCapturing else {
            completion(nil)
            return
        }
        isCapturing = true
        let id = UUID()
        currentCaptureID = id
        pendingCompletion = completion

        let delegate = PhotoDelegate(
            onImage: { [weak self] shot in
                DispatchQueue.main.async { self?.finishCapture(id: id, image: shot) }
            },
            onDone: { [weak self] in
                DispatchQueue.main.async {
                    self?.finishCapture(id: id, image: nil)
                    self?.inFlight[id] = nil
                }
            }
        )
        inFlight[id] = delegate

        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else {
                delegate.onImage(nil)
                delegate.onDone()
                return
            }
            let settings = AVCapturePhotoSettings()
            // v21:フラッシュ(AUTO / OFF。撮影画面の左のボタン)
            let flashAuto = UserDefaults.standard.object(forKey: "capture.flashAuto") as? Bool ?? true
            if flashAuto, self.photoOutput.supportedFlashModes.contains(.auto) { settings.flashMode = .auto }
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.captureTimeout) { [weak self] in
            self?.finishCapture(id: id, image: nil)
        }
    }

    /// メインで呼ぶ。同じ撮影の2回目以降(古い完了・時間切れのあと)は無視する
    private func finishCapture(id: UUID, image: CapturedShot?) {
        guard currentCaptureID == id, let completion = pendingCompletion else { return }
        pendingCompletion = nil
        currentCaptureID = nil
        isCapturing = false
        completion(image)
        if stopsWhenIdle { stop() }
    }
}

nonisolated extension CaptureCameraModel: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    /// frameQueue。最新の1枚だけを持つ(変換はしない)
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output === audioOutput {
            recorder.handleAudio(sampleBuffer)
            return
        }
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frameLock.lock()
        latestFrame = buffer
        frameLock.unlock()
        // v20:動画モードのときだけ、加工してファインダーと録画へ
        recorder.handleVideo(sampleBuffer)
    }
}

/// 撮り終わるまで保持する、撮影1回ぶんのデリゲート
nonisolated final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let onImage: (CapturedShot?) -> Void
    let onDone: () -> Void

    init(onImage: @escaping (CapturedShot?) -> Void, onDone: @escaping () -> Void) {
        self.onImage = onImage
        self.onDone = onDone
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        CaptureSignpost.mark("photoDelegate", error == nil ? "ok" : "error")   // ② 長押し完了 → デリゲート
        guard error == nil, let data = photo.fileDataRepresentation(), let shot = CapturedShot.make(from: data) else {
            onImage(nil)
            return
        }
        CaptureSignpost.mark("photoDecoded")
        onImage(shot)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        onDone()
    }
}

// MARK: - 絞り(黒い円が中心へせばまる)

struct IrisShape: Shape {
    var radius: CGFloat
    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        let r = max(0, radius)
        path.addEllipse(in: CGRect(x: rect.midX - r, y: rect.midY - r, width: r * 2, height: r * 2))
        return path
    }
}

// MARK: - 粒子(グレイン)

struct GrainView: View {
    let seed: Int

    var body: some View {
        Canvas { context, size in
            var rng = SeededRandom(seed: UInt64(seed &* 7919 &+ 17))
            let count = Int(size.width * size.height / 260)
            for _ in 0..<count {
                let x = CGFloat(rng.next() % 10_000) / 10_000 * size.width
                let y = CGFloat(rng.next() % 10_000) / 10_000 * size.height
                let light = rng.next() % 2 == 0
                context.fill(Path(CGRect(x: x, y: y, width: 1.4, height: 1.4)), with: .color(light ? .white : .black))
            }
        }
        .allowsHitTesting(false)
    }
}

nonisolated struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// 撮影画面は v21 で作り直した:Camera/Services/CaptureScreenV21.swift
