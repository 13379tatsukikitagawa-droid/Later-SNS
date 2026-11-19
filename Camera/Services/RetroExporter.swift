import AVFoundation
import CoreImage
import SwiftData
import UIKit

// v21 C:撮ったあとに 1回だけ、もとの ふつうの映像から RETRO-8 の動画を書き出す(アプリの中・バックグラウンド)。
// AVAssetReader → RetroLook(Core Image)→ AVAssetWriter。540×720・30fps・H.264 Main・約 1.2Mbps・キーフレーム 30・B フレームなし。
// 音:80Hz 以下と 7kHz 以上を切る・軽くコンプ・室内の「ジー」をごく小さく → AAC 64kbps モノ。
// 成功したら、ポスター(image)・モザイクを RETRO-8 の1コマ目にして、もとの映像を すぐ消す。
// 途中で落ちたら、次の起動で つづきから(もとの映像が のこっているので)。

nonisolated enum RetroExporter {
    struct Result: Sendable {
        let poster: Data
        let duration: Double
    }

    enum ExportError: Error { case noVideo, reader, writer }

    static func export(raw: URL, to output: URL, velocities: [Double], captureDate: Date, light: Bool = RetroLook.isHot) async throws -> Result {
        let asset = AVURLAsset(url: raw)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else { throw ExportError.noVideo }
        let audioTrack = try await asset.loadTracks(withMediaType: .audio).first
        let reader = try AVAssetReader(asset: asset)
        let videoOut = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        videoOut.alwaysCopiesSampleData = false
        guard reader.canAdd(videoOut) else { throw ExportError.reader }
        reader.add(videoOut)
        var audioOut: AVAssetReaderTrackOutput?
        if let audioTrack {
            let out = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsNonInterleaved: false,
                AVLinearPCMIsBigEndianKey: false,
                AVNumberOfChannelsKey: 1,
                AVSampleRateKey: 44_100,
            ])
            if reader.canAdd(out) { reader.add(out); audioOut = out }
        }

        try? FileManager.default.removeItem(at: output)
        let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
        let videoIn = AVAssetWriterInput(mediaType: .video, outputSettings: [
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
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoIn, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: VideoRules.width,
            kCVPixelBufferHeightKey as String: VideoRules.height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ])
        guard writer.canAdd(videoIn) else { throw ExportError.writer }
        writer.add(videoIn)
        var audioIn: AVAssetWriterInput?
        if audioOut != nil {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 1,
                AVSampleRateKey: 44_100,
                AVEncoderBitRateKey: VideoRules.audioBitRate,
            ])
            if writer.canAdd(input) { writer.add(input); audioIn = input }
        }
        guard reader.startReading(), writer.startWriting() else { throw ExportError.reader }
        writer.startSession(atSourceTime: .zero)

        let film = FilmLook.shared   // v107:iPhone 8 風(LUT + うすい シャープ + 動く 粒子)。日付の 焼きこみは しない
        let box = ExportBox()
        let group = DispatchGroup()

        // 映像
        group.enter()
        let videoQueue = DispatchQueue(label: "later.retro.video")
        videoIn.requestMediaDataWhenReady(on: videoQueue) {
            while videoIn.isReadyForMoreMediaData {
                guard let sample = videoOut.copyNextSampleBuffer(), let source = CMSampleBufferGetImageBuffer(sample) else {
                    videoIn.markAsFinished()
                    group.leave()
                    return
                }
                let pts = CMSampleBufferGetPresentationTimeStamp(sample)
                if box.first == nil { box.first = pts }
                let t = CMTimeGetSeconds(CMTimeSubtract(pts, box.first ?? pts))
                var image = CIImage(cvPixelBuffer: source)
                image = image.transformed(by: CGAffineTransform(scaleX: CGFloat(VideoRules.width) / image.extent.width, y: CGFloat(VideoRules.height) / image.extent.height))
                image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
                    .cropped(to: CGRect(x: 0, y: 0, width: VideoRules.width, height: VideoRules.height))
                _ = t
                let processed = film.retro8Frame(image, frame: box.frame)
                box.frame += 1
                guard let pool = adaptor.pixelBufferPool else { continue }
                var out: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(nil, pool, &out)
                guard let out else { continue }
                film.context.render(processed, to: out, bounds: CGRect(x: 0, y: 0, width: VideoRules.width, height: VideoRules.height), colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
                if box.poster == nil, let cg = film.context.createCGImage(processed, from: processed.extent) {
                    box.poster = UIImage(cgImage: cg).jpegData(compressionQuality: 0.85)
                }
                adaptor.append(out, withPresentationTime: CMTimeSubtract(pts, box.first ?? pts))
                box.last = CMTimeSubtract(pts, box.first ?? pts)
            }
        }

        // 音
        if let audioOut, let audioIn {
            group.enter()
            let audioQueue = DispatchQueue(label: "later.retro.audio")
            let filter = RetroAudioFilter()
            audioIn.requestMediaDataWhenReady(on: audioQueue) {
                while audioIn.isReadyForMoreMediaData {
                    guard let sample = audioOut.copyNextSampleBuffer() else {
                        audioIn.markAsFinished()
                        group.leave()
                        return
                    }
                    filter.process(sample)
                    // 映像と同じく、はじまりを 0 にそろえる
                    if let shifted = Self.shift(sample, by: box.first ?? .zero) { audioIn.append(shifted) }
                }
            }
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            group.notify(queue: .global()) { continuation.resume() }
        }
        await writer.finishWriting()
        guard writer.status == .completed, let poster = box.poster else { throw ExportError.writer }
        return Result(poster: poster, duration: CMTimeGetSeconds(box.last) + 1.0 / Double(VideoRules.fps))
    }

    private static func shift(_ sample: CMSampleBuffer, by offset: CMTime) -> CMSampleBuffer? {
        var count: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(sample, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count)
        var timing = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: count)
        CMSampleBufferGetSampleTimingInfoArray(sample, entryCount: count, arrayToFill: &timing, entriesNeededOut: &count)
        for i in 0..<count {
            timing[i].presentationTimeStamp = CMTimeSubtract(timing[i].presentationTimeStamp, offset)
            timing[i].decodeTimeStamp = .invalid
        }
        guard CMTimeCompare(timing.first?.presentationTimeStamp ?? .zero, .zero) >= 0 else { return nil }
        var out: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: sample, sampleTimingEntryCount: count, sampleTimingArray: &timing, sampleBufferOut: &out)
        return out
    }
}

private final class ExportBox: @unchecked Sendable {
    var first: CMTime?
    var last: CMTime = .zero
    var frame = 0
    var poster: Data?
}

/// 音:80Hz 以下を切る → 7kHz 以上を切る → 軽くコンプ → 室内の「ジー」をごく小さく(Float32 モノ・その場で書きかえる)
final class RetroAudioFilter: @unchecked Sendable {
    private var hp = Biquad.highPass(frequency: 80, sampleRate: 44_100)
    private var lp = Biquad.lowPass(frequency: 7_000, sampleRate: 44_100)
    private var envelope: Float = 0
    private var noiseState: UInt32 = 0x1234_5678
    private var humPhase: Float = 0

    func process(_ sample: CMSampleBuffer) {
        guard let block = CMSampleBufferGetDataBuffer(sample) else { return }
        var length = 0
        var pointer: UnsafeMutablePointer<CChar>?
        guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer) == noErr,
              let pointer else { return }
        let count = length / MemoryLayout<Float>.size
        pointer.withMemoryRebound(to: Float.self, capacity: count) { samples in
            for i in 0..<count {
                var x = hp.run(samples[i])
                x = lp.run(x)
                // 軽いコンプ(-18dB から 3:1)
                let level = abs(x)
                envelope = level > envelope ? envelope + (level - envelope) * 0.01 : envelope + (level - envelope) * 0.0005
                let threshold: Float = 0.126
                if envelope > threshold {
                    let over = envelope / threshold
                    x *= pow(over, -2.0 / 3.0)
                }
                // 室内の「ジー」(とても小さい。ノイズ + 100Hz)
                noiseState = noiseState &* 1_664_525 &+ 1_013_904_223
                let noise = (Float(noiseState >> 9) / Float(1 << 23) - 0.5) * 0.004
                humPhase += 2 * .pi * 100 / 44_100
                if humPhase > 2 * .pi { humPhase -= 2 * .pi }
                samples[i] = max(-1, min(1, x * 1.15 + noise + sin(humPhase) * 0.0015))
            }
        }
    }
}

struct Biquad {
    var b0: Float, b1: Float, b2: Float, a1: Float, a2: Float
    var x1: Float = 0, x2: Float = 0, y1: Float = 0, y2: Float = 0

    mutating func run(_ x: Float) -> Float {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x; y2 = y1; y1 = y
        return y
    }

    /// RBJ の式(Q = 0.707)
    static func highPass(frequency: Float, sampleRate: Float) -> Biquad {
        let w = 2 * Float.pi * frequency / sampleRate, alpha = sin(w) / (2 * 0.707), c = cos(w), a0 = 1 + alpha
        return Biquad(b0: (1 + c) / 2 / a0, b1: -(1 + c) / a0, b2: (1 + c) / 2 / a0, a1: -2 * c / a0, a2: (1 - alpha) / a0)
    }

    static func lowPass(frequency: Float, sampleRate: Float) -> Biquad {
        let w = 2 * Float.pi * frequency / sampleRate, alpha = sin(w) / (2 * 0.707), c = cos(w), a0 = 1 + alpha
        return Biquad(b0: (1 - c) / 2 / a0, b1: (1 - c) / a0, b2: (1 - c) / 2 / a0, a1: -2 * c / a0, a2: (1 - alpha) / a0)
    }
}

/// 書き出しの順番待ち(端末に のこす。落ちても、次の起動で つづきから)
@MainActor
enum RetroExportQueue {
    struct Job: Codable, Equatable {
        /// もとの映像(LaterVideoStore の "raw-" のファイル)
        let rawName: String
        let captureDate: Date
        let velocities: [Double]
    }

    private static let key = "retro.exportJobs.v1"
    private static var running = false
    /// 書き出しが終わったときに、写真を書きかえる場所
    static weak var context: ModelContext?

    static var jobs: [Job] {
        get { (UserDefaults.standard.data(forKey: key)).flatMap { try? JSONDecoder().decode([Job].self, from: $0) } ?? [] }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: key) }
    }

    static func enqueue(_ job: Job) {
        var list = jobs
        list.append(job)
        jobs = list
        run()
    }

    /// 順番に書き出す(バックグラウンドでも、つづけられる所まで)
    static func run() {
        guard !running, let job = jobs.first else { return }
        running = true
        let background = BackgroundTaskBox.begin(name: "later.retroExport")
        Task { @MainActor in
            defer {
                background.end()
                running = false
            }
            let raw = LaterVideoStore.url(fileName: job.rawName)
            guard FileManager.default.fileExists(atPath: raw.path) else {
                drop(job)
                run()
                return
            }
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent("later-retro-\(UUID().uuidString).mp4")
            let started = Date()
            #if DEBUG
            let debugToken = DebugFilm.beginVideo(raw: raw)
            #endif
            do {
                let result = try await RetroExporter.export(raw: raw, to: temp, velocities: job.velocities, captureDate: job.captureDate)
                #if DEBUG
                DebugFilm.finishVideo(debugToken, baked: temp, clipSeconds: result.duration)
                #endif
                print(String(format: "[RetroExport] %.1f秒の動画を %.1f秒で書き出し", result.duration, Date().timeIntervalSince(started)))
                let name = try LaterVideoStore.adopt(temp)
                apply(job: job, fileName: name, poster: result.poster)
                // もとの ふつう映像は、すぐ消す(容量とプライバシー)
                LaterVideoStore.deleteLocal(job.rawName)
                drop(job)
            } catch {
                print("[RetroExport] 書き出しに失敗:\(error)。次の起動で もう一度")
                #if DEBUG
                DebugFilm.discardVideo(debugToken)
                #endif
                try? FileManager.default.removeItem(at: temp)
                return
            }
            run()
        }
    }

    private static func drop(_ job: Job) {
        jobs = jobs.filter { $0 != job }
    }

    /// 写真(グループごとの写しすべて)を、RETRO-8 の動画・ポスターに入れかえる
    private static func apply(job: Job, fileName: String, poster: Data) {
        guard let context else { return }
        let date = job.captureDate
        let raw = job.rawName
        let photos = (try? context.fetch(FetchDescriptor<LaterPhoto>(predicate: #Predicate { $0.captureDate == date }))) ?? []
        let mosaic = MosaicRenderer.makeTiny(from: poster)
        for photo in photos where photo.videoFileName == raw {
            photo.videoFileName = fileName
            photo.imageData = poster
            photo.mosaicTiny = mosaic
            photo.filmVersion = FilmLook.version   // v107:焼いた ファイルの しるし(動画)
            photo.isColorGraded = true
        }
        try? context.save()
        // すでに「投稿する」を選んでいたら、もう一度送る(レトロ済みの動画だけが届く)
        guard let manager = CloudKitManager.current else { return }
        Task {
            for photo in photos where photo.isPosted {
                guard let groupID = photo.groupID, let group = try? context.fetch(FetchDescriptor<LaterGroup>(predicate: #Predicate { $0.id == groupID })).first else { continue }
                await manager.markForUpload(photo: photo, in: group)
            }
            await manager.sendPendingChangesNow()
        }
    }
}
