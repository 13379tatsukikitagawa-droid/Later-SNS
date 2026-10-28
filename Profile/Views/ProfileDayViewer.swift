import SwiftUI
import UIKit

/// 「預けた日々」の全画面ビューア(v4)。点からふくらんで開き、
/// 左右スワイプ・レールなぞり・下ドラッグ・×で動く。
///
/// 縦に積む:上のバー(×・共有先)→ 4:3の写真 → 写真の下の情報 → 日付レール。
/// 位置は固定の座標ではなく、Safe Area と縦の並びで決める(機種が違っても重ならない)。
struct DayFullScreenViewer: View {
    /// Profileに出す日すべて(ProfileShot.visibleShots、古い順)。ひらいていない日も含む(レール用)。
    let shots: [WeekDayPoint]
    let initialID: String
    let namespace: Namespace.ID
    let haptics: ExposureHaptics
    /// アカウントの「Mondo に出す」設定(シートの説明文だけに使う。表示の ON / OFF は写真ごとの実績)
    let isMondoSettingOn: Bool
    let imageFor: (WeekDayPoint) -> UIImage?
    /// その日の写真を、共有先すべてから消す
    let onDelete: (WeekDayPoint) -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var currentID: String
    @State private var dragAxis: Axis?
    @State private var dragOffsetY: CGFloat = 0
    @State private var dragOffsetX: CGFloat = 0
    @State private var photoOnly = false
    @State private var contentOpacity: Double = 0
    @State private var infoHeight: CGFloat = 110
    @State private var isShareSheetOpen = false
    @State private var isConfirmingDelete = false
    @State private var sheetDrag: CGFloat = 0
    @State private var railTouchedKey: String?
    @State private var showsNotOpenedToast = false
    @State private var toastToken = 0

    private static let dismissThreshold: CGFloat = 110
    private static let swipeThreshold: CGFloat = 60
    private static let minPhotoHeight: CGFloat = 340
    private static let railWidth: CGFloat = 310
    private static let railHeight: CGFloat = 46
    private static let slideAnimation = Animation.timingCurve(0.22, 0.8, 0.24, 1, duration: 0.45)

    init(
        shots: [WeekDayPoint],
        initialID: String,
        namespace: Namespace.ID,
        haptics: ExposureHaptics,
        isMondoSettingOn: Bool,
        imageFor: @escaping (WeekDayPoint) -> UIImage?,
        onDelete: @escaping (WeekDayPoint) -> Void,
        onDismiss: @escaping () -> Void,
        startsWithChrome: Bool = false
    ) {
        self.shots = shots
        self.initialID = initialID
        self.namespace = namespace
        self.haptics = haptics
        self.isMondoSettingOn = isMondoSettingOn
        self.imageFor = imageFor
        self.onDelete = onDelete
        self.onDismiss = onDismiss
        _currentID = State(initialValue: initialID)
        // ふつうは、ふくらむ動きのあとで文字を出す(スナップショットでは最初から出す)
        _contentOpacity = State(initialValue: startsWithChrome ? 1 : 0)
    }

    /// 写真として見られる日(ひらいた日)。スワイプ・レールの切りかえ先。
    private var days: [WeekDayPoint] { shots.filter(\.opened) }
    private var currentIndex: Int { days.firstIndex(where: { $0.id == currentID }) ?? 0 }
    private var current: WeekDayPoint? { days[safe: currentIndex] }

    var body: some View {
        GeometryReader { proxy in
            let insets = Self.windowSafeInsets
            let layout = Layout(size: proxy.size, safeTop: insets.top, infoHeight: infoHeight)
            ZStack(alignment: .top) {
                Color.black.opacity(1 - dragDismissProgress * 0.6)

                if let current, !reduceTransparency {
                    ambientGlow(for: current, layout: layout)
                        .opacity(1 - dragDismissProgress)
                }

                ZStack(alignment: .top) {
                    photoPager(layout: layout)
                        .offset(y: layout.photoTop + (photoOnly ? 54 : 0))
                        .scaleEffect(photoOnly ? 1.06 : 1, anchor: .center)

                    chrome(layout: layout)
                        .opacity(photoOnly ? 0 : contentOpacity)
                        .allowsHitTesting(!photoOnly)
                }
                .scaleEffect(reduceMotion ? 1 : 1 - dragDismissProgress * 0.08)
                .offset(y: dragOffsetY)
                .opacity(1 - dragDismissProgress * 0.5)

                if showsNotOpenedToast {
                    notOpenedToast
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 104)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }

                if isShareSheetOpen, let current {
                    shareSheet(for: current, bottomInset: insets.bottom)
                        .zIndex(5)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(dragGesture, including: isShareSheetOpen ? .subviews : .all)
        }
        .ignoresSafeArea()
        .onAppear {
            if reduceMotion {
                contentOpacity = 1
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeOut(duration: 0.25)) { contentOpacity = 1 }
                }
            }
        }
        .onChange(of: days.map(\.id)) { _, ids in
            // 消したあとなど、見ていた日がなくなったら閉じる(移る先は onDelete の前に決めている)
            if ids.isEmpty { onDismiss() } else if !ids.contains(currentID), let last = ids.last { currentID = last }
        }
    }

    private var dragDismissProgress: Double {
        min(1, max(0, dragOffsetY / 280))
    }

    // MARK: - 縦の並び

    /// 上のバー → 写真 → 情報 → レール。写真の高さだけが伸び縮みする。
    private struct Layout {
        let width: CGFloat
        let barTop: CGFloat
        let photoTop: CGFloat
        let photoSize: CGSize
        let infoTop: CGFloat
        let railTop: CGFloat

        init(size: CGSize, safeTop: CGFloat, infoHeight: CGFloat) {
            width = size.width
            barTop = safeTop + 4
            photoTop = barTop + 44 + 12
            railTop = size.height - 34 - DayFullScreenViewer.railHeight
            let photoWidth = size.width - 24
            let ideal = photoWidth * 4 / 3
            // 写真の下 23pt に情報、情報とレールのあいだに最低 16pt
            let available = railTop - 16 - infoHeight - 23 - photoTop
            let height = max(DayFullScreenViewer.minPhotoHeight, min(ideal, available))
            photoSize = CGSize(width: photoWidth, height: height)
            infoTop = photoTop + height + 23
        }
    }

    // MARK: - 写真の色のにじみ(没入)

    private func ambientGlow(for day: WeekDayPoint, layout: Layout) -> some View {
        ZStack {
            if let image = imageFor(day) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: layout.width, height: 640)
                    .clipped()
                    .blur(radius: 64)
                    .saturation(1.3)
                    .opacity(0.42)
                    // ぼかしの上端がくっきり切れないよう、上をやわらかく消す
                    .mask(LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.18),
                    ], startPoint: .top, endPoint: .bottom))
                    .id(day.id)
                    .transition(.opacity)
            }
            LinearGradient(stops: [
                .init(color: .black.opacity(0.35), location: 0),
                .init(color: .clear, location: 0.22),
                .init(color: .black.opacity(0.55), location: 0.62),
                .init(color: .black, location: 0.88),
            ], startPoint: .top, endPoint: .bottom)
        }
        .frame(width: layout.width, height: 640)
        .offset(y: 60)
        .animation(.easeInOut(duration: 0.45), value: day.id)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - 写真(横にすべる)

    @ViewBuilder
    private func photoPager(layout: Layout) -> some View {
        if reduceMotion {
            // 「視差効果を減らす」:スライドの代わりにクロスフェード
            ZStack {
                if let current {
                    photoCard(for: current, size: layout.photoSize)
                        .matchedGeometryEffect(id: "day-\(current.id)", in: namespace)
                        .id(current.id)
                        .transition(.opacity)
                }
            }
            .frame(width: layout.width)
            .animation(.easeInOut(duration: 0.3), value: currentID)
        } else {
            HStack(spacing: 0) {
                ForEach(days) { day in
                    Group {
                        if day.id == currentID {
                            photoCard(for: day, size: layout.photoSize)
                                .matchedGeometryEffect(id: "day-\(day.id)", in: namespace)
                        } else {
                            photoCard(for: day, size: layout.photoSize)
                        }
                    }
                    .frame(width: layout.width)
                }
            }
            .frame(width: layout.width, alignment: .leading)
            .offset(x: -CGFloat(currentIndex) * layout.width + dragOffsetX)
        }
    }

    private func photoCard(for day: WeekDayPoint, size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        let isLastDay = day.remainingDays <= 1
        return ZStack(alignment: .bottomTrailing) {
            Group {
                if let image = imageFor(day) {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                } else {
                    (day.color ?? .white).opacity(0.3)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .saturation(isLastDay ? 0.78 : 1)
            .brightness(isLastDay ? -0.08 : 0)

            // ビネット+上端のうすい光
            EllipticalGradient(stops: [
                .init(color: .clear, location: 0.58),
                .init(color: .black.opacity(0.34), location: 1),
            ], center: UnitPoint(x: 0.5, y: 0.45))
            LinearGradient(stops: [
                .init(color: .white.opacity(0.07), location: 0),
                .init(color: .clear, location: 0.26),
            ], startPoint: .top, endPoint: .bottom)

            // 日付を読めるようにする、下のグラデ
            LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                .frame(height: 120)
                .frame(maxHeight: .infinity, alignment: .bottom)

            Text(ProfileShot.filmStamp(for: day.date))
                .font(.system(size: 13, design: .monospaced))
                .tracking(0.12 * 13)
                .foregroundStyle(Self.filmOrange)
                .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                .shadow(color: Self.filmOrange.opacity(0.8), radius: 4)
                .shadow(color: Self.filmOrange.opacity(0.45), radius: 9)
                .dynamicTypeSize(.large)
                .padding(.trailing, 20)
                .padding(.bottom, 18)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.75), radius: 40, y: 34)
        .contentShape(shape)
        .onTapGesture { togglePhotoOnly() }
        .accessibilityElement()
        .accessibilityLabel(photoLabel(for: day))
        .accessibilityAddTraits(.isImage)
        .accessibilityHint("ダブルタップで、写真だけを表示します")
        .accessibilityAction { togglePhotoOnly() }
    }

    private func photoLabel(for day: WeekDayPoint) -> String {
        var label = "\(WeekDayCard.dateLabel(day.date))の写真。\(day.remainingText)"
        let targets = ProfileShot.spokenShareTargets(groups: day.groups, isOnMondo: day.isOnMondo)
        if !targets.isEmpty { label += "。共有先、\(targets)" }
        return label
    }

    // MARK: - 上のバー・情報・レール

    private func chrome(layout: Layout) -> some View {
        ZStack(alignment: .top) {
            topBar
                .padding(.horizontal, 22)
                .offset(y: layout.barTop)

            if let current {
                infoBlock(for: current)
                    .padding(.horizontal, 28)
                    .frame(width: layout.width, alignment: .leading)
                    .onGeometryChange(for: CGFloat.self, of: \.size.height) { infoHeight = $0 }
                    .offset(y: layout.infoTop)
            }

            rail
                .frame(width: Self.railWidth, height: Self.railHeight)
                .frame(width: layout.width)
                .offset(y: layout.railTop)
        }
        .frame(width: layout.width, alignment: .top)
    }

    private var topBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(ViewerGlass(shape: Circle(), opaque: reduceTransparency))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("閉じる")

            Spacer(minLength: 12)

            if let current {
                sharePill(for: current)
            }
        }
        .frame(height: 44)
    }

    private func sharePill(for day: WeekDayPoint) -> some View {
        Button {
            haptics.playTransient(intensity: 0.25, sharpness: 0.4)
            isConfirmingDelete = false
            withAnimation(.timingCurve(0.22, 0.8, 0.24, 1, duration: 0.4)) { isShareSheetOpen = true }
        } label: {
            HStack(spacing: 7) {
                HStack(spacing: -5) {
                    if !day.groups.isEmpty {
                        ShareTargetDot(gradient: Self.groupGradient, size: 16)
                    }
                    if day.isOnMondo {
                        ShareTargetDot(gradient: Self.mondoGradient, size: 16)
                    }
                }
                Text(ProfileShot.shareSummary(groups: day.groups, isOnMondo: day.isOnMondo))
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(-0.01 * 13)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.leading, 12)
            .padding(.trailing, 14)
            .frame(height: 40)
            .background(ViewerGlass(shape: Capsule(), opaque: reduceTransparency))
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("共有先、\(ProfileShot.spokenShareTargets(groups: day.groups, isOnMondo: day.isOnMondo).replacingOccurrences(of: "、", with: "と "))")
        .accessibilityHint("ダブルタップで詳しく")
    }

    private func infoBlock(for day: WeekDayPoint) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(WeekDayCard.dateLabel(day.date))
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.05 * 34)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 12)
                RemainingMeter(remainingDays: day.remainingDays, text: day.remainingText)
            }

            Text(subtitle(for: day))
                .font(.system(size: 11.5, design: .monospaced))
                .tracking(0.1 * 11.5)
                .foregroundStyle(Color(hex: "A6A6AD"))
                .padding(.top, 11)

            if !day.tags.isEmpty {
                OnboardingFlowLayout(spacing: 7) {
                    ForEach(day.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(.white.opacity(0.1)))
                            .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1))
                    }
                }
                .padding(.top, 14)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 日付レール

    private enum SlotKind: Equatable {
        case opened(WeekDayPoint)
        case notOpened(WeekDayPoint)
        case missing
    }

    private var railSlots: [(key: String, kind: SlotKind)] {
        ProfileShot.railDayKeys(now: Date()).map { key in
            guard let shot = shots.first(where: { $0.id == key }) else { return (key, .missing) }
            return (key, shot.opened ? .opened(shot) : .notOpened(shot))
        }
    }

    private static func slotX(_ index: Int) -> CGFloat { 20 + CGFloat(index) * 45 }
    private static let slotY: CGFloat = 18
    /// にじみを切らないための、描画領域のはみ出し
    private static let railBleed: CGFloat = 24

    private var rail: some View {
        let slots = railSlots
        return Canvas { graphics, _ in
            graphics.translateBy(x: Self.railBleed, y: Self.railBleed)
            drawRail(slots: slots, in: &graphics)
        }
        .frame(width: Self.railWidth + Self.railBleed * 2, height: Self.railHeight + Self.railBleed * 2)
        .padding(-Self.railBleed)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in railTouch(at: value.location.x, slots: slots) }
                .onEnded { _ in railTouchedKey = nil }
        )
        .accessibilityElement()
        .accessibilityLabel("日付")
        .accessibilityValue(current.map { "\(WeekDayCard.dateLabel($0.date))、\($0.remainingText)" } ?? "")
        .accessibilityHint(shots.contains { !$0.opened } ? "今日の写真、あしたの朝にひらきます" : "")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(by: 1)
            case .decrement: step(by: -1)
            @unknown default: break
            }
        }
    }

    private func drawRail(slots: [(key: String, kind: SlotKind)], in graphics: inout GraphicsContext) {
        // 糸:ある日どうしを、撮らなかった日をまたいで隣から隣へ
        var previous: (point: CGPoint, weight: Double)?
        for (index, slot) in slots.enumerated() {
            let shot: WeekDayPoint
            switch slot.kind {
            case .opened(let s), .notOpened(let s): shot = s
            case .missing: continue
            }
            let point = CGPoint(x: Self.slotX(index), y: Self.slotY)
            if let previous {
                var path = Path()
                path.move(to: previous.point)
                path.addLine(to: point)
                graphics.stroke(
                    path,
                    with: .color(.white.opacity(0.55 * min(previous.weight, shot.weight))),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1, 5])
                )
            }
            previous = (point, shot.weight)
        }

        for (index, slot) in slots.enumerated() {
            let center = CGPoint(x: Self.slotX(index), y: Self.slotY)
            switch slot.kind {
            case .missing:
                graphics.fill(Self.circle(center, 1.4), with: .color(.white.opacity(0.18)))
            case .notOpened:
                graphics.stroke(Self.circle(center, 5.2), with: .color(.white.opacity(0.5)), lineWidth: 1.4)
                graphics.fill(Self.circle(center, 1.8), with: .color(.white.opacity(0.6)))
            case .opened(let shot):
                let color = shot.color ?? .white
                if shot.id == currentID {
                    graphics.drawLayer { layer in
                        layer.addFilter(.blur(radius: 6))
                        layer.fill(Self.circle(center, 15), with: .color(color.opacity(0.5)))
                    }
                    graphics.drawLayer { layer in
                        layer.addFilter(.shadow(color: .white.opacity(0.9), radius: 5))
                        layer.fill(Self.circle(center, 7), with: .color(.white))
                    }
                    graphics.draw(
                        Text(Self.railLabelFormatter.string(from: shot.date))
                            .font(.system(size: 10.5, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(.white),
                        at: CGPoint(x: center.x, y: center.y + 18)
                    )
                } else {
                    graphics.fill(Self.circle(center, 4), with: .color(color.opacity(shot.weight)))
                }
            }
        }
    }

    private static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    /// 指にいちばん近い枠を選ぶ
    private func railTouch(at x: CGFloat, slots: [(key: String, kind: SlotKind)]) {
        let index = min(slots.count - 1, max(0, Int(((x - 20) / 45).rounded())))
        let slot = slots[index]
        guard slot.key != railTouchedKey else { return }
        railTouchedKey = slot.key
        switch slot.kind {
        case .opened(let shot):
            guard shot.id != currentID else { return }
            haptics.playTransient(intensity: 0.25, sharpness: 0.4)
            withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : Self.slideAnimation) { currentID = shot.id }
        case .notOpened:
            presentNotOpenedToast()
        case .missing:
            break
        }
    }

    private func presentNotOpenedToast() {
        haptics.playSoftDouble()
        toastToken += 1
        let token = toastToken
        withAnimation(.easeOut(duration: 0.2)) { showsNotOpenedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            guard token == toastToken else { return }
            withAnimation(.easeOut(duration: 0.25)) { showsNotOpenedToast = false }
        }
    }

    private var notOpenedToast: some View {
        Text("まだ、ひらいていません ・ あしたの朝")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(ViewerGlass(shape: Capsule(), opaque: reduceTransparency))
            .frame(maxWidth: .infinity)
    }

    // MARK: - ジェスチャー

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isShareSheetOpen else { return }
                let dx = value.translation.width, dy = value.translation.height
                if dragAxis == nil { dragAxis = abs(dy) > abs(dx) ? .vertical : .horizontal }
                if dragAxis == .vertical {
                    dragOffsetY = max(0, dy)
                } else if !reduceMotion {
                    let atEdge = (currentIndex == 0 && dx > 0) || (currentIndex == days.count - 1 && dx < 0)
                    dragOffsetX = atEdge ? dx * 0.3 : dx
                }
            }
            .onEnded { value in
                defer { dragAxis = nil }
                guard !isShareSheetOpen else { return }
                let dx = value.translation.width, dy = value.translation.height
                if dragAxis == .vertical, dy > Self.dismissThreshold {
                    onDismiss()
                    return
                }
                if dragAxis == .horizontal, abs(dx) > Self.swipeThreshold {
                    step(by: dx < 0 ? 1 : -1)
                }
                withAnimation(dragAxis == .horizontal ? Self.slideAnimation : .spring(response: 0.38, dampingFraction: 0.72)) {
                    dragOffsetY = 0
                    dragOffsetX = 0
                }
            }
    }

    /// 前後のひらいた日へ(撮らなかった日は、そもそも days に無いので飛ばされる)
    private func step(by delta: Int) {
        let newIndex = currentIndex + delta
        guard days.indices.contains(newIndex) else {
            haptics.playTransient(intensity: 0.6, sharpness: 0.5)
            return
        }
        haptics.playTransient(intensity: 0.25, sharpness: 0.4)
        withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : Self.slideAnimation) {
            currentID = days[newIndex].id
            dragOffsetX = 0
        }
    }

    private func togglePhotoOnly() {
        withAnimation(.easeInOut(duration: photoOnly ? 0.35 : 0.45)) { photoOnly.toggle() }
    }

    private func subtitle(for day: WeekDayPoint) -> String {
        var parts = [WeekDayCard.weekdayLabel(day.date)]
        if let location = day.locationName { parts.append(location) }
        return parts.joined(separator: " ・ ")
    }

    // MARK: - 共有先シート

    private func closeShareSheet() {
        withAnimation(.easeOut(duration: 0.28)) {
            isShareSheetOpen = false
            sheetDrag = 0
        }
        isConfirmingDelete = false
    }

    private func shareSheet(for day: WeekDayPoint, bottomInset: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.62)
                .onTapGesture { closeShareSheet() }
                .transition(.opacity)

            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(.white.opacity(0.25))
                    .frame(width: 40, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)

                Text("この写真の共有先")
                    .font(.system(size: 18, weight: .bold))
                    .tracking(-0.03 * 18)
                    .foregroundStyle(.white)
                    .padding(.top, 18)
                Text("\(Self.railLabelFormatter.string(from: day.date)) ・ \(day.remainingText)")
                    .font(.system(size: 10.5, design: .monospaced))
                    .tracking(0.14 * 10.5)
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .padding(.top, 6)

                VStack(spacing: 14) {
                    ForEach(Array(day.groups.enumerated()), id: \.offset) { _, group in
                        shareRow(
                            gradient: Self.groupGradient,
                            title: group.name,
                            detail: group.otherMemberCount > 0 ? "グループの\(group.otherMemberCount)人に届いています" : "グループに届いています",
                            isOn: true
                        )
                    }
                    shareRow(
                        gradient: Self.mondoGradient,
                        title: "Mondo",
                        detail: day.isOnMondo
                            ? "世界の昨日に並びます(審査あり)"
                            : (isMondoSettingOn ? "この日の1枚は、いま Mondo に出ていません" : "公開をオフにしています"),
                        isOn: day.isOnMondo
                    )
                }
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 0) {
                    Text("共有されるのは、毎日の1枚だけです。")
                    Text("プロフィールにも、その1枚だけが並びます。")
                }
                .font(.system(size: 11.5))
                .lineSpacing(9)
                .foregroundStyle(Color(hex: "A6A6AD"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.045)))
                .padding(.top, 18)

                deleteArea(for: day)
                    .padding(.top, 18)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, max(22, bottomInset))
            .background(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "1D1D21"), Color(hex: "101012")], startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            .offset(y: max(0, sheetDrag))
            .gesture(
                DragGesture()
                    .onChanged { sheetDrag = $0.translation.height }
                    .onEnded { value in
                        if value.translation.height > 90 {
                            closeShareSheet()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { sheetDrag = 0 }
                        }
                    }
            )
            .transition(.move(edge: .bottom))
        }
        .accessibilityAddTraits(.isModal)
    }

    private func shareRow(gradient: [Color], title: String, detail: String, isOn: Bool) -> some View {
        HStack(spacing: 12) {
            ShareTargetDot(gradient: gradient, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color(hex: "8E8E93"))
            }
            Spacer(minLength: 8)
            Text(isOn ? "ON" : "OFF")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(isOn ? Color(hex: "8DE0B4") : Color(hex: "6B6B70"))
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func deleteArea(for day: WeekDayPoint) -> some View {
        if isConfirmingDelete {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { isConfirmingDelete = false }
                } label: {
                    Text("やめる")
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Capsule().fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)

                Button { delete(day) } label: {
                    Text("消す")
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Capsule().fill(Color(hex: "FF6B5E")))
                }
                .buttonStyle(.plain)
            }
            .transition(.opacity)
        } else {
            Button {
                haptics.playTransient(intensity: 0.25, sharpness: 0.4)
                withAnimation(.easeOut(duration: 0.2)) { isConfirmingDelete = true }
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text("この日の写真を、いま消す")
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(Color(hex: "FF8A7A"))
                    Text("7日を待たずに、すべての共有先から消えます。もとにもどせません。")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color(hex: "8E8E93"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .transition(.opacity)
        }
    }

    /// 消す → 隣の日へ移る(新しい側を優先)。1つもなくなれば閉じる。
    private func delete(_ day: WeekDayPoint) {
        haptics.playTransient(intensity: 1.0, sharpness: 0.7)
        let remaining = days.filter { $0.id != day.id }
        let index = currentIndex
        let next = remaining.indices.contains(index) ? remaining[index] : remaining.last
        closeShareSheet()
        if let next {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : Self.slideAnimation) { currentID = next.id }
            onDelete(day)
        } else {
            onDelete(day)
            onDismiss()
        }
    }

    // MARK: - 色・書式

    static let filmOrange = Color(hex: "FFA65E")
    static let groupGradient = [Color(hex: "FFB48A"), Color(hex: "9A6CF0")]
    static let mondoGradient = [Color(hex: "6AA8FF"), Color(hex: "7BE0C8")]

    private static let railLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "MM.dd"
        return formatter
    }()

    /// 親(Profile)が Safe Area を無視しているので、窓の Safe Area を直接読む。
    private static var windowSafeInsets: UIEdgeInsets {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        return (windows.first(where: \.isKeyWindow) ?? windows.first)?.safeAreaInsets ?? .zero
    }
}

// MARK: - 部品

/// 「×」と「共有先」のガラス(白14%→5%のたてグラデ・内側に白10%の線・背景ぼかし)。
/// 「透明度を下げる」では不透明な #1c1c20。
private struct ViewerGlass<S: InsettableShape>: View {
    let shape: S
    let opaque: Bool

    var body: some View {
        if opaque {
            shape.fill(Color(hex: "1C1C20"))
                .overlay(shape.strokeBorder(.white.opacity(0.1), lineWidth: 1))
        } else {
            shape.fill(.ultraThinMaterial.opacity(0.6))
                .overlay(shape.fill(LinearGradient(colors: [.white.opacity(0.14), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom)))
                .overlay(shape.strokeBorder(.white.opacity(0.1), lineWidth: 1))
        }
    }
}

/// 共有先の丸(グループ = オレンジ→紫、Mondo = 青→ミント)
private struct ShareTargetDot: View {
    let gradient: [Color]
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(.white.opacity(size > 20 ? 0.12 : 0.9), lineWidth: size > 20 ? 1 : 1.2))
            .accessibilityHidden(true)
    }
}

/// 残りの目盛り:7本の縦棒のうち、左から残り日数ぶんが点灯。下に文言。
private struct RemainingMeter: View {
    let remainingDays: Int
    let text: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 7) {
            HStack(spacing: 4) {
                ForEach(0..<ProfileShot.railSlotCount, id: \.self) { index in
                    let lit = index < remainingDays
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(lit
                              ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "FFD0A0"), Color(hex: "FF9A4D")], startPoint: .top, endPoint: .bottom))
                              : AnyShapeStyle(Color.white.opacity(0.17)))
                        .frame(width: 3, height: 13)
                        .shadow(color: lit ? Color(hex: "FF9A4D").opacity(0.55) : .clear, radius: 4)
                }
            }
            Text(text)
                .font(.system(size: 10.5, design: .monospaced))
                .tracking(0.06 * 10.5)
                .foregroundStyle(Color(hex: "FFB36B"))
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.top, 6)
        .accessibilityElement()
        .accessibilityLabel(text)
    }
}
