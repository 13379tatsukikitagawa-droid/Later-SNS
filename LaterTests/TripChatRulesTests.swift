import Testing
import Foundation
@testable import Later_再度

/// v129 2章:Trip の チャット。きょう 撮った 写真は 送れない(あした 9:00 の 解禁を 守る)
@MainActor
struct TripChatRulesTests {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Tokyo")!; return c }
    private func at(_ d: Int, _ h: Int, _ m: Int = 0) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h, minute: m))! }

    @Test func todaysPhotoCannotBeSent() {
        // 11/21 の 12:00 に 撮った → 11/21 の 夜 ・ 11/22 の 8:59 まで 送れない
        let taken = at(21, 12)
        #expect(!TripChatRules.canSendPhoto(takenAt: taken, now: at(21, 12, 1), calendar: cal))
        #expect(!TripChatRules.canSendPhoto(takenAt: taken, now: at(21, 23, 59), calendar: cal))
        #expect(!TripChatRules.canSendPhoto(takenAt: taken, now: at(22, 8, 59), calendar: cal))
        #expect(TripChatRules.canSendPhoto(takenAt: taken, now: at(22, 9, 0), calendar: cal))
    }

    @Test func earlyMorningPhotoOpensAtNineSameDay() {
        // 0:00〜9:00 に 撮った 写真は その日の 9:00 に ひらく
        let taken = at(21, 7)
        #expect(!TripChatRules.canSendPhoto(takenAt: taken, now: at(21, 8, 59), calendar: cal))
        #expect(TripChatRules.canSendPhoto(takenAt: taken, now: at(21, 9, 0), calendar: cal))
    }

    @Test func sendableListHasOnlyDevelopedPhotosNewestFirst() {
        let now = at(21, 12)
        let photos = [("today", at(21, 10)), ("old", at(19, 10)), ("yesterday", at(20, 18)), ("todayEarly", at(21, 8))]
        let list = TripChatRules.sendable(photos, takenAt: { $0.1 }, now: now, calendar: cal).map(\.0)
        #expect(list == ["todayEarly", "yesterday", "old"])   // 8時に 撮った 物は 9:00 に ひらいて いる
        #expect(!list.contains("today"))
    }

    @Test func eightStickers() {
        #expect(TripChatRules.stickers.count == 8)
        #expect(Set(TripChatRules.stickers.map(\.id)).count == 8)
        #expect(TripChatRules.art("star-sun") != nil)
        #expect(TripChatRules.art("それな") == nil)   // 古い ハッシュタグ型は 別の 見た目
    }

    private func msg(_ id: String, _ who: String, _ d: Int, _ h: Int, _ m: Int, kind: ChatMessage.Kind = .text) -> ChatMessage {
        ChatMessage(id: id, groupID: UUID(), senderId: who, kind: kind, text: id, stickerId: nil, photoRecordName: nil, sentAt: at(d, h, m), expiresAt: at(d + 7, h, m))
    }

    @Test func dayDividersAndClusters() {
        let ms = [msg("a", "x", 20, 10, 0), msg("b", "x", 20, 10, 2), msg("c", "y", 20, 10, 3), msg("d", "y", 21, 8, 0), msg("e", "y", 21, 8, 1)]
        let items = TripChatRules.items(ms, me: "y", tripStart: at(20, 0), calendar: cal)
        // day, a, b, c, day, d, e
        #expect(items.count == 7)
        if case .day(_, let label) = items[0] { #expect(label.hasPrefix("DAY 1 ・ 11/20")) } else { Issue.record("day 1") }
        if case .day(_, let label) = items[4] { #expect(label.hasPrefix("DAY 2 ・ 11/21")) } else { Issue.record("day 2") }
        if case .bubble(_, let first, let last, let mine) = items[1] { #expect(first && !last && !mine) } else { Issue.record("a") }
        if case .bubble(_, let first, let last, _) = items[2] { #expect(!first && last) } else { Issue.record("b") }
        if case .bubble(_, let first, let last, let mine) = items[3] { #expect(first && last && mine) } else { Issue.record("c") }
        // 日が かわったら 同じ 人でも 別の かたまり
        if case .bubble(_, let first, let last, _) = items[5] { #expect(first && !last) } else { Issue.record("d") }
        if case .bubble(_, let first, let last, _) = items[6] { #expect(!first && last) } else { Issue.record("e") }
    }

    @Test func systemMessageBreaksCluster() {
        let ms = [msg("a", "x", 20, 10, 0), msg("s", "x", 20, 10, 1, kind: .system), msg("b", "x", 20, 10, 2)]
        let items = TripChatRules.items(ms, me: nil, tripStart: at(20, 0), calendar: cal)
        #expect(items.count == 4)
        if case .system = items[2] {} else { Issue.record("system") }
        if case .bubble(_, _, let last, _) = items[1] { #expect(last) } else { Issue.record("a") }
        if case .bubble(_, let first, _, _) = items[3] { #expect(first) } else { Issue.record("b") }
    }

    @Test func emptyTextCannotBeSent() {
        #expect(!TripChatRules.canSendText("  \n "))
        #expect(TripChatRules.canSendText("はよ 撮って"))
    }
}

/// v129 D:通知
@MainActor
struct TripChatPushRulesTests {
    private func push(_ id: UUID) -> [AnyHashable: Any] { ["kind": "trip_chat", "tripId": id.uuidString.lowercased()] }

    @Test func groupIDFromPush() {
        let g = UUID()
        #expect(TripChatPushRules.groupID(fromPush: push(g)) == g)
        #expect(TripChatPushRules.groupID(fromPush: ["kind": "friend_request"]) == nil)
        #expect(TripChatPushRules.groupID(fromPush: ["kind": "trip_chat", "tripId": "bad"]) == nil)
    }

    @Test func openRoomIsNotPresented() {
        let g = UUID(), other = UUID()
        #expect(!TripChatPushRules.shouldPresentInForeground(userInfo: push(g), openRoom: g))
        #expect(TripChatPushRules.shouldPresentInForeground(userInfo: push(g), openRoom: other))
        #expect(TripChatPushRules.shouldPresentInForeground(userInfo: push(g), openRoom: nil))
        // ほかの 通知(友だち申請 など)は いつも 出す
        #expect(TripChatPushRules.shouldPresentInForeground(userInfo: ["kind": "friend_request"], openRoom: g))
        #expect(TripChatPushRules.shouldPresentInForeground(userInfo: [:], openRoom: g))
    }

    @Test func localNotificationOnlyWhenWorkerIsOff() {
        #expect(TripChatPushRules.shouldPostLocal(useWorker: false, isOpenRoom: false, muted: false))
        #expect(!TripChatPushRules.shouldPostLocal(useWorker: true, isOpenRoom: false, muted: false))   // 二重に しない
        #expect(!TripChatPushRules.shouldPostLocal(useWorker: false, isOpenRoom: true, muted: false))
        #expect(!TripChatPushRules.shouldPostLocal(useWorker: false, isOpenRoom: false, muted: true))
    }
}
