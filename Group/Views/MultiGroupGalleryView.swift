import SwiftUI
import SwiftData

/// 複数グループ対応の弧状ダイヤル付きギャラリー
struct MultiGroupGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allPhotos: [LaterPhoto]
    @Query private var allVideos: [LaterVideo]
    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]

    /// この画面(Personalモード)が実際に表示するのは、selectedDayPhotosが参照する
    /// 直近7サイクル分(recentCycleKeys)の写真だけ。以前は期間を問わず全ユーザーの全写真を
    /// 無条件に購読しており、無関係な古い写真や他ユーザーの写真が更新されるだけでも
    /// この画面の@Queryが再評価されていた(グループ数・写真数が増えるほど重くなる要因の
    /// 一つ)。撮影者(自分)による絞り込みはcurrentUserの解決が別の@Query(profiles)に
    /// 依存するため、ここでは期間だけをDB側で絞り込み、撮影者による絞り込みは
    /// 既存通りselectedDayPhotos側の計算プロパティで行う(7日分まで絞られた後の
    /// 小さな配列に対する処理なので、コスト面の懸念は小さい)。
    init() {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -8, to: calendar.startOfDay(for: Date())) ?? .distantPast
        let predicate = #Predicate<LaterPhoto> { $0.captureDate >= cutoff }
        _allPhotos = Query(filter: predicate, sort: [SortDescriptor(\.captureDate, order: .reverse)])
        let videoPredicate = #Predicate<LaterVideo> { $0.captureDate >= cutoff }
        _allVideos = Query(filter: videoPredicate, sort: [SortDescriptor(\.captureDate, order: .reverse)])
    }
    
    // Display mode toggle
    @State private var displayMode: DisplayMode = .personal
    
    // Group selection (for Group mode)
    @State private var selectedGroupIndex: Int = 0
    
    // Date selection (maintained across group switches)
    // index0は現在進行中(未解禁)のサイクルで通常は写真が無いため、デフォルトの
    // 選択位置は直近に解禁済みのサイクル(index1)にする。
    @State private var selectedDateIndex: Int = 1
    
    // Photo paging
    @State private var currentPhotoIndex: Int = 0

    // 動画シェルフでタップされた動画(nilでなければ再生シートを表示)
    @State private var selectedVideoForPlayback: LaterVideo?
    
    // Loading state for smooth transitions
    @State private var isLoadingPhoto: Bool = false

    // Caption-cover flip card (resets whenever the selected day/mode/group changes)
    @State private var isFlipped: Bool = false
    @State private var flipDegrees: Double = 0
    private let flipDuration: Double = 0.5

    // Haptics
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    enum DisplayMode: String, CaseIterable {
        case personal = "Personal"
        case group = "Group"
    }
    
    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }

    // User's groups
    private var userGroups: [LaterGroup] {
        guard let user = currentUser else { return [] }
        return groups.filter { group in
            group.members.contains(where: { $0.id == user.id })
        }
    }
    
    // Currently selected group
    private var selectedGroup: LaterGroup? {
        guard displayMode == .group,
              !userGroups.isEmpty,
              selectedGroupIndex < userGroups.count else {
            return nil
        }
        return userGroups[selectedGroupIndex]
    }
    
    /// 直近7サイクル分の識別キー。時間帯制限の撤廃に伴い、サイクルの境界は日付からの
    /// 計算ではなく、実際に解禁が起きた瞬間(LaterPhoto.unlockDate、解禁時にlastUnlockAtと
    /// 同じ値が焼き込まれる)になった。index0は「まだ解禁されていない、現在進行中サイクル」
    /// (解禁待ち)を表すセンチネルとしてDate.distantFutureを使う(dateHeaderString/
    /// bigDateStringは既にdate <= Date()がfalseの場合に「解禁待ち」を返すため、この
    /// センチネルだけで自然に表示が成立する)。index1〜6はそこから遡った直近6サイクル分
    /// (いずれも解禁済み)。
    ///
    /// Personalモードは複数グループを横断するため、グループごとに独立して決まる
    /// lastUnlockAtでは単一の境界に揃えられない。そのため暦日(解禁された日)単位に
    /// 緩めてグルーピングする。Groupモードは単一グループのunlockDateでそのまま揃う。
    private var recentCycleKeys: [Date] {
        let calendar = Calendar.current
        let pastKeys: [Date]
        switch displayMode {
        case .personal:
            guard let user = currentUser else { return [Date.distantFuture] }
            let unlockDays = Set(allPhotos
                .filter { $0.owner?.id == user.id && $0.isUnlocked }
                .map { calendar.startOfDay(for: $0.unlockDate) })
            pastKeys = Array(unlockDays.sorted(by: >).prefix(6))
        case .group:
            guard let group = selectedGroup else { return [Date.distantFuture] }
            let unlockDates = Set(group.photos.filter(\.isUnlocked).map(\.unlockDate))
            pastKeys = Array(unlockDates.sorted(by: >).prefix(6))
        }
        return [Date.distantFuture] + pastKeys
    }

    private var selectedCycleKey: Date {
        recentCycleKeys[selectedDateIndex]
    }

    // Photos for selected cycle (Personal mode)
    private var selectedDayPhotos: [LaterPhoto] {
        guard let user = currentUser else { return [] }
        let calendar = Calendar.current
        let isCurrentCycle = selectedCycleKey == .distantFuture

        let matches = allPhotos.filter { photo in
            guard photo.owner?.id == user.id else { return false }
            if isCurrentCycle {
                return !photo.isUnlocked
            }
            return photo.isUnlocked && calendar.isDate(photo.unlockDate, inSameDayAs: selectedCycleKey)
        }

        // 1回の撮影を複数グループへ送信した場合(setlog方式)、同じ画像データを持つ
        // LaterPhotoがグループの数だけ別レコードとして保存されている
        // (PostTargetGroupSelectionView.submitPost参照)。Personalモードはグループを
        // 問わず横断して見せるタブのため、同じ写真が重複して並ばないよう、
        // 同一imageDataのものは最初の1件だけ残す。
        var seenImageHashes = Set<Int>()
        var deduplicated: [LaterPhoto] = []
        for photo in matches {
            guard seenImageHashes.insert(photo.imageData.hashValue).inserted else { continue }
            deduplicated.append(photo)
        }
        return deduplicated
    }

    // 選択中グループ・サイクルの解禁済み写真すべて(Group mode)。投票フェーズ撤去に伴い、
    // 選出を待たずグループ全員分をそのまま一覧表示する。
    private var selectedGroupPhotos: [LaterPhoto] {
        guard let group = selectedGroup else { return [] }
        if selectedCycleKey == .distantFuture {
            return group.currentCyclePhotos()
        }
        return group.photos.filter { $0.isUnlocked && $0.unlockDate == selectedCycleKey }
    }

    private var displayPhotos: [LaterPhoto] {
        switch displayMode {
        case .personal:
            return selectedDayPhotos
        case .group:
            return selectedGroupPhotos
        }
    }

    /// 動画は写真の投票による絞り込みには参加しない(ブラインド解禁のタイミングだけを
    /// 写真と共有する設計)ため、Personalモード限定で「自分が投稿した、選択中の日の動画」を
    /// そのまま並べる。同一動画を複数グループへ投稿した場合の重複排除はselectedDayPhotosと
    /// 同じ考え方(サムネイルの内容が同じものは1件にまとめる)。
    private var selectedDayVideos: [LaterVideo] {
        guard displayMode == .personal, let user = currentUser else { return [] }
        let calendar = Calendar.current
        let isCurrentCycle = selectedCycleKey == .distantFuture

        let matches = allVideos.filter { video in
            guard video.owner?.id == user.id else { return false }
            if isCurrentCycle {
                return !video.isUnlocked
            }
            return video.isUnlocked && calendar.isDate(video.unlockDate, inSameDayAs: selectedCycleKey)
        }

        var seenThumbnailHashes = Set<Int>()
        var deduplicated: [LaterVideo] = []
        for video in matches {
            guard seenThumbnailHashes.insert(video.thumbnailData.hashValue).inserted else { continue }
            deduplicated.append(video)
        }
        return deduplicated
    }

    /// 一覧では動画本体を一切ダウンロード・デコードせず、サムネイル
    /// (LaterVideo.thumbnailData)だけを横並びで表示する。タップした時にだけ
    /// VideoDetailPlayerViewを開き、そこで初めて動画本体を都度フェッチする。
    private var videoShelf: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(selectedDayVideos) { video in
                    Button {
                        selectedVideoForPlayback = video
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            CachedPhotoImage(imageData: video.thumbnailData, cacheKey: video.imageCacheKey) { uiImage in
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            }
                            .frame(width: 84, height: 112)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                            )

                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                                .shadow(radius: 3)
                                .padding(6)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
        .frame(height: 112)
        .sheet(item: $selectedVideoForPlayback) { video in
            VideoDetailPlayerView(video: video)
        }
    }

    var body: some View {
        ZStack {
            // Full black background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Navigation - Two-tier structure
                navigationHeader
                
                // Full-screen photo stage
                // maxHeight: .infinityによりphotoStageが余白領域を全て吸収するため、
                // 下のMultiGroupArcDialのセクション(固定サイズ)は、写真/空状態表示の
                // 内容がどう変化してもサイズ・位置が一切変わらない(常に画面下端に
                // 固定した高さで独立配置される)。
                photoStage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 2026/9: 動画機能はUI導線のみ一時非表示(コードは残す、
                // CameraCaptureView.modeToggle非表示化と同じ方針)。
                // if !selectedDayVideos.isEmpty {
                //     videoShelf
                //         .padding(.bottom, 8)
                // }

                // 日付スクロール(写真カードとは重ならない、写真下の独立領域)。
                // 高さ・下部余白は固定値(GeometryReaderで中身のサイズは変わらない)にして
                // おり、CustomBottomBar(画面最下部に浮遊する高さ約64pt+下辺14ptの
                // タブバー)の上端との間に20pt以上のクリアランスを確保している。
                MultiGroupArcDial(
                    dates: recentCycleKeys,
                    selectedIndex: $selectedDateIndex,
                    onIndexChanged: { newIndex in
                        selectionFeedback.selectionChanged()
                        currentPhotoIndex = 0
                        isFlipped = false
                        flipDegrees = 0
                        // 調査項目1: 「写真を開いた(日付を切り替えた)際の表示までの時間」の
                        // 計測ポイント。isLoadingPhotoがtrue→falseに戻るまでを1回分とする。
                        let token = PerformanceSignpost.begin("Gallery.openPhoto")
                        // Trigger photo reload
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isLoadingPhoto = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isLoadingPhoto = false
                            }
                            PerformanceSignpost.end("Gallery.openPhoto", token)
                        }
                    }
                )
                .frame(height: 112)
                .padding(.bottom, 52)
            }
        }
        .trackFrameDrops("MultiGroupGalleryView")
        .onAppear {
            selectionFeedback.prepare()
            impactFeedback.prepare()
        }
    }
    
    // MARK: - Navigation Header (Two-tier)
    
    private var navigationHeader: some View {
        VStack(spacing: 0) {
            // プロフィール画面のヘッダーボタンからfullScreenCoverで開く導線に
            // 変更したため、戻る手段が無くなっていた。この画面自体はNavigationStackを
            // 持たない構造のため、GroupHomeDetailView.headerと同じ見た目
            // (chevron.left、36x36円形)の戻るボタンを新しい行として追加する
            // (Mode SwitcherやCircle Selectorの既存レイアウトには触れない)。
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                Spacer()
            }
            .padding(.top, 8)
            .padding(.horizontal, 20)

            // Tier 1: Mode Switcher (Personal | Group)
            modeSwitcher
                .padding(.top, 12)
                .padding(.horizontal, 20)
            
            // Tier 2: Circle Selector (visible only in Group mode)
            if displayMode == .group {
                circleSelector
                    .padding(.top, 12)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .background(.ultraThinMaterial.opacity(0.3))
                .ignoresSafeArea(edges: .top)
        )
    }
    
    // MARK: - Mode Switcher
    
    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(DisplayMode.allCases, id: \.self) { mode in
                Button(action: { switchMode(to: mode) }) {
                    Text(mode.rawValue)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(displayMode == mode ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(displayMode == mode ? Color.brandGreen : Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
        // Personal/Groupの切り替えボタン自体の上をなぞってスライドでも切り替えられるようにする。
        // 写真表示エリア(photoStage)には既に「同じ日の複数枚をめくる」横スワイプの
        // TabViewがあるため、そちらとは競合しないようこのスイッチャー領域だけに限定している。
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    guard let currentIndex = DisplayMode.allCases.firstIndex(of: displayMode) else { return }
                    if value.translation.width < -20,
                       currentIndex + 1 < DisplayMode.allCases.count {
                        switchMode(to: DisplayMode.allCases[currentIndex + 1])
                    } else if value.translation.width > 20, currentIndex > 0 {
                        switchMode(to: DisplayMode.allCases[currentIndex - 1])
                    }
                }
        )
    }

    private func switchMode(to mode: DisplayMode) {
        guard mode != displayMode else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            displayMode = mode
            currentPhotoIndex = 0
            isFlipped = false
            flipDegrees = 0
        }
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Circle Selector (LazyHStack for performance)
    
    private var circleSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(Array(userGroups.enumerated()), id: \.offset) { index, group in
                    groupChip(group: group, index: index)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 44)
    }
    
    private func groupChip(group: LaterGroup, index: Int) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedGroupIndex = index
                currentPhotoIndex = 0
                isFlipped = false
                flipDegrees = 0

                // Fade transition for photo
                isLoadingPhoto = true
            }
            
            selectionFeedback.selectionChanged()
            
            // Simulate photo load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isLoadingPhoto = false
                }
            }
        }) {
            Text(group.name)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(selectedGroupIndex == index ? .brandGreen : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    selectedGroupIndex == index ? 
                                        Color.brandGreen : Color.white.opacity(0.2),
                                    lineWidth: selectedGroupIndex == index ? 2 : 1
                                )
                        )
                        .shadow(
                            color: selectedGroupIndex == index ? 
                                Color.brandGreen.opacity(0.6) : .clear,
                            radius: selectedGroupIndex == index ? 12 : 0
                        )
                )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedGroupIndex)
    }
    
    // MARK: - Photo Stage
    
    private var photoStage: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            VStack(spacing: 10) {
                // 日付表示は写真面(photoCard)の左上/右上へ移した。以前はここにも
                // 常時表示していたため、写真中央〜下部のキャプション/撮影者表示と
                // 視覚的に重複して見づらくなっていた。読み込み中/写真が無い日だけ、
                // 目印としてこの簡易ヘッダーを出す。
                if isLoadingPhoto || displayPhotos.isEmpty {
                    dateHeader
                }

                ZStack {
                    if isLoadingPhoto {
                        // Loading spinner
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .brandGreen))
                                .scaleEffect(1.5)

                            Text("Loading...")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundStyle(.brandGreen)
                                .padding(.top, 12)
                        }
                    } else if displayPhotos.isEmpty {
                        emptyStateView
                    } else {
                        flipCard(width: width, height: height - 40)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.top, 8)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    // MARK: - 日付ヘッダー(常時表示)

    private var dateHeader: some View {
        Text(dateHeaderString(selectedCycleKey))
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.55))
            .tracking(1)
    }

    /// サイクルのラベル。まだ解禁されていないサイクル(現在進行中)なら「解禁待ち」、
    /// 解禁済みなら「M月d日 H:mm解禁」の形式で表示する(暦日ではなく解禁日時基準)。
    private func dateHeaderString(_ date: Date) -> String {
        guard date <= Date() else { return "解禁待ち" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日 H:mm解禁"
        return formatter.string(from: date)
    }

    // MARK: - めくれるカード(キャプション面 ⇄ 写真面)

    private func flipCard(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if !isFlipped {
                captionFace(width: width, height: height)
            } else {
                photoFace(width: width, height: height)
                    // 180度分あらかじめ逆回転させておくことで、外側のrotation3DEffectが
                    // 180度に達した時に鏡文字にならず正しい向きで表示される。
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
        }
        .rotation3DEffect(.degrees(flipDegrees), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isFlipped else { return }
            impactFeedback.impactOccurred()
            withAnimation(.easeInOut(duration: flipDuration)) {
                flipDegrees = 180
            }
            // 回転の中間地点(90度)でキャプション面から写真面に表示を切り替える。
            DispatchQueue.main.asyncAfter(deadline: .now() + flipDuration / 2) {
                isFlipped = true
            }
        }
    }

    // MARK: - キャプション面(めくる前)

    private func captionFace(width: CGFloat, height: CGFloat) -> some View {
        Group {
            if displayMode == .personal {
                personalStackCover(width: width, height: height)
            } else {
                VStack(spacing: 20) {
                    Spacer()

                    Text(bigDateString(selectedCycleKey))
                        .font(.system(size: 40, weight: .bold, design: .serif))
                        .foregroundStyle(.white)

                    if let caption = displayPhotos.first?.caption, !caption.isEmpty {
                        Text(caption)
                            .font(.system(size: 19, weight: .medium, design: .serif))
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    VStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.35))
                        Text("タップして開く")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .padding(.top, 12)

                    Spacer()
                }
            }
        }
        .frame(width: width, height: height)
    }

    /// Personalモード限定: その日撮影した自分の写真(最大5枚)をチェキ風に重ねて見せる表紙。
    /// タップすると既存のflipCardアニメーションでphotoFace(横スワイプで1枚ずつ)に開く。
    private func personalStackCover(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 18) {
            Spacer()

            ChekiPhotoStack(photos: displayPhotos)
                .frame(width: width * 0.72)

            Text("タップして開く")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.35))

            Spacer()
        }
    }

    private func bigDateString(_ date: Date) -> String {
        guard date <= Date() else { return "解禁待ち" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    // MARK: - 写真面(めくった後、複数枚は既存のTabViewページングをそのまま使う)

    private func photoFace(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            TabView(selection: $currentPhotoIndex) {
                ForEach(Array(displayPhotos.enumerated()), id: \.offset) { index, photo in
                    Group {
                        if displayMode == .personal {
                            chekiCard(photo: photo, width: width, height: height)
                        } else {
                            photoCard(photo: photo, width: width, height: height)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentPhotoIndex) { _, _ in
                impactFeedback.impactOccurred()
            }

            // Page indicator
            if displayPhotos.count > 1 {
                VStack {
                    Spacer()

                    HStack(spacing: 8) {
                        ForEach(0..<displayPhotos.count, id: \.self) { index in
                            Circle()
                                .fill(currentPhotoIndex == index ? Color.brandGreen : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .animation(.spring(response: 0.3), value: currentPhotoIndex)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }

            // 解禁後、自分が撮影した写真を見ている時だけ「保存」「共有」ボタンを出す。
            // 他人が撮影した写真(選出された他人の写真等)を見ている場合は出さない。
            if let currentPhoto, isOwnPhoto(currentPhoto) {
                VStack {
                    Spacer()
                    ChekiSaveShareButtons(photo: currentPhoto)
                        .padding(.bottom, displayPhotos.count > 1 ? 56 : 20)
                }
            }
        }
        .frame(width: width, height: height)
    }

    /// TabViewのcurrentPhotoIndexに対応する写真。ページ切り替え直後の一瞬など
    /// インデックスが範囲外になり得るため安全に扱う。
    private var currentPhoto: LaterPhoto? {
        displayPhotos.indices.contains(currentPhotoIndex) ? displayPhotos[currentPhotoIndex] : nil
    }

    /// 表示中の写真が自分自身が撮影したものかどうか。
    private func isOwnPhoto(_ photo: LaterPhoto) -> Bool {
        guard let authorRecordName = photo.authorCloudKitUserRecordName,
              let myRecordName = CloudKitManager.current?.currentUserRecordName else { return false }
        return authorRecordName == myRecordName
    }
    
    /// Personalモード限定: チェキ風の単体表示で1枚を見せる(横スワイプはTabViewが担当)。
    private func chekiCard(photo: LaterPhoto, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 10) {
            ChekiPhotoFrame(photo: photo)
                .frame(maxWidth: width * 0.88)

            if let caption = photo.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(width: width, height: height)
    }

    private func photoCard(photo: LaterPhoto, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            CachedPhotoImage(imageData: photo.imageData, cacheKey: photo.imageCacheKey) { uiImage in
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width - 32, height: height * 0.82)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .clipped()
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.brandGreen.opacity(0.3),
                                        Color.brandGreen.opacity(0.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            }

            // 写真下部: キャプション+撮影者/撮影場所のみ(日付表示は写真カードから完全に
            // 切り離し、MultiGroupArcDialとして写真の下に独立した領域を設けている)
            VStack(spacing: 4) {
                if let caption = photo.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 6) {
                    if let locationName = photo.locationName, !locationName.isEmpty {
                        Label(locationName, systemImage: "mappin")
                    }
                    Text(photo.owner?.name ?? photo.authorNameCache ?? "不明")
                }
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
            .padding(.top, 40)
            .frame(width: width - 32)
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.75), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .allowsHitTesting(false)
        }
        .frame(width: width, height: height * 0.82)
    }

    // その日の写真が1枚も無い場合だけ表示する空状態。投票フェーズ撤去に伴い、
    // 解禁済みの写真は(選出を待たず)displayPhotosへそのまま含まれるため、
    // ここに到達するのは本当に写真が無い場合のみになる。
    private var emptyStateView: some View {
        EmptyGalleryView(message: emptyStateMessage)
    }

    private var emptyStateMessage: String {
        if displayMode == .group, let groupName = selectedGroup?.name {
            return "\(groupName)では、この日の写真はまだありません"
        }
        return "この日の写真はまだありません"
    }
}

// MARK: - 日付スクロール(写真カードから完全に独立した、写真下の専用領域)

/// 以前はアーク(弧)状に日付を並べ、選択中の項目ほど上に大きくせり出す演出
/// だったため、この領域(高さ110pt)の上端を越えて上のphotoStage(写真)側へ
/// 常時はみ出し、写真下部と日付の大きな数字が重なって見づらくなっていた。
/// ここではみ出しの原因だった弧状の位置計算(sin/cos)を廃止し、全項目を
/// この領域の中央に水平一列で並べる(=写真とは絶対に重ならない)フラットな
/// 帯状デザインに変更した。選択切り替えの操作性(スワイプで±1日)は維持しつつ、
/// 各日付項目に直接タップしても切り替えられるようにしている。
struct MultiGroupArcDial: View {
    let dates: [Date]
    @Binding var selectedIndex: Int
    let onIndexChanged: (Int) -> Void

    @State private var dragOffset: CGFloat = 0
    /// 長押しすると入る「自由移動モード」。通常のスワイプは±1項目までしか動かないが、
    /// このモード中はドラッグ量に応じて何項目でも自由に移動できる(離すと最寄りの
    /// 項目にスナップする)。
    @State private var isFreeMoveMode = false

    private let itemSpacing: CGFloat = 80

    /// 選択中の日付に使うグリーン(#4ade6c)。他画面で使っているCore.brandGreen
    /// (ネオングリーン寄りの発色)とは別に、この日付表示専用の指定色として扱う。
    private static let selectedDateColor = Color.brandGreen

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let centerX = width / 2
            // 縦方向は領域サイズに対する比率ではなく、上端からの固定ptで配置する。
            // 中央寄せだと写真とタブバーのちょうど中間の低い位置に見えてしまい、
            // 「日付が下すぎる」という見え方になっていた。固定値にすることで、
            // この領域自体の高さが変わっても数字の位置が意図せずズレることもない。
            let centerY: CGFloat = 32

            ZStack {
                ForEach(Array(dates.enumerated()), id: \.offset) { index, date in
                    dateItem(for: date, at: index, centerX: centerX, centerY: centerY)
                }
            }
            .frame(width: width, height: geometry.size.height)
            .contentShape(Rectangle())
            // 長押し(0.35秒)で自由移動モードに入る。指を離さずそのままドラッグを続けると
            // 下のDragGesture側がisFreeMoveModeを見て、以降のドラッグをクランプしなくなる。
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.35)
                    .onEnded { _ in
                        isFreeMoveMode = true
                        HapticsManager.tick()
                    }
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if isFreeMoveMode {
                            // 自由移動モード中はクランプせず、ドラッグ量そのままに何項目でも動かす。
                            dragOffset = value.translation.width
                        } else {
                            // 通常モードはプレビュー中の見た目のズレも±1項目分までにクランプする
                            // (最終的に1日しか進まないのに、ドラッグ中だけ何日分も動いて見えるのを防ぐ)。
                            dragOffset = max(-itemSpacing, min(itemSpacing, value.translation.width))
                        }
                    }
                    .onEnded { value in
                        defer { isFreeMoveMode = false }
                        let translation = value.translation.width
                        let newIndex: Int

                        if isFreeMoveMode {
                            // 自由移動モード: ドラッグした距離(itemSpacing換算)の分だけ、
                            // 最寄りの項目へスナップする。
                            let itemsMoved = Int((-translation / itemSpacing).rounded())
                            newIndex = max(0, min(dates.count - 1, selectedIndex + itemsMoved))
                        } else {
                            // 通常モード: 速度を加味した予測移動量(predictedEndTranslation)は
                            // 使わない。軽く弾いただけでも速度成分だけで数日分に相当してしまうため、
                            // 実際の指の移動量(translation)だけを見て、方向を判定しつつ
                            // 必ず±1日にクランプする(強く弾いても2日以上先へは飛ばない)。
                            let threshold: CGFloat = 12
                            var delta = 0
                            if translation < -threshold {
                                delta = 1
                            } else if translation > threshold {
                                delta = -1
                            }
                            newIndex = max(0, min(dates.count - 1, selectedIndex + delta))
                        }

                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }

                        if newIndex != selectedIndex {
                            selectedIndex = newIndex
                            onIndexChanged(newIndex)
                        }
                    }
            )
        }
    }

    private func dateItem(for date: Date, at index: Int, centerX: CGFloat, centerY: CGFloat) -> some View {
        let offset = CGFloat(index - selectedIndex) * itemSpacing
        let totalOffset = offset + dragOffset
        let x = centerX + totalOffset

        // 選択項目からの距離に応じて、大きさ・不透明度を弱める。
        let distance = abs(totalOffset)
        let fadeOpacity = max(0.25, 1.0 - distance / 220)

        let isSelected = index == selectedIndex

        return VStack(spacing: 4) {
            Text(cycleDateLabel(from: date))
                .font(.system(size: isSelected ? 26 : 19, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? Self.selectedDateColor : Color.white.opacity(fadeOpacity * 0.45))
                .shadow(color: isSelected ? Self.selectedDateColor.opacity(0.6) : .clear, radius: isSelected ? 10 : 0)

            Text(cycleTimeLabel(from: date))
                .font(.system(size: isSelected ? 12 : 10, weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? Self.selectedDateColor.opacity(0.85) : Color.white.opacity(fadeOpacity * 0.3))

            // 選択中の日付の下だけに小さいドットインジケーターを出す。非選択時も
            // 透明度0で領域自体は確保し、選択が切り替わるたびに縦位置がズレないようにする。
            Circle()
                .fill(Self.selectedDateColor)
                .frame(width: 4, height: 4)
                .opacity(isSelected ? 1 : 0)
        }
        .position(x: x, y: centerY)
        .onTapGesture {
            guard index != selectedIndex else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedIndex = index
            }
            onIndexChanged(index)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedIndex)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
    }

    /// サイクルの解禁日(M/d形式)。1日=1単位だった暦日表示から、1解禁サイクル=1単位の
    /// 表示への切り替えに伴い、そのサイクルの解禁日時のうち日付部分を表示する。
    private func cycleDateLabel(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    /// サイクルの解禁時刻(H:mm形式)。まだ解禁されていない(現在進行中の)サイクルには
    /// 「解禁待ち」を表示する。
    private func cycleTimeLabel(from date: Date) -> String {
        guard date <= Date() else { return "解禁待ち" }
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    MultiGroupGalleryView()
        .modelContainer(for: [UserProfile.self, LaterPhoto.self, LaterGroup.self], inMemory: true)
}
