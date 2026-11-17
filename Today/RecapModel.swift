import Foundation
import UIKit

// v50:ME の 7日ぶんから「Recap」(動画みたいに 流れる まとめ)を 作る ための、見た目に 寄らない データ。
// 書き出し(RecapExporter)と プレイヤー(RecapPlayerView)の 両方が、ここの並びを そのまま使う。

/// Film / Cheki / Beat:見た目と、1コマの長さだけが変わる(写真・日付は変えない)
enum RecapStyle: String, CaseIterable, Identifiable {
    case film, cheki, beat

    var id: String { rawValue }

    var label: String {
        switch self {
        case .film: return "Film"
        case .cheki: return "Cheki"
        case .beat: return "Beat"
        }
    }

    /// 1枚の写真を見せる時間(秒)
    var photoDuration: Double {
        switch self {
        case .beat: return 0.56
        case .cheki: return 1.5
        case .film: return 1.15
        }
    }

    /// 日付の橋(その日の最初)の長さ
    var dayDuration: Double { photoDuration * 0.9 }
}

/// Recap の1コマ
enum RecapSegment: Identifiable {
    case day(MEDay)
    case photo(day: MEDay, shot: MEShot, image: UIImage, kept: Bool)
    case end(totalShots: Int, keptCount: Int, rangeLabel: String, covers: [UIImage])

    var id: String {
        switch self {
        case .day(let day): return "day-\(day.key)"
        case .photo(_, let shot, _, _): return "photo-\(shot.id)"
        case .end: return "end"
        }
    }

    func duration(style: RecapStyle) -> Double {
        switch self {
        case .day: return style.dayDuration
        case .photo: return style.photoDuration
        case .end: return 0
        }
    }
}

enum RecapSequence {
    /// 古い日 → 新しい日の順(mock と同じ)。ひらいていない(今日の未発表)コマは含めない。
    /// image が取れないコマは、その1枚だけ抜く(日付の橋は、ひらいているコマが1枚でもあれば出す)。
    static func build(days: [MEDay], image: (MEShot) -> UIImage?) -> [RecapSegment] {
        let ordered = days.sorted { $0.ago > $1.ago } // 古い(ago大)→新しい(ago小)
        var segments: [RecapSegment] = []
        var allShots: [(day: MEDay, shot: MEShot, image: UIImage)] = []
        for day in ordered {
            let openShots = day.shots.filter(\.reveal.isOpen)
            let withImages = openShots.compactMap { shot -> (MEDay, MEShot, UIImage)? in
                guard let img = image(shot) else { return nil }
                return (day, shot, img)
            }
            guard !withImages.isEmpty else { continue }
            segments.append(.day(day))
            for (d, shot, img) in withImages {
                let kept = MEPickStore.pick(day: d.key) == shot.id
                segments.append(.photo(day: d, shot: shot, image: img, kept: kept))
                allShots.append((d, shot, img))
            }
        }
        guard !allShots.isEmpty else { return [] }
        let keptCount = Set(ordered.compactMap { MEPickStore.pick(day: $0.key) }).count
        let rangeLabel = rangeLabel(days: ordered)
        let covers = Array(allShots.suffix(6)).map(\.image)
        segments.append(.end(totalShots: allShots.count, keptCount: keptCount, rangeLabel: rangeLabel, covers: covers))
        return segments
    }

    private static func rangeLabel(days: [MEDay]) -> String {
        guard let oldest = days.max(by: { $0.ago < $1.ago }), let newest = days.min(by: { $0.ago < $1.ago }) else { return "" }
        return "\(MERules.dot(oldest.date)) — \(MERules.dot(newest.date))"
    }

    /// 1枚でも ひらいている コマが あるか(無ければ、Recap の入口ごと 出さない)
    static func hasAnyOpenShot(days: [MEDay]) -> Bool {
        days.contains { day in day.shots.contains { $0.reveal.isOpen } }
    }
}
