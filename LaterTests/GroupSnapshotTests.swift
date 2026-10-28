import SwiftUI
import Testing
@testable import Later_再度

/// 見た目の確認用:Homeのグループの列・招待カード・QR(LATER_SNAPSHOT_DIR が設定されている時だけ)
@MainActor
struct GroupSnapshotTests {
    private var dir: URL? { ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"].map { URL(fileURLWithPath: $0) } }

    private func write<V: View>(_ view: V, size: CGSize, name: String) throws {
        guard let dir else { return }
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height).background(Color.black).environment(\.colorScheme, .dark))
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try #require(image.pngData()).write(to: dir.appendingPathComponent("\(name).png"))
    }

    @Test(arguments: [4, 10])
    func addSheet(_ count: Int) throws {
        let view = GroupAddSheet(groupCount: count, onJoin: {}, onCreate: {})
            .background(Color(hex: "1C1C1E"))
            .frame(maxHeight: .infinity, alignment: .top)
        try write(view, size: CGSize(width: 390, height: 300), name: "group_add_sheet_\(count)")
        try write(view.environment(\.dynamicTypeSize, .accessibility1), size: CGSize(width: 390, height: 420), name: "group_add_sheet_\(count)_ax1")
    }

    @Test func strip() throws {
        let names = ["よいしょー", "かぞく", "ゼミのみんな", "朝ラン部", "とても長いグループの名前"]
        let counts = [(8, 3), (3, 3), (6, 0), (13, 7), (2, 1)]
        let ids = names.map { _ in UUID() }
        let auras = GroupRingMath.auraIndices(for: ids)
        let summaries = names.indices.map { i in
            GroupSummary(id: ids[i], name: names[i], iconData: nil, auraIndex: auras[i], memberCount: counts[i].0, postedYesterday: counts[i].1)
        }
        let view = HomeGroupStrip(summaries: summaries, canCreate: true, isFrontmost: false, entranceStart: nil, onSelect: { _ in }, onCreate: {})
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 20)
        try write(view, size: CGSize(width: 390, height: 170), name: "group_strip")

        // ScrollView の中は ImageRenderer で描かれないので、丸だけを並べて確かめる
        let tiles = HStack(alignment: .top, spacing: 12) {
            ForEach(summaries) { s in
                VStack(spacing: 7) {
                    ZStack {
                        GroupFace(iconData: nil, initial: s.initial, auraIndex: s.auraIndex, diameter: 46)
                        GroupLightRing(memberCount: s.memberCount, posted: s.postedYesterday, diameter: 62)
                    }
                    .frame(width: 62, height: 62)
                    Text(s.name).font(.system(size: 11.5, weight: .medium)).foregroundStyle(.white.opacity(0.88)).lineLimit(1).frame(maxWidth: 66)
                    Text(s.countText).font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(s.allPosted ? Color(hex: "FFB26E") : Color(hex: "8E8E93"))
                }
                .frame(width: 66)
            }
        }
        try write(tiles, size: CGSize(width: 390, height: 130), name: "group_tiles")
    }

    @Test(arguments: [false, true])
    func inviteCard(full: Bool) throws {
        let group = LaterGroup(name: "よいしょー")
        let summary = GroupSummary(id: group.id, name: group.name, iconData: nil, auraIndex: 0, memberCount: full ? 8 : 4, postedYesterday: 3)
        let view = InviteCard(group: group, summary: summary, haptics: ExposureHaptics(), onShowQR: { _ in })
            .padding(20)
            .frame(maxHeight: .infinity, alignment: .top)
        try write(view, size: CGSize(width: 390, height: 300), name: full ? "invite_card_full" : "invite_card")
    }

    @Test func qr() throws {
        let view = InviteQROverlay(url: InviteConfig.joinLink(shareURL: URL(string: "https://www.icloud.com/share/0abcDEF123#Later")!), auraIndex: 1, onClose: {})
        try write(view, size: CGSize(width: 390, height: 844), name: "invite_qr")
    }
}
