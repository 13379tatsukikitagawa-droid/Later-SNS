import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Photos
import SwiftUI
import UIKit

// MARK: - 円(グループの顔 + 点の輪)

/// グループは「点の輪」。点の数 = 人数の上限、光る点 = いる人。作成から加入まで、この見え方で一貫させる。
/// 中は(下から)オーラ → 写真 → 頭文字 → 光沢。リングは120秒で1周(視差効果を減らす=止める)。
struct GroupCircle: View {
    var image: UIImage?
    let initial: String
    let colorIndex: Int
    let memberLimit: Int
    let litCount: Int
    let diameter: CGFloat
    var rotates = true
    /// 招待を受ける画面:あなたの席(点線のオレンジの点)。nil なら出さない
    var seatIndex: Int?
    /// 席への到着(0〜1 で、オレンジに跳ねて白に)。nil なら到着前
    var arrival: Double?
    /// 到着のあと、ほかの点が時計まわりに順番にきらっと光る(秒)
    var sparkleTime: Double?
    /// 誰かが入った(③):その点がオレンジで現れて白に変わり、輪が広がる
    var popStart: Date?
    var popIndex = 0
    /// エラー画面:彩度を落として薄く
    var faded = false
    /// 円板のぽんと跳ねる量(1 = 通常)
    var discScale: CGFloat = 1
    /// 写真の「現像」(0 = ぼかし・うす白・低い彩度 → 1 = くっきり)
    var develop: Double = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotationStart = Date()

    private var discDiameter: CGFloat { diameter * 0.74 }

    var body: some View {
        let colors = GroupRingMath.auraPalettes[(GroupPalette.isValid(colorIndex) ? colorIndex : 0)]
        TimelineView(.animation(paused: !(rotates && !reduceMotion) && popStart == nil)) { context in
            let now = context.date
            ZStack {
                ring(now: now)
                disc(colors: colors)
                    .scaleEffect(discScale)
            }
            .frame(width: diameter, height: diameter)
        }
        .saturation(faded ? 0.2 : 1)
        .opacity(faded ? 0.5 : 1)
        .accessibilityElement()
        .accessibilityLabel("グループの顔")
        .accessibilityValue("\(litCount) / \(memberLimit)人")
    }

    private func disc(colors: [Color]) -> some View {
        let d = discDiameter
        return ZStack {
            // オーラ
            colors[2]
            Circle().fill(colors[0]).frame(width: d * 0.85).offset(x: -d * 0.2, y: -d * 0.16).blur(radius: d * 0.2)
            Circle().fill(colors[1]).frame(width: d * 0.75).offset(x: d * 0.22, y: d * 0.2).blur(radius: d * 0.2)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 16 * (1 - develop))
                    .saturation(0.3 + 0.7 * develop)
                    .overlay(Color.white.opacity(0.35 * (1 - develop)))
            } else {
                Text(initial)
                    .font(.system(size: d * 0.42, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    .contentTransition(.opacity)
            }
            // 光沢:左上から白の放射+下から暗い放射
            RadialGradient(colors: [.white.opacity(0.3), .clear], center: UnitPoint(x: 0.25, y: 0.18), startRadius: 0, endRadius: d * 0.6)
            RadialGradient(colors: [.black.opacity(0.28), .clear], center: UnitPoint(x: 0.5, y: 1.05), startRadius: 0, endRadius: d * 0.55)
        }
        .frame(width: d, height: d)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
        .accessibilityHidden(true)
    }

    private func ring(now: Date) -> some View {
        let rotation = (rotates && !reduceMotion && arrival == nil && seatIndex == nil)
            ? now.timeIntervalSince(rotationStart) / 120 * 2 * .pi : 0
        return Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = diameter / 2 - 6
            context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                           with: .color(.white.opacity(0.08)), lineWidth: 1)
            let total = GroupPalette.clampLimit(memberLimit)
            for i in 0..<total {
                let angle = GroupRingMath.angle(index: i, total: total) + rotation
                let p = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                if i == seatIndex {
                    drawSeat(at: p, in: &context)
                    continue
                }
                if i < litCount {
                    var r: CGFloat = 3
                    var color = Color.white
                    var opacity = 1.0
                    if let sparkleTime {
                        // 到着のあと、0.07秒ずつ遅れて、半径 +1.6pt
                        let u = min(1, max(0, (sparkleTime - Double(i) * 0.07) / 0.25))
                        let bump = sin(u * .pi)
                        r += 1.6 * bump
                        opacity = 0.85 + 0.15 * bump
                    }
                    if let popStart, i == popIndex, !reduceMotion {
                        let t = now.timeIntervalSince(popStart)
                        let grow = min(1, max(0, t / 0.9))
                        r *= grow < 0.35 ? 0.2 + 2.5 * (grow / 0.35) : 2.7 - 1.7 * HomeMotion.ease((grow - 0.35) / 0.65)
                        color = grow < 0.6 ? Color(hex: "FFB26E") : .white
                        let ringU = min(1, max(0, t / 1.2))
                        if ringU < 1 {
                            let rr = 3 * (1 + 5 * ringU)
                            context.stroke(Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: rr * 2, height: rr * 2)),
                                           with: .color(Color(hex: "FFB26E").opacity(0.8 * (1 - ringU))), lineWidth: 1.3)
                        }
                    }
                    context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(color.opacity(opacity)))
                } else {
                    let r: CGFloat = 2
                    context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.24)))
                }
            }
        }
        .frame(width: diameter + 40, height: diameter + 40)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// あなたの席:点線のオレンジの点 → 到着でオレンジに跳ねて(半径×2.7)白に
    private func drawSeat(at p: CGPoint, in context: inout GraphicsContext) {
        let orange = Color(hex: "FFB26E")
        guard let arrival else {
            let r: CGFloat = 4.5
            context.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                           with: .color(orange), style: StrokeStyle(lineWidth: 1.3, dash: [2, 2]))
            return
        }
        let u = min(1, max(0, arrival))
        let scale: CGFloat = u < 0.3 ? 1 + 1.7 * CGFloat(u / 0.3) : 2.7 - 1.7 * CGFloat(HomeMotion.ease((u - 0.3) / 0.7))
        let r = 3 * scale
        let color = u < 0.6 ? orange : Color.white
        context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(color))
    }

    /// 席(=次に光る点)の、円の中心からの位置。光の玉の行き先の計算に使う
    static func seatOffset(index: Int, memberLimit: Int, diameter: CGFloat) -> CGSize {
        let total = GroupPalette.clampLimit(memberLimit)
        let angle = GroupRingMath.angle(index: index, total: total)
        let radius = diameter / 2 - 6
        return CGSize(width: cos(angle) * radius, height: sin(angle) * radius)
    }
}

// MARK: - 顔の画像(切り出し・色あい)

/// 色あい:そのまま / あたたか / しずか / モノクロ
enum FaceTone: String, CaseIterable, Identifiable {
    case original, warm, calm, mono
    var id: String { rawValue }
    var label: String {
        switch self {
        case .original: return "そのまま"
        case .warm: return "あたたか"
        case .calm: return "しずか"
        case .mono: return "モノクロ"
        }
    }
}

/// 顔の画像を作る。プレビューと保存で同じ関数を使う(=同じ結果になる)。
enum FaceImageRenderer {
    static let outputSide: CGFloat = 1024
    static let scaleRange: ClosedRange<CGFloat> = 1.0...2.2
    private static let context = CIContext()

    /// 中央の正方形から、大きさ(scale)と位置(offset。円板の直径に対する割合、-0.5〜0.5)で切り出す範囲(画像の座標)
    static func cropRect(imageSize: CGSize, scale: CGFloat, offset: CGSize) -> CGRect {
        let side = min(imageSize.width, imageSize.height)
        let s = min(scaleRange.upperBound, max(scaleRange.lowerBound, scale))
        let cropSide = side / s
        let clamped = clampOffset(offset, scale: s)
        let centerX = imageSize.width / 2 - clamped.width * side
        let centerY = imageSize.height / 2 - clamped.height * side
        var rect = CGRect(x: centerX - cropSide / 2, y: centerY - cropSide / 2, width: cropSide, height: cropSide)
        rect.origin.x = min(max(0, rect.origin.x), imageSize.width - cropSide)
        rect.origin.y = min(max(0, rect.origin.y), imageSize.height - cropSide)
        return rect
    }

    /// 移動できる量は、大きさに応じて上限あり(はみ出さない)。offset は正方形の一辺に対する割合
    static func clampOffset(_ offset: CGSize, scale: CGFloat) -> CGSize {
        let limit = (1 - 1 / max(1, scale)) / 2
        return CGSize(width: min(limit, max(-limit, offset.width)), height: min(limit, max(-limit, offset.height)))
    }

    /// 切り出し → 色あい → 正方形の画像
    static func render(_ image: UIImage, scale: CGFloat, offset: CGSize, tone: FaceTone, side: CGFloat = outputSide) -> UIImage? {
        guard let normalized = normalizedCGImage(image) else { return nil }
        let size = CGSize(width: normalized.width, height: normalized.height)
        let rect = cropRect(imageSize: size, scale: scale, offset: offset)
        guard let cropped = normalized.cropping(to: rect.integral) else { return nil }
        var ci = CIImage(cgImage: cropped)
        ci = apply(tone, to: ci)
        let factor = side / CGFloat(cropped.width)
        ci = ci.transformed(by: CGAffineTransform(scaleX: factor, y: factor))
        guard let out = context.createCGImage(ci, from: CGRect(x: 0, y: 0, width: side, height: side)) else { return nil }
        return UIImage(cgImage: out)
    }

    static func apply(_ tone: FaceTone, to image: CIImage) -> CIImage {
        switch tone {
        case .original:
            return image
        case .warm:
            // セピア 32% + 彩度 +15% + 色相 −8°
            let sepia = CIFilter.sepiaTone()
            sepia.inputImage = image
            sepia.intensity = 0.32
            let color = CIFilter.colorControls()
            color.inputImage = sepia.outputImage
            color.saturation = 1.15
            let hue = CIFilter.hueAdjust()
            hue.inputImage = color.outputImage
            hue.angle = Float(-8 * Double.pi / 180)
            return hue.outputImage ?? image
        case .calm:
            // 彩度 −30% + コントラスト −4% + 色相 +12° + 明るさ +4%
            let color = CIFilter.colorControls()
            color.inputImage = image
            color.saturation = 0.7
            color.contrast = 0.96
            color.brightness = 0.04
            let hue = CIFilter.hueAdjust()
            hue.inputImage = color.outputImage
            hue.angle = Float(12 * Double.pi / 180)
            return hue.outputImage ?? image
        case .mono:
            // グレースケール + コントラスト +5%
            let color = CIFilter.colorControls()
            color.inputImage = image
            color.saturation = 0
            color.contrast = 1.05
            return color.outputImage ?? image
        }
    }

    /// 向きをなおした CGImage(長辺 2000px まで)
    static func normalizedCGImage(_ image: UIImage, maxSide: CGFloat = 2000) -> CGImage? {
        let longest = max(image.size.width, image.size.height)
        let k = min(1, maxSide / max(1, longest))
        let size = CGSize(width: (image.size.width * k).rounded(), height: (image.size.height * k).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }
}

// MARK: - 最近の写真

/// 直近20枚。許可(全部・限定)があるときだけ読む。作成画面を開いた時点では、許可を聞かない。
@MainActor
@Observable
final class RecentPhotos {
    enum Access { case unknown, granted, denied }

    private(set) var access: Access = .unknown
    private(set) var thumbnails: [(id: String, image: UIImage)] = []
    @ObservationIgnored private var assets: [PHAsset] = []

    init() {
        update(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    /// 「アルバム」を押したとき(ライブラリが必要になったとき)に、初めて聞く
    func requestIfNeeded() async {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined else { return }
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        update(status)
    }

    private func update(_ status: PHAuthorizationStatus) {
        switch status {
        case .authorized, .limited:
            access = .granted
            load()
        case .denied, .restricted:
            access = .denied
        default:
            access = .unknown
        }
    }

    private func load() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 20
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var list: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in list.append(asset) }
        assets = list
        thumbnails = []
        let manager = PHImageManager.default()
        let request = PHImageRequestOptions()
        request.deliveryMode = .opportunistic
        request.isNetworkAccessAllowed = true
        for asset in list {
            manager.requestImage(for: asset, targetSize: CGSize(width: 222, height: 276), contentMode: .aspectFill, options: request) { [weak self] image, info in
                guard let self, let image, (info?[PHImageResultIsDegradedKey] as? Bool) != true else { return }
                Task { @MainActor in
                    if let index = self.thumbnails.firstIndex(where: { $0.id == asset.localIdentifier }) {
                        self.thumbnails[index].image = image
                    } else {
                        self.thumbnails.append((asset.localIdentifier, image))
                        let order = self.assets.map(\.localIdentifier)
                        self.thumbnails.sort { (order.firstIndex(of: $0.id) ?? 0) < (order.firstIndex(of: $1.id) ?? 0) }
                    }
                }
            }
        }
    }

    /// 選んだ写真を、顔に使える大きさで読む
    func fullImage(id: String) async -> UIImage? {
        guard let asset = assets.first(where: { $0.localIdentifier == id }) else { return nil }
        return await withCheckedContinuation { continuation in
            let request = PHImageRequestOptions()
            request.deliveryMode = .highQualityFormat
            request.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 1600, height: 1600), contentMode: .aspectFill, options: request) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

// MARK: - 円形のカメラ(背面のみ)

/// 全画面のカメラ。円形のファインダー(直径304pt)。白い大きな丸で1回タップ。前向きへの切りかえは付けない。
struct CircleCameraView: View {
    let haptics: ExposureHaptics
    let onCaptured: (UIImage) -> Void
    let onClose: () -> Void

    @State private var camera = CircleCamera()
    @State private var flash = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if camera.isDenied {
                VStack(spacing: 12) {
                    Text("カメラの許可がありません")
                        .font(.system(size: 17, weight: .bold))
                    Text("設定アプリで許可すると、ここで撮れます。写真か色だけでも、顔は作れます。")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "BCBBC0"))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
            } else {
                VStack(spacing: 0) {
                    Text("円のなかに、顔になる景色を。")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 70)
                    Text("1回タップで撮れます。やり直しもできます。")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color(hex: "BCBBC0"))
                        .padding(.top, 8)
                    Spacer()
                    CameraPreview(session: camera.session)
                        .frame(width: 304, height: 304)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1.5))
                    Spacer()
                    Button(action: shoot) {
                        Circle().fill(.white).frame(width: 74, height: 74)
                            .overlay(Circle().strokeBorder(.black.opacity(0.15), lineWidth: 3).padding(4))
                    }
                    .buttonStyle(PressScaleStyle(scale: 0.92))
                    .accessibilityLabel("撮る")
                    .padding(.bottom, 48)
                }
            }
            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("閉じる")
                    Spacer()
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            Color.white.ignoresSafeArea().opacity(flash ? 1 : 0).allowsHitTesting(false)
        }
        .task { await camera.start() }
        .onDisappear { camera.stop() }
    }

    private func shoot() {
        haptics.playTransient(intensity: 1.0, sharpness: 0.7)
        withAnimation(.easeOut(duration: 0.13)) { flash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { withAnimation(.easeIn(duration: 0.13)) { flash = false } }
        camera.capture { image in
            guard let image else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { onCaptured(image) }
        }
    }
}

@MainActor
@Observable
final class CircleCamera: NSObject, AVCapturePhotoCaptureDelegate {
    @ObservationIgnored let session = AVCaptureSession()
    @ObservationIgnored private let output = AVCapturePhotoOutput()
    @ObservationIgnored private var completion: ((UIImage?) -> Void)?
    private(set) var isDenied = false

    /// このタブを押したときに、初めてカメラの許可を聞く
    func start() async {
        var status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            status = await AVCaptureDevice.requestAccess(for: .video) ? .authorized : .denied
        }
        guard status == .authorized else {
            isDenied = true
            return
        }
        guard session.inputs.isEmpty,
              let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        let session = self.session
        Task.detached { session.startRunning() }
    }

    func stop() {
        let session = self.session
        Task.detached { session.stopRunning() }
    }

    func capture(_ completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        Task { @MainActor in
            completion?(image)
            completion = nil
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
