import SwiftUI

/// 昨日を見る画面に出す1枚(昨日の窓に撮られた写真)。
struct YesterdayItem: Identifiable, Equatable {
    let id: String
    let imageData: Data?
    let cacheKey: String
    let authorName: String
    let authorSeed: UUID
    let locationName: String?
    let tags: [String]
    let captureDate: Date
    let isMine: Bool
}

/// 範囲:みんな(参加しているすべてのグループ)か、ひとつのグループ
enum YesterdayScope: Hashable {
    /// みんな(参加しているすべてのグループ)
    case everyone
    /// 自分の1枚だけ
    case mine
    /// Mondo(世界の昨日)
    case mondo
    case group(UUID)
}

extension YesterdayItem {
    /// 昨日の窓の写真を集める。同じ1枚(グループごとの複製)はまとめ、自分の1枚は最後に置く。
    /// 並び順はランダム(固定だと、順位に見えてしまう)。
    static func collect(from groups: [LaterGroup], myRecordName: String?, myProfileID: UUID?, blocked: Set<String> = [], now: Date, calendar: Calendar = .current) -> [YesterdayItem] {
        let window = DailyWindow.yesterday(for: now, calendar: calendar)
        var seen = Set<String>()
        var mine: [YesterdayItem] = []
        var others: [YesterdayItem] = []
        for group in groups {
            // 投稿した写真だけ(撮った時点では画像以外だけが届いている)
            for photo in group.photos where photo.isPosted && photo.captureDate >= window.open && photo.captureDate < window.close {
                if let author = photo.authorCloudKitUserRecordName, blocked.contains(author) { continue }
                let key = photo.dedupeKey
                guard seen.insert(key).inserted else {
                    // 画像が届いている方を優先する
                    if let i = others.firstIndex(where: { $0.id == key }), (others[i].imageData?.isEmpty ?? true), !photo.imageData.isEmpty {
                        others[i] = item(photo, key: key, isMine: false)
                    }
                    continue
                }
                let isMine = (myRecordName != nil && photo.authorCloudKitUserRecordName == myRecordName)
                    || (myProfileID != nil && photo.owner?.id == myProfileID)
                let entry = item(photo, key: key, isMine: isMine)
                if isMine { mine.append(entry) } else { others.append(entry) }
            }
        }
        return others.shuffled() + mine
    }

    private static func item(_ photo: LaterPhoto, key: String, isMine: Bool) -> YesterdayItem {
        YesterdayItem(
            id: key,
            imageData: photo.imageData.isEmpty ? nil : photo.imageData,
            cacheKey: photo.imageCacheKey,
            authorName: isMine ? "あなた" : (photo.authorNameCache ?? photo.owner?.name ?? "だれか"),
            authorSeed: photo.owner?.id ?? photo.id,
            locationName: photo.locationName,
            tags: photo.tags,
            captureDate: photo.captureDate,
            isMine: isMine
        )
    }
}

/// 昨日を見る(全画面)。写真は端から端まで。上にスワイプで次の人へ(縦のページング)。
/// いいね・コメント・リアクション・保存・共有のボタンは置かない。
struct YesterdayViewer: View {
    /// nilなら取得できなかった(エラーのカード)
    let items: [YesterdayItem]?
    let scope: YesterdayScope
    /// 範囲のピルで選べるグループ
    let groups: [LaterGroup]
    let haptics: ExposureHaptics
    let onScopeChange: (YesterdayScope) -> Void
    let onRetry: () -> Void
    let onClose: () -> Void
    /// 範囲のピルの代わりに出す固定のラベル(Mondo:「Mondo」「#コーヒー」)。nilならピル
    var fixedTitle: String? = nil
    /// 枚数表示の分母(Mondo:世界の光の数。nil なら並んでいる枚数)
    var totalCount: Int? = nil
    var initialIndex = 0
    /// 端末にない画像を読む(Mondo)。nilなら item.imageData を使う
    var remoteImage: ((YesterdayItem) async -> UIImage?)? = nil
    /// 「ここまで。」のカードの文言(nilなら昨日の文言)
    var endMessage: (title: String, body: String)? = nil
    /// 右下の ⋯(通報・ブロック)。nilなら出さない
    var onMore: ((YesterdayItem) -> Void)? = nil
    /// 空の画面:「自分」のとき、みんなに1枚以上あるか
    var everyoneHasPhotos = false
    /// 空の画面:Mondo を読みこみ中か
    var isReloading = false
    /// 空の画面:今日の1枚を撮ったか(今日のカード)
    var showsTodayCard = false
    /// 範囲メニューに Mondo を出すか
    var offersMondo = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var drag: CGFloat = 0
    @State private var isChromeHidden = false
    @State private var isScopeMenuOpen = false
    /// ひらく瞬間の現像(0 → 1、約1.8秒)
    @State private var reveal: Double = 0

    private var pageCount: Int { (items?.count ?? 0) + 1 }

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            ZStack(alignment: .top) {
                Color.black

                Group {
                    if let emptyKind {
                        // 見ている範囲に写真が1枚もない(写真がある範囲の「ここまで。」とは別物)
                        EmptyYesterdayView(
                            kind: emptyKind,
                            everyoneHasPhotos: everyoneHasPhotos,
                            isReloading: isReloading,
                            showsTodayCard: showsTodayCard,
                            haptics: haptics,
                            onSeeEveryone: { onScopeChange(.everyone) },
                            onReload: onRetry
                        )
                    } else if let items {
                        pages(items, height: h, width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing)
                    } else {
                        errorCard
                    }
                }
                .id(emptyKind == nil ? "pages-\(scope)" : "empty")
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.4), value: emptyKind == nil)

                chrome(safeTop: proxy.safeAreaInsets.top)
                    .opacity(isChromeHidden ? 0 : 1)
                    .animation(.easeInOut(duration: 0.25), value: isChromeHidden)

                if isScopeMenuOpen {
                    Color.black.opacity(0.001)
                        .onTapGesture { closeScopeMenu() }
                    scopeMenu(safeTop: proxy.safeAreaInsets.top)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: -6)).combined(with: .scale(scale: 0.97, anchor: .topTrailing)), removal: .opacity))
                }
            }
            .ignoresSafeArea()
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            index = initialIndex
            playReveal()
        }
        .onChange(of: scope) { _, _ in
            index = 0
            playReveal()
        }
    }

    /// 空の画面を出す範囲(写真が1枚もない)。Mondo は取得の失敗・集計がまだでも空の画面にする。
    private var emptyKind: EmptyYesterdayView.Kind? {
        switch scope {
        case .mondo:
            return (items?.isEmpty ?? true) ? .mondo : nil
        case .mine:
            return items?.isEmpty == true ? .mine : nil
        case .everyone, .group:
            return items?.isEmpty == true ? .everyone : nil
        }
    }

    private func playReveal() {
        reveal = 0
        withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .easeOut(duration: 1.8)) { reveal = 1 }
    }

    // MARK: - ページ

    private func pages(_ items: [YesterdayItem], height: CGFloat, width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                if abs(i - index) <= 1 {
                    page(item, isFirst: i == 0, width: width, height: height)
                        .offset(y: CGFloat(i - index) * height + drag)
                }
            }
            if abs(items.count - index) <= 1 {
                endCard
                    .frame(width: width, height: height)
                    .offset(y: CGFloat(items.count - index) * height + drag)
            }
        }
        .frame(width: width, height: height, alignment: .top)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { isChromeHidden.toggle() }
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    let atEdge = (index == 0 && value.translation.height > 0) || (index == pageCount - 1 && value.translation.height < 0)
                    drag = atEdge ? value.translation.height * 0.3 : value.translation.height
                }
                .onEnded { value in
                    var next = index
                    if value.translation.height < -70 { next += 1 }
                    if value.translation.height > 70 { next -= 1 }
                    let clamped = min(max(0, next), pageCount - 1)
                    if clamped != index {
                        haptics.playTransient(intensity: 0.3, sharpness: 0.4)
                    } else if next != index {
                        haptics.playTransient(intensity: 0.55, sharpness: 0.5)
                    }
                    withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .timingCurve(0.22, 0.8, 0.24, 1, duration: 0.5)) {
                        index = clamped
                        drag = 0
                    }
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityScrollAction { edge in
            let next = edge == .bottom ? index + 1 : index - 1
            index = min(max(0, next), pageCount - 1)
        }
    }

    private func page(_ item: YesterdayItem, isFirst: Bool, width: CGFloat, height: CGFloat) -> some View {
        let r = isFirst ? reveal : 1
        return ZStack(alignment: .bottomLeading) {
            Group {
                if let remoteImage {
                    RemotePhoto(item: item, load: remoteImage) { image in
                        developed(image, r: r, width: width, height: height)
                    }
                } else {
                    localPhoto(item, r: r, width: width, height: height)
                }
            }
            .frame(width: width, height: height)
            .accessibilityLabel("\(item.authorName)の昨日の1枚")

            pageOverlay(item)
        }
        .frame(width: width, height: height)
    }

    private func developed(_ image: UIImage, r: Double, width: CGFloat, height: CGFloat) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height)
            .clipped()
            .blur(radius: 34 * (1 - r))
            .saturation(0.15 + 0.85 * r)
            .brightness(-0.45 * (1 - r))
            .scaleEffect(1 + 0.12 * (1 - r))
    }

    private func localPhoto(_ item: YesterdayItem, r: Double, width: CGFloat, height: CGFloat) -> some View {
            CachedPhotoImage(imageData: item.imageData, cacheKey: item.cacheKey) { image in
                developed(image, r: r, width: width, height: height)
            } placeholder: {
                ZStack {
                    Color(hex: "121214")
                    if item.imageData == nil {
                        Text("この1枚は、まだ届いていません")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "8E8E93"))
                    }
                }
            }
    }

    private func pageOverlay(_ item: YesterdayItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            // 上は暗く、下は黒へ溶ける
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom).frame(height: 180)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom).frame(height: 300)
            }
            .allowsHitTesting(false)

            info(item)
                .padding(.leading, 26)
                .padding(.bottom, 78)
                .opacity(isChromeHidden ? 0 : 1)
                .animation(.easeInOut(duration: 0.25), value: isChromeHidden)

            if let onMore {
                Button { onMore(item) } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.isMine ? "取り下げる" : "報告・見えなくする")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 20)
                .padding(.bottom, 74)
                .opacity(isChromeHidden ? 0 : 1)
            }
        }
    }

    private func info(_ item: YesterdayItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                PersonaIcon(seed: item.authorSeed)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                Text(item.authorName)
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-0.03 * 24)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Text([item.locationName, "昨日"].compactMap { $0 }.joined(separator: " ・ "))
                .font(.system(size: 11, design: .monospaced))
                .tracking(0.1 * 11)
                .foregroundStyle(.white.opacity(0.7))
            if !item.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(item.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(.white.opacity(0.14)))
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var endCard: some View {
        VStack(spacing: 14) {
            Text(endMessage?.title ?? "ここまで。")
                .font(.system(size: endMessage == nil ? 28 : 22, weight: .bold))
                .foregroundStyle(.white)
            Text("THE END OF YESTERDAY")
                .font(.system(size: 10.5, design: .monospaced))
                .tracking(0.2 * 10.5)
                .foregroundStyle(HomePalette.orange)
            Text(endMessage?.body ?? (items?.isEmpty == true ? "昨日は、まだ誰も撮っていませんでした" : (items?.allSatisfy(\.isMine) == true ? "昨日は、あなたの1枚だけでした" : "今日の1枚は、あしたの朝にひらきます")))
                .font(.system(size: 13))
                .foregroundStyle(HomePalette.subText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private var errorCard: some View {
        VStack(spacing: 16) {
            Text("いま、ひらけませんでした。")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Button(action: onRetry) {
                Text("もう一度")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 上の段・右の道すじ

    private func chrome(safeTop: CGFloat) -> some View {
        ZStack(alignment: .top) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.ultraThinMaterial))
                        .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("閉じる")
                Spacer()
                if let fixedTitle {
                    Text(fixedTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(Capsule().fill(.ultraThinMaterial))
                } else {
                    scopePill
                }
            }
            .padding(.horizontal, 18)

            Text(emptyKind == nil ? counterText : "")
                .font(.system(size: 11, design: .monospaced))
                .tracking(0.16 * 11)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.85))
                .frame(height: 44)

            Text(filmDate)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(HomePalette.orange)
                .shadow(color: HomePalette.orange.opacity(0.8), radius: 4)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 24)
                .padding(.top, 58)
                .accessibilityHidden(true)

            if emptyKind == nil {
                trail
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, 14)
            }
        }
        .padding(.top, safeTop + 6)
    }

    private var counterText: String {
        guard let items, !items.isEmpty else { return "" }
        let shown = min(index + 1, items.count)
        let total = max(totalCount ?? items.count, items.count)
        return String(format: "%02d / ", shown) + total.formatted(.number.grouping(.automatic))
    }

    private var filmDate: String {
        let date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "'%02d %02d %02d", (c.year ?? 0) % 100, c.month ?? 0, c.day ?? 0)
    }

    /// 右端の小さな点の道すじ(いまの位置だけ大きく光る)
    private var trail: some View {
        let count = min(pageCount, 14)
        let start = max(0, min(index - count / 2, pageCount - count))
        return VStack(spacing: 7) {
            ForEach(start..<(start + count), id: \.self) { i in
                Circle()
                    .fill(.white.opacity(i == index ? 1 : 0.3))
                    .frame(width: i == index ? 6 : 3.5, height: i == index ? 6 : 3.5)
                    .shadow(color: i == index ? .white : .clear, radius: 4)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: index)
        .accessibilityHidden(true)
    }

    private var scopeTitle: String {
        switch scope {
        case .everyone: return "みんな"
        case .mine: return "自分"
        case .mondo: return "Mondo"
        case .group(let id): return groups.first { $0.id == id }?.name ?? "グループ"
        }
    }

    /// 範囲ボタン(タップでメニュー。ごく軽く1回)
    private var scopePill: some View {
        Button {
            haptics.playTransient(intensity: 0.3, sharpness: 0.4)
            withAnimation(.easeOut(duration: 0.22)) { isScopeMenuOpen.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(scopeTitle).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                    .rotationEffect(.degrees(isScopeMenuOpen ? 180 : 0))
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("範囲、\(scopeTitle)")
        .accessibilityHint("範囲を切りかえます")
    }

    private var scopeOptions: [(YesterdayScope, String)] {
        var options: [(YesterdayScope, String)] = [(.everyone, "みんな"), (.mine, "自分")]
        if offersMondo { options.append((.mondo, "Mondo")) }
        options += groups.map { (.group($0.id), $0.name) }
        return options
    }

    /// 0.22秒でひらく(透明 → 不透明、上から6pt下がる、0.97倍 → 1倍)
    private func scopeMenu(safeTop: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(scopeOptions.enumerated()), id: \.offset) { i, option in
                if i == 3 { Divider().overlay(.white.opacity(0.08)) }
                Button { switchScope(option.0) } label: {
                    HStack {
                        Text(option.1).lineLimit(1)
                        Spacer(minLength: 12)
                        if option.0 == scope {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(HomePalette.orange)
                        }
                    }
                    .font(.system(size: 14, weight: option.0 == scope ? .semibold : .regular))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(option.0 == scope ? [.isSelected] : [])
            }
        }
        .frame(width: 190)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 18)
        .padding(.top, safeTop + 6 + 44 + 6)
    }

    private func closeScopeMenu() {
        withAnimation(.easeOut(duration: 0.18)) { isScopeMenuOpen = false }
    }

    /// 範囲をかえる(ごく軽く1回)
    private func switchScope(_ next: YesterdayScope) {
        closeScopeMenu()
        guard next != scope else { return }
        haptics.playTransient(intensity: 0.3, sharpness: 0.4)
        onScopeChange(next)
    }
}

/// 端末にない写真(Mondo)。読み込むまでは黒のまま、読めたらフェードで出す。
private struct RemotePhoto<Content: View>: View {
    let item: YesterdayItem
    let load: (YesterdayItem) async -> UIImage?
    @ViewBuilder let content: (UIImage) -> Content
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color(hex: "121214")
            if let image { content(image).transition(.opacity) }
        }
        .task(id: item.id) {
            let loaded = await load(item)
            withAnimation(.easeOut(duration: 0.3)) { image = loaded }
        }
    }
}
