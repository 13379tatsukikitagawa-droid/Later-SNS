import Testing
import Foundation
@testable import Later_再度

struct InboxRulesV136Tests {
    @Test func badgeCountsRequestsAndTripInvites() {
        #expect(InboxRulesV136.badge(requests: 2, tripInvites: 1) == 3)
        #expect(InboxRulesV136.badge(requests: 0, tripInvites: 0) == 0)
        #expect(InboxRulesV136.badge(requests: -1, tripInvites: 0) == 0)
    }
    @Test func permissionCardFollowsState() {
        #expect(InboxRulesV136.permissionCard(.on) == nil)
        #expect(InboxRulesV136.permissionCard(.unset)?.action == .turnOn)
        #expect(InboxRulesV136.permissionCard(.unset)?.button == "オンにする")
    }
    @Test func deniedPermissionOpensSettings() {
        let c = InboxRulesV136.permissionCard(.off)
        #expect(c?.action == .openSettings)
        #expect(c?.button == "設定をひらく")
    }
    @Test func bucketsTodayAndWeek() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let now = cal.date(from: DateComponents(year: 2026, month: 12, day: 10, hour: 12))!
        func d(_ day: Int, _ h: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: 12, day: day, hour: h))! }
        #expect(InboxRulesV136.bucket(of: d(10, 0), now: now, calendar: cal) == .today)
        #expect(InboxRulesV136.bucket(of: d(9, 23), now: now, calendar: cal) == .week)
        #expect(InboxRulesV136.bucket(of: d(4, 9), now: now, calendar: cal) == .week)
        #expect(InboxRulesV136.bucket(of: d(3, 9), now: now, calendar: cal) == nil)
    }
    @Test func emptyCopyHasThreeLines() {
        #expect(InboxRulesV136.comingLines.count == 3)
        #expect(InboxRulesV136.emptyTitle == "まだ通知はありません")
    }
}
