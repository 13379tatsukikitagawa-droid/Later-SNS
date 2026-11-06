import AVFoundation
import CoreImage
import CoreMotion
import SwiftUI
import UIKit

// v21 C:撮影中は ふつうの映像のまま記録する(ファインダーも ふつう)。
// RETRO-8 は、撮ったあとに裏で1回だけ かける(RetroExporter)。ここは「ふつうの映像」の録画だけ。
// もとの映像:720×960(3:4)・30fps・H.264・約 6Mbps。音:AAC 128kbps モノ(マイクを断られたら音なし)。
// 横の速さ(ジャイロ)を コマごとに残し、書き出しのローリングシャッターに使う。
// 最長 10 秒。1秒より みじかいものは捨てる(1こま使わない)。frameQueue で動かす(メインでは加工しない)。

struct RecordedVideo: Sendable {
    /// もとの ふつうの映像
    let url: URL
    let duration: Double
    /// 仮のポスター(最初のコマ・ふつう)。書き出しが終わったら RETRO-8 の1コマ目に入れかわる
    let poster: Data
    let hasAudio: Bool
    /// コマごとの 横の速さ(px/秒・幅 360 基準)
    let velocities: [Double]
}

enum VideoRules {
    /// 書き出し(RETRO-8)
    static let width = 540
    static let height = 720
    static let fps: Int32 = 30
    static let bitRate = 1_200_000
    static let keyFrameInterval = 30
    static let audioBitRate = 64_000
    /// もとの映像
    static let rawWidth = 720
    static let rawHeight = 960
    static let rawBitRate = 6_000_000
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
    private let lock = NSLock()
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var pool: CVPixelBufferPool?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var startTime: CMTime?
    private var lastTime: CMTime = .zero
    private var poster: Data?
    private var outputURL: URL?
    private var active = false
    private var recording = false
    private var withAudio = false
    private var velocities: [Double] = []
    private let motion = CMMotionManager()

    init() {
        if motion.isGyroAvailable {
            motion.gyroUpdateInterval = 1.0 / 30
            motion.startGyroUpdates()
        }
    }

    deinit { motion.stopGyroUpdates() }

    /// 録画の間だけ、フレームを受けとる
    func setActive(_ on: Bool) {
        lock.lock(); active = on; lock.unlock()
    }

    // MARK: 録画(メインから呼ぶ)

    func startRecording(audio: Bool) {
        lock.lock()
        defer { lock.unlock() }
        guard !recording else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("later-raw-\(UUID().uuidString).mp4")
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return }
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: VideoRules.rawWidth,
            AVVideoHeightKey: VideoRules.rawHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: VideoRules.rawBitRate,
                AVVideoMaxKeyFrameIntervalKey: VideoRules.keyFrameInterval,
                AVVideoAllowFrameReorderingKey: false,
            ],
        ])
        video.expectsMediaDataInRealTime = true
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: VideoRules.rawWidth,
            kCVPixelBufferHeightKey as String: VideoRules.rawHeight,
        ])
        guard writer.canAdd(video) else { return }
        writer.add(video)
        var audioInput: AVAssetWriterInput?
        if audio {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 1,
                AVSampleRateKey: 44_100,
                AVEncoderBitRateKey: 128_000,
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
        self.velocities = []
        self.withAudio = audioInput != nil
        self.recording = true
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
        let start = startTime
        let end = lastTime
        let poster = self.poster
        let hasAudio = withAudio
        let velocities = self.velocities
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
            completion(RecordedVideo(url: url, duration: duration, poster: poster, hasAudio: hasAudio, velocities: velocities))
        }
    }

    // MARK: フレーム(frameQueue)

    /// カメラの1コマ。録画中だけ、ふつうのまま 720×960 にして書く
    func handleVideo(_ sampleBuffer: CMSampleBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard active, recording, let writer, let videoInput, let adaptor,
              let source = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        var image = CIImage(cvPixelBuffer: source)
        let scale = max(CGFloat(VideoRules.rawWidth) / image.extent.width, CGFloat(VideoRules.rawHeight) / image.extent.height)
        image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let dx = (image.extent.width - CGFloat(VideoRules.rawWidth)) / 2, dy = (image.extent.height - CGFloat(VideoRules.rawHeight)) / 2
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX - dx, y: -image.extent.minY - dy))
            .cropped(to: CGRect(x: 0, y: 0, width: VideoRules.rawWidth, height: VideoRules.rawHeight))
        if startTime == nil {
            writer.startSession(atSourceTime: time)
            startTime = time
            if let cg = context.createCGImage(image, from: image.extent) {
                poster = UIImage(cgImage: cg).jpegData(compressionQuality: 0.85)
            }
        }
        guard CMTimeGetSeconds(CMTimeSubtract(time, startTime ?? time)) <= VideoRules.maxDuration,
              videoInput.isReadyForMoreMediaData, let out = makeBuffer() else { return }
        context.render(image, to: out)
        if adaptor.append(out, withPresentationTime: time) {
            lastTime = time
            // 横の速さ(ジャイロ → 幅 360 基準の px/秒)
            velocities.append((motion.gyroData?.rotationRate.y ?? 0) * 360 * 1.2)
        }
    }

    /// マイクの音
    func handleAudio(_ sampleBuffer: CMSampleBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard recording, let start = startTime, let audioInput, audioInput.isReadyForMoreMediaData else { return }
        guard CMTimeCompare(CMSampleBufferGetPresentationTimeStamp(sampleBuffer), start) >= 0 else { return }
        audioInput.append(sampleBuffer)
    }

    private func makeBuffer() -> CVPixelBuffer? {
        if pool == nil {
            let attrs: [CFString: Any] = [
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey: VideoRules.rawWidth,
                kCVPixelBufferHeightKey: VideoRules.rawHeight,
                kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
            ]
            CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &pool)
        }
        guard let pool else { return nil }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        return buffer
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

