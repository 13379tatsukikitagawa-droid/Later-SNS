import CloudKit
import Foundation
import Testing
@testable import Later_再度

/// v22 L-4:今日の 1曲(リンクの 読みとり・CloudKit に 書く 項目)
@MainActor
struct MusicPickTests {
    @Test func リンクを見つける() {
        // Spotify は 使わない(リンクとして 見つけない)
        #expect(MusicLink.find(in: "きいて https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC?si=abc") == nil)
        let apple = MusicLink.find(in: "https://music.apple.com/jp/album/name/1440857781?i=1440857904")
        #expect(apple?.service == .apple)
        #expect(apple.flatMap { MusicLink.appleSongID(from: $0.url) } == "1440857904")
        #expect(MusicLink.appleSongID(from: URL(string: "https://music.apple.com/jp/song/name/1440857904")!) == "1440857904")
        #expect(MusicLink.find(in: "https://example.com/track/1") == nil)
        #expect(MusicLink.find(in: "") == nil)
    }

    @Test func 曲なしの写真は_曲の項目を1つも書かない() throws {
        let zone = CKRecordZone.ID(zoneName: "z", ownerName: CKCurrentUserDefaultName)
        let photo = LaterPhoto(imageData: Data(), captureDate: Date(), unlockDate: Date(), owner: nil)
        let record = try photo.toCKRecord(existing: nil, zoneID: zone, groupRecordID: CKRecord.ID(recordName: "g", zoneID: zone))
        for key in ["musicTitle", "musicArtist", "musicArtworkURL", "musicLink", "musicService"] {
            #expect(!record.allKeys().contains(key), "\(key) が 書かれている")
        }
    }

    @Test func 曲つきの写真は_5つの項目を書く() throws {
        let zone = CKRecordZone.ID(zoneName: "z", ownerName: CKCurrentUserDefaultName)
        let photo = LaterPhoto(imageData: Data(), captureDate: Date(), unlockDate: Date(), owner: nil)
        photo.isPosted = true   // 曲は 投稿したときに 送る
        photo.applyMusic(MusicPick(title: "放課後", artist: "だれか", artworkURL: "https://example.com/a.jpg",
                                   link: "https://music.apple.com/jp/song/x/1", service: .apple))
        let record = try photo.toCKRecord(existing: nil, zoneID: zone, groupRecordID: CKRecord.ID(recordName: "g", zoneID: zone))
        #expect(record["musicTitle"] as? String == "放課後")
        #expect(record["musicArtist"] as? String == "だれか")
        #expect(record["musicArtworkURL"] as? String == "https://example.com/a.jpg")
        #expect(record["musicLink"] as? String == "https://music.apple.com/jp/song/x/1")
        #expect(record["musicService"] as? String == "apple")

        // 読みもどし
        let copy = LaterPhoto(imageData: Data(), captureDate: Date(), unlockDate: Date(), owner: nil)
        try copy.apply(from: record)
        #expect(copy.musicTitle == "放課後")
        #expect(copy.musicService == "apple")
    }

    @Test func 下書きは日ごとに1曲() {
        MusicDraft.save(nil)
        #expect(MusicDraft.load() == nil)
        let pick = MusicPick(title: "t", artist: "a", artworkURL: nil, link: nil, service: .apple)
        MusicDraft.save(pick)
        #expect(MusicDraft.load() == pick)
        MusicDraft.save(nil)
        #expect(MusicDraft.load() == nil)
    }
}
