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

struct AppLinksV108Tests {
    @Test func parsesFriendAndTrip() {
        #expect(AppLinks.parse(URL(string: "https://later-app-f2606.firebaseapp.com/u/yui_0612?openExternalBrowser=1")!) == .friend(handle: "yui_0612"))
        #expect(AppLinks.parse(URL(string: "https://later-app-f2606.firebaseapp.com/t/maple24")!) == .trip(token: "maple24"))
        #expect(AppLinks.parse(URL(string: "https://later-social.later-social.workers.dev/t/Kx7Qm2pLx9?openExternalBrowser=1")!) == .trip(token: "Kx7Qm2pLx9"))   // v109 Worker
        #expect(AppLinks.parse(URL(string: "https://lattag.app/t/maple24")!) == nil)   // 持って いない ドメインは 受けない
        #expect(AppLinks.parse(URL(string: "later://u/yui_0612")!) == .friend(handle: "yui_0612"))
        #expect(AppLinks.parse(URL(string: "https://example.com/u/yui_0612")!) == nil)
        #expect(AppLinks.parse(URL(string: "https://later-app-f2606.firebaseapp.com/g/abc")!) == nil)
    }
    @Test func parsesPastedText() {
        #expect(AppLinks.parse(text: "ゆい から\n↓\nhttps://later-app-f2606.firebaseapp.com/u/yui_0612?openExternalBrowser=1\n\nアプリが") == .friend(handle: "yui_0612"))
    }
}

struct ShareTextV108Tests {
    @Test func friendText() {
        let t = ShareTextV108.friend(name: "ゆい", handle: "yui_0612")!
        #expect(t.hasPrefix("ゆい (@yui_0612) から Lattag の 友だち申請です"))
        #expect(!t.contains("アプリが ない 時"))
        #expect(t.contains("https://later-app-f2606.firebaseapp.com/u/yui_0612?openExternalBrowser=1"))
        #expect(!t.contains("later://"))
        #expect(ShareTextV108.friend(name: "ゆい", handle: "") == nil)
    }
    @Test func tripText() {
        let t = ShareTextV108.trip(host: "たつき", name: "大阪", dates: "11/21〜11/23", members: 3, key: "#maple24")
        #expect(t.hasPrefix("『大阪』に 招待されました(たつき から)\n\n↓ タップで ひらく(アプリが ひらきます)"))
        #expect(t.contains("https://later-app-f2606.firebaseapp.com/t/maple24?openExternalBrowser=1"))
        #expect(t.hasSuffix("KEY:#maple24"))
        #expect(ShareTextV108.shortDate("NOV 21") == "11/21")
    }
}
