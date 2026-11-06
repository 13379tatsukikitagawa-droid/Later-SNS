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
    private let position: AVCaptureDevice.Position = .back
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

    func stop() {
        dispatchPrecondition(condition: .onQueue(.main))
        stopsWhenIdle = false
        wantsRunning = false
        startToken = UUID()
        if status == .ready || status == .failed { status = .idle }
        // 撮影の途中で閉じたら、完了を待たずに終わらせる(フラグを必ず戻す)
        if let id = currentCaptureID { finishCapture(id: id, image: nil) }
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
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
            if self.audioConfigured { completion(true); return }
            guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
                  let mic = AVCaptureDevice.default(for: .audio),
                  let input = try? AVCaptureDeviceInput(device: mic) else { completion(false); return }
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
            self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
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

// MARK: - 撮影画面

struct CaptureScreen: View {
    @ObservedObject var camera: CaptureCameraModel
    let layout: CaptureLayout
    let tags: [String]
    let place: String?
    /// 今日のこり(撮る前の値)
    let left: Int
    let haptics: ExposureHaptics
    /// タグ画面から、カードがひろがって入ってきた(③ の登場)
    var playsEntrance = true
    /// 戻る(Home へ)
    var onBack: () -> Void = {}
    /// 長押しが 1.0 になった(長押し・音量ボタン長押し・VoiceOver の操作のどれでも、ここを通る)。
    /// 写真は待たない。絞り・フラッシュ・凍結した絵・撮影は、CaptureFlow がその1フレームで始める(ブリンク → フラッシュ → ミルク色のチェキ)
    var onShutter: () -> Void = {}
    /// v20:動画モード(写真のシャッターを隠し、音量ボタンは「押している間だけ録画」)
    var isVideoMode = false
    var onVideoVolume: (Bool) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var hold = HoldShutter()
    /// v18.2:音量ボタンの「ここで撮れる」は初回だけ
    @AppStorage("capture.volumeEdgeHintSeen") private var volumeEdgeHintSeen = false
    @State private var lastVolumePress: Date?
    /// 左はしの光(1回押し = 光るだけ / 2回押し = 強く光って撮る)
    @State private var edgeFlash = 0
    @State private var edgeStrong = false
    @State private var showsEdgeHint = false

    @State private var appeared = false
    @State private var bump = false
    @State private var isFiring = false
    @State private var message: String?
    @State private var messageToken = UUID()
    @State private var holdStart: Date?

    private var p: CGFloat { hold.progress }
    private var finder: CGRect { layout.finder }
    private var holdingEffects: Bool { p > 0 && !reduceMotion }

    var body: some View {
        ZStack(alignment: .topLeading) {
            CaptureTint.cameraBG

            finderView
                .frame(width: finder.width, height: finder.height)
                .offset(x: finder.minX, y: finder.minY)

            topBar

            if camera.status != .denied {
                shutterArea
                    .opacity(isVideoMode ? 0 : 1)
                    .allowsHitTesting(!isVideoMode)
            }

            if let message {
                messagePill(message)
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .ignoresSafeArea()
        .statusBarHidden()
        .onAppear(perform: appear)
        .onDisappear {
            hold.end()
            haptics.cancelHold()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { hold.end() }
        }
        .onChange(of: hold.stage) { _, stage in
            guard stage > 0, hold.isHolding else { return }
            bump = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { bump = false }
        }
    }

    // MARK: ファインダー

    private var finderView: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return ZStack {
            ZStack {
                CaptureCameraPreview(
                    session: camera.session,
                    volumeEnabled: camera.status == .ready,
                    onVolumePress: { if isVideoMode { onVideoVolume(true) } else { volumePressed() } },
                    onVolumeRelease: { if isVideoMode { onVideoVolume(false) } }
                )
                .opacity(camera.status == .ready ? 1 : 0)

                if holdingEffects {
                    TimelineView(.periodic(from: .now, by: 0.1)) { context in
                        GrainView(seed: Int(context.date.timeIntervalSinceReferenceDate * 10))
                            .blendMode(.overlay)
                            .opacity(0.26 * Double(p))
                    }
                }
            }
            .brightness(0.11 * Double(p))
            .scaleEffect(reduceMotion ? 1 : 1 + 0.012 * p)
            .blur(radius: appeared || !playsEntrance || reduceMotion ? 0 : 12)
            .scaleEffect(appeared || !playsEntrance || reduceMotion ? 1 : 1.07)

            vignette

            statusOverlay

            cornerMarks
                .padding(22)
                .scaleEffect(appeared || !playsEntrance || reduceMotion ? 1 : 1.6)
                .opacity(appeared || !playsEntrance ? 1 : 0)
                .allowsHitTesting(false)

            // 日付スタンプ(今の日時。1分ごと)。写真には焼きつけない
            dateStamp
                .opacity(chromeOpacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 22)
                .padding(.bottom, 58)
                .allowsHitTesting(false)

            tagTapes
                .opacity(chromeOpacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 22)
                .padding(.bottom, 16)
                .allowsHitTesting(false)

            // 左はし:音量ボタンのための光(どの機種でも同じ場所。上から 150pt・長さ 250pt)
            VolumeEdgeGlow(flash: edgeFlash, strong: edgeStrong, hint: showsEdgeHint, reduceMotion: reduceMotion)
                .opacity(chromeOpacity)
                .allowsHitTesting(false)
        }
        .clipShape(shape)
    }

    /// ふちを暗く。ながおし中は濃くなり、どくどく脈うつ
    private var vignette: some View {
        TimelineView(.animation(paused: !holdingEffects)) { context in
            let pulse: Double = {
                guard holdingEffects, let holdStart else { return 1 }
                let phase = HoldShutter.heartbeatPhase(elapsed: context.date.timeIntervalSince(holdStart))
                return 0.9 + 0.1 * sin(phase)
            }()
            let strength = (0.42 + 0.4 * Double(reduceMotion ? 0 : p)) * pulse
            RadialGradient(
                colors: [.clear, .black.opacity(min(0.95, strength))],
                center: .center,
                startRadius: min(finder.width, finder.height) * 0.32,
                endRadius: max(finder.width, finder.height) * 0.62
            )
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch camera.status {
        case .ready:
            EmptyView()
        case .idle:
            Text("準備中")
                .font(.system(size: 13, weight: .bold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.6))
        case .denied:
            VStack(spacing: 14) {
                Text("カメラが使えません")
                    .font(.system(size: 17, weight: .heavy))
                Text("設定アプリで、Later のカメラを\n許可してください。")
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } label: {
                    Text("設定をひらく")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 22)
                        .frame(height: 44)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
        case .failed:
            VStack(spacing: 14) {
                Text("カメラを開けませんでした")
                    .font(.system(size: 17, weight: .heavy))
                Button {
                    camera.retry()
                } label: {
                    Text("もう一度")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 22)
                        .frame(height: 44)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
        }
    }

    private var cornerMarks: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                CornerMark()
                    .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(width: 18, height: 18)
                    .rotationEffect(.degrees(Double(index) * 90))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: [.topLeading, .topTrailing, .bottomTrailing, .bottomLeading][index])
            }
        }
    }

    private var dateStamp: some View {
        TimelineView(.everyMinute) { context in
            Text(CaptureClock.stamp(context.date))
                .font(CaptureFont.mono(14))
                .foregroundStyle(CaptureTint.stamp)
                .shadow(color: CaptureTint.stamp.opacity(0.8), radius: 4)
                .shadow(color: CaptureTint.orange.opacity(0.5), radius: 9)
        }
        .mask(alignment: .leading) {
            // 左から右へ打ち出される
            Rectangle().scaleEffect(x: appeared || !playsEntrance || reduceMotion ? 1 : 0, anchor: .leading)
        }
    }

    private var tagTapes: some View {
        let items: [DymoTape.Kind] = (place.map { [.place($0)] } ?? []) + tags.map { .word($0) }
        return ViewThatFits(in: .horizontal) {
            tapeRow(items, maxWidth: 210)
            tapeRow(items, maxWidth: 118)
        }
        .frame(maxWidth: finder.width - 44, alignment: .leading)
    }

    private func tapeRow(_ items: [DymoTape.Kind], maxWidth: CGFloat) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, kind in
                DymoTape(kind: kind, height: 28, fontSize: 12.5, maxWidth: maxWidth)
            }
        }
    }

    // MARK: 上の行(戻る・のこり窓)

    private var topBar: some View {
        HStack {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.12)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("戻る")

            Spacer()

            leftWindow
        }
        .padding(.horizontal, 18)
        .frame(width: layout.size.width)
        .offset(y: max(14, layout.safeTop - 8))
        .opacity(chromeOpacity)
        .offset(y: appeared || !playsEntrance || reduceMotion ? 0 : -12)
        .opacity(appeared || !playsEntrance ? 1 : 0)
    }

    /// のこりの表示はここだけ(下のFILM帯は作らない)
    private var leftWindow: some View {
        HStack(spacing: 7) {
            Text("LEFT")
                .font(CaptureFont.mono(9))
                .foregroundStyle(.white.opacity(0.5))
            Text(String(format: "%02d", left))
                .font(CaptureFont.mono(17))
                .foregroundStyle(CaptureTint.orange)
                .shadow(color: CaptureTint.orange.opacity(0.75), radius: 4)
                .frame(width: 42, height: 28)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.black))
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(height: 40)
        .background(Capsule().fill(CaptureTint.leftBox))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("のこり \(left) こま")
    }

    private var chromeOpacity: Double { 1 - 0.68 * Double(p) }

    // MARK: シャッター

    private var shutterArea: some View {
        VStack(spacing: 6) {
            ShutterButtonView(progress: p, bump: bump, reduceMotion: reduceMotion)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in hold.begin() }
                        .onEnded { _ in hold.end() }
                )
                .accessibilityElement()
                .accessibilityLabel("撮る")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { accessibilityFire() }
                .offset(y: appeared || !playsEntrance || reduceMotion ? 0 : 44)

            Text(HoldShutter.hint(for: p))
                .font(.system(size: 12.5, weight: .medium))
                .tracking(0.75)
                .foregroundStyle(.white.opacity(p > 0 ? 1 : 0.62))
                .animation(.easeOut(duration: 0.15), value: HoldShutter.stage(for: p))
                .opacity(appeared || !playsEntrance ? 1 : 0)
        }
        .position(x: layout.shutterCenter.x, y: layout.shutterCenter.y + 14)
    }

    // MARK: 動き

    private func appear() {
        configureHold()
        if playsEntrance && !reduceMotion {
            // 520ms(タグ画面のカードがひろがる途中)から、ピントが合うように出る
            withAnimation(FlowMotion.out(0.85)) { appeared = true }
        } else {
            withAnimation(.easeOut(duration: 0.25)) { appeared = true }
        }
        // 初回だけ:ボタンの位置から「ここで撮れる」
        if !volumeEdgeHintSeen {
            volumeEdgeHintSeen = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { showsEdgeHint = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
                withAnimation(.easeOut(duration: 0.4)) { showsEdgeHint = false }
            }
        }
    }

    private func configureHold() {
        hold.canStart = {
            camera.status == .ready && !camera.isCapturing && !isFiring && left > 0
        }
        hold.onRefused = {
            if left <= 0 {
                haptics.playSoftDouble()
                showMessage("今日は、ここまで\n\(FilmRoll.shotsPerDay)こま、撮りました")
            }
        }
        hold.onBegin = {
            holdStart = Date()
            haptics.beginHold(duration: hold.duration, intensity: 0.15...0.85, sharpness: 0.2...0.55)
        }
        hold.onCancel = {
            holdStart = nil
            haptics.cancelHold()
        }
        hold.onStage = { stage in
            haptics.captureKot(stage: stage)
        }
        hold.onFire = { fire() }
    }

    /// 音量ボタン:0.5秒以内の2回押しで、写真を1枚。1回だけなら、左はしが光るだけ
    private func volumePressed() {
        let now = Date()
        if let last = lastVolumePress, now.timeIntervalSince(last) <= VolumeShutterRules.doublePressWindow {
            lastVolumePress = nil
            edgeStrong = true
            edgeFlash += 1
            Haptics.play(.click)
            guard hold.canStart() else {
                if left <= 0 { Haptics.play(.warn) }
                hold.onRefused()
                return
            }
            fire()
        } else {
            lastVolumePress = now
            edgeStrong = false
            edgeFlash += 1
        }
    }

    private func accessibilityFire() {
        guard hold.canStart() else {
            hold.onRefused()
            return
        }
        fire()
    }

    /// p = 1:その場で撮影後へ(写真・保存は待たない)。takePhoto は CaptureFlow が、同じフレームで裏で呼ぶ
    private func fire() {
        guard !isFiring else { return }
        isFiring = true
        holdStart = nil
        haptics.cancelHold()
        CaptureSignpost.shutter()   // ① ② ③ の起点
        onShutter()
    }

    private func back() {
        hold.end()
        haptics.cancelHold()
        isFiring = false
        onBack()
    }

    private func showMessage(_ text: String) {
        let token = UUID()
        messageToken = token
        withAnimation(.easeOut(duration: 0.2)) { message = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            guard messageToken == token else { return }
            withAnimation(.easeOut(duration: 0.25)) { message = nil }
        }
    }

    private func messagePill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .foregroundStyle(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Capsule().fill(.white))
            .frame(width: layout.size.width)
            .offset(y: finder.midY - 24)
            .transition(.opacity)
            .allowsHitTesting(false)
    }
}

/// 四隅の目印「┌」(角丸6)。回して4つ使う
struct CornerMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r: CGFloat = 6
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}


/// 音量ボタンで撮る決めごと
enum VolumeShutterRules {
    /// この時間以内の2回押しで撮る
    static let doublePressWindow: TimeInterval = 0.5
    /// 左はしの光(上から・長さ)
    static let edgeTop: CGFloat = 150
    static let edgeLength: CGFloat = 250

    /// 2回目が、まだ 2回押しになるか
    static func isDoublePress(previous: Date?, now: Date) -> Bool {
        guard let previous else { return false }
        return now.timeIntervalSince(previous) <= doublePressWindow
    }
}

/// 左はしの細い朝焼け色の帯(ゆっくり明るく暗く)+ 縦書き「VOL ×2」。押すと光る。初回だけ「ここで撮れる」
private struct VolumeEdgeGlow: View {
    let flash: Int
    let strong: Bool
    let hint: Bool
    let reduceMotion: Bool

    @State private var boost = 0.0

    var body: some View {
        ZStack(alignment: .topLeading) {
            TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let breath = reduceMotion ? 0.5 : 0.5 + 0.5 * sin(t * 2 * .pi / 3.2)
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: "FFB36A"), Color(hex: "FF6A3D"), Color(hex: "FF5DA2"), Color(hex: "9A7CFF")], startPoint: .top, endPoint: .bottom))
                    .frame(width: 3, height: VolumeShutterRules.edgeLength)
                    .shadow(color: Color(hex: "FF6A3D").opacity(0.8 * (0.4 + boost)), radius: 6 + 10 * boost)
                    .opacity(0.25 + 0.35 * breath + 0.4 * boost)
            }
            .padding(.top, VolumeShutterRules.edgeTop)
            Text("VOL ×2")
                .font(.system(size: 8.5, weight: .regular, design: .monospaced))
                .tracking(0.24 * 8.5)
                .foregroundStyle(.white.opacity(0.45))
                .fixedSize()
                .rotationEffect(.degrees(90))
                .frame(width: 12, height: 50)
                .padding(.leading, 6)
                .padding(.top, VolumeShutterRules.edgeTop + VolumeShutterRules.edgeLength / 2 - 25)
            if hint {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 11, weight: .bold))
                    Text("ここで撮れる ・ 2回おす").font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(Capsule().fill(.white))
                .padding(.leading, 24)
                .padding(.top, VolumeShutterRules.edgeTop + VolumeShutterRules.edgeLength / 2 - 15)
                .transition(.offset(x: -40).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea()
        .onChange(of: flash) { _, _ in
            withAnimation(.easeOut(duration: 0.08)) { boost = strong ? 1 : 0.6 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { withAnimation(.easeOut(duration: 0.5)) { boost = 0 } }
        }
        .accessibilityHidden(true)
    }
}
