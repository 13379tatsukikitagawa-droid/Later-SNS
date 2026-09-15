import AVFoundation
internal import Combine

/// 動画撮影専用のAVCaptureSession管理。
///
/// FilmCameraController(写真撮影用)とはあえて別のAVCaptureSessionを持つ。
/// 同一の物理カメラデバイスを2つのAVCaptureSessionが同時に使うことはできない
/// (iOSの制約)ため、動画撮影中だけ写真用セッションを一時停止し、このセッションに
/// 切り替える設計にしている(TrueBlindCameraView側でstartIfNeeded/stopの
/// 呼び出しタイミングを制御する)。
///
/// セッションプリセットに.hd1920x1080を使うことで、4K等の高解像度撮影を避けつつ
/// 標準的な向き・アスペクト比の処理をAVFoundationに任せる(AVVideoWidthKey/HeightKeyの
/// 手動指定は、センサーの向き(landscape)とエンコード時の向き(portrait)の対応を
/// 誤ると映像が歪む/引き伸ばされるリスクがあるため、プリセット任せの方が安全)。
@MainActor
final class VideoCaptureController: NSObject, ObservableObject {
    /// 10秒を超える動画は撮らない(要件)。
    static let maxDuration: TimeInterval = 10
    /// ファイルサイズ・エンコード負荷を抑えるため、フレームレートも30fpsから落とす。
    static let targetFrameRate: Double = 20

    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var recordingCompletion: ((URL?, Error?) -> Void)?

    @Published private(set) var cameraPosition: AVCaptureDevice.Position = .back
    @Published private(set) var isRecording = false
    /// 0.0〜1.0。UIの録画プログレスリング表示用。
    @Published private(set) var recordingProgress: Double = 0
    private var progressTimer: Timer?
    private var recordingStartDate: Date?

    private var isConfigured = false

    /// 呼び出し時点でカメラ/マイクの権限確認〜セッション構築までを行う。
    /// 既にセッションを構築済みなら何もしない(configure()は複数回呼んでも安全)。
    func configure() {
        guard !isConfigured else { return }
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard videoStatus == .authorized || videoStatus == .notDetermined else { return }

        func proceed() {
            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                    DispatchQueue.main.async { self?.setupSession() }
                }
            } else {
                setupSession()
            }
        }

        if videoStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                guard granted else { return }
                DispatchQueue.main.async { proceed() }
            }
        } else {
            proceed()
        }
    }

    /// 【重要】ここでは背面/前面カメラの入力(AVCaptureDeviceInput)をあえて追加しない。
    ///
    /// 実機で録画が毎回失敗していた根本原因はこれだった: 以前はここでカメラの入力を
    /// 即座に追加していたため、TrueBlindCameraView.onAppear内でcamera.configure()
    /// (写真用セッション、同じ物理カメラデバイスの入力を保持し続けたままライブ
    /// プレビューとして走り続ける)の直後にvideoCamera.configure()が呼ばれ、
    /// 「写真用セッションがまだその物理カメラデバイスの入力を保持している状態」で
    /// 動画用セッションが同じデバイスの入力を新たに作ろうとしてしまっていた。
    /// AVCaptureDeviceInput(device:)は、同じAVCaptureDeviceが既に別の入力として
    /// (そのセッションが稼働中か否かに関わらず)使用されていると生成に失敗するため、
    /// try?でnilになり、動画用セッションにカメラ入力が一切追加されないまま
    /// isConfigured=trueになっていた。その結果、録画開始時にはセッションはisRunning=true
    /// (入力ゼロでも起動自体はできてしまう)なのに映像コネクションが存在せず、
    /// movieOutput.startRecordingが実際のAVFoundationエラーで失敗する、という
    /// 「毎回必ず失敗する」不具合になっていた。
    ///
    /// カメラの入力は、実際に録画を始める直前(=写真用セッションが確実に停止し、
    /// 物理カメラデバイスを解放した後)にattachCameraInput()で追加し、録画終了後は
    /// releaseCameraInput()で即座に外す(写真用セッションの再開に間に合わせるため)。
    /// マイク(audioDeviceInput)は写真用セッション側が一切使わないデバイスなので、
    /// ここで先に追加してしまって問題ない。
    private func setupSession() {
        guard !isConfigured else { return }
        isConfigured = true

        session.beginConfiguration()
        // ファイルサイズ・処理負荷を大幅に抑えるため、VGA(640x480)に落とす
        // (レトロな質感を狙う演出上の意図もある)。
        session.sessionPreset = .vga640x480

        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
            audioDeviceInput = audioInput
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        movieOutput.maxRecordedDuration = CMTime(seconds: Self.maxDuration, preferredTimescale: 600)

        session.commitConfiguration()
    }

    /// 写真用セッション(FilmCameraController)が物理カメラデバイスを解放した後、
    /// 実際に録画を始める直前に呼ぶ。videoDeviceInputが既にあれば何もしない
    /// (startRunningIfNeededから毎回呼ばれるため冪等にしておく)。
    private func attachCameraInput() {
        guard videoDeviceInput == nil else { return }
        session.beginConfiguration()
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            videoDeviceInput = input
            Self.applyTargetFrameRate(to: device)
        }
        // 映像コネクションはカメラ入力が実際に追加された後でないと存在しないため、
        // スタビライゼーション/コーデック設定もここで行う(以前はsetupSession側にあったが、
        // その時点ではまだカメラ入力が無く、常にconnectionがnilでこのブロック自体が
        // 素通りされてしまっていた)。
        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .standard
            }
            // AVCaptureMovieFileOutputはHEVCが利用可能な機種ではデフォルトでHEVCを選ぶ。
            // ここでは明示的にH.264を指定し、後段のFilmEmulationVideoExporterでの
            // 再エンコード(H.264/HEVC選択・ビットレート調整)に一本化する
            // (中間ファイルの段階でコーデックを揃えておいた方が扱いやすいため)。
            if movieOutput.availableVideoCodecTypes.contains(.h264) {
                movieOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.h264], for: connection)
            }
        }
        session.commitConfiguration()
    }

    /// 録画終了後、写真用セッション(camera.resumeAfterVideoRecording())が物理カメラ
    /// デバイスを再び使えるように、動画用セッション側のカメラ入力を即座に外す。
    private func releaseCameraInput() {
        guard let videoDeviceInput else { return }
        session.beginConfiguration()
        session.removeInput(videoDeviceInput)
        self.videoDeviceInput = nil
        session.commitConfiguration()
    }

    /// completionは、session.startRunning()が実際に完了した後(=セッションが稼働状態に
    /// なった後)にメインスレッドで呼ばれる。以前はこの完了を待たずに呼び出し元が
    /// videoCamera.startRecording(...)を同期的に呼んでしまっており、セッションが
    /// 稼働する前にmovieOutput.startRecordingが呼ばれる非同期処理の順序不備があった
    /// (「見た目は録画中だが実際には録画が正しく開始されない」不具合の原因)。
    func startRunningIfNeeded(completion: @escaping () -> Void = {}) {
        guard isConfigured else {
            print("[VideoCapture] startRunningIfNeeded: configure()未完了のため開始できません")
            DispatchQueue.main.async(execute: completion)
            return
        }
        // 呼び出し元(TrueBlindCameraView.startVideoRecording)は、写真用セッションを
        // 確実に停止させた後にこれを呼ぶため、ここでカメラ入力を追加しても
        // 物理カメラデバイスの取り合いにならない。
        attachCameraInput()
        guard !session.isRunning else {
            DispatchQueue.main.async(execute: completion)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async(execute: completion)
        }
    }

    /// AVCaptureSession.stopRunning()は完全に停止するまでブロックする仕様のため、
    /// メインスレッドで直接呼ぶとUIハング(ウォッチドッグによる強制終了)の原因になる。
    /// バックグラウンドキューで実行し、完了後にメインスレッドへ戻ってからcompletionを呼ぶ。
    func stopRunning(completion: @escaping () -> Void = {}) {
        guard session.isRunning else {
            // 録画開始に失敗してsession.isRunningがfalseのまま終わるケースでも、
            // attachCameraInput()で追加したカメラ入力が残っていることがあるため、
            // ここで確実に解放しておく(写真用セッションの再開を妨げないため)。
            releaseCameraInput()
            DispatchQueue.main.async(execute: completion)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.releaseCameraInput()
                completion()
            }
        }
    }

    /// 写真用(FilmCameraController)と共有される単一のcameraPosition状態から呼ばれる。
    /// FilmCameraControllerとVideoCaptureControllerがそれぞれ独立にcameraPositionを
    /// 持っていたことが、Video開始時に意図せず背面カメラへ切り替わってしまう不具合の
    /// 原因だったため、切り替えボタン(TrueBlindCameraView.switchCameraButton)は
    /// 両方のコントローラーへ同じpositionを明示的に伝える設計にする。
    /// まだconfigure()が完了していない(isConfigured==false)場合は、実機のセッションを
    /// 操作せずcameraPositionの値だけ更新する(setupSession()実行時にこの値が使われるため、
    /// 後から呼ばれるconfigure()が自然に正しい向きで初期化される)。
    func setCameraPosition(_ newPosition: AVCaptureDevice.Position) {
        guard cameraPosition != newPosition else { return }
        cameraPosition = newPosition
        // 録画していない間(=写真用セッションがまだ物理カメラデバイスを使っている間)は
        // videoDeviceInputはnilのはずなので、ここでは値を更新するだけにとどめる。
        // 次にattachCameraInput()が呼ばれるとき、更新済みのcameraPositionが使われる。
        guard let currentInput = videoDeviceInput else { return }
        session.beginConfiguration()
        session.removeInput(currentInput)
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            videoDeviceInput = input
            Self.applyTargetFrameRate(to: device)
        } else {
            videoDeviceInput = nil
        }
        session.commitConfiguration()
    }

    /// activeFormatはsessionPreset(.vga640x480)に応じてAVFoundationが選ぶため、
    /// ここではその上でフレームレートだけをtargetFrameRateに固定する
    /// (min/max双方を同じ値にすることで可変フレームレートを禁止し、常に20fpsで撮る)。
    private static func applyTargetFrameRate(to device: AVCaptureDevice) {
        guard let range = device.activeFormat.videoSupportedFrameRateRanges.first(where: {
            $0.minFrameRate <= targetFrameRate && targetFrameRate <= $0.maxFrameRate
        }) ?? device.activeFormat.videoSupportedFrameRateRanges.first else { return }
        let clampedRate = min(max(targetFrameRate, range.minFrameRate), range.maxFrameRate)
        let duration = CMTime(value: 1, timescale: CMTimeScale(clampedRate))
        do {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            device.unlockForConfiguration()
        } catch {
            print("[VideoCapture] フレームレート設定に失敗: \(error)")
        }
    }

    /// 撮影開始。呼び出し元は、videoCamera.session が実際にstartRunning()し終わった後
    /// (startRunningIfNeededのcompletion経由)にだけこれを呼ぶこと。一時ファイルへ
    /// 書き出し、最大10秒(maxRecordedDuration)で自動停止する。completionは
    /// (自動停止・手動停止いずれの場合も)録画終了時に1回だけ呼ばれ、失敗時は
    /// 第2引数に実際の原因(Error)を渡す。
    ///
    /// isRecording/recordingProgress等の状態は、ここでは即座に更新しない。
    /// 実際に録画が始まったことを示すfileOutput(_:didStartRecordingTo:from:)を
    /// 起点に更新することで、UIの「録画中」表示と実態のズレを防ぐ
    /// (以前はここで即座にisRecording=trueにしていたため、movieOutputへの
    /// startRecording呼び出しがまだセッション未稼働のタイミングで行われていた
    /// 問題と合わさり、UI上は録画中に見えても実際には録画されていない
    /// 状態が起こり得た)。
    ///
    /// isConfigured/session.isRunningを確認せずmovieOutput.startRecordingを
    /// 呼んでいたため、カメラ/マイク権限が拒否されセッションが未構成のまま
    /// 録画が試みられても「録画に失敗しました」としか出ず原因が分からなかった。
    /// ここで明示的にガードし、原因を特定できるエラーを返す。
    func startRecording(completion: @escaping (URL?, Error?) -> Void) {
        guard !isRecording else { return }
        guard isConfigured, session.isRunning else {
            print("[VideoCapture] startRecording: セッション未構成/未稼働のため開始できません(isConfigured=\(isConfigured), session.isRunning=\(session.isRunning))")
            completion(nil, VideoCaptureError.sessionNotReady)
            return
        }
        // attachCameraInput()でのカメラ入力追加に失敗していると(例: 物理カメラデバイスが
        // まだ他のセッションに使われている等)、session.isRunningがtrueでも実際には
        // 映像を記録できない状態になっている。以前はここを確認せずstartRecordingへ
        // 進んでいたため、「セッションは動いているのに毎回録画だけ失敗する」不具合が
        // 原因不明のまま起きていた。ここで明示的にガードし、原因を特定できるエラーを返す。
        guard movieOutput.connection(with: .video) != nil else {
            print("[VideoCapture] startRecording: 映像コネクションが存在しないため開始できません(videoDeviceInput=\(String(describing: videoDeviceInput)))")
            completion(nil, VideoCaptureError.cameraUnavailable)
            return
        }
        recordingCompletion = completion
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
    }

    /// 最大時間に達する前にユーザーが手動で止めた場合に呼ぶ。自己申告フラグ(isRecording)
    /// だけでなく、AVFoundation側の実際の状態(movieOutput.isRecording)も確認し、
    /// 食い違っていれば警告ログを出す(「見た目は録画中だが実際には録画されていない」
    /// 不具合が今後起きた際に、ログから即座に気づけるようにするため)。
    func stopRecording() {
        guard isRecording else { return }
        if !movieOutput.isRecording {
            print("[VideoCapture] 警告: 自己申告フラグ(isRecording=true)とAVFoundation側の実際の状態(movieOutput.isRecording=false)が食い違っています。録画が正しく開始されていない可能性があります。")
        }
        movieOutput.stopRecording()
    }
}

/// startRecording呼び出し時点でセッションがまだ使える状態になっていない場合に返す
/// エラー。カメラ/マイク権限が拒否されconfigure()がsetupSession()まで進めなかった
/// ケースが典型例(errorDescriptionはvideoProcessingErrorMessageにそのまま使われる)。
enum VideoCaptureError: LocalizedError {
    case sessionNotReady
    /// attachCameraInput()でカメラ入力の追加に失敗し、movieOutputに映像コネクションが
    /// 存在しないまま録画が試みられた場合に返す。
    case cameraUnavailable

    var errorDescription: String? {
        switch self {
        case .sessionNotReady:
            return "カメラを準備できませんでした(カメラ/マイクへのアクセスが許可されているかご確認ください)"
        case .cameraUnavailable:
            return "カメラを使用できませんでした。他のカメラ機能を終了してからもう一度お試しください。"
        }
    }
}

extension VideoCaptureController: AVCaptureFileOutputRecordingDelegate {
    /// AVFoundationが実際に録画を開始した瞬間に呼ばれる。isRecording/recordingProgress等の
    /// 状態更新はここを起点にする(startRecording呼び出し時点ではまだ実際に録画が
    /// 始まっているとは限らないため)。
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        Task { @MainActor in
            isRecording = true
            recordingStartDate = Date()
            recordingProgress = 0
            progressTimer?.invalidate()
            progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self, let start = self.recordingStartDate else { return }
                self.recordingProgress = min(1, Date().timeIntervalSince(start) / Self.maxDuration)
            }
        }
    }

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            progressTimer?.invalidate()
            progressTimer = nil
            isRecording = false
            recordingProgress = 0
            recordingStartDate = nil
            if let error {
                // AVErrorMaximumDurationReached(-11810)は「30秒に達して正常に自動停止した」
                // ケースでも付与されることがあるため、ファイル自体が書けていれば成功として扱う。
                let nsError = error as NSError
                let reachedMaxDuration = nsError.domain == AVFoundationErrorDomain
                    && nsError.code == AVError.maximumDurationReached.rawValue
                if !reachedMaxDuration {
                    print("[VideoCapture] 録画終了時にエラー: \(error)")
                }
            }
            let exists = FileManager.default.fileExists(atPath: outputFileURL.path)
            recordingCompletion?(exists ? outputFileURL : nil, exists ? nil : error)
            recordingCompletion = nil
        }
    }
}
