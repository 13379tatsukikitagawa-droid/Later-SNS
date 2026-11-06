import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// 見た目の確認用:今日のホーム + 下へつづく層(LATER_SNAPSHOT_DIR が設定されている時だけ)。
/// ScrollView は ImageRenderer で描けないので、窓にのせて、スクロールしながら撮る。
@MainActor
struct HomeLayerSnapshotTests {
    private static let size = CGSize(width: 402, height: 874)

    private func at(dayOffset: Int, hour: Int) -> Date {
        let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: Calendar.current.startOfDay(for: Date()))!
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    private func photo(_ hue: CGFloat) -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { ctx in
            UIColor(hue: hue, saturation: 0.55, brightness: 0.85, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
            UIColor(hue: hue + 0.1, saturation: 0.7, brightness: 0.6, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 240, width: 300, height: 160))
        }.jpegData(compressionQuality: 0.8)!
    }

    private func data(open: Bool, first: Bool = false) -> HomeLayerData {
        let names = ["あお", "みどり", "そら", "はる", "ゆき"]
        var data = HomeLayerData()
        data.windowKey = "w"
        data.me = HomeFriend(id: "me", name: "わたし", avatarData: nil, seed: UUID(), hasShot: open, city: nil, mosaicTiny: nil, mosaicKey: "me", tag: nil, knockOff: false, isMe: true, groupIDs: [])
        if !first {
            data.friends = names.enumerated().map { i, n in
                HomeFriend(id: "f\(i)", name: n, avatarData: nil, seed: UUID(), hasShot: i % 2 == 0, city: "渋谷区", mosaicTiny: nil, mosaicKey: "f\(i)", tag: "夕焼け", knockOff: false, isMe: false, groupIDs: [])
            }
            data.yesterday = (0..<4).map { i in
                HomeYesterdayCard(id: "c\(i)", groupID: UUID(), groupRecordName: "g", photoRecordName: "p\(i)", authorName: names[i], mosaicTiny: nil, mosaicKey: "c\(i)", tag: ["夕焼け", "コーヒー", "帰り道", "空"][i], captureDate: at(dayOffset: -1, hour: 15), imageData: open ? photo(CGFloat(i) * 0.2) : nil)
            }
        }
        data.words = ["夕焼け", "コーヒー", "帰り道", "空", "ねこ", "雨", "散歩", "朝ごはん", "電車", "友だち"]
        data.film = (0..<7).map { ago in
            let kind: HomeFilmDay.Kind = first ? (ago == 0 ? .empty : .rest) : (ago == 0 ? (open ? .developing : .empty) : (ago == 4 ? .rest : (ago == 1 && !open ? .developing : .photo(photo(CGFloat(ago) * 0.13)))))
            return HomeFilmDay(key: "d\(ago)", ago: ago, date: Calendar.current.date(byAdding: .day, value: -ago, to: Date())!, kind: kind)
        }
        return data
    }

    private func home(state: HomeState, content: HomeDevelopCard.Content, data: HomeLayerData, now: Date) -> some View {
        HomeView(
            state: state, now: now, light: .count(12840), developContent: content, developTexture: nil,
            shotsToday: [HomeState.dawn, .first, .rest].contains(state) ? 0 : 1,
            tones: DevelopProgress.defaultTones, openedTones: DevelopProgress.defaultTones,
            groupSummaries: [], canCreateGroup: true, isCovered: false, holdModel: HoldGaugeModel(),
            avatarImage: nil, avatarSeed: UUID(), showsAvatarBadge: false,
            onOpenProfile: {}, onDevelopTap: {}, onSelectGroup: { _ in }, onCreateGroup: {},
            layerData: data
        )
    }

    private func shoot<V: View>(_ view: V, name: String, offsets: [CGFloat], dir: URL) async throws {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(origin: .zero, size: Self.size)
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        try await Task.sleep(for: .seconds(1.0))
        for offset in offsets {
            if let scroll = Self.findScroll(in: host.view) {
                let maxY = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
                scroll.setContentOffset(CGPoint(x: 0, y: min(offset, maxY) - scroll.adjustedContentInset.top), animated: false)
            }
            try await Task.sleep(for: .seconds(1.2))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            try image.pngData()?.write(to: dir.appendingPathComponent("\(name)-\(Int(offset)).png"))
        }
        window.isHidden = true
    }

    /// いちばん大きい縦のスクロール(ホームの器)
    private static func findScroll(in view: UIView) -> UIScrollView? {
        var best: UIScrollView?
        func walk(_ v: UIView) {
            if let s = v as? UIScrollView, s.bounds.width >= size.width - 1 {
                if best == nil || s.contentSize.height > best!.contentSize.height { best = s }
            }
            v.subviews.forEach(walk)
        }
        walk(view)
        return best
    }

    @Test func 層のスナップショット() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"] else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let now = at(dayOffset: 0, hour: 14)
        let offsets: [CGFloat] = [0, 160, 760, 1360, 1960, 9999]

        try await shoot(home(state: .opened(shotAt: now), content: .developing(capturedAt: now, isNight: false), data: data(open: true), now: now)
            .environment(\.palette, .night), name: "opened", offsets: offsets, dir: dir)
        try await shoot(home(state: .dawn, content: .developed(capturedAt: at(dayOffset: -1, hour: 18)), data: data(open: false), now: now)
            .environment(\.palette, .day), name: "dawn", offsets: offsets, dir: dir)
        try await shoot(home(state: .night, content: .developing(capturedAt: at(dayOffset: -1, hour: 20), isNight: true), data: data(open: false), now: at(dayOffset: 0, hour: 6))
            .environment(\.palette, .night), name: "night", offsets: [0, 760, 9999], dir: dir)
        try await shoot(home(state: .first, content: .first, data: data(open: false, first: true), now: now)
            .environment(\.palette, .day), name: "first", offsets: [0, 700, 9999], dir: dir)
    }
}
