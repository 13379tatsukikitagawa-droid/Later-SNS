// 参考(形の 見本)・ そのまま コピー しない。PROMPT_v107.md が 正解。数字は tools/film/film_pipeline.py と 同じ。
// ねらい:撮った 時に **1回 だけ** 焼きこむ。表示の 時には 何も しない(軽い)。焼いた ファイルを そのまま 保存 ・ 送る(友だちにも 同じ 質感)。
import CoreImage
import CoreImage.CIFilterBuiltins
import AVFoundation
import UIKit

final class FilmLook {
    static let shared = FilmLook()

    // CIContext は アプリで 1つ(作るのが 重い)。半精度で メモリを へらす。
    let context = CIContext(options: [
        .workingFormat: CIFormat.RGBAh,
        .cacheIntermediates: false,
        .priorityRequestLow: true,
    ])
    private let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

    // 使う 時に 1回 だけ 読む(Assets / Bundle:cheki_v2_lut33.bin ・ retro8_lut33.bin ・ grain_512.png)
    private lazy var chekiLUT: Data = Self.load("cheki_v2_lut33", "bin")
    private lazy var retro8LUT: Data = Self.load("retro8_lut33", "bin")
    private lazy var grainTile: CIImage = {
        let url = Bundle.main.url(forResource: "grain_512", withExtension: "png")!
        return CIImage(contentsOf: url)!.applyingFilter("CIAffineTile")   // ならべて 無限に
    }()
    private static func load(_ n: String, _ e: String) -> Data {
        try! Data(contentsOf: Bundle.main.url(forResource: n, withExtension: e)!)
    }

    // MARK: - 写真:チェキ
    struct Cheki {
        static let longEdge: CGFloat = 1440      // Instax の 解像(約 12本/mm × 62mm × 2)
        static let soften: CGFloat = 0.86        // 1回 小さく して もどす = 少し やわらかい
        static let bloomSigma: Double = 8        // 1440px の とき
        static let bloomIntensity: CGFloat = 0.22
        static let vignetteIntensity: Double = 0.42
        static let vignetteRadius: Double = 1.15
        static let grainAlpha: CGFloat = 0.55
        static let jpegQuality: CGFloat = 0.85
    }

    /// 撮った 写真(HEIC / JPEG の Data)→ チェキの JPEG(EXIF ・ 位置情報 なし)
    func chekiJPEG(from photoData: Data, cropAspect: CGFloat? = 3.0 / 4.0, seed: UInt64) -> Data? {
        guard var img = CIImage(data: photoData, options: [.applyOrientationProperty: true]) else { return nil }
        img = img.settingProperties([:])                    // ← メタデータを 捨てる(EXIF ・ GPS)

        // 0) 切りぬき(今の アプリの 比率の まま)
        if let r = cropAspect { img = Self.centerCrop(img, aspect: r) }

        // 1) 縮小 → 解像感を 少し 落とす
        let s = Cheki.longEdge / max(img.extent.width, img.extent.height)
        img = img.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: s * Cheki.soften, kCIInputAspectRatioKey: 1])
        img = img.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: 1 / Cheki.soften, kCIInputAspectRatioKey: 1])
        img = img.cropped(to: img.extent.integral)
        let extent = img.extent

        // 2) 色(LUT 33³ ・ sRGB で 引く)
        img = lut(img, chekiLUT)

        // 3) にじみ:ぼかした 物の 明るい 所 だけ を 足す
        let k = extent.width / 1440
        let blur = img.clampedToExtent().applyingGaussianBlur(sigma: Cheki.bloomSigma * k).cropped(to: extent)
        let hi = blur.applyingFilter("CIToneCurve", parameters: [
            "inputPoint0": CIVector(x: 0, y: 0), "inputPoint1": CIVector(x: 0.55, y: 0),
            "inputPoint2": CIVector(x: 0.75, y: 0.25), "inputPoint3": CIVector(x: 0.9, y: 0.7), "inputPoint4": CIVector(x: 1, y: 1)])
        let hiScaled = hi.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: Cheki.bloomIntensity, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: Cheki.bloomIntensity, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: Cheki.bloomIntensity, w: 0)])
        img = hiScaled.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: img]).cropped(to: extent)

        // 4) ビネット
        img = img.applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: Cheki.vignetteIntensity, kCIInputRadiusKey: Cheki.vignetteRadius])

        // 5) 粒子(タイル ・ 写真ごとに ずらす ・ ソフトライト)
        img = grain(over: img, alpha: Cheki.grainAlpha, seed: seed)

        return context.jpegRepresentation(of: img, colorSpace: srgb,
                                          options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: Cheki.jpegQuality])
    }

    // MARK: - 動画:iPhone 8 風(撮った あと 1回 書き出す)
    struct Retro8 {
        static let sharpness: Double = 0.35
        static let grainAlpha: CGFloat = 0.30
    }

    /// 録画の あと:LUT + うすい シャープ + 粒子(こまごとに ずらす)→ 1080p30 H.264 の mp4
    func exportRetro8(input: URL, output: URL) async throws {
        let asset = AVURLAsset(url: input)
        let lutData = retro8LUT
        let ctx = context
        let comp = try await AVMutableVideoComposition.videoComposition(with: asset) { [weak self] req in
            guard let self else { req.finish(with: NSError(domain: "FilmLook", code: 1)); return }
            let ext = req.sourceImage.extent
            var img = self.lut(req.sourceImage, lutData)
            img = img.applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: Retro8.sharpness, kCIInputRadiusKey: 1.2])
            let frame = UInt64(max(0, req.compositionTime.seconds * 30))
            img = self.grain(over: img, alpha: Retro8.grainAlpha, seed: frame).cropped(to: ext)
            req.finish(with: img, context: ctx)
        }
        comp.frameDuration = CMTime(value: 1, timescale: 30)   // 30fps(iPhone 8 の ふつうの 動画)

        guard let ex = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1920x1080) else { throw NSError(domain: "FilmLook", code: 2) }
        ex.videoComposition = comp
        ex.shouldOptimizeForNetworkUse = true
        ex.metadataItemFilter = .forSharing()                    // 位置情報などを のぞく
        try await ex.export(to: output, as: .mp4)               // iOS 18〜。それ より 前は exportAsynchronously
    }

    // MARK: - 部品
    private func lut(_ img: CIImage, _ data: Data) -> CIImage {
        let f = CIFilter.colorCubeWithColorSpace()
        f.inputImage = img
        f.cubeDimension = 33
        f.cubeData = data
        f.colorSpace = srgb            // LUT は sRGB の 値で 作って ある
        return f.outputImage ?? img
    }

    private func grain(over img: CIImage, alpha: CGFloat, seed: UInt64) -> CIImage {
        var rng = SplitMix64(seed: seed)
        let ox = CGFloat(rng.next() % 512), oy = CGFloat(rng.next() % 512)
        let g = grainTile.transformed(by: CGAffineTransform(translationX: ox, y: oy))
            .applyingFilter("CIColorMatrix", parameters: [          // 0.5 を 中心に 強さを しぼる
                "inputRVector": CIVector(x: alpha, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: alpha, y: 0, z: 0, w: 0),   // 灰色の タイル(R を 3つに)
                "inputBVector": CIVector(x: alpha, y: 0, z: 0, w: 0),
                "inputBiasVector": CIVector(x: 0.5 * (1 - alpha), y: 0.5 * (1 - alpha), z: 0.5 * (1 - alpha), w: 0)])
            .cropped(to: img.extent)
        return g.applyingFilter("CISoftLightBlendMode", parameters: [kCIInputBackgroundImageKey: img]).cropped(to: img.extent)
    }

    private static func centerCrop(_ img: CIImage, aspect: CGFloat) -> CIImage {
        let e = img.extent
        var w = e.width, h = e.height
        if w / h > aspect { w = h * aspect } else { h = w / aspect }
        return img.cropped(to: CGRect(x: e.midX - w / 2, y: e.midY - h / 2, width: w, height: h))
            .transformed(by: CGAffineTransform(translationX: -(e.midX - w / 2), y: -(e.midY - h / 2)))
    }
}

/// 同じ seed なら 同じ 粒子(テストで くらべられる)
struct SplitMix64 { var s: UInt64; init(seed: UInt64) { s = seed }
    mutating func next() -> UInt64 { s &+= 0x9E3779B97F4A7C15; var z = s; z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9; z = (z ^ (z >> 27)) &* 0x94D049BB133111EB; return z ^ (z >> 31) } }

// MARK: - 撮る 時の 設定(iPhone 8 らしさの 半分は ここで 決まる ・ 処理 0)
enum Retro8Capture {
    static func configure(device: AVCaptureDevice, movieOutput: AVCaptureMovieFileOutput, connection: AVCaptureConnection) throws {
        try device.lockForConfiguration()
        // 1080p / 30fps の フォーマット(4K ・ 60fps に しない)
        if let f = device.formats.first(where: {
            let d = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
            return d.width == 1920 && d.height == 1080 && $0.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 30 }
        }) { device.activeFormat = f }
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
        // HDR 動画 なし(iPhone 8 には 無かった)・ SDR の sRGB
        if device.activeFormat.isVideoHDRSupported {
            device.automaticallyAdjustsVideoHDREnabled = false
            device.isVideoHDREnabled = false
        }
        if device.activeFormat.supportedColorSpaces.contains(.sRGB) { device.activeColorSpace = .sRGB }
        device.unlockForConfiguration()
        // 手ぶれ補正は ふつう(強い 補正に しない)
        if connection.isVideoStabilizationSupported { connection.preferredVideoStabilizationMode = .standard }
        // H.264
        if movieOutput.availableVideoCodecTypes.contains(.h264) {
            movieOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.h264], for: connection)
        }
    }
}
