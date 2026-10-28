import SwiftUI
import Testing
@testable import Later_再度

/// 見た目の確認用:解禁(途中・おわり)と、投稿するか選ぶシートを画像に書き出す(LATER_SNAPSHOT_DIR が設定されている時だけ)。
@MainActor
struct UnlockPostSnapshotTests {
    struct Scene: Sendable, CustomTestStringConvertible {
        let name: String
        let progress: Double?
        var testDescription: String { name }
    }

    @Test(arguments: [Scene(name: "p00", progress: 0), Scene(name: "p30", progress: 0.3), Scene(name: "p55", progress: 0.55), Scene(name: "p70", progress: 0.7), Scene(name: "p100", progress: 1), Scene(name: "choose", progress: nil)])
    func render(_ scene: Scene) throws {
        guard let dir = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"].map({ URL(fileURLWithPath: $0) }) else { return }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { context in
            let colors = [UIColor(red: 0.95, green: 0.6, blue: 0.35, alpha: 1).cgColor, UIColor(red: 0.25, green: 0.3, blue: 0.6, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 300, y: 400), options: [])
        }
        let view = UnlockPostView(
            image: image,
            capturedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            groups: [ProfileShareGroup(name: "よいしょー", otherMemberCount: 4)],
            showsMondo: true,
            playsUnlock: scene.progress != nil,
            haptics: ExposureHaptics(),
            onDecide: { _ in },
            onFinished: { _ in },
            frozenProgress: scene.progress
        )
        .frame(width: 390, height: 844)
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let output = try #require(renderer.uiImage)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try #require(output.pngData()).write(to: dir.appendingPathComponent("unlock_\(scene.name).png"))
    }
}
