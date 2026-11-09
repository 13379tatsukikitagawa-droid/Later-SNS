import CloudKit
import Foundation
import Testing
@testable import Later_再度

/// 【プライバシー】「投稿する」を押すまで、グループに 届けるのは 撮った人・撮った時刻・グループの印だけ
@MainActor
struct PostPrivacyTests {
    private let zone = CKRecordZone.ID(zoneName: "z", ownerName: CKCurrentUserDefaultName)
    private var groupID: CKRecord.ID { CKRecord.ID(recordName: "g", zoneID: zone) }
    private static let withheld = ["tags", "caption", "locationName", "groupNameCache", "approxLatitude", "approxLongitude",
                                   "durationSeconds", "mosaicTiny", "image", "musicTitle", "musicArtist", "musicArtworkURL", "musicLink", "musicService"]

    private func photo(posted: Bool) -> LaterPhoto {
        let photo = LaterPhoto(imageData: Data([1, 2, 3]), captureDate: Date(), unlockDate: Date(), owner: nil)
        photo.isPosted = posted
        photo.tags = ["エモい"]
        photo.caption = "ひとこと"
        photo.locationName = "どこか"
        photo.groupNameCache = "グループ"
        photo.approxLatitude = 35.6
        photo.approxLongitude = 139.7
        photo.mosaicTiny = Data([9])
        photo.authorCloudKitUserRecordName = "_me"
        photo.applyMusic(MusicPick(title: "曲", artist: "だれか", artworkURL: nil, link: "https://music.apple.com/x", service: .apple))
        return photo
    }

    @Test func 投稿の前は_撮った人と時刻と印だけ() throws {
        let record = try photo(posted: false).toCKRecord(existing: nil, zoneID: zone, groupRecordID: groupID)
        for key in Self.withheld { #expect(!record.allKeys().contains(key), "\(key) が 投稿の前に 入っている") }
        #expect(record["authorCloudKitUserRecordName"] as? String == "_me")
        #expect(record["captureDate"] as? Date != nil)
        #expect(record["isPosted"] as? Bool == false)
        #expect(record["groupIDString"] != nil || record["group"] != nil)
    }

    @Test func 投稿したら_ぜんぶ送る() throws {
        let record = try photo(posted: true).toCKRecord(existing: nil, zoneID: zone, groupRecordID: groupID)
        #expect(record["tags"] as? [String] == ["エモい"])
        #expect(record["locationName"] as? String == "どこか")
        #expect(record["approxLatitude"] as? Double == 35.6)
        #expect(record["musicTitle"] as? String == "曲")
        #expect(record["image"] != nil)
    }

    @Test func 投稿の前のレコードを読んでも_自分の端末の値は消えない() throws {
        let mine = photo(posted: false)
        let record = try mine.toCKRecord(existing: nil, zoneID: zone, groupRecordID: groupID)
        try mine.apply(from: record)
        #expect(mine.tags == ["エモい"])
        #expect(mine.locationName == "どこか")
        #expect(mine.musicTitle == "曲")
        #expect(mine.approxLatitude == 35.6)
    }
}
