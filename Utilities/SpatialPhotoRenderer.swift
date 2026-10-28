import CoreMotion
import Metal
import MetalKit
import UIKit

/// 空間写真の描画(高さ場レイマーチ + ディスクぼかし)。デモ later_video_mock_v3_demo.html の GLSL と同じ式。
enum SpatialPhotoShader {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct Uniforms {
        float2 cam;
        float2 res;
        float strength;
        float focus;
        float zoom;
        float blur;
        float grain;
        float lensR;
        float steps;
        float scanY;
        float scanGlow;
        float time;
        float2 fill;
    };

    struct VOut {
        float4 position [[position]];
        float2 uv;
    };

    vertex VOut spatialVertex(uint vid [[vertex_id]]) {
        float2 corners[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
        VOut out;
        out.position = float4(corners[vid], 0, 1);
        // 画像の左上を (0,0) にする
        out.uv = float2(corners[vid].x * 0.5 + 0.5, 0.5 - corners[vid].y * 0.5);
        return out;
    }

    float hash(float2 p) {
        return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
    }

    fragment float4 spatialFragment(VOut in [[stage_in]],
                                    constant Uniforms &u [[buffer(0)]],
                                    texture2d<float> colorTex [[texture(0)]],
                                    texture2d<float> depthTex [[texture(1)]],
                                    sampler s [[sampler(0)]]) {
        float2 fc = in.position.xy;

        // レンズの外は黒(パールがレンズになる)
        float dl = length(fc - u.res * 0.5);
        float lens = 1.0 - smoothstep(u.lensR - 1.5, u.lensR + 1.5, dl);
        if (lens <= 0.0) { return float4(0, 0, 0, 1); }

        // 画面いっぱいに写真を合わせる(切り取り)→ ズーム
        float2 base = (in.uv - 0.5) * u.fill + 0.5;
        float2 uv = (base - 0.5) / u.zoom + 0.5;

        // 高さ場レイマーチ:手前(h = 1)から奥へ降りて、最初に地面に当たった所を取る
        float2 dir = u.cam * u.strength;
        float h = 1.0;
        float jitter = hash(fc) / u.steps;
        float2 p = uv - dir * 0.5 + dir * jitter;
        float2 dp = dir / u.steps;
        float dh = 1.0 / u.steps;
        for (int i = 0; i < 96; i++) {
            if (float(i) >= u.steps) { break; }
            float d = depthTex.sample(s, clamp(p, 0.001, 0.999)).r;
            if (d >= h) { break; }
            h -= dh;
            p += dp;
        }
        // フォーカス面からのずれぶん、色の位置をずらす
        float2 sp = uv + dir * (h - u.focus);

        // ディスクぼかし(24タップ)
        float3 acc = float3(0.0);
        for (int k = 0; k < 24; k++) {
            float a = float(k) * 2.39996;
            float rr = sqrt(float(k) + 0.5) / sqrt(24.0) * u.blur;
            float2 o = float2(cos(a), sin(a)) * rr / u.res;
            acc += colorTex.sample(s, clamp(sp + o, 0.001, 0.999)).rgb;
        }
        float3 col = acc / 24.0;

        // 奥行きを読み取る帯(暖色・控えめ。近いほど強い)
        float band = (1.0 - smoothstep(0.0, 0.025, abs(in.uv.y - u.scanY))) * u.scanGlow;
        float near = depthTex.sample(s, clamp(uv, 0.001, 0.999)).r;
        col += float3(1.0, 0.72, 0.45) * band * 0.25 * (0.4 + 0.6 * near);

        // 粒子ノイズ・ビネット
        col += (hash(fc + u.time) - 0.5) * u.grain;
        float2 d2 = in.uv - 0.5;
        col *= 1.0 - 0.35 * dot(d2, d2);

        return float4(col * lens, 1.0);
    }
    """
}

/// MTKView に空間写真を描く。傾き(CoreMotion)を ±8° で切って、ローパスをかけてから使う。
final class SpatialPhotoRenderer: NSObject, MTKViewDelegate {
    /// Uniforms は Metal の struct と並び順・型をそろえる(float2 は 8 バイト境界)
    struct Uniforms {
        var cam: SIMD2<Float>
        var res: SIMD2<Float>
        var strength: Float
        var focus: Float
        var zoom: Float
        var blur: Float
        var grain: Float
        var lensR: Float
        var steps: Float
        var scanY: Float
        var scanGlow: Float
        var time: Float
        var fill: SIMD2<Float>
    }

    /// 傾きの最大(±8°)
    static let maxTilt: Double = 8 * Double.pi / 180
    static let lowPassFactor: Float = 0.12

    /// Metal が使えるか(シミュレータや古い端末では false → 普通の写真を出す)
    static var isAvailable: Bool { MTLCreateSystemDefaultDevice() != nil }

    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let sampler: MTLSamplerState
    private let colorTexture: MTLTexture
    private let depthTexture: MTLTexture
    private let imageAspect: CGFloat
    private let motion = CMMotionManager()
    private let start: Date
    private let reduceMotion: Bool
    private let lowPower: Bool

    private var reference: CMAttitude?
    private var manual = false
    private var camTarget = SIMD2<Float>(0, 0)
    private var cam = SIMD2<Float>(0, 0)

    init?(view: MTKView, color: UIImage, depth: UIImage, start: Date, reduceMotion: Bool) {
        guard let device = view.device,
              let queue = device.makeCommandQueue(),
              let library = try? device.makeLibrary(source: SpatialPhotoShader.source, options: nil),
              let vertex = library.makeFunction(name: "spatialVertex"),
              let fragment = library.makeFunction(name: "spatialFragment")
        else { return nil }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else { return nil }

        guard let colorImage = DepthMapEncoder.downscaledRGBA(color, maxLongSide: 1600),
              let depthImage = DepthMapEncoder.rgbaImage(from: depth)
        else { return nil }
        let loader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [.SRGB: false]
        guard let colorTexture = try? loader.newTexture(cgImage: colorImage, options: options),
              let depthTexture = try? loader.newTexture(cgImage: depthImage, options: options)
        else { return nil }

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        guard let sampler = device.makeSamplerState(descriptor: samplerDescriptor) else { return nil }

        self.queue = queue
        self.pipeline = pipeline
        self.sampler = sampler
        self.colorTexture = colorTexture
        self.depthTexture = depthTexture
        self.imageAspect = CGFloat(colorImage.width) / CGFloat(colorImage.height)
        self.start = start
        self.reduceMotion = reduceMotion
        self.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        super.init()

        // 視差効果を減らすときは、傾きを読まない(静止画)
        if !reduceMotion, motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1.0 / 30.0
            motion.startDeviceMotionUpdates()
        }
    }

    /// 画面から消えたとき・視差をやめるときに呼ぶ(傾きの読み取りを止める)
    func stop() {
        motion.stopDeviceMotionUpdates()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let buffer = queue.makeCommandBuffer(),
              let encoder = buffer.makeRenderCommandEncoder(descriptor: pass)
        else { return }

        let t = Date().timeIntervalSince(start)
        let frame = SpatialPhotoTimeline.at(t, reduceMotion: reduceMotion)
        readTilt()
        if frame.isSwaying && !manual && !lowPower {
            // 手で傾けていないあいだは、ゆっくり自動で揺れる
            let s = t - SpatialPhotoTimeline.swayStart
            camTarget = SIMD2<Float>(Float(0.6 * sin(s * 0.9)), Float(0.6 * sin(s * 0.6 + 1)))
        }
        cam += (camTarget - cam) * Self.lowPassFactor

        // 画面(画素)の大きさに合わせて、写真を切り取る(aspect fill)
        let width = Float(view.drawableSize.width), height = Float(view.drawableSize.height)
        let viewAspect = CGFloat(width / height)
        let fill = SIMD2<Float>(
            Float(min(1, viewAspect / imageAspect)),
            Float(min(1, imageAspect / viewAspect))
        )
        let scale = Float(view.contentScaleFactor)
        var uniforms = Uniforms(
            cam: cam,
            res: SIMD2<Float>(width, height),
            strength: Float(frame.strength),
            focus: Float(SpatialPhotoTimeline.focus),
            zoom: Float(SpatialPhotoTimeline.zoom),
            blur: Float(frame.blur) * scale,
            grain: 0.03,
            lensR: Float(min(frame.lensRadius, 10_000)) * scale,
            steps: lowPower ? 48 : 96,
            scanY: Float(frame.scanProgress),
            scanGlow: frame.isScanning ? 1 : 0,
            time: Float(t),
            fill: fill
        )

        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentTexture(colorTexture, index: 0)
        encoder.setFragmentTexture(depthTexture, index: 1)
        encoder.setFragmentSamplerState(sampler, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        buffer.present(drawable)
        buffer.commit()

        // 視差を減らすときは1枚だけ描いて止める
        if reduceMotion { view.isPaused = true }
    }

    /// 最初の姿勢を基準にして、傾きを -1〜1 にする(±8° でクランプ)
    private func readTilt() {
        guard !reduceMotion, let data = motion.deviceMotion else { return }
        // 基準は必ずコピーを取る(同じオブジェクトだと、差がゼロになる)
        if reference == nil { reference = data.attitude.copy() as? CMAttitude }
        guard let reference else { return }
        let attitude = data.attitude
        attitude.multiply(byInverseOf: reference)
        let roll = attitude.roll, pitch = attitude.pitch
        if abs(roll) + abs(pitch) > 0.01 { manual = true }
        camTarget = SIMD2<Float>(
            Float(max(-1, min(1, roll / Self.maxTilt))),
            Float(max(-1, min(1, pitch / Self.maxTilt)))
        )
    }
}
