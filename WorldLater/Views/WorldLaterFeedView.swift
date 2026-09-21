import SwiftUI
import SwiftData

/// World Later(匿名グローバルフィード)。世界中のユーザーの投稿を、投稿者を
/// 特定できる情報なしに一覧表示する。タップすると詳細(Today's Laterへの選出・通報)へ進む。
struct WorldLaterFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \TodaysLaterSelection.selectedDate, order: .reverse) private var mySelections: [TodaysLaterSelection]

    @State private var posts: [WorldPost] = []
    @State private var isLoading = false
    @State private var selectedPost: WorldPost?
    @State private var showingMyPage = false

    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }

    private static let neonGreen = Color.brandGreen
    /// 「LATEST」に表示する枚数。posts自体が既にWorldLaterService.fetchRecentPosts
    /// (resultsLimit付き)で件数を絞って取得済みのため、ここは追加のクエリなしで
    /// 先頭から数枚を切り出すだけでよい。
    private static let latestStripCount = 3

    /// 今日既にTodays's Laterを選び終えているか(1日1回までの制約)。
    private var hasSelectedToday: Bool {
        let calendar = Calendar.current
        return mySelections.contains { calendar.isDateInToday($0.selectedDate) }
    }

    private var visiblePosts: [WorldPost] {
        posts.filter { !$0.isHidden }
    }

    /// 直近の投稿(既にpostedAt降順で取得済みなので先頭がそのまま最新)。
    private var latestPosts: [WorldPost] {
        Array(visiblePosts.prefix(Self.latestStripCount))
    }

    /// 地図に置くピン。位置は投稿IDから決定論的に算出した装飾的な座標で、
    /// 実際の撮影地点とは一切紐づけない(WorldPostに位置情報フィールド自体が無い)。
    private var mapPins: [WorldMapPin] {
        visiblePosts.map { WorldMapPin(id: $0.id, point: DeterministicMapPosition.point(for: $0.id)) }
    }

    /// 地図上で「糸で吊るされた写真」を添える1件(直近の投稿)。
    private var featuredMapPhoto: (photoID: UUID, imageData: Data, cacheKey: String)? {
        guard let post = visiblePosts.first else { return nil }
        return (post.id, post.imageData, post.imageCacheKey)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                worldHeader

                if visiblePosts.isEmpty {
                    mapEmptyState
                        .padding(.top, 44)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    mapPopulatedState
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 90)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .refreshable { await loadPosts() }
        .task { await loadPosts() }
        .sheet(item: $selectedPost) { post in
            WorldPostDetailView(post: post, hasSelectedToday: hasSelectedToday) {
                posts.removeAll { $0.id == post.id }
            }
        }
        .fullScreenCover(isPresented: $showingMyPage) {
            MyPageView()
        }
    }

    /// Worldタブには元々共通ヘッダー(BrandHeaderRow)が無いため、マイページ導線
    /// (アバターアイコン)だけを見せる最小限のヘッダー行を追加する。
    private var worldHeader: some View {
        HStack {
            Spacer()
            Button {
                showingMyPage = true
            } label: {
                CachedPhotoImage(
                    imageData: currentUser?.profileImageData,
                    cacheKey: "avatar_header_\(currentUser?.id.uuidString ?? "me")"
                ) { uiImage in
                    Image(uiImage: uiImage)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Self.neonGreen.opacity(0.6))
                }
                .frame(width: 30, height: 30)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Self.neonGreen.opacity(0.4), lineWidth: 1.2))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 状態A: 投稿なし

    private var mapEmptyState: some View {
        VStack(spacing: 22) {
            WorldMapCanvas(showsPlaceholderMarkers: true)
                .frame(width: 260, height: 170)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.corkboardCard)
                        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
                )
                .overlay(alignment: .top) {
                    CorkboardPin()
                        .offset(y: -10)
                }
                .rotationEffect(.degrees(-3))

            VStack(spacing: 10) {
                Text(isLoading ? "読み込み中…" : "世界のどこかから、\n届くのを待とう")
                    .font(.custom("Caveat-Bold", size: 26))
                    .foregroundStyle(Color.corkboardHeading)
                    .multilineTextAlignment(.center)

                Text("世界中のLaterユーザーの匿名の一枚が\nここに地図として集まります")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.corkboardTabInactiveText)
                    .multilineTextAlignment(.center)
            }

            Text("投稿が集まると、Today's Laterが選べるようになります")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.corkboardCTAText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.corkboardCard)
                        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 4)
                )
                .rotationEffect(.degrees(2))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 状態B: 投稿が集まった状態

    private var mapPopulatedState: some View {
        VStack(alignment: .leading, spacing: 18) {
            WorldMapCanvas(pins: mapPins, featured: featuredMapPhoto)
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.corkboardCard)
                        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
                )
                .overlay(alignment: .top) {
                    CorkboardPin(size: 20)
                        .offset(y: -12)
                }

            VStack(alignment: .leading, spacing: 12) {
                Text("LATEST・世界の最新の一枚")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.corkboardTabInactiveText)

                HStack(spacing: 12) {
                    ForEach(latestPosts) { post in
                        Button {
                            selectedPost = post
                        } label: {
                            CachedPhotoImage(imageData: post.imageData, cacheKey: post.imageCacheKey) { uiImage in
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Color.corkboardPhotoArea
                            }
                            .frame(width: 84, height: 84)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func loadPosts() async {
        isLoading = true
        defer { isLoading = false }
        let myID = CloudKitManager.current?.currentUserRecordName
        posts = await WorldLaterService.fetchRecentPosts(currentUserRecordName: myID)
    }
}

/// World Later投稿の詳細表示。Today's Laterへの選出(理由タグ付き)と通報を行える。
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

    /// post.isUnlockedはfetch時点のスナップショットのため、翌朝9:00をまたいで
    /// この画面を開き続けているケースでも正しく判定できるよう、都度Date()と比較する。
    private var isUnlocked: Bool {
        Date() >= post.unlockDate
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                VStack(spacing: 20) {
                    if isUnlocked {
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
                        lockedPlaceholder
                            .padding(.horizontal, 20)
                    }

                    if !isUnlocked {
                        Text("翌朝9:00に解禁されます")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    } else if post.isOwnPost {
                        Text("あなたの投稿です")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.brandGreen)
                    } else {
                        selectButton
                    }

                    Spacer()

                    if isUnlocked, post.isOwnPost {
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
                    } else if isUnlocked {
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

    /// 解禁(翌朝9:00)前の表示。画像本体は見せず、地域名・時刻・キャプションだけを見せる。
    private var lockedPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .aspectRatio(1, contentMode: .fit)

            VStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))

                VStack(spacing: 6) {
                    if let locationRegion = post.locationRegion, !locationRegion.isEmpty {
                        Label(locationRegion, systemImage: "mappin")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Text(post.captureDate.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                    if let caption = post.caption, !caption.isEmpty {
                        Text(caption)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
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
                .fill(hasSelectedToday ? Color.white.opacity(0.15) : Color.brandGreen)
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
