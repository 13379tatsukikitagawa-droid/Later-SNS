import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// v107:写真 = チェキ ・ 動画 = iPhone 8 の 質感。**撮った 時に 1回 だけ 焼きこむ**(表示の 時には 何も かけない)。
/// 数字は `Design/LattagKit/tools/film/film_pipeline.py` と 同じ。焼いた ファイルに `filmVersion = 2` の しるしを つける。
nonisolated final class FilmLook: @unchecked Sendable {
    static let shared = FilmLook()
    /// 焼いた ファイルの しるし(写真 ・ 動画 とも)
    static let version = 2

    /// CIContext は アプリで 1つ(作るのが 重い)。半精度で メモリを へらす
    /// 作業は sRGB の まま(film_pipeline.py が sRGB の 値で 作って ある ・ 線形に すると にじみ ・ ビネット ・ 粒子が 暗く 出る)
    private static let srgbSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CIContext(options: [.workingColorSpace: FilmLook.srgbSpace, .workingFormat: CIFormat.RGBAh, .cacheIntermediates: false, .priorityRequestLow: true])
    private var srgb: CGColorSpace { Self.srgbSpace }

    // 使う 時に 1回 だけ 読む
    private lazy var chekiLUT: Data = Self.load("cheki_v2_lut33", "bin")
    private lazy var retro8LUT: Data = Self.load("retro8_lut33", "bin")
    private lazy var grainTile: CIImage = {
        guard let url = Bundle.main.url(forResource: "grain_512", withExtension: "png"), let img = CIImage(contentsOf: url) else { return CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: CGRect(x: 0, y: 0, width: 512, height: 512)) }
        return img.applyingFilter("CIAffineTile")
    }()
    private static func load(_ n: String, _ e: String) -> Data {
        guard let url = Bundle.main.url(forResource: n, withExtension: e), let d = try? Data(contentsOf: url) else { return Data() }
        return d
    }

    // MARK: 写真:チェキ
    enum Cheki {
        static let longEdge: CGFloat = 1440
        static let soften: CGFloat = 0.86
        static let bloomSigma: Double = 8
        static let bloomIntensity: CGFloat = 0.22
        static let vignetteIntensity: Double = 0.42
        static let vignetteRadius: Double = 1.15
        static let grainAlpha: CGFloat = 0.55
        static let jpegQuality: CGFloat = 0.85
    }

    /// 撮った 写真(HEIC / JPEG の Data)→ チェキの JPEG(EXIF ・ 位置情報 なし)。`seed` が 同じ なら 同じ 粒子
    func chekiJPEG(from photoData: Data, cropAspect: CGFloat? = 3.0 / 4.0, seed: UInt64) -> Data? {
        guard var img = CIImage(data: photoData, options: [.applyOrientationProperty: true]) else { return nil }
        img = img.settingProperties([:])
        if let r = cropAspect { img = Self.centerCrop(img, aspect: r) }
        return render(img, seed: seed)
    }

    /// 撮った 写真(UIImage)から(向きは もう 直って いる)
    func chekiJPEG(from image: UIImage, cropAspect: CGFloat? = 3.0 / 4.0, seed: UInt64) -> Data? {
        guard var img = CIImage(image: image) else { return nil }
        img = img.settingProperties([:])
        if let r = cropAspect { img = Self.centerCrop(img, aspect: r) }
        return render(img, seed: seed)
    }

    private func render(_ input: CIImage, seed: UInt64) -> Data? {
        var img = input
        let s = Cheki.longEdge / max(img.extent.width, img.extent.height)
        let k0 = min(1, s)   // 小さい 写真は 大きく しない
        img = img.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: k0 * Cheki.soften, kCIInputAspectRatioKey: 1])
        img = img.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: 1 / Cheki.soften, kCIInputAspectRatioKey: 1])
        img = img.cropped(to: img.extent.integral)
        let extent = img.extent

        img = lut(img, chekiLUT)

        let k = extent.width / 1440
        let blur = img.clampedToExtent().applyingGaussianBlur(sigma: Cheki.bloomSigma * Double(k)).cropped(to: extent)
        let hi = blur.applyingFilter("CIToneCurve", parameters: [
            "inputPoint0": CIVector(x: 0, y: 0), "inputPoint1": CIVector(x: 0.55, y: 0),
            "inputPoint2": CIVector(x: 0.75, y: 0.25), "inputPoint3": CIVector(x: 0.9, y: 0.7), "inputPoint4": CIVector(x: 1, y: 1)])
        let hiScaled = hi.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: Cheki.bloomIntensity, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: Cheki.bloomIntensity, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: Cheki.bloomIntensity, w: 0)])
        img = hiScaled.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: img]).cropped(to: extent).settingAlphaOne(in: extent)   // 足しざん合成は 不透明度も 足す → 1 に もどす

        // ビネット:film_pipeline.py の 式(1 - 強さ × smoothstep(0.35, 半径, d)^1.5)を 小さな 画像に 1回 だけ 作って 引きのばす
        let mask = Self.vignetteMask.transformed(by: CGAffineTransform(scaleX: extent.width / 128, y: extent.height / 128)).transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY)).cropped(to: extent)
        img = img.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: mask]).cropped(to: extent)
        img = grain(over: img, alpha: Cheki.grainAlpha, seed: seed)

        return context.jpegRepresentation(of: img, colorSpace: srgb, options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: Cheki.jpegQuality])
    }

    /// テスト用:LUT だけ を かけた 結果(色の 方向の 確認)
    func lutOnly(_ img: CIImage, cheki: Bool) -> CIImage { lut(img, cheki ? chekiLUT : retro8LUT) }

    /// 128 × 128 の ビネット(1回 だけ 作る)
    private static let vignetteMask: CIImage = {
        let n = 128
        var px = [UInt8](repeating: 255, count: n * n * 4)
        func smooth(_ a: Double, _ b: Double, _ x: Double) -> Double { let t = min(1, max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t) }
        for y in 0..<n { for x in 0..<n {
            let nx = (Double(x) + 0.5 - 64) / 64, ny = (Double(y) + 0.5 - 64) / 64
            let d = (nx * nx + ny * ny).squareRoot() / 2.0.squareRoot()
            let v = 1 - Cheki.vignetteIntensity * pow(smooth(0.35, Cheki.vignetteRadius, d), 1.5)
            let b = UInt8(max(0, min(255, (v * 255).rounded())))
            let i = (y * n + x) * 4
            px[i] = b; px[i + 1] = b; px[i + 2] = b; px[i + 3] = 255
        } }
        let data = Data(px)
        return CIImage(bitmapData: data, bytesPerRow: n * 4, size: CGSize(width: n, height: n), format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
    }()

    // MARK: 動画:iPhone 8 風(撮った あと 1回 書き出す ・ 1こま ずつ GPU)
    enum Retro8 {
        static let sharpness: Double = 0.35
        static let sharpRadius: Double = 1.2
        static let grainAlpha: CGFloat = 0.30
    }

    /// 1こま:LUT(色)→ うすい シャープ → 粒子(こまごとに ずらす)。向き ・ 大きさは 呼ぶ 側で そろえて ある
    func retro8Frame(_ input: CIImage, frame: Int) -> CIImage {
        let ext = input.extent
        var img = lut(input, retro8LUT)
        img = img.applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: Retro8.sharpness, kCIInputRadiusKey: Retro8.sharpRadius]).cropped(to: ext)
        return grain(over: img, alpha: Retro8.grainAlpha, seed: UInt64(max(0, frame))).cropped(to: ext).settingAlphaOne(in: ext)
    }

    // MARK: 部品
    private func lut(_ img: CIImage, _ data: Data) -> CIImage {
        let f = CIFilter.colorCubeWithColorSpace()
        f.inputImage = img
        f.cubeDimension = 33
        f.cubeData = data
        f.colorSpace = srgb
        return f.outputImage ?? img
    }

    func grain(over img: CIImage, alpha: CGFloat, seed: UInt64) -> CIImage {
        var z = seed &+ 0x9E3779B97F4A7C15
        func mix() -> UInt64 { z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9; z = (z ^ (z >> 27)) &* 0x94D049BB133111EB; z ^= z >> 31; z &+= 0x9E3779B97F4A7C15; return z }
        let ox = CGFloat(mix() % 512), oy = CGFloat(mix() % 512)
        let g = grainTile.transformed(by: CGAffineTransform(translationX: ox, y: oy))
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: alpha, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: alpha, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: alpha, y: 0, z: 0, w: 0),
                "inputBiasVector": CIVector(x: 0.5 * (1 - alpha), y: 0.5 * (1 - alpha), z: 0.5 * (1 - alpha), w: 0)])
            .cropped(to: img.extent)
        return g.applyingFilter("CISoftLightBlendMode", parameters: [kCIInputBackgroundImageKey: img]).cropped(to: img.extent)
    }

    static func centerCrop(_ img: CIImage, aspect: CGFloat) -> CIImage {
        let e = img.extent
        var w = e.width, h = e.height
        if w / h > aspect { w = h * aspect } else { h = w / aspect }
        let r = CGRect(x: e.midX - w / 2, y: e.midY - h / 2, width: w, height: h).integral
        return img.cropped(to: r).transformed(by: CGAffineTransform(translationX: -r.minX, y: -r.minY))
    }

    /// 写真ごとに ちがう 粒子の 種(元の バイト列から)
    static func seed(for data: Data) -> UInt64 {
        var h: UInt64 = 1469598103934665603
        for b in data.prefix(4096) { h = (h ^ UInt64(b)) &* 1099511628211 }
        return h
    }
}
