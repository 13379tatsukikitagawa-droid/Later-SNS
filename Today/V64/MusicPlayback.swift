// MusicPlayback.swift
// v89 D:今日の 1曲の プレビュー(30秒 ・ くり返し)。シートを とじても 流れつづける。撮影画面では 小さく(45%)。
// Apple Music に 入って いなくても 流れる(previewAssets)。ほかの 音楽は 止まって よい(.playback)。

import AVFoundation
import Observation

@Observable
final class MusicPlayback {
    static let shared = MusicPlayback()

    private(set) var playingKey: String?
    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var loopObserver: NSObjectProtocol?
    @ObservationIgnored private var fadeTimer: Timer?
    @ObservationIgnored private(set) var volume: Float = 0.9

    var isPlaying: Bool { playingKey != nil }

    func isPlaying(_ key: String) -> Bool { playingKey == key }

    /// 流す(同じ 曲を もう1回 = 止める)
    func toggle(key: String, url: URL?) {
        if playingKey == key { stop(); return }
        guard let url else { return }
        start(key: key, url: url)
    }

    func start(key: String, url: URL) {
        stopImmediately()
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.volume = volume
        loopObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak p] _ in
            p?.seek(to: .zero); p?.play()
        }
        p.play()
        player = p
        playingKey = key
    }

    /// 撮影画面の 間は 小さく
    func setVolume(_ v: Float) {
        volume = v
        player?.volume = v
    }

    func stop() { stopImmediately() }

    /// フェードで 止める(撮った あと ・ Home へ もどった とき)
    func fadeOut(duration: TimeInterval = 0.6) {
        guard let p = player else { return }
        fadeTimer?.invalidate()
        let steps = 12, start = p.volume
        var i = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: duration / Double(steps), repeats: true) { [weak self] t in
            i += 1
            p.volume = start * Float(max(0, 1 - Double(i) / Double(steps)))
            if i >= steps { t.invalidate(); self?.stopImmediately() }
        }
    }

    private func stopImmediately() {
        fadeTimer?.invalidate(); fadeTimer = nil
        player?.pause(); player = nil
        if let o = loopObserver { NotificationCenter.default.removeObserver(o); loopObserver = nil }
        playingKey = nil
    }
}
