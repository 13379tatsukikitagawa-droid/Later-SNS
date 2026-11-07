import CloudKit
import Foundation
import Testing
import UIKit
@testable import Later_再度

/// グループの列(点の計算・要約)と、招待(トークン・リンク)
@MainActor
struct GroupInviteTests {
    struct DotCase: CustomTestStringConvertible, Sendable {
        let members: Int
        let posted: Int
        let total: Int
        let lit: Int
        var testDescription: String { "メンバー\(members)・投稿\(posted)" }
    }

    @Test(arguments: [
        DotCase(members: 1, posted: 0, total: 1, lit: 0),
        DotCase(members: 1, posted: 1, total: 1, lit: 1),
        DotCase(members: 8, posted: 3, total: 8, lit: 3),
        DotCase(members: 8, posted: 8, total: 8, lit: 8),
        DotCase(members: 12, posted: 12, total: 12, lit: 12),
        DotCase(members: 12, posted: 0, total: 12, lit: 0),
        // 13人:12個に丸めて、光る割合をそろえる
        DotCase(members: 13, posted: 6, total: 12, lit: 6),
        DotCase(members: 13, posted: 13, total: 12, lit: 12),
        // 1人でも投稿していれば1つは光る・全員でなければ1つは消えたまま
        DotCase(members: 13, posted: 1, total: 12, lit: 1),
        DotCase(members: 13, posted: 12, total: 12, lit: 11),
        // 抜けた人の投稿で、メンバー数をこえても光りすぎない
        DotCase(members: 3, posted: 5, total: 3, lit: 3),
    ])
    func dots(_ c: DotCase) {
        let result = GroupRingMath.dots(memberCount: c.members, posted: c.posted)
        #expect(result.total == c.total)
        #expect(result.lit == c.lit)
    }

    private func summary(members: Int, posted: Int) -> GroupSummary {
        GroupSummary(id: UUID(), name: "よいしょー", iconData: nil, auraIndex: 0, memberCount: members, postedYesterday: posted)
    }

    @Test func 全員投稿_0人_満員_空きあり() {
        let all = summary(members: 3, posted: 3)
        #expect(all.allPosted)
        #expect(all.countText == "3 / 3")
        let none = summary(members: 8, posted: 0)
        #expect(!none.allPosted)
        #expect(none.isFull)
        #expect(none.openSeats == 0)
        let open = summary(members: 4, posted: 2)
        #expect(!open.isFull)
        #expect(open.openSeats == 4)
        #expect(open.spokenSummary == "よいしょー、メンバー4人のうち2人が昨日投稿しました")
    }

    @Test func オーラの色はとなりと続かない() {
        let ids = (0..<40).map { _ in UUID() }
        let auras = GroupRingMath.auraIndices(for: ids)
        for i in 1..<auras.count { #expect(auras[i] != auras[i - 1]) }
        // 同じIDなら同じ色(起動しなおしても変わらない)
        #expect(GroupRingMath.stableHash(ids[0]) == GroupRingMath.stableHash(ids[0]))
    }

    private let shareURL = URL(string: "https://www.icloud.com/share/0abcDEF123#Later")!

    @Test func 招待リンクは以前の_later_join() {
        let link = InviteConfig.joinLink(shareURL: shareURL)
        #expect(link.scheme == "later")
        #expect(link.host == "join")
        #expect(InviteConfig.shareURL(from: link) == shareURL)
        // 素の CKShare URL も受けとれる。ちがう URL は受けとらない
        #expect(InviteConfig.shareURL(from: shareURL) == shareURL)
        #expect(InviteConfig.shareURL(from: URL(string: "https://example.com/share/x")!) == nil)
    }

    @Test func 招待リンクはエンコードなしで作り_あり_なしの両方を読める() {
        let link = InviteConfig.joinLink(shareURL: shareURL)
        #expect(link.absoluteString == "later://join?shareUrl=\(shareURL.absoluteString)")
        let plain = URL(string: "later://join?shareUrl=https://www.icloud.com/share/048QUuOQglIyxDdrKDRVre3wg")!
        #expect(InviteConfig.shareURL(from: plain)?.absoluteString == "https://www.icloud.com/share/048QUuOQglIyxDdrKDRVre3wg")
        let encoded = URL(string: "later://join?shareUrl=https%3A%2F%2Fwww.icloud.com%2Fshare%2F048QUuOQglIyxDdrKDRVre3wg")!
        #expect(InviteConfig.shareURL(from: encoded)?.absoluteString == "https://www.icloud.com/share/048QUuOQglIyxDdrKDRVre3wg")
        #expect(InviteConfig.shareURL(from: URL(string: "later://join?x=1")!) == nil)
    }

    @Test func スキーマの失敗の文からフィールドを取り出す() {
        let text = "Cannot create new field 'faceStyle' in production schema for record type 'LaterGroup'"
        #expect(CloudDiagnostics.fieldName(in: text) == "faceStyle")
        #expect(CloudDiagnostics.recordType(in: text) == "LaterGroup")
        let error = CKError(.invalidArguments, userInfo: ["ServerErrorDescription": text])
        #expect(CloudDiagnostics.isSchemaError(error))
        #expect(CloudDiagnostics.describe(error).contains("field=faceStyle"))
        #expect(!CloudDiagnostics.isSchemaError(CKError(.networkUnavailable)))
    }

    @Test func 作成の失敗の理由を日本語で短く出す() {
        #expect(GroupCreateFailureText.reason(for: GroupSharingError.notSignedIn) == GroupCreateFailureText.notSignedIn)
        #expect(GroupCreateFailureText.reason(for: CKError(.notAuthenticated)) == GroupCreateFailureText.notSignedIn)
        let offline = GroupSharingError.zoneCreationFailed(underlying: CKError(.networkUnavailable))
        #expect(GroupCreateFailureText.reason(for: offline) == GroupCreateFailureText.network)
        // 部分的な失敗:巻き添え(22)ではなく、中身の 本当の原因で えらぶ
        let schema = CKError(.invalidArguments, userInfo: ["ServerErrorDescription": "Cannot create new field 'knockOff' in production schema"])
        let profileID = CKRecord.ID(recordName: "profile_x")
        let groupID = CKRecord.ID(recordName: "group_x")
        let partial = CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [profileID: schema, groupID: CKError(.batchRequestFailed)]])
        #expect(CloudDiagnostics.isSchemaError(partial))
        #expect(GroupCreateFailureText.reason(for: GroupSharingError.groupCreationFailed(underlying: partial)) == GroupCreateFailureText.schema)
        #expect(GroupCreateFailureText.reason(for: GroupSharingError.groupCreationFailed(underlying: CKError(.batchRequestFailed))) == GroupCreateFailureText.generic)
    }

    @Test func 合言葉の形() {
        #expect(GroupInviteService.isPassphrase("hikari-2741"))
        #expect(!GroupInviteService.isPassphrase("ABC234"))
        #expect(!GroupInviteService.isPassphrase("hikari-27"))
    }

    @Test func 共有の文面にあおる言葉を入れない() {
        let text = InviteConfig.shareMessage(groupName: "よいしょー", url: InviteConfig.joinLink(shareURL: shareURL))
        #expect(text == "「よいしょー」に招待されました。Later で、昨日をひらきあいましょう。\nlater://join?shareUrl=\(shareURL.absoluteString)")
        for word in ["早く", "いまだけ", "今だけ", "急いで"] { #expect(!text.contains(word)) }
    }

    @Test func QRは読める大きさで作れる() throws {
        let image = try #require(InviteQR.image(for: InviteConfig.joinLink(shareURL: shareURL)))
        #expect(image.size.width >= 300)
    }
}
