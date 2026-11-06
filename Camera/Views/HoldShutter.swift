// HoldShutter.swift
// 長押し1.5秒で撮る、の進み(7-4)と、シャッターの見た目(7-1・7-2)。
// 指でも音量ボタン(AVCaptureEventInteraction)でも、同じ begin / end を呼ぶ。

import SwiftUI
import QuartzCore
internal import Combine

@MainActor
final class HoldShutter: ObservableObject {
    /// 進み(0→1)
    @Published private(set) var progress: CGFloat = 0
    /// 段階(0: p<0.34 / 1: p<0.72 / 2: それ以上)
    @Published private(set) var stage = 0

    let duration: CFTimeInterval
    /// 撮影中・のこり0・許可なし・準備前は false
    var canStart: () -> Bool = { true }
    /// 押したが始められなかった(1回の押しにつき1回だけ)
    var onRefused: () -> Void = {}
    /// 押し始めた(触覚のじわっと強く)
    var onBegin: () -> Void = {}
    /// 途中で離した(触覚を止める)
    var onCancel: () -> Void = {}
    /// p が段階を通った
    var onStage: (Int) -> Void = { _ in }
    /// p == 1 で1回だけ
    var onFire: () -> Void = {}

    private var task: Task<Void, Never>?
    private var fired = false
    private var pressed = false
    private let now: () -> CFTimeInterval

    init(duration: CFTimeInterval = 1.5, now: @escaping () -> CFTimeInterval = CACurrentMediaTime) {
        self.duration = duration
        self.now = now
    }

    var isHolding: Bool { task != nil }

    /// 指/音量ボタンを押した。指が動くたびに呼ばれてもよい(1回の押しで1度だけ始める)
    func begin() {
        guard !pressed else { return }
        pressed = true
        guard task == nil, !fired else { return }
        guard canStart() else {
            onRefused()
            return
        }
        let t0 = now()
        onBegin()
        task = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                if self.tick(elapsed: self.now() - t0) { return }
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }

    /// 進みを1回すすめる。撮ったら true(テストからも呼ぶ)
    @discardableResult
    func tick(elapsed: CFTimeInterval) -> Bool {
        let p = CGFloat(min(1, max(0, elapsed / duration)))
        progress = p
        let nextStage = Self.stage(for: p)
        if nextStage != stage {
            stage = nextStage
            if nextStage > 0, p < 1 { onStage(nextStage) }
        }
        if p >= 1 {
            fired = true
            task?.cancel()
            task = nil
            onFire()
            return true
        }
        return false
    }

    /// 指/音量ボタンを離した・画面が消えた・撮影に失敗した。どの道でも必ずここでフラグを戻す
    func end() {
        task?.cancel()
        task = nil
        if !fired, progress > 0 || pressed { onCancel() }
        fired = false
        pressed = false
        progress = 0
        stage = 0
    }

    /// 撮影が終わった(成功・失敗・時間切れ)あとに、見た目だけ元に戻す。指を離すまで、もう一度は始めない
    func resetAfterShot() {
        task?.cancel()
        task = nil
        progress = 0
        stage = 0
    }

    nonisolated static func stage(for p: CGFloat) -> Int {
        if p < 0.34 { return 0 }
        if p < 0.72 { return 1 }
        return 2
    }

    nonisolated static func hint(for p: CGFloat) -> String {
        if p <= 0 { return "ながおしで、撮る" }
        switch stage(for: p) {
        case 0: return "そのまま…"
        case 1: return "もうすこし"
        default: return "もうすぐ"
        }
    }

    /// 鼓動(1秒に約1.2回 → 約3.8回)。経過時間 t の位相(周波数を時間で積分した値)
    nonisolated static func heartbeatPhase(elapsed t: Double, duration: Double = 1.5) -> Double {
        let f0 = 1.2, f1 = 3.8
        return 2 * .pi * (f0 * t + (f1 - f0) / (2 * duration) * t * t)
    }
}

// MARK: - シャッターの見た目

struct ShutterButtonView: View {
    let progress: CGFloat
    /// 段階のふくらみ(1.07倍、200ms)
    var bump = false
    var reduceMotion = false

    var body: some View {
        ZStack {
            // うすい下地リング(進みがあるときだけ)
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 5.5)
                .frame(width: 102, height: 102)
                .opacity(progress > 0 ? 1 : 0)

            // 進行リング(サンライズ、12時から時計まわり)。進みが0のときは点が残らないよう不透明度0
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(colors: CaptureTint.sunrise + [CaptureTint.sunrise[0]], center: .center, startAngle: .degrees(0), endAngle: .degrees(360)),
                    style: StrokeStyle(lineWidth: 5.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 102, height: 102)
                .shadow(color: CaptureTint.orange.opacity(0.7), radius: 3)
                .opacity(progress > 0.001 ? 1 : 0)

            // 銀の輪
            Circle()
                .fill(AngularGradient(colors: [Color(white: 0.92), Color(white: 0.55), Color(white: 0.98), Color(white: 0.6), Color(white: 0.92)], center: .center))
                .frame(width: 76, height: 76)

            // まん中の玉(上が明るい)
            Circle()
                .fill(RadialGradient(
                    colors: [PaletteHex(rgb: 0xFFB98A).color, PaletteHex(rgb: 0xFF6A1A).color, PaletteHex(rgb: 0xD94A0A).color],
                    center: UnitPoint(x: 0.5, y: 0.22), startRadius: 2, endRadius: 40
                ))
                .frame(width: 64, height: 64)
                .scaleEffect(1 - 0.18 * progress)
        }
        .scaleEffect(bump && !reduceMotion ? 1.07 : 1)
        .animation(.easeOut(duration: 0.1), value: bump)
        .frame(width: 120, height: 120)
        .contentShape(Circle())
    }
}
