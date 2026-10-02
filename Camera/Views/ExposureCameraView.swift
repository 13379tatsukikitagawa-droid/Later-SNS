import SwiftUI
import UIKit

/// 撮影画面(再設計 Step 1:Opal型・長押し露光)。
///
/// ① 構える … ライブ映像・タグを選ぶ。振動なし
/// ② 長押しで露光 … 約1.5秒の長押しで撮影。円が縮み、周りが絞られ、触覚がだんだん強くなる。
///    途中で離すとキャンセルして元に戻る(撮影しない)
/// ③ 暗転・預ける … 撮った瞬間に画面を黒に落とし、写真は一切見せない
///
/// 撮った写真はプレビューもサムネイルも出さず、その場で保存する(保存はonCaptured)。
struct ExposureCameraView: View {
    /// 今日すでに撮っているか(撮っていればシャッターは押せない)。
    let hasShotToday: Bool
    /// 撮影データ(圧縮済み)・露光を始めた時刻・タグ・地名を渡して保存する。保存できたらtrue。
    let onCaptured: (_ imageData: Data, _ exposureStart: Date, _ tags: [String], _ locationName: String?) -> Bool
    /// 暗転画面を見せ終わった時に呼ぶ(呼び出し側が画面を閉じる)。
    let onFinished: () -> Void
    /// 撮影せずに閉じる。
    let onClose: () -> Void
    /// 何を撮るか。プロフィール画像の撮り直しでも、同じ撮影(長押し・プレビューなし・暗転)を使う。
    var purpose: ExposurePurpose = .daily

    private enum Phase: Equatable {
        case ready
        case exposed
        case failed
    }

    private enum Palette {
        static let subText = Color(hex: "BCBBC0")
        static let surface = Color(hex: "1C1C1E")
        static let stamp = Color(hex: "FF8A3D")
    }

    private enum Timing {
        static let releaseReset: TimeInterval = 0.25
        static let blackout: TimeInterval = 0.3
        static let exposedHold: TimeInterval = 2.5
        static let fadeOut: TimeInterval = 0.6
    }

    @StateObject private var camera = FilmCameraController()
    @StateObject private var locationProvider = CameraLocationNameProvider()
    @State private var haptics = ExposureHaptics()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var tags: [String] = []
    @State private var showingTagPicker = false

    /// 長押しを始めた時刻。nilなら押していない。
    @State private var pressStart: Date?
    /// 押していない間の進み具合(離した時に0へ戻すアニメーションに使う)。
    @State private var restingProgress: Double = 0
    @State private var holdTask: Task<Void, Never>?

    @State private var phase: Phase = .ready
    @State private var exposureStart: Date?
    @State private var isBlackedOut = false
    @State private var isExposedContentVisible = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TimelineView(.animation(paused: pressStart == nil)) { context in
                readyLayout(progress: progress(at: context.date))
            }

            FilmGrainOverlay()
                .ignoresSafeArea()

            if isBlackedOut {
                Color.black
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            if phase != .ready {
                exposedLayout
                    .opacity(isExposedContentVisible ? 1 : 0)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear {
            camera.configure()
            haptics.prepare()
            locationProvider.requestPlaceName()
        }
        .onDisappear {
            holdTask?.cancel()
            haptics.tearDown()
            camera.stopSession()
        }
        .sheet(isPresented: $showingTagPicker) {
            ExposureTagPicker(tags: $tags)
        }
    }

    // MARK: - 進み具合

    private func progress(at date: Date) -> Double {
        guard let pressStart else { return restingProgress }
        return min(1, max(0, date.timeIntervalSince(pressStart) / DailyExposureRules.holdDuration))
    }

    private var canShootNow: Bool {
        canBeginExposure(at: Date())
    }

    /// 今日の1枚は時間帯・1日1枚の判定に従う。プロフィール画像は呼び出し側が回数を判定する。
    private func canBeginExposure(at date: Date) -> Bool {
        switch purpose {
        case .daily: return DailyExposureRules.canBeginExposure(at: date, hasShotToday: hasShotToday)
        case .profilePhoto: return true
        }
    }

    // MARK: - ①② 構える・露光

    private func readyLayout(progress: Double) -> some View {
        let fade = 1 - 0.78 * progress
        return VStack(spacing: 14) {
            header
                .opacity(fade)
            viewfinder(progress: progress)
                .frame(maxHeight: .infinity)
            tagRow
                .opacity(purpose == .daily ? fade : 0)
                .disabled(progress > 0 || purpose != .daily)
            shutter(progress: progress)
                .padding(.top, 4)
            hint(progress: progress)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: ヘッダー

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.subText)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .disabled(pressStart != nil)
            .accessibilityLabel("閉じる")

            Text("Later")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.04 * 22)
                .foregroundStyle(.white)

            Spacer()

            if purpose == .daily {
                lightsOutCapsule
            }
        }
    }

    /// 「消灯まで 05:49」。24:00までの残り時間(時:分)。
    private var lightsOutCapsule: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let label: String = {
                guard let remaining = DailyExposureRules.remainingUntilLightsOut(from: context.date) else { return "消灯中" }
                let minutes = Int(remaining) / 60
                return String(format: "消灯まで %02d:%02d", minutes / 60, minutes % 60)
            }()
            HStack(spacing: 7) {
                Circle()
                    .fill(.white)
                    .frame(width: 5, height: 5)
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .tracking(-0.01 * 12)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Palette.surface))
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: ファインダー

    private func viewfinder(progress: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        return ZStack {
            CameraPreviewRepresentable(session: camera.session)

            irisOverlay(progress: progress)

            CornerBrackets()
                .stroke(.white, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .padding(EdgeInsets(top: 18, leading: 18, bottom: 46, trailing: 18))
                .scaleEffect(1 - 0.1 * progress)

            VStack {
                Spacer()
                HStack(alignment: .lastTextBaseline) {
                    Text("No.01 / 01")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Text(Self.stampLabel(for: Date()))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Palette.stamp)
                        .shadow(color: Palette.stamp.opacity(0.65), radius: 6)
                        .opacity(1 - 0.45 * progress)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 16)
            }
            .accessibilityHidden(true)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.07), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ファインダー")
    }

    /// カメラの絞りのように、周りから暗く絞っていく(中心だけ明るく残る)。
    private func irisOverlay(progress: Double) -> some View {
        GeometryReader { proxy in
            let minSide = min(proxy.size.width, proxy.size.height)
            let maxRadius = hypot(proxy.size.width, proxy.size.height) / 2
            let start = maxRadius + (minSide * 0.16 - maxRadius) * progress
            RadialGradient(
                colors: [.clear, .black],
                center: .center,
                startRadius: max(0, start),
                endRadius: max(0, start) + minSide * 0.35
            )
            .opacity(min(1, progress * 1.4))
        }
        .allowsHitTesting(false)
    }

    // MARK: タグの行

    private var tagRow: some View {
        HStack(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Button {
                    tags.removeAll { $0 == tag }
                } label: {
                    Text("#\(tag)")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(-0.01 * 13)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Palette.surface))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("タグ \(tag)")
                .accessibilityHint("タップで外す")
            }

            if tags.count < DailyExposureRules.maxTags {
                Button {
                    showingTagPicker = true
                } label: {
                    Text("+ タグ")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.subText)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .overlay(
                            Capsule().strokeBorder(Palette.subText.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("タグを追加")
            }

            Spacer(minLength: 0)

            Text("\(tags.count) / \(DailyExposureRules.maxTags)")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(Palette.subText)
                .accessibilityLabel("タグ \(tags.count)個、最大\(DailyExposureRules.maxTags)個")
        }
        .frame(height: 32)
    }

    // MARK: シャッター

    private func shutter(progress: Double) -> some View {
        let innerDiameter = 74 * (1 - progress)
        let isAvailable = canShootNow && phase == .ready
        return ZStack {
            Circle()
                .strokeBorder(.white, lineWidth: 2)
                .frame(width: 92, height: 92)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white, Color(white: 0.86)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: innerDiameter, height: innerDiameter)
                .shadow(color: .white.opacity(0.35 * (1 - progress)), radius: 18)
        }
        .frame(width: 92, height: 92)
        .contentShape(Circle())
        .opacity(isAvailable ? 1 : 0.35)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in beginHoldIfNeeded() }
                .onEnded { _ in releaseHold() }
        )
        .accessibilityElement()
        .accessibilityLabel("長押しで撮影")
        .accessibilityHint(isAvailable ? "ダブルタップしたまま押し続けると、撮影します" : "今は撮影できません")
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(pressStart != nil ? "露光中" : "")
    }

    private func hint(progress: Double) -> some View {
        let text = pressStart == nil
            ? "長押しで、露光する"
            : String(format: "露光 %.2f / %.2fs", progress * DailyExposureRules.holdDuration, DailyExposureRules.holdDuration)
        return Text(text)
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.45))
            .accessibilityHidden(true)
    }

    // MARK: - 長押しの処理

    private func beginHoldIfNeeded() {
        guard pressStart == nil, phase == .ready else { return }
        // 24:00の判定は押し始めた時刻で行う。
        let start = Date()
        guard canBeginExposure(at: start) else { return }
        restingProgress = 0
        pressStart = start
        haptics.beginHold(duration: DailyExposureRules.holdDuration)
        holdTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(DailyExposureRules.holdDuration))
            guard !Task.isCancelled, pressStart == start else { return }
            completeExposure(start: start)
        }
    }

    /// 途中で離した。撮影はキャンセルし、円・絞り・ブラケット・ヘッダーを元に戻す。
    private func releaseHold() {
        guard pressStart != nil, phase == .ready else { return }
        holdTask?.cancel()
        holdTask = nil
        haptics.cancelHold()
        withAnimation(.easeOut(duration: Timing.releaseReset)) {
            pressStart = nil
            restingProgress = 0
        }
    }

    private func completeExposure(start: Date) {
        holdTask = nil
        // 触覚の「くっきり1回」と撮影を同じ瞬間に行う。
        haptics.fireCapture()
        camera.capturePhoto(flashOn: false) { data in
            DispatchQueue.main.async { handleCapturedData(data, start: start) }
        }

        exposureStart = start
        withAnimation(.easeIn(duration: Timing.blackout)) {
            phase = .exposed
            pressStart = nil
            restingProgress = 1
            isBlackedOut = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(Timing.blackout)) {
            isExposedContentVisible = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Timing.blackout + Timing.exposedHold))
            withAnimation(.easeInOut(duration: Timing.fadeOut)) {
                isExposedContentVisible = false
            }
            try? await Task.sleep(for: .seconds(Timing.fadeOut))
            onFinished()
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

    // MARK: - ③ 暗転・預ける

    private var exposedLayout: some View {
        ExposedNoticeView(
            title: phase == .failed ? "預けられませんでした" : "預けました",
            message: exposedMessage,
            footer: phase == .exposed ? exposureStart.map { Self.exposedLabel(for: $0) } : nil
        )
    }

    private var exposedMessage: String {
        switch (purpose, phase == .failed) {
        case (.daily, false): return "今日の1枚は、\n次にあなたが撮った瞬間に、ひらく。"
        case (.daily, true): return "今日の1枚は、まだ撮れます。\n少し時間をおいて、もう一度。"
        case (.profilePhoto, false): return "あなたの1枚は、\n次の 9:00 に現像されます。"
        case (.profilePhoto, true): return "プロフィールの画像は、\nあとから撮り直せます。"
        }
    }

    // MARK: - 日付の表記

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }

    private static let stampFormatter = formatter("''yy MM dd")
    private static let exposedDateFormatter = formatter("MM.dd")
    private static let exposedTimeFormatter = formatter("HH:mm")

    /// 「'26 10 02」
    private static func stampLabel(for date: Date) -> String {
        stampFormatter.string(from: date)
    }

    /// 「EXPOSED · 10.02 · 18:11」
    private static func exposedLabel(for date: Date) -> String {
        "EXPOSED · \(exposedDateFormatter.string(from: date)) · \(exposedTimeFormatter.string(from: date))"
    }
}

enum ExposurePurpose: Equatable {
    /// 今日の1枚
    case daily
    /// プロフィール画像(次の9:00に現像される)
    case profilePhoto
}

// MARK: - 暗転・預ける(撮影画面と初回設定で共有)

/// 撮った瞬間の暗転画面の中身。中央にやわらかく光る白い点と「預けました」、下に等幅の小さな文字。
/// 写真は一切見せない。
struct ExposedNoticeView: View {
    let title: String
    let message: String
    var footer: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDotBright = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
                .shadow(color: .white.opacity(0.8), radius: 8)
                .opacity(isDotBright ? 1 : 0.7)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 27, weight: .bold))
                .tracking(-0.04 * 27)
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
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                isDotBright = true
            }
        }
    }
}

// MARK: - 角ブラケット

/// ファインダー四隅の「 」形のブラケット。角は少しだけ丸める。
private struct CornerBrackets: Shape {
    var armLength: CGFloat = 22
    var cornerRadius: CGFloat = 4

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1),
            (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
            (CGPoint(x: rect.minX, y: rect.maxY), 1, -1),
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1),
        ]
        for (corner, dx, dy) in corners {
            path.move(to: CGPoint(x: corner.x, y: corner.y + dy * armLength))
            path.addLine(to: CGPoint(x: corner.x, y: corner.y + dy * cornerRadius))
            path.addQuadCurve(
                to: CGPoint(x: corner.x + dx * cornerRadius, y: corner.y),
                control: corner
            )
            path.addLine(to: CGPoint(x: corner.x + dx * armLength, y: corner.y))
        }
        return path
    }
}

// MARK: - フィルムのグレイン

/// 画面全体に薄く重ねる固定のグレイン(動かさない)。ノイズ画像は一度だけ作って使い回し、
/// リアルタイムにフィルターはかけない。撮影画面はoverlay合成・0.5、Homeは通常合成・0.05。
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

// MARK: - タグを選ぶ

/// 「みんながよく使うタグ」から選ぶか、自由に入力する。最大DailyExposureRules.maxTags個。
private struct ExposureTagPicker: View {
    @Binding var tags: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @FocusState private var isDraftFocused: Bool

    private static let maxTagLength = 20

    private var isFull: Bool { tags.count >= DailyExposureRules.maxTags }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("タグ")
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.04 * 20)
                Spacer()
                Text("\(tags.count) / \(DailyExposureRules.maxTags)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(hex: "BCBBC0"))
                Button("完了") { dismiss() }
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.leading, 12)
            }

            HStack(spacing: 8) {
                TextField("自由に入力", text: $draft)
                    .focused($isDraftFocused)
                    .submitLabel(.done)
                    .onSubmit(addDraft)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(hex: "1C1C1E")))
                Button("追加", action: addDraft)
                    .font(.system(size: 14, weight: .semibold))
                    .disabled(normalized(draft) == nil || isFull)
            }

            Text("みんながよく使うタグ")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "BCBBC0"))

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(DailyExposureRules.suggestedTags, id: \.self) { tag in
                        let isSelected = tags.contains(tag)
                        Button {
                            toggle(tag)
                        } label: {
                            Text("#\(tag)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isSelected ? .black : .white)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(isSelected ? Color.white : Color(hex: "1C1C1E")))
                        }
                        .buttonStyle(.plain)
                        .disabled(!isSelected && isFull)
                        .opacity(!isSelected && isFull ? 0.4 : 1)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
        }
        .padding(20)
        .foregroundStyle(.white)
        .tint(.white)
        .presentationDetents([.medium])
        .presentationBackground(.black)
        .preferredColorScheme(.dark)
    }

    private func normalized(_ text: String) -> String? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasPrefix("#") || value.hasPrefix("＃") {
            value.removeFirst()
        }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return String(value.prefix(Self.maxTagLength))
    }

    private func addDraft() {
        guard let tag = normalized(draft), !isFull else { return }
        if !tags.contains(tag) {
            tags.append(tag)
        }
        draft = ""
    }

    private func toggle(_ tag: String) {
        if let index = tags.firstIndex(of: tag) {
            tags.remove(at: index)
        } else if !isFull {
            tags.append(tag)
        }
    }
}

#Preview("撮影画面") {
    ExposureCameraView(
        hasShotToday: false,
        onCaptured: { _, _, _, _ in true },
        onFinished: {},
        onClose: {}
    )
}
