import SwiftUI
import Testing
@testable import Later_再度

/// 見た目の確認用:作成・招待・エラーの「円」(LATER_SNAPSHOT_DIR が設定されている時だけ)
@MainActor
struct GroupCircleSnapshotTests {
    @Test func circles() throws {
        guard let dir = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"].map({ URL(fileURLWithPath: $0) }) else { return }
        let view = VStack(spacing: 24) {
            HStack(spacing: 20) {
                GroupCircle(initial: "帰", colorIndex: GroupPalette.index(forName: "帰り道の4人"), memberLimit: 6, litCount: 1, diameter: 160, rotates: false)
                GroupCircle(initial: "よ", colorIndex: 1, memberLimit: 8, litCount: 4, diameter: 160, rotates: false, seatIndex: 4)
            }
            HStack(spacing: 20) {
                GroupCircle(initial: "よ", colorIndex: 1, memberLimit: 8, litCount: 5, diameter: 160, rotates: false, arrival: 0.2)
                GroupCircle(initial: "し", colorIndex: 4, memberLimit: 4, litCount: 4, diameter: 160, rotates: false, faded: true)
            }
            HStack(spacing: 12) {
                ForEach(0..<GroupPalette.count, id: \.self) { i in
                    GroupCircle(initial: "あ", colorIndex: i, memberLimit: 8, litCount: 3, diameter: 52, rotates: false)
                }
            }
        }
        .padding(20)
        .frame(width: 390, height: 520)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try #require(image.pngData()).write(to: dir.appendingPathComponent("group_circles.png"))
    }
}
