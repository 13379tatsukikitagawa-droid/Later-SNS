import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import Later_再度

@MainActor
struct MondoTests {
    // MARK: - 入口

    /// 9時の切りかわりのあとは、撮っていなくても入れる。夜(9時前)で撮らなかった .rest だけ入れない。
    @Test func canEnterAfterNineEvenWithoutShot() {
        let shot = Date()
        for state in [HomeState.opened(shotAt: shot), .ready(shotAt: shot), .deciding(shotAt: shot), .more(shotAt: shot, remaining: 2), .night, .first, .dawn] {
            #expect(state.mondoGate == .enter, "\(state) は入れる")
        }
        guard case .locked(let title, let message) = HomeState.rest.mondoGate else {
            Issue.record("rest は入れない"); return
        }
        #expect(title == "9時に、Mondo がひらく")
        #expect(message == "みんなの写真が、見られます")
    }

    // MARK: - ことばの群れ

    @Test func bubbleSizes() {
        #expect(MondoAggregator.bubbleFontSize(count: 34, maxCount: 34) == 24)
        #expect(MondoAggregator.bubbleFontSize(count: 17, maxCount: 34) == 19)
        #expect(MondoAggregator.bubbleFontSize(count: 1, maxCount: 34) == 14)
    }

    @Test func bubbleOrderIsStablePerDayAndNotRanked() {
        let tags = (0..<6).map { (tag: "t\($0)", count: 60 - $0 * 10) }
        let a = MondoAggregator.bubbleOrder(tags, dayKey: "2026-10-02").map(\.tag)
        let b = MondoAggregator.bubbleOrder(tags, dayKey: "2026-10-02").map(\.tag)
        #expect(a == b)
        // 何日か見て、少なくとも1日は多い順と違う並びになる(ランキングに見えない)
        let days = (1...9).map { "2026-10-0\($0)" }
        #expect(days.contains { MondoAggregator.bubbleOrder(tags, dayKey: $0).map(\.tag) != tags.map(\.tag) })
        #expect(Set(days.map { MondoAggregator.bubbleOrder(tags, dayKey: $0).map(\.tag) }).count > 1)
    }

    // MARK: - 集計(昨日の窓だけ・見えなくしたもの・ブロック)

    private func entry(_ id: String, person: String, day: String, tags: [String], country: String = "JP") -> MondoEntry {
        MondoEntry(id: id, mondoID: person, name: person, place: MondoPlace(countryCode: country, countryName: country, region: nil), tags: tags, dayKey: day, toneHex: nil, isMine: false)
    }

    @Test func summarizeOnlyYesterday() {
        let entries = [
            entry("a", person: "u1", day: "2026-10-02", tags: ["コーヒー", "空"]),
            entry("b", person: "u2", day: "2026-10-02", tags: ["コーヒー"], country: "IT"),
            entry("c", person: "u3", day: "2026-10-03", tags: ["コーヒー"]), // 今日:混ぜない
            entry("d", person: "u4", day: "2026-10-02", tags: ["夜"]),       // 報告して見えなくした
            entry("e", person: "u5", day: "2026-10-02", tags: ["夜"]),       // ブロック
        ]
        let s = MondoAggregator.summarize(entries, dayKey: "2026-10-02", hidden: ["d"], blocked: ["u5"])
        #expect(s.lightCount == 2)
        #expect(s.countryCount == 2)
        #expect(s.topTags.map(\.tag) == ["コーヒー", "空"])
        #expect(Set(s.entries.map(\.id)) == ["a", "b"])
    }

    @Test func onlyAllowedTagsArePublished() {
        #expect(MondoTags.publishable(["coffee", "#空", "わたしの秘密", "空", "夜", "散歩"]) == ["コーヒー", "空", "夜"])
    }

    // MARK: - Exif・GPS を落とす

    @Test func sanitizedImageHasNoMetadata() throws {
        // GPS・Exif・機種の入った JPEG を作る
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 48))
        let cg = try #require(renderer.image { ctx in UIColor.orange.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 48)) }.cgImage)
        let data = NSMutableData()
        let dest = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        let props: [CFString: Any] = [
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 35.68, kCGImagePropertyGPSLongitude: 139.76, kCGImagePropertyGPSLatitudeRef: "N", kCGImagePropertyGPSLongitudeRef: "E"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:10:02 09:12:00", kCGImagePropertyExifLensModel: "iPhone"],
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Apple", kCGImagePropertyTIFFModel: "iPhone 17"],
        ]
        CGImageDestinationAddImage(dest, cg, props as CFDictionary)
        #expect(CGImageDestinationFinalize(dest))
        #expect(MondoImageSanitizer.hasMetadata(data as Data))

        let clean = try #require(MondoImageSanitizer.sanitizedJPEG(from: data as Data, maxDimension: 32))
        #expect(!MondoImageSanitizer.hasMetadata(clean))
        let size = try #require(UIImage(data: clean)).size
        #expect(max(size.width, size.height) <= 32)
    }

    @Test func blockKeysRoundTrip() {
        let blocked = [BlockedUser(blockedCloudKitUserRecordName: MondoService.blockKey("abc")), BlockedUser(blockedCloudKitUserRecordName: "_icloudUser")]
        #expect(MondoService.blockedMondoIDs(blocked) == ["abc"])
    }

    // MARK: - 見た目の書き出し(LATER_SNAPSHOT_DIR がある時だけ)

    @Test func exportScreens() throws {
        guard let dir = HomeSnapshotTests.outputDirectory else { return }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let tones = ["C98A5A", "5A7FA8", "D9B26A", "8A6AA8", "6AA88A", "A85A5A"]
        let places = [("JP", "日本", "東京都"), ("IT", "Italia", "Lazio"), ("FR", "France", "Île-de-France"), ("US", "United States", "California")]
        let tagSets = [["コーヒー", "朝ごはん"], ["空"], ["コーヒー", "散歩"], ["夜"], ["空", "カフェ"], ["コーヒー"]]
        let entries = (0..<4).map { i in
            MondoEntry(id: "r\(i)", mondoID: UUID().uuidString, name: ["みお", "Luca", "Chloé", "Sam"][i % 4],
                       place: MondoPlace(countryCode: places[i % 4].0, countryName: places[i % 4].1, region: places[i % 4].2),
                       tags: tagSets[i % 6], dayKey: "2026-10-02", toneHex: tones[i % 6], isMine: false)
        }
        let summary = MondoAggregator.summarize(entries, dayKey: "2026-10-02", hidden: [], blocked: [])
        let top = MondoTopView(dayKey: "2026-10-02", load: .ready(summary), onBack: {}, onSettings: {}, onTag: { _ in }, onOpen: { _, _, _ in }, onRetry: {})
            .scrollContent
            .frame(width: 390)
            .background(Color.black)
            .environment(\.colorScheme, .dark)
        let r1 = ImageRenderer(content: top)
        r1.scale = 1
        try #require(r1.uiImage?.pngData()).write(to: dir.appendingPathComponent("mondo_top.png"))

        for (i, state) in [MondoTopView.State.notReady, .failed].enumerated() {
            let v = MondoTopView(dayKey: "2026-10-02", load: state, onBack: {}, onSettings: {}, onTag: { _ in }, onOpen: { _, _, _ in }, onRetry: {})
                .scrollContent.frame(width: 390).background(Color.black)
            let r = ImageRenderer(content: v)
            r.scale = 2
            try #require(r.uiImage?.pngData()).write(to: dir.appendingPathComponent("mondo_state\(i).png"))
        }

        let welcome = MondoWelcomeView(haptics: ExposureHaptics(), onEnter: {})
            .frame(width: 390, height: 844)
        let r2 = ImageRenderer(content: welcome)
        r2.scale = 2
        try #require(r2.uiImage?.pngData()).write(to: dir.appendingPathComponent("mondo_welcome.png"))
    }
}
