import SwiftUI
import Testing
@testable import Later_再度

/// 見た目の確認用:Profileの全画面ビューア(v4)を画像に書き出す(LATER_SNAPSHOT_DIR が設定されている時だけ)。
@MainActor
struct ProfileViewerSnapshotTests {
    private struct Host: View {
        let shots: [WeekDayPoint]
        let initialID: String
        @Namespace private var namespace

        var body: some View {
            DayFullScreenViewer(
                shots: shots, initialID: initialID, namespace: namespace, haptics: ExposureHaptics(),
                isMondoSettingOn: true, imageFor: { _ in Self.sampleImage }, onDelete: { _ in }, onDismiss: {},
                startsWithChrome: true
            )
        }

        static let sampleImage: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { context in
            let colors = [UIColor(red: 0.95, green: 0.6, blue: 0.35, alpha: 1).cgColor, UIColor(red: 0.25, green: 0.3, blue: 0.6, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 300, y: 400), options: [])
        }
    }

    @Test(arguments: [844.0, 667.0])
    func render(height: Double) throws {
        guard let dir = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"].map({ URL(fileURLWithPath: $0) }) else { return }
        let calendar = Calendar.current
        let now = Date()
        let group = ProfileShareGroup(name: "よいしょー", otherMemberCount: 4)
        let sources = [-5, -3, -2, -1, 0].map { offset -> ProfileShot.Source in
            let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))!
            let captured = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day)!
            return ProfileShot.Source(
                dayKey: ExposureDayStore.dayKey(for: captured), captureDate: min(captured, now),
                colorHex: ["FFB48A", "9A6CF0", "6AA8FF", "7BE0C8", "FFD0A0"][offset + 5 > 4 ? 4 : max(0, offset + 5)],
                locationName: "杉並区", tags: ["空", "散歩", "カフェ"], groups: [group], isOnMondo: offset == -1
            )
        }
        let shots = ProfileShot.visibleShots(from: sources, now: now)
        let lastOpened = shots.last { $0.opened }
        let current = try #require(lastOpened)
        let size = CGSize(width: 390, height: height)
        let view = Host(shots: shots, initialID: current.id)
            .frame(width: size.width, height: size.height)
            .background(Color.black)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try #require(image.pngData()).write(to: dir.appendingPathComponent("profile_viewer_\(Int(height)).png"))
    }
}
