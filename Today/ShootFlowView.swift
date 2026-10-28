import SwiftUI
import UIKit

/// Homeの「今日を撮る」から開く、撮影までの流れ:タグ画面 → 撮影画面(Step 1)。
/// 2つの画面を1つのフルスクリーンの中で切り替える(画面を重ねて開かない)。
/// 「撮影へ」を押すと、枠の中のチップが撮影画面の下の段へ飛んでいき(0.52秒、60msずつずらす)、
/// タグ画面はフェードアウト・撮影画面はフェードイン(0.45秒)。撮影画面の「←」で戻ってタグを直せる。
struct ShootFlowView: View {
    /// 今日すでに撮った枚数(3こままで)
    let shotsToday: Int
    /// 月がふくらんで開いた時の、タグ画面の各要素をずらして入れる演出の遅れ(nilなら演出なし)
    var entranceDelay: Double?
    /// 撮った1枚を保存する(タグはこの画面で決めたもの)。保存できたらtrue。
    let onCaptured: (_ imageData: Data, _ exposureStart: Date, _ tags: [String], _ locationName: String?) -> Bool
    let onFinished: () -> Void
    let onClose: () -> Void

    private enum Stage {
        case tags, camera
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    /// アプリで1つのカメラ。タグ画面が開いた時から動かし(先ごしらえ)、ここを離れる時に止める。
    private let camera = FilmCameraController.shared

    @State private var stage: Stage = .tags
    /// 同じ日のあいだは下書きとして残す(Homeから入り直したら復元)。
    @State private var tags: [String] = ShootTagDraft.load()
    @State private var isCameraMounted = false
    @State private var tagScreenOpacity = 1.0
    @State private var cameraOpacity = 0.0
    @State private var focusTrigger = 0
    @State private var sourceFrames: [String: CGRect] = [:]
    @State private var isAwaitingTargets = false
    @State private var hidesCameraTags = false
    @State private var flights: [ShootChipFlight] = []

    var body: some View {
        ZStack {
            TagBeforeShootView(
                tags: $tags,
                focusTrigger: focusTrigger,
                entranceDelay: entranceDelay,
                onClose: onClose,
                onProceed: goToCamera
            )
            .opacity(tagScreenOpacity)
            .allowsHitTesting(stage == .tags)

            if isCameraMounted {
                ExposureCameraView(
                    shotsToday: shotsToday,
                    onCaptured: { data, start, _, locationName in
                        let saved = onCaptured(data, start, tags, locationName)
                        if saved {
                            // 撮影が完了したら下書きを捨て、タグを履歴に残す(失敗した時は下書きを残す)。
                            ShootTagDraft.clear()
                            ShootTagHistory.record(tags)
                        }
                        return saved
                    },
                    onFinished: onFinished,
                    onClose: backToTags,
                    presetTags: tags,
                    hidesPresetTags: hidesCameraTags,
                    managesSession: false
                )
                .opacity(cameraOpacity)
                .allowsHitTesting(stage == .camera)
            }

            flightLayer
        }
        .coordinateSpace(.named(TagBeforeShootView.coordinateSpace))
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            // タグ画面が開いたら、撮影のセッションを先に起こしておく(キューに積むだけ。ブロックしない)
            camera.useBackCameraIfNeeded()
            camera.configure()
        }
        .onDisappear { camera.stopSession() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { camera.resumeIfNeeded() }
        }
        .onPreferenceChange(CameraTagChipFrameKey.self) { targets in
            // 撮影画面には、タグを最大2つ・場所1つまでチップで見せる。届いたものから飛ばす。
            guard isAwaitingTargets, !targets.isEmpty else { return }
            launchFlights(to: targets)
        }
    }

    // MARK: - タグ画面 → 撮影画面

    private func goToCamera(_ chipFrames: [String: CGRect]) {
        // タグ画面のキーボードを閉じてから撮影画面へ。
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        sourceFrames = chipFrames
        stage = .camera
        isCameraMounted = true
        withAnimation(.easeInOut(duration: reduceMotion ? 0.25 : 0.45)) {
            tagScreenOpacity = 0
            cameraOpacity = 1
        }
        guard !tags.isEmpty, !reduceMotion else { return }
        hidesCameraTags = true
        isAwaitingTargets = true
        // 撮影画面のチップの位置がわからないまま時間が過ぎたら、飛ばさずにそのまま出す。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard isAwaitingTargets else { return }
            isAwaitingTargets = false
            hidesCameraTags = false
        }
    }

    private func launchFlights(to targets: [String: CGRect]) {
        isAwaitingTargets = false
        flights = tags.compactMap { tag in
            guard let from = sourceFrames[tag], let to = targets[tag] else { return nil }
            return ShootChipFlight(tag: tag, from: from, to: to)
        }
        guard !flights.isEmpty else {
            hidesCameraTags = false
            return
        }
        for (index, flight) in flights.enumerated() {
            withAnimation(.easeInOut(duration: 0.52).delay(0.06 * Double(index))) {
                if let i = flights.firstIndex(where: { $0.id == flight.id }) { flights[i].progress = 1 }
            }
        }
        let total = 0.52 + 0.06 * Double(flights.count - 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            hidesCameraTags = false
            flights = []
        }
    }

    // MARK: - 撮影画面 → タグ画面(撮影前ならタグを直せる)

    private func backToTags() {
        stage = .tags
        flights = []
        hidesCameraTags = false
        withAnimation(.easeInOut(duration: reduceMotion ? 0.25 : 0.45)) {
            tagScreenOpacity = 1
            cameraOpacity = 0
        }
        focusTrigger += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
            if stage == .tags { isCameraMounted = false }
        }
    }

    // MARK: - 飛ぶチップ

    private var flightLayer: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .named(TagBeforeShootView.coordinateSpace)).origin
            ZStack(alignment: .topLeading) {
                ForEach(flights) { flight in
                    MorphingTagChip(tag: flight.tag, progress: flight.progress, from: flight.from, to: flight.to, origin: origin)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ShootChipFlight: Identifiable {
    let id = UUID()
    let tag: String
    let from: CGRect
    let to: CGRect
    var progress: Double = 0
}

/// タグ画面の白いチップから、撮影画面の暗いチップ(#1C1C1E・白文字)へ、大きさと色を変えながら飛ぶ。
private struct MorphingTagChip: View, Animatable {
    let tag: String
    var progress: Double
    let from: CGRect
    let to: CGRect
    let origin: CGPoint

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let p = CGFloat(progress)
        let width = from.width + (to.width - from.width) * p
        let height = from.height + (to.height - from.height) * p
        let x = from.midX + (to.midX - from.midX) * p - origin.x
        let y = from.midY + (to.midY - from.midY) * p - origin.y - 16 * CGFloat(sin(Double.pi * progress))
        ZStack {
            Capsule().fill(Color.white).opacity(1 - progress)
            Capsule().fill(Color(hex: "1C1C1E")).opacity(progress)
            Text("#\(tag)")
                .font(.system(size: 13.5 - 0.5 * p, weight: progress < 0.5 ? .bold : .medium))
                .foregroundStyle(progress < 0.5 ? Color.black : Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 10)
        }
        .frame(width: width, height: height)
        .position(x: x, y: y)
    }
}
