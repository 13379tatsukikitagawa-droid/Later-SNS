import SwiftUI
import SwiftData
import UIKit

/// プロフィール v5「あなたの星」。夜空と地平線と、ひとつの光(ホームやウィジェットと同じ景色)。
/// 上半分は空:プロフィール写真が星になり、まわりに今日の現像の点の輪、自分のタグがまわる。
/// 下半分は水面:預けた日々(直近7日)が、遠近の光の道に並ぶ。
/// 自分だけが見る画面で、いいね・フォロワー・連続日数は出さない。数字は「現像の%」と「日付」だけ。
/// ハプティクスは、点を押し続けて「ひらく」ときの1回だけ。
struct ProfileImmersiveView: View {
    /// Homeへ戻る(左上の「<」)。右スワイプでも戻る(MainNavigationViewが受け持つ)。
    var onBack: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.selectedMainTabIndex) private var selectedMainTabIndex

    @Query private var profiles: [UserProfile]
    @Query(sort: \ExposureDay.captureDate, order: .reverse) private var exposureDays: [ExposureDay]

    @AppStorage("profileBallColorHex") private var cachedBallColorHex: String = ""
    @AppStorage("profileBallColorKey") private var cachedBallColorKey: String = ""
    @AppStorage(AvatarBadge.pendingKey) private var avatarBadgePending: String = ""
    @AppStorage(AvatarBadge.acknowledgedKey) private var avatarBadgeAcknowledged: String = ""

    @State private var isOnScreen = false
    @State private var tilt = GlassTilt()
    @State private var haptics = ExposureHaptics()
    @State private var editFocus: ProfileEditFocus?
    @State private var isShowingSettings = false
    @State private var planetFocus: Double = 1
    /// 0 = 真珠、1 = 写真(初めて現像された瞬間の演出で0→1)
    @State private var revealProgress: Double = 1
    @State private var openedDay: WeekDayPoint?
    @State private var isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    /// ふれている点(水面の枠の番号)
    @State private var selectedSlot: Int?
    @State private var pressStart: Date?
    @State private var hasTriggeredOpen = false
    @Namespace private var dotsNamespace

    @ScaledMetric(relativeTo: .caption2) private var captionSize: CGFloat = 10.5
    @ScaledMetric(relativeTo: .caption2) private var noteSize: CGFloat = 10

    /// アプリを起動して最初にProfileを開いた時だけ登場演出を再生する。
    private static var hasPlayedEntrance = false
    private static let profileTabIndex = 1
    private static let thumbnailCache = NSCache<NSString, UIImage>()
    private static let hitRadius: CGFloat = 40
    private static let coordinateSpace = "profileStar"

    private var profile: UserProfile? { UserProfile.current(from: profiles) }

    private var isVisible: Bool {
        isOnScreen && scenePhase == .active && selectedMainTabIndex == Self.profileTabIndex
            && editFocus == nil && !isShowingSettings
    }

    private var motion: ProfileStarMotion {
        if reduceMotion { return .reduced }
        if isLowPower { return .still }
        return .full
    }

    private var profileImage: UIImage? {
        profile?.profileImageData.flatMap(UIImage.init(data:))
    }

    private var planetColor: Color? {
        guard profileImage != nil, !cachedBallColorHex.isEmpty else { return nil }
        return Color(hex: cachedBallColorHex)
    }

    private var displayName: String {
        profile?.name.isEmpty == false ? profile!.name : "Later"
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let g = ProfileStarGeometry(size: size)
            let days = starDays(now: Date())
            ZStack(alignment: .topLeading) {
                skyBackground

                ProfileStarLiveScene(
                    input: sceneInput(days: days),
                    size: size,
                    tilt: tilt,
                    isRunning: isVisible,
                    isPressing: pressStart != nil,
                    onTick: checkHold(at:)
                )

                skyTouchLayer(g: g, size: size)
                textLayer(g: g, size: size, days: days)
                waterTouchLayer(g: g, size: size, days: days)
                dayAnchors(g: g, days: days)
                accessibilityDays(g: g, days: days)

                if openedDay == nil, let slot = selectedSlot, let day = days.first(where: { $0.slot == slot }) {
                    dayCard(for: day, g: g, size: size)
                }

                header
                    .padding(.horizontal, 22)
                    .frame(width: size.width)
                    .position(x: size.width / 2, y: 58 * g.sy + 22)

                if let openedDay {
                    DayFullScreenViewer(
                        shots: shots,
                        initialID: openedDay.id,
                        namespace: dotsNamespace,
                        haptics: haptics,
                        isMondoSettingOn: MondoService.isPublic,
                        imageFor: fullImage(for:),
                        onDelete: deleteShot,
                        onDismiss: closeOpenedDay
                    )
                    .frame(width: size.width, height: size.height)
                    .transition(.opacity)
                    .zIndex(10)
                }
            }
            .frame(width: size.width, height: size.height)
            .coordinateSpace(name: Self.coordinateSpace)
        }
        .ignoresSafeArea(edges: .top)
        .preference(key: ProfileViewerOpenKey.self, value: openedDay != nil)
        .overlay {
            // 粒子ノイズ(小さな画像をタイル)
            FilmGrainOverlay(opacity: 0.05, blendMode: .normal)
                .ignoresSafeArea()
        }
        .onAppear {
            isOnScreen = true
            haptics.prepare()
            updatePlanetColorIfNeeded()
            playEntranceIfNeeded()
            playRevealIfNeeded()
        }
        .onDisappear { isOnScreen = false }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .NSProcessInfoPowerStateDidChange) {
                isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
        .onChange(of: isVisible) { _, visible in
            updateMotion()
            if visible {
                playRevealIfNeeded()
                // Profileを開いたら、アバターの白い点を消す。
                if !avatarBadgePending.isEmpty {
                    avatarBadgeAcknowledged = avatarBadgePending
                    avatarBadgePending = ""
                }
            } else {
                resetTouch()
            }
        }
        .onChange(of: motion) { _, _ in updateMotion() }
        .onChange(of: profile?.profileImageData) { _, _ in
            updatePlanetColorIfNeeded()
            playRevealIfNeeded()
        }
        .fullScreenCover(item: $editFocus) { focus in
            ProfileEditScreen(initialFocus: focus)
        }
        .fullScreenCover(isPresented: $isShowingSettings) {
            SettingsMenuView(isShowing: $isShowingSettings)
        }
    }

    // MARK: - 景色の材料

    private func sceneInput(days: [ProfileStarDay]) -> ProfileStarInput {
        ProfileStarInput(
            image: profileImage,
            planetColor: planetColor,
            reveal: revealProgress,
            focus: planetFocus,
            tags: profile?.selfTags ?? [],
            days: days,
            todayShotAt: todayShotDate(now: Date()),
            auroraColors: weekPoints.compactMap { $0.opened ? $0.color : nil },
            now: Date(),
            motion: motion,
            selectedSlot: selectedSlot,
            pressStart: pressStart
        )
    }

    /// 今日(9:00〜翌8:59)に撮った時刻。撮る前は nil
    private func todayShotDate(now: Date) -> Date? {
        let start = LaterWidgetDay.start(of: now)
        return exposureDays.first { $0.captureDate >= start && $0.captureDate <= now }?.captureDate
    }

    /// 水面の点。撮らなかった日は作らない(道は途切れずに続く)。
    private func starDays(now: Date) -> [ProfileStarDay] {
        var result: [ProfileStarDay] = []
        for point in weekPoints {
            guard let slot = ProfileStarLayout.slot(for: point.date, now: now),
                  !result.contains(where: { $0.slot == slot }) else { continue }
            result.append(ProfileStarDay(slot: slot, point: point, color: point.opened ? (point.color ?? .white) : .white, date: point.date))
        }
        // 今日撮ったが、まだどこにも預けていない(ひらけない)1枚も、点だけは出す
        if let shot = todayShotDate(now: now), !result.contains(where: { $0.slot == 0 }) {
            result.append(ProfileStarDay(slot: 0, point: nil, color: .white, date: shot))
        }
        return result
    }

    private var skyBackground: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.04, green: 0.05, blue: 0.12), location: 0),
                .init(color: Color(red: 0.02, green: 0.02, blue: 0.06), location: 0.5),
                .init(color: .black, location: 1),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - 文字(視差で動かさない)

    @ViewBuilder
    private func textLayer(g: ProfileStarGeometry, size: CGSize, days: [ProfileStarDay]) -> some View {
        let tags = profile?.selfTags ?? []

        Text(displayName)
            .font(.system(size: 35 * g.s, weight: .heavy))
            .tracking(-0.04 * 35 * g.s)
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: size.width - 64)
            .shadow(color: .black.opacity(0.6), radius: 10)
            .onTapGesture { editFocus = .name }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("名前を編集します")
            .position(x: size.width / 2, y: g.y(ProfileStarLayout.nameY))

        Text("LATER ・ \(Self.sinceFormatter.string(from: sinceDate)) から")
            .font(.system(size: captionSize, design: .monospaced))
            .tracking(0.18 * captionSize)
            .foregroundStyle(.white.opacity(0.58))
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .position(x: size.width / 2, y: g.y(ProfileStarLayout.sinceY))

        if tags.isEmpty {
            Button { editFocus = .tags } label: {
                Text("タグを足す")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "BCBBC0"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .position(x: size.width / 2, y: g.y(ProfileStarLayout.tagRowY))
        } else if !motion.showsOrbitTags {
            // 視差を減らす:タグは名前の下に横並び
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { ProfileStarTag(text: $0) }
            }
            .onTapGesture { editFocus = .tags }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("自分を表すタグ:\(tags.joined(separator: "、"))")
            .accessibilityAddTraits(.isButton)
            .position(x: size.width / 2, y: g.y(ProfileStarLayout.tagRowY))
        }

        HStack(alignment: .firstTextBaseline) {
            Text("預けた日々")
                .font(.system(size: 17 * g.s, weight: .bold))
                .foregroundStyle(.white)
            Spacer(minLength: 12)
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(todayStatusText(now: context.date))
                    .font(.system(size: captionSize, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            }
        }
        .padding(.horizontal, 24)
        .frame(width: size.width)
        .accessibilityElement(children: .combine)
        .position(x: size.width / 2, y: g.y(ProfileStarLayout.headingY))

        VStack(spacing: 3) {
            Text("点を押し続けると、その日がひらく")
            Text("写真は、撮ってから7日間だけ残ります")
        }
        .font(.system(size: noteSize))
        .foregroundStyle(.white.opacity(0.6))
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .frame(width: size.width, height: size.height, alignment: .bottom)
        .padding(.bottom, 26)
        .allowsHitTesting(false)
    }

    /// 右上の文言:「今日 現像 NN%」/ 撮る前は「今日は、まだ撮っていません」
    private func todayStatusText(now: Date) -> String {
        guard let shot = todayShotDate(now: now) else { return "今日は、まだ撮っていません" }
        let percent = ProfileStarLayout.developPercent(ProfileStarLayout.developProgress(shotAt: shot, now: now))
        return "今日 現像 \(percent)%"
    }

    /// 最初に撮った日(なければ初回設定を終えた日)。
    private var sinceDate: Date {
        if let first = exposureDays.last?.captureDate { return first }
        if let completed = UserDefaults.standard.object(forKey: "onboardingCompletedAt") as? Date { return completed }
        return Date()
    }

    private static let sinceFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM.dd"
        return formatter
    }()

    // MARK: - ヘッダー(戻る・編集|設定)

    private var header: some View {
        HStack(spacing: 10) {
            if let onBack {
                GlassCircleButton(systemImage: "chevron.left", label: "戻る", action: onBack)
            }
            Spacer()
            GlassActionPill(
                onEdit: { editFocus = ProfileEditFocus.none },
                onSettings: { isShowingSettings = true }
            )
        }
    }

    // MARK: - 空にふれる(惑星 → 写真の編集、タグ → タグの編集)

    private func skyTouchLayer(g: ProfileStarGeometry, size: CGSize) -> some View {
        let center = g.pt(ProfileStarLayout.planetCenter)
        let tags = profile?.selfTags ?? []
        return ZStack {
            Color.clear
                .frame(width: size.width, height: g.y(240))
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture(coordinateSpace: .named(Self.coordinateSpace)).onEnded { value in
                    handleSkyTap(at: value.location, g: g, tags: tags)
                })
                .position(x: size.width / 2, y: center.y)
                .accessibilityHidden(true)

            // 読み上げ用:惑星
            Color.clear
                .frame(width: ProfileStarLayout.planetDiameter * g.s, height: ProfileStarLayout.planetDiameter * g.s)
                .contentShape(Circle())
                .allowsHitTesting(false)
                .accessibilityElement()
                .accessibilityLabel("プロフィール写真、\(displayName)")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { editFocus = .photo }
                .position(center)

            if motion.showsOrbitTags, !tags.isEmpty {
                Color.clear
                    .frame(width: 2 * ProfileStarLayout.tagOrbitRadiusX * g.s, height: 20)
                    .allowsHitTesting(false)
                    .accessibilityElement()
                    .accessibilityLabel("自分を表すタグ:\(tags.joined(separator: "、"))")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { editFocus = .tags }
                    .position(x: center.x, y: center.y + ProfileStarLayout.tagOrbitRadiusY * g.s + 20)
            }
        }
    }

    private func handleSkyTap(at location: CGPoint, g: ProfileStarGeometry, tags: [String]) {
        let center = g.pt(ProfileStarLayout.planetCenter)
        if motion.showsOrbitTags, !tags.isEmpty {
            let elapsed = motion.isMoving ? Date().timeIntervalSinceReferenceDate : 0
            let offset = ProfileStarTilt(x: motion.isMoving ? tilt.x : 0, y: motion.isMoving ? tilt.y : 0).offset(9)
            for index in tags.indices {
                let orbit = ProfileStarLayout.tagOrbit(index: index, count: tags.count, elapsed: elapsed)
                guard orbit.depth >= 0.5 else { continue }
                let p = CGPoint(x: center.x + orbit.offset.x * g.s + offset.width, y: center.y + orbit.offset.y * g.s + offset.height)
                if abs(p.x - location.x) < 48, abs(p.y - location.y) < 18 {
                    editFocus = .tags
                    return
                }
            }
        }
        if hypot(location.x - center.x, location.y - center.y) <= ProfileStarLayout.planetDiameter * g.s / 2 + 8 {
            editFocus = .photo
        }
    }

    // MARK: - 水面の点にふれる / 押し続ける

    private func slotPosition(_ slot: Int, g: ProfileStarGeometry, withParallax: Bool) -> CGPoint {
        let p = g.pt(ProfileStarLayout.slotCenter(slot))
        guard withParallax, motion.isMoving else { return p }
        let offset = ProfileStarTilt(x: tilt.x, y: tilt.y).offset(22)
        return CGPoint(x: p.x + offset.width, y: p.y + offset.height)
    }

    private func waterTouchLayer(g: ProfileStarGeometry, size: CGSize, days: [ProfileStarDay]) -> some View {
        let top = g.y(ProfileStarLayout.headingY + 24)
        let bottom = size.height - 64
        return Color.clear
            .frame(width: size.width, height: max(0, bottom - top))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpace))
                    .onChanged { value in track(value.location, g: g, days: days) }
                    .onEnded { _ in releaseTouch() }
            )
            .position(x: size.width / 2, y: (top + bottom) / 2)
            .accessibilityHidden(true)
    }

    private func track(_ location: CGPoint, g: ProfileStarGeometry, days: [ProfileStarDay]) {
        guard openedDay == nil, !hasTriggeredOpen else { return }
        var nearest: (slot: Int, distance: CGFloat)?
        for day in days where day.point != nil {
            let p = slotPosition(day.slot, g: g, withParallax: true)
            let distance = hypot(p.x - location.x, p.y - location.y)
            if distance <= Self.hitRadius, distance < (nearest?.distance ?? .infinity) {
                nearest = (day.slot, distance)
            }
        }
        guard nearest?.slot != selectedSlot else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            selectedSlot = nearest?.slot
        }
        pressStart = nearest == nil ? nil : Date()
    }

    private func releaseTouch() {
        guard !hasTriggeredOpen else { return }
        resetTouch()
    }

    private func resetTouch() {
        withAnimation(.easeOut(duration: 0.18)) { selectedSlot = nil }
        pressStart = nil
        hasTriggeredOpen = false
    }

    /// 約0.55秒押し続けたら、ビューアをひらく(ここで1回だけハプティクス)
    private func checkHold(at date: Date) {
        guard openedDay == nil, !hasTriggeredOpen, let slot = selectedSlot, let pressStart,
              date.timeIntervalSince(pressStart) >= ProfileStarLayout.holdDuration,
              let point = weekPoints.first(where: { ProfileStarLayout.slot(for: $0.date, now: Date()) == slot }),
              point.opened else { return }
        hasTriggeredOpen = true
        haptics.fireCapture(intensity: 1.0, sharpness: 0.7)
        openDay(point)
    }

    /// ふれている間の小さな写真カード(日付と「あと6日で、消えます」)
    private func dayCard(for day: ProfileStarDay, g: ProfileStarGeometry, size: CGSize) -> some View {
        let p = slotPosition(day.slot, g: g, withParallax: true)
        let r = ProfileStarLayout.slotRadius(day.slot) * g.s * 1.35
        let half = WeekDayCard.width / 2
        // 右側の点はカードを左に、今日と左側の点は右に
        let toLeft = day.slot != 0 && ProfileStarLayout.labelOnRight(day.slot)
        let x = min(max(p.x + (toLeft ? -1 : 1) * (r + 14 + half), 14 + half), size.width - 14 - half)
        let cardHalfHeight = WeekDayCard.approximateHeight / 2
        let y = min(max(p.y, g.y(ProfileStarLayout.headingY) + cardHalfHeight), size.height - 20 - cardHalfHeight)
        return Group {
            if let point = day.point {
                WeekDayCard(point: point, thumbnail: thumbnail(for: point))
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .id(point.id)
            }
        }
        .position(x: x, y: y)
        .allowsHitTesting(false)
    }

    /// 全画面へ「ふくらむ」ための見えないアンカー
    private func dayAnchors(g: ProfileStarGeometry, days: [ProfileStarDay]) -> some View {
        ForEach(days) { day in
            if let point = day.point {
                let size = ProfileStarLayout.slotRadius(day.slot) * g.s * 2
                Circle()
                    .fill(Color.clear)
                    .frame(width: size, height: size)
                    .position(slotPosition(day.slot, g: g, withParallax: false))
                    .matchedGeometryEffect(id: "day-\(point.id)", in: dotsNamespace)
                    .allowsHitTesting(false)
            }
        }
    }

    /// VoiceOver:点 =「10月15日の写真。あと6日で消えます。ダブルタップでひらく」
    private func accessibilityDays(g: ProfileStarGeometry, days: [ProfileStarDay]) -> some View {
        ForEach(days.sorted { $0.slot < $1.slot }) { day in
            Color.clear
                .frame(width: 44, height: 44)
                .allowsHitTesting(false)
                .accessibilityElement()
                .accessibilityLabel(Self.spokenLabel(for: day))
                .accessibilityAddTraits(day.point?.opened == true ? .isButton : [])
                .accessibilityAction {
                    if let point = day.point, point.opened { openDay(point) }
                }
                .position(slotPosition(day.slot, g: g, withParallax: false))
        }
    }

    static func spokenLabel(for day: ProfileStarDay) -> String {
        guard let point = day.point, point.opened else {
            return "今日の1枚。あしたの朝9:00に、ひらきます"
        }
        let remaining = point.remainingDays <= 1 ? "あしたの朝、消えます" : "あと\(point.remainingDays)日で消えます"
        return "\(WeekDayCard.dateLabel(point.date))の写真。\(remaining)。ダブルタップでひらく"
    }

    // MARK: - 預けた日々(直近7日)

    /// Profileに出す日(古い順)。点・ビューアは、すべてこの結果を使う。
    private var shots: [WeekDayPoint] {
        ProfileShot.shots(profile: profile, exposureDays: exposureDays, now: Date())
    }

    /// 新しい順(0が今日)
    private var weekPoints: [WeekDayPoint] {
        shots.reversed()
    }

    /// 並べ替え前のprofile.photosから、その日(dayKey)に対応するLaterPhotoを探す。
    /// 全画面ビューアの本番画質は、サムネイル(ExposureDay)ではなくこちらを使う。
    private func photo(forDayKey dayKey: String) -> LaterPhoto? {
        profile?.photos.first { ExposureDayStore.dayKey(for: $0.captureDate) == dayKey }
    }

    private func thumbnail(for point: WeekDayPoint) -> UIImage? {
        guard point.opened, point.showsPhoto else { return nil }
        let key = point.id as NSString
        if let cached = Self.thumbnailCache.object(forKey: key) { return cached }
        guard let data = exposureDays.first(where: { $0.dayKey == point.id })?.thumbnailData,
              let image = UIImage(data: data) else { return nil }
        Self.thumbnailCache.setObject(image, forKey: key)
        return image
    }

    /// 全画面ビューア用の本画質画像(7日以内はLaterPhotoがまだ端末にあるはず)。
    private func fullImage(for point: WeekDayPoint) -> UIImage? {
        guard point.opened, point.showsPhoto, let data = photo(forDayKey: point.id)?.imageData else {
            return thumbnail(for: point)
        }
        return UIImage(data: data)
    }

    // MARK: - 点を開く

    /// その日の写真を、共有先すべて(グループ・Mondo)から消す。7日で消える時と同じ範囲を消し、
    /// 点の記録(ExposureDay)も消す。
    private func deleteShot(_ point: WeekDayPoint) {
        let cloudKitManager = CloudKitManager.current
        let photos = profile?.photos.filter { ExposureDayStore.dayKey(for: $0.captureDate) == point.id } ?? []
        for photo in photos {
            cloudKitManager?.markForDelete(photo: photo)
            modelContext.delete(photo)
        }
        for day in exposureDays where day.dayKey == point.id {
            modelContext.delete(day)
        }
        try? modelContext.save()
        Self.thumbnailCache.removeObject(forKey: point.id as NSString)

        let mondoRecord = MondoIdentity.recordName(mondoID: MondoIdentity.id, dayKey: point.id)
        Task {
            if MondoLocalStore.published.contains(mondoRecord) {
                await MondoService.shared.withdraw([mondoRecord])
            }
            await cloudKitManager?.sendPendingChangesNow()
        }
    }

    private func openDay(_ point: WeekDayPoint) {
        withAnimation(.timingCurve(0.3, 0.7, 0.2, 1, duration: 0.46)) {
            openedDay = point
        }
    }

    private func closeOpenedDay() {
        withAnimation(.timingCurve(0.3, 0.7, 0.2, 1, duration: 0.46)) {
            openedDay = nil
        }
        resetTouch()
    }

    // MARK: - 動き

    private func updateMotion() {
        if isVisible && motion.isMoving {
            tilt.start()
        } else {
            tilt.stop()
        }
    }

    private func playEntranceIfNeeded() {
        guard !Self.hasPlayedEntrance else { return }
        Self.hasPlayedEntrance = true
        guard motion.isMoving else { return }
        planetFocus = 0
        withAnimation(.easeOut(duration: 0.8)) { planetFocus = 1 }
    }

    /// 初めてプロフィール画像が現像された時に一度だけ、星に写真が入る(音・振動はなし)。
    private func playRevealIfNeeded() {
        let defaults = UserDefaults.standard
        guard isOnScreen, profileImage != nil, defaults.bool(forKey: ProfilePhotoDevelopment.revealPendingKey) else { return }
        defaults.set(false, forKey: ProfilePhotoDevelopment.revealPendingKey)
        revealProgress = 0
        withAnimation(.easeOut(duration: motion.isMoving ? 1.6 : 0.25)) { revealProgress = 1 }
    }

    /// 写真の中心の色は、画像が変わった時に1度だけ計算して保存する。
    private func updatePlanetColorIfNeeded() {
        guard let profile, let data = profile.profileImageData else { return }
        let key = "\(data.count)-\(profile.profileUpdatedAt?.timeIntervalSince1970 ?? 0)"
        guard key != cachedBallColorKey else { return }
        Task.detached(priority: .utility) {
            let hex = UIImage(data: data).flatMap { PhotoColor.centerColorHex(of: $0) }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 1.0)) {
                    cachedBallColorHex = hex ?? ""
                }
                cachedBallColorKey = key
            }
        }
    }
}

// MARK: - 動く景色(TimelineView は、ここ1つだけ)

/// 傾き(45Hz)を読むのはこのビューだけにして、プロフィール全体を作り直さないようにする。
private struct ProfileStarLiveScene: View {
    let input: ProfileStarInput
    let size: CGSize
    let tilt: GlassTilt
    let isRunning: Bool
    let isPressing: Bool
    let onTick: (Date) -> Void

    var body: some View {
        // 止めている時(視差を減らす・低電力)も、押し続けのリングと現像の進みのために、ゆっくり進める
        let moving = input.motion.isMoving || isPressing
        TimelineView(.animation(minimumInterval: moving ? nil : 30, paused: !isRunning)) { context in
            ProfileStarFrame(
                input: input,
                time: context.date,
                tilt: ProfileStarTilt(x: tilt.x, y: tilt.y),
                size: size
            )
            .onChange(of: context.date) { _, date in onTick(date) }
        }
    }
}

/// Homeのアバターの白い点(あなたのページに、見ていない変化がある)。
/// いまは「現像が100%になった」時だけ点け、Profileを開いたら消す。
enum AvatarBadge {
    /// 点いている時、その1枚を表すキー
    static let pendingKey = "avatarBadgePending"
    /// 最後に見た(消した)1枚のキー
    static let acknowledgedKey = "avatarBadgeAcknowledged"
}

// MARK: - ガラスの部品(.ultraThinMaterial + 白のふち)

private struct GlassCircleButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1))
                .environment(\.colorScheme, .dark)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// 編集・設定を1つにまとめたガラスのカプセル(96×44)。中央に高さ20pt・1ptの区切り線を挟む。
private struct GlassActionPill: View {
    let onEdit: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            pillButton(systemImage: "pencil", label: "編集", action: onEdit)
            Rectangle()
                .fill(.white.opacity(0.22))
                .frame(width: 1, height: 20)
            pillButton(systemImage: "slider.horizontal.3", label: "設定", action: onSettings)
        }
        .frame(width: 96, height: 44)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1))
        .environment(\.colorScheme, .dark)
    }

    private func pillButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - 編集シート

enum ProfileEditFocus: String, Identifiable {
    case none, photo, name, tags
    var id: String { rawValue }
}

enum ProfileEditRules {
    static let bioMaxLength = 30
}

/// Profileの全画面ビューアが開いているか。開いている間は、右スワイプでHomeへ戻らない
/// (ビューアの右スワイプは「前の日へ」)。
struct ProfileViewerOpenKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}
