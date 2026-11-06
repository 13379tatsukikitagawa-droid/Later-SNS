import AVFoundation
import AVKit
import SwiftUI

// v20:あしたの朝 9:00 に ひらく → 上映。
// はじめて見るとき:上に 7セグ 8:59 → 9:00(click)→ ミルク色が 1.7秒でとける(連続 0.15 → 0.85)→ heart → 穴が光り 3回チカチカ(tick ×4)→「▶ 上映する」
// 上映:チェキが 1.3倍に ひろがり、まわりが暗くなって再生(ループ)。pop → 0.26秒後に projector → 最初の 0.7秒だけ tick。
// 音は上映のときだけ(消音スイッチに従う .ambient)。小さなスピーカーの印でオフにできる。タップで soft、ちぢんで戻る。

/// はじめて ひらいた動画(端末の中だけ)
enum VideoDevelopSeen {
    private static let key = "video.developSeen.v1"

    static func isSeen(_ id: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: key) ?? []).contains(id)
    }

    static func markSeen(_ id: String) {
        var list = UserDefaults.standard.stringArray(forKey: key) ?? []
        guard !list.contains(id) else { return }
        list.append(id)
        UserDefaults.standard.set(Array(list.suffix(200)), forKey: key)
    }
}

struct VideoProjectionView: View {
    let id: String
    let poster: UIImage?
    let duration: Double
    /// 本体を取る(端末にあればそれ。なければ CloudKit から)
    let loadURL: () async -> URL?
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .developing
    @State private var clockText = "8:59"
    @State private var milk = 1.0
    @State private var glow = 0.0
    @State private var flicker = false
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    @State private var muted = false
    @State private var current = 0.0
    @State private var expanded = false
    @State private var ramp = HapticRamp()
    @State private var timeObserver: Any?
    @State private var loadFailed = false

    enum Phase { case developing, ready, projecting }

    var body: some View {
        ZStack {
            Color.black.opacity(expanded ? 0.86 : 0.7).ignoresSafeArea()
                .onTapGesture { close() }
            VStack(spacing: 22) {
                if phase != .projecting {
                    Text(clockText)
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "FF8A2A"))
                        .shadow(color: Color(hex: "FF8A2A").opacity(0.7), radius: 10)
                        .contentTransition(.numericText())
                } else {
                    Text("▶ \(MilkCheki.durationText(current)) / \(MilkCheki.durationText(duration))")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "FF8A2A"))
                }
                cheki
                    .scaleEffect(expanded ? 1.3 : 1)
                    .opacity(flicker ? 0.55 : 1)
                    .onTapGesture { if phase == .projecting { close() } }
                if phase == .ready {
                    Button(action: project) {
                        Text("▶ 上映する")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 26)
                            .frame(height: 50)
                            .background(Capsule().fill(LinearGradient(colors: [Color(hex: "FF8A2A"), Color(hex: "FF5DA2"), Color(hex: "9A7CFF")], startPoint: .leading, endPoint: .trailing)))
                    }
                    .buttonStyle(SquishButtonStyle(pressedScale: 0.94))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if phase == .projecting {
                    // 下に細い進みの線
                    GeometryReader { proxy in
                        Capsule().fill(.white.opacity(0.15))
                            .overlay(alignment: .leading) {
                                Capsule().fill(Color(hex: "FF8A2A")).frame(width: proxy.size.width * min(1, current / max(0.1, duration)))
                            }
                    }
                    .frame(width: 200, height: 3)
                    .padding(.top, 40)
                }
                if loadFailed {
                    Text("動画を、まだ取れませんでした").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                }
            }
            if phase == .projecting {
                Button {
                    muted.toggle()
                    player?.isMuted = muted
                    Haptics.play(.tick)
                } label: {
                    Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 40, height: 40).background(GlassCapsule())
                }
                .accessibilityLabel(muted ? "音を出す" : "音を消す")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(20)
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.8), value: expanded)
        .animation(.easeOut(duration: 0.3), value: phase)
        .task { await start() }
        .onDisappear { teardown() }
    }

    private var cheki: some View {
        ZStack {
            Color(hex: "F7F4EE")
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    holes
                    ZStack {
                        if phase == .projecting, let player {
                            VideoLayerView(player: player)
                        } else if let poster {
                            Image(uiImage: poster).resizable().scaledToFill()
                                .blur(radius: 10 * milk)
                        } else {
                            Color(hex: "3A3A40")
                        }
                        // ミルク色(とけていく)
                        LinearGradient(colors: [Color(hex: "DDE6E2"), Color(hex: "C9D3E0")], startPoint: .top, endPoint: .bottom)
                            .opacity(0.94 * milk)
                    }
                    .clipped()
                    holes
                }
                .frame(height: 300)
                HStack {
                    Text("MOVIE").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Color(hex: "FF8A2A"))
                    Spacer()
                    Text(RetroStamp.text(for: Date())).font(.custom("Caveat-Bold", size: 20)).foregroundStyle(Color(hex: "FF7A1A"))
                }
                .padding(.top, 10)
            }
            .padding(12)
        }
        .frame(width: 252, height: 354)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: Color(hex: "FF8A2A").opacity(0.5 * glow), radius: 30)
        .shadow(color: .black.opacity(0.5), radius: 20, y: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(phase == .projecting ? "上映中。タップで とじる" : "動画のチェキ")
    }

    private var holes: some View {
        VStack(spacing: 0) {
            ForEach(0..<9, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1).fill(Color(hex: "F7F4EE").opacity(0.85 + 0.15 * glow))
                    .shadow(color: Color(hex: "FFB070").opacity(glow), radius: 4)
                    .frame(width: 5, height: 5).frame(maxHeight: .infinity)
            }
        }
        .frame(width: 9)
        .background(Color(hex: "111111"))
    }

    // MARK: 流れ

    private func start() {
        // 本体は、先に取りはじめる(見るのは上映のとき)
        Task { await prepare() }
        guard !VideoDevelopSeen.isSeen(id) else {
            milk = 0
            phase = .ready
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation { clockText = "9:00" }
            Haptics.play(.click)
            try? await Task.sleep(for: .seconds(0.3))
            // ミルク色が 1.7秒でとける(じわっと強く)
            ramp.start()
            let begin = Date()
            while true {
                let k = min(1, Date().timeIntervalSince(begin) / 1.7)
                milk = 1 - k
                ramp.update(0.15 + 0.7 * k)
                if k >= 1 { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
            ramp.stop()
            Haptics.play(.heart)
            withAnimation(.easeOut(duration: 0.3)) { glow = 1 }
            for i in 0..<4 {
                if i < 3 { flicker = true }
                Haptics.play(.tick, gap: 0)
                try? await Task.sleep(for: .seconds(0.07))
                flicker = false
                try? await Task.sleep(for: .seconds(0.09))
            }
            VideoDevelopSeen.markSeen(id)
            withAnimation(.easeOut(duration: 0.5)) { glow = 0.4 }
            phase = .ready
        }
    }

    private func prepare() async {
        guard player == nil, let url = await loadURL() else {
            if player == nil { loadFailed = true }
            return
        }
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer()
        looper = AVPlayerLooper(player: queue, templateItem: item)
        queue.isMuted = muted
        player = queue
    }

    private func project() {
        guard let player else {
            Haptics.play(.warn)
            return
        }
        // 音は上映のときだけ(消音スイッチに従う)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        phase = .projecting
        Haptics.play(.pop)
        expanded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { Haptics.play(.projector) }
        for i in 0..<4 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.12) { Haptics.play(.tick, gap: 0) } }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 10), queue: .main) { time in
            MainActor.assumeIsolated { current = CMTimeGetSeconds(time).truncatingRemainder(dividingBy: max(0.1, duration)) }
        }
        player.play()
    }

    private func close() {
        Haptics.play(.soft)
        expanded = false
        teardown()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onClose() }
    }

    private func teardown() {
        ramp.stop()
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        timeObserver = nil
        player?.pause()
    }
}

/// AVPlayer の絵(コントロールなし)
struct VideoLayerView: UIViewRepresentable {
    let player: AVPlayer

    final class Host: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> Host {
        let view = Host()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: Host, context: Context) {
        if uiView.playerLayer.player !== player { uiView.playerLayer.player = player }
    }
}
