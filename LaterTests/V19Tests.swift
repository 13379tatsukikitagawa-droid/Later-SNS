import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// v19 ME と Mondo の決めごと
@MainActor
struct V19Tests {
    private func entry(_ id: String, _ code: String, _ region: String?, tags: [String] = []) -> MondoEntry {
        MondoEntry(id: id, mondoID: "m\(id)", name: "x", place: MondoPlace(countryCode: code, countryName: code == "JP" ? "日本" : "Portugal", region: region),
                   tags: tags, dayKey: "2026-11-04", toneHex: nil, isMine: false)
    }

    @Test func MEの日めくりのことば() {
        let cal = Calendar.current
        let day = MEDay(key: "k", date: Date(), ago: 6, shots: [], tags: [], developed: true)
        #expect(day.daysLeft == 1)
        #expect(MERules.lifeText(day) == "あした きえる")
        #expect(MERules.lifeText(MEDay(key: "k", date: Date(), ago: 0, shots: [], tags: [], developed: false)) == "9:00 に ひらく")
        #expect(MERules.lifeText(MEDay(key: "k", date: Date(), ago: 2, shots: [], tags: [], developed: true)) == "あと 5日")
        #expect(MERules.label(ago: 1, date: Date(), calendar: cal) == "きのう")
        #expect(MERules.lightLeak(ago: 4) == 0)
        #expect(MERules.lightLeak(ago: 5) > 0)
        #expect(abs(MERules.sepia(ago: 2) - 0.15) < 0.0001)
        #expect(MERules.fan(count: 3, index: 2).x == 48)
    }

    @Test func えらぶは1日1枚で移る() {
        let saved = MEPickStore.picks
        defer { MEPickStore.picks = saved }
        MEPickStore.picks = [:]
        MEPickStore.set(day: "2026-11-04", shotID: "a", imageData: nil)
        MEPickStore.set(day: "2026-11-04", shotID: "b", imageData: nil)
        #expect(MEPickStore.pick(day: "2026-11-04") == "b")
        #expect(MEPickStore.picks.count == 1)
        MEPickStore.set(day: "2024-01-01", shotID: "old", imageData: nil)
        MEPickStore.prune(now: Date())
        #expect(MEPickStore.pick(day: "2024-01-01") == nil)
    }

    @Test func MEは同じ1枚をまとめて3枚まで() throws {
        let profile = UserProfile(name: "a", username: "")
        let cal = Calendar.current
        let now = cal.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.date(bySettingHour: 10, minute: 0, second: 0, of: now)!)!
        var photos: [LaterPhoto] = []
        for i in 0..<4 {
            let t = yesterday.addingTimeInterval(Double(i) * 3600)
            // 同じ1枚がグループ2つぶん
            for _ in 0..<2 {
                let p = LaterPhoto(imageData: Data(), captureDate: t, unlockDate: t, owner: profile)
                p.tags = ["空"]
                photos.append(p)
            }
        }
        let days = MERules.days(photos: photos, now: now)
        #expect(days.count == 7)
        #expect(days[1].shots.count == 3)
        // 【B】今日 まだ 撮っていないので、昨日の 3枚は ひらいていない(あと 1・2・3こま)
        #expect(!days[1].developed)
        #expect(days[1].shots.map(\.reveal) == [.waiting(shots: 1), .waiting(shots: 2), .waiting(shots: 3)])
        #expect(days[0].shots.isEmpty)
    }
}
