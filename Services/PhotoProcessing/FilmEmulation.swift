import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// チェキっぽい写真にする Core Image のフィルタチェーン(2026-11 見本:Docs/Mocks/later_me_mondo_v19_cheki.html)。
/// ChekiColorGrade(ChekiPhotoFrame.swift)から呼ばれる。保存する写真に、解禁の直前に1回だけ焼き込む
/// (isColorGraded で二重にかけない)。日がたって色あせる表現(ME)は、表示側のフィルタで別にかける。
///
/// 目ざす見た目:ふわっと白っぽく、ほんのり赤みのクリーム色。黒は真っ黒にしない(影は青緑)。光はにじみ、ふちが少しとける。粒は細かく。
///
/// 順番:レンズ(ぼかしをまぜる)→ 色収差 → 色(3D LUT:ガンマ・曲線・色相・彩度・マゼンタ・黒の持ち上げ・白の肩)
///       → ハレーション → ビネット(四隅に緑青)→ 現像ムラ → 夜のフラッシュ → ふちの化学反応 → 粒子
/// 半径などの px は「幅 420px のとき」の値。写真の幅に合わせて大きくする。
enum FilmEmulation {

    // MARK: - 値(見本の cheki_pipeline.py の値)

    struct Configuration {
        /// 0(加工なし)〜1(ぜんぶ)。現像中プレビューの段階表示に使う
        var strength: Double = 1

        // レンズ
        var lensBlur = 0.9
        var lensMix = 0.55
        // 色収差(ふちほど強く)
        var aberration = 0.8
        // 色
        var gamma = 0.82
        var contrast = 1.02
        var blackLift: SIMD3<Double> = [0.070, 0.075, 0.105]
        var whiteShoulder: SIMD3<Double> = [0.965, 0.945, 0.915]
        /// 緑 → 黄緑 / 青 → 青緑(度)
        var greenToYellow = 9.0
        var blueToCyan = 7.0
        var saturation = 1.12
        /// 赤〜橙を さらに
        var warmSaturation = 0.10
        /// 中間のマゼンタ
        var midMagenta = 0.02
        // ハレーション
        var halationThreshold = 0.78
        var halationRadius = 11.0
        var halationStrength = 0.30
        var halationColor: SIMD3<Double> = [1.0, 0.52, 0.30]
        // ビネット(中心は少し左上)
        var vignette = 0.24
        // 現像ムラ
        var unevenLuma = 0.03
        var unevenColor = 0.035
        // 粒子
        var grainLuma = 0.020
        var grainChroma = 0.008
        // ふちの化学反応(端の約5px をクリームにとかす・極細の暗い線)
        var edgeWidth = 5.0
        var edgeCream = 0.26
        var edgeLine = 0.12
        /// 夜の撮影:中心を明るく、周りを落とす
        var nightFlash = false

        static let `default` = Configuration()
    }

    /// data から安定した seed を作る(粒子・現像ムラの位置)
    static func seed(for data: Data) -> UInt32 {
        var hash: UInt32 = 2166136261
        for byte in data.prefix(4096) { hash = (hash ^ UInt32(byte)) &* 16777619 }
        return hash ^ UInt32(truncatingIfNeeded: data.count)
    }

    /// 撮った時刻が夜(21:00〜9:00)か(フラッシュの表現)
    static func isNightShot(_ date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= 21 || hour < 9
    }

    // MARK: - 現像中プレビュー用

    /// progress(0 = 撮った直後 〜 1 = 仕上がり)に合わせて、加工の強さを上げていく
    static func developingConfiguration(progress: Double) -> Configuration {
        var config = Configuration.default
        let p = min(1, max(0, progress))
        // 30% までは ほぼ元のまま → 95% で ぜんぶ
        let local = min(1, max(0, (p - 0.3) / 0.65))
        config.strength = PhotoUnlockUtilities.applyEasing(progress: local, easingType: .easeInOut)
        return config
    }

    // MARK: - 入口

    static func process(_ image: CIImage, configuration: Configuration = .default, seed: UInt32) -> CIImage {
        let extent = image.extent
        guard configuration.strength > 0, extent.width > 1, extent.height > 1 else { return image }
        let c = configuration
        let k = max(0.5, Double(min(extent.width, extent.height)) / 420)

        var out = image
        out = lens(out, extent: extent, radius: c.lensBlur * k, mix: c.lensMix)
        out = aberration(out, extent: extent, shift: c.aberration * k)
        out = colorCube(out, configuration: c)
        out = halation(out, extent: extent, configuration: c, k: k)
        out = vignette(out, extent: extent, amount: c.vignette)
        out = uneven(out, extent: extent, configuration: c, seed: seed)
        if c.nightFlash { out = flash(out, extent: extent) }
        out = edges(out, extent: extent, configuration: c, k: k)
        out = grain(out, extent: extent, configuration: c, seed: seed, k: k)
        out = out.cropped(to: extent)

        if c.strength < 1 {
            let dissolve = CIFilter.dissolveTransition()
            dissolve.inputImage = image
            dissolve.targetImage = out
            dissolve.time = Float(c.strength)
            return (dissolve.outputImage ?? out).cropped(to: extent)
        }
        return out
    }

    // MARK: - レンズ:ぼかしを元とまぜる

    private static func lens(_ image: CIImage, extent: CGRect, radius: Double, mix: Double) -> CIImage {
        let blur = image.clampedToExtent().applyingGaussianBlur(sigma: radius).cropped(to: extent)
        let dissolve = CIFilter.dissolveTransition()
        dissolve.inputImage = image
        dissolve.targetImage = blur
        dissolve.time = Float(mix)
        return dissolve.outputImage?.cropped(to: extent) ?? image
    }

    // MARK: - 色収差:赤と青を左右にずらす(ふちほど強く)

    private static func aberration(_ image: CIImage, extent: CGRect, shift: Double) -> CIImage {
        let clamped = image.clampedToExtent()
        // 赤だけ・緑だけ・青だけの絵を、チャンネルごとの最大でまとめる(足し算は透明度まで足されるので使わない)
        let red = channel(clamped, r: 1, g: 0, b: 0).transformed(by: CGAffineTransform(translationX: shift, y: 0))
        let green = channel(clamped, r: 0, g: 1, b: 0)
        let blue = channel(clamped, r: 0, g: 0, b: 1).transformed(by: CGAffineTransform(translationX: -shift, y: 0))
        let shifted = maximum(maximum(red, green), blue).cropped(to: extent)
        // まん中はずらさない → ふちほど ずれる
        let mask = radialMask(extent: extent, center: CGPoint(x: extent.midX, y: extent.midY), inner: 0.25, outer: 0.75, innerValue: 0, outerValue: 1)
        return blend(base: image, top: shifted, mask: mask, extent: extent)
    }

    // MARK: - 色(33³ の 3D LUT。sRGB の値で計算する)

    private static func colorCube(_ image: CIImage, configuration c: Configuration) -> CIImage {
        let data = cubeData(c)
        let filter = CIFilter.colorCubeWithColorSpace()
        filter.inputImage = image
        filter.cubeDimension = Float(cubeSize)
        filter.cubeData = data
        filter.colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        return filter.outputImage ?? image
    }

    static let cubeSize = 33
    /// いつもの値の LUT は1回だけ作る(static let は、どのスレッドからでも安全に1回だけ作られる)
    private static let defaultCube: Data = makeCube(.default)

    static func cubeData(_ c: Configuration) -> Data {
        let d = Configuration.default
        let same = c.gamma == d.gamma && c.contrast == d.contrast && c.blackLift == d.blackLift && c.whiteShoulder == d.whiteShoulder
            && c.greenToYellow == d.greenToYellow && c.blueToCyan == d.blueToCyan && c.saturation == d.saturation
            && c.warmSaturation == d.warmSaturation && c.midMagenta == d.midMagenta
        return same ? defaultCube : makeCube(c)
    }

    private static func makeCube(_ c: Configuration) -> Data {
        let n = cubeSize
        var values = [Float](repeating: 0, count: n * n * n * 4)
        var i = 0
        for b in 0..<n {
            for g in 0..<n {
                for r in 0..<n {
                    let rgb = grade(SIMD3(Double(r), Double(g), Double(b)) / Double(n - 1), c)
                    values[i] = Float(rgb.x); values[i + 1] = Float(rgb.y); values[i + 2] = Float(rgb.z); values[i + 3] = 1
                    i += 4
                }
            }
        }
        return values.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    /// 1色ぶんの色の加工(sRGB 0〜1)
    static func grade(_ input: SIMD3<Double>, _ c: Configuration) -> SIMD3<Double> {
        // ガンマ(白っぽく)と、コントラスト
        var v = SIMD3(pow(input.x, c.gamma), pow(input.y, c.gamma), pow(input.z, c.gamma))
        v = (v - 0.5) * c.contrast + 0.5
        v = simd_clamp01(v)
        // 色相・彩度(HSV)
        var (h, s, val) = hsv(v)
        let greenW = window(h, center: 120, width: 45), blueW = window(h, center: 220, width: 40)
        h -= c.greenToYellow * greenW + c.blueToCyan * blueW
        if h < 0 { h += 360 }
        let warmW = max(window(h, center: 20, width: 30), window(h, center: 360, width: 20))
        s = min(1, s * c.saturation * (1 + c.warmSaturation * warmW))
        v = rgb(h, s, val)
        // 中間のマゼンタ
        let luma = 0.299 * v.x + 0.587 * v.y + 0.114 * v.z
        let mid = 4 * luma * (1 - luma)
        v += SIMD3(c.midMagenta, -c.midMagenta, c.midMagenta) * 0.5 * mid
        v = simd_clamp01(v)
        // 黒の持ち上げ(青緑の影)・白の肩(クリーム)
        return c.blackLift + v * (c.whiteShoulder - c.blackLift)
    }

    private static func simd_clamp01(_ v: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(min(1, max(0, v.x)), min(1, max(0, v.y)), min(1, max(0, v.z)))
    }

    /// 色相の窓(中心から width 度で 0 になる、なめらかな山)
    private static func window(_ h: Double, center: Double, width: Double) -> Double {
        var d = abs(h - center)
        if d > 180 { d = 360 - d }
        guard d < width else { return 0 }
        let t = d / width
        return 1 - t * t * (3 - 2 * t)
    }

    private static func hsv(_ c: SIMD3<Double>) -> (Double, Double, Double) {
        let mx = max(c.x, c.y, c.z), mn = min(c.x, c.y, c.z), d = mx - mn
        var h = 0.0
        if d > 1e-6 {
            if mx == c.x { h = 60 * ((c.y - c.z) / d).truncatingRemainder(dividingBy: 6) }
            else if mx == c.y { h = 60 * ((c.z - c.x) / d + 2) }
            else { h = 60 * ((c.x - c.y) / d + 4) }
        }
        if h < 0 { h += 360 }
        return (h, mx == 0 ? 0 : d / mx, mx)
    }

    private static func rgb(_ h: Double, _ s: Double, _ v: Double) -> SIMD3<Double> {
        let c = v * s, x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1)), m = v - c
        let (r, g, b): (Double, Double, Double)
        switch h {
        case ..<60: (r, g, b) = (c, x, 0)
        case ..<120: (r, g, b) = (x, c, 0)
        case ..<180: (r, g, b) = (0, c, x)
        case ..<240: (r, g, b) = (0, x, c)
        case ..<300: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        return SIMD3(r + m, g + m, b + m)
    }

    // MARK: - ハレーション:明るい所が橙赤ににじむ

    private static func halation(_ image: CIImage, extent: CGRect, configuration c: Configuration, k: Double) -> CIImage {
        // 作業色空間は linear なので、sRGB のしきい値を linear にする
        let t = pow(c.halationThreshold, 2.2)
        let scale = 1 / max(0.01, 1 - t)
        let luma = CIFilter.colorMatrix()
        luma.inputImage = image
        let w = CIVector(x: 0.2126 * scale, y: 0.7152 * scale, z: 0.0722 * scale, w: 0)
        luma.rVector = w; luma.gVector = w; luma.bVector = w
        luma.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        luma.biasVector = CIVector(x: -t * scale, y: -t * scale, z: -t * scale, w: 0)
        guard let bright = luma.outputImage?.applyingFilter("CIColorClamp") else { return image }
        let glow = bright.clampedToExtent().applyingGaussianBlur(sigma: c.halationRadius * k).cropped(to: extent)
        let tint = CIFilter.colorMatrix()
        tint.inputImage = glow
        let a = c.halationStrength
        tint.rVector = CIVector(x: c.halationColor.x * a, y: 0, z: 0, w: 0)
        tint.gVector = CIVector(x: 0, y: c.halationColor.y * a, z: 0, w: 0)
        tint.bVector = CIVector(x: 0, y: 0, z: c.halationColor.z * a, w: 0)
        tint.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        guard let colored = tint.outputImage else { return image }
        let screen = CIFilter.screenBlendMode()
        screen.inputImage = colored
        screen.backgroundImage = image
        return screen.outputImage?.cropped(to: extent) ?? image
    }

    // MARK: - ビネット:四隅を暗く(中心は少し左上)、四隅だけ緑青

    private static func vignette(_ image: CIImage, extent: CGRect, amount: Double) -> CIImage {
        // CI の座標は左下が原点。左上 = y を上へ
        let center = CGPoint(x: extent.midX - extent.width * 0.04, y: extent.midY + extent.height * 0.05)
        let radius = hypot(extent.width, extent.height) / 2
        let gradient = CIFilter.radialGradient()
        gradient.center = center
        gradient.radius0 = Float(radius * 0.45)
        gradient.radius1 = Float(radius * 1.05)
        gradient.color0 = CIColor(red: 1, green: 1, blue: 1)
        let edge = 1 - amount
        gradient.color1 = CIColor(red: edge * 0.94, green: edge * 1.0, blue: edge * 1.0)
        guard let mask = gradient.outputImage?.cropped(to: extent) else { return image }
        let multiply = CIFilter.multiplyCompositing()
        multiply.inputImage = mask
        multiply.backgroundImage = image
        return multiply.outputImage?.cropped(to: extent) ?? image
    }

    // MARK: - 現像ムラ:明るさ ±3% / 色 ±3.5%(黄 ↔ 青)、上は白く下は濃く

    private static func uneven(_ image: CIImage, extent: CGRect, configuration c: Configuration, seed: UInt32) -> CIImage {
        // 小さなノイズを大きくのばして、なめらかなムラにする(毎回の重い生成はしない)
        let offset = CGFloat(seed % 997)
        let noise = CIFilter.randomGenerator().outputImage?
            .transformed(by: CGAffineTransform(translationX: offset, y: offset * 0.7))
            .cropped(to: CGRect(x: offset, y: offset * 0.7, width: 6, height: 8))
            .transformed(by: CGAffineTransform(translationX: -offset, y: -offset * 0.7))
            .transformed(by: CGAffineTransform(scaleX: extent.width / 6, y: extent.height / 8))
            .clampedToExtent()
            .applyingGaussianBlur(sigma: Double(max(extent.width, extent.height)) / 10)
            .cropped(to: extent)
        guard let noise else { return image }
        // ノイズ(0〜1)→ 明るさ ±L、色 黄 ↔ 青 ±C(R,G は同じ向き、B は逆)
        let l = c.unevenLuma, col = c.unevenColor
        let m = CIFilter.colorMatrix()
        m.inputImage = noise
        m.rVector = CIVector(x: 2 * l + col, y: 0, z: 0, w: 0)
        m.gVector = CIVector(x: 2 * l + col, y: 0, z: 0, w: 0)
        m.bVector = CIVector(x: 2 * l - col, y: 0, z: 0, w: 0)
        // ノイズの透明度は使わない(いつも不透明)
        m.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        let base = 1 - l - col / 2
        m.biasVector = CIVector(x: base, y: base, z: 1 - l + col / 2, w: 1)
        guard let factor = m.outputImage else { return image }
        // 上は白く(+1.5%)、下は濃く(-2%)
        let vertical = CIFilter.linearGradient()
        vertical.point0 = CGPoint(x: extent.midX, y: extent.maxY)
        vertical.point1 = CGPoint(x: extent.midX, y: extent.minY)
        vertical.color0 = CIColor(red: 1.015, green: 1.015, blue: 1.015)
        vertical.color1 = CIColor(red: 0.98, green: 0.98, blue: 0.98)
        var out = multiply(image, factor, extent: extent)
        if let v = vertical.outputImage?.cropped(to: extent) { out = multiply(out, v, extent: extent) }
        return out
    }

    // MARK: - 夜のフラッシュ:中心を明るく、周りを落とす

    private static func flash(_ image: CIImage, extent: CGRect) -> CIImage {
        let radius = hypot(extent.width, extent.height) / 2
        let gradient = CIFilter.radialGradient()
        gradient.center = CGPoint(x: extent.midX, y: extent.midY + extent.height * 0.04)
        gradient.radius0 = Float(radius * 0.15)
        gradient.radius1 = Float(radius * 0.95)
        gradient.color0 = CIColor(red: 1.14, green: 1.12, blue: 1.10)
        gradient.color1 = CIColor(red: 0.82, green: 0.82, blue: 0.85)
        guard let mask = gradient.outputImage?.cropped(to: extent) else { return image }
        return multiply(image, mask, extent: extent)
    }

    // MARK: - ふちの化学反応:端の約5px をクリームにとかし、極細の暗い線

    private static func edges(_ image: CIImage, extent: CGRect, configuration c: Configuration, k: Double) -> CIImage {
        let width = c.edgeWidth * k
        // ふちが白(1)、内側が黒(0)のマスク
        let inner = CIImage(color: .black).cropped(to: extent.insetBy(dx: width, dy: width))
        let edgeMask = inner.composited(over: CIImage(color: .white).cropped(to: extent))
            .clampedToExtent().applyingGaussianBlur(sigma: width * 0.6).cropped(to: extent)
        let cream = CIImage(color: CIColor(red: 0.97, green: 0.94, blue: 0.88)).cropped(to: extent)
        let creamMix = blend(base: image, top: cream, mask: scaleGray(edgeMask, by: c.edgeCream), extent: extent)
        // 極細の暗い線(いちばん外の1px)
        let lineWidth = max(1, 0.8 * k)
        let lineInner = CIImage(color: .black).cropped(to: extent.insetBy(dx: lineWidth, dy: lineWidth))
        let lineMask = lineInner.composited(over: CIImage(color: CIColor(red: c.edgeLine, green: c.edgeLine, blue: c.edgeLine)).cropped(to: extent))
        let dark = CIImage(color: CIColor(red: 0.12, green: 0.1, blue: 0.08)).cropped(to: extent)
        return blend(base: creamMix, top: dark, mask: lineMask, extent: extent)
    }

    // MARK: - 粒子:明るさ 2.0% / 色つぶ 0.8%。暗い所ほど強く、白飛びでは弱める

    private static func grain(_ image: CIImage, extent: CGRect, configuration c: Configuration, seed: UInt32, k: Double) -> CIImage {
        // ノイズ画像の R と G(同じ分布の、別々のノイズ)の差から、平均がちょうど 1 の倍率を作る:
        //   倍率 = 1 + 2a × (R − G)。差は三角分布で、標準偏差は 2a/√6 → 表の値(2.0% / 0.8%)を標準偏差として a を決める
        let lumaA = c.grainLuma * 6.0.squareRoot() / 2, chromaA = c.grainChroma * 6.0.squareRoot() / 2
        guard lumaA > 0 || chromaA > 0 else { return image }

        func random(_ shift: UInt32) -> CIImage? {
            let offset = CGFloat((seed &+ shift) % UInt32(noiseSize))
            let scale = CGFloat(max(1, k * 0.8))
            let tile = CIFilter.affineTile()
            tile.inputImage = noiseTile
            tile.transform = CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: -offset, y: -offset * 0.7)
            return tile.outputImage?.cropped(to: extent)
        }
        guard let n1 = random(0), let n2 = random(1777) else { return image }
        // 明るさ:R,G,B 同じ倍率
        let luma = CIFilter.colorMatrix()
        luma.inputImage = n1
        let lv = CIVector(x: 2 * lumaA, y: -2 * lumaA, z: 0, w: 0)
        luma.rVector = lv; luma.gVector = lv; luma.bVector = lv
        luma.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        luma.biasVector = CIVector(x: 1, y: 1, z: 1, w: 1)
        // 色つぶ:赤み ↔ 青み(赤と青で逆向き)
        let chroma = CIFilter.colorMatrix()
        chroma.inputImage = n2
        chroma.rVector = CIVector(x: 2 * chromaA, y: -2 * chromaA, z: 0, w: 0)
        chroma.gVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        chroma.bVector = CIVector(x: -2 * chromaA, y: 2 * chromaA, z: 0, w: 0)
        chroma.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        chroma.biasVector = CIVector(x: 1, y: 1, z: 1, w: 1)
        guard let lf = luma.outputImage, let cf = chroma.outputImage else { return image }
        let factor = multiply(lf, cf, extent: extent)
        // 暗い所ほど強く(1)、白飛びでは弱く(0.3):その割合で、倍率 1(変化なし)とまぜる
        let weight = CIFilter.colorMatrix()
        weight.inputImage = image
        let lw = CIVector(x: -0.2126 * 0.7, y: -0.7152 * 0.7, z: -0.0722 * 0.7, w: 0)
        weight.rVector = lw; weight.gVector = lw; weight.bVector = lw
        weight.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        weight.biasVector = CIVector(x: 1, y: 1, z: 1, w: 0)
        guard let strength = weight.outputImage?.applyingFilter("CIColorClamp") else { return image }
        let one = CIImage(color: CIColor(red: 1, green: 1, blue: 1)).cropped(to: extent)
        let weighted = blend(base: one, top: factor, mask: strength, extent: extent)
        return multiply(image, weighted, extent: extent)
    }

    /// 粒子のための小さなノイズ画像(256×256・一様・毎回作らない)。色の変換をかけない(値をそのまま使う)
    static let noiseSize = 256
    private static let noiseTile: CIImage = {
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        var bytes = [UInt8](repeating: 255, count: noiseSize * noiseSize * 4)
        for i in 0..<(noiseSize * noiseSize) {
            for ch in 0..<3 {
                state ^= state << 13; state ^= state >> 7; state ^= state << 17
                bytes[i * 4 + ch] = UInt8(truncatingIfNeeded: state >> 24)
            }
        }
        let data = Data(bytes)
        return CIImage(bitmapData: data, bytesPerRow: noiseSize * 4, size: CGSize(width: noiseSize, height: noiseSize), format: .RGBA8, colorSpace: nil)
    }()

    /// チャンネルごとに倍にする
    private static func tone(_ image: CIImage, r: Double, g: Double, b: Double) -> CIImage {
        let m = CIFilter.colorMatrix()
        m.inputImage = image
        m.rVector = CIVector(x: r, y: 0, z: 0, w: 0)
        m.gVector = CIVector(x: 0, y: g, z: 0, w: 0)
        m.bVector = CIVector(x: 0, y: 0, z: b, w: 0)
        m.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        return m.outputImage ?? image
    }

    // MARK: - 共通

    private static func channel(_ image: CIImage, r: CGFloat, g: CGFloat, b: CGFloat) -> CIImage {
        let m = CIFilter.colorMatrix()
        m.inputImage = image
        m.rVector = CIVector(x: r, y: 0, z: 0, w: 0)
        m.gVector = CIVector(x: 0, y: g, z: 0, w: 0)
        m.bVector = CIVector(x: 0, y: 0, z: b, w: 0)
        m.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        return m.outputImage ?? image
    }

    private static func maximum(_ a: CIImage, _ b: CIImage) -> CIImage {
        let f = CIFilter.maximumCompositing()
        f.inputImage = a
        f.backgroundImage = b
        return f.outputImage ?? b
    }

    private static func add(_ a: CIImage, _ b: CIImage) -> CIImage {
        let f = CIFilter.additionCompositing()
        f.inputImage = a
        f.backgroundImage = b
        return f.outputImage ?? b
    }

    private static func multiply(_ image: CIImage, _ factor: CIImage, extent: CGRect) -> CIImage {
        let f = CIFilter.multiplyCompositing()
        f.inputImage = factor
        f.backgroundImage = image
        return f.outputImage?.cropped(to: extent) ?? image
    }

    private static func blend(base: CIImage, top: CIImage, mask: CIImage, extent: CGRect) -> CIImage {
        let f = CIFilter.blendWithMask()
        f.inputImage = top
        f.backgroundImage = base
        f.maskImage = mask
        return f.outputImage?.cropped(to: extent) ?? base
    }

    private static func scaleGray(_ image: CIImage, by factor: Double) -> CIImage {
        let m = CIFilter.colorMatrix()
        m.inputImage = image
        m.rVector = CIVector(x: factor, y: 0, z: 0, w: 0)
        m.gVector = CIVector(x: 0, y: factor, z: 0, w: 0)
        m.bVector = CIVector(x: 0, y: 0, z: factor, w: 0)
        m.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        return m.outputImage ?? image
    }

    private static func radialMask(extent: CGRect, center: CGPoint, inner: Double, outer: Double, innerValue: Double, outerValue: Double) -> CIImage {
        let radius = hypot(extent.width, extent.height) / 2
        let g = CIFilter.radialGradient()
        g.center = center
        g.radius0 = Float(radius * inner)
        g.radius1 = Float(radius * outer)
        g.color0 = CIColor(red: innerValue, green: innerValue, blue: innerValue)
        g.color1 = CIColor(red: outerValue, green: outerValue, blue: outerValue)
        return g.outputImage?.cropped(to: extent) ?? CIImage(color: .white).cropped(to: extent)
    }
}
