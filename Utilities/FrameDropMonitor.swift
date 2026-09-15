import SwiftUI
import QuartzCore
import os

/// Instrumentsを使わずに「フレームドロップが起きているか」を確認するための、
/// CADisplayLinkベースの簡易モニター。画面の理想フレーム間隔(ProMotion機なら
/// 約8.3ms=120Hz、それ以外は約16.7ms=60Hz)の1.5倍を超えた間隔が来た回数と、
/// 一番ひどかった間隔をログに出す。
///
/// 常時有効にするとログが増えすぎるため、`.trackFrameDrops(label:)`で
/// 明示的に付けた画面が表示されている間だけ計測する。
private final class FrameDropRecorder {
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var droppedFrameCount = 0
    private var worstFrameMs: Double = 0
    private var totalFrameCount = 0
    private let label: String
    private let logger = Logger(subsystem: "jp.shotoku.later", category: "Performance")

    init(label: String) {
        self.label = label
    }

    func start() {
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        logger.notice("[Perf] FrameDropMonitor開始: \(self.label, privacy: .public)")
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        let summary = totalFrameCount > 0
            ? "総フレーム数=\(totalFrameCount), 閾値超え=\(droppedFrameCount)件, 最悪フレーム=\(String(format: "%.1f", worstFrameMs))ms"
            : "フレーム未計測(表示時間が短すぎた可能性)"
        logger.notice("[Perf] FrameDropMonitor終了: \(self.label, privacy: .public) - \(summary, privacy: .public)")
    }

    @objc private func tick(_ link: CADisplayLink) {
        defer { lastTimestamp = link.timestamp }
        totalFrameCount += 1
        guard let lastTimestamp else { return }
        let delta = (link.timestamp - lastTimestamp) * 1000
        // targetTimestamp - timestampが理想的な1フレーム分の間隔(ProMotion機のリフレッシュレート
        // 変動にも追従する)。その1.5倍を超えたら「ドロップした」とみなす。
        let idealFrameMs = (link.targetTimestamp - link.timestamp) * 1000
        let threshold = max(idealFrameMs, 16.7) * 1.5
        if delta > threshold {
            droppedFrameCount += 1
            worstFrameMs = max(worstFrameMs, delta)
        }
    }
}

private struct FrameDropTrackingModifier: ViewModifier {
    let label: String
    @State private var recorder: FrameDropRecorder?

    func body(content: Content) -> some View {
        content
            .onAppear {
                let recorder = FrameDropRecorder(label: label)
                self.recorder = recorder
                recorder.start()
            }
            .onDisappear {
                recorder?.stop()
                recorder = nil
            }
    }
}

extension View {
    /// この画面が表示されている間、フレームドロップの発生回数と最悪ケースをログに出す。
    /// 「Instrumentsを使わずともスクロール時のフレームドロップを判別できるように」という
    /// 調査要件のための、Gallery等スクロールが絡む画面向けの一時的な計測用modifier。
    func trackFrameDrops(_ label: String) -> some View {
        modifier(FrameDropTrackingModifier(label: label))
    }
}
