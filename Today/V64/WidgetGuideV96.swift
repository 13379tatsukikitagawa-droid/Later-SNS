import SwiftUI

// v104:ウィジェット。先に 1つ えらぶ → アプリの 中の 動く 案内(5場面)→ もどった 時に 自動で たしかめる。
// アプリから ホーム画面へ 行く ・ ウィジェットを 自動で 置く ことは できない(iOS の きまり)。
// 見本は 実際の ウィジェットと 同じ View(拡張と 共有)を 見本の データで 並べる。

enum WidgetGuideV96 {
    /// v104:出すのは はじめての 時 1回 だけ(`@AppStorage("widgetOfferShown")`)。設定からは 何度でも
    static let seenKey = "widgetOfferShown"
    static var seen: Bool { UserDefaults.standard.bool(forKey: seenKey) || UserDefaults.standard.bool(forKey: "widgetGuideV96.seen") }
    static func markSeen() { UserDefaults.standard.set(true, forKey: seenKey) }

    /// 見本の データ(画像なし。写真は 灰色の 台紙)
    static func sample(now: Date = Date()) -> WidgetModel {
        let key = LaterDay.key(for: now)
        let friends = [("れな", "れ", "C8F25A", 3), ("あや", "あ", "9ED8FF", 2), ("そら", "そ", "EE5E9C", 0), ("かい", "か", "F4B942", 1)].map { n, i, c, s in
            FriendRing(uid: n, name: n, initial: i, colorHex: c, shotsToday: s, avatar: nil)
        }
        let snap = WidgetSnapshot(dayKey: key, writtenAt: now, shots: 1, limit: 3, shotTimes: [now.addingTimeInterval(-3600)], shotBlurs: [], friends: friends, today: nil,
                                  yesterday: DaySummary(dayKey: key, people: 4, count: 11, tag: "夕焼け", names: ["れな", "あや", "そら", "かい"]),
                                  yesterdayPhotos: [], lockedPreviews: [], mondoTag: "夕焼け", mondoCount: 1203, mondoCountries: 128,
                                  trip: TripSnap(id: "sample", title: "京都 2泊3日", sub: "11/19 THU ・ 3人", day: 2, count: 12, total: 23, passNo: 4065, filled: Array(0..<12), cover: nil),
                                  next: nil, myRecordName: nil, myName: "")
        return WidgetModel.make(snap, now: now)
    }
}

