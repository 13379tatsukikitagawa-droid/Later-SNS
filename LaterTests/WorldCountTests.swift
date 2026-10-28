import SwiftUI
import Testing
@testable import Later_再度

@MainActor
struct WorldCountTests {
    @Test func fontSizeByCharacters() {
        #expect(HomeLightOrb.formatted(12840) == "12,840")
        #expect(HomeLightOrb.numberFontSize("128") == 58)
        #expect(HomeLightOrb.numberFontSize("1,284") == 52)
        #expect(HomeLightOrb.numberFontSize("12,840") == 46)
        #expect(HomeLightOrb.numberFontSize("7") == 58)
    }

    @Test(arguments: [128, 12840, 7, 0, -1])
    func export(_ n: Int) throws {
        guard let dir = HomeSnapshotTests.outputDirectory else { return }
        let light: YesterdayLight = n < 0 ? .loading : .count(n)
        let shot = HomeSnapshotTests.date(0, 9, 8)
        let image = try #require(HomeSnapshotTests.renderHome(
            state: .opened(shotAt: shot), content: .developing(capturedAt: shot, isNight: false),
            now: HomeSnapshotTests.date(0, 14, 20), light: light))
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try #require(image.pngData()).write(to: dir.appendingPathComponent("world_\(n).png"))
    }
}
