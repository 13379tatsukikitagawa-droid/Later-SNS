import AVFoundation
import SwiftUI

// v20 撮影画面の動画モード(見本:Docs/Mocks/later_video_v20.html)。
// 上のまん中のガラスのカプセル「写真 / 動画」・ファインダーを よこになぞっても切りかわる(左へ = 動画)。
// 動画のシャッターは珊瑚いろ:おして 0.62秒ためる → ドン・カチッで録画 → 目もり 24こが 0.42秒ごとにともる →
// 7秒すぎで赤 → はなすと とまる(10秒ぴったりは自動)。1秒より みじかいと 1こま使わない。

enum CaptureMode: String, Equatable {
    case photo, video
}

enum VideoShutterRules {
    /// よこになぞる:46pt 以上・縦は 40pt 以内
    static func swipe(dx: CGFloat, dy: CGFloat) -> CaptureMode? {
        guard abs(dx) >= 46, abs(dy) <= 40 else { return nil }
        return dx < 0 ? .video : .photo
    }

    /// 録画の経過 → ともった目もりの数
    static func litTicks(elapsed: Double) -> Int {
        min(VideoRules.tickCount, max(0, Int(elapsed / VideoRules.tickInterval)))
    }

    /// のこり わずか(赤)
    static func isWarning(elapsed: Double) -> Bool { elapsed >= VideoRules.warnAfter }

    /// 録画中の連続バイブ(reel):ふだん 0.14「カラカラ」、7秒すぎで 0.16 → 0.76「ぎゅーっ」
    static func reelLevel(elapsed: Double) -> Double {
        guard elapsed >= VideoRules.warnAfter else { return 0.14 }
        let k = min(1, (elapsed - VideoRules.warnAfter) / (VideoRules.maxDuration - VideoRules.warnAfter))
        return 0.16 + 0.6 * k
    }

    /// 「● 00:03 / 10」
    static func timerText(_ elapsed: Double) -> String {
        String(format: "● %02d:%02d / %d", Int(elapsed) / 60, Int(elapsed) % 60, Int(VideoRules.maxDuration))
    }

    static let coral: [Color] = [Color(hex: "FF9A7A"), Color(hex: "FF5A3C"), Color(hex: "D63A26")]
}

/// 上のまん中:写真 / 動画(白いつまみが ばねで左右に。動画のときは橙〜桃)
struct CaptureModeSwitch: View {
    let mode: CaptureMode
    let onChange: (CaptureMode) -> Void

    var body: some View {
        ZStack(alignment: mode == .photo ? .leading : .trailing) {
            Capsule().fill(.white.opacity(0.085)).background(.ultraThinMaterial.opacity(0.5), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            Capsule()
                .fill(mode == .photo ? AnyShapeStyle(Color.white) : AnyShapeStyle(LinearGradient(colors: [Color(hex: "FFB36A"), Color(hex: "FF5DA2")], startPoint: .leading, endPoint: .trailing)))
                .frame(width: 54, height: 26)
                .padding(2)
            HStack(spacing: 0) {
                label("写真", .photo)
                label("動画", .video)
            }
        }
        .frame(width: 112, height: 30)
        .animation(.spring(response: 0.38, dampingFraction: 0.7), value: mode)
        .accessibilityElement(children: .contain)
    }

    private func label(_ text: String, _ value: CaptureMode) -> some View {
        Button { if mode != value { onChange(value) } } label: {
            Text(text)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(mode == value ? Color(hex: "111111") : .white.opacity(0.75))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityAddTraits(mode == value ? .isSelected : [])
    }
}

/// 録画のシャッター(形は写真と同じ 24こまの目もりのリング。色だけ珊瑚)
struct VideoShutterButton: View {
    /// 0〜1(ためる)
    let charge: Double
    let recording: Bool
    let elapsed: Double
    let reduceMotion: Bool

    var body: some View {
        let warning = VideoShutterRules.isWarning(elapsed: elapsed)
        let ringColor = warning ? Color(hex: "FF3B30") : Color(hex: "FF5A3C")
        let lit = recording ? VideoShutterRules.litTicks(elapsed: elapsed) : 0
        let progress = recording ? min(1, elapsed / VideoRules.maxDuration) : 0.06 * charge
        ZStack {
            // 目もり 24本(8本ごとに太い)
            ForEach(0..<VideoRules.tickCount, id: \.self) { i in
                Capsule()
                    .fill(i < lit ? ringColor : .white.opacity(0.28))
                    .frame(width: i % 8 == 0 ? 2.4 : 1.4, height: i % 8 == 0 ? 9 : 6)
                    .offset(y: -62)
                    .rotationEffect(.degrees(Double(i) / Double(VideoRules.tickCount) * 360))
            }
            Circle().stroke(.white.opacity(0.28), lineWidth: 1.2).frame(width: 104, height: 104)
            Circle().trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 104, height: 104)
            RoundedRectangle(cornerRadius: recording ? 12 : 38, style: .continuous)
                .fill(LinearGradient(colors: VideoShutterRules.coral, startPoint: .top, endPoint: .bottom))
                .frame(width: 76, height: 76)
                .scaleEffect(recording ? 0.46 : 1 - 0.3 * charge)
                .shadow(color: Color(hex: "FF5A3C").opacity(0.5), radius: 12, y: 4)
        }
        .frame(width: 132, height: 132)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.32, dampingFraction: 0.7), value: recording)
    }
}

/// 動画モードの重ね(ファインダーの加工映像・カプセル・シャッター・録画のしるし)
struct VideoModeLayer: View {
    let camera: CaptureCameraModel
    let layout: CaptureLayout
    @Binding var mode: CaptureMode
    let left: Int
    /// とめて、のこった動画(1秒以上)
    let onRecorded: (RecordedVideo) -> Void
    let onRecordingChange: (Bool) -> Void
    /// 音量ボタン(動画モードでは、押している間だけ録画)
    var volumeDown = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("video.micAsked") private var micAsked = false
    @State private var hasAudio = false
    @State private var charge = 0.0
    @State private var charging = false
    @State private var recording = false
    @State private var recordStart: Date?
    @State private var elapsed = 0.0
    @State private var loop: Task<Void, Never>?
    @State private var ramp = HapticRamp()
    @State private var switchFlash = 0.0
    @State private var toast: String?
    @State private var pressed = false

    private var finder: CGRect { layout.finder }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if mode == .video {
                // 加工した映像(ライブ映像と書き出しは同じ絵)
                RetroPreviewView(layer: camera.recorder.displayLayer)
                    .frame(width: finder.width, height: finder.height)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        // 録画中:ふちが珊瑚いろに、息をするように光る
                        if recording {
                            TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
                                let breath = reduceMotion ? 1 : 0.55 + 0.45 * sin(context.date.timeIntervalSinceReferenceDate * 2 * .pi / 1.6)
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .strokeBorder(VideoShutterRules.isWarning(elapsed: elapsed) ? Color(hex: "FF3B30") : Color(hex: "FF7A5A"), lineWidth: 2.5)
                                    .opacity(breath)
                            }
                        }
                    }
                    .offset(x: finder.minX, y: finder.minY)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            // 切りかえた瞬間:ふっと明るく、にじんでから戻る(0.3秒)
            RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.white)
                .frame(width: finder.width, height: finder.height)
                .blur(radius: 20)
                .opacity(switchFlash)
                .offset(x: finder.minX, y: finder.minY)
                .allowsHitTesting(false)

            // 左上の小さな字
            Text(mode == .video ? "RETRO-8 ・ 30fps" : "LIVE ・ ISO 400")
                .font(.system(size: 9.5, design: .monospaced))
                .tracking(0.16 * 9.5)
                .foregroundStyle(.white.opacity(0.8))
                .offset(x: finder.minX + 18, y: finder.minY + 16)
                .allowsHitTesting(false)

            // 上のまん中:カプセル(録画中は「● 00:03 / 10」)
            Group {
                if recording {
                    TimelineView(.periodic(from: .now, by: 0.5)) { context in
                        let blink = Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
                        Text(VideoShutterRules.timerText(elapsed))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .overlay(alignment: .leading) {
                                Circle().fill(Color(hex: "FF3B30")).frame(width: 7, height: 7).opacity(blink ? 1 : 0.2).padding(.leading, 1)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(Capsule().fill(.black.opacity(0.45)))
                    }
                } else {
                    CaptureModeSwitch(mode: mode) { switchMode(to: $0) }
                }
            }
            .position(x: layout.size.width / 2, y: 122 + 15)

            if mode == .video {
                VStack(spacing: 6) {
                    VideoShutterButton(charge: charge, recording: recording, elapsed: elapsed, reduceMotion: reduceMotion)
                        .contentShape(Circle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in if !pressed { pressed = true; pressBegan() } }
                                .onEnded { _ in pressed = false; pressEnded() }
                        )
                        .accessibilityElement()
                        .accessibilityLabel(recording ? "録画をとめる" : "録画をはじめる")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { recording ? stop(auto: false) : startCharge(thenRecord: true) }
                    Text(hint)
                        .font(.system(size: 12.5, weight: .medium))
                        .tracking(0.75)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .position(x: layout.shutterCenter.x, y: layout.shutterCenter.y + 14)
            }

            if let toast {
                Text(toast)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(GlassCapsule())
                    .position(x: layout.size.width / 2, y: finder.midY)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.25), value: mode)
        .animation(.easeOut(duration: 0.25), value: toast)
        .onAppear { camera.recorder.setActive(mode == .video) }
        .onDisappear {
            if recording { stop(auto: false) }
            camera.recorder.setActive(false)
            ramp.stop()
        }
        .onChange(of: mode) { _, m in camera.recorder.setActive(m == .video) }
        .onChange(of: volumeDown) { _, down in if mode == .video { volume(down) } }
        .onChange(of: scenePhase) { _, phase in
            // 割りこみ:1秒以上撮れていれば、そこまでを保存して とめる(1秒未満は捨てる)
            if phase != .active, recording { stop(auto: false) }
        }
    }

    private var hint: String {
        if recording { return VideoShutterRules.isWarning(elapsed: elapsed) ? "もうすぐ 10びょう" : "はなすと とまる" }
        if charging { return "○ ○ ○ そのまま" }
        return RetroSettings.usesTapRecording ? "タップで はじめる" : "おして まわす"
    }

    // MARK: 切りかえ

    func switchMode(to next: CaptureMode) {
        guard next != mode, !recording, !charging else { return }
        Haptics.play(.detent)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { Haptics.play(.tick, gap: 0) }
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.1)) { switchFlash = 0.35 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { withAnimation(.easeOut(duration: 0.2)) { switchFlash = 0 } }
        }
        mode = next
        if next == .video { prepareAudio() }
    }

    /// はじめて動画モードに切りかえた時に、マイクの許可をもらう。断られたら音なし
    private func prepareAudio() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined && !micAsked {
            micAsked = true
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if granted { connectAudio() } else { show("音なし") }
                }
            }
        } else if status == .authorized {
            connectAudio()
        } else {
            hasAudio = false
        }
    }

    private func connectAudio() {
        camera.enableAudio { ok in DispatchQueue.main.async { hasAudio = ok } }
    }

    // MARK: 録画

    private func pressBegan() {
        if RetroSettings.usesTapRecording {
            if recording { stop(auto: false) } else { startCharge(thenRecord: true) }
            return
        }
        startCharge(thenRecord: true)
    }

    private func pressEnded() {
        guard !RetroSettings.usesTapRecording else { return }
        if charging {
            // ためている途中で はなした:何も撮らない
            cancelCharge()
        } else if recording {
            stop(auto: false)
        }
    }

    /// 音量ボタン(押している間だけ録画)
    func volume(_ down: Bool) {
        if down { if !recording && !charging { startCharge(thenRecord: true) } } else { pressEnded() }
    }

    private func startCharge(thenRecord: Bool) {
        guard !recording, !charging else { return }
        guard left > 0 else {
            Haptics.play(.warn)
            show("今日は、ここまで")
            return
        }
        charging = true
        Haptics.play(.pop)
        ramp.start()
        let start = Date()
        loop?.cancel()
        loop = Task { @MainActor in
            var ticks = 0
            while !Task.isCancelled && charging {
                let k = min(1, Date().timeIntervalSince(start) / VideoRules.charge)
                charge = k
                ramp.update(0.12 + 0.5 * k)
                let due = Int(k * 4)
                while ticks < due { ticks += 1; Haptics.play(.tick, gap: 0) }
                if k >= 1 { beginRecording(); return }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func cancelCharge() {
        charging = false
        loop?.cancel()
        ramp.stop()
        withAnimation(.easeOut(duration: 0.2)) { charge = 0 }
        Haptics.play(.soft)
    }

    private func beginRecording() {
        charging = false
        charge = 0
        Haptics.play(.thud)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { Haptics.play(.click) }
        camera.recorder.startRecording(audio: hasAudio)
        recording = true
        onRecordingChange(true)
        let start = Date()
        recordStart = start
        ramp.update(0.14)
        loop = Task { @MainActor in
            var lit = 0
            while !Task.isCancelled && recording {
                let e = Date().timeIntervalSince(start)
                elapsed = e
                ramp.update(VideoShutterRules.reelLevel(elapsed: e))
                let now = VideoShutterRules.litTicks(elapsed: e)
                if now > lit { lit = now; Haptics.play(.tick, gap: 0, intensity: 0.5) }
                if e >= VideoRules.maxDuration { stop(auto: true); return }
                try? await Task.sleep(for: .milliseconds(30))
            }
        }
    }

    private func stop(auto: Bool) {
        guard recording else { return }
        recording = false
        onRecordingChange(false)
        loop?.cancel()
        ramp.stop()
        let took = recordStart.map { Date().timeIntervalSince($0) } ?? 0
        recordStart = nil
        if auto {
            Haptics.play(.thud)
        } else {
            Haptics.play(.click)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) { Haptics.play(.soft) }
        }
        let tooShort = !VideoRules.keeps(duration: took)
        camera.recorder.stopRecording { video in
            DispatchQueue.main.async {
                elapsed = 0
                guard let video, !tooShort else {
                    // 1秒より みじかい:1こま使わない
                    Haptics.play(.warn)
                    show("1秒より みじかいと 撮れません")
                    return
                }
                onRecorded(video)
            }
        }
    }

    private func show(_ text: String) {
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { if toast == text { toast = nil } }
    }
}
