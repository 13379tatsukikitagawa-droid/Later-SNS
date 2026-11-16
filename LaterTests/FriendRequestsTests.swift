import Testing
import Foundation
@testable import Later_再度

/// P07:友だちの 申請 → 承認(純粋な 決まり)
struct FriendRequestsTests {
    private func req(_ from: String, _ to: String, _ t: Double) -> FriendRequests.Request {
        .init(id: "req_\(from)_\(to)", fromUserID: from, toUserID: to, fromName: from, createdAt: Date(timeIntervalSince1970: t))
    }

    @Test func 返事まえの申請だけ() {
        let reqs = [req("a", "me", 1), req("b", "me", 3), req("c", "me", 2), req("x", "other", 9)]
        let resp = [FriendRequests.Response(requesterID: "c", responderID: "me", decision: "declined")]
        let p = FriendRequests.pending(requests: reqs, myResponses: resp, me: "me")
        #expect(p.map(\.fromUserID) == ["b", "a"])   // 新しい 順・返事ずみ(c)と 他人あて(x)は 出ない
    }

    @Test func 同じ相手の重複は1つ() {
        let reqs = [req("a", "me", 1), req("a", "me", 5)]
        #expect(FriendRequests.pending(requests: reqs, myResponses: [], me: "me").count == 1)
    }

    @Test func 承認された相手につなぐ() {
        let mine = [req("me", "a", 1), req("me", "b", 2)]
        let resp = [FriendRequests.Response(requesterID: "me", responderID: "a", decision: "accepted"),
                    FriendRequests.Response(requesterID: "me", responderID: "b", decision: "declined")]
        #expect(FriendRequests.acceptedTargets(myRequests: mine, responses: resp, me: "me") == ["a"])
    }
}

/// P07:1対1 チャットの 決まり
struct DirectMessagesTests {
    @Test func 部屋のIDは順番によらない() {
        #expect(DirectMessages.conversationID("b", "a") == DirectMessages.conversationID("a", "b"))
        #expect(DirectMessages.conversationID("a", "b") != DirectMessages.conversationID("a", "c"))
    }

    @Test func 送れる文字() {
        #expect(DirectMessages.clean("  やあ ") == "やあ")
        #expect(DirectMessages.clean("   ") == nil)
        #expect(DirectMessages.clean(String(repeating: "あ", count: 501)) == nil)
    }

    @Test func 古い順() {
        let a = DirectMessages.Message(id: "1", senderID: "x", text: "a", createdAt: Date(timeIntervalSince1970: 5))
        let b = DirectMessages.Message(id: "2", senderID: "y", text: "b", createdAt: Date(timeIntervalSince1970: 1))
        #expect(DirectMessages.ordered([a, b]).map(\.id) == ["2", "1"])
    }
}
