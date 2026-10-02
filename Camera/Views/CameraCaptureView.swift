import SwiftUI
import AVFoundation
import AudioToolbox
import CoreLocation
internal import Combine

/// Daily Shot Camera(2026/9 再設計)。Apple標準カメラと同じく、ライブプレビューが
/// 画面全体を占め、コントロールは上下のグラデーションスクリムに浮かぶガラス質の部品
/// だけにする。配色は他画面と同じダークグリーン+アクセント(#22FF6E)に統一し、
/// 暖色は焼き込み日付スタンプ(#FF6A2B)だけに限定する。
///
/// 撮影処理(AVFoundation)・CloudKitへの保存・キャプション画面への遷移ロジックは
/// TodayView.swift側にあり、ここでは一切変更しない。UIKitはAVCaptureSessionの
/// プレビューレイヤーだけを担当し、それ以外の見た目は全てSwiftUIで描画する。
struct TrueBlindCameraView: View {
    /// 今日すでに撮影した枚数と、個人の撮影上限(「残り◯枚」表示・上限到達判定用)
    var currentCount: Int
    var limit: Int
    /// 直近(昨日を起点)からの連続撮影日数。控えめなアイコン表示にのみ使う。
    var streakCount: Int
    /// 撮影データに加え、その時点で取得できていた撮影地の地名(未取得/権限無しならnil)を渡す。
    var onCapture: (Data, String?) -> Void
    /// 動画(FilmEmulation加工済み.mp4のURL・サムネイル・長さ(秒)・撮影地の地名)の
    /// 撮影完了時に呼ぶ。
    var onCaptureVideo: (URL, UIImage?, Double, String?) -> Void
    /// 撮影前のキャプション入力画面(CaptionEntryView)で入力された文字列。空文字なら
    /// ピル自体を表示しない。撮影処理そのものには使わず、あくまでファインダー上の
    /// 表示用(投稿時のキャプションはPostTargetGroupSelectionView.initialCaption経由で
    /// 別途引き継がれる)。
    var caption: String = ""

    /// 呼び出し元(CheckiCameraEntryView)から共有されるAVCaptureSessionのコントローラー。
    @ObservedObject var camera: FilmCameraController
    /// 入口画面での前面/背面カメラの選択(仕様上、常にフロントカメラから始まる)を
    /// そのまま引き継ぐための初期値。
    private let initialCameraPosition: AVCaptureDevice.Position
    /// 入口画面のフラッシュ切り替えとこの画面のフラッシュ切り替えを同じ状態にする。
    @Binding var isFlashOn: Bool

    init(
        camera: FilmCameraController,
        initialCameraPosition: AVCaptureDevice.Position,
        isFlashOn: Binding<Bool>,
        currentCount: Int,
        limit: Int,
        streakCount: Int,
        caption: String = "",
        onCapture: @escaping (Data, String?) -> Void,
        onCaptureVideo: @escaping (URL, UIImage?, Double, String?) -> Void
    ) {
        self.camera = camera
        self.initialCameraPosition = initialCameraPosition
        self._isFlashOn = isFlashOn
        self.currentCount = currentCount
        self.limit = limit
        self.streakCount = streakCount
        self.caption = caption
        self.onCapture = onCapture
        self.onCaptureVideo = onCaptureVideo
        _cameraPosition = State(initialValue: initialCameraPosition)
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var videoCamera = VideoCaptureController()
    @StateObject private var locationProvider = CameraLocationNameProvider()
    /// シャッター押下時、画面全体を覆う白フラッシュの表示状態。
    @State private var showShutterFlash = false
    /// シャッター押下時、フルスクリーンプレビューを一瞬縮める演出の状態。
    @State private var isShutterFrameAnimating = false
    @State private var lastCapturedThumbnail: UIImage?
    @State private var isShowingThumbnailPreview = false

    // MARK: - Photo/Video モード切り替え、および動画撮影関連の状態
    enum CaptureMode {
        case photo, video
    }
    @State private var captureMode: CaptureMode = .photo
    /// Photo用(camera)・Video用(videoCamera)の両コントローラーで共有する、単一の
    /// カメラ位置状態。以前は各コントローラーが独立にcameraPositionを持っており、
    /// Videoモード開始時に意図せず背面カメラへ切り替わる不具合の原因になっていた。
    /// switchCameraButtonはこの値を更新した上で、両コントローラーへ明示的に伝える。
    @State private var cameraPosition: AVCaptureDevice.Position
    @State private var isPressingShutter = false
    /// 動画モードでのシャッターの押し方。押した瞬間に録画を始め、長押し
    /// (longPressThreshold以上)なら離した時点で停止、短いタップなら録画を続けて
    /// 次のタップで停止する(Apple標準カメラと同じ操作感)。
    private enum VideoPress {
        case none
        /// 録画していない状態で押し始めた(=この押下で録画を開始した)。
        case starting(Date)
        /// 録画中に押し始めた(=離したら停止する)。
        case stopping
    }
    @State private var videoPress: VideoPress = .none
    /// 停止操作が、AVFoundation側で実際に録画が始まるより前に行われた場合にtrue。
    /// 録画が始まった瞬間(onChange(of: videoCamera.isRecording))に止める。
    @State private var stopWhenRecordingStarts = false
    /// 動画モード用のセッション(videoCamera)が稼働していて、押した瞬間に録画を
    /// 始められる状態か。写真用・動画用の2つのセッションは同じ物理カメラを同時に
    /// 使えないため、以前はシャッターを押してから切り替えていたが、その切り替えに
    /// 1〜2秒かかり、長押しをすぐ離すと0秒の録画になって失敗していた。
    /// 「動画」を選んだ時点で切り替えておく。
    @State private var isVideoSessionReady = false
    /// 写真用⇔動画用セッションの切り替え中。
    @State private var isSwitchingSession = false
    @State private var isRecordingVideo = false
    @State private var isProcessingVideo = false
    /// 「録画自体の失敗」か「加工処理の失敗」かでアラートのタイトルを出し分けるため、
    /// videoProcessingErrorMessage(本文)とは別に保持する。必ず両方セットで設定すること。
    @State private var videoProcessingErrorTitle: String?
    @State private var videoProcessingErrorMessage: String?

    // MARK: - セルフタイマー(写真モードのみ)
    enum SelfTimer: Int, CaseIterable {
        case off = 0, three = 3, ten = 10

        var next: SelfTimer {
            let all = SelfTimer.allCases
            return all[(all.firstIndex(of: self)! + 1) % all.count]
        }
    }
    @State private var selfTimer: SelfTimer = .off
    /// カウントダウン中の残り秒数。nilならカウントダウンしていない。
    @State private var countdownRemaining: Int?
    @State private var countdownTask: Task<Void, Never>?

    @State private var isPulsing = false
    @State private var isPulsingDelayed = false
    @State private var isStatusDotLit = false

    /// シャッターボタンのDragGesture(minimumDistance: 0)で、指の移動量がこの値未満なら
    /// 「タップ」とみなす閾値(pt)。
    private static let tapDistanceThreshold: CGFloat = 10

    private var isLimitReached: Bool { currentCount >= limit }
    private var remainingCount: Int { max(0, limit - currentCount) }
    /// これから撮るのが今日の何枚目か(上限到達後は上限のまま)。
    private var frameNumber: Int { min(currentCount + 1, max(limit, 1)) }
    private var isCountingDown: Bool { countdownRemaining != nil }
    /// 録画中・カウントダウン中は、モードやカメラ等の切り替えを受け付けない。
    private var isBusy: Bool { isRecordingVideo || isCountingDown || isSwitchingSession }
    /// 長押しとタップを分ける閾値(秒)。
    private static let longPressThreshold: TimeInterval = 0.4

    // MARK: - カラー(他画面のColor.later*と同じダークグリーンの世界観に揃える)

    private static let accent = Color.laterAccent
    private static let text = Color.laterText
    private static let mutedText = Color.laterTextMuted
    private static let softText = Color(hex: "CFE9D8")
    /// ボタン類の半透明黒ガラスの地色。
    private static let glassFill = Color(hex: "050F09")
    private static let glassBorder = Color.white.opacity(0.12)
    /// セグメントのアクティブ側など、アクセント色の上に載せる文字色。
    private static let onAccent = Color(hex: "04170B")
    /// 上下スクリムの地色(rgba(3,9,5,…))。
    private static let scrimColor = Color(red: 3 / 255, green: 9 / 255, blue: 5 / 255)
    /// カメラ未許可などでプレビューが映らない間に見える背景。
    private static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "23301f"), Color(hex: "101b12"), Color(hex: "0a120c")],
        startPoint: UnitPoint(x: 0.33, y: 0),
        endPoint: UnitPoint(x: 0.67, y: 1)
    )
    /// 焼き込み日付スタンプの色。画面内で唯一の暖色で、他のボタン類には使わない。
    private static let dateStampColor = Color(hex: "FF6A2B")
    private static let recordingRed = Color(hex: "FF3B30")

    // MARK: - レイアウト(セーフエリア基準。390×844のモックでは上118px/下300px相当)

    /// 撮影可能エリア(コーナーブラケット)の上端。上部コントロールのすぐ下。
    private static let viewfinderTopInset: CGFloat = 70
    /// 撮影可能エリアの下端。下部コントロールのすぐ上。
    private static let viewfinderBottomInset: CGFloat = 262

    var body: some View {
        ZStack {
            Self.backgroundGradient
                .ignoresSafeArea()

            previewFrame
                .ignoresSafeArea()

            filmGrainOverlay
                .ignoresSafeArea()

            vignetteOverlay
                .ignoresSafeArea()

            scrims

            viewfinderDecorations

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer(minLength: 0)
                bottomControls
            }

            if let countdownRemaining {
                countdownOverlay(countdownRemaining)
            }
        }
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
        // シャッター押下時の白フラッシュは画面全体を覆う演出のため、全体に重ねる。
        .overlay {
            if showShutterFlash {
                Color.white
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if isShowingThumbnailPreview, let lastCapturedThumbnail {
                thumbnailPreview(lastCapturedThumbnail)
            }
        }
        // 加工中(FilmEmulationVideoExporter実行中)のローディング表示。
        .overlay {
            if isProcessingVideo {
                ZStack {
                    Self.glassFill.opacity(0.85).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Self.accent)
                        Text("動画を加工中です…")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Self.softText)
                    }
                }
            }
        }
        .onAppear {
            camera.configure()
            videoCamera.configure()
            locationProvider.requestPlaceName()
            startPulseAnimations()
        }
        .onDisappear {
            cancelCountdown()
            // 動画モードのまま閉じた場合も、動画用セッション(カメラ・マイク)を確実に止める。
            if isVideoSessionReady || captureMode == .video {
                isVideoSessionReady = false
                videoCamera.stopRunning()
            }
        }
        // 停止操作が、録画が実際に始まる前に行われていた場合は、始まった瞬間に止める。
        .onChange(of: videoCamera.isRecording) { _, isRecording in
            if isRecording && stopWhenRecordingStarts {
                stopWhenRecordingStarts = false
                videoCamera.stopRecording()
            }
        }
        .alert(videoProcessingErrorTitle ?? "動画の加工に失敗しました", isPresented: Binding(
            get: { videoProcessingErrorMessage != nil },
            set: { if !$0 { videoProcessingErrorMessage = nil; videoProcessingErrorTitle = nil } }
        )) {
            Button("OK") { videoProcessingErrorMessage = nil; videoProcessingErrorTitle = nil }
        } message: {
            Text(videoProcessingErrorMessage ?? "")
        }
    }

    private func startPulseAnimations() {
        withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) {
            isPulsing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) {
                isPulsingDelayed = true
            }
        }
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            isStatusDotLit = true
        }
    }

    // MARK: - ガラス質の部品

    /// 半透明黒ガラスのピル(ヒント・キャプション・現像ステータス)。
    private func glassCapsule<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .background(Self.glassFill.opacity(0.55), in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Self.glassBorder, lineWidth: 1))
    }

    // MARK: - 上部オーバーレイ(閉じる・現像ステータス・フレームカウンター)

    private var topBar: some View {
        ZStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Self.text)
                        .frame(width: 34, height: 34)
                        .background(Self.glassFill.opacity(0.45), in: Circle())
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                }
                .buttonStyle(CameraLightGlowButtonStyle())
                .accessibilityLabel("閉じる")

                Spacer()

                frameCounterDial
            }

            developStatusPill
        }
    }

    private var developStatus: (label: String, color: Color) {
        if isRecordingVideo { return ("録画中", Self.recordingRed) }
        if isLimitReached { return ("今日は撮影済み", Self.mutedText) }
        if isCountingDown { return ("セルフタイマー", Self.accent) }
        if isSwitchingSession { return ("カメラを準備中", Self.mutedText) }
        return ("現像 準備OK", Self.accent)
    }

    /// フレーム番号の代わりに「今撮れる状態か」を知らせるステータス。
    private var developStatusPill: some View {
        let status = developStatus
        return glassCapsule {
            HStack(spacing: 7) {
                Circle()
                    .fill(status.color)
                    .frame(width: 7, height: 7)
                    .shadow(color: status.color.opacity(0.9), radius: isStatusDotLit ? 5 : 1)
                    .opacity(isLimitReached ? 1 : (isStatusDotLit ? 1 : 0.45))
                Text(status.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Self.softText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .accessibilityElement(children: .combine)
    }

    /// 円形フレームカウンター(アクセント色の縁取り)。中心に今日の何枚目か。
    private var frameCounterDial: some View {
        VStack(spacing: -3) {
            Text("\(frameNumber)")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
            Text("枚目")
                .font(.system(size: 8, weight: .semibold))
        }
        .foregroundStyle(Self.text)
        .frame(width: 40, height: 40)
        .background(Self.glassFill.opacity(0.45), in: Circle())
        .overlay(Circle().strokeBorder(Self.accent, lineWidth: 1.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日の\(frameNumber)枚目")
    }

    // MARK: - プレビュー(フルブリードのライブプレビュー)

    private var previewFrame: some View {
        ZStack {
            CameraPreviewRepresentable(session: camera.session)

            // 動画モードの間は物理カメラを写真用セッションから動画用セッションへ明け渡す
            // (同じカメラを2つのAVCaptureSessionが同時には使えないため)。写真用の
            // プレビューは裏で一時停止中の最終フレームのまま止まっているだけなので、
            // 動画用プレビューを上から重ねて隠す。
            if isVideoSessionReady || isRecordingVideo {
                CameraPreviewRepresentable(session: videoCamera.session)
            }

            if isLimitReached {
                Self.glassFill.opacity(0.55)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        // シャッター押下時、プレビュー全体を一瞬だけ縮める演出。
        .scaleEffect(isShutterFrameAnimating ? 0.97 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isShutterFrameAnimating)
    }

    // MARK: - フィルム粒子・ビネット・上下スクリム(装飾のみ、撮影処理には無関係)

    /// フィルム粒子ノイズ。再描画のたびに粒の位置が変わってちらつかないよう、
    /// 固定の種から決定的に生成する。
    private var filmGrainOverlay: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func next() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double(seed >> 11) / Double(1 << 53)
            }
            for _ in 0..<520 {
                let rect = CGRect(x: next() * size.width, y: next() * size.height, width: 1.2, height: 1.2)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.02 + next() * 0.06)))
            }
        }
        .allowsHitTesting(false)
        .opacity(0.5)
    }

    /// 周辺減光。黒のビネットに、うっすら緑の内側グロー
    /// (box-shadow: inset 0 0 220px 70px rgba(34,255,110,0.07)相当)を重ねる。
    private var vignetteOverlay: some View {
        ZStack {
            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.45)],
                center: .center,
                startRadius: 140,
                endRadius: 460
            )
            Rectangle()
                .strokeBorder(Self.accent.opacity(0.12), lineWidth: 140)
                .blur(radius: 110)
        }
        .clipped()
        .allowsHitTesting(false)
    }

    /// 帯ではなく、プレビューの上に重ねるグラデーションスクリム。
    private var scrims: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Self.scrimColor.opacity(0.65), Self.scrimColor.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)

            Spacer(minLength: 0)

            LinearGradient(
                stops: [
                    .init(color: Self.scrimColor.opacity(0.85), location: 0),
                    .init(color: Self.scrimColor.opacity(0.85), location: 0.3),
                    .init(color: Self.scrimColor.opacity(0), location: 1)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 280)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - ファインダー上の装飾(ブラケット・キャプション・日付・ヒント)

    private var viewfinderDecorations: some View {
        ZStack {
            cornerBrackets

            VStack(spacing: 0) {
                HStack {
                    captionPill
                    Spacer()
                }
                Spacer()
                HStack {
                    Spacer()
                    dateStamp
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)

            hintPill
        }
        .padding(.top, Self.viewfinderTopInset)
        .padding(.bottom, Self.viewfinderBottomInset)
    }

    private var cornerBrackets: some View {
        GeometryReader { geometry in
            let length: CGFloat = 24
            let inset: CGFloat = 14
            let w = geometry.size.width
            let h = geometry.size.height
            Path { path in
                // 左上
                path.move(to: CGPoint(x: inset, y: length))
                path.addLine(to: CGPoint(x: inset, y: 0))
                path.addLine(to: CGPoint(x: inset + length, y: 0))
                // 右上
                path.move(to: CGPoint(x: w - inset - length, y: 0))
                path.addLine(to: CGPoint(x: w - inset, y: 0))
                path.addLine(to: CGPoint(x: w - inset, y: length))
                // 左下
                path.move(to: CGPoint(x: inset, y: h - length))
                path.addLine(to: CGPoint(x: inset, y: h))
                path.addLine(to: CGPoint(x: inset + length, y: h))
                // 右下
                path.move(to: CGPoint(x: w - inset - length, y: h))
                path.addLine(to: CGPoint(x: w - inset, y: h))
                path.addLine(to: CGPoint(x: w - inset, y: h - length))
            }
            .stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
        .allowsHitTesting(false)
    }

    /// 前のステップ(CaptionEntryView)で入力されたキャプションを左上に小さく表示する。
    @ViewBuilder
    private var captionPill: some View {
        if !caption.isEmpty {
            glassCapsule {
                Text(caption)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Self.text)
                    .lineLimit(1)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
            }
        }
    }

    /// 右下の焼き込み日付スタンプ('26 9 21のような表記)。
    private var dateStamp: some View {
        Text(Self.dateStampLabel())
            .font(.custom("Courier New", size: 15).weight(.bold).italic())
            .foregroundStyle(Self.dateStampColor)
            .shadow(color: Self.dateStampColor.opacity(0.7), radius: 4)
            .accessibilityHidden(true)
    }

    private static func dateStampLabel() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "''yy M d"
        return formatter.string(from: Date())
    }

    @ViewBuilder
    private var hintPill: some View {
        if !isLimitReached && !isBusy {
            glassCapsule {
                Text("枠の中に、今日をおさめよう")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Self.softText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .allowsHitTesting(false)
        } else if isLimitReached {
            glassCapsule {
                Text("今日のフィルムを使い切りました")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Self.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - 下部オーバーレイ(モード行・シャッター行・マイクロコピー)

    private var bottomControls: some View {
        VStack(spacing: 0) {
            modeRow
                .padding(.horizontal, 28)
                .padding(.bottom, 30)

            shutterRow
                .padding(.horizontal, 28)

            Text(microcopy)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Self.mutedText)
                .padding(.top, 12)
                .padding(.bottom, 4)
        }
    }

    private var microcopy: String {
        if isLimitReached { return "今日の1枚は、もう撮り終えました" }
        if isCountingDown { return "もう一度押すと、タイマーを止めます" }
        if isRecordingVideo, case .none = videoPress { return "もう一度押すと、録画を止めます" }
        switch captureMode {
        case .photo: return "押すと、現像がはじまります"
        case .video: return "長押しで録画・離すと現像がはじまります"
        }
    }

    // MARK: モード行(フラッシュ・写真/動画・セルフタイマー)

    private var modeRow: some View {
        ZStack {
            HStack {
                flashButton
                Spacer()
                selfTimerButton
            }
            modeToggle
        }
    }

    private var flashButton: some View {
        Button {
            isFlashOn.toggle()
            HapticsManager.tick()
        } label: {
            Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isFlashOn ? Self.accent : Self.text)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(CameraLightGlowButtonStyle())
        .disabled(isBusy)
        .opacity(isBusy ? 0.4 : 1.0)
        .accessibilityLabel(isFlashOn ? "フラッシュ オン" : "フラッシュ オフ")
    }

    /// タップでオフ→3秒→10秒→オフと切り替える。写真モードでのみ有効。
    private var selfTimerButton: some View {
        let isAvailable = captureMode == .photo && !isBusy
        return Button {
            selfTimer = selfTimer.next
            HapticsManager.tick()
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "timer")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(selfTimer == .off ? Self.text : Self.accent)
                    .frame(width: 32, height: 32)
                if selfTimer != .off {
                    Text("\(selfTimer.rawValue)")
                        .font(.custom("Courier New", size: 10).weight(.bold))
                        .foregroundStyle(Self.onAccent)
                        .padding(.horizontal, 3)
                        .background(Capsule().fill(Self.accent))
                        .offset(x: 4, y: 2)
                }
            }
        }
        .buttonStyle(CameraLightGlowButtonStyle())
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1.0 : 0.4)
        .accessibilityLabel(selfTimer == .off ? "セルフタイマー オフ" : "セルフタイマー \(selfTimer.rawValue)秒")
    }

    /// 写真/動画のセグメント。アクティブ側はアクセント色で塗りつぶす。録画中・
    /// カウントダウン中はモードを変更できない。
    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeToggleButton(title: "写真", mode: .photo)
            modeToggleButton(title: "動画", mode: .video)
        }
        .padding(3)
        .background(Self.glassFill.opacity(0.45), in: Capsule())
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Self.glassBorder, lineWidth: 1))
        .disabled(isBusy)
        .opacity(isBusy ? 0.4 : 1.0)
    }

    private func modeToggleButton(title: String, mode: CaptureMode) -> some View {
        Button {
            switchCaptureMode(to: mode)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(captureMode == mode ? Self.onAccent : Self.softText)
                .frame(width: 58, height: 28)
                .background(Capsule().fill(captureMode == mode ? Self.accent : Color.clear))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: captureMode)
        .accessibilityAddTraits(captureMode == mode ? .isSelected : [])
    }

    // MARK: シャッター行(サムネイル・シャッター・カメラ切替+残り枚数)

    private var shutterRow: some View {
        ZStack {
            shutterButton

            HStack(alignment: .center) {
                thumbnailView
                Spacer()
                VStack(spacing: 6) {
                    switchCameraButton
                    Text(isLimitReached ? "撮影済み" : "残り\(remainingCount)枚")
                        .font(.custom("Courier New", size: 11).weight(.bold))
                        .foregroundStyle(Self.softText)
                }
                .frame(width: 64)
            }
        }
        .frame(height: 120)
    }

    private var thumbnailView: some View {
        Button {
            guard lastCapturedThumbnail != nil else { return }
            isShowingThumbnailPreview = true
        } label: {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Self.glassFill.opacity(0.35))
                .frame(width: 44, height: 44)
                .overlay {
                    if let lastCapturedThumbnail {
                        Image(uiImage: lastCapturedThumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(CameraLightGlowButtonStyle())
        .disabled(lastCapturedThumbnail == nil)
        .accessibilityLabel("直前の1枚")
    }

    private var switchCameraButton: some View {
        Button {
            cameraPosition = cameraPosition == .back ? .front : .back
            camera.setCameraPosition(cameraPosition)
            videoCamera.setCameraPosition(cameraPosition)
            HapticsManager.tick()
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Self.text)
                .frame(width: 40, height: 40)
                .background(Self.glassFill.opacity(0.45), in: Circle())
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Self.glassBorder, lineWidth: 1))
        }
        .buttonStyle(CameraLightGlowButtonStyle())
        // 録画中にカメラデバイスの入力を差し替えると、書き出し中のファイルが
        // 壊れる/録画が異常終了するおそれがあるため、録画中は切り替えを禁止する。
        .disabled(isBusy)
        .opacity(isBusy ? 0.4 : 1.0)
        .accessibilityLabel("カメラを切り替え")
    }

    // MARK: シャッターボタン

    private var shutterAccent: Color {
        captureMode == .video ? Self.recordingRed : Self.accent
    }

    /// 上限到達時はロック表示付きで押せなくする。
    private var isShutterDisabled: Bool { isLimitReached }
    /// 動画用セッションの準備が終わるまで(切り替え中を含む)は押せない。
    private var isShutterUnavailable: Bool {
        isShutterDisabled || isSwitchingSession || (captureMode == .video && !isVideoSessionReady)
    }

    /// Photoモード: タップで撮影(セルフタイマー設定時はカウントダウン後に撮影)。
    /// Videoモード: 押した瞬間に録画開始。長押しなら離すと停止、短いタップなら次の
    /// タップで停止(いずれも10秒経過で自動停止)。いずれも
    /// 終了と同時に投稿画面へ遷移する(processRecordedVideo → onCaptureVideo参照)。
    private var shutterButton: some View {
        ZStack {
            if !isShutterDisabled {
                pulseRing(isActive: isPulsing)
                pulseRing(isActive: isPulsingDelayed)
            }

            // 白いリング(4px)
            Circle()
                .strokeBorder(Color.white, lineWidth: 4)
                .frame(width: 84, height: 84)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 3)

            if isRecordingVideo {
                Circle()
                    .trim(from: 0, to: videoCamera.recordingProgress)
                    .stroke(Self.recordingRed, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 84, height: 84)
                    .animation(.linear(duration: 0.05), value: videoCamera.recordingProgress)
            }

            shutterCore

            if isShutterDisabled {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Self.onAccent.opacity(0.7))
            }
        }
        .frame(width: 120, height: 120)
        .opacity(isShutterUnavailable ? 0.5 : 1.0)
        .scaleEffect(isPressingShutter ? 0.92 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressingShutter)
        .contentShape(Circle())
        // タップ・長押しを1つのDragGesture(minimumDistance: 0)で扱う。.onTapGestureと
        // DragGestureを併用すると認識器が競合してタップが安定しないため。
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressingShutter { isPressingShutter = true }
                    guard captureMode == .video, case .none = videoPress else { return }
                    if isRecordingVideo {
                        videoPress = .stopping
                    } else {
                        videoPress = .starting(Date())
                        startVideoRecording()
                    }
                }
                .onEnded { value in
                    isPressingShutter = false
                    switch captureMode {
                    case .photo:
                        let dragDistance = hypot(value.translation.width, value.translation.height)
                        guard dragDistance < Self.tapDistanceThreshold else { return }
                        handlePhotoShutter()
                    case .video:
                        switch videoPress {
                        case .stopping:
                            stopVideoRecording()
                        case .starting(let pressedAt):
                            // 長押しなら離した時点で停止。短いタップなら録画を続ける。
                            if Date().timeIntervalSince(pressedAt) >= Self.longPressThreshold {
                                stopVideoRecording()
                            }
                        case .none:
                            break
                        }
                        videoPress = .none
                    }
                }
        )
        .disabled(isShutterUnavailable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(captureMode == .photo ? "シャッター" : "録画ボタン")
        .accessibilityHint(captureMode == .photo ? "押すと撮影します" : "長押しで録画して離すと停止、またはタップで開始と停止")
        .accessibilityAddTraits(.isButton)
    }

    /// 内側のディスク。写真: アクセント色の細い縁取りを持つ白い円。動画: 赤い角丸四角
    /// (録画中はさらに小さくなる)。形状の変化はアニメーションでつなぐ。
    private var shutterCore: some View {
        let size: CGFloat
        let cornerRadius: CGFloat
        switch captureMode {
        case .photo:
            size = 68; cornerRadius = 34
        case .video:
            size = isRecordingVideo ? 28 : 36
            cornerRadius = isRecordingVideo ? 6 : 9
        }
        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(captureMode == .photo ? Color.white : Self.recordingRed)
            .overlay {
                if captureMode == .photo {
                    Circle().strokeBorder(Self.accent, lineWidth: 2)
                }
            }
            .frame(width: size, height: size)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: captureMode)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isRecordingVideo)
    }

    private func pulseRing(isActive: Bool) -> some View {
        Circle()
            .strokeBorder(shutterAccent.opacity(0.55), lineWidth: 1.5)
            .frame(width: 84, height: 84)
            .scaleEffect(isActive ? 1.45 : 1)
            .opacity(isActive ? 0 : 0.7)
    }

    // MARK: - セルフタイマーのカウントダウン

    private func handlePhotoShutter() {
        if isCountingDown {
            cancelCountdown()
            return
        }
        guard selfTimer != .off else {
            capture()
            return
        }
        let seconds = selfTimer.rawValue
        countdownRemaining = seconds
        HapticsManager.tick()
        countdownTask = Task { @MainActor in
            for remaining in stride(from: seconds - 1, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                if remaining == 0 {
                    countdownRemaining = nil
                    countdownTask = nil
                    capture()
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { countdownRemaining = remaining }
                    HapticsManager.tick()
                }
            }
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdownRemaining = nil
    }

    private func countdownOverlay(_ remaining: Int) -> some View {
        Text("\(remaining)")
            .font(.custom("Courier New", size: 96).weight(.bold))
            .foregroundStyle(Self.accent)
            .shadow(color: Self.accent.opacity(0.6), radius: 16)
            .contentTransition(.numericText(countsDown: true))
            .allowsHitTesting(false)
            .accessibilityLabel("あと\(remaining)秒")
    }

    // MARK: - 直前の1枚のプレビュー

    private func thumbnailPreview(_ image: UIImage) -> some View {
        ZStack {
            Color.laterBackground.opacity(0.94).ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(24)
        }
        .contentShape(Rectangle())
        .onTapGesture { isShowingThumbnailPreview = false }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("直前の1枚。タップで閉じる")
    }

    // MARK: - 撮影処理(既存のonCaptureクロージャをそのまま呼ぶだけ)

    private func capture() {
        guard !isLimitReached else { return }

        // 白フラッシュ: 0→1へ即座に(全体200ms以内のうち15%程度=約30msで)立ち上がり、
        // その後150msでフェードアウトする。合計約180msで、連続撮影のテンポを損なわない。
        withAnimation(.linear(duration: 0.03)) { showShutterFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            withAnimation(.linear(duration: 0.15)) { showShutterFlash = false }
        }

        // カメラ枠: 一瞬scale 0.94まで縮めて緑に変え、直後に白へ戻しながら1.0へ戻す
        // (縮み80ms+戻り120msの合計200ms程度)。
        withAnimation(.easeOut(duration: 0.08)) { isShutterFrameAnimating = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeOut(duration: 0.12)) { isShutterFrameAnimating = false }
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // シャッター音。既存のサウンド再生処理はこのプロジェクトに無かったため新規追加。
        // 1108は写真撮影用のシステムサウンドID。
        AudioServicesPlaySystemSound(1108)

        camera.capturePhoto(flashOn: isFlashOn) { data in
            // AVCapturePhotoOutputのデリゲートコールバックはメインスレッドとは限らない。
            // ここから先の@State更新(lastCapturedThumbnail)、およびonCapture経由で
            // TodayView側が行うSwiftDataへの保存はメインスレッドで行う必要があるため、
            // 明示的にディスパッチする(バックグラウンドスレッドのままだと、保存が
            // 不安定になったり無言で失敗したりする原因になる)。
            DispatchQueue.main.async {
                guard let data else {
                    print("[PhotoSave Error] capturePhotoの結果データがnil(撮影自体に失敗)")
                    return
                }
                if let uiImage = UIImage(data: data) {
                    lastCapturedThumbnail = uiImage
                } else {
                    print("[PhotoSave Error] UIImage(data:)への変換に失敗。データサイズ=\(data.count)bytes")
                }
                // 画面を閉じる責務は呼び出し側(TodayViewのshowingCamera = false)だけに委ねる。
                // ここで自身もdismiss()すると、二つのfullScreenCoverが同時に閉じる/開こうとして
                // 競合し、後続のキャプション入力画面が開かないことがある。
                onCapture(Self.compressedImageData(from: data), locationProvider.placeName)
            }
        }
    }

    // MARK: - 動画撮影処理

    /// 写真/動画モードの切り替え。同じ物理カメラを2つのAVCaptureSessionが同時には
    /// 使えないため、写真用セッションを完全に止めてから動画用セッションを動かす
    /// (またはその逆)。以前はこの切り替えをシャッターを押してから行っていたため、
    /// 録画が実際に始まるまで1〜2秒の無反応な時間ができ、長押しをすぐ離すと0秒の
    /// 録画になって失敗していた。モードを選んだ時点で切り替えておくことで、
    /// シャッターを押した瞬間に録画を始められるようにする。
    private func switchCaptureMode(to mode: CaptureMode) {
        guard captureMode != mode, !isBusy else { return }
        captureMode = mode
        HapticsManager.tick()
        isSwitchingSession = true

        switch mode {
        case .video:
            camera.pauseForVideoRecording {
                videoCamera.startRunningIfNeeded {
                    isSwitchingSession = false
                    guard videoCamera.session.isRunning else {
                        // 権限の確認中/拒否などで動画用セッションを起動できなかった場合は、
                        // 写真モードへ戻して原因を伝える。
                        print("[VideoCapture] 動画用セッションを起動できませんでした")
                        captureMode = .photo
                        videoCamera.stopRunning {
                            camera.resumeAfterVideoRecording()
                        }
                        videoProcessingErrorTitle = "動画モードを開始できませんでした"
                        videoProcessingErrorMessage = VideoCaptureError.sessionNotReady.localizedDescription
                        return
                    }
                    isVideoSessionReady = true
                }
            }
        case .photo:
            isVideoSessionReady = false
            videoCamera.stopRunning {
                camera.resumeAfterVideoRecording()
                isSwitchingSession = false
            }
        }
    }

    /// 動画用セッションは「動画」を選んだ時点で稼働済み(switchCaptureMode参照)なので、
    /// ここでは録画だけを開始する。録画終了後もセッションは動画モードのまま動かしておき
    /// (失敗時にすぐ撮り直せるように)、画面を閉じる時(onDisappear)に止める。
    private func startVideoRecording() {
        guard !isLimitReached, !isRecordingVideo, isVideoSessionReady else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        stopWhenRecordingStarts = false
        isRecordingVideo = true
        videoCamera.startRecording { [self] rawURL, recordingError in
            DispatchQueue.main.async {
                isRecordingVideo = false
                stopWhenRecordingStarts = false
                guard let rawURL else {
                    print("[VideoCapture] 録画に失敗しました(rawURLがnil) error=\(String(describing: recordingError))")
                    videoProcessingErrorTitle = "録画に失敗しました"
                    if let recordingError {
                        videoProcessingErrorMessage = "録画に失敗しました(エラー: \(recordingError.localizedDescription))。もう一度お試しください。"
                    } else {
                        videoProcessingErrorMessage = "録画に失敗しました。もう一度お試しください。"
                    }
                    return
                }
                processRecordedVideo(rawURL: rawURL)
            }
        }
    }

    /// 停止操作。AVFoundation側でまだ録画が始まっていなければ、始まった瞬間に止める
    /// (onChange(of: videoCamera.isRecording)参照)。
    private func stopVideoRecording() {
        guard isRecordingVideo else { return }
        if videoCamera.isRecording {
            videoCamera.stopRecording()
        } else {
            stopWhenRecordingStarts = true
        }
    }

    /// 撮影直後・アップロード前に一度だけFilmEmulationを適用して書き出す
    /// (再生のたびに処理しない、という要件のための「一度だけ」の実処理箇所)。
    private func processRecordedVideo(rawURL: URL) {
        isProcessingVideo = true
        videoProcessingErrorTitle = nil
        videoProcessingErrorMessage = nil
        Task {
            do {
                let result = try await FilmEmulationVideoExporter.export(rawURL: rawURL)
                print("[VideoCapture] 加工完了: 加工前=\(result.rawFileSize)bytes 加工後=\(result.processedFileSize)bytes")
                await MainActor.run {
                    isProcessingVideo = false
                    // 画面を閉じる責務はcapture()と同じく呼び出し側(TodayView)に委ねる。
                    // 終了(手動停止・10秒経過どちらも)と同時に、動画専用の投稿画面へ
                    // 即座に遷移させる。
                    onCaptureVideo(result.processedVideoURL, result.thumbnail, result.durationSeconds, locationProvider.placeName)
                }
                try? FileManager.default.removeItem(at: rawURL)
            } catch {
                print("[VideoCapture] 加工失敗: \(error)")
                await MainActor.run {
                    videoProcessingErrorTitle = "動画の加工に失敗しました"
                    videoProcessingErrorMessage = "動画の加工に失敗しました: \(error.localizedDescription)"
                    isProcessingVideo = false
                }
            }
        }
    }

    // MARK: - アップロード前の画像圧縮
    //
    // AVCapturePhotoOutputが返す生データ(フルサイズHEIC/JPEG、機種によっては
    // 1枚あたり数MB〜十数MB)を無圧縮のままCKAssetとしてアップロードしていたため、
    // 解禁後に他メンバーの端末へ画像が届くまでの送信が遅くなったり、モバイル回線等で
    // 途中で失敗しやすくなったりする一因になっていた。長辺を上限まで縮小し、
    // JPEG(quality 0.8)へ再エンコードしてからLaterPhoto.imageDataとして使う。
    private static let maxCapturedImageDimension: CGFloat = 1600

    private static func compressedImageData(from data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let resized = resizedIfNeeded(image, maxDimension: maxCapturedImageDimension)
        return resized.jpegData(compressionQuality: 0.8) ?? data
    }

    private static func resizedIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension else { return image }
        let scale = maxDimension / longestSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - 現在地の地名取得(CoreLocation)
//
// 許可が無い場合・取得や逆ジオコーディングに失敗した場合はplaceNameがnilのまま
// なので、呼び出し側(locationTag)はタグ自体を非表示にするだけでよい。

final class CameraLocationNameProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var placeName: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestPlaceName() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self, error == nil, let placemark = placemarks?.first else { return }
            self.placeName = placemark.locality ?? placemark.subLocality ?? placemark.name
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 取得失敗時はplaceNameをnilのままにし、タグを非表示にする。
    }
}

// MARK: - AVCaptureSession管理(UIKit、プレビューレイヤーとフラッシュ/撮影のみを担当)

final class FilmCameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var captureCompletion: ((Data?) -> Void)?

    /// 現在アクティブなカメラ(前面/背面)。switchCamera()で切り替わる。
    @Published private(set) var cameraPosition: AVCaptureDevice.Position = .back

    func configure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted { DispatchQueue.main.async { self?.setupSession() } }
            }
        default: break
        }
    }

    private func setupSession() {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        addInput(for: cameraPosition)
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    /// 前面(内カメラ/自撮り)と背面カメラを切り替える。既存の入力を外してから
    /// 新しいデバイスの入力に差し替えるだけで、出力(photoOutput)やプレビュー層は
    /// そのまま使い回せる(セッション自体の再起動は不要)。
    ///
    /// 動画用(VideoCaptureController)と共有される単一のcameraPosition状態から呼ばれる。
    /// 両コントローラーが独立にcameraPositionを持っていたことが、Video開始時に
    /// 意図せず背面カメラへ切り替わってしまう不具合の原因だったため、切り替えボタン
    /// (TrueBlindCameraView.switchCameraButton)は両方へ同じpositionを明示的に伝える。
    /// まだsetupSession()が完了していない場合は、実機のセッションを操作せず
    /// cameraPositionの値だけ更新する(setupSession()実行時にこの値が使われる)。
    func setCameraPosition(_ newPosition: AVCaptureDevice.Position) {
        guard cameraPosition != newPosition else { return }
        guard !session.inputs.isEmpty else {
            cameraPosition = newPosition
            return
        }
        session.beginConfiguration()
        for input in session.inputs {
            session.removeInput(input)
        }
        addInput(for: newPosition)
        session.commitConfiguration()
        cameraPosition = newPosition
    }

    private func addInput(for position: AVCaptureDevice.Position) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            print("FilmCameraController: カメラデバイスが見つかりません(position: \(position))")
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
        } catch {
            print("FilmCameraController: failed to configure session: \(error)")
        }
    }

    /// 動画撮影(VideoCaptureController)へ切り替える間、同じ物理カメラデバイスを
    /// 2つのAVCaptureSessionが同時に使うことはできないため、写真用セッションを
    /// 一時停止する。動画撮影が終わったらresumeAfterVideoRecording()で再開する。
    ///
    /// stopRunning()だけでなく、ここでカメラの入力(AVCaptureDeviceInput)自体も
    /// session.removeInput()で明示的に外す。stopRunning()でセッションを止めても
    /// 入力を保持したままだと、VideoCaptureController側が同じ物理カメラデバイスで
    /// 新しい入力(AVCaptureDeviceInput)を作ろうとした際に「デバイスが既に別の
    /// セッションで使われている」扱いになり、動画用セッションにカメラ入力が
    /// 追加できない(録画が毎回失敗する)不具合の一因になっていたため、入力の有無に
    /// ついては疑わしきは罰する形で確実に外しておく。
    ///
    /// AVCaptureSession.stopRunning()は完全に停止するまでブロックする仕様のため、
    /// メインスレッドで直接呼ぶとUIハング(ウォッチドッグによる強制終了)の原因になる。
    /// バックグラウンドキューで実行し、完了後にメインスレッドへ戻ってからcompletionを
    /// 呼ぶ(呼び出し側は「写真用セッションが完全に止まり、カメラ入力も外れた後」を
    /// 前提に動画用セッションを開始できる)。
    func pauseForVideoRecording(completion: @escaping () -> Void = {}) {
        guard session.isRunning else {
            removeCameraInput()
            DispatchQueue.main.async(execute: completion)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.removeCameraInput()
                completion()
            }
        }
    }

    private func removeCameraInput() {
        guard let input = session.inputs.first else { return }
        session.beginConfiguration()
        session.removeInput(input)
        session.commitConfiguration()
    }

    /// 外しておいたカメラ入力を再度追加してから、写真用セッションを再開する。
    /// (removeCameraInput()で外した入力を戻さずにstartRunning()すると、入力ゼロの
    /// セッションが「動いてはいるが何も映さない」状態になり、ライブプレビューが
    /// 固まる/写真撮影が無言で失敗する原因になるため、必ず入力を戻してから再開する。)
    func resumeAfterVideoRecording() {
        if session.inputs.isEmpty {
            session.beginConfiguration()
            addInput(for: cameraPosition)
            session.commitConfiguration()
        }
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func capturePhoto(flashOn: Bool, completion: @escaping (Data?) -> Void) {
        captureCompletion = completion
        let settings = AVCapturePhotoSettings()
        // 前面カメラにはフラッシュが無いため、背面カメラの時だけフラッシュ設定を適用する。
        if cameraPosition == .back, photoOutput.supportedFlashModes.contains(flashOn ? .on : .off) {
            settings.flashMode = flashOn ? .on : .off
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension FilmCameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            print("[PhotoSave Error] AVCapturePhotoOutput処理失敗: \(error)")
        }
        guard error == nil, let data = photo.fileDataRepresentation() else {
            if error == nil {
                print("[PhotoSave Error] photo.fileDataRepresentation()がnilを返却(画像データ化に失敗)")
            }
            captureCompletion?(nil)
            captureCompletion = nil
            return
        }
        captureCompletion?(data)
        captureCompletion = nil
    }
}

// MARK: - プレビューレイヤーのホスト(UIViewのlayerClassをAVCaptureVideoPreviewLayerにする
// 標準的な手法。frameの手動同期が不要になり、回転・リサイズにも自動追従する)

struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

// MARK: - スケールボタンスタイル
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// 撮影画面のガラス質アイコンボタン用のタップ演出(押している間だけ縮む)。
struct CameraLightGlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
