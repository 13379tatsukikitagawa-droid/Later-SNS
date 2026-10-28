import SwiftUI
import UIKit

// 発表された一枚(世界の一枚・グループの一枚)の見た目。
// 集計の方法(DailyPick の作成・9:00 の集計)はまだ決まっていないので、ここは「ローカルの仮の状態」。
// 何も入っていない間は、MONDO のカードも GROUP のタイルも出さない(初日・灯ゼロの日と同じ)。

/// 発表された一枚(画面に出すぶんだけ)
struct AnnouncedPick: Equatable, Identifiable {
    /// 撮影日 yyyy-MM-dd
    let day: String
    /// `world` またはグループの recordName
    let scope: String
    let photoRecordName: String
    let tags: [String]
    let source: ViewerPage.Source
    /// グループの一枚:撮った人の丸
    var authorSeed: UUID?
    var authorImage: Data?

    var id: String { "\(day)|\(scope)" }
    var isWorld: Bool { scope == LampScope.world }
}

/// 発表された一枚の置き場(ローカルの仮)。DailyPick が決まったら、ここへ流しこむ。
/// 今は何も入っていない(DailyPick も 9:00 の集計も、まだ作っていない)。
@MainActor
@Observable
final class AnnouncedPickStore {
    static let shared = AnnouncedPickStore()

    private static let seenKey = "calendarSeenDay"

    /// 発表ずみの一枚(世界とグループ。日付ごと)
    var picks: [AnnouncedPick] = []
    private var seenRevision = 0

    /// その日の世界の一枚。なければ nil(カードを出さない)
    func world(day: String) -> AnnouncedPick? {
        picks.first { $0.day == day && $0.isWorld }
    }

    /// その日のグループの一枚(グループの recordName ごと)。なければタイルを出さない
    func group(day: String, scope: String) -> AnnouncedPick? {
        picks.first { $0.day == day && $0.scope == scope }
    }

    /// その日のグループの一枚の数(カレンダーの下の点)
    func groupPicks(day: String) -> [AnnouncedPick] {
        picks.filter { $0.day == day && !$0.isWorld }
    }

    /// 新しい一枚があって、まだカレンダーを開いていないか(ボタンの橙の点)
    var hasUnseen: Bool {
        _ = seenRevision
        guard let latest = picks.filter(\.isWorld).map(\.day).max() else { return false }
        return latest > (UserDefaults.standard.string(forKey: Self.seenKey) ?? "")
    }

    /// カレンダーを開いた。橙の点を消す
    func markSeen() {
        guard let latest = picks.map(\.day).max() else { return }
        UserDefaults.standard.set(latest, forKey: Self.seenKey)
        seenRevision += 1
    }
}

// MARK: - 写真

/// 発表された一枚の写真。土台が大きさを決め、写真は overlay に入れて切る(fill の写真が親の幅を広げないように)。
struct AnnouncedPhoto: View {
    let pick: AnnouncedPick

    @State private var image: UIImage?

    var body: some View {
        Group {
            switch pick.source {
            case .mondo(let entry):
                MondoTile(entry: entry, cornerRadius: 0)
            case .local:
                Color(hex: "2A2A2E")
                    .overlay(LinearGradient(colors: [.white.opacity(0.08), .black.opacity(0.25)], startPoint: .top, endPoint: .bottom))
                    .overlay {
                        if let image {
                            Image(uiImage: image).resizable().aspectRatio(contentMode: .fill).transition(.opacity)
                        }
                    }
                    .clipped()
                    .task(id: pick.id) {
                        guard case .local(let data) = pick.source, let data, !data.isEmpty else { return }
                        let loaded = await TileImageLoader.image(id: "pick|" + pick.id, data: data)
                        withAnimation(.easeOut(duration: 0.3)) { image = loaded }
                    }
            }
        }
    }
}

// MARK: - MONDO:昨日の一枚(大きなカード)

/// チェキの紙に載せた、縦長の写真(上と横 12・下 66)。幅は呼ぶ側が画面の幅から決める(固定の数字にしない)。
struct AnnouncedWorldCard: View {
    /// 写真の縦横の比(452 / 350)
    static let aspect: CGFloat = 452 / 350

    let pick: AnnouncedPick
    let width: CGFloat
    let onOpen: (CGPoint) -> Void

    var body: some View {
        let w = max(0, width)
        let photoWidth = max(0, w - 24)
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                AnnouncedPhoto(pick: pick)

                // 左上:点灯アイコン(42pt)
                LampBadge(diameter: 42)
                    .padding(12)

                // 右上:地球(世界の一枚)
                Image(systemName: "globe")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.black.opacity(0.35)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(12)
                    .accessibilityHidden(true)
            }
            .frame(width: photoWidth, height: photoWidth * Self.aspect)
            .clipped()

            // 紙の下の厚いところ:ハッシュタグ(インク)と撮影日
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(pick.tags.prefix(2).enumerated()), id: \.offset) { index, tag in
                        Text("#\(tag)")
                            .font(V5.hand(index == 0 ? 22 : 16))
                            .foregroundStyle(index == 0 ? ChicColor.ink : ChicColor.sub)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                Spacer(minLength: 0)
                Text(V5.monthDay(fromDayKey: pick.day))
                    .font(V5.mono(13, weight: .medium))
                    .foregroundStyle(ChicColor.sub)
                    .lineLimit(1)
            }
            .frame(width: photoWidth, height: 66, alignment: .leading)
        }
        .chicPrint(side: 12, bottom: 0, rotation: ChicTilt.degrees(0))
        .padding(.bottom, 4)
        .contentShape(Rectangle())
        .onSpatialTap(perform: onOpen)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("昨日の一枚。\(pick.tags.map { "#\($0)" }.joined(separator: " "))")
    }
}

// MARK: - GROUP:発表された一枚(タイル)

/// グループのカードの写真の列の、いちばん左。チェキの紙(118 × 170・上と横 5・下 30)。
struct AnnouncedGroupTile: View {
    static let width: CGFloat = 118
    static let height: CGFloat = 170

    let pick: AnnouncedPick
    let onTap: (CGPoint) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                AnnouncedPhoto(pick: pick)
                VStack {
                    HStack(alignment: .top) {
                        Spacer(minLength: 4)
                        LampBadge(diameter: 32)
                    }
                    Spacer(minLength: 0)
                }
                .padding(6)
                .allowsHitTesting(false)
            }
            .frame(width: 108, height: 135)
            .clipped()

            Text(V5.monthDay(fromDayKey: pick.day))
                .font(V5.mono(11, weight: .medium))
                .foregroundStyle(ChicColor.sub)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 108, height: 30, alignment: .leading)
        }
        .chicPrint(side: 5, bottom: 0, rotation: ChicTilt.degrees(0))
        .frame(width: Self.width, height: Self.height)
        .contentShape(Rectangle())
        .onSpatialTap(perform: onTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("発表された一枚。\(pick.tags.map { "#\($0)" }.joined(separator: " "))")
    }
}

/// 自分の灯の印(GROUP のタイルの右下の、小さな点灯アイコン)
struct LampTileMark: View {
    var body: some View {
        LampBadge(diameter: 24)
            .accessibilityLabel("灯をともした写真")
    }
}
