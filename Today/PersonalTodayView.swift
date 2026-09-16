import SwiftUI
import SwiftData

/// Homeタブの「Personal」タブ専用コンテンツ。ME(個人用スペース)の記録だけを表示し、
/// Community(Circle)向けの文言・導線(「誰かと一緒に、始めよう」「グループを作る」)は
/// 一切表示しない。以前はTodayShootingView(groups: personalOnlyGroups)を共用していたため
/// Community向けの空状態がそのまま出てしまっていた不具合の修正として、Personal専用に
/// 新規実装した(TodayView.HomeSelectorMode参照)。
struct PersonalTodayView: View {
    /// 「ME」個人用スペース。オンボーディング未完了などでまだ存在しない場合はnil。
    let group: LaterGroup?

    @Query private var profiles: [UserProfile]
    @State private var showingDevelopingProgress = false

    private static let neonGreen = Color.brandGreen
    /// 過去の記録グリッドを一度に表示する上限枚数。データは既にSwiftDataでローカルに
    /// 保持済み(新規CloudKitクエリ不要)なので、ここはあくまで描画コスト対策の
    /// クライアント側ページングであり、「もっと見る」で残りをまとめて表示する。
    private static let initialPastPhotoLimit = 30

    @State private var showingAllPastPhotos = false

    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }

    private var myID: UUID? {
        currentUser?.id
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
            // 2026/9: ヘッダー(ロゴ+モードセレクター+アバター)はTodayView側で
            // World/Personal/Community共通の1段に統合したため、ここではもう描画しない
            // (BrandHeaderRowはPersonal/Community専用のヘッダーとしては廃止)。
            VStack(alignment: .leading, spacing: 22) {
                if hasAnyRecord {
                    todayCard
                        .padding(.top, 6)
                        .frame(maxWidth: .infinity, alignment: .center)

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
        .sheet(isPresented: $showingDevelopingProgress) {
            DevelopingProgressView(photos: todaysPhotos)
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

    // MARK: - 状態B: 今日のカード

    private var todayCard: some View {
        Button(action: handleTodayCardTap) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.corkboardTodayPhotoArea)

                    if let photo = todaysRepresentativePhoto, photo.isUnlocked {
                        CachedPhotoImage(imageData: photo.imageData, cacheKey: photo.imageCacheKey) { uiImage in
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                        }
                        .clipped()
                    } else if developingPhotoCount > 0 {
                        Color.brandGreen.opacity(0.22)
                        VStack(spacing: 6) {
                            Image(systemName: "flask.fill")
                                .font(.system(size: 22, weight: .semibold))
                            Text("現像中")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(Self.neonGreen)
                    } else {
                        Circle()
                            .strokeBorder(Color.corkboardHeading.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .padding(30)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(Color.corkboardHeading.opacity(0.25))
                    }
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                Text(Self.todayDateLabel())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.corkboardTabInactiveText)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.corkboardCard)
                    .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
            )
            .overlay(alignment: .top) {
                CorkboardPin(size: 20)
                    .offset(y: -14)
            }
        }
        .buttonStyle(.plain)
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

    private static func todayDateLabel() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd"
        return "TODAY・\(formatter.string(from: Date()))"
    }

    // MARK: - 過去の記録(コルクボードに増えていくポラロイドのグリッド)

    private static let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private var pastRecordsGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("過去の記録")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            LazyVGrid(columns: Self.gridColumns, spacing: 22) {
                ForEach(visiblePastPhotos, id: \.id) { photo in
                    pastPhotoCard(photo)
                }
            }

            if !showingAllPastPhotos && pastPhotos.count > Self.initialPastPhotoLimit {
                Button {
                    showingAllPastPhotos = true
                } label: {
                    Text("もっと見る")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Self.neonGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pastPhotoCard(_ photo: LaterPhoto) -> some View {
        VStack(spacing: 8) {
            CachedPhotoImage(imageData: photo.imageData, cacheKey: photo.imageCacheKey) { uiImage in
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.corkboardPhotoArea
            }
            .frame(width: 150, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            Text(Self.pastDateLabel(for: photo.captureDate))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.corkboardTabInactiveText)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.corkboardCard)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 5)
        )
        // 決定論的な回転(DeterministicRotation参照)。写真ID基準なので、スクロールで
        // 再描画されても・アプリを再起動しても同じ写真は常に同じ角度になる。
        .rotationEffect(.degrees(DeterministicRotation.degrees(seed: photo.id)))
    }

    private static func pastDateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd"
        return formatter.string(from: date)
    }

}
