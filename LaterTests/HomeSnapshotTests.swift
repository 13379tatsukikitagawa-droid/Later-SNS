import SwiftUI
import Testing
@testable import Later_再度

/// 見た目の確認用:6つの状態のHomeを、390×844で画像に書き出す(LATER_SNAPSHOT_DIR が設定されている時だけ)。
/// 実行例:TEST_RUNNER_LATER_SNAPSHOT_DIR=/tmp/snaps xcodebuild test -only-testing:LaterTests ...
@MainActor
struct HomeSnapshotTests {
    static var outputDirectory: URL? {
        ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"].map { URL(fileURLWithPath: $0) }
    }

    static func date(_ dayOffset: Int, _ hour: Int, _ minute: Int) -> Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: Date()))!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    /// Home(と月)を、指定の状態・起動アニメーションの時刻で描く。
    static func renderHome(state: HomeState, content: HomeDevelopCard.Content, now: Date, light: YesterdayLight, launch: LaunchFrame = .finished,
                           size: CGSize = CGSize(width: 390, height: 844), typeSize: DynamicTypeSize = .large) -> UIImage? {
        let hold = HoldGaugeModel()
        let haptics = ExposureHaptics()
        let mode: HomeMoon.Mode = {
            switch state.moonPlan(yesterday: light) {
            case .locked(let t, let s): return .dim(title: t, subtitle: s)
            case .shoot: return .tap(title: "今日を撮る", subtitle: "タップ", tone: .warm)
            case .decide: return .tap(title: "昨日の1枚を選ぶ", subtitle: "タップ", tone: .decide)
            case .open: return .hold
            case .review: return .tap(title: "昨日をもう一度見る", subtitle: "タップ", tone: .cool)
            }
        }()
        let view = ZStack {
            HomeView(
                state: state, now: now, light: light, developContent: content, developTexture: nil,
                tones: DevelopProgress.defaultTones, openedTones: DevelopProgress.defaultTones,
                groupSummaries: [], canCreateGroup: true, isCovered: false, holdModel: hold,
                avatarImage: nil, avatarSeed: UUID(uuidString: "6C1F2D2E-8E2B-4B57-9A8A-1F6C2B3D4E5F"),
                showsAvatarBadge: false, onOpenProfile: {}, onDevelopTap: {}, onSelectGroup: { _ in }, onCreateGroup: {},
                launch: launch
            )
            HomeMoon(mode: mode, screenSize: size, holdModel: hold, haptics: haptics, textOpacity: 1, isInteractive: false, onTap: {}, onHoldComplete: {},
                     launchGlowOpacity: launch.moonGlowOpacity, launchGlowScale: launch.moonGlowScale)
                .position(MoonLayout.center(in: size))
                .offset(y: launch.moonOffset)
                .opacity(launch.moonOpacity)
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: 40)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: size.width, height: size.height)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        .environment(\.dynamicTypeSize, typeSize)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.uiImage
    }

    /// 上部(ロゴ・消灯まで・プロフィール):幅402 / 375 / 320、文字サイズ最大
    @Test(arguments: ["w402", "w375", "w320", "w320_ax5", "night_w375"].map(Scene.init))
    func renderHeader(_ scene: Scene) throws {
        guard let dir = Self.outputDirectory else { return }
        let width: CGFloat = scene.name.contains("402") ? 402 : scene.name.contains("375") ? 375 : 320
        let night = scene.name.hasPrefix("night")
        let image = try #require(Self.renderHome(
            state: night ? .night : .ready(shotAt: Self.date(0, 9, 8)),
            content: night ? .rest : .developing(capturedAt: Self.date(0, 9, 8), isNight: false),
            now: night ? Self.date(0, 6, 6) : Self.date(0, 9, 7),
            light: .count(3),
            size: CGSize(width: width, height: 700),
            typeSize: scene.name.hasSuffix("ax5") ? .accessibility5 : .large
        ))
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try #require(image.pngData()).write(to: dir.appendingPathComponent("header_\(scene.name).png"))
    }

    struct Scene: Sendable, CustomTestStringConvertible {
        let name: String
        var testDescription: String { name }
    }

    @Test(arguments: ["night", "rest", "dawn", "ready", "opened", "first"].map(Scene.init))
    func render(_ scene: Scene) throws {
        guard let dir = Self.outputDirectory else { return }
        let shot = Self.date(0, 9, 8)
        let (state, content, now, light): (HomeState, HomeDevelopCard.Content, Date, YesterdayLight) = {
            switch scene.name {
            case "night": return (.night, .developing(capturedAt: Self.date(-1, 20, 10), isNight: true), Self.date(0, 6, 40), .count(128))
            case "rest": return (.rest, .rest, Self.date(0, 6, 40), .count(128))
            case "dawn": return (.dawn, .developed(capturedAt: Self.date(-1, 18, 11)), Self.date(0, 9, 6), .count(128))
            case "ready": return (.ready(shotAt: shot), .developing(capturedAt: shot, isNight: false), Self.date(0, 14, 20), .count(128))
            case "opened": return (.opened(shotAt: shot), .developing(capturedAt: shot, isNight: false), Self.date(0, 14, 20), .count(128))
            default: return (.first, .first, Self.date(0, 12, 0), .count(0))
            }
        }()
        let image = try #require(Self.renderHome(state: state, content: content, now: now, light: light))
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try #require(image.pngData()).write(to: dir.appendingPathComponent("home_\(scene.name).png"))
    }

    @Test(arguments: [false, true])
    func renderDevelopSheet(_ developed: Bool) throws {
        guard let dir = Self.outputDirectory else { return }
        let captured = developed ? Self.date(-1, 9, 8) : Self.date(0, 9, 8)
        let view = DevelopSheet(capturedAt: captured, isDeveloped: developed, now: developed ? Self.date(0, 9, 30) : Self.date(0, 16, 50),
                                texture: nil, haptics: ExposureHaptics(), playsEntrance: false)
            .frame(width: 390, height: 744)
            .background(LinearGradient(colors: [Color(hex: "1B1B1F"), Color(hex: "0C0C0E")], startPoint: .top, endPoint: .bottom))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try #require(image.pngData()).write(to: dir.appendingPathComponent("develop_sheet_\(developed ? "ready" : "developing").png"))
    }
}
