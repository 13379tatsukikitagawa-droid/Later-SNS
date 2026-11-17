import SwiftData
import SwiftUI

/// v47:ON THIS DAY。ALBUMS の下。1週間前・1か月前・2か月前…の同じ日に、★で残した1枚があれば出す。
/// ★は MEPickStore(1日1枚・1年だけ端末に残る)。1枚もない日はセクションごと出さない。
enum OnThisDayRules {
    /// 試す「何日前」の一覧(近い順)
    static let offsets = [7, 30, 60, 90, 180, 270, 330]

    static func agoLabel(_ ago: Int) -> String {
        switch ago {
        case 7: return "1 week ago"
        case 30: return "1 month ago"
        case 60: return "2 months ago"
        case 90: return "3 months ago"
        case 180: return "6 months ago"
        case 270: return "9 months ago"
        default: return "11 months ago"
        }
    }

    static func memories(now: Date, exposureDays: [ExposureDay], calendar: Calendar = .current) -> [OnThisDayMemory] {
        offsets.compactMap { ago in
            guard let date = calendar.date(byAdding: .day, value: -ago, to: now) else { return nil }
            let key = ExposureDayStore.dayKey(for: date, calendar: calendar)
            guard let shotID = MEPickStore.pick(day: key) else { return nil }
            let day = exposureDays.first { $0.dayKey == key }
            return OnThisDayMemory(
                dayKey: key, shotID: shotID, date: date, ago: ago,
                capturedAt: day?.captureDate, place: day?.locationName, tags: MEPickStore.tags(day: key)
            )
        }
    }
}

struct OnThisDayMemory: Identifiable {
    let dayKey: String
    let shotID: String
    let date: Date
    let ago: Int
    let capturedAt: Date?
    let place: String?
    let tags: [String]

    var id: String { dayKey }
    var daysLeft: Int { max(0, MEPickStore.keepDays - ago) }
}

struct OnThisDaySection: View {
    let now: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \ExposureDay.captureDate, order: .reverse) private var exposureDays: [ExposureDay]
    @State private var index = 0
    @State private var flipped = false
    @State private var showsLarge = false

    private var memories: [OnThisDayMemory] { OnThisDayRules.memories(now: now, exposureDays: Array(exposureDays)) }

    var body: some View {
        let list = memories
        if !list.isEmpty {
            let memory = list[index % list.count]
            VStack(alignment: .leading, spacing: 0) {
                DarkLabel(text: "ON THIS DAY")
                HStack(alignment: .top, spacing: 18) {
                    cheki(memory)
                    info(memory, count: list.count)
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
            }
            .onChange(of: memory.dayKey) { _, _ in flipped = false }
            .fullScreenCover(isPresented: $showsLarge) {
                ZStack {
                    Color.black.ignoresSafeArea()
                    if let image = MEPickStore.image(day: memory.dayKey) {
                        Image(uiImage: image).resizable().scaledToFit()
                    }
                    VStack {
                        HStack {
                            Button { showsLarge = false } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Circle().fill(.white.opacity(0.14)))
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        .padding(20)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: チェキふうのカード(タップでうらがえる・長押しで大きく)

    private func cheki(_ memory: OnThisDayMemory) -> some View {
        ZStack {
            if flipped {
                back(memory).rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            } else {
                front(memory)
            }
        }
        .frame(width: 118, height: 150)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .rotationEffect(.degrees(-4))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8), value: flipped)
        .onTapGesture {
            Haptics.play(.tick)
            flipped.toggle()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            // mock:のこした1枚を ひらく瞬間は「ドクン」(heart)。
            Haptics.play(.heart)
            showsLarge = true
        }
        .accessibilityLabel("\(OnThisDayRules.agoLabel(memory.ago))の1枚。タップで裏を見る。長押しで大きく見る")
    }

    private func front(_ memory: OnThisDayMemory) -> some View {
        ZStack(alignment: .bottom) {
            if let image = MEPickStore.image(day: memory.dayKey) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Darkroom.card2
            }
            Rectangle().fill(.white).frame(height: 34)
                .overlay(
                    Text(verbatim: Darkroom.dayLabel(memory.date))
                        .font(Darkroom.mono(9))
                        .foregroundStyle(Darkroom.stamp)
                )
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: "star.fill")
                .font(.system(size: 11))
                .foregroundStyle(Darkroom.star)
                .shadow(color: .black.opacity(0.4), radius: 2)
                .padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func back(_ memory: OnThisDayMemory) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if let capturedAt = memory.capturedAt {
                Text(verbatim: Darkroom.time(capturedAt)).font(.system(size: 11, weight: .bold, design: .serif))
            }
            if let place = memory.place {
                Text(verbatim: place).font(.system(size: 10.5, design: .serif)).lineLimit(2)
            }
            if let tag = memory.tags.first {
                Text(verbatim: "#\(tag)").font(.system(size: 10.5, design: .serif)).foregroundStyle(Color(hex: "C0392B"))
            }
            Spacer(minLength: 0)
            Text(verbatim: "kept ★").font(.system(size: 9, weight: .semibold, design: .serif)).foregroundStyle(.black.opacity(0.5))
        }
        .foregroundStyle(.black.opacity(0.78))
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: 右:日付・のこりバー・次へ

    private func info(_ memory: OnThisDayMemory, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: Darkroom.dayLabel(memory.date)).font(Darkroom.title(Darkroom.dayLabel(memory.date), size: 22))
            Text(verbatim: OnThisDayRules.agoLabel(memory.ago))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Darkroom.weak)
            yearBar(memory)
            HStack(spacing: 8) {
                Text(verbatim: "\(memory.daysLeft) DAYS LEFT")
                    .font(Darkroom.mono(10))
                    .foregroundStyle(Darkroom.faint)
                if count > 1 {
                    Circle().fill(Darkroom.faint).frame(width: 3, height: 3)
                    Button {
                        Haptics.play(.tick)
                        index += 1
                    } label: {
                        Text(verbatim: "›").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func yearBar(_ memory: OnThisDayMemory) -> some View {
        let progress = Double(memory.daysLeft) / Double(MEPickStore.keepDays)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12)).frame(height: 4)
                Capsule().fill(Darkroom.orange).frame(width: max(3, geo.size.width * progress), height: 4)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}
