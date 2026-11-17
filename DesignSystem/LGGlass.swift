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
struct LGGlassEdge: View {
    var radius: CGFloat
    var width: CGFloat = 1.2
    @ObservedObject private var light = LGLightDirection.shared

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(
                AngularGradient(stops: [
                    .init(color: .white.opacity(0.95), location: 0),
                    .init(color: .white.opacity(0.18), location: 0.22),
                    .init(color: .white.opacity(0.08), location: 0.45),
                    .init(color: .white.opacity(0.55), location: 0.52),
                    .init(color: .white.opacity(0.12), location: 0.72),
                    .init(color: .white.opacity(0.95), location: 1),
                ], center: .center, angle: .degrees(light.angle)),
                lineWidth: width)
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
