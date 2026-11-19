import AVFoundation
import SwiftUI

// v21 A:撮影画面(見本:Docs/Mocks/later_v21.html の 撮影。390×844 の座標。縦は画面の高さの比)。
// 窓(左右16・上112・高さ500・角30)・まわりは黒(.8)・四隅の L字・窓の中の左上「LIVE ・ ISO 400」(158pt)・
// 上のまん中「写真 / 動画」(122pt)・上のバー(もどる・Later today・7セグの のこり + のこり EXP)・
// 市区町村 + タグのカプセル・左にフラッシュ・まん中にシャッター(ガラスのリング 104・白い芯・24の目もり)・右に今日のチェキの山・
// ヒント・左のふち「VOL 長押し」(押している間、下から光でたまる)。
// 撮影中も ファインダーは ふつうの映像(動画でも加工しない。レトロは書き出しの1回だけ:C)。

struct CaptureScreenV21: View {
    @ObservedObject var camera: CaptureCameraModel
    let layout: CaptureLayout
    let tags: [String]
    let place: String?
    let left: Int
    /// v22 L-4:今日の 1曲(ピルに「♪ 曲名」を 1つだけ・短く)
    var musicTitle: String? = nil
    var playsEntrance = false
    @Binding var mode: CaptureMode
    let onBack: () -> Void
    let onEditTags: () -> Void
    /// 写真が撮れた(長押し 1.5秒・音量ボタン長押し・VoiceOver)
    let onPhoto: (ShutterSource) -> Void
    /// 動画を とめた(1秒以上のこった)
    let onRecorded: (RecordedVideo) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("capture.flashAuto") private var flashAuto = true
    @AppStorage("video.micAsked") private var micAsked = false
    @State private var gesture = ShutterGesture()
    @State private var appeared = false
    @State private var switchGlow = 0.0
    @State private var hintOverride: String?
    @State private var toast: String?
    @State private var hasAudio = false
    @State private var countFlick = 0
    @State private var snapRing = false
    @State private var pressedScreen = false
    @State private var flipRot = 0.0
    @State private var flipIcon = 0.0
    @State private var flipBlur = 0.0
    @State private var screenFlash = false
    private var front: Bool { camera.cameraPosition == .front }

    private var ky: CGFloat { layout.ky }
    private var win: CGRect { layout.finder }
    private var shots: Int { max(0, FilmRoll.shotsPerDay - left) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: "050506")
            // ふつうの映像(画面いっぱい。窓のまわりは黒 .8)
            CaptureCameraPreview(
                session: camera.session,
                volumeEnabled: camera.status == .ready,
                onVolumePress: { HintCenter.shared.touched(.shoot); gesture.press(.volume) },
                onVolumeRelease: { gesture.release(.volume) }
            )
            .opacity(camera.status == .ready ? 1 : 0)
            .scaleEffect(reduceMotion ? 1 : 1 + 0.045 * photoEase, anchor: UnitPoint(x: 0.5, y: 0.42))
            .brightness(switchGlow)
            .rotation3DEffect(.degrees(flipRot), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .scaleEffect(1 - 0.1 * abs(flipRot) / 86)
            .blur(radius: flipBlur)
            .onTapGesture(count: 2) { flipCamera() }
            windowMask
            if screenFlash { Color.white.ignoresSafeArea().allowsHitTesting(false).transition(.opacity) }
            corners
            windowLabels
            topBar
            modeOrRecording
            stamp
            volumeEdge
            tagRow
            sideButtons
            shutter
            hint
            if let toast {
                Text(toast)
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(GlassCapsule())
                    .position(x: layout.size.width / 2, y: layout.y(60) + 20)
                    .transition(.opacity)
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .ignoresSafeArea()
        .statusBarHidden()
        .animation(.easeOut(duration: 0.3), value: toast)
        .onAppear(perform: appear)
        .onDisappear { gesture.interrupt(); camera.recorder.setActive(false) }
        .onChange(of: scenePhase) { _, phase in if phase != .active { gesture.interrupt() } }
        .onChange(of: mode) { _, m in gesture.mode = m; camera.setVideoLook(m == .video) }   // v107:動画モードの 間だけ HDR オフ ・ sRGB ・ 手ぶれ補正 .standard
        .onChange(of: left) { _, _ in countFlick += 1 }
        .onChange(of: gesture.releasedEarlyToken) { _, _ in
            hintOverride = "もうすこし、長く"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { hintOverride = nil }
        }
        .onChange(of: gesture.snapToken) { _, _ in
            snapRing = true
            if front { fireScreenFlash() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { snapRing = false }
        }
        // ファインダーを よこになぞって切りかえ(左へ = 動画)
        .simultaneousGesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                guard win.contains(value.startLocation), !gesture.isBusy,
                      let next = VideoShutterRules.swipe(dx: value.translation.width, dy: value.translation.height) else { return }
                switchMode(next)
            }
        )
    }

    // MARK: 窓

    /// カメラを うらがえす(0.44秒):横に 86°(0.19秒)→ 入れかえ → もどる(0.25秒)。動画の 間は 切りかえない。外カメは ひらく たびに もどる(ExposureCameraView)
    private func flipCamera() {
        guard !gesture.isRecording else { return }
        Haptics.play(.sel)
        let next: AVCaptureDevice.Position = front ? .back : .front
        if reduceMotion { camera.setCameraPosition(next); Haptics.play(.tick); return }
        withAnimation(.easeIn(duration: 0.19)) { flipRot = 86; flipBlur = 8; switchGlow = -0.3 }
        withAnimation(.easeInOut(duration: 0.44)) { flipIcon += 180 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.19) {
            camera.setCameraPosition(next)
            Haptics.play(.tick)
            flipRot = -86
            withAnimation(.easeOut(duration: 0.25)) { flipRot = 0; flipBlur = 0; switchGlow = 0 }
        }
    }

    /// インカメの フラッシュ = 画面を 白く(0.25秒 ・ 明るさ 最大 → もどす)
    private func fireScreenFlash() {
        let old = UIScreen.main.brightness
        UIScreen.main.brightness = 1
        withAnimation(.easeOut(duration: 0.05)) { screenFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { withAnimation(.easeOut(duration: 0.2)) { screenFlash = false }; UIScreen.main.brightness = old }
    }

    private var windowMask: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        return Rectangle()
            .fill(Color(red: 5 / 255, green: 5 / 255, blue: 7 / 255).opacity(gesture.isBusy && mode == .photo ? 0.9 : 0.8))
            .reverseMask { shape.frame(width: win.width, height: win.height).position(x: win.midX, y: win.midY) }
            .overlay {
                shape.strokeBorder(.white.opacity(0.16), lineWidth: 1)
                    .frame(width: win.width, height: win.height)
                    .position(x: win.midX, y: win.midY)
            }
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.3), value: gesture.isBusy)
    }

    /// 四隅の L字(30×30・2pt・角10)。写真の長押しで 8pt 寄る
    private var corners: some View {
        let inset = 14 + 8 * CGFloat(photoEase)
        return ZStack(alignment: .topLeading) {
            ForEach(0..<4, id: \.self) { i in
                CornerL(corner: i)
                    .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 30, height: 30)
                    .position(
                        x: i % 2 == 0 ? win.minX + inset + 15 : win.maxX - inset - 15,
                        y: i < 2 ? win.minY + inset + 15 : win.maxY - inset - 15
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private var windowLabels: some View {
        HStack(spacing: 6) {
            Circle().fill(mode == .video ? Color(hex: "FFB27A") : Color(hex: "FF4F3A")).frame(width: 6, height: 6)
            Text(mode == .video ? "LIVE ・ 30fps" : "LIVE ・ ISO 400")
                .font(.system(size: 9.5, design: .monospaced)).tracking(0.2 * 9.5)
                .foregroundStyle(.white.opacity(0.7))
        }
        .fixedSize()
        .position(x: 38 + 50, y: max(win.minY + 40, layout.y(158)) + 6)
        .opacity(appearOpacity)
        .allowsHitTesting(false)
    }

    // MARK: 上

    private var topBar: some View {
        HStack {
            Button {
                Haptics.play(.tick)
                onBack()
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 46, height: 46).background(GlassCapsule())
            }
            .buttonStyle(SquishButtonStyle(pressedScale: 0.88))
            .accessibilityLabel("もどる")
            Spacer()
            HStack(alignment: .top, spacing: -2) {
                Text("Lattag").font(.system(size: 22, weight: .black)).tracking(-0.05 * 22).foregroundStyle(.white)
            }
            Spacer()
            // のこりの 7セグ(薄い 8 が下に見える)+「のこり / EXP」
            HStack(spacing: 8) {
                ZStack {
                    SevenSegmentText(text: "8", height: 26, color: Color(hex: "1A2010"))
                    SevenSegmentText(text: "\(max(0, left))", height: 26, color: Color(hex: "C8F25A"))
                        .shadow(color: Color(hex: "C8F25A").opacity(0.75), radius: 5)
                        .keyframeAnimator(initialValue: 1.0, trigger: countFlick) { content, o in content.opacity(o) } keyframes: { _ in
                            KeyframeTrack { LinearKeyframe(0.2, duration: 0.08); LinearKeyframe(1, duration: 0.08); LinearKeyframe(0.3, duration: 0.08); LinearKeyframe(1, duration: 0.08) }
                        }
                }
                .frame(width: 18, height: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text("のこり").font(.system(size: 8, design: .monospaced)).tracking(0.14 * 8).foregroundStyle(Color(hex: "7A7A82"))
                    Text("EXP").font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(0.14 * 8).foregroundStyle(Color(hex: "C8F25A"))
                }
            }
            .padding(.leading, 10).padding(.trailing, 12)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "0B0B0D")).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.14), lineWidth: 1)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("のこり \(max(0, left))こま")
        }
        .padding(.horizontal, 20)
        .frame(width: layout.size.width, height: 46)
        .position(x: layout.size.width / 2, y: layout.topBarCenterY)
        .opacity(appearOpacity)
    }

    @ViewBuilder
    private var modeOrRecording: some View {
        let y = max(win.minY + 10, layout.y(122)) + 15
        if gesture.isRecording {
            HStack(spacing: 7) {
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    Circle().fill(Color(hex: "FF3B30")).frame(width: 8, height: 8)
                        .shadow(color: Color(hex: "FF3B30"), radius: 5)
                        .opacity(Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0 ? 1 : 0.25)
                }
                Text(String(format: "%02d:%02d", Int(gesture.elapsed) / 60, Int(gesture.elapsed) % 60))
                    .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                Text("/ 10").font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
            }
            .frame(width: 124, height: 30)
            .background(Capsule().fill(Color(red: 18 / 255, green: 18 / 255, blue: 22 / 255).opacity(0.55)).overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1)))
            .position(x: layout.size.width / 2, y: y)
            .transition(.opacity.combined(with: .scale(scale: 0.94)))
        } else {
            CaptureModeSwitch(mode: mode) { switchMode($0) }
                .position(x: layout.size.width / 2, y: y)
                .opacity(appearOpacity)
                .transition(.opacity)
        }
    }

    private var stamp: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Text(Self.stampText(context.date))
                .font(.system(size: 14, weight: .bold, design: .monospaced)).tracking(0.06 * 14)
                .foregroundStyle(Color(hex: "C8F25A"))
                .shadow(color: Color(red: 1, green: 0.47, blue: 0.16).opacity(0.7), radius: 5)
        }
        .fixedSize()
        .position(x: win.maxX - 22 - 70, y: win.maxY - 38 + 9)
        .opacity(appearOpacity)
        .allowsHitTesting(false)
    }

    /// 「'26 11 05  20:43」
    static func stampText(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(format: "'%02d %02d %02d  %02d:%02d", (c.year ?? 2026) % 100, c.month ?? 1, c.day ?? 1, c.hour ?? 0, c.minute ?? 0)
    }

    // MARK: 左のふち(音量ボタン)

    private var volumeEdge: some View {
        let holdingVolume = gesture.source == .volume
        let fill: Double = {
            guard holdingVolume else { return 0 }
            switch gesture.phase {
            case .holding: return gesture.progress
            case .charging: return gesture.progress
            case .recording: return 1
            case .idle: return 0
            }
        }()
        let top = layout.y(150), length = layout.y(250)
        return ZStack(alignment: .topLeading) {
            TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion || holdingVolume)) { context in
                let breath = reduceMotion || holdingVolume ? 1 : 0.35 + 0.65 * (0.5 + 0.5 * cos(context.date.timeIntervalSinceReferenceDate * 2 * .pi / 2.8))
                ZStack(alignment: .bottom) {
                    UnevenRoundedRectangle(bottomTrailingRadius: holdingVolume ? 5 : 3, topTrailingRadius: holdingVolume ? 5 : 3)
                        .fill(LinearGradient(stops: [
                            .init(color: .clear, location: 0), .init(color: Color(red: 1, green: 0.67, blue: 0.43).opacity(0.9), location: 0.3),
                            .init(color: Color(red: 1, green: 0.47, blue: 0.63).opacity(0.9), location: 0.7), .init(color: .clear, location: 1),
                        ], startPoint: .top, endPoint: .bottom))
                    UnevenRoundedRectangle(bottomTrailingRadius: 5, topTrailingRadius: 5)
                        .fill(LinearGradient(colors: [Color(hex: "FFD08A"), Color(hex: "FF7A4A")], startPoint: .bottom, endPoint: .top))
                        .frame(height: length * fill)
                }
                .frame(width: holdingVolume ? 9 : 4, height: length)
                .shadow(color: Color(red: 1, green: 0.55, blue: 0.35).opacity(holdingVolume ? 0.9 : 0.7), radius: holdingVolume ? 17 : 9)
                .opacity(breath)
            }
            .padding(.top, top)
            Text("VOL 長押し")
                .font(.system(size: 8, design: .monospaced)).tracking(0.2 * 8)
                .foregroundStyle(Color(red: 1, green: 0.75, blue: 0.59).opacity(0.55))
                .fixedSize()
                .rotationEffect(.degrees(-90))
                .frame(width: 10, height: 70)
                .padding(.leading, 9)
                .padding(.top, layout.y(258))
        }
        .animation(.easeOut(duration: 0.12), value: holdingVolume)
        .opacity(appearOpacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: 下

    private var tagRow: some View {
        let shown = Array(tags.prefix(2))
        return HStack(spacing: 7) {
            if let place, !place.isEmpty {
                chip(icon: "mappin", text: place, tint: Color(hex: "FFD2B0"))
            }
            ForEach(shown, id: \.self) { tag in chip(icon: nil, text: "#\(tag)", tint: .white) }
            if tags.isEmpty { chip(icon: nil, text: "#タグなし", tint: .white.opacity(0.7)) }
            if tags.count > 2 { chip(icon: nil, text: "+\(tags.count - 2)", tint: .white) }
            if let musicTitle { chip(icon: "music.note", text: musicTitle, tint: .white) }
        }
        .frame(width: layout.size.width - 32)
        .position(x: layout.size.width / 2, y: win.maxY + layout.y(14) + 16)
        .opacity(appearOpacity)
    }

    private func chip(icon: String?, text: String, tint: Color) -> some View {
        Button {
            Haptics.play(.tick)
            onEditTags()
        } label: {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 11, weight: .bold)) }
                Text(text).font(.system(size: 13, weight: .bold)).lineLimit(1)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 13)
            .frame(height: 32)
            .background(GlassCapsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("タグを なおす")
    }

    private var sideButtons: some View {
        let y = layout.shutterCenter.y
        return ZStack(alignment: .topLeading) {
            // 左:フラッシュ(AUTO / OFF)
            Button {
                flashAuto.toggle()
                Haptics.play(.click)
            } label: {
                VStack(spacing: 5) {
                    Image(systemName: flashAuto ? "bolt.fill" : "bolt.slash")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(flashAuto ? Color(hex: "C8F25A") : .white)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(flashAuto ? Color(hex: "C8F25A").opacity(0.16) : .white.opacity(0.08)))
                        .overlay(Circle().strokeBorder(flashAuto ? Color(hex: "C8F25A").opacity(0.55) : .white.opacity(0.12), lineWidth: 1))
                    Text(front ? "SCREEN" : (flashAuto ? "AUTO" : "OFF")).font(.system(size: 8.5, design: .monospaced)).tracking(0.14 * 8.5).foregroundStyle(Color(hex: "8E8E95"))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("フラッシュ、\(flashAuto ? "オート" : "オフ")")
            .position(x: 52 + 29, y: y)
            // 右:カメラ切りかえ(BACK / FRONT)。0 / 3 は 消した(のこり枚数は 右上)
            Button { flipCamera() } label: {
                VStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath.camera").font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(front ? Color(hex: "C8F25A") : .white)
                        .rotationEffect(.degrees(flipIcon)).frame(width: 50, height: 50)
                        .background(Circle().fill(front ? Color(hex: "C8F25A").opacity(0.16) : .white.opacity(0.08)))
                        .overlay(Circle().strokeBorder(front ? Color(hex: "C8F25A").opacity(0.55) : .white.opacity(0.12), lineWidth: 1))
                    Text(front ? "FRONT" : "BACK").font(.system(size: 8.5, design: .monospaced)).tracking(0.14 * 8.5).foregroundStyle(Color(hex: "8E8E95"))
                }
            }
            .buttonStyle(.plain)
            .disabled(gesture.isRecording)
            .accessibilityLabel("カメラを きりかえる。いま \(front ? "インカメ" : "外カメ")")
            .position(x: layout.size.width - 52 - 29, y: y)
        }
        .opacity(appearOpacity)
    }

    // MARK: シャッター

    private var photoEase: Double {
        guard case .holding = gesture.phase else { return 0 }
        let k = gesture.progress
        return k * k * (3 - 2 * k)
    }

    private var shutter: some View {
        let video = mode == .video
        let recording = gesture.isRecording
        let late = recording && VideoShutterRules.isWarning(elapsed: gesture.elapsed)
        let ringProgress: Double = recording ? min(1, gesture.elapsed / VideoRules.maxDuration) : (video ? 0.06 * gesture.progress : gesture.progress)
        let e = photoEase
        let dead = left <= 0 && !recording
        return ZStack {
            // 後ろの朝焼けの光
            Circle()
                .fill(RadialGradient(colors: video
                    ? [Color(red: 1, green: 0.43, blue: 0.31).opacity(0.55), Color(red: 1, green: 0.27, blue: 0.43).opacity(0.25), .clear]
                    : [Color(red: 1, green: 0.63, blue: 0.39).opacity(0.62), Color(red: 1, green: 0.43, blue: 0.63).opacity(0.28), .clear],
                    center: .center, startRadius: 0, endRadius: 125))
                .frame(width: 250, height: 250)
                .scaleEffect(0.5 + 0.8 * max(e, recording ? 0.6 : 0))
                .opacity(max(e * 0.95, recording ? 0.6 : 0))
                .allowsHitTesting(false)
            ZStack {
                ShutterIconV94(progress: video ? 0.06 * gesture.progress : gesture.progress, holding: gesture.phase != .idle && !recording, video: video, recording: recording, dead: dead, late: late, snapToken: gesture.snapToken, recordingProgress: ringProgress)
                // のこりの3つの点(アイコンの 上)
                ForEach(0..<3, id: \.self) { i in
                    let on = i < left
                    Circle().fill(on ? Color(hex: "C8F25A") : Color(hex: "4A4A52"))
                        .frame(width: on ? 6.8 : 4.8, height: on ? 6.8 : 4.8)
                        .offset(y: -56)
                        .rotationEffect(.degrees(Double(i - 1) * 14))
                }
                // 光の輪が1つ はじける
                Circle().strokeBorder(Color(hex: "C8F25A"), lineWidth: 2)
                    .frame(width: 112, height: 112)
                    .scaleEffect(snapRing ? 2.4 : 0.6)
                    .opacity(snapRing ? 0 : 0)
                    .animation(snapRing ? .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.52) : nil, value: snapRing)
            }
            .frame(width: 104, height: 104)
            // はじめての 合図(shoot):「押しつづける」見本
            .overlay { if HintCenter.shared.active == .shoot && gesture.phase == .idle { ShutterHintDemo() } }
            .firstHint(.shoot, eligible: (appeared || !playsEntrance) && left > 0, edge: .top, shape: .circle, onDark: true, gap: 22)
            .scaleEffect(reduceMotion ? 1 : (gesture.phase == .idle ? 1 : (video ? 1 : 0.95 + 0.09 * e)))
            .animation(.spring(response: 0.38, dampingFraction: 0.6), value: recording)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !pressedScreen { pressedScreen = true; HintCenter.shared.touched(.shoot); gesture.press(.screen) } }
                    .onEnded { _ in pressedScreen = false; gesture.release(.screen) }
            )
            .accessibilityElement()
            .accessibilityLabel(video ? (recording ? "録画をとめる" : "録画をはじめる") : "撮る")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { gesture.accessibilityActivate() }
        }
        .position(layout.shutterCenter)
        .opacity(appeared || !playsEntrance ? 1 : 0)
    }

    /// 最後の 45% は、芯が小きざみに ふるえる(最大 ±1.5pt)
    private var jitter: CGSize {
        guard !reduceMotion, case .holding = gesture.phase, gesture.progress > 0.55 else { return .zero }
        let t = (gesture.progress - 0.55) * 3.4
        return CGSize(width: Double.random(in: -0.5...0.5) * t, height: Double.random(in: -0.5...0.5) * t)
    }

    private var hint: some View {
        let text: String = {
            if let hintOverride { return hintOverride }
            if gesture.isRecording { return VideoShutterRules.isWarning(elapsed: gesture.elapsed) ? "もうすぐ 10びょう" : "はなすと とまる" }
            if case .holding = gesture.phase { return ShutterRules.photoHint(stage: gesture.lit / 8) }
            if case .charging = gesture.phase { return "○ ○ ○  そのまま" }
            return ShutterRules.idleHint(mode: mode, left: left)
        }()
        return Text(text)
            .font(.system(size: 9.5, design: .monospaced)).tracking(0.18 * 9.5)
            .foregroundStyle(hintOverride != nil ? Color(hex: "C8F25A") : Color(hex: "6A6A72"))
            .multilineTextAlignment(.center)
            .frame(width: layout.size.width - 20)
            .position(x: layout.size.width / 2, y: min(layout.size.height - max(layout.safeBottom, 12) - 8, layout.y(792) + 6))
            // 合図の 見本の 間は、下の 小さな 説明文を かくす
            .opacity(HintCenter.shared.active == .shoot ? 0 : appearOpacity)
            .animation(.easeOut(duration: 0.2), value: text)
    }

    private var appearOpacity: Double { appeared || !playsEntrance ? 1 : 0 }

    // MARK: 動き

    private func appear() {
        gesture.mode = mode
        // のこりは FilmCounter を、そのつど見る(この関数の中の left は古くなる)
        gesture.canStart = { camera.status == .ready && !camera.isCapturing && FilmCounter.shared.remaining > 0 }
        gesture.onRefused = {
            if FilmCounter.shared.remaining <= 0 { show("今日は、ここまで") }
        }
        gesture.onPhoto = { source in onPhoto(source) }
        gesture.onStartRecording = {
            camera.recorder.setActive(true)
            // 準備は メインの外。最初の コマが 書けた(録画が 実際に はじまった)瞬間に「ピッ」:rigid → 0.08秒後に soft
            camera.recorder.startRecordingAsync(audio: hasAudio) {
                Haptics.pulse(intensity: 1, sharpness: 0.9)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { Haptics.play(.soft, gap: 0) }
            }
        }
        gesture.onStopRecording = { took, _ in
            let tooShort = !VideoRules.keeps(duration: took)
            camera.recorder.stopRecordingAsync { video in
                DispatchQueue.main.async {
                    camera.recorder.setActive(false)
                    // 録画が 止まった あとに 鳴らす(動画の 音に 振動の 音が 入らないように)
                    guard let video, !tooShort else {
                        Haptics.play(.warn)   // みじかすぎ:やわらかく 2回
                        show("1秒より みじかいと 撮れません")
                        return
                    }
                    Haptics.play(.success)   // おわった:やさしく
                    onRecorded(video)
                }
            }
        }
        if mode == .video { prepareAudio() }
        camera.setVideoLook(mode == .video)
        if playsEntrance && !reduceMotion {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) { withAnimation(.easeOut(duration: 0.45)) { appeared = true } }
        } else {
            appeared = true
        }
    }

    private func switchMode(_ next: CaptureMode) {
        guard next != mode, !gesture.isBusy else { return }
        Haptics.play(.detent)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { Haptics.play(.tick, gap: 0) }
        // ごく軽く明るくなるだけ(0.24秒)
        switchGlow = 0.12
        withAnimation(.easeOut(duration: 0.24)) { switchGlow = 0 }
        mode = next
        if next == .video { prepareAudio() }
    }

    private func prepareAudio() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined && !micAsked {
            micAsked = true
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if granted { camera.enableAudio { ok in DispatchQueue.main.async { hasAudio = ok } } } else { show("音なし") }
                }
            }
        } else if status == .authorized {
            camera.enableAudio { ok in DispatchQueue.main.async { hasAudio = ok } }
        }
    }

    private func show(_ text: String) {
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { if toast == text { toast = nil } }
    }
}

/// シャッターの目もり 24本(8本ごとに太い)
private struct ShutterTicks: View {
    let lit: Int
    let video: Bool
    let late: Bool

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            for i in 0..<ShutterRules.ticks {
                let a = (-90 + Double(i) * 360 / Double(ShutterRules.ticks)) * .pi / 180
                let big = i % 8 == 0
                let r1: Double = big ? 55 : 56, r2: Double = big ? 62 : 59.5
                var p = Path()
                p.move(to: CGPoint(x: c.x + r1 * cos(a), y: c.y + r1 * sin(a)))
                p.addLine(to: CGPoint(x: c.x + r2 * cos(a), y: c.y + r2 * sin(a)))
                let on = i < lit
                let color: Color = on
                    ? (late ? Color(hex: "FF3B30") : (video ? (big ? Color(hex: "FFC2A8") : Color(hex: "FF7A5A")) : (big ? Color(hex: "E2FF9A") : Color(hex: "C8F25A"))))
                    : .white.opacity(big ? 0.42 : 0.2)
                ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: big ? 2.6 : 1.6, lineCap: .round))
            }
        }
        .frame(width: 130, height: 130)
        .allowsHitTesting(false)
    }
}

/// 四隅の L字(0 左上・1 右上・2 左下・3 右下)
private struct CornerL: Shape {
    let corner: Int

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = 10
        switch corner {
        case 0:
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
            p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case 1:
            p.move(to: CGPoint(x: rect.minX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case 2:
            p.move(to: CGPoint(x: rect.minX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
            p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.maxY), control: CGPoint(x: rect.minX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        default:
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        return p
    }
}

extension View {
    /// 形の所だけ くりぬく
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            Rectangle().overlay { mask().blendMode(.destinationOut) }.compositingGroup()
        }
    }
}
