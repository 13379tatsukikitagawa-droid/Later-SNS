import AVFoundation
import CoreImage

/// FilmEmulation(トーンカーブ/ハレーション/グレイン/周辺減光/現像ムラ)を、動画の
/// 各フレームに対してCore Image経由で適用するための、AVVideoComposition用の指示。
/// 1本の動画全体(=1つのtimeRange)につき1つのインスタンスで足りる。
final class FilmEmulationVideoCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    var timeRange: CMTimeRange
    var enablePostProcessing: Bool = false
    var containsTweening: Bool = true
    var requiredSourceTrackIDs: [NSValue]?
    var passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

    let sourceTrackID: CMPersistentTrackID
    /// 動画1本ごとに固定のベースseed(写真と同じ考え方でFilmEmulation.seed(for:)相当のものを使う)。
    let baseSeed: UInt32
    /// グレイン/現像ムラをフレームごとにわずかに変化させ、実際のフィルムのように
    /// 粒状感が「揺れる」ようにするための概算フレームレート。
    let frameRate: Float

    init(timeRange: CMTimeRange, sourceTrackID: CMPersistentTrackID, baseSeed: UInt32, frameRate: Float) {
        self.timeRange = timeRange
        self.sourceTrackID = sourceTrackID
        self.baseSeed = baseSeed
        self.frameRate = frameRate
        self.requiredSourceTrackIDs = [NSNumber(value: sourceTrackID)]
        super.init()
    }
}

/// AVAssetReader/AVAssetWriter経由のオフライン書き出し(FilmEmulationVideoExporter)専用の
/// カスタムコンポジター。撮影直後に一度だけ実行し、加工済みの動画ファイルを生成する
/// (再生のたびに毎回これを通すわけではない)。
final class FilmEmulationVideoCompositor: NSObject, AVVideoCompositing {
    let sourcePixelBufferAttributes: [String: Any]? = [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
    ]
    let requiredPixelBufferAttributesForRenderContext: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
    ]

    // CIContextはCPU/GPU双方のリソースを抱えるため使い回す。GPU(Metal)経由での
    // レンダリングになるようデフォルトの(ソフトウェアレンダラーを強制しない)初期化にする。
    private let context = CIContext()
    private let renderQueue = DispatchQueue(label: "jp.shotoku.later.FilmEmulationVideoCompositor")

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        renderQueue.async { [context] in
            guard let instruction = asyncVideoCompositionRequest.videoCompositionInstruction as? FilmEmulationVideoCompositionInstruction,
                  let sourceBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: instruction.sourceTrackID) else {
                asyncVideoCompositionRequest.finish(with: FilmEmulationVideoError.missingSourceFrame)
                return
            }
            guard let outputBuffer = asyncVideoCompositionRequest.renderContext.newPixelBuffer() else {
                asyncVideoCompositionRequest.finish(with: FilmEmulationVideoError.pixelBufferAllocationFailed)
                return
            }

            let frameIndex = UInt32(truncatingIfNeeded: Int(
                asyncVideoCompositionRequest.compositionTime.seconds * Double(instruction.frameRate)
            ))
            let frameSeed = instruction.baseSeed &+ frameIndex

            let sourceImage = CIImage(cvPixelBuffer: sourceBuffer)
            let processed = FilmEmulation.process(sourceImage, seed: frameSeed)
            context.render(processed, to: outputBuffer, bounds: sourceImage.extent, colorSpace: CGColorSpaceCreateDeviceRGB())
            asyncVideoCompositionRequest.finish(withComposedVideoFrame: outputBuffer)
        }
    }

    func cancelAllPendingVideoCompositionRequests() {
        // 全フレームを同期的にrenderQueueへdispatch::asyncで積んでいるだけで、
        // 個別リクエストへのキャンセルトークンは保持していないため、ここでは何もしない
        // (書き出し失敗時はAVAssetWriter/AVAssetReader側のerrorハンドリングに委ねる)。
    }
}

enum FilmEmulationVideoError: Error {
    case missingSourceFrame
    case pixelBufferAllocationFailed
}
