import SwiftUI
internal import Combine
import CoreMotion

/// ふちの 光の 向き(PROMPT_v65 §6)。端末の かたむき(Core Motion)を なめらかに 追う。
/// 角度 = 210° + 横の かたむき × 70°。2.5秒 触らないと ゆっくり 自動で ゆれる。Reduce Motion では 210° で 止める。
@MainActor
final class LGLightDirection: ObservableObject {
    static let shared = LGLightDirection()
    @Published private(set) var angle: Double = 210

    private let motion = CMMotionManager()
    private var smoothRoll = 0.0, smoothPitch = 0.0
    private var lastTouch = Date.distantPast
    private var timer: Timer?
    private var users = 0

    func start() {
        users += 1
        guard users == 1 else { return }
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1.0 / 30
            motion.startDeviceMotionUpdates()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        users = max(0, users - 1)
        guard users == 0 else { return }
        timer?.invalidate(); timer = nil
        motion.stopDeviceMotionUpdates()
    }

    /// 指で なぞって いる 間の 位置(-1〜1)
    func touch(x: Double) { lastTouch = Date(); smoothRoll = max(-1, min(1, x)) }

    private func tick() {
        // 画面が 前に 出て いない とき(バックグラウンド)は 計算しない
        guard UIApplication.shared.applicationState == .active else { return }
        if UIAccessibility.isReduceMotionEnabled { if angle != 210 { angle = 210 }; return }
        var roll = smoothRoll, pitch = smoothPitch
        let idle = Date().timeIntervalSince(lastTouch) > 2.5
        if let m = motion.deviceMotion {
            roll = max(-1, min(1, m.attitude.roll / (.pi / 4)))
            pitch = max(-1, min(1, m.attitude.pitch / (.pi / 4)))
        } else if idle {
            let t = Date.timeIntervalSinceReferenceDate
            roll = sin(2 * .pi * 0.35 * t)
            pitch = sin(2 * .pi * 0.27 * t)
        }
        if Date().timeIntervalSince(lastTouch) > 0.2 {
            smoothRoll += (roll - smoothRoll) * 0.08
            smoothPitch += (pitch - smoothPitch) * 0.08
        }
        // 0.4° 未満の 変化では 公開しない(読んで いる 全部の ふちが 作り直されるのを へらす)
        let next = 210 + smoothRoll * 70
        if abs(next - angle) >= 0.4 { angle = next }
    }
}

/// ふちの 光(角度の グラデーション)。iOS 26 より 前の 端末で 使う。
/// 角度の グラデーションの 絵は 1回 だけ 作って 使いまわし、傾きでは 絵を 回転させる だけ(毎回 描きなおさない)。
struct LGGlassEdge: View {
    var radius: CGFloat
    var width: CGFloat = 1.2
    @ObservedObject private var light = LGLightDirection.shared

    /// 白 95% → 22% 地点 18% → 45% 地点 8% → 52% 地点 55% → 72% 地点 12% → 白 95%(PROMPT_v65 §6)
    private static let conic: UIImage = {
        let n = 256
        return UIGraphicsImageRenderer(size: CGSize(width: n, height: n)).image { ctx in
            let stops: [(Double, CGFloat)] = [(0, 0.95), (0.22, 0.18), (0.45, 0.08), (0.52, 0.55), (0.72, 0.12), (1, 0.95)]
            func alpha(_ t: Double) -> CGFloat {
                for i in 1..<stops.count where t <= stops[i].0 {
                    let a = stops[i - 1], b = stops[i], k = CGFloat((t - a.0) / (b.0 - a.0))
                    return a.1 + (b.1 - a.1) * k
                }
                return stops.last!.1
            }
            let c = CGPoint(x: Double(n) / 2, y: Double(n) / 2)
            let steps = 360
            for i in 0..<steps {
                let t = Double(i) / Double(steps)
                let a0 = t * 2 * .pi - .pi / 2, a1 = (t + 1.0 / Double(steps) * 1.2) * 2 * .pi - .pi / 2
                let path = UIBezierPath()
                path.move(to: c)
                path.addArc(withCenter: c, radius: CGFloat(n), startAngle: CGFloat(a0), endAngle: CGFloat(a1), clockwise: true)
                path.close()
                UIColor.white.withAlphaComponent(alpha(t)).setFill()
                path.fill()
            }
        }
    }()

    var body: some View {
        // 角度 0 = 真上。モックの `from <angle>deg` と 同じ 向きで 回す
        Color.clear
            .overlay {
                Image(uiImage: Self.conic).resizable().frame(width: 600, height: 600)
                    .rotationEffect(.degrees(light.angle))
            }
            .mask(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.white, lineWidth: width))
            .allowsHitTesting(false)
            .onAppear { light.start() }
            .onDisappear { light.stop() }
    }
}

/// すりガラス。iOS 26:`.glassEffect`(押せる 物は `.interactive()`)。それ より 前:`.ultraThinMaterial` + 白 + ふち。
struct LGGlassModifier: ViewModifier {
    var radius: CGFloat
    var interactive: Bool
    var edge: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            if interactive { content.glassEffect(.regular.interactive(), in: shape) }
            else { content.glassEffect(.regular, in: shape) }
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(LGGlassEdge(radius: radius, width: edge))
        }
    }
}

extension View {
    func lgGlass(radius: CGFloat = 18, interactive: Bool = false, edge: CGFloat = 1.2) -> some View {
        modifier(LGGlassModifier(radius: radius, interactive: interactive, edge: edge))
    }
}
