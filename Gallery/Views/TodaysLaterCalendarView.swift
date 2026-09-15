import SwiftUI
import SwiftData

/// 「今日のLater」(World Laterから自分が選んだ1枚)を月間グリッドに蓄積表示する
/// カレンダー画面。BeRealのカレンダー機能に近い見た目を目指すが、今回は簡易な
/// グリッド表示のみ(詳細なビジュアルデザインは別途)。
///
/// 選択記録(TodaysLaterSelection)自体はWorldPostのrecordNameしか持たないため、
/// 表示にはCloudKitのPublic DBから該当WorldPostを個別にフェッチする必要がある
/// (WorldPostはローカルのSwiftDataには永続化されていない、WorldLaterFeedView参照)。
/// 表示中の月に含まれる選択分だけを都度フェッチし、サムネイルとしてキャッシュする。
struct TodaysLaterCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TodaysLaterSelection.selectedDate, order: .reverse) private var selections: [TodaysLaterSelection]

    @State private var displayedMonth: Date = Date()
    @State private var loadedPosts: [String: WorldPost] = [:]
    @State private var isLoadingThumbnails = false
    @State private var selectedSelection: TodaysLaterSelection?

    private var calendar: Calendar { Calendar.current }

    private var selectionsInDisplayedMonth: [TodaysLaterSelection] {
        selections.filter { calendar.isDate($0.selectedDate, equalTo: displayedMonth, toGranularity: .month) }
    }

    private func selection(onDay day: Int) -> TodaysLaterSelection? {
        var components = calendar.dateComponents([.year, .month], from: displayedMonth)
        components.day = day
        guard let date = calendar.date(from: components) else { return nil }
        return selectionsInDisplayedMonth.first { calendar.isDate($0.selectedDate, inSameDayAs: date) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        monthHeader
                        calendarGrid
                        if selectionsInDisplayedMonth.isEmpty {
                            emptyMonthNote
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("カレンダー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .task(id: displayedMonth) { await loadThumbnailsForDisplayedMonth() }
        .sheet(item: $selectedSelection) { selection in
            TodaysLaterSelectionDetailView(selection: selection, post: loadedPosts[selection.targetPostRecordName])
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer()
            Text(displayedMonth.formatted(.dateTime.year().month(.wide)))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Button { changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var calendarGrid: some View {
        let month = calendar.component(.month, from: displayedMonth)
        let year = calendar.component(.year, from: displayedMonth)
        return VStack(spacing: 10) {
            HStack {
                ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(daysInMonth(month: month, year: year), id: \.self) { day in
                    if day > 0 {
                        dayCell(day: day)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
    }

    private func dayCell(day: Int) -> some View {
        let match = selection(onDay: day)
        let isToday = isDayToday(day: day)
        return Button {
            if let match { selectedSelection = match }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(match != nil ? Color.white.opacity(0.08) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isToday ? Color.brandGreen.opacity(0.6) : Color.clear, lineWidth: 1.5)
                    )

                if let match, let post = loadedPosts[match.targetPostRecordName] {
                    CachedPhotoImage(imageData: post.imageData, cacheKey: post.imageCacheKey) { uiImage in
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.white.opacity(0.05)
                    }
                    .frame(height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    Text("\(day)")
                        .font(.system(size: 13, weight: match != nil ? .bold : .regular))
                        .foregroundStyle(match != nil ? .white : .white.opacity(0.4))
                }
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .disabled(match == nil)
    }

    private var emptyMonthNote: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.25))
            Text("この月にはまだ「今日のLater」がありません")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.top, 24)
    }

    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newDate
        }
    }

    private func isDayToday(day: Int) -> Bool {
        var components = calendar.dateComponents([.year, .month], from: displayedMonth)
        components.day = day
        guard let date = calendar.date(from: components) else { return false }
        return calendar.isDateInToday(date)
    }

    private func daysInMonth(month: Int, year: Int) -> [Int] {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let firstDay = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else { return [] }
        let leadingBlanks = calendar.component(.weekday, from: firstDay) - 1
        return Array(repeating: 0, count: leadingBlanks) + Array(1...range.count)
    }

    private func loadThumbnailsForDisplayedMonth() async {
        guard !isLoadingThumbnails else { return }
        isLoadingThumbnails = true
        defer { isLoadingThumbnails = false }
        let myID = CloudKitManager.current?.currentUserRecordName
        for selection in selectionsInDisplayedMonth where loadedPosts[selection.targetPostRecordName] == nil {
            if let post = await WorldLaterService.fetchPost(recordName: selection.targetPostRecordName, currentUserRecordName: myID) {
                loadedPosts[selection.targetPostRecordName] = post
            }
        }
    }
}

/// カレンダーの1マスをタップした際の詳細表示。
private struct TodaysLaterSelectionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let selection: TodaysLaterSelection
    let post: WorldPost?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                VStack(spacing: 20) {
                    if let post {
                        CachedPhotoImage(imageData: post.imageData, cacheKey: post.imageCacheKey) { uiImage in
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Color.white.opacity(0.05)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 20)

                        if let locationRegion = post.locationRegion, !locationRegion.isEmpty {
                            Label(locationRegion, systemImage: "mappin")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    } else {
                        ProgressView().tint(.white)
                    }

                    Text(selection.reasonTag)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.brandGreen)

                    Text(selection.selectedDate.formatted(date: .long, time: .omitted))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))

                    Spacer()
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
        }
    }
}

#Preview {
    TodaysLaterCalendarView()
}
