import Foundation
import SwiftUI

// v21 B:画面のシャッターと音量ボタン(サイドボタン・Camera Control)を、同じ「長押しの状態機械」につなぐ。
// 入力元(画面 / 音量)だけがちがう。先に押した方が勝ち、はなすのも同じ入力元。2回押しは なし。
// 写真:1.5秒おしつづけて撮る(目もりが 24こ ぐるっと)。はやく はなす → 何も撮らない(soft・「もうすこし、長く」)
// 動画:0.62秒ためる → 録画(thud → 90ms click)→ おしている間まわる → はなすと とまる。10秒で自動。1秒未満は使わない。
// タップ式(設定・VoiceOver・スイッチコントロール):動画は 1回目で はじまり、もう1回で とまる(音量ボタンも同じ)。

enum ShutterSource: Equatable {
    case screen, volume
}

enum ShutterRules {
    static let photoHold: Double = 1.5
    static let ticks = 24

    /// 写真:灯る目もりの数(進み = 時間^1.25)
    static func litTicks(progress k: Double) -> Int {
        min(ticks, Int(Double(ticks) * pow(max(0, min(1, k)), 1.25)))
    }

    /// 写真のヒント(○ ○ ○ そのまま / ● ○ ○ もうすこし / ● ● ○ いま)
    static func photoHint(stage: Int) -> String {
        switch stage {
        case 0: return "○ ○ ○  そのまま"
        case 1: return "● ○ ○  もうすこし"
        default: return "● ● ○  いま"
        }
    }

    static func idleHint(mode: CaptureMode, left: Int) -> String {
        if left <= 0 { return "今日は、ここまで" }
        return mode == .video ? "ながおしで まわす ・ はなすと とまる ・ 音量ボタンも" : "ながおしで撮る ・ 音量ボタンも ながおし"
    }
}

@MainActor @Observable
final class ShutterGesture {
    enum Phase: Equatable {
        case idle
        /// 写真:おしつづけている
        case holding(start: Date)
        /// 動画:ためている
        case charging(start: Date)
        /// 動画:録画中
        case recording(start: Date)
    }

    private(set) var phase: Phase = .idle
    private(set) var source: ShutterSource?
    /// 写真 0〜1・動画のためる 0〜1
    private(set) var progress: Double = 0
    /// 灯っている目もり
    private(set) var lit = 0
    /// 録画の経過
    private(set) var elapsed: Double = 0
    /// はやく はなした(ヒント「もうすこし、長く」)
    private(set) var releasedEarlyToken = 0
    /// 撮れた(芯が きゅっと点 → ぱっと戻る)
    private(set) var snapToken = 0

    var mode: CaptureMode = .photo
    /// 撮れる状態か(カメラが動いている・のこりがある)
    @ObservationIgnored var canStart: () -> Bool = { true }
    @ObservationIgnored var onRefused: () -> Void = {}
    @ObservationIgnored var onPhoto: (ShutterSource) -> Void = { _ in }
    @ObservationIgnored var onStartRecording: () -> Void = {}
    @ObservationIgnored var onStopRecording: (_ took: Double, _ auto: Bool) -> Void = { _, _ in }

    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private let ramp = HapticRamp()

    nonisolated init() {}

    var isBusy: Bool { phase != .idle }
    var isRecording: Bool { if case .recording = phase { return true } else { return false } }

    /// タップ式(動画だけ)
    var tapToRecord: Bool { RetroSettings.usesTapRecording }

    // MARK: 入力

    func press(_ from: ShutterSource) {
        if from == .volume { Haptics.play(.click) }
        switch phase {
        case .idle:
            guard canStart() else {
                Haptics.play(.warn)
                onRefused()
                return
            }
            source = from
            if mode == .photo { beginPhoto() } else { beginCharge() }
        case .recording where tapToRecord && from == source:
            stopRecording(auto: false)
        default:
            break   // 先に押した方が勝ち
        }
    }

    func release(_ from: ShutterSource) {
        guard from == source else { return }
        switch phase {
        case .holding:
            cancelPhoto()
        case .charging where !tapToRecord:
            cancelCharge()
        case .recording where !tapToRecord:
            stopRecording(auto: false)
        default:
            break
        }
    }

    /// アプリが うしろへ:写真は捨てる。動画は 1秒以上なら そこまで保存(未満は捨てる)
    func interrupt() {
        switch phase {
        case .holding: cancelPhoto()
        case .charging: cancelCharge()
        case .recording: stopRecording(auto: false)
        case .idle: break
        }
    }

    /// VoiceOver の操作:長押しなしで撮る / はじめる・とめる
    func accessibilityActivate() {
        guard phase == .idle || isRecording else { return }
        if isRecording { stopRecording(auto: false); return }
        guard canStart() else { Haptics.play(.warn); onRefused(); return }
        source = .screen
        if mode == .photo {
            snapToken += 1
            onPhoto(.screen)
            source = nil
        } else {
            beginRecording()
        }
    }

    // MARK: 写真

    private func beginPhoto() {
        let start = Date()
        phase = .holding(start: start)
        progress = 0
        lit = 0
        Haptics.play(.pop)
        ramp.start()
        loop?.cancel()
        loop = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled, case .holding = self.phase {
                let k = min(1, Date().timeIntervalSince(start) / ShutterRules.photoHold)
                self.progress = k
                self.ramp.update(0.12 + 0.78 * k)
                let want = ShutterRules.litTicks(progress: k)
                while self.lit < want {
                    self.lit += 1
                    if self.lit % 8 == 0 && self.lit < ShutterRules.ticks { Haptics.play(.click, gap: 0) } else { Haptics.play(.tick, gap: 0) }
                }
                if k >= 1 {
                    self.finishPhoto()
                    return
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func finishPhoto() {
        ramp.stop()
        let from = source ?? .screen
        phase = .idle
        source = nil
        snapToken += 1
        onPhoto(from)
        rewind(fast: false)
    }

    private func cancelPhoto() {
        loop?.cancel()
        ramp.stop()
        phase = .idle
        source = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { progress = 0 }
        Haptics.play(.soft)
        releasedEarlyToken += 1
        rewind(fast: true)
    }

    /// 灯った目もりを、逆まわりに すばやく消す(0.014秒ずつ。3本ごとに tick)
    private func rewind(fast: Bool) {
        let start = lit
        guard start > 0 else { return }
        Task { @MainActor [weak self] in
            var i = 0
            while let self, self.lit > 0, self.phase == .idle {
                self.lit -= 1
                if fast && i % 3 == 0 { Haptics.play(.tick, gap: 0.03) }
                i += 1
                try? await Task.sleep(for: .milliseconds(14))
            }
            self?.progress = 0
        }
    }

    // MARK: 動画

    private func beginCharge() {
        let start = Date()
        phase = .charging(start: start)
        Haptics.play(.pop)
        ramp.start()
        loop?.cancel()
        loop = Task { @MainActor [weak self] in
            var ticks = 0
            while let self, !Task.isCancelled, case .charging = self.phase {
                let k = min(1, Date().timeIntervalSince(start) / VideoRules.charge)
                self.progress = k
                self.ramp.update(0.12 + 0.5 * k)
                while ticks < Int(k * 4) { ticks += 1; Haptics.play(.tick, gap: 0) }
                if k >= 1 { self.beginRecording(); return }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func cancelCharge() {
        loop?.cancel()
        ramp.stop()
        phase = .idle
        source = nil
        withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
        Haptics.play(.soft)
    }

    private func beginRecording() {
        let start = Date()
        phase = .recording(start: start)
        progress = 0
        lit = 0
        Haptics.play(.thud)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { Haptics.play(.click) }
        ramp.start()
        ramp.update(0.14)
        onStartRecording()
        loop?.cancel()
        loop = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled, case .recording = self.phase {
                let e = Date().timeIntervalSince(start)
                self.elapsed = e
                self.ramp.update(VideoShutterRules.reelLevel(elapsed: e))
                let now = VideoShutterRules.litTicks(elapsed: e)
                if now > self.lit { self.lit = now; Haptics.play(.tick, gap: 0, intensity: 0.5) }
                if e >= VideoRules.maxDuration { self.stopRecording(auto: true); return }
                try? await Task.sleep(for: .milliseconds(30))
            }
        }
    }

    private func stopRecording(auto: Bool) {
        guard case .recording(let start) = phase else { return }
        loop?.cancel()
        ramp.stop()
        let took = Date().timeIntervalSince(start)
        phase = .idle
        source = nil
        elapsed = 0
        lit = 0
        if auto {
            Haptics.play(.thud)
        } else {
            Haptics.play(.click)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) { Haptics.play(.soft) }
        }
        onStopRecording(took, auto)
    }
}
