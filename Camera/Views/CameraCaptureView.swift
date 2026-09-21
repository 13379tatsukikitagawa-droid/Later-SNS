import SwiftUI
import AVFoundation
import AudioToolbox
import CoreLocation
internal import Combine

/// 上品でシンプルなフィルムカメラ風のUI。撮影処理(AVFoundation)・CloudKitへの保存・
/// キャプション画面への遷移ロジックはTodayView.swift側にあり、ここでは一切変更しない。
/// UIKitはAVCaptureSessionのプレビューレイヤーだけを担当し、それ以外の見た目は
/// 全てSwiftUIで描画する。強いフィルムグレイン・ヴィネットはこの画面には適用しない
/// (現像後の写真側への適用は別途対応する)。
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

    /// 呼び出し元(CheckiCameraEntryView、チェキ型入口画面)から共有される
    /// AVCaptureSessionのコントローラー。入口の小窓プレビューと同じインスタンスを
    /// 使い回すことで、カメラセッションが二重に起動しないようにする。
    @ObservedObject var camera: FilmCameraController
    /// 入口画面での前面/背面カメラの選択(仕様上、入口は常にフロントカメラから始まる)を
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
        onCapture: @escaping (Data, String?) -> Void,
        onCaptureVideo: @escaping (URL, UIImage?, Double, String?) -> Void
    ) {
        self.camera = camera
        self.initialCameraPosition = initialCameraPosition
        self._isFlashOn = isFlashOn
        self.currentCount = currentCount
        self.limit = limit
        self.streakCount = streakCount
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
    /// 「今日のテーマ」バナーの表示状態。デフォルトはfalse(任意表示)。
    @State private var showThemeBanner = false

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
    @State private var isRecordingVideo = false
    @State private var isProcessingVideo = false
    /// 「録画自体の失敗」か「加工処理の失敗」かでアラートのタイトルを出し分けるため、
    /// videoProcessingErrorMessage(本文)とは別に保持する。必ず両方セットで設定すること。
    @State private var videoProcessingErrorTitle: String?
    @State private var videoProcessingErrorMessage: String?

    private static let shutterAccentGreen = Color(hex: "4ade6c")
    /// シャッターボタンのDragGesture(minimumDistance: 0)で、指の移動量がこの値未満なら
    /// 「タップ」とみなす閾値(pt)。
    private static let tapDistanceThreshold: CGFloat = 10

    private var isLimitReached: Bool { currentCount >= limit }
    private var remainingCount: Int { max(0, limit - currentCount) }

    // MARK: - カラー(このカメラ画面専用。他画面のColor.brandGreen等には影響しない)
    private let accentOrange = Color(red: 1.0, green: 0.541, blue: 0.239)      // #ff8a3d
    /// チェキのフチを模したクリーム色。上部バー・下部の帯の背景に使う。
    private static let filmCream = Color(hex: "f4efe4")

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(Self.filmCream)

            themeBanner
                .padding(.top, 10)

            ZStack {
                previewFrame
                guideText
            }
            .padding(.horizontal, 6)
            .background(Self.filmCream)
            .overlay(alignment: .bottom) {
                locationTag
                    .padding(.bottom, 10)
            }

            bottomFilmBand
        }
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden()
        // シャッター押下時の白フラッシュは画面全体を覆う演出のため、previewFrameの
        // 内側だけでなく画面全体に重ねるオーバーレイとしてここに置く。
        .overlay {
            if showShutterFlash {
                Color.white
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        // 加工中(FilmEmulationVideoExporter実行中)は「読み込み中」系画面と同じ
        // トーンのローディング表示にする(このステージでは仮の確認用UI)。
        .overlay {
            if isProcessingVideo {
                ZStack {
                    Color.black.opacity(0.75).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("動画を加工中です…")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
        }
        .onAppear {
            camera.configure()
            videoCamera.configure()
            locationProvider.requestPlaceName()
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

    // MARK: - 上部バー(閉じる+「TODAY'S LATER・日付」ステータス+フラッシュ/カメラ切り替え)
    // チェキのフチ(クリーム色の帯)の上に載るため、暗い背景を前提にしたスタイルではなく
    // 濃い色のアイコン+薄い黒丸の組み合わせにする。

    private static func todayLabel() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: Date())
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.corkboardHeading.opacity(0.85))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.black.opacity(0.06)))
            }
            .buttonStyle(CameraLightGlowButtonStyle())

            Spacer()

            VStack(spacing: 2) {
                Text("TODAY'S LATER・\(Self.todayLabel())")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.corkboardHeading.opacity(0.75))
                Text(isLimitReached ? "本日分は撮影済み" : "残り\(remainingCount)枚")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.corkboardTabInactiveText)
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    isFlashOn.toggle()
                } label: {
                    Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isFlashOn ? accentOrange : Color.corkboardHeading.opacity(0.85))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.black.opacity(0.06)))
                }
                .buttonStyle(CameraLightGlowButtonStyle())

                switchCameraButton
            }
        }
    }

    /// 「今日のテーマ」の表示有無を任意で切り替えるボタン。以前はtopBar右上にあったが、
    /// 新しいtopBarはステータス表示+フラッシュ/カメラ切り替え専用にしたため、
    /// 目立たない位置(bottomFilmBand)に移した。機能・見た目(緑発光)自体は変更なし。
    private var themeBannerToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showThemeBanner.toggle()
            }
        } label: {
            Image(systemName: showThemeBanner ? "text.quote" : "quote.bubble")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(showThemeBanner ? Self.shutterAccentGreen : Color.corkboardTabInactiveText)
        }
        .buttonStyle(.plain)
    }

    /// 任意表示の「今日のテーマ」バナー。撮影を妨げないよう、topBarの下に控えめに挟む
    /// だけで、撮影可否や投稿内容には一切影響しない完全な演出。
    @ViewBuilder
    private var themeBanner: some View {
        if showThemeBanner {
            HStack(spacing: 8) {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Self.shutterAccentGreen)
                Text(DailyThemeProvider.theme())
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(Color.black.opacity(0.5))
            )
            .overlay(
                Capsule().strokeBorder(Self.shutterAccentGreen.opacity(0.3), lineWidth: 1)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - カメラ切り替え(前面/背面)ボタン。右下(bottomRowの右端)に配置する。

    private var switchCameraButton: some View {
        Button {
            cameraPosition = cameraPosition == .back ? .front : .back
            camera.setCameraPosition(cameraPosition)
            videoCamera.setCameraPosition(cameraPosition)
            HapticsManager.tick()
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath.camera")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.corkboardHeading.opacity(0.85))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.black.opacity(0.06)))
        }
        .buttonStyle(CameraLightGlowButtonStyle())
        // 録画中にカメラデバイスの入力を差し替えると、書き出し中のファイルが
        // 壊れる/録画が異常終了するおそれがあるため、録画中は切り替えを禁止する。
        .disabled(isRecordingVideo)
        .opacity(isRecordingVideo ? 0.4 : 1.0)
    }

    // MARK: - プレビュー(フルスクリーンのライブプレビュー。チェキのフチはbody側の
    // クリーム色の帯で表現するため、このView自体は枠や角丸を持たない)

    private var previewFrame: some View {
        ZStack {
            CameraPreviewRepresentable(session: camera.session)

            // 動画撮影中は物理カメラを写真用セッションから動画用セッションへ明け渡す
            // (同じカメラを2つのAVCaptureSessionが同時には使えないため)。写真用の
            // プレビューは裏で一時停止中の最終フレームのまま止まっているだけなので、
            // 動画用プレビューを上から重ねて隠す。
            if isRecordingVideo {
                CameraPreviewRepresentable(session: videoCamera.session)
            }

            if isLimitReached {
                Color.black.opacity(0.55)
                Text("今日のフィルムを使い切りました")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        // シャッター押下時、プレビュー全体を一瞬だけ縮める演出(以前は枠の色替え+縮小
        // だったが、フルスクリーン化に伴い枠が無くなったため縮小のみ引き継ぐ)。
        .scaleEffect(isShutterFrameAnimating ? 0.97 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isShutterFrameAnimating)
    }

    /// プレビュー中央に薄く重ねるガイド文言。撮影の邪魔にならないよう控えめに。
    private var guideText: some View {
        Text("枠の中に、今日をおさめよう")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.black.opacity(0.35)))
            .opacity(isLimitReached ? 0 : 1)
    }

    // MARK: - 現在地タグ(取得できない/許可が無い場合はタグ自体を非表示にする)

    private var locationTag: some View {
        Group {
            if let placeName = locationProvider.placeName {
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 11, weight: .semibold))
                    Text(placeName)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.45)))
            }
        }
    }

    // MARK: - Photo/Video 切り替え(セグメントコントロール)
    // 「単押し=写真・長押し=動画」という単一ボタンでの暗黙の切り替えは廃止し、
    // 明示的なモード切り替えに置き換える(要件)。切り替えに応じてシャッターボタンの
    // 挙動自体も変わる(Photo=単押しで撮影、Video=タップで録画開始→再タップまたは
    // 10秒経過で終了)。録画中はモードを変更できないようにする。
    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeToggleButton(title: "PHOTO", mode: .photo)
            modeToggleButton(title: "VIDEO", mode: .video)
        }
        .padding(3)
        .background(Capsule().fill(Color.black.opacity(0.06)))
        .overlay(Capsule().strokeBorder(Color.corkboardHeading.opacity(0.2), lineWidth: 1))
        .disabled(isRecordingVideo)
        .opacity(isRecordingVideo ? 0.4 : 1.0)
    }

    private func modeToggleButton(title: String, mode: CaptureMode) -> some View {
        Button {
            guard captureMode != mode else { return }
            captureMode = mode
            HapticsManager.tick()
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(captureMode == mode ? .white : Color.corkboardHeading.opacity(0.6))
                .frame(width: 72, height: 30)
                .background(
                    Capsule().fill(captureMode == mode ? Color.corkboardHeading.opacity(0.85) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: captureMode)
    }

    // MARK: - チェキのフチを模した、太いクリーム色の下部帯
    // 状態Bの主役であるシャッターボタンをここに置く。Dispoにあるような投稿先の
    // 複数アイコン・ライブラリ切り替えは実装せず、ボタンは1つだけにする。

    private var bottomFilmBand: some View {
        VStack(spacing: 14) {
            HStack {
                themeBannerToggleButton

                Spacer()

                if streakCount > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(streakCount)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(accentOrange)
                }

                Spacer()

                modeToggle
            }
            .padding(.horizontal, 24)

            bottomRow

            Text("押すと、現像がはじまります")
                .font(.custom("Caveat-Bold", size: 17))
                .foregroundStyle(Color.corkboardHeading.opacity(0.75))
        }
        .padding(.top, 16)
        .padding(.bottom, 30)
        .background(Self.filmCream)
    }

    // MARK: - 下部(シャッターを中央に固定し、その左に直前の撮影サムネイルを配置)

    private var bottomRow: some View {
        ZStack {
            shutterButton

            HStack {
                thumbnailView
                Spacer()
            }
            .padding(.horizontal, 28)
        }
    }

    private var thumbnailView: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.black.opacity(0.05))
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
                    .strokeBorder(Color.corkboardHeading.opacity(0.15), lineWidth: 1)
            )
    }

    /// Photoモード: タップで即座に撮影。Videoモード: タップで録画開始、録画中に
    /// もう一度タップすると停止(または10秒経過で自動停止)。いずれの終了方法でも
    /// 終了と同時に投稿画面(動画専用キャプション画面)へ即座に遷移する
    /// (processRecordedVideo → onCaptureVideo参照)。
    private var shutterButton: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.corkboardHeading.opacity(0.3), lineWidth: 1.5)
                .frame(width: 72, height: 72)

            if isRecordingVideo {
                Circle()
                    .trim(from: 0, to: videoCamera.recordingProgress)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 78, height: 78)
                    .animation(.linear(duration: 0.05), value: videoCamera.recordingProgress)
            }

            Circle()
                .fill(captureMode == .video ? Color.red : Color.white)
                .frame(width: 64, height: 64)

            if isRecordingVideo {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
            } else if isLimitReached && captureMode == .photo {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.6))
            }
        }
        .opacity(isLimitReached && captureMode == .photo ? 0.5 : 1.0)
        .scaleEffect(isPressingShutter ? 0.9 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressingShutter)
        .contentShape(Circle())
        // 以前は.onTapGestureと.simultaneousGesture(DragGesture)を同じビューに
        // 併用しており、2つのジェスチャー認識器が競合してタップが安定して発火しない
        // 不具合があった。DragGesture(minimumDistance: 0)1つに統合し、onEndedで
        // 「指がほぼ動いていなければタップとみなす」判定を行うことで、押下状態の表示
        // (isPressingShutter)とタップ相当の操作を単一のジェスチャーで両立させる。
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressingShutter = true }
                .onEnded { value in
                    isPressingShutter = false
                    let dragDistance = hypot(value.translation.width, value.translation.height)
                    guard dragDistance < Self.tapDistanceThreshold else { return }
                    switch captureMode {
                    case .photo:
                        capture()
                    case .video:
                        if isRecordingVideo {
                            videoCamera.stopRecording()
                        } else {
                            startVideoRecording()
                        }
                    }
                }
        )
        .disabled(isLimitReached && captureMode == .photo)
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

    /// 同じ物理カメラを2つのAVCaptureSessionが同時には使えないため、写真用の
    /// セッションを完全に止めてから動画用セッションを動かす必要がある。以前は
    /// camera.pauseForVideoRecording(写真用セッションの停止)の完了を待たずに
    /// videoCamera.startRecording(movieOutput.startRecording)を同期的に呼んでおり、
    /// 動画用セッションがまだstartRunning()し終わっていない状態で録画を開始しようと
    /// してしまう非同期処理の順序不備があった(「見た目は録画中だが実際には録画が
    /// 開始されない」不具合の原因)。ここではpauseForVideoRecording→
    /// videoCamera.startRunningIfNeeded(completion:)と、両方の完了を確実に待ってから
    /// videoCamera.startRecording(...)を呼ぶ形に直列化する。isRecordingVideoも、
    /// この録画開始呼び出しの直前(実際に開始する寸前)に立てる。
    private func startVideoRecording() {
        guard !isLimitReached, !isRecordingVideo else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        camera.pauseForVideoRecording {
            videoCamera.startRunningIfNeeded {
                isRecordingVideo = true
                videoCamera.startRecording { [self] rawURL, recordingError in
                    DispatchQueue.main.async {
                        isRecordingVideo = false
                        // stopRunning()もバックグラウンドキューで実行され、完了後に
                        // メインスレッドへ戻ってからcompletionが呼ばれる(同上)。
                        videoCamera.stopRunning {
                            camera.resumeAfterVideoRecording()
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
            }
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

/// クリーム色の帯(チェキのフチ)に載る、濃い色のアイコンボタン用のタップ演出
/// (押している間だけ縮む)。状態Bのtop bar・switchCameraButtonで使う。
struct CameraLightGlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
