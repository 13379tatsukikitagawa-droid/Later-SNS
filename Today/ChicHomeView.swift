import SwiftUI

/// 白 × シックの Home(撮る前の今日のホーム:first・dawn と、月が出る夜の night・rest)。
/// HomeView が、この状態のときだけ表示をこの View にゆずる。状態・時刻・操作は HomeView と同じものを受け取る。
/// 位置は上から順に積み(ヘッダー → 輪 → 見出し → カード → ボタン → 月のぶんの余白)、
/// 背の低い端末では輪を縮めて収める。
struct ChicHomeView: View {
    let state: HomeState
    let now: Date
    let light: YesterdayLight
    let developContent: HomeDevelopCard.Content
    let developTexture: UIImage?
    var shotsToday = 0
    let tones: [Color]
    let groupSummaries: [GroupSummary]
    let canCreateGroup: Bool
    let isCovered: Bool
    let avatarImage: UIImage?
    let avatarSeed: UUID?
    let showsAvatarBadge: Bool
    let onOpenProfile: () -> Void
    var avatarSwitch = AvatarSwitch()
    var avatarName = ""
    let onDevelopTap: () -> Void
    let onSelectGroup: (UUID) -> Void
    let onCreateGroup: () -> Void
    var onJoinGroup: () -> Void = {}
    var onAddGroup: () -> Void = {}
    var arrivingGroupID: UUID?
    var launch: LaunchFrame = .finished
    var onOrbTap: () -> Void = {}
    var isDiving = false

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.selectedMainTabIndex) private var selectedMainTabIndex
    @State private var isOnScreen = false
    @State private var showsLights = false

    private static let homeTabIndex = 0
    /// 月の見えている高さ(84)+ 余白
    private static let moonReserve: CGFloat = 98

    private var isVisible: Bool {
        isOnScreen && scenePhase == .active && selectedMainTabIndex == Self.homeTabIndex && !isCovered
    }

    private func toggleLights() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.8)) { showsLights.toggle() }
    }

    private var motionOn: Bool { isVisible && HomeMotion.ambientAllowed(reduceMotion: reduceMotion) }

    var body: some View {
        GeometryReader { proxy in
            let fullHeight = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            let width = proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing
            let top = max(proxy.safeAreaInsets.top, 44)
            let compact = fullHeight < 720
            let bottomBlock: CGFloat = groupSummaries.isEmpty ? 64 : 130
            let headBlock: CGFloat = compact ? 92 : 112
            let reserved: CGFloat = LaterHeader.height + headBlock + HomeDevelopCard.height + bottomBlock + Self.moonReserve + 56
            let ringSide = min(300, max(170, fullHeight - top - reserved))

            VStack(spacing: 0) {
                LaterHeader(
                    home: .today,
                    shotsToday: shotsToday,
                    avatarImage: avatarImage,
                    avatarName: avatarName,
                    showsBadge: showsAvatarBadge,
                    onAvatar: { if showsLights { withAnimation(.easeOut(duration: 0.25)) { showsLights = false } } else { onOpenProfile() } },
                    onConsumption: toggleLights,
                    avatarSwitch: avatarSwitch
                )
                .opacity(launch.headerOpacity)

                Spacer(minLength: 0)

                ring(side: ringSide, width: width)
                    .opacity(launch.bgOpacity)

                Spacer(minLength: 0)

                textBlock(compact: compact)
                    .padding(.horizontal, 24)
                    .offset(y: launch.headOffset)
                    .opacity(launch.headOpacity)

                Spacer(minLength: 8)

                HomeDevelopCard(
                    content: developContent,
                    now: now,
                    texture: developTexture,
                    tones: tones,
                    isAnimating: false,
                    film: (taken: shotsToday, isNight: state.isNight),
                    onTap: onDevelopTap,
                    chic: true
                )
                .padding(.horizontal, 20)
                .offset(y: launch.cardOffset)
                .opacity(launch.cardOpacity)

                Spacer(minLength: 10)

                bottomBlockView
                    .offset(y: launch.groupOffset)
                    .opacity(launch.groupOpacity)

                Color.clear.frame(height: Self.moonReserve)
            }
            .padding(.top, top)
            .frame(width: width, height: fullHeight, alignment: .top)
            .opacity(isDiving ? 0 : 1)
            .animation(.easeOut(duration: 0.32), value: isDiving)
            .lightsPanelOverlay(isOpen: $showsLights, now: now, taken: shotsToday, top: top, width: width)
        }
        .background {
            if palette.isNight {
                ChicNightBackground().ignoresSafeArea()
            } else {
                ChicColor.paper.ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .onAppear { isOnScreen = true }
        .onDisappear { isOnScreen = false }
    }

    // MARK: - 輪と落書き

    private var dateText: String { HomeDevelopCard.stampText(now) }

    private func ring(side: CGFloat, width: CGFloat) -> some View {
        let scale = side / 300
        return ZStack {
            ZStack(alignment: .topLeading) {
                if palette.isNight { ChicNightSphere() }
                ringRotating
                doodles
            }
            .frame(width: 300, height: 300, alignment: .topLeading)
            .scaleEffect(scale)
            .frame(width: 300 * scale, height: 300 * scale)
            orbHit
                .frame(width: 230 * scale, height: 230 * scale)
        }
        .frame(width: width, height: side)
    }

    /// 回る輪(48秒で1周)。視差効果を減らすとき・画面が見えていないときは止める。
    private var ringRotating: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !motionOn)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let angle = motionOn ? (t.truncatingRemainder(dividingBy: 48) / 48) * 360 : 0
            ChicRingArt(dateText: dateText)
                .rotationEffect(.degrees(angle))
        }
        .frame(width: 300, height: 300)
        .accessibilityHidden(true)
    }

    /// 輪のまわりの落書き(文字の上には置かない)。4pt・3.2秒でゆれる。
    private var doodles: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !motionOn)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            // 0 → 1 → 0 を 3.2 秒で(CSS の bob と同じ:50% で -4pt・6°)
            let phase = motionOn ? 0.5 - 0.5 * cos(t / 3.2 * 2 * .pi) : 0
            ZStack(alignment: .topLeading) {
                doodle(.star, width: 32, x: -15, y: 6, rotation: -12, phase: phase, floats: true)
                doodle(.wave, width: 40, x: 273, y: 38, rotation: 18, phase: phase, floats: false)
                doodle(.flower, width: 28, x: 291, y: 292, rotation: 10, phase: phase, floats: true)
                doodle(.dots, width: 20, x: -15, y: 272, rotation: 0, phase: phase, floats: false)
            }
            .frame(width: 300, height: 300, alignment: .topLeading)
        }
        .frame(width: 300, height: 300)
        .accessibilityHidden(true)
    }

    private func doodle(_ kind: ChicDoodleKind, width: CGFloat, x: CGFloat, y: CGFloat, rotation: Double, phase: Double, floats: Bool) -> some View {
        ChicDoodle(kind: kind, width: width)
            .rotationEffect(.degrees(rotation + (floats ? 6 * phase : 0)))
            .offset(x: x, y: y - (floats ? 4 * phase : 0))
    }

    /// 輪の中心の文字と、タップ(Mondo の入口)
    private var orbHit: some View {
        centerLabel
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Circle())
            .onTapGesture(perform: onOrbTap)
            .opacity(launch.countOpacity)
            .animation(.easeInOut(duration: 0.6), value: light)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(orbAccessibilityText)
            .accessibilityAddTraits(.isButton)
    }

    private var centerLabel: some View {
        VStack(spacing: 6) {
            if state == .first {
                if palette.isNight {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .padding(.bottom, 14)
                }
                Text("ここから、はじまる")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(0.08 * 13)
                    .foregroundStyle(palette.isNight ? palette.sub : palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(width: 150)
            } else {
                Text(light.value.map(Self.formatted) ?? "—")
                    .font(.system(size: 46, weight: .heavy))
                    .tracking(-0.04 * 46)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(palette.ink.opacity(light.value == nil ? 0.4 : 1))
                    .frame(width: 150)
                Text("世界の光 ・ 昨日")
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(0.2 * 10)
                    .foregroundStyle(palette.sub)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    private static func formatted(_ n: Int) -> String {
        n.formatted(.number.grouping(.automatic).locale(Locale(identifier: "en_US")))
    }

    private var orbAccessibilityText: String {
        if state == .first { return "ここから、はじまる" }
        guard let n = light.value else { return "昨日の世界の光" }
        return "昨日、世界で\(Self.formatted(n))枚の光があります"
    }

    // MARK: - 見出しと補足

    private func textBlock(compact: Bool) -> some View {
        let lines = HomeView.headline(state).components(separatedBy: "\n")
        let key = Self.circledWord(state)
        return VStack(spacing: 10) {
            VStack(spacing: 2) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    ChicHeadlineLine(line: line, key: key, compact: compact)
                }
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(lines.joined())
            Text(HomeView.subline(state))
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .foregroundStyle(palette.sub)
        }
        .frame(maxWidth: .infinity)
        .id(state.kind)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    /// 手描きの楕円で囲む言葉
    static func circledWord(_ state: HomeState) -> String? {
        switch state {
        case .first: return "撮って"
        case .dawn: return "昨日"
        case .night: return "仕上がります"
        default: return nil
        }
    }

    // MARK: - ボタン / グループ

    @ViewBuilder
    private var bottomBlockView: some View {
        if groupSummaries.isEmpty {
            HStack(spacing: 10) {
                Button(action: onJoinGroup) {
                    ChicActionLabel(icon: "qrcode", title: "参加する", note: "合言葉・QR・リンク", filled: false)
                }
                .buttonStyle(PressScaleStyle(scale: 0.97, duration: 0.15))
                .accessibilityLabel("グループに参加する。合言葉・QR・リンク")
                Button(action: onCreateGroup) {
                    ChicActionLabel(icon: "plus", title: "つくる", note: "4〜8人のグループ", filled: true)
                }
                .buttonStyle(PressScaleStyle(scale: 0.97, duration: 0.15))
                .accessibilityLabel("グループをつくる。4〜8人のグループ")
            }
            .padding(.horizontal, 20)
        } else {
            // 既存のグループの列は白地用に作り直していないので、濃い面にのせて、そのまま使う(フェーズ2で作り直す)
            HomeGroupStrip(
                summaries: groupSummaries,
                canCreate: canCreateGroup,
                isFrontmost: isVisible,
                entranceStart: nil,
                onSelect: onSelectGroup,
                onCreate: onCreateGroup,
                onJoin: onJoinGroup,
                onAdd: onAddGroup,
                arrivingID: arrivingGroupID,
                shotsToday: shotsToday
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(palette.isNight ? palette.fill : ChicColor.ink))
            .overlay {
                if palette.isNight { RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(palette.line, lineWidth: 1) }
            }
            .padding(.horizontal, 12)
            .environment(\.colorScheme, .dark)
        }
    }
}

/// 見出しの1行。囲む言葉が含まれていれば、その言葉に手描きの楕円を重ねる。
/// 幅が足りないときは、字を小さくした候補に切りかえる。
private struct ChicHeadlineLine: View {
    @Environment(\.palette) private var palette
    let line: String
    let key: String?
    let compact: Bool

    var body: some View {
        let base: CGFloat = compact ? 30 : 34
        ViewThatFits(in: .horizontal) {
            row(size: base)
            row(size: base - 3)
            row(size: base - 6)
            row(size: base - 9)
            row(size: base - 12)
        }
    }

    private func row(size: CGFloat) -> some View {
        let parts = split()
        return HStack(spacing: 0) {
            if !parts.pre.isEmpty { Text(parts.pre) }
            if let hit = parts.hit {
                Text(hit).overlay { ChicScribble() }
            }
            if !parts.post.isEmpty { Text(parts.post) }
        }
        .font(.system(size: size, weight: .heavy))
        .tracking(-0.04 * size)
        .foregroundStyle(palette.ink)
        .fixedSize()
    }

    private func split() -> (pre: String, hit: String?, post: String) {
        guard let key, let range = line.range(of: key) else { return (line, nil, "") }
        return (String(line[..<range.lowerBound]), key, String(line[range.upperBound...]))
    }
}

/// 「参加する」(薄いグレー)/「つくる」(インク)。2行:タイトル Bold + 小さい補足。角丸22。
private struct ChicActionLabel: View {
    @Environment(\.palette) private var palette
    let icon: String
    let title: String
    let note: String
    let filled: Bool

    private var night: Bool { palette.isNight }
    /// 夜の「つくる」(白地)の上の文字色は、昼のインク
    private var onLight: Color { Palette.day.ink }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(night ? (filled ? onLight : palette.ink) : ChicColor.ink)
                .frame(width: 30, height: 30)
                .background(Circle().fill(night ? Color.clear : Color.white))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15.5, weight: .bold))
                    .tracking(-0.02 * 15.5)
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(note)
                    .font(.system(size: 10.5))
                    .foregroundStyle(noteColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 64)
        .background(background(shape))
        .overlay {
            if night && !filled { shape.strokeBorder(palette.ink.opacity(0.12), lineWidth: 1) }
        }
        .accessibilityElement(children: .combine)
    }

    private var titleColor: Color {
        if night { return filled ? onLight : palette.ink }
        return filled ? Color.white : ChicColor.ink
    }

    private var noteColor: Color {
        if night { return filled ? Palette.day.sub : palette.sub }
        return filled ? Color.white.opacity(0.6) : ChicColor.sub
    }

    @ViewBuilder
    private func background(_ shape: RoundedRectangle) -> some View {
        if night && filled {
            shape.fill(LinearGradient(colors: [palette.ink, Color(hex: "E6E6EC")], startPoint: .top, endPoint: .bottom))
        } else if night {
            shape.fill(palette.fill)
        } else {
            shape.fill(filled ? ChicColor.ink : ChicColor.fill)
        }
    }
}
