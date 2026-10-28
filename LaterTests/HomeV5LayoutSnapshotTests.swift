import SwiftUI
import Testing
@testable import Later_再度

/// 見た目の確認用:Home v5 の画面を、3つの画面幅(375 / 402 / 440)で画像に書き出す(LATER_SNAPSHOT_DIR が設定されている時だけ)。
/// 実行例:TEST_RUNNER_LATER_SNAPSHOT_DIR=/tmp/snaps xcodebuild test -only-testing:LaterTests/HomeV5LayoutSnapshotTests ...
@MainActor
struct HomeV5LayoutSnapshotTests {
    struct Device: Sendable, CustomTestStringConvertible {
        let name: String
        let size: CGSize
        var testDescription: String { name }
    }

    static let devices = [
        Device(name: "se_375", size: CGSize(width: 375, height: 667)),
        Device(name: "pro_402", size: CGSize(width: 402, height: 874)),
        Device(name: "promax_440", size: CGSize(width: 440, height: 956)),
    ]

    private func scene(_ kind: String, size: CGSize, typeSize: DynamicTypeSize) -> some View {
        let haptics = ExposureHaptics()
        return ZStack(alignment: .top) {
            V5Backdrop(isAnimating: false)
            if kind == "group" {
                TwoPageSwitcher(firstTitle: "MONDO", secondTitle: "GROUP", showsSecond: true, onSelect: { _ in }) {
                    Color.clear
                } second: {
                    HomeV5GroupPage(sections: [], isActive: false, haptics: haptics, shotEvent: nil, windowKey: "snap",
                                    topInset: 59, canCreate: true, onOpenRoom: { _ in }, onOpenTile: { _, _, _ in },
                                    onCycleLocation: { _ in }, onAdd: {})
                }
            } else {
                TwoPageSwitcher(firstTitle: "MONDO", secondTitle: "GROUP", showsSecond: false, onSelect: { _ in }) {
                    HomeV5MondoPage(phase: .notReady, dayKey: "2026-10-26", isActive: false, topInset: 59, onTick: {}, onSettings: {},
                                    onRetry: {}, onOpenTag: { _, _, _ in }, onOpenAll: { _, _ in })
                } second: {
                    Color.clear
                }
            }
            V5HeaderScrim()
            LaterHeader(home: .yesterday, avatarName: "さ", showsBadge: false)
                .padding(.top, 59)
            if kind == "guide" {
                FirstGuideView(haptics: haptics, onDismiss: {})
            }
        }
        .frame(width: size.width, height: size.height)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        .environment(\.dynamicTypeSize, typeSize)
    }

    @Test(arguments: devices)
    func render(_ device: Device) throws {
        guard let dir = HomeSnapshotTests.outputDirectory else { return }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        HomeV5Signals.shared.isShowingGuide = false
        for (kind, typeSize) in [("mondo", DynamicTypeSize.large), ("group", .large), ("guide", .large), ("mondo_xxxl", .xxxLarge)] {
            HomeV5Signals.shared.isShowingGuide = (kind == "guide")
            defer { HomeV5Signals.shared.isShowingGuide = false }
            let renderer = ImageRenderer(content: scene(kind, size: device.size, typeSize: typeSize))
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            try #require(image.pngData()).write(to: dir.appendingPathComponent("v5_\(kind)_\(device.name).png"))
        }
    }
}
