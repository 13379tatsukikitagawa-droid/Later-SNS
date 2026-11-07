import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// v22 L:タグ画面(いま人気の 2列・ことば)と、見た目の確認(LATER_SNAPSHOT_DIR があるときだけ)
@MainActor
struct TagScreenL22Tests {
    @Test func いま人気は2列で_同じことばを重ねない() {
        let rows = TagWords.rows(world: ["空", "新しいことば", "#エモい"], shuffle: { $0 })
        #expect(rows.first.first == "空")
        #expect(rows.first.contains("新しいことば"))
        #expect(Set(rows.first).count == rows.first.count)
        #expect(Set(rows.first).isDisjoint(with: rows.second))
        #expect(Set(rows.second) == Set(TagWords.row2))
        // 1列目と 2列目の ことばは、ぜんぶ 出る
        #expect(Set(TagWords.row1).isSubset(of: Set(rows.first)))
    }

    @Test func ことばは_やさしい形だけ() {
        for word in TagWords.row1 + TagWords.row2 {
            #expect(!word.hasPrefix("#"))
            #expect(TagRules.clean(word) == word)
            #expect(!ShootTagRules.isForbidden(word))
        }
        #expect(!TagWords.all.contains("きもい"))
        #expect(TagDictionary.display("エモい") == "#エモい")
        #expect(TagDictionary.display("ねむい") == "#ねむい")
    }

    @Test func ならびは毎回すこし変わる() {
        let orders = Set((0..<8).map { _ in TagWords.rows().first.prefix(3).joined() })
        #expect(orders.count > 1)
    }

    @Test func 見た目() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"] else { return }
        let only = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_ONLY"] ?? "all"
        guard only == "all" || only == "tag" else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (label, size) in [("se", CGSize(width: 375, height: 667)), ("pro", CGSize(width: 390, height: 844)), ("promax", CGSize(width: 440, height: 956))] {
            for (state, tags) in [("empty", [String]()), ("two", ["エモい", "放課後"])] {
                let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
                let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
                window.frame = CGRect(origin: .zero, size: size)
                window.windowLevel = .alert + 1
                window.rootViewController = UIHostingController(rootView: TagSnapshotHost(tags: tags))
                window.makeKeyAndVisible()
                try await Task.sleep(for: .seconds(2.4))
                let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                try image.pngData()?.write(to: dir.appendingPathComponent("tag-\(state)-\(label).png"))
                window.isHidden = true
            }
        }
    }
}

private struct TagSnapshotHost: View {
    @State var tags: [String]
    var body: some View {
        TagScreen(left: 3, haptics: ExposureHaptics(), tags: $tags, place: nil)
    }
}
