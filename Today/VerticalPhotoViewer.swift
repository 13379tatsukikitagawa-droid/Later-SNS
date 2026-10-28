import ImageIO
import SwiftUI
import UIKit

// 写真を見る、縦スクロールの全画面ページ(Home v5 第5章)。どこから開いても同じビューア。
// 1ページ=1枚、縦にピタッと止まる。横スワイプで写真を送る画面は作らない。
// いいね・コメント・保存・共有のボタンは置かない。

/// ビューアの1ページ
struct ViewerPage: Identifiable, Equatable {
    enum Source: Equatable {
        /// 端末にある写真(解禁ずみ)。データが空なら、モザイクで代用する
        case local(Data?)
        /// Mondo の公開写真(取りに行く)
        case mondo(MondoEntry)
    }

    enum Kind: Equatable {
        case photo
        /// 終わりのページ
        case end(title: String, body: String)
    }

    let id: String
    var kind: Kind = .photo
    var source: Source = .local(nil)
    var tags: [String] = []
    var capturedAt: Date?
    /// 撮った日(時刻がないとき:Mondo は「10.25」だけ)
    var dayText: String?
    /// グループの写真:撮った人の丸アイコン
    var authorSeed: UUID?
    var authorImage: Data?
    var showsAuthor = false
    /// 解禁前(鍵つきのモザイクのページ)
    var isLocked = false
    var tiny: Data?
    var tinyKey: String = ""
    /// 左上、‹ の右に出す名前(`#夕焼け` / グループ名)
    var label: String = ""
    /// 右上の「03 / 30」
    var counter: String = ""
    /// Mondo の写真:右上の ⋯(通報・ブロック・取り下げ)の対象
    var moreEntry: MondoEntry?
    /// 灯の置き場所(この場所・この日)。nil なら、灯に関わる表示を何も出さない
    var lamp: LampTarget?
    /// 発表ずみの一枚(押せない、ともったままの点灯アイコンを右下に静かに出す)
    var showsLitMark = false
    /// 世界の一枚:左下に地球のアイコン(丸、44pt)
    var showsGlobe = false
}

/// ビューアのページが属する「灯の置き場所」
struct LampTarget: Equatable {
    /// 撮影日 yyyy-MM-dd
    let day: String
    /// `world` またはグループの recordName
    let scope: String
    /// ともす対象の写真。自分の写真・未解禁のときは nil(灯ボタンを出さない)
    let photoRecordName: String?
}

struct VerticalPhotoViewer: View {
    let pages: [ViewerPage]
    let startIndex: Int
    let haptics: ExposureHaptics
    let onClose: () -> Void
    var onMore: ((MondoEntry) -> Void)?
    /// 灯の状態。nil なら灯の表示は出さない(カレンダーなど)
    var lampBoard: LampBoard?
    var now: Date = Date()
    /// true なら、自前の上のバー(‹・名前・枚数)を出さない。NavigationStack の標準の戻るボタンと、ツールバーの枚数に任せる(カレンダーの日の詳細)
    var usesNavigationChrome = false
    /// 表示中のページが変わった(ツールバーの「01 / 02」用)
    var onPageChange: ((ViewerPage) -> Void)?

    @State private var position: String?
    @State private var lampBurst = 0

    private var currentIndex: Int {
        guard let position, let index = pages.firstIndex(where: { $0.id == position }) else { return min(startIndex, max(0, pages.count - 1)) }
        return index
    }

    private var current: ViewerPage? {
        pages.indices.contains(currentIndex) ? pages[currentIndex] : nil
    }

    init(pages: [ViewerPage], startIndex: Int, haptics: ExposureHaptics, onMore: ((MondoEntry) -> Void)? = nil, lampBoard: LampBoard? = nil, now: Date = Date(), onClose: @escaping () -> Void) {
        self.pages = pages
        self.startIndex = startIndex
        self.haptics = haptics
        self.onMore = onMore
        self.lampBoard = lampBoard
        self.now = now
        self.onClose = onClose
        let start = pages.indices.contains(startIndex) ? pages[startIndex].id : pages.first?.id
        _position = State(initialValue: start)
    }

    /// NavigationStack の中に置く(標準の戻るボタン・ツールバーの枚数を使う)
    func navigationChrome(onPageChange: @escaping (ViewerPage) -> Void) -> VerticalPhotoViewer {
        var copy = self
        copy.usesNavigationChrome = true
        copy.onPageChange = onPageChange
        return copy
    }

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            let w = proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing
            ZStack(alignment: .top) {
                V5.bg.ignoresSafeArea()

                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(pages) { page in
                            ViewerPageView(page: page, topInset: proxy.safeAreaInsets.top, bottomInset: proxy.safeAreaInsets.bottom)
                                .frame(width: w, height: h)
                                .id(page.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $position)
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .ignoresSafeArea()

                lampLayer(width: proxy.size.width, height: h)

                if !usesNavigationChrome {
                    topBar(topInset: proxy.safeAreaInsets.top)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        // 下へ大きく引いたら閉じる(先頭のページにいるとき。ほかのページでは縦の送りを優先する)
                        if currentIndex == 0, value.translation.height > 170, abs(value.translation.width) < 120 { onClose() }
                    }
            )
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .onAppear { if let current { onPageChange?(current) } }
        .onChange(of: position) { old, new in
            if let page = pages.first(where: { $0.id == new }) { onPageChange?(page) }
            guard old != nil, old != new, let page = pages.first(where: { $0.id == new }) else { return }
            // 1枚止まるたびの「カチッ」。解禁前のページは、やわらかく2回
            if page.isLocked { haptics.playSoftDouble() } else { haptics.playPattern(HomeHapticPattern.pageStop) }
        }
    }

    // MARK: - 灯

    /// 灯ボタン(右から24pt・下から140pt)、写真の右下のにじみ、発表ずみの静かな点灯アイコン
    private func lampLayer(width: CGFloat, height: CGFloat) -> some View {
        let target = current?.kind == .photo ? current?.lamp : nil
        let litPhoto = target.flatMap { lampBoard?.litPhoto(day: $0.day, scope: $0.scope) }
        let isThisLit = litPhoto != nil && litPhoto == target?.photoRecordName
        let canPress = target.map { $0.photoRecordName != nil && LampRules.isOpen(photoDay: $0.day, now: now) } ?? false
        return ZStack(alignment: .bottomTrailing) {
            Color.clear
            if lampBoard != nil, target != nil {
                LampBloom(burst: lampBurst, isLit: isThisLit)
            }
            if canPress, let target, let photo = target.photoRecordName {
                LampButton(isLit: isThisLit, burst: lampBurst) { pressLamp(target, photo: photo) }
                    .padding(.trailing, 24)
                    .padding(.bottom, 140)
            } else if current?.showsLitMark == true {
                LampBadge(diameter: 44)
                    .padding(.trailing, 24)
                    .padding(.bottom, 140)
                    .accessibilityLabel("選ばれた一枚")
            }
        }
        .frame(width: width, height: height)
        .ignoresSafeArea()
    }

    private func pressLamp(_ target: LampTarget, photo: String) {
        guard let lampBoard else { return }
        switch lampBoard.toggle(day: target.day, scope: target.scope, photoRecordName: photo, now: now) {
        case .placed, .moved:
            withAnimation(.easeOut(duration: 0.3)) { lampBurst += 1 }
            haptics.playLampPlace()
        case .cancelled:
            haptics.playLampCancel()
        }
    }

    // MARK: - 上のバー

    private func topBar(topInset: CGFloat) -> some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("閉じる")

            if let current, current.kind == .photo {
                Text(current.label)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.6), radius: 4)
                    .contentTransition(.opacity)
                    .animation(.easeOut(duration: 0.25), value: current.label)
            }
            Spacer(minLength: 0)
            if let current, current.kind == .photo, !current.counter.isEmpty {
                Text(current.counter)
                    .font(V5.mono(12))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.6), radius: 4)
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(current.counter.replacingOccurrences(of: "/", with: "枚目、全"))枚")
                    // 枚数の下:この場所の「今日の灯」の状態(どの写真を見ていても点灯して見える)
                    .overlay(alignment: .topTrailing) {
                        if let target = current.lamp, let lampBoard {
                            LampStatusDot(isLit: lampBoard.isLit(day: target.day, scope: target.scope))
                                .offset(y: 22)
                        }
                    }
            }
            if let entry = current?.moreEntry, let onMore {
                Button { onMore(entry) } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.ultraThinMaterial))
                        .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("この写真について")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, topInset + 4)
    }
}

// MARK: - 1ページ

private struct ViewerPageView: View {
    let page: ViewerPage
    let topInset: CGFloat
    let bottomInset: CGFloat

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            V5.bg
            switch page.kind {
            case .end(let title, let body):
                endPage(title: title, body: body)
            case .photo:
                photoPage
            }
        }
    }

    private func endPage(title: String, body: String) -> some View {
        VStack(spacing: 12) {
            Circle().fill(V5.amber).frame(width: 9, height: 9).shadow(color: V5.amber, radius: 8)
            Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
            Text(body).font(.system(size: 12.5)).foregroundStyle(Color(hex: "8E8E93"))
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 30)
    }

    private var photoPage: some View {
        ZStack {
            // 薄い紙の縁(6pt)の内側に、角丸46ptの写真
            RoundedRectangle(cornerRadius: 50, style: .continuous)
                .fill(Color(hex: "EFE6D6").opacity(0.14))
                .padding(.vertical, 0)
            photoBody
                .clipShape(RoundedRectangle(cornerRadius: 46, style: .continuous))
                .padding(6)

            // 上に暗いグラデ、下に暗いグラデ(330pt)、左上に光のもれ
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom).frame(height: 200)
                Spacer(minLength: 0)
                LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .top, endPoint: .bottom).frame(height: 330)
            }
            .clipShape(RoundedRectangle(cornerRadius: 46, style: .continuous))
            .padding(6)
            .allowsHitTesting(false)

            RadialGradient(colors: [V5.amber.opacity(0.28), .clear], center: .topLeading, startRadius: 0, endRadius: 260)
                .blendMode(.screen)
                .clipShape(RoundedRectangle(cornerRadius: 46, style: .continuous))
                .padding(6)
                .allowsHitTesting(false)

            if page.isLocked { lockBadge }

            captions
        }
        .task(id: page.id) { await load() }
    }

    @ViewBuilder
    private var photoBody: some View {
        ZStack {
            MosaicView(tiny: page.tiny, key: page.tinyKey, level: .l0)
            if !page.isLocked, let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            }
        }
        .clipped()
    }

    /// 中央の鍵(ガラスの丸)
    private var lockBadge: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(.white.opacity(0.92))
            .frame(width: 84, height: 84)
            .background(Circle().fill(.ultraThinMaterial))
            .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 12)
            .accessibilityLabel("まだひらいていない写真")
    }

    private var captions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    if page.showsGlobe {
                        Image(systemName: "globe")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.ultraThinMaterial))
                            .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1.5))
                            .shadow(color: .black.opacity(0.4), radius: 4)
                            .accessibilityLabel("世界の一枚")
                    }
                    if page.showsAuthor, let seed = page.authorSeed {
                        AuthorDot(seed: seed, imageData: page.authorImage)
                            .frame(width: 44, height: 44)
                    }
                    ForEach(Array(page.tags.prefix(2).enumerated()), id: \.offset) { index, tag in
                        Text("#\(tag)")
                            .font(V5.hand(index == 0 ? 25 : 19))
                            .foregroundStyle(.white.opacity(index == 0 ? 1 : 0.88))
                            .shadow(color: .black.opacity(0.65), radius: 5, y: 1)
                    }
                }
                Spacer(minLength: 8)
                if let text = dateText {
                    Text(text)
                        .font(V5.mono(13, weight: .medium))
                        .foregroundStyle(V5.amber)
                        .shadow(color: .black.opacity(0.6), radius: 4)
                        .rotationEffect(.degrees(-3))
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.bottom, max(34, bottomInset + 20))
        .allowsHitTesting(false)
    }

    private var dateText: String? {
        if let capturedAt = page.capturedAt { return V5.stamp(capturedAt) }
        return page.dayText
    }

    // MARK: - 読みこみ

    private func load() async {
        guard !page.isLocked, page.kind == .photo else { return }
        switch page.source {
        case .local(let data):
            guard let data, !data.isEmpty else { return }
            let decoded = await Task.detached(priority: .userInitiated) { Self.downsample(data, maxPixel: 1800) }.value
            withAnimation(.easeOut(duration: 0.25)) { image = decoded }
        case .mondo(let entry):
            if let thumb = await MondoService.shared.thumbnail(for: entry) {
                withAnimation(.easeOut(duration: 0.2)) { image = thumb }
            }
            if let full = await MondoService.shared.fullImage(for: entry) {
                withAnimation(.easeOut(duration: 0.25)) { image = full }
            }
        }
    }

    nonisolated private static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map { UIImage(cgImage: $0) }
    }
}

/// 撮った人の丸アイコン(プロフィール画像があればそれ、なければペルソナ)
struct AuthorDot: View {
    let seed: UUID
    let imageData: Data?

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                PersonaIcon(seed: seed)
            }
        }
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.55), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.4), radius: 4)
    }
}
