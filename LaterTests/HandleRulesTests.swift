import Testing
import Foundation
@testable import Later_再度

struct HandleRulesTests {
    @Test func 正規化() {
        #expect(HandleRules.normalize("Ｙui_0612") == "yui_0612")
        #expect(HandleRules.normalize("ゆい!") == "")
    }
    @Test func きまり() {
        #expect(HandleRules.validate("yui_0612") == nil)
        #expect(HandleRules.validate("ab") == .tooShort)
        #expect(HandleRules.validate(String(repeating: "a", count: 21)) == .tooLong)
        #expect(HandleRules.validate(".abc") == .dotEdge)
        #expect(HandleRules.validate("abc.") == .dotEdge)
        #expect(HandleRules.validate("a..b") == .doubleDot)
        #expect(HandleRules.validate("123456") == .allDigits)
        #expect(HandleRules.validate("admin") == .reserved)
        #expect(HandleRules.validate("lattag_official") == .reserved)
    }
    @Test func 候補は規則を満たす() {
        let s = HandleRules.suggestions(fromName: "ゆい", now: Date(timeIntervalSince1970: 1_763_424_000))
        #expect(!s.isEmpty)
        #expect(s.allSatisfy { HandleRules.validate($0) == nil })
        #expect(s[0].hasPrefix("yui"))
    }
    @Test func 十四日() {
        let now = Date()
        #expect(HandleRules.daysUntilChange(lastChange: nil, now: now) == 0)
        #expect(HandleRules.daysUntilChange(lastChange: now.addingTimeInterval(-5 * 86400), now: now) == 9)
        #expect(HandleRules.daysUntilChange(lastChange: now.addingTimeInterval(-20 * 86400), now: now) == 0)
    }
}

struct DirectoryNameKeyTests {
    @Test func カタカナはひらがなと同じ() {
        #expect(DirectoryNameKey.make("ユイ") == DirectoryNameKey.make("ゆい"))
        #expect(DirectoryNameKey.make("Yui Chan") == "yuichan")
    }
}

struct QRHandleParseTests {
    @Test func lattagURLからIDを読む() {
        #expect(FriendQRScanView.handle(from: URL(string: "https://lattag.app/u/yui_0612")!) == "yui_0612")
        #expect(FriendQRScanView.handle(from: URL(string: "https://example.com/u/yui_0612")!) == nil)
        #expect(FriendQRScanView.handle(from: URL(string: "https://lattag.app/x/yui_0612")!) == nil)
        #expect(FriendQRScanView.handle(from: URL(string: "https://lattag.app/u/admin")!) == nil)
    }
}
