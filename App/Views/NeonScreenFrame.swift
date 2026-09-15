import SwiftUI

extension Notification.Name {
    /// 解禁・目標達成などここぞという瞬間に、NeonScreenFrameを一瞬だけ強く光らせるための
    /// トリガー。どの画面からでも`NotificationCenter.default.post(name: .neonFramePulseRequested, object: nil)`
    /// を呼ぶだけで良い(NeonScreenFrame自体はMainTabViewに1つだけマウントされている)。
    static let neonFramePulseRequested = Notification.Name("neonFramePulseRequested")
}

/// SETLOG風の「画面外周が優しく発光している」演出。
///
/// 以前は`TimelineView(.animation)`で緑の光の尾を持つビームを画面外周に沿って
/// 常時周回させ続けており、毎フレーム(最大120Hz)最大32個の`RoundedRectangle.trim().stroke()`を
/// 再構築していた。これがアプリ全体の負荷の主要因の1つになっていたため、通常時は
/// 完全に静的な縁取り+shadow(TimelineView無し、再描画は他の理由でこのViewが
/// 更新される時だけ)に変更した。解禁・目標達成などのイベント時だけ、
/// `.neonFramePulseRequested`通知を受けて一瞬だけ光が強まり、また静止状態へ
/// 戻る短いアニメーションを再生する。
///
/// 使い方: `SomeRootView().overlay(NeonScreenFrame())`
struct NeonScreenFrame: View {
    private static let neonGreen = Color.brandGreen
    private static let baseOpacity: Double = 0.6
    private static let baseShadowRadius: CGFloat = 14
    private static let pulseOpacity: Double = 1.0
    private static let pulseShadowRadius: CGFloat = 26

    var cornerRadius: CGFloat = 40
    var lineWidth: CGFloat = 2.5

    @State private var borderOpacity: Double = NeonScreenFrame.baseOpacity
    @State private var shadowRadius: CGFloat = NeonScreenFrame.baseShadowRadius

    private var frameShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        frameShape
            .strokeBorder(Self.neonGreen.opacity(borderOpacity), lineWidth: lineWidth)
            .shadow(color: Self.neonGreen.opacity(0.6), radius: shadowRadius, x: 0, y: 0)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onReceive(NotificationCenter.default.publisher(for: .neonFramePulseRequested)) { _ in
                pulse()
            }
    }

    private func pulse() {
        withAnimation(.easeOut(duration: 0.25)) {
            borderOpacity = Self.pulseOpacity
            shadowRadius = Self.pulseShadowRadius
        }
        withAnimation(.easeInOut(duration: 0.9).delay(0.25)) {
            borderOpacity = Self.baseOpacity
            shadowRadius = Self.baseShadowRadius
        }
    }
}
