// CaptureFlow.swift
// 「今日を撮る」から開く流れ。タグ → 撮影 → 撮影後 を1つの入れ物で動かす(Step の持ち主はここだけ)。
// 撮影の前に、撮影画面へ直接飛ばさない(入口はかならずタグ画面)。
//
// つながる動き(9章)
// ③ タグ → 撮影:プレビュー帯のコピーが、そのままファインダーの大きさにひろがる
// ⑤ 撮る瞬間(v18.2):ブリンク → フラッシュ → ミルク色のチェキ → 0.78秒でホームへ引きつぎ、物干しへ とぶ(ShotLanding.swift)
// 動きの途中のタップは無視する(navBusy)。戻る・閉じるは、いつでもすぐ反応する。
// 画面を閉じたら(onDisappear)、かならずカメラを止める(緑の点が消える)。

import SwiftUI
import UIKit

struct CaptureFlow: View {
    enum Step {
        case tags
        case capture
    }

    /// 今日、すでに撮った数(ホームの「のこり○こま」と同じ元データ)
    var shotsToday: Int = 0
    /// タグの画面・撮影画面の「戻る」(Home に戻る)
    var onCancel: () -> Void = {}
    /// 撮影後の動きが終わった。撮った写真(日付スタンプは焼きつけない)・タグ(# なし 0〜2個)・
    /// 場所(市区町村。取れなければ nil)・その日の何こめか(1〜3)
    /// 呼ばれるのは1回だけ。アバターに届いた瞬間(途中で閉じても・背面でも、かならず1回)。ここで保存する。画面はまだ閉じない
    var onFinish: (_ photo: UIImage, _ tags: [String], _ place: String?, _ shotIndex: Int) -> Void = { _, _, _, _ in }
    /// v18.2:撮ったチェキを、ホームへ引きつぐ(0.78秒。ここから先はホームが物干しへ とばす)
    var onShot: (ShotHandOff) -> Void = { _ in }
    /// 撮れなかった(写真が返らなかった)
    var onCaptureFailed: () -> Void = {}
    /// v20:録った動画(1秒以上)。保存だけ行う
    var onFinishVideo: (_ video: RecordedVideo, _ tags: [String], _ place: String?, _ shotIndex: Int) -> Void = { _, _, _, _ in }

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: Step = .tags
    @StateObject private var camera = CaptureCameraModel()
    @StateObject private var placeProvider = CapturePlaceProvider()
    @State private var haptics = ExposureHaptics()

    /// タグ画面で選んでいるタグ(その日の下書き。2こめ以降も最初から選ばれている)
    @State private var tags: [String] = []
    @State private var draftLoaded = false
    /// この1枚に付けるタグ(「つけずに撮る」なら空)
    @State private var shotTags: [String] = []
    @State private var isRestTime = false

    // ③ カード → ファインダー
    @State private var cardFrame: CGRect = .zero
    @State private var isLeavingTags = false
    @State private var expandCopy = false
    @State private var expanded = false
    @State private var copyOpacity: Double = 1
    @State private var playsCaptureEntrance = false
    /// 動きの途中のタップを無視する
    @State private var navBusy = false
    @State private var transitionToken = UUID()

    // 撮ったあと(ブリンク → フラッシュ → ミルク色のチェキ)
    @State private var shotStart: Date?
    @State private var shotIsVideo: (Bool, Double?) = (false, nil)
    /// v20:写真 / 動画
    @State private var mode: CaptureMode = .photo

    private var left: Int { FilmRoll.shotsRemaining(shotsToday: shotsToday) }
    private var shotIndex: Int { min(FilmRoll.shotsPerDay, shotsToday + 1) }
    private var colors: CaptureColors { .for(palette) }

    var body: some View {
        GeometryReader { proxy in
            let layout = CaptureLayout(
                size: CGSize(width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
                             height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom),
                safeTop: proxy.safeAreaInsets.top,
                safeBottom: proxy.safeAreaInsets.bottom
            )
            ZStack {
                if isRestTime {
                    restView
                } else {
                    content(layout)
                }
            }
        }
        .onAppear(perform: appear)
        .onDisappear {
            transitionToken = UUID()
            if shotStart != nil {
                // 撮影の途中なら、写真が返ってから止める(保存は写真が返った時点で1回)
                camera.stopWhenIdle()
            } else {
                camera.stop()
            }
            haptics.tearDown()
        }
        .onChange(of: tags) { _, newValue in
            if draftLoaded { TagDraft.save(newValue) }
        }
    }

    @ViewBuilder
    private func content(_ layout: CaptureLayout) -> some View {
        switch step {
        case .tags:
            TagScreen(
                left: left,
                haptics: haptics,
                tags: $tags,
                place: placeProvider.placeName,
                leaving: isLeavingTags,
                hidesCard: expandCopy,
                onCardFrame: { cardFrame = $0 },
                onClose: cancel,
                onStart: { withTags in goCapture(withTags: withTags, layout: layout) }
            )
            .transition(.opacity)
        case .capture:
            ZStack {
                CaptureScreenV21(
                    camera: camera,
                    layout: layout,
                    tags: shotTags,
                    place: placeProvider.placeName,
                    left: left,
                    playsEntrance: playsCaptureEntrance,
                    mode: $mode,
                    onBack: cancel,
                    onEditTags: backToTags,
                    onPhoto: { shutter(layout: layout) },
                    onRecorded: { video in recorded(video, layout: layout) }
                )
                .allowsHitTesting(step == .capture && shotStart == nil)
                if expandCopy {
                    cardCopy(layout)
                }
                if let shotStart {
                    ShotSequenceOverlay(
                        start: shotStart,
                        finder: layout.finder,
                        center: CGPoint(x: layout.finder.midX, y: layout.finder.midY),
                        isVideo: shotIsVideo.0,
                        duration: shotIsVideo.1,
                        flashOn: false,
                        reduceMotion: reduceMotion
                    )
                }
            }
            .transition(.opacity)
        }
        if step == .tags && expandCopy {
            cardCopy(layout)
        }
    }

    /// ひろがるカードのコピー(画面の最上位。もとのカードは動かさない)
    private func cardCopy(_ layout: CaptureLayout) -> some View {
        let rect = expanded ? layout.finder : cardFrame
        let slots: [TagPreviewCard.Slot] = (0..<TagRules.maxCount).map { index in
            index < shotTags.count ? .tag(shotTags[index]) : .empty
        }
        return TagPreviewCard(
            colors: colors,
            place: placeProvider.placeName,
            slots: expanded ? shotTags.map { .tag($0) } : slots,
            showsLabel: !expanded,
            reduceMotion: true
        )
        .frame(width: rect.width, height: rect.height)
        .clipShape(RoundedRectangle(cornerRadius: expanded ? 28 : 24, style: .continuous))
        .position(x: rect.midX, y: rect.midY)
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .ignoresSafeArea()
        .opacity(copyOpacity)
        .allowsHitTesting(false)
    }

    private var restView: some View {
        ZStack(alignment: .topLeading) {
            colors.bg.color.ignoresSafeArea()
            VStack(spacing: 10) {
                Text("おやすみの時間")
                    .font(CaptureFont.heading(26))
                Text("9:00 になると、また撮れます")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(colors.sub.color)
            }
            .foregroundStyle(colors.ink.color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(action: cancel) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(colors.ink.color)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(colors.fill.color))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("戻る")
            .padding(.leading, 20)
            .padding(.top, 4)
        }
    }

    // MARK: 流れ

    private func appear() {
        haptics.prepare()
        if CaptureClock.isRestTime() {
            isRestTime = true
            haptics.playSoftDouble()
            return
        }
        // 下書きの読み込み・場所の取得は、画面を出したあとに行う
        DispatchQueue.main.async {
            if !draftLoaded {
                tags = TagDraft.load()
                draftLoaded = true
            }
            placeProvider.request()
        }
    }

    /// 「撮影へ」「つけずに撮る」:カードがファインダーにひろがって、撮影画面へ(約1.0秒)
    private func goCapture(withTags: Bool, layout: CaptureLayout) {
        guard !navBusy, step == .tags else { return }
        if CaptureClock.isRestTime() {
            isRestTime = true
            haptics.playSoftDouble()
            return
        }
        guard left > 0 else {
            haptics.playSoftDouble()
            return
        }
        navBusy = true
        shotTags = withTags ? tags : []
        camera.start()   // 映像が早く来るよう、ひろがり始めに起動する(sessionQueue で)

        let token = UUID()
        transitionToken = token
        func after(_ seconds: Double, _ work: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                guard transitionToken == token else { return }
                work()
            }
        }

        if reduceMotion || cardFrame == .zero {
            // ひろがらず、クロスフェード(250ms)
            playsCaptureEntrance = false
            withAnimation(.easeInOut(duration: 0.25)) { step = .capture }
            after(0.25) { navBusy = false }
            return
        }

        playsCaptureEntrance = true
        copyOpacity = 1
        expanded = false
        expandCopy = true
        isLeavingTags = true
        DispatchQueue.main.async {
            withAnimation(FlowMotion.io(0.56)) { expanded = true }
        }
        after(0.52) {
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { step = .capture }
        }
        after(0.7) {
            withAnimation(.easeOut(duration: 0.32)) { copyOpacity = 0 }
        }
        after(1.02) {
            expandCopy = false
            expanded = false
            isLeavingTags = false
            navBusy = false
        }
    }

    /// 長押しが 1.0 になった / 音量ボタン2回 / VoiceOver の操作。
    /// 撮った写真は一度も見せない:ブリンク → フラッシュ → ミルク色のチェキに入れかえ、0.78秒でホームへ引きつぐ。
    /// 保存は、写真が返った時点で1回だけ(見せる動きとは つなげない)
    private func shutter(layout: CaptureLayout) {
        guard step == .capture, shotStart == nil else { return }
        transitionToken = UUID()
        expandCopy = false
        let number = shotIndex   // 保存のあと shotsToday が変わっても、この1枚の番号は変えない
        let tags = shotTags
        let places = placeProvider
        let finish = onFinish
        let failed = onCaptureFailed
        let camera = camera
        camera.takePhoto { shot in
            if let shot {
                ShotEncoder.prepare(shot.full, sourceData: shot.sourceData)   // 保存の重い処理を、もう始める
                finish(shot.full, tags, places.placeName, number)
            } else {
                failed()
            }
            camera.stopWhenIdle()
        }
        Haptics.play(.shutter)
        shotStart = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + ShotTiming.pop) { Haptics.play(.pop) }
        let finder = layout.finder
        let rect = CGRect(x: finder.midX - ShotTiming.chekiSize.width / 2, y: finder.midY - ShotTiming.chekiSize.height / 2,
                          width: ShotTiming.chekiSize.width, height: ShotTiming.chekiSize.height)
        let handOff = onShot
        DispatchQueue.main.asyncAfter(deadline: .now() + ShotTiming.handOff) {
            handOff(ShotHandOff(rect: rect, index: number - 1, isVideo: false, duration: nil))
        }
    }

    /// タグのカプセルをタップ:タグ画面へもどる(なおす)
    private func backToTags() {
        guard shotStart == nil else { return }
        withAnimation(.easeOut(duration: 0.3)) { step = .tags }
    }

    /// v20:録った動画(1秒以上)。保存は今すぐ(見せる動きとは つなげない)。見た目は穴あきのミルク色のチェキで、ホームへ
    private func recorded(_ video: RecordedVideo, layout: CaptureLayout) {
        guard shotStart == nil else { return }
        let number = shotIndex
        onFinishVideo(video, shotTags, placeProvider.placeName, number)
        shotIsVideo = (true, video.duration)
        shotStart = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + ShotTiming.pop) { Haptics.play(.pop) }
        let finder = layout.finder
        let rect = CGRect(x: finder.midX - ShotTiming.chekiSize.width / 2, y: finder.midY - ShotTiming.chekiSize.height / 2,
                          width: ShotTiming.chekiSize.width, height: ShotTiming.chekiSize.height)
        let handOff = onShot
        DispatchQueue.main.asyncAfter(deadline: .now() + ShotTiming.handOff) {
            handOff(ShotHandOff(rect: rect, index: number - 1, isVideo: true, duration: video.duration))
        }
    }

    /// 戻る・閉じる:動きの途中でも、すぐやめて Home へ
    private func cancel() {
        transitionToken = UUID()
        navBusy = false
        camera.stop()
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        onCancel()
    }
}
