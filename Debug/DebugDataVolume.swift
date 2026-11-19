#if DEBUG
import CloudKit
import SwiftData
import SwiftUI

/// v106 §7-2:設定 > DEBUG「データの 量」。数を 出す だけ(消さない)。
/// ゾーン ・ Trip ・ グループ ・ 写真の 数と 大きさ、いちばん 古い 日付、端末の ファイル。
struct DebugDataVolumeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var lines: [(String, String)] = []
    @State private var zoneLines: [String] = []
    @State private var report = ""
    @State private var busy = true

    var body: some View {
        NavigationStack {
            List {
                Section("端末(SwiftData ・ ファイル)") {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, l in
                        HStack(alignment: .firstTextBaseline) { Text(l.0); Spacer(); Text(l.1).font(.system(.body, design: .monospaced)).multilineTextAlignment(.trailing) }
                    }
                }
                Section("iCloud(ゾーン)") {
                    if busy { ProgressView() }
                    ForEach(zoneLines, id: \.self) { Text($0).font(.system(size: 12, design: .monospaced)) }
                }
                Section { Button("数字を コピー") { UIPasteboard.general.string = report } }
            }
            .navigationTitle("データの 量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
            .task { await load() }
        }
    }

    private func bytes(_ n: Int64) -> String { ByteCountFormatter.string(fromByteCount: n, countStyle: .file) }

    private func dirSize(_ url: URL) -> Int64 {
        guard let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey]) else { return 0 }
        var t: Int64 = 0
        for case let u as URL in e {
            let v = try? u.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey])
            if v?.isRegularFile == true { t += Int64(v?.totalFileAllocatedSize ?? 0) }
        }
        return t
    }

    @MainActor private func load() async {
        var out: [(String, String)] = []
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first
        if let support { out.append(("Application Support", bytes(dirSize(support)))) }
        if let caches { out.append(("Caches", bytes(dirSize(caches)))) }
        if let docs { out.append(("Documents", bytes(dirSize(docs)))) }
        if let support, let items = try? fm.contentsOfDirectory(at: support, includingPropertiesForKeys: nil) {
            for u in items where u.pathExtension == "store" || u.lastPathComponent.hasSuffix(".store") { out.append(("  \(u.lastPathComponent)", bytes(dirSize(u)))) }
        }
        let groups = (try? modelContext.fetch(FetchDescriptor<LaterGroup>())) ?? []
        let personal = groups.filter(\.isPersonalSpace).count
        let shared = groups.count - personal
        out.append(("グループ(Trip) ・ ふつう / ME", "\(shared) / \(personal)"))
        if let oldest = groups.map(\.creationDate).min() { out.append(("いちばん 古い グループ", oldest.formatted(date: .numeric, time: .omitted))) }
        let photos = (try? modelContext.fetch(FetchDescriptor<LaterPhoto>())) ?? []
        let total = photos.reduce(Int64(0)) { $0 + Int64($1.imageData.count) }
        out.append(("写真の 数 ・ 大きさ", "\(photos.count) 枚 ・ \(bytes(total))"))
        if let big = photos.map({ $0.imageData.count }).max() { out.append(("いちばん 大きい 1枚", bytes(Int64(big)))) }
        if let oldest = photos.map(\.captureDate).min() { out.append(("いちばん 古い 写真", oldest.formatted(date: .numeric, time: .omitted))) }
        let profiles = (try? modelContext.fetch(FetchDescriptor<UserProfile>())) ?? []
        out.append(("プロフィール", "\(profiles.count)"))
        lines = out

        var zl: [String] = []
        let c = CKContainer(identifier: CloudKitManager.containerIdentifier)
        for (label, db) in [("private", c.privateCloudDatabase), ("shared", c.sharedCloudDatabase)] {
            do {
                let zones = try await db.allRecordZones()
                zl.append("[\(label)] ゾーン \(zones.count) 個")
                for z in zones.prefix(60) {
                    zl.append("  \(z.zoneID.zoneName.prefix(28)) ・ owner \(z.zoneID.ownerName.prefix(10))")
                }
            } catch { zl.append("[\(label)] 読めません: \(error.localizedDescription)") }
        }
        zoneLines = zl
        busy = false
        report = (out.map { "\($0.0): \($0.1)" } + zl).joined(separator: "\n")
    }
}
#endif
