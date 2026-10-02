import SwiftUI
import SwiftData
internal import Combine

/// World Later(匿名グローバルフィード、マップ表示版)。世界中のユーザーのDaily Shotが
/// 翌朝9:00の解禁タイミングでここにも反映される。投稿には市区町村レベルまで粗く丸めた
/// 実位置情報が紐づき、地図上にピンとして表示する(装飾的な座標ではない)。解禁前でも
/// 地域・時刻・キャプションは先出しで見え、写真本体のみ解禁までロックされる。
struct WorldLaterFeedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \TodaysLaterSelection.selectedDate, order: .reverse) private var mySelections: [TodaysLaterSelection]

    @State private var posts: [WorldPost] = []
    @State private var isLoading = false
    @State private var selectedPost: WorldPost?
    @State private var scrollTargetID: UUID?
    @State private var highlightedClusterKey: String?
    /// エール送信後、一時的にパルスリング+トーストを出す投稿ID。誰にも数が見えない
    /// 完全に一過性のローカル演出のため、どこにも永続化しない
    /// (WorldPost自体にもエールを数えるフィールドを追加しない)。
    @State private var cheeringPostID: UUID?
    @State private var showingCheerToast = false
    /// 「⑨空の状態」のカウントダウン表示・自動更新用の現在時刻(1秒ごとに更新)。
    @State private var now = Date()
    @State private var hasRefreshedAfterUnlock = false

    private static let accent = Color.laterAccent
    private static let mapBackground = Color(hex: "060B08")
    private static let lockedPinStroke = Color(hex: "3c5a49")
    private static let mutedText = Color(hex: "8FB49B")
    private static let footerText = Color(hex: "7FA88E")

    /// 今日既にTodays's Laterを選び終えているか(1日1回までの制約)。
    private var hasSelectedToday: Bool {
        let calendar = Calendar.current
        return mySelections.contains { calendar.isDateInToday($0.selectedDate) }
    }

    /// 位置情報が取得できた投稿のみを地図・カルーセルの対象にする
    /// (座標が無いと地図上に置きようが無いため)。
    private var mappablePosts: [WorldPost] {
        posts.filter { !$0.isHidden && $0.roundedLatitude != nil && $0.roundedLongitude != nil }
    }

    /// 丸め座標が同一の投稿同士をまとめたクラスタ(=1つのピン)。粗い位置丸めが
    /// 自然に生む「複数投稿のまとまり」をそのまま可視化する。
    private struct PostCluster: Identifiable {
        let key: String
        let latitude: Double
        let longitude: Double
        let posts: [WorldPost]
        var id: String { key }
        var unlockedCount: Int { posts.filter(\.isUnlocked).count }
        var isLocked: Bool { unlockedCount == 0 }
    }

    private var clusters: [PostCluster] {
        let grouped = Dictionary(grouping: mappablePosts) { post in
            "\(post.roundedLatitude ?? 0)_\(post.roundedLongitude ?? 0)"
        }
        return grouped.compactMap { key, posts in
            guard let lat = posts.first?.roundedLatitude, let lon = posts.first?.roundedLongitude else { return nil }
            return PostCluster(key: key, latitude: lat, longitude: lon, posts: posts)
        }
    }

    private func clusterKey(for post: WorldPost) -> String {
        "\(post.roundedLatitude ?? 0)_\(post.roundedLongitude ?? 0)"
    }

    /// 「まだ何も解禁されていない状態」かどうか。ロック中の投稿自体は存在しうるが、
    /// 実際に見られるものが1件も無ければ空の状態(待機ヒーロー)を出す。
    private var hasAnyUnlockedPost: Bool {
        posts.contains { $0.isUnlocked && !$0.isHidden }
    }

    /// 直近の翌朝9:00(今が9:00より前ならその日の9:00、過ぎていれば翌日の9:00)。
    /// Home画面のカウントダウンとずれないよう、計算はWorldLaterService側の
    /// 共通関数に統一している。
    private var nextGlobalUnlockDate: Date {
        WorldLaterService.nextGlobalUnlockDate(from: now)
    }

    private static let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            mapLayer

            VStack(spacing: 0) {
                header

                if hasAnyUnlockedPost {
                    Spacer()
                    carousel
                } else {
                    waitingHero
                        .padding(.top, 8)
                    Spacer(minLength: 12)
                }

                bottomNavBar
            }
        }
        .background(Self.mapBackground.ignoresSafeArea())
        .statusBarHidden()
        .task { await loadPosts() }
        .onReceive(Self.timer) { newNow in
            now = newNow
            guard !hasAnyUnlockedPost, now >= nextGlobalUnlockDate, !hasRefreshedAfterUnlock else { return }
            hasRefreshedAfterUnlock = true
            Task { await loadPosts() }
        }
        .sheet(item: $selectedPost) { post in
            WorldPostDetailView(post: post, hasSelectedToday: hasSelectedToday) {
                posts.removeAll { $0.id == post.id }
            }
        }
        .overlay(alignment: .bottom) {
            if showingCheerToast {
                Text("エールを送りました")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Self.mapBackground)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Self.accent))
                    .padding(.bottom, 230)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - ①マップ層(ドットグリッド+ぼかしブロブの簡易表現。地図SDK差し替え前提)

    private var mapLayer: some View {
        GeometryReader { geometry in
            ZStack {
                Self.mapBackground

                Canvas { context, size in
                    let spacing: CGFloat = 22
                    var x: CGFloat = 0
                    while x < size.width {
                        var y: CGFloat = 0
                        while y < size.height {
                            context.fill(
                                Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)),
                                with: .color(.white.opacity(0.05))
                            )
                            y += spacing
                        }
                        x += spacing
                    }
                }

                Circle().fill(Self.accent.opacity(0.06)).frame(width: 260, height: 260).blur(radius: 60)
                    .position(x: geometry.size.width * 0.2, y: geometry.size.height * 0.25)
                Circle().fill(Self.accent.opacity(0.05)).frame(width: 200, height: 200).blur(radius: 50)
                    .position(x: geometry.size.width * 0.75, y: geometry.size.height * 0.55)

                if hasAnyUnlockedPost {
                    ForEach(clusters) { cluster in
                        pin(for: cluster)
                            .position(
                                x: geometry.size.width * normalizedX(longitude: cluster.longitude),
                                y: geometry.size.height * normalizedY(latitude: cluster.latitude)
                            )
                    }
                } else {
                    ForEach(Self.ghostPinPositions, id: \.self) { point in
                        ghostPin
                            .position(x: geometry.size.width * point.x, y: geometry.size.height * point.y)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    /// 「このあたりにやがて投稿が現れる」と予感させるだけの、実データを一切含まない
    /// 装飾用のダミー位置(固定6点。再描画のたびに動かないよう定数にしている)。
    /// 中央に縦に並ぶヒーロー/カウントダウンカードと重ならないよう、左右の余白帯だけに
    /// 配置する(画面中央の広い帯は避ける)。
    private static let ghostPinPositions: [CGPoint] = [
        CGPoint(x: 0.10, y: 0.16),
        CGPoint(x: 0.88, y: 0.13),
        CGPoint(x: 0.06, y: 0.45),
        CGPoint(x: 0.92, y: 0.42),
        CGPoint(x: 0.11, y: 0.75),
        CGPoint(x: 0.87, y: 0.78)
    ]

    private var ghostPin: some View {
        Circle()
            .strokeBorder(Color(hex: "8FB49B").opacity(0.3), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
            .frame(width: 20, height: 20)
    }

    /// 簡易的な正距円筒図法(実座標ベース。地図SDK導入後はSDK側の投影に置き換える)。
    private func normalizedX(longitude: Double) -> Double { (longitude + 180) / 360 }
    private func normalizedY(latitude: Double) -> Double { (90 - latitude) / 180 }

    @ViewBuilder
    private func pin(for cluster: PostCluster) -> some View {
        let isHighlighted = highlightedClusterKey == cluster.key
        Button {
            highlightedClusterKey = cluster.key
            if let first = cluster.posts.first {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scrollTargetID = first.id
                }
            }
        } label: {
            if cluster.isLocked {
                ZStack {
                    Circle()
                        .strokeBorder(Self.lockedPinStroke, lineWidth: 1.5)
                        .frame(width: 26, height: 26)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Self.lockedPinStroke)
                }
            } else if cluster.posts.count > 1 {
                ZStack {
                    Circle()
                        .fill(Self.accent)
                        .frame(width: 36, height: 36)
                        .shadow(color: Self.accent.opacity(0.5), radius: isHighlighted ? 10 : 4)
                    Text("\(cluster.posts.count)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Self.mapBackground)
                }
            } else {
                ZStack {
                    if isHighlighted {
                        Circle()
                            .strokeBorder(Self.accent.opacity(0.4), lineWidth: 2)
                            .frame(width: 32, height: 32)
                    }
                    Circle()
                        .fill(Self.accent)
                        .frame(width: 16, height: 16)
                        .shadow(color: Self.accent.opacity(0.6), radius: isHighlighted ? 8 : 3)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - ②ヘッダー(マップにオーバーレイ、上から下へフェードするスクリム)

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer(minLength: 0)
                homeWorldSwitcher
                Spacer(minLength: 0)
            }
            .overlay(alignment: .trailing) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .padding(.top, 8)

            Text("世界中の「今日」がここに集まる・位置は市区町村までぼかされます")
                .font(.system(size: 11.5))
                .foregroundStyle(Self.mutedText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [Self.mapBackground.opacity(0.95), Self.mapBackground.opacity(0.6), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    /// Home/World切替ピル。Home画面のヘッダーにある同じ意匠のピルと対になる導線。
    /// Worldではこちらが常にアクティブ表示で、Homeをタップするとこの画面(モーダル)を閉じる。
    private var homeWorldSwitcher: some View {
        HStack(spacing: 2) {
            Button {
                dismiss()
            } label: {
                Text("Home")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Self.mutedText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            Text("World")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "04170B"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Self.accent))
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.laterCard)
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    // MARK: - ⑨空の状態(まだ何も解禁されていない・9:00の解禁を待つヒーロー)

    @State private var pulseRingA = false
    @State private var pulseRingB = false

    private var waitingHero: some View {
        VStack(spacing: 16) {
            ZStack {
                pulseRing(isActive: pulseRingA)
                pulseRing(isActive: pulseRingB)

                ZStack {
                    Circle()
                        .fill(Self.accent.opacity(0.1))
                        .frame(width: 96, height: 96)
                    Circle()
                        .strokeBorder(Self.accent, lineWidth: 1.5)
                        .frame(width: 96, height: 96)
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Self.accent)
                }
            }
            .frame(height: 150)
            .onAppear {
                withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) {
                    pulseRingA = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                    withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) {
                        pulseRingB = true
                    }
                }
            }

            VStack(spacing: 8) {
                Text("世界のどこかから、今日が届きはじめる")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("毎朝9:00、世界中のDaily Shotがいっせいに解禁される。ここはその瞬間を待つ場所。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Self.mutedText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 32)
            }

            countdownCard
                .padding(.horizontal, 20)

            waitingCTAButton
                .padding(.horizontal, 20)
        }
    }

    private func pulseRing(isActive: Bool) -> some View {
        Circle()
            .strokeBorder(Self.accent.opacity(0.5), lineWidth: 1.5)
            .frame(width: 96, height: 96)
            .scaleEffect(isActive ? 2.2 : 1)
            .opacity(isActive ? 0 : 0.6)
    }

    private var countdownCard: some View {
        let remaining = max(0, Int(nextGlobalUnlockDate.timeIntervalSince(now)))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60

        return VStack(spacing: 14) {
            Text("解禁まで")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Self.mutedText)

            HStack(spacing: 10) {
                countdownBox(value: hours, label: "HRS")
                Text(":").font(.system(size: 22, weight: .bold)).foregroundStyle(Self.accent.opacity(0.6))
                countdownBox(value: minutes, label: "MIN")
                Text(":").font(.system(size: 22, weight: .bold)).foregroundStyle(Self.accent.opacity(0.6))
                countdownBox(value: seconds, label: "SEC")
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Self.accent.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Self.accent.opacity(0.4), lineWidth: 1.5))
    }

    private func countdownBox(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%02d", value))
                .font(.custom("Courier New", size: 24).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Self.accent)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Self.mutedText)
        }
        .frame(width: 60)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.laterCard))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Self.accent.opacity(0.4), lineWidth: 1))
    }

    private var waitingCTAButton: some View {
        Button {
            HapticsManager.shutterClick()
            CaptureRequestStore.shared.pendingRequestID = UUID()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("今日の1枚を撮って、参加する")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(Self.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .overlay(Capsule().strokeBorder(Self.accent, lineWidth: 1.3))
        }
        .buttonStyle(.plain)
    }

    // MARK: - ③ボトムナビ(Home/撮影/プロフィールの共通3タブ。ここはHome/World切替ピルが
    // 担う場所のため、3つともアクティブ表示にはしない)

    private var bottomNavBar: some View {
        ZStack {
            HStack {
                bottomNavIcon("house") {
                    dismiss()
                }
                Spacer()
                Color.clear.frame(width: 52, height: 52)
                Spacer()
                bottomNavIcon("person.crop.circle") {
                    dismiss()
                    NotificationCenter.default.post(name: .switchToProfileTabRequested, object: nil)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.horizontal, 56)

            CameraApertureButton(isLocked: false) {
                HapticsManager.shutterClick()
                CaptureRequestStore.shared.pendingRequestID = UUID()
                dismiss()
            }
        }
        .padding(.bottom, 8)
    }

    private func bottomNavIcon(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.7))
        }
        .buttonStyle(.plain)
    }

    // MARK: - ③下部カルーセル

    private var carousel: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 14) {
                ForEach(mappablePosts) { post in
                    carouselCard(post)
                        .id(post.id)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, (UIScreen.main.bounds.width - 268) / 2)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollTargetID)
        .scrollIndicators(.hidden)
        .frame(height: 300)
        .onChange(of: scrollTargetID) { _, newValue in
            guard let newValue, let post = mappablePosts.first(where: { $0.id == newValue }) else { return }
            highlightedClusterKey = clusterKey(for: post)
        }
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func carouselCard(_ post: WorldPost) -> some View {
        if post.isUnlocked {
            unlockedCard(post)
        } else {
            lockedCard(post)
        }
    }

    private func cardHeader(_ post: WorldPost) -> some View {
        Button {
            selectedPost = post
        } label: {
            HStack(spacing: 6) {
                if let region = post.locationRegion, !region.isEmpty {
                    Image(systemName: "mappin")
                        .font(.system(size: 10, weight: .semibold))
                    Text(region)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                } else {
                    Text("どこかの街")
                        .font(.system(size: 12, weight: .semibold))
                }
                Text("・\(Self.relativeTime(post.captureDate))")
                    .font(.system(size: 11))
                    .foregroundStyle(Self.mutedText)
                Spacer()
            }
            .foregroundStyle(Color.laterText)
        }
        .buttonStyle(.plain)
    }

    private func unlockedCard(_ post: WorldPost) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(post)

            ZStack {
                CachedPhotoImage(imageData: post.imageData, cacheKey: post.imageCacheKey) { uiImage in
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.laterCard
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if cheeringPostID == post.id {
                    Circle()
                        .strokeBorder(Self.accent, lineWidth: 2)
                        .frame(width: 60, height: 60)
                        .scaleEffect(1.8)
                        .opacity(0)
                        .animation(.easeOut(duration: 0.6), value: cheeringPostID)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onTapGesture(count: 2) {
                sendCheer(to: post)
            }

            if let caption = post.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.laterTextMuted)
                    .lineLimit(2)
            }

            Text("写真をダブルタップでそっとエール（数は誰にも見えない）")
                .font(.system(size: 9.5))
                .foregroundStyle(Self.footerText)
                .lineLimit(2)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(Color.white.opacity(0.06)))
        }
        .padding(14)
        .frame(width: 268)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.laterCard))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.laterBorder, lineWidth: 1))
    }

    private func lockedCard(_ post: WorldPost) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(post)

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.laterCard)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Self.lockedPinStroke, lineWidth: 1.5)
                Image(systemName: "lock.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Self.lockedPinStroke)

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("9:00に解禁")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Self.mapBackground)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Self.accent))
                    }
                }
                .padding(10)
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)

            if let caption = post.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.laterTextMuted)
                    .lineLimit(2)
            } else {
                Text("写真は解禁までのお楽しみ")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Self.footerText)
            }
        }
        .padding(14)
        .frame(width: 268)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.laterCard))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.laterBorder, lineWidth: 1))
    }

    private func sendCheer(to post: WorldPost) {
        HapticsManager.tick()
        cheeringPostID = post.id
        withAnimation(.easeOut(duration: 0.2)) {
            showingCheerToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.2)) {
                showingCheerToast = false
            }
            cheeringPostID = nil
        }
    }

    private static func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func loadPosts() async {
        isLoading = true
        defer { isLoading = false }
        let myID = CloudKitManager.current?.currentUserRecordName
        posts = await WorldLaterService.fetchRecentPosts(currentUserRecordName: myID)
    }
}

/// World Later投稿の詳細表示。Today's Laterへの選出(理由タグ付き)と通報を行える。
/// カルーセルカードの地域・時刻部分をタップすると開く。
private struct WorldPostDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let post: WorldPost
    let hasSelectedToday: Bool
    /// 自分の投稿を削除した場合、親のフィードから即座に取り除いてもらうためのコールバック。
    var onDeleted: () -> Void = {}

    @State private var showingReasonPicker = false
    @State private var showingReportSheet = false
    @State private var showingSelectedConfirmation = false
    @State private var isSubmittingSelection = false
    @State private var isDeleting = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.laterBackground.ignoresSafeArea()
                VStack(spacing: 20) {
                    if post.isUnlocked {
                        CachedPhotoImage(imageData: post.imageData, cacheKey: post.imageCacheKey) { uiImage in
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Color.white.opacity(0.05)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 20)
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.laterTextMuted)
                            Text("解禁までのお楽しみです")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.laterTextMuted)
                        }
                        .frame(height: 240)
                    }

                    if let caption = post.caption, !caption.isEmpty {
                        Text(caption)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.laterText)
                            .padding(.horizontal, 20)
                    }

                    if post.isOwnPost {
                        Text("あなたの投稿です")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.laterAccent)
                    } else if post.isUnlocked {
                        selectButton
                    }

                    Spacer()

                    if post.isOwnPost {
                        Button(role: .destructive) {
                            Task { await deleteOwnPost() }
                        } label: {
                            if isDeleting {
                                ProgressView().tint(.white)
                            } else {
                                Text("この投稿を取り下げる")
                            }
                        }
                        .disabled(isDeleting)
                    } else {
                        Button {
                            showingReportSheet = true
                        } label: {
                            Label("報告する", systemImage: "flag")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                .padding(.top, 40)
                .padding(.bottom, 30)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .sheet(isPresented: $showingReasonPicker) {
                TodaysLaterReasonPickerView { reason in
                    Task { await submitSelection(reason: reason) }
                }
            }
            .sheet(isPresented: $showingReportSheet) {
                ReportSheet(targetType: .worldPost, targetID: post.ckRecordName ?? post.id.uuidString)
            }
            .alert("選びました", isPresented: $showingSelectedConfirmation) {
                Button("OK") { dismiss() }
            } message: {
                Text("今日のLaterとして選びました。")
            }
        }
    }

    private var selectButton: some View {
        Button {
            showingReasonPicker = true
        } label: {
            if isSubmittingSelection {
                ProgressView().tint(.black)
            } else {
                Text(hasSelectedToday ? "今日はもう選び終えています" : "今日のLaterに選ぶ")
            }
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(hasSelectedToday ? Color.white.opacity(0.15) : Color.laterAccent)
        )
        .padding(.horizontal, 20)
        .disabled(hasSelectedToday || isSubmittingSelection)
    }

    private func submitSelection(reason: TodaysLaterReasonTag) async {
        guard let targetRecordName = post.ckRecordName else { return }
        isSubmittingSelection = true
        defer { isSubmittingSelection = false }
        do {
            try await WorldLaterService.submitSelection(targetPostRecordName: targetRecordName, reasonTag: reason.rawValue)
            let selection = TodaysLaterSelection(targetPostRecordName: targetRecordName, reasonTag: reason.rawValue)
            modelContext.insert(selection)
            try? modelContext.save()
            showingSelectedConfirmation = true
        } catch {
            print("[WorldLater] submitSelection failed: \(error)")
        }
    }

    private func deleteOwnPost() async {
        isDeleting = true
        defer { isDeleting = false }
        await WorldLaterService.deletePost(post)
        onDeleted()
        dismiss()
    }
}
