import Foundation
import Testing
import UIKit
@testable import Later_再度

/// グループ作成(名前・色・人数の上限・顔の画像)と、入るときの判定
@MainActor
struct GroupCreateJoinTests {
    @Test func 同じ名前なら必ず同じ色_グレーは自動で選ばない() {
        for name in ["よいしょー", "帰り道の4人", "朝活ぐみ", "a", "しずかな会"] {
            let a = GroupPalette.index(forName: name)
            #expect(a == GroupPalette.index(forName: name))
            #expect((0..<GroupPalette.automaticCount).contains(a))
        }
        // 文字が変われば、色も変わりうる(5種に散らばる)
        let spread = Set((0..<60).map { GroupPalette.index(forName: "グループ\($0)") })
        #expect(spread.count == GroupPalette.automaticCount)
    }

    @Test func 名前は12文字まで_改行と絵文字はとりのぞく() {
        #expect(GroupNameRules.sanitizeInput("あいうえおかきくけこさしすせそ") == "あいうえおかきくけこさし")
        #expect(GroupNameRules.sanitizeInput("帰り道\nの4人") == "帰り道の4人")
        #expect(GroupNameRules.sanitizeInput("朝活🌅ぐみ👍🏽") == "朝活ぐみ")
        #expect(GroupNameRules.finalize("  しずかな会  ") == "しずかな会")
        #expect(GroupNameRules.initial(of: " よいしょー") == "よ")
        #expect(GroupNameRules.finalize("   ").isEmpty)
    }

    @Test(arguments: [3, 4, 6, 8, 9])
    func 人数の上限は4から8_点の数とずれない(limit: Int) {
        let clamped = GroupPalette.clampLimit(limit)
        #expect(GroupMembershipPolicy.memberLimitRange.contains(clamped))
        #expect(GroupRingMath.dots(memberCount: clamped, posted: 1).total == clamped)
        let summary = GroupSummary(id: UUID(), name: "a", iconData: nil, auraIndex: 0, memberCount: clamped, postedYesterday: 0, memberLimit: clamped)
        #expect(summary.isFull)
        #expect(summary.openSeats == 0)
    }

    struct JoinCase: CustomTestStringConvertible, Sendable {
        let label: String
        let member: Bool
        let count: Int
        let limit: Int
        let groups: Int
        let expiresIn: TimeInterval?
        let revoked: Bool
        let expected: JoinCheck
        var testDescription: String { label }
    }

    @Test(arguments: [
        JoinCase(label: "入れる", member: false, count: 4, limit: 8, groups: 3, expiresIn: 3600, revoked: false, expected: .ok),
        JoinCase(label: "満員", member: false, count: 8, limit: 8, groups: 3, expiresIn: 3600, revoked: false, expected: .full),
        JoinCase(label: "上限4の満員", member: false, count: 4, limit: 4, groups: 3, expiresIn: 3600, revoked: false, expected: .full),
        JoinCase(label: "期限切れ", member: false, count: 4, limit: 8, groups: 3, expiresIn: -1, revoked: false, expected: .unavailable),
        JoinCase(label: "止めた", member: false, count: 4, limit: 8, groups: 3, expiresIn: 3600, revoked: true, expected: .unavailable),
        JoinCase(label: "すでに入っている", member: true, count: 8, limit: 8, groups: 10, expiresIn: -1, revoked: true, expected: .alreadyMember),
        JoinCase(label: "10個まで", member: false, count: 4, limit: 8, groups: 10, expiresIn: 3600, revoked: false, expected: .tooManyGroups),
    ])
    func 入れるかどうか(_ c: JoinCase) {
        let now = Date()
        let result = JoinCheck.evaluate(
            isAlreadyMember: c.member, memberCount: c.count, memberLimit: c.limit, joinedGroupCount: c.groups,
            expiresAt: c.expiresIn.map { now.addingTimeInterval($0) }, revoked: c.revoked, now: now
        )
        #expect(result == c.expected)
    }

    @Test func 同時に最後の1席に入ったら_あとの人が抜ける() {
        #expect(!JoinCheck.isOverCapacity(acceptedCount: 8, memberLimit: 8))
        #expect(JoinCheck.isOverCapacity(acceptedCount: 9, memberLimit: 8))
        #expect(JoinCheck.isOverCapacity(acceptedCount: 5, memberLimit: 4))
    }

    @Test func 席は次に光る点() {
        // 4人 → 5人目は、8点の輪の6時の位置(下)
        let offset = GroupCircle.seatOffset(index: 4, memberLimit: 8, diameter: 264)
        #expect(abs(offset.width) < 0.01)
        #expect(offset.height > 100)
    }

    // MARK: 顔の画像

    /// 左半分が赤・右半分が青の 800×600 の画像
    private func sample() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600), format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }()).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 600))
            UIColor.blue.setFill(); ctx.fill(CGRect(x: 400, y: 0, width: 400, height: 600))
        }
    }

    @Test func 切り出しは中央の正方形_はみ出さない() {
        let size = CGSize(width: 800, height: 600)
        #expect(FaceImageRenderer.cropRect(imageSize: size, scale: 1, offset: .zero) == CGRect(x: 100, y: 0, width: 600, height: 600))
        let zoomed = FaceImageRenderer.cropRect(imageSize: size, scale: 2, offset: CGSize(width: 1, height: 1))
        #expect(zoomed.width == 300)
        #expect(zoomed.minX >= 0 && zoomed.maxX <= 800 && zoomed.minY >= 0 && zoomed.maxY <= 600)
        #expect(FaceImageRenderer.clampOffset(CGSize(width: 0.4, height: 0), scale: 1) == .zero)
    }

    private func center(_ image: UIImage) -> (r: CGFloat, b: CGFloat) {
        let cg = image.cgImage!
        var pixel = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: -CGFloat(cg.width) / 2 + 0.5, y: -CGFloat(cg.height) / 2 + 0.5, width: CGFloat(cg.width), height: CGFloat(cg.height)))
        return (CGFloat(pixel[0]) / 255, CGFloat(pixel[2]) / 255)
    }

    @Test func プレビューと保存が同じになる() throws {
        let image = sample()
        // 右へずらして(=左の赤い側が中央にくる)、大きくして、色あいをつける
        let offset = CGSize(width: 0.2, height: 0)
        for tone in FaceTone.allCases {
            let preview = try #require(FaceImageRenderer.render(image, scale: 1.8, offset: offset, tone: tone, side: 512))
            let saved = try #require(FaceImageRenderer.render(image, scale: 1.8, offset: offset, tone: tone))
            #expect(saved.size.width == FaceImageRenderer.outputSide)
            let a = center(preview), b = center(saved)
            #expect(abs(a.r - b.r) < 0.03 && abs(a.b - b.b) < 0.03, "\(tone)")
        }
        let plain = try #require(FaceImageRenderer.render(image, scale: 1.8, offset: offset, tone: .original))
        #expect(center(plain).r > 0.8)
        let mono = try #require(FaceImageRenderer.render(image, scale: 1.8, offset: offset, tone: .mono))
        let m = center(mono)
        #expect(abs(m.r - m.b) < 0.05)
    }
}
