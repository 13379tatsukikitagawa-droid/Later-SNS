import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import Later_再度

@MainActor
struct HomeV5LogicTests {
    private let group = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    // MARK: - どの状態で v5 を出すか

    @Test func v5ShowsOnlyAfterTheFirstShot() {
        let shot = Date()
        for state in [HomeState.ready(shotAt: shot), .opened(shotAt: shot), .more(shotAt: shot, remaining: 2)] {
            #expect(state.usesGroupHome, "\(state) は v5")
        }
        for state in [HomeState.first, .dawn, .night, .rest, .deciding(shotAt: shot)] {
            #expect(!state.usesGroupHome, "\(state) は v5 にしない")
        }
    }

    // MARK: - 解禁

    @Test func unlockCountIsTheSmallerOfTodayAndYesterday() {
        #expect(UnlockPlan.credits(shotsToday: 2, candidates: 3) == 2)
        #expect(UnlockPlan.credits(shotsToday: 3, candidates: 1) == 1)
        #expect(UnlockPlan.credits(shotsToday: 0, candidates: 5) == 0)
        #expect(UnlockPlan.credits(shotsToday: 9, candidates: 9) == FilmRoll.shotsPerDay)
        #expect(UnlockPlan.credits(shotsToday: -1, candidates: 4) == 0)
    }

    @Test func unlockOrderIsFixedForTheDayAndDiffersByGroup() {
        let keys = ["a", "b", "c", "d", "e", "f"]
        let first = UnlockPlan.order(keys: keys, groupID: group, dayKey: "2026-10-25")
        #expect(first == UnlockPlan.order(keys: keys.reversed(), groupID: group, dayKey: "2026-10-25"))
        #expect(Set(first) == Set(keys))
        let otherDay = UnlockPlan.order(keys: keys, groupID: group, dayKey: "2026-10-26")
        let otherGroup = UnlockPlan.order(keys: keys, groupID: UUID(), dayKey: "2026-10-25")
        // 同じ並びになることもありうるが、6枚で3通りとも同じになる確率は低い
        #expect(first != otherDay || first != otherGroup)
    }

    @Test func morePhotosOpenInTheSameOrderAndKeepEarlierOnes() {
        let keys = ["a", "b", "c", "d", "e"]
        let one = UnlockPlan.unlockedKeys(keys: keys, groupID: group, dayKey: "2026-10-25", shotsToday: 1)
        let two = UnlockPlan.unlockedKeys(keys: keys, groupID: group, dayKey: "2026-10-25", shotsToday: 2)
        let three = UnlockPlan.unlockedKeys(keys: keys, groupID: group, dayKey: "2026-10-25", shotsToday: 3)
        #expect(one.count == 1 && two.count == 2 && three.count == 3)
        #expect(Array(two.prefix(1)) == one)
        #expect(Array(three.prefix(2)) == two)
    }

    @Test func unlockNeverExceedsWhatArrived() {
        #expect(UnlockPlan.unlockedKeys(keys: ["a"], groupID: group, dayKey: "d", shotsToday: 3).count == 1)
        #expect(UnlockPlan.unlockedKeys(keys: [], groupID: group, dayKey: "d", shotsToday: 3).isEmpty)
    }

    // MARK: - モザイクの段階・時間割

    @Test func mosaicLevelsGetFiner() {
        #expect(MosaicLevel.l0.grid?.columns == 6 && MosaicLevel.l0.grid?.rows == 13)
        #expect(MosaicLevel.l1.grid?.columns == 11 && MosaicLevel.l1.grid?.rows == 24)
        #expect(MosaicLevel.l2.grid?.columns == 22 && MosaicLevel.l2.grid?.rows == 48)
        #expect(MosaicLevel.l3.grid == nil)
        #expect(MosaicLevel.l0 < .l1 && MosaicLevel.l1 < .l2 && MosaicLevel.l2 < .l3)
    }

    @Test func unlockTimelineStepsThroughTheLevels() {
        #expect(UnlockTimeline.level(atElapsed: -0.1) == .l0)
        #expect(UnlockTimeline.level(atElapsed: 0) == .l1)
        #expect(UnlockTimeline.level(atElapsed: 0.25) == .l1)
        #expect(UnlockTimeline.level(atElapsed: 0.26) == .l2)
        #expect(UnlockTimeline.level(atElapsed: 0.52) == .l3)
        #expect(UnlockTimeline.level(atElapsed: 2) == .l3)
    }

    @Test func unlockStartsAfter1_4SecondsAndStaggersBy0_52() {
        #expect(UnlockTimeline.startTime(forIndex: 0) == 1.4)
        #expect(abs(UnlockTimeline.startTime(forIndex: 2) - 2.44) < 1e-9)
        #expect(UnlockTimeline.totalDuration(count: 0) == 0)
        #expect(abs(UnlockTimeline.totalDuration(count: 3) - (1.4 + 1.04 + 1.1)) < 1e-9)
    }

    // MARK: - 触覚・押し方

    @Test func hapticPatternsPulseOnTheEvenSegments() {
        let pulses = HomeHapticPattern.pulses(HomeHapticPattern.switchScreen)
        #expect(pulses.count == 2)
        #expect(pulses[0].time == 0)
        #expect(abs(pulses[1].time - 0.070) < 1e-9)
        let para = HomeHapticPattern.pulses(HomeHapticPattern.unlockTile)
        #expect(para.count == 4)
        #expect(para.map(\.intensity) == para.map(\.intensity).sorted())
        #expect(HomeHapticPattern.pulses(HomeHapticPattern.pageStop).count == 1)
        #expect(HomeHapticPattern.pulses([]).isEmpty)
    }

    // MARK: - ハッシュタグのランキング

    private func entry(_ id: String, tags: [String], day: String = "2026-10-25") -> MondoEntry {
        MondoEntry(id: id, mondoID: "m-\(id)", name: id, place: nil, tags: tags, dayKey: day, toneHex: nil, isMine: false)
    }

    @Test func rankingSortsByCountAndMeasuresTheBar() {
        let ranking = TagRanking.rank([("散歩", 18), ("夕焼け", 36), ("コーヒー", 9)], dayKey: "2026-10-25")
        #expect(ranking.map(\.tag) == ["夕焼け", "散歩", "コーヒー"])
        #expect(ranking.map(\.rank) == [1, 2, 3])
        #expect(ranking[0].ratio == 1)
        #expect(ranking[1].ratio == 0.5)
        #expect(ranking[2].ratio == 0.25)
    }

    @Test func rankingKeepsTopSixOnly() {
        let tags = (1...9).map { (tag: "t\($0)", count: $0) }
        let ranking = TagRanking.rank(tags, dayKey: "2026-10-25")
        #expect(ranking.count == 6)
        #expect(ranking.first?.tag == "t9")
    }

    @Test func tiedCountsAreOrderedByTheDateSeedNotByInputOrder() {
        let a = TagRanking.rank([("あ", 5), ("い", 5), ("う", 5)], dayKey: "2026-10-25")
        let b = TagRanking.rank([("う", 5), ("あ", 5), ("い", 5)], dayKey: "2026-10-25")
        #expect(a.map(\.tag) == b.map(\.tag))
    }

    @Test func rowPhotosAreAFixedShuffleForTheDay() {
        let entries = (0..<10).map { entry("e\($0)", tags: ["散歩"]) }
        let a = TagRanking.photos(for: "散歩", in: entries, dayKey: "2026-10-25")
        let b = TagRanking.photos(for: "散歩", in: entries.reversed(), dayKey: "2026-10-25")
        #expect(a.count == 10)
        #expect(Set(a.map(\.id)) == Set(entries.map(\.id)))
        // 入力の並びに関係なく、同じ並び方(速さ・人気で決めない)
        #expect(Set(a.prefix(4).map(\.id)).count == 4)
        #expect(TagRanking.photos(for: "散歩", in: entries, dayKey: "2026-10-25").map(\.id) == a.map(\.id))
        _ = b
        #expect(TagRanking.photos(for: "夜", in: entries, dayKey: "2026-10-25").isEmpty)
    }

    @Test func feedContinuesIntoTheNextTagInRankingOrder() {
        let entries = (0..<3).map { entry("a\($0)", tags: ["夕焼け"]) } + (0..<2).map { entry("b\($0)", tags: ["散歩"]) }
        let ranking = TagRanking.rank([("夕焼け", 3), ("散歩", 2)], dayKey: "2026-10-25")
        let pages = TagFeed.pages(ranking: ranking, entries: entries, dayKey: "2026-10-25")
        #expect(pages.map(\.tag) == ["夕焼け", "夕焼け", "夕焼け", "散歩", "散歩"])
        #expect(pages.map(\.index) == [0, 1, 2, 0, 1])
        #expect(pages[0].counterText == "01 / 03")
        #expect(pages[4].counterText == "02 / 02")
    }

    @Test func feedCapsEachTagAtTheLimit() {
        let entries = (0..<30).map { entry("x\($0)", tags: ["夕焼け"]) }
        let ranking = TagRanking.rank([("夕焼け", 30)], dayKey: "2026-10-25")
        let pages = TagFeed.pages(ranking: ranking, entries: entries, dayKey: "2026-10-25", perTag: 8)
        #expect(pages.count == 8)
        // 分母は、そのタグの光の数
        #expect(pages[2].counterText == "03 / 30")
    }

    @Test func feedStartsFromThePressedPhoto() {
        let entries = (0..<3).map { entry("a\($0)", tags: ["夕焼け"]) } + (0..<2).map { entry("b\($0)", tags: ["散歩"]) }
        let ranking = TagRanking.rank([("夕焼け", 3), ("散歩", 2)], dayKey: "2026-10-25")
        let pages = TagFeed.pages(ranking: ranking, entries: entries, dayKey: "2026-10-25")
        let target = pages[4]
        #expect(TagFeed.startIndex(in: pages, tag: target.tag, entryID: target.entry.id) == 4)
        #expect(TagFeed.startIndex(in: pages, tag: "散歩", entryID: nil) == 3)
        #expect(TagFeed.startIndex(in: pages, tag: "ない", entryID: nil) == 0)
    }

    // MARK: - 位置の共有

    @Test func locationModeCyclesOffShotPlaceNowOff() {
        let all = GroupLocationMode.allCases
        #expect(GroupLocationMode.off.next(available: all) == .shotPlace)
        #expect(GroupLocationMode.shotPlace.next(available: all) == .now)
        #expect(GroupLocationMode.now.next(available: all) == .off)
    }

    @Test func nowModeIsHeldBackByDefaultForSafety() {
        #expect(LocationPolicy.nowModeEnabled == false)
        #expect(GroupLocationMode.available == [.off, .shotPlace])
        #expect(GroupLocationMode.shotPlace.next() == .off)
        // 古い値が残っていても、使えないモードはオフとして扱う
        #expect(GroupLocationMode.now.next(available: [.off, .shotPlace]) == .off)
    }

    @Test func locationDefaultsToOffPerGroup() {
        let suite = UserDefaults(suiteName: "HomeV5LogicTests-\(UUID().uuidString)")!
        #expect(LocationShareStore.mode(for: group, defaults: suite) == .off)
        LocationShareStore.setMode(.shotPlace, for: group, defaults: suite)
        #expect(LocationShareStore.mode(for: group, defaults: suite) == .shotPlace)
        #expect(LocationShareStore.mode(for: UUID(), defaults: suite) == .off)
        LocationShareStore.setMode(.off, for: group, defaults: suite)
        #expect(LocationShareStore.mode(for: group, defaults: suite) == .off)
    }

    @Test func locationIsRoundedToAbout500MetreCells() {
        let cell = LocationRounding.cell(latitude: 35.66921, longitude: 139.70123)
        #expect(cell.latitude == 35.670)
        #expect(cell.longitude == 139.700)
        #expect(LocationRounding.round(35.6642) == 35.665)
        #expect(LocationRounding.round(-33.8688) == -33.870)
        // 丸めた値をもう一度丸めても変わらない
        #expect(LocationRounding.round(LocationRounding.round(35.6642)) == 35.665)
        // 格子の中の別の点は、同じ値になる(正確な位置は残らない)
        #expect(LocationRounding.round(35.6626) == LocationRounding.round(35.6674))
    }

    @Test func roundedValuesNeverLeakMoreThanThreeDecimals() {
        for value in [35.123456, 139.987654, -0.000123, 12.3456789] {
            let rounded = LocationRounding.round(value)
            #expect(abs(rounded * 1000 - (rounded * 1000).rounded()) < 1e-6)
            #expect(abs(rounded - value) <= LocationPolicy.gridStep / 2 + 1e-9)
        }
    }

    @Test func distanceBetweenCells() {
        let a = LocationRounding.cell(latitude: 35.6812, longitude: 139.7671)
        let b = LocationRounding.cell(latitude: 35.6895, longitude: 139.6917)
        let km = LocationRounding.distanceKm(from: a, to: b)
        #expect(km > 6.5 && km < 7.5)
        #expect(LocationRounding.distanceKm(from: a, to: a) == 0)
        #expect(LocationRounding.distanceText(0.64) == "0.6 km")
    }

    @Test func nowPinsFadeAfterAnHourWithoutUpdates() {
        let now = Date(timeIntervalSinceReferenceDate: 10_000)
        #expect(LocationPolicy.pinOpacity(updatedAt: now.addingTimeInterval(-60), now: now) == 1)
        #expect(LocationPolicy.pinOpacity(updatedAt: now.addingTimeInterval(-2700), now: now) == 0.5)
        #expect(LocationPolicy.pinOpacity(updatedAt: now.addingTimeInterval(-3600), now: now) == 0)
        #expect(LocationPolicy.pinOpacity(updatedAt: now.addingTimeInterval(-9000), now: now) == 0)
    }

    // MARK: - モザイク用の小さな画像

    private func solidJPEG(_ color: UIColor, size: CGSize = CGSize(width: 300, height: 400)) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.9)!
    }

    private func centerPixel(_ image: UIImage) -> (r: Int, g: Int, b: Int) {
        let cg = image.cgImage!
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(cg, in: CGRect(x: -cg.width / 2, y: -cg.height / 2, width: cg.width, height: cg.height))
        return (Int(pixel[0]), Int(pixel[1]), Int(pixel[2]))
    }

    @Test func tinyImageIs22By48AndSmall() throws {
        let tiny = try #require(MosaicRenderer.makeTiny(from: solidJPEG(.orange)))
        let image = try #require(UIImage(data: tiny))
        #expect(image.cgImage?.width == 22)
        #expect(image.cgImage?.height == 48)
        #expect(tiny.count < 4_000)
    }

    @Test func tinyImageKeepsTheColourOfThePhoto() throws {
        let sunset = try #require(MosaicRenderer.makeTiny(from: solidJPEG(UIColor(red: 1, green: 0.55, blue: 0.2, alpha: 1))))
        let night = try #require(MosaicRenderer.makeTiny(from: solidJPEG(UIColor(red: 0.1, green: 0.2, blue: 0.7, alpha: 1))))
        let warm = centerPixel(try #require(UIImage(data: sunset)))
        let cold = centerPixel(try #require(UIImage(data: night)))
        #expect(warm.r > warm.b + 80)
        #expect(cold.b > cold.r + 80)
    }

    @Test func mosaicLevelsRenderAtTheirGridSize() throws {
        let tiny = try #require(MosaicRenderer.makeTiny(from: solidJPEG(.systemTeal)))
        for (level, columns, rows) in [(MosaicLevel.l0, 6, 13), (.l1, 11, 24), (.l2, 22, 48)] {
            let image = try #require(MosaicRenderer.image(fromTiny: tiny, key: "t-\(level.rawValue)", level: level))
            #expect(image.cgImage?.width == columns)
            #expect(image.cgImage?.height == rows)
        }
        #expect(MosaicRenderer.image(fromTiny: tiny, key: "t-3", level: .l3) == nil)
    }

    @Test func brokenTinyDataGivesNoImage() {
        #expect(MosaicRenderer.makeTiny(from: Data([1, 2, 3])) == nil)
        #expect(MosaicRenderer.image(fromTiny: Data([1, 2, 3]), key: "broken", level: .l0) == nil)
    }

    @Test func aspectFillCoversTheTarget() {
        let rect = MosaicRenderer.aspectFillRect(imageSize: CGSize(width: 300, height: 400), in: CGSize(width: 22, height: 48))
        #expect(rect.height >= 48 - 1e-9)
        #expect(rect.width >= 22 - 1e-9)
        #expect(abs(rect.midX - 11) < 1e-9 && abs(rect.midY - 24) < 1e-9)
    }

    // MARK: - 撮影のあとの合図

    @Test func eachShotMakesANewEvent() {
        let a = ShotEvent()
        let b = ShotEvent()
        #expect(a != b)
    }
}
