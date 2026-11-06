import AVFoundation
import CoreImage
import CoreMotion
import SwiftUI
import UIKit

// v20 動画:カメラの映像を RETRO-8(RetroLook)で加工し、同じ絵を
//   ① ファインダー(AVSampleBufferDisplayLayer)と ② 録画(AVAssetWriter)の両方へ流す(見たとおりに撮れる)。
// すべて frameQueue(カメラのフレームの列)で動かす。メインスレッドでは加工しない。バッファは使い回す。
// 書き出し:540×720(3:4)・30fps・H.264 Main・約 1.1Mbps(vlook.py の maxrate)・キーフレーム 30 コマごと・B フレームなし。
// 音:AAC 64kbps モノ(マイクを断られたら、音なしで録る)。最長 10 秒。1秒より みじかいものは捨てる(1こま使わない)。

struct RecordedVideo: Sendable {
    let url: URL
    let duration: Double
    /// ポスター(最初のコマ・加工ずみの JPEG)
    let poster: Data
    let hasAudio: Bool
}

enum VideoRules {
    static let width = 540
    static let height = 720
    static let fps: Int32 = 30
    static let bitRate = 1_100_000
    static let keyFrameInterval = 30
    static let audioBitRate = 64_000
    static let maxDuration: Double = 10
    static let minDuration: Double = 1
    /// おして ためる
    static let charge: Double = 0.62
    /// 目もり 24 こ(10 秒で一周 → 0.42 秒ごと)
    static let tickCount = 24
    static var tickInterval: Double { maxDuration / Double(tickCount) }
    /// のこり 3 秒で赤くなる
    static let warnAfter: Double = 7

    /// 録れた長さで、のこすか(1秒より みじかいと捨てる)
    static func keeps(duration: Double) -> Bool { duration >= minDuration }
}

final class RetroRecorder: @unchecked Sendable {
    let look = RetroLook()
    /// ファインダー(メインで作り、ここから enqueue する。enqueue はどのスレッドからでもよい)
    let displayLayer = AVSampleBufferDisplayLayer()

    private let lock = NSLock()
    /// ここから下は frameQueue でだけ触る
    private var pool: CVPixelBufferPool?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var startTime: CMTime?
    private var lastTime: CMTime = .zero
    private var poster: Data?
    private var outputURL: URL?
    private var firstFrameTime: CMTime?
    private var active = false
    private var recording = false
    private var stopping = false
    private var withAudio = false

    private let motion = CMMotionManager()

    init() {
        displayLayer.videoGravity = .resizeAspectFill
        if motion.isGyroAvailable {
            motion.gyroUpdateInterval = 1.0 / 30
            motion.startGyroUpdates()
        }
    }

    deinit { motion.stopGyroUpdates() }

    /// 動画モードの間だけ、フレームを加工する
    func setActive(_ on: Bool) {
        lock.lock(); active = on; lock.unlock()
        if on { look.reset() }
    }

    var isActive: Bool { lock.lock(); defer { lock.unlock() }; return active }

    // MARK: 録画(メインから呼ぶ)

    func startRecording(audio: Bool) {
        lock.lock()
        defer { lock.unlock() }
        guard !recording else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("later-\(UUID().uuidString).mp4")
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return }
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: VideoRules.width,
            AVVideoHeightKey: VideoRules.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: VideoRules.bitRate,
                AVVideoMaxKeyFrameIntervalKey: VideoRules.keyFrameInterval,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel,
                AVVideoAllowFrameReorderingKey: false,
                AVVideoExpectedSourceFrameRateKey: VideoRules.fps,
            ],
        ])
        video.expectsMediaDataInRealTime = true
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: VideoRules.width,
            kCVPixelBufferHeightKey as String: VideoRules.height,
        ])
        guard writer.canAdd(video) else { return }
        writer.add(video)
        var audioInput: AVAssetWriterInput?
        if audio {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 1,
                AVSampleRateKey: 44_100,
                AVEncoderBitRateKey: VideoRules.audioBitRate,
            ])
            input.expectsMediaDataInRealTime = true
            if writer.canAdd(input) { writer.add(input); audioInput = input }
        }
        guard writer.startWriting() else { return }
        self.writer = writer
        self.videoInput = video
        self.audioInput = audioInput
        self.adaptor = adaptor
        self.outputURL = url
        self.startTime = nil
        self.poster = nil
        self.withAudio = audioInput != nil
        self.recording = true
        self.stopping = false
        look.reset()
    }

    /// とめる。1秒より みじかい・失敗は nil(ファイルは消す)
    func stopRecording(completion: @escaping @Sendable (RecordedVideo?) -> Void) {
        lock.lock()
        guard recording, let writer, let videoInput, let url = outputURL else {
            lock.unlock()
            completion(nil)
            return
        }
        recording = false
        stopping = true
        let start = startTime
        let end = lastTime
        let poster = self.poster
        let hasAudio = withAudio
        audioInput?.markAsFinished()
        videoInput.markAsFinished()
        self.writer = nil
        self.videoInput = nil
        self.audioInput = nil
        self.adaptor = nil
        lock.unlock()
        guard let start else {
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: url)
            completion(nil)
            return
        }
        let duration = min(VideoRules.maxDuration, CMTimeGetSeconds(CMTimeSubtract(end, start)) + 1.0 / Double(VideoRules.fps))
        writer.endSession(atSourceTime: end)
        writer.finishWriting {
            guard writer.status == .completed, VideoRules.keeps(duration: duration), let poster else {
                try? FileManager.default.removeItem(at: url)
                completion(nil)
                return
            }
            completion(RecordedVideo(url: url, duration: duration, poster: poster, hasAudio: hasAudio))
        }
    }

    // MARK: フレーム(frameQueue)

    /// カメラの1コマ。動画モードのときだけ加工して、ファインダーと録画へ
    func handleVideo(_ sampleBuffer: CMSampleBuffer) {
        lock.lock()
        let on = active
        let rec = recording
        lock.unlock()
        guard on, let source = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if firstFrameTime == nil { firstFrameTime = time }
        let t = CMTimeGetSeconds(CMTimeSubtract(time, startTime ?? firstFrameTime ?? time))

        // 3:4 に合わせて 540×720 へ(アスペクト・フィル)
        var image = CIImage(cvPixelBuffer: source)
        let scale = max(CGFloat(VideoRules.width) / image.extent.width, CGFloat(VideoRules.height) / image.extent.height)
        image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let dx = (image.extent.width - CGFloat(VideoRules.width)) / 2, dy = (image.extent.height - CGFloat(VideoRules.height)) / 2
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX - dx, y: -image.extent.minY - dy))
            .cropped(to: CGRect(x: 0, y: 0, width: VideoRules.width, height: VideoRules.height))

        // 横に動くと、かたむく(ジャイロの回転の速さ → 幅 360 基準の px/秒)
        let rate = motion.gyroData?.rotationRate.y ?? 0
        let velocity = rate * 360 * 1.2
        // 日付スタンプは、録画のときに焼きこむ(ファインダーにも同じものを出す)
        let processed = look.process(image, time: t, velocityX: velocity, stampText: RetroSettings.stampOn ? RetroStamp.text(for: Date()) : nil)

        guard let out = makeBuffer() else { return }
        look.context.render(processed, to: out, bounds: CGRect(x: 0, y: 0, width: VideoRules.width, height: VideoRules.height), colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        enqueueForDisplay(out, time: time)

        guard rec else { return }
        lock.lock()
        defer { lock.unlock() }
        guard recording, let writer, let videoInput, let adaptor else { return }
        if startTime == nil {
            writer.startSession(atSourceTime: time)
            startTime = time
            // ポスター(最初のコマ・加工ずみ)
            if let cg = look.context.createCGImage(processed, from: processed.extent) {
                poster = UIImage(cgImage: cg).jpegData(compressionQuality: 0.85)
            }
        }
        guard CMTimeGetSeconds(CMTimeSubtract(time, startTime ?? time)) <= VideoRules.maxDuration else { return }
        if videoInput.isReadyForMoreMediaData, adaptor.append(out, withPresentationTime: time) {
            lastTime = time
        }
    }

    /// マイクの音(frameQueue とは別の列からでもよい)
    func handleAudio(_ sampleBuffer: CMSampleBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard recording, startTime != nil, let audioInput, audioInput.isReadyForMoreMediaData else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard let start = startTime, CMTimeCompare(time, start) >= 0 else { return }
        audioInput.append(sampleBuffer)
    }

    private func makeBuffer() -> CVPixelBuffer? {
        if pool == nil {
            let attrs: [CFString: Any] = [
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey: VideoRules.width,
                kCVPixelBufferHeightKey: VideoRules.height,
                kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
            ]
            CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &pool)
        }
        guard let pool else { return nil }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        return buffer
    }

    private func enqueueForDisplay(_ buffer: CVPixelBuffer, time: CMTime) {
        var format: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: buffer, formatDescriptionOut: &format)
        guard let format else { return }
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: VideoRules.fps), presentationTimeStamp: time, decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: buffer, formatDescription: format, sampleTiming: &timing, sampleBufferOut: &sample)
        guard let sample else { return }
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true) as? [NSMutableDictionary], let first = attachments.first {
            first[kCMSampleAttachmentKey_DisplayImmediately] = true
        }
        let renderer = displayLayer.sampleBufferRenderer
        if renderer.status == .failed { renderer.flush() }
        renderer.enqueue(sample)
    }
}

/// 動画の設定(端末の中だけ)
enum RetroSettings {
    private static let stampKey = "video.stampOn"
    private static let tapKey = "video.tapToRecord"

    /// 日付スタンプ(初期はオン)
    static var stampOn: Bool {
        get { UserDefaults.standard.object(forKey: stampKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: stampKey) }
    }

    /// 録画:タップで はじめる・とめる(初期は長押し)
    static var tapToRecord: Bool {
        get { UserDefaults.standard.bool(forKey: tapKey) }
        set { UserDefaults.standard.set(newValue, forKey: tapKey) }
    }

    /// VoiceOver・スイッチコントロールがオンなら、自動でタップ式
    @MainActor
    static var usesTapRecording: Bool {
        tapToRecord || UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning
    }
}

/// ファインダー(加工ずみの映像)
struct RetroPreviewView: UIViewRepresentable {
    let layer: AVSampleBufferDisplayLayer

    final class Host: UIView {
        var displayLayer: AVSampleBufferDisplayLayer? {
            didSet {
                oldValue?.removeFromSuperlayer()
                if let displayLayer { layer.addSublayer(displayLayer) }
                setNeedsLayout()
            }
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            displayLayer?.frame = bounds
        }
    }

    func makeUIView(context: Context) -> Host {
        let view = Host()
        view.backgroundColor = .black
        view.displayLayer = layer
        return view
    }

    func updateUIView(_ uiView: Host, context: Context) {
        if uiView.displayLayer !== layer { uiView.displayLayer = layer }
    }
}
