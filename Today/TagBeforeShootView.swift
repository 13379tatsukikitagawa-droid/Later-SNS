import SwiftUI

/// 撮影前のタグ画面。Laterにはキャプションが無く、かわりに撮る前に「今日」にタグをつける。
/// 主役は自由に書くこと(入力の枠)。川(おすすめ)は、書けない時のヒントにすぎない。
/// 毎日使う画面なので、3秒で終わることを優先し、演出はフェードと小さな動きだけにする。
struct TagBeforeShootView: View {
    @Binding var tags: [String]
    /// 値が変わるたびにキーボードを開き直す(撮影画面から戻った時)
    let focusTrigger: Int
    let onClose: () -> Void
    /// 「撮影へ」「タグなしで撮る」。チップの位置(飛ぶ動きの出発点)を渡す。
    let onProceed: (_ chipFrames: [String: CGRect]) -> Void

    static let coordinateSpace = "shootFlow"
    private let suggestions: TagSuggestionProvider = BundledTagSuggestionProvider()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 27

    @State private var inputText = ""
    @State private var haptics = ExposureHaptics()
    @State private var chipFrames: [String: CGRect] = [:]
    @State private var inputFrame: CGRect = .zero
    @State private var flights: [TagFlight] = []
    /// 飛んでいる途中のタグ(枠の中のチップは、着地するまで見せない)
    @State private var landing: Set<String> = []
    @State private var bounce: [String: Int] = [:]
    @State private var notice: String?
    @State private var noticeTask: Task<Void, Never>?
    @State private var shakeCount = 0
    @State private var isBreathing = false
    @State private var exampleIndex = 0
    @State private var isExampleVisible = true
    @State private var hintIndex = 0
    @State private var isProceeding = false

    private static let examples = ["雨の日", "帰り道", "机の上", "朝ごはん", "夕焼け", "ひとりの時間"]
    private static let hints = ["空白か改行で、タグになります", "場所や名前は書かないでください"]

    private var isFull: Bool { tags.count >= ShootTagRules.maxTags }
    private var hasContent: Bool { !tags.isEmpty || !inputText.isEmpty }
    private var selectedKeys: Set<String> { Set(tags.map { ShootTagRules.key($0) }) }

    private var candidates: [String] {
        let prefix = inputText.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
        guard !prefix.isEmpty else { return [] }
        var result: [String] = []
        for tag in ShootTagHistory.candidates(matching: prefix) + suggestions.candidates(matching: prefix) {
            let key = ShootTagRules.key(tag)
            if !result.contains(where: { ShootTagRules.key($0) == key }) && !selectedKeys.contains(key) {
                result.append(tag)
            }
        }
        return Array(result.prefix(6))
    }

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let showsRivers = height >= 380
            let showsSecondRiver = height >= 455
            VStack(alignment: .leading, spacing: 0) {
                closeButton
                    .padding(.leading, 20)

                Text("今日を撮る前に")
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(0.14 * 10)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 15)
                    .padding(.horizontal, 28)
                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)

                Text("今日を、ひとことで。")
                    .font(.system(size: titleSize, weight: .semibold))
                    .tracking(-0.045 * titleSize)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 8)
                    .padding(.horizontal, 28)
                    .accessibilityAddTraits(.isHeader)

                inputPanel
                    .padding(.top, 20)
                    .padding(.horizontal, 28)
                    .modifier(ShakeEffect(animatableData: CGFloat(shakeCount)))

                Text(notice ?? " ")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .frame(maxWidth: .infinity)
                    .opacity(notice == nil ? 0 : 1)
                    .animation(.easeOut(duration: 0.2), value: notice)
                    .frame(height: 18)
                    .padding(.top, 2)

                if showsRivers {
                    riversArea(showsSecond: showsSecondRiver)
                }
                Spacer(minLength: 0)
            }
            .frame(width: proxy.size.width, alignment: .leading)
        }
        .background(alignment: .top) { topGlow }
        .background(Color.black.ignoresSafeArea())
        .overlay {
            FilmGrainOverlay(opacity: 0.05, blendMode: .normal)
                .ignoresSafeArea()
        }
        .overlay { flightLayer }
        .onPreferenceChange(TagChipFrameKey.self) { frames in
            chipFrames = frames
            launchPendingFlights()
        }
        .onPreferenceChange(TagInputFrameKey.self) { inputFrame = $0 }
        .onAppear {
            haptics.prepare()
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { isBreathing = true }
            }
        }
        .task { await rotateExamplesAndHints() }
        .onChange(of: candidates.isEmpty) { _, isEmpty in
            guard !isEmpty, voiceOverEnabled else { return }
            UIAccessibility.post(notification: .announcement, argument: "候補 \(candidates.count)件")
        }
    }

    // MARK: - 上部

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(LinearGradient(colors: [.white.opacity(0.13), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom)))
                .overlay(Circle().strokeBorder(.white.opacity(0.09), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("閉じる")
    }

    private var topGlow: some View {
        GeometryReader { proxy in
            Ellipse()
                .fill(RadialGradient(colors: [.white.opacity(0.12), .clear], center: .center, startRadius: 0, endRadius: proxy.size.width * 0.62))
                .frame(width: proxy.size.width * 1.4, height: 420)
                .position(x: proxy.size.width / 2, y: -25)
        }
        .frame(height: 420)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - 入力の枠(主役)

    private var inputPanel: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            chipRow
                .frame(height: 34)
                .padding(.top, 14)

            inputRow
                .frame(height: 44)
                .padding(.top, 16)

            Spacer(minLength: 0)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(tags.count) / \(ShootTagRules.maxTags)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color(hex: "8E8E93"))
                    Text(Self.hints[hintIndex])
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(Color(hex: "6B6B70"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .id(hintIndex)
                        .transition(.opacity)
                }
                .dynamicTypeSize(...DynamicTypeSize.large)
                .accessibilityElement(children: .combine)
                Spacer(minLength: 8)
                ctaButton
            }
            .padding(.bottom, 14)
        }
        .padding(.horizontal, 18)
        .frame(height: 160)
        .background(shape.fill(LinearGradient(colors: [.white.opacity(0.10), .white.opacity(0.045)], startPoint: .top, endPoint: .bottom)))
        .overlay(shape.strokeBorder(.white.opacity(isBreathing ? 0.32 : 0.18), lineWidth: 1))
        .overlay(alignment: .top) {
            Capsule().fill(.white.opacity(0.2)).frame(height: 1).padding(.horizontal, 26)
        }
        .shadow(color: .white.opacity(isBreathing ? 0.12 : 0.07), radius: 20)
        .shadow(color: .black.opacity(0.5), radius: 16, y: 10)
    }

    private var chipRow: some View {
        HStack(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                TagChip(tag: tag, bounceTrigger: bounce[tag] ?? 0) { remove(tag) }
                    .opacity(landing.contains(tag) ? 0 : 1)
                    .background(GeometryReader { geometry in
                        Color.clear.preference(key: TagChipFrameKey.self, value: [tag: geometry.frame(in: .named(Self.coordinateSpace))])
                    })
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputRow: some View {
        HStack(alignment: .center, spacing: 4) {
            Text("#")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color(hex: "6B6B70"))
                .accessibilityHidden(true)
            ZStack(alignment: .leading) {
                if isFull {
                    Text("3つまでです")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color(hex: "6B6B70"))
                        .accessibilityHidden(true)
                } else if inputText.isEmpty {
                    Text(Self.examples[exampleIndex])
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.white.opacity(0.22))
                        .opacity(isExampleVisible ? 1 : 0)
                        .lineLimit(1)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
                TagInputField(
                    text: $inputText,
                    isFull: isFull,
                    focusTrigger: focusTrigger,
                    accessibilityLabel: "タグを入力。#のあとに言葉を書く。いま \(tags.count)個、最大\(ShootTagRules.maxTags)個",
                    onCommit: { raw in commitInput(raw) },
                    onPaste: { parts in pasteTags(parts) },
                    onRejectedWhileFull: { reject(.full) }
                )
                .opacity(isFull ? 0.02 : 1)
                .background(GeometryReader { geometry in
                    Color.clear.preference(key: TagInputFrameKey.self, value: geometry.frame(in: .named(Self.coordinateSpace)))
                })
            }
        }
    }

    private var ctaButton: some View {
        Button(action: proceed) {
            HStack(spacing: 7) {
                if hasContent {
                    ZStack {
                        Circle().strokeBorder(.black, lineWidth: 1.5).frame(width: 14, height: 14)
                        Circle().fill(.black).frame(width: 6, height: 6)
                    }
                    .accessibilityHidden(true)
                }
                Text(hasContent ? "撮影へ" : "タグなしで撮る")
                    .font(.system(size: 14.5, weight: .bold))
                    .tracking(-0.025 * 14.5)
                    .lineLimit(1)
            }
            .foregroundStyle(hasContent ? Color.black : Color.white)
            .padding(.horizontal, 18)
            .frame(height: 42)
            .background(Capsule().fill(hasContent ? Color.white : Color.white.opacity(0.12)))
            .shadow(color: .white.opacity(hasContent ? 0.2 : 0), radius: 14)
            .animation(.easeInOut(duration: 0.25), value: hasContent)
        }
        .buttonStyle(ShrinkPressStyle(scale: 0.96))
        .disabled(isProceeding)
        .accessibilityLabel(hasContent ? "撮影へ" : "タグなしで撮る")
    }

    // MARK: - 川・候補

    @ViewBuilder
    private func riversArea(showsSecond: Bool) -> some View {
        let isTyping = !inputText.isEmpty
        VStack(alignment: .leading, spacing: 0) {
            riverHeading(isTyping ? "候補" : "いま、よく選ばれている")
                .padding(.top, 4)
            Group {
                if isTyping {
                    candidateRow
                } else {
                    TagRiver(
                        items: suggestions.popularTags().map { .tag($0) },
                        period: 46,
                        direction: -1,
                        selectedKeys: selectedKeys,
                        isDimmed: isFull,
                        onTap: riverTapped
                    )
                }
            }
            .frame(height: 44)
            .padding(.top, 6)
            .transition(.opacity)

            if showsSecond && !isTyping {
                let recent = ShootTagHistory.recent
                let last = ShootTagHistory.last
                if !recent.isEmpty || !last.isEmpty {
                    riverHeading("最近つかった・あなたのタグ")
                        .padding(.top, 14)
                    TagRiver(
                        items: (last.isEmpty ? [] : [.repeatLast]) + recent.map { .tag($0) },
                        period: 38,
                        direction: 1,
                        selectedKeys: selectedKeys,
                        isDimmed: isFull,
                        onTap: riverTapped
                    )
                    .frame(height: 44)
                    .padding(.top, 6)
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isTyping)
    }

    private func riverHeading(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9.5, design: .monospaced))
            .foregroundStyle(Color(hex: "6B6B70"))
            .padding(.horizontal, 28)
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .accessibilityAddTraits(.isHeader)
    }

    private var candidateRow: some View {
        HStack(spacing: 8) {
            ForEach(candidates, id: \.self) { candidate in
                GlassTagChip(title: "#\(candidate)", isSelected: false)
                    .overlay(GeometryReader { geometry in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                inputText = ""
                                addTag(candidate, from: geometry.frame(in: .named(Self.coordinateSpace)))
                            }
                    })
                    .accessibilityElement()
                    .accessibilityLabel("#\(candidate)")
                    .accessibilityHint("ダブルタップで追加")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { inputText = ""; addTag(candidate, from: nil) }
            }
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    private func riverTapped(_ item: TagRiverItem, frame: CGRect) {
        switch item {
        case .tag(let tag):
            guard !selectedKeys.contains(ShootTagRules.key(tag)) else { return }
            addTag(tag, from: frame)
        case .repeatLast:
            repeatLastTags(from: frame)
        }
    }

    // MARK: - 飛ぶ動き

    private var flightLayer: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .named(Self.coordinateSpace)).origin
            ZStack(alignment: .topLeading) {
                ForEach(flights) { flight in
                    if let to = flight.to {
                        TagChip(tag: flight.tag, bounceTrigger: 0, onRemove: {})
                            .modifier(ArcFlightEffect(
                                progress: flight.progress,
                                from: CGPoint(x: flight.from.midX - origin.x, y: flight.from.midY - origin.y),
                                to: CGPoint(x: to.midX - origin.x, y: to.midY - origin.y),
                                lift: 24,
                                fromScale: 1.1,
                                toScale: 1.0
                            ))
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 枠の中のチップの位置がわかったら、待っているタグを飛ばす(0.42秒、真ん中で24pt持ち上がる)。
    private func launchPendingFlights() {
        for index in flights.indices where flights[index].to == nil {
            guard let target = chipFrames[flights[index].tag] else { continue }
            flights[index].to = target
            let id = flights[index].id
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.42)) {
                    if let i = flights.firstIndex(where: { $0.id == id }) { flights[i].progress = 1 }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.43) { land(flightID: id) }
        }
    }

    private func land(flightID: UUID) {
        guard let index = flights.firstIndex(where: { $0.id == flightID }) else { return }
        let flight = flights.remove(at: index)
        landing.remove(flight.tag)
        bounce[flight.tag, default: 0] += 1
        playLandingHaptic(flight.landingHaptic)
    }

    // MARK: - タグを足す・外す

    /// 入力の行の文字を確定する(リターン・空白・「追加」・CTA)。
    private func commitInput(_ raw: String) {
        guard ShootTagRules.normalize(raw) != nil else { return }
        if addTag(raw, from: inputFrame == .zero ? nil : inputFrame) {
            inputText = ""
        }
    }

    private func pasteTags(_ parts: [String]) {
        for part in parts where !isFull {
            addTag(part, from: inputFrame == .zero ? nil : inputFrame)
        }
    }

    /// 「↺ 前回と同じ」:前回のタグを170msずつずらして、上限まで入れる。
    /// 触覚は最初の着地だけ。3つ満杯になるなら最後の着地だけ強く。
    private func repeatLastTags(from frame: CGRect) {
        let pending = ShootTagHistory.last.filter { !selectedKeys.contains(ShootTagRules.key($0)) }
        let room = ShootTagRules.maxTags - tags.count
        guard room > 0 else {
            reject(.full)
            return
        }
        let toAdd = Array(pending.prefix(room))
        let fills = toAdd.count == room
        for (index, tag) in toAdd.enumerated() {
            let haptic: TagLandingHaptic
            if index == toAdd.count - 1 && fills {
                haptic = .strong
            } else {
                haptic = index == 0 ? .auto : .none
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.17 * Double(index)) {
                addTag(tag, from: frame, haptic: haptic)
            }
        }
    }

    @discardableResult
    private func addTag(_ raw: String, from source: CGRect?, haptic: TagLandingHaptic = .auto) -> Bool {
        guard let tag = ShootTagRules.normalize(raw) else { return false }
        if ShootTagRules.isForbidden(tag) {
            reject(.forbidden)
            return false
        }
        // 同じタグはすでに入っていたら、確定しない(ふるえや音も出さない)。
        if selectedKeys.contains(ShootTagRules.key(tag)) { return true }
        guard !isFull else {
            reject(.full)
            return false
        }
        tags.append(tag)
        ShootTagDraft.save(tags)

        if reduceMotion || source == nil {
            bounce[tag, default: 0] += 1
            playLandingHaptic(haptic)
            return true
        }
        landing.insert(tag)
        flights.append(TagFlight(tag: tag, from: source!, landingHaptic: haptic))
        launchPendingFlights()
        return true
    }

    private func remove(_ tag: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            tags.removeAll { $0 == tag }
        }
        ShootTagDraft.save(tags)
        haptics.playTransient(intensity: ShootTagHaptics.remove.intensity, sharpness: ShootTagHaptics.remove.sharpness)
    }

    private func playLandingHaptic(_ kind: TagLandingHaptic) {
        switch kind {
        case .none:
            return
        case .strong:
            haptics.playTransient(intensity: ShootTagHaptics.landFull.intensity, sharpness: ShootTagHaptics.landFull.sharpness)
        case .auto:
            let value = tags.count >= ShootTagRules.maxTags ? ShootTagHaptics.landFull : ShootTagHaptics.land
            haptics.playTransient(intensity: value.intensity, sharpness: value.sharpness)
        }
    }

    /// 断られた:枠が小さく左右に揺れ、「注意の一言」を1.4秒出し、やわらかく2回。
    private func reject(_ reason: ShootTagRules.Rejection) {
        if !reduceMotion {
            withAnimation(.linear(duration: 0.3)) { shakeCount += 1 }
        }
        showNotice(reason == .full ? "3つまでです" : "使えない言葉です")
        let value = ShootTagHaptics.reject
        haptics.playTransient(intensity: value.intensity, sharpness: value.sharpness)
        DispatchQueue.main.asyncAfter(deadline: .now() + ShootTagHaptics.rejectGap) {
            haptics.playTransient(intensity: value.intensity, sharpness: value.sharpness)
        }
    }

    private func showNotice(_ text: String) {
        noticeTask?.cancel()
        notice = text
        noticeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            notice = nil
        }
    }

    // MARK: - 撮影へ

    /// 入力中の文字が残っていれば、先にタグとして確定してから(飛ぶ動きも出す)0.48秒後に撮影へ。
    private func proceed() {
        guard !isProceeding else { return }
        if !inputText.isEmpty {
            let raw = inputText
            guard ShootTagRules.normalize(raw) != nil else {
                inputText = ""
                onProceed(chipFrames)
                return
            }
            guard addTag(raw, from: inputFrame == .zero ? nil : inputFrame) else { return }
            inputText = ""
            isProceeding = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
                isProceeding = false
                onProceed(chipFrames)
            }
            return
        }
        onProceed(chipFrames)
    }

    // MARK: - 例・ヒントの入れ替え

    private func rotateExamplesAndHints() async {
        var tick = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            tick += 1
            if inputText.isEmpty {
                withAnimation(.easeInOut(duration: 0.5)) { isExampleVisible = false }
                try? await Task.sleep(for: .seconds(0.5))
                exampleIndex = (exampleIndex + 1) % Self.examples.count
                withAnimation(.easeInOut(duration: 0.5)) { isExampleVisible = true }
            }
            if tick % 2 == 0 {
                withAnimation(.easeInOut(duration: 0.5)) { hintIndex = (hintIndex + 1) % Self.hints.count }
            }
        }
    }
}

// MARK: - 確定したタグのチップ

/// 白ベタ・黒文字のチップ。右に小さな「×」。タップで外す。着地の時に小さく弾む。
struct TagChip: View {
    let tag: String
    let bounceTrigger: Int
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 4) {
                Text("#\(tag)")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .frame(width: 15, height: 15)
            }
            .padding(.leading, 13)
            .padding(.trailing, 8)
            .frame(height: 34)
            .background(Capsule().fill(.white))
            .shadow(color: .white.opacity(0.25), radius: 8)
        }
        .buttonStyle(.plain)
        .keyframeAnimator(initialValue: 1.0, trigger: bounceTrigger) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            CubicKeyframe(0.8, duration: 0.01)
            SpringKeyframe(1.0, duration: 0.44, spring: .init(response: 0.32, dampingRatio: 0.55))
        }
        .accessibilityLabel("#\(tag)")
        .accessibilityHint("ダブルタップで外す")
    }
}

/// 川・候補のガラスのチップ(高さ44・左右16pt)。
struct GlassTagChip: View {
    let title: String
    let isSelected: Bool
    var isEmphasized = false

    var body: some View {
        Text(title)
            .font(.system(size: 14.5, weight: .medium))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(
                Capsule().fill(isEmphasized
                    ? AnyShapeStyle(Color.white.opacity(0.1))
                    : AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.13), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom)))
            )
            .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1))
            .opacity(isSelected ? 0.22 : 1)
    }
}

// MARK: - タグの川

enum TagRiverItem: Hashable {
    case tag(String)
    /// 「↺ 前回と同じ」
    case repeatLast
}

/// 横に流れるタグの帯。中身を2回並べて継ぎ目なくループさせる。指で触れているあいだは止まる。
/// Reduce Motionのときは流さず、横にスクロールできるだけの帯にする。
struct TagRiver: View {
    let items: [TagRiverItem]
    /// 半周(トラックの半分)の秒数
    let period: Double
    /// -1:右→左、1:左→右
    let direction: Double
    let selectedKeys: Set<String>
    /// 3つ満杯の時は全体を暗くし、タップしても入らない
    let isDimmed: Bool
    let onTap: (TagRiverItem, CGRect) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var contentWidth: CGFloat = 0
    @State private var phaseBase: Double = 0
    @State private var phaseStart = Date()
    @State private var isTouching = false

    var body: some View {
        Group {
            if reduceMotion {
                ScrollView(.horizontal, showsIndicators: false) {
                    row.padding(.horizontal, 28)
                }
            } else {
                GeometryReader { _ in
                    TimelineView(.animation(paused: isTouching || scenePhase != .active)) { context in
                        let phase = currentPhase(at: context.date)
                        let offset = direction < 0 ? -phase * contentWidth : -(1 - phase) * contentWidth
                        HStack(spacing: 8) {
                            row
                                .background(GeometryReader { geometry in
                                    Color.clear.onAppear { contentWidth = geometry.size.width + 8 }
                                })
                            row.accessibilityHidden(true)
                        }
                        .fixedSize()
                        .offset(x: offset)
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !isTouching else { return }
                            phaseBase = currentPhase(at: Date())
                            isTouching = true
                        }
                        .onEnded { _ in
                            phaseStart = Date()
                            isTouching = false
                        }
                )
            }
        }
        .frame(height: 44)
        .mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0), .init(color: .black, location: 0.09),
                .init(color: .black, location: 0.91), .init(color: .clear, location: 1),
            ], startPoint: .leading, endPoint: .trailing)
        )
        .opacity(isDimmed ? 0.32 : 1)
        .allowsHitTesting(!isDimmed)
        .animation(.easeInOut(duration: 0.25), value: isDimmed)
    }

    private func currentPhase(at date: Date) -> Double {
        if isTouching { return phaseBase }
        let value = phaseBase + date.timeIntervalSince(phaseStart) / period
        return value - floor(value)
    }

    private var row: some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.self) { item in
                chip(item)
            }
        }
    }

    @ViewBuilder
    private func chip(_ item: TagRiverItem) -> some View {
        let (title, isSelected, isEmphasized, label): (String, Bool, Bool, String) = {
            switch item {
            case .tag(let tag):
                let selected = selectedKeys.contains(ShootTagRules.key(tag))
                return ("#\(tag)", selected, false, "#\(tag)")
            case .repeatLast:
                return ("↺ 前回と同じ", false, true, "前回と同じ")
            }
        }()
        GlassTagChip(title: title, isSelected: isSelected, isEmphasized: isEmphasized)
            .overlay(GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !isSelected else { return }
                        onTap(item, geometry.frame(in: .named(TagBeforeShootView.coordinateSpace)))
                    }
            })
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityValue(isSelected ? "選択済み" : "")
            .accessibilityHint(isSelected ? "" : "ダブルタップで追加")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { if !isSelected { onTap(item, .zero) } }
    }
}

// MARK: - 部品

/// 着地の触覚:自動(3つ目ならやや強く)/ 鳴らさない / やや強く
enum TagLandingHaptic {
    case auto, none, strong
}

struct TagFlight: Identifiable {
    let id = UUID()
    let tag: String
    let from: CGRect
    var to: CGRect?
    var progress: Double = 0
    var landingHaptic: TagLandingHaptic = .auto

    init(tag: String, from: CGRect, landingHaptic: TagLandingHaptic = .auto) {
        self.tag = tag
        self.from = from
        self.landingHaptic = landingHaptic
    }
}

/// 弧を描いて飛ぶ(真ん中でliftだけ持ち上がる)。大きさはfromScale→toScale。
struct ArcFlightEffect: ViewModifier, Animatable {
    var progress: Double
    let from: CGPoint
    let to: CGPoint
    let lift: CGFloat
    let fromScale: CGFloat
    let toScale: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let p = CGFloat(progress)
        let x = from.x + (to.x - from.x) * p
        let y = from.y + (to.y - from.y) * p - lift * CGFloat(sin(Double.pi * progress))
        content
            .scaleEffect(fromScale + (toScale - fromScale) * p)
            .position(x: x, y: y)
    }
}

/// 枠が小さく左右に揺れる(±5pt・0.3秒)。
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = 5 * sin(animatableData * .pi * 4)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}

struct ShrinkPressStyle: ButtonStyle {
    let scale: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct TagChipFrameKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct TagInputFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}
