import AVFoundation
import CoreImage
import UIKit

/// 撮影直後の動画にFilmEmulation(トーンカーブ/ハレーション/グレイン/周辺減光/現像ムラ)を
/// 一度だけ適用し、H.264/HEVCの動画ファイルとして書き出す。
///
/// AVAssetExportSessionの標準プリセットではビットレートを直接指定できないため、
/// AVAssetReader(カスタムAVVideoCompositionを適用したAVAssetReaderVideoCompositionOutput
/// 経由で加工済みフレームを読み出す)+AVAssetWriter(コーデック・ビットレートを明示指定)の
/// 組み合わせで書き出す。再生のたびに処理するのではなく、この書き出しを撮影直後に
/// 一度だけ行い、以降は加工済みファイルをそのまま使う想定。
enum FilmEmulationVideoExporter {

    // MARK: - 書き出しパラメータ(あとから調整しやすいよう一箇所にまとめる)

    struct Settings {
        /// H.264かHEVCか。HEVCの方が同画質でファイルサイズが小さくなりやすいが、
        /// 共有・互換性を優先するならH.264の方が無難(古い端末・他アプリとの相性)。
        var codec: AVVideoCodecType = .hevc
        /// ビットレート(bps)。VGA(640x480)・20fps・最大10秒のクリップを想定した初期値
        /// (以前は1080p・30秒想定の6,000,000だったが、解像度・秒数の削減に合わせて
        /// 大幅に下げた)。実機での加工前後のファイルサイズを見ながら、まずここだけを
        /// 調整すればよい。
        var averageBitRate: Int = 1_500_000
        /// 音声のビットレート(bps)。
        var audioBitRate: Int = 96_000

        static let `default` = Settings()
    }

    struct Result: Identifiable {
        var id: URL { processedVideoURL }
        let processedVideoURL: URL
        /// 加工後の先頭フレームを静止画として書き出したもの(将来のサムネイル用途)。
        let thumbnail: UIImage?
        let rawFileSize: Int
        let processedFileSize: Int
        let durationSeconds: Double
    }

    enum ExportError: Error {
        case noVideoTrack
        case readerSetupFailed
        case writerSetupFailed
        case exportFailed(String)
    }

    /// rawURL(VideoCaptureControllerが書き出した未加工の.movファイル)を読み込み、
    /// FilmEmulationを適用したうえで新しいファイルへ書き出す。
    /// rawURLの削除は呼び出し側の判断に委ねる(ここでは削除しない)。
    static func export(rawURL: URL, settings: Settings = .default) async throws -> Result {
        let asset = AVURLAsset(url: rawURL)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ExportError.noVideoTrack
        }
        let audioTrack = try await asset.loadTracks(withMediaType: .audio).first

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let frameRate: Float = nominalFrameRate > 0 ? nominalFrameRate : 30
        let duration = try await asset.load(.duration)

        // 動画ごとに固定のベースseed。写真のFilmEmulation.seed(for:)と同じ考え方で、
        // ファイル名(撮影ごとに一意なUUID)から決定論的に作る。
        let baseSeed = FilmEmulation.seed(for: Data(rawURL.lastPathComponent.utf8))

        let instruction = FilmEmulationVideoCompositionInstruction(
            timeRange: CMTimeRange(start: .zero, duration: duration),
            sourceTrackID: videoTrack.trackID,
            baseSeed: baseSeed,
            frameRate: frameRate
        )

        // レンダリング自体はセンサーのnaturalSize(向き補正前、通常はlandscape)のまま行い、
        // 最終的な縦横の向きは書き出しトラック側にpreferredTransformをそのまま引き継がせる
        // (フレームのピクセルを自前で回転させると、回転方向を誤った場合に映像が歪む
        // リスクがあるため、向きの制御はAVFoundation標準の仕組みに任せる)。
        let videoComposition = AVMutableVideoComposition()
        videoComposition.customVideoCompositorClass = FilmEmulationVideoCompositor.self
        videoComposition.renderSize = naturalSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        videoComposition.instructions = [instruction]

        guard let reader = try? AVAssetReader(asset: asset) else {
            throw ExportError.readerSetupFailed
        }

        let readerVideoOutput = AVAssetReaderVideoCompositionOutput(
            videoTracks: [videoTrack],
            videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        )
        readerVideoOutput.videoComposition = videoComposition
        readerVideoOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(readerVideoOutput) else { throw ExportError.readerSetupFailed }
        reader.add(readerVideoOutput)

        var readerAudioOutput: AVAssetReaderTrackOutput?
        if let audioTrack {
            // AVAssetWriter側で改めてAACへ再エンコードするため、読み出し時は
            // 一旦Linear PCMへデコードする(圧縮形式のまま別の圧縮形式へ入れ替えることは
            // 直接できないため)。
            let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM
            ])
            output.alwaysCopiesSampleData = false
            if reader.canAdd(output) {
                reader.add(output)
                readerAudioOutput = output
            }
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            throw ExportError.writerSetupFailed
        }

        let videoOutputSettings: [String: Any] = [
            AVVideoCodecKey: settings.codec,
            AVVideoWidthKey: naturalSize.width,
            AVVideoHeightKey: naturalSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: settings.averageBitRate,
                AVVideoExpectedSourceFrameRateKey: Int(frameRate)
            ]
        ]
        let writerVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoOutputSettings)
        writerVideoInput.expectsMediaDataInRealTime = false
        writerVideoInput.transform = preferredTransform
        guard writer.canAdd(writerVideoInput) else { throw ExportError.writerSetupFailed }
        writer.add(writerVideoInput)

        var writerAudioInput: AVAssetWriterInput?
        if readerAudioOutput != nil {
            let audioOutputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVEncoderBitRateKey: settings.audioBitRate,
                AVNumberOfChannelsKey: 1,
                AVSampleRateKey: 44_100
            ]
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
            input.expectsMediaDataInRealTime = false
            if writer.canAdd(input) {
                writer.add(input)
                writerAudioInput = input
            }
        }

        guard reader.startReading() else {
            throw ExportError.exportFailed(reader.error?.localizedDescription ?? "reader.startReading失敗")
        }
        guard writer.startWriting() else {
            throw ExportError.exportFailed(writer.error?.localizedDescription ?? "writer.startWriting失敗")
        }
        writer.startSession(atSourceTime: .zero)

        var capturedThumbnail: UIImage?
        let thumbnailOrientation = Self.uiImageOrientation(for: preferredTransform)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let videoQueue = DispatchQueue(label: "jp.shotoku.later.FilmEmulationVideoExporter.video")
            let audioQueue = DispatchQueue(label: "jp.shotoku.later.FilmEmulationVideoExporter.audio")
            let group = DispatchGroup()

            group.enter()
            writerVideoInput.requestMediaDataWhenReady(on: videoQueue) {
                while writerVideoInput.isReadyForMoreMediaData {
                    guard let sampleBuffer = readerVideoOutput.copyNextSampleBuffer() else {
                        writerVideoInput.markAsFinished()
                        group.leave()
                        return
                    }
                    // 先頭フレーム(加工済み)をサムネイル候補として控えておく。
                    if capturedThumbnail == nil, let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
                        if let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent) {
                            capturedThumbnail = UIImage(cgImage: cgImage, scale: 1, orientation: thumbnailOrientation)
                        }
                    }
                    if !writerVideoInput.append(sampleBuffer) {
                        writerVideoInput.markAsFinished()
                        group.leave()
                        return
                    }
                }
            }

            if let readerAudioOutput, let writerAudioInput {
                group.enter()
                writerAudioInput.requestMediaDataWhenReady(on: audioQueue) {
                    while writerAudioInput.isReadyForMoreMediaData {
                        guard let sampleBuffer = readerAudioOutput.copyNextSampleBuffer() else {
                            writerAudioInput.markAsFinished()
                            group.leave()
                            return
                        }
                        if !writerAudioInput.append(sampleBuffer) {
                            writerAudioInput.markAsFinished()
                            group.leave()
                            return
                        }
                    }
                }
            }

            group.notify(queue: .main) {
                if reader.status == .failed {
                    writer.cancelWriting()
                    continuation.resume(throwing: ExportError.exportFailed(reader.error?.localizedDescription ?? "reader失敗"))
                    return
                }
                writer.finishWriting {
                    if writer.status == .completed {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: ExportError.exportFailed(writer.error?.localizedDescription ?? "writer失敗"))
                    }
                }
            }
        }

        return Result(
            processedVideoURL: outputURL,
            thumbnail: capturedThumbnail,
            rawFileSize: fileSize(at: rawURL),
            processedFileSize: fileSize(at: outputURL),
            durationSeconds: duration.seconds
        )
    }

    private static func fileSize(at url: URL) -> Int {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return 0 }
        return (attributes[.size] as? Int) ?? 0
    }

    /// preferredTransform(回転行列)から、代表的な0/90/180/270度のケースをUIImage.Orientationへ
    /// 変換する。ミラーリング(前面カメラの左右反転)の組み合わせまでは扱っていないため、
    /// 前面カメラで撮った動画のサムネイルは向きがずれる可能性がある(既知の制限)。
    private static func uiImageOrientation(for transform: CGAffineTransform) -> UIImage.Orientation {
        switch (transform.a, transform.b, transform.c, transform.d) {
        case (0, 1, -1, 0): return .right
        case (0, -1, 1, 0): return .left
        case (-1, 0, 0, -1): return .down
        default: return .up
        }
    }
}
