import SwiftUI
import WidgetKit
import UIKit

// v96:タイムライン。予約は 今 ・ 21:00(S2 が 黒へ)・ 24:00(消灯)・ 9:00(ひらく)。
// 秒は Text(timerInterval:) で 動く(エントリーを ふやさない)。S3 だけ 1時間ごとに 次の 友だち。

struct LattagEntry: TimelineEntry {
    let date: Date
    let model: WidgetModel
    /// S3:何人目の 友だちか(1時間ごとに 1つ 進む)
    let hourIndex: Int
}

struct LattagProvider: TimelineProvider {
    var hourly = false

    func placeholder(in context: Context) -> LattagEntry { Self.entry(at: Date(), snapshot: .empty) }

    func getSnapshot(in context: Context, completion: @escaping (LattagEntry) -> Void) {
        _ = WidgetSharedFonts.register
        completion(Self.entry(at: Date(), snapshot: WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LattagEntry>) -> Void) {
        _ = WidgetSharedFonts.register
        let now = Date()
        let snapshot = WidgetSnapshot.load()
        let dates = WidgetDayClock.entryDates(from: now, hourly: hourly)
        let entries = dates.map { Self.entry(at: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .after(WidgetDayClock.opens(now))))
    }

    static func entry(at date: Date, snapshot: WidgetSnapshot) -> LattagEntry {
        let model = WidgetModel.make(snapshot, now: date, filmShots: WidgetFilm.shots(now: date))
        let hour = Int(date.timeIntervalSinceReferenceDate / 3600)
        return LattagEntry(date: date, model: model, hourIndex: hour)
    }
}

/// App Group の 小さな 画像(ウィジェットの メモリは 小さい。表示の 2倍 まで の 物 だけ 置いて ある)
enum WImage {
    static func load(_ name: String?) -> UIImage? {
        guard let name, let url = LattagShared.imageURL(name) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
