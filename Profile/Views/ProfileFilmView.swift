import SwiftUI
import SwiftData
import UIKit

/// プロフィール(フィルム版)。写真が画面ぜんぶ。名前とタグは写真の上に直接書き、下に7コマのフィルム。
/// コマを押す / 上にスワイプで、その日が画面いっぱいにひらく(ProfileFilmPages)。
/// 文字は増やさない。残りの日数は、フィルムの見た目(右ほど古く・色あせ・縁が焼ける)で伝える。
struct ProfileFilmView: View {
    /// Homeへ戻る(左上)。MainNavigationView からだけ渡す。
    var onBack: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var profiles: [UserProfile]
    @Query(sort: \ExposureDay.captureDate, order: .reverse) private var exposureDays: [ExposureDay]

    @State private var haptics = ProfileFilmHaptics()
    @State private var exposure = ExposureHaptics()
    @State private var isShowingEdit = false
    @State private var isShowingSettings = false
    /// 中央にいるコマ(日付キー)。フィルムとページの両方が、この値で連動する
    @State private var focusKey: String?
    /// ひらいている日。nil のときは、メイン画面だけ
    @State private var openedKey: String?
    @State private var openAnchor = UnitPoint(x: 0.5, y: 0.8)
    /// 初回の現像(ぼかし → くっきり)。この画面を開いているあいだに1回だけ
    @State private var developAmount: Double = 1
    @State private var hasDeveloped = false

    private static let filmSpace = "profileFilmSpace"

    private var profile: UserProfile? {
        UserProfile.current(from: profiles)
    }

    /// Profile に出す日(古い順)。ひらいていない今日の1枚も入る。
    private var shots: [WeekDayPoint] {
        ProfileShot.shots(profile: profile, exposureDays: exposureDays, now: Date())
    }

    /// 今日(左)から6日前(右)までの7コマ
    private var frames: [ProfileFilmFrame] {
        let now = Date()
        let calendar = Calendar.current
        let points = Dictionary(uniqueKeysWithValues: shots.map { ($0.id, $0) })
        let today = calendar.startOfDay(for: now)
        return ProfileFilmMath.dayKeys(now: now).enumerated().map { ago, key in
            ProfileFilmFrame(
                key: key,
                ago: ago,
                date: calendar.date(byAdding: .day, value: -ago, to: today) ?? today,
                point: points[key]
            )
        }
    }

    private var todayKey: String {
        ProfileFilmMath.dayKeys(now: Date()).first ?? ""
    }

    private var displayName: String {
        guard let name = profile?.name, !name.isEmpty else { return "ゲスト" }
        return name
    }

    private var tagText: String {
        (profile?.selfTags ?? []).map { "#\($0)" }.joined(separator: "  ")
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            paper
            photo
            shades
            caption
            stamp
            filmStrip
            topButtons
            editButton
            swipeMark

            if let openedKey {
                ProfileFilmPages(
                    shots: shots,
                    startKey: openedKey,
                    focusKey: $focusKey,
                    imageFor: fullImage(for:),
                    haptics: haptics,
                    exposure: exposure,
                    onDelete: deleteDay,
                    onClose: close
                )
                .transition(.opacity.combined(with: .scale(scale: 0.16, anchor: openAnchor)))
                .zIndex(10)
            }
        }
        .ignoresSafeArea()
        .preference(key: ProfileViewerOpenKey.self, value: openedKey != nil)
        .onAppear {
            if focusKey == nil { focusKey = todayKey }
            haptics.prepare()
            exposure.prepare()
            developOnce()
        }
        .onChange(of: focusKey) { old, _ in
            // フィルムを自分でさしたときだけ鳴らす(ページ連動の変化では鳴らさない)
            guard old != nil, openedKey == nil else { return }
            haptics.play(.slide)
        }
        .sheet(isPresented: $isShowingEdit) {
            ProfileEditView()
        }
        .fullScreenCover(isPresented: $isShowingSettings) {
            SettingsMenuView(isShowing: $isShowingSettings)
                .transition(.move(edge: .trailing))
        }
    }

    // MARK: - 紙・写真・影

    private var paper: some View {
        LinearGradient(
            colors: [Color(hex: "FBF8F1"), Color(hex: "F1ECE1"), Color(hex: "E7E0D2")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    /// 写真は紙のふちの内側(6pt)いっぱい。角丸は46pt。約36pt上へずらす(人物が名前にかくれないため)。
    private var photo: some View {
        // 土台(Color.clear)が大きさを決め、写真は overlay に入れて切る。
        // scaledToFill の写真をそのまま置くと、画面より横に広い大きさを返して、Profile の外(Home)まで右へずらしていた。
        Color.clear
            .overlay {
                if let image = heroImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .saturation(1.1)
                        .contrast(1.05)
                        .blur(radius: 18 * developAmount)
                        .overlay(Color(hex: "FBF8F1").opacity(0.85 * developAmount))
                } else {
                    Color(hex: "2A1D16")
                }
            }
            .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 46, style: .continuous))
        .padding(6)
        .offset(y: -36)
    }

    private var heroImage: UIImage? {
        guard let profile, let data = profile.profileImageData else { return nil }
        let stamp = Int(profile.profileUpdatedAt?.timeIntervalSince1970 ?? 0)
        return ProfileFilmImages.image(key: "hero_\(profile.id.uuidString)_\(stamp)", data: data)
    }

    /// 上と下の影、周辺の減光、左上の光漏れ
    private var shades: some View {
        ZStack {
            VStack(spacing: 0) {
                LinearGradient(colors: [Color(hex: "080503").opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 190)
                Spacer(minLength: 0)
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "0A0705").opacity(0.94), location: 0),
                        .init(color: Color(hex: "0A0705").opacity(0.8), location: 0.22),
                        .init(color: Color(hex: "0A0705").opacity(0.32), location: 0.58),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 470)
            }
            RadialGradient(
                stops: [
                    .init(color: .clear, location: 0.58),
                    .init(color: .black.opacity(0.42), location: 1),
                ],
                center: .center,
                startRadius: 0,
                endRadius: 560
            )
            RadialGradient(
                colors: [Color(hex: "FF7628").opacity(0.38), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 172
            )
            .blendMode(.screen)
        }
        .allowsHitTesting(false)
    }

    // MARK: - 名前・タグ・日付・編集

    private var caption: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(displayName)
                .font(.system(size: 48, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "FFF7EA"))
                .shadow(color: .black.opacity(0.5), radius: 10, y: 2)
            if !tagText.isEmpty {
                Text(tagText)
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(hex: "FFF4E4").opacity(0.88))
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 26)
        .padding(.bottom, 196)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tagText.isEmpty ? displayName : "\(displayName)。\(tagText)")
        .allowsHitTesting(false)
    }

    /// 日付の印字(プロフィール写真を設定した日)
    private var stamp: some View {
        Text(ProfileShot.filmStamp(for: profile?.profileUpdatedAt ?? Date()))
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(Color(hex: "FF8A1F"))
            .shadow(color: Color(hex: "FF8A1F").opacity(0.6), radius: 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 24)
            .padding(.bottom, 186)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var editButton: some View {
        Button {
            isShowingEdit = true
        } label: {
            glassCircle(systemName: "pencil")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("プロフィールを編集")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 20)
        .padding(.bottom, 214)
    }

    // MARK: - 上のボタン

    private var topButtons: some View {
        HStack {
            if let onBack {
                Button {
                    onBack()
                } label: {
                    glassCircle(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("ホームへ戻る")
            }
            Spacer(minLength: 0)
            Button {
                isShowingSettings = true
            } label: {
                glassCircle(systemName: "gearshape.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("設定")
        }
        .padding(.horizontal, 20)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 60)
    }

    private func glassCircle(systemName: String) -> some View {
        ProfileFilmGlass(systemName: systemName)
    }

    // MARK: - フィルム(7コマ)

    private var filmStrip: some View {
        GeometryReader { proxy in
            // 左右6ptの余白を除いた幅(中央のコマは、この幅の真ん中に来る)
            let filmWidth = proxy.size.width - 12
            VStack(spacing: 0) {
                sprockets
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 8) {
                        tomorrowSlot
                        ForEach(frames) { frame in
                            ProfileFilmSlot(
                                frame: frame,
                                image: slotImage(for: frame),
                                isFocused: focusKey == frame.key,
                                developPercent: developPercent(for: frame),
                                onOpen: { openFromFilm(frame.key) },
                                onNope: { haptics.play(.nope) }
                            )
                            .id(frame.key)
                            .visualEffect { content, geometry in
                                let offset = geometry.frame(in: .named(Self.filmSpace)).midX - filmWidth / 2
                                let distance = ProfileFilmMath.distance(offset: offset)
                                return content
                                    .scaleEffect(ProfileFilmMath.scale(distance: distance))
                                    .opacity(ProfileFilmMath.opacity(distance: distance, ago: frame.ago))
                                    .rotation3DEffect(
                                        .degrees(ProfileFilmMath.tiltDegrees(distance: distance, offset: offset)),
                                        axis: (x: 0, y: 1, z: 0),
                                        perspective: 0.4
                                    )
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .coordinateSpace(name: Self.filmSpace)
                .contentMargins(.horizontal, max(0, (filmWidth - ProfileFilmMath.frameSize.width) / 2), for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $focusKey)
                .scrollIndicators(.hidden)
                sprockets
            }
            .background(filmBody)
            .overlay(filmEdges)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color(hex: "FFCD96").opacity(0.15), lineWidth: 1))
            .shadow(color: .black.opacity(0.6), radius: 17, y: 18)
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .simultaneousGesture(swipeUp)
        }
        .frame(height: 172)
    }

    private var filmBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "22130A").opacity(0.8), Color(hex: "0E0906").opacity(0.92)], startPoint: .top, endPoint: .bottom))
        }
    }

    /// 左右の端を、暗くする(11%)
    private var filmEdges: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 40)
            Spacer(minLength: 0)
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                .frame(width: 40)
        }
        .allowsHitTesting(false)
    }

    /// フィルムの穴(上と下。フィルムと一緒に動く)
    private var sprockets: some View {
        HStack(spacing: 0) {
            ForEach(0..<20, id: \.self) { index in
                if index > 0 { Spacer(minLength: 0) }
                RoundedRectangle(cornerRadius: 1.8, style: .continuous)
                    .fill(.white.opacity(0.3))
                    .frame(width: 9, height: 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .allowsHitTesting(false)
    }

    /// あしたの空のコマ(押せない)
    private var tomorrowSlot: some View {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .strokeBorder(Color(hex: "FFEBC8").opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(width: ProfileFilmMath.frameSize.width, height: ProfileFilmMath.frameSize.height)
            .overlay(alignment: .bottomLeading) {
                Text("\(Calendar.current.component(.day, from: tomorrow))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color(hex: "FF8A1F").opacity(0.3))
                    .padding(5)
            }
            .accessibilityHidden(true)
    }

    /// 写真が1枚でもあるときだけ出す、上スワイプのしるし
    @ViewBuilder
    private var swipeMark: some View {
        if !shots.isEmpty {
            Capsule()
                .fill(.white.opacity(0.42))
                .frame(width: 38, height: 4)
                .padding(.bottom, 180)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var swipeUp: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard openedKey == nil, value.translation.height < -60,
                      abs(value.translation.width) < abs(value.translation.height) else { return }
                // 中央が写真のコマならその日、空ならいちばん新しい写真の日
                if let focused = shots.first(where: { $0.id == focusKey && $0.opened && $0.showsPhoto }) {
                    open(focused.id)
                } else if let newest = shots.last(where: { $0.opened && $0.showsPhoto }) {
                    open(newest.id)
                }
            }
    }

    // MARK: - 画像・現像

    private func slotImage(for frame: ProfileFilmFrame) -> UIImage? {
        guard let point = frame.point, point.opened, point.showsPhoto else { return nil }
        return thumbnail(for: frame.key)
    }

    /// 今日のコマが現像中のとき、その進み(0〜100)
    private func developPercent(for frame: ProfileFilmFrame) -> Int? {
        guard let point = frame.point, !point.opened else { return nil }
        return ProfileStarLayout.developPercent(ProfileStarLayout.developProgress(shotAt: point.date, now: Date()))
    }

    private func thumbnail(for key: String) -> UIImage? {
        let data = exposureDays.first(where: { $0.dayKey == key })?.thumbnailData
        return ProfileFilmImages.image(key: "thumb_\(key)", data: data)
    }

    /// ページ用の本画質(7日以内は端末にあるLaterPhotoを使う)。無ければサムネイル。
    private func fullImage(for point: WeekDayPoint) -> UIImage? {
        guard point.opened, point.showsPhoto else { return nil }
        let data = profile?.photos.first(where: { ExposureDayStore.dayKey(for: $0.captureDate) == point.id })?.imageData
        if let data {
            return ProfileFilmImages.image(key: "full_\(point.id)", data: data)
        }
        return thumbnail(for: point.id)
    }

    /// 初回の現像:ぼかし → くっきり(1.9秒)。この画面を開いているあいだは、1回だけ。
    private func developOnce() {
        guard !hasDeveloped else { return }
        hasDeveloped = true
        guard !reduceMotion else {
            developAmount = 0
            return
        }
        developAmount = 1
        withAnimation(.easeOut(duration: 1.9)) { developAmount = 0 }
    }

    // MARK: - 開く・とじる・消す

    private func openFromFilm(_ key: String) {
        guard let point = shots.first(where: { $0.id == key }), point.opened, point.showsPhoto else {
            haptics.play(.nope)
            return
        }
        haptics.play(.press)
        open(key)
    }

    private func open(_ key: String) {
        focusKey = key
        haptics.play(.deck)
        withAnimation(reduceMotion ? .easeOut(duration: 0.25) : .timingCurve(0.2, 0.85, 0.2, 1, duration: 0.62)) {
            openedKey = key
        }
    }

    private func close() {
        haptics.play(.light)
        withAnimation(reduceMotion ? .easeOut(duration: 0.25) : .timingCurve(0.2, 0.85, 0.2, 1, duration: 0.5)) {
            openedKey = nil
        }
    }

    /// その日の写真を、共有先すべて(グループ・Mondo)から消す。点の記録と、サムネイルも消す。
    /// 消したあとは、近い日のページへ。1枚も無くなったら、メイン画面にもどる。
    private func deleteDay(_ point: WeekDayPoint) {
        let newestFirst = Array(shots.reversed())
        let index = newestFirst.firstIndex(where: { $0.id == point.id })
        let neighbors = newestFirst.filter { $0.id != point.id }
        // 古い側(次)を優先し、無ければ新しい側(前)
        let nextKey: String? = {
            guard let index else { return neighbors.first?.id }
            if index < neighbors.count { return neighbors[index].id }
            return neighbors.last?.id
        }()

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
        ProfileFilmImages.remove(point.id)

        let mondoRecord = MondoIdentity.recordName(mondoID: MondoIdentity.id, dayKey: point.id)
        Task {
            if MondoLocalStore.published.contains(mondoRecord) {
                await MondoService.shared.withdraw([mondoRecord])
            }
            await cloudKitManager?.sendPendingChangesNow()
        }

        withAnimation(reduceMotion ? .easeOut(duration: 0.25) : .timingCurve(0.3, 0.7, 0.2, 1, duration: 0.46)) {
            if let nextKey {
                focusKey = nextKey
                openedKey = nextKey
            } else {
                openedKey = nil
            }
        }
    }
}

/// フィルムの1コマ分の材料(今日からの日数・日付・写真)
struct ProfileFilmFrame: Identifiable {
    let key: String
    /// 今日からの日数(0が今日、6が6日前)
    let ago: Int
    let date: Date
    let point: WeekDayPoint?

    var id: String { key }
}

/// 写真の小さなキャッシュ。キーは日付キーなど安定した ID(data.hashValue は使わない)。
enum ProfileFilmImages {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 40
        return cache
    }()

    static func image(key: String, data: Data?) -> UIImage? {
        guard let data else { return nil }
        if let cached = cache.object(forKey: key as NSString) { return cached }
        guard let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key as NSString)
        return image
    }

    /// その日の写真を消したとき、その日の分だけ捨てる
    static func remove(_ dayKey: String) {
        cache.removeObject(forKey: "thumb_\(dayKey)" as NSString)
        cache.removeObject(forKey: "full_\(dayKey)" as NSString)
    }
}

/// フィルムの1コマ。押すと開く(写真がないコマは、ぷるっと揺れるだけ)。
private struct ProfileFilmSlot: View {
    let frame: ProfileFilmFrame
    let image: UIImage?
    let isFocused: Bool
    /// 今日の現像中だけ、その進み(0〜100)
    let developPercent: Int?
    let onOpen: () -> Void
    let onNope: () -> Void

    @State private var nopeCount = 0

    private static let accent = Color(hex: "FF8A1F")

    private var dayNumber: Int {
        Calendar.current.component(.day, from: frame.date)
    }

    private var isOpenable: Bool {
        frame.point?.opened == true && frame.point?.showsPhoto == true
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            content
            Text("\(dayNumber)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Self.accent)
                .shadow(color: Self.accent.opacity(0.6), radius: 4)
                .padding(5)
        }
        .frame(width: ProfileFilmMath.frameSize.width, height: ProfileFilmMath.frameSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(Self.accent.opacity(isFocused ? 1 : 0.22), lineWidth: isFocused ? 2 : 1)
        )
        .shadow(color: Self.accent.opacity(isFocused ? 0.5 : 0), radius: 12)
        .saturation(ProfileFilmMath.ageSaturation(ago: frame.ago))
        .modifier(Shake(progress: CGFloat(nopeCount)))
        .animation(.linear(duration: 0.4), value: nopeCount)
        .contentShape(Rectangle())
        .onTapGesture { activate() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { activate() }
    }

    @ViewBuilder
    private var content: some View {
        if let image, isOpenable {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: ProfileFilmMath.frameSize.width, height: ProfileFilmMath.frameSize.height)
                .overlay(burn)
                .overlay(Color(hex: "B8895A").opacity(ProfileFilmMath.ageSepia(ago: frame.ago)).blendMode(.multiply))
        } else if let developPercent {
            // 今日・現像中:ミルク色の膜と、中央のリング
            ZStack {
                Color(hex: "FBF8F1").opacity(0.9)
                Circle()
                    .stroke(Self.accent.opacity(0.25), lineWidth: 2.6)
                    .frame(width: 42, height: 42)
                Circle()
                    .trim(from: 0, to: CGFloat(developPercent) / 100)
                    .stroke(Self.accent, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                    .frame(width: 42, height: 42)
                    .rotationEffect(.degrees(-90))
            }
        } else {
            // 写真がない日:点線のコマ
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Color(hex: "FFEBC8").opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                )
        }
    }

    /// 縁が橙に焼ける(古いほど強い)
    private var burn: some View {
        RadialGradient(
            stops: [
                .init(color: .clear, location: 0.35),
                .init(color: Self.accent.opacity(0.55), location: 1),
            ],
            center: .center,
            startRadius: 0,
            endRadius: 60
        )
        .opacity(ProfileFilmMath.ageBurn(ago: frame.ago))
    }

    private func activate() {
        if isOpenable && developPercent == nil {
            onOpen()
        } else {
            nopeCount += 1
            onNope()
        }
    }

    private var accessibilityText: String {
        let month = Calendar.current.component(.month, from: frame.date)
        let label = "\(month)月\(dayNumber)日"
        if let developPercent {
            return "今日。現像中、\(developPercent)パーセント"
        }
        if let point = frame.point, point.showsPhoto {
            return "\(label)。あと\(point.remainingDays)日で消えます"
        }
        return "\(label)。写真なし"
    }
}

/// 横に小さく揺れる(写真がないコマを押したとき)。動きを減らす設定でも、この揺れは短く残す。
private struct Shake: GeometryEffect {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 4 * sin(progress * .pi * 4), y: 0))
    }
}
