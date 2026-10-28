import MetalKit
import SwiftUI
import UIKit

/// 空間写真。深度があれば奥行きつきで描き、なければ普通の写真として出す(エラーは見せない)。
/// 「視差効果を減らす」がオンのときは、深度があっても静止画にする。
struct SpatialPhotoView: View {
    let color: UIImage
    /// 深度マップ(8bit グレースケール)。nil なら普通の写真
    let depth: UIImage?

    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let depth, !reduceMotion, SpatialPhotoRenderer.isAvailable {
                SpatialMetalSurface(color: color, depth: depth, start: start, reduceMotion: reduceMotion)
                SpatialPhotoLabels(start: start, reduceMotion: reduceMotion)
            } else {
                Image(uiImage: color)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
        .clipped()
    }
}

/// 文字(事実だけ):「空間写真」チップ、「奥行きを読み取っています NN%」、「傾けると、奥行き」
private struct SpatialPhotoLabels: View {
    let start: Date
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSince(start)
            let frame = SpatialPhotoTimeline.at(t, reduceMotion: reduceMotion)
            VStack {
                HStack {
                    Text("空間写真")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.12)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
                        .opacity(t > 0.2 ? 1 : 0)
                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.top, 56)

                Spacer()

                if let percent = frame.scanPercent {
                    Text("奥行きを読み取っています \(percent)%")
                        .font(.system(size: 13))
                        .monospacedDigit()
                        .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.7))
                        .padding(.bottom, 240)
                }
                if frame.showsHint {
                    Text("傾けると、奥行き")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, 96)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// MTKView を SwiftUI に載せる。消えるときに傾きの読み取りを止める。
private struct SpatialMetalSurface: UIViewRepresentable {
    let color: UIImage
    let depth: UIImage
    let start: Date
    let reduceMotion: Bool

    final class Coordinator {
        var renderer: SpatialPhotoRenderer?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)
        view.isOpaque = true
        view.framebufferOnly = true
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = ProcessInfo.processInfo.isLowPowerModeEnabled ? 30 : 60
        if let renderer = SpatialPhotoRenderer(view: view, color: color, depth: depth, start: start, reduceMotion: reduceMotion) {
            view.delegate = renderer
            context.coordinator.renderer = renderer
        }
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}

    static func dismantleUIView(_ uiView: MTKView, coordinator: Coordinator) {
        coordinator.renderer?.stop()
        uiView.delegate = nil
    }
}
