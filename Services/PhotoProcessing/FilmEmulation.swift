import CoreImage
import CoreImage.CIFilterBuiltins
import CoreGraphics

/// 「盛れる」簡易補正(顔検出不要)を行うCore Imageフィルタチェーン。
/// ChekiColorGrade(ChekiPhotoFrame.swift)から呼ばれる。
///
/// 以前はトーンカーブ/ハレーション/グレイン/周辺減光/現像ムラの5層構成の
/// フィルムエミュレーション(チェキ風の質感)だったが、「元の写真が主役で、
/// 被写体が判別できないレベルのノイズになる」という問題を受けて全面的に撤去し、
/// 明るさ・コントラスト・彩度の引き上げ、美肌(ぼかしブレンド)、暖色寄りの
/// 色温度調整という、より軽い補正に置き換えた。サードパーティライブラリは使わず、
/// CoreImage.CIFilterBuiltinsの標準フィルタのみで構成しているため、
/// 全工程がGPU(Metal)経由で処理される。
enum FilmEmulation {

    // MARK: - 強度パラメータ

    /// 各要素の有効/無効と強度をまとめた設定。値を変えるだけで見た目を調整・比較できる。
    struct Configuration {
        var colorAdjustEnabled = true
        var skinSmoothEnabled = true

        /// 0(無補正)〜1(下記の各種フル効果)。DevelopingProgressView(現像中プレビュー)の
        /// 段階的表現ではcolorKeyframes経由の値が渡される。デフォルト1では
        /// 下記の値がそのままフル適用される。
        var colorAdjustStrength: Double = 1.0
        /// 同上。美肌(ぼかしブレンド)側の段階的表現用(textureKeyframes経由)。
        var skinSmoothStrength: Double = 1.0

        // --- 明るさ・コントラスト・彩度(CIColorControls) ---
        /// CIColorControls.brightnessへそのまま加算する値。控えめな値から開始。
        var brightnessBoost: Double = 0.04
        /// contrast = 1.0 + この値。自然な範囲での引き上げ。
        var contrastBoost: Double = 0.05
        /// saturation = 1.0 + この値。血色・鮮やかさの強調。
        var saturationBoost: Double = 0.15

        // --- 暖色寄りの色温度(CIColorMatrixでR+/B-) ---
        /// 赤チャンネルの引き上げ量。
        var warmthRedBoost: Double = 0.03
        /// 青チャンネルの引き下げ量。既存の「青みがかった」とは逆方向の暖色寄りにする。
        var warmthBlueCut: Double = 0.02

        // --- 美肌(ガウスぼかし+ブレンド) ---
        /// ぼかし半径(px)。書き出し幅(ChekiPhotoFrameは実寸100〜300px程度)を想定した値。
        var skinSmoothBlurRadius: Double = 4.0
        /// 元画像とぼかし画像のブレンド比率(0=無補正、1=ぼかしのみ)。画像全体に均一に
        /// ぼかしをかけるのではなく、この比率で元画像とブレンドすることで、ディテール・
        /// 輪郭のシャープさを保ちながら質感だけを滑らかにする(顔検出は使わないため、
        /// 画像全体が均一に対象になる)。
        var skinSmoothOpacity: Double = 0.35

        static let `default` = Configuration()

        /// 全要素OFF(旧処理相当の見た目と比較する際のデバッグ用)
        static var allDisabled: Configuration {
            var c = Configuration()
            c.colorAdjustEnabled = false
            c.skinSmoothEnabled = false
            return c
        }
    }

    /// data(写真の元バイト列)から安定したseedを作る。現在の処理内容(明るさ/彩度/
    /// 美肌/色温度)はランダム要素を持たないため実質未使用だが、呼び出し側のAPIを
    /// 変えずに済むよう引数として残している(将来ランダム要素を再度足す場合に備える)。
    static func seed(for data: Data) -> UInt32 {
        UInt32(truncatingIfNeeded: data.hashValue)
    }

    // MARK: - 現像中プレビュー用の段階的Configuration

    /// progress(0=撮影直後〜1=解禁/現像完了)から、その時点での「現像されかけの状態」を
    /// 表すConfigurationを作る。DevelopingProgressView(現像中プレビュー)専用。
    ///
    /// - 0〜30%: 補正ほぼ0(元画像に近い状態)
    /// - 30〜70%: 明るさ・彩度・色温度が本来値の30〜70%まで上昇
    /// - 70〜95%: 明るさ・彩度・色温度が100%まで上昇すると同時に、美肌も0→100%で立ち上がる
    /// - 95〜100%: 全パラメータが完全な状態(通常のChekiColorGrade表示と同一)に収束
    ///
    /// 区間の継ぎ目で傾きが不連続にならないよう、区間ごとにease-in-out
    /// (PhotoUnlockUtilities.applyEasing(_:.easeInOut))で補間する。
    static func developingConfiguration(progress: Double) -> Configuration {
        let colorAmount = interpolateKeyframes(colorKeyframes, progress: progress)
        let textureAmount = interpolateKeyframes(textureKeyframes, progress: progress)

        var config = Configuration.default
        config.colorAdjustStrength = colorAmount
        // textureAmountが0の間はフィルタ自体を丸ごとスキップし、計算コストを省く
        // (現像初期〜中盤は美肌ぼかしが一切見えないため、無効化しても見た目に影響が無い)。
        config.skinSmoothEnabled = textureAmount > 0
        config.skinSmoothStrength = textureAmount
        return config
    }

    /// (progress境界, その時点での値)のキーフレーム列を、区間ごとease-in-outで補間する。
    private static func interpolateKeyframes(_ keyframes: [(Double, Double)], progress: Double) -> Double {
        guard let first = keyframes.first else { return 0 }
        let p = min(1, max(0, progress))
        guard p > first.0 else { return first.1 }
        for i in 1..<keyframes.count {
            let (endP, endV) = keyframes[i]
            let (startP, startV) = keyframes[i - 1]
            guard p <= endP else { continue }
            guard endP > startP else { return endV }
            let local = (p - startP) / (endP - startP)
            let eased = PhotoUnlockUtilities.applyEasing(progress: local, easingType: .easeInOut)
            return startV + (endV - startV) * eased
        }
        return keyframes.last?.1 ?? 0
    }

    private static let colorKeyframes: [(Double, Double)] = [
        (0.0, 0.0),
        (0.30, 0.05),
        (0.70, 0.7),
        (0.95, 1.0),
        (1.0, 1.0),
    ]

    private static let textureKeyframes: [(Double, Double)] = [
        (0.0, 0.0),
        (0.70, 0.0),
        (0.95, 1.0),
        (1.0, 1.0),
    ]

    // MARK: - エントリポイント

    /// orientation補正済みのCIImageに「盛れる」簡易補正を適用する。
    static func process(_ image: CIImage, configuration: Configuration = .default, seed: UInt32) -> CIImage {
        let extent = image.extent
        var output = image

        if configuration.colorAdjustEnabled, configuration.colorAdjustStrength > 0 {
            output = applyColorAdjust(output, configuration: configuration)
        }
        if configuration.skinSmoothEnabled, configuration.skinSmoothStrength > 0 {
            output = applySkinSmooth(output, extent: extent, configuration: configuration)
        }
        return output.cropped(to: extent)
    }

    // MARK: - 明るさ・コントラスト・彩度・色温度

    /// CIColorControlsで明るさ・コントラスト・彩度を引き上げ、続けてCIColorMatrixで
    /// 赤チャンネルを上げ・青チャンネルを下げることで暖色寄りのトーンに寄せる。
    /// strength(0〜1)は各値に線形に乗算する(DevelopingProgressViewの段階的表現用)。
    private static func applyColorAdjust(_ image: CIImage, configuration: Configuration) -> CIImage {
        let strength = min(max(configuration.colorAdjustStrength, 0), 1)

        let controls = CIFilter.colorControls()
        controls.inputImage = image
        controls.brightness = Float(configuration.brightnessBoost * strength)
        controls.contrast = Float(1.0 + configuration.contrastBoost * strength)
        controls.saturation = Float(1.0 + configuration.saturationBoost * strength)
        let colorAdjusted = controls.outputImage ?? image

        let warmth = CIFilter.colorMatrix()
        warmth.inputImage = colorAdjusted
        let r = 1.0 + configuration.warmthRedBoost * strength
        let b = 1.0 - configuration.warmthBlueCut * strength
        warmth.rVector = CIVector(x: r, y: 0, z: 0, w: 0)
        warmth.gVector = CIVector(x: 0, y: 1, z: 0, w: 0)
        warmth.bVector = CIVector(x: 0, y: 0, z: b, w: 0)
        warmth.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        return warmth.outputImage ?? colorAdjusted
    }

    // MARK: - 美肌(ガウスぼかし+ブレンド)

    /// 画像全体を軽くぼかした版を作り、元画像とopacity比率で線形ブレンドする
    /// (result = original*(1-opacity) + blurred*opacity)。顔検出・マスクを使わないため
    /// 画像全体が均一に対象になるが、opacityを低く抑えることで輪郭のシャープさを保つ。
    private static func applySkinSmooth(_ image: CIImage, extent: CGRect, configuration: Configuration) -> CIImage {
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = image.clampedToExtent()
        blur.radius = Float(configuration.skinSmoothBlurRadius)
        guard let blurred = blur.outputImage?.cropped(to: extent) else { return image }

        let opacity = min(max(configuration.skinSmoothOpacity * configuration.skinSmoothStrength, 0), 1)
        let scaledOriginal = scale(image, by: 1 - opacity)
        let scaledBlur = scale(blurred, by: opacity)
        return additionComposite(scaledBlur, scaledOriginal).cropped(to: extent)
    }

    // MARK: - 共通ヘルパー

    private static func scale(_ image: CIImage, by factor: Double) -> CIImage {
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = image
        matrix.rVector = CIVector(x: factor, y: 0, z: 0, w: 0)
        matrix.gVector = CIVector(x: 0, y: factor, z: 0, w: 0)
        matrix.bVector = CIVector(x: 0, y: 0, z: factor, w: 0)
        matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        return matrix.outputImage ?? image
    }

    private static func additionComposite(_ image: CIImage, _ background: CIImage) -> CIImage {
        let filter = CIFilter.additionCompositing()
        filter.inputImage = image
        filter.backgroundImage = background
        return filter.outputImage ?? background
    }
}
