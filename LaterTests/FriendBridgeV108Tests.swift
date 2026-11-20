import Foundation
import Testing
@testable import Later_再度

struct FriendBridgeV108Tests {
    private func req(_ from: String, _ to: String) -> FriendRequests.Request {
        .init(id: "req_\(from)_\(to)", fromUserID: from, toUserID: to, fromName: from, createdAt: Date())
    }
    @Test func crossedOnlyWhenBothSent() {
        let incoming = [req("b", "a"), req("c", "a")]
        let mine = [req("a", "b")]
        let r = FriendRequestBridgeV108.crossedTargets(myRequests: mine, incoming: incoming, me: "a")
        #expect(r.map(\.fromUserID) == ["b"])
        #expect(FriendRequestBridgeV108.crossedTargets(myRequests: [], incoming: incoming, me: "a").isEmpty)
    }
    @Test func bridgeSubscriptionIDs() {
        #expect(FriendRequestBridgeV108.isBridgeNotification(subscriptionID: "friendreq-in-x"))
        #expect(FriendRequestBridgeV108.isBridgeNotification(subscriptionID: "friendreq-ok-x"))
        #expect(!FriendRequestBridgeV108.isBridgeNotification(subscriptionID: "photocaptured-private-x"))
        #expect(!FriendRequestBridgeV108.isBridgeNotification(subscriptionID: nil))
    }
}
