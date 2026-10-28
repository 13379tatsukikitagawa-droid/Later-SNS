import SwiftUI
import UIKit
import AVKit

/// 撮影画面(カメラの映像だけ・シャッターの幕・文字なしの「撮ったあと」)。
///
/// ① 構える … 全画面に外カメラの映像。幕(上下の黒い板)が開いて始まる
/// ② 長押しで露光 … 1.5秒で写真が決まる(トン)。リングの橙の弧が満ち、映像が少し明るくなる。
///    途中で離すと撮らない(弧は0.2秒でもどる)
/// ③ 撮ったあと … 白いフラッシュ → 幕が閉じ、フィルムが巻かれて空のこまで止まる。写真は一度も見せない
///
/// 撮った写真はプレビューもサムネイルも出さず、その場で保存する(保存はonCaptured)。
struct ExposureCameraView: View {
    /// 今日すでに撮った枚数(FilmRoll.shotsPerDay まで撮れる)
    let shotsToday: Int
    /// 撮影データ(圧縮済み)・露光を始めた時刻・タグ・地名を渡して保存する。保存できたらtrue。
    let onCaptured: (_ imageData: Data, _ exposureStart: Date, _ tags: [String], _ locationName: String?) -> Bool
    /// 撮ったあとの流れを終えた時に呼ぶ(呼び出し側が画面を閉じる)。
    let onFinished: () -> Void
    /// 撮影せずに閉じる(撮影前のタグ画面へ戻る時も、この呼び出し)。
    let onClose: () -> Void
    /// 何を撮るか。プロフィール画像の撮り直しでも、同じ撮影(長押し・プレビューなし・暗転)を使う。
    var purpose: ExposurePurpose = .daily
    /// 撮影前のタグ画面(TagBeforeShootView)で決めたタグ。撮影画面では編集せず、文字として見せる。
    var presetTags: [String]?
    /// タグ画面からチップが飛んでくる間は、タグを隠しておく。
    var hidesPresetTags = false
    /// この画面が消える時にセッションを止めるか。タグ画面から続く流れ(ShootFlowView)は、流れの側が止める。
    var managesSession = true

    private enum Phase: Equatable {
        case ready
        case exposed
        case failed
    }

    /// 離したあと、ゲージを p×(1-k)² でもどす途中の状態。
    private struct ReleaseDecay: Equatable {
        let start: Date
        let from: Double
    }

    private enum Timing {
        /// 預けられなかった時、説明を見せる時間
        static let failedHold: TimeInterval = 1.4
        /// 幕を開けるまでの最短の時間(映像が来ていても)
        static let minimumClosed: TimeInterval = 0.35
        /// 離したあと、リングの弧がもどる時間
        static let releaseDuration: TimeInterval = 0.2
        /// 撮れた直後の白いフラッシュ
        static let flash: TimeInterval = 0.26
        /// フラッシュのあと、幕が閉じる時間
        static let curtainClose: TimeInterval = 0.07
    }

    @ObservedObject private var camera = FilmCameraController.shared
    @StateObject private var locationProvider = CameraLocationNameProvider()
    @State private var haptics = ExposureHaptics()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var tags: [String] = []

    /// 長押しを始めた時刻。nilなら押していない。
    @State private var pressStart: Date?
    @State private var releaseDecay: ReleaseDecay?
    @State private var holdTask: Task<Void, Never>?

    @State private var phase: Phase = .ready
    @State private var exposureStart: Date?
    /// 撮ったあとのアニメの開始時刻(写真が決まった瞬間)。nilならアニメなし。
    @State private var afterShotStart: Date?

    /// 1.5秒の写真を撮ったか(撮ったら「トン」)
    @State private var shutterFired = false
    @State private var stillData: Data?
    @State private var stillCaptured = false
    /// 録画の結果を待っているか(録画を始めた時だけ true)
    @State private var recordingPending = false
    /// 離した(または自動終了した)あと、残すものを決めて待っている最中か
    @State private var isSettling = false
    @State private var outcome: ExposureOutcome = .discard
    @State private var isFinished = false

    /// 幕:開いているか / 最短の時間(0.35秒)がたったか / 撮ったあとで閉じたか
    @State private var curtainsOpen = false
    @State private var minimumClosedPassed = false
    @State private var closedByShot = false
    @State private var flashOpacity = 0.0

    /// 日付スタンプの時刻(1分ごとに更新)
    @State private var stampDate = Date()

    var body: some View {
        GeometryReader { outer in
            ZStack {
                Color.black.ignoresSafeArea()

                TimelineView(.animation(paused: isStill)) { context in
                    captureLayout(at: context.date, safeTop: outer.safeAreaInsets.top)
                        .opacity(phase == .failed ? 0 : 1)
                }

                if camera.isAccessDenied {
                    ExposedNoticeView(
                        title: "カメラを使えません",
                        message: "設定アプリでカメラを許可すると、\n撮れるようになります。",
                        risesIntoOrb: false
                    )
                }

                if phase == .failed {
                    ExposedNoticeView(
                        title: "預けられませんでした",
                        message: failedMessage,
                        risesIntoOrb: false
                    )
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
        .onAppear {
            if let presetTags { tags = presetTags }
            // タグ画面から続く時は、もう動いている。ここは何度呼んでも、キューに積むだけ。
            camera.useBackCameraIfNeeded()
            camera.configure()
            haptics.prepare()
            locationProvider.requestPlaceName()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Timing.minimumClosed))
                minimumClosedPassed = true
            }
        }
        .task { await tickStamp() }
        .onChange(of: shouldOpenCurtains) { _, shouldOpen in
            if shouldOpen { openCurtains() }
        }
        .onDisappear {
            holdTask?.cancel()
            // 画面を閉じたら、途中の露光は残さない(録画の結果が届いても何もしない)
            pressStart = nil
            camera.stopVideoRecording()
            haptics.tearDown()
            if managesSession { camera.stopSession() }
        }
    }

    // MARK: - 進み具合

    /// 長押し中は押した時間から、離したあとは decay からの値を返す。
    private func progress(at date: Date) -> Double {
        if let pressStart {
            return min(1, max(0, date.timeIntervalSince(pressStart) / DailyExposureRules.holdDuration))
        }
        guard let releaseDecay else { return 0 }
        return CaptureMotion.releasedProgress(
            from: releaseDecay.from,
            elapsed: date.timeIntervalSince(releaseDecay.start),
            duration: Timing.releaseDuration
        )
    }

    /// 動きがない時間は、TimelineView を止めておく(描き直しを減らす)。
    private var isStill: Bool {
        pressStart == nil && releaseDecay == nil && afterShotStart == nil
    }

    private func afterShotFrame(at date: Date) -> CaptureAfterShotFrame? {
        guard let afterShotStart else { return nil }
        return CaptureAfterShot.frame(
            at: date.timeIntervalSince(afterShotStart),
            reduceMotion: reduceMotion
        )
    }

    private var canShootNow: Bool {
        canBeginExposure(at: Date())
    }

    /// 今日の1枚は時間帯・1日の上限(3こま)の判定に従う。プロフィール画像は呼び出し側が回数を判定する。
    private func canBeginExposure(at date: Date) -> Bool {
        switch purpose {
        case .daily: return DailyExposureRules.canBeginExposure(at: date, shotsToday: shotsToday)
        case .profilePhoto: return true
        }
    }

    // MARK: - 幕

    /// 映像が流れ始めていて、最短の0.35秒もたち、撮ったあとでもない。
    private var shouldOpenCurtains: Bool {
        minimumClosedPassed && camera.isRunning && !closedByShot && !camera.isAccessDenied
    }

    private func openCurtains() {
        guard !curtainsOpen else { return }
        withAnimation(.timingCurve(0.7, 0, 0.25, 1, duration: 0.5)) {
            curtainsOpen = true
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// 撮れた:白いフラッシュ(0.85 → 0 を0.26秒)のあと、幕が0.07秒で閉じる。
    private func playShotFlashAndClose() {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { flashOpacity = 0.85 }
        DispatchQueue.main.async {
            withAnimation(.linear(duration: Timing.flash)) { flashOpacity = 0 }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Timing.flash))
            closedByShot = true
            withAnimation(.linear(duration: Timing.curtainClose)) { curtainsOpen = false }
        }
    }

    // MARK: - 撮影画面の配置(カメラの映像の上には、必要なものだけ)

    private func captureLayout(at date: Date, safeTop: CGFloat) -> some View {
        let p = progress(at: date)
        let shot = afterShotFrame(at: date)
        let chrome = shot?.chrome ?? 1
        return GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                cameraImage(progress: p, size: size)
                    .opacity(shot?.window ?? 1)
                chromeLayer(progress: p, chrome: chrome, size: size, safeTop: safeTop)
                Color.white
                    .opacity(flashOpacity)
                    .allowsHitTesting(false)
                if let shot {
                    CaptureFilmAdvanceLayer(frame: shot, exposedAt: exposureStart)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
    }

    // MARK: 映像・グラデーション・ビネット・グレイン・幕

    private func cameraImage(progress p: Double, size: CGSize) -> some View {
        ZStack {
            if VideoExposureRules.previewMode == .visible {
                CameraPreviewRepresentable(session: camera.session)
                    .brightness(p * 0.12)
            } else {
                // プレビューなし:映像は出さず、黒いまま
                Color(white: 0.04)
            }

            // 周りを少し暗くする(中心0・四隅 黒35%)
            Rectangle()
                .fill(RadialGradient(
                    colors: [.clear, .black.opacity(0.35)],
                    center: .center,
                    startRadius: 0,
                    endRadius: hypot(size.width, size.height) / 2
                ))
                .allowsHitTesting(false)

            // 上 18%:黒42% → 0 / 下 38%:0 → 黒62%
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.42), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: size.height * 0.18)
                Spacer(minLength: 0)
                LinearGradient(colors: [.clear, .black.opacity(0.62)], startPoint: .top, endPoint: .bottom)
                    .frame(height: size.height * 0.38)
            }
            .allowsHitTesting(false)

            // later_film_grain.png はリポジトリに無いので、既存の固定グレイン(タイル・オーバーレイ・動かない)を使う
            FilmGrainOverlay(opacity: 0.38, blendMode: .overlay)

            shutterCurtains(size: size)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .accessibilityHidden(true)
    }

    /// 上下2枚の黒い板(それぞれ画面の高さの50.5%)。閉じている時は画面を隠し、開く時は上は上へ・下は下へ。
    private func shutterCurtains(size: CGSize) -> some View {
        let height = size.height * 0.505
        return ZStack {
            VStack(spacing: 0) {
                Color.black
                    .frame(height: height)
                    .offset(y: curtainsOpen ? -height : 0)
                Spacer(minLength: 0)
                Color.black
                    .frame(height: height)
                    .offset(y: curtainsOpen ? height : 0)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: 映像の上に置くもの(戻る・ロゴ・数字ダイヤル・日付・タグ・シャッター)

    private func chromeLayer(progress p: Double, chrome: Double, size: CGSize, safeTop: CGFloat) -> some View {
        ZStack {
            header(chrome: chrome)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, safeTop + 14)
            dateStamp
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 26)
                .padding(.bottom, 212)
                .opacity(chrome)
            tagRow
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 20)
                .padding(.bottom, 166)
                .opacity(chrome * (purpose == .daily ? 1 : 0))
            shutter(progress: p, chrome: chrome)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 54)
            holdLabel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 24)
                .opacity(chrome)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: ヘッダー(戻る・ロゴ・数字ダイヤル)

    private func header(chrome: Double) -> some View {
        ZStack {
            // ロゴは押せない(タップを通す)
            Text("Later")
                .font(CaptureFonts.interBlack(21))
                .tracking(-0.04 * 21)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 12)
                .allowsHitTesting(false)

            HStack {
                backButton
                    .opacity(chrome)
                Spacer()
                DigitDial(value: remainingShots, maxValue: FilmRoll.shotsPerDay)
                    .opacity(purpose == .daily ? chrome : 0)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(purpose == .daily ? "今日の撮影、残り\(remainingShots)枚" : "")
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 40)
    }

    private var backButton: some View {
        Button(action: onClose) {
            Text("‹")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .background(Circle().fill(.black.opacity(0.22)))
        }
        .buttonStyle(.plain)
        .disabled(pressStart != nil)
        .accessibilityLabel(presetTags == nil ? "閉じる" : "タグに戻る")
    }

    private var remainingShots: Int {
        FilmRoll.shotsRemaining(shotsToday: shotsToday)
    }

    // MARK: 日付スタンプ(右下)

    private var dateStamp: some View {
        Text(Self.stampFormatter.string(from: stampDate))
            .font(CaptureFonts.monoBold(15))
            .foregroundStyle(Color(hex: "FF8A3D"))
            .shadow(color: Color(hex: "FF6E14").opacity(0.8), radius: 6)
            .shadow(color: Color(hex: "3C1400").opacity(0.45), radius: 8, y: 1)
            .lineLimit(1)
            .fixedSize()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// 次の「分」の境目で更新する(1秒ごとのタイマーは使わない)。
    private func tickStamp() async {
        while !Task.isCancelled {
            let now = Date()
            stampDate = now
            let next = (now.timeIntervalSince1970 / 60).rounded(.down) * 60 + 60
            try? await Task.sleep(for: .seconds(max(0.5, next - now.timeIntervalSince1970)))
        }
    }

    // MARK: タグ(下の中央・1行)

    /// 場所(ピン+地名)→ タグ(0〜3つ)。入りきらない時は、最後のタグが「…」になる。タップでタグ画面へ。
    private var tagRow: some View {
        let shown = Array(tags.prefix(3))
        return Button {
            onClose()
        } label: {
            ViewThatFits(in: .horizontal) {
                tagRowContent(shown, ellipsizeLast: false)
                tagRowContent(shown, ellipsizeLast: true)
            }
            .opacity(hidesPresetTags ? 0 : 1)
        }
        .buttonStyle(.plain)
        .disabled(presetTags == nil || pressStart != nil)
        .accessibilityLabel("タグ \(shown.joined(separator: "、"))。タップでタグ画面に戻る")
    }

    private func tagRowContent(_ shown: [String], ellipsizeLast: Bool) -> some View {
        HStack(spacing: 12) {
            if purpose == .daily, let placeName = locationProvider.placeName {
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 12))
                    Text(placeName)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
                .foregroundStyle(.white.opacity(0.75))
            }
            ForEach(Array(shown.enumerated()), id: \.element) { index, tag in
                let isLast = index == shown.count - 1
                if ellipsizeLast && isLast {
                    Text("…")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                } else {
                    tagText(tag)
                }
            }
        }
        .fixedSize()
    }

    private func tagText(_ tag: String) -> some View {
        (Text("#").foregroundColor(Color(hex: "FF8A3D")) + Text(tag).foregroundColor(.white))
            .font(.system(size: 15, weight: .heavy))
            .lineLimit(1)
            .background(GeometryReader { geometry in
                Color.clear.preference(key: CameraTagChipFrameKey.self, value: [tag: geometry.frame(in: .named(TagBeforeShootView.coordinateSpace))])
            })
    }

    // MARK: シャッター(リング80pt+内側の白い円)

    private func shutter(progress p: Double, chrome: Double) -> some View {
        let isAvailable = canShootNow && phase == .ready
        let isHolding = pressStart != nil
        return ZStack {
            Circle()
                .stroke(.white.opacity(0.95), lineWidth: 3)
            Circle()
                .trim(from: 0, to: p)
                .stroke(Color(hex: "FF6A1A"), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(.white)
                .padding(8)
                .scaleEffect(isHolding ? 0.86 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHolding)
        }
        .frame(width: 80, height: 80)
        .contentShape(Circle())
        .opacity((isAvailable ? 1 : 0.35) * chrome)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in beginHoldIfNeeded() }
                .onEnded { _ in releaseHold() }
        )
        .accessibilityElement()
        .accessibilityLabel("長押しで撮影")
        .accessibilityHint(isAvailable ? "ダブルタップしたまま押し続けると、撮影します" : "今は撮影できません")
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isHolding ? "露光中" : "")
    }

    /// 小さな「HOLD」(押している間は消える)
    private var holdLabel: some View {
        Text("HOLD")
            .font(CaptureFonts.monoBold(9))
            .foregroundStyle(.white.opacity(0.45))
            .opacity(pressStart == nil ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: - 長押しの処理

    /// 押し始めたら、録画も同時に始める(離したときに、写真・動画・捨てるを決める)。
    private func beginHoldIfNeeded() {
        guard pressStart == nil, phase == .ready else { return }
        // 24:00の判定は押し始めた時刻で行う。
        let start = Date()
        guard canBeginExposure(at: start) else { return }
        releaseDecay = nil
        pressStart = start
        resetHoldState(recordingPending: camera.canRecordVideo)
        haptics.beginHold(duration: DailyExposureRules.holdDuration)
        camera.startVideoRecording { clip in
            onClipFinished(clip, start: start)
        }

        holdTask = Task { @MainActor in
            // 1.5秒で写真が決まる(「トン」)
            try? await Task.sleep(for: .seconds(DailyExposureRules.holdDuration))
            guard !Task.isCancelled, pressStart == start else { return }
            fireShutter(start: start)

            // 15秒で自動的に終わる(録画の上限と同じ)
            try? await Task.sleep(for: .seconds(VideoExposureRules.maxDuration - DailyExposureRules.holdDuration))
            guard !Task.isCancelled, pressStart == start else { return }
            settle(start: start, heldFor: VideoExposureRules.maxDuration)
        }

        // 録画の「ふわ」(5秒・10秒)
        for mark in VideoExposureRules.softMarks {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(mark))
                guard pressStart == start, camera.isRecording else { return }
                haptics.fireCapture(intensity: 0.35, sharpness: 0.2)
            }
        }
    }

    /// 途中で離した。1.5秒より前なら何も撮らず元に戻す。1.5秒を過ぎていたら、残すものを決める。
    /// 取り消し(.cancelled)も、離したのと同じに扱う:1.5秒より前なら何も残さず、後なら1.5秒の写真は決まっている。
    private func releaseHold() {
        guard let start = pressStart, phase == .ready else { return }
        guard shutterFired else {
            holdTask?.cancel()
            holdTask = nil
            haptics.cancelHold()
            camera.stopVideoRecording()   // 録画は捨てる(onClipFinished が後始末する)
            beginRelease(from: start)
            return
        }
        settle(start: start, heldFor: Date().timeIntervalSince(start))
    }

    /// 押すのを止めた。ゲージは今の値から、0.3秒でもどる。
    private func beginRelease(from start: Date) {
        let now = Date()
        let from = progress(at: now)
        pressStart = nil
        releaseDecay = ReleaseDecay(start: now, from: from)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Timing.releaseDuration))
            if releaseDecay?.start == now { releaseDecay = nil }
        }
    }

    /// 1.5秒の写真を撮る(「トン」と同時)。
    private func fireShutter(start: Date) {
        guard !shutterFired else { return }
        shutterFired = true
        // 触覚の「パシャ」(強さ0.9・鋭さ0.8)と撮影を同じ瞬間に行う。
        haptics.fireCapture(intensity: 0.9, sharpness: 0.8)
        camera.capturePhoto { data in
            DispatchQueue.main.async {
                stillData = data
                stillCaptured = true
                finishIfReady(start: start)
            }
        }
    }

    /// 離した・15秒になった・録画が途切れた、のどれかで決める。
    private func settle(start: Date, heldFor: TimeInterval) {
        guard !isSettling, !isFinished else { return }
        isSettling = true
        holdTask?.cancel()
        holdTask = nil
        if !shutterFired { fireShutter(start: start) }

        outcome = VideoExposureRules.outcome(heldFor: heldFor, canRecord: camera.canRecordVideo)
        if outcome == .discard {
            // 1.5秒より前(電話で中断された、など):何も残さず元に戻す
            isSettling = false
            camera.stopVideoRecording()
            beginRelease(from: start)
            return
        }
        camera.stopVideoRecording()
        finishIfReady(start: start)
    }

    /// 録画の結果が届いた(止めた時・15秒・中断・失敗のどれでも、必ず1回)。
    private func onClipFinished(_ clip: RecordedClip?, start: Date) {
        recordingPending = false
        // 動画の保存は次の段階で作る。いまは、録れた動画をここで捨てる(写真だけを残す)
        if let clip { try? FileManager.default.removeItem(at: clip.url) }
        if isSettling {
            finishIfReady(start: start)
            return
        }
        // 止めていないのに届いた(中断・15秒)→ そこまでで決める
        guard pressStart == start, phase == .ready else { return }
        settle(start: start, heldFor: clip?.duration ?? Date().timeIntervalSince(start))
    }

    /// 写真と録画の結果がそろったら、預けて、撮ったあとの流れへ。
    private func finishIfReady(start: Date) {
        guard isSettling, !isFinished, stillCaptured, !recordingPending else { return }
        isFinished = true
        handleCapturedData(stillData, start: start)
        presentExposed(start: start)
    }

    private func resetHoldState(recordingPending pending: Bool) {
        shutterFired = false
        stillData = nil
        stillCaptured = false
        recordingPending = pending
        isSettling = false
        isFinished = false
        outcome = .discard
    }

    /// 撮ったあと。成功なら文字なしのアニメ(フィルムを巻く)、失敗なら説明を見せてから閉じる。
    private func presentExposed(start: Date) {
        holdTask = nil
        exposureStart = start

        if phase == .failed {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Timing.failedHold))
                onFinished()
            }
            return
        }

        UIAccessibility.post(notification: .announcement, argument: announcement)
        withAnimation(.easeInOut(duration: 0.15)) {
            phase = .exposed
        }
        afterShotStart = Date()
        playShotFlashAndClose()

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(CaptureAfterShot.duration(reduceMotion: reduceMotion)))
            onFinished()
        }
    }

    /// 撮ったあとの読み上げ(画面には出さない)
    private var announcement: String {
        switch purpose {
        case .daily: return "今日の1枚を預けました。あした9時に撮れます。"
        case .profilePhoto: return "あなたの1枚は、次の9:00に現像されます。"
        }
    }

    private func handleCapturedData(_ data: Data?, start: Date) {
        guard let data else {
            print("[PhotoSave Error] capturePhotoの結果データがnil(撮影自体に失敗)")
            phase = .failed
            return
        }
        let compressed = CapturedImageCompressor.compressedImageData(from: data)
        if !onCaptured(compressed, start, tags, locationProvider.placeName) {
            phase = .failed
        }
    }

    private var failedMessage: String {
        purpose == .daily
            ? "今日の1枚は、まだ撮れます。\n少し時間をおいて、もう一度。"
            : "プロフィールの画像は、\nあとから撮り直せます。"
    }

    // MARK: - 日付の表記

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // 「'26 10 27  18:42」(年・月・日、空白2つ、時刻)
        formatter.dateFormat = "''yy MM dd  HH:mm"
        return formatter
    }()
}

/// 撮影画面の上部の、タグチップの位置(タグ画面から飛んでくる動きの着地点)。
struct CameraTagChipFrameKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

enum ExposurePurpose: Equatable {
    /// 今日の1枚
    case daily
    /// プロフィール画像(次の9:00に現像される)
    case profilePhoto
}

// MARK: - 預けられなかった時の表示(撮影画面と初回設定で共有)

/// 中央にやわらかく光る白い点と、タイトル・説明。
struct ExposedNoticeView: View {
    let title: String
    let message: String
    var footer: String?
    /// 白い点がすっと上に昇って、光の球にとけていく(1.8秒)
    var risesIntoOrb = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDotBright = false
    @State private var hasRisen = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
                .shadow(color: .white.opacity(0.8), radius: 8)
                .opacity(hasRisen ? 0 : (isDotBright ? 1 : 0.7))
                .scaleEffect(hasRisen ? 2.4 : 1)
                .offset(y: hasRisen ? -260 : 0)
                .blur(radius: hasRisen ? 6 : 0)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.04 * 28)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.top, 24)

            Text(message)
                .font(.system(size: 14))
                .tracking(-0.01 * 14)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hex: "BCBBC0"))
                .padding(.top, 12)

            Spacer()

            if let footer {
                Text(footer)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.32))
                    .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .onAppear {
            // ゆっくり呼吸するように、ごくわずかに明滅する(速くしない)。
            guard !reduceMotion else { return }
            if risesIntoOrb {
                withAnimation(.timingCurve(0.5, 0, 0.3, 1, duration: 1.8).delay(0.3)) { hasRisen = true }
                return
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                isDotBright = true
            }
        }
    }
}

// MARK: - フィルムのグレイン

/// 画面に薄く重ねる固定のグレイン(動かさない)。ノイズ画像は一度だけ作って使い回し、
/// リアルタイムにフィルターはかけない。
struct FilmGrainOverlay: View {
    var opacity: Double = 0.5
    var blendMode: BlendMode = .overlay

    private static let noiseImage: UIImage = {
        let side = 160
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return format
        }())
        return renderer.image { context in
            var generator = SystemRandomNumberGenerator()
            for y in 0..<side {
                for x in 0..<side {
                    let white = CGFloat(Double.random(in: 0...1, using: &generator))
                    context.cgContext.setFillColor(UIColor(white: white, alpha: 1).cgColor)
                    context.cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }()

    var body: some View {
        Image(uiImage: Self.noiseImage)
            .resizable(resizingMode: .tile)
            .blendMode(blendMode)
            .opacity(opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

#Preview("撮影画面") {
    ExposureCameraView(
        shotsToday: 0,
        onCaptured: { _, _, _, _ in true },
        onFinished: {},
        onClose: {}
    )
}
