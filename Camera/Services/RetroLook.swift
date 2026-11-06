import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo
import Foundation

// 動画の質感「RETRO-8」(2017年ごろの iPhone 8 のビデオ)。値は Docs/Mocks/video_look_samples/vlook.py の V と同じ。
// 写真のチェキ(FilmEmulation:ふわっと)とは混ぜない。動画は パキッと・ざらざら・白は飛ぶ・ちょっと安っぽい。
//
// ライブ映像と書き出しは、同じ RetroLook.process を通す(見たとおりに撮れる)。
// 1コマの流れ:解像感を落とす → 露出の呼吸 → かけすぎシャープ・トーン・色・白飛び・まだら・粒・残像・段々・ビネット(1つのカーネル)
//             → ローリングシャッター(かたむき)→ 日付スタンプ
// px の値は幅 360px が基準。実際の幅に合わせて、幅の比で大きくする。
// 色の計算は sRGB の値で行う(vlook.py と同じ)。CIContext の作業色空間を sRGB にして使う。

struct RetroLookParams: Equatable, Sendable {
    var baseWidth = 360.0
    var resScale = 0.80
    var sharpenSigma = 1.0
    var sharpenAmount = 0.85
    var gamma = 0.93
    var contrast = 1.08
    var saturation = 1.10
    var lift: SIMD3<Double> = [0.030, 0.032, 0.040]
    var highlightGain = 1.07
    var warm: SIMD3<Double> = [1.035, 1.0, 0.955]
    var lumaNoise = 0.020
    var lumaNoiseDark = 0.030
    var chromaBlotch = 0.030
    var chromaCell = 7.0
    var ghost = 0.14
    var bandLevels = 44.0
    var bandBelow = 0.34
    var aeAmplitude = 0.045
    var aePeriod = 3.3
    var rollingShutter = 0.9
    var vignette = 0.16
    var stamp = true

    static let `default` = RetroLookParams()

    /// 露出の呼吸(3.3秒周期 ±4.5%)
    func exposure(at t: Double) -> Double {
        1 + aeAmplitude * sin(2 * .pi * t / aePeriod)
    }

    /// ローリングシャッターのかたむき(横の速さ px/秒・幅 360 基準)→ x のずれ = 係数 ×(y − 中心)
    func shear(velocityX: Double) -> Double {
        // vlook.py:sk = vx × rs_k × 0.012 ×((y/H) − 0.5)× H × 0.5
        max(-0.25, min(0.25, velocityX * rollingShutter * 0.012 * 0.5))
    }
}

/// 1本の録画(またはライブ映像)ぶんの状態。残像のため、前のコマの結果を1枚だけ持つ
final class RetroLook: @unchecked Sendable {
    let params: RetroLookParams
    let context: CIContext
    private var previous: CIImage?
    private var frameIndex = 0
    private var stampCache: (text: String, size: CGSize, image: CIImage)?

    init(params: RetroLookParams = .default, context: CIContext? = nil) {
        self.params = params
        self.context = context ?? CIContext(options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .workingFormat: CIFormat.RGBAh,
            .cacheIntermediates: false,
        ])
    }

    private var ghostBuffers: [CVPixelBuffer] = []
    private var ghostIndex = 0

    /// 残像のバッファ(同じ大きさなら使い回す)
    private func ghostBuffer(size: CGSize) -> CVPixelBuffer? {
        let w = Int(size.width), h = Int(size.height)
        if let first = ghostBuffers.first, CVPixelBufferGetWidth(first) != w || CVPixelBufferGetHeight(first) != h { ghostBuffers = [] }
        while ghostBuffers.count < 2 {
            var buffer: CVPixelBuffer?
            let attrs: [CFString: Any] = [kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary, kCVPixelBufferMetalCompatibilityKey: true]
            CVPixelBufferCreate(nil, w, h, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &buffer)
            guard let buffer else { return nil }
            ghostBuffers.append(buffer)
        }
        ghostIndex = (ghostIndex + 1) % 2
        return ghostBuffers[ghostIndex]
    }

    /// 新しい録画のはじまり(残像をリセット)
    func reset() {
        previous = nil
        frameIndex = 0
    }

    /// 熱いときは、残像と色のまだらを切って軽くする
    static var isHot: Bool {
        ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
    }

    /// 1コマを加工する。time = 録画のはじまりからの秒、velocityX = 横の速さ(px/秒・幅 360 基準)、stampText = 「'26 11 05」(nil なら出さない)
    func process(_ input: CIImage, time: Double, velocityX: Double = 0, stampText: String? = nil, light: Bool = RetroLook.isHot) -> CIImage {
        let extent = input.extent
        let k = Double(extent.width) / params.baseWidth
        frameIndex += 1

        // 解像感:いったん 80% に落として戻す
        var a = input
        if params.resScale < 1 {
            let s = CGFloat(params.resScale)
            a = a.transformed(by: CGAffineTransform(scaleX: s, y: s))
                .samplingLinear()
                .transformed(by: CGAffineTransform(scaleX: 1 / s, y: 1 / s))
                .cropped(to: extent)
        }
        // 露出の呼吸
        let ae = params.exposure(at: time)
        // シャープのためのぼかし
        let blur = a.clampedToExtent().applyingGaussianBlur(sigma: params.sharpenSigma * k).cropped(to: extent)
        // 粒と色のまだら:ノイズ画像1枚を、コマごとにずらしてタイル(毎コマ乱数を作らない)
        let grain = Self.tile(offset: frameIndex &* 97, scale: CGFloat(max(1, k * 0.9)), extent: extent)
        let blotch = Self.tile(offset: frameIndex &* 53 &+ 101, scale: CGFloat(params.chromaCell * k), extent: extent)
        let prev = (light ? nil : previous) ?? a

        guard let kernel = Self.kernel else { return a }
        let args: [Any] = [
            a, blur, grain, blotch, prev,
            ae,
            CIVector(x: CGFloat(params.gamma), y: CGFloat(params.contrast), z: CGFloat(params.saturation), w: CGFloat(params.highlightGain)),
            CIVector(x: CGFloat(params.lift.x), y: CGFloat(params.lift.y), z: CGFloat(params.lift.z), w: CGFloat(params.sharpenAmount)),
            CIVector(x: CGFloat(params.warm.x), y: CGFloat(params.warm.y), z: CGFloat(params.warm.z), w: 0),
            CIVector(x: CGFloat(params.lumaNoise), y: CGFloat(params.lumaNoiseDark), z: CGFloat(light ? 0 : params.chromaBlotch), w: CGFloat(light || previous == nil ? 0 : params.ghost)),
            CIVector(x: CGFloat(params.bandLevels), y: CGFloat(params.bandBelow), z: CGFloat(params.vignette), w: 0),
            CIVector(x: extent.minX, y: extent.minY, z: extent.width, w: extent.height),
        ]
        guard var out = kernel.apply(extent: extent, arguments: args) else { return a }
        // 残像のため、このコマの結果を持っておく(かたむき・スタンプの前)。
        // 画像の木が長くならないよう、GPU の中の使い回しバッファ(2枚を交互)に描いてから持つ(CPU へ読み戻さない)
        if !light, let buffer = ghostBuffer(size: extent.size) {
            context.render(out, to: buffer, bounds: extent, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
            previous = CIImage(cvPixelBuffer: buffer).transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
        } else {
            previous = nil
        }
        // ローリングシャッター(横に動くとき、かたむく)
        let shear = params.shear(velocityX: velocityX)
        if abs(shear) > 0.0005 {
            // 中心のまわりで、横にずらす(上と下で逆向き)
            let t = CGAffineTransform(translationX: -extent.midX, y: -extent.midY)
                .concatenating(CGAffineTransform(a: 1, b: 0, c: CGFloat(shear), d: 1, tx: 0, ty: 0))
                .concatenating(CGAffineTransform(translationX: extent.midX, y: extent.midY))
            out = out.clampedToExtent().transformed(by: t).cropped(to: extent)
        }
        // 日付スタンプ(右下・橙の 7セグ)
        if params.stamp, let stampText {
            out = stamp(stampText, size: extent.size, k: k).composited(over: out).cropped(to: extent)
        }
        return out
    }

    // MARK: - カーネル(1回で、トーン・色・白飛び・まだら・粒・残像・段々・ビネット)

    private static let kernel: CIColorKernel? = {
        let source = """
        kernel vec4 retro(__sample src, __sample blur, __sample grain, __sample blotch, __sample prev,
                          float ae, vec4 tone, vec4 liftAmt, vec4 warm, vec4 noise, vec4 band, vec4 rect) {
            vec3 a = clamp(src.rgb * ae, 0.0, 1.0);
            vec3 b = blur.rgb * ae;
            a = clamp(a + (a - b) * liftAmt.w, 0.0, 1.2);
            a = pow(clamp(a, 0.0, 1.0), vec3(tone.x));
            a = 0.5 + (a - 0.5) * tone.y;
            a = liftAmt.rgb + clamp(a, 0.0, 1.3) * (1.0 - liftAmt.rgb);
            a = a * warm.rgb;
            float lum = (a.r + a.g + a.b) / 3.0;
            a = lum + (a - lum) * tone.z;
            float hi = clamp((lum - 0.65) / 0.35, 0.0, 1.0);
            a = clamp(a * (1.0 + (tone.w - 1.0) * hi), 0.0, 1.0);
            lum = (a.r + a.g + a.b) / 3.0;
            float dk = 1.0 - clamp(lum / 0.55, 0.0, 1.0);
            vec3 cn = (blotch.rgb - 0.5) * 3.464;
            cn = cn - (cn.r + cn.g + cn.b) / 3.0;
            a = a + cn * noise.z * dk;
            float gn = (grain.r - 0.5) * 3.464;
            a = a + (noise.x + noise.y * dk) * gn;
            float g = noise.w * (0.35 + 0.65 * dk);
            a = a * (1.0 - g) + prev.rgb * g;
            if (lum < band.y) { a = floor(a * band.x + 0.5) / band.x; }
            vec2 d = destCoord() - rect.xy;
            float ux = (d.x - rect.z * 0.5) / (rect.z * 0.5);
            float uy = (d.y - rect.w * 0.5) / (rect.w * 0.5);
            float v = 1.0 - band.z * pow(clamp((sqrt(ux * ux + uy * uy) - 0.5) / 0.9, 0.0, 1.0), 1.4);
            a = clamp(a * v, 0.0, 1.0);
            return vec4(a, 1.0);
        }
        """
        return CIColorKernel(source: source)
    }()

    // MARK: - ノイズ(256×256 の一様ノイズ1枚。色の変換をかけない)

    private static let noiseSize = 256
    private static let noiseTile: CIImage = {
        var state: UInt64 = 0xD1B5_4A32_D192_ED03
        var bytes = [UInt8](repeating: 255, count: noiseSize * noiseSize * 4)
        for i in 0..<(noiseSize * noiseSize) {
            for ch in 0..<3 {
                state ^= state << 13; state ^= state >> 7; state ^= state << 17
                bytes[i * 4 + ch] = UInt8(truncatingIfNeeded: state >> 24)
            }
        }
        return CIImage(bitmapData: Data(bytes), bytesPerRow: noiseSize * 4, size: CGSize(width: noiseSize, height: noiseSize), format: .RGBA8, colorSpace: nil)
    }()

    private static func tile(offset: Int, scale: CGFloat, extent: CGRect) -> CIImage {
        let o = CGFloat(offset % noiseSize)
        let f = CIFilter.affineTile()
        f.inputImage = noiseTile.samplingNearest()
        f.transform = CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: -o, y: -o * 0.61)
        return (f.outputImage ?? noiseTile).cropped(to: extent)
    }

    // MARK: - 日付スタンプ(橙の 7セグ・にじむ光)

    private func stamp(_ text: String, size: CGSize, k: Double) -> CIImage {
        if let cached = stampCache, cached.text == text, cached.size == size { return cached.image }
        let image = RetroStamp.image(text: text, size: size, scale: k)
        stampCache = (text, size, image)
        return image
    }
}

/// 7セグの日付スタンプ(vlook.py の stamp_layer と同じ形)
enum RetroStamp {
    static func segments(_ ch: Character) -> String {
        ["0": "abcdef", "1": "bc", "2": "abdeg", "3": "abcdg", "4": "bcfg", "5": "acdfg", "6": "acdefg", "7": "abc", "8": "abcdefg", "9": "abcdfg"][ch] ?? ""
    }

    /// 「'26 11 05」
    static func text(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "'%02d %02d %02d", (c.year ?? 2026) % 100, c.month ?? 1, c.day ?? 1)
    }

    static func image(text: String, size: CGSize, scale k: Double) -> CIImage {
        let w = Int(size.width), h = Int(size.height)
        guard w > 0, h > 0, let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return CIImage.empty()
        }
        // CG は左下が原点。vlook.py の y(上から)を下からに直して描く
        let s = CGFloat(k)
        let dw = 8 * s, dh = 15 * s, t = 2 * s, gap = 4 * s
        let total = text.reduce(CGFloat(0)) { $0 + ((" '".contains($1)) ? dw * 0.55 + gap : dw + gap) }
        var x = CGFloat(w) - 18 * s - total
        // 形は上からの y で計算し(vlook.py と同じ)、描くときに下からの y に直す
        let y0 = CGFloat(h) - 22 * s - dh
        func flip(_ y: CGFloat) -> CGFloat { CGFloat(h) - y }
        ctx.setFillColor(gray: 1, alpha: 1)
        func poly(_ pts: [(CGFloat, CGFloat)]) {
            guard let first = pts.first else { return }
            ctx.beginPath()
            ctx.move(to: CGPoint(x: first.0, y: flip(first.1)))
            for p in pts.dropFirst() { ctx.addLine(to: CGPoint(x: p.0, y: flip(p.1))) }
            ctx.closePath()
            ctx.fillPath()
        }
        for c in text {
            if c == "'" {
                poly([(x + 3 * s, y0), (x + 5 * s, y0), (x + 3.4 * s, y0 + 6 * s), (x + 2 * s, y0 + 6 * s)])
                x += dw * 0.55 + gap
                continue
            }
            if c == " " { x += dw * 0.55 + gap; continue }
            func hseg(_ sy: CGFloat) {
                let yy = y0 + sy * dh
                poly([(x + t * 0.7, yy), (x + t * 1.1, yy - t / 2), (x + dw - t * 1.1, yy - t / 2), (x + dw - t * 0.7, yy), (x + dw - t * 1.1, yy + t / 2), (x + t * 1.1, yy + t / 2)])
            }
            func vseg(_ sx: CGFloat, _ sy: CGFloat) {
                let xx = x + sx * dw, ya = y0 + sy * dh + t * 0.7, yb = y0 + (sy + 0.5) * dh - t * 0.7
                poly([(xx, ya), (xx + t / 2, ya + t / 2), (xx + t / 2, yb - t / 2), (xx, yb), (xx - t / 2, yb - t / 2), (xx - t / 2, ya + t / 2)])
            }
            for seg in segments(c) {
                switch seg {
                case "a": hseg(0)
                case "g": hseg(0.5)
                case "d": hseg(1)
                case "f": vseg(0, 0)
                case "b": vseg(1, 0)
                case "e": vseg(0, 0.5)
                case "c": vseg(1, 0.5)
                default: break
                }
            }
            x += dw + gap
        }
        guard let cg = ctx.makeImage() else { return CIImage.empty() }
        let core = CIImage(cgImage: cg)
        let extent = core.extent
        // にじむ光:glow = blur(2.2)×0.9 + blur(6)×0.5 → 橙 (1, .54, .16)×0.55 を足す。芯は (1, .62, .22)
        let g1 = core.clampedToExtent().applyingGaussianBlur(sigma: 2.2 * k).cropped(to: extent)
        let g2 = core.clampedToExtent().applyingGaussianBlur(sigma: 6 * k).cropped(to: extent)
        func colored(_ img: CIImage, _ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat) -> CIImage {
            let m = CIFilter.colorMatrix()
            m.inputImage = img
            m.rVector = CIVector(x: r, y: 0, z: 0, w: 0)
            m.gVector = CIVector(x: g, y: 0, z: 0, w: 0)
            m.bVector = CIVector(x: b, y: 0, z: 0, w: 0)
            m.aVector = CIVector(x: a, y: 0, z: 0, w: 0)
            return m.outputImage ?? img
        }
        let glow = colored(g1, 1.0 * 0.9 * 0.55, 0.54 * 0.9 * 0.55, 0.16 * 0.9 * 0.55, 0.9 * 0.55)
            .composited(over: colored(g2, 1.0 * 0.5 * 0.55, 0.54 * 0.5 * 0.55, 0.16 * 0.5 * 0.55, 0.5 * 0.55))
        let coreColored = colored(core, 1.0 * 0.92, 0.62 * 0.92, 0.22 * 0.92, 0.92)
        return coreColored.composited(over: glow).cropped(to: extent)
    }
}
