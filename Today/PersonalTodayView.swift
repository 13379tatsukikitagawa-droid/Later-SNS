import SwiftUI
import SwiftData

/// MainTabViewの「Personal」タブ(2026/9 新デザイン仕様「⑦Personal画面」)。
/// ME(個人用スペース)の記録だけを表示し、Community(Circle)向けの文言・導線
/// (「誰かと一緒に、始めよう」「グループを作る」)は一切表示しない。
struct PersonalTodayView: View {
    /// 「ME」個人用スペース。オンボーディング未完了などでまだ存在しない場合はnil。
    let group: LaterGroup?

    @Query private var profiles: [UserProfile]
    @State private var showingDevelopingProgress = false

    private static let accent = Color.laterAccent
    /// 過去の記録グリッドを一度に表示する上限枚数。データは既にSwiftDataでローカルに
    /// 保持済み(新規CloudKitクエリ不要)なので、ここはあくまで描画コスト対策の
    /// クライアント側ページングであり、「もっと見る」で残りをまとめて表示する。
    private static let initialPastPhotoLimit = 30

    @State private var showingAllPastPhotos = false

    private var myID: UUID? {
        UserProfile.current(from: profiles)?.id
    }

    /// 自分がMEスペースに撮影した写真の全件(今日・過去問わず)。1件でもあれば
    /// 状態B(記録が溜まった状態)を表示する判定に使う。
    private var myPhotos: [LaterPhoto] {
        guard let group, let myID else { return [] }
        return group.photos.filter { $0.owner?.id == myID }
    }

    private var hasAnyRecord: Bool {
        !myPhotos.isEmpty
    }

    /// 今日撮影した写真(現像中バッジ・今日のカードの表示に使う)。
    /// TodayShootingViewのmyTodaysPhotosと同じ考え方(現在進行中サイクル基準)。
    private var todaysPhotos: [LaterPhoto] {
        guard let group, let myID else { return [] }
        return group.currentCyclePhotos()
            .filter { $0.owner?.id == myID }
            .sorted { $0.captureDate < $1.captureDate }
    }

    private var developingPhotoCount: Int {
        todaysPhotos.filter { !$0.isUnlocked }.count
    }

    /// 今日のカードに表示する代表写真(最新の1枚)。
    private var todaysRepresentativePhoto: LaterPhoto? {
        todaysPhotos.last
    }

    /// 今日を除く、解禁済みの過去の記録。新しい順。
    private var pastPhotos: [LaterPhoto] {
        myPhotos
            .filter { $0.isUnlocked && !Calendar.current.isDateInToday($0.captureDate) }
            .sorted { $0.captureDate > $1.captureDate }
    }

    private var visiblePastPhotos: [LaterPhoto] {
        showingAllPastPhotos ? pastPhotos : Array(pastPhotos.prefix(Self.initialPastPhotoLimit))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if hasAnyRecord {
                    statusCard
                        .padding(.top, 6)

                    if !pastPhotos.isEmpty {
                        pastRecordsGrid
                    }
                } else {
                    emptyState
                        .padding(.top, 44)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 90)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.laterBackground.ignoresSafeArea())
        .sheet(isPresented: $showingDevelopingProgress) {
            DevelopingProgressView(photos: todaysPhotos)
        }
    }

    // MARK: - ①ヘッダー(見出し)

    private var header: some View {
        HStack {
            Text("あなたの記録")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Color.laterText)

            Spacer()
        }
    }

    // MARK: - 状態A: 記録なし(初回)

    private var emptyState: some View {
        PolaroidPromptCard(
            heading: "今日の一枚を、\n残そう",
            caption: "ここには、あなたが撮った瞬間だけが\n少しずつ積み重なっていきます",
            ctaTitle: "＋ 今日の一枚を撮る",
            iconSystemName: "camera.fill"
        ) {
            requestCapture()
        }
    }

    // MARK: - ②今日のステータスカード

    private var statusCard: some View {
        Button(action: handleTodayCardTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.laterCard)

                    if let photo = todaysRepresentativePhoto, photo.isUnlocked {
                        CachedPhotoImage(imageData: photo.imageData, cacheKey: photo.imageCacheKey) { uiImage in
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                        }
                        .clipped()
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.laterTextMuted)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("今日の1枚：\(statusHeadline)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.laterText)
                    Text(statusSubline)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.laterTextMuted)
                }

                Spacer()

                if developingPhotoCount > 0 {
                    Text("現像中")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Self.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Self.accent.opacity(0.15)))
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.laterCard))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.laterBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var statusHeadline: String {
        if let photo = todaysRepresentativePhoto, photo.isUnlocked { return "解禁中" }
        if developingPhotoCount > 0 { return "現像中" }
        return "まだ撮影していません"
    }

    private var statusSubline: String {
        guard let group else { return "" }
        return "\(todaysPhotos.count)/\(GroupUnlockPolicy.individualMaximumPhotoCount(for: group))枚 撮影済み"
    }

    private func handleTodayCardTap() {
        if todaysPhotos.isEmpty {
            requestCapture()
        } else {
            showingDevelopingProgress = true
        }
    }

    private func requestCapture() {
        CaptureRequestStore.shared.pendingRequestID = UUID()
    }

    // MARK: - ③これまでの記録(3列グリッド)

    private static let gridColumns = [
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3)
    ]

    private var pastRecordsGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("これまでの記録")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.laterText)

            LazyVGrid(columns: Self.gridColumns, spacing: 3) {
                ForEach(visiblePastPhotos, id: \.id) { photo in
                    pastPhotoCard(photo)
                }
            }

            if !showingAllPastPhotos && pastPhotos.count > Self.initialPastPhotoLimit {
                Button {
                    showingAllPastPhotos = true
                } label: {
                    Text("もっと見る")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Self.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pastPhotoCard(_ photo: LaterPhoto) -> some View {
        VStack(spacing: 4) {
            CachedPhotoImage(imageData: photo.imageData, cacheKey: photo.imageCacheKey) { uiImage in
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.laterCard
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(Self.pastDateLabel(for: photo.captureDate))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.laterTextMuted)
        }
    }

    private static func pastDateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd"
        return formatter.string(from: date)
    }

}
