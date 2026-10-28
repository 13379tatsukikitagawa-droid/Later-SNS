import SwiftData
import SwiftUI

// MARK: - 入れ物(ようこそ → トップ → ことばのページ → ビューア)

/// Mondo(世界の「昨日」)。Home の光の球から入る。反応も競争も作らず、終わりがある。
struct MondoRootView: View {
    let now: Date
    let haptics: ExposureHaptics
    let onClose: () -> Void

    private enum Load: Equatable {
        case loading
        case ready(MondoDaySummary)
        /// サーバの審査がまだ・その日の Mondo がまだできていない
        case notReady
        case failed
    }

    @Environment(\.modelContext) private var modelContext
    @Query private var blockedUsers: [BlockedUser]
    @AppStorage("mondoSeen") private var mondoSeen = false

    @State private var load: Load = .loading
    @State private var showingWelcome = false
    @State private var tagPage: String?
    @State private var viewer: ViewerContext?
    @State private var showingSettings = false
    @State private var reportTarget: MondoEntry?
    @State private var isShown = false

    struct ViewerContext: Identifiable {
        let id = UUID()
        let title: String
        let entries: [MondoEntry]
        let start: Int
        /// 枚数表示の分母(Mondo ぜんたいは世界の光の数。ことばのページは、そのことばの数)
        var total: Int?
    }

    private var dayKey: String {
        MondoWindow.yesterdayKey(now: now)
    }

    private var blocked: Set<String> { MondoService.blockedMondoIDs(blockedUsers) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            MondoTopView(
                dayKey: dayKey,
                load: loadState,
                onBack: onClose,
                onSettings: { showingSettings = true },
                onTag: { tag in
                    haptics.playTransient(intensity: 0.3, sharpness: 0.4)
                    withAnimation(.easeOut(duration: 0.3)) { tagPage = tag }
                },
                onOpen: { entries, index, title in
                    haptics.playTransient(intensity: 0.3, sharpness: 0.4)
                    let total: Int? = {
                        guard case .ready(let s) = load else { return nil }
                        if title == "Mondo" { return WorldCountStore.shared.count ?? s.lightCount }
                        return s.topTags.first { "#\($0.tag)" == title }?.count
                    }()
                    viewer = ViewerContext(title: title, entries: entries, start: index, total: total)
                },
                onRetry: { Task { await reload() } }
            )

            if let tag = tagPage, case .ready(let summary) = load {
                MondoTagPage(
                    tag: tag,
                    summary: summary,
                    onBack: { withAnimation(.easeOut(duration: 0.25)) { tagPage = nil } },
                    onOpen: { entries, index in
                        haptics.playTransient(intensity: 0.3, sharpness: 0.4)
                        viewer = ViewerContext(title: "#\(tag)", entries: entries, start: index, total: summary.topTags.first { $0.tag == tag }?.count)
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(1)
            }

            if showingWelcome {
                MondoWelcomeView(haptics: haptics) {
                    mondoSeen = true
                    withAnimation(.easeOut(duration: 0.4)) { showingWelcome = false }
                }
                .transition(.opacity)
                .zIndex(3)
            }
        }
        .opacity(isShown ? 1 : 0)
        .offset(y: isShown ? 0 : 24)
        .onAppear {
            showingWelcome = !mondoSeen
            withAnimation(.easeOut(duration: 0.35)) { isShown = true }
        }
        .task { await reload() }
        .onChange(of: blockedUsers.count) { _, _ in Task { await reload() } }
        .fullScreenCover(item: $viewer) { context in
            MondoViewer(context: context, haptics: haptics, onReport: { reportTarget = $0 })
        }
        .sheet(isPresented: $showingSettings) {
            MondoSettingsSheet(haptics: haptics, onShowWelcome: {
                showingSettings = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { withAnimation { showingWelcome = true } }
            })
            .presentationDetents([.medium, .large])
            .presentationBackground(Color(hex: "121214"))
        }
    }

    private var loadState: MondoTopView.State {
        switch load {
        case .loading: return .loading
        case .ready(let s): return s.entries.isEmpty ? .empty : .ready(s)
        case .notReady: return .notReady
        case .failed: return .failed
        }
    }

    private func reload() async {
        do {
            let summary = try await MondoService.shared.fetchDay(dayKey: dayKey, blocked: blocked)
            WorldCountStore.shared.record(summary)
            withAnimation(.easeOut(duration: 0.4)) { load = .ready(summary) }
        } catch MondoService.FetchError.notReady {
            withAnimation { load = .notReady }
        } catch {
            withAnimation { load = .failed }
        }
    }
}

// MARK: - 点でできた地球

/// フィボナッチ球(約600点)。1周 約60秒。奥の点ほどうすく小さく。色は琥珀〜白。
struct MondoGlobe: View {
    var diameter: CGFloat = 260
    var pointCount = 600
    var isAnimating = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static func points(_ n: Int) -> [(x: Double, y: Double, z: Double)] {
        let golden = Double.pi * (3 - 5.0.squareRoot())
        return (0..<n).map { i in
            let y = 1 - (Double(i) + 0.5) / Double(n) * 2
            let r = (1 - y * y).squareRoot()
            let theta = golden * Double(i)
            return (cos(theta) * r, y, sin(theta) * r)
        }
    }

    var body: some View {
        let pts = Self.points(pointCount)
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isAnimating || reduceMotion)) { context in
            let angle = context.date.timeIntervalSinceReferenceDate * 2 * .pi / 60
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2
                let tilt = 0.35
                for p in pts {
                    // y軸まわりに回して、少し手前に傾ける
                    let x = p.x * cos(angle) + p.z * sin(angle)
                    let z0 = -p.x * sin(angle) + p.z * cos(angle)
                    let y = p.y * cos(tilt) - z0 * sin(tilt)
                    let z = p.y * sin(tilt) + z0 * cos(tilt)
                    let depth = (z + 1) / 2 // 0 奥 → 1 手前
                    let r = 0.6 + 0.7 * depth
                    let color = Color(red: 1, green: 0.62 + 0.38 * depth, blue: 0.37 + 0.63 * depth)
                    let point = CGPoint(x: c.x + CGFloat(x) * radius, y: c.y - CGFloat(y) * radius)
                    ctx.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                             with: .color(color.opacity(0.15 + 0.8 * depth)))
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .background(
            Circle().fill(HomePalette.orange.opacity(0.12)).blur(radius: 50).scaleEffect(1.1)
        )
        .accessibilityHidden(true)
    }
}

// MARK: - トップ

struct MondoTopView: View {
    enum State: Equatable {
        case loading, empty, notReady, failed
        case ready(MondoDaySummary)
    }

    let dayKey: String
    let load: State
    let onBack: () -> Void
    let onSettings: () -> Void
    let onTag: (String) -> Void
    let onOpen: (_ entries: [MondoEntry], _ index: Int, _ title: String) -> Void
    let onRetry: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                scrollContent
            }
            .scrollIndicators(.hidden)

            header
        }
    }

    /// スクロールの中身(書き出し確認用に、スクロールなしでも描けるようにしている)
    var scrollContent: some View {
        VStack(spacing: 0) {
            MondoGlobe(diameter: 250)
                .padding(.top, 80)
            titleBlock
                .padding(.top, 18)
            content
                .padding(.top, 30)
        }
        .padding(.bottom, 60)
    }

    private var header: some View {
        HStack {
            circleButton("chevron.left", label: "Home にもどる", action: onBack)
            Spacer()
            circleButton("ellipsis", label: "Mondo の設定", action: onSettings)
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(
            LinearGradient(colors: [.black.opacity(0.85), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                .background(.ultraThinMaterial.opacity(0.4))
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea(edges: .top)
        )
    }

    private func circleButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var dateLabel: String {
        let parts = dayKey.split(separator: "-")
        guard parts.count == 3 else { return dayKey }
        return "\(parts[1]).\(parts[2])"
    }

    private var titleBlock: some View {
        VStack(spacing: 8) {
            Text("Mondo")
                .font(.system(size: 44, weight: .bold))
                .tracking(-0.05 * 44)
                .foregroundStyle(.white)
            Text("昨日の世界 ・ \(dateLabel)")
                .font(.system(size: 11, design: .monospaced))
                .tracking(0.14 * 11)
                .foregroundStyle(HomePalette.subText)
            if case .ready(let s) = load {
                // Home の数字・ビューアの枚数と同じ値(WorldCountStore)
                let world = WorldCountStore.shared
                let shown = (world.dayKey == s.dayKey ? world.count : nil) ?? s.lightCount
                Text("\(shown.formatted(.number.grouping(.automatic))) の光 ・ \(s.countryCount) の国と地域")
                    .font(.system(size: 11, design: .monospaced))
                    .tracking(0.1 * 11)
                    .foregroundStyle(HomePalette.orange)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch load {
        case .loading:
            message("世界を、たずねています", "")
        case .empty:
            message("昨日は、まだ誰も Mondo に出していません", "あしたの朝、また新しい世界がひらきます。")
        case .notReady:
            message("今日の Mondo は、まだ準備中です", "あしたの朝、また来てください。")
        case .failed:
            VStack(spacing: 16) {
                message("いま、世界につながりません", "また あとで")
                Button("もう一度", action: onRetry)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.white))
            }
        case .ready(let s):
            readyContent(s)
        }
    }

    private func message(_ title: String, _ body: String) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            if !body.isEmpty {
                Text(body).font(.system(size: 12.5)).foregroundStyle(Color(hex: "8E8E93"))
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    private func readyContent(_ s: MondoDaySummary) -> some View {
        VStack(alignment: .leading, spacing: 34) {
            if !s.topTags.isEmpty {
                bubbles(s)
            }
            ForEach(s.topTags.prefix(MondoConfig.tagRows).map(\.tag), id: \.self) { tag in
                tagRow(tag, summary: s)
            }
            allYesterday(s)
            end
        }
    }

    // ことばの群れ(数字なし・並びは日付シードでバラバラ)
    private func bubbles(_ s: MondoDaySummary) -> some View {
        let maxCount = s.topTags.map(\.count).max() ?? 1
        return VStack(alignment: .leading, spacing: 14) {
            sectionLabel("昨日、多かったことば")
            OnboardingFlowLayout(spacing: 10) {
                ForEach(MondoAggregator.bubbleOrder(s.topTags, dayKey: s.dayKey), id: \.tag) { item in
                    MondoBubble(tag: item.tag, size: MondoAggregator.bubbleFontSize(count: item.count, maxCount: maxCount)) { onTag(item.tag) }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func entries(for tag: String, in s: MondoDaySummary) -> [MondoEntry] {
        s.entries.filter { $0.tags.contains(tag) }
    }

    private func tagRow(_ tag: String, summary s: MondoDaySummary) -> some View {
        let list = entries(for: tag, in: s)
        let count = s.topTags.first { $0.tag == tag }?.count ?? list.count
        return VStack(alignment: .leading, spacing: 12) {
            Button { onTag(tag) } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text("#\(tag)").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    Text("\(count) の光").font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Color(hex: "8E8E93"))
                    Spacer()
                    Text("すべて ›").font(.system(size: 12)).foregroundStyle(HomePalette.subText)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(list.prefix(MondoConfig.tilesPerRow).enumerated()), id: \.element.id) { i, entry in
                        Button { onOpen(list, i, "#\(tag)") } label: {
                            MondoTile(entry: entry).frame(width: 120, height: 160)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func allYesterday(_ s: MondoDaySummary) -> some View {
        let list = Array(s.entries.prefix(MondoConfig.maxCards))
        return VStack(alignment: .leading, spacing: 18) {
            sectionLabel("すべての昨日").padding(.horizontal, 20)
            ForEach(Array(list.enumerated()), id: \.element.id) { i, entry in
                Button { onOpen(list, i, "Mondo") } label: {
                    MondoCard(entry: entry)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
        }
    }

    private var end: some View {
        VStack(spacing: 8) {
            Text("今日の Mondo は、ここまで。")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
            Text("あしたの朝、また新しい世界がひらきます。")
                .font(.system(size: 12.5))
                .foregroundStyle(Color(hex: "8E8E93"))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, design: .monospaced))
            .tracking(0.16 * 9.5)
            .foregroundStyle(Color(hex: "6B6B70"))
    }
}

/// ことばのバブル(ガラス風の丸い角、左に色の点)。タップで一瞬ふくらむ。
struct MondoBubble: View {
    let tag: String
    let size: CGFloat
    let action: () -> Void
    @State private var isPopped = false

    private var dotColor: Color {
        var g = SeededGenerator(seed: tag)
        let palette = [HomePalette.orange, HomePalette.blue, HomePalette.yellow, Color(hex: "C97BE0"), Color(hex: "9EE3C2")]
        return palette[Int(g.next() % UInt64(palette.count))]
    }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.12)) { isPopped = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { withAnimation(.easeOut(duration: 0.12)) { isPopped = false } }
            action()
        } label: {
            HStack(spacing: 7) {
                Circle().fill(dotColor).frame(width: 6, height: 6)
                Text("#\(tag)").font(.system(size: size, weight: .semibold)).foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(.white.opacity(0.08)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .scaleEffect(isPopped ? 1.04 : 1)
    }
}

// MARK: - タイル・カード(読み込みまでは色のぼかし)

struct MondoTile: View {
    let entry: MondoEntry
    var cornerRadius: CGFloat = 14
    @State private var image: UIImage?

    var body: some View {
        // 土台が大きさを決め、写真は overlay に入れて切る(fill の写真が横にはみ出して、親の幅を広げないように)
        Color(hex: entry.toneHex ?? "2A2A2E")
            .overlay(LinearGradient(colors: [.white.opacity(0.08), .black.opacity(0.25)], startPoint: .top, endPoint: .bottom))
            .blur(radius: 8)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fill).transition(.opacity)
                }
            }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: entry.id) {
            let loaded = await MondoService.shared.thumbnail(for: entry)
            withAnimation(.easeOut(duration: 0.3)) { image = loaded }
        }
        .accessibilityLabel("\(entry.name)の昨日の1枚")
    }
}

struct MondoCard: View {
    let entry: MondoEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MondoTile(entry: entry, cornerRadius: 22)
                .aspectRatio(3 / 4, contentMode: .fit)
                .frame(maxWidth: .infinity)
            HStack(spacing: 10) {
                PersonaIcon(seed: MondoIdentity.seed(for: entry.mondoID))
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.name).font(.system(size: 14, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                    Text([entry.place?.label, "昨日"].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ・ "))
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(Color(hex: "8E8E93"))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            if !entry.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(entry.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(.white.opacity(0.1)))
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - ことばのページ

struct MondoTagPage: View {
    let tag: String
    let summary: MondoDaySummary
    let onBack: () -> Void
    let onOpen: (_ entries: [MondoEntry], _ index: Int) -> Void

    private var list: [MondoEntry] {
        // 並びは日付シードのシャッフル(投稿の速さ・人気で並べない)
        MondoAggregator.seededShuffle(summary.entries.filter { $0.tags.contains(tag) }, seed: summary.dayKey + tag)
    }

    /// タイルの高さ(バラバラ。日付とレコードで決まる)
    private func height(_ entry: MondoEntry) -> CGFloat {
        var g = SeededGenerator(seed: entry.id)
        return 170 + CGFloat(g.next() % 90)
    }

    var body: some View {
        let items = list
        let count = summary.topTags.first { $0.tag == tag }?.count ?? items.count
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text("#\(tag)")
                        .font(.system(size: 36, weight: .bold))
                        .tracking(-0.04 * 36)
                        .foregroundStyle(.white)
                    Text("昨日 ・ \(count) の光")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(hex: "8E8E93"))
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(0..<2, id: \.self) { column in
                            VStack(spacing: 10) {
                                ForEach(Array(items.enumerated()).filter { $0.offset % 2 == column }, id: \.element.id) { i, entry in
                                    Button { onOpen(items, i) } label: {
                                        MondoTile(entry: entry).frame(height: height(entry))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.top, 18)
                    Text("今日の Mondo は、ここまで。")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "8E8E93"))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, 70)
                .padding(.bottom, 50)
            }
            .scrollIndicators(.hidden)

            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)
            .padding(.leading, 18)
            .padding(.top, 4)
            .accessibilityLabel("もどる")
        }
    }
}

// MARK: - ビューア(Home v3 のビューアを Mondo のスコープで使う)

struct MondoViewer: View {
    let context: MondoRootView.ViewerContext
    let haptics: ExposureHaptics
    let onReport: (MondoEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var hidden: Set<String> = MondoLocalStore.hidden
    @State private var sheetEntry: MondoEntry?

    private var entries: [MondoEntry] { context.entries.filter { !hidden.contains($0.id) } }

    var body: some View {
        let list = entries
        YesterdayViewer(
            items: list.map(Self.item),
            scope: .everyone,
            groups: [],
            haptics: haptics,
            onScopeChange: { _ in },
            onRetry: {},
            onClose: { dismiss() },
            fixedTitle: context.title,
            totalCount: context.total,
            initialIndex: min(context.start, max(0, list.count - 1)),
            remoteImage: { item in
                guard let entry = list.first(where: { $0.id == item.id }) else { return nil }
                if let full = await MondoService.shared.fullImage(for: entry) { return full }
                return await MondoService.shared.thumbnail(for: entry)
            },
            endMessage: (title: "今日の Mondo は、ここまで。", body: "あしたの朝、また新しい世界がひらきます。"),
            onMore: { item in sheetEntry = list.first { $0.id == item.id } }
        )
        .overlay {
            if let entry = sheetEntry {
                MondoReportSheet(
                    entry: entry,
                    haptics: haptics,
                    onReport: {
                        await MondoService.shared.report(entry)
                        hidden = MondoLocalStore.hidden
                    },
                    onBlock: {
                        await MondoService.shared.block(entry, modelContext: modelContext)
                        hidden.formUnion(context.entries.filter { $0.mondoID == entry.mondoID }.map(\.id))
                    },
                    onWithdraw: {
                        await MondoService.shared.withdraw([entry.id])
                        MondoLocalStore.hide(entry.id)
                        hidden = MondoLocalStore.hidden
                    },
                    onClose: { sheetEntry = nil }
                )
            }
        }
    }

    static func item(_ entry: MondoEntry) -> YesterdayItem {
        YesterdayItem(
            id: entry.id,
            imageData: nil,
            cacheKey: "mondo-\(entry.id)",
            authorName: entry.isMine ? "あなた" : entry.name,
            authorSeed: MondoIdentity.seed(for: entry.mondoID),
            locationName: entry.place?.label,
            tags: entry.tags,
            captureDate: Date(),
            isMine: entry.isMine
        )
    }
}

// MARK: - 通報・ブロック(ビューアの ⋯)

struct MondoReportSheet: View {
    let entry: MondoEntry
    let haptics: ExposureHaptics
    let onReport: () async -> Void
    let onBlock: () async -> Void
    let onWithdraw: () async -> Void
    let onClose: () -> Void

    @State private var done: (title: String, body: String)?
    @State private var isShown = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(isShown ? 0.55 : 0)
                .ignoresSafeArea()
                .onTapGesture(perform: close)
            VStack(spacing: 0) {
                if let done {
                    VStack(spacing: 8) {
                        Text(done.title).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        Text(done.body).font(.system(size: 13)).foregroundStyle(Color(hex: "8E8E93"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else if entry.isMine {
                    row("Mondo から取り下げる", "あなたの1枚が、Mondo から消えます") {
                        await onWithdraw()
                        finish("取り下げました。", "グループには、そのまま届いています")
                    }
                    cancelRow
                } else {
                    row("この写真を報告する", "不適切な写真を、運営にしらせます") {
                        await onReport()
                        finish("報告しました。ありがとう。", "この写真は、あなたには見えなくなります")
                    }
                    Divider().overlay(.white.opacity(0.08))
                    row("この人を見えなくする", "あなたからは、この人の写真が見えなくなります") {
                        await onBlock()
                        finish("見えなくしました。", "設定から、もとにもどせます")
                    }
                    cancelRow
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 30)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
                    .fill(Color(hex: "161618"))
                    .ignoresSafeArea(edges: .bottom)
            )
            .offset(y: isShown ? 0 : 400)
        }
        .onAppear { withAnimation(.timingCurve(0.22, 0.8, 0.24, 1, duration: 0.45)) { isShown = true } }
    }

    private var cancelRow: some View {
        Button(action: close) {
            Text("やめる")
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "8E8E93"))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
        }
        .buttonStyle(.plain)
    }

    private func row(_ title: String, _ detail: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                Text(detail).font(.system(size: 12)).foregroundStyle(Color(hex: "8E8E93"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 送った:やわらかく1回 → 1.6秒で自動で閉じる
    private func finish(_ title: String, _ body: String) {
        haptics.playTransient(intensity: 0.4, sharpness: 0.2)
        withAnimation(.easeOut(duration: 0.2)) { done = (title, body) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: close)
    }

    private func close() {
        withAnimation(.easeIn(duration: 0.25)) { isShown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: onClose)
    }
}

// MARK: - ようこそ(初回だけ・4ページ)

struct MondoWelcomeView: View {
    let haptics: ExposureHaptics
    let onEnter: () -> Void

    @State private var page = 0
    @State private var isPublic = MondoService.isPublic

    private struct Page {
        let kicker: String
        let title: String
        let body: String
    }

    private let pages = [
        Page(kicker: "BENVENUTO", title: "ようこそ、\nMondo へ。", body: "Mondo(モンド)は、イタリア語で「世界」。\n世界じゅうの昨日が、ここに集まる場所です。"),
        Page(kicker: "01 / 03", title: "ひとり1枚、\n昨日の世界。", body: "ことばごとに集まったり、流れるように見たり。\nいろいろな国の、昨日の1枚が並びます。"),
        Page(kicker: "02 / 03", title: "名前も、フォローも、\nいいねもない。", body: "見えるのは、名前と丸いアイコン、\nそして国と地域だけ。"),
        Page(kicker: "03 / 03", title: "昨日だけ。\n7日で消える。", body: "あしたになれば、また新しい世界。"),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            MondoGlobe(diameter: 340)
                .offset(y: -150)
                .opacity(0.9)

            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                let p = pages[page]
                VStack(alignment: .leading, spacing: 14) {
                    Text(p.kicker)
                        .font(.system(size: 10.5, design: .monospaced))
                        .tracking(0.2 * 10.5)
                        .foregroundStyle(HomePalette.orange)
                    Text(p.title)
                        .font(.system(size: 30, weight: .bold))
                        .tracking(-0.04 * 30)
                        .foregroundStyle(.white)
                    Text(p.body)
                        .font(.system(size: 14))
                        .lineSpacing(4)
                        .foregroundStyle(HomePalette.subText)
                    if page == 3 {
                        Toggle(isOn: $isPublic) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("自分の1枚を Mondo に出す").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                                Text("いつでも変えられます。オフなら、グループにだけ届きます")
                                    .font(.system(size: 11.5)).foregroundStyle(Color(hex: "8E8E93"))
                            }
                        }
                        .tint(HomePalette.orange)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.07)))
                        .padding(.top, 8)
                        .onChange(of: isPublic) { _, value in
                            haptics.playTransient(intensity: 0.3, sharpness: 0.4)
                            MondoService.isPublic = value
                        }
                    }
                }
                .id(page)
                .transition(.opacity)
                .padding(.horizontal, 28)

                HStack(spacing: 7) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Circle().fill(.white.opacity(i == page ? 1 : 0.25)).frame(width: 6, height: 6)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 34)

                Button(action: next) {
                    Text(page == pages.count - 1 ? "Mondo へ、はいる" : "つぎへ")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 26)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                if value.translation.width < -60, page < pages.count - 1 { go(page + 1) }
                if value.translation.width > 60, page > 0 { go(page - 1) }
            }
        )
    }

    private func next() {
        if page == pages.count - 1 {
            haptics.playTransient(intensity: 0.9, sharpness: 0.6)
            onEnter()
        } else {
            go(page + 1)
        }
    }

    private func go(_ target: Int) {
        haptics.playTransient(intensity: 0.3, sharpness: 0.4)
        withAnimation(.easeInOut(duration: 0.35)) { page = target }
    }
}

// MARK: - 設定(⋯ → シート)

struct MondoSettingsSheet: View {
    let haptics: ExposureHaptics
    let onShowWelcome: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var blockedUsers: [BlockedUser]
    @State private var isPublic = MondoService.isPublic
    @State private var showingBlocked = false
    #if DEBUG
    @AppStorage("mondoDebugAllowUnreviewed") private var debugAllowUnreviewed = false
    @AppStorage(MondoWindow.debugTodayAsYesterdayKey) private var debugTodayAsYesterday = false
    #endif

    private var mondoBlocked: [BlockedUser] {
        blockedUsers.filter { $0.blockedCloudKitUserRecordName.hasPrefix("mondo:") }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $isPublic) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("自分の1枚を Mondo に出す")
                            Text("オフなら、グループにだけ届きます").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .tint(HomePalette.orange)
                    .onChange(of: isPublic) { _, value in
                        haptics.playTransient(intensity: 0.3, sharpness: 0.4)
                        MondoService.isPublic = value
                        // オフにしたら、公開済みの分を削除
                        if !value { Task { await MondoService.shared.withdrawAll() } }
                    }
                }
                Section {
                    Button("Mondo の説明を、もういちど見る", action: onShowWelcome)
                    NavigationLink("見えなくした人(\(mondoBlocked.count))") { blockedList }
                }
                Section {
                    LabeledContent("お問い合わせ", value: MondoConfig.contactEmail)
                        .textSelection(.enabled)
                    Link("Mondo のルール", destination: MondoConfig.rulesURL)
                }
                #if DEBUG
                Section("開発用") {
                    Toggle("審査なしで見る(開発用)", isOn: $debugAllowUnreviewed)
                    Toggle("今日の窓を、昨日として読む", isOn: $debugTodayAsYesterday)
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Mondo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("とじる") { dismiss() } }
            }
        }
    }

    private var blockedList: some View {
        List {
            if mondoBlocked.isEmpty {
                Text("見えなくした人は、いません").foregroundStyle(.secondary)
            }
            ForEach(mondoBlocked) { blocked in
                HStack {
                    Text(blocked.displayName ?? "だれか")
                    Spacer()
                    Button("もとにもどす") {
                        Task { await ModerationService.unblockUser(blocked, modelContext: modelContext) }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(hex: "121214"))
        .navigationTitle("見えなくした人")
    }
}
