import AVFoundation
import PhotosUI
import SwiftUI
import UIKit
import Vision

// MARK: - カメラ(読みとり・追いかけ・灯り・暗さ)

/// QRの読みとり。読みとりは画面全体(窓は目印)。QRの外形を画面の座標で返し、角かっこが吸いつく。
/// VisionKit の DataScannerViewController は、灯り(トーチ)と「暗い」の判定に必要な
/// カメラの情報を扱えないため、AVCaptureSession で作る(近いQRは、超広角への自動切りかえで読む)。
@MainActor
@Observable
final class QRScanCamera: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    enum Access { case unknown, authorized, denied, unavailable }

    @ObservationIgnored let session = AVCaptureSession()
    @ObservationIgnored weak var previewLayer: AVCaptureVideoPreviewLayer?
    @ObservationIgnored private var device: AVCaptureDevice?
    @ObservationIgnored private var monitor: Task<Void, Never>?
    @ObservationIgnored private var lastSeen: Date?

    private(set) var access: Access = .unknown
    /// いま映っているQRの中身・画面の座標での外形・見えはじめた時刻
    private(set) var code: String?
    private(set) var codeRect: CGRect?
    private(set) var codeSince: Date?
    /// 露出が上がりきっても暗い
    private(set) var isDark = false
    private(set) var isTorchOn = false
    var hasTorch: Bool { device?.hasTorch ?? false }
    /// ロックしたあとは、QRを追わない
    var isPaused = false

    func start() async {
        var status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            status = await AVCaptureDevice.requestAccess(for: .video) ? .authorized : .denied
        }
        guard status == .authorized else {
            access = .denied
            return
        }
        if session.inputs.isEmpty {
            guard let device = Self.bestDevice(), let input = try? AVCaptureDeviceInput(device: device) else {
                access = .unavailable
                return
            }
            self.device = device
            let output = AVCaptureMetadataOutput()
            session.beginConfiguration()
            if session.canAddInput(input) { session.addInput(input) }
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: .main)
                output.metadataObjectTypes = [.qr]
            }
            session.commitConfiguration()
            configure(device)
        }
        access = .authorized
        let session = self.session
        Task.detached { if !session.isRunning { session.startRunning() } }
        startMonitor()
    }

    func stop() {
        setTorch(false)
        monitor?.cancel()
        monitor = nil
        let session = self.session
        Task.detached { session.stopRunning() }
    }

    func setTorch(_ on: Bool) {
        guard let device, device.hasTorch, (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
        isTorchOn = on
    }

    /// 近いものにピントが合うカメラ(超広角を含む仮想カメラ)を優先
    private static func bestDevice() -> AVCaptureDevice? {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        ).devices.first
    }

    private func configure(_ device: AVCaptureDevice) {
        guard (try? device.lockForConfiguration()) != nil else { return }
        // 仮想カメラ:ふつうの画角(広角)から始める。近いQRでは、自動で超広角(マクロ)に切りかわる
        if let wide = device.virtualDeviceSwitchOverVideoZoomFactors.first {
            device.videoZoomFactor = CGFloat(truncating: wide)
        }
        if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
        device.unlockForConfiguration()
    }

    /// 見えなくなったQRを外す(0.3秒)・暗さを確かめる(0.5秒ごと)
    private func startMonitor() {
        monitor?.cancel()
        monitor = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { return }
                if let lastSeen = self.lastSeen, Date().timeIntervalSince(lastSeen) > 0.3, !self.isPaused {
                    self.code = nil
                    self.codeRect = nil
                    self.codeSince = nil
                    self.lastSeen = nil
                }
                tick += 1
                if tick % 5 == 0, let device = self.device {
                    let maxISO = device.activeFormat.maxISO
                    let dark = !self.isTorchOn && device.iso >= maxISO * 0.9 && device.exposureTargetOffset < -0.5
                    if dark != self.isDark { self.isDark = dark }
                }
            }
        }
    }

    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        MainActor.assumeIsolated {
            guard !isPaused, let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let value = object.stringValue else { return }
            let now = Date()
            if value != code {
                code = value
                codeSince = now
            }
            codeRect = previewLayer?.transformedMetadataObject(for: object)?.bounds
            lastSeen = now
        }
    }

    /// 写真の中のQRを読む(写真ライブラリの権限は要らない:PhotosPicker で渡されたデータだけ)
    nonisolated static func detectQR(in data: Data) async -> String? {
        await Task.detached {
            guard let image = UIImage(data: data)?.cgImage else { return nil }
            let request = VNDetectBarcodesRequest()
            request.symbologies = [.qr]
            try? VNImageRequestHandler(cgImage: image).perform([request])
            return request.results?.compactMap(\.payloadStringValue).first
        }.value
    }
}

/// カメラの絵(画面いっぱい)
struct QRCameraPreview: UIViewRepresentable {
    let camera: QRScanCamera

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = camera.session
        view.previewLayer.videoGravity = .resizeAspectFill
        camera.previewLayer = view.previewLayer
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

// MARK: - QRを読む画面

/// QRを読む画面(5-2 の置きかえ)。上に切りかえはなく、下のドックに 灯り / 写真から / 合言葉。
/// 読みとれたら、窓が丸になって、招待を受ける画面の円(同じ264pt)の位置へ動いてつながる。
struct QRScanView: View {
    let haptics: ExposureHaptics
    /// はじめから合言葉のシートを出す
    let startsWithPassphrase: Bool
    /// 招待の中身を取りに行く(ロックしてから。グループ名は、ロックするまで見せない)
    let prepare: (URL) async -> Result<PreparedInvitation, GroupJoinService.Failure>
    /// 招待を受ける画面 / エラー画面へ
    let onResolved: (Result<PreparedInvitation, GroupJoinService.Failure>) -> Void
    let onClose: () -> Void

    static let windowSide: CGFloat = 264
    static let orange = Color(hex: "FFB26E")

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var camera = QRScanCamera()
    @State private var lockStart: Date?
    @State private var prepared: Result<PreparedInvitation, GroupJoinService.Failure>?
    @State private var preparedAt: Date?
    @State private var resolved = false
    /// Later の招待ではないQR:外れるまで(または2.5秒)、いちど無視する
    @State private var ignoredCode: String?
    @State private var notice: String?
    @State private var noticeTask: Task<Void, Never>?
    @State private var showingPassphrase = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photoImage: UIImage?
    @State private var hasClipboardURL = false
    @State private var showingPhotoPickerFromDenied = false

    var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            let safeBottom = proxy.safeAreaInsets.bottom
            let size = CGSize(width: proxy.size.width, height: proxy.size.height + safeTop + safeBottom)
            let layout = Layout(size: size, safeTop: safeTop, safeBottom: safeBottom)
            TimelineView(.animation(paused: camera.access != .authorized)) { context in
                let tau = lockStart.map { context.date.timeIntervalSince($0) }
                ZStack {
                    if camera.access == .denied || camera.access == .unavailable {
                        deniedView(layout: layout)
                    } else {
                        scanStage(layout: layout, tau: tau, now: context.date)
                    }
                }
                .frame(width: size.width, height: size.height)
                .onChange(of: context.date) { _, date in tick(date) }
            }
            .ignoresSafeArea()
            .sheet(isPresented: $showingPassphrase) {
                PassphraseEntryView(haptics: haptics) { url in
                    showingPassphrase = false
                    // 「見つかった」の強い1回は、合言葉の画面で鳴らしている
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { lock(url, haptic: false) }
                }
                .presentationDetents([.height(max(320, size.height - 196))])
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(36)
                .presentationDragIndicator(.visible)
                .environment(\.colorScheme, .dark)
            }
        }
        .background(Color.black)
        .task {
            await camera.start()
            if startsWithPassphrase { showingPassphrase = true }
            try? await Task.sleep(for: .seconds(0.5))
            await checkClipboard()
        }
        .onDisappear { camera.stop() }
        .onChange(of: scenePhase) { _, phase in
            // 設定でカメラを許可してもどってきた:そのまま読みとりを始める
            if phase == .active, camera.access == .denied, AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
                Task { await camera.start() }
            }
            if phase == .active, lockStart == nil { Task { await checkClipboard() } }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await readPhoto(item) }
        }
    }

    // MARK: 位置

    struct Layout {
        let size: CGSize
        let safeTop: CGFloat
        let safeBottom: CGFloat

        var headingTop: CGFloat { safeTop + 58 }
        /// 窓の中心(見出しにかからない範囲で、画面のまん中より少し上)
        var windowCenter: CGPoint {
            CGPoint(x: size.width / 2, y: max(safeTop + 150 + QRScanView.windowSide / 2, size.height * 0.46))
        }
        /// 招待を受ける画面の円の中心(×の行44 + INVITATION 約14 + 間14 + 半径132)
        var invitationCenter: CGPoint {
            CGPoint(x: size.width / 2, y: safeTop + 44 + 2 + 12 + 14 + QRScanView.windowSide / 2)
        }
        var dockY: CGFloat { size.height - max(safeBottom, 16) - 14 - 34 }
    }

    // MARK: 読みとりの舞台

    @ViewBuilder
    private func scanStage(layout: Layout, tau: Double?, now: Date) -> some View {
        let m = Morph(tau: tau, reduceMotion: reduceMotion || voiceOverEnabled)
        let window = layout.windowCenter
        let side = Self.windowSide
        let circleCenter = CGPoint(
            x: window.x,
            y: window.y + (layout.invitationCenter.y - window.y) * m.move
        )

        // カメラ(写真から読んだときは、窓の中にその写真)
        QRCameraPreview(camera: camera)
            .accessibilityHidden(true)
        if let photoImage {
            Image(uiImage: photoImage)
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: m.cornerRadius, style: .continuous))
                .position(window)
        }

        // まわりは、ぼかして暗く(黒58%+ぼかし)。窓の中だけ、カメラの絵がそのまま
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(Color.black.opacity(0.58))
            .mask(
                Rectangle()
                    .overlay(
                        RoundedRectangle(cornerRadius: m.cornerRadius, style: .continuous)
                            .frame(width: side, height: side)
                            .position(window)
                            .blendMode(.destinationOut)
                    )
                    .compositingGroup()
            )
            .allowsHitTesting(false)

        // 合言葉のシートの間は、後ろのカメラを、さらに暗く(78%)
        Color.black.opacity(showingPassphrase ? 0.78 : 0)
            .animation(.easeInOut(duration: 0.3), value: showingPassphrase)
            .allowsHitTesting(false)

        // 角かっこ:QRに吸いつく(0.3秒)。Later のQRでなければ灰色。ロックでオレンジ
        let target = trackedRect(window: window) ?? CGRect(x: window.x - side / 2, y: window.y - side / 2, width: side, height: side)
        ScanBrackets(cornerRadius: 16)
            .stroke(bracketColor(locked: tau != nil), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .shadow(color: tau != nil ? Self.orange.opacity(0.8) : .clear, radius: 8)
            .frame(width: target.width, height: target.height)
            .position(x: target.midX, y: target.midY)
            .animation(.easeInOut(duration: 0.3), value: target)
            .opacity(1 - m.bracketsOut)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel("QRコードの読みとり範囲")

        // ロックのあと:まわりが黒に近づく
        Color.black.opacity(0.96 * m.blackout).allowsHitTesting(false)

        // 窓 → 丸:窓の縁がオレンジに光り、中のカメラが消えて、グループの色の丸が現れる
        if tau != nil {
            ZStack {
                RoundedRectangle(cornerRadius: m.cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(m.fill))
                RoundedRectangle(cornerRadius: m.cornerRadius, style: .continuous)
                    .strokeBorder(Self.orange.opacity(m.edgeGlow), lineWidth: 2)
                    .shadow(color: Self.orange.opacity(0.9 * m.edgeGlow), radius: 14)
                lockedCircle
                    .opacity(m.disc)
                    .scaleEffect(0.86 + 0.14 * m.disc)
            }
            .frame(width: side, height: side)
            .position(circleCenter)
            .allowsHitTesting(false)

            invitationLabels(center: circleCenter, show: m.labels)
        }

        chrome(layout: layout, m: m, now: now)
    }

    /// 取得できたらグループの色・人数の丸。間に合わないときは、オレンジの丸のまま待つ
    @ViewBuilder
    private var lockedCircle: some View {
        if case .success(let prepared)? = prepared {
            GroupCircle(
                image: prepared.invitation.iconData.flatMap(UIImage.init(data:)),
                initial: GroupNameRules.initial(of: prepared.invitation.groupName),
                colorIndex: prepared.invitation.colorIndex,
                memberLimit: prepared.invitation.memberLimit,
                litCount: prepared.memberCount,
                diameter: Self.windowSide,
                seatIndex: prepared.seatIndex
            )
            .transition(.opacity)
        } else {
            Circle()
                .fill(RadialGradient(colors: [Self.orange, Self.orange.opacity(0.55)], center: .center, startRadius: 0, endRadius: 100))
                .frame(width: Self.windowSide * 0.74, height: Self.windowSide * 0.74)
        }
    }

    @ViewBuilder
    private func invitationLabels(center: CGPoint, show: Double) -> some View {
        if case .success(let prepared)? = prepared, show > 0 {
            Text("INVITATION")
                .font(.system(size: 10, design: .monospaced))
                .tracking(0.26 * 10)
                .foregroundStyle(.white.opacity(0.55))
                .position(x: center.x, y: center.y - Self.windowSide / 2 - 20)
                .opacity(show)
            VStack(spacing: 8) {
                Text(prepared.invitation.groupName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text("招待を、ひらいています")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "BCBBC0"))
            }
            .position(x: center.x, y: center.y + Self.windowSide / 2 + 46)
            .opacity(show)
        }
    }

    // MARK: ×・見出し・状態・ドック

    @ViewBuilder
    private func chrome(layout: Layout, m: Morph, now: Date) -> some View {
        let locked = lockStart != nil
        // 左上の×、上中央の JOIN
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.white.opacity(0.12)).background(.ultraThinMaterial, in: Circle()))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("閉じる")
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(width: layout.size.width)
        .position(x: layout.size.width / 2, y: layout.safeTop + 26)
        .opacity(1 - m.chromeOut)
        .disabled(locked)

        Text("JOIN")
            .font(.system(size: 10, design: .monospaced))
            .tracking(0.26 * 10)
            .foregroundStyle(.white.opacity(0.5))
            .position(x: layout.size.width / 2, y: layout.safeTop + 26)
            .opacity(1 - m.chromeOut)
            .accessibilityHidden(true)

        // 見出し(読みとれたら「見つけました。」)
        VStack(spacing: 8) {
            Text(locked ? "見つけました。" : "QRコードを、窓にあわせて。")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .contentTransition(.opacity)
            Text(locked ? "グループの招待を、ひらきます。" : "画面のどこに映っても、読みとれます。")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "BCBBC0"))
                .contentTransition(.opacity)
        }
        .multilineTextAlignment(.center)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .padding(.horizontal, 24)
        .frame(width: layout.size.width)
        .position(x: layout.size.width / 2, y: layout.headingTop + 26)
        .opacity(1 - m.headingOut)
        .animation(.easeInOut(duration: 0.25), value: locked)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)

        // 窓の下:状態の一行 / お知らせのカプセル
        statusLine(now: now)
            .position(x: layout.size.width / 2, y: layout.windowCenter.y + Self.windowSide / 2 + 28)
            .opacity(1 - m.chromeOut)

        // ドックの上:コピーしたリンク
        if hasClipboardURL, !locked {
            clipboardChip
                .position(x: layout.size.width / 2, y: layout.dockY - 34 - 32)
                .transition(.opacity.combined(with: .offset(y: 8)))
        }

        dock(width: layout.size.width - 48, now: now)
            .position(x: layout.size.width / 2, y: layout.dockY)
            .opacity(1 - m.chromeOut)
            .disabled(locked)
    }

    @ViewBuilder
    private func statusLine(now: Date) -> some View {
        if let notice {
            Text(notice)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(Capsule().fill(.black.opacity(0.55)).background(.ultraThinMaterial, in: Capsule()))
                .transition(.opacity)
        } else {
            let blink = reduceMotion ? 1 : 0.55 + 0.45 * (0.5 + 0.5 * sin(now.timeIntervalSinceReferenceDate * 2 * .pi / 1.6))
            HStack(spacing: 7) {
                Circle().fill(.white).frame(width: 6, height: 6).opacity(blink)
                Text(camera.isDark ? "暗いときは、灯りを。" : "さがしています")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private var clipboardChip: some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text("コピーしたリンクが、あります")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            // システムの貼り付けボタン(中身を読むのは、押されたときだけ。許可のダイアログが出ない)
            PasteButton(payloadType: URL.self) { urls in
                guard let url = urls.first else { return }
                if let shareURL = InviteConfig.shareURL(from: url) {
                    hasClipboardURL = false
                    lock(shareURL, haptic: true)
                } else {
                    showNotice("Later の招待ではありません")
                }
            }
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .tint(.white)
            .labelStyle(.titleOnly)
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(height: 44)
        .background(Capsule().fill(.white.opacity(0.1)).background(.ultraThinMaterial, in: Capsule()))
        .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
    }

    private func dock(width: CGFloat, now: Date) -> some View {
        let iconOnly = dynamicTypeSize >= .accessibility1
        // 暗い場所:「灯り」がゆっくり光って(1.8秒)気づかせる。自動では点けない
        let hint = camera.isDark && !camera.isTorchOn && !reduceMotion
            ? 0.5 + 0.5 * sin(now.timeIntervalSinceReferenceDate * 2 * .pi / 1.8)
            : 0
        return HStack(spacing: 6) {
            dockButton(icon: camera.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill", title: "灯り", filled: camera.isTorchOn, glow: hint, iconOnly: iconOnly) {
                choose()
                camera.setTorch(!camera.isTorchOn)
            }
            .disabled(!camera.hasTorch)
            .accessibilityLabel("灯り")
            .accessibilityValue(camera.isTorchOn ? "オン" : "オフ")

            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                dockLabel(icon: "photo", title: "写真から", filled: false, glow: 0, iconOnly: iconOnly)
            }
            .simultaneousGesture(TapGesture().onEnded { choose() })
            .accessibilityLabel("写真から")

            dockButton(icon: "character.cursor.ibeam", title: "合言葉", filled: false, glow: 0, iconOnly: iconOnly) {
                choose()
                showingPassphrase = true
            }
            .accessibilityLabel("合言葉")
        }
        .padding(6)
        .frame(width: width, height: 68)
        .background(Capsule().fill(.white.opacity(0.08)).background(.ultraThinMaterial, in: Capsule()))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }

    private func dockButton(icon: String, title: String, filled: Bool, glow: Double, iconOnly: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            dockLabel(icon: icon, title: title, filled: filled, glow: glow, iconOnly: iconOnly)
        }
        .buttonStyle(PressScaleStyle(scale: 0.95, duration: 0.15))
    }

    private func dockLabel(icon: String, title: String, filled: Bool, glow: Double, iconOnly: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 15, weight: .medium))
            if !iconOnly {
                Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            }
        }
        .foregroundStyle(filled ? Color.black : Color.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Capsule().fill(filled ? Color.white : Color.white.opacity(0.06 + 0.22 * glow)))
        .shadow(color: .white.opacity(0.5 * glow), radius: 10)
        .contentShape(Capsule())
    }

    // MARK: カメラが使えないとき

    private func deniedView(layout: Layout) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("閉じる")
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, layout.safeTop + 6)
            Spacer()
            Image(systemName: "video.slash")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 84, height: 84)
                .background(Circle().fill(.white.opacity(0.08)))
                .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
                .accessibilityHidden(true)
            Text("カメラが、つかえません。")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 24)
            Text("合言葉か、写真からなら、入れます。")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "BCBBC0"))
                .padding(.top, 8)
            Spacer()
            VStack(spacing: 12) {
                Button {
                    choose()
                    showingPassphrase = true
                } label: {
                    Text("合言葉で入る")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(PressScaleStyle(scale: 0.97))
                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                    Text("写真から読みとる")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Capsule().fill(.white.opacity(0.1)).background(.ultraThinMaterial, in: Capsule()))
                }
                .simultaneousGesture(TapGesture().onEnded { choose() })
                if camera.access == .denied {
                    Button("設定で、カメラを許可する ›") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "BCBBC0"))
                    .padding(.top, 4)
                }
                if let notice {
                    Text(notice)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color(hex: "BCBBC0"))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, layout.safeBottom + 24)
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .background(Rectangle().fill(.ultraThinMaterial).overlay(Color.black.opacity(0.7)))
    }

    // MARK: 動き

    /// ロックからの経過時間 τ(秒)で決まる見た目。Reduce Motion ではクロスフェードだけ
    struct Morph {
        var cornerRadius: CGFloat = 44
        var edgeGlow = 0.0
        var fill = 0.0
        var disc = 0.0
        var move = 0.0
        var blackout = 0.0
        var labels = 0.0
        var chromeOut = 0.0
        var headingOut = 0.0
        var bracketsOut = 0.0

        init(tau: Double?, reduceMotion: Bool) {
            guard let tau else { return }
            func seg(_ a: Double, _ b: Double) -> Double { min(1, max(0, (tau - a) / (b - a))) }
            func ease(_ x: Double) -> Double { x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2 }
            chromeOut = seg(0, 0.25)
            if reduceMotion {
                // 0.3秒のクロスフェードだけ(位置は動かさず、まわりを暗くして丸を出す)
                let f = seg(0, 0.3)
                cornerRadius = 132
                fill = f
                disc = f
                blackout = f
                labels = f
                headingOut = 0
                bracketsOut = f
                move = 1
                return
            }
            // 窓の縁がオレンジに(0.25秒で立ち上がり、0.6秒で消える)
            edgeGlow = tau < 0.25 ? seg(0, 0.25) : 1 - seg(0.25, 0.85)
            // +0.2秒〜:窓が丸に(0.35秒)。中のカメラが消え、グループの色の丸が現れる
            let round = ease(seg(0.2, 0.55))
            cornerRadius = 44 + (132 - 44) * round
            fill = seg(0.2, 0.55)
            disc = ease(seg(0.3, 0.7))
            bracketsOut = seg(0.2, 0.45)
            // +0.45秒〜:まわりが黒に近づき、招待の円の位置へ
            blackout = ease(seg(0.45, 1.05))
            move = ease(seg(0.45, 1.05))
            headingOut = seg(0.45, 0.75)
            // +0.9秒〜:INVITATION・グループ名・「招待を、ひらいています」
            labels = seg(0.9, 1.2)
        }
    }

    private func bracketColor(locked: Bool) -> Color {
        if locked { return Self.orange }
        if let code = camera.code, !isLaterInvite(code) { return .white.opacity(0.34) }
        return .white
    }

    /// QRの外形 + 24pt の余白(窓の外に映っていても追う)
    private func trackedRect(window: CGPoint) -> CGRect? {
        guard lockStart == nil, let rect = camera.codeRect, rect.width > 4 else { return nil }
        return rect.insetBy(dx: -24, dy: -24)
    }

    private func isLaterInvite(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return InviteConfig.shareURL(from: url) != nil
    }

    // MARK: 読みとり・ロック

    /// 同じQRが約0.25秒、安定して見えていたらロック。Later の招待でなければ、静かに文言だけ
    private func tick(_ now: Date) {
        if let lockStart {
            advanceLock(now: now, since: lockStart)
            return
        }
        guard !showingPassphrase, let code = camera.code, let since = camera.codeSince else {
            if camera.code == nil, ignoredCode != nil { ignoredCode = nil }
            return
        }
        guard now.timeIntervalSince(since) >= 0.25 else { return }
        if let url = URL(string: code), let shareURL = InviteConfig.shareURL(from: url) {
            lock(shareURL, haptic: true)
        } else if ignoredCode != code {
            // 触覚なし・音なし・揺れなし・リンクも開かない。同じQRで何度も出さない
            ignoredCode = code
            showNotice("Later の招待ではありません")
        }
    }

    private func lock(_ shareURL: URL, haptic: Bool) {
        guard lockStart == nil else { return }
        camera.isPaused = true
        if haptic { haptics.playTransient(intensity: 1.0, sharpness: 0.7) }
        UIAccessibility.post(notification: .announcement, argument: "招待を見つけました")
        noticeTask?.cancel()
        notice = nil
        hasClipboardURL = false
        lockStart = Date()
        Task {
            let result = await prepare(shareURL)
            withAnimation(.easeInOut(duration: 0.3)) {
                prepared = result
                preparedAt = Date()
            }
        }
    }

    /// 丸になり、招待の中身がそろったら、招待を受ける画面へ(中身の入れかえだけ)。
    /// 取得が間に合わないときは、オレンジの丸のまま最長3秒待ち、だめならエラー画面へ
    private func advanceLock(now: Date, since: Date) {
        guard !resolved else { return }
        let tau = now.timeIntervalSince(since)
        let minimum = reduceMotion || voiceOverEnabled ? 0.35 : 1.35
        if let prepared, let preparedAt {
            let shown = now.timeIntervalSince(preparedAt)
            if case .success = prepared, tau >= minimum, shown >= 0.3 {
                resolved = true
                camera.stop()
                onResolved(prepared)
            } else if case .failure = prepared, tau >= 0.6 {
                resolved = true
                camera.stop()
                onResolved(prepared)
            }
        } else if tau >= minimum + 3 {
            resolved = true
            camera.stop()
            onResolved(.failure(.network))
        }
    }

    // MARK: 写真から・コピーしたリンク

    private func readPhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard let string = await QRScanCamera.detectQR(in: data) else {
            showNotice("QRコードが見つかりません")
            return
        }
        guard let url = URL(string: string), let shareURL = InviteConfig.shareURL(from: url) else {
            showNotice("Later の招待ではありません")
            return
        }
        // 窓の中に、選んだ写真を出して、同じ流れへ
        photoImage = UIImage(data: data)
        lock(shareURL, haptic: true)
    }

    /// URLらしいものがあるかだけを確かめる(中身は読まない:貼り付けの許可ダイアログが出ない)
    private func checkClipboard() async {
        guard UIPasteboard.general.hasURLs || UIPasteboard.general.hasStrings else {
            hasClipboardURL = false
            return
        }
        let patterns = (try? await UIPasteboard.general.detectedPatterns(for: [\.probableWebURL])) ?? []
        withAnimation(.easeOut(duration: 0.3)) { hasClipboardURL = !patterns.isEmpty }
    }

    private func showNotice(_ text: String) {
        noticeTask?.cancel()
        withAnimation(.easeOut(duration: 0.25)) { notice = text }
        noticeTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { notice = nil }
        }
    }

    /// ドックを選ぶ:ごく軽く1回(えらぶ)
    private func choose() {
        haptics.playTransient(intensity: 0.3, sharpness: 0.5)
    }
}

/// 角かっこ(四隅):腕30pt・角丸16pt
struct ScanBrackets: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let arm: CGFloat = 30
        let r = min(cornerRadius, arm - 2)
        var p = Path()
        // 左上
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + arm))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))
        // 右上
        p.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))
        // 右下
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - arm, y: rect.maxY))
        // 左下
        p.move(to: CGPoint(x: rect.minX + arm, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - arm))
        return p
    }
}
