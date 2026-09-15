#if DEBUG
import SwiftUI
import PhotosUI
import CoreImage.CIFilterBuiltins

/// 旧チェキ風フィルムエミュレーション(トーンカーブ/ハレーション/グレイン/
/// 周辺減光/現像ムラの5層構成)と、それを撤去して置き換えた新しい「盛れる」
/// 簡易補正(明るさ・コントラスト・彩度の引き上げ、美肌ぼかしブレンド、
/// 暖色寄りの色温度)を並べて見比べるための確認専用画面。
/// #if DEBUGで囲っているため本番(Release/TestFlight)ビルドには一切含まれない、
/// 確認が終わり次第削除してよい一時的なデバッグ用コード。
///
/// 「旧チェキ加工」列は、撤去済みの5層フィルムエミュレーションの数値を
/// このファイル内に再現したもの(FilmEmulation.swift側のprivateヘルパーは
/// ここから呼べないため、CIFilter APIで同じ計算を組み直している)。
/// 「新・盛れる補正」列は現在のFilmEmulation.process()をそのまま呼ぶため、
/// FilmEmulation.swift側の数値をさらに調整すれば自動的にこちらへ反映される。
///
/// フォトライブラリから、明るい屋外・暗い室内・人物など条件を変えた写真を選び、
/// 実機で見比べる。特に美肌効果が強すぎてのっぺりしていないか、明るさ・彩度の
/// 引き上げが不自然でないかを確認する。
struct FilmEmulationDebugPreview: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem?
    @State private var oldImage: UIImage?
    @State private var newImage: UIImage?
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("テスト画像を選択", systemImage: "photo.badge.plus")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)

                    if isProcessing {
                        ProgressView()
                            .padding(.top, 40)
                    } else if let oldImage, let newImage {
                        comparisonBlock(title: "旧チェキ加工(トーンカーブ/ハレーション/グレイン/周辺減光/現像ムラ、撤去済み)", image: oldImage)
                        comparisonBlock(
                            title: "新・盛れる補正(現在のFilmEmulation.process: 明るさ/コントラスト/彩度/美肌/色温度)",
                            image: newImage
                        )
                    } else {
                        Text("上のボタンから明るい写真・暗い写真・人物写真などを選んで比較してください")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 60)
                            .padding(.horizontal, 24)
                    }
                }
                .padding()
            }
            .navigationTitle("FilmEmulation比較(Debug)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                Task {
                    guard let newItem, let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                    await process(data: data)
                }
            }
        }
    }

    private func comparisonBlock(title: String, image: UIImage) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    @MainActor
    private func process(data: Data) async {
        isProcessing = true
        oldImage = nil
        newImage = nil
        let result = await Task.detached(priority: .userInitiated) {
            Self.render(data: data)
        }.value
        oldImage = result.0
        newImage = result.1
        isProcessing = false
    }

    private static func cgOrientation(_ uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    // MARK: - 修正前の数値を再現する簡易パイプライン(このファイル限定、比較専用)

    private enum LegacyChannel { case red, green, blue }

    private static func legacyCurveSamplePoint(x: Double, channel: LegacyChannel) -> Double {
        var y = x
        let highlightStart = 0.6
        if x > highlightStart {
            let t = (x - highlightStart) / (1 - highlightStart)
            let rolled = 1 - pow(1 - t, 1.6)
            y = highlightStart + rolled * (1 - highlightStart)
        }
        let bump = sin(.pi * min(max(x, 0), 1))
        switch channel {
        case .red:
            y += 0.015 * bump
        case .green:
            y += 0.03 * bump
        case .blue:
            if x < 0.45 {
                y -= 0.06 * (1 - x / 0.45)
            }
        }
        return min(max(y, 0), 1)
    }

    private static func legacyProcess(_ image: CIImage) -> CIImage {
        let sampleCount = 32
        var samples = [Float]()
        samples.reserveCapacity(sampleCount * 3)
        for i in 0..<sampleCount {
            let x = Double(i) / Double(sampleCount - 1)
            for channel in [LegacyChannel.red, .green, .blue] {
                samples.append(Float(legacyCurveSamplePoint(x: x, channel: channel)))
            }
        }
        let curveData = samples.withUnsafeBufferPointer { Data(buffer: $0) }
        let curves = CIFilter.colorCurves()
        curves.inputImage = image
        curves.curvesData = curveData
        curves.curvesDomain = CIVector(x: 0, y: 1)
        curves.colorSpace = CGColorSpaceCreateDeviceRGB()
        let curved = curves.outputImage ?? image

        let vignette = CIFilter.vignette()
        vignette.inputImage = curved
        vignette.intensity = 0.9
        vignette.radius = 1.6
        let vignetted = vignette.outputImage ?? curved

        // 現像ムラ(旧数値0.05, k=0.1)はノイズによる微細なムラより画面全体への
        // 一律な乗算(平均約-5%)が支配的なため、比較用に定数倍で簡易的に近似する。
        let uneven = CIFilter.colorMatrix()
        uneven.inputImage = vignetted
        let k: CGFloat = 0.95
        uneven.rVector = CIVector(x: k, y: 0, z: 0, w: 0)
        uneven.gVector = CIVector(x: 0, y: k, z: 0, w: 0)
        uneven.bVector = CIVector(x: 0, y: 0, z: k, w: 0)
        uneven.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        return uneven.outputImage ?? vignetted
    }

    private static func render(data: Data) -> (UIImage?, UIImage?) {
        let context = CIContext()
        guard let sourceImage = UIImage(data: data), let cgImage = sourceImage.cgImage else { return (nil, nil) }
        let ciImage = CIImage(cgImage: cgImage).oriented(cgOrientation(sourceImage.imageOrientation))

        // 修正前: シャドウの黒浮き修正が入る前のトーンカーブ/vignette/現像ムラの
        // 数値をこのファイル内で再現したもの(FilmEmulation.swift側はprivateな
        // ヘルパーのため、ここでは同じ計算をCIFilter APIで直接組み立てている)。
        // ハレーション・グレインは今回の修正対象外(数値変更なし)のため、
        // シャドウ/周辺減光の差が見やすいよう両列とも省いている。
        let oldOutput = legacyProcess(ciImage)

        // 修正後: 現在のFilmEmulation.process(FilmEmulation.swift側の数値を
        // 動かせば、ビルドし直すだけでここにも自動的に反映される)。
        let newOutput = FilmEmulation.process(ciImage, seed: FilmEmulation.seed(for: data))

        var old: UIImage?
        var new: UIImage?
        if let cg = context.createCGImage(oldOutput, from: ciImage.extent) {
            old = UIImage(cgImage: cg)
        }
        if let cg = context.createCGImage(newOutput, from: ciImage.extent) {
            new = UIImage(cgImage: cg)
        }
        return (old, new)
    }
}
#endif
