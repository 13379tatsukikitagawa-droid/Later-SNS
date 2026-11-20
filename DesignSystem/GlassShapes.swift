import SwiftUI

/// 黒いガラス(白 8.5% → 3.5%・ふち 白12%・上のふちに細い光)。撮影 ・ ME の 画面で 使う。
struct GlassCapsule: View {
    var body: some View {
        Capsule()
            .fill(LinearGradient(colors: [.white.opacity(0.085), .white.opacity(0.035)], startPoint: .top, endPoint: .bottom))
            .background(.ultraThinMaterial.opacity(0.6), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}

struct GlassRect: View {
    var radius: CGFloat
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape
            .fill(LinearGradient(colors: [.white.opacity(0.085), .white.opacity(0.035)], startPoint: .top, endPoint: .bottom))
            .background(.ultraThinMaterial.opacity(0.6), in: shape)
            .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .overlay(alignment: .top) {
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
            }
    }
}
