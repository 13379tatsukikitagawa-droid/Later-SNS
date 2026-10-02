import SwiftUI
import SwiftData

/// Today's Later画面(2026/9 再設計「v3 縦スクロール・フィルムリール」)。自分が撮った
/// 直近7日間の記録を、1日1枚の大きなチェキ風カードとして縦に並べる。画面全体を
/// 1本の35mmフィルムに見立て、左右のパーフォレーション帯はコンテンツと一緒に流れる。
/// PersonalタブとProfileの「カレンダー」リンクから遷移する。閲覧専用。
///
/// 旧デザインにあった「Worldで選ぶ」導線・問いかけ文・インセンティブ文言は廃止した
/// (実際の選出処理はWorldPostDetailView.selectButton側に残っている)。
struct TodaysLaterCalendarView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.dismiss) private var dismiss

    /// スクロールを始めたら、下端の「まだ続く」シェブロンを消す。
    @State private var hasScrolled = false

    private static let accent = Color.laterAccent
    static let dayCount = 7

    private var calendar: Calendar { Calendar.current }

    /// 今日(index 0)〜6日前の7日分と、その日の代表写真(最新の1枚)。
    private var reelDays: [ReelDay] {
        let myPhotos = UserProfile.current(from: profiles)?.photos ?? []
        let today = calendar.startOfDay(for: Date())
        return (0..<Self.dayCount).compactMap { daysAgo in
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            let latest = myPhotos
                .filter { calendar.isDate($0.captureDate, inSameDayAs: day) }
                .max { $0.captureDate < $1.captureDate }
            return ReelDay(date: day, daysAgo: daysAgo, photo: latest)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 14)

            ScrollView {
                reel
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .bottom)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > 8
            } action: { _, scrolled in
                if scrolled && !hasScrolled {
                    withAnimation(.easeOut(duration: 0.25)) { hasScrolled = true }
                }
            }
            .overlay(alignment: .bottom) {
                scrollHint
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .background(Color.laterBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - ヘッダー

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.laterText)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("戻る")

                Text("Today's \(Text("Later").foregroundStyle(Self.accent))")
                    .font(.system(size: 24, weight: .heavy).italic())
                    .foregroundStyle(Color.laterText)
                    .accessibilityAddTraits(.isHeader)

                Spacer()
            }

            Text("下にスクロールして、直近7日間を巻き戻す")
                .font(.system(size: 12))
                .foregroundStyle(Color.laterTextMuted)
        }
    }

    // MARK: - フィルムリール本体

    private var reel: some View {
        LazyVStack(spacing: 0) {
            ForEach(reelDays) { day in
                if day.daysAgo > 0 {
                    FrameGap(daysAgo: day.daysAgo)
                }
                ReelDayCard(day: day, total: Self.dayCount)
            }

            FilmTail()
        }
        .padding(.horizontal, FilmPerforationStrip.width + 14)
        .padding(.top, 6)
        // タブバーの下(画面最下部)まで帯を通しつつ、最後のコマが下端のフェードに隠れないようにする。
        .padding(.bottom, 120)
        // パーフォレーション帯はコンテンツと同じスクロール座標系に乗せる(固定装飾にしない)。
        .background {
            HStack(spacing: 0) {
                FilmPerforationStrip()
                Spacer(minLength: 0)
                FilmPerforationStrip()
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: - 下端のフェード+シェブロン

    private var scrollHint: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color.laterBackground.opacity(0), Color.laterBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 110)

            if !hasScrolled {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Self.accent)
                    .padding(.bottom, 40)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - データ

private struct ReelDay: Identifiable {
    let date: Date
    /// 0=今日、6=6日前。
    let daysAgo: Int
    /// その日の最新の1枚。撮っていない日はnil。
    let photo: LaterPhoto?

    var id: Date { date }
    var isToday: Bool { daysAgo == 0 }
}

// MARK: - デイリーカード(チェキ風)

private struct ReelDayCard: View {
    let day: ReelDay
    let total: Int

    private static let accent = Color.laterAccent
    /// チェキの印画紙の白(真っ白より少し温かみのある色)。暗い背景から浮かせる。
    private static let paper = Color(hex: "F3F0E8")
    private static let ink = Color(hex: "1B2A20")
    private static let inkMuted = Color(hex: "55665A")
    private static let unexposed = Color(hex: "0B1510")

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日"
        return f
    }()

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "EEEE"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "H:mm"
        return f
    }()

    private static let spokenTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "H時mm分"
        return f
    }()

    private static let unlockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日 H:mm"
        return f
    }()

    private var hasRecord: Bool { day.photo != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photoArea
                .aspectRatio(4.0 / 5.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if day.isToday { todayBadge.padding(10) }
                }
                .overlay(alignment: .topTrailing) {
                    frameNumber.padding(10)
                }

            caption
                .padding(.horizontal, 4)
                .padding(.top, 14)
                .padding(.bottom, 6)
        }
        .padding(12)
        .padding(.bottom, 8)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Self.paper))
        .opacity(hasRecord ? 1 : 0.55)
        .shadow(color: .black.opacity(0.45), radius: 14, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: 写真

    @ViewBuilder
    private var photoArea: some View {
        if let photo = day.photo {
            if photo.isUnlocked {
                Color.black
                    .overlay {
                        CachedPhotoImage(imageData: photo.imageData, cacheKey: photo.imageCacheKey) { uiImage in
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Self.unexposed
                        }
                    }
                    .clipped()
            } else {
                placeholderFrame(
                    systemImage: "hourglass",
                    title: "現像中",
                    subtitle: "\(Self.unlockFormatter.string(from: photo.unlockDate))に解禁",
                    tint: Self.accent
                )
            }
        } else {
            placeholderFrame(
                systemImage: "film",
                title: "この日の記録はありません",
                subtitle: nil,
                tint: Color.laterTextMuted
            )
        }
    }

    /// 写真が無い/まだ見られないコマ。未露光のフィルムのような暗い面にする。
    private func placeholderFrame(systemImage: String, title: String, subtitle: String?, tint: Color) -> some View {
        ZStack {
            LinearGradient(
                colors: [Self.unexposed, Color.laterCard],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.laterText)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.laterTextMuted)
                }
            }
        }
    }

    private var todayBadge: some View {
        Text("TODAY")
            .font(.system(size: 11, weight: .heavy))
            .tracking(1.2)
            .foregroundStyle(Color.laterBackground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Self.accent))
    }

    private var frameNumber: some View {
        Text(String(format: "%02d / %02d", day.daysAgo + 1, total))
            .font(.custom("Courier New", size: 12).weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.black.opacity(0.55)))
    }

    // MARK: 手書き日付+メタ情報

    private var caption: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Self.dateFormatter.string(from: day.date))
                .font(.custom("Caveat-Bold", size: 34))
                .foregroundStyle(Self.ink)

            Text(metaParts.joined(separator: " ・ "))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Self.inkMuted)
                .lineLimit(1)
        }
    }

    /// 曜日・地域・時刻。地域/時刻は投稿時に保存済みの値をそのまま使う
    /// (locationNameは撮影時点で市区町村レベルに丸め済み)。
    private var metaParts: [String] {
        var parts = [Self.weekdayFormatter.string(from: day.date)]
        if let photo = day.photo {
            if let location = photo.locationName, !location.isEmpty {
                parts.append(location)
            }
            parts.append(Self.timeFormatter.string(from: photo.captureDate))
        } else {
            parts.append("記録なし")
        }
        return parts
    }

    private var accessibilityText: String {
        let date = Self.dateFormatter.string(from: day.date)
        let weekday = Self.weekdayFormatter.string(from: day.date)
        let prefix = day.isToday ? "今日、" : ""
        guard let photo = day.photo else {
            return "\(prefix)\(date)、\(weekday)、記録なし"
        }
        var parts = [date, weekday]
        if let location = photo.locationName, !location.isEmpty {
            parts.append(location)
        }
        parts.append(Self.spokenTimeFormatter.string(from: photo.captureDate))
        let suffix = photo.isUnlocked ? "の記録" : "の記録、現像中"
        return prefix + parts.joined(separator: "、") + suffix
    }
}

// MARK: - コマ間の区切り

private struct FrameGap: View {
    let daysAgo: Int

    var body: some View {
        HStack(spacing: 10) {
            dashes
            Text("\(daysAgo)日前")
                .font(.custom("Courier New", size: 12).weight(.bold))
                .foregroundStyle(Color.laterTextMuted)
                .fixedSize()
            dashes
        }
        .padding(.vertical, 22)
        .accessibilityHidden(true)
    }

    private var dashes: some View {
        Rectangle()
            .fill(Color.laterBorder)
            .frame(height: 1)
    }
}

// MARK: - フィルムのテール(終端)

private struct FilmTail: View {
    var body: some View {
        VStack(spacing: 10) {
            // 巻き取り側の先端(リーダー/テール)を模した、先細りの帯
            UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28, style: .continuous)
                .fill(Color.laterCard)
                .overlay(
                    UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28, style: .continuous)
                        .strokeBorder(Color.laterBorder, lineWidth: 1)
                )
                .frame(height: 56)
                .overlay {
                    Text("END OF ROLL")
                        .font(.custom("Courier New", size: 13).weight(.bold))
                        .tracking(3)
                        .foregroundStyle(Color.laterAccent)
                }

            Text("ここまでです ・ それより前は残りません")
                .font(.system(size: 12))
                .foregroundStyle(Color.laterTextMuted)
        }
        .padding(.top, 30)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ここまでです。それより前の記録は残りません")
    }
}

// MARK: - 35mmフィルムのパーフォレーション帯

private struct FilmPerforationStrip: View {
    static let width: CGFloat = 20

    private static let holeSize = CGSize(width: 9, height: 12)
    private static let pitch: CGFloat = 22

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: "08120C")))
            let x = (size.width - Self.holeSize.width) / 2
            var y: CGFloat = 6
            while y < size.height {
                let hole = CGRect(x: x, y: y, width: Self.holeSize.width, height: Self.holeSize.height)
                context.fill(
                    Path(roundedRect: hole, cornerRadius: 2.5),
                    with: .color(Color.laterAccent.opacity(0.14))
                )
                y += Self.pitch
            }
        }
        .frame(width: Self.width)
    }
}
