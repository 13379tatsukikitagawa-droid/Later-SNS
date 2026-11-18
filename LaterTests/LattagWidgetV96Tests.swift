import Foundation
import Testing
@testable import Later_再度

/// v96 ウィジェット:時間の 切りかわり ・ 日の またぎ ・ 写真の ルール(PROMPT_v96 §5 / §7)
struct LattagWidgetV96Tests {
    static let calendar = Calendar.current
    static let base = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_790_000_000))
    static func at(_ day: Int, _ h: Int, _ m: Int = 0) -> Date {
        calendar.date(byAdding: .minute, value: day * 1440 + h * 60 + m, to: base)!
    }

    func snap(day: Int, shots: Int, photos: Bool = true) -> WidgetSnapshot {
        var s = WidgetSnapshot.empty
        s.dayKey = LaterDay.key(for: Self.at(day, 12))
        s.shots = shots
        s.shotTimes = shots > 0 ? [Self.at(day, 10)] : []
        s.friends = [FriendRing(uid: "a", name: "あ", initial: "あ", colorHex: "EE5E9C", shotsToday: 2, avatar: nil, knock: nil)]
        s.today = DaySummary(dayKey: s.dayKey, people: 4, count: 7, tag: "夕焼け", names: ["あ"])
        s.yesterday = DaySummary(dayKey: "prev", people: 2, count: 3, tag: "朝", names: ["い"])
        s.yesterdayPhotos = photos ? [YPhoto(uid: "a", name: "あ", time: "21:12", tag: nil, thumb: "y_1.jpg")] : []
        return s
    }

    @Test func 時間帯() {
        #expect(WidgetDayClock.part(Self.at(0, 8, 59)) == .lightsOut)
        #expect(WidgetDayClock.part(Self.at(0, 9)) == .day)
        #expect(WidgetDayClock.part(Self.at(0, 20, 59)) == .day)
        #expect(WidgetDayClock.part(Self.at(0, 21)) == .evening)
        #expect(WidgetDayClock.part(Self.at(0, 23, 59)) == .evening)
        #expect(WidgetDayClock.part(Self.at(1, 0)) == .lightsOut)
    }

    @Test func 予約は_今_21時_24時_9時() {
        let dates = WidgetDayClock.entryDates(from: Self.at(0, 15))
        #expect(dates == [Self.at(0, 15), Self.at(0, 21), Self.at(1, 0), Self.at(1, 9)])
        // 夜中は 9:00 だけ
        #expect(WidgetDayClock.entryDates(from: Self.at(1, 3)) == [Self.at(1, 3), Self.at(1, 9)])
    }

    @Test func 同じ日() {
        let m = WidgetModel.make(snap(day: 0, shots: 2), now: Self.at(0, 22))
        #expect(m.shots == 2 && m.remaining == 1)
        #expect(m.unlocked)
        #expect(m.yesterday?.people == 2)
        #expect(m.yesterdayPhotos.count == 1)
        #expect(m.friendsShot == 1)
    }

    @Test func 九時を_またぐと_今日が_きのうに() {
        // アプリを ひらかず 9:00 を すぎた:こまも 友だちも 0、今日の まとめが きのうに、写真は 出さない
        let m = WidgetModel.make(snap(day: 0, shots: 3), now: Self.at(1, 9, 1))
        #expect(m.shots == 0)
        #expect(!m.unlocked)
        #expect(m.yesterday?.people == 4)
        #expect(m.yesterday?.tag == "夕焼け")
        #expect(m.yesterdayPhotos.isEmpty)
        #expect(m.friendsShot == 0)
    }

    @Test func 撮って_いなければ_写真を_出さない() {
        let m = WidgetModel.make(snap(day: 0, shots: 0), now: Self.at(0, 12))
        #expect(!m.unlocked)
        #expect(m.yesterdayPhotos.isEmpty)
    }

    @Test func フィルムの_こまが_先() {
        // 撮った 瞬間(スナップショットが まだ 古い)でも FilmCounter の 数で 進む
        let m = WidgetModel.make(snap(day: 0, shots: 0), now: Self.at(0, 12), filmShots: 1)
        #expect(m.shots == 1 && m.unlocked)
    }

    @Test func 現像の_進み() {
        let m = WidgetModel.make(snap(day: 0, shots: 1), now: Self.at(0, 21, 30))
        // 10:00 → 翌 9:00(23時間)の うち 11.5時間
        #expect(m.devPercent == 50)
    }

    @Test func 保存と_読みこみ() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ws_\(UUID().uuidString).json")
        let s = snap(day: 0, shots: 2)
        s.save(to: url)
        #expect(WidgetSnapshot.load(from: url) == s)
        try? FileManager.default.removeItem(at: url)
        #expect(WidgetSnapshot.load(from: url) == .empty)
    }

    @Test func 行き先() {
        #expect(WidgetRouteStore.route(from: URL(string: "lattag://shoot")!) == .shoot)
        #expect(WidgetRouteStore.route(from: URL(string: "lattag://yesterday?f=abc")!) == .yesterday(friend: "abc"))
        #expect(WidgetRouteStore.route(from: URL(string: "lattag://trip/1234")!) == .trip("1234"))
        #expect(WidgetRouteStore.route(from: URL(string: "lattag://friend?u=x")!) == nil)
        #expect(LattagShared.Link.yesterday(friend: "u1").absoluteString == "lattag://yesterday?f=u1")
    }

    @Test @MainActor func 友だちの_色は_起動ごとに_同じ() {
        #expect(WidgetSnapshotWriter.color(for: "abc") == WidgetSnapshotWriter.color(for: "abc"))
        #expect(WidgetSnapshotWriter.passNumber("京都") == WidgetSnapshotWriter.passNumber("京都"))
    }
}
