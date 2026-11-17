import ImageIO
import SwiftData
import SwiftUI
import UIKit

// v19 ME(見本:Docs/Mocks/later_me_mondo_v19.html の ME 部分)。
// 7日の日めくり(cover flow)+ 8日目のカード + カレンダー。黒いガラスとフィルムの粒子。
// 「えらぶ(★)」は1日1枚。端末の中だけに保存し、えらんだ1枚の小さな画像も端末に1年のこす(ユーザーの決定)。

// MARK: - 決めごと

struct MEShot: Identifiable, Equatable {
    /// 同じ1枚がグループの数だけあるので、撮った時刻でまとめた鍵
    let id: String
    let takenAt: Date
    /// 画像を読む元(LaterPhoto の id)
    let photoID: UUID
    /// v20:動画なら長さ
    var duration: Double? = nil
    /// 【B】ひらいているか(前日の写真は 今日 撮った枚数だけ)
    var reveal: OwnReveal.Status = .open
}

struct MEDay: Identifiable, Equatable {
    let key: String
    let date: Date
    /// 今日からの日数(0 が今日)
    let ago: Int
    let shots: [MEShot]
    let tags: [String]
    /// 9:00 をすぎて仕上がったか(今日の写真は読まない)
    let developed: Bool

    var id: String { key }
    /// のこり日数(7 → 1)
    var daysLeft: Int { MERules.days - ago }
}

enum MERules {
    static let days = DailyExposureRules.photoRetentionDays
    /// 長押しで えらぶ
    static let pickHold: TimeInterval = 0.7
    /// 扇(枚数ごとの横のずれ・傾き)
    static func fan(count: Int, index: Int) -> (x: CGFloat, rotation: Double) {
        switch count {
        case 1: return (0, -2)
        case 2: return [(-34, -7.0), (32, 6.0)][min(index, 1)]
        default: return [(-50, -10.0), (0, 1.0), (48, 9.0)][min(index, 2)]
        }
    }

    /// 7日分(今日 → 6日前)。写真は自分のもの(グループごとの写しは1枚にまとめる)
    static func days(photos: [LaterPhoto], now: Date, calendar: Calendar = .current) -> [MEDay] {
        let todayStart = calendar.startOfDay(for: DailyWindow.latest(for: now, calendar: calendar).open)
        let byDay = Dictionary(grouping: photos) { ExposureDayStore.dayKey(for: $0.captureDate, calendar: calendar) }
        return (0..<days).map { ago in
            let date = calendar.date(byAdding: .day, value: -ago, to: todayStart) ?? todayStart
            let key = ExposureDayStore.dayKey(for: date, calendar: calendar)
            var seen = Set<TimeInterval>()
            let list = (byDay[key] ?? []).sorted { $0.captureDate < $1.captureDate }.filter { seen.insert($0.captureDate.timeIntervalSinceReferenceDate.rounded()).inserted }
            let own = photos.map(\.captureDate)
            let shots = list.prefix(3).map { MEShot(id: "\(key)|\(Int($0.captureDate.timeIntervalSinceReferenceDate))", takenAt: $0.captureDate, photoID: $0.id, duration: $0.isVideo ? $0.durationSeconds : nil,
                                                    reveal: OwnReveal.status(takenAt: $0.captureDate, now: now, ownCaptureDates: own, calendar: calendar)) }
            var tags: [String] = []
            for photo in list { for tag in photo.tags where !tags.contains(tag) { tags.append(tag) } }
            // その日の 1枚でも ひらいていれば「仕上がった日」(1枚ずつの 判定は MEShot.reveal)
            let developed = shots.contains { $0.reveal.isOpen }
            return MEDay(key: key, date: date, ago: ago, shots: Array(shots), tags: Array(tags.prefix(2)), developed: developed)
        }
    }

    /// 「11.05」
    static func dot(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.month, .day], from: date)
        return String(format: "%02d.%02d", c.month ?? 1, c.day ?? 1)
    }

    /// きょう / きのう / おととい / 曜日
    static func label(ago: Int, date: Date, calendar: Calendar = .current) -> String {
        switch ago {
        case 0: return "きょう"
        case 1: return "きのう"
        case 2: return "おととい"
        default:
            let names = ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"]
            return names[(calendar.component(.weekday, from: date) - 1) % 7]
        }
    }

    /// 「あと n日 / あした きえる / 9:00 に ひらく」
    static func lifeText(_ day: MEDay) -> String {
        if day.ago == 0 && !day.developed { return "9:00 に ひらく" }
        if day.daysLeft == 1 { return "あした きえる" }
        return "あと \(day.daysLeft)日"
    }

    /// 色あせ(2日目以降):セピア +0.075/日、彩度 −0.07/日
    static func sepia(ago: Int) -> Double { Double(ago) * 0.075 }
    static func saturation(ago: Int) -> Double { 1 - Double(ago) * 0.07 }
    /// 6日目から光もれ
    static func lightLeak(ago: Int) -> Double { ago >= 5 ? min(1, Double(ago - 4) * 0.35) : 0 }
}

// MARK: - えらんだ1枚(端末の中だけ・1年)

enum MEPickStore {
    private static let key = "me.picks.v1"
    /// v47:ON THIS DAY の裏面に出す、その日のタグ(端末だけ)
    private static let tagsKey = "me.picks.tags.v1"
    static let keepDays = 365

    /// dayKey → えらんだ1枚の id
    static var picks: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static func pick(day: String) -> String? { picks[day] }

    static func tags(day: String) -> [String] {
        ((UserDefaults.standard.dictionary(forKey: tagsKey) as? [String: [String]]) ?? [:])[day] ?? []
    }

    /// えらぶ(その日の前の★は移る)。画像は小さくして、端末に1年のこす
    static func set(day: String, shotID: String, imageData: Data?, videoURL: URL? = nil, tags: [String] = []) {
        var all = picks
        all[day] = shotID
        picks = all
        var allTags = (UserDefaults.standard.dictionary(forKey: tagsKey) as? [String: [String]]) ?? [:]
        allTags[day] = tags
        UserDefaults.standard.set(allTags, forKey: tagsKey)
        // v20:えらんだのが動画なら、本体の写しも1年のこす(7日の削除とは別の場所)
        try? FileManager.default.removeItem(at: videoFileURL(day: day))
        if let videoURL, FileManager.default.fileExists(atPath: videoURL.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? FileManager.default.copyItem(at: videoURL, to: videoFileURL(day: day))
        }
        if let imageData, let small = MEImageLoader.downscale(imageData, maxPixel: 720),
           let jpeg = UIImage(cgImage: small).jpegData(compressionQuality: 0.82) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? jpeg.write(to: fileURL(day: day), options: .atomic)
        }
    }

    static func image(day: String) -> UIImage? {
        UIImage(contentsOfFile: fileURL(day: day).path)
    }

    /// 1年より前のものを消す
    static func prune(now: Date, calendar: Calendar = .current) {
        guard let limit = calendar.date(byAdding: .day, value: -keepDays, to: now) else { return }
        let limitKey = ExposureDayStore.dayKey(for: limit, calendar: calendar)
        var all = picks
        var allTags = (UserDefaults.standard.dictionary(forKey: tagsKey) as? [String: [String]]) ?? [:]
        for day in all.keys where day < limitKey {
            all[day] = nil
            allTags[day] = nil
            try? FileManager.default.removeItem(at: fileURL(day: day))
            try? FileManager.default.removeItem(at: videoFileURL(day: day))
        }
        picks = all
        UserDefaults.standard.set(allTags, forKey: tagsKey)
    }

    private static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MEPicks", isDirectory: true)
    }

    private static func fileURL(day: String) -> URL { folder.appendingPathComponent("\(day).jpg") }
    static func videoFileURL(day: String) -> URL { folder.appendingPathComponent("\(day).mp4") }

    /// えらんだ動画の写し(なければ nil)
    static func video(day: String) -> URL? {
        let u = videoFileURL(day: day)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }
}

/// 写真を小さくして読む(チェキ1枚ぶん)
enum MEImageLoader {
    private static let cache = NSCache<NSString, UIImage>()

    static func downscale(_ data: Data, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func cached(_ key: String) -> UIImage? { cache.object(forKey: key as NSString) }

    static func load(key: String, data: Data) async -> UIImage? {
        if let hit = cached(key) { return hit }
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            downscale(data, maxPixel: 420).map { UIImage(cgImage: $0) }
        }.value
        if let image { cache.setObject(image, forKey: key as NSString) }
        return image
    }
}

// MARK: - 画面

struct MEScreenV19: View {
    let onBack: () -> Void
    let onShoot: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [UserProfile]
    @Query(sort: \ExposureDay.captureDate, order: .reverse) private var exposureDays: [ExposureDay]
    @State private var page: Int? = 0
    @State private var showsCalendar = false
    /// 昨日のホームの タブに あった カレンダー(LaterCalendarView)
    @State private var showsLaterCalendar = false
    @State private var showsProfile = false
    @State private var showsRecap = false
    @State private var picks: [String: String] = MEPickStore.picks
    @State private var toast: String?
    @State private var squish = [0, 0]
    /// v20:上映している動画
    @State private var projecting: (shot: MEShot, day: MEDay)?
    @State private var grainPhase = 0

    private var me: UserProfile? { UserProfile.current(from: profiles) }
    private var days: [MEDay] { MERules.days(photos: me?.photos ?? [], now: Date()) }

    var body: some View {
        let list = days
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                background
                // 背の低い画面(SE)では、下の「カレンダー」まで 届くよう たてに スクロールできる
                ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                    header(list)
                    // v54:見本 C02 の 順番:見出し → Recap(ヒーロー・362×430 ふう)→ 日ごとの めくり
                    recapButton
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                    Text("きょうも いちまい。")
                        .font(.system(size: 27, design: .serif).italic())
                        .tracking(0.14 * 27)
                        .foregroundStyle(Color(hex: "A3A3AA"))
                        .padding(.leading, 28)
                        .padding(.top, 20)
                    MEDayFlow(days: list, picks: $picks, page: $page, width: proxy.size.width, onToast: show, onPlay: { shot, day in projecting = (shot, day) })
                        .frame(height: 400)
                        .padding(.top, 12)
                    dots(count: list.count + 1)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    Spacer(minLength: 8)
                    calendarButton
                        .padding(.horizontal, 20)
                    laterCalendarRow
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 24)
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                if showsCalendar {
                    Color.black.opacity(0.45).ignoresSafeArea()
                        .onTapGesture { closeCalendar() }
                        .transition(.opacity)
                    MECalendarSheet(
                        exposureDays: Array(exposureDays),
                        picks: picks,
                        recentKeys: list.map(\.key),
                        onJump: { index in
                            Haptics.play(.detent)
                            closeCalendar(quiet: true)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { page = index } }
                        },
                        onToast: show,
                        onClose: { closeCalendar() }
                    )
                    .frame(height: min(640, proxy.size.height * 0.78))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
                }
                if let projecting {
                    let photo = me?.photos.first { $0.id == projecting.shot.photoID }
                    VideoProjectionView(
                        id: projecting.shot.id,
                        poster: photo.flatMap { UIImage(data: $0.imageData) },
                        duration: projecting.shot.duration ?? 0,
                        loadURL: {
                            if let photo, let url = try? await LaterVideoStore.fetch(photo) { return url }
                            return MEPickStore.video(day: projecting.day.key)
                        },
                        onClose: { self.projecting = nil }
                    )
                    .transition(.opacity)
                    .zIndex(4)
                }
                if let toast {
                    Text(toast)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(GlassCapsule())
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .offset(y: -12)))
                        .allowsHitTesting(false)
                        .zIndex(3)
                }
            }
        }
        .background(Color(hex: "0A0A0C").ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: showsCalendar)
        .animation(.easeOut(duration: 0.3), value: toast)
        .fullScreenCover(isPresented: $showsLaterCalendar) {
            LaterCalendarView(onClose: { showsLaterCalendar = false })
        }
        .fullScreenCover(isPresented: $showsProfile) {
            ProfileShelfView(onBack: { showsProfile = false }, onShoot: {
                showsProfile = false
                onShoot()
            })
        }
        .fullScreenCover(isPresented: $showsRecap) {
            RecapPlayerView(days: days, images: fullImage(for:), onClose: { showsRecap = false })
        }
        .onAppear {
            Haptics.prepare()
            MEPickStore.prune(now: Date())
            picks = MEPickStore.picks
        }
    }

    private var background: some View {
        ZStack {
            Color(hex: "0A0A0C")
            RadialGradient(colors: [Color(hex: "1D1720"), .clear], center: UnitPoint(x: 0.15, y: 0), startRadius: 0, endRadius: 420)
            RadialGradient(colors: [Color(hex: "22160F"), .clear], center: UnitPoint(x: 1, y: 1), startRadius: 0, endRadius: 360)
            MEGrain()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        HStack {
            Button {
                Haptics.play(.tick)
                onBack()
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 52, height: 52).background(GlassCapsule())
            }
            .buttonStyle(SquishButtonStyle(pressedScale: 0.88))
            .accessibilityLabel("もどる")
            Spacer()
            Button {
                Haptics.play(.tick)
                showsProfile = true
            } label: {
                HStack(spacing: 8) {
                    Circle().fill(RadialGradient(colors: [Color(hex: "FFE0EA"), Color(hex: "FF8FB0"), Color(hex: "9A7CFF")], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 14))
                        .frame(width: 20, height: 20)
                    Text("プロフィール").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                }
                .padding(.horizontal, 18)
                .frame(height: 44)
                .background(GlassCapsule())
            }
            .buttonStyle(SquishButtonStyle(pressedScale: 0.94))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func header(_ list: [MEDay]) -> some View {
        let frames = list.reduce(0) { $0 + $1.shots.count }
        let index = min(page ?? 0, list.count)
        let shownDate: String = index < list.count ? MERules.dot(list[index].date) : MERules.dot(Calendar.current.date(byAdding: .day, value: -MERules.days, to: list.first?.date ?? Date()) ?? Date())
        return HStack(alignment: .top) {
            HStack(spacing: -6) {
                ForEach(0..<2, id: \.self) { i in
                    Text(i == 0 ? "M" : "E")
                        .font(.system(size: 132, weight: .black))
                        .tracking(-0.085 * 132)
                        .foregroundStyle(Color(hex: "F4F4F6"))
                        .keyframeAnimator(initialValue: CGSize(width: 1, height: 1), trigger: squish[i]) { content, s in
                            content.scaleEffect(x: s.width, y: s.height, anchor: .bottom)
                        } keyframes: { _ in
                            KeyframeTrack(\.width) {
                                CubicKeyframe(1.08, duration: 0.15)
                                CubicKeyframe(0.96, duration: 0.15)
                                SpringKeyframe(1, duration: 0.2)
                            }
                            KeyframeTrack(\.height) {
                                CubicKeyframe(0.84, duration: 0.15)
                                CubicKeyframe(1.06, duration: 0.15)
                                SpringKeyframe(1, duration: 0.2)
                            }
                        }
                }
            }
            .frame(height: 120)
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.play(.pop)
                squish[0] += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) { squish[1] += 1 }
            }
            .accessibilityLabel("ME")
            .accessibilityAddTraits(.isHeader)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(frames)").font(.system(size: 22, weight: .bold, design: .monospaced)).foregroundStyle(Color(hex: "FF8A2A"))
                Text("こま ・ 7 DAYS").font(.system(size: 9.5, design: .monospaced)).tracking(0.18 * 9.5).foregroundStyle(Color(hex: "5E5E66"))
                Text(shownDate).font(.system(size: 9.5, design: .monospaced)).tracking(0.18 * 9.5).foregroundStyle(Color(hex: "FF8A2A"))
            }
            .padding(.top, 30)
            .accessibilityElement(children: .combine)
        }
        .padding(.leading, 22)
        .padding(.trailing, 26)
        .padding(.top, 2)
    }

    private func dots(count: Int) -> some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                let on = i == (page ?? 0)
                Capsule()
                    .fill(on ? Color(hex: "F4F4F6") : (i == count - 1 ? .clear : .white.opacity(0.18)))
                    .overlay { if i == count - 1 && !on { Capsule().strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [2, 2])) } }
                    .frame(width: on ? 18 : 6, height: 6)
            }
        }
        .animation(.easeOut(duration: 0.3), value: page)
        .accessibilityHidden(true)
    }

    /// v50:Recap(動画みたいに 流れる まとめ)を ひらく。mock .mrc:高さ430・角丸32・4枚コラージュの背景。
    private var recapButton: some View {
        let list = days
        let shots = list.flatMap { day in day.shots.filter(\.reveal.isOpen).map { ($0, day) } }
        let covers = Array(list.prefix(4).compactMap { $0.shots.first(where: { $0.reveal.isOpen }) }.compactMap(fullImage(for:)))
        let keptCount = Set(list.compactMap { MEPickStore.pick(day: $0.key) }).count
        return Button {
            Haptics.play(.pop)
            showsRecap = true
        } label: {
            ZStack(alignment: .bottomLeading) {
                collage(covers)
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.15), location: 0),
                    .init(color: .black.opacity(0.05), location: 0.35),
                    .init(color: .black.opacity(0.82), location: 1),
                ], startPoint: .top, endPoint: .bottom)

                Text("RECAP")
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2.4)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11).frame(height: 26)
                    .background(Capsule().fill(.black.opacity(0.45)))
                    .padding(.leading, 22).padding(.top, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Your").font(.custom("InstrumentSerif-Regular", size: 46)).foregroundStyle(.white)
                    Text("week.").font(.custom("InstrumentSerif-Italic", size: 52)).foregroundStyle(Color(hex: "C8F25A"))
                    HStack(spacing: 4) {
                        statNumber(shots.count); Text("shots").font(statLabelFont)
                        statNumber(7); Text("days").font(statLabelFont)
                        statNumber(keptCount); Text("kept").font(statLabelFont)
                    }
                    .foregroundStyle(Color(hex: "C9C9CF"))
                    .padding(.top, 8)
                }
                .padding(.leading, 24).padding(.bottom, 28)

                Image(systemName: "play.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 68, height: 68)
                    .background(Circle().fill(.white))
                    .padding(.trailing, 22).padding(.bottom, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .frame(height: 430)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.98))
    }

    private var statLabelFont: Font { .system(size: 10, weight: .bold, design: .monospaced) }

    private func statNumber(_ n: Int) -> some View {
        Text("\(n)").font(.custom("InstrumentSerif-Regular", size: 20)).foregroundStyle(.white)
    }

    /// 2×2(すき間3pt)の 写真コラージュ。足りない分は 色で うめる。
    private func collage(_ images: [UIImage]) -> some View {
        func cell(_ i: Int) -> some View {
            ZStack {
                if images.indices.contains(i) {
                    Image(uiImage: images[i]).resizable().scaledToFill()
                } else {
                    Color(hex: "161618")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        return VStack(spacing: 3) {
            HStack(spacing: 3) { cell(0); cell(1) }
            HStack(spacing: 3) { cell(2); cell(3) }
        }
        .background(Color.black)
    }

    /// Recap 用:1コマの本画質(動画は、仕上がっている絵=ポスターを使う)
    private func fullImage(for shot: MEShot) -> UIImage? {
        guard let data = me?.photos.first(where: { $0.id == shot.photoID })?.imageData else { return nil }
        return UIImage(data: data)
    }

    private var calendarButton: some View {
        Button {
            Haptics.play(.pop)
            showsCalendar = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("カレンダーで 見る").font(.system(size: 19, weight: .heavy)).tracking(-0.02 * 19).foregroundStyle(.white)
                    Text("色だけ ずっと のこる").font(.system(size: 12, design: .serif)).tracking(0.14 * 12).foregroundStyle(Color(hex: "8E8E95"))
                }
                Spacer()
                MEMiniGrid(exposureDays: Array(exposureDays), picks: picks)
            }
            .padding(.leading, 24)
            .padding(.trailing, 18)
            .frame(height: 76)
            .background(GlassRect(radius: 28))
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
    }

    /// 「カレンダー」の行(昨日のホームの タブから うつした)
    private var laterCalendarRow: some View {
        Button {
            Haptics.play(.detent)
            showsLaterCalendar = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                Text("カレンダー").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Color(hex: "8E8E95"))
            }
            .padding(.horizontal, 22)
            .frame(height: 52)
            .background(GlassRect(radius: 22))
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
        .accessibilityLabel("カレンダー")
    }

    private func closeCalendar(quiet: Bool = false) {
        if !quiet { Haptics.play(.soft) }
        showsCalendar = false
    }

    private func show(_ message: String) {
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { if toast == message { toast = nil } }
    }
}

/// フィルムの粒子(0.9秒ごとに少しずらす)
struct MEGrain: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.18)) { context in
            let step = reduceMotion ? 0 : Int(context.date.timeIntervalSinceReferenceDate / 0.18) % 5
            let shifts: [CGSize] = [.zero, CGSize(width: -14, height: 9), CGSize(width: 10, height: -12), CGSize(width: -8, height: -6), CGSize(width: 12, height: 10)]
            GrainView(seed: 3)
                .padding(-40)
                .offset(shifts[step])
                .opacity(0.5)
                .blendMode(.overlay)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 7日の日めくり

private struct MEDayFlow: View {
    let days: [MEDay]
    @Binding var picks: [String: String]
    @Binding var page: Int?
    let width: CGFloat
    let onToast: (String) -> Void
    var onPlay: (MEShot, MEDay) -> Void = { _, _ in }

    @State private var lastPage: Int? = 0

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    MEDayCard(day: day, pickedID: picks[day.key], onPick: { shot, data, video in pick(day: day, shot: shot, data: data, video: video) }, onToast: onToast, onPlay: { onPlay($0, day) })
                        .id(index)
                        .modifier(CoverFlow())
                }
                MEGhostCard(tone: days.first(where: { $0.developed && !$0.shots.isEmpty })?.key)
                    .id(days.count)
                    .modifier(CoverFlow())
            }
            .scrollTargetLayout()
            .padding(.top, 6)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $page, anchor: .center)
        .contentMargins(.horizontal, max(0, (width - 250) / 2), for: .scrollContent)
        .onChange(of: page) { _, new in
            guard let new, new != lastPage else { return }
            lastPage = new
            if new == days.count { Haptics.play(.warn) } else { Haptics.play(.detent) }
        }
    }

    private func pick(day: MEDay, shot: MEShot, data: Data?, video: URL?) {
        MEPickStore.set(day: day.key, shotID: shot.id, imageData: data, videoURL: video, tags: day.tags)
        picks = MEPickStore.picks
        Haptics.play(.heart)
        onToast("えらんだ1枚は、1年 のこります")
    }
}

/// まん中がまっすぐ。となりは 16° ずつ奥へ回って、小さく・うすく
private struct CoverFlow: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.visualEffect { effect, proxy in
            let frame = proxy.frame(in: .scrollView)
            let container = proxy.bounds(of: .scrollView)?.width ?? frame.width
            let d = (frame.midX - container / 2) / 264
            let a = min(abs(d), 1.6)
            return effect
                .rotation3DEffect(.degrees(reduceMotion ? 0 : -d * 16), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                .scaleEffect(1 - a * 0.08)
                .opacity(1 - a * 0.38)
        }
    }
}

private struct MEDayCard: View {
    let day: MEDay
    let pickedID: String?
    let onPick: (MEShot, Data?, URL?) -> Void
    let onToast: (String) -> Void
    var onPlay: (MEShot) -> Void = { _ in }

    @Query private var photos: [LaterPhoto]
    @State private var spread = false

    init(day: MEDay, pickedID: String?, onPick: @escaping (MEShot, Data?, URL?) -> Void, onToast: @escaping (String) -> Void, onPlay: @escaping (MEShot) -> Void = { _ in }) {
        self.day = day
        self.pickedID = pickedID
        self.onPick = onPick
        self.onToast = onToast
        self.onPlay = onPlay
        let ids = day.shots.map(\.photoID)
        _photos = Query(filter: #Predicate<LaterPhoto> { ids.contains($0.id) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(MERules.dot(day.date)).font(.system(size: 15, weight: .bold, design: .monospaced)).tracking(0.08 * 15).foregroundStyle(Color(hex: "FF8A2A"))
                    Text(MERules.label(ago: day.ago, date: day.date)).font(.system(size: 20, weight: .heavy)).tracking(-0.02 * 20).foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    MELifeBars(left: day.daysLeft)
                    Text(MERules.lifeText(day)).font(.system(size: 8.5, design: .monospaced)).tracking(0.14 * 8.5).foregroundStyle(Color(hex: "5E5E66"))
                }
                .padding(.top, 4)
            }
            ZStack {
                if day.shots.isEmpty {
                    rest
                } else {
                    fan
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 228)
            .padding(.top, 14)
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 8) {
                HStack(spacing: 5) {
                    ForEach(day.tags, id: \.self) { tag in
                        Text("#\(tag)").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: "D9D9DE"))
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.08)))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Text("えらんだ ・ 1年").font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: "FFB070"))
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(hex: "FF8A2A").opacity(0.16)))
                    .opacity(pickedID == nil ? 0 : 1)
                    .offset(y: pickedID == nil ? 4 : 0)
                    .animation(.easeOut(duration: 0.35), value: pickedID)
            }
        }
        .padding(18)
        .frame(width: 250, height: 380)
        .background(GlassRect(radius: 30))
        .accessibilityElement(children: .contain)
    }

    private var rest: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.fill").font(.system(size: 30)).foregroundStyle(Color(hex: "C9C9CF"))
                .frame(width: 96, height: 96).background(GlassCapsule())
            Text("おやすみ").font(.system(size: 17, weight: .heavy)).foregroundStyle(.white)
            Text("撮らない日も、あっていい").font(.system(size: 12.5, design: .serif)).tracking(0.1 * 12.5).foregroundStyle(Color(hex: "8E8E95"))
        }
        .padding(.top, 10)
    }

    /// ひらく前の チェキを 押したとき の 文
    static func lockedToast(_ reveal: OwnReveal.Status) -> String {
        if case .waiting(let n) = reveal { return "今日 あと\(n)こま 撮ると、ひらきます" }
        return "9:00 まで まってね"
    }

    private var fan: some View {
        ZStack {
            ForEach(Array(day.shots.enumerated()), id: \.element.id) { index, shot in
                let f = MERules.fan(count: day.shots.count, index: index)
                MECheki(
                    shot: shot,
                    ago: day.ago,
                    developed: shot.reveal.isOpen,
                    lockedText: shot.reveal.lockedText,
                    picked: pickedID == shot.id,
                    data: photos.first { $0.id == shot.photoID }?.imageData,
                    onTap: {
                        // 開いた状態で動画のチェキをタップ:上映(ひらく前は、9:00 まで)
                        if spread, shot.duration != nil {
                            if shot.reveal.isOpen { onPlay(shot) } else {
                                Haptics.play(.warn)
                                onToast(Self.lockedToast(shot.reveal))
                            }
                            return
                        }
                        Haptics.play(.pop)
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) { spread.toggle() }
                    },
                    onPick: { data in
                        let video = photos.first { $0.id == shot.photoID }.flatMap { LaterVideoStore.localURL(for: $0) }
                        onPick(shot, data, video)
                    },
                    onTooEarly: {
                        Haptics.play(.warn)
                        onToast(Self.lockedToast(shot.reveal))
                    }
                )
                .rotationEffect(.degrees(spread ? f.rotation * 1.6 : f.rotation))
                .offset(x: spread ? f.x * 1.5 : f.x, y: spread ? -6 : 0)
                .zIndex(pickedID == shot.id ? 4 : (index == 1 ? 3 : 2))
            }
        }
    }
}

/// のこり日数の棒 7本(のこり1日は、最後の棒が赤く点めつ)
private struct MELifeBars: View {
    let left: Int
    @State private var blink = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<MERules.days, id: \.self) { k in
                RoundedRectangle(cornerRadius: 2)
                    .fill(fill(k))
                    .frame(width: 4, height: 14)
                    .opacity(left == 1 && k == 0 ? (blink ? 0.35 : 1) : 1)
            }
        }
        .onAppear {
            guard left == 1 else { return }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { blink = true }
        }
        .accessibilityLabel("のこり \(left)日")
    }

    private func fill(_ k: Int) -> AnyShapeStyle {
        guard k < left else { return AnyShapeStyle(Color.white.opacity(0.12)) }
        if left == 1 { return AnyShapeStyle(Color(hex: "FF4F3A")) }
        return AnyShapeStyle(LinearGradient(colors: [Color(hex: "FFD08A"), Color(hex: "FF8A2A")], startPoint: .top, endPoint: .bottom))
    }
}

/// 1枚のチェキ。タップで扇 / 長押し 0.7秒で えらぶ(ふちが橙で一周)
private struct MECheki: View {
    let shot: MEShot
    let ago: Int
    let developed: Bool
    /// ひらく前の 短い文(「あと2こま」/「9:00 に ひらく」)
    var lockedText: String? = nil
    let picked: Bool
    let data: Data?
    let onTap: () -> Void
    let onPick: (Data?) -> Void
    let onTooEarly: () -> Void

    @State private var image: UIImage?
    @State private var progress: CGFloat = 0
    @State private var pressing = false
    @State private var bounce = 0
    @State private var ramp = HapticRamp()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                photo
                    .frame(width: 124, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                Spacer(minLength: 0)
            }
            .padding(7)
            .frame(width: 138, height: 197)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color(hex: "F7F4EE")))
            .overlay(alignment: .bottomLeading) {
                Text(ago == 0 ? "today" : "ME").font(.system(size: 12, design: .serif).italic()).foregroundStyle(Color(hex: "8E8E93")).padding(.leading, 9).padding(.bottom, 9)
            }
            .overlay(alignment: .bottomTrailing) {
                if let duration = shot.duration {
                    Text("▶ \(MilkCheki.durationText(duration))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Color(hex: "FF8A2A")).padding(.trailing, 9).padding(.bottom, 9)
                } else {
                    Text(shot.takenAt.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                        .font(.custom("Caveat-Bold", size: 16)).foregroundStyle(Color(hex: "3A3A3C")).padding(.trailing, 9).padding(.bottom, 7)
                }
            }
            // 動画:絵の左右にフィルムの穴
            .overlay(alignment: .top) {
                if shot.duration != nil {
                    HStack {
                        MEFilmHoles()
                        Spacer()
                        MEFilmHoles()
                    }
                    .frame(width: 124, height: 160)
                    .padding(.top, 7)
                    .allowsHitTesting(false)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .trim(from: 0, to: progress)
                    .stroke(Color(hex: "FF8A2A"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .padding(-6)
                    .opacity(progress > 0 ? 1 : 0)
            }
            .shadow(color: .black.opacity(0.55), radius: 17, y: 18)
            // ★
            Image(systemName: "star.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color(hex: "FF8A2A")).shadow(color: Color(hex: "FF7828").opacity(0.5), radius: 7, y: 6))
                .overlay(Circle().strokeBorder(Color(hex: "0A0A0C"), lineWidth: 3).padding(-3))
                .offset(x: 8, y: -10)
                .scaleEffect(picked ? 1 : 0.01)
                .animation(.spring(response: 0.45, dampingFraction: 0.45), value: picked)
        }
        .scaleEffect(1 + progress * 0.06)
        .keyframeAnimator(initialValue: 1.0, trigger: bounce) { content, s in content.scaleEffect(s) } keyframes: { _ in
            KeyframeTrack { CubicKeyframe(1.12, duration: 0.2); SpringKeyframe(1, duration: 0.32) }
        }
        .onTapGesture(perform: onTap)
        .onLongPressGesture(minimumDuration: MERules.pickHold, maximumDistance: 8) {
            ramp.stop()
            pressing = false
            guard developed else { return }
            progress = 0
            bounce += 1
            onPick(data)
        } onPressingChanged: { down in
            if down {
                guard developed else { onTooEarly(); return }
                pressing = true
                ramp.start()
                withAnimation(.linear(duration: MERules.pickHold)) { progress = 1 }
                Task { @MainActor in
                    let start = Date()
                    while pressing {
                        ramp.update(0.15 + 0.7 * min(1, Date().timeIntervalSince(start) / MERules.pickHold))
                        try? await Task.sleep(for: .milliseconds(30))
                    }
                }
            } else {
                pressing = false
                ramp.stop()
                withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
            }
        }
        .task(id: shot.id) {
            guard developed, image == nil, let data else { return }
            image = await MEImageLoader.load(key: shot.id, data: data)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(developed ? "写真\(picked ? "、えらんだ1枚" : "")" : "まだ ひらいていない。\(lockedText ?? "9:00 に ひらく")")
        .accessibilityAction(named: "えらぶ") { if developed { onPick(data) } else { onTooEarly() } }
    }

    @ViewBuilder
    private var photo: some View {
        if !developed {
            // きょう:ミルク色(写真は読まない)
            ZStack {
                LinearGradient(colors: [Color(hex: "DDE6E2"), Color(hex: "C9D3E0")], startPoint: UnitPoint(x: 0.3, y: 0), endPoint: UnitPoint(x: 0.7, y: 1))
                if let lockedText, lockedText.hasPrefix("あと") {
                    // 【B】前日の 写真:今日 あと Nこま 撮ると ひらく
                    VStack(spacing: 4) {
                        Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold))
                        Text(lockedText).font(.system(size: 12, weight: .heavy))
                    }
                    .foregroundStyle(Color(hex: "5D6770"))
                } else {
                    Text("DEVELOPING\n9:00").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(0.2 * 9)
                        .multilineTextAlignment(.center).foregroundStyle(Color(hex: "7D8790"))
                }
            }
        } else if let image {
            ZStack {
                Image(uiImage: image).resizable().scaledToFill()
                    .saturation(MERules.saturation(ago: ago))
                    .contrast(1 - Double(ago) * 0.03)
                    .brightness(Double(ago) * 0.03)
                // セピア(色を茶へ寄せる)
                Color(red: 0.44, green: 0.26, blue: 0.08).opacity(MERules.sepia(ago: ago)).blendMode(.color)
                // ふちが暗くなる
                RadialGradient(colors: [.clear, Color(red: 0.2, green: 0.1, blue: 0.04).opacity(Double(ago) * 0.07)], center: .center, startRadius: 40, endRadius: 110)
                // 6日目からは、角に光もれ
                if MERules.lightLeak(ago: ago) > 0 {
                    ZStack {
                        RadialGradient(colors: [Color(red: 1, green: 0.9, blue: 0.75).opacity(0.7), .clear], center: .topTrailing, startRadius: 0, endRadius: 90)
                        RadialGradient(colors: [Color(red: 1, green: 0.55, blue: 0.27).opacity(0.45), .clear], center: .bottomLeading, startRadius: 0, endRadius: 80)
                    }
                    .blendMode(.screen)
                    .opacity(MERules.lightLeak(ago: ago))
                }
            }
        } else {
            Color(hex: "222222")
        }
    }
}

/// 8日目から:点線のふち、ぼかした色のかたまり
private struct MEGhostCard: View {
    let tone: String?

    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [Color(hex: "C8E0A0"), Color(hex: "88B070")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 120, height: 150)
                .blur(radius: 10)
                .opacity(0.85)
            Text("8日目からは、色だけ").font(.system(size: 17, weight: .heavy)).foregroundStyle(.white)
            Text("えらんだ1枚は、\nカレンダーに 1年 のこる").font(.system(size: 13, design: .serif)).tracking(0.08 * 13)
                .multilineTextAlignment(.center).lineSpacing(5).foregroundStyle(Color(hex: "8E8E95"))
        }
        .frame(width: 250, height: 380)
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(.white.opacity(0.16), style: StrokeStyle(lineWidth: 1.4, dash: [5, 4])))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - カレンダー

enum MECalKind: Equatable {
    case shot(String?)
    case picked(String?)
    case rest
    case future
}

struct MECalCell: Identifiable, Equatable {
    let key: String
    let day: Int
    let kind: MECalKind
    let isToday: Bool
    var id: String { key }
}

enum MECalendarRules {
    static func cells(month: Date, exposure: [String: String?], picks: [String: String], now: Date, calendar: Calendar = .current) -> (leading: Int, cells: [MECalCell]) {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        let leading = calendar.component(.weekday, from: start) - 1
        let count = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        let todayKey = ExposureDayStore.dayKey(for: DailyWindow.latest(for: now, calendar: calendar).open, calendar: calendar)
        let cells: [MECalCell] = (0..<count).map { i in
            let date = calendar.date(byAdding: .day, value: i, to: start) ?? start
            let key = ExposureDayStore.dayKey(for: date, calendar: calendar)
            let kind: MECalKind
            if key > todayKey { kind = .future }
            else if picks[key] != nil { kind = .picked(exposure[key] ?? nil) }
            else if let color = exposure[key] { kind = .shot(color) }
            else { kind = .rest }
            return MECalCell(key: key, day: i + 1, kind: kind, isToday: key == todayKey)
        }
        return (leading, cells)
    }
}

/// カレンダーのボタンの右:直近4週間(7×4)
struct MEMiniGrid: View {
    let exposureDays: [ExposureDay]
    let picks: [String: String]

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: DailyWindow.latest(for: Date(), calendar: calendar).open)
        let colors = Dictionary(exposureDays.map { ($0.dayKey, $0.colorHex) }, uniquingKeysWith: { a, _ in a })
        let keys: [String] = (0..<28).reversed().map { ExposureDayStore.dayKey(for: calendar.date(byAdding: .day, value: -$0, to: today) ?? today, calendar: calendar) }
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(8), spacing: 3), count: 7), spacing: 3) {
            ForEach(keys, id: \.self) { key in
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(colors[key].map { Color(hex: $0 ?? "FFB27A") } ?? Color.white.opacity(0.08))
                    .frame(width: 8, height: 8)
                    .overlay { if picks[key] != nil { RoundedRectangle(cornerRadius: 2.5).strokeBorder(.white, lineWidth: 1.4) } }
            }
        }
        .frame(width: 7 * 8 + 6 * 3)
        .accessibilityHidden(true)
    }
}

struct MECalendarSheet: View {
    let exposureDays: [ExposureDay]
    let picks: [String: String]
    /// 日めくりの7日(今日 → 6日前)
    let recentKeys: [String]
    let onJump: (Int) -> Void
    let onToast: (String) -> Void
    let onClose: () -> Void

    @State private var pops: [String: Int] = [:]

    private var months: [Date] {
        let calendar = Calendar.current
        let now = Date()
        let oldest = exposureDays.last?.captureDate ?? now
        let start = max(oldest, calendar.date(byAdding: .month, value: -11, to: now) ?? now)
        var list: [Date] = []
        var cursor = calendar.date(from: calendar.dateComponents([.year, .month], from: start)) ?? start
        let end = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        while cursor <= end {
            list.append(cursor)
            cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? end.addingTimeInterval(1)
        }
        return list
    }

    var body: some View {
        let colors = Dictionary(exposureDays.map { ($0.dayKey, $0.colorHex) }, uniquingKeysWith: { a, _ in a })
        VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(.white.opacity(0.25)).frame(width: 40, height: 5).frame(maxWidth: .infinity).padding(.bottom, 14)
                .contentShape(Rectangle().inset(by: -12)).onTapGesture(perform: onClose)
            HStack(alignment: .firstTextBaseline) {
                Text("カレンダー").font(.system(size: 24, weight: .heavy)).foregroundStyle(.white)
                Spacer()
                Text("\(String(Calendar.current.component(.year, from: Date()))) ・ ME").font(.system(size: 10, design: .monospaced)).tracking(0.18 * 10).foregroundStyle(Color(hex: "5E5E66"))
            }
            HStack(spacing: 14) {
                legend(AnyView(RoundedRectangle(cornerRadius: 3).fill(LinearGradient(colors: [Color(hex: "FFB27A"), Color(hex: "9C86FF")], startPoint: .topLeading, endPoint: .bottomTrailing))), "撮った日(色)")
                legend(AnyView(Circle().fill(Color(hex: "FF8A2A"))), "えらんだ1枚(1年)")
                legend(AnyView(RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(0.3), lineWidth: 1.4)), "おやすみ")
            }
            .padding(.top, 8)
            .padding(.bottom, 14)
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(months, id: \.self) { month in
                            monthView(month, colors: colors)
                        }
                        Color.clear.frame(height: 30).id("bottom")
                    }
                }
                .scrollIndicators(.hidden)
                .onAppear { reader.scrollTo("bottom", anchor: .bottom) }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 34, topTrailingRadius: 34, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.11, green: 0.11, blue: 0.125).opacity(0.92), Color(red: 0.055, green: 0.055, blue: 0.063).opacity(0.97)], startPoint: .top, endPoint: .bottom))
                .background(.ultraThinMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 34, topTrailingRadius: 34, style: .continuous))
                .overlay(UnevenRoundedRectangle(topLeadingRadius: 34, topTrailingRadius: 34, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func legend(_ swatch: AnyView, _ text: String) -> some View {
        HStack(spacing: 5) {
            swatch.frame(width: 9, height: 9)
            Text(text).font(.system(size: 11, design: .serif)).foregroundStyle(Color(hex: "8E8E95"))
        }
    }

    private func monthView(_ month: Date, colors: [String: String?]) -> some View {
        let layout = MECalendarRules.cells(month: month, exposure: colors, picks: picks, now: Date())
        let m = Calendar.current.component(.month, from: month)
        let english = ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"][m - 1]
        let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 7)
        return VStack(alignment: .leading, spacing: 10) {
            Text("\(english) ・ \(m)月").font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(0.2 * 12).foregroundStyle(Color(hex: "A3A3AA"))
            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"].indices, id: \.self) { i in
                    Text(["S", "M", "T", "W", "T", "F", "S"][i]).font(.system(size: 9, design: .monospaced)).foregroundStyle(Color(hex: "5E5E66"))
                }
                ForEach(0..<layout.leading, id: \.self) { _ in Color.clear.aspectRatio(1 / 1.18, contentMode: .fit) }
                ForEach(layout.cells) { cell in
                    tile(cell)
                }
            }
        }
    }

    private func tile(_ cell: MECalCell) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return ZStack(alignment: .topLeading) {
            switch cell.kind {
            case .shot(let hex):
                shape.fill(Color(hex: hex ?? "FFB27A"))
                LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: UnitPoint(x: 0.5, y: 0.55), endPoint: .bottom).clipShape(shape)
            case .picked(let hex):
                if let image = MEPickStore.image(day: cell.key) {
                    Color.clear.overlay(Image(uiImage: image).resizable().scaledToFill()).clipShape(shape)
                } else {
                    shape.fill(Color(hex: hex ?? "FFB27A"))
                }
                LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: UnitPoint(x: 0.5, y: 0.55), endPoint: .bottom).clipShape(shape)
                Image(systemName: "star.fill").font(.system(size: 7, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 14, height: 14).background(Circle().fill(Color(hex: "FF8A2A")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(4)
                // v20:えらんだのが動画なら、小さな ▶
                if MEPickStore.video(day: cell.key) != nil {
                    Image(systemName: "play.fill").font(.system(size: 7, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).padding(5)
                }
            case .rest:
                shape.fill(.white.opacity(0.04))
            case .future:
                Color.clear
            }
            Text("\(cell.day)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(cellTextColor(cell))
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
        }
        .aspectRatio(1 / 1.18, contentMode: .fit)
        .overlay { if cell.isToday { shape.strokeBorder(Color(hex: "FF8A2A"), lineWidth: 1.6) } }
        .keyframeAnimator(initialValue: 1.0, trigger: pops[cell.key, default: 0]) { content, s in content.scaleEffect(s) } keyframes: { _ in
            KeyframeTrack { CubicKeyframe(1.15, duration: 0.16); SpringKeyframe(1, duration: 0.24) }
        }
        .contentShape(shape)
        .onTapGesture { tap(cell) }
        .accessibilityLabel(accessibility(cell))
    }

    private func cellTextColor(_ cell: MECalCell) -> Color {
        switch cell.kind {
        case .shot, .picked: return .white.opacity(0.9)
        case .rest: return Color(hex: "5E5E66")
        case .future: return Color(hex: "2C2C32")
        }
    }

    private func accessibility(_ cell: MECalCell) -> String {
        switch cell.kind {
        case .shot: return "\(cell.day)日、撮った日"
        case .picked: return "\(cell.day)日、えらんだ1枚"
        case .rest: return "\(cell.day)日、おやすみ"
        case .future: return "\(cell.day)日"
        }
    }

    private func tap(_ cell: MECalCell) {
        pops[cell.key, default: 0] += 1
        if case .future = cell.kind {
            Haptics.play(.soft)
            onToast("まだ 来ていない日")
            return
        }
        if let index = recentKeys.firstIndex(of: cell.key) {
            onJump(index)
            return
        }
        switch cell.kind {
        case .picked:
            Haptics.play(.heart)
            onToast("\(cell.key.suffix(5).replacingOccurrences(of: "-", with: ".")) ・ えらんだ1枚")
        case .shot:
            Haptics.play(.tick)
            onToast("\(cell.key.suffix(5).replacingOccurrences(of: "-", with: ".")) ・ 色だけ のこっています")
        default:
            Haptics.play(.soft)
            onToast("\(cell.key.suffix(5).replacingOccurrences(of: "-", with: ".")) ・ おやすみ")
        }
    }
}


/// 動画のチェキの、フィルムの穴(幅 9pt の黒い帯に、四角い穴)
struct MEFilmHoles: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1).fill(Color(hex: "F7F4EE").opacity(0.85))
                    .frame(width: 4.5, height: 4.5).frame(maxHeight: .infinity)
            }
        }
        .frame(width: 9)
        .background(Color(hex: "111111"))
    }
}
