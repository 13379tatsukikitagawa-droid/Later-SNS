import SwiftUI
import UIKit

/// 「預けた日々」の1点(直近7日・1日1枚)。ProfileShot.visibleShotsが作る。
struct WeekDayPoint: Identifiable, Equatable {
    let id: String              // ExposureDay.dayKey
    let date: Date
    /// その日の1枚がひらいているか(その日より後に撮っていれば、ひらいている)
    let opened: Bool
    /// 写真の中心の色(ひらいている日だけ。ひらいていない日は白)
    let color: Color?
    let locationName: String?
    let tags: [String]
    /// 写真(本体)を見てよい期間内か(7日以内)
    let showsPhoto: Bool
    /// 消えるまでの残り日数(1〜7)。すでに期限を過ぎていれば0。
    let remainingDays: Int
    /// その日の1枚が届いているグループ(MEを除く)
    var groups: [ProfileShareGroup] = []
    /// その日の1枚が、いま Mondo に出ているか
    var isOnMondo = false

    /// まだひらいていない1枚(撮った翌朝9:00まで)。点・レールでは「今日の点」として出す。
    var isToday: Bool { !opened }

    /// 濃さ(0.3〜1.0)。古い日ほどうすい。
    var weight: Double { 0.3 + 0.7 * Double(min(7, max(0, remainingDays))) / 7 }

    var remainingText: String {
        remainingDays <= 1 ? "あしたの朝、消えます" : "あと\(remainingDays)日で、消えます"
    }
}

// MARK: - なぞった時の小さなカード

struct WeekDayCard: View {
    let point: WeekDayPoint
    let thumbnail: UIImage?

    static let width: CGFloat = 150
    static let approximateHeight: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnailArea
                .frame(width: Self.width - 14, height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(title)
                .font(.system(size: 16, weight: .bold))
                .tracking(-0.03 * 16)
                .foregroundStyle(.white)
                .padding(.top, 8)
                .padding(.horizontal, 3)

            Text(subtitle)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(Color(hex: "8E8E93"))
                .lineLimit(1)
                .padding(.top, 2)
                .padding(.horizontal, 3)
                .padding(.bottom, 4)
        }
        .padding(7)
        .frame(width: Self.width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "1D1D20"), Color(hex: "121214")], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 24, y: 12)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var thumbnailArea: some View {
        if point.opened, point.showsPhoto, let thumbnail {
            Image(uiImage: thumbnail).resizable().aspectRatio(contentMode: .fill)
        } else if point.opened {
            (point.color ?? .white).opacity(0.55)
        } else {
            ZStack {
                Color.black
                Circle().fill(.white).frame(width: 6, height: 6).shadow(color: .white.opacity(0.8), radius: 5)
            }
        }
    }

    private var title: String {
        if !point.opened { return point.isToday ? "今日の1枚" : Self.dateLabel(point.date) }
        return Self.dateLabel(point.date)
    }

    private var subtitle: String {
        if !point.opened { return "あしたの朝 9:00 に、ひらきます" }
        return point.remainingText
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter
    }()
    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    static func dateLabel(_ date: Date) -> String { dateFormatter.string(from: date) }
    static func weekdayLabel(_ date: Date) -> String { weekdayFormatter.string(from: date) }
}
